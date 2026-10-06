#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# reads db-dump/romm.sql -> mariadb romm. Bring up only the database first
# (`docker compose up -d romm-db`) so RomM's startup migrations don't race the replay,
# then start romm once this finishes.
restore_mariadb romm-db romm
