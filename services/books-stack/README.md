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
safe to re-run or cron.

### `import-new-books.sh`

Copies ebooks out of `/mnt/torrents/books` into `./ingest/`, which
calibre-web-automated watches. Deduplicates on the sha256 of each file.

### `import-new-audiobooks.sh`

Copies audiobooks out of `/mnt/torrents/audiobooks` straight into
`/mnt/media/audiobooks` — Audiobookshelf reads the library directly, there is no
ingest folder. Run with `--dry-run` to preview.

It differs from the ebook script in two deliberate ways:

- **The unit of import is the top-level entry**, not the individual file. An
  audiobook is usually a *folder* (`Mistborn/`, or a 109-part Monte Cristo), and
  Audiobookshelf derives the book and its part ordering from that folder.
  Flattening files the way the ebook script does would turn one book into a
  hundred unrelated ones.
- **The fingerprint is path + size, not a content hash.** Content-hashing the
  library means re-reading ~25 GB on every run. Sizes still catch the cases that
  matter: a new part, a replaced file, a truncated download.

It also copies rather than hardlinks — `/mnt/torrents` (ext4) and `/mnt/media`
(zfs) are separate filesystems, so hardlinks are impossible. Downloads stay put
for seeding. Each entry is staged as `.importing-<name>` and renamed into place
only once complete, so Audiobookshelf never scans a half-written book. Entries
modified in the last 5 minutes are skipped as still-downloading, and free space
is checked before each copy.

State lives in `imported-books-hashes.txt` and `imported-audiobooks-hashes.txt`.
Books already present in the library on first run are *adopted* into the hash DB
rather than re-copied.

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
