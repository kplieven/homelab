## Homepage Dashboard Setup

This directory contains the configuration for running [Homepage](https://gethomepage.dev/) — a modern, customizable dashboard for your homelab — using Docker Compose. The setup supports dynamic Docker integration, custom widgets, and a configurable background image.

---

**What This Setup Does**

- Deploys the Homepage dashboard for quick access to all your homelab services.
- Integrates with Docker to automatically display running containers.
- Supports custom widgets for system resources, search, weather, and more.
- Allows you to set a custom background image.
- Uses environment variables for flexible configuration of ports, URLs, and paths.

---

## Environment Variables

The `.env.example` file defines the following variables:


| Variable | Description |
| :-- | :-- |
| `PORT` | Port the Homepage service will be exposed on (default: 3001). |
| `SERVER_IP` | The local IP address of your server (e.g., `192.168.1.100`). |
| `HOMEPAGE_URL` | The URL that will be used to access the Homepage dashboard (e.g., `http://homelab.local`). |
| `BACKGROUND_IMAGE_PATH` | Absolute path to an image on your server to use as the dashboard background. |


---

## Setup Instructions

1. **Enter** the directory containing this setup.
2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables))
4. **Customize your dashboard**:
    - Edit files in `./config/` to configure widgets, layout, Docker integration, and more.
    - Example widget and settings configurations are provided in `settings.yaml` and `widgets.yaml`.
    - To enable weather, update the `openmeteo` widget in `widgets.yaml` with your latitude, longitude, and timezone.
5. **Run the container** with Docker Compose:

```sh
docker compose up -d
```

6. **Access your dashboard** at:
    - `http://localhost:3001` (or your chosen `PORT`)
    - Or via your configured URL through Caddy

---

## Notes

- The dashboard will automatically display running Docker containers if the Docker socket is mounted and `docker.yaml` is configured.
- The background image must be accessible at the path specified by `BACKGROUND_IMAGE_PATH` and will appear as `/images/background.jpg` in the dashboard.
- You can further customize the dashboard by editing the YAML files in the `config` directory. See the [Homepage documentation](https://gethomepage.dev/latest/configuration/) for more options.
- The container runs as user/group IDs specified by `PUID` and `PGID` for correct file permissions.


