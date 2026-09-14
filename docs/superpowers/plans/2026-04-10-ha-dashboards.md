# Home Assistant Dashboards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two Home Assistant dashboards — a masonry single-page overview (default) and a Sections-based responsive dashboard (sidebar) — covering Security, Network, and Media.

**Architecture:** Dashboards stored as YAML files under `services/home-assistant/config/`, version-controlled in the repo. `configuration.yaml` is updated to activate YAML lovelace mode. Dashboard A is the default view; Dashboard B is a second dashboard registered in the sidebar.

**Tech Stack:** Home Assistant Lovelace YAML, HA built-in cards (`picture-glance`, `tile`, `entities`, `media-control`, `vertical-stack`, `horizontal-stack`), HA `sections` view type.

---

## ⚠️ Entity ID Verification (do this first)

Before writing dashboard YAML, confirm the exact entity IDs for your devices in **HA → Developer Tools → States**. Search for these:

| Device | What to search | Expected entity type |
|---|---|---|
| G4 Doorbell camera | `camera.` | `camera.*doorbell*` or `camera.*g4*` |
| Doorbell ring event | `event.` | `event.*doorbell*` or `event.*ring*` |
| Front door light | `light.` | `light.*door*` or `light.*front*` |
| Dream Router | `sensor.` | `sensor.*udm*` or `sensor.*dream*` |
| AP 1 | `sensor.` | `sensor.*ap*` — note the exact name |
| AP 2 | `sensor.` | `sensor.*ap*` — note the exact name |
| Sonos Beam | `media_player.` | `media_player.*sonos*` or `media_player.*beam*` |

Replace the placeholder entity IDs in Tasks 2 and 3 with your verified entity IDs.

---

## Task 1: Enable YAML lovelace mode and create directory structure

**Files:**
- Modify: `services/home-assistant/config/configuration.yaml`
- Create: `services/home-assistant/config/dashboards/` (directory)

- [ ] **Step 1: Add lovelace config to configuration.yaml**

Add to the end of `services/home-assistant/config/configuration.yaml`:

```yaml

lovelace:
  mode: yaml
  dashboards:
    lovelace-sections:
      mode: yaml
      title: Home (Sections)
      icon: mdi:view-dashboard-variant
      show_in_sidebar: true
      filename: dashboards/sections.yaml
```

- [ ] **Step 2: Create the dashboards directory**

```bash
mkdir -p services/home-assistant/config/dashboards
```

- [ ] **Step 3: Commit**

```bash
cd services/home-assistant
git add config/configuration.yaml config/dashboards/
git commit -m "feat: [Home Assistant] enable YAML lovelace mode with sections dashboard slot"
```

---

## Task 2: Create Dashboard A — Home Overview (masonry, default)

**Files:**
- Create: `services/home-assistant/config/ui-lovelace.yaml`

> Replace `camera.g4_doorbell_pro`, `event.g4_doorbell_pro_ring`, `light.front_door_light`, `sensor.udm_uptime`, `sensor.udm_wan_ip`, `sensor.ap_1_clients`, `sensor.ap_1_uptime`, `sensor.ap_2_clients`, `sensor.ap_2_uptime`, `media_player.sonos_beam` with verified entity IDs from Developer Tools.

- [ ] **Step 1: Create ui-lovelace.yaml**

Create `services/home-assistant/config/ui-lovelace.yaml`:

```yaml
title: Home
views:
  - title: Overview
    icon: mdi:home
    path: default_view
    cards:

      # ── Security ──────────────────────────────────────────
      - type: vertical-stack
        cards:
          - type: markdown
            content: "## 🔒 Security"
          - type: picture-glance
            title: Front Door
            camera_image: camera.g4_doorbell_pro
            entities:
              - entity: event.g4_doorbell_pro_ring
                icon: mdi:doorbell
              - entity: light.front_door_light
                icon: mdi:lightbulb
          - type: horizontal-stack
            cards:
              - type: tile
                entity: event.g4_doorbell_pro_ring
                name: Doorbell — last ring
              - type: tile
                entity: light.front_door_light
                name: Front door light

      # ── Network ───────────────────────────────────────────
      - type: vertical-stack
        cards:
          - type: markdown
            content: "## 📡 Network"
          - type: horizontal-stack
            cards:
              - type: entities
                title: Dream Router
                entities:
                  - entity: sensor.udm_uptime
                    name: Uptime
                  - entity: sensor.udm_wan_ip
                    name: WAN IP
              - type: entities
                title: AP 1
                entities:
                  - entity: sensor.ap_1_clients
                    name: Clients
                  - entity: sensor.ap_1_uptime
                    name: Uptime
              - type: entities
                title: AP 2
                entities:
                  - entity: sensor.ap_2_clients
                    name: Clients
                  - entity: sensor.ap_2_uptime
                    name: Uptime

      # ── Media ─────────────────────────────────────────────
      - type: vertical-stack
        cards:
          - type: markdown
            content: "## 🎵 Media"
          - type: media-control
            entity: media_player.sonos_beam
```

- [ ] **Step 2: Reload HA lovelace and verify Dashboard A loads**

In HA: **Developer Tools → YAML → Lovelace dashboards → Reload**  
Or restart HA: `cd services/home-assistant && docker compose restart`

Open HA in browser. The default dashboard should show Overview with 3 sections. If you see a YAML parse error, HA will display it in the UI — fix and reload.

- [ ] **Step 3: Fix any entity ID mismatches**

In HA: **Developer Tools → States** — confirm each entity exists and is returning data. Update entity IDs in `ui-lovelace.yaml` as needed, then reload lovelace.

- [ ] **Step 4: Commit**

```bash
git add services/home-assistant/config/ui-lovelace.yaml
git commit -m "feat: [Home Assistant] add Dashboard A — masonry home overview"
```

---

## Task 3: Create Dashboard B — Home Sections (sidebar)

**Files:**
- Create: `services/home-assistant/config/dashboards/sections.yaml`

> Use the same verified entity IDs from Task 2.

- [ ] **Step 1: Create dashboards/sections.yaml**

Create `services/home-assistant/config/dashboards/sections.yaml`:

```yaml
title: Home (Sections)
views:
  - title: Overview
    icon: mdi:home
    path: sections_view
    type: sections
    max_columns: 3
    sections:

      # ── Security ──────────────────────────────────────────
      - type: grid
        title: 🔒 Security
        cards:
          - type: picture-glance
            title: Front Door
            camera_image: camera.g4_doorbell_pro
            entities:
              - entity: event.g4_doorbell_pro_ring
                icon: mdi:doorbell
              - entity: light.front_door_light
                icon: mdi:lightbulb
          - type: tile
            entity: event.g4_doorbell_pro_ring
            name: Doorbell — last ring
          - type: tile
            entity: light.front_door_light
            name: Front door light

      # ── Network ───────────────────────────────────────────
      - type: grid
        title: 📡 Network
        cards:
          - type: entities
            title: Dream Router
            entities:
              - entity: sensor.udm_uptime
                name: Uptime
              - entity: sensor.udm_wan_ip
                name: WAN IP
          - type: entities
            title: AP 1
            entities:
              - entity: sensor.ap_1_clients
                name: Clients
              - entity: sensor.ap_1_uptime
                name: Uptime
          - type: entities
            title: AP 2
            entities:
              - entity: sensor.ap_2_clients
                name: Clients
              - entity: sensor.ap_2_uptime
                name: Uptime

      # ── Media ─────────────────────────────────────────────
      - type: grid
        title: 🎵 Media
        cards:
          - type: media-control
            entity: media_player.sonos_beam
```

- [ ] **Step 2: Reload HA lovelace and verify Dashboard B is in the sidebar**

In HA: **Developer Tools → YAML → Lovelace dashboards → Reload**

The sidebar should now show **"Home (Sections)"** as a second dashboard. Open it and verify all 3 sections render.

- [ ] **Step 3: Fix any entity ID mismatches**

Same process as Task 2 Step 3 — check Developer Tools → States, update entity IDs, reload.

- [ ] **Step 4: Commit**

```bash
git add services/home-assistant/config/dashboards/sections.yaml
git commit -m "feat: [Home Assistant] add Dashboard B — sections responsive view"
```
