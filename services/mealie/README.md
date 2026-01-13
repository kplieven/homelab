## Mealie Container Setup

This directory contains the configuration for running [Mealie](https://mealie.io/) — a self-hosted recipe manager and meal planner — using Docker Compose.

---

**What This Setup Does**

- Deploys Mealie for managing recipes and meal planning.
- Import recipes from websites with automatic parsing.
- Organize recipes with categories, tags, and collections.
- Generate shopping lists from recipes.
- Plan meals with the built-in calendar.
- Persistent storage for recipes, images, and backups.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the homepage will link to. |
| `PORT` | Port the Mealie service will be exposed on (default: 2283). |
| `POSTGRES_USER` | The PostgreSQL database username. |
| `POSTGRES_PASSWORD` | The PostgreSQL database password. |
| `POSTGRES_SERVER` | The PostgreSQL server hostname. |
| `POSTGRES_PORT` | The PostgreSQL server port. |
| `POSTGRES_DB` | The PostgreSQL database name. |


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

5. **Access Mealie** at:
    - `http://localhost:9925` (or your server IP, or your chosen `PORT`)
    - Or via your configured URL through Caddy

6. **Create your account** and start adding recipes.

---

## Notes

- Recipe data and configuration are stored in the `./data` directory.
- Database files are stored in the `./database` directory (if using SQLite).
- Logs are available in `./data/` with rotation.
- Automatic backups can be configured through the web interface.
- The built-in recipe scraper supports hundreds of popular recipe websites.
- Mealie supports multiple users with shared recipe collections.
- Shopping lists can be organized by recipe or created manually.
- Meal plans support drag-and-drop scheduling.
- Export and import recipes in various formats (JSON, Markdown, etc.).
