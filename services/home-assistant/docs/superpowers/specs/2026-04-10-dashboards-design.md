# Home Assistant Dashboards — Design Spec

## Problem

No dashboards exist yet. The goal is a monitoring-focused whole-home overview, accessible from any device (phone, tablet, desktop).

## Devices & Integrations

All integrations are configured and working in HA:

| Device | Integration |
|---|---|
| Front door light | Legrand/Netatmo |
| UniFi Dream Router | UniFi Network |
| UniFi AP × 2 | UniFi Network |
| G4 Doorbell Pro | UniFi Protect |
| Sonos Beam | Sonos |

## Dashboards

### Dashboard A — Home Overview (primary)

- **View type:** `masonry` (default)
- **Storage:** YAML file (`ui-lovelace.yaml` in config, with `lovelace: mode: yaml`)
- **Use case:** Default dashboard, monitoring-first, works on any screen size

**Layout:**

```
┌─────────────────────────────────────────────────┐
│ 🔒 SECURITY                                     │
│ ┌───────────────────┐  ┌──────────┐ ┌─────────┐ │
│ │  Camera feed      │  │ Doorbell │ │  Light  │ │
│ │  (G4 Doorbell)    │  │ last evt │ │  front  │ │
│ └───────────────────┘  └──────────┘ └─────────┘ │
│                                                  │
│ 📡 NETWORK                                      │
│ ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│ │Dream Router│  │   AP 1   │  │   AP 2   │    │
│ │status/WAN │  │clients   │  │clients   │    │
│ └───────────┘  └───────────┘  └───────────┘    │
│                                                  │
│ 🎵 MEDIA                                        │
│ ┌────────────────────────────────────────────┐  │
│ │  Sonos Beam — now playing / volume         │  │
│ └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**Cards:**

| Section | Card type | Entity (pattern) |
|---|---|---|
| Camera feed | `picture-glance` or `camera` | `camera.g4_doorbell_*` |
| Doorbell last event | `entities` | `event.g4_doorbell_*` or `sensor.*doorbell*` |
| Front door light | `light` (via `tile` card) | `light.front_door` or similar |
| Dream Router | `entities` | `device_tracker.*` / `sensor.*router*` |
| AP 1 | `entities` | `sensor.*ap_*` or UniFi device sensors |
| AP 2 | `entities` | `sensor.*ap_*` |
| Sonos Beam | `media-player` (via `media-control` card) | `media_player.sonos_beam` |

> Entity IDs need to be verified in HA Developer Tools → States before finalising YAML.

### Dashboard B — Home Sections (secondary/experimental)

- **View type:** `sections`
- **Storage:** Separate dashboard entry in `configuration.yaml`
- **Use case:** Modern responsive grid, easy to rearrange in HA UI

Same logical sections as Dashboard A but using HA's Sections view type, which provides a drag-and-drop responsive column grid. Good for tablets/displays.

## Storage Approach

Use **YAML mode** (`lovelace: mode: yaml`) so dashboards are version-controlled alongside other HA config.

- `services/home-assistant/config/ui-lovelace.yaml` — Dashboard A (default)
- `services/home-assistant/config/dashboards/sections.yaml` — Dashboard B

Add to `configuration.yaml`:
```yaml
lovelace:
  mode: yaml
  dashboards:
    lovelace-sections:
      mode: yaml
      title: Home (Sections)
      icon: mdi:view-dashboard
      show_in_sidebar: true
      filename: dashboards/sections.yaml
```

## Success Criteria

- Default dashboard loads on first open with all 3 sections visible
- Camera card shows G4 Doorbell feed
- Network section shows online/offline status for router + both APs
- Sonos media player card shows current state
- Sections dashboard accessible from sidebar
- All files committed to the repo
