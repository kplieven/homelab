## Media Stack Setup

This directory contains the configuration for running a complete media automation stack using Docker Compose. The stack includes services for automated media downloading, organization, and management.

---

**What This Setup Does**

- **Prowlarr**: Indexer manager and proxy for Radarr/Sonarr/Lidarr.
- **Radarr**: Movie collection manager with automatic downloading.
- **Sonarr**: TV show collection manager with automatic downloading.
- **Bazarr**: Subtitle management for movies and TV shows.
- **qBittorrent**: BitTorrent client for downloading content.
- **Jellyfin**: Media server for streaming your content.
- **Jellyseerr**: Request management for Jellyfin with Radarr/Sonarr integration.
- **Audiobookshelf**: Audiobook and podcast server.

---

## Services Overview

### Prowlarr

Indexer management and integration:
- Centralized indexer configuration
- Automatic sync with Radarr, Sonarr, and other *arr apps
- Indexer health monitoring
- Support for Usenet and torrent indexers

### Radarr

Movie management:
- Automatic movie downloads based on quality profiles
- Library organization and renaming
- Calendar and upcoming releases
- Custom formats and scoring
- Integration with download clients

### Sonarr

TV show management:
- Automatic episode downloads
- Season pack support
- Series monitoring
- Episode file management
- Release profile management

### Bazarr

Subtitle management:
- Automatic subtitle downloads
- Support for multiple languages
- Integration with Radarr and Sonarr
- Multiple subtitle provider support

### qBittorrent

BitTorrent client:
- Web-based interface
- Category and tag management
- Integration with *arr applications
- Sequential downloading support

### Jellyfin

Media server:
- Stream movies, TV shows, music, and more
- Multi-device support
- Hardware transcoding support
- User management and parental controls

### Jellyseerr

Request management:
- User-friendly interface for requesting movies and TV shows
- Integration with Radarr and Sonarr
- User permissions and quotas
- Request approval workflow

### Audiobookshelf

Audiobook server:
- Organize and stream audiobooks
- Podcast support
- Progress tracking
- Mobile apps available

### FlareSolverr

Cloudflare bypass proxy:
- Bypasses Cloudflare protection for indexers
- Required for many public torrent indexers
- Integrates with Prowlarr
- Runs on port 8191

---

## Environment Variables

Each service has its own configuration. A few common ones:

| Variable | Description |
| :-- | :-- |
| `<SERVICE>_API_KEY` | The API key for the corresponding service (for Homepage widget) |
| `<SERVICE>_URL` | The URL that the homepage will link to for each service. |

### VPN (Gluetun)

Check out the [Gluetun wiki](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) for setup guides for various different VPN providers

| Variable | Description |
| :-- | :-- |
| `VPN_SERVICE_PROVIDER` | Your VPN provider |
| `VPN_TYPE` | VPN type (`openvpn` or `wireguard`) |
| `OPENVPN_USER` | OpenVPN username (if using `openvpn`) |
| `OPENVPN_PASSWORD` | OpenVPN password (if using `openvpn`) |

### MyAnonaMouse (MAM)

. If you are not a MyAnonaMouse user you can remove these variables and also remove the `mam` and `seedboxapi` containers from the compose file.

| Variable | Description |
| :-- | :-- |
| `MAM_SESSION_ID` | Session ID for the MAM seedboxapi container. |
| `MAM_USERNAME` | Username for the MAM qBittorrent container (for Homepage widget). |
| `MAM_PASSWORD` | Password for the MAM qBittorrent container (for Homepage widget). |

---

## Setup Instructions

1. **Enter** the media-stack directory.

2. **Configure environment variables**:
    - Create `.env` files from examples in each service subdirectory
    - Set appropriate ports and paths
    - Configure timezone and user permissions

3. **Prepare storage directories**:
    - Create directories for media storage (movies, TV shows, music, etc.)
    - Create directories for downloads
    - Ensure proper permissions

4. **Run the entire stack** with Docker Compose:

```sh
docker compose up -d
```

---

## Integration Guide

### Prowlarr → Radarr/Sonarr

1. In Prowlarr, go to Settings → Apps
2. Add Radarr and Sonarr with their API keys
3. Indexers will sync automatically

### FlareSolverr Setup

For indexers that use Cloudflare protection:

1. In Prowlarr, go to Settings → Indexers → Add Indexer
2. When adding an indexer that requires FlareSolverr, select the FlareSolverr tag
3. Go to Settings → Tags and create a FlareSolverr tag if needed
4. Go to Settings → Indexers → FlareSolverr Proxies
5. Add FlareSolverr with URL: `http://flaresolverr:8191`
6. Assign the tag to indexers that need Cloudflare bypass

### Download Client Setup

1. Configure qBittorrent in each *arr application
2. Set categories/labels for automatic organization
3. Configure completed download handling

### Jellyseerr → Jellyfin/Radarr/Sonarr

1. Connect Jellyseerr to your Jellyfin server
2. Add Radarr and Sonarr with API keys
3. Configure request settings and permissions

---

## Notes

- Configuration for each service is stored in `./service-name/config/` or `./service-name/`.
- All services include Homepage dashboard integration via Docker labels.
- Services communicate via Docker network for security.
- qBittorrent downloads are typically organized by categories.
- Jellyfin supports hardware transcoding if configured properly.
- Regular backups of configuration directories are recommended.
- For troubleshooting, check individual service logs: `docker compose logs -f service-name`.
