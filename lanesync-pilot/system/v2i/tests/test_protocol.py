import time
import unittest

from cereal import custom
from openpilot.system.v2i.protocol import V2IBuffer, apply_message


class TestV2IProtocol(unittest.TestCase):
  def test_spat(self):
    buf = V2IBuffer()
    mono = time.monotonic()
    ok = apply_message(buf, b'{"type":"spat","signal":"red","distance_m":30}', mono)
    self.assertTrue(ok)
    self.assertTrue(buf.traffic_light_valid)
    self.assertEqual(buf.traffic_light, custom.V2IState.TrafficLight.red)
    self.assertEqual(buf.distance_m, 30.0)

  def test_speed_mph(self):
    buf = V2IBuffer()
    ok = apply_message(buf, b'{"type":"speed_advisory","speed_mph":25}', time.monotonic())
    self.assertTrue(ok)
    self.assertTrue(buf.speed_advisory_valid)
    self.assertAlmostEqual(buf.speed_advisory_mps, 25 * 0.44704, places=2)

  def test_invalid_json(self):
    buf = V2IBuffer()
    ok = apply_message(buf, b"not json", time.monotonic())
    self.assertFalse(ok)


if __name__ == "__main__":
  unittest.main()
