## Many Notes Container Setup

This directory contains the configuration for running Many Notes — a self-hosted note-taking and synchronization service — using Docker Compose.

---

**What This Setup Does**

- Deploys Many Notes for centralized note management and synchronization.
- Uses Typesense for full-text search capabilities.
- Provides persistent storage for notes, vaults, and metadata.
- Database backend for reliable data storage.
- Supports multiple clients and synchronization across devices.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that will be used to access Many Notes. |
| `PORT` | Port the Many Notes service will be exposed on (default: 8012). |


---

## Setup Instructions

>[!NOTE]
You must create these empty folders prior to running the container: `database`, `logs`, `private` and `typesense`

1. **Enter** the directory containing this setup.

2. **Create required directories**:

```sh
mkdir -p database logs private typesense
```

3. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

4. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

5. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

6. **Access Many Notes** at:
    - `http://localhost:8012` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

---

## Notes

- Database files are stored in the `./database` directory.
- Private vaults are stored in `./private/vaults/`.
- Typesense search index is stored in `./typesense/` subdirectories (db, meta, models, state).
- Log files are available in the `./logs` directory.
- All data persists across container restarts.
