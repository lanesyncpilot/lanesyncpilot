#!/usr/bin/env python3
import os
import socket
import time

import cereal.messaging as messaging
from openpilot.common.params import Params
from openpilot.common.realtime import Ratekeeper
from openpilot.common.swaglog import cloudlog
from openpilot.system.v2i.protocol import V2IBuffer, apply_message, fill_capnp

V2I_PORT = int(os.getenv("V2I_PORT", "7701"))
STALE_TIMEOUT = float(os.getenv("V2I_STALE_TIMEOUT", "3.0"))
PUBLISH_HZ = 10.0


def main() -> None:
  params = Params()
  port = int(params.get("V2IPort") or V2I_PORT)

  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
  sock.bind(("0.0.0.0", port))
  sock.setblocking(False)

  cloudlog.info(f"v2id listening on UDP port {port}")

  pm = messaging.PubMaster(["v2iState"])
  rk = Ratekeeper(PUBLISH_HZ, print_delay_threshold=None)
  buf = V2IBuffer()

  while True:
    while True:
      try:
        data, addr = sock.recvfrom(4096)
      except BlockingIOError:
        break
      except OSError as e:
        cloudlog.warning(f"v2id recv error: {e}")
        break

      if apply_message(buf, data, time.monotonic()):
        fmt = "J2735" if data[:3] == b"J35" else "JSON"
        cloudlog.debug(f"v2id rx {fmt} from {addr[0]}:{addr[1]}")

    now = time.monotonic()
    if buf.valid and buf.last_mono > 0 and (now - buf.last_mono) > STALE_TIMEOUT:
      buf.valid = False
      buf.traffic_light_valid = False
      buf.speed_advisory_valid = False
      buf.hazard_valid = False

    msg = messaging.new_message("v2iState")
    fill_capnp(msg.v2iState, buf, now)
    msg.valid = buf.valid
    pm.send("v2iState", msg)

    rk.keep_time()


if __name__ == "__main__":
  main()
