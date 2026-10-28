"""The setup probe must be isolated from production and credential-bearing files."""
import importlib.util
import hashlib
import hmac
from pathlib import Path
import re
import tempfile
import unittest
import zipfile


SPEC = importlib.util.spec_from_file_location(
    "phone_setup_probe", Path(__file__).with_name("build-phone-setup-probe.py")
)
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


class PhoneSetupProbeTest(unittest.TestCase):
    def test_native_hmac_and_hkdf_vectors_against_host_crypto(self):
        source = (PROBE.ROOT / "tests/native/PhoneSetupProbe.brs").read_text()
        mac_key = re.search(r'key = phoneProbeBytes\("([0-9a-f]+)"\)', source)[1]
        ikm = re.search(r'ikm = phoneProbeBytes\("([0-9a-f]+)"\)', source)[1]
        salt = re.search(r'salt = phoneProbeBytes\("([0-9a-f]+)"\)', source)[1]
        self.assertEqual(len(bytes.fromhex(mac_key)), 20)
        self.assertEqual(len(bytes.fromhex(ikm)), 22)
        mac = hmac.new(bytes.fromhex(mac_key), b"Hi There", hashlib.sha256).hexdigest()
        self.assertIn('"' + mac + '"', source)
        prk = hmac.new(bytes.fromhex(salt), bytes.fromhex(ikm), hashlib.sha256).digest()
        self.assertIn('"' + prk.hex() + '"', source)
        info = bytes.fromhex("f0f1f2f3f4f5f6f7f8f9")
        first = hmac.new(prk, info + b"\x01", hashlib.sha256).digest()
        second = hmac.new(prk, first + info + b"\x02", hashlib.sha256).digest()
        self.assertIn('"' + (first + second[:10]).hex() + '"', source)

    def test_package_is_self_contained(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "probe.zip"
            PROBE.build(path)
            with zipfile.ZipFile(path) as package:
                self.assertEqual(set(package.namelist()), {
                    "manifest", "source/Main.brs", "source/PhoneSetupModel.brs",
                    "components/PhoneSetupProbe.xml",
                })
                self.assertIn(b"title=Aerio Setup Compatibility Probe", package.read("manifest"))
                self.assertNotIn(b"AerioScene", package.read("source/Main.brs"))
                self.assertNotIn(b"roRegistry", package.read("source/Main.brs"))
                self.assertIsNone(package.testzip())


if __name__ == "__main__":
    unittest.main()
