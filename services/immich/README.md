## Immich Container Setup

This directory contains the configuration for running [Immich](https://immich.app/) — a self-hosted photo and video backup solution — using Docker Compose.

---

**What This Setup Does**

- Deploys Immich with machine learning capabilities for facial recognition and object detection.
- Uses PostgreSQL with pgvector extension for AI-powered search.
- Provides mobile app support (iOS and Android).
- Automatic photo and video backup from mobile devices.
- Advanced features: facial recognition, object detection, smart search.
- Hardware acceleration support (optional).

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `UPLOAD_LOCATION` | Path where photos and videos will be stored on the host. |
| `DB_PASSWORD` | PostgreSQL database password. |
| `URL` | The URL the Immich instance will be accessible at. |
| `PORT` | Port the Immich service will be exposed on (default: 2283). |
| `IMMICH_API_KEY` | Your Immich API token (for Homepage widget). |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

4. **Ensure the upload location exists**:

```sh
mkdir -p /path/to/upload/location
```

5. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

6. **Access Immich** at:
    - `http://localhost:2283` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

7. **Complete the initial setup** through the web interface:
    - Create your admin account
    - Configure machine learning settings
    - Download the mobile app and configure backup

---

## Hardware Acceleration

To enable hardware acceleration for video transcoding:

1. Edit `docker-compose.yml` and uncomment the appropriate `extends` section for your hardware.
2. Uncomment the machine learning acceleration in the `immich-machine-learning` service.
3. Restart the containers.

---

## Notes

- Photos are stored at `UPLOAD_LOCATION` on your host.
- Import folder can be mounted at `/usr/src/app/import` for bulk imports.
- PostgreSQL data is stored in the `./postgres` directory.
- Machine learning models are cached for faster processing.
- The mobile app provides automatic background backup.
- Facial recognition and object detection require the machine learning service.
- API key can be generated in the web interface under Account Settings.
- Homepage widget integration shows library statistics (photos, videos, storage).
- The library folder contains your organized photo library.
