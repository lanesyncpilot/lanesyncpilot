# AT&T data plan + Wi‑Fi for V2I / iPhone nav

Use an **AT&T SIM** in your comma device for cellular data, and turn on the **Wi‑Fi hotspot** so your iPhone (CarPlay / Shortcuts) can reach `phonenavd` and `v2id` on the same network.

## Files

| File | Purpose |
|------|---------|
| `dataplan.json` | APN profiles (`consumer`, `iot_m2m`, `firstnet`, …) |
| `att-lte.nmconnection` | NetworkManager GSM profile for AT&T |
| `apply_dataplan.sh` | One-shot setup on the device |

## On-device setup

```bash
# Copy this folder to the comma (from your laptop)
scp -r att comma@<device-ip>:/data/

ssh comma@<device-ip>
chmod +x /data/att/apply_dataplan.sh
/data/att/apply_dataplan.sh consumer
```

Or enable in UI: **Settings → Developer → AT&T data plan + Wi‑Fi hotspot**.

## APN profiles

| Profile | APN | When to use |
|---------|-----|-------------|
| `consumer` | `broadband` | Default AT&T phone/data SIM |
| `nxtgenphone` | `nxtgenphone` | If `broadband` fails |
| `iot_m2m` | `PRODATA` | AT&T business / IoT SIM |
| `firstnet` | `firstnet-broadband` | FirstNet SIM |

Change profile:

```bash
params set AttDataPlanProfile iot_m2m
params put_bool OnroadCycleRequested 1
```

## iPhone on comma Wi‑Fi

1. After hotspot is on, join the comma Wi‑Fi network on your iPhone (SSID like `weedle-xxxx`).
2. Use comma IP (often `192.168.43.1` on hotspot — check Settings → Network on device).
3. Point iOS Shortcuts at `http://<comma-ip>:7710/nav` (see `openpilot-0.11.0/tools/v2i/ios/README.md`).

## Params

| Param | Default | Meaning |
|-------|---------|---------|
| `AttDataPlanEnabled` | 0 | Run `attd` and apply AT&T APN |
| `AttDataPlanProfile` | `consumer` | Key in `dataplan.json` |
| `AttWifiHotspot` | 1 | Start Wi‑Fi hotspot when onroad |
| `GsmApn` | (set by attd) | AT&T APN string |

## Verify

```bash
# Cellular
mmcli -m 0 | grep -E 'state|operator'
curl -s http://127.0.0.1:7710/health

# Hotspot — iPhone should see comma SSID
nmcli con show --active
```
