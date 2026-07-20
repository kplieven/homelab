#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
dump_postgres postgres "${DB_USERNAME}" "${DB_DATABASE}"

