#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
# wg-easy 15 keeps the server private key and every peer config in config/wg-easy.db
# (real SQLite), which **/*.db excludes. Without this dump the snapshot restores a
# WireGuard server with no identity and no peers.
dump_sqlite_tree ./config
