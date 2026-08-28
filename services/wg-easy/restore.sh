#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
# wg0.conf is restored with the rest of config/ by restic; only wg-easy.db comes from
# the dump. Stop the container first: wg-easy holds the db open and rewrites it on exit,
# which would put the old peer set straight back over the restored one.
restore_sqlite_tree ./config
