#!/bin/bash
# Shared restore helpers. Sourced by services/*/restore.sh with CWD = service dir.

# restore_postgres <container> <user> <db>
restore_postgres() {
    local container="$1" user="$2" db="$3"
    [[ -f "db-dump/${db}.sql" ]] || { echo "restore_postgres: no db-dump/${db}.sql" >&2; return 1; }
    # ON_ERROR_STOP: without it psql reports success after replaying a broken dump
    # halfway, which is exactly the outcome this design exists to avoid.
    docker compose exec -T "$container" \
        psql -U "$user" -d "$db" --set ON_ERROR_STOP=on < "db-dump/${db}.sql"
}

# restore_mongo <container>
restore_mongo() {
    local container="$1"
    [[ -f db-dump/mongo.archive ]] || { echo "restore_mongo: no db-dump/mongo.archive" >&2; return 1; }
    docker compose exec -T "$container" mongorestore --archive --drop < db-dump/mongo.archive
}

# restore_sqlite_tree <path> [srcdir]   (FORCE=1 to overwrite a live db)
# srcdir defaults to db-dump/; pass the matching per-service dir written by dump_sqlite_tree.
restore_sqlite_tree() {
    local root="$1" src="${2:-db-dump}" found=0 f base
    [[ -d "$src" ]] || { echo "restore_sqlite_tree: no $src/" >&2; return 1; }
    for f in "$src"/*; do
        [[ -f "$f" ]] || continue
        base=$(basename "$f")
        case "$base" in *.sql|*.archive) continue ;; esac
        found=1
        if [[ -e "${root}/${base}" && "${FORCE:-0}" != "1" ]]; then
            echo "restore_sqlite_tree: ${root}/${base} exists; stop the service and re-run with FORCE=1" >&2
            return 1; fi
        mkdir -p "$root"; cp -a "$f" "${root}/${base}"
    done
    [[ $found -eq 1 ]] || { echo "restore_sqlite_tree: no sqlite dumps in $src/" >&2; return 1; }
}

