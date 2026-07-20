#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# reads db-dump/mongo.archive -> mongorestore --archive --drop
restore_mongo mongo

