#!/bin/bash
#
# Import finished ebook downloads into Calibre-Web-Automated's ingest folder.
#
# Unlike import-new-audiobooks.sh, the unit of import is the individual *file*:
# an ebook is standalone, where an audiobook is a folder whose structure carries
# the multi-part ordering and must be copied whole.
#
# Where several formats of the same book arrive in one download, only the most
# preferred one is imported. Files are grouped by directory + basename stem, so
# a single-book torrent ("Dune.epub", "Dune.mobi") collapses to one format while
# a bundle torrent keeps every distinct title. Two namings of the same book
# ("Dune.epub", "Dune (retail).mobi") have different stems and both import --
# the pre-existing behaviour, and preferable to guessing at title equality.
#
# /mnt/torrents and the ingest folder are separate filesystems, so this copies;
# hardlinking is not possible. Downloads stay put for seeding.

set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Where they are downloaded
SOURCE_DIR="/mnt/torrents/books"
# Where calibre listens for new books
DEST_DIR="$SCRIPT_DIR/ingest"
# Local file to know which books have been imported already
HASH_DB="$SCRIPT_DIR/imported-books-hashes.txt"

# Extensions to import, MOST PREFERRED FIRST. An extension absent from this
# list is never imported at all. Order is the whole point: within one group the
# earliest-listed format wins and the rest are left where they are.
FORMAT_PRIORITY="epub mobi azw3 pdf djvu cbz cbr"

# Skip anything still being written: a group is only imported once every file
# in it has been untouched for this long.
SETTLE_MINUTES=5

# An empty hash DB against a full source directory is the shape of a lost or
# restored-without-state DB, not of a first run with real work to do. Importing
# then would flood the ingest folder with the entire back catalogue. Refuse, and
# make the operator pick --adopt-all (record everything, copy nothing) or
# --force (yes, really import all of it).
FLOOD_THRESHOLD=5

DRY_RUN=0
ADOPT_ALL=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --adopt-all) ADOPT_ALL=1 ;;
        --force)     FORCE=1 ;;
        *) echo "usage: $(basename "$0") [--dry-run] [--adopt-all] [--force]" >&2; exit 2 ;;
    esac
done

mkdir -p "$DEST_DIR" || exit 1
touch "$HASH_DB" || exit 1

# Build a case-insensitive find expression from the priority list.
FIND_EXPR=()
for ext in $FORMAT_PRIORITY; do
    FIND_EXPR+=(-iname "*.$ext" -o)
done
unset 'FIND_EXPR[${#FIND_EXPR[@]}-1]'   # drop trailing -o

# Index of an extension in FORMAT_PRIORITY; lower is better. Returns 1 for an
# extension not in the list, which cannot happen given the find expression above
# but keeps the function honest if it is ever called from elsewhere.
priority_of() {
    local want="${1,,}" i=0 ext
    for ext in $FORMAT_PRIORITY; do
        [[ "$ext" == "$want" ]] && { printf '%s' "$i"; return 0; }
        i=$((i + 1))
    done
    return 1
}

declare -A best_path      # group key -> winning file
declare -A best_prio      # group key -> winning file's priority index
declare -A group_recent   # group key -> set if ANY member was touched recently

candidates=0

# Settle is evaluated per GROUP, not per file. If Dune.epub is still downloading
# while Dune.mobi is complete, importing the mobi now would mean importing the
# epub as a second copy minutes later. The whole group waits instead.
while IFS= read -r -d '' f; do
    ext="${f##*.}"
    prio="$(priority_of "$ext")" || continue
    candidates=$((candidates + 1))

    dir="$(dirname "$f")"
    base="$(basename "$f")"
    key="$dir/${base%.*}"

    cur="${best_prio[$key]:-}"
    if [[ -z "$cur" ]] || (( prio < cur )); then
        best_prio[$key]=$prio
        best_path[$key]="$f"
    fi

    if [[ -n "$(find "$f" -newermt "-${SETTLE_MINUTES} minutes" -print -quit)" ]]; then
        group_recent[$key]=1
    fi
done < <(find "$SOURCE_DIR" -type f \( "${FIND_EXPR[@]}" \) -print0)

groups=${#best_path[@]}
superseded=$((candidates - groups))

if (( groups == 0 )); then
    echo "Nothing to do: no importable files under $SOURCE_DIR"
    exit 0
fi

if (( ! ADOPT_ALL && ! FORCE && ! DRY_RUN )) \
   && [[ ! -s "$HASH_DB" ]] && (( groups >= FLOOD_THRESHOLD )); then
    echo "ERROR: $HASH_DB is empty but $groups books are waiting to import." >&2
    echo "       That is what a lost or unrestored hash DB looks like, not a first run." >&2
    echo "       Re-run with --adopt-all to record them without copying," >&2
    echo "       or --force if you really do want all $groups imported." >&2
    exit 1
fi

imported=0
adopted=0
skipped=0
failed=0

for key in "${!best_path[@]}"; do
    file="${best_path[$key]}"
    name="$(basename "$file")"

    hash="$(sha256sum "$file" | awk '{print $1}')" || {
        echo "ERROR: could not hash '$file'" >&2
        failed=$((failed + 1))
        continue
    }

    if grep -qF "$hash" "$HASH_DB"; then
        echo "Skipping already-imported book: $name"
        skipped=$((skipped + 1))
        continue
    fi

    # Checked before --adopt-all as well as before a copy: adopting a file that
    # is still being written would record the hash of a partial file, which the
    # finished file would then not match.
    if [[ -n "${group_recent[$key]:-}" ]]; then
        echo "Skipping (still downloading, modified < ${SETTLE_MINUTES}m ago): $name"
        skipped=$((skipped + 1))
        continue
    fi

    # Record without copying: used by --adopt-all to rebuild a lost hash DB from
    # a library that already holds these books.
    if (( ADOPT_ALL )); then
        echo "Adopting (not copying): $name"
        (( DRY_RUN )) || printf '%s\t%s\n' "$hash" "$name" >> "$HASH_DB"
        adopted=$((adopted + 1))
        continue
    fi

    # The ingest folder is transient -- CWA consumes and removes files -- so a
    # name already sitting there is another book waiting its turn, not this one
    # already done. Disambiguate rather than overwrite it.
    dest="$DEST_DIR/$name"
    if [[ -e "$dest" ]]; then
        dest="$DEST_DIR/${name%.*}.${hash:0:8}.${name##*.}"
        echo "Name collision in ingest, importing as: $(basename "$dest")"
    fi

    size=$(stat -c %s "$file")
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

    # Copy to a dot-prefixed staging name first, then rename into place, so CWA
    # never picks up a half-written file from the folder it is watching.
    staging="$DEST_DIR/.importing-$(basename "$dest")"
    rm -f "$staging"

    if cp "$file" "$staging" && mv -T "$staging" "$dest"; then
        printf '%s\t%s\n' "$hash" "$name" >> "$HASH_DB"
        echo "Imported new book: $name ($(numfmt --to=iec "$size"))"
        imported=$((imported + 1))
    else
        echo "ERROR: failed to import '$name'" >&2
        rm -f "$staging"
        failed=$((failed + 1))
    fi
done

echo
echo "Done. imported=$imported adopted=$adopted skipped=$skipped failed=$failed" \
     "(superseded by a preferred format: $superseded)"
(( failed == 0 ))
