## Caddy Reverse Proxy Setup

This directory contains the configuration for running [Caddy](https://caddyserver.com/) as a reverse proxy for your homelab services, with optional automatic HTTPS via Cloudflare DNS.

---

**What This Setup Does**

- Proxies your services behind your domain using Caddy.
- Can automatically manage TLS certificates via Cloudflare (for public domains).
- Exposes a metrics/admin endpoint for Caddy.
- Uses environment variables for flexible and secure configuration.

---

## Environment Variables

The `.env.example` file defines the following variables:


| Variable | Description |
| :-- | :-- |
| `PORT` | The port used for Caddy's admin/metrics endpoint (default: `2019`). |
| `SERVER_IP` | The local IP address of your server (e.g., `192.168.1.100`). |
| `HOMEPAGE_WIDGET_URL` | URL used by the Caddy homepage widget (e.g., `http://192.168.1.100:2019`). |
| `DOMAIN` | Your main domain name (e.g., `example.com` or `homelab.local`). |
| `CF_API_KEY` | Cloudflare API key for DNS-based TLS certificate management (only needed for public domains). |


---

## Setup Instructions

1. **Enter** the `services/caddy` directory.
2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values:
    - `PORT`: Usually leave as `2019` unless you need a different admin port.
    - `SERVER_IP`: Set to your server's local IP (e.g., `192.168.1.100`).
    - `HOMEPAGE_WIDGET_URL`: Usually does not need changing; will auto-populate with the above values.
    - `DOMAIN`:
        - For public access: use your real domain (e.g., `example.com`).
        - For local/private access: use a local domain (e.g., `homelab.local` or `mydomain.lan`).
    - `CF_API_KEY`: Only required if you are using a public domain and want Caddy to manage TLS certificates via Cloudflare.
4. **DNS Setup:**
    - **Public Domain:** Point your domain and subdomains (e.g., `www.example.com`, `prowlarr.example.com`) to your server's public IP in Cloudflare.
    - **Local/Private Domain:** Set up local DNS (e.g., Pi-hole, AdGuard Home, or your router's DNS) to resolve your chosen domain (e.g., `homelab.local`) to your server's local IP. No need for Cloudflare or public DNS.
5. **Run Caddy** by starting the docker container:

```sh
docker compose up -d
```

6. **Access your services** at:
    - `https://example.com` (homepage)
    - `https://prowlarr.example.com`
    - ...and other subdomains as defined in the `Caddyfile`.

---

## Notes for Local-Only Access

- If you do **not** want your services accessible from the public internet, use a local-only domain (such as `homelab.local`) and configure your local DNS to resolve that domain to your server's IP.
- In this case, you do **not** need to set `CF_API_KEY` or use Cloudflare DNS for certificate management.
- For local-only domains, you can use Caddy's internal (self-signed) certificates or configure Caddy to serve HTTP only, depending on your security requirements.
- Example `.env` for local setup:

```env
PORT=2019
SERVER_IP=192.168.1.100
HOMEPAGE_WIDGET_URL=http://192.168.1.100:2019
DOMAIN=homelab.local
CF_API_KEY=
```

## Notes for access using Tailscale

- Add your device to your Tailnet
- Then point your domains to the IP of the server inside of the Tailnet. You can find your IP by running:

```sh
tailscale ip --4
```

---

## Example Caddyfile Snippet for Local Domains

```caddyfile
{
    admin 0.0.0.0:2019
}

{$DOMAIN}, www.{$DOMAIN} {
    reverse_proxy {$SERVER_IP}:3001
    # No TLS block needed for local-only HTTP, or use Caddy's internal CA for local HTTPS
}

prowlarr.{$DOMAIN} {
    reverse_proxy {$SERVER_IP}:9696
}
```

---

*For more details, see the [Caddy documentation](https://caddyserver.com/docs/) and your local DNS resolver's documentation.*


