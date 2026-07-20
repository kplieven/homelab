#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
restore_postgres postgres "${KOMODO_DB_USERNAME}" postgres

