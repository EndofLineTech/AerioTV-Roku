"""Full-app pairing artifacts must never alter the normal app or release ZIP."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("pairing_builder", ROOT / "scripts/build-pairing-test.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class PairingTestBuild(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "normal.zip"
        with zipfile.ZipFile(self.source, "w", zipfile.ZIP_DEFLATED) as package:
            package.write(ROOT / "manifest", "manifest")
            for folder in ["source", "components"]:
                for path in (ROOT / folder).rglob("*"):
                    if path.is_file():
                        package.write(path, path.relative_to(ROOT).as_posix())
            for name in ["LICENSE.txt", "NOTICE.txt", "material-icons-LICENSE.txt"]:
                package.write(ROOT / "images" / name, "images/" + name)
        self.original = self.source.read_bytes()

    def build(self, **kwargs):
        return BUILDER.build(self.source, self.directory / "pairing", **kwargs)

    def replace_entry(self, name, content):
        with zipfile.ZipFile(self.source) as package:
            entries = {entry: package.read(entry) for entry in package.namelist()}
        entries[name] = content
        with zipfile.ZipFile(self.source, "w", zipfile.ZIP_DEFLATED) as package:
            for entry, data in entries.items():
                package.writestr(entry, data)

    def test_requires_explicit_opt_in(self):
        with self.assertRaisesRegex(ValueError, "explicit"):
            self.build()
        self.assertFalse((self.directory / "pairing").exists())

    def test_only_entropy_warning_manifest_and_marker_differ(self):
        result = self.build(enable_device_key_test=True)
        output = Path(result["zip"])
        self.assertRegex(output.name, r"^aeriotv-roku-v\d+\.\d+\.\d+-pairing-test\.zip$")
        self.assertEqual(self.source.read_bytes(), self.original)
        with zipfile.ZipFile(self.source) as before, zipfile.ZipFile(output) as after:
            self.assertEqual(set(after.namelist()) - set(before.namelist()), {"pairing-test-build.json"})
            changed = {name for name in before.namelist() if before.read(name) != after.read(name)}
            self.assertEqual(changed, {"manifest", "source/PhoneSetupEntropy.brs", "components/PhoneSetupView.xml"})
            for name in ["source/Main.brs", "components/AerioScene.brs", "components/PhoneSetupTask.brs",
                         "components/PhoneSetupNavigation.brs", "source/PhoneSetupStore.brs",
                         "components/DispatcharrTask.brs", "components/M3uTask.brs", "components/XtreamTask.brs"]:
                self.assertEqual(before.read(name), after.read(name), name)
            self.assertIn(b"aeriotv_pairing_test=1", after.read("manifest"))
            self.assertIn(b"title=AerioTV Pairing Test", after.read("manifest"))
            self.assertIn(b"DEVICE-KEY SOURCE NOT SECURITY-QUALIFIED", after.read("components/PhoneSetupView.xml"))
            self.assertIn(b'CreateObject("roDeviceCrypto")', after.read("source/PhoneSetupEntropy.brs"))
            self.assertNotIn("fixture-materials.json", after.namelist())
            self.assertNotIn(b"pkg:/fixture", after.read("source/PhoneSetupEntropy.brs").lower())
            metadata = json.loads(after.read("pairing-test-build.json"))
            self.assertTrue(metadata["realApplicationRegistry"])
            self.assertFalse(metadata["shippingApproved"])
            self.assertEqual(metadata["baseZipSha256"], hashlib.sha256(self.original).hexdigest())
        self.assertEqual(Path(result["checksums"]).read_text(),
                         hashlib.sha256(output.read_bytes()).hexdigest() + "  " + output.name + "\n")

    def test_rejects_probe_and_already_enabled_input(self):
        with zipfile.ZipFile(self.source, "a") as package:
            package.writestr("fixture-materials.json", "[]")
        with self.assertRaisesRegex(ValueError, "probe|development"):
            self.build(enable_device_key_test=True)

    def test_rejects_building_from_a_pairing_candidate(self):
        candidate = self.build(enable_device_key_test=True)
        with self.assertRaisesRegex(ValueError, "test build|shipping"):
            BUILDER.build(Path(candidate["zip"]), self.directory / "again", enable_device_key_test=True)

    def test_rejects_a_modified_shipping_entropy_provider(self):
        source = (ROOT / "source/PhoneSetupEntropy.brs").read_bytes()
        self.replace_entry("source/PhoneSetupEntropy.brs", source.replace(b"    return invalid\nend function", b"    return 0\nend function", 1))
        with self.assertRaisesRegex(ValueError, "unchanged fail-closed"):
            self.build(enable_device_key_test=True)

    def test_rejects_a_base_missing_the_native_hex_fix(self):
        source = (ROOT / "source/PhoneSetupX25519.brs").read_bytes()
        self.replace_entry("source/PhoneSetupX25519.brs", source.replace(b"value = lcase(value)", b"value = value"))
        with self.assertRaisesRegex(ValueError, "uppercase"):
            self.build(enable_device_key_test=True)

    def test_cannot_write_into_the_release_directory(self):
        with self.assertRaisesRegex(ValueError, "release"):
            BUILDER.build(self.source, ROOT / "out/release", enable_device_key_test=True)


if __name__ == "__main__":
    unittest.main()
