#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a

# NOT dump_postgres -- that produced a dump that cannot be restored, silently, for as
# long as this service has been backed up. Verified 2026-09-08 during the Proxmox move.
#
# Komodo's data lives in FerretDB. FerretDB keeps the documents in ordinary tables
# (documentdb_data.documents_<n>) but the collection catalogue
# (documentdb_api_catalog.collections) belongs to the `documentdb` EXTENSION, and
# pg_dump does not dump extension-owned table data. A pg_dump/psql round-trip therefore
# restores every document row and no catalogue at all: FerretDB sees zero collections
# while documents_<n> already exist, so Komodo allocates collection id 17 afresh and
# dies on `relation "documents_17" already exists`.
#
# Second, independent defect in the old approach: the dump's own `COPY cron.job` block
# always collided with the jobs that `CREATE EXTENSION documentdb` re-registers earlier
# in the same replay, so ON_ERROR_STOP aborted at the FIRST COPY and every table came
# back empty.
#
# Dumping over the mongo wire protocol avoids both. The ferretdb image is scratch-based
# (no shell, no mongodump), hence the sidecar.
dump_mongo_sidecar komodo_default \
    "mongodb://${KOMODO_DB_USERNAME}:${KOMODO_DB_PASSWORD}@ferretdb:27017/komodo"
