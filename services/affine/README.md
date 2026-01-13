## Affine Container Setup

This directory contains the configuration for running [Affine](https://affine.pro/) — an open-source alternative to Notion or Obsidian — using Docker Compose.

---

**What This Setup Does**

- Deploys Affine workspace with full editing and collaboration features.
- Uses PostgreSQL as the backend database.
- Provides persistent storage for workspaces, avatars, blobs, and copilot data.
- Self-hosted alternative to cloud-based note-taking apps.
- Supports real-time collaboration.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `PORT` | Port for the Affine web interface (default: 3010). |
| `URL` | The URL that will be used to access Affine. |
| `DB_USER` | PostgreSQL database username (typically: affine). |
| `DB_PASSWORD` | PostgreSQL database password. |
| `DB_DATABASE` | PostgreSQL database name (typically: affine). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

4. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

5. **Access Affine** at:
    - `http://localhost:3010` (or your chosen `PORT`)
    - Or via your configured URL through Caddy (don't forget to set the host for outgoing links in `.env`!)

---

## Notes

- PostgreSQL data is stored in the `./postgres` directory.
- Affine configuration is stored in the `./config` directory.
- Storage files are organized in `./storage` with subdirectories for avatars, blobs, and copilot.
- All data persists across container restarts.
- The initial setup will guide you through creating your first workspace.
