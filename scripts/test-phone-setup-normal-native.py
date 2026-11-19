"""Real normal receiver/provider + unmodified peer encoders; isolated state, exact restore."""
import argparse
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TEMP = Path("/private/var/folders/qc/4lbpvxwj7pn5_675mjffljrr0000gn/T/opencode")
PRODUCTION_FILES = [
    "source/PhoneSetupEntropy.brs", "source/PhoneSetupCrypto.brs", "source/PhoneSetupX25519.brs",
    "source/PhoneSetupStore.brs", "source/PhoneSetupProfileImport.brs", "source/PhoneSetupProfilePolicy.brs",
    "components/PhoneSetupTask.brs", "components/PhoneSetupTask.xml",
    "components/PhoneSetupView.brs", "components/PhoneSetupView.xml",
    "components/PhoneSetupNavigation.brs", "components/PhoneSetupProfileNavigation.brs",
    "components/PhoneSetupProfileVerifyTask.brs", "components/DispatcharrTask.brs",
    "components/ProfilePinNavigation.brs", "components/ProfileSwitchNavigation.brs",
]

def package_fingerprints(path):
    """Stable source-byte identity across compiler ZIP timestamps/compression."""
    with zipfile.ZipFile(path) as package:
        return {name: hashlib.sha256(package.read(name)).hexdigest() for name in sorted(package.namelist())}

def replace_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError("Private Guide Days probe hook no longer matches; refusing build")
    return source.replace(old, new, 1)


def build(output, normal, section, diagnostic=False, live=None, guide_days=None):
    fixture = (ROOT / "tests/native/PhoneSetupNormalFixture.brs").read_text()
    if live:
        initialization = "\n".join([
            f"    m.phoneNormalDefaultUser = {int(live['accounts'][0]['user']['id'])}",
            f"    m.phoneNormalSecondaryUser = {int(live['accounts'][1]['user']['id'])}",
            f"    m.phoneNormalExpectedRole = {json.dumps(live['role'])}",
            f"    m.phoneNormalDefaultKeyHash = {json.dumps(hashlib.sha256(live['accounts'][0]['user']['api_key'].encode()).hexdigest())}",
            f"    m.phoneNormalSecondaryKeyHash = {json.dumps(hashlib.sha256(live['accounts'][1]['user']['api_key'].encode()).hexdigest())}",
        ])
        fixture = fixture.replace('    m.phoneNormalPhase = 0', initialization + '\n    m.phoneNormalPhase = 0', 1)
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == "components/AerioScene.brs":
                source = body.decode()
                target = 'CreateObject("roRegistrySection", "AerioTV")'
                assert source.count(target) == 1
                isolated = f'CreateObject("roRegistrySection", "{section}")'
                if guide_days is not None:
                    isolated += "\n    m.profileSyncWriterReady = false\n    m.profileSyncSchedulingReady = false"
                source = source.replace(target, isolated, 1)
                target = "sub onLaunchRequest()\n"
                assert source.count(target) == 1
                source = source.replace(target, target + '''    if m.top.launchRequest.phoneNormalOpen = "1"
        startPhoneNormalProbe()
        return
    end if
''', 1)
                fixture_source = fixture
                if guide_days is not None:
                    expected = 30 if guide_days == 0 else guide_days
                    fixture_source = replace_once(fixture_source, '        store = loadUserProfileStore(m.registry, m.selectedConnectionId)\n', f'''        if m.guideDaysProbeDone <> true
            entry = connectionStoreEntry(loadConnectionStore(m.registry), m.selectedConnectionId)
            restored = accountPreferences(loadPreferenceStore(m.registry, true), m.accountIdentity)
            if entry = invalid then finishPhoneNormalProbe(false, "guide-slot-missing") : return
            if entry.guideDays <> {guide_days} or m.phoneOptions <> invalid then finishPhoneNormalProbe(false, "guide-import-metadata") : return
            if m.accountPreferences.guide.futureDays <> {expected} or restored.guide.futureDays <> {expected} or restored.guide.historyDays <> 3 then finishPhoneNormalProbe(false, "guide-preference-mismatch") : return
            result = m.guide.callFunc("probeImportedGuideWindow", {expected})
            if result.state = "waiting" then return
            print "[setup-phone-normal] "; FormatJson({{kind: "guide-days", state: result.state, days: {expected}, window: result.window, programs: result.programs}})
            if result.state <> "loaded" then finishPhoneNormalProbe(false, "guide-window") : return
            openSettingsHub()
            m.settingsHub.selection = userViewEvent({{scope: "guide", key: "futureDays", value: 6, account: m.accountIdentity}}, currentUserSessionId())
            m.guideDaysProbeEditing = true
            m.phoneNormalPhase = 70
            return
        end if
        store = loadUserProfileStore(m.registry, m.selectedConnectionId)
''')
                    fixture_source = replace_once(fixture_source, '        finishPhoneNormalProbe(passed, "complete")\n', '''        if not passed then finishPhoneNormalProbe(false, "profile-switch") : return
        if not beginUserProfileSwitch(m.guideDaysDefaultId) then finishPhoneNormalProbe(false, "guide-reconnect") : return
        m.phoneNormalPhase = 90
    else if phase = 70
        if m.page <> "settings" or m.guideDaysProbeEditing <> true then finishPhoneNormalProbe(false, "guide-edit-admission") : return
        restored = accountPreferences(loadPreferenceStore(m.registry, true), m.accountIdentity)
        if restored.guide.futureDays <> 6 or m.accountPreferences.guide.futureDays <> 6 then return
        m.guideDaysDefaultId = m.activeUserScope.profileId
        closeSettingsHub()
        m.guideDaysProbeEditing = false
        m.phoneNormalPhase = 7
        m.guideDaysProbeDone = true
    else if phase = 90
        if m.profilePinDialog = invalid then return
        m.profilePinDialog.textEditBox.text = "1234"
        onProfilePinSubmit(phoneNormalEvent(m.profilePinDialog, 0))
        m.phoneNormalPhase = 91
    else if phase = 91
        if m.busy or m.page <> "guide" or m.activeUserScope = invalid or m.capabilityTask <> invalid then return
        if m.activeUserScope.profileId <> m.guideDaysDefaultId or m.activeUserScope.accountId <> m.phoneNormalDefaultUser.toStr() then finishPhoneNormalProbe(false, "guide-reconnect-identity") : return
        restored = accountPreferences(loadPreferenceStore(m.registry, true), m.accountIdentity)
        passed = restored.guide.futureDays = 6 and m.accountPreferences.guide.futureDays = 6 and m.guide.config.preferences.guide.futureDays = 6 and restored.guide.historyDays = 3 and m.phoneOptions = invalid
        print "[setup-phone-normal] "; FormatJson({kind: "guide-reconnect", kept_edit: passed})
        finishPhoneNormalProbe(passed, "guide-reconnect")
''')
                body = (source + "\n" + fixture_source).encode()
            elif name == "source/MetadataCacheStore.brs":
                assert body.count(b'"cachefs:/aeriotv-metadata-v1"') == 1
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/phone-normal-cache"')
            elif guide_days is not None and name == "components/GuideView.xml":
                body = replace_once(body, b'<interface>', b'<interface>\n    <function name="probeImportedGuideWindow" />')
            elif guide_days is not None and name == "components/GuideView.brs":
                target = b"    result = event.getData()\n    m.top.metadataEvent = {ok: result.ok, stage: \"window\","
                body = replace_once(body, target, b'''    result = event.getData()
    if m.guideDaysProbeWindow <> invalid and result.windowStart = m.guideDaysProbeWindow
        m.guideDaysProbeSource = textValue(result.source)
    end if
    m.top.metadataEvent = {ok: result.ok, stage: "window",''')
                body += b"\n" + (ROOT / "tests/native/PhoneSetupGuideDaysFixture.brs").read_bytes()
            elif guide_days is not None and name == "source/HttpTransport.brs":
                target = b"    method = ucase(method)\n"
                body = replace_once(body, target, target + b'''    if method <> "GET"
        print "[setup-phone-normal] "; FormatJson({kind: "non-read-blocked"})
        result.error = "invalid-request"
        return result
    end if
''')
            elif guide_days is not None and name == "components/DispatcharrSyncWriteTask.brs":
                body = replace_once(body, b'    if m.syncWriterReady <> true then finishDispatcharrSyncWrite(denied) : return\n',
                                    b'    finishDispatcharrSyncWrite(denied) : return\n')
            elif diagnostic and name == "components/PhoneSetupProfileVerifyTask.brs":
                text = body.decode()
                anchor = '    if phoneProfileVerificationCancelled() or m.base = ""'
                assert text.count(anchor) == 1
                text = text.replace(anchor, '''    print "[setup-phone-normal] "; FormatJson({kind: "verify-diagnostic", stage: "admission", current: requestGateTaskSessionCurrent(), has_session_field: m.top.hasField("aeriosession"), base: m.base <> "", nonce: userProfileLocalId(m.top.captureNonce) <> "", profiles_type: type(m.top.profiles), credential_type: type(m.top.defaultCredential)})
''' + anchor, 1)
                anchor = '\n    ordered = phoneSetupProfileQueue(m.rows)\n'
                assert text.count(anchor) == 1
                text = text.replace(anchor, anchor + '''    print "[setup-phone-normal] "; FormatJson({kind: "verify-diagnostic", stage: "queue", ok: ordered.ok, rows: m.rows.count(), has_key: textValue(m.defaultCredential.apiKey) <> ""})
''', 1)
                anchor = '        user = requestJson(m.base + "/api/accounts/users/me/")'
                assert text.count(anchor) == 1
                text = text.replace(anchor, '''        print "[setup-phone-normal] "; FormatJson({kind: "verify-diagnostic", stage: "before-request", current: requestGateTaskSessionCurrent(), key: m.key <> ""})
''' + anchor + '''
        failureReason = ""
        failureCategory = ""
        failureStatus = -1
        if type(m.httpFailure) = "roAssociativeArray"
            failureStatus = m.httpFailure.status
            candidateCategory = textValue(m.httpFailure.category)
            if CreateObject("roRegex", "^[a-z-]{1,50}$", "").isMatch(candidateCategory) then failureCategory = candidateCategory
            candidateReason = textValue(m.httpFailure.gateReason)
            if CreateObject("roRegex", "^[a-z-]{1,50}$", "").isMatch(candidateReason) then failureReason = candidateReason
        end if
        print "[setup-phone-normal] "; FormatJson({kind: "verify-diagnostic", stage: "after-request", user_type: type(user), status: failureStatus, category: failureCategory, gate_reason: failureReason})
''', 1)
                body = text.encode()
            package.writestr(name, body)
        for name in ["PhoneEntropyFaultProbe.brs", "PhoneEntropyFaultProbe.xml"]:
            package.write(ROOT / "tests/native" / name, "components/" + name)
        package.writestr("phone-setup-normal-probe.json", json.dumps({"isolated": True, "productionReceiver": True}))


def load_module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"test-profile-{name}-native.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def private_json(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as file:
        json.dump(value, file)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "out/aeriotv-roku.zip")
    parser.add_argument("--restore", type=Path, required=True)
    parser.add_argument("--peer", choices=["apple", "android"], required=True)
    parser.add_argument("--dispatcharr-credentials", type=Path, required=True, help="Private approved live test accounts; never a laptop-hosted provider")
    parser.add_argument("--secondary-role", choices=["user", "child"], default="child")
    parser.add_argument("--diagnostic", action="store_true", help="Private verification-stage logs; never counts as normal-byte acceptance")
    parser.add_argument("--guide-days", type=int, choices=range(15), help="Read-only Guide Days probe; require the persisted preference, live guide clamp and provider response")
    parser.add_argument("--peer-directory", type=Path, default=TEMP / "mrr-peer-wire")
    args = parser.parse_args()
    primitives, recovery = load_module("primitives"), load_module("recovery")
    host, password = os.environ["ROKU_HOST"], os.environ["ROKU_DEV_PASSWORD"]
    expected = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if primitives.installed_md5(host, password) != expected:
        raise RuntimeError("Installed app differs from exact restore ZIP; refusing replacement")
    accounts_module = load_module("picker-launch")
    live_base, accounts = accounts_module.real_baseline_accounts(json.loads(args.dispatcharr_credentials.read_text()))
    live = {"accounts": accounts, "role": args.secondary_role}
    events = []
    section = "AerioPhoneNormal-" + str(uuid.uuid4())
    run_id = str(uuid.uuid4())[:8]
    archive = ROOT / f"out/phone-normal-{args.peer}-{run_id}-probe.zip"
    cleaner = ROOT / f"out/phone-normal-{args.peer}-{run_id}-cleanup.zip"
    build(archive, args.source, section, diagnostic=args.diagnostic, live=live, guide_days=args.guide_days)
    # Compile the complete private app before touching the development slot.
    with tempfile.TemporaryDirectory(dir=TEMP) as folder:
        with zipfile.ZipFile(archive) as package:
            package.extractall(folder)
        config = Path(folder) / "bsconfig.json"
        config.write_text(json.dumps({"rootDir": folder, "files": ["manifest", "source/**/*", "components/**/*"],
                                      "createPackage": False, "copyToStaging": False}))
        compiled = subprocess.run([str(ROOT / "node_modules/.bin/bsc"), "--project", str(config)],
                                  capture_output=True, text=True, timeout=90)
        if compiled.returncode:
            raise RuntimeError("Private normal-app fixture compilation failed:\n" + compiled.stdout + compiled.stderr)
    recovery.cleanup_package(cleaner, section)
    report = {"passed": False, "peer": args.peer, "secondary_role": args.secondary_role, "events": events,
              "live_dispatcharr": True, "approved_accounts": len(accounts), "discovery_transport": {},
               "production_bytes_preserved": not args.diagnostic and args.guide_days is None, "diagnostic_only": args.diagnostic,
               "guide_days": args.guide_days,
              "probe_archive": str(archive), "restore_sha256": hashlib.sha256(args.restore.read_bytes()).hexdigest(),
              "source_sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
              "source_file_sha256": package_fingerprints(args.source),
              "probe_sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    with zipfile.ZipFile(args.source) as normal, zipfile.ZipFile(archive) as probe:
        assert all(normal.read(name) == probe.read(name) for name in PRODUCTION_FILES
                   if not (args.diagnostic and name == "components/PhoneSetupProfileVerifyTask.brs"))
    browse_events = queue.Queue()
    browser = None

    def ecp(path):
        request = urllib.request.Request(f"http://{host}:8060/{path}", data=b"", method="POST")
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status

    def run_probe(path, marker, prefix, timeout=40):
        return subprocess.run([sys.executable, "scripts/run-native-probe.py", str(path), "--prefix", prefix,
                               "--marker", marker, "--timeout", str(timeout)], cwd=ROOT,
                              capture_output=True, text=True, timeout=timeout + 70)

    def receive_url(session, envelope):
        request = urllib.request.Request(f"http://{host}:{session['port']}/setup", data=envelope,
                                         headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    def encode_peer(session, folder, wrong=False):
        payload = {"playlist": {"id": "00000000-0000-4000-8000-000000000070", "type": "dispatcharr", "name": "Normal Phone Import",
                               "url": live_base, "credential": {"apiKey": accounts[0]["user"]["api_key"]},
                               "vodEnabled": False, "guideDays": 3 if args.guide_days is None else args.guide_days},
                   "profiles": [], "sync": {"provider": "dispatcharr", "enabled": True}}
        salt = "00112233445566778899aabbccddeeff"
        for index in [1, 0]:
            user = accounts[index]["user"]
            is_default = index == 0
            role = "user" if is_default else args.secondary_role
            ident = 7 if is_default else 9
            row = {"username": user["username"], "displayName": "Phone Default" if is_default else "Phone Secondary",
                   "isDefault": is_default, "role": role, "id": f"00000000-0000-4000-8000-{ident:012d}"}
            if not is_default:
                row["credential"] = {"apiKey": user["api_key"]}
            if is_default or role == "child":
                pin = "1234" if is_default else "UDLR"
                row.update({"pinType": "numbers" if is_default else "directions", "pinSalt": salt,
                            "pinHash": hashlib.sha256(bytes.fromhex(salt) + pin.encode()).hexdigest()})
            payload["profiles"].append(row)
        stem = "wrong" if wrong else "valid"
        payload_path, config_path = folder / f"{stem}-payload.json", folder / f"{stem}-config.json"
        envelope_path, normalized_path = folder / f"{stem}-envelope.json", folder / f"{stem}-normalized.json"
        code = session["code"]
        if wrong:
            code = str((int(code) + 1) % 1000000).zfill(6)
        private_json(payload_path, payload)
        private_json(config_path, {"payloadPath": str(payload_path), "tvPublicKey": session["pk"], "code": code,
                                  "outputEnvelope": str(envelope_path), "outputPayload": str(normalized_path)})
        if args.peer == "apple":
            command = [str(args.peer_directory / "apple-peer"), str(config_path)]
        else:
            java = TEMP / "mrr-peer-tools/jdk-17.0.21+9/Contents/Home/bin/java"
            libraries = [args.peer_directory / name for name in ["android-peer.jar",
                         "kotlinx-serialization-core-jvm-1.9.0.jar", "kotlinx-serialization-json-jvm-1.9.0.jar"]]
            command = [str(java), "-cp", ":".join(map(str, libraries)), "PeerMainKt", str(config_path)]
        encoded = subprocess.run(command, capture_output=True, text=True, timeout=30)
        if encoded.returncode:
            raise RuntimeError("Unmodified peer encoder failed; no private input/output emitted")
        return envelope_path.read_bytes()

    try:
        cache = TEMP / "phone-normal-swift-cache"
        browser = subprocess.Popen(["swift", "-module-cache-path", str(cache),
                                    "scripts/browse-pairing-service.swift", host],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

        def read_browse():
            for line in browser.stdout:
                try:
                    browse_events.put(json.loads(line))
                except json.JSONDecodeError:
                    pass

        threading.Thread(target=read_browse, daemon=True).start()
        until = time.monotonic() + 70
        while time.monotonic() < until:
            if browse_events.get(timeout=70).get("event") == "ready":
                break
        else:
            raise RuntimeError("Bonjour browser did not become ready")
        with tempfile.TemporaryDirectory(dir=TEMP) as private:
            private = Path(private)
            command = [sys.executable, "scripts/run-native-probe.py", str(archive), "--prefix", "[setup-",
                       "--marker", '"kind":"result"', "--timeout", "360"]
            with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
                opened = False
                for line in process.stdout:
                    print(line, end="", flush=True)
                    stage = re.search(r"\[setup-discovery\] ([a-z-]+)", line)
                    if stage:
                        stage = stage.group(1)
                        report["discovery_transport"][stage] = report["discovery_transport"].get(stage, 0) + 1
                    if "Running dev" in line and not opened:
                        opened = True
                        report["open_status"] = ecp("input?phoneNormalOpen=1")
                    if "[setup-phone-normal] {" not in line:
                        continue
                    event = json.loads(line.split("[setup-phone-normal] ", 1)[1])
                    events.append(event)
                    if event.get("kind") != "ready":
                        continue
                    image = private / "qr.jpg"
                    captured = subprocess.run([sys.executable, "scripts/capture-roku-screenshot.py", "--developer-mode",
                                               "--output", str(image)], capture_output=True, timeout=45)
                    if captured.returncode:
                        raise RuntimeError("Native QR capture failed")
                    qr = subprocess.run(["swift", "-module-cache-path", str(cache), "scripts/read-setup-probe-qr.swift",
                                         str(image)], capture_output=True, text=True, timeout=60)
                    image.unlink(missing_ok=True)
                    if qr.returncode:
                        raise RuntimeError("Native normal-build QR did not decode")
                    link = urllib.parse.urlsplit(qr.stdout.strip())
                    fields = urllib.parse.parse_qs(link.query)
                    assert link.scheme == "aeriotv" and link.netloc == "setup" and fields["ip"][0] == host
                    raw = fields["pk"][0]
                    public = base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4))
                    session = {"pk": base64.b64encode(public).decode(), "code": fields["code"][0],
                               "port": int(fields["port"][0])}
                    assert len(public) == 32 and len(session["code"]) == 6 and session["code"].isdigit()
                    report["native_qr"] = True
                    until = time.monotonic() + 20
                    report["bonjour"] = False
                    report["discovery_events"] = {}
                    report["discovery_candidates"] = []
                    while time.monotonic() < until:
                        try:
                            row = browse_events.get(timeout=max(0.1, until - time.monotonic()))
                        except queue.Empty:
                            break
                        name = str(row.get("event", "unknown"))
                        report["discovery_events"][name] = report["discovery_events"].get(name, 0) + 1
                        if name in ["resolved", "dns-resolved"]:
                            report["discovery_candidates"].append({"same_port": row.get("port") == session["port"],
                                "same_public_key": row.get("pk") == session["pk"], "same_host": row.get("host") == host,
                                "no_code": row.get("noCode") is True})
                        if row.get("event") in ["resolved", "dns-resolved"] and row.get("port") == session["port"] and row.get("pk") == session["pk"]:
                            report["bonjour"] = row.get("host") == host and row.get("v") == "1" and row.get("noCode") is True
                            break
                    wrong = encode_peer(session, private, wrong=True)
                    status, body = receive_url(session, wrong)
                    report["wrong_code_refused"] = status == 403 and body == {"ok": False, "error": "wrong_code"}
                    valid = encode_peer(session, private)
                    status, body = receive_url(session, valid)
                    report["setup_accepted"] = status == 200 and body == {"ok": True}
                    try:
                        replay_status, _ = receive_url(session, valid)
                        report["replay_refused"] = replay_status == 403
                    except urllib.error.URLError:
                        report["replay_refused"] = True
                code = process.wait(timeout=10)
        report["verification_order"] = "default-before-secondary" if events and events[-1].get("passed") else "unverified"
        report["passed"] = not args.diagnostic and code == 0 and events[-1].get("kind") == "result" and events[-1].get("passed") is True
        report["passed"] = report["passed"] and all(report.get(field) is True for field in [
            "native_qr", "wrong_code_refused", "setup_accepted", "replay_refused",
            "live_dispatcharr"])
        if args.guide_days is not None:
            guide = [event for event in events if event.get("kind") == "guide-days"]
            report["guide_days_live"] = len(guide) == 1 and guide[0]["state"] == "loaded"
            report["guide_days_reconnect"] = any(event.get("kind") == "guide-reconnect" and event.get("kept_edit") is True for event in events)
            report["passed"] = report["passed"] and report["guide_days_live"] and report["guide_days_reconnect"] and not any(
                event.get("kind") == "non-read-blocked" for event in events)
        report["acceptance_path"] = "QR/direct LAN endpoint over VPN; multicast discovery separately unverified" if not report.get("bonjour") else "QR and Bonjour"
    finally:
        if browser is not None:
            browser.terminate()
            browser.wait(timeout=10)
        try:
            cleanup = run_probe(cleaner, "cleanup=", "[profile-recovery]")
            report["cleaned"] = cleanup.returncode == 0 and "cleanup=true" in cleanup.stdout
        finally:
            restore = run_probe(args.restore, "Running dev", "[restore]")
            report["restored"] = restore.returncode == 0 and primitives.installed_md5(host, password) == expected
            report["passed"] = report["passed"] and report.get("cleaned", False) and report["restored"]
            suffix = "-diagnostic" if args.diagnostic else ""
            if args.guide_days is not None:
                suffix += f"-guide-days-{args.guide_days}"
            encoded_report = json.dumps(report, indent=2) + "\n"
            (ROOT / f"out/phone-normal-{args.peer}{suffix}-{run_id}.json").write_text(encoded_report)
            (ROOT / f"out/phone-normal-{args.peer}{suffix}-native.json").write_text(encoded_report)
            print(json.dumps({field: report.get(field) for field in ["peer", "passed", "cleaned", "restored"]}), flush=True)
    if not report["passed"]:
        raise SystemExit("Normal phone-setup native assertions failed; preserve report")
    return report


if __name__ == "__main__":
    main()
