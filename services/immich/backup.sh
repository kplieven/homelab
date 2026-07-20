#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
# Container is "database" in recent releases, "immich_postgres" in older ones.
# Confirm with: docker compose config --services
dump_postgres database "${DB_USERNAME}" "${DB_DATABASE_NAME}"

