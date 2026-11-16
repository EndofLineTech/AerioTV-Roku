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
import urllib.parse
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def await_back_ack(report, completed):
    """Join the HTTP-thread command result, not a later snapshot during cleanup."""
    if not report.get("back_attempted") or not completed.wait(5):
        return False
    return report.get("back_status") == 200


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
                target = "sub onLaunchRequest()\n    if m.profileStartupDeferred = true then return\n"
                assert source.count(target) == 1
                source = source.replace(target, target + '''    if m.top.launchRequest.pickerProbeSubmit = "1"
        m.pickerProbeSubmit = true
        return
    end if
''', 1)
                target = '    if not welcome\n        if deferUserProfileLaunch() then return\n        launchGate = selectedUserProfileGate()'
                assert source.count(target) == 1
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
            elif name == "source/Main.brs" and mode == "cold-link":
                target = b'    if type(args) = "roAssociativeArray" then scene.launchRequest = args'
                assert body.count(target) == 1
                body = body.replace(target, b'    scene.launchRequest = {contentId: "missing-fixture-id", mediaType: "live"}', 1)
            elif name == "source/StartupBeaconModel.brs":
                for beacon in ["AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]:
                    target = f'    m.top.signalBeacon("{beacon}")'.encode()
                    assert body.count(target) == 1
                    body = body.replace(target, f'    print "[picker-launch] "; FormatJson({{kind: "beacon", name: "{beacon}"}})\n'.encode() + target, 1)
            elif name == "components/ProfilePickerNavigation.brs":
                if mode == "identity":
                    target = b"sub beginStartupProfileSelection(targetId as string, ownPin = invalid as dynamic)\n"
                    assert body.count(target) == 1
                    body = body.replace(target, target + b"    if m.pickerProbeSelectionCount = invalid then m.pickerProbeSelectionCount = 0\n    m.pickerProbeSelectionCount++\n", 1)
                target = b"    m.profilePicker = picker\n"
                assert body.count(target) == 1
                body = body.replace(target, target + b"    m.pickerProbePickerCount++\n", 1)
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
    parser.add_argument("--mode", choices=["plain", "pin", "import-pin", "back", "reject", "identity", "cold-link", "warm-link", "warm-pin-link", "warm-auth-link", "warm-import-pin-link", "warm-load-link", "own-keyless", "own-pin", "own-held", "own-cancel", "own-link", "own-pin-link", "own-auth-link", "own-default", "own-default-pin", "own-wrong", "own-recreated", "own-memory", "own-keyboard"], default="plain")
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
    back_completed = threading.Event()
    own_cancel_completed = threading.Event()
    own_link_completed = threading.Event()
    stamp = int(time.time())
    target_user = 7 if args.mode in ["own-default", "own-default-pin"] else 8
    if args.mode == "own-recreated":
        target_user = 88
    credential_user = 7 if target_user == 7 else 8

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_POST(self):
            if args.mode not in ["own-keyless", "own-pin", "own-held", "own-cancel", "own-auth-link", "own-default", "own-default-pin", "own-wrong", "own-recreated", "own-memory", "own-keyboard"]:
                self.reject_write()
                return
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            accepted = self.path == "/api/accounts/token/" and body == {"username": f"Synthetic{credential_user}", "password": "synthetic-password"} and not self.headers.get("X-API-Key") and not self.headers.get("Authorization")
            report.setdefault("credential_posts", []).append({"path": self.path, "accepted": accepted})
            if args.mode == "own-auth-link":
                report["media_input_activity"] = modules["management"].management_probe_activity(host)
                if report["media_input_activity"] == {"dev_active": True, "screensaver_active": False}:
                    command = urllib.request.Request(f"http://{host}:8060/input?contentId=missing-fixture-id&mediaType=live", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(command, timeout=3) as response:
                            report["media_input_status"] = response.status
                    except OSError as error:
                        report["media_input_error"] = type(error).__name__
                own_link_completed.set()
                time.sleep(4)
            if args.mode == "own-cancel" and len(report["credential_posts"]) == 1:
                report["own_cancel_activity"] = modules["management"].management_probe_activity(host)
                if report["own_cancel_activity"] == {"dev_active": True, "screensaver_active": False}:
                    command = urllib.request.Request(f"http://{host}:8060/keypress/Back", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(command, timeout=3) as response:
                            report["own_cancel_status"] = response.status
                    except OSError as error:
                        report["own_cancel_error"] = type(error).__name__
                own_cancel_completed.set()
                time.sleep(4)
            encoded = json.dumps({"access": "synthetic-startup"} if accepted else {"detail": "Unauthorized"}).encode()
            self.send_response(200 if accepted else 401)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            try:
                self.wfile.write(encoded)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def do_GET(self):
            key = self.headers.get("X-API-Key", "")
            user = {"synthetic-a": 7, "synthetic-b": 8}.get(key, 0)
            if args.mode == "own-recreated" and key == "synthetic-b":
                user = 88
            bearer = self.headers.get("Authorization") == "Bearer synthetic-startup"
            if bearer:
                user = target_user
            hits.append({"user": user, "path": self.path, "method": "GET", "own_password_check": bearer})
            delayed_link = args.mode == "warm-auth-link" and self.path == "/api/accounts/users/me/"
            delayed_link = delayed_link or args.mode == "warm-load-link" and self.path.startswith("/api/channels/")
            if delayed_link and user == 8 and not report.get("media_input_attempted"):
                report["media_input_attempted"] = True
                report["media_input_boundary"] = hits.copy()
                report["media_input_activity"] = modules["management"].management_probe_activity(host)
                if report["media_input_activity"] == {"dev_active": True, "screensaver_active": False}:
                    request = urllib.request.Request(f"http://{host}:8060/input?contentId=missing-fixture-id&mediaType=live", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            report["media_input_status"] = response.status
                    except OSError as error:
                        report["media_input_error"] = type(error).__name__
                time.sleep(4)
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
                back_completed.set()
                time.sleep(4)
            value = []
            if self.path == "/api/accounts/users/me/":
                value = {"id": user, "username": f"Synthetic{user}", "user_level": 1}
                if args.mode == "own-recreated" and user == 88:
                    value["username"] = "Synthetic8"
                if bearer:
                    value["api_key"] = "synthetic-a" if target_user == 7 else "synthetic-b"
                if args.mode == "identity":
                    value = {"id": 9, "username": "Synthetic9", "user_level": 1}
                    report["mismatched_me_response"] = {"status": 200, "id": 9, "username": "Synthetic9"}
            elif self.path == "/api/accounts/users/me/app-data/":
                value = {"apps": [{"key": "synthetic8.aeriotv", "bytes": 600}]} if args.mode in ["import-pin", "warm-import-pin-link"] and user == 8 else {"apps": []}
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

        def reject_write(self):
            hits.append({"method": self.command, "unexpected": True})
            self.send_error(405)

        do_PUT = reject_write
        do_PATCH = reject_write
        do_DELETE = reject_write

    server = ThreadingHTTPServer((local, 0), Fixture)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = "AerioPickerLaunchProbe-" + str(uuid.uuid4())
    archive = ROOT / "out/profile-picker-launch-probe.zip"
    cleaner = ROOT / "out/profile-picker-launch-cleanup.zip"
    build(archive, ROOT / "out/aeriotv-roku.zip", section, f"http://{local}:{server.server_port}", args.mode)
    modules["recovery"].cleanup_package(cleaner, section)
    report = {"passed": False, "mode": args.mode, "events": [], "keys": [], "restore_sha256": hashlib.sha256(restore.read_bytes()).hexdigest(), "probe_sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
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
                screenshot_path = str(Path(args.report).with_suffix(".jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", screenshot_path], cwd=ROOT, capture_output=True, timeout=40)
                report["screenshot"] = captured.returncode == 0
                report["screenshot_path"] = screenshot_path
                keys = [] if args.mode in ["cold-link", "warm-link"] else ["Right", "Select"]
                if args.mode in ["own-default", "own-default-pin"]:
                    keys = ["Select"]
                if args.mode == "warm-link":
                    request = urllib.request.Request(f"http://{host}:8060/input?contentId=missing-fixture-id&mediaType=live", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            report["media_input_status"] = response.status
                    except OSError as error:
                        report["media_input_error"] = type(error).__name__
                for key in keys:
                    attempt = {"key": key}
                    report["keys"].append(attempt)
                    request = urllib.request.Request(f"http://{host}:8060/keypress/{key}", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            attempt["status"] = response.status
                    except OSError as error:
                        attempt["error"] = type(error).__name__
                        break
            elif event["kind"] == "keyboard-ready":
                value = "Synthetic8" if event["field"] == "username" else "synthetic-password"
                image = str(Path(args.report).with_name(Path(args.report).stem + f'-{event["field"]}-keyboard.jpg'))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                entry = {"field": event["field"], "characters": len(value), "statuses": [], "captured": captured.returncode == 0}
                report.setdefault("keyboard_inputs", []).append(entry)
                for character in value:
                    command = urllib.request.Request(f"http://{host}:8060/keypress/Lit_{urllib.parse.quote(character, safe='')}", data=b"", method="POST")
                    with urllib.request.urlopen(command, timeout=3) as response:
                        entry["statuses"].append(response.status)
                image = str(Path(args.report).with_name(Path(args.report).stem + f'-{event["field"]}-filled-keyboard.jpg'))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                entry["filled_captured"] = captured.returncode == 0
                command = urllib.request.Request(f"http://{host}:8060/input?pickerProbeSubmit=1", data=b"", method="POST")
                with urllib.request.urlopen(command, timeout=3) as response:
                    entry["submit_status"] = response.status
            elif event["kind"] == "own-rejected":
                report["own_rejected"] = event.get("passed") is True
                report["own_rejected_boundary"] = hits.copy()
                command = urllib.request.Request(f"http://{host}:8060/input?pickerProbeSubmit=1", data=b"", method="POST")
                with urllib.request.urlopen(command, timeout=3) as response:
                    report["own_retry_status"] = response.status
            elif event["kind"] == "own-cancelled":
                report["own_cancelled"] = event.get("passed") is True
                report["own_cancel_boundary"] = hits.copy()
                command = urllib.request.Request(f"http://{host}:8060/keypress/Select", data=b"", method="POST")
                with urllib.request.urlopen(command, timeout=3) as response:
                    report["own_retry_status"] = response.status
            elif event["kind"] == "own-form-ready":
                report["pre_form_requests"] = hits.copy()
                image = str(Path(args.report).with_name(Path(args.report).stem + "-own-form.jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                report["own_form_screenshot"] = captured.returncode == 0
                if args.mode in ["own-link", "own-pin-link"]:
                    command = urllib.request.Request(f"http://{host}:8060/input?contentId=missing-fixture-id&mediaType=live", data=b"", method="POST")
                    with urllib.request.urlopen(command, timeout=3) as response:
                        report["media_input_status"] = response.status
                    continue
                command = urllib.request.Request(f"http://{host}:8060/input?pickerProbeSubmit=1", data=b"", method="POST")
                with urllib.request.urlopen(command, timeout=3) as response:
                    report["own_form_submit_status"] = response.status
            elif event["kind"] == "pin-ready":
                report.setdefault("pre_pin_requests", []).append(hits.copy())
                if args.mode in ["warm-pin-link", "warm-import-pin-link"] and event.get("target_before_link"):
                    request = urllib.request.Request(f"http://{host}:8060/input?contentId=missing-fixture-id&mediaType=live", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=3) as response:
                            report["media_input_status"] = response.status
                    except OSError as error:
                        report["media_input_error"] = type(error).__name__
                    continue
                if event.get("source_pin"):
                    image = str(Path(args.report).with_name(Path(args.report).stem + f'-source-pin-{event["number"]}.jpg'))
                    captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                    report.setdefault("source_pin_screenshots", []).append({"path": image, "captured": captured.returncode == 0})
                command = {"number": event["number"]}
                report.setdefault("pin_commands", []).append(command)
                request = urllib.request.Request(f"http://{host}:8060/input?pickerProbeSubmit=1", data=b"", method="POST")
                try:
                    with urllib.request.urlopen(request, timeout=3) as response:
                        command["status"] = response.status
                except OSError as error:
                    command["error"] = type(error).__name__
            elif event["kind"] == "rejected-ready":
                report["rejected_ready"] = event.get("ready", False)
                report["held_retry_boundary"] = hits.copy()
                image = str(Path(args.report).with_name(Path(args.report).stem + "-rejected.jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                report["rejected_screenshot"] = captured.returncode == 0
                report["rejected_screenshot_path"] = image
                if not report["rejected_ready"]:
                    raise RuntimeError("Rejected startup target lost focus or ownership")
                request = urllib.request.Request(f"http://{host}:8060/keypress/Select", data=b"", method="POST")
                try:
                    with urllib.request.urlopen(request, timeout=3) as response:
                        report["held_retry_status"] = response.status
                except OSError as error:
                    report["held_retry_error"] = type(error).__name__
        code = process.wait(timeout=15)
        if args.mode == "back":
            report["back_ack_before_verdict"] = await_back_ack(report, back_completed)
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
        pin_count = {"plain": 0, "pin": 1, "import-pin": 2, "back": 0, "reject": 0, "identity": 0, "cold-link": 1, "warm-link": 1, "warm-pin-link": 1, "warm-auth-link": 1, "warm-import-pin-link": 2, "warm-load-link": 1, "own-keyless": 0, "own-pin": 1, "own-held": 0, "own-cancel": 0, "own-link": 1, "own-pin-link": 2, "own-auth-link": 1, "own-default": 0, "own-default-pin": 1, "own-wrong": 0, "own-recreated": 0, "own-memory": 0, "own-keyboard": 0}[args.mode]
        before_pins = report.get("pre_pin_requests", [])
        pin_ok = len(pins) == pin_count and all(event["wrong_covered"] and event["verified"] for event in pins) and [command.get("status") for command in report.get("pin_commands", [])] == [200] * pin_count
        if pin_count:
            pin_ok = pin_ok and len(before_pins) == pin_count and before_pins[0] == [] and all(not hit.get("path", "").startswith("/api/channels/") for boundary in before_pins for hit in boundary)
        if args.mode == "import-pin":
            reads = [event["read_nonce"] for event in phases if event["phase"] == "read"]
            pin_ok = pin_ok and len(set(reads)) == 2 and all(reads) and paths.count("/api/accounts/users/me/app-data/synthetic8.aeriotv/") == 2
        wanted_keys = [200] if args.mode in ["own-default", "own-default-pin"] else [200, 200]
        report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == wanted_keys and [p["phase"] for p in phases] == expected_phases and all(p["no_actor"] and p["empty_key"] for p in phases) and all(h.get("user") == target_user and h["method"] == "GET" for h in hits) and listing >= 2 and heavy > listing and paths.count("/api/accounts/users/me/") >= 3 and pin_ok
        if args.mode in ["own-keyless", "own-pin", "own-held", "own-cancel", "own-default", "own-default-pin", "own-wrong", "own-recreated", "own-memory", "own-keyboard"]:
            post_count = 2 if args.mode == "own-cancel" else 1
            expected_posts = [{"path": "/api/accounts/token/", "accepted": True}] * post_count
            if args.mode == "own-wrong":
                expected_posts.insert(0, {"path": "/api/accounts/token/", "accepted": False})
            report["passed"] = report["passed"] and report.get("credential_posts") == expected_posts and report.get("pre_form_requests") == [] and report.get("own_form_submit_status") == 200 and report.get("own_form_screenshot") is True and hits[0].get("own_password_check") is True and sum(hit["own_password_check"] for hit in hits) == 1
            report["passed"] = report["passed"] and [event["name"] for event in events if event["kind"] == "beacon"] == ["AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]
            if args.mode == "own-cancel":
                report["passed"] = report["passed"] and own_cancel_completed.wait(5) and report.get("own_cancel_status") == 200 and report.get("own_cancelled") is True and report.get("own_cancel_boundary") == [] and report.get("own_retry_status") == 200 and report.get("own_cancel_activity") == {"dev_active": True, "screensaver_active": False}
            if args.mode == "own-wrong":
                report["passed"] = report["passed"] and report.get("own_rejected") is True and report.get("own_rejected_boundary") == [] and report.get("own_retry_status") == 200
            if args.mode == "own-keyboard":
                inputs = report.get("keyboard_inputs", [])
                results = [event for event in events if event["kind"] == "keyboard-result"]
                report["passed"] = report["passed"] and [item["field"] for item in inputs] == ["username", "password"] and all(item["captured"] and item["filled_captured"] and item.get("submit_status") == 200 and item["statuses"] == [200] * item["characters"] for item in inputs) and len(results) == 1 and results[0].get("passed") is True
        if args.mode in ["back", "reject", "identity"]:
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("exited" if args.mode == "back" else "rejected") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == [200, 200] and [p["phase"] for p in phases] == ["authenticate"] and all(p["no_actor"] and p["empty_key"] for p in phases) and len(hits) == 1 and hits[0].get("user") == 8 and hits[0].get("path") == "/api/accounts/users/me/" and hits[0]["method"] == "GET"
            if args.mode == "back":
                report["passed"] = report["passed"] and report.get("back_ack_before_verdict") is True and report.get("back_status") == 200 and report.get("back_activity") == {"dev_active": True, "screensaver_active": False}
            else:
                report["passed"] = report["passed"] and report.get("rejected_ready") is True and report.get("held_retry_status") == 200 and report.get("rejected_screenshot") is True and len(report.get("held_retry_boundary", [])) == 1 and events[-1].get("held_refused") is True
                if args.mode == "identity":
                    report["passed"] = report["passed"] and report.get("mismatched_me_response") == {"status": 200, "id": 9, "username": "Synthetic9"} and events[-1].get("no_broker_hold") is True
        if args.mode in ["cold-link", "warm-link", "warm-pin-link", "warm-auth-link", "warm-import-pin-link", "warm-load-link"]:
            expected_beacons = ["AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]
            if args.mode != "cold-link":
                expected_beacons = ["AppDialogInitiate", "AppDialogComplete", "AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]
            beacons = [event["name"] for event in events if event["kind"] == "beacon"]
            expected_keys = [] if args.mode in ["cold-link", "warm-link"] else [200, 200]
            expected_phases = ["authenticate"] if args.mode == "warm-auth-link" else []
            own_hits = hits
            pin_ok = len(pins) == 1 and pins[0]["wrong_covered"] and pins[0]["verified"] and [command.get("status") for command in report.get("pin_commands", [])] == [200]
            if args.mode == "warm-auth-link":
                pin_ok = pin_ok and len(before_pins) == 1 and len(before_pins[0]) == 1 and before_pins[0][0].get("user") == 8 and before_pins[0][0].get("path") == "/api/accounts/users/me/"
                own_hits = hits[1:]
                pin_ok = pin_ok and report.get("media_input_activity") == {"dev_active": True, "screensaver_active": False}
            else:
                pin_ok = pin_ok and len(before_pins) == (2 if args.mode == "warm-pin-link" else 1) and all(boundary == [] for boundary in before_pins)
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("source_link") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [p["phase"] for p in phases] == expected_phases and [key.get("status") for key in report["keys"]] == expected_keys and all(h.get("user") == 7 and h["method"] == "GET" for h in own_hits) and listing >= 2 and heavy > listing and paths.count("/api/accounts/users/me/") >= 3 and pin_ok and beacons == expected_beacons
            report["passed"] = report["passed"] and len(report.get("source_pin_screenshots", [])) == 1 and all(image["captured"] for image in report["source_pin_screenshots"])
            if args.mode != "cold-link":
                report["passed"] = report["passed"] and report.get("media_input_status") == 200
        if args.mode in ["warm-import-pin-link", "warm-load-link"]:
            target_hits = [hit for hit in hits if hit.get("user") == 8]
            source_hits = hits[len(target_hits):]
            pin_ok = len(pins) == pin_count and all(pin["wrong_covered"] and pin["verified"] for pin in pins) and [command.get("status") for command in report.get("pin_commands", [])] == [200] * pin_count
            if args.mode == "warm-import-pin-link":
                expected_target_paths = ["/api/accounts/users/me/", "/api/accounts/users/me/", "/api/accounts/users/me/app-data/", "/api/accounts/users/me/app-data/synthetic8.aeriotv/"]
                expected_phases = ["authenticate", "read"]
                pin_ok = pin_ok and len(before_pins) == 3 and before_pins[0] == [] and before_pins[1] == target_hits and before_pins[2] == target_hits
            else:
                expected_target_paths = ["/api/accounts/users/me/", "/api/accounts/users/me/", "/api/accounts/users/me/app-data/", "/api/accounts/users/me/", "/api/channels/channels/summary/?ordering=channel_number"]
                expected_phases = ["authenticate", "read", "load"]
                pin_ok = pin_ok and len(before_pins) == 1 and before_pins[0] == target_hits and report.get("media_input_boundary") == target_hits and report.get("media_input_activity") == {"dev_active": True, "screensaver_active": False}
            source_paths = [hit["path"] for hit in source_hits]
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("source_link") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [key.get("status") for key in report["keys"]] == [200, 200] and [p["phase"] for p in phases] == expected_phases and all(p["no_actor"] and p["empty_key"] for p in phases) and [hit["path"] for hit in target_hits] == expected_target_paths and all(hit.get("user") == 7 and hit["method"] == "GET" for hit in source_hits) and source_paths.count("/api/accounts/users/me/") >= 3 and "/api/accounts/users/me/app-data/" in source_paths and any(path.startswith("/api/channels/") for path in source_paths) and pin_ok and beacons == expected_beacons and report.get("media_input_status") == 200 and len(report.get("source_pin_screenshots", [])) == 1 and report["source_pin_screenshots"][0]["captured"]
        if args.mode in ["own-link", "own-pin-link", "own-auth-link"]:
            beacons = [event["name"] for event in events if event["kind"] == "beacon"]
            pin_ok = len(pins) == pin_count and all(pin["wrong_covered"] and pin["verified"] for pin in pins) and [command.get("status") for command in report.get("pin_commands", [])] == [200] * pin_count and len(before_pins) == pin_count and all(boundary == [] for boundary in before_pins)
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("source_link") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [key.get("status") for key in report["keys"]] == [200, 200] and phases == [] and all(hit.get("user") == 7 and hit["method"] == "GET" and not hit["own_password_check"] for hit in hits) and listing >= 2 and heavy > listing and paths.count("/api/accounts/users/me/") >= 3 and pin_ok and report.get("pre_form_requests") == [] and report.get("own_form_screenshot") is True and report.get("media_input_status") == 200 and beacons == ["AppDialogInitiate", "AppDialogComplete", "AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"] and len(report.get("source_pin_screenshots", [])) == 1 and report["source_pin_screenshots"][0]["captured"]
            if args.mode == "own-auth-link":
                report["passed"] = report["passed"] and own_link_completed.wait(5) and report.get("media_input_activity") == {"dev_active": True, "screensaver_active": False} and report.get("credential_posts") == [{"path": "/api/accounts/token/", "accepted": True}]
            else:
                report["passed"] = report["passed"] and report.get("credential_posts", []) == []
        report["ready_events_valid"] = all(event.get("ready") is True for event in events if event["kind"] in ["ready", "pin-ready", "rejected-ready", "own-form-ready", "keyboard-ready"])
        report["passed"] = report["passed"] and report["ready_events_valid"]
    finally:
        report["requests"] = hits.copy()
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
