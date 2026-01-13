## AdGuard Home Container Setup

This directory contains the configuration for running [AdGuard Home](https://adguardhome.net/) — a network-wide ad and tracker blocker — using Docker Compose.

---

**What This Setup Does**

- Deploys AdGuard Home as a DNS server with ad-blocking capabilities.
- Provides DNS-level filtering for your entire network.
- Includes DHCP server functionality.
- Offers a web interface for configuration and statistics.
- Persistent configuration and data storage.
- Integrates with Homepage dashboard with widget support for real-time statistics.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `HOMEPAGE_URL` | The URL that Homepage will link to for AdGuard Home access. |
| `HOMEPAGE_WIDGET_URL` | The URL for the Homepage widget to connect to (typically same as HOMEPAGE_URL). |
| `PORT` | Port the Filebrowser service will be exposed on (default: 3009). |
| `USERNAME` | Username for AdGuard Home authentication (for Homepage widget). |
| `PASSWORD` | Password for AdGuard Home authentication (for Homepage widget). |


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

5. **Access AdGuard Home** at:
    - `http://localhost:3009` (mapped from internal port 3000)
    - Or via your configured URL through Caddy
    - Follow the initial setup wizard to configure your admin credentials

6. **Configure your devices** to use AdGuard Home as their DNS server:
    - Set DNS to your server's IP address
    - Or configure your router to use AdGuard Home as the primary DNS

---

## Notes

- Configuration files are stored in the `./config` directory.
- Data and statistics are stored in the `./data` directory.
- The container exposes multiple ports for DNS, DHCP, DoT, DoH, and other protocols.
- Initial setup creates default configuration files on first run.
- To enable DHCP server, configure it through the web interface after initial setup.
- For optimal security, change the default admin password during initial setup.
- Homepage widget integration shows query statistics and blocked domains.
- Timezone is set to Europe/Brussels; adjust in `docker-compose.yml` if needed.
