# T-Mobile data plan + Wi‑Fi for V2I / iPhone nav

Use a **T-Mobile SIM** in your comma device for cellular data, and turn on the **Wi‑Fi hotspot** so your iPhone (CarPlay / Shortcuts) can reach `phonenavd` and `v2id` on the same network.

## Files

| File | Purpose |
|------|---------|
| `dataplan.json` | APN profiles (`consumer`, `wholesale`, `iot_m2m`, …) |
| `tmobile-lte.nmconnection` | NetworkManager GSM profile for T-Mobile |
| `apply_dataplan.sh` | One-shot setup on the device |

## On-device setup

```bash
# Copy this folder to the comma (from your laptop)
scp -r tmobile comma@<device-ip>:/data/

ssh comma@<device-ip>
chmod +x /data/tmobile/apply_dataplan.sh
/data/tmobile/apply_dataplan.sh consumer
```

Or enable in UI: **Settings → Developer → T-Mobile data plan + Wi‑Fi hotspot**.

## APN profiles

| Profile | APN | When to use |
|---------|-----|-------------|
| `consumer` | `fast.t-mobile.com` | Default T-Mobile phone/data SIM |
| `wholesale` | `wholesale` | MVNO / wholesale SIMs |
| `iot_m2m` | `iot.tmowholesale.com` | T-Mobile business / IoT SIM |
| `firstnet` | `firstnet-broadband` | FirstNet SIM |

Change profile:

```bash
params set TmobileDataPlanProfile wholesale
params put_bool OnroadCycleRequested 1
```

## Params

| Param | Default | Meaning |
|-------|---------|---------|
| `TmobileDataPlanEnabled` | 0 | Run `tmobiled` and apply T-Mobile APN |
| `TmobileDataPlanProfile` | `consumer` | Key in `dataplan.json` |
| `TmobileWifiHotspot` | 1 | Start Wi‑Fi hotspot when onroad |
| `V2ITmobileApn` | — | T-Mobile APN override |
| `V2ICarrier` | `att` | Set to `tmobile` when using T-Mobile |

## Verify

```bash
mmcli -m 0 | grep -E 'state|operator'
curl -s http://127.0.0.1:7710/health
nmcli con show --active
```
