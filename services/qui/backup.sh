#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
# qui keeps everything in one SQLite db: instance definitions, their encrypted
# API credentials, and UI preferences. Most of it lives in the -wal until a
# checkpoint, so .backup (not cp) is what makes the dump complete.
dump_sqlite_tree ./config
