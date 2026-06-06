"""Parse iPhone / CarPlay navigation updates (JSON over HTTP)."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any


@dataclass
class PhoneNavBuffer:
  valid: bool = False
  active: bool = False
  source: str = ""
  destination_name: str = ""
  dest_lat: float = 0.0
  dest_lon: float = 0.0
  distance_remaining_m: float = -1.0
  time_remaining_s: float = -1.0
  maneuver_text: str = ""
  carplay_connected: bool = False
  route: list[tuple[float, float]] = field(default_factory=list)
  rx_count: int = 0
  last_mono: float = 0.0


def _as_float(val: Any, default: float = -1.0) -> float:
  try:
    return float(val)
  except (TypeError, ValueError):
    return default


def _parse_route(route: Any) -> list[tuple[float, float]]:
  coords: list[tuple[float, float]] = []
  if not isinstance(route, list):
    return coords
  for pt in route:
    if not isinstance(pt, dict):
      continue
    lat = pt.get("lat", pt.get("latitude"))
    lon = pt.get("lon", pt.get("longitude"))
    if lat is None or lon is None:
      continue
    coords.append((_as_float(lat, 0.0), _as_float(lon, 0.0)))
  return coords


def apply_nav_json(buf: PhoneNavBuffer, payload: bytes, mono: float) -> bool:
  try:
    msg = json.loads(payload.decode("utf-8"))
  except (UnicodeDecodeError, json.JSONDecodeError):
    return False

  if not isinstance(msg, dict):
    return False

  if msg.get("clear") or msg.get("active") is False:
    buf.__init__()
    return True

  buf.valid = True
  buf.active = bool(msg.get("active", True))
  buf.rx_count += 1
  buf.last_mono = mono

  buf.source = str(msg.get("source", "iphone"))
  buf.destination_name = str(msg.get("destination", msg.get("destination_name", "")))
  buf.dest_lat = _as_float(msg.get("dest_lat", msg.get("destination_latitude")), buf.dest_lat)
  buf.dest_lon = _as_float(msg.get("dest_lon", msg.get("destination_longitude")), buf.dest_lon)
  buf.distance_remaining_m = _as_float(msg.get("distance_remaining_m", msg.get("distance_remaining")), buf.distance_remaining_m)
  buf.time_remaining_s = _as_float(msg.get("time_remaining_s", msg.get("time_remaining")), buf.time_remaining_s)
  buf.maneuver_text = str(msg.get("maneuver", msg.get("maneuver_text", "")))
  buf.carplay_connected = bool(msg.get("carplay_connected", msg.get("carplay", False)))
  if "route" in msg:
    buf.route = _parse_route(msg["route"])

  return True


def fill_phone_nav_capnp(nav: Any, buf: PhoneNavBuffer, now_mono: float) -> None:
  nav.valid = buf.valid
  nav.active = buf.active
  nav.source = buf.source
  nav.destinationName = buf.destination_name
  nav.destinationLatitude = buf.dest_lat
  nav.destinationLongitude = buf.dest_lon
  nav.distanceRemaining = buf.distance_remaining_m
  nav.timeRemaining = buf.time_remaining_s
  nav.maneuverText = buf.maneuver_text
  nav.carplayConnected = buf.carplay_connected
  nav.rxCount = buf.rx_count
  if buf.last_mono > 0:
    nav.messageAge = max(0.0, now_mono - buf.last_mono)
  else:
    nav.messageAge = 0.0
