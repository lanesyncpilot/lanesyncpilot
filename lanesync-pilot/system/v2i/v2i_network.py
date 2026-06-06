"""WiFi + cellular (AT&T / T-Mobile / Verizon) connectivity helpers for V2I / phone nav."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from typing import Optional

from openpilot.common.swaglog import cloudlog

# AT&T consumer / IoT APNs (SIM must be activated on an AT&T data plan)
ATT_APN_PRESETS = {
  "phone": "phone",           # legacy smartphones
  "nxtgenphone": "nxtgenphone",  # LTE smartphones / most plans
  "broadband": "broadband",   # mobile hotspot / tablet plans
  "enhancedphone": "enhancedphone",
}

DEFAULT_ATT_APN = "nxtgenphone"
DEFAULT_TMOBILE_APN = "fast.t-mobile.com"

TMOBILE_APN_PRESETS = {
  "consumer": "fast.t-mobile.com",
  "wholesale": "wholesale",
  "iot_m2m": "iot.tmowholesale.com",
}

DEFAULT_VERIZON_APN = "vzwinternet"

VERIZON_APN_PRESETS = {
  "consumer": "vzwinternet",
  "ims": "vzwims",
  "iot_m2m": "vzwinternet",
}

CARRIER_APN = {
  "att": DEFAULT_ATT_APN,
  "tmobile": DEFAULT_TMOBILE_APN,
  "verizon": DEFAULT_VERIZON_APN,
  "auto": "",
}


@dataclass
class NetworkStatus:
  wifi_enabled: bool = False
  wifi_connected: bool = False
  wifi_ssid: str = ""
  cellular_active: bool = False
  carrier: str = ""
  apn: str = ""
  device_ip: str = ""
  lte_connected: bool = False


def resolve_apn(carrier: str, custom_apn: str) -> str:
  if custom_apn.strip():
    return custom_apn.strip()
  return CARRIER_APN.get(carrier.lower(), "")


def ensure_wifi_radio_on() -> None:
  try:
    subprocess.run(["nmcli", "radio", "wifi", "on"], check=False, timeout=5)
  except Exception as e:
    cloudlog.warning(f"v2i network: nmcli wifi on failed: {e}")


def read_network_status() -> NetworkStatus:
  st = NetworkStatus()
  try:
    r = subprocess.run(
      ["nmcli", "-t", "-f", "WIFI", "radio"],
      capture_output=True, text=True, timeout=5,
    )
    st.wifi_enabled = r.stdout.strip().lower() == "enabled"
  except Exception:
    pass

  try:
    r = subprocess.run(
      ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
      capture_output=True, text=True, timeout=5,
    )
    for line in r.stdout.splitlines():
      parts = line.split(":")
      if len(parts) >= 2 and parts[0] == "yes":
        st.wifi_connected = True
        st.wifi_ssid = parts[1]
        break
  except Exception:
    pass

  try:
    r = subprocess.run(
      ["nmcli", "-t", "-f", "TYPE,STATE", "dev", "status"],
      capture_output=True, text=True, timeout=5,
    )
    for line in r.stdout.splitlines():
      if line.startswith("gsm:") or line.startswith("cdma:"):
        st.cellular_active = "connected" in line
        st.lte_connected = st.cellular_active
  except Exception:
    pass

  try:
    r = subprocess.run(
      ["nmcli", "-t", "-f", "IP4.ADDRESS", "dev", "show"],
      capture_output=True, text=True, timeout=5,
    )
    for line in r.stdout.splitlines():
      if line and ":" in line:
        ip = line.split(":")[-1].split("/")[0]
        if ip and not ip.startswith("127."):
          st.device_ip = ip
          break
  except Exception:
    pass

  return st


def apply_gsm_via_wifi_manager(carrier: str, apn: str, allow_cellular: bool) -> None:
  """Apply APN through NetworkManager (same path as stock network settings)."""
  try:
    from openpilot.system.ui.lib.wifi_manager import WifiManager
    wm = WifiManager()
    wm.set_active(True)
    ensure_wifi_radio_on()
    metered = not allow_cellular
    roaming = carrier not in ("att", "tmobile", "verizon")
    wm.update_gsm_settings(roaming=roaming, apn=apn, metered=metered)
    cloudlog.info(f"v2i network: applied carrier={carrier} apn={apn!r} metered={metered}")
  except Exception as e:
    cloudlog.warning(f"v2i network: WifiManager GSM apply failed: {e}")
