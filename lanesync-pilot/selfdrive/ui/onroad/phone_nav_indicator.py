"""HUD destination banner from iPhone / CarPlay navigation bridge."""

from __future__ import annotations

import pyray as rl
from openpilot.selfdrive.ui.ui_state import ui_state
from openpilot.system.ui.lib.application import gui_app, FontWeight
from openpilot.system.ui.lib.text_measure import measure_text_cached

STALE_AGE = 30.0


def _nav_active() -> bool:
  sm = ui_state.sm
  if not sm.valid.get("phoneNavState", False):
    return False
  nav = sm["phoneNavState"]
  return nav.valid and nav.active and nav.messageAge < STALE_AGE


def draw_phone_nav_banner(x: float, y: float, max_width: float = 520) -> None:
  if not _nav_active():
    return

  nav = ui_state.sm["phoneNavState"]
  dest = nav.destinationName or "Destination"
  maneuver = nav.maneuverText

  if nav.carplayConnected:
    prefix = "CarPlay · "
  elif nav.source:
    prefix = f"{nav.source} · "
  else:
    prefix = ""

  line1 = prefix + dest
  if len(line1) > 48:
    line1 = line1[:45] + "..."

  font_bold = gui_app.font(FontWeight.SEMI_BOLD)
  font_med = gui_app.font(FontWeight.MEDIUM)

  w1 = min(measure_text_cached(font_bold, line1, 26).x, max_width)
  h = 56
  if maneuver:
    h += 28

  rl.draw_rectangle_rounded(rl.Rectangle(x, y, w1 + 28, h), 0.25, 8, rl.Color(0, 0, 0, 150))
  rl.draw_text_ex(font_bold, line1, rl.Vector2(x + 14, y + 10), 26, 0, rl.WHITE)

  if maneuver:
    m = maneuver if len(maneuver) <= 56 else maneuver[:53] + "..."
    rl.draw_text_ex(font_med, m, rl.Vector2(x + 14, y + 38), 22, 0, rl.Color(255, 255, 255, 190))

  if nav.distanceRemaining >= 0:
    dist = nav.distanceRemaining
    if ui_state.is_metric:
      if dist >= 1000:
        eta_dist = f"{dist / 1000:.1f} km"
      else:
        eta_dist = f"{int(dist)} m"
    else:
      dist_ft = dist * 3.28084
      if dist_ft >= 5280:
        eta_dist = f"{dist_ft / 5280:.1f} mi"
      else:
        eta_dist = f"{int(dist_ft)} ft"
    if nav.timeRemaining >= 0:
      mins = int(nav.timeRemaining // 60)
      eta_dist += f" · {mins} min"
    tw = measure_text_cached(font_med, eta_dist, 20).x
    rl.draw_text_ex(font_med, eta_dist, rl.Vector2(x + w1 + 28 - tw - 14, y + 12), 20, 0, rl.Color(128, 216, 166, 255))
