#!/bin/bash
set -euo pipefail
mountpoint -q /local/backup/path || { echo "/local/backup/path is not mounted; refusing to run" >&2; exit 1; }

