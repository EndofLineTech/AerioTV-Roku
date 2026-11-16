"""Create the explicitly approved test connection, then install the normal baseline."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(source, target, config):
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as output:
        for name in original.namelist():
            body = original.read(name)
            if name == "components/AerioScene.brs":
                text = body.decode()
                anchor = '    m.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert text.count(anchor) == 1
                text = text.replace(anchor, anchor + "\n    startBaselineProvision()", 1)
                anchor = "\n    m.task.baseUrl = m.baseUrl\n"
                assert text.count(anchor) == 1
                text = text.replace(anchor, anchor + '''    if textValue(m.baselineProvisionSlot) <> "" and m.baselineProvisionSlot = m.selectedConnectionId
        m.task.expectedUsername = m.baselineProvisionConfig.username
        if m.authMode = "password" then m.task.ownProfileSignIn = true
    end if
''', 1)
                body = (text + "\n" + (ROOT / "tests/native/ProfileBaselineProvisionFixture.brs").read_text()).encode()
            output.writestr(name, body)
        output.writestr("baseline-provision-private.json", json.dumps(config))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--current", required=True, type=Path, help="Exact currently installed baseline ZIP")
    parser.add_argument("--baseline", required=True, type=Path, help="Fixed normal baseline to leave installed")
    parser.add_argument("--confirm-create", action="store_true", required=True)
    parser.add_argument("--report", type=Path, default=Path("out/profiles-baseline-provision-native.json"))
    args = parser.parse_args()
    if args.credentials.resolve().is_relative_to(ROOT):
        raise RuntimeError("Private credentials must remain outside the checkout")
    credentials = json.loads(args.credentials.read_text())
    config = {"baseUrl": credentials["baseUrl"].rstrip("/"), **credentials["accounts"][0]}
    spec = importlib.util.spec_from_file_location("device", ROOT / "scripts/test-profile-primitives-native.py")
    device = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(device)
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    if device.installed_md5(host, password) != hashlib.md5(args.current.read_bytes()).hexdigest():
        raise RuntimeError("Current baseline checksum differs; refusing setup")
    report = {"passed": False, "normal_baseline_installed": False}

    def run(path, marker, timeout):
        return subprocess.run(["python3", "scripts/run-native-probe.py", str(path), "--prefix", "[baseline-setup]", "--marker", marker, "--timeout", str(timeout)], cwd=ROOT, capture_output=True, text=True, timeout=timeout + 60)

    with tempfile.TemporaryDirectory(prefix="aeriotv-baseline-setup-", dir=args.credentials.resolve().parent) as folder:
        archive = Path(folder) / "provision-private.zip"
        build(args.baseline, archive, config)
        try:
            result = run(archive, '"kind":"result"', 180)
            print(result.stdout, end="", flush=True)
            report["output"] = result.stdout.splitlines()
            verdicts = [json.loads(line.split("[baseline-setup] ", 1)[1]) for line in report["output"] if '"kind":"result"' in line]
            report["passed"] = result.returncode == 0 and len(verdicts) == 1 and verdicts[0]["passed"]
        finally:
            restored = run(args.baseline, "Running dev", 45)
            report["normal_baseline_installed"] = restored.returncode == 0 and device.installed_md5(host, password) == hashlib.md5(args.baseline.read_bytes()).hexdigest()
            if not report["normal_baseline_installed"]:
                fallback = run(args.current, "Running dev", 45)
                report["previous_baseline_restored"] = fallback.returncode == 0 and device.installed_md5(host, password) == hashlib.md5(args.current.read_bytes()).hexdigest()
            args.report.write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps({key: report[key] for key in ["passed", "normal_baseline_installed"]}), flush=True)
    if not report["passed"] or not report["normal_baseline_installed"]:
        raise SystemExit("Test connection setup or normal baseline installation needs attention")


if __name__ == "__main__":
    main()
