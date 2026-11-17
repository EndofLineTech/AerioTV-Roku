"""Production native-keyboard Directions integration; not spoken-entry acceptance."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def build(normal, output, section, base):
    pin = module("directions_voice_pin", "test-profile-pin-native.py")
    with tempfile.TemporaryDirectory(prefix="directions-voice-build-", dir=output.parent) as folder:
        intermediate = Path(folder) / "private-pin.zip"
        pin.build(intermediate, normal, section, base, directions=True)
        with zipfile.ZipFile(intermediate) as original, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
            for name in original.namelist():
                body = original.read(name)
                if name == "manifest":
                    body = body.replace(b"aeriotv_profile_directions_test=1\n", b"")
                    body += b"\naeriotv_profiles_baseline=1\naeriotv_profile_voice_pin_test=1\n"
                elif name == "components/ProfilePinNavigation.brs":
                    text = body.decode()
                    # Replace only the old input driver, not production PIN UI,
                    # parsing, verification, persistence or continuation logic.
                    start = text.index("\nsub onPinFixtureTick()")
                    text = text[:start] + "\n" + (ROOT / "tests/native/DirectionsVoiceEntryFixture.brs").read_text()
                    body = text.encode()
                elif name == "components/AerioScene.brs":
                    seed = f'm.registry = CreateObject("roRegistrySection", "{section}")'.encode()
                    assert body.count(seed) == 1
                    body = body.replace(seed, seed + b'''\n    ' Private native entry proof never uploads.
    m.profileSyncWriterReady = false
    m.profileSyncSchedulingReady = false''', 1)
                    anchor = b"sub onLaunchRequest()\n"
                    assert body.count(anchor) == 1
                    body = body.replace(anchor, anchor + b'''    if m.top.launchRequest.directionsVoiceSubmit = "1"
        m.directionsVoiceSubmit = true
        return
    end if
''', 1)
                target.writestr(name, body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=Path("out/mrr-directions-native-entry-native.json"))
    parser.add_argument("--cancel", action="store_true", help="Real Back from native launch keyboard must exit without provider requests")
    args = parser.parse_args()
    device = module("directions_voice_device", "test-profile-primitives-native.py")
    recovery = module("directions_voice_recovery", "test-profile-recovery-native.py")
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    expected = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if device.installed_md5(host, password) != expected:
        raise RuntimeError("Exact installed baseline differs; refusing candidate")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    hits = []

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            hits.append(self.path)
            value = []
            if self.path == "/api/accounts/users/me/":
                value = {"id": 7, "username": "Synthetic7", "user_level": 1}
            elif self.path == "/api/accounts/users/me/app-data/":
                value = {"apps": []}
            raw = json.dumps(value).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    report = {"passed": False, "mode": "cancel" if args.cancel else "entry", "entry_integration_passed": False, "spoken_entry_verified": False, "public_approval": False, "events": [], "requests": hits}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    section = "AerioDirectionsVoice-" + str(uuid.uuid4())

    def run(path, marker, prefix, timeout=45):
        return subprocess.run([sys.executable, "scripts/run-native-probe.py", str(path), "--prefix", prefix, "--marker", marker, "--timeout", str(timeout)], cwd=ROOT, capture_output=True, text=True, timeout=timeout + 60)

    with tempfile.TemporaryDirectory(prefix="directions-voice-", dir=ROOT / "out") as folder:
        archive, cleaner = Path(folder) / "candidate.zip", Path(folder) / "cleanup.zip"
        build(ROOT / "out/aeriotv-roku.zip", archive, section, f"http://{local}:{server.server_port}")
        recovery.cleanup_package(cleaner, section)
        marker = "[profile-pin] exit-main" if args.cancel else '"kind":"guide"'
        command = [sys.executable, "scripts/run-native-probe.py", str(archive), "--prefix", "[profile-pin]", "--marker", marker, "--timeout", "75"]
        try:
            with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    if "[profile-pin] {" not in line:
                        continue
                    event = json.loads(line.split("[profile-pin] ", 1)[1])
                    report["events"].append(event)
                    if event["kind"] == "covered":
                        report["before_entry_requests"] = hits.copy()
                        if args.cancel:
                            req = urllib.request.Request(f"http://{host}:8060/keypress/Back", data=b"", method="POST")
                            with urllib.request.urlopen(req, timeout=3) as response:
                                report["back_status"] = response.status
                            continue
                        statuses = []
                        for letter in "udlr":
                            req = urllib.request.Request(f"http://{host}:8060/keypress/Lit_{letter}", data=b"", method="POST")
                            with urllib.request.urlopen(req, timeout=3) as response:
                                statuses.append(response.status)
                        report["text_entry_statuses"] = statuses
                        image = args.report.with_suffix(".keyboard.jpg")
                        capture = subprocess.run([sys.executable, "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", str(image)], cwd=ROOT, capture_output=True, timeout=45)
                        report["masked_keyboard_capture"] = capture.returncode == 0
                        report["before_submit_requests"] = hits.copy()
                        req = urllib.request.Request(f"http://{host}:8060/input?directionsVoiceSubmit=1", data=b"", method="POST")
                        with urllib.request.urlopen(req, timeout=3) as response:
                            report["submit_status"] = response.status
                code = process.wait(timeout=10)
            rows = report["events"]
            covered = next((r for r in rows if r["kind"] == "covered"), {})
            report["voice_available_observed"] = covered.get("voice") is True
            report["entry_integration_passed"] = code == 0 and [r["kind"] for r in rows] == ["covered", "input", "unlocked", "guide"] and all(covered.get(k) is True for k in ["covered", "closed", "nativekeyboard", "masked"]) and covered.get("domain") == "password" and not covered.get("task") and rows[1]["characters"] == 4 and rows[2].get("grant") is True and rows[3].get("account") == "7" and report.get("before_entry_requests") == [] and report.get("before_submit_requests") == [] and report.get("text_entry_statuses") == [200] * 4 and report.get("submit_status") == 200 and report.get("masked_keyboard_capture") is True
            if args.cancel:
                report["entry_integration_passed"] = code == 0 and [r["kind"] for r in rows] == ["covered"] and all(covered.get(k) is True for k in ["covered", "closed", "nativekeyboard", "masked"]) and covered.get("domain") == "password" and not covered.get("task") and hits == [] and report.get("back_status") == 200
            report["passed"] = report["entry_integration_passed"]
        finally:
            try:
                cleaned = run(cleaner, "cleanup=", "[profile-recovery]")
                report["cleaned"] = cleaned.returncode == 0 and "cleanup=true" in cleaned.stdout
            finally:
                restored = run(args.restore, "Running dev", "[restore]")
                report["restored"] = restored.returncode == 0 and device.installed_md5(host, password) == expected
                server.shutdown()
                server.server_close()
                args.report.write_text(json.dumps(report, indent=2) + "\n")
                print(json.dumps({k: report.get(k) for k in ["passed", "cleaned", "restored", "public_approval"]}), flush=True)
    if not all(report.get(k) for k in ["passed", "cleaned", "restored"]):
        raise SystemExit("Native Directions candidate requires attention")


if __name__ == "__main__":
    main()
