## Uptime Kuma Container Setup

This directory contains the configuration for running [Uptime Kuma](https://github.com/louislam/uptime-kuma) — a self-hosted monitoring tool for tracking the uptime of your services — using Docker Compose.

---

**What This Setup Does**

- Deploys Uptime Kuma for monitoring uptime and response times of your services.
- Supports HTTP(S), TCP, DNS, Docker, and ping monitoring.
- Provides status pages, notifications, and incident management.
- Persistent storage for monitoring data and configuration.

---

## Environment Variables

The `.env.example` file should define the following variables:

| Variable | Description |
| :-- | :-- |
| `URL` | The URL that will be used to access Uptime Kuma. |
| `PORT` | Port the Uptime Kuma service will be exposed on (default: `3002`). |

---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create the data directory**:

```sh
mkdir -p data
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

6. **Access Uptime Kuma** at:
    - `http://localhost:3002` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

---

## Notes

- All data is stored in the `./data` directory including the SQLite database.
- On first launch, you will be prompted to create an admin account.
- The default internal port is 3001, mapped to 3002 externally to avoid conflict with Homepage.
- Configure notifications (Telegram, Discord, Slack, email, etc.) from the Uptime Kuma UI.
