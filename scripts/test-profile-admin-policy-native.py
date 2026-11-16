"""Native synthetic admin policy/task checks; no HTTP, credentials or registry."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True, type=Path)
    parser.add_argument("--report", default="out/profile-admin-policy-native.json", type=Path)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("device", ROOT / "scripts/test-profile-primitives-native.py")
    device = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(device)
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    digest = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if device.installed_md5(host, password) != digest:
        raise RuntimeError("Exact restore ZIP differs from installed app")
    archive = ROOT / "out/profile-admin-policy-probe.zip"
    checks = ""
    for suite in ["UserProfileServerAdmin", "ProfileServerAdminTask"]:
        text = (ROOT / f"tests/{suite}.test.brs").read_text().split("sub check(", 1)[0]
        text = text.replace("sub main()", f"sub run{suite}Checks()").replace("check(", "profileAdminAssert(")
        text = text.replace("httpTransferOnce", "profileAdminFixtureTransfer")
        text = text.replace('m.profileAdminJsonParser = function(text as string) as dynamic\n        return ParseJson(text)\n    end function', 'm.profileAdminJsonParser = invalid')
        checks += text + "\n"
    task = (ROOT / "components/ProfileServerAdminTask.brs").read_text()
    task = task[task.index("sub runProfileServerAdmin()"):]
    task = task.replace("httpTransferOnce", "profileAdminFixtureTransfer")
    main_source = '''sub Main()
    m.adminFailures = 0
    runUserProfileServerAdminChecks()
    runProfileServerAdminTaskChecks()
    print "[admin-probe] "; FormatJson({kind: "result", passed: m.adminFailures = 0, failures: m.adminFailures})
end sub
sub profileAdminAssert(passed as boolean, message as string)
    if not passed then m.adminFailures++ : print "[admin-probe] FAIL: "; message
end sub
'''
    with zipfile.ZipFile(ROOT / "out/aeriotv-roku.zip") as source, zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
        for name in source.namelist():
            if name.startswith("source/") or name == "manifest":
                body = source.read(name)
                if name == "source/Main.brs":
                    body = (main_source + checks + task).encode()
                output.writestr(name, body)
    report = {"passed": False, "restored": False}
    def run(path, marker):
        return subprocess.run(["python3", "scripts/run-native-probe.py", str(path), "--prefix", "[admin-probe]", "--marker", marker, "--timeout", "60"], cwd=ROOT, capture_output=True, text=True, timeout=120)
    try:
        result = run(archive, '"kind":"result"')
        print(result.stdout, end="", flush=True)
        report["output"] = result.stdout.splitlines()
        verdicts = [json.loads(line.split("[admin-probe] ", 1)[1]) for line in report["output"] if '"kind":"result"' in line]
        report["passed"] = result.returncode == 0 and len(verdicts) == 1 and verdicts[0]["passed"]
    finally:
        restored = run(args.restore, "Running dev")
        report["restored"] = restored.returncode == 0 and device.installed_md5(host, password) == digest
        args.report.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report[key] for key in ["passed", "restored"]}), flush=True)
    if not report["passed"] or not report["restored"]:
        raise SystemExit("Admin native policy check or restore failed")


if __name__ == "__main__":
    main()
