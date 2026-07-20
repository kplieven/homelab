#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
restore_postgres postgres "${DB_USERNAME}" "${DB_DATABASE}"

