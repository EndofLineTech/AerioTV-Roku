"""Real own-account profiles Sync on the explicitly provisioned test Roku.

Only existing production controllers/Tasks perform writes. The host reads each
approved account before/after, privately backs up existing canonical values,
and never creates users or changes server administration/networking.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def build(source, target, config):
    if set(config) != {"baseUrl", "first", "second", "mode"} or config["mode"] not in {"write", "off"}:
        raise ValueError("Qualification package accepts identity hints, not credentials")
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as output:
        for name in original.namelist():
            body = original.read(name)
            if name == "components/AerioScene.brs":
                text = body.decode()
                anchor = '    m.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert text.count(anchor) == 1
                text = text.replace(anchor, anchor + "\n    startRealProfileSyncProof()", 1)
                body = (text + "\n" + (ROOT / "tests/native/RealProfileSyncFixture.brs").read_text()).encode()
            elif name == "components/ProfileSyncSessionNavigation.brs":
                anchor = b"    m.profileSyncSchedule = dispatcharrSyncScheduleComplete(m.profileSyncSchedule, context.ticket, saved.ok = true,"
                assert body.count(anchor) == 1
                body = body.replace(anchor, b"    recordRealProfileSyncReceipt(result, saved)\n" + anchor, 1)
            elif name == "components/ProfilePickerNavigation.brs":
                anchor = b"    if not userProfileStartupSelectionCurrent(m.registry, context, nonce, m.activeUserScope, textValue(m.apiKey), memory, false) then return"
                assert body.count(anchor) == 1
                body = body.replace(anchor, b"    traceRealSyncStartup(context)\n" + anchor, 1)
            output.writestr(name, body)
        output.writestr("real-sync-config.json", json.dumps(config))


def typed_equal(a, b):
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(typed_equal(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(typed_equal(x, y) for x, y in zip(a, b))
    return a == b


def credential_free(raw, accounts):
    secrets = [value for account in accounts for value in [account["user"]["api_key"], account["password"]] if value]
    return raw is not None and all(secret.encode() not in raw for secret in secrets)


def read_canonical(base, user):
    key = urllib.parse.quote(user["username"].strip().lower() + ".aeriotv", safe="")
    url = base + "/api/accounts/users/me/app-data/" + key + "/"
    request = urllib.request.Request(url, headers={"X-API-Key": user["api_key"]})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read(131073)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            value = json.load(error)
            if value.get("code") == "key_not_found":
                return None, None
        raise
    if len(raw) > 131072:
        raise RuntimeError("Existing canonical exceeds the supported preservation budget")
    return raw, json.loads(raw)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--restore", type=Path, required=True)
    parser.add_argument("--source", type=Path, help="Candidate baseline to qualify; the exact restore ZIP remains independently checked")
    parser.add_argument("--report", type=Path, default=Path("out/mrr-real-profiles-sync-native.json"))
    parser.add_argument("--confirm-test-sync-writes", action="store_true", required=True)
    args = parser.parse_args()
    if args.credentials.resolve().is_relative_to(ROOT):
        raise RuntimeError("Credentials must remain outside the checkout")
    device = module("real_sync_device", "test-profile-primitives-native.py")
    baseline = module("real_sync_accounts", "test-profile-picker-launch-native.py")
    base, accounts = baseline.real_baseline_accounts(json.loads(args.credentials.read_text()))
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    digest = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if device.installed_md5(host, password) != digest:
        raise RuntimeError("Exact installed restore ZIP differs")
    backup = Path(tempfile.mkdtemp(prefix="aeriotv-sync-before-", dir=args.credentials.resolve().parent))
    before = []
    for index, account in enumerate(accounts):
        raw, value = read_canonical(base, account["user"])
        before.append(value)
        file = backup / f"account-{index + 1}.json"
        file.write_bytes(raw if raw is not None else b"null")
        file.chmod(0o600)
    report = {"passed": False, "restored": False, "private_backup_directory": str(backup), "accounts": []}
    with tempfile.TemporaryDirectory(prefix="aeriotv-real-sync-", dir=args.credentials.resolve().parent) as folder:
        archive = Path(folder) / "qualified-private.zip"
        config = {"baseUrl": base, "first": accounts[0]["user"]["username"], "second": accounts[1]["user"]["username"], "mode": "write"}
        source = args.source or args.restore
        build(source, archive, config)
        try:
            result = subprocess.run([sys.executable, "scripts/run-native-probe.py", str(archive), "--prefix", "[real-sync]", "--marker", '"kind":"result"', "--timeout", "180"], cwd=ROOT, capture_output=True, text=True, timeout=240)
            print(result.stdout, end="", flush=True)
            report["output"] = result.stdout.splitlines()
            verdicts = [json.loads(line.split("[real-sync] ", 1)[1]) for line in report["output"] if '"kind":"result"' in line]
            report["native_passed"] = result.returncode == 0 and len(verdicts) == 1 and verdicts[0]["passed"]
            expected = {a["user"]["username"].lower() for a in accounts}
            for index, account in enumerate(accounts):
                raw, after = read_canonical(base, account["user"])
                valid = isinstance(after, dict)
                rows = after.get("categories", {}).get("profiles", {}).get("data", {}).get("rows", []) if valid else []
                names = {r[1].lower() for r in rows if isinstance(r, list) and len(r) >= 2 and isinstance(r[1], str)}
                preserved = True
                if before[index] is not None:
                    old = {k: v for k, v in before[index].get("categories", {}).items() if k != "profiles"}
                    new = {k: v for k, v in after.get("categories", {}).items() if k != "profiles"} if valid else {}
                    preserved = typed_equal(old, new)
                clean = credential_free(raw, accounts)
                report["accounts"].append({"own_canonical_readback": valid, "profiles_present": expected.issubset(names), "unsupported_categories_preserved": preserved, "credential_free": clean})
            report["passed"] = report["native_passed"] and all(all(a.values()) for a in report["accounts"])
        finally:
            if not report.get("native_passed"):
                cleanup = Path(folder) / "sync-off-private.zip"
                build(source, cleanup, {**config, "mode": "off"})
                stopped = subprocess.run([sys.executable, "scripts/run-native-probe.py", str(cleanup), "--prefix", "[real-sync]", "--marker", '"kind":"result"', "--timeout", "75"], cwd=ROOT, capture_output=True, text=True, timeout=135)
                report["off_cleanup_output"] = stopped.stdout.splitlines()
            restored = subprocess.run([sys.executable, "scripts/run-native-probe.py", str(args.restore), "--prefix", "[restore]", "--marker", "Running dev", "--timeout", "40"], cwd=ROOT, capture_output=True, text=True, timeout=100)
            report["restored"] = restored.returncode == 0 and device.installed_md5(host, password) == digest
            args.report.write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps({k: report[k] for k in ["passed", "restored"]}), flush=True)
    if not report["passed"] or not report["restored"]:
        raise SystemExit("Real profiles Sync requires attention")


if __name__ == "__main__":
    main()
