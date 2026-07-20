#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# One compose folder, several services, each with its own config dir and database(s).
# Sonarr/Radarr/Prowlarr each ship a logs.db beside their main *.db, so a single shared
# db-dump/ would let those basenames collide — last writer wins, silently. Pass each
# service its own output dir (2nd arg to dump_sqlite_tree) so nothing overwrites anything
# else. The exclude-file re-includes services/*/db-dump/** recursively, so the per-service
# subdirs back up unchanged — no exclude-file edit needed.
for svc in sonarr radarr prowlarr bazarr jellyfin audiobookshelf; do
    [[ -d "./$svc/config" ]] || continue
    dump_sqlite_tree "./$svc/config" "db-dump/$svc"
done

