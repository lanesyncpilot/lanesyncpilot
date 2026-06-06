"""WiFi / AT&T cellular status for V2I connectivity."""

from __future__ import annotations

import pyray as rl
from openpilot.selfdrive.ui.ui_state import ui_state
from openpilot.system.ui.lib.application import gui_app, FontWeight


def draw_v2i_network_badge(x: float, y: float) -> None:
  sm = ui_state.sm
  if not sm.valid.get("v2iNetworkState", False):
    return
  net = sm["v2iNetworkState"]
  if not net.valid:
    return

  parts = []
  if net.wifiConnected:
    ssid = net.wifiSsid or "Wi‑Fi"
    if len(ssid) > 12:
      ssid = ssid[:10] + "…"
    parts.append(f"Wi‑Fi {ssid}")
  elif net.wifiEnabled:
    parts.append("Wi‑Fi on")
  if net.cellularActive:
    carrier = (net.carrier or "LTE").upper()
    if carrier == "ATT":
      carrier = "AT&T"
    parts.append(carrier)
  if net.deviceIp:
    parts.append(net.deviceIp)

  if not parts:
    return

  text = " · ".join(parts)
  font = gui_app.font(FontWeight.MEDIUM)
  pad = 8
  tw = rl.measure_text_ex(font, text, 18, 1).x
  rl.draw_rectangle_rounded(rl.Rectangle(x, y, tw + pad * 2, 28), 0.3, 6, rl.Color(0, 0, 0, 140))
  color = rl.Color(128, 216, 166, 255) if net.wifiConnected or net.cellularActive else rl.Color(180, 180, 180, 255)
  rl.draw_text_ex(font, text, rl.Vector2(x + pad, y + 6), 18, 0, color)
