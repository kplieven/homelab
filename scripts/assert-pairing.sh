#!/bin/bash
set -euo pipefail
EXCLUDES="${1:-/etc/restic/homelab-excludes.txt}"
ROOT="$(dirname "$(readlink -f "$0")")/.."
fail=0
# Path-scoped rules: the service is named in the rule itself.
while read -r line; do
    case "$line" in ''|'#'*|'!'*|'**'*) continue ;; esac
    svc=$(echo "$line" | sed -n 's#.*/services/\([^/]*\)/.*#\1#p')
    [[ -n "$svc" ]] || continue
    [[ -d "$ROOT/services/$svc" ]] || continue
    if [[ ! -x "$ROOT/services/$svc/backup.sh" ]]; then
        echo "UNPAIRED: $line is excluded but services/$svc has no executable backup.sh" >&2
        fail=1; fi
done < "$EXCLUDES"

# Wildcard rules (**/*.db and friends) name no service, so the loop above cannot
# check them -- yet they are what actually excludes most live databases. Resolve
# them against the tree instead: any live database a wildcard rule matches must sit
# in a service that has a backup.sh, or it is excluded with no dump behind it.
# Only database patterns are checked; noise rules (*.log, *.tmp) need no dump. The
# -wal/-shm variants are derivatives of a .db that is itself checked below.
while read -r line; do
    case "$line" in
        '**/*.db'|'**/*.sqlite'|'**/*.sqlite3') ;;
        *) continue ;;
    esac
    while IFS= read -r hit; do
        [[ "$hit" == */db-dump/* ]] && continue
        svc=$(echo "$hit" | sed -n 's#^\./services/\([^/]*\)/.*#\1#p')
        [[ -n "$svc" ]] || continue
        if [[ ! -x "$ROOT/services/$svc/backup.sh" ]]; then
            echo "UNPAIRED: $hit matches '$line' but services/$svc has no executable backup.sh" >&2
            fail=1; fi
    done < <(cd "$ROOT" && find ./services -name "${line##*/}" 2>/dev/null)
done < "$EXCLUDES"

[[ $fail -eq 0 ]] || { echo "assert-pairing: refusing to back up with unpaired exclusions" >&2; exit 1; }
echo "assert-pairing: all exclusions paired"

