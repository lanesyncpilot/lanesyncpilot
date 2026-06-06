import unittest

from openpilot.system.v2i.phone_nav_protocol import PhoneNavBuffer, apply_nav_json, fill_phone_nav_capnp


class TestPhoneNavProtocol(unittest.TestCase):
  def test_nav_update(self):
    buf = PhoneNavBuffer()
    payload = b'''{
      "source": "carplay",
      "carplay_connected": true,
      "active": true,
      "destination": "Home",
      "dest_lat": 37.4,
      "dest_lon": -122.1,
      "distance_remaining_m": 1000,
      "time_remaining_s": 120,
      "maneuver": "Turn left"
    }'''
    self.assertTrue(apply_nav_json(buf, payload, 0.0))
    self.assertTrue(buf.active)
    self.assertEqual(buf.destination_name, "Home")
    self.assertTrue(buf.carplay_connected)

  def test_clear(self):
    buf = PhoneNavBuffer()
    apply_nav_json(buf, b'{"active": true, "destination": "X"}', 0.0)
    apply_nav_json(buf, b'{"active": false}', 1.0)
    self.assertFalse(buf.valid)


if __name__ == "__main__":
  unittest.main()
