#!/bin/bash
#
# Import finished audiobook downloads into the Audiobookshelf library.
#
# Unlike import-new-books.sh, the unit of import is the *top-level entry* in
# SOURCE_DIR (a folder like "Mistborn/" or a lone "Book.m4b"), not the
# individual audio file. Audiobookshelf derives the book -- and its multi-part
# ordering -- from that folder, so flattening it the way the ebook script does
# would turn a 109-part Monte Cristo into 109 unrelated "books".
#
# /mnt/torrents and /mnt/media are separate filesystems (ext4 vs zfs), so this
# copies; hardlinking is not possible. Downloads stay put for seeding.

set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Where they are downloaded
SOURCE_DIR="/mnt/torrents/audiobooks"
# The Audiobookshelf library itself -- there is no ingest folder to watch
DEST_DIR="/mnt/media/audiobooks"
# Local file to know which audiobooks have been imported already
HASH_DB="$SCRIPT_DIR/imported-audiobooks-hashes.txt"

# Audio extensions that make an entry count as an audiobook (case-insensitive)
EXTENSIONS="m4b m4a mp3 flac ogg opus aac wma"

# Skip anything still being written: an entry is only imported once every file
# in it has been untouched for this long.
SETTLE_MINUTES=5

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

mkdir -p "$DEST_DIR"
touch "$HASH_DB"

# Build a case-insensitive find expression for the audio extensions
FIND_EXPR=()
for ext in $EXTENSIONS; do
    FIND_EXPR+=(-iname "*.$ext" -o)
done
unset 'FIND_EXPR[${#FIND_EXPR[@]}-1]'   # drop trailing -o

# A cheap, stable fingerprint of an entry: every audio file's path relative to
# the entry root, plus its size. Content hashing would mean re-reading ~25 GB
# on every run; sizes catch the cases that matter (new part, replaced file,
# truncated download) without the I/O.
fingerprint() {
    local entry="$1"
    {
        if [[ -d "$entry" ]]; then
            find "$entry" -type f \( "${FIND_EXPR[@]}" \) -printf '%P\t%s\n' | sort
        else
            printf '%s\t%s\n' "$(basename "$entry")" "$(stat -c %s "$entry")"
        fi
    } | sha256sum | awk '{print $1}'
}

# True if every audio file in the entry has been quiet for SETTLE_MINUTES.
is_settled() {
    local entry="$1"
    local recent
    recent=$(find "$entry" -type f \( "${FIND_EXPR[@]}" \) -newermt "-${SETTLE_MINUTES} minutes" -print -quit)
    [[ -z "$recent" ]]
}

has_audio() {
    local entry="$1"
    [[ -n "$(find "$entry" -type f \( "${FIND_EXPR[@]}" \) -print -quit)" ]]
}

entry_size() {
    du -sb "$1" | awk '{print $1}'
}

imported=0
adopted=0
skipped=0
failed=0

shopt -s nullglob dotglob
for entry in "$SOURCE_DIR"/*; do
    name="$(basename "$entry")"

    if ! has_audio "$entry"; then
        echo "Skipping (no audio files): $name"
        skipped=$((skipped + 1))
        continue
    fi

    hash="$(fingerprint "$entry")"

    if grep -qF "$hash" "$HASH_DB"; then
        echo "Skipping already-imported audiobook: $name"
        skipped=$((skipped + 1))
        continue
    fi

    # Already sitting in the library from a previous manual copy: record it so
    # we never re-copy it, but leave the destination alone.
    if [[ -e "$DEST_DIR/$name" ]]; then
        echo "Adopting existing library entry (not re-copying): $name"
        (( DRY_RUN )) || printf '%s\t%s\n' "$hash" "$name" >> "$HASH_DB"
        adopted=$((adopted + 1))
        continue
    fi

    if ! is_settled "$entry"; then
        echo "Skipping (still downloading, modified < ${SETTLE_MINUTES}m ago): $name"
        skipped=$((skipped + 1))
        continue
    fi

    size=$(entry_size "$entry")
    avail=$(df -B1 --output=avail "$DEST_DIR" | tail -n1)
    if (( size > avail )); then
        echo "ERROR: not enough space for '$name' ($(numfmt --to=iec "$size") needed, $(numfmt --to=iec "$avail") free)" >&2
        failed=$((failed + 1))
        continue
    fi

    if (( DRY_RUN )); then
        echo "[dry-run] Would import: $name ($(numfmt --to=iec "$size"))"
        imported=$((imported + 1))
        continue
    fi

    # Copy into a staging name first, then rename into place, so Audiobookshelf
    # never scans a half-written book.
    staging="$DEST_DIR/.importing-$name"
    rm -rf "$staging"

    if cp -a "$entry" "$staging" && mv -T "$staging" "$DEST_DIR/$name"; then
        printf '%s\t%s\n' "$hash" "$name" >> "$HASH_DB"
        echo "Imported new audiobook: $name ($(numfmt --to=iec "$size"))"
        imported=$((imported + 1))
    else
        echo "ERROR: failed to import '$name'" >&2
        rm -rf "$staging"
        failed=$((failed + 1))
    fi
done

echo
echo "Done. imported=$imported adopted=$adopted skipped=$skipped failed=$failed"
(( failed == 0 ))
