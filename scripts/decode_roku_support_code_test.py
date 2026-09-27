"""Fixed-vector parity and corruption checks for the BrightScript support code."""

import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "support_code", Path(__file__).with_name("decode-roku-support-code.py")
)
CODEC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CODEC)


class SupportCodeTest(unittest.TestCase):
    def test_known_approved_fields_only(self):
        # D11 + playback(3), -3 offset, 500-749ms bucket, <1min age + CRC.
        payload = "D113" + CODEC.encode36(4092, 3) + "200"
        checksum = 0
        for char in payload:
            checksum = (checksum * 31 + CODEC.ALPHABET.index(char)) % 46656
        compact = payload + CODEC.encode36(checksum, 3)
        code = "-".join(compact[i:i + 4] for i in range(0, len(compact), 4))
        self.assertEqual(code, "D113-35O2-00AW-Y")
        decoded = CODEC.decode(code)
        self.assertEqual(decoded["events"], [{"stage": "playback", "code": -3,
                                               "age_minutes": 0, "elapsed_ms_bucket": "500-749"}])

    def test_corrupt_and_malformed_codes_fail_closed(self):
        payload = "D113" + CODEC.encode36(4092, 3) + "200"
        checksum = 0
        for char in payload:
            checksum = (checksum * 31 + CODEC.ALPHABET.index(char)) % 46656
        valid = payload + CODEC.encode36(checksum, 3)
        for bad in ("", "D10", valid[:-1] + "Z", valid + "A", valid.lower(), valid + "?", "D19" + valid[3:]):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                CODEC.decode(bad)


if __name__ == "__main__":
    unittest.main()
