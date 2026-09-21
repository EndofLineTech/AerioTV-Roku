import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "roku_device_info", Path(__file__).with_name("roku_device_info.py")
)
roku_device_info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(roku_device_info)


class RokuDeviceInfoTests(unittest.TestCase):
    def test_whitelists_safe_device_fields(self):
        info = roku_device_info.parse_device_info("""
            <device-info>
              <model-name>Streaming Stick 4K</model-name>
              <model-number>3820RW2</model-number>
              <software-version>15.3.4</software-version>
              <software-build>2402</software-build>
              <uptime>12345</uptime>
              <serial-number>do-not-print</serial-number>
              <device-id>do-not-print</device-id>
            </device-info>
        """)
        self.assertEqual(info["model-name"], "Streaming Stick 4K")
        self.assertEqual(info["uptime"], "12345")
        self.assertNotIn("serial-number", info)
        self.assertNotIn("device-id", info)


if __name__ == "__main__":
    unittest.main()
