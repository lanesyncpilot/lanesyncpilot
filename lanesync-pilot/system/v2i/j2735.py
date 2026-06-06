"""SAE J2735-inspired binary V2I framing (lite subset for RSU gateways).

Full J2735 uses ASN.1 UPER; this module defines a compact binary envelope RSUs
can emit after decoding J2735, or for lab use without an ASN.1 stack.

Wire format (little-endian):
  magic     3 bytes  b'J35'
  msg_type  1 byte   1=SPaT, 2=speed advisory, 3=hazard
  payload   variable

SPaT (type 1): signal u8, time_to_change f32, distance_m f32
Speed (type 2): speed_mps f32
Hazard (type 3): hazard u8, distance_m f32

Signal / hazard codes match cereal V2IState enums.
"""

from __future__ import annotations

import struct
from typing import Optional

from cereal import custom

MAGIC = b"J35"
MSG_SPAT = 1
MSG_SPEED = 2
MSG_HAZARD = 3

SPAT_FMT = "<Bff"  # signal, time_to_change, distance_m
SPEED_FMT = "<f"
HAZARD_FMT = "<Bf"

SPAT_SIZE = struct.calcsize(SPAT_FMT)
SPEED_SIZE = struct.calcsize(SPEED_FMT)
HAZARD_SIZE = struct.calcsize(HAZARD_FMT)


def encode_spat(signal: int, time_to_change: float, distance_m: float) -> bytes:
  return MAGIC + bytes([MSG_SPAT]) + struct.pack(SPAT_FMT, signal & 0xFF, time_to_change, distance_m)


def encode_speed(speed_mps: float) -> bytes:
  return MAGIC + bytes([MSG_SPEED]) + struct.pack(SPEED_FMT, speed_mps)


def encode_hazard(hazard: int, distance_m: float = -1.0) -> bytes:
  return MAGIC + bytes([MSG_HAZARD]) + struct.pack(HAZARD_FMT, hazard & 0xFF, distance_m)


def decode(payload: bytes) -> Optional[tuple[str, dict]]:
  if len(payload) < 4 or payload[:3] != MAGIC:
    return None

  msg_type = payload[3]
  body = payload[4:]

  if msg_type == MSG_SPAT and len(body) >= SPAT_SIZE:
    signal, ttc, dist = struct.unpack(SPAT_FMT, body[:SPAT_SIZE])
    signal_names = {
      custom.V2IState.TrafficLight.unknown: "unknown",
      custom.V2IState.TrafficLight.red: "red",
      custom.V2IState.TrafficLight.yellow: "yellow",
      custom.V2IState.TrafficLight.green: "green",
      custom.V2IState.TrafficLight.flashingRed: "flashing_red",
      custom.V2IState.TrafficLight.flashingYellow: "flashing_yellow",
    }
    return ("spat", {
      "signal": signal_names.get(signal, "unknown"),
      "time_to_change": ttc,
      "distance_m": dist,
    })

  if msg_type == MSG_SPEED and len(body) >= SPEED_SIZE:
    (speed_mps,) = struct.unpack(SPEED_FMT, body[:SPEED_SIZE])
    return ("speed_advisory", {"speed_mps": speed_mps})

  if msg_type == MSG_HAZARD and len(body) >= HAZARD_SIZE:
    hazard, dist = struct.unpack(HAZARD_FMT, body[:HAZARD_SIZE])
    hazard_names = {
      custom.V2IState.Hazard.none: "none",
      custom.V2IState.Hazard.workZone: "work_zone",
      custom.V2IState.Hazard.congestion: "congestion",
      custom.V2IState.Hazard.weather: "weather",
      custom.V2IState.Hazard.emergencyVehicle: "emergency_vehicle",
    }
    return ("hazard", {"hazard": hazard_names.get(hazard, "none"), "distance_m": dist})

  return None
