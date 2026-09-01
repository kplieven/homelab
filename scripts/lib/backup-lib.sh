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

# dump_sqlite_tree <path> [outdir]  ->  <outdir>/<basename> for each *.db / *.sqlite3 / *.sqlite
# outdir defaults to db-dump/; pass it when one service owns several databases that would
# otherwise collide on basename (see media-stack). Discovers rather than hardcodes:
# filenames vary by image version.
dump_sqlite_tree() {
    local root="$1" out="${2:-db-dump}" found=0 f base
    mkdir -p "$out"
    while IFS= read -r -d '' f; do
        found=1; base=$(basename "$f")
        # .backup takes a read lock and yields a consistent copy of a database that is
        # actively being written. A plain cp does not.
        if ! sqlite3 "$f" ".backup '${out}/${base}.tmp'" 2>/dev/null; then
            echo "dump_sqlite_tree: .backup failed for $f" >&2
            rm -f "${out}/${base}.tmp"; return 1; fi
        if [[ "$(sqlite3 "${out}/${base}.tmp" 'PRAGMA integrity_check;' 2>/dev/null)" != "ok" ]]; then
            echo "dump_sqlite_tree: $f dumped but fails integrity_check" >&2
            rm -f "${out}/${base}.tmp"; return 1; fi
        mv -f "${out}/${base}.tmp" "${out}/${base}"
    done < <(find "$root" -type f \( -name '*.db' -o -name '*.sqlite3' -o -name '*.sqlite' \) -print0)
    # An empty result means the paths moved under us — the service's data is then
    # silently absent from the snapshot. Fail rather than succeed emptily.
    [[ $found -eq 1 ]] || { echo "dump_sqlite_tree: no sqlite databases under $root" >&2; return 1; }
}

