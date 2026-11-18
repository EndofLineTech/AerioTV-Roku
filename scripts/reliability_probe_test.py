"""Causal reliability diagnostics must not alter application behavior."""
import importlib.util
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class ReliabilityProbeTest(unittest.TestCase):
    def test_guide_sweep_distinguishes_cleared_suppression_from_recovery(self):
        runner = load("guide", "test-live-guide-scroll-native.py")
        sample = {"kind": "live-guide-sweep", "lineup": 36, "covered_rows": 36,
                  "mapping_ready": True, "mapping_warning": False, "visible": 6}
        seeded = {"kind": "live-guide-seeded-failure", "suppressed": True}
        retry = {"kind": "live-guide-refresh-retry", "downloaded": True, "still_suppressed": False}
        runner.assert_guide_sweep([sample, seeded, retry], expect_retry=True)
        with self.assertRaises(SystemExit):
            runner.assert_guide_sweep([sample, seeded, dict(retry, downloaded=False)], expect_retry=True)
        with self.assertRaises(SystemExit):
            runner.assert_guide_sweep([dict(sample, covered_rows=35)])
        first_page = dict(sample, row_start=0)
        with self.assertRaises(SystemExit):
            runner.assert_guide_sweep([first_page], expect_revisit=True)
        warm_page = {"kind": "live-guide-poster-timing", "revisiting": True}
        with self.assertRaises(SystemExit):
            runner.assert_guide_sweep([dict(sample, row_start=1), warm_page], expect_revisit=True)
        runner.assert_guide_sweep([first_page, warm_page], expect_revisit=True)

    def test_guide_probe_keeps_download_code_unchanged(self):
        guide = load("guide", "test-live-guide-scroll-native.py")
        with tempfile.TemporaryDirectory() as directory:
            source, output = (Path(directory) / name for name in ("base.zip", "probe.zip"))
            logo_task = (ROOT / "components/LogoCacheTask.brs").read_bytes()
            with zipfile.ZipFile(source, "w") as package:
                package.writestr("components/GuideView.brs", "' Original guide code\n")
                package.writestr("components/LogoCacheTask.brs", logo_task)
            guide.build(output, source, "test-reliability")
            with zipfile.ZipFile(output) as package:
                self.assertEqual(package.read("components/LogoCacheTask.brs"), logo_task)
                view = package.read("components/GuideView.brs")
                self.assertTrue(view.startswith(b"' Original guide code\n"))
                self.assertIn(b"live-guide-poster-timing", view)
                self.assertIn(b"all_cached_ms", view)

    def test_guide_probe_poster_size_experiment_changes_only_guide_view(self):
        guide = load("guide", "test-live-guide-scroll-native.py")
        with tempfile.TemporaryDirectory() as directory:
            source, baseline, limited = (Path(directory) / name for name in ("source.zip", "baseline.zip", "limited.zip"))
            view_path = "components/GuideView.brs"
            with zipfile.ZipFile(source, "w") as package:
                package.write(ROOT / view_path, view_path)
                package.write(ROOT / "components/LogoCacheTask.brs", "components/LogoCacheTask.brs")
            guide.build(baseline, source, "test-reliability")
            with patch.object(guide, "limit_poster_size", True):
                guide.build(limited, source, "test-reliability")
            with zipfile.ZipFile(baseline) as a, zipfile.ZipFile(limited) as b:
                self.assertEqual(set(a.namelist()), set(b.namelist()))
                self.assertEqual([name for name in a.namelist() if a.read(name) != b.read(name)], [view_path])
                self.assertEqual(b.read(view_path), a.read(view_path).replace(
                    b'        logo.loadDisplayMode = "scaleToFit"\n',
                    b'        logo.loadDisplayMode = "limitSize"\n', 1))

    def test_guide_page_scroll_experiment_changes_only_the_private_driver(self):
        guide = load("guide", "test-live-guide-scroll-native.py")
        with tempfile.TemporaryDirectory() as directory:
            source, baseline, paged = (Path(directory) / name for name in ("source.zip", "baseline.zip", "paged.zip"))
            view_path = "components/GuideView.brs"
            original_view = (ROOT / view_path).read_bytes()
            with zipfile.ZipFile(source, "w") as package:
                package.writestr(view_path, original_view)
                package.write(ROOT / "components/LogoCacheTask.brs", "components/LogoCacheTask.brs")
            guide.build(baseline, source, "test-reliability")
            with patch.object(guide, "page_scroll", True):
                guide.build(paged, source, "test-reliability")
            with zipfile.ZipFile(baseline) as a, zipfile.ZipFile(paged) as b:
                self.assertEqual(set(a.namelist()), set(b.namelist()))
                self.assertEqual([name for name in a.namelist() if a.read(name) != b.read(name)], [view_path])
                self.assertTrue(b.read(view_path).startswith(original_view))
                branch = b'        executeGuideRemoteAction("pageDown")'
                self.assertIn(b"    else if false\n" + branch, a.read(view_path)[len(original_view):])
                self.assertIn(b"    else if true\n" + branch, b.read(view_path)[len(original_view):])

    def test_saved_picker_probe_requires_exact_hash_and_private_main(self):
        runner = load("picker", "test-profile-picker-native.py")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "saved.zip"
            with zipfile.ZipFile(path, "w") as package:
                package.writestr("manifest", "title=Aerio Profile Picker Probe\n")
                package.write(ROOT / "tests/native/ProfilePickerProbe.brs", "source/Main.brs")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(runner.verify_saved_picker_probe(path, digest), digest)
            with self.assertRaises(ValueError):
                runner.verify_saved_picker_probe(path, "0" * 64)
            with zipfile.ZipFile(path, "w") as package:
                package.writestr("manifest", "title=AerioTV\n")
                package.writestr("source/Main.brs", "sub Main()\nend sub\n")
            with self.assertRaises(ValueError):
                runner.verify_saved_picker_probe(path, hashlib.sha256(path.read_bytes()).hexdigest())

    def test_native_logo_checks_use_current_callback_without_a_provider(self):
        runner = load("policy", "test-profiles-baseline-policy-native.py")
        with tempfile.TemporaryDirectory() as directory:
            original, probe = Path(directory) / "original.zip", Path(directory) / "probe.zip"
            with zipfile.ZipFile(original, "w") as package:
                package.writestr("source/Main.brs", "sub Main()\nend sub\n")
            runner.build_policy_probe(original, probe, logo_checks=True)
            with zipfile.ZipFile(probe) as package:
                self.assertEqual(package.read("source/GuideLogosProbe.brs"), (ROOT / "components/GuideLogos.brs").read_bytes())
                self.assertIn(b"runLogoCacheChecks()", package.read("source/Main.brs"))
                self.assertIn(b"downloaded-image decoder failures", package.read("source/LogoCacheProbeChecks.brs"))

    def test_curl_key_transport_sends_once_and_does_not_retry_timeouts(self):
        runner = load("picker", "test-profile-picker-native.py")
        with patch.object(runner.subprocess, "run") as call:
            call.return_value.returncode = 28
            call.return_value.stdout = "000"
            result = runner.send_picker_key("192.0.2.1", "Select", "keypress", "curl")
            self.assertEqual(call.call_count, 1)
            command = call.call_args.args[0]
            self.assertNotIn("--retry", command)
            self.assertIn("http://192.0.2.1:8060/keypress/Select", command)
            self.assertNotIn("status", result)
            self.assertEqual(result["curl_exit"], 28)

    def test_symbol_diagnostic_preserves_unrelated_bytes_and_original(self):
        runner = load("policy", "test-profiles-baseline-policy-native.py")
        with tempfile.TemporaryDirectory() as directory:
            original, probe = Path(directory) / "original.zip", Path(directory) / "probe.zip"
            main = (ROOT / "tests/native/UserProfileProbe.brs").read_bytes()
            with zipfile.ZipFile(original, "w") as package:
                package.writestr("source/Main.brs", main)
                package.writestr("source/StrictJson.brs", b"unchanged")
                package.write(ROOT / "source/PhoneSetupProfileImport.brs", "source/PhoneSetupProfileImport.brs")
                package.writestr("manifest", b"title=Private")
            before = original.read_bytes()
            runner.build_policy_probe(original, probe, diagnostic=True)
            self.assertEqual(original.read_bytes(), before)
            with zipfile.ZipFile(probe) as package:
                self.assertEqual(package.read("source/StrictJson.brs"), b"unchanged")
                policy = package.read("source/PhoneSetupProfileImport.brs").decode()
                self.assertIn("phoneSetupProbeBatchRefusal", policy)
                self.assertIn('kind: "batch-refusal"', policy)
                text = package.read("source/Main.brs").decode()
                self.assertIn('kind: "symbol-bindings"', text)
                self.assertIn("type(strictJsonEncode)", text)
                self.assertIn("type(runUserProfileOwnSignInChecks)", text)
                self.assertLess(text.index("type(strictJsonEncode)"), text.index("    runUserProfileOwnSignInChecks()"))
                self.assertIn("if not bindingsOk", text)
                self.assertNotIn("httpTransferOnce(", text[:text.lower().index("end sub")])
                self.assertIn("runPhoneSetupProfilesChecks()", text)

    def test_picker_capture_policy_does_not_weaken_event_acceptance(self):
        runner = load("picker", "test-profile-picker-native.py")
        keys = [{"status": 200, "kind": kind, "key": key} for kind, key in [
            ("keypress", "Select"), ("keypress", "Select"), ("keypress", "Left"),
            ("keydown", "Select"), ("keyup", "Select"), ("keypress", "Right"),
            ("keypress", "Select"), ("keypress", "Back"),
        ]]
        self.assertTrue(runner.picker_passed(0, [{"kind": "intent"}] * 6 + [{"kind": "complete", "passed": True}],
                                             keys, capture=False, screenshot=False))
        self.assertFalse(runner.picker_passed(0, [{"kind": "intent"}] * 6 + [{"kind": "complete", "passed": True}],
                                              keys[:-1], capture=False, screenshot=False))
        self.assertFalse(runner.picker_passed(0, [{"kind": "complete", "passed": True}],
                                              keys, capture=False, screenshot=False))
        self.assertFalse(runner.picker_passed(0, [{"kind": "intent"}] * 6 + [{"kind": "complete", "passed": True}],
                                              [{"error": "TimeoutError"}], capture=False, screenshot=False))
        self.assertFalse(runner.picker_passed(0, [{"kind": "intent"}] * 6 + [{"kind": "complete", "passed": True}],
                                              keys, capture=True, screenshot=False))


if __name__ == "__main__":
    unittest.main()
