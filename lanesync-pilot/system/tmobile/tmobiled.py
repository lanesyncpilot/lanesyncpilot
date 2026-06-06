#!/usr/bin/env python3
"""Apply T-Mobile cellular data plan and enable Wi‑Fi hotspot for V2I / iPhone bridge."""

import os
import shutil
import subprocess
import time

from openpilot.common.params import Params
from openpilot.common.realtime import Ratekeeper
from openpilot.common.swaglog import cloudlog
from openpilot.system.tmobile.tmobile_config import get_profile, tmobile_config_dirs
from openpilot.system.hardware import PC, TICI

HOTSPOT_CON_NAME = "Hotspot"
LTE_CON_NAMES = ("lte", "tmobile-lte")


def _run(cmd: list[str], check: bool = False) -> subprocess.CompletedProcess:
  return subprocess.run(cmd, capture_output=True, text=True, check=check)


def _nmcli_available() -> bool:
  return shutil.which("nmcli") is not None


def apply_gsm_apn(apn: str, roaming: bool, metered: bool) -> None:
  params = Params()
  if apn:
    params.put("GsmApn", apn)
    params.put("V2ITmobileApn", apn)
  else:
    params.remove("GsmApn")
  params.put("V2ICarrier", "tmobile")
  params.put_bool("GsmRoaming", roaming)
  params.put_bool("GsmMetered", metered)

  if not _nmcli_available():
    return

  for con in LTE_CON_NAMES:
    r = _run(["nmcli", "con", "show", con])
    if r.returncode != 0:
      continue
    _run(["nmcli", "con", "mod", con, "gsm.apn", apn, "gsm.auto-config", "no"])
    _run(["nmcli", "con", "mod", con, "gsm.home-only", "yes" if not roaming else "no"])
    _run(["nmcli", "con", "mod", con, "connection.metered", "yes" if metered else "no"])
    cloudlog.info(f"tmobiled configured nmcli connection {con} apn={apn}")


def install_nmconnection() -> None:
  if not _nmcli_available():
    return
  dest = "/etc/NetworkManager/system-connections/tmobile-lte.nmconnection"
  for d in tmobile_config_dirs():
    src = d / "tmobile-lte.nmconnection"
    if not src.is_file():
      continue
    try:
      shutil.copy(src, dest)
      os.chmod(dest, 0o600)
      _run(["nmcli", "con", "load", dest])
      cloudlog.info("tmobiled installed tmobile-lte.nmconnection")
    except OSError as e:
      cloudlog.warning(f"tmobiled could not install nmconnection: {e}")
    break


def bring_up_cellular() -> None:
  if not _nmcli_available():
    return
  for con in LTE_CON_NAMES:
    r = _run(["nmcli", "con", "up", con])
    if r.returncode == 0:
      cloudlog.info(f"tmobiled brought up {con}")
      return
  cloudlog.warning("tmobiled failed to activate LTE connection")


def enable_wifi_hotspot() -> None:
  if not _nmcli_available():
    return
  r = _run(["nmcli", "con", "up", HOTSPOT_CON_NAME])
  if r.returncode == 0:
    cloudlog.info("tmobiled enabled Wi‑Fi hotspot")
  else:
    cloudlog.warning(f"tmobiled hotspot activate: {r.stderr.strip()}")


def main() -> None:
  params = Params()
  profile_name = params.get("TmobileDataPlanProfile") or "consumer"
  custom_apn = params.get("V2ITmobileApn") or ""
  profile = get_profile(profile_name)
  apn = custom_apn.strip() or str(profile.get("apn", "fast.t-mobile.com"))
  roaming = bool(profile.get("roaming", False))
  metered = bool(profile.get("metered", False))
  hotspot = params.get_bool("TmobileWifiHotspot")

  cloudlog.info(f"tmobiled starting profile={profile_name} apn={apn} hotspot={hotspot}")

  apply_gsm_apn(apn, roaming, metered)

  if TICI and not PC:
    install_nmconnection()
    bring_up_cellular()
    if hotspot:
      enable_wifi_hotspot()

  rk = Ratekeeper(0.05, print_delay_threshold=None)
  last_hotspot = 0.0
  while True:
    if params.get_bool("TmobileWifiHotspot") and TICI and not PC:
      if time.monotonic() - last_hotspot > 120.0:
        enable_wifi_hotspot()
        last_hotspot = time.monotonic()
    rk.keep_time()


if __name__ == "__main__":
  main()
