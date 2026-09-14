# Migrating to the TerraMaster F4-424 Pro (Proxmox VE 9)

Companion to [`migrate-homeserver.md`](migrate-homeserver.md), which covers the
generic restore. This file covers only what is *specific* to this move: the old
box had one disk, the new one has two tiers, so paths change — and that is the
part the generic guide cannot know about.

## The machines

| | Old | New |
|---|---|---|
| Host | bare-metal Debian, `192.168.0.100` | Proxmox VE 9, `192.168.0.101` |
| Services | on the host | unprivileged LXC **100** (`homelab`), `192.168.0.102` |
| Storage | one SSD, `/mnt/ssd` (`/dev/sda2`, 786G) | NVMe (LVM-thin) + `tank`, 2×4TB RAIDZ1 (~3.6 TiB) |

Unprivileged LXC shifts UIDs by 100000: container `root` is host `100000`, and the
service user (1000) is host `101000`. That is why host-side rsyncs use
`--chown=101000:101000` and container-side ones use `--chown=1000:1000`.

## Storage tiers — the rule

**Frequent read-write on NVMe. Bulk media on the HDD pool, so the disks spin up only
when something is actually being consumed.**

| Host path (`.101`) | Container path | Tier | Holds |
|---|---|---|---|
| `/tank/media` | `/mnt/media` | HDD | tv, movies, books, audiobooks — the *library* |
| *(LVM-thin, `vm-100-disk-1`)* | `/mnt/torrents` | NVMe | active downloads + seeding |
| `/tank/photos` | `/mnt/photos` | HDD | `Foto's`, immich upload + library |
| `/tank/files` | `/mnt/files` | HDD | Documents, Scans, Backup, music, archives, to-be-imported |
| `/tank/restic` | `/mnt/restic` | HDD | the restic repository |

Dataset properties: `recordsize=1M` throughout (it is an upper bound, so small files
are unharmed), `compression=lz4` except `tank/restic`, which is `off` — restic already
compresses with zstd and encrypts, so a second pass is pure CPU for nothing.

**Books and audiobooks are served from the HDD**, not from the seeding copy. The
torrent copies on NVMe are disposable; stop seeding whenever. This costs 24G of
duplication until then.

## Path map

Everything that moves, and where it lands. `repoint-paths.sh` in the repo root applies
the `.env` half of this automatically.

    /mnt/ssd/server/media           ->  /mnt/media
    /mnt/ssd/server/torrents        ->  /mnt/torrents
    /mnt/ssd/server/to-be-imported  ->  /mnt/files/to-be-imported
    /mnt/ssd/Foto's                 ->  /mnt/photos/Foto's
    /mnt/ssd/immich, immich_library ->  /mnt/photos/...
    /mnt/ssd/Documents, Scans       ->  /mnt/files/...
    /mnt/ssd/Backup, music,
      informatica_archived          ->  /mnt/files/...
    /mnt/ssd/restic                 ->  /mnt/restic

## Compose changes (not handled by the script)

These are structural, tracked in git, and must NOT be applied to the old box while it is
still serving — a restart would bind paths that do not exist there. Apply after restore.

**`media-stack`** — the single `${MEDIA_ROOT}:/data` mount cannot survive the split,
because `/data/media` and `/data/torrents` are now different filesystems. Split it, and
keep the **in-container** paths identical so qBittorrent needs no force-recheck and the
\*arrs need no root-folder change:

    sonarr/radarr/bazarr/mam:  ${MEDIA_ROOT}:/data/media
                               ${TORRENT_ROOT}:/data/torrents
    jellyfin:                  ${MEDIA_ROOT}/media:/data/media      (unchanged)
    qbittorrent:               ${TORRENT_ROOT}:/data/torrents
    audiobookshelf:            ${MEDIA_ROOT}/audiobooks:/audiobooks  <- was torrents/audiobooks

Consequence: torrents -> library imports are now a real cross-device copy, not an atomic
rename, so imports get slower and hardlinks are impossible across the boundary. That
costs nothing here — `find /mnt/ssd/server -type f -links +1` returns zero, so there
were never any hardlinks to lose.

**`filebrowser`** — `${BROWSER_ROOT_PATH}:/srv` becomes three mounts whose in-container
paths match the old single root, so `filebrowser.db` stays valid:

    ${BROWSER_ROOT_PATH}:/srv/media
    ${TORRENT_ROOT}:/srv/torrents
    ${FILES_ROOT}/to-be-imported:/srv/to-be-imported

Do **not** point the root at `/mnt` — that would expose the restic repo through a web UI.

**`homepage`** — one disk widget became two. Add `TORRENT_DISK_PATH` to the env passthrough
and a second bind, then list both in `config/widgets.yaml`.

**GPU** — the old box had NVIDIA; the F4-424 Pro has Intel Quick Sync via `/dev/dri`:

    immich:    nvenc -> quicksync,  image -cuda -> -openvino,  service cuda -> openvino
    jellyfin:  deploy driver nvidia -> device passthrough of /dev/dri (VAAPI)
    media-stack/docker-compose.yml lines ~101-103 still reserve an NVIDIA GPU — remove.

Passed through with `pct set 100 --dev0 /dev/dri/renderD128,gid=$RGID --dev1 /dev/dri/card0,gid=$VGID`.
Mountpoints and devices do **not** hotplug: one `pct reboot 100` picks them all up.

**Immich split** — `thumbs/` and `encoded-video/` are read-write-hot and belong on NVMe,
not on the pool with the originals.

## Order of operations

1. Datasets first, *then* copy into them. A dataset created over a populated directory
   hides the data under the new mount.
2. Serialise the large rsyncs. 1GbE is the ceiling and concurrent sequential streams onto
   a 2-disk RAIDZ1 just cause seek thrash.
3. Secrets go host-to-host, root-to-root, never through the git repo:
   `sudo scp /etc/restic/repo.pass /etc/restic/tunnel_ed25519 root@192.168.0.101:/root/`.
   The repository is inert without `repo.pass`.
4. `repoint-paths.sh` runs **after** the restore and **before** any `docker compose up`.
5. Before wiping the old box, confirm the ~38G that restic never covered is on the new
   one: `informatica_archived` (17G), `Backup` (17G), `music` (3.9G),
   `Basisschool Maxime.zip` (155M). Step 8 of the generic guide destroys these.

## Reminder about `docs/backup/server/`

Those four files are sanitised **templates** — `HOMELAB_DIR`, `REST_PASS`, `HC_*` are
placeholders, not values to fill in on disk. The live rendered copies belong only in
`/etc/restic/`. A rendered `profiles.yaml` committed here publishes the VPS REST
password to GitHub.
