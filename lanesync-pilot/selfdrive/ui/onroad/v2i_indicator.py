"""Onroad HUD indicator for infrastructure traffic signals."""

from __future__ import annotations

import pyray as rl
from cereal import custom
from openpilot.selfdrive.ui.ui_state import ui_state
from openpilot.system.ui.lib.application import gui_app, FontWeight
from openpilot.system.ui.lib.text_measure import measure_text_cached

V2I_STALE_AGE = 2.0
LAMP_RADIUS = 14
LAMP_GAP = 8


def _v2i_active() -> bool:
  sm = ui_state.sm
  if not sm.valid.get("v2iState", False):
    return False
  v2i = sm["v2iState"]
  return v2i.valid and v2i.messageAge < V2I_STALE_AGE


def _lamp_color(active: bool, on: bool, on_color: rl.Color, off_color: rl.Color) -> rl.Color:
  if not active:
    return off_color
  return on_color if on else off_color


def draw_v2i_indicator(x: float, y: float, font_size: int = 28) -> None:
  """Draw a vertical traffic-light stack with countdown when V2I is active."""
  if not _v2i_active():
    return

  v2i = ui_state.sm["v2iState"]
  if not v2i.trafficLightValid:
    return

  tl = v2i.trafficLight
  is_red = tl in (custom.V2IState.TrafficLight.red, custom.V2IState.TrafficLight.flashingRed)
  is_yellow = tl in (custom.V2IState.TrafficLight.yellow, custom.V2IState.TrafficLight.flashingYellow)
  is_green = tl == custom.V2IState.TrafficLight.green

  off = rl.Color(60, 60, 60, 200)
  red = rl.Color(220, 50, 50, 255)
  yellow = rl.Color(230, 200, 40, 255)
  green = rl.Color(50, 200, 90, 255)

  cx = int(x + LAMP_RADIUS)
  cy = int(y + LAMP_RADIUS)
  rl.draw_rectangle_rounded(
    rl.Rectangle(x, y, LAMP_RADIUS * 2 + 12, LAMP_RADIUS * 6 + LAMP_GAP * 2 + 16),
    0.2, 8, rl.Color(0, 0, 0, 140),
  )

  for i, (on, col) in enumerate([(is_red, red), (is_yellow, yellow), (is_green, green)]):
    ly = cy + i * (LAMP_RADIUS * 2 + LAMP_GAP)
    color = _lamp_color(True, on, col, off)
    rl.draw_circle(cx + 6, ly, LAMP_RADIUS, color)
    if on and tl in (custom.V2IState.TrafficLight.flashingRed, custom.V2IState.TrafficLight.flashingYellow):
      rl.draw_circle_lines(cx + 6, ly, LAMP_RADIUS + 2, rl.WHITE)

  if v2i.timeToChange > 0:
    font = gui_app.font(FontWeight.MEDIUM)
    ttc = f"{int(v2i.timeToChange)}s"
    tw = measure_text_cached(font, ttc, font_size).x
    rl.draw_text_ex(font, ttc, rl.Vector2(cx + 6 - tw / 2, y + LAMP_RADIUS * 6 + LAMP_GAP * 2 + 20),
                    font_size, 0, rl.WHITE)

  if v2i.distanceToIntersection >= 0:
    font = gui_app.font(FontWeight.MEDIUM)
    dist = v2i.distanceToIntersection
    unit = "m" if ui_state.is_metric else "ft"
    if not ui_state.is_metric:
      dist *= 3.28084
    dist_text = f"{int(dist)}{unit}"
    rl.draw_text_ex(font, dist_text, rl.Vector2(x, y - 30), 24, 0, rl.Color(255, 255, 255, 180))


def draw_v2i_hazard_badge(x: float, y: float) -> None:
  if not _v2i_active():
    return
  v2i = ui_state.sm["v2iState"]
  if not v2i.hazardValid or v2i.hazard == custom.V2IState.Hazard.none:
    return

  labels = {
    custom.V2IState.Hazard.workZone: "WORK ZONE",
    custom.V2IState.Hazard.congestion: "CONGESTION",
    custom.V2IState.Hazard.weather: "WEATHER",
    custom.V2IState.Hazard.emergencyVehicle: "EMERGENCY",
  }
  text = labels.get(v2i.hazard, "HAZARD")
  font = gui_app.font(FontWeight.SEMI_BOLD)
  tw = measure_text_cached(font, text, 26).x
  pad = 12
  rl.draw_rectangle_rounded(rl.Rectangle(x, y, tw + pad * 2, 40), 0.3, 6, rl.Color(200, 120, 0, 220))
  rl.draw_text_ex(font, text, rl.Vector2(x + pad, y + 8), 26, 0, rl.WHITE)
