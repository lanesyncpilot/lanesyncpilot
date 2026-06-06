#!/usr/bin/env python3
"""Receive navigation from iPhone (Shortcuts) while using Apple CarPlay / Maps."""

import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Callable

import cereal.messaging as messaging
from openpilot.common.params import Params
from openpilot.common.realtime import Ratekeeper
from openpilot.common.swaglog import cloudlog
from openpilot.system.v2i.phone_nav_protocol import PhoneNavBuffer, apply_nav_json, fill_phone_nav_capnp

PHONE_NAV_PORT = int(os.getenv("PHONE_NAV_PORT", "7710"))
STALE_TIMEOUT = float(os.getenv("PHONE_NAV_STALE_TIMEOUT", "30.0"))
PUBLISH_HZ = 1.0


class _NavState:
  def __init__(self) -> None:
    self.lock = threading.Lock()
    self.buf = PhoneNavBuffer()
    self.pending: bytes | None = None
    self.auth_token: str | None = None


_NAV = _NavState()


class PhoneNavHandler(BaseHTTPRequestHandler):
  def log_message(self, fmt: str, *args) -> None:
    cloudlog.debug("phonenavd " + (fmt % args))

  def _check_auth(self) -> bool:
    token = _NAV.auth_token
    if not token:
      return True
    auth = self.headers.get("Authorization", "")
    if auth == f"Bearer {token}":
      return True
    from urllib.parse import parse_qs, urlparse
    qs = parse_qs(urlparse(self.path).query)
    return qs.get("token", [None])[0] == token

  def _read_body(self) -> bytes:
    length = int(self.headers.get("Content-Length", 0))
    return self.rfile.read(length) if length else b""

  def _respond(self, code: int, body: dict) -> None:
    data = json.dumps(body).encode()
    self.send_response(code)
    self.send_header("Content-Type", "application/json")
    self.send_header("Content-Length", str(len(data)))
    self.end_headers()
    self.wfile.write(data)

  def do_GET(self) -> None:
    if self.path.startswith("/health"):
      with _NAV.lock:
        b = _NAV.buf
        self._respond(200, {
          "ok": True,
          "active": b.active,
          "destination": b.destination_name,
          "carplay": b.carplay_connected,
        })
      return
    self._respond(404, {"error": "not found"})

  def do_POST(self) -> None:
    if not self._check_auth():
      self._respond(401, {"error": "unauthorized"})
      return

    if self.path.startswith("/nav/clear") or self.path.startswith("/nav/stop"):
      with _NAV.lock:
        _NAV.pending = json.dumps({"active": False}).encode()
      self._respond(200, {"ok": True, "cleared": True})
      return

    if not self.path.startswith("/nav"):
      self._respond(404, {"error": "not found"})
      return

    body = self._read_body()
    with _NAV.lock:
      _NAV.pending = body
    self._respond(200, {"ok": True})


def _run_http_server(port: int, stop: Callable[[], bool]) -> None:
  server = HTTPServer(("0.0.0.0", port), PhoneNavHandler)
  server.timeout = 0.5
  cloudlog.info(f"phonenavd HTTP listening on port {port}")
  while not stop():
    server.handle_request()
  server.server_close()


def _publish_nav_messages(pm: messaging.PubMaster, buf: PhoneNavBuffer) -> None:
  phone_msg = messaging.new_message("phoneNavState")
  fill_phone_nav_capnp(phone_msg.phoneNavState, buf, time.monotonic())
  phone_msg.valid = buf.valid and buf.active
  pm.send("phoneNavState", phone_msg)

  if not buf.active:
    return

  instr = messaging.new_message("navInstruction")
  ni = instr.navInstruction
  ni.maneuverPrimaryText = buf.maneuver_text or f"Navigate to {buf.destination_name}"
  ni.maneuverSecondaryText = buf.destination_name
  if buf.distance_remaining_m >= 0:
    ni.distanceRemaining = buf.distance_remaining_m
  if buf.time_remaining_s >= 0:
    ni.timeRemaining = buf.time_remaining_s
    ni.timeRemainingTypical = buf.time_remaining_s
  instr.valid = True
  pm.send("navInstruction", instr)

  if buf.route:
    route_msg = messaging.new_message("navRoute")
    coords = route_msg.navRoute.coordinates
    del coords[:]
    for lat, lon in buf.route[:500]:
      c = coords.add()
      c.latitude = lat
      c.longitude = lon
    route_msg.valid = True
    pm.send("navRoute", route_msg)


def main() -> None:
  params = Params()
  port = int(params.get("PhoneNavPort") or PHONE_NAV_PORT)
  _NAV.auth_token = params.get("PhoneNavToken") or None

  stop_flag = {"stop": False}

  http_thread = threading.Thread(
    target=_run_http_server,
    args=(port, lambda: stop_flag["stop"]),
    daemon=True,
  )
  http_thread.start()

  pm = messaging.PubMaster(["phoneNavState", "navInstruction", "navRoute"])
  rk = Ratekeeper(PUBLISH_HZ, print_delay_threshold=None)

  try:
    while True:
      with _NAV.lock:
        if _NAV.pending is not None:
          apply_nav_json(_NAV.buf, _NAV.pending, time.monotonic())
          _NAV.pending = None
        buf = _NAV.buf

      now = time.monotonic()
      if buf.valid and buf.last_mono > 0 and (now - buf.last_mono) > STALE_TIMEOUT:
        buf.active = False

      _publish_nav_messages(pm, buf)

      rk.keep_time()
  finally:
    stop_flag["stop"] = True
    http_thread.join(timeout=2.0)


if __name__ == "__main__":
  main()
