## Vaultwarden Container Setup

This directory contains the configuration for running [Vaultwarden](https://github.com/dani-garcia/vaultwarden) — an unofficial Bitwarden-compatible server — using Docker Compose.

---

**What This Setup Does**

- Deploys Vaultwarden as a self-hosted password manager.
- Compatible with official Bitwarden clients (web, mobile, desktop, browser extensions).
- Lightweight and resource-efficient alternative to official Bitwarden server.
- Includes automated backup script with cloud sync.
- Supports organizations, collections, and password sharing.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `ADMIN_TOKEN` | Admin panel access token (hashed). Generate with vaultwarden. |
| `URL` | The URL that will be used to access Vaultwarden (must be HTTPS in production). |
| `PORT` | Port for the Vaultwarden web interface (default: 8484). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Generate an admin token**:

```sh
docker run --rm -it vaultwarden/server /vaultwarden hash
```

Enter a strong password when prompted. Copy the output hash to `ADMIN_TOKEN` in your `.env` file.

4. **Edit `.env`** and fill in your remaining values.

5. **Run the container** with Docker Compose:

```sh
docker compose up -d
```

6. **Access Vaultwarden** at:
    - Via your configured URL through Caddy (HTTPS required for full functionality)

7. **Create your account**:
    - Navigate to your Vaultwarden URL
    - Click "Create Account"
    - Set up your master password
    - Start using Vaultwarden with Bitwarden clients

---

## Backup

An automated backup script is provided:

1. **Copy the example backup script**:

```sh
cp backup.sh.example backup.sh
```

2. **Edit `backup.sh`** and configure:
    - `BACKUP_DIR`: Local backup destination
    - `RCLONE_REMOTE`: Your rclone remote name
    - `RCLONE_DESTINATION`: Cloud backup path
    - Retention policy settings

3. **Make the script executable**:

```sh
chmod +x backup.sh
```

4. **Test the backup**:

```sh
./backup.sh
```

5. **Schedule with cron** for automatic backups:

```sh
# Add to crontab for daily backups at 3 AM
0 3 * * * /path/to/vaultwarden/backup.sh >> /path/to/vaultwarden/backup.log 2>&1
```

---

## Admin Panel

Access the admin panel at `/admin` using your `ADMIN_TOKEN`:

- View and manage users
- Configure server settings
- Monitor diagnostics
- Manage organizations
- View system information

---

## Notes

- All data is stored in the `./data` directory including:
  - SQLite database (`db.sqlite3`)
  - Attachments
  - Sends (temporary file sharing)
  - Configuration
  - RSA keys
- The container runs on port 81 and is mapped to port 80 internally.
- **HTTPS is required** for full functionality (browser extensions, U2F, etc.).
- Configure HTTPS via Caddy or your reverse proxy.
- After creating accounts, consider disabling signups via admin panel.
- WebSocket support is built-in for real-time synchronization.
- Compatible with all official Bitwarden clients without modification.
- Regular backups are critical for password management systems.
- The backup script creates timestamped archives including all vault data.
- Homepage integration available via Docker labels.
