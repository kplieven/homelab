## Immich Container Setup

This directory contains the configuration for running [Immich](https://immich.app/) — a self-hosted photo and video backup solution — using Docker Compose.

---

**What This Setup Does**

- Deploys Immich with machine learning capabilities for facial recognition and object detection.
- Uses PostgreSQL with pgvector extension for AI-powered search.
- Provides mobile app support (iOS and Android).
- Automatic photo and video backup from mobile devices.
- Advanced features: facial recognition, object detection, smart search.
- Hardware-accelerated video transcoding and machine learning (NVIDIA/CUDA on this host — see [Hardware Acceleration](#hardware-acceleration)).
- Automatically mirrors the import folder structure into Immich albums (see [Folder Album Creator](#folder-album-creator)).

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
| `IMPORT_LOCATION` | Host folder Immich imports existing photos from. |
| `TZ` | Timezone for the container, as a TZ identifier (e.g. `Etc/UTC`). |

---

## Secrets

One Immich API key covers both consumers, and it lives in `.env` as `IMMICH_API_KEY`:

- the **Homepage widget**, via the `homepage.widget.key` label on `immich-server`;
- the **folder album creator**, via `API_KEY: ${IMMICH_API_KEY}`.

Both read the same variable, so the key cannot drift between them. Compose interpolates
`${IMMICH_API_KEY}` from `.env` in this directory — the album creator needs no `env_file:`
for it.

The key can only be generated once an admin account exists, so it is filled in *after*
the first start (see step 9 below). `.env` is gitignored, and `*.secret` is too; a real
API key grants full access to the whole library, so neither belongs in a commit.

The container also accepts `API_KEY_FILE` pointing at a mounted file instead. That keeps
the key out of the process list — with `API_KEY` the wrapper passes it as a command-line
argument to `immich_auto_album.py`, so it is visible in `ps` and in `docker inspect`. The
trade-off here went the other way: one key in one place, and no file that has to stay
readable by the container's UID.

---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

```sh
cp .env.example .env
```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)).

4. **Check the hardware acceleration settings** in `docker-compose.yml` — the committed
   values target an NVIDIA GPU and **will fail to start on other hardware**.
   See [Hardware Acceleration](#hardware-acceleration).

5. **Ensure the upload location exists**:

```sh
mkdir -p /path/to/upload/location
```

6. **Run the containers** with Docker Compose:

```sh
docker compose up -d
```

7. **Access Immich** at:
    - `http://localhost:2283` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

8. **Complete the initial setup** through the web interface:
    - Create your admin account
    - Configure machine learning settings
    - Enable hardware transcoding (see [Hardware Acceleration](#hardware-acceleration))
    - Download the mobile app and configure backup

9. **Generate an API key** in the web interface under *Account Settings → API Keys*, set
   it as `IMMICH_API_KEY` in `.env`, and recreate the containers that consume it:

```sh
docker compose up -d immich-server immich-folder-album-creator
```

Verify the album creator picked it up:

```sh
docker logs -f immich_folder_album_creator
```

---

## Hardware Acceleration

Hardware acceleration is **enabled** in this setup, configured for an **NVIDIA GPU**:

| Service | Where it is set | Current value |
| :-- | :-- | :-- |
| `immich-server` (transcoding) | `extends` → `hwaccel.transcoding.yml` | `nvenc` |
| `immich-machine-learning` (inference) | `extends` → `hwaccel.ml.yml` | `cuda` |
| `immich-machine-learning` (image tag) | `image:` suffix | `${IMMICH_VERSION:-release}-cuda` |

On the host, NVIDIA acceleration also requires the
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
to be installed and configured for Docker.

### Adapting it to different hardware

If your machine does not have an NVIDIA GPU, **you must change this** or the containers
will fail to start.

1. **Transcoding** — in `immich-server`, set the `extends: service:` to match your hardware:
   `nvenc` (NVIDIA), `quicksync` (Intel iGPU), `vaapi` (AMD/Intel), `vaapi-wsl` (WSL2),
   `rkmpp` (Rockchip), or `cpu` for none.
   The device mappings for each backend live in `hwaccel.transcoding.yml`.

2. **Machine learning** — in `immich-machine-learning`, change **both**:
    - the `extends: service:` to `cuda`, `rocm`, `openvino`, `openvino-wsl`, `armnn`,
      `rknn`, or `cpu`;
    - the image tag suffix to match (e.g. `...:${IMMICH_VERSION:-release}-openvino`).
      For CPU inference, drop the suffix entirely and remove the `extends` block.

   The backends are defined in `hwaccel.ml.yml`.

3. **Restart** the containers:

```sh
docker compose up -d
```

### Enabling it in Immich

Compose only exposes the GPU to the containers. Transcoding acceleration must also be
switched on in the web interface, under
*Administration → Settings → Video Transcoding → Hardware Acceleration*, by selecting the
matching API (NVENC, Quick Sync, VAAPI, RKMPP). Machine learning acceleration needs no
extra toggle — the `-cuda` (or equivalent) image uses the GPU on its own.

Verify with `docker compose logs immich-machine-learning` and, for NVIDIA, `nvidia-smi`
while a transcode job runs.

---

## Folder Album Creator

The `immich-folder-album-creator` container
([salvoxia/immich-folder-album-creator](https://github.com/Salvoxia/immich-folder-album-creator))
turns the folder structure of the import library into Immich albums, so photos organised
in folders on disk end up in matching albums.

| Setting | Purpose |
| :-- | :-- |
| `API_URL` | Immich API endpoint. Hardcoded to the public `.../api` URL; the internal `http://immich_server:2283/api` is kept commented out as an alternative. |
| `API_KEY` | The Immich API key, taken from `IMMICH_API_KEY` in `.env`. |
| `ROOT_PATH` | Library root **as Immich sees it** (`/usr/src/app/import`), not the host path. |
| `CRON_EXPRESSION` | Run schedule — currently hourly (`0 * * * *`). |
| `LOG_LEVEL` | Currently `DEBUG`; lower to `INFO` once it runs cleanly. |
| `user: 1001:1001` | UID/GID the container runs as. |

Things to adapt on another machine:

- **The UID/GID** (`user: 1001:1001`) must have read access to `${IMPORT_LOCATION}`.
  Check with `id` and adjust.
- **`ROOT_PATH`** must match the container-side mount of the import folder in
  `immich-server` (`/usr/src/app/import`). If you change that mount, change this too.
- **`API_URL`** is a hardcoded literal, not read from `.env` — change it to your own
  domain. It must be reachable from inside the container; the public URL routes back out
  through Caddy, while the internal service URL avoids that round trip.
- **The API key** must be set in `.env` before this container is useful; until then it
  will log authentication errors on every cron run.

The import folder is mounted **read-only** into `immich-server`
(`${IMPORT_LOCATION}:/usr/src/app/import:ro`) but **read-write** into the album creator
at `/external_libs/photos`, which is required for `.albumprops` files to work.

---

## Notes

- Photos are stored at `UPLOAD_LOCATION` on your host.
- Import folder is mounted read-only at `/usr/src/app/import` for bulk imports.
- PostgreSQL data is stored in the `./postgres` directory.
- Machine learning models are cached for faster processing (`model-cache` volume).
- The mobile app provides automatic background backup.
- Facial recognition and object detection require the machine learning service.
- API key can be generated in the web interface under Account Settings.
- Homepage widget integration shows library statistics (photos, videos, storage).
- The library folder contains your organized photo library.
