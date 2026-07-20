#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# reads db-dump/postgres.sql -> psql -U postgres -d postgres (--set ON_ERROR_STOP=on)
restore_postgres postgres postgres postgres

