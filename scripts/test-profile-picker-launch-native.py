"""Qualify private normal-app startup selection with isolated HTTP and registry."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import threading
import time
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(path, normal, section, base, mode="plain"):
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == "manifest":
                body = body.replace(b"title=AerioTV\n", b"title=Aerio Startup Picker Probe\n")
            elif name == "source/MetadataCacheStore.brs":
                assert body.count(b'"cachefs:/aeriotv-metadata-v1"') == 1
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/picker-launch-cache"')
            elif name == "components/AerioScene.brs":
                source = body.decode()
                assert source.count("m.profilePickerReady = false") == 1
                source = source.replace("m.profilePickerReady = false", "m.profilePickerReady = true", 1)
                target = '    m.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert source.count(target) == 1
                source = source.replace(target, f'    m.registry = CreateObject("roRegistrySection", "{section}")\n    seedProfilePickerLaunchProbe({json.dumps(base)}, {json.dumps(mode)})', 1)
                target = "sub onLaunchRequest()\n"
                assert source.count(target) == 1
                source = source.replace(target, target + '''    if m.top.launchRequest.pickerProbeSubmit = "1"
        m.pickerProbeSubmit = true
        return
    end if
''', 1)
                target = '    if not welcome\n        launchGate = selectedUserProfileGate()'
                assert source.count(target) == 1
                source = source.replace(target, '    if not welcome\n        if beginUserProfileLaunchPicker(false) then return\n        launchGate = selectedUserProfileGate()', 1)
                if mode == "back":
                    target = "            cancelStartupProfileTask()\n            closeUserProfileLaunchPicker()\n            m.top.exitRequested = true"
                    assert source.count(target) == 1
                    source = source.replace(target, target.replace("            m.top.exitRequested", "            verifyStartupPickerProbeCancel()\n            m.top.exitRequested"), 1)
                body = source.encode() + b"\n" + (ROOT / "tests/native/ProfilePickerLaunchFixture.brs").read_bytes()
            elif name == "components/AerioScene.xml" and mode == "back":
                body = body.replace(b"<interface>", b'<interface><field id="pickerProbeCancelPassed" type="boolean" value="false" />', 1)
            elif name == "source/Main.brs" and mode == "back":
                target = b"                    screen.close()\n"
                assert body.count(target) == 1
                body = body.replace(target, b'                    passed = scene.pickerProbeCancelPassed\n' + target + b'                    print "[picker-launch] "; FormatJson({kind: "result", passed: passed, exited: true})\n', 1)
            elif name == "components/ProfilePickerNavigation.brs":
                target = b"    m.profileStartupTask = task\n"
                assert body.count(target) == 1
                body = body.replace(target, target + b'    m.pickerProbeTask = task\n    print "[picker-launch] "; FormatJson({kind: "phase", phase: phase, no_actor: m.activeUserScope = invalid, empty_key: m.apiKey = "", read_nonce: textValue(context.readNonce)})\n', 1)
                if mode == "back":
                    target = b"        m.top.exitRequested = true\n"
                    assert body.count(target) == 1
                    body = body.replace(target, b"        verifyStartupPickerProbeCancel()\n" + target, 1)
            elif name == "components/GuideView.xml":
                body = body.replace(b"</interface>", b'<function name="profilePickerProbeLineup" /></interface>', 1)
            elif name == "components/GuideView.brs":
                body += b'\nfunction profilePickerProbeLineup() as string\n    if type(m.channels) <> "roArray" then return ""\n    if m.channels.count() = 0 then return ""\n    return m.channels[0].id\nend function\n'
            package.writestr(name, body)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True)
    parser.add_argument("--report", default="out/profile-picker-launch-native.json")
    parser.add_argument("--mode", choices=["plain", "pin", "import-pin", "back", "reject"], default="plain")
    args = parser.parse_args()
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    modules = {}
    for name in ["primitives", "recovery", "management"]:
        spec = importlib.util.spec_from_file_location(name, ROOT / f"scripts/test-profile-{name}-native.py")
        modules[name] = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modules[name])
    restore = Path(args.restore)
    digest = hashlib.md5(restore.read_bytes()).hexdigest()
    if modules["primitives"].installed_md5(host, password) != digest:
        raise RuntimeError("Exact restore ZIP differs from installed app")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    hits = []
    stamp = int(time.time())

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            key = self.headers.get("X-API-Key", "")
            user = {"synthetic-a": 7, "synthetic-b": 8}.get(key, 0)
            hits.append({"user": user, "path": self.path, "method": "GET"})
            if args.mode == "back" and self.path == "/api/accounts/users/me/" and not report.get("back_attempted"):
                report["back_attempted"] = True
                report["back_activity"] = modules["management"].management_probe_activity(host)
                if report["back_activity"] == {"dev_active": True, "screensaver_active": False}:
                    request = urllib.request.Request(f"http://{host}:8060/keypress/Back", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            report["back_status"] = response.status
                    except OSError as error:
                        report["back_error"] = type(error).__name__
                time.sleep(4)
            value = []
            if self.path == "/api/accounts/users/me/":
                value = {"id": user, "username": f"Synthetic{user}", "user_level": 1}
            elif self.path == "/api/accounts/users/me/app-data/":
                value = {"apps": [{"key": "synthetic8.aeriotv", "bytes": 600}]} if args.mode == "import-pin" else {"apps": []}
            elif self.path == "/api/accounts/users/me/app-data/synthetic8.aeriotv/":
                salt = "0123456789abcdef0123456789abcdef"
                updated = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(stamp))
                value = {"schemaVersion": 3, "deviceId": "synthetic-phone", "platform": "android", "appVersion": "1", "updatedAt": updated, "categories": {"profiles": {"updatedAt": updated, "data": {"rows": [[8, "Synthetic8", "Imported target", "numbers", hashlib.sha256(bytes.fromhex(salt) + b"5678").hexdigest(), salt, "user", stamp, {}, 0]], "removed": []}}}}
            elif self.path.split("?", 1)[0] in ["/api/channels/channels/", "/api/channels/channels/summary/"]:
                value = [{"id": user, "uuid": f"00000000-0000-4000-8000-{user:012d}", "name": f"Synthetic {user}", "channel_number": user}]
            rejected = args.mode == "reject"
            if rejected:
                value = {"detail": "Invalid API key"}
            body = json.dumps(value).encode()
            self.send_response(401 if rejected or not user else 200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def do_POST(self):
            hits.append({"method": self.command, "unexpected": True})
            self.send_error(405)

        do_PUT = do_POST
        do_PATCH = do_POST
        do_DELETE = do_POST

    server = ThreadingHTTPServer((local, 0), Fixture)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = "AerioPickerLaunchProbe-" + str(uuid.uuid4())
    archive = ROOT / "out/profile-picker-launch-probe.zip"
    cleaner = ROOT / "out/profile-picker-launch-cleanup.zip"
    build(archive, ROOT / "out/aeriotv-roku.zip", section, f"http://{local}:{server.server_port}", args.mode)
    modules["recovery"].cleanup_package(cleaner, section)
    report = {"passed": False, "mode": args.mode, "events": [], "keys": [], "restore_sha256": hashlib.sha256(restore.read_bytes()).hexdigest()}
    process = None

    def run(path, marker, prefix):
        return subprocess.run(["python3", "scripts/run-native-probe.py", str(path), "--prefix", prefix, "--marker", marker, "--timeout", "45"], cwd=ROOT, capture_output=True, text=True, timeout=100)

    try:
        process = subprocess.Popen(["python3", "scripts/run-native-probe.py", str(archive), "--prefix", "[picker-launch]", "--marker", '"kind":"result"', "--timeout", "75"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end="", flush=True)
            report.setdefault("output", []).append(line.rstrip())
            if "[picker-launch] {" not in line:
                continue
            event = json.loads(line.split("[picker-launch] ", 1)[1])
            report["events"].append(event)
            if event["kind"] == "ready":
                report["pre_selection_requests"] = hits.copy()
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", "out/profile-picker-launch-native.jpg"], cwd=ROOT, capture_output=True, timeout=40)
                report["screenshot"] = captured.returncode == 0
                for key in ["Right", "Select"]:
                    attempt = {"key": key}
                    report["keys"].append(attempt)
                    request = urllib.request.Request(f"http://{host}:8060/keypress/{key}", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            attempt["status"] = response.status
                    except OSError as error:
                        attempt["error"] = type(error).__name__
                        break
            elif event["kind"] == "pin-ready":
                report.setdefault("pre_pin_requests", []).append(hits.copy())
                command = {"number": event["number"]}
                report.setdefault("pin_commands", []).append(command)
                request = urllib.request.Request(f"http://{host}:8060/input?pickerProbeSubmit=1", data=b"", method="POST")
                try:
                    with urllib.request.urlopen(request, timeout=3) as response:
                        command["status"] = response.status
                except OSError as error:
                    command["error"] = type(error).__name__
        code = process.wait(timeout=15)
        events = report["events"]
        phases = [e for e in events if e["kind"] == "phase"]
        paths = [hit.get("path", "") for hit in hits]
        listing = next((i for i, path in enumerate(paths) if path == "/api/accounts/users/me/app-data/"), -1)
        heavy = next((i for i, path in enumerate(paths) if path.startswith("/api/channels/")), -1)
        report["requests"] = hits.copy()
        expected_phases = ["authenticate", "read", "load"]
        if args.mode == "import-pin":
            expected_phases.insert(2, "read")
        pins = [event for event in events if event["kind"] == "pin-submitted"]
        pin_count = {"plain": 0, "pin": 1, "import-pin": 2, "back": 0, "reject": 0}[args.mode]
        before_pins = report.get("pre_pin_requests", [])
        pin_ok = len(pins) == pin_count and all(event["wrong_covered"] and event["verified"] for event in pins) and [command.get("status") for command in report.get("pin_commands", [])] == [200] * pin_count
        if pin_count:
            pin_ok = pin_ok and len(before_pins) == pin_count and before_pins[0] == [] and all(not hit.get("path", "").startswith("/api/channels/") for boundary in before_pins for hit in boundary)
        if args.mode == "import-pin":
            reads = [event["read_nonce"] for event in phases if event["phase"] == "read"]
            pin_ok = pin_ok and len(set(reads)) == 2 and all(reads) and paths.count("/api/accounts/users/me/app-data/synthetic8.aeriotv/") == 2
        report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == [200, 200] and [p["phase"] for p in phases] == expected_phases and all(p["no_actor"] and p["empty_key"] for p in phases) and all(h.get("user") == 8 and h["method"] == "GET" for h in hits) and listing >= 2 and heavy > listing and paths.count("/api/accounts/users/me/") >= 3 and pin_ok
        if args.mode in ["back", "reject"]:
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("exited" if args.mode == "back" else "rejected") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == [200, 200] and [p["phase"] for p in phases] == ["authenticate"] and all(p["no_actor"] and p["empty_key"] for p in phases) and len(hits) == 1 and hits[0].get("user") == 8 and hits[0].get("path") == "/api/accounts/users/me/" and hits[0]["method"] == "GET"
            if args.mode == "back":
                report["passed"] = report["passed"] and report.get("back_status") == 200 and report.get("back_activity") == {"dev_active": True, "screensaver_active": False}
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        try:
            cleaned = run(cleaner, "[profile-recovery] cleanup=", "[profile-recovery]")
            report["cleaned"] = cleaned.returncode == 0 and "cleanup=true" in cleaned.stdout
        finally:
            restored = run(restore, "Running dev", "[picker-restore]")
            report["restored"] = restored.returncode == 0 and modules["primitives"].installed_md5(host, password) == digest
            server.shutdown()
            server.server_close()
            Path(args.report).write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps({key: report.get(key, False) for key in ["passed", "cleaned", "restored"]}), flush=True)
        if not report.get("cleaned") or not report.get("restored"):
            raise RuntimeError("Private cleanup or exact app restoration failed")
    if not report["passed"]:
        raise SystemExit("Native startup picker qualification failed")


if __name__ == "__main__":
    main()
