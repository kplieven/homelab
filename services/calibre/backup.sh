#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
# calibre-web's own app database only. The Calibre LIBRARY is bulk data on /mnt/ssd
# and out of scope.
dump_sqlite_tree ./calibre-web/config

