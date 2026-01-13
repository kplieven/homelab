## WG-Easy Container Setup

This directory contains the configuration for running [WG-Easy](https://github.com/wg-easy/wg-easy) — a simple web-based UI for WireGuard VPN — using Docker Compose.

---

**What This Setup Does**

- Deploys WireGuard VPN with an easy-to-use web interface.
- Create and manage VPN clients through a browser.
- Generate QR codes for easy mobile device setup.
- Monitor client connections and traffic.
- Secure remote access to your home network.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that will be used to access the WG-Easy web interface. |
| `PORT` | Port for the web interface (default: 51821). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables))

4. **Enable port forwarding** on your router

5. **Run the container** with Docker Compose:

```sh
docker compose up -d
```

6. **Access WG-Easy** at:
    - `http://localhost:51821` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

7. **Create VPN clients**:
    - Click "New" to create a client
    - Scan the QR code with your mobile device
    - Or download the configuration file for desktop clients

8. **Configure your firewall** to allow WireGuard traffic:
    - Allow UDP port 51820 (WireGuard default)
    - Allow TCP port 51821 (web interface, if externally accessible)

---

## Notes

- WireGuard configuration and client data are stored in the `/etc/wireguard` directory within the container.
- The container requires `NET_ADMIN` and `SYS_MODULE` capabilities for WireGuard to function.
- IP forwarding must be enabled on the host for VPN routing to work.
- Default WireGuard port is 51820/UDP.
- Client configurations are displayed as QR codes for easy mobile setup.
- The web interface shows real-time connection status for all clients.
- Each client gets a unique IP address in the VPN subnet.
- Consider using a strong password and enabling HTTPS for the web interface.
- For split-tunneling, configure allowed IPs in client settings.
- The container runs in privileged mode to manage network interfaces.
