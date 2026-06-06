# LaneSync Pilot

**LaneSync Pilot** is an openpilot fork built for connected driving: **V2I** (Vehicle-to-Infrastructure) and **phone navigation** are integrated into the stack, HUD, and longitudinal planner.

Based on [openpilot v0.11.0](https://github.com/commaai/openpilot).

**LaneSync version:** `1.0.0` (param: `LaneSyncVersion`)

## Features

### V2I (Vehicle-to-Infrastructure)

- Listens for RSU messages on **UDP port 7701** (JSON or J2735-lite binary)
- SPaT traffic signals, speed advisories, and hazard alerts
- HUD traffic-light indicator and hazard badge
- Planner integration: caps cruise speed from advisories; holds at red within 50 m
- CARLA bridge and test sender in `tools/v2i/`

### Navigation (iPhone / CarPlay bridge)

Comma devices cannot host Apple CarPlay — CarPlay runs on your phone or car screen. While you navigate with Maps over CarPlay, your **iPhone** sends destination and turn-by-turn updates to the comma over Wi‑Fi via a free **Shortcuts** automation.

- HTTP server on port **7710** (`phonenavd`)
- Publishes `phoneNavState`, `navInstruction`, and `navRoute`
- HUD destination banner with CarPlay badge
- Setup guide: `tools/v2i/ios/README.md`

### Dashcam companion apps

- **`dashcamd`** HTTP API on port **7720** — lists bookmark-saved clips and streams video
- **Android app** in `mobile/android/` — browse, play, and download saved dashcams
- **iOS** — implement in `mobile/ios/` against the same API

### Connectivity

- Wi‑Fi always-on for iPhone ↔ comma link
- AT&T, T-Mobile, and Verizon LTE data plan support with Wi‑Fi hotspot (`att/`, `tmobile/`, `verizon/` folders; `attd`, `tmobiled`, `verizond` daemons)
- Network status badge on HUD

## Quick start on a comma device

1. Install LaneSync Pilot using your fork URL during comma setup (or clone to `/data/openpilot`).
2. Enable features in **Settings → Developer**:

| Toggle | Param |
|--------|-------|
| Vehicle-to-Infrastructure (V2I) | `V2IEnabled` |
| iPhone Navigation (CarPlay) | `PhoneNavEnabled` |
| AT&T Data Plan + Wi‑Fi Hotspot | `AttDataPlanEnabled` |
| T-Mobile Data Plan + Wi‑Fi Hotspot | `TmobileDataPlanEnabled` |
| Verizon Data Plan + Wi‑Fi Hotspot | `VerizonDataPlanEnabled` |

Or via SSH:

```bash
params set V2IEnabled 1
params set PhoneNavEnabled 1
params set V2IPort 7701
params set PhoneNavPort 7710
# reboot or cycle onroad
```

## Test from your laptop

```bash
# Simulate RSU traffic signal
python3 tools/v2i/v2i_sender.py --host <comma-ip> --demo

# Simulate iPhone navigation
python3 tools/v2i/phone_nav_sender.py --host <comma-ip>

# Interactive HUD mockup
python3 tools/v2i/hud_mockup_server.py --comma-ip <comma-ip>
open http://127.0.0.1:8765
```

## Architecture

| Daemon | Port | Topic |
|--------|------|-------|
| `v2id` | UDP 7701 | `v2iState` |
| `phonenavd` | HTTP 7710 | `phoneNavState`, `navRoute`, `navInstruction` |
| `v2inetd` | — | `v2iNetworkState` |
| `attd` | — | AT&T APN + hotspot |
| `tmobiled` | — | T-Mobile APN + hotspot |
| `verizond` | — | Verizon APN + hotspot |
| `dashcamd` | HTTP 7720 | Saved dashcam API for mobile apps |

Cereal schemas live in `cereal/custom.capnp` using comma's reserved fork slots (`V2IState`, `PhoneNavState`, `V2INetworkState`).

## Cellular data plans

### AT&T

```bash
scp -r att comma@<comma-ip>:/data/
ssh comma@<comma-ip> 'chmod +x /data/att/apply_dataplan.sh && /data/att/apply_dataplan.sh consumer'
```

See `att/README.md` for profile details.

### T-Mobile

```bash
scp -r tmobile comma@<comma-ip>:/data/
ssh comma@<comma-ip> 'chmod +x /data/tmobile/apply_dataplan.sh && /data/tmobile/apply_dataplan.sh consumer'
```

See `tmobile/README.md` for profile details. Default APN: `fast.t-mobile.com`.

### Verizon

```bash
scp -r verizon comma@<comma-ip>:/data/
ssh comma@<comma-ip> 'chmod +x /data/verizon/apply_dataplan.sh && /data/verizon/apply_dataplan.sh consumer'
```

See `verizon/README.md` for profile details. Default APN: `vzwinternet`.

## Disclaimer

LaneSync Pilot is not affiliated with comma.ai. Use at your own risk. V2I and navigation features are experimental.
