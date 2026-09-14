#!/bin/bash
# Shared dump helpers. Sourced by services/*/backup.sh with CWD = service dir.
#
# Every dump writes to db-dump/<name>.tmp and only mv's into place on success, so a
# failed dump can never destroy the previous good one. Callers run under `set -e`: a
# non-zero return aborts the service's backup.sh, which aborts the orchestrator, which
# makes resticprofile skip the backup entirely. That chain is what stops a stale or
# torn dump from being silently shipped.

_dump_dir() { mkdir -p db-dump; }

# dump_postgres <container> <user> <db> [pg_dump args...]  ->  db-dump/<db>.sql
# Trailing args go to pg_dump verbatim. Used to drop table DATA that is pure operational
# log -- see komodo's cron.job_run_details. Prefer --exclude-table-data over
# --exclude-table: it drops one table's rows without touching sibling tables that a
# restore genuinely needs.
dump_postgres() {
    local container="$1" user="$2" db="$3"; shift 3
    _dump_dir
    # The `|| { rm; return 1; }` is not redundant under `set -e`: the redirect creates
    # the .tmp before pg_dump runs, so a bare failure would abort here and strand it.
    docker compose exec -T "$container" \
        pg_dump -U "$user" -d "$db" --clean --if-exists "$@" > "db-dump/${db}.sql.tmp" || {
        echo "dump_postgres: pg_dump failed for ${db}" >&2
        rm -f "db-dump/${db}.sql.tmp"; return 1; }
    # pg_dump writes a terminating comment; its absence means a truncated dump that
    # psql would replay halfway and leave a half-populated database.
    grep -q 'PostgreSQL database dump complete' "db-dump/${db}.sql.tmp" || {
        echo "dump_postgres: ${db} dump is truncated" >&2
        rm -f "db-dump/${db}.sql.tmp"; return 1; }
    mv -f "db-dump/${db}.sql.tmp" "db-dump/${db}.sql"
}

# dump_mongo <container> [db]  ->  db-dump/mongo.archive
dump_mongo() {
    local container="$1" db="${2:-}"
    _dump_dir
    local args=(--archive); [[ -n "$db" ]] && args+=(--db "$db")
    # Same trap as dump_postgres: without the `||`, a mongodump failure aborts on this
    # line under `set -e` and leaves mongo.archive.tmp behind. A stranded .tmp beside a
    # missing mongo.archive is the signature of exactly that.
    docker compose exec -T "$container" mongodump "${args[@]}" > db-dump/mongo.archive.tmp || {
        echo "dump_mongo: mongodump failed" >&2
        rm -f db-dump/mongo.archive.tmp; return 1; }
    # NOTE: -s only proves non-empty. Unlike dump_postgres (terminator check) and
    # dump_sqlite_tree (integrity_check), there is no content validation here — a
    # truncated archive passes. See the verify list.
    [[ -s db-dump/mongo.archive.tmp ]] || {
        echo "dump_mongo: empty archive" >&2
        rm -f db-dump/mongo.archive.tmp; return 1; }
    mv -f db-dump/mongo.archive.tmp db-dump/mongo.archive
}

# dump_mongo_sidecar <network> <uri> [min_bytes]  ->  db-dump/mongo.archive
# For a mongo-wire database whose own container carries no mongodump: runs the tool
# from a mongo:6 sidecar on <network> instead of `docker compose exec`. FerretDB is
# scratch-based (no shell, no tools), so this is the only way to reach it.
#
# min_bytes defaults to 1024. An archive holding zero collections is ~112 bytes and
# would sail through dump_mongo's `-s` non-empty check, so the floor is the point:
# for a database that is never legitimately empty, "dumped nothing" is a failure,
# not a backup.
dump_mongo_sidecar() {
    local network="$1" uri="$2" min="${3:-1024}"
    _dump_dir
    docker run --rm --network "$network" mongo:6 \
        mongodump --uri "$uri" --archive > db-dump/mongo.archive.tmp || {
        echo "dump_mongo_sidecar: mongodump failed" >&2
        rm -f db-dump/mongo.archive.tmp; return 1; }
    local size; size=$(stat -c%s db-dump/mongo.archive.tmp 2>/dev/null || echo 0)
    (( size >= min )) || {
        echo "dump_mongo_sidecar: archive is ${size}B, below the ${min}B floor -- refusing to ship it" >&2
        rm -f db-dump/mongo.archive.tmp; return 1; }
    mv -f db-dump/mongo.archive.tmp db-dump/mongo.archive
}

# dump_sqlite_tree <path> [outdir]  ->  <outdir>/<path relative to <path>> for each
# *.db / *.sqlite3 / *.sqlite. outdir defaults to db-dump/; pass it when one compose
# project owns several services that would otherwise share an output dir (see
# media-stack). Discovers rather than hardcodes: filenames vary by image version.
#
# The dump MIRRORS each database's path under <path> instead of flattening it to a
# basename. Flattening had two failure modes, both silent:
#   - Two databases with the same name under one service collapsed into one file,
#     last writer wins. bazarr (config/bazarr.db + config/db/bazarr.db) and babybuddy
#     (config/db.sqlite3 + config/data/db.sqlite3) were each losing one database.
#   - A nested database restored to the wrong directory, because the restore side had
#     no path left to reconstruct. jellyfin (config/data/data/) and jellyseerr
#     (config/db/) both came back where nothing would read them.
# The restic exclude-file re-includes services/*/db-dump/** recursively, so the deeper
# subdirs this now creates back up unchanged -- no exclude-file edit needed.
dump_sqlite_tree() {
    local root="${1%/}" out="${2:-db-dump}" found=0 f rel
    mkdir -p "$out"
    while IFS= read -r -d '' f; do
        found=1; rel="${f#"$root"/}"
        mkdir -p "${out}/$(dirname "$rel")"
        # .backup takes a read lock and yields a consistent copy of a database that is
        # actively being written. A plain cp does not.
        if ! sqlite3 "$f" ".backup '${out}/${rel}.tmp'" 2>/dev/null; then
            echo "dump_sqlite_tree: .backup failed for $f" >&2
            rm -f "${out}/${rel}.tmp"; return 1; fi
        if [[ "$(sqlite3 "${out}/${rel}.tmp" 'PRAGMA integrity_check;' 2>/dev/null)" != "ok" ]]; then
            echo "dump_sqlite_tree: $f dumped but fails integrity_check" >&2
            rm -f "${out}/${rel}.tmp"; return 1; fi
        mv -f "${out}/${rel}.tmp" "${out}/${rel}"
    done < <(find "$root" -type f \( -name '*.db' -o -name '*.sqlite3' -o -name '*.sqlite' \) -print0)
    # An empty result means the paths moved under us — the service's data is then
    # silently absent from the snapshot. Fail rather than succeed emptily.
    [[ $found -eq 1 ]] || { echo "dump_sqlite_tree: no sqlite databases under $root" >&2; return 1; }
}

