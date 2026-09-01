#!/bin/bash
# /usr/local/sbin/restic-drill.sh -- mode 0700, owned by root (it embeds REST_PASS).
# Wired to a systemd timer every 90 days; see the unit at the bottom of this file.
#
# The quarterly restore drill (README 5.3). It restores from the REMOTE, not the local
# repo, because that is the only thing that exercises the tunnel, the remote data and the
# path you would actually use on the worst day of your year.
#
# `restic check` proves a repository is internally consistent -- which an immaculate
# repository full of empty archives also manages. This proves the data is USABLE.
#
# Every assertion below is fatal under `set -e`, so the healthcheck ping on the last line
# is reached only if all of them passed. Silence is the alarm: HC_DRILL has a 90-day
# period and 100-day grace, so a drill that fails, or never runs at all, goes red.
set -euo pipefail
RESTIC=/usr/local/bin/restic          # absolute: the timer's PATH lacks /usr/local/bin
REPO="rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo"
PASS=/etc/restic/repo.pass
TMP=$(mktemp -d -p /dev/shm restic-drill.XXXXXX)   # tmpfs: plaintext vault never hits disk
trap 'rm -rf "$TMP"' EXIT

# Every db-dump in the snapshot.
"$RESTIC" -r "$REPO" --password-file "$PASS" \
    restore latest --tag homelab --include '*/db-dump/*' --target "$TMP"

db=$(find "$TMP" -name db-snapshot.sqlite3 | head -1)
[[ -n "$db" ]] || { echo "no vaultwarden database in snapshot" >&2; exit 1; }
sqlite3 "file:$db?immutable=1" 'PRAGMA integrity_check;' | grep -qx ok

# Every sqlite dump passes integrity_check. Identify SQLite by its magic bytes, never
# by extension: stirling-pdf writes an H2 database named *.mv.db, which a *.db glob
# happily matches and sqlite3 rejects with "file is not a database", while
# audiobookshelf writes *.sqlite, which a *.db/*.sqlite3 glob misses entirely. Both are
# the same mistake -- inferring a format from a filename -- and the second is the
# dangerous one, because it fails silently. Walk every dumped file and let the format
# identify itself.
sqlite_n=0
while IFS= read -r -d '' f; do
    # tr -d before the substitution: bash cannot hold NUL bytes in a variable and warns
    # "null byte in input ignored" for every binary file otherwise. SQLite's first 15
    # bytes contain no NUL, so stripping them keeps the test exact and silences the noise.
    [[ "$(head -c 15 "$f" 2>/dev/null | tr -d '\000')" == "SQLite format 3" ]] || continue
    # immutable=1: open read-only without needing to create a -shm/journal beside the
    # file. Verification must never write to the evidence it is verifying, and as a plain
    # read-write open this fails outright on a dump whose directory is not writable.
    [[ "$(sqlite3 "file:$f?immutable=1" 'PRAGMA integrity_check;')" == "ok" ]] \
        || { echo "$f fails integrity_check" >&2; exit 1; }
    sqlite_n=$((sqlite_n+1))
done < <(find "$TMP" -path '*/db-dump/*' -type f -print0)

# Every postgres dump ran to completion. A truncated dump replays halfway.
pg_n=0
while IFS= read -r -d '' f; do
    grep -q 'PostgreSQL database dump complete' "$f" || { echo "$f is truncated" >&2; exit 1; }
    pg_n=$((pg_n+1))
done < <(find "$TMP" -path '*/db-dump/*' -name '*.sql' -print0)

# A loop that iterates zero times passes. If the restore brought nothing back, or an
# include pattern quietly stopped matching, every check above succeeds by vacuum and the
# drill reports green having verified nothing -- the exact failure this drill exists to
# catch. Assert it actually looked at something.
(( sqlite_n > 0 )) || { echo "no sqlite dumps found to check; drill verified nothing" >&2; exit 1; }
(( pg_n > 0 ))     || { echo "no postgres dumps found to check; drill verified nothing" >&2; exit 1; }
echo "drill: $sqlite_n sqlite + $pg_n postgres dumps verified"

# Paperless still has a real document count. The `select` matters: manifest.json is a
# Django fixture dump -- one array holding tags, correspondents, users and saved views
# alongside documents -- so a bare `jq length` sails past the threshold even if every
# document vanished. Tune 100 to a little below the real count.
"$RESTIC" -r "$REPO" --password-file "$PASS" \
    restore latest --tag homelab --include '*/export/manifest.json' --target "$TMP"
manifest=$(find "$TMP" -name manifest.json | head -1)
[[ -n "$manifest" ]] || { echo "no paperless manifest in snapshot" >&2; exit 1; }
count=$(jq '[.[] | select(.model == "documents.document")] | length' "$manifest")
[[ "$count" -gt 100 ]] || { echo "manifest has only $count documents; suspicious" >&2; exit 1; }

curl -fsS -m 10 --retry 3 HC_URL/ping/HC_DRILL

# ---------------------------------------------------------------------------
# systemd parses NO inline comments: a trailing `# ...` is read as part of the value,
# so `OnCalendar=... # quarterly` fails with "Failed to parse calendar specification"
# and the timer loads as bad-setting. Every comment below is on its own line.
#
# /etc/systemd/system/restic-drill.service
#   [Unit]
#   Description=Quarterly restic restore drill (from the remote)
#   After=network-online.target restic-tunnel.service
#   Wants=network-online.target
#
#   [Service]
#   Type=oneshot
#   ExecStart=/usr/local/sbin/restic-drill.sh
#
# /etc/systemd/system/restic-drill.timer
#   [Unit]
#   Description=Run the restic restore drill every 90 days
#
#   [Timer]
#   # Quarterly, clear of the 01:30 backup, 02:30 copy and 03:00 check.
#   OnCalendar=*-01,04,07,10-01 05:00:00
#   # A host that was down at the trigger still drills on next boot.
#   Persistent=true
#   RandomizedDelaySec=1h
#
#   [Install]
#   WantedBy=timers.target
#
# Verify before enabling -- both must be clean:
#   systemd-analyze verify /etc/systemd/system/restic-drill.{service,timer}
#   systemd-analyze calendar '*-01,04,07,10-01 05:00:00'
# ---------------------------------------------------------------------------
