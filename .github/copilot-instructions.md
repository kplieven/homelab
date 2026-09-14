# Copilot Instructions

## Architecture

This is a Docker Compose homelab — each service lives in `services/<name>/` with its own `docker-compose.yml`, `.env`, `.env.example`, and `README.md`. There is no shared orchestration; each service is independently deployable.

Services are exposed through a **Caddy** reverse proxy (`services/caddy/`). The **Homepage** dashboard (`services/homepage/`) auto-discovers services via Docker socket labels — there is no central services config file.

Backup-capable services include a `backup.sh.example` that follows a shared pattern: docker exec → tar with datestamp → `scripts/backup_retention.py` → rclone sync.

## Commands

Update all services:

```sh
./scripts/update-and-run-containers.sh          # pull + restart all
./scripts/update-and-run-containers.sh --dry-run # preview only
```

Single service:

```sh
cd services/<name> && docker compose pull && docker compose up -d
```

Backup retention (dry run by default):

```sh
python3 scripts/backup_retention.py /path/to/backups
python3 scripts/backup_retention.py /path/to/backups --apply
```

## Conventions

### Commit messages

```
<type>: [<Service>] <description>
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`. Service name in brackets. Examples:

```
feat: [Babybuddy] add service
fix: [Caddy] zone was sometimes detected wrongly
docs: [Linkwarden] add Linkwarden to the main README
```

### Adding a new service

1. Create `services/<name>/` with:
   - `docker-compose.yml` — use `restart: unless-stopped`, `env_file: .env`, ports as `${PORT:-default}:internal`
   - `.env.example` — UPPERCASE_WITH_UNDERSCORES, required vars first (empty), defaults/comments below a separator line
   - `README.md` — follows the template: Header → "What This Setup Does" → Environment Variables table → Setup Instructions → Notes
2. Add `homepage.*` labels to the main container in docker-compose for dashboard discovery:
   ```yaml
   labels:
     - homepage.group=<Category>
     - homepage.name=<Display Name>
     - homepage.icon=<icon-name>
     - homepage.href=${URL}
     - homepage.widget.type=<widget-type>
     - homepage.widget.url=${URL}
     - homepage.widget.key=${SERVICE_API_KEY}
   ```
   Groups in use: Infrastructure, Media, Photos, Documents, Security, Productivity, Books, Files, Automation, Download, Family, Tools.
3. Add the service to the root `README.md` in three places: directory tree, service overview table, and documentation links section.
4. Add relevant entries to `.gitignore` if the service produces local state (databases, logs, config dirs).

### .gitignore patterns

- `.env` files are **never committed** (only `.env.example`)
- `backup.sh` is never committed (only `backup.sh.example`)
- Runtime dirs (`config/`, `data/`, `database/`, `logs/`, `storage/`, `private/`) are excluded

### Networking

Services that need to communicate use a `local_network` bridge network defined in their own compose file. Caddy reaches services via `host.docker.internal` or the server's local IP (`${SERVER_IP}`).

### Backup scripts

When creating `backup.sh.example` for a service:

1. Define empty config vars at the top: `BACKUP_DIR`, `RCLONE_REMOTE`, `RCLONE_DESTINATION`
2. Use `docker compose exec` to trigger the service's native backup
3. Archive as `<service>_backup_$(date +%Y%m%d).tar.gz`
4. Call `python3 $SCRIPT_DIR/../../scripts/backup_retention.py $BACKUP_DIR --apply`
5. Sync with `rclone sync`
