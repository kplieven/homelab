## Babybuddy Container Setup

This directory contains the configuration for running [Babybuddy](https://github.com/babybuddy/babybuddy) — a self-hosted baby tracking application using Docker Compose.

---

**What This Setup Does**

- Deploys Babybuddy for tracking feedings, diaper changes, sleep, tummy time, and more.
- Provides a clean web interface for logging baby care activities.
- Persistent storage for all tracking data.
- Integrates with the Homepage dashboard.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the homepage will link to. |
| `PORT` | Port the Babybuddy service will be exposed on (default: 1234). |


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

5. **Access Babybuddy** at:
    - `http://localhost:1234` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

6. **Create your account** and start tracking (default account is admin:admin).

---

## Notes

- Configuration data is stored in the `./config` directory.
- All data persists across container restarts.
- Timezone is set to Europe/Brussels; adjust in `docker-compose.yml` if needed.
- Homepage integration is configured via Docker labels.
- Default credentials may need to be set on first login.
- The application supports timers for tracking ongoing activities like feedings and sleep.
- Data can be exported for backup or analysis purposes.
