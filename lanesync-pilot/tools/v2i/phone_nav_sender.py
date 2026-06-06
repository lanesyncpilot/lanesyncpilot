#!/usr/bin/env python3
"""Simulate iPhone CarPlay navigation POST to phonenavd."""

import argparse
import json
import urllib.request


def main() -> None:
  parser = argparse.ArgumentParser()
  parser.add_argument("--host", default="127.0.0.1")
  parser.add_argument("--port", type=int, default=7710)
  parser.add_argument("--destination", default="Stanford University")
  parser.add_argument("--maneuver", default="Continue on US-101 South")
  args = parser.parse_args()

  payload = {
    "source": "carplay",
    "carplay_connected": True,
    "active": True,
    "destination": args.destination,
    "dest_lat": 37.4275,
    "dest_lon": -122.1697,
    "distance_remaining_m": 8500,
    "time_remaining_s": 720,
    "maneuver": args.maneuver,
  }
  url = f"http://{args.host}:{args.port}/nav"
  req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
                               headers={"Content-Type": "application/json"})
  with urllib.request.urlopen(req, timeout=5) as resp:
    print(resp.read().decode())


if __name__ == "__main__":
  main()
