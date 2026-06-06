#!/usr/bin/env python3
"""Serve hud_mockup.html and proxy nav/V2I to a comma device (avoids browser CORS)."""

import argparse
import json
import socket
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
HTML = HERE / "hud_mockup.html"
V2I_PORT = 7701


class Handler(BaseHTTPRequestHandler):
  comma_ip = "192.168.0.42"

  def _json(self, code: int, body: dict) -> None:
    data = json.dumps(body).encode()
    self.send_response(code)
    self.send_header("Content-Type", "application/json")
    self.send_header("Access-Control-Allow-Origin", "*")
    self.send_header("Content-Length", str(len(data)))
    self.end_headers()
    self.wfile.write(data)

  def do_OPTIONS(self) -> None:
    self.send_response(204)
    self.send_header("Access-Control-Allow-Origin", "*")
    self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    self.send_header("Access-Control-Allow-Headers", "Content-Type")
    self.end_headers()

  def do_GET(self) -> None:
    if self.path in ("/", "/index.html"):
      body = HTML.read_bytes()
      self.send_response(200)
      self.send_header("Content-Type", "text/html; charset=utf-8")
      self.send_header("Access-Control-Allow-Origin", "*")
      self.send_header("Content-Length", str(len(body)))
      self.end_headers()
      self.wfile.write(body)
      return

    if self.path.startswith("/api/health"):
      from urllib.parse import parse_qs, urlparse
      qs = parse_qs(urlparse(self.path).query)
      ip = (qs.get("ip") or [self.comma_ip])[0]
      try:
        with urllib.request.urlopen(f"http://{ip}:7710/health", timeout=2) as r:
          self._json(200, {"ok": True, "comma": ip, "nav": json.loads(r.read().decode())})
      except Exception as e:
        self._json(502, {"ok": False, "error": str(e)})
      return

    self._json(404, {"error": "not found"})

  def do_POST(self) -> None:
    length = int(self.headers.get("Content-Length", 0))
    raw = self.rfile.read(length) if length else b"{}"
    try:
      payload = json.loads(raw.decode())
    except json.JSONDecodeError:
      self._json(400, {"error": "invalid json"})
      return

    ip = payload.pop("comma_ip", None) or self.comma_ip

    if self.path.startswith("/api/nav"):
      try:
        req = urllib.request.Request(
          f"http://{ip}:7710/nav",
          data=json.dumps(payload).encode(),
          headers={"Content-Type": "application/json"},
          method="POST",
        )
        with urllib.request.urlopen(req, timeout=3) as r:
          self._json(200, {"ok": True, "response": json.loads(r.read().decode())})
      except Exception as e:
        self._json(502, {"ok": False, "error": str(e)})
      return

    if self.path.startswith("/api/v2i"):
      try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(json.dumps(payload).encode(), (ip, V2I_PORT))
        sock.close()
        self._json(200, {"ok": True, "sent_udp": V2I_PORT})
      except Exception as e:
        self._json(502, {"ok": False, "error": str(e)})
      return

    self._json(404, {"error": "not found"})


def main() -> None:
  parser = argparse.ArgumentParser()
  parser.add_argument("--port", type=int, default=8765)
  parser.add_argument("--comma-ip", default="192.168.0.42")
  args = parser.parse_args()

  Handler.comma_ip = args.comma_ip
  server = HTTPServer(("127.0.0.1", args.port), Handler)
  print(f"HUD mockup: http://127.0.0.1:{args.port}/")
  print(f"Proxying to comma @ {args.comma_ip} (nav :7710, v2i UDP :{V2I_PORT})")
  server.serve_forever()


if __name__ == "__main__":
  main()
