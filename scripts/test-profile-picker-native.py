"""Exercise the private picker with real ECP keys and restore the exact app.

Synthetic UI only: no application startup, registry, provider or credentials.
ROKU_HOST and ROKU_DEV_PASSWORD are supplied through the environment.
"""
import argparse
import hashlib
import http.client
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
import uuid
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def picker_passed(code, events, keys, capture=True, screenshot=False):
    expected_keys = [
        ("keypress", "Select"), ("keypress", "Select"), ("keypress", "Left"),
        ("keydown", "Select"), ("keyup", "Select"), ("keypress", "Right"),
        ("keypress", "Select"), ("keypress", "Back"),
    ]
    return (code == 0 and bool(events) and events[-1].get("kind") == "complete"
            and events[-1].get("passed") is True
            and (not capture or screenshot is True)
            and len([event for event in events if event["kind"] == "intent"]) == 6
            and [(key.get("kind"), key.get("key")) for key in keys] == expected_keys
            and all(key.get("status") == 200 for key in keys))


def verify_saved_picker_probe(path, expected_digest):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected_digest:
        raise ValueError("Saved picker probe SHA-256 differs; refusing replacement")
    with zipfile.ZipFile(path) as package:
        if (package.read("source/Main.brs") != (ROOT / "tests/native/ProfilePickerProbe.brs").read_bytes()
                or b"title=Aerio Profile Picker Probe\n" not in package.read("manifest")):
            raise ValueError("Saved ZIP is not the approved private picker probe")
    return digest


def send_picker_key(host, name, kind="keypress", transport="urllib"):
    attempt = {"key": name, "kind": kind, "transport": transport}
    started = time.monotonic()
    url = f"http://{host}:8060/{kind}/{name}"
    if transport == "curl":
        result = subprocess.run(["curl", "--silent", "--max-time", "3", "--request", "POST",
                                 "--data", "", "--output", os.devnull, "--write-out", "%{http_code}", url],
                                capture_output=True, text=True, timeout=6)
        attempt["curl_exit"] = result.returncode
        if result.returncode == 0 and result.stdout.strip().isdigit():
            attempt["status"] = int(result.stdout.strip())
    else:
        request = urllib.request.Request(url, data=b"", method="POST")
        opener = urllib.request.urlopen
        if transport == "urllib-trace":
            class TracedConnection(http.client.HTTPConnection):
                def connect(self):
                    attempt["phase"] = "connecting"
                    super().connect()
                    attempt["connected_ms"] = round((time.monotonic() - started) * 1000)
                    attempt["phase"] = "connected"

                def send(self, data):
                    super().send(data)
                    attempt["sent_ms"] = round((time.monotonic() - started) * 1000)
                    attempt["phase"] = "request-sent"

                def getresponse(self):
                    attempt["phase"] = "waiting-response-headers"
                    response = super().getresponse()
                    attempt["phase"] = "response-headers-received"
                    return response

            class TracedHandler(urllib.request.HTTPHandler):
                def http_open(self, request):
                    return self.do_open(TracedConnection, request)

            opener = urllib.request.build_opener(TracedHandler()).open
        try:
            with opener(request, timeout=3) as response:
                attempt["status"] = response.status
        except OSError as error:
            attempt["error"] = type(error).__name__
    attempt["elapsed_ms"] = round((time.monotonic() - started) * 1000)
    return attempt


def build(path, diagnostic_keys=False):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("manifest", "title=Aerio Profile Picker Probe\nmajor_version=0\nminor_version=0\nbuild_version=1\nui_resolutions=fhd\n")
        package.write(ROOT / "tests/native/ProfilePickerProbe.brs", "source/Main.brs")
        package.write(ROOT / "tests/native/ProfilePickerProbe.xml", "components/ProfilePickerProbe.xml")
        package.write(ROOT / "tests/native/ProfilePickerProbeScene.brs", "components/ProfilePickerProbeScene.brs")
        for name in ["UserProfileAvatar", "SceneUi"]:
            package.write(ROOT / f"source/{name}.brs", f"source/{name}.brs")
        package.write(ROOT / "source/UserProfilePickerInput.brs", "source/UserProfilePickerInput.brs")
        for name in ["UserProfilePicker", "AerioSurface"]:
            for extension in ["brs", "xml"]:
                file = ROOT / f"components/{name}.{extension}"
                if diagnostic_keys and name == "UserProfilePicker" and extension == "brs":
                    text = file.read_text()
                    anchor = "function onKeyEvent(key as string, press as boolean) as boolean\n"
                    assert text.count(anchor) == 1
                    text = text.replace(anchor, anchor + '''    if key = "OK" or key = "back" or key = "left" or key = "right" or key = "up" or key = "down"
        print "[picker-probe] "; FormatJson({kind: "raw-key", key: key, press: press, focus_chain: m.top.isInFocusChain(), busy: m.top.busy})
    end if
''', 1)
                    package.writestr(f"components/{name}.{extension}", text)
                else:
                    package.write(file, f"components/{name}.{extension}")
        for image in (ROOT / "images").rglob("*"):
            if image.is_file():
                package.write(image, image.relative_to(ROOT))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True)
    parser.add_argument("--report", default="out/profile-picker-native.json")
    parser.add_argument("--capture", choices=["screenshot", "none"], default="screenshot",
                        help="Controlled diagnostic comparison; six real intent callbacks and all ECP acknowledgements remain mandatory")
    parser.add_argument("--key-transport", choices=["urllib", "urllib-trace", "curl"], default="urllib")
    parser.add_argument("--diagnostic-keys", action="store_true", help="Private enum-only picker key telemetry, never shipping code")
    parser.add_argument("--reuse-probe", type=Path, help="Controlled comparison using exactly the same saved private ZIP")
    parser.add_argument("--expected-probe-sha256", help="Required digest when reusing a saved probe")
    args = parser.parse_args()
    host = os.environ["ROKU_HOST"]
    password = os.environ["ROKU_DEV_PASSWORD"]
    spec = importlib.util.spec_from_file_location("primitive_runner", ROOT / "scripts/test-profile-primitives-native.py")
    primitives = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(primitives)
    restore = Path(args.restore)
    digest = hashlib.md5(restore.read_bytes()).hexdigest()
    if primitives.installed_md5(host, password) != digest:
        raise RuntimeError("Exact restore ZIP does not match installed app; refusing replacement")
    if args.reuse_probe:
        if not args.expected_probe_sha256:
            parser.error("--reuse-probe requires --expected-probe-sha256")
        archive = args.reuse_probe.resolve()
        verify_saved_picker_probe(archive, args.expected_probe_sha256)
    else:
        archive = ROOT / f"out/profile-picker-{uuid.uuid4().hex[:12]}-probe.zip"
        build(archive, diagnostic_keys=args.diagnostic_keys)
    report = {"restore_sha256": hashlib.sha256(restore.read_bytes()).hexdigest(), "events": [], "keys": [], "passed": False,
              "capture_policy": args.capture, "key_transport": args.key_transport, "diagnostic_keys": args.diagnostic_keys,
              "reuse_probe": bool(args.reuse_probe), "archive": str(archive), "probe_sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}

    def key(name, kind="keypress"):
        report["keys"].append(send_picker_key(host, name, kind, args.key_transport))

    process = None
    try:
        process = subprocess.Popen([sys.executable, "scripts/run-native-probe.py", str(archive), "--prefix", "[picker-probe]", "--marker", '"kind":"complete"', "--timeout", "60"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end="", flush=True)
            report.setdefault("output", []).append(line.rstrip())
            if "[picker-probe] {" not in line:
                continue
            event = json.loads(line.split("[picker-probe] ", 1)[1])
            report["events"].append(event)
            if event["kind"] == "ready":
                if args.capture == "screenshot":
                    screenshot = subprocess.run([sys.executable, "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", str(archive.with_suffix(".jpg"))], cwd=ROOT, capture_output=True, timeout=40)
                    report["screenshot"] = screenshot.returncode == 0
                key("Select")
            elif event["kind"] == "intent":
                if event["step"] == 0:
                    key("Select")
                elif event["step"] == 1:
                    key("Left")
                    key("Select", "keydown")
                    time.sleep(0.9)
                    key("Select", "keyup")
                elif event["step"] == 3:
                    key("Right")
                    key("Select")
                elif event["step"] == 4:
                    key("Back")
        code = process.wait(timeout=15)
        events = report["events"]
        report["installed_probe_verified"] = primitives.installed_md5(host, password) == hashlib.md5(archive.read_bytes()).hexdigest()
        report["passed"] = report["installed_probe_verified"] and picker_passed(code, events, report["keys"], capture=args.capture == "screenshot", screenshot=report.get("screenshot", False))
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        restored = subprocess.run([sys.executable, "scripts/run-native-probe.py", str(restore), "--marker", "Running dev", "--prefix", "[picker-restore]", "--timeout", "30"], cwd=ROOT, capture_output=True, text=True, timeout=80)
        report["restored"] = restored.returncode == 0 and primitives.installed_md5(host, password) == digest
        Path(args.report).write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"passed": report["passed"], "restored": report["restored"]}), flush=True)
        if not report["restored"]:
            raise RuntimeError("Exact owner app restore failed")
    if not report["passed"]:
        raise SystemExit("Picker UI qualification failed")


if __name__ == "__main__":
    main()
