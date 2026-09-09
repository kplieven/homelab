#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# One compose folder, several services with their own config dirs and databases.
# Same collision rule as media-stack: a single shared db-dump/ would let equal
# basenames overwrite each other silently, so give every service its own output
# dir (2nd arg to dump_sqlite_tree). The exclude-file re-includes
# services/*/db-dump/** recursively, so the per-service subdirs back up unchanged.
#
# The Calibre LIBRARY and the audiobook files are bulk data on /mnt/media and
# out of scope here. mam is qBittorrent (flat .conf + .fastresume, no sqlite),
# so it is not dumped either -- its config dir is backed up as plain files.
for svc in calibre-web audiobookshelf; do
    [[ -d "./$svc/config" ]] || continue
    dump_sqlite_tree "./$svc/config" "db-dump/$svc"
done
