"""JSON-over-UDP V2I message parsing (SPaT / speed advisory / hazard)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from cereal import custom
from openpilot.system.v2i.j2735 import decode as decode_j2735


SIGNAL_MAP = {
  "unknown": custom.V2IState.TrafficLight.unknown,
  "red": custom.V2IState.TrafficLight.red,
  "yellow": custom.V2IState.TrafficLight.yellow,
  "green": custom.V2IState.TrafficLight.green,
  "flashing_red": custom.V2IState.TrafficLight.flashingRed,
  "flashing_yellow": custom.V2IState.TrafficLight.flashingYellow,
}

HAZARD_MAP = {
  "none": custom.V2IState.Hazard.none,
  "work_zone": custom.V2IState.Hazard.workZone,
  "congestion": custom.V2IState.Hazard.congestion,
  "weather": custom.V2IState.Hazard.weather,
  "emergency_vehicle": custom.V2IState.Hazard.emergencyVehicle,
}


@dataclass
class V2IBuffer:
  valid: bool = False
  intersection_id: str = ""
  distance_m: float = -1.0
  traffic_light_valid: bool = False
  traffic_light: int = int(custom.V2IState.TrafficLight.unknown)
  time_to_change: float = 0.0
  speed_advisory_valid: bool = False
  speed_advisory_mps: float = 0.0
  hazard_valid: bool = False
  hazard: int = int(custom.V2IState.Hazard.none)
  rx_count: int = 0
  last_mono: float = 0.0


def _as_float(val: Any, default: float = -1.0) -> float:
  try:
    return float(val)
  except (TypeError, ValueError):
    return default


def apply_message(buf: V2IBuffer, payload: bytes, mono: float) -> bool:
  j2735 = decode_j2735(payload)
  if j2735 is not None:
    msg_type, fields = j2735
    fields = {"type": msg_type, **fields}
    return apply_message(buf, json.dumps(fields).encode("utf-8"), mono)

  try:
    msg = json.loads(payload.decode("utf-8"))
  except (UnicodeDecodeError, json.JSONDecodeError):
    return False

  if not isinstance(msg, dict):
    return False

  msg_type = str(msg.get("type", "")).lower()
  if not msg_type:
    return False

  buf.valid = True
  buf.rx_count += 1
  buf.last_mono = mono

  if "intersection_id" in msg:
    buf.intersection_id = str(msg["intersection_id"])
  if "distance_m" in msg:
    buf.distance_m = _as_float(msg["distance_m"], buf.distance_m)

  if msg_type in ("spat", "traffic_light"):
    signal = str(msg.get("signal", "unknown")).lower()
    buf.traffic_light_valid = True
    buf.traffic_light = int(SIGNAL_MAP.get(signal, custom.V2IState.TrafficLight.unknown))
    buf.time_to_change = max(0.0, _as_float(msg.get("time_to_change"), 0.0))
    return True

  if msg_type in ("speed_advisory", "speed"):
    speed = msg.get("speed_mps", msg.get("speed_mph"))
    if speed is None:
      return False
    speed_f = _as_float(speed, -1.0)
    if "speed_mph" in msg:
      speed_f *= 0.44704
    if speed_f < 0:
      return False
    buf.speed_advisory_valid = True
    buf.speed_advisory_mps = speed_f
    return True

  if msg_type == "hazard":
    hazard = str(msg.get("hazard", "none")).lower()
    buf.hazard_valid = True
    buf.hazard = int(HAZARD_MAP.get(hazard, custom.V2IState.Hazard.none))
    return True

  if msg_type == "clear":
    buf.__init__()
    return True

  return False


def fill_capnp(v2i: Any, buf: V2IBuffer, now_mono: float) -> None:
  v2i.valid = buf.valid
  v2i.intersectionId = buf.intersection_id
  v2i.distanceToIntersection = buf.distance_m
  v2i.trafficLightValid = buf.traffic_light_valid
  v2i.trafficLight = buf.traffic_light
  v2i.timeToChange = buf.time_to_change
  v2i.speedAdvisoryValid = buf.speed_advisory_valid
  v2i.speedAdvisory = buf.speed_advisory_mps
  v2i.hazardValid = buf.hazard_valid
  v2i.hazard = buf.hazard
  v2i.rxCount = buf.rx_count
  if buf.last_mono > 0:
    v2i.messageAge = max(0.0, now_mono - buf.last_mono)
  else:
    v2i.messageAge = 0.0
