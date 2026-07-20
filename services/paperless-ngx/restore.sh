#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# The exporter output (../export) is the primary restore artefact. document_importer expects
# an EMPTY instance: start with a fresh (empty) database volume and the stack up, then import.
# Importing into a populated instance duplicates or errors.
docker compose run --rm webserver document_importer ../export

# The Postgres dump is belt-and-braces. Use it INSTEAD of the importer above (never both) to
# replay the raw dump straight into a fresh empty DB:
#   restore_postgres db paperless paperless

