#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
# Container is "database" in recent releases, "immich_postgres" in older ones — must match
# the name backup.sh used. Confirm with: docker compose config --services
restore_postgres database "${DB_USERNAME}" "${DB_DATABASE_NAME}"

