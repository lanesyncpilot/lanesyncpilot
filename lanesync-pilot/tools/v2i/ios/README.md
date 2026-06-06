# iPhone + Apple CarPlay navigation bridge

comma devices do **not** run Apple CarPlay (CarPlay stays on your car’s head unit or iPhone). While you navigate with **Apple Maps** or **Google Maps** over CarPlay, your **iPhone** can still send destination and ETA updates to the comma device over Wi‑Fi using a free **Shortcuts** automation.

## Requirements

1. comma device on the same Wi‑Fi as your iPhone — easiest: enable **AT&T**, **T-Mobile**, or **Verizon data plan + Wi‑Fi hotspot** (`att/README.md`, `tmobile/README.md`, `verizon/README.md`) and join the comma hotspot on your iPhone.
2. **LaneSync Pilot** with **PhoneNavEnabled** on (Settings → Developer → **iPhone Navigation (CarPlay)**).
3. iOS **Shortcuts** app.

Find your comma IP: phone browser → `http://<comma-ip>:7710/health` should return `{"ok":true,...}`.

## Quick test (Terminal on Mac)

```bash
curl -X POST http://192.168.1.100:7710/nav \
  -H "Content-Type: application/json" \
  -d '{
    "source": "carplay",
    "carplay_connected": true,
    "active": true,
    "destination": "1 Infinite Loop, Cupertino",
    "dest_lat": 37.3318,
    "dest_lon": -122.0312,
    "distance_remaining_m": 4200,
    "time_remaining_s": 480,
    "maneuver": "Continue on I-280 South"
  }'
```

You should see the destination banner on the openpilot HUD.

## Build the iOS Shortcut

### Shortcut: “Update comma navigation”

1. Open **Shortcuts** → **+** → name it `Update comma navigation`.
2. Add **Ask for Input** (Text) — prompt: `Destination name` → save as `Destination`.
3. Add **Get Current Location** → save as `Current Location`.
4. *(Optional)* Add **Get Details of Location** → Street Address for richer names.
5. Add **Get Contents of URL**:
   - URL: `http://YOUR_COMMA_IP:7710/nav`
   - Method: **POST**
   - Headers: `Content-Type` = `application/json`
   - Request Body: **JSON** with keys:

```json
{
  "source": "carplay",
  "carplay_connected": true,
  "active": true,
  "destination": "Destination",
  "dest_lat": "Latitude from Current Location",
  "dest_lon": "Longitude from Current Location",
  "maneuver": "Navigation active",
  "distance_remaining_m": 0,
  "time_remaining_s": 0
}
```

In Shortcuts, tap each value and pick the variables from previous steps (Magic Variables).

6. Add **Show Notification** — “Sent to comma”.

Replace `YOUR_COMMA_IP` with your device IP (e.g. `192.168.0.42`).

### Automation: refresh while driving (CarPlay)

1. **Shortcuts** → **Automation** → **+** → **CarPlay** → **Is Connected** (or **Bluetooth** → your car).
2. Action: **Run Shortcut** → `Update comma navigation`.
3. Turn off **Ask Before Running**.

### Automation: periodic updates

1. **Automation** → **Time of Day** is not ideal; use **Leave** or repeat:
2. **CarPlay** → **Connects** → Run shortcut, then add **Wait** 60 s → loop (advanced) or run shortcut manually when starting a trip.

### Stop navigation

Add a second shortcut **End comma navigation**:

- **Get Contents of URL** → `POST` → `http://YOUR_COMMA_IP:7710/nav/clear`

## Security (optional)

On the comma device:

```bash
params put PhoneNavToken "your-secret-token"
```

In Shortcuts, add header: `Authorization` = `Bearer your-secret-token`.

## Apple Maps / Google Maps note

iOS does not expose live Maps turn-by-turn to third parties. This bridge uses:

- Destination name you enter or share
- iPhone GPS for position
- Optional distance/time you paste or estimate

For richer maneuvers, use **Share** → **Shortcuts** if your Maps app supports it, or update the shortcut when Siri announces the next turn.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `health` fails | Same Wi‑Fi? Firewall? `PhoneNavEnabled=1` and onroad |
| HUD empty | POST body must include `"active": true` |
| Stale banner | Updates must arrive at least every 30 s |

See also [../../README.md](../../../README.md) and [../hud_mockup.html](../hud_mockup.html).
