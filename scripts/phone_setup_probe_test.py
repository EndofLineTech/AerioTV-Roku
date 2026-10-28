"""The setup probe must be isolated from production and credential-bearing files."""
import importlib.util
import hashlib
import hmac
from pathlib import Path
import re
import subprocess
import json
import tempfile
import unittest
import zipfile


SPEC = importlib.util.spec_from_file_location(
    "phone_setup_probe", Path(__file__).with_name("build-phone-setup-probe.py")
)
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


class PhoneSetupProbeTest(unittest.TestCase):
    def test_matrix_covers_valid_and_invalid_contract_cases(self):
        output = subprocess.run(["node", str(PROBE.ROOT / "scripts/phone-setup-vectors.mjs")],
                                check=True, capture_output=True, text=True)
        rows = json.loads(output.stdout)
        self.assertEqual(len(rows), 27)
        self.assertEqual(len({row["id"] for row in rows}), 27)
        self.assertEqual([len(row["plain"]) // 2 for row in rows if row["valid"]], [0, 1, 16, 37])
        for length in [0, 1, 16, 37]:
            for kind in ["changed-key", "changed-nonce", "changed-tag", "missing-tag", "truncated-tag"]:
                row = next(r for r in rows if r["id"] == f"length-{length}-{kind}")
                self.assertFalse(row["valid"])

    def test_native_gcm_fixture_matches_host_aes256gcm(self):
        result = subprocess.run([
            "node", "-e",
            "const c=require('node:crypto').createCipheriv('aes-256-gcm',Buffer.alloc(32),Buffer.alloc(12));"
            "const out=Buffer.concat([c.update(Buffer.alloc(16)),c.final(),c.getAuthTag()]);"
            "process.stdout.write(out.toString('hex'));",
        ], check=True, capture_output=True, text=True)
        source = (PROBE.ROOT / "tests/native/PhoneSetupProbe.brs").read_text()
        self.assertIn('"' + result.stdout + '"', source)

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
                    "source/PhoneSetupMatrix.brs", "fixtures.json",
                })
                self.assertIn(b"title=Aerio Setup Compatibility Probe", package.read("manifest"))
                self.assertNotIn(b"AerioScene", package.read("source/Main.brs"))
                self.assertNotIn(b"roRegistry", package.read("source/Main.brs"))
                self.assertIsNone(package.testzip())


if __name__ == "__main__":
    unittest.main()
