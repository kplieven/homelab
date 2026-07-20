#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
mkdir -p db-dump

# Vaultwarden's own consistent SQLite dump, written into ./data as db_<timestamp>.sqlite3.
docker compose exec -T vaultwarden /vaultwarden backup

# Move the fresh dump to a FIXED filename so restic dedupes across nights, verify it,
# and clean up the timestamped originals so they can't accumulate inside live data/.
newest=$(find ./data -maxdepth 1 -name 'db_2*.sqlite3' -newermt '-5 minutes' | sort | tail -n1)
[[ -n "$newest" ]] || { echo "vaultwarden backup produced no dump" >&2; exit 1; }
sqlite3 "$newest" 'PRAGMA integrity_check;' | grep -qx ok
mv -f "$newest" db-dump/db-snapshot.sqlite3
find ./data -maxdepth 1 -name 'db_2*.sqlite3' -delete

