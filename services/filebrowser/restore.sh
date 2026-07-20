#!/bin/bash
set -euo pipefail
[[ -f db-dump/filebrowser.db ]] || { echo "restore: no db-dump/filebrowser.db" >&2; exit 1; }
[[ ! -f filebrowser.db || "${FORCE:-0}" == 1 ]] || { echo "restore: live db present; set FORCE=1" >&2; exit 1; }
docker compose stop
cp -a db-dump/filebrowser.db filebrowser.db
docker compose start
