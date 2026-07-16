# Migrating the off-site copy to a new VPS

You are moving the append-only remote from one VPS to another — new provider, or new
box. The home server and its local repo do not change; only the copy target does.

A restic repository is **just a directory**, so the fast, correct way is to copy the
directory verbatim and repoint the tunnel. Re-initialising a fresh remote and re-copying
from scratch also works but re-uploads everything — use it only if you cannot get the
old directory off the old VPS.

Read [`README.md`](README.md) first; this guide reuses [§1.2](README.md#12-vps-rest-server),
[§1.3](README.md#13-restricted-ssh-key-for-the-tunnel) and
[§1.4](README.md#14-home-server-tunnel-unit) by reference.

| | **Approach A — copy the repo** (recommended) | **Approach B — re-init and re-copy** |
|---|---|---|
| Data moved | rsync the directory | `restic copy` re-uploads everything |
| Dedup/chunker params | preserved automatically (same repo) | must pass `--copy-chunker-params` |
| History | preserved exactly | preserved (copied snapshot-by-snapshot) |
| Keys | both keys already in the copied repo | must re-add the emergency key |
| Use when | you can reach the old repo directory | the old VPS is already gone |

---

## Approach A — copy the repository (recommended)

### 1. Stand up rest-server on the new VPS

Repeat [README §1.2](README.md#12-vps-rest-server) on the new box: the `restic` system
user, `/srv/restic`, the htpasswd file, `rest-server.service` (append-only) and the
`rest-server-maintenance.service` sibling, the `restic-tunnel` user, and the `HC_DISK`
cron. You may **keep the same `REST_USER`/`REST_PASS`** (simplest — the home server URL
does not change) or mint new ones; if new, you will update `profiles.yaml` in step 5.

Do **not** `restic init` on the new box. The repository arrives by copy in the next step;
initialising first would create an empty repo you then have to delete.

Record the new VPS's SSH host-key fingerprint from the provider console now — you need it
in step 4.

### 2. Copy the repository directory old → new

Stop writes so you copy a consistent tree. On the **old** VPS:

```bash
sudo systemctl stop rest-server        # reads/writes paused; the repo is now quiescent
```

A restic repo is self-consistent even mid-write (append-only, content-addressed), but
stopping rest-server removes all doubt and the window is short. Copy the whole
`/srv/restic` tree (it holds `repo/` **and** `.htpasswd`), preserving ownership and
permissions. Route it however your network allows — directly if the boxes can reach each
other, or via your workstation as a relay:

```bash
# Direct, if new VPS can pull from old (run on the NEW VPS):
sudo rsync -aHAX --numeric-ids --info=progress2 \
    -e ssh admin@OLD_VPS:/srv/restic/ /srv/restic/

# Or two hops through your laptop:
rsync -aHAX --numeric-ids admin@OLD_VPS:/srv/restic/ /tmp/restic-move/
rsync -aHAX --numeric-ids /tmp/restic-move/ admin@NEW_VPS:/tmp/restic-in/
# then on the new VPS: sudo rsync -aHAX /tmp/restic-in/ /srv/restic/
```

Fix ownership on the new box (rsync as your admin user will not preserve the `restic`
uid unless you ran it as root with `--numeric-ids` and the uids match):

```bash
sudo chown -R restic:restic /srv/restic
sudo chmod 0700 /srv/restic
```

Start rest-server on the **new** VPS, and restart it on the **old** one (so the old
remote keeps working until you have proven the new one — do not burn the bridge yet):

```bash
# new VPS:
sudo systemctl enable --now rest-server && ss -lntp | grep 8000
# old VPS:
sudo systemctl start rest-server
```

### 3. Authorise the home server's tunnel key on the new VPS

The **same** home-server tunnel key can be reused — no need to regenerate it. On the new
VPS, add its public key to `~restic-tunnel/.ssh/authorized_keys` with the identical
restriction prefix from [README §1.3](README.md#13-restricted-ssh-key-for-the-tunnel):

```
restrict,port-forwarding,permitopen="127.0.0.1:8000",command="/usr/bin/false" ssh-ed25519 AAAA... restic-tunnel@homeserver
```

Then run the three [§1.3 confirmation checks](README.md#confirm-the-restriction-actually-holds)
against `NEW_VPS` — the restriction is new box, new sshd, and untested until you drive
traffic through it. Especially check #2 (port 9999 must be refused): `permitopen` is the
only thing standing between this key and the new VPS's port 22.

### 4. Repoint the tunnel on the home server

Update `/etc/systemd/system/restic-tunnel.service` to the new host, and swap the known
host key — verifying the new fingerprint before trusting it:

```bash
sudo sed -i 's/OLD_VPS/NEW_VPS/' /etc/systemd/system/restic-tunnel.service

# verify the new host key against the provider console, THEN trust it:
sudo ssh-keyscan NEW_VPS 2>/dev/null | ssh-keygen -lf -              # compare fingerprint
sudo ssh-keygen -R OLD_VPS -f /root/.ssh/known_hosts                 # drop the old entry
sudo ssh-keyscan NEW_VPS | sudo tee -a /root/.ssh/known_hosts

sudo systemctl daemon-reload
sudo systemctl restart restic-tunnel
curl -si --max-time 5 http://127.0.0.1:8000/ | head -1              # HTTP/1.1 401 Unauthorized
```

The `401` proves the tunnel now lands on the new VPS's rest-server. (Update the
`Description=` line's hostname too, so `systemctl status` doesn't lie to a future you.)

### 5. Update the profile only if credentials changed

If you kept the same `REST_USER`/`REST_PASS`, `profiles.yaml` needs **no change** — the
URL is `127.0.0.1:8000`, which the tunnel now forwards to the new box. If you minted new
credentials, update the `offsite:` `repository:` line in
[`/etc/restic/profiles.yaml`](README.md#19-resticprofile-configuration) (and the drill
in [§5.3](README.md#53-the-quarterly-drill), which embeds them).

### 6. Verify the new remote holds everything

```bash
R="sudo /usr/local/bin/restic -r rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo --password-file /etc/restic/repo.pass"
$R snapshots | tail            # ALL history present, up to the latest local snapshot
$R check                       # structure intact after the copy
$R key list                    # two keys — daily + emergency — carried over in the copy
```

Then run one real `offsite` copy. Because the repository was copied verbatim, the
chunker params match automatically and this is a near-noop moving only tonight's delta —
which is itself the proof that the two repos are correctly in sync:

```bash
sudo resticprofile -c /etc/restic/profiles.yaml -n offsite copy
```

Confirm `HC_OFFSITE` goes green.

### 7. Update the recovery sheet and decommission the old VPS

The disaster path reads the remote by `VPS_HOST` and provider account — both change with
the new box. Update the paper sheet: new `VPS_HOST`, new provider account email /
password / 2FA recovery codes, new host fingerprint. The repo path `/srv/restic/repo` is
unchanged.

Only after several green `offsite` copies **and** a passing drill against the new remote:

```bash
sudo /usr/local/sbin/restic-drill.sh; echo "exit: $?"      # exercises the new tunnel + remote
```

- On the **old** VPS, remove the home server's key from `~restic-tunnel/.ssh/authorized_keys`.
- Destroy the old VPS.

---

## Approach B — re-init a fresh remote and re-copy

Use this only when the old VPS (and its repo directory) is already unreachable, so you
must rebuild the remote from the home server's local repo.

1. Stand up rest-server on the new VPS — step 1 above.
2. Authorise and repoint the tunnel — steps 3 and 4 above.
3. **Init the new remote from the local repo, with matching chunker params.** This is
   the second command in [README §1.5](README.md#15-home-server-restic-resticprofile-repositories),
   and `--copy-chunker-params` is mandatory — skip it and every future `copy` re-uploads
   from scratch forever:

   ```bash
   sudo /usr/local/bin/restic -r "rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo" \
       --password-file /etc/restic/repo.pass \
       init \
       --from-repo /mnt/ssd/restic \
       --from-password-file /etc/restic/repo.pass \
       --copy-chunker-params
   ```
4. **Re-add the emergency key** to the new remote — a fresh `init` only carries the daily
   key ([README §1.11](README.md#111-add-the-emergency-key)):

   ```bash
   sudo /usr/local/bin/restic -r "rest:http://REST_USER:REST_PASS@127.0.0.1:8000/repo" \
       --password-file /etc/restic/repo.pass key add
   ```
5. **Seed the full history** with a first copy — this one is *not* a noop; it uploads
   every snapshot the empty remote lacks, i.e. all of them:

   ```bash
   sudo resticprofile -c /etc/restic/profiles.yaml -n offsite copy
   ```
6. Verify (step 6 above), update the recovery sheet (step 7). There is no old VPS to
   decommission.

---

## What "done" looks like

- `curl -si http://127.0.0.1:8000/` returns `401` and the tunnel `Description=` names the
  new host.
- `restic snapshots` over the new tunnel shows the full history; `restic check` passes.
- `restic key list` shows both keys on the new remote.
- An `offsite` copy is a small delta (Approach A) or has finished seeding (Approach B),
  and `HC_OFFSITE` is green.
- The drill passes against the new remote.
- The recovery sheet names the new VPS; the old VPS's authorised tunnel key is removed
  and the box is destroyed.
