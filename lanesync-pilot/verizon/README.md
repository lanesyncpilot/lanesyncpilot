# Verizon data plan + Wi‑Fi for V2I / iPhone nav

Use a **Verizon SIM** in your comma device for cellular data, and turn on the **Wi‑Fi hotspot** so your iPhone (CarPlay / Shortcuts) can reach `phonenavd` and `v2id` on the same network.

## Files

| File | Purpose |
|------|---------|
| `dataplan.json` | APN profiles (`consumer`, `ims`, `iot_m2m`, …) |
| `verizon-lte.nmconnection` | NetworkManager GSM profile for Verizon |
| `apply_dataplan.sh` | One-shot setup on the device |

## On-device setup

```bash
scp -r verizon comma@<device-ip>:/data/

ssh comma@<device-ip>
chmod +x /data/verizon/apply_dataplan.sh
/data/verizon/apply_dataplan.sh consumer
```

Or enable in UI: **Settings → Developer → Verizon data plan + Wi‑Fi hotspot**.

## APN profiles

| Profile | APN | When to use |
|---------|-----|-------------|
| `consumer` | `vzwinternet` | Default Verizon phone/data SIM |
| `ims` | `vzwims` | If `vzwinternet` fails |
| `iot_m2m` | `vzwinternet` | Verizon business / IoT SIM |
| `firstnet` | `firstnet-broadband` | FirstNet SIM |

Change profile:

```bash
params set VerizonDataPlanProfile ims
params put_bool OnroadCycleRequested 1
```

## Params

| Param | Default | Meaning |
|-------|---------|---------|
| `VerizonDataPlanEnabled` | 0 | Run `verizond` and apply Verizon APN |
| `VerizonDataPlanProfile` | `consumer` | Key in `dataplan.json` |
| `VerizonWifiHotspot` | 1 | Start Wi‑Fi hotspot when onroad |
| `V2IVerizonApn` | — | Verizon APN override |
| `V2ICarrier` | `att` | Set to `verizon` when using Verizon |

## Verify

```bash
mmcli -m 0 | grep -E 'state|operator'
curl -s http://127.0.0.1:7710/health
nmcli con show --active
```
