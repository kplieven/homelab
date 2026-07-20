#!/bin/bash
set -euo pipefail
# Stirling-PDF embeds H2 (.mv.db), not SQLite — dump_sqlite_tree cannot read it, and
# **/*.db excludes the live file. Stop/copy is the only consistent snapshot without JDBC.
# No backup-lib.sh: every helper in it is SQLite/Postgres/Mongo-specific.
mkdir -p db-dump

docker compose stop
trap 'docker compose start' EXIT          # container comes back even if the copy fails

# The version is IN the filename and changes on upgrade, so the glob is deliberate and
# stale copies are cleared first — db-dump/ must hold exactly one, or restore.sh cannot
# tell which version the current image wants.
rm -f db-dump/stirling-pdf-DB-*.mv.db
for f in config/stirling-pdf-DB-*.mv.db; do
    b=$(basename "$f")
    cp -a "$f" "db-dump/${b}.tmp"
    mv -f "db-dump/${b}.tmp" "db-dump/${b}"
done

trap - EXIT
docker compose start

