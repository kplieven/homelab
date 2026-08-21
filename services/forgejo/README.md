## Forgejo Container Setup

This directory contains the configuration for running [Forgejo](https://forgejo.org/) — a self-hosted lightweight software forge for Git hosting, issues and pull requests — using Docker Compose.

---

**What This Setup Does**

- Deploys Forgejo as a private Git forge for your own repositories.
- Exposes both a web UI and an SSH endpoint for `git push` / `git clone`.
- Stores all repositories, database and configuration under `./data` as a bind mount, so the backup tooling can see it.
- Runs on its own Docker network, isolated from the other stacks.
- Integrates with [homepage](https://gethomepage.dev/) via container labels.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the homepage will link to for Forgejo access. |
| `PORT` | Port the Forgejo web interface will be exposed on (default: 3005). |
| `SSH_PORT` | Host port mapped to Forgejo's SSH daemon for Git over SSH (default: 222). |
| `TZ` | Timezone for the container, as a TZ identifier (e.g. `Etc/UTC`). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

4. **Run the container** with Docker Compose:

```sh
docker compose up -d
```

5. **Access Forgejo** at:
    - `http://localhost:3005` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

6. **Complete the installer** in the browser on first run, then create your admin account.

---

## Notes

- The first user registered becomes the instance administrator; disable open registration afterwards in Forgejo's settings.
- Git over SSH uses `SSH_PORT` on the host (default 222), so clone URLs take the form `ssh://git@<host>:222/<user>/<repo>.git`.
- `USER_UID` / `USER_GID` are set to 1000 so files under `./data` stay owned by the host user.
- All state lives in `./data`; `backup.sh` dumps the database into `db-dump/` so restic never captures a torn copy.
- Restore with `restore.sh`, which refuses to overwrite a live database unless `FORCE=1` is set.
- The image is pinned to a major version (`:15`) rather than `latest`, so upgrades are deliberate.
