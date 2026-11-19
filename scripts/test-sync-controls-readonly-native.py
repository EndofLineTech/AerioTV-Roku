"""Drive native Sync controls against only approved accounts, with no provider writes."""
import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PREFIX = "[sync-controls-readonly]"
PRIVATE_MARKER = "sync-controls-private.json"


def private_output(path):
    # Credentials must never be written through a symlink, into a checkout or
    # over an existing file. Restrict permissions from the first byte.
    if path.parent.resolve().is_relative_to(ROOT):
        raise RuntimeError("Private qualification archive must stay outside this checkout")
    return os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb")


def helper(filename):
    spec = importlib.util.spec_from_file_location(filename, ROOT / "scripts" / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def insert(data, anchor, replacement):
    if data.count(anchor) != 1:
        raise RuntimeError("Native qualification hook did not match exactly")
    return data.replace(anchor, replacement, 1)


def build(candidate, archive, section, config):
    registry = b'CreateObject("roRegistrySection", "AerioTV")'
    isolated = f'CreateObject("roRegistrySection", "{section}")'.encode()
    with zipfile.ZipFile(candidate) as source, private_output(archive) as output, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
        required = {"components/AerioScene.brs", "components/DispatcharrSyncWriteTask.brs",
                    "components/ProfileSyncSessionNavigation.brs", "source/HttpTransport.brs",
                    "source/MetadataCacheStore.brs"}
        if any(source.namelist().count(name) != 1 for name in required) or any(
                name.rsplit("/", 1)[-1].lower() == PRIVATE_MARKER for name in source.namelist()):
            raise RuntimeError("Candidate lacks required unique isolation/transport modules")
        for name in source.namelist():
            body = source.read(name)
            if name == "components/AerioScene.brs":
                body = insert(body, registry, isolated + b"\n    seedSyncControlsReadOnly()")
                body += b"\n" + (ROOT / "tests/native/DispatcharrSyncControlsReadOnlyFixture.brs").read_bytes()
            elif name == "components/DispatcharrSyncWriteTask.brs":
                body = insert(body, registry, isolated)
            elif name == "components/ProfileSyncSessionNavigation.brs":
                anchor = b"    m.profileSyncSchedule = dispatcharrSyncScheduleComplete(m.profileSyncSchedule, context.ticket, saved.ok = true,"
                body = insert(body, anchor, b"    recordSyncControlsReadOnly(result, saved, context)\n" + anchor)
            elif name == "source/HttpTransport.brs":
                anchor = b"    method = ucase(method)"
                body = insert(body, anchor, anchor + b'''
    if method <> "GET" and method <> "HEAD"
        print "[sync-controls-readonly] "; "{""phase"":""blocked-mutation"",""valid"":false}"
        result.error = "qualification-read-only"
        return result
    end if''')
            elif name == "source/MetadataCacheStore.brs":
                body = insert(body, b"cachefs:/aeriotv-metadata-v1", b"tmp:/sync-controls-native")
            target.writestr(name, body)
        target.writestr(PRIVATE_MARKER, json.dumps(config))


def native_command(archive, prefix, marker, timeout):
    return [sys.executable, "scripts/run-native-probe.py", str(archive),
            "--prefix", prefix, "--marker", marker, "--timeout", str(timeout)]


def drive(archive, host, report):
    order = ["manager", "off", "held", "profiles-off", "back", "release", "pending", "result"]
    keys = {"off": ["Select"], "held": ["Down", "Select"], "profiles-off": ["Down", "Select"],
            "back": ["Back"], "pending": ["Select"]}
    with subprocess.Popen(native_command(archive, PREFIX, '"phase":"result"', 90), cwd=ROOT,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
        try:
            for line in process.stdout:
                if not line.startswith(PREFIX + " "):
                    # Never persist arbitrary native console lines alongside a
                    # fixture that seeds credentials.
                    continue
                row = json.loads(line[len(PREFIX) + 1:])
                if row["phase"] == "diagnostic":
                    report.setdefault("runtime", []).append(row)
                    continue
                position = len(report["steps"])
                report["steps"].append(row)
                if position >= len(order) or row["phase"] != order[position] or not row["valid"]:
                    return False
                route = keys.get(row["phase"], [])
                for key in route:
                    request = urllib.request.Request(f"http://{host}:8060/keypress/{key}", data=b"", method="POST")
                    try:
                        with urllib.request.urlopen(request, timeout=4) as response:
                            report["key_statuses"].append(response.status)
                    except OSError as error:
                        report["remote_error"] = {"key": key, "type": type(error).__name__}
                        return False
        finally:
            # The runner already bounds install/console time on the happy
            # path. Stop early on refusal before handing device to cleanup.
            if len(report["steps"]) != len(order) or not report["steps"][-1]["valid"]:
                process.terminate()
        return process.wait(timeout=8) == 0 and len(report["steps"]) == len(order)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    if args.credentials.resolve().is_relative_to(ROOT) or args.credentials.stat().st_mode & 0o077:
        raise RuntimeError("Test credentials require a private file outside this checkout")
    digest = hashlib.sha256(args.restore.read_bytes()).hexdigest()
    with zipfile.ZipFile(args.restore) as restore:
        manifest = restore.read("manifest").decode().splitlines()
    expected = args.restore.with_suffix(".zip.sha256").read_text().split()
    if not {"major_version=0", "minor_version=3", "build_version=102"}.issubset(manifest) or expected != [digest, args.restore.name]:
        raise RuntimeError("Released v0.3.102 restore ZIP failed manifest/checksum preflight")
    device = helper("test-profile-primitives-native.py")
    restore_md5 = hashlib.md5(args.restore.read_bytes()).hexdigest()
    report = {"restore_sha256": digest, "steps": [], "key_statuses": [], "passed": False, "cleaned": False, "restored": False}
    with tempfile.TemporaryDirectory(prefix="aerio-sync-ro-", dir=args.credentials.resolve().parent) as folder:
        lock_path = args.credentials.resolve().parent / f"aeriotv-roku-{host}.lock"
        with lock_path.open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if device.installed_md5(host, password) != restore_md5:
                raise RuntimeError("Installed developer ZIP differs; refusing replacement")
            config = json.loads(args.credentials.read_text())
            if len(config["accounts"]) != 2:
                raise RuntimeError("Exactly two approved test accounts are required")
            base, accounts = helper("test-profile-picker-launch-native.py").real_baseline_accounts(config)
            facts = [{k: a["user"][k] for k in ("id", "username", "user_level", "is_staff", "is_superuser") if k in a["user"]} for a in accounts]
            section = "AerioSyncReadOnly-" + str(uuid.uuid4())
            archive, cleaner = (Path(folder) / name for name in ("ui.zip", "cleanup.zip"))
            build(args.candidate, archive, section, {"baseUrl": base, "primary": facts[0], "sibling": facts[1], "key": accounts[0]["user"]["api_key"]})
            helper("test-profile-recovery-native.py").cleanup_package(cleaner, section)
            try:
                report["passed"] = drive(archive, host, report)
            finally:
                try:
                    result = subprocess.run(native_command(cleaner, "[profile-recovery]", "cleanup=", 30), cwd=ROOT, capture_output=True, text=True, timeout=80)
                    report["cleaned"] = result.returncode == 0 and "cleanup=true" in result.stdout
                finally:
                    result = subprocess.run(native_command(args.restore, "[restore]", "Running dev", 45), cwd=ROOT, capture_output=True, text=True, timeout=100)
                    report["restored"] = result.returncode == 0 and device.installed_md5(host, password) == restore_md5
                    args.report.write_text(json.dumps(report, indent=2) + "\n")
                    print(json.dumps({k: report[k] for k in ("passed", "cleaned", "restored")}), flush=True)
    if not all(report[k] for k in ("passed", "cleaned", "restored")):
        raise SystemExit("Native read-only Sync controls require attention")


if __name__ == "__main__":
    main()
