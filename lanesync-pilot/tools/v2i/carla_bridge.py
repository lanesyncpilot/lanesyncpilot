#!/usr/bin/env python3
"""Bridge CARLA traffic lights to openpilot v2id (JSON over UDP).

Requires: pip install carla  (match your CARLA server version)

Example:
  # Terminal 1: CARLA server
  ./CarlaUE4.sh

  # Terminal 2: bridge -> comma device or localhost
  python tools/v2i/carla_bridge.py --host 192.168.1.100 --carla-host localhost

When the ego vehicle approaches a traffic light, the bridge publishes SPaT-like
updates to v2id on UDP port 7701 (or V2IPort param).
"""

from __future__ import annotations

import argparse
import json
import math
import socket
import sys
import time

try:
  import carla
except ImportError:
  print("Install the CARLA Python API: pip install carla", file=sys.stderr)
  sys.exit(1)

def light_state_to_signal(state: carla.TrafficLightState) -> str:
  if state == carla.TrafficLightState.Red:
    return "red"
  if state == carla.TrafficLightState.Yellow:
    return "yellow"
  if state == carla.TrafficLightState.Green:
    return "green"
  return "unknown"


def nearest_traffic_light(world: carla.World, vehicle: carla.Vehicle) -> tuple[carla.TrafficLight | None, float]:
  loc = vehicle.get_location()
  best_tl = None
  best_dist = 1e9
  for tl in world.get_actors().filter("traffic.traffic_light*"):
    d = loc.distance(tl.get_location())
    if d < best_dist:
      best_dist = d
      best_tl = tl
  return best_tl, best_dist


def main() -> None:
  parser = argparse.ArgumentParser(description="CARLA -> openpilot V2I bridge")
  parser.add_argument("--host", default="127.0.0.1", help="openpilot device IP running v2id")
  parser.add_argument("--port", type=int, default=7701)
  parser.add_argument("--carla-host", default="127.0.0.1")
  parser.add_argument("--carla-port", type=int, default=2000)
  parser.add_argument("--hz", type=float, default=10.0)
  parser.add_argument("--max-range", type=float, default=80.0, help="max distance to report TL (m)")
  args = parser.parse_args()

  client = carla.Client(args.carla_host, args.carla_port)
  client.set_timeout(5.0)
  world = client.get_world()

  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  dt = 1.0 / args.hz
  last_signal = None

  print(f"CARLA bridge -> {args.host}:{args.port}  (Ctrl+C to stop)")

  while True:
    try:
      vehicle = world.get_actors().filter("vehicle.*")[0]
    except IndexError:
      time.sleep(dt)
      continue

    tl, dist = nearest_traffic_light(world, vehicle)
    if tl is None or dist > args.max_range:
      time.sleep(dt)
      continue

    state = tl.get_state()
    signal = light_state_to_signal(state)
    ttc = max(0.0, tl.get_yellow_time() if state == carla.TrafficLightState.Yellow else tl.get_red_time())

    payload = {
      "type": "spat",
      "intersection_id": f"carla-{tl.id}",
      "signal": signal,
      "time_to_change": ttc,
      "distance_m": dist,
    }

    if signal != last_signal or int(time.time()) % 2 == 0:
      sock.sendto(json.dumps(payload).encode(), (args.host, args.port))
      print(f"  {signal} @ {dist:.0f}m  ttc={ttc:.1f}s")
      last_signal = signal

    # Optional speed advisory from vehicle limit in CARLA
    vel = vehicle.get_velocity()
    speed_mps = math.sqrt(vel.x ** 2 + vel.y ** 2 + vel.z ** 2)
    if signal == "red" and dist < 40:
      advisory = {"type": "speed_advisory", "speed_mps": 0.0}
      sock.sendto(json.dumps(advisory).encode(), (args.host, args.port))

    time.sleep(dt)


if __name__ == "__main__":
  main()
