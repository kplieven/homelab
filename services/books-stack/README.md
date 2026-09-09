## Books Stack

Everything book-shaped in one place: the ebook library, the audiobook library,
and the MyAnonaMouse torrent client that feeds both.

| Service | Image | Port | Purpose |
| :-- | :-- | :-- | :-- |
| `calibre-web-automated` | `crocodilestick/calibre-web-automated` | `8083` | Ebook library + auto-ingest |
| `audiobookshelf` | `ghcr.io/advplyr/audiobookshelf` | `13378` | Audiobook library and player |
| `mam` | `lscr.io/linuxserver/qbittorrent:5.1.0` | `8089`* | MyAnonaMouse torrent client |
| `seedboxapi` | `myanonamouse/seedboxapi` | — | Keeps the MAM session pinned to the VPN IP |

\* published by the gluetun stack — see Networking.

---

## Networking

`mam` and `seedboxapi` have **no network stack of their own**. They share the
namespace of the `gluetun` container defined in [`../gluetun`](../gluetun), so
their traffic leaves through the VPN behind gluetun's killswitch.

Three things follow from that, and they are easy to trip over:

1. **`container:` not `service:`.** The `network_mode: "service:gluetun"` form
   only resolves inside a single compose project. Across stacks you address the
   container directly — `network_mode: "container:gluetun"` — which is what
   compose lowers `service:` to anyway.
2. **Their ports are published elsewhere.** A container without its own network
   stack cannot publish a port from its own compose file. MAM's WebUI mapping
   (`8089`) lives in `../gluetun/docker-compose.yml`. Change it there.
3. **`depends_on` cannot cross projects.** Bring `services/gluetun` up *first*.
   And if gluetun is ever recreated — an image pull, a compose up after an edit —
   run `../gluetun/restart-dependents.sh`. The namespace is pinned by container
   **ID**, so a recreated gluetun leaves `mam` and `seedboxapi` attached to an ID
   that no longer exists. The failure is silent: they keep reporting `running`
   while having no network at all.

`calibre-web-automated` and `audiobookshelf` use normal bridge networking and
are unaffected by any of this.

---

## Importing

Two scripts move finished downloads into the libraries. Both are idempotent and
safe to re-run by hand; both are driven by systemd timers every 15 minutes — see
[Automation](#automation).

### `import-new-books.sh`

Copies ebooks out of `/mnt/torrents/books` into `./ingest/`, which
calibre-web-automated watches. Deduplicates on the sha256 of each file.

**Only the preferred format of a book is imported.** `FORMAT_PRIORITY` is an
*ordered* list — `epub mobi azw3 pdf djvu cbz cbr` — and an extension absent
from it is never imported at all. Files are grouped by directory + basename
stem, and within a group the earliest-listed format wins:

```
Dune/                          Bundle/
  Dune.epub   <- imported        Dune.epub        <- imported
  Dune.mobi   <- superseded      Foundation.epub  <- imported
  Dune.pdf    <- superseded      Neuromancer.mobi <- imported
```

Grouping per *directory* is what keeps a bundle torrent intact: those three
titles have different stems, so all three survive. The limitation is the mirror
image — `Dune.epub` and `Dune (retail).mobi` have different stems too, so both
import. That is the pre-existing behaviour and preferable to guessing at title
equality from filenames.

**Settle is evaluated per group, not per file.** If `Dune.epub` is still
downloading while `Dune.mobi` is complete, importing the mobi now would mean
importing the epub as a second copy minutes later. The whole group waits until
every member has been quiet for 5 minutes.

Each file is staged as `.importing-<name>` and renamed into place only once
complete — the dot prefix matters, because CWA is watching that directory. Free
space is checked before each copy. A name already present in `ingest/` gets a
short hash suffix rather than being overwritten: ingest is transient, so a
colliding name is a *different* book still waiting to be processed, not this one
already done.

Flags: `--dry-run` (preview), `--adopt-all` and `--force` (see State).

### `import-new-audiobooks.sh`

Copies audiobooks out of `/mnt/torrents/audiobooks` straight into
`/mnt/media/audiobooks` — Audiobookshelf reads the library directly, there is no
ingest folder. Run with `--dry-run` to preview.

It differs from the ebook script in two deliberate ways:

- **The unit of import is the top-level entry**, not the individual file. An
  audiobook is usually a *folder* (`Mistborn/`, or a 109-part Monte Cristo), and
  Audiobookshelf derives the book and its part ordering from that folder.
  Flattening files the way the ebook script does would turn one book into a
  hundred unrelated ones. It follows that format preference does not apply here:
  there is nothing to choose between.
- **The fingerprint is path + size, not a content hash.** Content-hashing the
  library means re-reading ~25 GB on every run. Sizes still catch the cases that
  matter: a new part, a replaced file, a truncated download.

It also copies rather than hardlinks — `/mnt/torrents` (ext4) and `/mnt/media`
(zfs) are separate filesystems, so hardlinks are impossible. Downloads stay put
for seeding. Each entry is staged as `.importing-<name>` and renamed into place
only once complete, so Audiobookshelf never scans a half-written book. Entries
modified in the last 5 minutes are skipped as still-downloading, and free space
is checked before each copy.

### State

State lives in `imported-books-hashes.txt` and `imported-audiobooks-hashes.txt`.
Both are **gitignored**: they are state, not config, rewritten on every timer
run. restic covers them as part of `HOMELAB_DIR`, which is the actual recovery
path — a `git clone` alone will not bring them back.

Audiobooks already sitting in the library are *adopted* into the hash DB rather
than re-copied. **The ebook script has no equivalent**, and cannot have a
reliable one: calibre renames files on import (`Andy Weir - Project Hail
Mary.epub` becomes `Project Hail Mary - Andy Weir.epub`), so matching library
filenames against download filenames produces constant false negatives.

Instead it refuses to start when the hash DB is empty but five or more books are
waiting — the shape of a lost or unrestored DB, not of a genuine first run — and
tells you to pick:

```sh
./import-new-books.sh --adopt-all   # record them all, copy nothing
./import-new-books.sh --force       # yes, really import all of them
```

That turns the failure worth worrying about, an ingest folder flooded with the
entire back catalogue, from something silent into something loud.

---

## Automation

| Unit | Runs | Timeout |
| :-- | :-- | :-- |
| `books-import.timer` | every 15 min | 1 h |
| `audiobook-import.timer` | every 15 min | 6 h |

Unit files live in `/etc/systemd/system/`. Both services are `Type=oneshot` and
run as **`User=<user>`** — the host user owning the libraries. That is
load-bearing, not tidiness: both containers run `PUID=1000`, and root-owned
files in `ingest/` or `/mnt/media/audiobooks` would be unmanageable by CWA and
Audiobookshelf.

`Persistent=false`, because a missed tick has nothing to catch up on — the next
one picks up whatever is sitting there. The audiobook timeout is six hours
against the books' one: a single audiobook copy can be 25 GB across a filesystem
boundary.

**No lockfile is needed.** systemd will not start a second instance of a
`oneshot` service that is still running, so a long copy spanning several ticks
cannot stack.

**Why a timer and not qBittorrent's `[AutoRun]`.** `mam` runs inside gluetun's
network namespace with different in-container paths and no access to these
scripts. A timer also catches files dropped into the download dirs by hand,
which an on-completion hook never would.

### Monitoring

Ping URLs live in `/etc/homelab-import.env`, mode `0600` (unit files are
world-readable, so they cannot go in the unit). `ExecStopPost` pings on success
and `/fail` otherwise, then exits `0` so a failed *ping* never masks a successful
*import* — an unreachable Healthchecks host still goes red on its own via the
dead man's switch.

Success pings **unconditionally**, including runs that import nothing. That is
what keeps "no new downloads this week" and "the importer is dead"
distinguishable, and it is why the checks can be tight: period 1 h, grace 2 h.

### Operating them

```sh
systemctl list-timers '*import*'
systemctl status books-import.service
journalctl -u audiobook-import.service -n 50

# Run one now, outside the schedule:
sudo systemctl start books-import.service

# Preview without touching anything:
./import-new-books.sh --dry-run
```

---

## Environment Variables

| Variable | Description |
| :-- | :-- |
| `CALIBRE_WEB_HOMEPAGE_URL` | URL the homepage dashboard links to for Calibre-Web. |
| `CALIBRE_WEB_PORT` | Host port for Calibre-Web (default `8083`). |
| `CALIBRE_LIBRARY_PATH` | Host path to the Calibre library. |
| `HARDCOVER_API_KEY` | Hardcover token, used as a metadata provider. |
| `AUDIOBOOKSHELF_URL` | URL the homepage dashboard links to for Audiobookshelf. |
| `AUDIOBOOKSHELF_API_KEY` | API key for the Audiobookshelf homepage widget. |
| `MAM_URL` | URL the homepage dashboard links to for MAM. |
| `MAM_USERNAME` / `MAM_PASSWORD` | Credentials for the MAM qBittorrent homepage widget. |
| `MAM_SESSION_ID` | Session ID for the seedboxapi container. |
| `TZ` | Timezone for all containers (TZ identifier). |
| `MEDIA_ROOT` | Host path to the bulk media library. |
| `TORRENT_ROOT` | Host path to the torrent download root. |

---

## Setup

1. `cp .env.example .env` and fill in the blanks.
2. Bring up the VPN first: `cd ../gluetun && docker compose up -d`.
3. `docker compose up -d` here.

## Notes

- `seedboxapi` deliberately has **no restart policy**. It exits `1` when
  MyAnonaMouse refuses a seedbox IP update (`"Last change too recent"` — MAM
  rate-limits how often the session IP may move, roughly hourly). Under a
  restart policy that becomes a loop hammering their API every few seconds.
  If the VPN exit IP changes, wait out the cooldown and start it again.
- `backup.sh` / `restore.sh` dump each service's sqlite databases into
  `db-dump/<service>/`. The per-service subdirectory is not cosmetic: a shared
  dump directory would let equal basenames overwrite each other silently.
  The Calibre library and the audiobook files are bulk data on `/mnt/media` and
  are out of scope for those scripts.
