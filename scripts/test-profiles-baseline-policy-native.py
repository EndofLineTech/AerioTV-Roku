"""Run baseline Add/storage policies without a host HTTP callback or owner data."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def build_policy_probe(original, archive, diagnostic=False, logo_checks=False):
    with zipfile.ZipFile(original) as source, zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
        for name in source.namelist():
            body = source.read(name)
            if name == "source/Main.brs":
                text = body.decode()
                end = text.lower().index("end sub") + len("end sub")
                preflight = ""
                if diagnostic:
                    preflight = '''    bindings = {strict_json: type(strictJsonEncode), own_sign_in: type(runUserProfileOwnSignInChecks), roster_store: type(runDispatcharrSyncSwitchRosterStoreChecks), phone_profiles: type(runPhoneSetupProfilesChecks), sync_mapping: type(runDispatcharrSyncMappingChecks)}
    bindingsOk = true
    for each name in bindings
        if bindings[name] <> "Function" and bindings[name] <> "roFunction" then bindingsOk = false
    end for
    print "[profile-probe] "; FormatJson({kind: "symbol-bindings", bindings: bindings, passed: bindingsOk})
    if not bindingsOk
        print "[profile-probe] "; FormatJson({kind: "baseline-policy-result", passed: false, reason: "symbol-binding"})
        return
    end if
'''
                text = '''sub Main()
    m.profileFailures = 0
''' + preflight + '''    runUserProfileOwnSignInChecks()
    runDispatcharrSyncSwitchRosterStoreChecks()
    runPhoneSetupProfilesChecks()
    runDispatcharrSyncMappingChecks()
''' + ("    runLogoCacheChecks()\n" if logo_checks else "") + '''
    print "[profile-probe] "; FormatJson({kind: "baseline-policy-result", passed: m.profileFailures = 0, failures: m.profileFailures})
end sub
''' + text[end:]
                body = text.encode()
            elif diagnostic and name == "source/PhoneSetupProfileImport.brs":
                text = body.decode()
                start = text.index("function phoneSetupProfileBatchPlan(")
                end = text.index("end function", start)
                lines = text[start:end].splitlines(keepends=True)
                for index, line in enumerate(lines, 1):
                    lines[index - 1] = line.replace("return denied", f'return phoneSetupProbeBatchRefusal("batch-line-{index}", denied)')
                text = text[:start] + "".join(lines) + text[end:]
                text += '''
function phoneSetupProbeBatchRefusal(stage as string, result as object) as object
    print "[profile-probe] "; FormatJson({kind: "batch-refusal", stage: stage})
    return result
end function
'''
                body = text.encode()
            output.writestr(name, body)
        if logo_checks:
            output.write(ROOT / "components/GuideLogos.brs", "source/GuideLogosProbe.brs")
            logo_task = (ROOT / "components/LogoCacheTask.brs").read_text().replace("sub init()", "sub logoCacheProbeInit()", 1)
            output.writestr("source/LogoCacheTaskProbe.brs", logo_task)
            checks = (ROOT / "tests/LogoCache.test.brs").read_text().split("sub assertEqual(", 1)[0]
            checks = checks.replace("sub main()", "sub runLogoCacheChecks()", 1).replace("assertEqual(", "profileLogoAssert(")
            checks += '''
sub profileLogoAssert(actual as dynamic, expected as dynamic, label as string)
    profileAssert(actual = expected, label)
end sub
'''
            output.writestr("source/LogoCacheProbeChecks.brs", checks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True, type=Path)
    parser.add_argument("--report", default="out/profiles-baseline-policy-native.json", type=Path)
    parser.add_argument("--diagnostic-symbols", action="store_true", help="Log function binding types before calls; no HTTP/provider or production changes")
    parser.add_argument("--logo-checks", action="store_true", help="Also run production logo helpers/status callbacks with pure native fixtures, no HTTP")
    args = parser.parse_args()
    device = module("device", "test-profile-primitives-native.py")
    builder = module("builder", "build-profile-probe.py")
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    digest = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if device.installed_md5(host, password) != digest:
        raise RuntimeError("Exact restore ZIP differs from installed app")
    run_id = uuid.uuid4().hex[:12]
    original = builder.build(ROOT / f"out/profiles-baseline-policy-{run_id}-source.zip", "http://unused.invalid", model_store=True)
    archive = ROOT / f"out/profiles-baseline-policy-{run_id}-probe.zip"
    build_policy_probe(original, archive, diagnostic=args.diagnostic_symbols, logo_checks=args.logo_checks)
    report = {"passed": False, "restored": False, "archive": str(archive),
              "probe_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
              "restore_sha256": hashlib.sha256(args.restore.read_bytes()).hexdigest(),
              "diagnostic_symbols": args.diagnostic_symbols, "logo_checks": args.logo_checks, "provider_requests": False}
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
