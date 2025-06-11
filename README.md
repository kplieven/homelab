# Homelab Docker Stack

A collection of self-hosted services running on Docker for personal homelab setup. All services are containerized and managed through Docker Compose for easy deployment, maintenance, and scalability.

## 🏠 What is this?

This repository contains a complete homelab infrastructure setup featuring:
- **Media Management**: Automated movie/TV downloading and streaming
- **Document Management**: Digital document organization and OCR
- **Home Automation**: Smart home control and monitoring
- **Security**: Password management and secure access
- **Productivity**: Note-taking, file sharing, and dashboard
- **Infrastructure**: Reverse proxy, monitoring, and backups

## 🚀 Quick Start

### Prerequisites

#### Required Software
- **Docker**: Version 20.10+ ([Installation Guide](https://docs.docker.com/get-docker/))
- **Docker Compose**: Version 2.0+ ([Installation Guide](https://docs.docker.com/compose/install/))
- **Git**: For cloning the repository

#### Optional Requirements
- **Domain name**: For external access with SSL certificates
- **VPN subscription**: For secure downloading (media stack)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/kplieven/homelab.git
   cd homelab
   ```

2. **Set up environment files**:
   ```bash
   # Copy all environment templates
   find services/ -name "*.env.example" -exec sh -c 'cp "$1" "${1%.example}"' _ {} \;
   ```

3. **Configure services**:

   - Configure `.env` files for each service. Read the information on the README files of each service for more details of what each variable does. (still todo!)

4. **Start the stack**:
   ```bash
   # Update and run all containers
   ./scripts/update-and-run-containers.sh
   ```

5. **Access your services**:
   - Dashboard: `http://localhost:3000` (or your configured domain)
   - Individual services: See [Service Overview](#-service-overview) below

## 🏗️ Architecture

```
Internet → Router/Firewall → Caddy (Reverse Proxy)
                                  ↓
        ┌─────────────────┬─────────────────┬─────────────────┐
        │   Media Stack   │   Productivity  │   Security      │
        │                 │                 │                 │
        │ • Jellyfin      │ • Paperless     │ • Vaultwarden   │
        │ • Radarr        │ • File Browser  │ • Home Assistant│
        │ • Sonarr        │ • PDF editor    │                 │
        │ • qBittorrent   │ • ...           │                 │
        └─────────────────┴─────────────────┴─────────────────┘
                                  ↓
                      Shared Storage & Backups
```

### Directory Structure
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

## 📋 Service Overview

### 🌐 Infrastructure
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Caddy](services/caddy/) | Reverse proxy & SSL | 80, 443, 2019 (admin) | ✅ Production |
| [Homepage](services/homepage/) | Central dashboard | 3000 | ✅ Production |

### 🎬 Media
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Media Stack](services/media-stack/) | Complete media automation | Various | ✅ Production |
| ↳ Jellyfin | Media server & streaming | 8096 | ✅ Production |
| ↳ Jellyseerr | Media request management | 5055 | ✅ Production |
| ↳ Radarr | Movie management | 7878 | ✅ Production |
| ↳ Sonarr | TV management | 8989 | ✅ Production |
| ↳ Prowlarr | Indexer management | 9696 | ✅ Production |
| ↳ Bazarr | Subtitle management | 6767 | ✅ Production |
| ↳ qBittorrent | Download client | 8080 | ✅ Production |
| ↳ qBittorrent (MyAnonaMouse) | Download client for MAM | 8089 | ✅ Production |
| ↳ Audiobookshelf | Audiobook server | 13378 | ✅ Production |

### 📄 Documents
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Paperless-NGX](services/paperless-ngx/) | Document management | 1111 | ✅ Production |
| [Stirling PDF](services/stirling-pdf/) | PDF manipulation | 8484 | ✅ Production |

### 🗃️ Files
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [File Browser](services/filebrowser/) | Web file manager | 5040 | ✅ Production |
| [PairDrop](services/pairdrop/) | Local file sharing | 3000 | ✅ Production |

### 📚 Productivity
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Many Notes](services/many-notes/) | Note-taking app | 8012 | ✅ Production |
| [Homepage](services/homepage/) | Dashboard | 3001 | ✅ Production |

### 📚 [E-books](services/calibre)
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| Calibre | E-book management | 8183 | ✅ Production |
| Calibre-web | Calibre frontend | 8083 | ✅ Production |

### 🔒 Security
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Vaultwarden](services/vaultwarden/) | Password manager | 81 | ✅ Production |

### 🏠 Automation
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Home Assistant](services/home-assistant/) | Home automation | 8123 | ✅ Production |

### 📸 Photos
| Service | Purpose | Port | Status |
|---------|---------|--------------|--------|
| [Immich](services/immich/) | Photo management | 2283 | ✅ Production |

## 🛠️ Management

### Daily Operations

#### Update All Services
```bash
# Update and restart all containers
./scripts/update-and-run-containers.sh

# Update specific service
cd services/SERVICE_NAME
docker-compose pull && docker-compose up -d
```

#### Monitor System Health
```bash
# Check all running containers
docker ps

# View resource usage
docker stats

# Check specific service logs
docker-compose -f services/SERVICE_NAME/docker-compose.yml logs -f
```

### Backup Management

#### Automated Backups
Several services include automatic backup scripts:
- **Paperless-NGX**: Document backup with cloud upload
- **Vaultwarden**: Password database backup

#### Setting Up Cloud Backups
1. Configure [`rclone`](https://rclone.org/docs/) remote
2. Rename `backup.sh.example` to `backup.sh`
3. Fill in the variables at the top the script (configures where to store backups and which rclone remote to use)
4. Set up cron jobs for automation by executing `crontab -e` and adding:
   ```bash
   # Example crontab entry (daily backup at 2 AM)
   0 2 * * * /path/to/homelab/services/paperless-ngx/backup.sh
   ```

## 🔧 Configuration

### Environment Variables

#### Global Configuration
Common variables used across services:

| Variable | Description | Example |
|----------|-------------|---------|
| `URL` | URL that will be used to link in the homepage | `jellyfin.internal` |
| `SERVICE_API_KEY` | API Key of the service that will be used by the homepage to show service specific information | |

#### Service-Specific Configuration
Each service has its own `.env` file with specific settings. See the README of each service to see what each variable is used.

### Network Configuration

#### Reverse Proxy Setup
Caddy automatically handles:
- ✅ SSL certificate generation (Let's Encrypt)
- ✅ HTTP to HTTPS redirects
- ✅ Subdomain routing
- ✅ Load balancing

#### Port Management
- **External Ports**: Only 80 (HTTP) and 443 (HTTPS) exposed, or expose none and connect through a VPN (such as Wireguard or Tailscale)
- **Internal Ports**: Services communicate via localhost network

### Storage Configuration

#### Persistent Data
```bash
# Recommended directory structure
/data/
├── media/              # Media files (movies, TV, music)
│   ├── audiobooks/
│   ├── books/
│   ├── movies/
│   ├── music/
│   └── tv/
├── torrents/           # Torrent files (movies, TV, music)
│   ├── audiobooks/
│   ├── books/
│   ├── movies/
│   ├── music/
│   ├── tv/
│   └── incomplete/     # Incomplete torrents
├── documents/          # Paperless document storage
├── photos/             # Immich photo storage
└── backups/            # Automated backups
```

## 🔒 Security

### Access Control
- **Authentication**: Caddy handles SSL termination
- **Authorization**: Service-level authentication where supported
- **Secret Management**: Environment files excluded from Git

### Security Best Practices
1. **Use strong passwords** for all service accounts
2. **Enable 2FA** where available (Vaultwarden, etc.)
3. **Regular updates** via the update script
4. **Monitor access logs** in Caddy and individual services
5. **Backup encryption** for sensitive data

### Firewall Configuration
These configurations I use for servers that won't be exposed.
Probably requires some additional hardening to protect from outside attacks.

```bash
sudo apt-get install ufw

# Recommended UFW rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

### SSH Configuration
Configure SSH to only allow users on local networks, then disable root SSH login.
To do this, edit your `sshd` configuration file:

```bash
sudo nano /etc/ssh/sshd_config
```

Then at the bottom append:

```
AllowUsers *@172.16.0.0/12 *@10.0.0.0/8 *@192.168.0.0/16

PermitRootLogin no
```

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
1. **Check Docker daemon**: `sudo systemctl status docker`
2. **Verify permissions**: `ls -la services/`
3. **Check logs**: `docker-compose logs SERVICE_NAME`
4. **Validate configuration**: Review `.env` files

#### Network Connectivity Issues
1. **DNS resolution**: `nslookup yourdomain.com`
2. **Port availability**: `netstat -tulpn | grep :80`
3. **Firewall rules**: `sudo ufw status`
4. **Container networking**: `docker network ls`

#### Storage Issues
1. **Disk space**: `df -h`
2. **Permissions**: `ls -la data/`
3. **Mount points**: Check Docker volume mounts
4. **File locks**: Restart affected services

### Getting Help

#### Log Analysis
```bash
# System-wide container status
docker ps -a

# Service-specific logs with timestamps
docker-compose -f services/SERVICE_NAME/docker-compose.yml logs -t --tail=100

# Real-time log monitoring
docker-compose -f services/SERVICE_NAME/docker-compose.yml logs -f
```

## 📚 Documentation

### Service Documentation (TODO!)
- [Caddy Configuration Guide](services/caddy/README.md)
- [Media Stack Setup Guide](services/media-stack/README.md)
- [Paperless-NGX Documentation](services/paperless-ngx/README.md)
- [Vaultwarden Setup Guide](services/vaultwarden/README.md)
- [Home Assistant Configuration](services/home-assistant/README.md)

### External Resources
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Homelab Community](https://www.reddit.com/r/homelab)
- [Self-Hosted Applications](https://github.com/awesome-selfhosted/awesome-selfhosted)

## 🏷️ Changelog

### v1.0.0
- ✅ Initial homelab setup
- ✅ Basic service configuration
- ✅ Docker Compose structure

## ⚠️ Disclaimer

This setup is designed for personal use in a homelab environment. For production deployments, additional security hardening, monitoring, and compliance measures should be implemented.

---

**📧 Support**: For questions or issues, please open a GitHub issue or check the [documentation](docs/).

**⭐ Star this repo** if you find it useful!

