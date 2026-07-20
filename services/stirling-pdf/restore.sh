#!/bin/bash
set -euo pipefail
# Mirror of backup.sh. H2's .mv.db is a plain file, so the restore is a copy back — but
# only into a stopped service, which this script handles itself. No restore-lib.sh:
# restore_sqlite_tree would copy the file into place without stopping the container.

shopt -s nullglob
dumps=(db-dump/stirling-pdf-DB-*.mv.db)

[[ ${#dumps[@]} -gt 0 ]] || { echo "restore: no db-dump/stirling-pdf-DB-*.mv.db" >&2; exit 1; }
# More than one means an upgrade left a stale version behind, and it is ambiguous which
# the current image wants. Fail rather than guess.
[[ ${#dumps[@]} -eq 1 ]] || {
    echo "restore: ${#dumps[@]} dumps present, expected 1 — remove stale versions:" >&2
    printf '  %s\n' "${dumps[@]}" >&2; exit 1; }

src="${dumps[0]}"; base=$(basename "$src")

if [[ -e "config/${base}" && "${FORCE:-0}" != "1" ]]; then
    echo "restore: config/${base} exists; re-run with FORCE=1 to overwrite" >&2
    exit 1
fi

docker compose stop
trap 'docker compose start' EXIT      # container comes back even if the copy fails
mkdir -p config
cp -a "$src" "config/${base}"
trap - EXIT
docker compose start

