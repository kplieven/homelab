#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# Mirror of backup.sh: each service's dumps live in db-dump/<svc>/ and restore
# into ./<svc>/config. Stop the books-stack containers first; re-run with
# FORCE=1 to overwrite a live database.
for svc in calibre-web audiobookshelf; do
    [[ -d "db-dump/$svc" ]] || continue
    restore_sqlite_tree "./$svc/config" "db-dump/$svc"
done
