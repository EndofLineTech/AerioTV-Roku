"""Run baseline Add/storage policies without a host HTTP callback or owner data."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True, type=Path)
    parser.add_argument("--report", default="out/profiles-baseline-policy-native.json", type=Path)
    args = parser.parse_args()
    device = module("device", "test-profile-primitives-native.py")
    builder = module("builder", "build-profile-probe.py")
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    digest = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if device.installed_md5(host, password) != digest:
        raise RuntimeError("Exact restore ZIP differs from installed app")
    original = builder.build(ROOT / "out/profiles-baseline-policy-source.zip", "http://unused.invalid", model_store=True)
    archive = ROOT / "out/profiles-baseline-policy-probe.zip"
    with zipfile.ZipFile(original) as source, zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
        for name in source.namelist():
            body = source.read(name)
            if name == "source/Main.brs":
                text = body.decode()
                end = text.lower().index("end sub") + len("end sub")
                text = '''sub Main()
    m.profileFailures = 0
    runUserProfileOwnSignInChecks()
    runDispatcharrSyncSwitchRosterStoreChecks()
    print "[profile-probe] "; FormatJson({kind: "baseline-policy-result", passed: m.profileFailures = 0, failures: m.profileFailures})
end sub
''' + text[end:]
                body = text.encode()
            output.writestr(name, body)
    report = {"passed": False, "restored": False}
    def run(path, marker):
        return subprocess.run(["python3", "scripts/run-native-probe.py", str(path), "--prefix", "[profile-probe]", "--marker", marker, "--timeout", "60"], cwd=ROOT, capture_output=True, text=True, timeout=120)
    try:
        result = run(archive, '"kind":"baseline-policy-result"')
        print(result.stdout, end="", flush=True)
        report["output"] = result.stdout.splitlines()
        verdicts = [json.loads(line.split("[profile-probe] ", 1)[1]) for line in report["output"] if '"kind":"baseline-policy-result"' in line]
        report["passed"] = result.returncode == 0 and len(verdicts) == 1 and verdicts[0]["passed"]
    finally:
        restored = run(args.restore, "Running dev")
        report["restored"] = restored.returncode == 0 and device.installed_md5(host, password) == digest
        args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report[key] for key in ["passed", "restored"]}), flush=True)
    if not report["passed"] or not report["restored"]:
        raise SystemExit("Baseline native policy check or restore failed")


if __name__ == "__main__":
    main()
