#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# --delete makes the export a mirror, not a pile: documents deleted in Paperless are
# deleted from the export too. The exporter is the primary restore artefact.
docker compose exec -T webserver document_exporter ../export --delete

# Belt-and-braces: dump the DB too. POSTGRES_USER/DB are "paperless" in the compose file.
# Confirm the DB service name (default "db") with: docker compose config --services
dump_postgres db paperless paperless

