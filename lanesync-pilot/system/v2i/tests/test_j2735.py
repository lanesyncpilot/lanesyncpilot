import unittest

from cereal import custom
from openpilot.system.v2i.j2735 import decode, encode_spat, encode_speed, encode_hazard
from openpilot.system.v2i.protocol import V2IBuffer, apply_message


class TestJ2735Lite(unittest.TestCase):
  def test_spat_roundtrip(self):
    pkt = encode_spat(custom.V2IState.TrafficLight.red, 10.0, 30.0)
    decoded = decode(pkt)
    self.assertIsNotNone(decoded)
    assert decoded is not None
    self.assertEqual(decoded[0], "spat")
    self.assertEqual(decoded[1]["signal"], "red")

    buf = V2IBuffer()
    self.assertTrue(apply_message(buf, pkt, 0.0))
    self.assertTrue(buf.traffic_light_valid)
    self.assertEqual(buf.traffic_light, custom.V2IState.TrafficLight.red)

  def test_speed(self):
    pkt = encode_speed(11.1)
    buf = V2IBuffer()
    self.assertTrue(apply_message(buf, pkt, 0.0))
    self.assertAlmostEqual(buf.speed_advisory_mps, 11.1, places=1)

  def test_hazard(self):
    pkt = encode_hazard(custom.V2IState.Hazard.workZone, 50.0)
    buf = V2IBuffer()
    self.assertTrue(apply_message(buf, pkt, 0.0))
    self.assertEqual(buf.hazard, custom.V2IState.Hazard.workZone)


if __name__ == "__main__":
  unittest.main()
