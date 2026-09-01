# Homelab backup & recovery

Off-site, encrypted, append-only backups for the whole homelab, built on
[restic](https://restic.net/) and
[resticprofile](https://creativeprojects.github.io/resticprofile/).

One restic profile snapshots `HOMELAB_DIR` — every service's compose file, `.env`,
config and state — dumping all 19 databases first so nothing is copied while it is
being written. A hardware change becomes: restore the snapshot, `docker compose up -d`,
done.

This replaces three shell/Python scripts (`current-tool/`) that tarred two services
nightly, pruned old archives by filename date, and `rclone sync`ed the result to
Proton Drive.

## The document set

| Document | When you read it |
|---|---|
| **This file** | First-time setup, day-to-day restores, maintenance. |
| [`migrate-homeserver.md`](migrate-homeserver.md) | Moving the home server to new hardware. |
| [`migrate-vps.md`](migrate-vps.md) | Moving the off-site copy to a different VPS. |
| [`migrate-vps-location.md`](migrate-vps-location.md) | Moving the repository to a new path on the same VPS. |
| `specs/`, `plans/` | The design and its implementation history. Provenance, not runbook. |

---

## What changed and why

| Old | New | Reason |
|---|---|---|
| `tar -czf` nightly full archive | restic snapshot of the directory | Gzip defeats deduplication. Every night re-uploaded the whole archive; now only changed chunks move. |
| `backup_retention.py` (92 lines) | `restic forget --keep-*` | The old policy only kept files whose *filename date* landed on Jan 1, the 1st, or a Monday. A backup missed on Jan 1 meant no yearly backup for that year, permanently. restic keeps the newest snapshot *within* each period. |
| `rclone sync` to Proton Drive | `restic copy` to a VPS | `sync` mirrors deletions. An unmounted `/mnt/ssd` would have emptied the remote. `copy` only ever adds. |
| Two services (paperless, vaultwarden) | The whole `HOMELAB_DIR` | A hardware move only counts as "done" if *everything* comes back, not two things. |
| No failure handling | resticprofile hooks + systemd | A dead container made `document_exporter` fail, but the script had no `set -e`, so `tar` archived the *previous* export under tonight's date and uploaded it. resticprofile skips the backup when a pre-hook fails. |
| No monitoring | Self-hosted Healthchecks | Nothing told you when backups stopped. |
| No restore test | Quarterly automated, annual manual | A repository can pass every integrity check and still contain nothing useful. |

## Architecture

```
  home server (trusted, holds the key)          VPS (semi-hostile, holds ciphertext)
  ┌───────────────────────────────┐             ┌──────────────────────────────────┐
  │ 21 services under HOMELAB_DIR  │             │                                  │
  │   dump DBs ─► restic backup    │             │  rest-server --append-only       │
  │                     │          │             │    127.0.0.1:8000                │
  │                     ▼          │  ssh -L     │         │                        │
  │        /mnt/ssd/restic  ───────┼────tunnel───┼────► /srv/restic/repo            │
  │        (local repo)            │             │      (append-only mirror)        │
  │        pruned weekly           │             │      never pruned on a schedule  │
  └───────────────────────────────┘             │  healthchecks (behind Caddy)     │
                                                 └──────────────────────────────────┘
```

Two properties do the work here:

**The VPS never learns the repository password.** restic encrypts before anything
leaves the home server. Someone with root on the VPS gets encrypted chunks.

**The home server cannot delete history.** rest-server runs with `--append-only`,
so it refuses every delete. Ransomware that owns the home server can write new
snapshots. It cannot remove the old ones.

Neither machine can both read the backups and destroy them. That is the point of
the whole arrangement, and the rest of this document exists to keep it true.

### The part that is easy to get wrong

Append-only is worthless if the SSH key carrying the tunnel can also open a shell
on the VPS. An attacker walks the key, gets a shell, deletes `/srv/restic/repo`
directly, and never touches rest-server at all.

The tunnel key must therefore be able to do exactly one thing: forward to one port.
See [1.3](#13-restricted-ssh-key-for-the-tunnel). It is not your admin key and must
never become your admin key.

## The invariant this design rests on

> Every service's state lives under `HOMELAB_DIR/services/<name>/`. Everything worth
> backing up is there; everything bulky is reached by an absolute path pointing
> somewhere else (`/mnt/ssd`).

This is true of the homelab repo today. It had one exception, since fixed in
[1.6](#16-prepare-the-homelab-repo): `wg-easy` kept the WireGuard server key and peer
configs in a named Docker volume, where nothing under `services/` could see them.
The bulk media on `/mnt/ssd` (photos, movies, shows) is explicitly **out of scope**;
this design covers service configuration and state only.

## Facts to fill in

Substitute these throughout. Everything below uses the placeholder names.

| Placeholder | Meaning | Example |
|---|---|---|
| `HOMELAB_DIR` | the homelab git repo's path on the home server | `/srv/homelab` |
| `VPS_HOST` | VPS hostname or IP | `vps.example.net` |
| `HC_URL` | Healthchecks base URL | `https://hc.example.net` |
| `HC_HOMELAB` etc. | per-check UUIDs from Healthchecks | `1c0a4f...` |
| `REST_USER` / `REST_PASS` | rest-server htpasswd credentials | |

The local repository lives at `/mnt/ssd/restic`, on a physically separate disk from
the live service data. The remote lives at `/srv/restic/repo` on the VPS.

## Verify before you trust this

These procedures were written and then partly run against real hardware. The
transport (1.3, 1.4) and the restic install (1.5) have been executed and corrected
against what actually happened. The following were **not** confirmable without the
live homelab tree and must be checked as you go — each is flagged again at its step:

- `exclude-file` pattern anchoring — whether restic anchors a leading `/` to the
  snapshot root or the filesystem root ([1.8](#18-the-exclude-file), Step 3). A
  silently non-matching exclude is the worst failure here: the backup keeps
  succeeding while copying a live database.
- resticprofile config schema, which changed between v1 and v2 (`resticprofile version`).
  The YAML in [1.9](#19-resticprofile-configuration) is v1.
- resticprofile's `$ERROR_STDERR` hook variable.
- the direction of `restic copy` (`--from-repo` names the *source*) — confirmed to
  still exist on `copy` and `init` in 0.19.1; confirm which end your `copy:` profile
  block names.
- the unit names `resticprofile schedule` generates, which have changed across releases.
- the `vaultwarden backup` subcommand and its output filename (older images lack it).
- container/DB service names per service (`database` vs `immich_postgres`, `db` vs
  `postgres`) — verified per service with `docker compose config --services`, not guessed.
- **`assert-pairing.sh` and the global SQLite patterns — RESOLVED.** It used to skip
  every `**` line, leaving the pairing rule unenforced for any service whose database is
  a bare `*.db`/`*.sqlite3` file rather than a `database/` directory. It now resolves
  those patterns against the live tree as well
  ([1.7](#the-orchestrator-and-the-pairing-assertion)). The first run caught two
  genuinely unpaired services: `wg-easy`, whose WireGuard server key and peer list were
  in no snapshot at all, and `adguard-home`. Neither had been noticed by eye in the
  months they were wrong — which is the whole argument for asserting mechanically.
- **`dump_mongo` has no content check.** `dump_postgres` greps for the terminator and
  `dump_sqlite_tree` runs `integrity_check`; `dump_mongo` only tests non-empty, so a
  truncated archive passes. Find a validity check for `mongodump --archive` output
  (`mongorestore --dry-run` against the archive is the candidate) and add it.

> **The lesson from the transport steps, which cost six defects:** the failure mode
> here is not an error message, it is a green check. A `-L` forward hangs identically
> whether it is permitted or refused. `curl -sf` reports a correct `401` as a failure.
> `permitopen` cannot grant a permission `restrict` has taken away. A non-matching
> exclude backs up a live database and passes `restic check`. Treat every "it seems
> fine" in this document as a claim to be driven with real traffic, not observed at rest.

---

# 1. Setup

Work through these in order. Steps 1.1 through 1.12 are safe to run while the old
cron scripts keep working; nothing is deleted until 1.13, and 1.13 does not happen
until the drill in [3.4](#34-disaster-the-home-server-is-gone) has succeeded.

## 1.1 Generate the two keys

Do this first, on a machine you trust, and write both down before continuing.

```bash
# Daily key: long, random, machine-readable. Never typed by a human. Goes in a
# file, so base64 is fine here.
openssl rand -base64 48

# Emergency key: six diceware words. Typed by a human, once, on the worst day of
# your year. Any diceware wordlist works. Example using the EFF long list:
shuf -n 6 eff_large_wordlist.txt | cut -f2 | paste -sd' '
```

The daily key goes into `/etc/restic/repo.pass` on the home server and into
Vaultwarden for convenience. The emergency key goes on paper and nowhere else.
[Section 4](#4-recovery-sheet) covers what else belongs on that paper.

Why two keys: a restic repository accepts several passwords, any of which unlocks
it. Storing the only key inside the password manager you are backing up is circular.
When Vaultwarden is the thing you need to restore, the key to restore it is inside
the thing you cannot open.

## 1.2 VPS: rest-server

Install as an unprivileged user with its own home.

```bash
sudo useradd --system --home-dir /srv/restic --create-home --shell /usr/sbin/nologin restic

# Fetch the binary matching your architecture from
# https://github.com/restic/rest-server/releases — do NOT apt-install it.
sudo install -m 0755 rest-server /usr/local/bin/rest-server

sudo -u restic mkdir -p /srv/restic/repo
sudo chmod 0700 /srv/restic
```

Create the htpasswd file. Generate `REST_PASS` as **hex**, not base64:

```bash
openssl rand -hex 32          # this is REST_PASS
```

`REST_PASS` ends up inside URLs (`rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo`).
base64 output contains `+`, `/` and `=`, which a URL parser reads as path separators
and other structure, so a base64 password breaks the URL roughly nine times in ten.
Hex is `[0-9a-f]` and always URL-safe. Name `REST_USER` after the **client**
(e.g. `homeserver`), not after you — it is a machine identity.

```bash
sudo apt install apache2-utils
sudo -u restic htpasswd -B -c /srv/restic/.htpasswd REST_USER
# paste the hex REST_PASS at the prompt
```

Loopback binding keeps the internet out; htpasswd keeps out other processes on a box
that runs other things. (When you *rotate* this later, drop the `-c` — with `-c`,
htpasswd truncates the file and recreates it, wiping any other entries.)

`/etc/systemd/system/rest-server.service`:

```ini
[Unit]
Description=restic REST server (append-only)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=restic
Group=restic
ExecStart=/usr/local/bin/rest-server \
    --path /srv/restic \
    --listen 127.0.0.1:8000 \
    --append-only \
    --htpasswd-file /srv/restic/.htpasswd
Restart=always
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/srv/restic

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rest-server
ss -lntp | grep 8000     # expect 127.0.0.1:8000, not 0.0.0.0:8000
```

If it is listening on `0.0.0.0`, stop and fix it. A publicly reachable rest-server
protected only by basic auth is not what this design assumes.

Create `rest-server-maintenance.service` now, while you are calm — a copy of the
above with `--append-only` removed and the `[Install]` section omitted (so it can
never be enabled by accident). It exists only for the rare pruning window in
[5.2](#52-pruning-the-remote); building it during an emergency is how the append-only
guard gets left off.

## 1.3 Restricted SSH key for the tunnel

On the **home server**, as root. `/etc/restic` does not exist yet — 1.5 fills the
rest of it, but the key needs it now:

```bash
sudo mkdir -p /etc/restic
sudo chmod 0700 /etc/restic

sudo ssh-keygen -t ed25519 -N '' -f /etc/restic/tunnel_ed25519 -C restic-tunnel@homeserver
sudo cat /etc/restic/tunnel_ed25519.pub
```

The key lands as `root:root`, mode `0600`. Every command touching it from here on needs
`sudo`, including the verification below — the tunnel unit in 1.4 runs as root for the
same reason.

On the **VPS**, the `restic` user has `nologin` as its shell, so add a dedicated
tunnel user:

```bash
sudo useradd --create-home --shell /bin/sh restic-tunnel
sudo -u restic-tunnel mkdir -p ~restic-tunnel/.ssh
sudo -u restic-tunnel chmod 700 ~restic-tunnel/.ssh
```

`~restic-tunnel/.ssh/authorized_keys`, all on one line:

```
restrict,port-forwarding,permitopen="127.0.0.1:8000",command="/usr/bin/false" ssh-ed25519 AAAA... restic-tunnel@homeserver
```

Read that left to right, which is how sshd parses it. `restrict` disables everything:
agent forwarding, X11, PTY allocation, port forwarding. `port-forwarding` then restores
*only* forwarding. `permitopen` narrows it to one destination. `command` forces
`/usr/bin/false` regardless of what the client asks to run.

`port-forwarding` is not optional and its position matters. `permitopen` **constrains** a
permission; it cannot **grant** one. Without `port-forwarding`, `restrict` leaves
forwarding off and every channel is refused — including the one you need — with
`administratively prohibited`. Placed *before* `restrict`, it gets clobbered.

### Confirm the restriction actually holds

Three checks, and all three must hold together. Note the `sudo`: the key is root-owned.

```bash
# 1. MUST print nothing. command="/usr/bin/false" runs instead of `id`.
sudo ssh -i /etc/restic/tunnel_ed25519 restic-tunnel@VPS_HOST 'id'
```

If this prints a user id, the key is not restricted, and append-only is protecting
nothing. Fix it before going further.

Checks 2 and 3 each need two terminals. A `-L` forward is **lazy**: ssh binds the local
listener immediately but does not ask the VPS to open the channel until something
connects to that local port. An unused forward therefore sits there looking identical
whether it is permitted or refused. You have to drive traffic through it or you are
testing nothing.

```bash
# 2. MUST be refused. Terminal A:
sudo ssh -v -i /etc/restic/tunnel_ed25519 -N -L 9999:127.0.0.1:22 restic-tunnel@VPS_HOST
# Terminal B:
curl -sv --max-time 5 http://127.0.0.1:9999/ 2>&1 | head -3
```

Terminal A must print `channel N: open failed: administratively prohibited`. This is the
check that matters most: `permitopen` is the only thing between this key and port 22 on
your VPS. If the channel opens, stop.

```bash
# 3. MUST succeed. Terminal A:
sudo ssh -v -i /etc/restic/tunnel_ed25519 -N -L 8000:127.0.0.1:8000 restic-tunnel@VPS_HOST
# Terminal B:
curl -si --max-time 5 http://127.0.0.1:8000/ | head -1
```

Terminal B must print `HTTP/1.1 401 Unauthorized`. That one line proves the whole chain:
channel permitted, rest-server alive, htpasswd enforced. `Connection refused` means
rest-server is not listening; a hang means the channel never opened.

Ctrl-C both when done — 1.4's unit is what runs the real tunnel.

## 1.4 Home server: tunnel unit

`/etc/systemd/system/restic-tunnel.service`:

```ini
[Unit]
Description=SSH tunnel to restic rest-server on VPS_HOST
After=network-online.target
Wants=network-online.target

[Service]
User=root
ExecStart=/usr/bin/ssh -N \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=yes \
    -i /etc/restic/tunnel_ed25519 \
    -L 127.0.0.1:8000:127.0.0.1:8000 \
    restic-tunnel@VPS_HOST
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Substitute `VPS_HOST` in the unit before installing it. It is the one placeholder that
has to survive into a file rather than a command line, and systemd will not warn you —
`ssh` simply fails to resolve the literal string, `Restart=always` loops it every ten
seconds, and the only symptom is a port nobody is listening on.

The tunnel unit runs as root and reads `/root/.ssh/known_hosts`, which
`StrictHostKeyChecking=yes` then enforces. If you have already `sudo ssh`'d to the VPS
by hand, the host key is there and you can skip the keyscan:

```bash
sudo grep -c 'VPS_HOST' /root/.ssh/known_hosts    # non-zero: skip the next block
```

Otherwise add it — but verify rather than trust. `ssh-keyscan` asks the server for its
key and believes whatever answers, so a scan performed through a hostile network
records the impostor and `StrictHostKeyChecking=yes` faithfully enforces your trust in
the wrong host:

```bash
sudo ssh-keyscan VPS_HOST 2>/dev/null | ssh-keygen -lf -
```

Compare the ED25519 fingerprint against the provider's console before continuing. Then:

```bash
sudo ssh-keyscan VPS_HOST | sudo tee -a /root/.ssh/known_hosts
sudo systemctl daemon-reload
sudo systemctl enable --now restic-tunnel

curl -si --max-time 5 http://127.0.0.1:8000/ | head -1    # expect: HTTP/1.1 401 Unauthorized
```

`401` is the pass: tunnel bound, channel permitted, rest-server answering, htpasswd
enforced. Do **not** use `curl -sf` here — `-f` returns exit 22 on any status at or
above 400, so it reports that correct `401` as a failure. Other exit codes worth
recognising: **7** means nothing is listening locally, so the unit is not running
(check `systemctl status restic-tunnel` and the journal); **52** or **56** mean the
listener is up but the channel is failing, which points back at `permitopen` rather
than the unit.

Once the repository exists (1.5), this is the stronger check, since it exercises the
credentials rather than just the transport:

```bash
curl -si --max-time 5 http://REST_USER:REST_PASS@127.0.0.1:8000/repo/config | head -1
```

Before `restic init` it returns `404` — which still confirms auth succeeded, since bad
credentials return `401`.

`ExitOnForwardFailure=yes` matters. Without it, ssh stays up with a dead forward and
restic hangs instead of failing.

## 1.5 Home server: restic, resticprofile, repositories

**Install restic from the upstream binary, not from apt.** Debian stable ships restic
0.14, years behind; the `init --from-repo` / `copy` behaviour this design depends on is
newer. Fetch the release matching your architecture from
<https://github.com/restic/restic/releases> — it ships bzip2-compressed:

```bash
# adjust version/arch to the release you downloaded
bunzip2 restic_*_linux_amd64.bz2
sudo install -m 0755 restic_*_linux_amd64 /usr/local/bin/restic
/usr/local/bin/restic version        # expect 0.18+ ; this design was written against 0.19.x

sudo apt install sqlite3 jq curl     # sqlite3 verifies dumps; jq drives the quarterly drill
# resticprofile: https://creativeprojects.github.io/resticprofile/installation/
curl -sfL https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh \
    | sudo sh -s -- -b /usr/local/bin
```

> **`sudo` and `/usr/local/bin`.** On a hardened box `secure_path` in `/etc/sudoers`
> may be `/usr/sbin:/usr/bin:/sbin:/bin` — deliberately *excluding* `/usr/local/*`,
> because `/usr/local/bin` is often group-writable (`root:staff`, mode `2775`) and a
> writable directory on root's PATH is a privilege-escalation vector. **Do not "fix"
> this by widening `secure_path`.** Instead call restic by absolute path under sudo:
> `sudo /usr/local/bin/restic ...`. Every `sudo restic` in this document means
> `sudo /usr/local/bin/restic`. resticprofile is told the absolute path explicitly in
> [1.9](#19-resticprofile-configuration) (`restic-binary:`), so its scheduled runs are
> unaffected; only your interactive `sudo` commands need the full path.
>
> If `sqlite3` will not install because the box mixes Debian suites, install it from
> the suite that actually has it, e.g. `sudo apt install -t sid sqlite3`. Do **not**
> apt-install restic to work around a dependency knot — you would get 0.14.

Lay down the daily key:

```bash
sudo mkdir -p /etc/restic
printf '%s' 'THE_DAILY_KEY_FROM_STEP_1.1' | sudo tee /etc/restic/repo.pass > /dev/null
sudo chmod 0400 /etc/restic/repo.pass
sudo chown root:root /etc/restic/repo.pass
```

Initialise the local repository, then the remote **from** the local one:

```bash
sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass init

sudo /usr/local/bin/restic -r "rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo" \
    --password-file /etc/restic/repo.pass \
    init \
    --from-repo /mnt/ssd/restic \
    --from-password-file /etc/restic/repo.pass \
    --copy-chunker-params
```

Two things that bite here:

- **Flag order.** `--from-repo`, `--from-password-file` and `--copy-chunker-params`
  belong to the `init` subcommand, so they come **after** `init`. `-r` and
  `--password-file` are global and come before. Put a `--from-*` flag before `init` and
  restic rejects it as `unknown flag`.
- **`--copy-chunker-params` is not optional.** Without it the two repositories chunk
  data differently, `restic copy` re-uploads everything from scratch, and deduplication
  between them never happens. There is no fix later short of recreating the remote. (The
  tunnel from 1.4 must be up for this second command to reach the remote.)

## 1.6 Prepare the homelab repo

Two changes to the homelab repo itself, both prerequisites for the design. Commit them
in the repo (they are code, not server config).

**wg-easy: named volume → bind mount.** Until this lands, WireGuard's server private
key and every peer config live in `/var/lib/docker/volumes/` and no folder-level backup
can see them. A hardware move would mean re-enrolling every VPN peer by hand.

```bash
cd HOMELAB_DIR/services/wg-easy
docker compose exec -T wg-easy ls -la /etc/wireguard      # note the files; you will compare
docker compose stop
mkdir -p config
docker run --rm -v wg-easy_etc_wireguard:/from -v "$PWD/config":/to alpine sh -c 'cp -a /from/. /to/'
```

Edit `docker-compose.yml`: delete the top-level `volumes:` block (`etc_wireguard:`), and
change the service mount from `etc_wireguard:/etc/wireguard` to `./config:/etc/wireguard`.
Then:

```bash
docker compose up -d && sleep 5
docker compose exec -T wg-easy wg show      # your existing peers must be listed
```

If peers are missing, **stop** — revert the compose file; the named volume is still
intact. Only once `wg show` is correct:

```bash
git add docker-compose.yml && git commit -m "fix(wg-easy): bind-mount wireguard state so backups can see it"
docker volume rm wg-easy_etc_wireguard
```

**Track the backup scripts.** The repo's `.gitignore` currently ignores `**/backup.sh`.
Under this design `backup.sh`/`restore.sh` hold **no secrets** (credentials come from
`.env`), and they must be tracked — otherwise the scripts exist only inside the backup
you are trying to restore *with*. Remove the `**/backup.sh` / `!**/backup.sh.example`
lines from `.gitignore`. Confirm `.env` stays ignored:

```bash
cd HOMELAB_DIR
git check-ignore -q services/immich/.env && echo ".env still ignored (good)"
git check-ignore -q services/linkwarden/docker-compose.env && echo "docker-compose.env still ignored (good)"
```

## 1.7 The dump layer

restic cannot make a database quiescent; that is the one job it cannot do for you. A
live Postgres directory or SQLite file copied byte-by-byte gives a torn snapshot that
`restic check` certifies as perfectly healthy. So every service that owns a database
gets a `backup.sh` that **dumps** it, the raw DB path is **excluded** ([1.8](#18-the-exclude-file)),
and an orchestrator runs all the dumps before restic starts — failing the whole run if
any dump fails.

### The pairing rule — the sharpest edge in the design

> **Every excluded raw-database path must have a `backup.sh` behind it that dumps it.
> An unpaired exclusion is silent, total data loss for that service.**

Exclude a `database/` directory but forget to dump it, and the backup succeeds, the
healthcheck stays green, `restic check` passes, and the data is simply gone — invisible
until the day you restore. So exclusions are named **explicitly, never by wildcard**
(a wildcard silently sweeps up a future service's DB dir that has no dump), and the
pairing is asserted **mechanically**, never by eye ([1.7 orchestrator](#the-orchestrator-and-the-pairing-assertion)).

Some databases genuinely cannot be dumped. An embedded engine with no online-dump API —
bbolt, H2 — yields a consistent copy only with the service stopped, and stopping it can
cost more than the data is worth: `adguard-home` keeps query statistics in bbolt, and
dumping them nightly means taking LAN-wide DNS down nightly. For those, the exclusion is
waived **per file**, in `services/<name>/no-db-dump`, naming the exact paths and the
reason. A waiver is deliberately not a per-service off switch — a database that appears
in that service later still fails the assertion — and every waiver prints on every run,
so it stays a decision on the record instead of becoming a silence.

### The shared library

All dump logic lives in one place so 19 services cannot become 19 subtly divergent
copies of the same `.tmp`-and-`mv` dance. `scripts/lib/backup-lib.sh`:

```bash
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
```

`scripts/lib/restore-lib.sh` mirrors it. It refuses to overwrite live data unless
`FORCE=1`, because the common operator error is running a restore against a running
service:

```bash
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
```

These are the only components with real unit tests. `scripts/lib/test-backup-lib.sh`
(in the repo) asserts against temp databases that a dump is created, readable, passes
`integrity_check`, skips `-wal`/`-shm`, survives a corrupt source without destroying the
previous good dump, leaves no `.tmp` residue, and round-trips through restore. Run it
after any change to the library: `./scripts/lib/test-backup-lib.sh` and `shellcheck
scripts/lib/*.sh`.

### One backup.sh / restore.sh per database-owning service

Each is a three-line declaration of which engine it owns. `services/home-assistant/backup.sh`:

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
dump_sqlite_tree ./config
```

`services/home-assistant/restore.sh`:

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/restore-lib.sh"
restore_sqlite_tree ./config
```

The full set — build one pair per row, and **verify the container/DB names with
`docker compose config --services` before running**, since they vary by image version:

| Service | `backup.sh` body (after sourcing the lib) | Notes |
|---|---|---|
| linkwarden | `dump_postgres postgres postgres postgres` | user and db both literally `postgres` |
| immich | `set -a; . ./.env; set +a` then `dump_postgres database "$DB_USERNAME" "$DB_DATABASE_NAME"` | container is `database` (older: `immich_postgres`) |
| affine | `set -a; . ./.env; set +a` then `dump_postgres postgres "$DB_USERNAME" "$DB_DATABASE"` | |
| mealie | `set -a; . ./.env; set +a` then `dump_postgres postgres "$POSTGRES_USER" "$POSTGRES_DB"` | |
| komodo | `set -a; . ./.env; set +a` then `dump_postgres postgres "$KOMODO_DB_USERNAME" postgres --exclude-table-data='cron.job_run_details'` | db literally `postgres`; the exclusion is not optional — see [5.4](#54-when-things-go-wrong) |
| paperless-ngx | `document_exporter ../export --delete` then `dump_postgres db paperless paperless` | see below |
| your-spotify | `dump_mongo mongo` | no auth |
| vaultwarden | special — `/vaultwarden backup`, see below | |
| home-assistant | `dump_sqlite_tree ./config` | |
| uptime-kuma | `dump_sqlite_tree ./data` | |
| filebrowser | special — BoltDB, not SQLite: `docker compose stop`, `cp -a filebrowser.db db-dump/`, restart from a `trap` | `sqlite3 .backup` cannot read a Bolt file and there is no online dump; a brief stop is the only consistent copy |
| babybuddy | `dump_sqlite_tree ./config` | |
| calibre | `dump_sqlite_tree ./calibre-web/config` | the Calibre *library* is on `/mnt/ssd`, out of scope |
| media-stack | loop `sonarr radarr prowlarr bazarr jellyfin audiobookshelf`, `dump_sqlite_tree ./$svc/config db-dump/$svc` | per-service `db-dump/<svc>/`; the `*arr` `logs.db` files would otherwise collide |
| wg-easy | `dump_sqlite_tree ./config` | wg-easy 15 keeps the server private key and every peer in `config/wg-easy.db`; `wg0.conf` beside it is plain text and rides along in the snapshot |
| stirling-pdf | special — embedded H2 (`config/stirling-pdf-DB-*.mv.db`), same stop/copy as filebrowser | the version is in the filename, so stale copies are cleared first: `db-dump/` must hold exactly one or `restore.sh` cannot tell which the image wants |
| adguard-home | **none** — waived in `services/adguard-home/no-db-dump` | `stats.db` and `sessions.db` are bbolt; all real config is `config/AdGuardHome.yaml`, snapshotted as a plain file. A restore loses statistics history and logged-in sessions, nothing else |

`restore.sh` mirrors each with the `restore_*` counterpart. Services with **no**
database get neither script; their plain files are backed up as-is. A service whose
database is waived gets neither script either, but it does need the `no-db-dump` file —
that is what separates "decided against" from "forgotten".

**paperless-ngx** uses its first-class exporter as the primary artefact; the Postgres
dump is belt-and-braces. `backup.sh`:

```bash
#!/bin/bash
set -euo pipefail
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib/backup-lib.sh"
# --delete makes the export a mirror rather than a pile: documents deleted in
# Paperless are deleted from the export too.
docker compose exec -T webserver document_exporter ../export --delete
dump_postgres db paperless paperless
```

`restore.sh` runs `document_importer ../export` (which expects an empty instance — see
[3.3](#33-a-whole-service-into-an-already-running-homelab)).

**vaultwarden** dumps via its own subcommand to a fixed filename so restic dedupes, and
cleans up the timestamped originals so they cannot accumulate inside the live data dir.
`backup.sh`:

```bash
#!/bin/bash
set -euo pipefail
mkdir -p db-dump
docker compose exec -T vaultwarden /vaultwarden backup
newest=$(find ./data -maxdepth 1 -name 'db_2*.sqlite3' -newermt '-5 minutes' | sort | tail -n1)
[[ -n "$newest" ]] || { echo "vaultwarden backup produced no dump" >&2; exit 1; }
sqlite3 "$newest" 'PRAGMA integrity_check;' | grep -qx ok
mv -f "$newest" db-dump/db-snapshot.sqlite3
find ./data -maxdepth 1 -name 'db_2*.sqlite3' -delete
```

Its `data/` also holds the RSA keys that sign session tokens and the `attachments`/
`sends`/`config.json` — all plain files, all backed up, none excluded. If your image
lacks the `backup` subcommand, fall back to `dump_sqlite_tree ./data`.

### The orchestrator and the pairing assertion

`scripts/assert-pairing.sh` (in the repo) reads the exclude file and fails if any
excluded database lacks an executable `backup.sh`. It makes two passes, because the
exclude file states the same rule two different ways: path-scoped lines name their
service directly, while the global `**/*.db` patterns name none and must be resolved
against the live tree to find out what they actually hide:

```bash
#!/bin/bash
set -euo pipefail
EXCLUDES="${1:-/etc/restic/homelab-excludes.txt}"
ROOT="$(dirname "$(readlink -f "$0")")/.."
fail=0

# A service may declare an individual database regenerable in services/<svc>/no-db-dump:
# one path per line, relative to the service dir, '#' comments allowed. Only the paths
# listed are waived, so a database appearing in that service LATER still fails the
# assertion -- this is a per-file waiver, not a per-service off switch. Every waiver is
# echoed on every run, because the failure this whole script exists to prevent is a
# quiet green check and a silent waiver would be exactly that.
waived() {   # waived <service> <path relative to the service dir>
    local svc="$1" rel="$2" marker="$ROOT/services/$svc/no-db-dump"
    [[ -f "$marker" ]] || return 1
    sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$marker" | grep -qxF "$rel" || return 1
    echo "assert-pairing: waived services/$svc/$rel (declared regenerable in no-db-dump)"
}

# Path-scoped rules: the service is named in the rule itself.
while read -r line; do
    case "$line" in ''|'#'*|'!'*|'**'*) continue ;; esac
    svc=$(echo "$line" | sed -n 's#.*/services/\([^/]*\)/.*#\1#p')
    [[ -n "$svc" ]] || continue
    [[ -d "$ROOT/services/$svc" ]] || continue
    if waived "$svc" "${line#*/services/$svc/}"; then continue; fi
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
        if waived "$svc" "${hit#./services/$svc/}"; then continue; fi
        if [[ ! -x "$ROOT/services/$svc/backup.sh" ]]; then
            echo "UNPAIRED: $hit matches '$line' but services/$svc has no executable backup.sh" >&2
            fail=1; fi
    done < <(cd "$ROOT" && find ./services -name "${line##*/}" 2>/dev/null)
done < "$EXCLUDES"

[[ $fail -eq 0 ]] || { echo "assert-pairing: refusing to back up with unpaired exclusions" >&2; exit 1; }
echo "assert-pairing: all exclusions paired"
```

The wildcard pass runs as root from the `run-before` hook, which matters: several
service data directories are `drwx------ root`, so the same `find` run as your own user
traverses none of them and reports everything as fine.

`/usr/local/sbin/homelab-dump.sh` — the `run-before` hook. It *runs* from a system path
so that the root-executed entry point sits outside the repo's write surface, but its
source is **tracked** at `docs/backup/server/homelab-dump.sh` and installed from there.
Those are separate questions: where a file executes from, and whether a reviewed copy
has history. It holds no secrets, so it gets both:

```bash
#!/bin/bash
# resticprofile run-before hook. Any failure aborts the backup — the point: a skipped
# backup with a red healthcheck beats a green backup of a stale or torn dump.
set -euo pipefail
HOMELAB_DIR=HOMELAB_DIR

"$HOMELAB_DIR/scripts/assert-pairing.sh" /etc/restic/homelab-excludes.txt

for script in "$HOMELAB_DIR"/services/*/backup.sh; do
    [[ -x "$script" ]] || continue
    dir=$(dirname "$script")
    svc=$(basename "$dir")

    # A service disabled with .disabled -- the repo-wide marker honoured by
    # update-and-run-containers.sh -- has no container left to dump from, so its
    # backup.sh fails and takes down every service after it in this loop with it. Skip
    # it. Its raw DB path stays excluded either way, so the snapshot then carries
    # whatever is already in db-dump/ and nothing else: the two checks below are what
    # make that safe rather than merely quiet.
    if [[ -f "$dir/.disabled" ]]; then
        # Still running means the marker is lying. The database can still be written, so
        # freezing the dump would let it go stale invisibly. Same probe as
        # update-and-run-containers.sh, so both agree on what "running" means.
        running=$(cd "$dir" && docker compose ps --services --filter "status=running" 2>/dev/null || true)
        [[ -z "$running" ]] || {
            echo "homelab-dump: $svc is marked .disabled but still running ($(echo "$running" | tr "\n" " " | sed "s/ *$//")); refusing to freeze its dump" >&2
            exit 1; }
        # Nothing in db-dump/ means it was disabled before it was ever dumped: its
        # database is excluded with no dump behind it. That is the unpaired exclusion
        # the pairing rule exists to prevent, reached from the other direction --
        # assert-pairing.sh sees the backup.sh and is satisfied, but it never runs.
        newest=$(find "$dir/db-dump" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null | sort -r | head -n1)
        [[ -n "$newest" ]] || {
            echo "homelab-dump: $svc is disabled but has no dump in db-dump/; its database is excluded with nothing behind it" >&2
            exit 1; }
        reason=$(tr '\n' ' ' < "$dir/.disabled" | sed 's/[[:space:]]*$//')
        echo "homelab-dump: $svc disabled${reason:+ ($reason)}, keeping its dump from $newest"
        continue
    fi

    ( cd "$dir" && ./backup.sh ) || { echo "homelab-dump: $svc/backup.sh failed" >&2; exit 1; }
done
echo "homelab-dump: all dumps complete"
```

### Disabled services

A service disabled with the repo's `.disabled` marker (see the top-level README) has no
container left to dump from. Its `backup.sh` fails, and because the orchestrator aborts
on the first failure, **every service after it alphabetically never gets dumped either** —
one disabled service silently costs you the whole night's backup. So the loop skips
disabled services.

Skipping is not free, though. The raw database path stays excluded whether the service
runs or not, so the snapshot keeps carrying whatever is already in `db-dump/` and nothing
else. That is correct — a stopped database is not changing, so its last dump is still
current — but only while two things hold, which is why the skip is guarded rather than
unconditional:

| Guard | What it catches |
|---|---|
| stack must actually be stopped | Marked `.disabled` but still running, usually a manual `docker compose up`. The database can still be written, so a frozen dump goes stale invisibly. |
| `db-dump/` must be non-empty | Disabled before it was ever dumped. Its database is excluded with no dump behind it — the unpaired-exclusion loss, reached from the direction `assert-pairing.sh` cannot see: the `backup.sh` exists, so the assertion is satisfied, but it never runs. |

Both refuse the backup rather than proceeding. The skip line prints the reason from the
marker file and the date of the dump being carried forward, so a service disabled for a
year does not quietly become a year-old dump nobody looked at.

Install it and confirm the assertion catches an unpaired exclusion. Use a throwaway
directory, **not** a real service: the check is `[[ ! -x services/<svc>/backup.sh ]]`, so
naming a real service makes the test's outcome depend on whether that service has been
implemented yet — it passes once that service's `backup.sh` exists, which looks like the
assertion is broken when it is working correctly.

```bash
sudo install -m 0755 docs/backup/server/homelab-dump.sh /usr/local/sbin/homelab-dump.sh
mkdir -p HOMELAB_DIR/services/zz-pairing-probe
printf 'HOMELAB_DIR/services/zz-pairing-probe/database\n' > /tmp/fake-excludes.txt
HOMELAB_DIR/scripts/assert-pairing.sh /tmp/fake-excludes.txt; echo "exit: $?"   # expect UNPAIRED, exit 1
rmdir HOMELAB_DIR/services/zz-pairing-probe
```

A directory with no `backup.sh` by construction, so this reads the same at any stage of
the build. If a *real* service unexpectedly reports `UNPAIRED`, check the exec bit with
`ls -l` before suspecting the script — the test is `-x`, not `-e`.

**Formerly a blind spot.** The first loop skips lines beginning `**` because they name
no service, which once left the global SQLite patterns in [1.8](#18-the-exclude-file)
with no pairing check at all — a database that is a bare `*.db` file rather than a
`database/` directory was excluded by those patterns and invisible to the assertion. The
second loop closes that by resolving the patterns against the tree. The remaining
uncovered case is narrower and named: a service that has a `backup.sh` which never
actually produces a dump. The assertion tests for the script, not for its output; the
disabled-service check above tests for the output, but only for disabled services.

`restic-guard.sh` refuses to run at all if the repo disk is unmounted — otherwise a
backup after an unmounted `/mnt/ssd` writes an empty snapshot and retention eventually
forgets the real ones. `/usr/local/sbin/restic-guard.sh`:

```bash
#!/bin/bash
set -euo pipefail
mountpoint -q /mnt/ssd || { echo "/mnt/ssd is not mounted; refusing to run" >&2; exit 1; }
```

```bash
sudo install -m 0755 docs/backup/server/restic-guard.sh /usr/local/sbin/restic-guard.sh
sudo chmod 0755 /usr/local/sbin/{restic-guard,homelab-dump}.sh
```

`scripts/restore-all.sh` is the mirror of the orchestrator, and lives in the **repo**
so it arrives with the snapshot on restore day:

```bash
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
```

Commit the tracked scripts (`scripts/`, `services/*/backup.sh`, `services/*/restore.sh`,
`.gitignore`).

For the server-side files, the question is **not** "is it server config" — that decides
where a file *runs*, not whether a reviewed copy has history. The only criterion that
forces the answer is whether it holds a secret:

| File | Secret? | Tracked |
|---|---|---|
| `/etc/restic/profiles.yaml` | **Yes** — `REST_PASS`, mode `0600` | Never. Track `profiles.yaml.example` with the password as a placeholder |
| `/usr/local/sbin/restic-drill.sh` | **Yes** — embeds `REST_PASS`, mode `0700` | Never |
| `/etc/restic/homelab-excludes.txt` | No | Yes |
| `/usr/local/sbin/homelab-dump.sh` | No | Yes |
| `/usr/local/sbin/restic-guard.sh` | No | Yes |

The tracked copies live under `docs/backup/server/`, mirroring what is installed on the
box, and every install step reads from there:

```
docs/backup/server/homelab-dump.sh
docs/backup/server/restic-guard.sh
docs/backup/server/homelab-excludes.txt
docs/backup/server/profiles.yaml.example
```

`docs/backup/server/` rather than `scripts/` keeps the semantics honest — these are
server config under review, not repo tooling. `restic-guard.sh` hardcodes `/mnt/ssd` and
is not portable; it should not sit somewhere that implies it is.

Two payoffs. The repo is the backup source, so tracked means these come back with the
restore instead of being rebuilt by hand ([migrate-homeserver.md](migrate-homeserver.md)).
And the `.example` gives you history on the *structure* of `profiles.yaml` — profile
names, schedules, hook wiring, retention — which is the part that changes and the part
you would want to diff after a bad edit. Only the two secret-bearing files stay
untracked, and both are regenerable: `REST_PASS` is thirty seconds of `htpasswd`.

## 1.8 The exclude file

**Must be built and verified on the server.** Pattern anchoring is the one unverified
item that can lose data silently. `/etc/restic/homelab-excludes.txt`, with the real
`HOMELAB_DIR` substituted throughout:

```gitignore
# Raw database dirs — REPLACED by dumps in each service's db-dump/. Named explicitly,
# never by wildcard: a wildcard would silently sweep up a future service's DB dir that
# has no dump behind it (the pairing rule).
HOMELAB_DIR/services/linkwarden/pgdata
HOMELAB_DIR/services/immich/postgres
HOMELAB_DIR/services/affine/postgres
HOMELAB_DIR/services/mealie/database
HOMELAB_DIR/services/komodo/db
HOMELAB_DIR/services/paperless-ngx/database
HOMELAB_DIR/services/your-spotify/database

# Live SQLite files — replaced by .backup output in db-dump/. -wal/-shm are meaningless
# without their db and harmful to restore beside a dump.
**/*.sqlite3
**/*.sqlite
**/*.db
**/*.db-wal
**/*.db-shm
**/*.sqlite3-wal
**/*.sqlite3-shm

# Re-include the dumps. MUST come after the SQLite patterns above, or **/*.db excludes
# the very dumps those rules exist to make room for.
!HOMELAB_DIR/services/*/db-dump/**

# Regenerable caches and indexes.
HOMELAB_DIR/services/immich/model-cache
HOMELAB_DIR/services/linkwarden/meili_data
HOMELAB_DIR/services/*/cache
HOMELAB_DIR/services/media-stack/*/metadata

# Noise.
**/logs/
**/*.log
**/tmp/
**/*.sock

# Half-written dumps. MUST come after the db-dump re-inclusion above, or that `!` line
# pulls them back in. A stranded .tmp means its dump died before the mv; backing it up
# ships a truncated file that looks like a dump on restore day.
**/*.tmp
```

`caddy/data` is **deliberately absent** — it holds issued TLS certificates, and a
rebuild day is the worst time to discover you are re-issuing 20 of them into Let's
Encrypt's rate limits. The SQLite-backed services have no entry in the raw-DB block on
purpose: their databases are files, not directories, and are handled by the SQLite
patterns further down — which is also why the pairing assertion cannot see them.

Install it, then verify all three ways — none of these is optional, because each guards
a different silent failure:

```bash
sudo install -m 0644 homelab-excludes.txt /etc/restic/homelab-excludes.txt
DR="sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass backup --dry-run -vv HOMELAB_DIR --exclude-file /etc/restic/homelab-excludes.txt"

# Step 3 — raw DB dirs are EXCLUDED. Expect NO output. Any line is a live database
# about to be backed up raw. If lines appear, the anchoring is wrong; try **/pgdata forms.
$DR 2>&1 | grep -E 'pgdata|postgres/|/database/' | head

# Step 4 — the dumps ARE included. Do NOT pipe through `head`: restic emits a line per
# dump file AND a line per db-dump/ directory, so 10 lines of `head` is ~5 services and
# looks like mass exclusion when nothing is wrong. Count instead, and compare against
# the dumps actually on disk.
find HOMELAB_DIR/services/*/db-dump -type f ! -name '*.tmp' | wc -l   # what should be there
$DR 2>&1 | grep -c 'db-dump'                                          # files + dir entries; strictly greater

# Then read the list. Every dump on disk must appear; a *.tmp appearing means step 6.
$DR 2>&1 | grep 'db-dump'

# Empty output means the `!` re-inclusion failed and every dump is excluded — a backup
# of no databases at all. A short-but-nonempty list is the dangerous case: the .sql
# dumps match no exclude pattern, so they show up whether or not the `!` line works.
# Confirm at least one *.db or *.sqlite3 dump is listed — those are the ones that prove
# the re-inclusion actually fired.
$DR 2>&1 | grep 'db-dump' | grep -E '\.db$|\.sqlite3?$' | head -3

# Step 6 — no half-written dumps. Expect NO output. A .tmp on disk means that dump died
# before its mv and the service has no valid dump at all.
find HOMELAB_DIR/services/*/db-dump -name '*.tmp'

# Step 5 — bulk media is NOT swept in. Expect NO output.
$DR 2>&1 | grep -iE '/mnt/ssd|Foto' | head
```

Record what the anchoring actually did in the verify list at the top of this file, so
the next reader inherits the answer rather than the question.

## 1.9 resticprofile configuration

`/etc/restic/profiles.yaml`, mode `0600` (it contains `REST_PASS`):

```yaml
version: "1"

global:
  restic-binary: /usr/local/bin/restic   # secure_path may exclude /usr/local; be explicit
  priority: low
  ionice: true
  ionice-class: 2
  ionice-level: 7
  restic-stale-lock-age: 2h

default:
  repository: "/mnt/ssd/restic"
  password-file: /etc/restic/repo.pass
  initialize: false

homelab:
  inherit: default
  backup:
    schedule: "*-*-* 01:30:00"
    schedule-permission: system
    schedule-lock-wait: 15m
    run-before:
      - /usr/local/sbin/restic-guard.sh
      - /usr/local/sbin/homelab-dump.sh
    source:
      - HOMELAB_DIR
    exclude-file: /etc/restic/homelab-excludes.txt
    tag:
      - homelab
    exclude-caches: true
    one-file-system: true      # never cross onto /mnt/ssd even if an .env points there
    run-after:
      - 'curl -fsS -m 10 --retry 3 HC_URL/ping/HC_HOMELAB'
    run-after-fail:
      - 'curl -fsS -m 10 --retry 3 --data-raw "$ERROR_STDERR" HC_URL/ping/HC_HOMELAB/fail'
  retention:
    after-backup: true
    prune: false
    tag: true
    host: true
    path: true
    keep-last: 3
    keep-daily: 7
    keep-weekly: 4
    keep-monthly: 12
    keep-yearly: 3

# Copies every snapshot not yet present on the VPS. New sources/tags are picked up
# automatically; there is nothing to add here when you back up a new service.
offsite:
  inherit: default
  copy:
    schedule: "*-*-* 02:30:00"
    schedule-permission: system
    initialize: false
    repository: "rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo"
    password-file: /etc/restic/repo.pass
    run-after:
      - 'curl -fsS -m 10 --retry 3 HC_URL/ping/HC_OFFSITE'
    run-after-fail:
      - 'curl -fsS -m 10 --retry 3 --data-raw "$ERROR_STDERR" HC_URL/ping/HC_OFFSITE/fail'

maintenance:
  inherit: default
  check:
    schedule: "Sun *-*-* 03:00:00"
    schedule-permission: system
    read-data-subset: "1/7"
    run-after:
      - 'curl -fsS -m 10 --retry 3 HC_URL/ping/HC_CHECK'
    run-after-fail:
      - 'curl -fsS -m 10 --retry 3 --data-raw "$ERROR_STDERR" HC_URL/ping/HC_CHECK/fail'
  prune:
    schedule: "Sun *-*-* 04:00:00"
    schedule-permission: system
```

Choices that are not obvious:

`retention.prune: false` runs `forget` nightly (unlinks snapshots, a second) and
`prune` weekly (repacks the repo, minutes). Keeping them apart keeps the nightly job
cheap. `read-data-subset: "1/7"` re-reads and rehashes one seventh of stored chunks each
Sunday, so everything is verified over seven weeks without a long weekly stall. The
`offsite` copy is a separate unit from the backup, so a broken tunnel turns one
healthcheck red and leaves the nightly backup untouched.

First run it by hand, then schedule and find out what resticprofile actually named the
timers — the scheme changes between releases, so read it rather than assume:

```bash
sudo resticprofile -c /etc/restic/profiles.yaml -n homelab backup --dry-run -v   # sanity
sudo resticprofile -c /etc/restic/profiles.yaml -n homelab backup                # real
sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass \
    ls latest --tag homelab | grep -c db-dump    # non-zero: dumps are in the snapshot
sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass \
    ls latest --tag homelab | grep -E 'pgdata|/database/' | head   # empty: no raw DB dirs

sudo resticprofile -c /etc/restic/profiles.yaml schedule --all
systemctl list-timers 'resticprofile*'
systemctl list-units 'resticprofile*.service'
```

The copy job needs the tunnel up before it starts. Add a drop-in against whatever the
`offsite` copy service turned out to be called:

```bash
sudo systemctl edit <the-offsite-copy-service>.service
```

```ini
[Unit]
Requires=restic-tunnel.service
After=restic-tunnel.service
```

`Requires=` starts the tunnel if it is not running; `After=` waits for it. Without the
drop-in, a copy scheduled soon after boot races the tunnel and fails on connection
refused. Finally, confirm the whole run finishes before `offsite` starts at 02:30 — one
profile now does the work of two plus 19 dumps. If it overruns, move `offsite` later.

## 1.10 Healthchecks

Create five checks. Grace periods matter more than people expect: too tight and a slow
night wakes you, too loose and a dead backup sits unnoticed for a month.

| Check | Period | Grace |
|---|---|---|
| `HC_HOMELAB` | 1 day | 26 h |
| `HC_OFFSITE` | 1 day | 26 h |
| `HC_CHECK` | 1 week | 8 d |
| `HC_DISK` | 1 day | 3 d |
| `HC_DRILL` | 90 days | 100 d |

Configure SMTP in Healthchecks and send yourself a test alert **before** you depend on
it. A dead man's switch wired to an inbox nobody reads is the same as no monitoring.

Add `HC_DISK` on the **VPS**, because the remote repository is never pruned on a
schedule and grows forever:

```sh
# /etc/cron.daily/restic-disk-check on the VPS, mode 0755
#!/bin/sh
used=$(df --output=pcent /srv | tail -1 | tr -dc '0-9')
[ "$used" -lt 70 ] && curl -fsS -m 10 HC_URL/ping/HC_DISK
```

The logic is inverted on purpose: the script pings only while the disk is healthy, so
crossing 70% stops the pings and the dead man's switch fires. When it does, see
[5.2](#52-pruning-the-remote).

## 1.11 Add the emergency key

With the repository initialised and the daily key working:

```bash
sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass key add
# Prompts for the new password. Enter the six diceware words from step 1.1.
sudo /usr/local/bin/restic -r /mnt/ssd/restic key list    # expect two keys
```

Do the same for the remote — keys are per-repository and are **not** copied by
`restic copy`:

```bash
sudo /usr/local/bin/restic -r "rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo" \
    --password-file /etc/restic/repo.pass key add
```

Now prove the emergency key works, before you carry it anywhere:

```bash
sudo /usr/local/bin/restic -r /mnt/ssd/restic snapshots   # type the diceware words at the prompt
```

If that lists snapshots, the key is real. Write the recovery sheet
([section 4](#4-recovery-sheet)) and take it off-site.

## 1.12 Parallel run

Leave the old cron entries in place. Let both systems run for two to four weeks. Proton
keeps receiving tarballs. Nothing is deleted. Watch for: healthchecks staying green,
`restic snapshots` growing as expected, the weekly `check` passing, `/mnt/ssd` usage not
climbing faster than predicted.

## 1.13 The gate

Do not skip this and do not do it from the home server. Perform the full manual restore
drill in [3.4](#34-disaster-the-home-server-is-gone), from your workstation, using only
the paper sheet. Stand up a throwaway Vaultwarden from the restored data and log into
it.

If and only if that works:

```bash
sudo crontab -e      # remove the old backup script entries
```

Then retire `current-tool/`, delete the Proton Drive data, and remove the
`Proton_encrypted` remote from `rclone.conf`. The old system stays until the new one has
handed you back your data — not until it looks right, not until the checks are green.

---

# 2. Adding a new service

The design was built so this is almost nothing.

1. **Add the service** to the homelab repo as usual — a `services/<name>/` folder with
   its compose file and `.env`, state bind-mounted locally. The folder backup picks it
   up automatically; the `offsite` copy picks up the new data with no config change.
2. **If it owns a database**, write `services/<name>/backup.sh` and `restore.sh` from
   the shared library (one of the patterns in the [1.7 table](#one-backupsh--restoresh-per-database-owning-service)),
   exclude the raw DB path in `/etc/restic/homelab-excludes.txt`, and re-run the
   [1.8](#18-the-exclude-file) dry-run checks. The pairing assertion will refuse the
   backup if you exclude the DB dir but forget the `backup.sh`. A bare `*.db`/`*.sqlite3`
   file needs no new exclude line — the global patterns already hide it, and the
   assertion resolves them against the tree, so it refuses the backup until the
   `backup.sh` exists. If the engine has no online dump and stopping the service costs
   more than the data is worth, waive the exact paths in `services/<name>/no-db-dump`
   with the reason, and say what a restore therefore loses.
3. **If it has no database**, do nothing else — plain files are covered.
4. **Extend the drill** ([5.3](#53-the-quarterly-drill)) if this data matters. A backup
   you have never restored is a hypothesis.

---

# 3. Restoring

## 3.1 Find what you are looking for

```bash
R="sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass"

$R snapshots                       # everything
$R snapshots --tag homelab         # the homelab snapshots
$R find --tag homelab 'invoice*'   # which snapshots contain a matching file
$R ls latest --tag homelab         # contents of the newest snapshot
$R diff <snap-a> <snap-b>          # what changed between two nights
```

## 3.2 A single file

`dump` writes to stdout without staging anything:

```bash
$R dump latest HOMELAB_DIR/services/paperless-ngx/export/documents/originals/2024/invoice.pdf > invoice.pdf
```

To pull a subtree, `restore ... --include <path> --target /tmp/restore`; restic recreates
the full path under the target.

## 3.3 A whole service (into an already-running homelab)

For a single service that broke, not a full rebuild (that is [migrate-homeserver.md](migrate-homeserver.md)).

**A SQLite service** — the dump goes back *before* the container starts:

```bash
cd HOMELAB_DIR/services/uptime-kuma
docker compose down
$R restore latest --tag homelab --include '*/services/uptime-kuma/*' --target /tmp/uk
# copy the restored files back (config dir etc), then put the db in place:
FORCE=1 ./restore.sh          # FORCE because the live db may still exist
docker compose up -d
```

**A Postgres service** — the container comes up first (fresh, empty), then the dump
loads into it:

```bash
cd HOMELAB_DIR/services/mealie
docker compose up -d          # fresh initdb, since pgdata was excluded/absent
sleep 8
./restore.sh                  # restore_postgres replays db-dump/mealie.sql
```

**Paperless-ngx** — `document_importer` expects an empty instance. Restoring into a
populated one duplicates or errors depending on version; drop the DB volume first if
recovering in place. (Its whole-service recovery mirrors the Postgres pattern above.)

**Vaultwarden** — never restore under a live server. `docker compose down`, move `data`
aside, restore the snapshot's `data/` (which carries the RSA session-signing keys —
restoring the DB without them logs every client out and can break sessions), then move
`db-dump/db-snapshot.sqlite3` into place as `data/db.sqlite3`, `integrity_check`, `chown`
to the container uid, and `up -d`. Keep the old `data` until you have logged in.

## 3.4 Disaster: the home server is gone

The path the paper sheet exists for. You have nothing except the sheet and a laptop.
For rebuilding onto replacement hardware afterward, follow
[migrate-homeserver.md](migrate-homeserver.md); the steps below get your credentials
back so the rest of the recovery is ordinary work.

**1. Get a shell on the VPS** — your admin SSH key, or the provider's cloud console using
the account credentials and 2FA recovery codes from the sheet. The tunnel key will not
help you: it is restricted to forwarding and it lived on the machine that no longer
exists. That restriction is what stopped the attacker; it also stops you.

**2. Read the repository directly**, skipping rest-server — it is just a network front
end for a directory:

```bash
sudo restic -r /srv/restic/repo snapshots        # password: the six diceware words
```

If restic is not on the VPS, install it (upstream binary), or pull the repo to your
laptop over `sftp:` — `restic -r sftp:admin@VPS_HOST:/srv/restic/repo snapshots`. sftp
reads need filesystem access to a `restic:restic 0700` repo, so either run restic on the
VPS under `sudo`, or add your admin user to the `restic` group ahead of time. Decide now,
not then.

**3. Restore Vaultwarden first** — your other credentials are in it:

```bash
sudo restic -r /srv/restic/repo restore latest --tag homelab \
    --include '*/services/vaultwarden/*' --target /tmp/vw
```

Copy `/tmp/vw/HOMELAB_DIR/services/vaultwarden` to any machine with Docker, follow the
Vaultwarden steps in [3.3](#33-a-whole-service-into-an-already-running-homelab), and log
in. Then rebuild the home server ([migrate-homeserver.md](migrate-homeserver.md)).

Do **not** run `restic forget` or `prune` against the remote while recovering. It is
append-only and the commands will fail — the design working. Recovery is read-only.

---

# 4. Recovery sheet

One page. Printed. Physically separate from the house: a safe, a relative, a bank box.
Not a photo on your phone, not a file in cloud storage. It must contain:

- The six diceware words. Handwritten or printed; memorised as well is better.
- `VPS_HOST`, and the repository path `/srv/restic/repo`.
- The VPS provider account email, password, and 2FA recovery codes.
- One sentence: *"restic -r /srv/restic/repo snapshots, then restore --tag homelab."*
- The date you last verified the drill.

`REST_PASS` does **not** go on this sheet. Disaster recovery ([3.4](#34-disaster-the-home-server-is-gone))
reads the repository on the VPS by local path, bypassing rest-server entirely, so the
htpasswd credential is never needed to get your data back — and it is regenerable in
thirty seconds with `htpasswd` if you ever do need it.

On the provider credentials, worth being explicit, because this is the failure that
survives every other precaution: reaching the VPS requires the provider account. The
provider account password is in Vaultwarden. Vaultwarden is what you are restoring. The
circularity removed at the restic layer reappears at the account layer, and paper is the
only thing that breaks it. The alternative is a second admin SSH key held somewhere
durable and independent, plus accepting that a lost account locks you out. Choose
deliberately; do not leave it undecided.

---

# 5. Maintenance

## 5.1 Routine

Nothing here is manual. It is listed so you know what should be happening.

| When | What | Where |
|---|---|---|
| Nightly | dump DBs, backup, `forget` | local repo |
| Nightly | `copy` | local → remote |
| Weekly | `check --read-data-subset=1/7` | local repo |
| Weekly | `prune` | local repo |
| Monthly | `check` (structure only) | remote repo |
| Quarterly | restore drill | remote repo |
| Annually | manual drill from the paper sheet | remote repo |

The monthly remote check is not in the resticprofile config. Add it as a cron entry on
the VPS reading the repository directly, or run it by hand from the home server over the
tunnel. Reading is always allowed in append-only mode.

## 5.2 Pruning the remote

The remote grows forever by design. When `HC_DISK` fires, prune it, and keep the
repository password off the VPS while you do:

```bash
# On the VPS: swap append-only off, briefly.
sudo systemctl stop rest-server
sudo systemctl start rest-server-maintenance    # the unit built in 1.2, without --append-only
```

```bash
# On the home server, tunnel up. The password never leaves this machine.
sudo /usr/local/bin/restic -r "rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo" \
    --password-file /etc/restic/repo.pass \
    forget --keep-daily 7 --keep-weekly 8 --keep-monthly 24 --keep-yearly 10 \
    --group-by host,paths --prune
```

```bash
# On the VPS: put the guard back. Immediately.
sudo systemctl stop rest-server-maintenance
sudo systemctl start rest-server
ss -lntp | grep 8000
```

The window during which your backups are deletable should be measured in minutes and
should never occur unattended.

## 5.3 The quarterly drill

`/usr/local/sbin/restic-drill.sh`, mode `0700`, owned by root (it embeds `REST_PASS`),
wired to a systemd timer every 90 days. It restores from the **remote**, because that
exercises the tunnel, the remote data, and the path you would really use. It calls
restic by absolute path — under its systemd timer the PATH does not include
`/usr/local/bin`:

```bash
#!/bin/bash
set -euo pipefail
RESTIC=/usr/local/bin/restic
REPO="rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo"
PASS=/etc/restic/repo.pass
TMP=$(mktemp -d -p /dev/shm restic-drill.XXXXXX)   # tmpfs: plaintext vault never hits disk
trap 'rm -rf "$TMP"' EXIT

# Every db-dump in the snapshot.
"$RESTIC" -r "$REPO" --password-file "$PASS" \
    restore latest --tag homelab --include '*/db-dump/*' --target "$TMP"

db=$(find "$TMP" -name db-snapshot.sqlite3 | head -1)
[[ -n "$db" ]] || { echo "no vaultwarden database in snapshot" >&2; exit 1; }
sqlite3 "$db" 'PRAGMA integrity_check;' | grep -qx ok

# Every sqlite dump passes integrity_check.
while IFS= read -r -d '' f; do
    [[ "$(sqlite3 "$f" 'PRAGMA integrity_check;')" == "ok" ]] \
        || { echo "$f fails integrity_check" >&2; exit 1; }
done < <(find "$TMP" -path '*/db-dump/*' \( -name '*.db' -o -name '*.sqlite3' \) -print0)

# Every postgres dump ran to completion. A truncated dump replays halfway.
while IFS= read -r -d '' f; do
    grep -q 'PostgreSQL database dump complete' "$f" || { echo "$f is truncated" >&2; exit 1; }
done < <(find "$TMP" -path '*/db-dump/*' -name '*.sql' -print0)

# Paperless still has a real document count.
"$RESTIC" -r "$REPO" --password-file "$PASS" \
    restore latest --tag homelab --include '*/export/manifest.json' --target "$TMP"
manifest=$(find "$TMP" -name manifest.json | head -1)
[[ -n "$manifest" ]] || { echo "no paperless manifest in snapshot" >&2; exit 1; }
count=$(jq '[.[] | select(.model == "documents.document")] | length' "$manifest")
[[ "$count" -gt 100 ]] || { echo "manifest has only $count documents; suspicious" >&2; exit 1; }

curl -fsS -m 10 --retry 3 HC_URL/ping/HC_DRILL
```

Tune the `100` to a little below your real document count. The `select` matters:
`manifest.json` is a Django fixture dump — one array holding tags, correspondents, users
and saved views alongside documents — so a bare `jq 'length'` would sail past a
document-count threshold even if every document had vanished. Filtering on
`documents.document` counts the thing you care about.

This proves the data is *usable*. `restic check` does not: it proves the repository is
internally consistent, which an immaculate repository full of empty archives also
manages.

## 5.4 When things go wrong

- **A run left a lock.** `restic unlock` after confirming nothing is running.
  `global.restic-stale-lock-age: 2h` handles most cases itself.
- **A db-dump is enormous and grows every night.** Suspect an unbounded log table before
  suspecting real data. Komodo's FerretDB/DocumentDB backend schedules two pg_cron index
  build tasks on a `2 seconds` interval; pg_cron records every run in
  `cron.job_run_details` and never prunes it. That reached 6.8 GB of a 7.1 GB database —
  96% of the dump was a log nothing reads. Rank a plain-SQL dump's tables without needing
  credentials by measuring the byte gaps between its `-- Data for Name:` markers:
  `grep -b '^-- Data for Name:' db-dump/x.sql`. The fix is three-layered: `TRUNCATE` to
  reclaim, a `cron.schedule('purge-cron-history', ...)` job to cap it at 7 days, and
  `--exclude-table-data` so the backup stays lean even if that job is lost to an upgrade.
- **`forget`/`prune` against the remote fails with a permission error.** Expected — the
  remote is append-only. See [5.2](#52-pruning-the-remote).
- **`offsite` fails but backups are green.** The tunnel is down.
  `systemctl status restic-tunnel`, then `ss -lntp | grep 8000` on both ends. Backups
  are unaffected.
- **restic exits 3.** The snapshot was created but some files could not be read — a
  partial backup that a naive `$? -eq 0` treats as success. Confirm resticprofile
  surfaces it as failure.
- **A snapshot is missing for a night the host was down.** Expected and handled: systemd
  timers run `Persistent=true`; retention keeps the newest snapshot *within* each period,
  not one dated to a specific day.
