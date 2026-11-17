"""Isolate native voice availability without app state, listeners or setting changes."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output, voice_controls=False):
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        manifest = "title=Aerio Voice Keyboard Diagnostic\nmajor_version=0\nminor_version=0\nbuild_version=1\nui_resolutions=fhd\nrsg_version=1.3\n"
        if voice_controls:
            manifest += "supports_voice_roinput=1\n"
        archive.writestr("manifest", manifest)
        archive.writestr("source/Main.brs", '''sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("VoiceKeyboardDiagnostic")
    screen.show()
    scene.start = true
    while true
        event = wait(0, port)
        if type(event) = "roSGScreenEvent"
            if event.isScreenClosed() then return
        end if
    end while
end sub
''')
        for extension in ["xml", "brs"]:
            archive.write(ROOT / f"tests/native/VoiceKeyboardDiagnostic.{extension}", f"components/VoiceKeyboardDiagnostic.{extension}")
        archive.writestr("profile-pin-probe.json", '{"kind":"isolated-voice-keyboard-diagnostic","shipping":false}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True, type=Path)
    parser.add_argument("--report", type=Path, default=Path("out/mrr19-minimal-voice-native.json"))
    parser.add_argument("--voice-controls", action="store_true", help="Compare the documented voice-control manifest attribute without changing device settings")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("voice_device", ROOT / "scripts/test-profile-primitives-native.py")
    device = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(device)
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    expected = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if device.installed_md5(host, password) != expected:
        raise RuntimeError("Restore ZIP differs from installed app; refusing replacement")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    report = {"diagnostic_completed": False, "settings_changed": False, "voice_controls_manifest": args.voice_controls, "events": []}

    def run(archive, prefix, marker):
        return subprocess.run([sys.executable, "scripts/run-native-probe.py", str(archive), "--prefix", prefix, "--marker", marker, "--timeout", "40"], cwd=ROOT, capture_output=True, text=True, timeout=100)

    with tempfile.TemporaryDirectory(prefix="voice-keyboard-", dir=ROOT / "out") as folder:
        archive = Path(folder) / "diagnostic.zip"
        build(archive, voice_controls=args.voice_controls)
        try:
            result = run(archive, "[voice-diagnostic]", '"kind":"complete"')
            print(result.stdout, end="", flush=True)
            rows = [json.loads(line.split("[voice-diagnostic] ", 1)[1]) for line in result.stdout.splitlines() if "[voice-diagnostic] {" in line]
            report["events"] = rows
            report["diagnostic_completed"] = result.returncode == 0 and len(rows) == 14 and rows[0].get("kind") == "capabilities" and rows[-1].get("kind") == "complete" and all(len([r for r in rows if r.get("mode") == mode]) == 3 for mode in ["generic", "password", "numeric", "dynamic"])
        finally:
            restored = run(args.restore, "[restore]", "Running dev")
            report["restored"] = restored.returncode == 0 and device.installed_md5(host, password) == expected
            args.report.write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps({key: report.get(key) for key in ["diagnostic_completed", "restored", "settings_changed"]}), flush=True)
    if not report["diagnostic_completed"] or not report["restored"]:
        raise SystemExit("Native voice diagnostic did not complete safely")


if __name__ == "__main__":
    main()
