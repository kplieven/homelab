## qui Container Setup

This directory contains the configuration for running [qui](https://github.com/autobrr/qui) — a fast, modern web interface that manages **several qBittorrent instances from one place** — using Docker Compose.

---

**What This Setup Does**

- Serves a single browser UI for both qBittorrent instances in this homelab:
  - `qbittorrent` in [`../media-stack`](../media-stack) (movies/TV, port `8080`)
  - `mam` in [`../books-stack`](../books-stack) (MyAnonaMouse, port `8089`)
- Runs on ordinary bridge networking, independent of the VPN.
- Stores its own accounts, instance credentials and UI preferences in `/config`.

---

## Why this is its own stack

qui manages instances in two different compose projects, so it belongs to
neither. More importantly it is **not** in gluetun's network namespace, unlike
the qBittorrent instances themselves:

- A management UI that goes down with the VPN killswitch is unavailable exactly
  when you want to look at it.
- A container sharing gluetun's namespace cannot publish its own port. The
  mapping would have to live in `../gluetun/docker-compose.yml` and be kept in
  sync there — see [that README](../gluetun/README.md). Nothing about qui needs
  the tunnel; it only talks to the two WebUIs.

Only peer traffic needs the VPN, and that still belongs to the qBittorrent
containers. qui's connections to them are management traffic over the LAN.

---

## Environment Variables

| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the homepage dashboard will link to. |
| `PORT` | Port for the qui web interface (default: 7476). |
| `TZ` | Timezone for the container, as a TZ identifier (e.g. `Etc/UTC`). |
| `QUI_LOG_LEVEL` | `ERROR`, `WARN`, `INFO`, `DEBUG` or `TRACE`. Upstream defaults to `DEBUG`, which is noisy for a container logging to stdout without rotation. |

qui reads `config.toml` in `/config` and lets environment variables override it.
Everything is prefixed `QUI__` (two underscores) upstream — `QUI__HOST`,
`QUI__PORT`, `QUI__BASE_URL`, `QUI__SESSION_SECRET_FILE`. Only the log level is
plumbed through here; add others to the compose file as needed.

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

5. **Access qui** at:
    - `http://localhost:7476` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

6. **Create your account.** The first visit registers the admin user. There is
   no default login, and no way to seed it from the environment.

7. **Add both instances.** Instances are configured in qui's web UI, not in
   compose — qui keeps them in its database. Use the **host IP**, not
   `localhost`:

| Name | URL | Credentials |
| :-- | :-- | :-- |
| Download | `http://192.168.0.102:8080` | the `qbittorrent` WebUI user |
| MAM | `http://192.168.0.102:8089` | the `mam` WebUI user |

---

## Notes

- **Use the host IP, not `localhost` or a container name.** `localhost` inside
  the qui container is qui itself. And both qBittorrent instances live in
  gluetun's network namespace, so they have no container hostname of their own to
  resolve — their WebUIs are published on the host by the gluetun stack. The host
  IP is how `../caddy` reaches them too.
- Both instances already have `WebUI\ServerDomains=*` set, so qui's requests are
  not rejected on the host header.
- `/config` holds `qui.db`. If UI preferences or instances disappear after a
  recreate, that volume is not persisting.
- No homepage widget exists for qui, so it gets link labels only. The per-instance
  qBittorrent widgets stay on the `qbittorrent` and `mam` containers.
- qui does not replace the per-instance WebUIs. Those still serve the stock
  qBittorrent WebUI on `8080` and `8089` and remain reachable directly.
- Upstream also offers a Postgres backend and a transparent qBittorrent reverse
  proxy for external apps. Neither is used here; sqlite is the default.
