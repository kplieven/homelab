## PairDrop Container Setup

This directory contains the configuration for running [PairDrop](https://github.com/schlagmichdoch/PairDrop) — a local file sharing service in your browser inspired by Apple's AirDrop — using Docker Compose.

---

**What This Setup Does**

- Deploys PairDrop for easy file sharing between devices on your network.
- No installation required on client devices (browser-based).
- Peer-to-peer file transfer within your local network.
- Works across different operating systems and devices.
- Privacy-focused with no external servers involved.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that will be used to access PairDrop. |
| `PORT` | Port for the PairDrop web interface (default: 3000). |


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

5. **Access PairDrop** at:
    - `http://localhost:3000` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

6. **Use PairDrop**:
    - Open PairDrop on multiple devices on the same network
    - Devices will automatically discover each other
    - Select files to share and choose the recipient device

---

## Notes

- PairDrop works entirely in the browser with no client installation needed.
- Files are transferred peer-to-peer for maximum speed and privacy.
- All devices must be on the same network to see each other.
- No files are stored on the server; transfers are direct between devices.
- Supports all file types and sizes.
- The interface automatically detects device names and types.
- For external access, ensure proper firewall configuration.
- PairDrop is lightweight and has minimal resource requirements.
