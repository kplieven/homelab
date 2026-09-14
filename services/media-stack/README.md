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
- **SuggestArr**: Watches your Jellyfin history and asks Seerr for similar titles.
- **Audiobookshelf**: Audiobook and podcast server.

---

> **Networking:** qBittorrent has no network stack of its own -- it shares the
> namespace of the `gluetun` container defined in [`../gluetun`](../gluetun),
> so its traffic leaves through the VPN. Consequences:
>
> - Bring `services/gluetun` up **before** this stack.
> - qBittorrent's WebUI port (`8080`) is published by the gluetun stack, not here.
> - `depends_on` cannot cross compose projects. If gluetun is ever recreated,
>   run `../gluetun/restart-dependents.sh` -- otherwise qBittorrent keeps
>   pointing at a dead namespace and silently loses all network while still
>   reporting as "running".
>
> Audiobookshelf, MAM and seedboxapi now live in [`../books-stack`](../books-stack).

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

### SuggestArr

Automatic recommendations:
- Reads recently watched items from Jellyfin
- Looks up similar movies/shows on TMDb
- Files the results as requests in Seerr on a cron schedule
- Keeps a record of what it has already asked for, so it does not re-request

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
| `TZ` | Timezone for all containers, as a TZ identifier (e.g. `Etc/UTC`). |
| `MEDIA_ROOT` | Host path to the bulk media library; `media/` and `torrents/` live under it. |
| `SUGGESTARR_PORT` | Port for SuggestArr. Note it is used on **both** sides of the port mapping — the app binds it inside the container too. |
| `SUGGESTARR_LOG_LEVEL` | `info`, `debug`, `warning` or `error`. |

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

### SuggestArr → Jellyfin/Seerr

SuggestArr is configured entirely in its own web UI (`http://<server>:5000`, or
`https://suggestarr.<domain>`). Nothing below can be set from the environment —
it is all written to `suggestarr/config_files/config.yaml`.

1. **TMDb API key.** Required; SuggestArr uses it to find similar titles.
   Get one at [themoviedb.org](https://www.themoviedb.org/settings/api).
2. **Media server.** Choose Jellyfin, point it at `http://jellyfin:8096`
   (same compose network) and give it the Jellyfin API key.
3. **Seerr.** Point it at `http://seerr:5055` with the Seerr API key.
4. **Select the users** whose watch history should drive recommendations.
5. **Set the cron schedule** for how often it should look for new content.

#### Keeping requests pending instead of auto-approved

This is the part that is easy to get wrong, because there are two different
"approval" settings and only one of them does what you want.

A Seerr **API key always acts as an admin**, and admin requests are approved on
arrival. So by default everything SuggestArr files lands in Seerr already
approved and heads straight for Radarr/Sonarr. The fix is to make SuggestArr
authenticate as an ordinary user that lacks the auto-approve permission.

**1. A local Seerr user.** In Seerr: **Users → Create Local User**. It must be a
*local* user — SuggestArr filters the list to users with no Plex or Jellyfin
account attached, so a Jellyfin-backed user will not appear. Its permissions
should be **Request** only: no Auto-Approve, no Auto-Approve Movies/Series, no
Manage Requests, no Admin.

**2. Point SuggestArr at Seerr and press Test Connection.** Use
`http://seerr:5055` — both containers are in this compose project, so the
container name resolves. `http://localhost:5055` is SuggestArr itself and the
test will fail.

**3. Expand Advanced Options.** This is where the option hides, and why it looks
like the Seer step only accepts a URL and a token:

- The **Advanced Options** collapsible does not exist until *after* Test
  Connection succeeds. Before that the step really does show nothing but the two
  fields.
- It is collapsed by default. The grey badge on its right reads **"Using admin
  account"** — that is the tell that requests will be auto-approved.
- Expand it and scroll past *Request Delay* to **User Authentication**
  ("Authenticate as a local user to make requests on their behalf"). Pick the
  user from the dropdown, type its password, press the authenticate button.
- The badge flips to **"User authenticated"**. SuggestArr stores the resulting
  session cookie as `SEER_SESSION_TOKEN` and sends requests with it instead of
  the admin API key.

If the dropdown is empty even after a successful test, Seerr has no local users —
go back to step 1.

> **Do not use SuggestArr's own "Approve requests before sending them to Seer"**
> for this. That setting holds suggestions *inside SuggestArr*, on its own
> Requests page — they never reach Seerr at all until you release them, so
> nothing shows up in Seerr's pending queue. Leave it off and let Seerr do the
> gatekeeping, which is what you actually see on the Seerr dashboard.

To verify it is working, run a job and check Seerr → **Requests**: the new items
should show as *Pending* and be attributed to the local user you created, not to
your admin account.

---

## Notes

- Configuration for each service is stored in `./service-name/config/` or `./service-name/`.
- All services include Homepage dashboard integration via Docker labels.
- Services communicate via Docker network for security.
- qBittorrent downloads are typically organized by categories.
- Jellyfin supports hardware transcoding if configured properly.
- Regular backups of configuration directories are recommended.
- For troubleshooting, check individual service logs: `docker compose logs -f service-name`.
