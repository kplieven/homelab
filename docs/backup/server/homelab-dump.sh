#!/bin/bash
# resticprofile run-before hook. Any failure aborts the backup — the point: a skipped
# backup with a red healthcheck beats a green backup of a stale or torn dump.
set -euo pipefail
HOMELAB_DIR=/path/to/homelab/dir

"$HOMELAB_DIR/scripts/assert-pairing.sh" /etc/restic/homelab-excludes.txt

for script in "$HOMELAB_DIR"/services/*/backup.sh; do
    [[ -x "$script" ]] || continue
    dir=$(dirname "$script")
    svc=$(basename "$dir")

    # A service disabled with .disabled -- the repo-wide marker honoured by
    # update-and-run-containers.sh -- has no container left to dump from, so its
    # backup.sh fails and takes down every service after it in this loop with it. Skip
    # it. Its raw DB path stays excluded either way, so the snapshot then carries
    # whatever is already in db-dump/ and nothing else: the two checks below are what
    # make that safe rather than merely quiet.
    if [[ -f "$dir/.disabled" ]]; then
        # Still running means the marker is lying. The database can still be written, so
        # freezing the dump would let it go stale invisibly. Same probe as
        # update-and-run-containers.sh, so both agree on what "running" means.
        running=$(cd "$dir" && docker compose ps --services --filter "status=running" 2>/dev/null || true)
        [[ -z "$running" ]] || {
            echo "homelab-dump: $svc is marked .disabled but still running ($(echo "$running" | tr "\n" " " | sed "s/ *$//")); refusing to freeze its dump" >&2
            exit 1; }
        # Nothing in db-dump/ means it was disabled before it was ever dumped: its
        # database is excluded with no dump behind it. That is the unpaired exclusion
        # the pairing rule exists to prevent, reached from the other direction --
        # assert-pairing.sh sees the backup.sh and is satisfied, but it never runs.
        newest=$(find "$dir/db-dump" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null | sort -r | head -n1)
        [[ -n "$newest" ]] || {
            echo "homelab-dump: $svc is disabled but has no dump in db-dump/; its database is excluded with nothing behind it" >&2
            exit 1; }
        reason=$(tr '\n' ' ' < "$dir/.disabled" | sed 's/[[:space:]]*$//')
        echo "homelab-dump: $svc disabled${reason:+ ($reason)}, keeping its dump from $newest"
        continue
    fi

    ( cd "$dir" && ./backup.sh ) || { echo "homelab-dump: $svc/backup.sh failed" >&2; exit 1; }
done
echo "homelab-dump: all dumps complete"
