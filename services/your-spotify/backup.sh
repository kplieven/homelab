#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# No auth on this instance. If mongodump is missing from the image, use:
#   docker compose exec -T mongo sh -c 'mongodump --archive'
dump_mongo mongo

