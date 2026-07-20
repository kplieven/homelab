#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
# db name is literally "postgres"; only the user comes from .env.
dump_postgres postgres "${KOMODO_DB_USERNAME}" postgres

