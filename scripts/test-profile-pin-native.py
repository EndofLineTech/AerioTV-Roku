"""Normal-app numeric launch protection using a private registry and real pad."""
import argparse
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
import time
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output, normal, section, base, imported=False, old_os=False):
    salt = 'bb' * 16
    digest = hashlib.sha256(bytes.fromhex(salt) + b'1234').hexdigest()
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'manifest':
                body = body.replace(b'title=AerioTV\n', b'title=Aerio Profile PIN Probe\n')
            if name == 'source/Main.brs':
                body = body.replace(b'sub Main(args as dynamic)', b'sub Main(args as dynamic)\n    print "[profile-pin] stage=main"', 1)
                body = body.replace(b'    scene.observeField("exitRequested", port)', b'    observed = scene.observeField("exitRequested", port)\n    print "[profile-pin] exit-observed="; observed', 1)
                body = body.replace(b'        event = wait(0, port)', b'        event = wait(0, port)\n        print "[profile-pin] main-event="; type(event)\n        if type(event) = "roSGNodeEvent" then print "[profile-pin] main-field="; event.getField(); " data="; event.getData()', 1)
                body = body.replace(b'                    screen.close()', b'                    print "[profile-pin] exit-main"\n                    screen.close()', 1)
            if name == 'components/AerioScene.brs':
                source = body.decode()
                source = source.replace('sub init()', 'sub init()\n    print "[profile-pin] stage=scene"', 1)
                if old_os:
                    source = source.replace('userProfileRuntimeSupported(CreateObject("roDeviceInfo").getOSVersion())', 'userProfileRuntimeSupported({major: "14", minor: "5"})', 1)
                    target_os = '        m.top.setFocus(true)\n        return'
                    assert target_os in source
                    source = source.replace(target_os, '''        m.top.setFocus(true)
        clock = m.top.createChild("Timer")
        clock.duration = 1
        clock.observeField("fire", "onPinRuntimeEvidence")
        clock.control = "start"
        return''', 1)
                    source += '''
sub onPinRuntimeEvidence()
    print "[profile-pin] "; FormatJson({kind: "covered", covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, native: false, runtime_rejected: true, task: m.task <> invalid})
end sub
'''
                target = 'm.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert source.count(target) == 1
                source = source.replace(target, f'''m.registry = CreateObject("roRegistrySection", "{section}")
    entry = normalizeConnectionEntry({{id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "{base}", accountId: "7", remember: true}})
    connections = {{schema: 1, selected: "slot-a", entries: [entry]}}
    profile = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {{id: 7, username: "Synthetic7", user_level: 1}}, 1)
    profile.pinType = "{'none' if imported else 'numbers'}"
    profile.pinHash = "{'' if imported else digest}"
    profile.pinSalt = "{'' if imported else salt}"
    store = defaultUserProfileStore("slot-a")
    store.profiles = [profile]
    store.active = profile.id
    m.registry.write("connectionsV1", FormatJson(connections))
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
    m.registry.write("connKey_slot-a", "synthetic-a")
    m.registry.flush()''', 1)
                source = source.replace('launchGate = selectedUserProfileGate()', 'launchGate = selectedUserProfileGate()\n        print "[profile-pin] gate="; launchGate.reason')
                source = source.replace('    m.guide.config = {', '    print "[profile-pin] "; FormatJson({kind: "guide", covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, account: m.serverAccountId})\n    m.guide.config = {', 1)
                source = source.replace('    m.task.control = "RUN"', '    print "[profile-pin] task-start="; m.task.subtype(); " verify="; m.task.verifyOnly\n    m.task.control = "RUN"')
                body = source.encode()
            if name == 'components/ProfilePinNavigation.brs':
                source = body.decode()
                source = source.replace('    m.top.exitRequested = true', '    m.top.exitRequested = true\n    print "[profile-pin] exit-field-set="; m.top.exitRequested', 1)
                target = '    dialog.setFocus(true)'
                assert source.count(target) == 1
                source = source.replace(target, target + '''
    m.pinFixturePhase = 0
    m.pinFixtureClock = m.top.createChild("Timer")
    m.pinFixtureClock.duration = 1
    m.pinFixtureClock.repeat = true
    m.pinFixtureClock.observeField("fire", "onPinFixtureTick")
    m.pinFixtureClock.control = "start"''', 1)
                source += '''
sub onPinFixtureTick()
    if m.profilePinDialog = invalid
        m.pinFixtureClock.control = "stop"
        return
    end if
    m.pinFixturePhase++
    if m.pinFixturePhase > 38
        m.pinFixtureClock.control = "stop"
        if m.task <> invalid then print "[profile-pin] task-state="; m.task.state; " result="; type(m.task.result); " progress="; m.task.progress; " current="; taskUserSessionCurrent(m.task); " broker="; m.requestGate.state; " ready="; m.requestGate.ready
        return
    end if
    if m.pinFixturePhase = 1
        print "[profile-pin] "; FormatJson({kind: "covered", covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, native: m.profilePinDialog.subtype() = "StandardPinPadDialog", task: m.task <> invalid})
        return
    end if
    if m.pinFixturePhase <= 6
        m.profilePinDialog.textEditBox.text = "9999"
        m.pinFixtureEventNode = m.profilePinDialog
        event = {node: m.pinFixtureEventNode, getRoSGNode: function() as object
            return m.node
        end function
        getData: function() as integer
            return 0
        end function}
        onProfilePinSubmit(event)
        if m.pinFixturePhase = 6
            print "[profile-pin] "; FormatJson({kind: "locked", covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, title: m.profilePinDialog.title, task: m.task <> invalid})
        end if
        return
    end if
    if m.pinFixturePhase = 7
        m.profilePinDialog.textEditBox.text = "1234"
        event = {node: m.pinFixtureEventNode, getRoSGNode: function() as object
            return m.node
        end function
        getData: function() as integer
            return 0
        end function}
        onProfilePinSubmit(event)
        print "[profile-pin] "; FormatJson({kind: "locked-correct", covered: m.profileGateCover.visible, task: m.task <> invalid})
        return
    end if
    if m.pinFixturePhase < 38 then return
    m.profilePinDialog.textEditBox.text = "1234"
    event = {node: m.pinFixtureEventNode, getRoSGNode: function() as object
        return m.node
    end function
    getData: function() as integer
        return 0
    end function}
    onProfilePinSubmit(event)
    print "[profile-pin] "; FormatJson({kind: "unlocked", covered: m.profileGateCover.visible, closed: m.global.profilegateclosed, grant: m.profileUnlockGrant <> invalid, busy: m.busy, credential: m.apiKey <> "", status: m.status})
end sub
'''
                body = source.encode()
            if name == 'components/DispatcharrTask.brs':
                body = body.replace(b'sub loadChannels()', b'sub loadChannels()\n    print "[profile-pin] task-running verify="; m.top.verifyOnly', 1)
            if name == 'source/HttpTransport.brs':
                body = body.replace(b'    permit = requestGateAcquire(url, key)', b'    print "[profile-pin] transport-acquire"\n    permit = requestGateAcquire(url, key)\n    print "[profile-pin] transport-permit="; permit.allowed; " reason="; permit.reason', 1)
                body = body.replace(b'    requestGateReport(permit, result)', b'    print "[profile-pin] transport-finished="; result.status; " error="; result.error\n    requestGateReport(permit, result)', 1)
            if name == 'source/DispatcharrHttp.brs':
                body = body.replace(b'    m.failure = ""', b'    print "[profile-pin] json-enter"\n    m.failure = ""', 1)
            if name == 'source/MetadataCacheStore.brs':
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/profile-pin-fixture-cache"')
            package.writestr(name, body)
        package.writestr('profile-pin-probe.json', json.dumps({'synthetic': True, 'privateRegistry': section}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--imported', action='store_true', help='Discover protection in early own-user roster before any lineup access')
    parser.add_argument('--cancel', action='store_true', help='Press real remote Back on the native launch pad and verify Main exits')
    parser.add_argument('--options', action='store_true', help='With --cancel, press Options before Back to test native pad behavior')
    parser.add_argument('--old-os', action='store_true', help='With --cancel, inject OS14.5 to verify the whole-app runtime fence')
    args = parser.parse_args()
    if args.options and not args.cancel:
        parser.error('--options requires --cancel')
    if args.old_os and not args.cancel:
        parser.error('--old-os requires --cancel')
    host, password = os.environ['ROKU_HOST'], os.environ['ROKU_DEV_PASSWORD']
    modules = {}
    for key, filename in [('primitives', 'test-profile-primitives-native.py'), ('recovery', 'test-profile-recovery-native.py')]:
        spec = importlib.util.spec_from_file_location(key, ROOT / 'scripts' / filename)
        modules[key] = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modules[key])
    restore = Path(args.restore)
    checksum = hashlib.md5(restore.read_bytes()).hexdigest()
    if modules['primitives'].installed_md5(host, password) != checksum:
        raise RuntimeError('Restore ZIP differs from installed app')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    hits = []

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            hits.append(self.path)
            value = []
            if self.path == '/api/accounts/users/me/':
                value = {'id': 7, 'username': 'Synthetic7', 'user_level': 1}
            if self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': [{'key': 'synthetic7.aeriotv', 'bytes': 600}]} if args.imported else {'apps': []}
            if self.path == '/api/accounts/users/me/app-data/synthetic7.aeriotv/':
                stamp = '2026-11-13T16:00:00Z'
                digest = hashlib.sha256(bytes.fromhex('bb' * 16) + b'1234').hexdigest()
                value = {'schemaVersion': 3, 'deviceId': 'synthetic-phone', 'platform': 'android', 'appVersion': '1', 'updatedAt': stamp,
                         'categories': {'profiles': {'updatedAt': stamp, 'data': {'rows': [[7, 'Synthetic7', 'Synthetic7', 'numbers', digest, 'bb' * 16, 'user', 1794585600]]}}}}
            body = json.dumps(value).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioProfilePinProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-pin-probe.zip'
    cleaner = ROOT / 'out/profile-pin-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}', args.imported, args.old_os)
    modules['recovery'].cleanup_package(cleaner, section)
    report = {'passed': False, 'restore_sha256': hashlib.sha256(restore.read_bytes()).hexdigest()}

    def run(path, marker, prefix='', timeout=55):
        command = ['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix,
                   '--marker', marker, '--timeout', str(timeout)]
        if path != archive:
            return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout + 45)
        output = []
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
            for line in process.stdout:
                output.append(line)
                if '[profile-pin] {' not in line:
                    continue
                event = json.loads(line.split('[profile-pin] ', 1)[1])
                if event.get('kind') in ['covered', 'locked', 'locked-correct']:
                    report.setdefault('protectedHits', []).append({'kind': event['kind'], 'paths': list(hits)})
                if event.get('kind') == 'covered':
                    screenshot = ROOT / ('out/profile-pin-import-covered.jpg' if args.imported else 'out/profile-pin-covered.jpg')
                    if args.old_os:
                        screenshot = ROOT / 'out/profile-runtime-floor.jpg'
                    captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', str(screenshot)], cwd=ROOT, capture_output=True, text=True, timeout=45)
                    report['screenshot'] = captured.returncode == 0
                    if args.cancel:
                        if args.options:
                            request = urllib.request.Request(f'http://{host}:8060/keypress/Info', data=b'', method='POST')
                            urllib.request.urlopen(request, timeout=10).close()
                            time.sleep(0.5)
                        request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                        urllib.request.urlopen(request, timeout=10).close()
                if event.get('kind') == 'locked':
                    screenshot = ROOT / ('out/profile-pin-import-locked.jpg' if args.imported else 'out/profile-pin-locked.jpg')
                    captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', str(screenshot)], cwd=ROOT, capture_output=True, text=True, timeout=45)
                    report['lockScreenshot'] = captured.returncode == 0
            stderr = process.stderr.read()
            return subprocess.CompletedProcess(command, process.wait(timeout=timeout + 45), ''.join(output), stderr)

    try:
        result = run(archive, '[profile-pin] exit-main' if args.cancel else '"kind":"guide"')
        (ROOT / 'out/profile-pin-console.txt').write_text(re.sub(r'(?i)[a-f0-9]{32,}', '[redacted]', result.stdout).replace(password, '[developer password]'))
        for line in result.stdout.splitlines():
            if '[profile-pin]' in line or any(word in line.lower() for word in ['error &h', 'error:', 'running dev', 'member function', 'backtrace', 'pkg:/components/']):
                line = re.sub(r'(?i)[a-f0-9]{32,}', '[redacted]', line)
                print(line.replace(password, '[developer password]'), flush=True)
        print(result.stderr, end='', flush=True)
        rows = [json.loads(line.split('[profile-pin] ', 1)[1]) for line in result.stdout.splitlines() if '[profile-pin] {' in line]
        report['events'] = rows
        report['hits'] = hits
        report['passed'] = result.returncode == 0 and len(rows) == 5 and all(row.get('covered') and not row.get('task') for row in rows[:3]) and rows[0].get('native') and not rows[3].get('covered') and not rows[3].get('closed') and rows[3].get('grant') and rows[4].get('account') == '7' and not rows[4].get('covered')
        allowed = ['/api/accounts/users/me/', '/api/accounts/users/me/app-data/', '/api/accounts/users/me/app-data/synthetic7.aeriotv/'] if args.imported else []
        report['passed'] = report['passed'] and report.get('screenshot', False) and len(report.get('protectedHits', [])) == 3 and all(path in allowed for sample in report['protectedHits'] for path in sample['paths'])
        if args.cancel:
            expected_surface = bool(rows and (rows[0].get('runtime_rejected') if args.old_os else rows[0].get('native')))
            report['passed'] = result.returncode == 0 and '[profile-pin] exit-main' in result.stdout and len(rows) == 1 and rows[0].get('covered') and expected_surface and report.get('screenshot', False) and all(path in allowed for path in hits)
        if not report['passed']:
            raise RuntimeError('Normal-app numeric gate assertion failed')
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
            report_name = 'profile-pin-import-native.json' if args.imported else 'profile-pin-native.json'
            if args.cancel:
                report_name = report_name.replace('-native', '-cancel-native')
            if args.options:
                report_name = report_name.replace('-cancel-', '-options-')
            if args.old_os:
                report_name = 'profile-runtime-floor-native.json'
            (ROOT / 'out' / report_name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
