# LaneSync V2I + Navigation

LaneSync Pilot version: **1.0.0** (`LaneSyncVersion` param)

## V2I message format (JSON over UDP)

Default port: **7701** (`V2IPort` param).

```json
{
  "intersection_id": "Main & 1st",
  "distance_m": 42.0,
  "signal": "red",
  "time_to_change_s": 12.5,
  "speed_advisory_mps": 13.4,
  "hazard": "work_zone"
}
```

### Signal values

`unknown`, `red`, `yellow`, `green`, `flashing_red`, `flashing_yellow`

### Hazard values

`none`, `work_zone`, `congestion`, `weather`, `emergency_vehicle`

## J2735-lite binary

See `j2735.py` and `tools/v2i/j2735_sender.py` for a compact binary envelope RSU gateways can emit after decoding full ASN.1 J2735.

## Phone navigation (HTTP POST)

Default port: **7710** (`PhoneNavPort` param).

```json
{
  "source": "carplay",
  "carplay_connected": true,
  "active": true,
  "destination": "Stanford University",
  "dest_lat": 37.4275,
  "dest_lon": -122.1697,
  "distance_remaining_m": 8500,
  "time_remaining_s": 720,
  "maneuver": "Continue on US-101 South"
}
```

Optional auth: set `PhoneNavToken` param and include `"token": "..."` in POST body.

## Tools

| Script | Purpose |
|--------|---------|
| `tools/v2i/v2i_sender.py` | UDP RSU simulator |
| `tools/v2i/j2735_sender.py` | Binary J2735-lite sender |
| `tools/v2i/phone_nav_sender.py` | HTTP nav simulator |
| `tools/v2i/carla_bridge.py` | CARLA traffic-light bridge |
| `tools/v2i/hud_mockup.html` | Browser HUD preview |
| `tools/v2i/ios/README.md` | iOS Shortcut setup |
