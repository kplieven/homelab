#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# DATABASE_URL=postgresql://postgres:...@postgres:5432/postgres
# container, user, and db are all literally "postgres" — no env var needed.
dump_postgres postgres postgres postgres

