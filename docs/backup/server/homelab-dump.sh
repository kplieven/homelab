#!/bin/bash
# resticprofile run-before hook. Any failure aborts the backup — the point: a skipped
# backup with a red healthcheck beats a green backup of a stale or torn dump.
set -euo pipefail
HOMELAB_DIR=/path/to/homelab/dir

"$HOMELAB_DIR/scripts/assert-pairing.sh" /etc/restic/homelab-excludes.txt

for script in "$HOMELAB_DIR"/services/*/backup.sh; do
    [[ -x "$script" ]] || continue
    svc=$(basename "$(dirname "$script")")
    ( cd "$(dirname "$script")" && ./backup.sh ) || { echo "homelab-dump: $svc/backup.sh failed" >&2; exit 1; }
done
echo "homelab-dump: all dumps complete"

