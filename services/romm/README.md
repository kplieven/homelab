## RomM Container Setup

This directory contains the configuration for running [RomM](https://romm.app/) — a self-hosted retro game library manager with in-browser emulation — using Docker Compose.

---

**What This Setup Does**

- Scans a ROM library and matches games against IGDB, ScreenScraper, RetroAchievements, SteamGridDB and Hasheous.
- Plays supported systems in the browser (EmulatorJS / RuffleRS).
- Stores uploaded saves, save states and screenshots per user.
- Runs a MariaDB database alongside RomM, dumped nightly by `backup.sh`.

---

## Environment Variables

The `.env.example` file should define the following variables:

| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the homepage will link to. |
| `PORT` | Port RomM will be exposed on (default: 8742). |
| `TZ` | Timezone for the container, as a TZ identifier (e.g. `Etc/UTC`). |
| `ROMM_LIBRARY` | Host path of the game library. Compose refuses to start while it is empty. |
| `ROMM_AUTH_SECRET_KEY` | Session signing key. Generate with `openssl rand -hex 32`. Changing it logs everyone out. |
| `DB_PASSWD` | Password of the `romm-user` MariaDB account. |
| `MARIADB_ROOT_PASSWORD` | MariaDB root password. Only needed to initialise an empty database. |
| `IGDB_CLIENT_ID` / `IGDB_CLIENT_SECRET` | IGDB (Twitch) API credentials. |
| `SCREENSCRAPER_USER` / `SCREENSCRAPER_PASSWORD` | ScreenScraper account. |
| `RETROACHIEVEMENTS_API_KEY` | RetroAchievements web API key. |
| `STEAMGRIDDB_API_KEY` | SteamGridDB API key. |
| `HOMEPAGE_USERNAME` / `HOMEPAGE_PASSWORD` | RomM login the Homepage widget uses. Create a viewer account for it. |

---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

4. **Lay out the library** under `ROMM_LIBRARY` as `roms/<platform>/...` — see the [folder structure docs](https://docs.romm.app/latest/getting-started/folder-structure/).

5. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

6. **Access RomM** at:
    - `http://localhost:8742` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

7. **Create the admin account** in the setup wizard, then a viewer account for the Homepage widget.

---

## Backup & Restore

`backup.sh` dumps the database to `db-dump/romm.sql` with `mariadb-dump --single-transaction`.
The raw `database/` directory and the `redis-data/` cache are excluded from restic; `assets/`
(saves and states), `resources/` and `config/` are backed up as plain files. The game
library itself lives outside this directory and is not covered.

To restore, start only the database so RomM's startup migrations don't race the replay:

```sh
docker compose up -d romm-db
./restore.sh
docker compose up -d
```

---

## Notes

- `resources/` holds downloaded cover art and screenshots; it can be re-fetched by a metadata rescan, but that is slow.
- `config/config.yml` is where platform folder bindings and exclusions go.
