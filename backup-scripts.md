# Per-service `backup.sh` scripts

Copy each block into `HOMELAB_DIR/services/<name>/backup.sh` on the server.

**Count:** 15 scripts covering all 19 databases — `media-stack` is one folder holding
5 databases, so it gets a single script. The remaining service folders own no database
and get no `backup.sh` (their plain files are backed up as-is).

| Class | Scripts | Databases |
|---|---|---|
| Postgres | linkwarden, immich, affine, mealie, komodo | 5 |
| Paperless (exporter + Postgres) | paperless-ngx | 1 |
| Mongo | your-spotify | 1 |
| Vaultwarden (own subcommand) | vaultwarden | 1 |
| Embedded SQLite | home-assistant, uptime-kuma, filebrowser, babybuddy, calibre | 5 |
| media-stack (SQLite ×5) | media-stack | 5 |
| Embedded H2 (stop/copy) | stirling-pdf | 1 |
| **Total** | **15 scripts** | **19** |

Every script sources `scripts/lib/backup-lib.sh` and runs with its own folder as CWD, so
`docker compose` and the relative dump paths resolve correctly. No script contains a
secret — credentials come from `.env` / `docker-compose.env`.

> **Verify container/DB names before trusting these.** They vary by image version. In
> each service folder: `docker compose config --services`. The inline comments flag the
> ones known to differ across releases (immich especially). `chmod +x` and a verify loop
> are at the bottom.

> **`.db` does not mean SQLite.** Three formats hide behind that one extension here:
> SQLite, BoltDB (`filebrowser`), and H2 (`stirling-pdf`). `dump_sqlite_tree` discovers
> files *by extension* and hands whatever it finds to `sqlite3 .backup`, which fails on
> the others — while `**/*.db` in the exclude file drops them from the snapshot either
> way. That combination is silent data loss. Before adding any service, read the magic
> bytes:
>
> ```bash
> head -c 16 <file> | od -c | head -1
> ```
>
> `S q L i t e   f o r m a t   3` is SQLite. `H : 2 , b l o c k :` is H2. Anything else
> needs its own dump strategy and its own script, not `dump_sqlite_tree`.

---

## Postgres services

### `services/linkwarden/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# DATABASE_URL=postgresql://postgres:...@postgres:5432/postgres
# container, user, and db are all literally "postgres" — no env var needed.
dump_postgres postgres postgres postgres
```

### `services/immich/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
# Container is "database" in recent releases, "immich_postgres" in older ones.
# Confirm with: docker compose config --services
dump_postgres database "${DB_USERNAME}" "${DB_DATABASE_NAME}"
```

### `services/affine/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
dump_postgres postgres "${DB_USERNAME}" "${DB_DATABASE}"
```

### `services/mealie/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
dump_postgres postgres "${POSTGRES_USER}" "${POSTGRES_DB}"
```

### `services/komodo/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

set -a; . ./.env; set +a
# db name is literally "postgres"; only the user comes from .env.
dump_postgres postgres "${KOMODO_DB_USERNAME}" postgres
```

---

## Paperless-ngx (exporter + Postgres)

### `services/paperless-ngx/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# --delete makes the export a mirror, not a pile: documents deleted in Paperless are
# deleted from the export too. The exporter is the primary restore artefact.
docker compose exec -T webserver document_exporter ../export --delete

# Belt-and-braces: dump the DB too. POSTGRES_USER/DB are "paperless" in the compose file.
# Confirm the DB service name (default "db") with: docker compose config --services
dump_postgres db paperless paperless
```

---

## Mongo

### `services/your-spotify/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# No auth on this instance. If mongodump is missing from the image, use:
#   docker compose exec -T mongo sh -c 'mongodump --archive'
dump_mongo mongo
```

---

## Vaultwarden (its own `backup` subcommand)

### `services/vaultwarden/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
mkdir -p db-dump

# Vaultwarden's own consistent SQLite dump, written into ./data as db_<timestamp>.sqlite3.
docker compose exec -T vaultwarden /vaultwarden backup

# Move the fresh dump to a FIXED filename so restic dedupes across nights, verify it,
# and clean up the timestamped originals so they can't accumulate inside live data/.
newest=$(find ./data -maxdepth 1 -name 'db_2*.sqlite3' -newermt '-5 minutes' | sort | tail -n1)
[[ -n "$newest" ]] || { echo "vaultwarden backup produced no dump" >&2; exit 1; }
sqlite3 "$newest" 'PRAGMA integrity_check;' | grep -qx ok
mv -f "$newest" db-dump/db-snapshot.sqlite3
find ./data -maxdepth 1 -name 'db_2*.sqlite3' -delete
```

The RSA session-signing keys, `attachments/`, `sends/` and `config.json` in `data/` are
plain files — backed up by the folder snapshot, not this script. Do not exclude them.

If your image lacks the `backup` subcommand, replace the body with `dump_sqlite_tree ./data`.

---

## Embedded-SQLite services

`dump_sqlite_tree` **discovers** `*.db` / `*.sqlite3` / `*.sqlite` under the given path
(recursively) and dumps each with `sqlite3 .backup`, so you don't hardcode filenames
that change between image versions.

### `services/home-assistant/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
dump_sqlite_tree ./config
```

### `services/uptime-kuma/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
dump_sqlite_tree ./data
```

### `services/filebrowser/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
# filebrowser.db sits at the service root, so the search root is "."
dump_sqlite_tree .
```

### `services/babybuddy/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
dump_sqlite_tree ./config
```

### `services/books-stack/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
# calibre-web's own app database only. The Calibre LIBRARY is bulk data on /mnt/ssd
# and out of scope.
dump_sqlite_tree ./calibre-web/config
```

---

## media-stack (one script, one `db-dump/<svc>/` per service)

### `services/media-stack/backup.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"

# One compose folder, several services, each with its own config dir and database(s).
# Sonarr/Radarr/Prowlarr each ship a logs.db beside their main *.db, so a single shared
# db-dump/ would let those basenames collide — last writer wins, silently. Pass each
# service its own output dir (2nd arg to dump_sqlite_tree) so nothing overwrites anything
# else. The exclude-file re-includes services/*/db-dump/** recursively, so the per-service
# subdirs back up unchanged — no exclude-file edit needed.
for svc in sonarr radarr prowlarr bazarr jellyfin audiobookshelf; do
    [[ -d "./$svc/config" ]] || continue
    dump_sqlite_tree "./$svc/config" "db-dump/$svc"
done
```

`dump_sqlite_tree`'s second argument is the output directory (default `db-dump/`); giving
each service its own makes a basename collision structurally impossible. If you already
ran the earlier single-directory version, clear its output once before re-running:

```bash
rm -rf services/media-stack/db-dump
```

Then confirm each service dumped into its own subdirectory:

```bash
find services/media-stack/db-dump -type f | sort
```

Expect `db-dump/sonarr/sonarr.db`, `db-dump/sonarr/logs.db`, `db-dump/radarr/radarr.db`,
`db-dump/radarr/logs.db`, … — the per-service prefix is what keeps the three `logs.db`
files (Sonarr, Radarr, and Prowlarr each ship one) from overwriting each other. The
library already ran `PRAGMA integrity_check` on every file before placing it.

The matching `services/media-stack/restore.sh` reads the same layout back — the output
dir becomes the source dir (second argument to `restore_sqlite_tree`). It is listed with
every other service's in **Per-service `restore.sh` scripts** at the end of this document.

---

## Embedded H2 (stirling-pdf)

Stirling-PDF embeds an **H2** database at `config/stirling-pdf-DB-<version>.mv.db`. It is
not SQLite — `sqlite3 .backup` cannot read it — and `**/*.db` in the exclude file matches
the filename, so without a script of its own the live database is dropped from every
snapshot and nothing replaces it.

H2 offers `BACKUP TO` / `SCRIPT TO`, but both need a JDBC connection into the container.
Stopping the service and copying the file is simpler and needs no tooling, at the cost of
a few seconds' downtime during the nightly run.

### `services/stirling-pdf/backup.sh`

```bash
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
```

H2's `.trace.db` (a log) and any `.lock.db` are correctly left behind: the glob requires
the `.mv.db` suffix, and restoring a stale lock file would block startup.

---

## Install and verify (on the server)

```bash
cd HOMELAB_DIR

# make them all executable
chmod +x services/{linkwarden,immich,affine,mealie,komodo,paperless-ngx,your-spotify,\
vaultwarden,home-assistant,uptime-kuma,filebrowser,babybuddy,calibre,media-stack,\
stirling-pdf}/backup.sh

# run each against the live containers and list what it produced
for s in linkwarden immich affine mealie komodo paperless-ngx your-spotify vaultwarden \
         home-assistant uptime-kuma filebrowser babybuddy calibre media-stack stirling-pdf; do
    echo "== $s"
    ( cd "services/$s" && ./backup.sh ) && ls "services/$s/db-dump/" 2>/dev/null
done

# every SQLite dump must pass integrity_check; every Postgres dump must be complete.
# -path '*/db-dump/*' -type f also reaches media-stack's per-service db-dump/<svc>/ files.
find services -path '*/db-dump/*' -type f | while IFS= read -r f; do
    case "$f" in
        *.sql)     grep -q 'PostgreSQL database dump complete' "$f" \
                       && echo "OK        $f" || echo "TRUNCATED $f" ;;
        *.archive) [[ -s "$f" ]] && echo "OK        $f" || echo "EMPTY     $f" ;;
        *.mv.db)   [[ -s "$f" ]] && echo "OK (H2)   $f" || echo "EMPTY     $f" ;;
        # Do NOT assume the rest are SQLite — a BoltDB or H2 file handed to sqlite3
        # returns noise, not a verdict. Check the magic bytes and say so out loud.
        *)         if head -c 15 "$f" | grep -q 'SQLite format 3'; then
                       printf '%-64s ' "$f"; sqlite3 "$f" 'PRAGMA integrity_check;'
                   else
                       echo "NOT-SQLITE $f — unrecognised format, verify it by hand"
                   fi ;;
    esac
done
```

Every line should read `OK` or `ok`. A dump that exists but is `TRUNCATED`/`EMPTY`/not
`ok` is the exact failure this design exists to catch — fix it before wiring the profile.

`NOT-SQLITE` means a file reached `db-dump/` that no branch above knows how to check —
either a new format needing its own verify, or a script that dumped the wrong thing.
Neither H2 nor BoltDB has an `integrity_check` equivalent, so both are verified only as
"non-empty"; the real test for those is the restore round-trip below.

A service that prints `no sqlite databases under ...` has its DB somewhere other than the
path assumed above; find it with `find services/<name> -name '*.db' -o -name '*.sqlite3'`
and correct that one script's search root.

---

# Per-service `restore.sh` scripts

Copy each block into `HOMELAB_DIR/services/<name>/restore.sh` — the mirror of the matching
`backup.sh`. Same rules: source `scripts/lib/restore-lib.sh`, run with the service folder as
CWD, no secrets (they come from `.env`). One pair per database-owning service; folders with
no database get neither script.

**Ordering differs by engine — get it wrong and you restore into the void or clobber live data:**

| Engine | Order | Why |
|---|---|---|
| Postgres / Mongo | container **up first** (fresh, empty), *then* `restore.sh` | the dump loads *into* a running, empty DB; `--clean --if-exists` / `--drop` handle a repopulate |
| SQLite | container **down first**, *then* `restore.sh` | the file is copied into place under the stopped service; `restore_sqlite_tree` refuses a live file unless `FORCE=1` |
| H2 (stirling-pdf) | run `restore.sh` directly — it stops and restarts the service itself | H2 keeps the `.mv.db` open and mmap'd; overwriting it under a live process corrupts both the file and the process's view |
| paperless-ngx | empty instance up, *then* `restore.sh` (importer) | `document_importer` duplicates or errors against a populated instance |
| vaultwarden | container **down**, folder snapshot restored, *then* `restore.sh` | the db must land beside the RSA keys the folder snapshot carries |

`restore_postgres` / `restore_mongo` have **no** `FORCE` guard — they replay a `--clean` /
`--drop` dump and are meant to run against a freshly-started empty DB. `restore_sqlite_tree`
**does** guard: it refuses to overwrite an existing live db unless you pass `FORCE=1`.

`scripts/restore-all.sh` (in the repo) loops `services/*/restore.sh` in the same way the
`run-before` hook loops the backups. `chmod +x` and a check are at the bottom.

---

## Postgres services

### `services/linkwarden/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# reads db-dump/postgres.sql -> psql -U postgres -d postgres (--set ON_ERROR_STOP=on)
restore_postgres postgres postgres postgres
```

### `services/immich/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
# Container is "database" in recent releases, "immich_postgres" in older ones — must match
# the name backup.sh used. Confirm with: docker compose config --services
restore_postgres database "${DB_USERNAME}" "${DB_DATABASE_NAME}"
```

### `services/affine/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
restore_postgres postgres "${DB_USERNAME}" "${DB_DATABASE}"
```

### `services/mealie/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
restore_postgres postgres "${POSTGRES_USER}" "${POSTGRES_DB}"
```

### `services/komodo/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

set -a; . ./.env; set +a
restore_postgres postgres "${KOMODO_DB_USERNAME}" postgres
```

---

## Paperless-ngx (exporter is primary; Postgres dump is fallback)

### `services/paperless-ngx/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# The exporter output (../export) is the primary restore artefact. document_importer expects
# an EMPTY instance: start with a fresh (empty) database volume and the stack up, then import.
# Importing into a populated instance duplicates or errors.
docker compose run --rm webserver document_importer ../export

# The Postgres dump is belt-and-braces. Use it INSTEAD of the importer above (never both) to
# replay the raw dump straight into a fresh empty DB:
#   restore_postgres db paperless paperless
```

---

## Mongo

### `services/your-spotify/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# reads db-dump/mongo.archive -> mongorestore --archive --drop
restore_mongo mongo
```

---

## Vaultwarden (its live SQLite db is the one excluded file)

### `services/vaultwarden/restore.sh`

```bash
#!/bin/bash
set -euo pipefail

# data/ — the RSA session-signing keys, attachments/, sends/, config.json — is restored by
# the folder snapshot itself. This puts back only the one file that was excluded and dumped:
# the live SQLite db. Restoring the db WITHOUT those keys logs every client out.
# Stop vaultwarden before running; FORCE=1 to overwrite an existing data/db.sqlite3.
src=db-dump/db-snapshot.sqlite3
dest=./data/db.sqlite3

[[ -f "$src" ]] || { echo "restore: no $src (did backup.sh run?)" >&2; exit 1; }
sqlite3 "$src" 'PRAGMA integrity_check;' | grep -qx ok \
    || { echo "restore: $src fails integrity_check" >&2; exit 1; }
if [[ -e "$dest" && "${FORCE:-0}" != "1" ]]; then
    echo "restore: $dest exists; stop vaultwarden and re-run with FORCE=1" >&2; exit 1
fi
mkdir -p ./data
cp -a "$src" "$dest"
# If vaultwarden runs as a non-root uid, chown "$dest" to it before `docker compose up -d`.
```

If your `backup.sh` used the `dump_sqlite_tree ./data` fallback (image without the `backup`
subcommand) instead of the subcommand above, restore with `restore_sqlite_tree ./data`.

---

## Embedded-SQLite services

Each is the exact mirror of its `backup.sh`: same search root, restored back into place.
The service must be **stopped** first; `FORCE=1` overwrites a db that is still present.

### `services/home-assistant/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
restore_sqlite_tree ./config
```

### `services/uptime-kuma/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
restore_sqlite_tree ./data
```

### `services/filebrowser/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
# restores db-dump/filebrowser.db -> ./filebrowser.db (search root was ".")
restore_sqlite_tree .
```

### `services/babybuddy/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
restore_sqlite_tree ./config
```

### `services/books-stack/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
restore_sqlite_tree ./calibre-web/config
```

---

## media-stack (one script, per-service `db-dump/<svc>/`)

### `services/media-stack/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"

# Mirror of backup.sh: each service's dumps live in db-dump/<svc>/ and restore into
# ./<svc>/config. The per-service dir is the source-dir (2nd) argument. Stop the media
# containers first; re-run with FORCE=1 to overwrite a live database.
for svc in sonarr radarr prowlarr bazarr jellyfin audiobookshelf; do
    [[ -d "db-dump/$svc" ]] || continue
    restore_sqlite_tree "./$svc/config" "db-dump/$svc"
done
```

---

## Embedded H2 (stirling-pdf)

### `services/stirling-pdf/restore.sh`

```bash
#!/bin/bash
set -euo pipefail
# Mirror of backup.sh. H2's .mv.db is a plain file, so the restore is a copy back — but
# only into a stopped service, which this script handles itself. No restore-lib.sh:
# restore_sqlite_tree would copy the file into place without stopping the container.

shopt -s nullglob
dumps=(db-dump/stirling-pdf-DB-*.mv.db)

[[ ${#dumps[@]} -gt 0 ]] || { echo "restore: no db-dump/stirling-pdf-DB-*.mv.db" >&2; exit 1; }
# More than one means an upgrade left a stale version behind, and it is ambiguous which
# the current image wants. Fail rather than guess.
[[ ${#dumps[@]} -eq 1 ]] || {
    echo "restore: ${#dumps[@]} dumps present, expected 1 — remove stale versions:" >&2
    printf '  %s\n' "${dumps[@]}" >&2; exit 1; }

src="${dumps[0]}"; base=$(basename "$src")

if [[ -e "config/${base}" && "${FORCE:-0}" != "1" ]]; then
    echo "restore: config/${base} exists; re-run with FORCE=1 to overwrite" >&2
    exit 1
fi

docker compose stop
trap 'docker compose start' EXIT      # container comes back even if the copy fails
mkdir -p config
cp -a "$src" "config/${base}"
trap - EXIT
docker compose start
```

The `FORCE` guard never fires on a real disaster restore: `config/` comes back from the
snapshot *without* the `.mv.db` (it was excluded), so the target path is empty and the
copy proceeds. It exists for the other case — running a restore against a live service.

Worth rehearsing this pair before trusting it, since neither has an `integrity_check`
equivalent to fall back on:

```bash
cd HOMELAB_DIR/services/stirling-pdf
./backup.sh && ls -l db-dump/
mv config/stirling-pdf-DB-*.mv.db /tmp/     # simulate the loss
./restore.sh && docker compose ps           # expect it back, container Up
```

---

## Install and verify (on the server)

```bash
cd HOMELAB_DIR

# make them all executable
chmod +x services/{linkwarden,immich,affine,mealie,komodo,paperless-ngx,your-spotify,\
vaultwarden,home-assistant,uptime-kuma,filebrowser,babybuddy,calibre,media-stack,\
stirling-pdf}/restore.sh

# syntax-check every restore.sh without running it
for s in linkwarden immich affine mealie komodo paperless-ngx your-spotify vaultwarden \
         home-assistant uptime-kuma filebrowser babybuddy calibre media-stack stirling-pdf; do
    bash -n "services/$s/restore.sh" && echo "OK  services/$s/restore.sh"
done
```

Do **not** loop-run these the way you test the backups: a restore mutates a live service.
Rehearse one at a time following the ordering table above (or the whole-server drill in
[docs/backup/migrate-homeserver.md](docs/backup/migrate-homeserver.md)), never against a
running container you care about.
