#!/bin/bash
# Repoint every .env from the old single-disk layout (/mnt/ssd/...) to the
# Proxmox split: bulk data on the HDD pool, torrents on NVMe.
#
# Run ON THE NEW BOX (container 100), after `restic restore`, BEFORE any
# `docker compose up`. Idempotent — safe to re-run.
#
# It only touches .env files. The structural compose changes (media-stack's
# single /data mount splitting in two, filebrowser, homepage, the GPU swap)
# are tracked in git and described in docs/backup/migrate-to-proxmox.md.
set -euo pipefail

HOMELAB_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$HOMELAB_DIR"

# Guard: running this on the old server would repoint a live system at paths
# that do not exist there, and every service would fail on next restart.
[[ -e /mnt/ssd ]] && { echo "REFUSING: /mnt/ssd exists — this looks like the old server" >&2; exit 1; }
for m in /mnt/media /mnt/torrents /mnt/files /mnt/photos; do
    mountpoint -q "$m" || { echo "REFUSING: $m is not a mountpoint — fix the LXC config first" >&2; exit 1; }
done

# Ordered most-specific-first; a later rule must never re-match an earlier result.
MAP=(
    "/mnt/ssd/server/media|/mnt/media"
    "/mnt/ssd/server/torrents|/mnt/torrents"
    "/mnt/ssd/server/to-be-imported|/mnt/files/to-be-imported"
    "/mnt/ssd/server|/mnt/media"
    "/mnt/ssd/immich_library|/mnt/photos/immich_library"
    "/mnt/ssd/immich|/mnt/photos/immich"
    "/mnt/ssd/Foto's|/mnt/photos/Foto's"
    "/mnt/ssd/Documents|/mnt/files/Documents"
    "/mnt/ssd/Scans|/mnt/files/Scans"
    "/mnt/ssd/Backup|/mnt/files/Backup"
    "/mnt/ssd/music|/mnt/files/music"
    "/mnt/ssd/informatica_archived|/mnt/files/informatica_archived"
    "/mnt/ssd/restic|/mnt/restic"
    "/mnt/ssd|/mnt/media"
)

changed=0
while IFS= read -r env; do
    before=$(sha256sum "$env")
    for rule in "${MAP[@]}"; do
        sed -i "s|${rule%%|*}|${rule##*|}|g" "$env"
    done
    [[ "$(sha256sum "$env")" != "$before" ]] && { echo "repointed: $env"; changed=$((changed+1)); }
done < <(find services -maxdepth 2 -name '.env' -type f)

# Vars that did not exist in the old layout, because the old layout had one disk.
add_var() {  # add_var <file> <KEY> <value>
    grep -q "^$2=" "$1" || { printf '%s=%s\n' "$2" "$3" >> "$1"; echo "added: $2 -> $1"; }
}
add_var services/media-stack/.env TORRENT_ROOT /mnt/torrents
add_var services/filebrowser/.env TORRENT_ROOT /mnt/torrents
add_var services/filebrowser/.env FILES_ROOT   /mnt/files
add_var services/homepage/.env    TORRENT_DISK_PATH /mnt/torrents

# import-new-books.sh hardcodes its paths rather than reading an .env.
sed -i 's|/mnt/ssd/server/torrents/books|/mnt/torrents/books|; s|/mnt/ssd/server/to-be-imported/books|/mnt/files/to-be-imported/books|' \
    services/books-stack/import-new-books.sh

echo
echo "Done — $changed .env files repointed."
echo "Verify nothing was missed:  grep -rn /mnt/ssd services/ --include='.env' --include='*.sh'"
