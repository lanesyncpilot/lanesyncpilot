# LaneSync Mobile

Companion apps for LaneSync Pilot.

| Platform | Path | Status |
|----------|------|--------|
| Android | [`android/`](android/) | Saved dashcam app (browse, play, download) |
| iOS | [`ios/`](ios/) | Stub — implement against `dashcamd` API |

Both apps talk to the comma device over Wi‑Fi:

- **Dashcam API** — `http://<comma-ip>:7720` (`dashcamd`)
- **Phone nav** — `http://<comma-ip>:7710` (`phonenavd`) — see `tools/v2i/ios/README.md`
