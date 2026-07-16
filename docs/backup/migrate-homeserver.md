# Migrating the home server to new hardware

This is the use case the whole design exists for: *restore, `docker compose up -d`,
done.* A bare machine with Docker and restic becomes the working homelab after one
restore and a per-service bring-up, with no step that depends on GitHub being reachable
or on an `.env` that lived only on the dead disk.

Read [`README.md`](README.md) first — this guide reuses its steps by reference rather
than repeating them.

## Which situation are you in?

| | The old box still boots | The old box is dead |
|---|---|---|
| **Repo source** | its `/mnt/ssd/restic` local repo | the VPS remote `/srv/restic/repo` |
| **Speed** | fast (local disk, or moved SSD) | limited by download from the VPS |
| **Do this** | the **planned** path below | the **disaster** path below |

The planned path is strongly preferable: take a final backup while the old box is alive,
and you restore from a complete, verified local repo with nothing to download. Only fall
to the disaster path if the old machine is genuinely unrecoverable — that path is
[README §3.4](README.md#34-disaster-the-home-server-is-gone) followed by this same
rebuild.

---

## Planned migration (old box still boots)

### 1. Capture the final state, while you still can

On the **old** home server, take a last backup and push it off-site, so the newest state
is in both repos before you power down:

```bash
sudo resticprofile -c /etc/restic/profiles.yaml -n homelab backup
sudo resticprofile -c /etc/restic/profiles.yaml -n offsite copy
sudo /usr/local/bin/restic -r /mnt/ssd/restic --password-file /etc/restic/repo.pass snapshots | tail
```

Confirm the newest snapshot is dated now. Then stop the services so nothing writes
after the snapshot:

```bash
for d in HOMELAB_DIR/services/*/; do (cd "$d" && docker compose down); done
```

### 2. Decide what carries the repository to the new box

- **Move the SSD.** If `/mnt/ssd` physically moves to the new machine, the local repo
  moves with it and the restore is a local read — fastest, and needs no VPS at all.
- **Leave the SSD behind.** Then the new box restores from the VPS remote over a tunnel
  you will set up in step 4. Everything still works; it just downloads.

Either way, the **repository password** is what you need in hand: the daily key (from
Vaultwarden, if you can still open it, or `/etc/restic/repo.pass` on the old box) or the
emergency key from the paper sheet.

### 3. Provision the new machine

Install the same base the old one had — this is [README §1.5](README.md#15-home-server-restic-resticprofile-repositories)
in miniature:

```bash
# Docker + compose, git, and the dump tooling
sudo apt install git sqlite3 jq curl        # NOT restic — see below
# restic from the upstream binary (apt ships 0.14):
#   https://github.com/restic/restic/releases  ->  install to /usr/local/bin/restic
# resticprofile:
curl -sfL https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh \
    | sudo sh -s -- -b /usr/local/bin
```

Recreate the mount and the key file:

```bash
# /mnt/ssd — attach the moved SSD (check /etc/fstab), or create a fresh mount if the
# repo will be pulled from the VPS. A repo dir on an unmounted path is a silent trap.
mountpoint -q /mnt/ssd && echo "mounted" || echo "NOT mounted — fix fstab before restoring"

sudo mkdir -p /etc/restic
printf '%s' 'THE_DAILY_KEY' | sudo tee /etc/restic/repo.pass > /dev/null
sudo chmod 0400 /etc/restic/repo.pass
```

Remember: every interactive `sudo restic` is `sudo /usr/local/bin/restic`, because
`secure_path` may exclude `/usr/local` (see README §1.5).

### 4. Reach the repository

**If the SSD moved** (`/mnt/ssd/restic` is present), skip to step 5 — you read it locally.

**If restoring from the VPS**, stand up a fresh tunnel. The old tunnel key died with the
old box, so generate a new one and authorise it — this is [README §1.3](README.md#13-restricted-ssh-key-for-the-tunnel)
and [§1.4](README.md#14-home-server-tunnel-unit) again:

```bash
sudo ssh-keygen -t ed25519 -N '' -f /etc/restic/tunnel_ed25519 -C restic-tunnel@homeserver
sudo cat /etc/restic/tunnel_ed25519.pub
# On the VPS: add this pubkey to ~restic-tunnel/.ssh/authorized_keys with the SAME
# restrict,port-forwarding,permitopen="127.0.0.1:8000",command="/usr/bin/false" prefix.
```

Install `restic-tunnel.service` (README §1.4), add the VPS host key to
`/root/.ssh/known_hosts` after verifying its fingerprint against the provider console,
start it, and confirm:

```bash
curl -si --max-time 5 http://127.0.0.1:8000/ | head -1        # HTTP/1.1 401 Unauthorized
```

Reading the append-only remote is permitted, so no maintenance window is needed to
restore from it.

### 5. Restore the snapshot

The snapshot carries absolute `HOMELAB_DIR` paths, the compose files, every `.env`, the
config/state dirs, the `db-dump/*` files, and `.git`. Restore straight to `/`:

```bash
# from the local repo (SSD moved):
REPO=/mnt/ssd/restic
# or from the remote (tunnel up):
REPO="rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo"

sudo /usr/local/bin/restic -r "$REPO" --password-file /etc/restic/repo.pass \
    restore latest --tag homelab --target /
```

Prove the restore *is* the clone — no GitHub required, and `git pull` works immediately:

```bash
cd HOMELAB_DIR && git status --short | head && git log --oneline -1
```

Confirm the raw DB dirs did **not** come back (they were excluded; the dumps replace
them):

```bash
find HOMELAB_DIR/services -name pgdata -o -name 'db.sqlite3' -o -name '*.db-wal' | head   # expect empty
find HOMELAB_DIR/services -path '*/db-dump/*' -type f | wc -l                             # one per DB service
```

### 6. Bring the services back — mind the order

The restore left every service's config in place but **no live databases** — pgdata is
absent, live SQLite files are absent, and each service has a `db-dump/` instead. Two
classes reload differently, and the order matters:

**SQLite services first, before their container starts.** The dump goes back into an
empty config dir cleanly (no live file to clobber), then the app opens it on first run:

```bash
cd HOMELAB_DIR
for s in home-assistant uptime-kuma filebrowser babybuddy calibre vaultwarden; do
    [[ -x services/$s/restore.sh ]] && ( cd services/$s && ./restore.sh )
done
# media-stack holds several SQLite services in one folder:
( cd services/media-stack && ./restore.sh )
```

**Postgres / Mongo services: container up first (fresh, empty), then load the dump.**
A fresh Postgres runs `initdb` because pgdata is absent; `restore_postgres` then replays
the dump into it:

```bash
cd HOMELAB_DIR
for s in linkwarden immich affine mealie komodo your-spotify; do
    ( cd services/$s && docker compose up -d )       # fresh initdb / empty mongo
done
sleep 12                                             # let the DBs accept connections
for s in linkwarden immich affine mealie komodo your-spotify; do
    ( cd services/$s && ./restore.sh )               # replay db-dump/* into the running DB
done
```

**Paperless-ngx** is its own case — `document_importer` wants an empty instance:

```bash
cd HOMELAB_DIR/services/paperless-ngx
docker compose up -d db broker
docker compose run --rm webserver document_importer ../export
docker compose up -d
```

Now bring up everything else (the services with no database, and restart the SQLite ones
if they were not started above):

```bash
cd HOMELAB_DIR
for d in services/*/; do ( cd "$d" && docker compose up -d ); done
```

> `restore-all.sh` ([README §1.7](README.md#17-the-dump-layer)) automates the DB-loading
> loop, but it assumes the right containers are already in the right state — SQLite down,
> Postgres up. On a from-scratch rebuild the explicit ordering above is safer; use
> `restore-all.sh` for the day-to-day single-service case.

### 7. Re-establish the backup system itself

The data is back; now make the new box able to back itself up.

- **Install the server-side pieces.** Most of these came back with the restore, since
  their tracked sources live in `docs/backup/server/` — install from there rather than
  retyping: `restic-guard.sh` and `homelab-dump.sh`
  ([README §1.7](README.md#the-orchestrator-and-the-pairing-assertion)),
  `homelab-excludes.txt` ([§1.8](README.md#18-the-exclude-file)), and
  `profiles.yaml.example` → `/etc/restic/profiles.yaml` with `REST_PASS` substituted
  ([§1.9](README.md#19-resticprofile-configuration)).

  ```bash
  sudo install -m 0755 docs/backup/server/restic-guard.sh  /usr/local/sbin/restic-guard.sh
  sudo install -m 0755 docs/backup/server/homelab-dump.sh  /usr/local/sbin/homelab-dump.sh
  sudo install -m 0644 docs/backup/server/homelab-excludes.txt /etc/restic/homelab-excludes.txt
  ```

- **Rebuild the two that cannot be tracked**, because they embed `REST_PASS`:
  `/etc/restic/profiles.yaml` (mode `0600`, from the `.example`) and
  `/usr/local/sbin/restic-drill.sh` ([§5.3](README.md#53-the-quarterly-drill), mode `0700`).
  `REST_PASS` itself is regenerable in thirty seconds with `htpasswd` if the old value
  is gone — see [§4](README.md#4-recovery-sheet).
- **Do NOT re-init the repositories.** They already exist and hold your history. Just
  point the profile at them.
- **Re-verify the exclude file** on the new tree ([§1.8](README.md#18-the-exclude-file)
  dry-run checks) — paths are identical, but confirm rather than assume.
- **Schedule the timers** and add the tunnel-ordering drop-in
  ([§1.9](README.md#19-resticprofile-configuration)).
- **The emergency key is already present** in both repos (per-repo keys travel with the
  repository, and both were seeded in §1.11). No key re-add is needed.

Take one real backup and one copy, and confirm both healthchecks go green:

```bash
sudo resticprofile -c /etc/restic/profiles.yaml -n homelab backup
sudo resticprofile -c /etc/restic/profiles.yaml -n offsite copy
```

### 8. Run the drill, then decommission the old box

```bash
sudo /usr/local/sbin/restic-drill.sh; echo "exit: $?"     # expect 0, HC_DRILL green
```

Only once the drill passes:

- **Revoke the old tunnel key.** On the VPS, delete the *old* home server's line from
  `~restic-tunnel/.ssh/authorized_keys`. Leaving a dead key authorised is the one loose
  end a hardware swap tends to forget, and it is a standing credential on the box that
  holds your ciphertext.
- **Wipe the old machine** (and its SSD, if it did not move).
- **Update the recovery sheet** if anything on it changed (it usually does not — same
  VPS, same repo path).

---

## Disaster migration (old box is dead)

You have no old box and no local repo — only the VPS remote, the paper sheet, and new
hardware.

1. **Recover your credentials first** via [README §3.4](README.md#34-disaster-the-home-server-is-gone):
   get a shell on the VPS, read `/srv/restic/repo` directly with the emergency key,
   restore Vaultwarden to a laptop, and log in. Everything else needs passwords that are
   in that vault.
2. **Provision the new home server** — steps 3 and 4 above. There is no SSD to move, so
   you will restore from the VPS over a fresh tunnel.
3. **Restore and bring up** — steps 5 and 6 above, using the remote repo URL.
4. **Re-establish the backup system** — step 7 above.
5. **Drill and finish** — step 8, minus the "wipe the old machine" (there isn't one).
   Still revoke any stale tunnel keys on the VPS.

The only real difference from the planned path is that you download the whole repository
instead of reading a local disk, and you lean on the paper sheet to break back in. The
rebuild itself is identical.

---

## What "done" looks like

- `git log` in `HOMELAB_DIR` shows real history; `git pull` works.
- Every service answers on its port; `wg show` lists your VPN peers (this is why 1.6's
  bind-mount fix exists).
- No `pgdata` / live `*.db` under `services/` — only `db-dump/` and restored live DBs.
- A fresh `homelab` backup and `offsite` copy both go green.
- The drill passes against the remote.
- The old tunnel key is gone from the VPS.
