## Komodo Container Setup

This directory contains the configuration for running [Komodo](https://github.com/mbecker20/komodo) — a GitOps-enabled infrastructure management platform — using Docker Compose.

---

**What This Setup Does**

- Deploys Komodo Core for centralized infrastructure management.
- Includes Komodo Periphery agent for executing commands on the host.
- Uses FerretDB as a MongoDB-compatible database backed by PostgreSQL.
- Provides real-time monitoring of Docker containers and system resources.
- Supports automated deployments via Git webhooks.
- Enables infrastructure-as-code with stack management.

---

## Environment Variables

The `.env` file defines extensive configuration options. Key variables include:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL that the Komodo service will be exposed on. |
| `PORT` | Port the Komodo service will be exposed on (default: 9120). |

---

## Setup Instructions

See the [setup guide](https://komo.do/docs/setup/ferretdb) of Komodo for more information.


## Stack Management

Komodo can manage Docker Compose stacks located in the parent directory:

1. Place your stack files in the parent directory (e.g., `../media-stack/`)
2. Komodo will discover them automatically via the mounted volume
3. Deploy and manage stacks through the Komodo web interface

---

## Notes

- Database data is stored in the `./db` directory.
- Repo cache is stored in `./cache` for Git operations.
- The setup includes Homepage dashboard integration via Docker labels.
- Periphery runs with access to the Docker socket for container management.
- The `komodo.skip` label prevents Komodo from managing its own containers.
- Monitoring interval can be adjusted based on your needs (1-second to 15-minute options).
- Resource polling for automated actions defaults to 1-hour intervals.
- WebSocket support enables real-time updates in the UI.
