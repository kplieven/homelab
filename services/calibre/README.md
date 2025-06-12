## Calibre \& Calibre-Web Docker Setup

This directory contains the configuration for running [Calibre](https://calibre-ebook.com/) and [Calibre-Web](https://github.com/janeczku/calibre-web) in your homelab using Docker Compose. Both services are configured for easy integration with a homepage dashboard and persistent storage.

---

**What This Setup Does**

- Deploys Calibre for full-featured ebook management and conversion, with GUI and content server interfaces.
- Deploys Calibre-Web for a modern web interface to browse, read, and manage your Calibre library.
- Integrates both services with [homepage](https://gethomepage.dev/) dashboards, including widget support for Calibre-Web.
- Uses environment variables for flexible configuration of ports, URLs, credentials, and data paths.

---

## Environment Variables

The `.env.example` file defines the following variables:


| Variable | Description |
| :-- | :-- |
| `CALIBRE_HOMEPAGE_URL` | URL for the Calibre GUI, used in the homepage dashboard. |
| `CALIBRE_GUI_PORT` | Port for Calibre's web GUI (default: 8183). |
| `CALIBRE_GUI_HTTPS_PORT` | Port for Calibre's web GUI over HTTPS (default: 8182). |
| `CALIBRE_WEBSERVER_PORT` | Port for Calibre's content server (default: 8184). |
| `CALIBRE_WEB_HOMEPAGE_URL` | URL for Calibre-Web, used in the homepage dashboard. |
| `CALIBRE_WEB_PORT` | Port for Calibre-Web (default: 8083). |
| `CALIBRE_WEB_USERNAME` | Username for Calibre-Web, used by the homepage widget for authentication. |
| `CALIBRE_WEB_PASSWORD` | Password for Calibre-Web, used by the homepage widget for authentication. |
| `PATH_TO_DATA` | Path on your host where your Calibre library and ebook files are stored. |


---

## Setup Instructions

1. **Enter** the directory containing this setup.
2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values:
    - `CALIBRE_HOMEPAGE_URL`: Set to the URL where Calibre's GUI will be accessible (e.g., `http://yourdomain:8183`).
    - `CALIBRE_GUI_PORT`, `CALIBRE_GUI_HTTPS_PORT`, `CALIBRE_WEBSERVER_PORT`: Set ports as desired, or use defaults.
    - `CALIBRE_WEB_HOMEPAGE_URL`: Set to the URL where Calibre-Web will be accessible (e.g., `http://yourdomain:8083`).
    - `CALIBRE_WEB_PORT`: Set port as desired, or use default.
    - `CALIBRE_WEB_USERNAME` and `CALIBRE_WEB_PASSWORD`: Set for homepage widget integration.
    - `PATH_TO_DATA`: Set to the absolute path on your host for Calibre library storage.
4. **Prepare your data folder**:
    - Ensure the path you set in `PATH_TO_DATA` exists and contains your Calibre library (or is empty for a new library).
    - If you don't have a Calibre library yet, you need to create one in the Calibre container first, then point to it in Calibre-web.
5. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

6. **Access your services** either through Caddy or at:
    - Calibre GUI: `http://<SERVER_IP>:8183` (or your chosen `CALIBRE_GUI_PORT`)
    - Calibre GUI (HTTPS): `https://<SERVER_IP>:8182` (or your chosen `CALIBRE_GUI_HTTPS_PORT`)
    - Calibre Content Server: `http://<SERVER_IP>:8184` (or your chosen `CALIBRE_WEBSERVER_PORT`)
    - Calibre-Web: `http://<SERVER_IP>:8083` (or your chosen `CALIBRE_WEB_PORT`)

---

## Notes

- Both containers use the [linuxserver.io](https://www.linuxserver.io/) images, which are well-maintained and support additional mods.
- Timezone and user/group IDs are set for compatibility with your host system. Adjust `PUID` and `PGID` in the `docker-compose.yml` if needed.
- All configuration and library data are stored in the `./calibre/config`, `./calibre-web/config`, and inside your `PATH_TO_DATA` directory on your host.
- The provided labels enable seamless integration with [homepage](https://gethomepage.dev/) dashboards, including Calibre-Web widget support.

