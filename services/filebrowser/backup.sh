#!/bin/bash
set -euo pipefail
# filebrowser uses BoltDB, not SQLite — sqlite3 .backup cannot read it, and there is no
# online dump API. A brief stop is the only way to get a non-torn copy.
mkdir -p db-dump
docker compose stop
trap 'docker compose start' EXIT          # container comes back even if the copy fails
cp -a filebrowser.db db-dump/filebrowser.db.tmp
mv -f db-dump/filebrowser.db.tmp db-dump/filebrowser.db
