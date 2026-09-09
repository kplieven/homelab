#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a

# See backup.sh for why this is a mongo restore and not a psql replay.
# komodo_core must be stopped first: it panics on a database that changes under it.
restore_mongo_sidecar komodo_default \
    "mongodb://${KOMODO_DB_USERNAME}:${KOMODO_DB_PASSWORD}@ferretdb:27017/komodo"
