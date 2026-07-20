#!/bin/bash
set -euo pipefail
ROOT="$(dirname "$(readlink -f "$0")")/.."
for script in "$ROOT"/services/*/restore.sh; do
    [[ -x "$script" ]] || continue
    svc=$(basename "$(dirname "$script")")
    echo "==> restoring $svc"
    ( cd "$(dirname "$script")" && ./restore.sh ) || { echo "restore-all: $svc/restore.sh failed" >&2; exit 1; }
done
echo "restore-all: complete"

