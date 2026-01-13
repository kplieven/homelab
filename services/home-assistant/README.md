## Home Assistant Container Setup

This directory contains the configuration for running [Home Assistant](https://www.home-assistant.io/) — an open-source home automation platform — using Docker Compose.

---

**What This Setup Does**

- Deploys Home Assistant for comprehensive home automation control.
- Integrates with hundreds of smart home devices and services.
- Provides powerful automation and scene capabilities.
- Offers a modern web interface and mobile apps.
- Persistent configuration and data storage.

---

## Environment Variables

The `.env.example` file should define the following variables:


| Variable | Description |
| :-- | :-- |
| `URL` | The URL the Home Assistant instance is accessible at |
| `HOME_ASSISTANT_ACCESS_TOKEN` | Your Home Assistant API token (for Homepage widget). |
=

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

5. **Access Home Assistant** at:
    - `http://localhost:8123`
    - Or via your configured URL through Caddy
    - Follow the onboarding process to create your account

---

## Notes

- All configuration files are stored in the `./config` directory.
- Configuration is managed through YAML files:
  - `configuration.yaml`: Main configuration file
  - `automations.yaml`: Automation definitions
  - `scripts.yaml`: Reusable scripts
  - `scenes.yaml`: Scene definitions
  - `secrets.yaml`: Sensitive information (passwords, API keys)
- Custom components can be placed in `./config/custom_components/`.
- The container uses host network mode for device discovery.
- Logs are stored in `./config/` directory.
- Home Assistant has a built-in editor for YAML configuration.
- Blueprints for automations can be stored in `./config/blueprints/`.
- The web interface provides a powerful visual editor for most configuration tasks.
