"""Qualify private normal-app startup selection with isolated HTTP and registry."""
import argparse
from collections import Counter
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
import re
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
PICKER_PREFIX = "[picker-launch] "
PICKER_ENTRIES = (
    "manifest", "components/AerioScene.brs", "components/ProfilePickerNavigation.brs",
    "components/GuideView.brs", "components/GuideView.xml", "source/MetadataCacheStore.brs",
    "source/StartupBeaconModel.brs",
)
PROTECTED_PICKER_ENTRIES = (
    "components/ProfilePinNavigation.brs", "components/DispatcharrTask.brs",
    "components/DispatcharrTask.xml", "source/UserProfileStartupSelection.brs",
    "source/RequestGateClient.brs", "source/HttpTransport.brs",
)
GATE_VERDICTS = (
    "allowed", "credential-held", "parked", "capacity", "invalid-context",
    "stale-session", "gate-unavailable", "other",
)
DIAGNOSTIC_FIELDS = {
    "pin-accepted": {},
    "scene-admission": {"context_present": bool, "task_present": bool, "picker_owned": bool},
    "target-role": {"allowed": bool},
    "task-created": {"created": bool},
    "before-run": {"owned": bool, "context_current": bool},
    "run-returned": {},
    "task-state": {"state": ("run", "done", "stop", "init", "other"), "owned": bool},
    "task-entry": {"cancelled": bool},
    "storage-current": {"owned": bool, "protected_check": bool},
    "scene-broker-snapshot": {
        "allowed": bool,
        "verdict": GATE_VERDICTS + (
            "broker-missing", "broker-not-ready", "snapshot-unavailable", "credential-digest-unavailable",
        ),
    },
    "broker-missing": {},
    "broker-not-ready": {},
    "broker-ready": {},
    "credential-digest-unavailable": {},
    "broker-no-reply": {},
    "acquire-enter": {},
    "permit-decision": {"verdict": GATE_VERDICTS},
    "transfer-start": {"started": bool},
}


def picker_event_fields(pairs):
    fields = dict(pairs)
    if len(fields) != len(pairs):
        raise ValueError("Duplicate picker event fields")
    return fields


def sanitized_picker_diagnostic(event):
    stage = event.get("stage")
    fields = DIAGNOSTIC_FIELDS.get(stage) if type(stage) is str else None
    if fields is None:
        return None
    safe = {"kind": "startup-diagnostic", "stage": stage}
    for name, allowed in fields.items():
        value = event.get(name)
        if allowed is bool:
            if type(value) is not bool:
                return None
        elif type(value) is not str or value not in allowed:
            return None
        safe[name] = value
    return safe


def record_picker_output(report, line, *, protected):
    """The native runner's stdout is a private pipe. Filter before public output."""
    _, prefix, payload = line.partition(PICKER_PREFIX.rstrip() if protected else PICKER_PREFIX)
    event = None
    if prefix and (protected or payload.startswith("{")):
        if protected:
            try:
                event = json.loads(payload, object_pairs_hook=picker_event_fields)
            except (ValueError, RecursionError):
                return None
            if not isinstance(event, dict) or not isinstance(event.get("kind"), str):
                return None
        else:
            event = json.loads(payload)
        if event.get("kind") == "startup-diagnostic":
            if not protected:
                return None
            event = sanitized_picker_diagnostic(event)
            if event is None:
                return None
            line = PICKER_PREFIX + json.dumps(event, separators=(",", ":")) + "\n"
    print(line, end="", flush=True)
    report.setdefault("output", []).append(line.rstrip())
    if event is not None:
        report["events"].append(event)
    return event


def require_patch_anchor(name, body, anchor):
    count = body.count(anchor)
    if count != 1:
        raise ValueError(f"{name}: expected a unique patch anchor, found {count}")


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
        if credentials.get("apiKey"):
            headers = {"X-API-Key": credentials["apiKey"]}
        else:
            password_body = {"username": credentials["username"], "password": credentials["password"]}
            request = urllib.request.Request(base + "/api/accounts/token/", data=json.dumps(password_body).encode(), headers={"Content-Type": "application/json"}, method="POST")
            token = read_json(request)["access"]
            headers = {"Authorization": "Bearer " + token}
        request = urllib.request.Request(base + "/api/accounts/users/me/", headers=headers)
        user = read_json(request)
        if user.get("username", "").lower() != credentials["username"].lower():
            raise RuntimeError("Test login did not return its own expected identity")
        if not user.get("api_key"):
            raise RuntimeError("Approved test account lacks API access; enable its own API key in Dispatcharr before testing")
        accounts.append({"user": user, "password": credentials.get("password", "")})
    if len(accounts) != 2 or accounts[0]["user"]["id"] == accounts[1]["user"]["id"]:
        raise RuntimeError("Two distinct approved accounts are required")
    return base, accounts


def live_request_hit(event, accounts):
    """Map a live probe request trace to the fixture ledger shape, or refuse it."""
    path, method, account = event.get("path"), event.get("method"), event.get("account")
    if type(path) is not str or not path.startswith("/") or "?" in path or "://" in path or len(path) > 200:
        return None
    if method not in ("GET", "POST", "PUT", "PATCH", "DELETE") or type(account) is not int:
        return None
    return {"user": accounts.get(account, 0), "path": path, "method": method, "own_password_check": False}


def live_child_transport_trace(accounts):
    first, second = (account["user"] for account in accounts)
    return f'''    traceKey = textValue(m.key)
    if bearer <> "" then traceKey = ""
    traceAccount = 0
    if traceKey = {json.dumps(first["api_key"])} then traceAccount = {int(first["id"])}
    if traceKey = {json.dumps(second["api_key"])} then traceAccount = {int(second["id"])}
    tracePath = "/non-api"
    traceStart = instr(1, url, "/api/")
    if traceStart > 0 then tracePath = mid(url, traceStart)
    traceQuery = instr(1, tracePath, "?")
    if traceQuery > 0 then tracePath = left(tracePath, traceQuery - 1)
    if left(tracePath, 32) = "/api/accounts/users/me/app-data/" and len(tracePath) > 32 then tracePath = "/api/accounts/users/me/app-data/<app>/"
    print "[picker-launch] "; FormatJson({{kind: "live-request", path: tracePath, method: method, account: traceAccount}})
'''


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


def vod_view_fixture(title, year):
    if not re.fullmatch(r"[A-Za-z0-9 -]{1,120}", title) or not re.fullmatch(r"[0-9]{4}", year):
        raise ValueError("Use a bounded plain-text movie title and four-digit year")
    view = (ROOT / "tests/native/ProfileVodViewFixture.brs").read_text()
    return view.replace('"Sintel"', json.dumps(title)).replace('"sintel"', json.dumps(title.lower())).replace('item.year = "2010"', f'item.year = {json.dumps(year)}')


def instrument_protected_child_picker(name, body):
    """Patch only the disposable ZIP. Emit literal labels, comparisons and flags."""
    def edit(anchor, replacement):
        nonlocal body
        anchor = anchor.encode()
        require_patch_anchor(name, body, anchor)
        body = body.replace(anchor, replacement.encode(), 1)

    if name == "components/ProfilePickerNavigation.brs":
        edit('''    context = m.profileStartupSelectionContext
    if context = invalid or m.profileStartupTask <> invalid then return
    if not startupProfileTargetAllowed(context) then failStartupProfileSelection("This profile requires protected Child access.") : return''', '''    context = m.profileStartupSelectionContext
    traceAuth = phase = "authenticate"
    if traceAuth then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "scene-admission", context_present: context <> invalid, task_present: m.profileStartupTask <> invalid, picker_owned: m.profilePickerContext <> invalid})
    if context = invalid or m.profileStartupTask <> invalid then return
    targetAllowed = startupProfileTargetAllowed(context)
    if traceAuth then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "target-role", allowed: targetAllowed})
    if not targetAllowed then failStartupProfileSelection("This profile requires protected Child access.") : return''')
        edit('    if task = invalid then task = CreateObject("roSGNode", kind)\n    tagTaskForCurrentUser(task)', '''    if task = invalid then task = CreateObject("roSGNode", kind)
    if traceAuth
        print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "task-created", created: task <> invalid})
        if task <> invalid then task.pickerProbe5fif = true
    end if
    tagTaskForCurrentUser(task)''')
        edit('    task.control = "RUN"\nend sub\n\nsub onStartupProfileState(event as object)\n    if not isCurrentTaskEvent(event, m.profileStartupTask) then return', '''    if traceAuth
        ownerCurrent = taskUserSessionCurrent(task)
        tagged = task.hasField("aeriosession")
        contextCurrent = currentUserSessionId() = context.nonce
        print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "before-run", owned: ownerCurrent and tagged, context_current: contextCurrent})
    end if
    task.control = "RUN"
    if traceAuth then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "run-returned"})
end sub

sub onStartupProfileState(event as object)
    owned = isCurrentTaskEvent(event, m.profileStartupTask)
    node = event.getRoSGNode()
    if node <> invalid and node.hasField("pickerProbe5fif")
        if node.pickerProbe5fif = true
            observed = "other"
            value = event.getData()
            if value = "run" or value = "done" or value = "stop" or value = "init" then observed = value
            print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "task-state", state: observed, owned: owned})
        end if
    end if
    if not owned then return''')
    elif name == "components/ProfilePinNavigation.brs":
        anchor = '''    if not checked.verified
        updateProfilePinFeedback(checked)
        return
    end if
    profile = context.profile
    m.profileUnlockGrant = {slot: context.slot, id: profile.id, pinType: profile.pinType, pinHash: profile.pinHash, pinSalt: profile.pinSalt}
'''
        edit(anchor, anchor + '''    if startupSelection and m.pickerProbeMode = "child-select-pin" then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "pin-accepted"})
''')
    elif name == "components/DispatcharrTask.xml":
        edit('  <interface>', '  <interface>\n    <field id="pickerProbe5fif" type="boolean" value="false" />')
    elif name == "components/DispatcharrTask.brs":
        edit('sub loadChannels()\n', '''sub loadChannels()
    if m.top.pickerProbe5fif = true then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "task-entry", cancelled: m.top.cancelRequested = true})
''')
    elif name == "source/UserProfileStartupSelection.brs":
        edit('''    if not userProfileStartupSelectionStorageCurrent(registry, context, activeNonce, activeScope, activeKey, memoryKeys, requirePin) then return false
    return requestGateAccessAllowed(context.connection.url, context.key)''', '''    storageCurrent = userProfileStartupSelectionStorageCurrent(registry, context, activeNonce, activeScope, activeKey, memoryKeys, requirePin)
    traceAccess = m.pickerProbeMode = "child-select-pin" and (context.phase = "pin" or context.phase = "authenticate")
    if traceAccess then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "storage-current", owned: storageCurrent, protected_check: requirePin})
    if not storageCurrent then return false
    return requestGateAccessAllowed(context.connection.url, context.key, traceAccess)''')
    elif name == "source/RequestGateClient.brs":
        edit('''function requestGateAccessAllowed(url as string, key as string) as boolean
    if not requestGateTaskSessionCurrent() then return false
    broker = requestGateBroker()
    if broker = invalid then return not requestGateMandatory()
    if not broker.ready then return false
    state = broker.snapshot
    if type(state) <> "roAssociativeArray" then return false
    hash = requestGateCredentialHash(key)
    if key <> "" and hash = "" then return false
    permit = requestGatePermit(state, requestGateServer(url), hash, CreateObject("roDateTime").asSeconds(), false)
    return permit.allowed
end function''', '''function requestGateAccessAllowed(url as string, key as string, traceAccess = false as boolean) as boolean
    if not requestGateTaskSessionCurrent() then return pickerProbe5fifAccess(traceAccess, false, "stale-session")
    broker = requestGateBroker()
    if broker = invalid then return pickerProbe5fifAccess(traceAccess, not requestGateMandatory(), "broker-missing")
    if not broker.ready then return pickerProbe5fifAccess(traceAccess, false, "broker-not-ready")
    state = broker.snapshot
    if type(state) <> "roAssociativeArray" then return pickerProbe5fifAccess(traceAccess, false, "snapshot-unavailable")
    hash = requestGateCredentialHash(key)
    if key <> "" and hash = "" then return pickerProbe5fifAccess(traceAccess, false, "credential-digest-unavailable")
    permit = requestGatePermit(state, requestGateServer(url), hash, CreateObject("roDateTime").asSeconds(), false)
    return pickerProbe5fifAccess(traceAccess, permit.allowed, pickerProbe5fifGateReason(permit.allowed, permit.reason))
end function

function pickerProbe5fifAccess(traceAccess as boolean, allowed as boolean, verdict as string) as boolean
    if traceAccess then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "scene-broker-snapshot", allowed: allowed, verdict: verdict})
    return allowed
end function

function pickerProbe5fifGateReason(allowed as boolean, reason as dynamic) as string
    if allowed then return "allowed"
    if GetInterface(reason, "ifString") = invalid then return "other"
    if reason = "rejected-key" then return "credential-held"
    if reason = "parked" then return "parked"
    if reason = "capacity" then return "capacity"
    if reason = "invalid-context" then return "invalid-context"
    if reason = "stale-session" then return "stale-session"
    if reason = "gate-unavailable" then return "gate-unavailable"
    return "other"
end function

function pickerProbe5fifTask() as boolean
    if type(m.top) <> "roSGNode" then return false
    if not m.top.hasField("pickerProbe5fif") then return false
    return m.top.pickerProbe5fif = true
end function''')
        edit('    if broker = invalid\n        if requestGateMandatory() then return denied', '''    if broker = invalid
        if pickerProbe5fifTask() then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "broker-missing"})
        if requestGateMandatory() then return denied''')
        edit('    if not broker.ready then return denied\n    hash = requestGateCredentialHash(key)', '''    if not broker.ready
        if pickerProbe5fifTask() then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "broker-not-ready"})
        return denied
    end if
    if pickerProbe5fifTask() then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "broker-ready"})
    hash = requestGateCredentialHash(key)''')
        edit('    if key <> "" and hash = "" then return denied\n    ticket = CreateObject("roSGNode", "RequestGateTicket")', '''    if key <> "" and hash = ""
        if pickerProbe5fifTask() then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "credential-digest-unavailable"})
        return denied
    end if
    ticket = CreateObject("roSGNode", "RequestGateTicket")''')
        edit('    result = requestGateExchange(broker, ticket)\n    if result = invalid then return denied', '''    result = requestGateExchange(broker, ticket)
    if result = invalid
        if pickerProbe5fifTask() then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "broker-no-reply"})
        return denied
    end if''')
    elif name == "source/HttpTransport.brs":
        edit('    permit = requestGateAcquire(url, key)\n', '''    traceAcquire = pickerProbe5fifTask()
    if traceAcquire then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "acquire-enter"})
    permit = requestGateAcquire(url, key)
    if traceAcquire
        verdict = pickerProbe5fifGateReason(permit.allowed, permit.reason)
        print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "permit-decision", verdict: verdict})
    end if
''')
        edit('    if not started then result.error = "network"', '''    if pickerProbe5fifTask() then print "[picker-launch] "; FormatJson({kind: "startup-diagnostic", stage: "transfer-start", started: started})
    if not started then result.error = "network"''')
    return body


def build(path, normal, section, base, mode="plain", baseline_accounts=None, admin_ui=False, phone_verify=False, phone_import=False, phone_import_add=False, profile_media=False, peer_envelope=None, peer_material=None, profile_vod=False, vod_title="Sintel", vod_year="2010"):
    if sum([admin_ui, phone_verify, phone_import, profile_media]) > 1:
        raise ValueError("Choose one focused native flow")
    if (phone_verify or phone_import or profile_media) and not baseline_accounts:
        raise ValueError("Phone verification needs private authorized test accounts")
    ordinary_live = baseline_accounts and not (admin_ui or phone_verify or phone_import or profile_media)
    required = list(PICKER_ENTRIES)
    if mode == "child-select-pin":
        required.extend(PROTECTED_PICKER_ENTRIES)
    if mode in ("back", "cold-link"):
        required.append("source/Main.brs")
    if mode == "back":
        required.append("components/AerioScene.xml")
    if mode == "reorder":
        required.append("components/ProfilePickerManagementNavigation.brs")
    if ordinary_live:
        required.append("source/HttpTransport.brs")
    if admin_ui:
        required.extend(("components/ProfileServerAdminTask.brs", "components/ProfileServerAdminNavigation.brs"))
    if phone_import:
        required.extend(("components/DispatcharrSyncWriteTask.brs", "components/DispatcharrTask.brs"))
    if profile_media:
        required.extend(("components/DvrView.xml", "components/DvrView.brs", "components/OnDemandPlayer.xml", "components/OnDemandPlayer.brs"))
    if profile_vod:
        required.extend(("components/VodView.xml", "components/VodView.brs"))
    with zipfile.ZipFile(normal) as original:
        entries = Counter(original.namelist())
        for name in dict.fromkeys(required):
            if entries[name] != 1:
                raise ValueError(f"{name}: expected one required ZIP entry, found {entries[name]}")
        # Work beside the destination for an atomic publish after every patch
        # validates and the ZIP closes. Do not expose a half-instrumented ZIP.
        with tempfile.TemporaryDirectory(prefix=".picker-probe-", dir=Path(path).parent) as directory:
            candidate = Path(directory) / "probe.zip"
            write_picker_archive(candidate, original, section, base, mode, baseline_accounts, ordinary_live, admin_ui, phone_verify, phone_import, phone_import_add, profile_media, peer_envelope, peer_material, profile_vod, vod_title, vod_year)
            candidate.replace(path)


def write_picker_archive(path, original, section, base, mode, baseline_accounts, ordinary_live, admin_ui, phone_verify, phone_import, phone_import_add, profile_media, peer_envelope, peer_material, profile_vod, vod_title, vod_year):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == "manifest":
                require_patch_anchor(name, body, b"title=AerioTV\n")
                body = body.replace(b"title=AerioTV\n", b"title=Aerio Startup Picker Probe\n")
                body += b"\naeriotv_picker_launch_probe=1\n"
                if mode == "baseline":
                    body += b"\naeriotv_profiles_baseline=1\n"
            elif name == "source/MetadataCacheStore.brs":
                require_patch_anchor(name, body, b'"cachefs:/aeriotv-metadata-v1"')
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/picker-launch-cache"')
            elif name == "source/HttpTransport.brs" and ordinary_live:
                anchor = b"    method = ucase(method)"
                require_patch_anchor(name, body, anchor)
                trace = live_child_transport_trace(baseline_accounts).encode() if mode == "child-select-pin" else b""
                body = body.replace(anchor, anchor + b'''
    ' Private qualification permits authenticating only at the token route.
    if method <> "GET" or body <> invalid or checkedJson <> invalid
        if (method <> "GET" and method <> "POST") or right(url, 20) <> "/api/accounts/token/"
            print "[picker-launch] "; "{""kind"":""blocked-network-mutation""}"
            result.error = "qualification-read-only"
            return result
        end if
    end if
''' + trace, 1)
            elif name == "components/AerioScene.brs":
                source = body.decode()
                if mode.startswith("child-"):
                    require_patch_anchor(name, source, '    m.profileChildAccessReady = false')
                    source = source.replace('    m.profileChildAccessReady = false', '    m.profileChildAccessReady = true', 1)
                require_patch_anchor(name, source, "m.profilePickerReady = false")
                source = source.replace("m.profilePickerReady = false", "m.profilePickerReady = true", 1)
                target = '    m.registry = CreateObject("roRegistrySection", "AerioTV")'
                require_patch_anchor(name, source, target)
                source = source.replace(target, f'    m.registry = CreateObject("roRegistrySection", "{section}")\n    seedProfilePickerLaunchProbe({json.dumps(base)}, {json.dumps(mode)})', 1)
                if phone_import:
                    # Protected synthetic phone imports must never upload their
                    # fixture PIN/roster to the real approved accounts.
                    anchor = f'    seedProfilePickerLaunchProbe({json.dumps(base)}, {json.dumps(mode)})'
                    require_patch_anchor(name, source, anchor)
                    source = source.replace(anchor, anchor + '\n    m.profileSyncWriterReady = false\n    m.profileSyncSchedulingReady = false', 1)
                # Keep private input interception after the deferred startup
                # guard, without changing cold/warm classification or routing.
                target = (
                    "sub onLaunchRequest()\n"
                    "    raw = m.top.launchRequest\n"
                    "    cold = m.top.launchFromMain = true and m.coldLaunchEligible = true\n"
                    "    if m.profileStartupDeferred = true then return\n"
                )
                require_patch_anchor(name, source, target)
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
                require_patch_anchor(name, source, target)
                if mode == "back":
                    target = "            cancelStartupProfileTask()\n            closeUserProfileLaunchPicker()\n            m.top.exitRequested = true"
                    require_patch_anchor(name, source, target)
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
                    if peer_envelope:
                        slot = json.loads(Path(peer_material).read_text())["expectedPlaylistId"].lower()
                        fixture = fixture.replace('"phone-import"', json.dumps(slot))
                if profile_media:
                    fixture = fixture.replace('sub onProfileBaselineProbeTick()\n', 'sub onProfileBaselineProbeTick()\n    onProfileMediaAcceptanceTick()\n    return\n', 1)
                    fixture += "\n" + (ROOT / ("tests/native/ProfileVodAcceptanceFixture.brs" if profile_vod else "tests/native/ProfileMediaAcceptanceFixture.brs")).read_text()
                if baseline_accounts:
                    fixture = real_baseline_fixture(fixture, baseline_accounts)
                    if mode == "child-select-pin":
                        live = '    m.pickerProbeLiveAccount = ""'
                        require_patch_anchor(name, fixture, live)
                        fixture = fixture.replace(live, f'    m.pickerProbeLiveAccount = "{int(baseline_accounts[1]["user"]["id"])}"', 1)
                body = (source + "\n" + fixture).encode()
            elif name == "components/ProfileServerAdminTask.brs" and admin_ui:
                text = body.decode()
                require_patch_anchor(name, text, "function profileAdminRequest(")
                start = text.index("function profileAdminRequest(")
                end = text.index("end function", start) + len("end function")
                text = text[:start] + (ROOT / "tests/native/ProfileServerAdminTransportFixture.brs").read_text() + text[end:]
                body = text.encode()
            elif name == "components/DispatcharrSyncWriteTask.brs" and phone_import:
                # The normal baseline now has qualified Sync. Phone fixtures
                # carry test PINs and must remain read-only even after consent.
                line = b'    if CreateObject("roAppInfo").getValue("aeriotv_profiles_baseline") = "1" then m.syncWriterReady = true'
                require_patch_anchor(name, body, line)
                body = body.replace(line, b"    ' Private phone qualification never enables PUT.", 1)
            elif name == "components/DispatcharrTask.brs" and phone_import:
                text = body.decode()
                target = 'sub publishError(message as string, relogin = false as boolean, apiAccessRequired = false as boolean)\n'
                require_patch_anchor(name, text, target)
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
                require_patch_anchor(name, text, target)
                text = text.replace(target, '    if result.ok <> true then print "[picker-launch] "; FormatJson({kind: "admin-ui-error", operation: context.operation, reason: result.reason})\n' + target)
                body = text.encode()
            elif name == "components/AerioScene.xml" and mode == "back":
                require_patch_anchor(name, body, b"<interface>")
                body = body.replace(b"<interface>", b'<interface><field id="pickerProbeCancelPassed" type="boolean" value="false" />', 1)
            elif name == "source/Main.brs" and mode == "back":
                target = b"                    screen.close()\n"
                require_patch_anchor(name, body, target)
                body = body.replace(target, b'                    passed = scene.pickerProbeCancelPassed\n' + target + b'                    print "[picker-launch] "; FormatJson({kind: "result", passed: passed, exited: true})\n', 1)
            elif name == "source/Main.brs" and mode == "cold-link":
                target = b'    if type(args) = "roAssociativeArray" then scene.launchRequest = args'
                require_patch_anchor(name, body, target)
                body = body.replace(target, b'    scene.launchRequest = {contentId: "missing-fixture-id", mediaType: "live"}', 1)
            elif name == "source/StartupBeaconModel.brs":
                for beacon in ["AppDialogInitiate", "AppDialogComplete", "AppLaunchComplete"]:
                    target = f'    m.top.signalBeacon("{beacon}")'.encode()
                    require_patch_anchor(name, body, target)
                    body = body.replace(target, f'    print "[picker-launch] "; FormatJson({{kind: "beacon", name: "{beacon}"}})\n'.encode() + target, 1)
            elif name == "components/ProfilePickerNavigation.brs":
                if mode == "identity":
                    target = b"sub beginStartupProfileSelection(targetId as string, ownPin = invalid as dynamic)\n"
                    require_patch_anchor(name, body, target)
                    body = body.replace(target, target + b"    if m.pickerProbeSelectionCount = invalid then m.pickerProbeSelectionCount = 0\n    m.pickerProbeSelectionCount++\n", 1)
                target = b"    m.profilePicker = picker\n"
                require_patch_anchor(name, body, target)
                body = body.replace(target, target + b"    m.pickerProbePickerCount++\n", 1)
                target = b"    m.profileStartupTask = task\n"
                require_patch_anchor(name, body, target)
                phase_event = b'    print "[picker-launch] "; FormatJson({kind: "phase", phase: phase, no_actor: m.activeUserScope = invalid, empty_key: m.apiKey = ""})\n'
                if mode == "import-pin":
                    phase_event = b'''    freshRead = false
    if phase = "read"
        freshRead = textValue(context.readNonce) <> "" and context.readNonce <> textValue(m.pickerProbeLastRead)
        m.pickerProbeLastRead = context.readNonce
    end if
    print "[picker-launch] "; FormatJson({kind: "phase", phase: phase, no_actor: m.activeUserScope = invalid, empty_key: m.apiKey = "", fresh_read: freshRead})
'''
                body = body.replace(target, target + b'    m.pickerProbeTask = task\n' + phase_event, 1)
                if mode == "back":
                    target = b"        m.top.exitRequested = true\n"
                    require_patch_anchor(name, body, target)
                    body = body.replace(target, b"        verifyStartupPickerProbeCancel()\n" + target, 1)
            elif name == "components/ProfilePickerManagementNavigation.brs" and mode == "reorder":
                target = b"    m.profilePickerReorderContext = context\n"
                require_patch_anchor(name, body, target)
                body = body.replace(target, target + b'    print "[picker-launch] "; FormatJson({kind: "reorder-held", passed: m.profilePickerReorderDialog = invalid and m.top.dialog = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.profileStartupTask = invalid})\n', 1)
            elif name == "components/GuideView.xml":
                require_patch_anchor(name, body, b"</interface>")
                body = body.replace(b"</interface>", b'<function name="profilePickerProbeLineup" /><function name="profilePickerProbeRole" /></interface>', 1)
            elif name == "components/GuideView.brs":
                body += b'\nfunction profilePickerProbeLineup() as string\n    if type(m.channels) <> "roArray" then return ""\n    if m.channels.count() = 0 then return ""\n    return m.channels[0].id\nend function\n'
                body += b'\nfunction profilePickerProbeRole() as string\n    return m.userRole\nend function\n'
            elif name == "components/VodView.xml" and profile_vod:
                require_patch_anchor(name, body, b"</interface>")
                body = body.replace(b"</interface>", b'<function name="profileVodAcceptanceState" /><function name="profileVodAcceptanceAction" /></interface>', 1)
            elif name == "components/VodView.brs" and profile_vod:
                body += b"\n" + vod_view_fixture(vod_title, vod_year).encode()
            elif name == "components/DvrView.xml" and profile_media:
                require_patch_anchor(name, body, b"</interface>")
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
            elif name == "components/OnDemandPlayer.xml" and profile_media:
                require_patch_anchor(name, body, b"</interface>")
                body = body.replace(b"</interface>", b'<function name="profileMediaAcceptanceState" /></interface>', 1)
            elif name == "components/OnDemandPlayer.brs" and profile_media:
                body += b'''
function profileMediaAcceptanceState() as object
    allowed = false
    current = false
    key = ""
    if type(m.top.request) = "roAssociativeArray"
        key = textValue(m.top.request.apiKey)
        current = userEventCurrent(m.top.request)
        allowed = requestGateRenderAllowed(m.top.request.url, m.top.request.apiKey)
    end if
    info = m.video.errorInfo
    diagnostic = {}
    if type(info) = "roAssociativeArray" then diagnostic = {category: textValue(info.category), code: info.errcode, ignored: info.ignored, message: sanitizePlaybackDiagnostic(textValue(info.dbgmsg), key)}
    if m.profileMediaAcceptanceMonitor = invalid then m.profileMediaAcceptanceMonitor = CreateObject("roAppMemoryMonitor")
    return {state: m.video.state, position: m.video.position, duration: m.video.duration, visible: m.top.visible, session: m.session <> invalid, current: current, allowed: allowed, errorCode: m.video.errorCode, errorStr: sanitizePlaybackDiagnostic(m.video.errorStr, key), nativeError: diagnostic, memoryPercent: m.profileMediaAcceptanceMonitor.getMemoryLimitPercent()}
end function
'''
            if mode == "child-select-pin":
                body = instrument_protected_child_picker(name, body)
            package.writestr(name, body)
        if phone_verify or phone_import:
            second = baseline_accounts[1]
            package.writestr("fixtures/phone-profile-verify.json", json.dumps({"userId": second["user"]["id"], "username": second["user"]["username"], "apiKey": second["user"]["api_key"], "password": second["password"], "addOnboarding": phone_import_add}))
        if peer_envelope:
            package.writestr("peer-envelope.json", Path(peer_envelope).read_bytes())
            package.writestr("peer-material.json", Path(peer_material).read_bytes())
            package.writestr("components/PeerSetupDecodeTask.xml", '''<component name="PeerSetupDecodeTask" extends="Task"><interface><field id="result" type="assocarray" /></interface><script uri="pkg:/source/PhoneSetupModel.brs" /><script uri="pkg:/source/PhoneSetupTransport.brs" /><script uri="pkg:/source/PhoneSetupCrypto.brs" /><script uri="pkg:/source/PhoneSetupX25519.brs" /><script uri="PeerSetupDecodeTask.brs" /></component>''')
            package.writestr("components/PeerSetupDecodeTask.brs", '''sub init()
    m.top.functionName = "decodePeerSetup"
end sub
sub decodePeerSetup()
    m.top.result = phoneSetupOpen(ReadAsciiFile("pkg:/peer-envelope.json"), ParseJson(ReadAsciiFile("pkg:/peer-material.json")))
end sub
''')


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
    parser.add_argument("--profile-vod", action="store_true", help="Populated Movies/Series and representative movie playback before/after own-account switching")
    parser.add_argument("--vod-title", default="Sintel", help="Representative title for --profile-vod")
    parser.add_argument("--vod-year", default="2010", help="Representative release year for --profile-vod")
    parser.add_argument("--peer-envelope", type=Path, help="Private actual-peer encrypted setup envelope; only with --phone-import")
    parser.add_argument("--peer-material", type=Path, help="Private test receiver material; never enables production entropy")
    parser.add_argument("--dispatcharr-credentials", type=Path, help="Private JSON: baseUrl and two accounts with username/password; implies baseline, read-only server testing")
    parser.add_argument("--mode", choices=["plain", "pin", "import-pin", "back", "reject", "identity", "cold-link", "warm-link", "warm-pin-link", "warm-auth-link", "warm-import-pin-link", "warm-load-link", "own-keyless", "own-pin", "own-held", "own-cancel", "own-link", "own-pin-link", "own-auth-link", "own-default", "own-default-pin", "own-wrong", "own-recreated", "own-memory", "own-keyboard", "child-select", "child-select-pin", "child-select-reject", "child-select-link", "reorder"], default="plain")
    args = parser.parse_args()
    if args.profile_vod:
        args.profile_media = True
        vod_view_fixture(args.vod_title, args.vod_year)
    if args.phone_import_add:
        args.phone_import = True
    if bool(args.peer_envelope) != bool(args.peer_material) or (args.peer_envelope and (not args.phone_import or args.phone_import_add)):
        parser.error("Peer envelope/material require --phone-import without --phone-import-add")
    for private in [args.peer_envelope, args.peer_material]:
        if private and private.resolve().is_relative_to(ROOT):
            parser.error("Peer secret material must remain outside the checkout")
    baseline_accounts = None
    if (args.admin_ui or args.phone_verify or args.phone_import or args.profile_media) and not args.dispatcharr_credentials:
        parser.error("Focused account flows require --dispatcharr-credentials")
    if sum([args.admin_ui, args.phone_verify, args.phone_import, args.profile_media]) > 1:
        parser.error("Choose one focused native flow")
    real_base = None
    if args.dispatcharr_credentials:
        if args.dispatcharr_credentials.resolve().is_relative_to(ROOT):
            raise RuntimeError("Keep real test credentials outside the repository")
        args.baseline = args.mode != "child-select-pin"
        if not args.baseline and any([args.admin_ui, args.phone_verify, args.phone_import, args.profile_media]):
            parser.error("Live child-select-pin is its own focused flow")
        real_base, baseline_accounts = real_baseline_accounts(json.loads(args.dispatcharr_credentials.read_text()))
    live_accounts = {}
    if baseline_accounts and not args.baseline:
        live_accounts = {int(account["user"]["id"]): label for account, label in zip(baseline_accounts, [7, 8])}
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
    build(archive, ROOT / "out/aeriotv-roku.zip", section, real_base or f"http://{local}:{server.server_port}", "baseline" if args.baseline else args.mode, baseline_accounts, admin_ui=args.admin_ui, phone_verify=args.phone_verify, phone_import=args.phone_import, phone_import_add=args.phone_import_add, profile_media=args.profile_media, peer_envelope=args.peer_envelope, peer_material=args.peer_material, profile_vod=args.profile_vod, vod_title=args.vod_title, vod_year=args.vod_year)
    modules["recovery"].cleanup_package(cleaner, section)
    report = {"passed": False, "mode": args.mode, "events": [], "keys": [], "restore_sha256": hashlib.sha256(restore.read_bytes()).hexdigest(), "probe_sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
    report["private_registry_section"] = section
    if args.profile_vod:
        report["representative_movie"] = {"title": args.vod_title, "year": args.vod_year}
    process = None

    def run(path, marker, prefix):
        return subprocess.run(["python3", "scripts/run-native-probe.py", str(path), "--prefix", prefix, "--marker", marker, "--timeout", "45"], cwd=ROOT, capture_output=True, text=True, timeout=100)

    try:
        process = subprocess.Popen(["python3", "scripts/run-native-probe.py", str(archive), "--prefix", "[picker-launch]", "--marker", '"kind":"result"', "--timeout", "180" if baseline_accounts else "75"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            event = record_picker_output(report, line, protected=args.mode == "child-select-pin" and not args.baseline)
            if event is None:
                continue
            if event["kind"] == "live-request":
                hit = live_request_hit(event, live_accounts)
                hits.append(hit if hit is not None else {"method": "invalid-trace", "unexpected": True})
                continue
            if event["kind"] == "profile-vod-visual":
                image = str(Path(args.report).with_suffix(f'.account-{event["account"]}-{event["view"]}.jpg'))
                captured = subprocess.run(["python3", "scripts/capture-roku-screenshot.py", "--developer-mode", "--output", image], cwd=ROOT, capture_output=True, timeout=40)
                entry = {"account": event["account"], "view": event["view"], "captured": captured.returncode == 0, "path": image}
                report.setdefault("vod_visuals", []).append(entry)
                request = urllib.request.Request(f"http://{host}:8060/input?pickerProbeVisualCaptured=1", data=b"", method="POST")
                with urllib.request.urlopen(request, timeout=3) as response:
                    entry["ack"] = response.status
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
            reads = [event["fresh_read"] for event in phases if event["phase"] == "read"]
            pin_ok = pin_ok and reads == [True, True] and paths.count("/api/accounts/users/me/app-data/synthetic8.aeriotv/") == 2
        wanted_keys = [200] if args.mode in ["own-default", "own-default-pin"] else [200, 200]
        report["passed"] = code == 0 and bool(events) and events[-1].get("passed") is True and report.get("pre_selection_requests") == [] and report.get("screenshot") is True and [k.get("status") for k in report["keys"]] == wanted_keys and [p["phase"] for p in phases] == expected_phases and all(p["no_actor"] and p["empty_key"] for p in phases) and all(h.get("user") == target_user and h["method"] == "GET" for h in hits) and listing >= 2 and heavy > listing and paths.count("/api/accounts/users/me/") >= 3 and pin_ok
        if args.mode in ["child-select", "child-select-pin"]:
            app_reads = 1 if live_accounts else paths.count("/api/accounts/users/me/app-data/synthetic8.aeriotv/")
            report["passed"] = report["passed"] and report.get("child_guide_screenshot") is True and app_reads == 1
            if live_accounts:
                report["real_dispatcharr"] = True
                report["passed"] = report["passed"] and events[-1].get("live") is True
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
            elif args.profile_media:
                report["media_transport"] = "actual-own-account-playback"
                report["passed"] = report["passed"] and all(events[-1].get(field) is True for field in ["profilemedia", "sourceplayed", "targetplayed"])
                if args.profile_vod:
                    visuals = report.get("vod_visuals", [])
                    report["passed"] = report["passed"] and events[-1].get("profilevod") is True and [(v["account"], v["view"]) for v in visuals] == [(a, view) for a in [1, 2] for view in ["movies", "series", "playing"]] and all(v["captured"] and v.get("ack") == 200 for v in visuals)
            else:
                report["passed"] = report["passed"] and report.get("switcher_screenshot") is True and report.get("switcher_visual_ack") == 200
                report["real_dispatcharr"] = True
        report["passed"] = report["passed"] and report["ready_events_valid"] and not any(
            event.get("kind") == "blocked-network-mutation" for event in events)
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
