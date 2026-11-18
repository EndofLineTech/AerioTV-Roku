import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parent.parent


class PhoneNormalProbeTest(unittest.TestCase):
    def test_overlay_probe_uses_the_rendered_poster_without_a_development_only_helper(self):
        spec = importlib.util.spec_from_file_location("guide_overlays", ROOT / "scripts/test-guide-overlays-live-native.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            normal, probe = Path(directory) / "normal.zip", Path(directory) / "probe.zip"
            guide = "components/GuideView.brs"
            details = "components/ProgramDetails.brs"
            with zipfile.ZipFile(normal, "w") as package:
                package.writestr(guide, "")
                package.writestr(details, "")
            module.build(probe, normal, "PrivateOverlay")
            with zipfile.ZipFile(probe) as package:
                guide_probe = package.read(guide).decode()
                details_probe = package.read(details).decode()
                self.assertNotIn("programArtworkUri(", guide_probe)
                self.assertIn('m.details.callFunc("probePosterState")', guide_probe)
                self.assertIn('hasArt: m.poster.uri <> ""', details_probe)
                self.assertIn("status: m.poster.loadStatus", details_probe)

    def test_package_fingerprints_ignore_zip_metadata_but_detect_changed_bytes(self):
        spec = importlib.util.spec_from_file_location("phone_normal", ROOT / "scripts/test-phone-setup-normal-native.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / f"{index}.zip" for index in range(3)]
            for index, path in enumerate(paths):
                with zipfile.ZipFile(path, "w") as package:
                    info = zipfile.ZipInfo("manifest", (2026, 11, 18, index, 0, 0))
                    package.writestr(info, "build_version=102" if index != 2 else "build_version=103")
            self.assertEqual(module.package_fingerprints(paths[0]), module.package_fingerprints(paths[1]))
            self.assertNotEqual(module.package_fingerprints(paths[0]), module.package_fingerprints(paths[2]))

    def test_native_acceptance_requires_live_dispatcharr_and_never_hosts_a_provider(self):
        runner = (ROOT / "scripts/test-phone-setup-normal-native.py").read_text()
        self.assertIn('parser.add_argument("--dispatcharr-credentials", type=Path, required=True', runner)
        self.assertNotIn("ThreadingHTTPServer", runner)
        self.assertIn('real_baseline_accounts', runner)

    def test_live_driver_contains_only_key_hashes_not_credentials(self):
        spec = importlib.util.spec_from_file_location("phone_normal", ROOT / "scripts/test-phone-setup-normal-native.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        live = {"role": "child", "accounts": [
            {"user": {"id": 41, "api_key": "private-default-key"}},
            {"user": {"id": 42, "api_key": "private-secondary-key"}},
        ]}
        with tempfile.TemporaryDirectory() as directory:
            normal, probe = Path(directory) / "normal.zip", Path(directory) / "probe.zip"
            with zipfile.ZipFile(normal, "w") as package:
                package.writestr("components/AerioScene.brs", (ROOT / "components/AerioScene.brs").read_bytes())
            module.build(probe, normal, "PrivateLiveDriver", live=live)
            with zipfile.ZipFile(probe) as package:
                body = package.read("components/AerioScene.brs").decode()
                self.assertIn("m.phoneNormalDefaultUser = 41", body)
                self.assertIn('m.phoneNormalExpectedRole = "child"', body)
                self.assertNotIn("private-default-key", body)
                self.assertNotIn("private-secondary-key", body)

    def test_diagnostic_changes_only_the_verifier_and_never_claims_production_bytes(self):
        spec = importlib.util.spec_from_file_location("phone_normal", ROOT / "scripts/test-phone-setup-normal-native.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            normal, probe = Path(directory) / "normal.zip", Path(directory) / "diagnostic.zip"
            with zipfile.ZipFile(normal, "w") as package:
                for name in module.PRODUCTION_FILES:
                    package.writestr(name, (ROOT / name).read_bytes())
            module.build(probe, normal, "PrivateDiagnostic", diagnostic=True)
            with zipfile.ZipFile(probe) as package:
                for name in module.PRODUCTION_FILES:
                    if name == "components/PhoneSetupProfileVerifyTask.brs":
                        text = package.read(name).decode()
                        self.assertIn("candidateCategory", text)
                        self.assertNotIn("FormatJson(m.httpFailure)", text)
                    else:
                        self.assertEqual(package.read(name), (ROOT / name).read_bytes())
        runner = (ROOT / "scripts/test-phone-setup-normal-native.py").read_text()
        self.assertIn('"production_bytes_preserved": not args.diagnostic', runner)
        self.assertIn('report["passed"] = not args.diagnostic', runner)

    def test_sync_offer_measures_master_opt_in_not_the_default_category_checkbox(self):
        fixture = (ROOT / "tests/native/PhoneSetupNormalFixture.brs").read_text()
        self.assertIn("not settings.enabled", fixture)
        self.assertNotIn("not settings.profiles", fixture)

    def test_normal_flow_keeps_production_receiver_crypto_and_profile_controllers(self):
        spec = importlib.util.spec_from_file_location("phone_normal", ROOT / "scripts/test-phone-setup-normal-native.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            normal, probe = Path(directory) / "normal.zip", Path(directory) / "probe.zip"
            critical = module.PRODUCTION_FILES
            with zipfile.ZipFile(normal, "w") as package:
                package.writestr("manifest", "title=AerioTV\n")
                for name in critical + ["components/AerioScene.brs", "source/MetadataCacheStore.brs"]:
                    package.writestr(name, (ROOT / name).read_bytes())
            module.build(probe, normal, "PhoneNormalPrivateSection")
            with zipfile.ZipFile(probe) as package:
                for name in critical:
                    self.assertEqual(package.read(name), (ROOT / name).read_bytes(), name)
                scene = package.read("components/AerioScene.brs").decode()
                self.assertIn("PhoneNormalPrivateSection", scene)
                self.assertNotIn('CreateObject("roRegistrySection", "AerioTV")', scene)
                self.assertNotIn("acceptPhoneSetupPayload(", scene[scene.index("sub startPhoneNormalProbe()"):])
                self.assertNotIn("m.profilePhoneImportReady = true", scene[scene.index("sub startPhoneNormalProbe()"):])
                self.assertNotIn("aeriotv_pairing_test", package.read("manifest").decode())
                self.assertIn("phone-setup-normal-probe.json", package.namelist())

    def test_normal_probe_artifacts_cannot_ship(self):
        script = """import {assertPackageEntries} from './scripts/verify-package.mjs';
import assert from 'node:assert/strict';
for (const name of ['phone-setup-normal-probe.json','source/PhoneSetupNormalFixture.brs','components/PhoneEntropyFaultProbe.xml']) {
assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml',
'images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt',name]), /phone|entropy/i);
}"""
        subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True)


if __name__ == "__main__":
    unittest.main()
