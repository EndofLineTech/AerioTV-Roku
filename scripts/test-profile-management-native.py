"""Private normal-app profile metadata and adult-purpose native-dialog probe."""
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
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output, normal, section, base, directions=False):
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'manifest':
                body = body.replace(b'title=AerioTV\n', b'title=Aerio Profile Management Probe\n')
                if directions:
                    body += b'\naeriotv_profile_directions_test=1\n'
            if name == 'source/MetadataCacheStore.brs':
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/profile-management-cache"')
            if name == 'components/AerioScene.brs':
                source = body.decode()
                target = 'm.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert source.count(target) == 1
                source = source.replace(target, f'''m.registry = CreateObject("roRegistrySection", "{section}")
    entry = normalizeConnectionEntry({{id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "{base}", accountId: "7", remember: true}})
    m.registry.write("connectionsV1", FormatJson({{schema: 1, selected: "slot-a", entries: [entry]}}))
    m.registry.write("connKey_slot-a", "synthetic-a")
    m.registry.flush()''', 1)
                target = '    m.guide.config = {\n'
                assert source.count(target) == 1
                source = source.replace(target, '''    m.managementProbeClock = m.top.createChild("Timer")
    m.managementProbeClock.duration = 1
    m.managementProbeClock.repeat = true
    m.managementProbeClock.observeField("fire", "onManagementProbeTick")
    m.managementProbePhase = 0
    m.managementProbeClock.control = "start"
''' + target, 1)
                source += '''
function managementProbeEvent(node as object, index as integer) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.index
    end function}
end function

sub onManagementProbeTick()
    m.managementProbePhase++
    phase = m.managementProbePhase
    if phase = 1
        store = loadUserProfileStore(m.registry, m.selectedConnectionId)
        adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        adult.isDefault = false
        adult.order = 1
        adult.pinType = "numbers"
        adult.pinSalt = string(32, "b")
        adult.pinHash = userProfilePinHash(adult.pinSalt, "1234")
        store.profiles.push(adult)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        openUserProfileManagement()
        print "[profile-management] "; FormatJson({kind: "roster", dialog: m.profileManagementDialog <> invalid, choices: m.profileManagementChoices.count()})
    else if phase = 2
        onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
    else if phase = 3
        onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
        print "[profile-management] "; FormatJson({kind: "keyboard", native: m.profileManagementDialog.subtype() = "StandardKeyboardDialog"})
    else if phase = 4
        m.profileManagementDialog.text = "Renamed Synthetic"
        onProfileManagementName(managementProbeEvent(m.profileManagementDialog, 0))
        store = loadUserProfileStore(m.registry, "slot-a")
        m.managementProbeRenamed = store.profiles[0].displayName = "Renamed Synthetic" and store.profiles[0].displayNameClaimed
        closeProfileManagementDialog()
        m.profileManagementPending = {id: store.profiles[0].id}
        beginAdultProfilePinGate()
        print "[profile-management] "; FormatJson({kind: "adult", native: m.adultPinDialog.subtype() = "StandardPinPadDialog", title: m.adultPinDialog.title, covered: m.profileGateCover.visible})
    else if phase = 5
        m.adultPinDialog.textEditBox.text = "9999"
        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
        m.managementProbeWrong = m.profileManagementGrant = invalid and m.adultPinDialog.textEditBox.text = "" and m.adultPinDialog.title = "Wrong PIN"
    else if phase = 6
        m.adultPinDialog.textEditBox.text = "1234"
        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
        store = loadUserProfileStore(m.registry, "slot-a")
        m.managementProbeEvidence = {kind: "result", renamed: m.managementProbeRenamed, wrong: m.managementProbeWrong, grant: userProfileManagementGrantMatches(store, invalid, m.profileManagementGrant, m.profileManagementNonce, true), learned: store.profiles[1].pinLength = 4, management: m.profileManagementDialog <> invalid, uncovered: not m.profileGateCover.visible, preserved: m.registry.read("connKey_slot-a") = "synthetic-a", no_unlock: m.profileUnlockGrant = invalid}
    else if phase = 7
        closeProfileManagementDialog()
        beginAdultProfilePinGate()
    else if phase = 8
        print "[profile-management] "; FormatJson({kind: "cancel-ready", covered: m.profileGateCover.visible})
    else if phase = 10
        m.managementProbeClock.control = "stop"
        m.managementProbeEvidence.cancelled = m.adultPinDialog = invalid and m.profileManagementGrant = invalid and not m.profileGateCover.visible and not m.global.profilegateclosed and m.top.exitRequested <> true
        m.managementProbeEvidence.cancel_dialog = m.adultPinDialog = invalid
        m.managementProbeEvidence.cancel_grant = m.profileManagementGrant = invalid
        m.managementProbeEvidence.cancel_cover = m.profileGateCover.visible
        m.managementProbeEvidence.cancel_closed = m.global.profilegateclosed
        m.managementProbeEvidence.cancel_exit = m.top.exitRequested
        print "[profile-management] "; FormatJson(m.managementProbeEvidence)
    end if
end sub
'''
                if directions:
                    source = source.replace('adult.pinType = "numbers"', 'adult.pinType = "directions"').replace('userProfilePinHash(adult.pinSalt, "1234")', 'userProfilePinHash(adult.pinSalt, "UDLR")')
                    source = source.replace('store.profiles.push(adult)', '''store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "numbers")
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinSalt", adult.pinSalt)
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinHash", userProfilePinHash(adult.pinSalt, "5678"))
        store.profiles.push(adult)''')
                    source = source.replace('        beginAdultProfilePinGate()\n', '        beginAdultProfilePinGate()\n        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 1))\n')
                    source = source.replace('m.adultPinDialog.subtype() = "StandardPinPadDialog"', 'm.adultPinDialog.subtype() = "DirectionsPinPad"')
                    source = source.replace('text = "9999"', 'text = "UUUU"').replace('text = "1234"', 'text = "UDLR"')
                body = source.encode()
            package.writestr(name, body)
        package.writestr('profile-management-probe.json', json.dumps({'synthetic': True}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--directions', action='store_true', help='Exercise numeric-to-Directions adult-type selection under developer opt-in')
    args = parser.parse_args()
    host, password = os.environ['ROKU_HOST'], os.environ['ROKU_DEV_PASSWORD']
    modules = {}
    for key in ['primitives', 'recovery']:
        spec = importlib.util.spec_from_file_location(key, ROOT / 'scripts' / f'test-profile-{key}-native.py')
        modules[key] = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modules[key])
    restore = Path(args.restore)
    checksum = hashlib.md5(restore.read_bytes()).hexdigest()
    if modules['primitives'].installed_md5(host, password) != checksum:
        raise RuntimeError('Restore ZIP differs from installed app')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            value = []
            if self.path == '/api/accounts/users/me/':
                value = {'id': 7, 'username': 'Synthetic7', 'user_level': 1}
            if self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
            body = json.dumps(value).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioManagementProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-management-probe.zip'
    cleaner = ROOT / 'out/profile-management-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}', args.directions)
    modules['recovery'].cleanup_package(cleaner, section)
    report = {'passed': False}

    def run(path, marker, prefix='[profile-management]'):
        command = ['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '45']
        if path != archive:
            return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=100)
        output = []
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
            for line in process.stdout:
                output.append(line)
                if '"kind":"cancel-ready"' in line:
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                    urllib.request.urlopen(request, timeout=10).close()
            stderr = process.stderr.read()
            return subprocess.CompletedProcess(command, process.wait(timeout=100), ''.join(output), stderr)

    try:
        result = run(archive, '"kind":"result"')
        print(result.stdout, end='', flush=True)
        rows = [json.loads(line.split('[profile-management] ', 1)[1]) for line in result.stdout.splitlines() if '[profile-management] {' in line]
        report['events'] = rows
        report['passed'] = result.returncode == 0 and len(rows) == 5 and rows[0].get('dialog') and rows[1].get('native') and rows[2].get('native') and rows[2].get('covered') and all(rows[4].get(key) for key in ['renamed', 'wrong', 'grant', 'learned', 'management', 'uncovered', 'preserved', 'no_unlock', 'cancelled'])
        if not report['passed']:
            raise RuntimeError('Native management controller assertions failed')
    finally:
        try:
            cleaned = run(cleaner, '[profile-recovery] cleanup=', '[profile-recovery]')
            report['cleaned'] = cleaned.returncode == 0 and '[profile-recovery] cleanup=true' in cleaned.stdout
        finally:
            restored = run(restore, 'Running dev')
            report['restored'] = restored.returncode == 0 and modules['primitives'].installed_md5(host, password) == checksum
            server.shutdown()
            server.server_close()
            report['passed'] = report['passed'] and report.get('cleaned', False) and report['restored']
            name = 'profile-management-directions-native.json' if args.directions else 'profile-management-native.json'
            (ROOT / 'out' / name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
