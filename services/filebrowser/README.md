## Filebrowser Container Setup

This directory contains the configuration for running [Filebrowser](https://filebrowser.org/) — a self-hosted, web-based file manager for your homelab — using Docker Compose. The setup provides a simple, secure interface for managing files, with persistent storage and customizable access controls.

---

**What This Setup Does**

- Deploys Filebrowser for easy, browser-based file management on your homelab.
- Exposes a directory of your choice as a read-only file browser.
- Persists your Filebrowser database and settings for reliable access and configuration.
- Runs the container with specific user/group IDs for correct file permissions.
- Integrates with your Homepage dashboard via Docker labels for seamless navigation.

---

## Environment Variables

The `.env.example` file defines the following variables:


| Variable | Description |
| :-- | :-- |
| `HOMEPAGE_URL` | The URL that Homepage will link to for Filebrowser access. |
| `PORT` | Port the Filebrowser service will be exposed on (default: 5040). |
| `BROWSER_ROOT_PATH` | The root directory to expose in Filebrowser (e.g., `/mnt/data`). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.
2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).
4. **Prepare configuration files**:
    - Ensure `filebrowser.db` exists (create an empty file if needed).
    - Edit `settings.json` to customize Filebrowser settings if desired.
5. **Run the container** with Docker Compose:

```sh
docker compose up -d
```

6. **Access Filebrowser** at:
    - `http://localhost:5040` (or your chosen `PORT`)
    - Or via your Homepage dashboard link

---

## Notes

- **Default Credentials**: The first time you access Filebrowser, use `admin` / `admin` as credentials. Change these immediately for security.
- **Persistent Data**: The database (`filebrowser.db`) and settings (`settings.json`) are mapped as volumes for persistent storage.
- **Permissions**: The container runs as the user/group IDs specified by `PUID` and `PGID`. Adjust these in the Docker Compose file or `.env` if needed to match your host system.
- **Read-Only Access**: The root directory is mounted as read-only (`:ro`). Remove `:ro` if you want write access.
- **Homepage Integration**: Docker labels allow Filebrowser to appear in your Homepage dashboard with the correct group, name, icon, and URL.

