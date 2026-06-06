#!/usr/bin/env python3
"""Keep WiFi on and configure AT&T / T-Mobile / Verizon cellular data for V2I / phone nav."""

import time

import cereal.messaging as messaging
from openpilot.common.params import Params
from openpilot.common.realtime import Ratekeeper
from openpilot.common.swaglog import cloudlog
from openpilot.system.v2i.v2i_network import (
  apply_gsm_via_wifi_manager,
  ensure_wifi_radio_on,
  read_network_status,
  resolve_apn,
)

PUBLISH_HZ = 0.2
APPLY_INTERVAL = 30.0


def _fill_network_msg(msg, st, carrier: str, apn: str, phonenav_up: bool) -> None:
  n = msg.v2iNetworkState
  n.valid = True
  n.wifiEnabled = st.wifi_enabled
  n.wifiConnected = st.wifi_connected
  n.wifiSsid = st.wifi_ssid
  n.cellularActive = st.cellular_active or st.lte_connected
  n.carrier = carrier
  n.apn = apn
  n.deviceIp = st.device_ip
  n.phonenavListening = phonenav_up
  n.allowCellularData = True


def _phonenav_listening() -> bool:
  import socket
  for port in (7710, 7701):
    try:
      s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      s.settimeout(0.3)
      s.connect(("127.0.0.1", port))
      s.close()
      return True
    except OSError:
      continue
  return False


def main() -> None:
  params = Params()
  rk = Ratekeeper(PUBLISH_HZ, print_delay_threshold=None)
  pm = messaging.PubMaster(["v2iNetworkState"])

  last_apply = 0.0
  carrier = params.get("V2ICarrier") or "att"
  allow_cellular = params.get_bool("V2IAllowCellular")

  cloudlog.info(f"v2inetd starting carrier={carrier}")

  while True:
    wifi_on = params.get_bool("V2IWifiEnabled")
    carrier = params.get("V2ICarrier") or "att"
    if carrier == "tmobile":
      custom_apn = params.get("V2ITmobileApn") or ""
    elif carrier == "verizon":
      custom_apn = params.get("V2IVerizonApn") or ""
    else:
      custom_apn = params.get("V2IAttApn") or ""
    allow_cellular = params.get_bool("V2IAllowCellular")
    apn = resolve_apn(carrier, custom_apn)

    now = time.monotonic()
    if now - last_apply >= APPLY_INTERVAL:
      if wifi_on:
        ensure_wifi_radio_on()
      if carrier not in ("", "none", "wifi_only") and apn:
        apply_gsm_via_wifi_manager(carrier, apn, allow_cellular)
        if allow_cellular:
          params.put_bool("GsmMetered", False)
          params.put("GsmApn", apn)
      last_apply = now

    st = read_network_status()
    msg = messaging.new_message("v2iNetworkState")
    _fill_network_msg(msg, st, carrier, apn, _phonenav_listening())
    msg.valid = True
    pm.send("v2iNetworkState", msg)

    rk.keep_time()


if __name__ == "__main__":
  main()
