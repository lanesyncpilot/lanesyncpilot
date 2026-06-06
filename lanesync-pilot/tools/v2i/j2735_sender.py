#!/usr/bin/env python3
"""Send J2735-lite binary frames to v2id."""

import argparse
import socket
import time

from cereal import custom
from openpilot.system.v2i.j2735 import encode_hazard, encode_spat, encode_speed


def main() -> None:
  parser = argparse.ArgumentParser(description="J2735-lite binary V2I sender")
  parser.add_argument("--host", default="127.0.0.1")
  parser.add_argument("--port", type=int, default=7701)
  parser.add_argument("--demo", action="store_true")
  args = parser.parse_args()

  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  addr = (args.host, args.port)

  if not args.demo:
    pkt = encode_spat(custom.V2IState.TrafficLight.red, 8.0, 35.0)
    sock.sendto(pkt, addr)
    print(f"sent SPaT ({len(pkt)} bytes)")
    return

  sequence = [
    encode_spat(custom.V2IState.TrafficLight.red, 5.0, 45.0),
    encode_speed(8.0),
    encode_spat(custom.V2IState.TrafficLight.yellow, 3.0, 25.0),
    encode_spat(custom.V2IState.TrafficLight.green, 20.0, 15.0),
    encode_hazard(custom.V2IState.Hazard.workZone, 100.0),
  ]
  for pkt in sequence:
    sock.sendto(pkt, addr)
    print(f"sent {pkt[:4]!r} ({len(pkt)} bytes)")
    time.sleep(2.0)


if __name__ == "__main__":
  main()
