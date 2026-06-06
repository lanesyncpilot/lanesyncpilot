#!/usr/bin/env python3
"""HTTP API for saved dashcam clips (Android / iOS companion apps)."""

import json
import mimetypes
import os
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import unquote, urlparse

from openpilot.common.params import Params
from openpilot.common.realtime import Ratekeeper
from openpilot.common.swaglog import cloudlog
from openpilot.system.dashcam.dashcam_api import list_saved_clips, resolve_clip_file

DASHCAM_PORT = int(os.getenv("DASHCAM_PORT", "7720"))
CHUNK_SIZE = 1024 * 256


class DashcamHandler(BaseHTTPRequestHandler):
  auth_token: str | None = None

  def log_message(self, fmt: str, *args) -> None:
    cloudlog.debug("dashcamd " + (fmt % args))

  def _check_auth(self) -> bool:
    token = DashcamHandler.auth_token
    if not token:
      return True
    auth = self.headers.get("Authorization", "")
    if auth == f"Bearer {token}":
      return True
    qs = urlparse(self.path).query
    return f"token={token}" in qs

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
    self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
    self.send_header("Access-Control-Allow-Headers", "Authorization, Range")
    self.end_headers()

  def do_GET(self) -> None:
    if not self._check_auth():
      self._json(401, {"error": "unauthorized"})
      return

    path = urlparse(self.path).path

    if path == "/health":
      clips = list_saved_clips()
      self._json(200, {
        "ok": True,
        "service": "lanesync-dashcam",
        "saved_count": len(clips),
        "port": DASHCAM_PORT,
      })
      return

    if path == "/routes" or path == "/clips":
      preserved_only = urlparse(self.path).query != "all=1"
      clips = [c.to_dict() for c in list_saved_clips(preserved_only=preserved_only)]
      self._json(200, {"clips": clips, "count": len(clips)})
      return

    if path.startswith("/video/"):
      parts = [unquote(p) for p in path.split("/")[2:] if p]
      if len(parts) != 2:
        self._json(400, {"error": "use /video/{segment_id}/{filename}"})
        return
      segment_id, filename = parts
      file_path = resolve_clip_file(segment_id, filename)
      if not file_path:
        self._json(404, {"error": "not found"})
        return
      self._stream_file(file_path)
      return

    self._json(404, {"error": "not found"})

  def _stream_file(self, file_path: str) -> None:
    size = os.path.getsize(file_path)
    mime, _ = mimetypes.guess_type(file_path)
    if file_path.endswith(".hevc"):
      mime = "video/hevc"
    elif file_path.endswith(".ts"):
      mime = "video/mp2t"
    mime = mime or "application/octet-stream"

    range_header = self.headers.get("Range")
    start = 0
    end = size - 1
    if range_header and range_header.startswith("bytes="):
      try:
        spec = range_header.split("=", 1)[1]
        if "-" in spec:
          s, e = spec.split("-", 1)
          if s:
            start = int(s)
          if e:
            end = int(e)
      except ValueError:
        start = 0
        end = size - 1

    start = max(0, min(start, size - 1))
    end = max(start, min(end, size - 1))
    length = end - start + 1

    if range_header:
      self.send_response(206)
      self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
    else:
      self.send_response(200)

    self.send_header("Content-Type", mime)
    self.send_header("Accept-Ranges", "bytes")
    self.send_header("Content-Length", str(length))
    self.send_header("Access-Control-Allow-Origin", "*")
    self.end_headers()

    with open(file_path, "rb") as f:
      f.seek(start)
      remaining = length
      while remaining > 0:
        chunk = f.read(min(CHUNK_SIZE, remaining))
        if not chunk:
          break
        self.wfile.write(chunk)
        remaining -= len(chunk)


def _run_http() -> None:
  params = Params()
  DashcamHandler.auth_token = params.get("DashcamApiToken") or None
  server = HTTPServer(("0.0.0.0", DASHCAM_PORT), DashcamHandler)
  cloudlog.info(f"dashcamd listening on :{DASHCAM_PORT}")
  server.serve_forever()


def main() -> None:
  thread = threading.Thread(target=_run_http, daemon=True)
  thread.start()
  rk = Ratekeeper(1.0, print_delay_threshold=None)
  while True:
    rk.keep_time()


if __name__ == "__main__":
  main()
