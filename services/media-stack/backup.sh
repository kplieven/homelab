#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# One compose folder, several services, each with its own config dir and database(s).
# Sonarr/Radarr/Prowlarr each ship a logs.db beside their main *.db, so a single shared
# db-dump/ would let those basenames collide — last writer wins, silently. Pass each
# service its own output dir (2nd arg to dump_sqlite_tree) so nothing overwrites anything
# else. The exclude-file re-includes services/*/db-dump/** recursively, so the per-service
# subdirs back up unchanged — no exclude-file edit needed.
# jellyseerr keeps its database one level deeper (config/db/db.sqlite3) and was
# missing from this list until its data was lost on the Proxmox migration: the
# **/*.sqlite3 exclude dropped it from restic with no dump behind it, and
# assert-pairing.sh could not see the gap because it checks for a backup.sh per
# service DIRECTORY -- media-stack has one, it just skipped a sub-service.
for svc in sonarr radarr prowlarr bazarr jellyfin jellyseerr; do
    [[ -d "./$svc/config" ]] || continue
    dump_sqlite_tree "./$svc/config" "db-dump/$svc"
done

# SuggestArr keeps requests.db in config_files/, not config/, so it cannot join the
# loop above. It matches the **/*.db exclude like every other live sqlite file, and
# media-stack already has a backup.sh, so assert-pairing.sh would NOT catch its
# absence -- the same blind spot that lost jellyseerr's database. Dump it explicitly.
# requests.db is the record of what has already been requested; without it a restored
# SuggestArr re-requests the entire watch history on its next run.
# An `if`, not `[[ ... ]] && cmd`: that form returns 1 when the dir is absent, and as
# the last line of a `set -e` script that becomes the script's exit status -- a missing
# optional service would fail the whole backup.
if [[ -d ./suggestarr/config_files ]]; then
    dump_sqlite_tree ./suggestarr/config_files db-dump/suggestarr
fi
