#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# db name is literally "romm" in the compose file; credentials come from the
# container's own MARIADB_USER/MARIADB_PASSWORD, so nothing is read from .env here.
dump_mariadb romm-db romm
