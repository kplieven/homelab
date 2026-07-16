# Moving the repository to a new path on the same VPS

Same VPS, new filesystem location — almost always because you have attached a bigger
disk and want the repository on it instead of the root filesystem. `/srv/restic` →
`/mnt/backup/restic`, say.

This is the smallest of the three migrations. A restic repository is just a directory;
you move the directory, tell rest-server its new `--path`, and update the one place the
old absolute path is written down for real: the recovery sheet. The **home server needs
no change at all** — it talks to `127.0.0.1:8000/repo` over the tunnel, and rest-server
abstracts the server-side path away from the client.

Read [`README.md`](README.md) first; this reuses [§1.2](README.md#12-vps-rest-server) and
[§4](README.md#4-recovery-sheet) by reference. Everything below runs **on the VPS**
unless noted.

Throughout: `OLD=/srv/restic`, `NEW=/mnt/backup/restic` (substitute your real paths).

## 1. Prepare and prove the new location

If the new path is on a separate disk, it must be mounted at boot — a repo directory on
an unmounted mountpoint is a silent trap: rest-server either serves an empty directory
(and append-only "protects" nothing) or writes onto the root disk *under* the
mountpoint, invisible until the real disk is mounted over it.

```bash
# add the disk to /etc/fstab, then:
sudo mkdir -p /mnt/backup
sudo mount -a
mountpoint -q /mnt/backup && echo "mounted (good)" || echo "NOT mounted — stop, fix fstab"
df -h /mnt/backup                     # confirm it is the big disk, not the root fs
```

## 2. Stop writes

```bash
sudo systemctl stop rest-server       # no writes during the move
```

The tunnel on the home server can stay up; with rest-server down it simply gets
connection-refused until step 5, and `Restart=always` reconnects on its own.

## 3. Move the whole `/srv/restic` tree

Move the **parent**, not just `repo/` — rest-server's `--path` points at `/srv/restic`,
which also holds `.htpasswd`. Preserve ownership and permissions:

```bash
sudo rsync -aHAX --numeric-ids --info=progress2 "$OLD"/ "$NEW"/
sudo chown -R restic:restic "$NEW"
sudo chmod 0700 "$NEW"
ls -la "$NEW"                          # expect: repo/  and  .htpasswd, owned restic:restic
```

Keep `$OLD` in place for now — it is your rollback until the new path is proven. (`rsync`
rather than `mv` because a cross-disk `mv` is a copy anyway, and rsync lets you verify
before deleting the source.)

## 4. Repoint rest-server at the new path

Edit **both** units — `rest-server.service` and its `rest-server-maintenance` sibling —
changing the two places the path appears: `--path` and `ReadWritePaths=`. The
`ProtectSystem=strict` sandbox means an un-updated `ReadWritePaths=` leaves rest-server
unable to write to the new location and it will fail on the first backup:

```bash
sudo sed -i 's#/srv/restic#/mnt/backup/restic#g' \
    /etc/systemd/system/rest-server.service \
    /etc/systemd/system/rest-server-maintenance.service
sudo systemctl daemon-reload
sudo systemctl start rest-server
ss -lntp | grep 8000                   # 127.0.0.1:8000, back up on the new path
```

Sanity-check the running unit actually points where you think:

```bash
systemctl show rest-server -p ExecStart | grep -o -- '--path [^ ]*'   # expect /mnt/backup/restic
```

## 5. Verify from the home server

Nothing changed on the home server, so this is the proof that the client is genuinely
insulated from the server-side move. On the **home server**:

```bash
curl -si --max-time 5 http://127.0.0.1:8000/ | head -1        # HTTP/1.1 401 Unauthorized

R="sudo /usr/local/bin/restic -r rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo --password-file /etc/restic/repo.pass"
$R snapshots | tail                     # full history, served from the new disk
$R check                                # structure intact after the move
```

Run one real `offsite` copy — a small delta, confirming writes land correctly on the new
path and `HC_OFFSITE` goes green:

```bash
sudo resticprofile -c /etc/restic/profiles.yaml -n offsite copy
```

## 6. Update the disk check and the recovery sheet

The `HC_DISK` cron watched the old filesystem. Point it at the new one — its whole job is
to warn before the repo's disk fills, so it must watch the disk the repo now lives on
([README §1.10](README.md#110-healthchecks)):

```bash
# /etc/cron.daily/restic-disk-check on the VPS
used=$(df --output=pcent /mnt/backup | tail -1 | tr -dc '0-9')
[ "$used" -lt 70 ] && curl -fsS -m 10 HC_URL/ping/HC_DISK
```

**Update the recovery sheet.** This is the one change that actually matters long-term.
The disaster path ([README §3.4](README.md#34-disaster-the-home-server-is-gone)) reads
the repository *directly by filesystem path*, bypassing rest-server:

```
restic -r /mnt/backup/restic/repo snapshots        # was /srv/restic/repo
```

If the sheet still says `/srv/restic/repo`, disaster recovery points restic at a path
that no longer exists — the move's only lasting trap. Fix the paper, and fix the
one-line restore sentence and the repository-path line on it.

## 7. Remove the old directory

Only after step 5 passes and the sheet is updated:

```bash
sudo rm -rf /srv/restic
```

If `/srv/restic` was itself on a disk you are decommissioning, unmount and detach it now.

---

## What "done" looks like

- `systemctl show rest-server` reports `--path /mnt/backup/restic`; `ss -lntp` shows it
  listening on `127.0.0.1:8000`.
- From the home server, `restic snapshots` shows the full history and `restic check`
  passes — with **no change to the home server's config**.
- An `offsite` copy is a small green delta.
- `HC_DISK` now watches `/mnt/backup`.
- The recovery sheet's repository path and restore sentence name the new location.
- The old `/srv/restic` is gone.
