## Your Spotify Container Setup

Your Spotify is a self-hosted dashboard for visualizing your Spotify listening statistics. It consists of a backend server that collects data from the Spotify API, a web client for interactive stats, and a MongoDB database for storing your data—all running locally on your server via Docker Compose.

---

**What This Setup Does**

- Deploys a backend server to securely connect to Spotify and gather your listening data.
- Runs a web client to present your Spotify stats in a clean, interactive dashboard.
- Stores all data locally in a MongoDB container for privacy and persistence.
- Integrates with your Homepage dashboard for quick access.

---

## Environment Variables

The `.env.example` file defines the following variables:

| Variable         | Description                                                      |
| :--------------- | :---------------------------------------------------------------|
| `CLIENT_URL`     | The URL where the web client will be accessible.                 |
| `CLIENT_PORT`    | Port for the web client (default: 9401).                        |
| `SERVER_URL`     | The URL where the backend server will be accessible.             |
| `SERVER_PORT`    | Port for the backend server (default: 9400).                    |
| `SPOTIFY_PUBLIC` | Your Spotify application Client ID (from Spotify Developer).     |
| `SPOTIFY_SECRET` | Your Spotify application Client Secret (from Spotify Developer). |
| `HOMEPAGE_URL`   | The URL that Homepage will link to for Your Spotify access.      |


---

## Setup Instructions

1. **Enter** the directory containing this setup.

2. **Create** your `.env` file by copying the example:

    ```
    cp .env.example .env
    ```

3. **Edit `.env`** and fill in your values (see [Environment Variables](#environment-variables)):
    - Register a Spotify application at the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/applications).
    - Set the Redirect URI in your Spotify app to:  
      `http://<SERVER_URL>/oauth/spotify/callback`
    - Copy the Client ID and Secret into `SPOTIFY_PUBLIC` and `SPOTIFY_SECRET`.

4. **Run the container** with Docker Compose:

    ```
    docker compose up -d
    ```

5. **Access Your Spotify** at:
    - `http://<CLIENT_URL>:<CLIENT_PORT>` (default: `http://localhost:9401`)
    - Or via your Homepage dashboard link

---

## Notes

- MongoDB data is stored in the `./database` directory relative to your compose file.
- The backend server listens on port 8080 inside the container, mapped to your chosen `SERVER_PORT`.
- The web client listens on port 3000 inside the container, mapped to your chosen `CLIENT_PORT`.
- Ensure your Spotify app’s Redirect URI matches what you set in `.env` and your server URL.
- Use `docker compose logs -f` to view logs for troubleshooting.
- Restart the containers with `docker compose restart` after making changes to `.env`.

