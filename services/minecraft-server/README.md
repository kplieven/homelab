## Minecraft Server Container Setup

This directory contains the configuration for running a [Minecraft server](https://github.com/itzg/docker-minecraft-server) — using Docker Compose.

---

**What This Setup Does**

- Deploys a Minecraft Java Edition server for players on your network or over VPN.
- Persists worlds, plugins and server configuration under `./data` as a bind mount.
- Applies a hard memory ceiling so the server cannot exhaust host RAM.
- Integrates with [homepage](https://gethomepage.dev/) via container labels.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `PORT` | Port the Minecraft server will be exposed on (default: 25565). |
| `MEM_LIMIT` | Hard memory ceiling for the container (default: 1500m). |
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

5. **Connect** from the Minecraft client using your server IP and `PORT`.

---

## Notes

- `EULA=true` accepts the [Minecraft EULA](https://www.minecraft.net/eula) on your behalf; the server refuses to start without it.
- `MEM_LIMIT` is a hard container limit. Raise it before increasing the JVM heap, or the server will be OOM-killed.
- World data lives in `./data` and is captured by the normal restic backup — there is no database to dump, so this service has no `backup.sh`.
- This service has no web UI, so its homepage entry carries no `href`.
- Stop the service with the repo's disable mechanism (a `.disabled` marker) rather than leaving it running idle.
