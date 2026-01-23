## Linkwarden Container Setup

This directory contains the configuration for running [Linkwarden](https://linkwarden.app/) — a self-hosted bookmark manager with collaboration features — using Docker Compose.

---

**What This Setup Does**

- Deploys Linkwarden for organizing and managing bookmarks.
- Uses PostgreSQL as the backend database.
- Includes MeiliSearch for fast full-text search capabilities.
- Supports collections, tags, and collaboration features.
- Automatically archives bookmarked pages for offline access.
- Provides browser extensions for easy bookmark saving.

---

## Environment Variables

This service uses two environment files:

### `.env` - Host Configuration

| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the homepage will link to. |
| `PORT` | Port the Linkwarden service will be exposed on (default: 3333). |
| `POSTGRES_PASSWORD` | PostgreSQL database password. |

### `docker-compose.env` - Container Configuration

| Variable | Description |
| :-- | :-- |
| `NEXTAUTH_URL` | The URL for NextAuth authentication callbacks (port must match `PORT` in `.env`). |
| `NEXTAUTH_SECRET` | Secret key for NextAuth session encryption (generate a random string). |
| `MEILI_MASTER_KEY` | MeiliSearch master key for search functionality. |

---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your environment files by copying the examples:

```sh
cp .env.example .env
cp docker-compose.env.example docker-compose.env
```

3. **Edit `.env`** and fill in your values:
    - Set `URL` to your desired access URL
    - Generate a secure `POSTGRES_PASSWORD`

4. **Edit `docker-compose.env`** and fill in your values:
    - Generate a secure `NEXTAUTH_SECRET` with: `openssl rand -base64 32`
    - Generate a secure `MEILI_MASTER_KEY`
    - Ensure `NEXTAUTH_URL` port matches `PORT` in `.env`

5. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

6. **Access Linkwarden** at:
    - `http://localhost:3333` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

7. **Create your account** and start organizing bookmarks.

---

## Notes

- PostgreSQL data is stored in the `./pgdata` directory.
- Linkwarden data and archived pages are stored in the `./data` directory.
- MeiliSearch index data is stored in the `./meili_data` directory.
- All data persists across container restarts.
- Browser extensions are available for Chrome, Firefox, and other browsers.
- Archived pages allow offline access to bookmarked content.
- Collections can be shared with other users for collaboration.
- Tags and filters help organize large bookmark collections.
- Homepage integration is configured via Docker labels.