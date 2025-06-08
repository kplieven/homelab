# Homelab Docker Stack

A collection of self-hosted services running on Docker for my personal homelab setup. All services are containerized and managed through Docker Compose for easy deployment and maintenance.

## 🏗️ Architecture

```
homelab/
├── scripts/                            # Management scripts
│   ├── backup_retention.py             # Automated backup cleanup
│   └── update-and-run-containers.sh    # Update all Docker containers
├── services/                           # Docker services
│   ├── caddy/                          # Reverse proxy & SSL termination
│   ├── calibre/                        # E-book management
│   ├── filebrowser/                    # Web-based file manager
│   ├── home-assistant/                 # Home automation platform
│   ├── homepage/                       # Dashboard/homepage
│   ├── immich/                         # Photo management & backup
│   ├── many-notes/                     # Note-taking application
│   ├── media-stack/                    # Combined media automation stack
│   │   ├── audiobookshelf/             # Audiobook server & player
│   │   ├── bazarr/                     # Subtitle management
│   │   ├── jellyfin/                   # Media server
│   │   ├── jellyseerr/                 # Media request management
│   │   ├── mam/                        # qBittorrent for MyAnonaMouse
│   │   ├── mam-seedboxapi/             # MAM API integration
│   │   ├── prowlarr/                   # Indexer manager
│   │   ├── qbittorrent/                # General torrent client
│   │   ├── radarr/                     # Movie collection manager
│   │   ├── sonarr/                     # TV show collection manager
│   │   └── gluetun/                    # VPN container for downloaders
│   ├── pairdrop/                       # Local file sharing
│   ├── paperless-ngx/                  # Document management system
│   ├── stirling-pdf/                   # PDF manipulation tools
│   └── vaultwarden/                    # Password manager (Bitwarden server)
└── README.md                           # This file
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Basic understanding of Docker
- *OPTIONAL:* Domain name pointed to your server (for Caddy reverse proxy)

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/kplieven/homelab
   cd homelab
   ```

2. **Create environment files:**
   ```bash
   # Copy all .env.example files to .env files
   find services/ -name "*.env.example" -exec sh -c 'cp "$1" "${1%.example}"' _ {} \;
   ```

3. **Edit environment files:**
   Edit each `.env` file in the service directories to match your setup

4. **Start services:**
   ```bash
   ./scripts/update-and-run-containers.sh
   ```

## 🛠️ Management

### Update All Services
```bash
./scripts/update-and-run-containers.sh
```

### Backup Management
Two services have a backup script located in their own folder:
- Paperless-NGX
- Vaultwarden

The backup scripts create a snapshot of the current state and upload it to a cloud storage of your choosing.

There's no need to run the `backup_retention.py` as the backup scripts themselves are already using it.
You can set up a cronjob for these backup scripts to make them run periodically automatically

#### Steps
1. Setup an [rclone](https://rclone.org/) backend
2. Rename `backup.sh.example` to `backup.sh`
3. Fill in the variable at the top of the script
4. Good to go

### Monitor Services
```bash
# Check all running containers
docker ps

# View logs for a specific service
docker-compose -f services/SERVICE_NAME/docker-compose.yml logs -f

# Restart a service
cd services/SERVICE_NAME && docker-compose restart
```

## 🔧 Configuration

### Environment Variables
Each service has its own `.env` file with service-specific configuration. Common variables include:

- `URL` - Your domain name
- `API_KEY` - API keys for homepage widgets

### Caddy Reverse Proxy
The Caddy service automatically handles:
- SSL certificate generation via Let's Encrypt
- Reverse proxy routing to services
- HTTP to HTTPS redirects

Update `services/caddy/Caddyfile` to add new services or modify routing.

## 📁 Data Management

### Persistent Data
- Each service stores its data in dedicated directories
- Data directories are excluded from Git via `.gitignore`, but should be created automatically
- Backup important data directories regularly

### File Permissions
Ensure proper file permissions for mounted volumes:
```bash
# Set ownership for service directories
sudo chown -R $USER:$USER services/
```

## 🔒 Security Considerations

- All `.env` files are excluded from version control
- Sensitive configuration files are not committed to Git
- Use strong passwords and enable 2FA where available
- Keep services updated regularly

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Caddy Documentation](https://caddyserver.com/docs/)

## ⚠️ Disclaimer

This setup is designed for personal use in a homelab environment. For production deployments, additional security hardening and monitoring should be implemented.
