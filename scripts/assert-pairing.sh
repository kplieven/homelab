#!/bin/bash
set -euo pipefail
EXCLUDES="${1:-/etc/restic/homelab-excludes.txt}"
ROOT="$(dirname "$(readlink -f "$0")")/.."
fail=0
while read -r line; do
    case "$line" in ''|'#'*|'!'*|'**'*) continue ;; esac
    svc=$(echo "$line" | sed -n 's#.*/services/\([^/]*\)/.*#\1#p')
    [[ -n "$svc" ]] || continue
    [[ -d "$ROOT/services/$svc" ]] || continue
    if [[ ! -x "$ROOT/services/$svc/backup.sh" ]]; then
        echo "UNPAIRED: $line is excluded but services/$svc has no executable backup.sh" >&2
        fail=1; fi
done < "$EXCLUDES"
[[ $fail -eq 0 ]] || { echo "assert-pairing: refusing to back up with unpaired exclusions" >&2; exit 1; }
echo "assert-pairing: all exclusions paired"

