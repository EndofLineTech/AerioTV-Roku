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
import tempfile
import time
import urllib.request
import urllib.error
import urllib.parse
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def await_back_ack(report, completed):
    """Join the HTTP-thread command result, not a later snapshot during cleanup."""
    if not report.get("back_attempted") or not completed.wait(5):
        return False
    return report.get("back_status") == 200


def real_baseline_accounts(config):
    """Resolve only the two explicitly supplied logins; never print their keys."""
    base = config["baseUrl"].rstrip("/")
    accounts = []
    def read_json(request):
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code == 429:
                retry = error.headers.get("Retry-After", "the server cooldown")
                raise RuntimeError(f"Dispatcharr rate-limited authentication; retry after {retry}. No automatic retry was sent.") from None
            raise
    for credentials in config["accounts"]:
        request = urllib.request.Request(base + "/api/accounts/token/", data=json.dumps(credentials).encode(), headers={"Content-Type": "application/json"}, method="POST")
        token = read_json(request)["access"]
        request = urllib.request.Request(base + "/api/accounts/users/me/", headers={"Authorization": "Bearer " + token})
        user = read_json(request)
        if user.get("username", "").lower() != credentials["username"].lower():
            raise RuntimeError("Test login did not return its own expected identity")
        if not user.get("api_key"):
            raise RuntimeError("Approved test account lacks API access; enable its own API key in Dispatcharr before testing")
        accounts.append({"user": user, "password": credentials["password"]})
    if len(accounts) != 2 or accounts[0]["user"]["id"] == accounts[1]["user"]["id"]:
        raise RuntimeError("Two distinct approved accounts are required")
    return base, accounts


def real_baseline_fixture(fixture, accounts):
    first, second = (account["user"] for account in accounts)
    for old, user in [(7, first), (8, second)]:
        fixture = fixture.replace(f'id: {old}, username: "Synthetic{old}", user_level: 1', f'id: {int(user["id"])}, username: {json.dumps(user["username"])}, user_level: {int(user["user_level"])}')
        fixture = fixture.replace(f'"Synthetic{old}"', json.dumps(user["username"]))
        fixture = fixture.replace(f'connectionPreferenceIdentity(connection, "{old}")', f'connectionPreferenceIdentity(connection, "{user["id"]}")')
    fixture = fixture.replace('accountId: "7"', f'accountId: "{first["id"]}"')
    fixture = fixture.replace('m.activeUserScope.accountId <> "8"', f'm.activeUserScope.accountId <> "{second["id"]}"')
    fixture = fixture.replace('m.activeUserScope.accountId = "8"', f'm.activeUserScope.accountId = "{second["id"]}"')
    fixture = fixture.replace('profile.userId = 8 then m.pickerProbeAdded', f'profile.userId = {second["id"]} then m.pickerProbeAdded')
    fixture = fixture.replace('if profile.userId = 8\n', f'if profile.userId = {second["id"]}\n')
    fixture = fixture.replace('"synthetic-a"', json.dumps(first["api_key"]))
    fixture = fixture.replace('"synthetic-b"', json.dumps(second["api_key"]))
    return fixture.replace('"synthetic-password"', json.dumps(accounts[1]["password"]))


def build(path, normal, section, base, mode="plain", baseline_accounts=None, admin_ui=False, phone_verify=False, phone_import=False, phone_import_add=False, profile_media=False):
    if sum([admin_ui, phone_verify, phone_import, profile_media]) > 1:
        raise ValueError("Choose one focused native flow")
    if (phone_verify or phone_import or profile_media) and not baseline_accounts:
        raise ValueError("Phone verification needs private authorized test accounts")
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == "manifest":
                body = body.replace(b"title=AerioTV\n", b"title=Aerio Startup Picker Probe\n")
                if mode == "baseline":
                    body += b"\naeriotv_profiles_baseline=1\n"
            elif name == "source/MetadataCacheStore.brs":
                assert body.count(b'"cachefs:/aeriotv-metadata-v1"') == 1
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/picker-launch-cache"')
            elif name == "components/AerioScene.brs":
                source = body.decode()
                if mode.startswith("child-"):
                    assert source.count('    m.profileChildAccessReady = false') == 1
                    source = source.replace('    m.profileChildAccessReady = false', '    m.profileChildAccessReady = true', 1)
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
    if m.top.launchRequest.pickerProbeVisualCaptured = "1"
        m.pickerProbeVisualCaptured = true
        return
    end if
''', 1)
                target = '    if not welcome\n        if deferUserProfileLaunch() then return\n        launchGate = selectedUserProfileGate()'
                assert source.count(target) == 1
                if mode == "back":
                    target = "            cancelStartupProfileTask()\n            closeUserProfileLaunchPicker()\n            m.top.exitRequested = true"
                    assert source.count(target) == 1
                    source = source.replace(target, target.replace("            m.top.exitRequested", "            verifyStartupPickerProbeCancel()\n            m.top.exitRequested"), 1)
                fixture = (ROOT / "tests/native/ProfilePickerLaunchFixture.brs").read_text()
                if admin_ui:
                    fixture = fixture.replace('sub onProfileBaselineProbeTick()\n', 'sub onProfileBaselineProbeTick()\n    onProfileServerAdminUiProbeTick()\n    return\n', 1)
                    fixture += "\n" + (ROOT / "tests/native/ProfileServerAdminUiFixture.brs").read_text()
                if phone_verify:
                    fixture = fixture.replace('sub onProfileBaselineProbeTick()\n', 'sub onProfileBaselineProbeTick()\n    onPhoneProfileVerifyProbeTick()\n    return\n', 1)
                    fixture += "\n" + (ROOT / "tests/native/PhoneSetupProfileVerifyFixture.brs").read_text()
                if phone_import:
                    fixture = fixture.replace('sub onProfileBaselineProbeTick()\n', 'sub onProfileBaselineProbeTick()\n    onPhoneProfileImportProbeTick()\n    return\n', 1)
                    fixture += "\n" + (ROOT / "tests/native/PhoneSetupProfileImportFixture.brs").read_text()
                if profile_media:
                    fixture = fixture.replace('sub onProfileBaselineProbeTick()\n', 'sub onProfileBaselineProbeTick()\n    onProfileMediaAcceptanceTick()\n    return\n', 1)
                    fixture += "\n" + (ROOT / "tests/native/ProfileMediaAcceptanceFixture.brs").read_text()
                if baseline_accounts:
                    fixture = real_baseline_fixture(fixture, baseline_accounts)
                body = (source + "\n" + fixture).encode()
            elif name == "components/ProfileServerAdminTask.brs" and admin_ui:
                text = body.decode()
                start = text.index("function profileAdminRequest(")
                end = text.index("end function", start) + len("end function")
                text = text[:start] + (ROOT / "tests/native/ProfileServerAdminTransportFixture.brs").read_text() + text[end:]
                body = text.encode()
            elif name == "components/DispatcharrTask.brs" and phone_import:
                text = body.decode()
                target = 'sub publishError(message as string, relogin = false as boolean, apiAccessRequired = false as boolean)\n'
                assert text.count(target) == 1
                text = text.replace(target, target + '''    status = 0
    category = ""
    if type(m.httpFailure) = "roAssociativeArray"
        status = m.httpFailure.status
        category = textValue(m.httpFailure.category)
    end if
    print "[picker-launch] "; FormatJson({kind: "phone-import-auth-error", status: status, category: category, rejected: relogin, apiAccess: apiAccessRequired})
''', 1)
                body = text.encode()
            elif name == "components/ProfileServerAdminNavigation.brs" and admin_ui:
                text = body.decode()
                target = '    if result.ok <> true then finishProfileServerAdminUi(textValue(result.reason)) : return'
                assert text.count(target) == 1
                text = text.replace(target, '    if result.ok <> true then print "[picker-launch] "; FormatJson({kind: "admin-ui-error", operation: context.operation, reason: result.reason})\n' + target)
                body = text.encode()
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
            elif name == "components/ProfilePickerManagementNavigation.brs" and mode == "reorder":
                target = b"    m.profilePickerReorderContext = context\n"
                assert body.count(target) == 1
                body = body.replace(target, target + b'    print "[picker-launch] "; FormatJson({kind: "reorder-held", passed: m.profilePickerReorderDialog = invalid and m.top.dialog = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid})\n', 1)
            elif name == "components/GuideView.xml":
                body = body.replace(b"</interface>", b'<function name="profilePickerProbeLineup" /><function name="profilePickerProbeRole" /></interface>', 1)
            elif name == "components/GuideView.brs":
                body += b'\nfunction profilePickerProbeLineup() as string\n    if type(m.channels) <> "roArray" then return ""\n    if m.channels.count() = 0 then return ""\n    return m.channels[0].id\nend function\n'
                body += b'\nfunction profilePickerProbeRole() as string\n    return m.userRole\nend function\n'
            elif name == "components/DvrView.xml" and profile_media:
                body = body.replace(b"</interface>", b'<function name="profileMediaAcceptanceRow" /></interface>', 1)
            elif name == "components/DvrView.brs" and profile_media:
                body += b'''
function profileMediaAcceptanceRow() as object
    for each row in m.loaded
        if row.status = "completed" and row.fileReady then return {loaded: true, ready: true, id: row.id}
    end for
    return {loaded: m.task = invalid, ready: false}
end function
'''
            package.writestr(name, body)
        if phone_verify or phone_import:
            second = baseline_accounts[1]
            package.writestr("fixtures/phone-profile-verify.json", json.dumps({"userId": second["user"]["id"], "username": second["user"]["username"], "apiKey": second["user"]["api_key"], "password": second["password"], "addOnboarding": phone_import_add}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restore", required=True)
    parser.add_argument("--report", default="out/profile-picker-launch-native.json")
    parser.add_argument("--baseline", action="store_true", help="Focused Add, switch, and management baseline flow")
    parser.add_argument("--admin-ui", action="store_true", help="Private synthetic admin transport with real native controls; requires read-only Dispatcharr fixture accounts")
    parser.add_argument("--phone-verify", action="store_true", help="Read-only native phone-profile credential service; never imports or writes server data")
    parser.add_argument("--phone-import", action="store_true", help="Private native receiver-controller import; isolated registry and read-only server access")
    parser.add_argument("--phone-import-add", action="store_true", help="Phone import with one default, then own-credential onboarding Add and Undo")
    parser.add_argument("--profile-media", action="store_true", help="Read-only completed DVR playback before/after own-account profile switching")
    parser.add_argument("--dispatcharr-credentials", type=Path, help="Private JSON: baseUrl and two accounts with username/password; implies baseline, read-only server testing")
    parser.add_argument("--mode", choices=["plain", "pin", "import-pin", "back", "reject", "identity", "cold-link", "warm-link", "warm-pin-link", "warm-auth-link", "warm-import-pin-link", "warm-load-link", "own-keyless", "own-pin", "own-held", "own-cancel", "own-link", "own-pin-link", "own-auth-link", "own-default", "own-default-pin", "own-wrong", "own-recreated", "own-memory", "own-keyboard", "child-select", "child-select-pin", "child-select-reject", "child-select-link", "reorder"], default="plain")
    args = parser.parse_args()
    if args.phone_import_add:
        args.phone_import = True
    baseline_accounts = None
    if (args.admin_ui or args.phone_verify or args.phone_import or args.profile_media) and not args.dispatcharr_credentials:
        parser.error("Focused account flows require --dispatcharr-credentials")
    if sum([args.admin_ui, args.phone_verify, args.phone_import, args.profile_media]) > 1:
        parser.error("Choose one focused native flow")
    real_base = None
    if args.dispatcharr_credentials:
        if args.dispatcharr_credentials.resolve().is_relative_to(ROOT):
            raise RuntimeError("Keep real test credentials outside the repository")
        args.baseline = True
        real_base, baseline_accounts = real_baseline_accounts(json.loads(args.dispatcharr_credentials.read_text()))
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
            if not args.baseline and args.mode not in ["own-keyless", "own-pin", "own-held", "own-cancel", "own-auth-link", "own-default", "own-default-pin", "own-wrong", "own-recreated", "own-memory", "own-keyboard"]:
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
            delayed_link = args.mode in ["warm-auth-link", "child-select-link"] and self.path == "/api/accounts/users/me/"
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
                with_profiles = args.mode in ["import-pin", "warm-import-pin-link", "child-select", "child-select-pin"]
                value = {"apps": [{"key": "synthetic8.aeriotv", "bytes": 600}]} if with_profiles and user == 8 else {"apps": []}
            elif self.path == "/api/accounts/users/me/app-data/synthetic8.aeriotv/":
                salt = "0123456789abcdef0123456789abcdef"
                updated = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(stamp))
                value = {"schemaVersion": 3, "deviceId": "synthetic-phone", "platform": "android", "appVersion": "1", "updatedAt": updated, "categories": {"profiles": {"updatedAt": updated, "data": {"rows": [[8, "Synthetic8", "Imported target", "numbers", hashlib.sha256(bytes.fromhex(salt) + b"5678").hexdigest(), salt, "user", stamp, {}, 0]], "removed": []}}}}
                if args.mode in ["child-select", "child-select-pin"]:
                    value["categories"]["profiles"]["data"]["rows"] = [[8, "Synthetic8", "Forbidden rename", "none", "", "", "user", stamp, {}, 0]]
            elif self.path.split("?", 1)[0] in ["/api/channels/channels/", "/api/channels/channels/summary/"]:
                value = [{"id": user, "uuid": f"00000000-0000-4000-8000-{user:012d}", "name": f"Synthetic {user}", "channel_number": user}]
            rejected = args.mode in ["reject", "child-select-reject"]
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
    private_package = tempfile.TemporaryDirectory(prefix="aeriotv-real-baseline-", dir=args.dispatcharr_credentials.resolve().parent) if baseline_accounts else None
    package_dir = Path(private_package.name) if private_package else ROOT / "out"
    archive = package_dir / "profile-picker-launch-probe.zip"
    cleaner = package_dir / "profile-picker-launch-cleanup.zip"
    build(archive, ROOT / "out/aeriotv-roku.zip", section, real_base or f"http://{local}:{server.server_port}", "baseline" if args.baseline else args.mode, baseline_accounts, admin_ui=args.admin_ui, phone_verify=args.phone_verify, phone_import=args.phone_import, phone_import_add=args.phone_import_add, profile_media=args.profile_media)
    modules["recovery"].cleanup_package(cleaner, section)
    report = {"passed": False, "mode": args.mode, "events": [], "keys": [], "restore_sha256": hashlib.sha256(restore.read_bytes()).hexdigest(), "probe_sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    report["private_registry_section"] = section
    process = None

    def run(path, marker, prefix):
        return subprocess.run(["python3", "scripts/run-native-probe.py", str(path), "--prefix", prefix, "--marker", marker, "--timeout", "45"], cwd=ROOT, capture_output=True, text=True, timeout=100)

    try:
        process = subprocess.Popen(["python3", "scripts/run-native-probe.py", str(archive), "--prefix", "[picker-launch]", "--marker", '"kind":"result"', "--timeout", "180" if baseline_accounts else "75"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end="", flush=True)
            report.setdefault("output", []).append(line.rstrip())
            if "[picker-launch] {" not in line:
                continue
            event = json.loads(line.split("[picker-launch] ", 1)[1])
            report["events"].append(event)
            if event["kind"] == "switcher-visual":
                image = str(Path(args.report).with_suffix(".switcher.jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                report["switcher_screenshot"] = captured.returncode == 0
                report["switcher_screenshot_path"] = image
                request = urllib.request.Request(f"http://{host}:8060/input?pickerProbeVisualCaptured=1", data=b"", method="POST")
                with urllib.request.urlopen(request, timeout=3) as response:
                    report["switcher_visual_ack"] = response.status
            if event["kind"] == "ready":
                report["pre_selection_requests"] = hits.copy()
                screenshot_path = str(Path(args.report).with_suffix(".jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", screenshot_path], cwd=ROOT, capture_output=True, timeout=40)
                report["screenshot"] = captured.returncode == 0
                report["screenshot_path"] = screenshot_path
                keys = [] if args.mode in ["cold-link", "warm-link"] else ["Right", "Select"]
                if args.mode in ["own-default", "own-default-pin"]:
                    keys = ["Select"]
                if args.mode == "reorder":
                    keys = ["Right"]
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
                if args.mode == "reorder" and all(key.get("status") == 200 for key in report["keys"]):
                    for action in ["keydown", "keyup"]:
                        command = urllib.request.Request(f"http://{host}:8060/{action}/Select", data=b"", method="POST")
                        attempt = {"key": "Select", "action": action}
                        report["keys"].append(attempt)
                        with urllib.request.urlopen(command, timeout=3) as response:
                            attempt["status"] = response.status
                        if action == "keydown":
                            time.sleep(0.9)
            elif event["kind"] == "reorder-menu":
                image = str(Path(args.report).with_name(Path(args.report).stem + "-move-menu.jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                report["reorder_screenshot"] = captured.returncode == 0
                command = urllib.request.Request(f"http://{host}:8060/keypress/Select", data=b"", method="POST")
                with urllib.request.urlopen(command, timeout=3) as response:
                    report["keys"].append({"key": "Select", "status": response.status})
            elif event["kind"] == "result" and args.mode in ["child-select", "child-select-pin"] and event.get("passed") is True:
                image = str(Path(args.report).with_name(Path(args.report).stem + "-child-guide.jpg"))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                report["child_guide_screenshot"] = captured.returncode == 0
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
        pin_count = {"plain": 0, "pin": 1, "import-pin": 2, "back": 0, "reject": 0, "identity": 0, "cold-link": 1, "warm-link": 1, "warm-pin-link": 1, "warm-auth-link": 1, "warm-import-pin-link": 2, "warm-load-link": 1, "own-keyless": 0, "own-pin": 1, "own-held": 0, "own-cancel": 0, "own-link": 1, "own-pin-link": 2, "own-auth-link": 1, "own-default": 0, "own-default-pin": 1, "own-wrong": 0, "own-recreated": 0, "own-memory": 0, "own-keyboard": 0, "child-select": 0, "child-select-pin": 1, "child-select-reject": 0, "child-select-link": 1, "reorder": 0}[args.mode]
        before_pins = report.get("pre_pin_requests", [])
        pin_ok = len(pins) == pin_count and all(event["wrong_covered"] and event["verified"] for event in pins) and [command.get("status") for command in report.get("pin_commands", [])] == [200] * pin_count
        if pin_count:
            pin_ok = pin_ok and len(before_pins) == pin_count and before_pins[0] == [] and all(not hit.get("path", "").startswith("/api/channels/") for boundary in before_pins for hit in boundary)
        if args.mode == "import-pin":
            reads = [event["read_nonce"] for event in phases if event["phase"] == "read"]
            pin_ok = pin_ok and len(set(reads)) == 2 and all(reads) and paths.count("/api/accounts/users/me/app-data/synthetic8.aeriotv/") == 2
        wanted_keys = [200] if args.mode in ["own-default", "own-default-pin"] else [200, 200]
        report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == wanted_keys and [p["phase"] for p in phases] == expected_phases and all(p["no_actor"] and p["empty_key"] for p in phases) and all(h.get("user") == target_user and h["method"] == "GET" for h in hits) and listing >= 2 and heavy > listing and paths.count("/api/accounts/users/me/") >= 3 and pin_ok
        if args.mode in ["child-select", "child-select-pin"]:
            report["passed"] = report["passed"] and report.get("child_guide_screenshot") is True and paths.count("/api/accounts/users/me/app-data/synthetic8.aeriotv/") == 1
        if args.mode == "reorder":
            held = [event for event in events if event["kind"] == "reorder-held"]
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("reordered") is True and report.get("pre_selection_requests") == [] and hits == [] and phases == [] and report.get("screenshot") is True and report.get("reorder_screenshot") is True and [key.get("status") for key in report["keys"]] == [200] * 4 and len(held) == 1 and held[0].get("passed") is True
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
        if args.mode in ["back", "reject", "identity", "child-select-reject"]:
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("exited" if args.mode == "back" else "rejected") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == [200, 200] and [p["phase"] for p in phases] == ["authenticate"] and all(p["no_actor"] and p["empty_key"] for p in phases) and len(hits) == 1 and hits[0].get("user") == 8 and hits[0].get("path") == "/api/accounts/users/me/" and hits[0]["method"] == "GET"
            if args.mode == "back":
                report["passed"] = report["passed"] and report.get("back_ack_before_verdict") is True and report.get("back_status") == 200 and report.get("back_activity") == {"dev_active": True, "screensaver_active": False}
            else:
                report["passed"] = report["passed"] and report.get("rejected_ready") is True and report.get("held_retry_status") == 200 and report.get("rejected_screenshot") is True and len(report.get("held_retry_boundary", [])) == 1 and events[-1].get("held_refused") is True
                if args.mode == "identity":
                    report["passed"] = report["passed"] and report.get("mismatched_me_response") == {"status": 200, "id": 9, "username": "Synthetic9"} and events[-1].get("no_broker_hold") is True
        if args.mode in ["cold-link", "warm-link", "warm-pin-link", "warm-auth-link", "warm-import-pin-link", "warm-load-link", "child-select-link"]:
            expected_beacons = ["AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]
            if args.mode != "cold-link":
                expected_beacons = ["AppDialogInitiate", "AppDialogComplete", "AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]
            beacons = [event["name"] for event in events if event["kind"] == "beacon"]
            expected_keys = [] if args.mode in ["cold-link", "warm-link"] else [200, 200]
            expected_phases = ["authenticate"] if args.mode in ["warm-auth-link", "child-select-link"] else []
            own_hits = hits
            pin_ok = len(pins) == 1 and pins[0]["wrong_covered"] and pins[0]["verified"] and [command.get("status") for command in report.get("pin_commands", [])] == [200]
            if args.mode in ["warm-auth-link", "child-select-link"]:
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
        report["ready_events_valid"] = all(event.get("ready") is True for event in events if event["kind"] in ["ready", "pin-ready", "rejected-ready", "own-form-ready", "keyboard-ready", "reorder-menu"])
        if args.baseline:
            report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("baseline") is True and report.get("credential_posts") == [{"path": "/api/accounts/token/", "accepted": True}] and all(hit.get("method") == "GET" for hit in hits) and any(hit.get("user") == 8 and hit.get("path", "").startswith("/api/channels/") for hit in hits)
            if baseline_accounts:
                report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and events[-1].get("baseline") is True
            if args.phone_import:
                report["verification_transport"] = "authorized-read-only"
                report["passed"] = report["passed"] and all(events[-1].get(field) is True for field in ["phoneimport", "ownkeys", "protectedadmission", "sourceunchanged", "recoveryui", "onboarding"])
            elif args.phone_verify:
                report["verification_transport"] = "authorized-read-only"
                report["passed"] = report["passed"] and all(events[-1].get(field) is True for field in ["phoneverify", "ownproofs", "inputscleared", "unchanged"])
            elif args.admin_ui:
                report["admin_transport"] = "synthetic-no-http"
                report["passed"] = report["passed"] and all(events[-1].get(field) is True for field in ["adminui", "syntheticadminonly", "apiaccess", "ownreload"])
            else:
                report["passed"] = report["passed"] and report.get("switcher_screenshot") is True and report.get("switcher_visual_ack") == 200
                report["real_dispatcharr"] = True
        report["passed"] = report["passed"] and report["ready_events_valid"]
    finally:
        report["requests"] = hits.copy()
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        try:
            cleaned = run(cleaner, "[profile-recovery] cleanup=", "[profile-recovery]")
            report["cleanup_returncode"] = cleaned.returncode
            report["cleaned"] = cleaned.returncode == 0 and "cleanup=true" in cleaned.stdout
        finally:
            restored = run(restore, "Running dev", "[picker-restore]")
            report["restore_returncode"] = restored.returncode
            report["restored"] = restored.returncode == 0 and modules["primitives"].installed_md5(host, password) == digest
            server.shutdown()
            server.server_close()
            if private_package:
                private_package.cleanup()
            Path(args.report).write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps({key: report.get(key, False) for key in ["passed", "cleaned", "restored"]}), flush=True)
        if not report.get("cleaned") or not report.get("restored"):
            raise RuntimeError("Private cleanup or exact app restoration failed")
    if not report["passed"]:
        raise SystemExit("Native startup picker qualification failed")


if __name__ == "__main__":
    main()
