#!/bin/bash
set -euo pipefail

# data/ — the RSA session-signing keys, attachments/, sends/, config.json — is restored by
# the folder snapshot itself. This puts back only the one file that was excluded and dumped:
# the live SQLite db. Restoring the db WITHOUT those keys logs every client out.
# Stop vaultwarden before running; FORCE=1 to overwrite an existing data/db.sqlite3.
src=db-dump/db-snapshot.sqlite3
dest=./data/db.sqlite3

[[ -f "$src" ]] || { echo "restore: no $src (did backup.sh run?)" >&2; exit 1; }
sqlite3 "$src" 'PRAGMA integrity_check;' | grep -qx ok \
    || { echo "restore: $src fails integrity_check" >&2; exit 1; }
if [[ -e "$dest" && "${FORCE:-0}" != "1" ]]; then
    echo "restore: $dest exists; stop vaultwarden and re-run with FORCE=1" >&2; exit 1
fi
mkdir -p ./data
cp -a "$src" "$dest"
# If vaultwarden runs as a non-root uid, chown "$dest" to it before `docker compose up -d`.

