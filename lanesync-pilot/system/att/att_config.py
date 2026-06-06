"""Load AT&T dataplan profiles from the repo ``att/`` folder or ``/data/att``."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from openpilot.common.basedir import BASEDIR


def att_config_dirs() -> list[Path]:
  dirs = [
    Path("/data/att"),
    Path(BASEDIR).parent.parent / "att",
    Path(BASEDIR) / "att",
  ]
  out: list[Path] = []
  for d in dirs:
    if d.is_dir() and (d / "dataplan.json").is_file():
      out.append(d)
  return out


def load_dataplan() -> dict[str, Any]:
  env = os.getenv("ATT_CONFIG_DIR")
  if env:
    path = Path(env) / "dataplan.json"
    if path.is_file():
      return json.loads(path.read_text())

  for d in att_config_dirs():
    return json.loads((d / "dataplan.json").read_text())

  return {
    "profiles": {
      "consumer": {"apn": "broadband", "roaming": False, "metered": False},
    },
    "default_profile": "consumer",
    "wifi_hotspot": {"enabled": True},
  }


def get_profile(name: str | None = None) -> dict[str, Any]:
  data = load_dataplan()
  key = name or data.get("default_profile", "consumer")
  profiles = data.get("profiles", {})
  if key not in profiles:
    key = data.get("default_profile", "consumer")
  return profiles.get(key, {"apn": "broadband", "roaming": False, "metered": False})
