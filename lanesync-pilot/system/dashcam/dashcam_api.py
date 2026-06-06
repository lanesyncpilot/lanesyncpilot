"""List and serve preserved (saved) dashcam segments from the comma device."""

from __future__ import annotations

import os
from dataclasses import dataclass, asdict
from typing import Any

from openpilot.common.params import Params
from openpilot.system.hardware.hw import Paths
from openpilot.system.loggerd.deleter import PRESERVE_ATTR_NAME, PRESERVE_ATTR_VALUE, has_preserve_xattr
from openpilot.system.loggerd.uploader import listdir_by_creation
VIDEO_FILES = ("qcamera.ts", "fcamera.hevc", "dcamera.hevc", "ecamera.hevc")
PREFERRED_PLAYBACK = ("qcamera.ts", "fcamera.hevc", "ecamera.hevc", "dcamera.hevc")


@dataclass
class DashcamClip:
  id: str
  preserved: bool
  files: list[str]
  size_bytes: int
  playback_file: str | None
  dongle_id: str

  def to_dict(self) -> dict[str, Any]:
    return asdict(self)


def _segment_files(segment_dir: str) -> list[str]:
  try:
    return sorted(f for f in os.listdir(segment_dir) if os.path.isfile(os.path.join(segment_dir, f)))
  except OSError:
    return []


def _pick_playback(files: list[str]) -> str | None:
  for name in PREFERRED_PLAYBACK:
    if name in files:
      return name
  return None


def _dir_size(segment_dir: str, files: list[str]) -> int:
  total = 0
  for name in files:
    try:
      total += os.path.getsize(os.path.join(segment_dir, name))
    except OSError:
      pass
  return total


def list_saved_clips(preserved_only: bool = True) -> list[DashcamClip]:
  root = Paths.log_root()
  dongle_id = Params().get("DongleId") or ""
  clips: list[DashcamClip] = []

  for seg_id in reversed(listdir_by_creation(root)):
    seg_path = os.path.join(root, seg_id)
    if not os.path.isdir(seg_path):
      continue

    preserved = has_preserve_xattr(seg_id)
    if preserved_only and not preserved:
      continue

    files = _segment_files(seg_path)
    if not any(f in files for f in VIDEO_FILES):
      continue

    clips.append(DashcamClip(
      id=seg_id,
      preserved=preserved,
      files=files,
      size_bytes=_dir_size(seg_path, files),
      playback_file=_pick_playback(files),
      dongle_id=dongle_id,
    ))

  return clips


def resolve_clip_file(segment_id: str, filename: str) -> str | None:
  if ".." in segment_id or "/" in segment_id or "\\" in segment_id:
    return None
  if ".." in filename or "/" in filename or "\\" in filename:
    return None
  if filename not in VIDEO_FILES and filename not in ("qlog", "qlog.zst", "rlog", "rlog.zst"):
    return None

  path = os.path.join(Paths.log_root(), segment_id, filename)
  if not os.path.isfile(path):
    return None
  return path


def mark_preserved(segment_id: str) -> bool:
  if ".." in segment_id or "/" in segment_id:
    return False
  path = os.path.join(Paths.log_root(), segment_id)
  if not os.path.isdir(path):
    return False
  try:
    os.setxattr(path, PRESERVE_ATTR_NAME, PRESERVE_ATTR_VALUE)
    return True
  except OSError:
    return False
