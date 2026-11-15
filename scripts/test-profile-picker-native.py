"""Exercise the private picker with real ECP keys and restore the exact app.

Synthetic UI only: no application startup, registry, provider or credentials.
ROKU_HOST and ROKU_DEV_PASSWORD are supplied through the environment.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(path):
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
                package.write(ROOT / f"components/{name}.{extension}", f"components/{name}.{extension}")
        for image in (ROOT / "images").rglob("*"):
            if image.is_file():
                package.write(image, image.relative_to(ROOT))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True)
    parser.add_argument("--report", default="out/profile-picker-native.json")
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
    archive = ROOT / "out/profile-picker-probe.zip"
    build(archive)
    report = {"restore_sha256": hashlib.sha256(restore.read_bytes()).hexdigest(), "events": [], "keys": [], "passed": False}

    def key(name, kind="keypress"):
        request = urllib.request.Request(f"http://{host}:8060/{kind}/{name}", data=b"", method="POST")
        attempt = {"key": name, "kind": kind}
        report["keys"].append(attempt)
        started = time.monotonic()
        try:
            with urllib.request.urlopen(request, timeout=3) as response:
                attempt["status"] = response.status
        except OSError as error:
            attempt["error"] = type(error).__name__
        attempt["elapsed_ms"] = round((time.monotonic() - started) * 1000)

    process = None
    try:
        process = subprocess.Popen(["python3", "scripts/run-native-probe.py", str(archive), "--prefix", "[picker-probe]", "--marker", '"kind":"complete"', "--timeout", "60"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end="", flush=True)
            report.setdefault("output", []).append(line.rstrip())
            if "[picker-probe] {" not in line:
                continue
            event = json.loads(line.split("[picker-probe] ", 1)[1])
            report["events"].append(event)
            if event["kind"] == "ready":
                screenshot = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", "out/profile-picker-native.jpg"], cwd=ROOT, capture_output=True, timeout=40)
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
                elif event["step"] == 2:
                    key("Right")
                    key("Select")
                elif event["step"] == 3:
                    key("Back")
        code = process.wait(timeout=15)
        events = report["events"]
        report["passed"] = code == 0 and events[-1].get("kind") == "complete" and events[-1].get("passed") is True and report.get("screenshot") is True and len([e for e in events if e["kind"] == "intent"]) == 5 and all(k.get("status") == 200 for k in report["keys"])
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        restored = subprocess.run(["python3", "scripts/run-native-probe.py", str(restore), "--marker", "Running dev", "--prefix", "[picker-restore]", "--timeout", "30"], cwd=ROOT, capture_output=True, text=True, timeout=80)
        report["restored"] = restored.returncode == 0 and primitives.installed_md5(host, password) == digest
        Path(args.report).write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"passed": report["passed"], "restored": report["restored"]}), flush=True)
        if not report["restored"]:
            raise RuntimeError("Exact owner app restore failed")
    if not report["passed"]:
        raise SystemExit("Picker UI qualification failed")


if __name__ == "__main__":
    main()
