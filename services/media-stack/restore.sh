#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# Mirror of backup.sh: each service's dumps live in db-dump/<svc>/ and restore into
# ./<svc>/config. The per-service dir is the source-dir (2nd) argument. Stop the media
# containers first; re-run with FORCE=1 to overwrite a live database.
for svc in sonarr radarr prowlarr bazarr jellyfin; do
    [[ -d "db-dump/$svc" ]] || continue
    restore_sqlite_tree "./$svc/config" "db-dump/$svc"
done

# Counterpart to backup.sh's explicit suggestarr dump: its database lives in
# config_files/, not config/. `if` rather than `&&` for the same reason as there.
if [[ -d db-dump/suggestarr ]]; then
    restore_sqlite_tree ./suggestarr/config_files db-dump/suggestarr
fi
