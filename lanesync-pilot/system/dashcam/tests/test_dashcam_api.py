import unittest

from openpilot.system.dashcam.dashcam_api import list_saved_clips, resolve_clip_file


class TestDashcamApi(unittest.TestCase):
  def test_resolve_rejects_traversal(self):
    self.assertIsNone(resolve_clip_file("../evil", "qcamera.ts"))
    self.assertIsNone(resolve_clip_file("ok", "../qcamera.ts"))

  def test_list_empty_when_no_root(self):
    # list_saved_clips should not crash on empty/missing dirs in test env
    clips = list_saved_clips(preserved_only=True)
    self.assertIsInstance(clips, list)


if __name__ == "__main__":
  unittest.main()
