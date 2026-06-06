# LaneSync Pilot

An [openpilot](https://github.com/commaai/openpilot) fork with **V2I** (Vehicle-to-Infrastructure) and **Navigation** built in.

## What's inside

```
V2I-for-Comma/
└── lanesync-pilot/     # openpilot v0.11.0 fork (LaneSync Pilot)
    ├── mobile/
    │   ├── android/    # Android app (dashcam, safety, Android Auto UI)
    │   └── ios/        # iOS stub (you implement)
    ├── system/v2i/     # V2I + phone nav daemons
    ├── system/dashcam/ # Saved dashcam HTTP API (dashcamd)
    ├── tools/v2i/      # Simulators, HUD mockup, iOS Shortcut setup
    └── att/            # AT&T data plan configs
```

## Features

- **V2I** — RSU traffic signals, speed advisories, hazards via UDP; planner + HUD integration
- **Navigation** — iPhone/CarPlay bridge sends turn-by-turn to comma over Wi‑Fi; Android app uses Android Auto
- **Dashcam** — Android app streams/downloads bookmark-saved clips via `dashcamd` (cloud: E2E encrypted, 7-day account storage)
- **Speed limit follow** — Car follows posted speed limits
- **Connectivity** — Wi‑Fi hotspot + AT&T / T-Mobile / Verizon LTE for phone ↔ device link
- **Version** — LaneSync Pilot `1.0.0` (shown on device home screen)

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
