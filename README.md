# LaneSync Pilot

An [openpilot](https://github.com/commaai/openpilot) fork with **V2I** (Vehicle-to-Infrastructure) and **Navigation** built in.

## What's inside

```
V2I-for-Comma/
├── lanesync-pilot/     # openpilot v0.11.0 fork (LaneSync Pilot)
│   ├── system/v2i/     # V2I + phone nav daemons
│   ├── tools/v2i/      # Simulators, HUD mockup, iOS setup
│   └── att/            # AT&T data plan configs
└── README.md           # This file
```

## Features

- **V2I** — RSU traffic signals, speed advisories, hazards via UDP; planner + HUD integration
- **Navigation** — iPhone/CarPlay bridge sends turn-by-turn to comma over Wi‑Fi
- **Connectivity** — Wi‑Fi hotspot + AT&T / T-Mobile / Verizon LTE for phone ↔ device link
- **Version** — LaneSync Pilot `1.0.0` (shown on device home screen)
- **Speed Limit Follow** - Makes the Car follow the speed limit 
- **Dashcam** - Comming later will be a Video Downloader and have them on End to End Encrypted but Account Neccessary to store for 7 days then download it to save it after 7 days

## Get started

See [lanesync-pilot/docs/LANESYNC.md](lanesync-pilot/docs/LANESYNC.md) for full setup, params, and testing.

### Install on comma

During comma device setup, enter your fork installer URL, or:

```bash
git clone <your-repo-url> /data/openpilot
cd /data/openpilot/lanesync-pilot
```

### Enable features

```bash
params set V2IEnabled 1
params set PhoneNavEnabled 1
```

Developer toggles are under **Settings → Developer** on the device UI.

## Based on

- openpilot v0.11.0 (comma.ai)
- Uses comma's reserved cereal fork slots for upstream compatibility
