#!/usr/bin/env python3
"""Send sample V2I JSON messages to a comma device or local v2id."""

import argparse
import json
import socket
import time


def send(sock: socket.socket, host: str, port: int, payload: dict) -> None:
  data = json.dumps(payload).encode("utf-8")
  sock.sendto(data, (host, port))
  print(f"sent: {payload}")


def main() -> None:
  parser = argparse.ArgumentParser(description="V2I UDP test sender")
  parser.add_argument("--host", default="127.0.0.1", help="comma device IP or localhost")
  parser.add_argument("--port", type=int, default=7701)
  parser.add_argument("--demo", action="store_true", help="cycle SPaT + speed advisory")
  args = parser.parse_args()

  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

  if not args.demo:
    send(sock, args.host, args.port, {
      "type": "spat",
      "intersection_id": "demo-1",
      "signal": "red",
      "time_to_change": 8.0,
      "distance_m": 35.0,
    })
    send(sock, args.host, args.port, {
      "type": "speed_advisory",
      "speed_mps": 11.1,
    })
    return

  sequence = [
    {"type": "spat", "intersection_id": "demo-1", "signal": "red", "time_to_change": 5.0, "distance_m": 40.0},
    {"type": "speed_advisory", "speed_mps": 8.0},
    {"type": "spat", "intersection_id": "demo-1", "signal": "yellow", "time_to_change": 3.0, "distance_m": 25.0},
    {"type": "spat", "intersection_id": "demo-1", "signal": "green", "time_to_change": 20.0, "distance_m": 15.0},
    {"type": "speed_advisory", "speed_mps": 15.0},
    {"type": "hazard", "hazard": "work_zone", "distance_m": 120.0},
  ]
  for payload in sequence:
    send(sock, args.host, args.port, payload)
    time.sleep(2.0)


if __name__ == "__main__":
  main()
