## Paperless-ngx Container Setup

This directory contains the configuration for running [Paperless-ngx](https://docs.paperless-ngx.com/) — a document management system that transforms physical documents into a searchable online archive — using Docker Compose.

---

**What This Setup Does**

- Deploys Paperless-ngx with full OCR and document processing capabilities.
- Includes PostgreSQL database, Redis broker, Gotenberg, and Tika services.
- Automatically consumes documents from a watched folder.
- Provides powerful search and tagging features.
- Supports document versioning and correspondence tracking.
- Includes automated backup script with cloud sync via rclone.

---

## Environment Variables

The `docker-compose.env` file defines extensive configuration options. Key variables include:


| Variable | Description |
| :-- | :-- |
| `PAPERLESS_TIME_ZONE` | Timezone for the application. |
| `PAPERLESS_OCR_LANGUAGE` | Primary OCR language (e.g., eng, deu, nld). |
| `PAPERLESS_SECRET_KEY` | Secret key for Django application (generate a random string). |
| `PAPERLESS_OCR_LANGUAGES` | Primary OCR language (e.g., eng, deu, nld). |
| `PAPERLESS_URL` | The external URL for accessing Paperless. |


The `.env` file should also define:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that will be used to access Paperless (for Homepage). |
| `PORT` | Port the Paperless service will be exposed on (default: 1111). |
| `PAPERLESS_API_KEY` | API key for Homepage widget integration. |
| `PATH_TO_DOCUMENTS` | The path Paperless will save documents to. |
| `PATH_TO_SCANS` | The path Paperless will scan for new documents. |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create your environment files** by copying the examples:

```sh
cp .env.example .env
cp docker-compose.env.example docker-compose.env
```

3. **Edit the files** and fill in your values:
    - Generate a secure `PAPERLESS_SECRET_KEY` with: `openssl rand -base64 32`
    - Configure OCR languages, timezone, and other settings
    - Set admin credentials if desired (or create superuser later)

4. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

5. **Create a superuser** (if not using environment variables):

```sh
docker compose run --rm webserver createsuperuser
```

6. **Access Paperless** at:
    - `http://localhost:1111` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

7. **Start scanning documents** by placing them in your configured consume directory.

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
# Add to crontab for daily backups at 2 AM
0 2 * * * /path/to/paperless-ngx/backup.sh >> /path/to/paperless-ngx/backup.log 2>&1
```

---

## Notes

- Export folder is `./export` for manual exports and backups.
- PostgreSQL database is stored in `./database`.
- Configuration data is stored in `./data`.
- All storage persists across container restarts.
- Homepage widget integration shows document count and statistics.
- OCR is performed automatically on all consumed documents.
- Supported formats: PDF, images, Office documents, emails, and more.
- Gotenberg provides Office document conversion support.
- Tika enhances metadata extraction and content parsing.