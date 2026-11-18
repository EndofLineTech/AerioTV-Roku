"""Private real-Scene switch faults with synthetic HTTP and exact app restoration."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent
CASES = ['key-loss', 'child-key-loss', 'stale-pin', 'retire-pin', 'rollback-unchanged',
         'rollback-pin', 'rollback-role', 'rollback-key', 'rollback-root',
         'cleanup-rollback', 'roster-stale-pin', 'adult-purpose-change', 'unavailable-actor-change', 'unavailable-actor-state',
         'startup-read-authority', 'startup-lineup-authority', 'own-email-consent', 'own-email-add', 'own-email-child']
ROSTER_CASES = ['cleanup-rollback', 'roster-stale-pin', 'adult-purpose-change']
HELD_CASES = [case for case in CASES if case.startswith('rollback-') or case.startswith('unavailable-actor-')]


def module(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / f'test-profile-{name}-native.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def build(output, normal, section, base, case):
    if case not in CASES:
        raise ValueError('Unknown switch fault')
    with tempfile.TemporaryDirectory(dir=output.parent) as folder:
        seed = Path(folder) / 'seed.zip'
        module('management').build(seed, normal, section, base)
        fixture = (ROOT / 'tests/native/ProfileSwitchFaultFixture.brs').read_text().replace('OWN_FAULT_CASE', json.dumps(case))
        if case in ROSTER_CASES:
            fixture = (ROOT / 'tests/native/ProfileSwitchRosterFaultFixture.brs').read_text().replace('OWN_FAULT_CASE', json.dumps(case)) + '\n' + fixture[fixture.index('sub reportSwitchFault('):]
        if case.startswith('startup-'):
            fixture = (ROOT / 'tests/native/ProfileStartupAuthorityFaultFixture.brs').read_text().replace('OWN_FAULT_CASE', json.dumps(case)) + '\n' + fixture[fixture.index('sub reportSwitchFault('):]
        with zipfile.ZipFile(seed) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
            for name in original.namelist():
                body = original.read(name)
                if name == 'components/AerioScene.brs':
                    source = body.decode().split('sub onManagementProbeTick()', 1)[0] + fixture
                    anchor = 'sub onLaunchRequest()\n'
                    assert source.count(anchor) == 1
                    source = source.replace(anchor, anchor + '''    if m.top.launchRequest.faultheld = "1"
        m.guardAuthHeld = true
        return
    end if
''', 1)
                    body = source.encode()
                package.writestr(name, body)
            package.writestr('profile-switch-fault-probe.json', json.dumps({'case': case, 'synthetic': True}))


def compile_probe(archive):
    with tempfile.TemporaryDirectory(dir=ROOT / 'out') as folder:
        with zipfile.ZipFile(archive) as package:
            package.extractall(folder)
        config = Path(folder) / 'bsconfig.json'
        config.write_text(json.dumps({'rootDir': folder, 'files': ['manifest', 'source/**/*', 'components/**/*'],
                                      'createPackage': False, 'copyToStaging': False}))
        result = subprocess.run([str(ROOT / 'node_modules/.bin/bsc'), '--project', str(config)],
                                cwd=ROOT, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            raise RuntimeError('Private switch fixture failed compilation:\n' + result.stdout + result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', type=Path, required=True)
    parser.add_argument('--source', type=Path, default=ROOT / 'out/aeriotv-roku.zip')
    parser.add_argument('--case', choices=CASES, required=True)
    args = parser.parse_args()
    primitives, recovery = module('primitives'), module('recovery')
    host, password = os.environ['ROKU_HOST'], os.environ['ROKU_DEV_PASSWORD']
    expected = hashlib.md5(args.restore.read_bytes()).hexdigest()
    if primitives.installed_md5(host, password) != expected:
        raise RuntimeError('Restore ZIP differs from installed app; refusing replacement')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    hits, events = [], []
    release_auth = threading.Event()
    auth_released = threading.Event()
    state = {}

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            key = self.headers.get('X-Api-Key', '')
            if not key and self.headers.get('Authorization', '').startswith('Bearer '):
                key = self.headers['Authorization'][7:]
            if self.client_address[0] != host or key not in ['synthetic-a', 'synthetic-b']:
                self.send_error(403)
                return
            user = 8 if key == 'synthetic-b' else 7
            hits.append({'user': user, 'path': self.path})
            if state.get('startup_race'):
                if user == 7 and self.path == '/api/accounts/users/me/':
                    state['race_me'] = state.get('race_me', 0) + 1
                # The previous admitted Guide may have already queued EPG.
                # Keep those separately; the new startup wave begins at /me.
                bucket = 'race_requests' if state.get('race_me', 0) else 'pre_auth_requests'
                state.setdefault(bucket, []).append({'user': user, 'path': self.path})
            if user == 8 and self.path == '/api/accounts/users/me/' and args.case in HELD_CASES:
                state['auth_held'] = True
                request = urllib.request.Request(f'http://{host}:8060/input?faultheld=1', data=b'', method='POST')
                with urllib.request.urlopen(request, timeout=5) as response:
                    state['signal_status'] = response.status
                state['released_after_verdict'] = release_auth.wait(timeout=30)
                auth_released.set()
            value = []
            path = self.path.split('?', 1)[0]
            if path == '/api/accounts/users/me/':
                value = {'id': user, 'username': f'Synthetic{user}', 'user_level': 1}
                threshold = 2 if args.case == 'startup-read-authority' else 3
                if args.case.startswith('startup-') and state.get('startup_race') and state.get('race_me', 0) >= threshold:
                    value['user_level'] = 10
            elif path == '/api/accounts/users/me/app-data/':
                value = {'apps': [{'key': 'synthetic8.aeriotv', 'bytes': 600}]} if args.case in ROSTER_CASES and user == 8 else {'apps': []}
            elif path == '/api/accounts/users/me/app-data/synthetic8.aeriotv/' and args.case in ROSTER_CASES:
                management = module('management')
                value = management.switch_import_pin_envelope()
                value['categories']['profiles']['data']['removed'] = management.switch_inactive_cleanup_envelope()['categories']['profiles']['data']['removed']
            elif path in ['/api/channels/channels/', '/api/channels/channels/summary/']:
                value = [{'id': user, 'uuid': f'00000000-0000-4000-8000-{user:012d}', 'name': f'Synthetic {user}', 'channel_number': user}]
            body = json.dumps(value).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def do_POST(self):
            hits.append({'method': 'POST', 'unexpected': True})
            self.send_error(405)

        do_PUT = do_POST
        do_PATCH = do_POST
        do_DELETE = do_POST

    server = ThreadingHTTPServer((local, 0), Fixture)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioSwitchFault-' + str(uuid.uuid4())
    archive = ROOT / f'out/p1-switch-fault-{args.case}.zip'
    cleaner = archive.with_suffix('.cleanup.zip')
    build(archive, args.source, section, f'http://{local}:{server.server_port}', args.case)
    compile_probe(archive)
    recovery.cleanup_package(cleaner, section)
    report = {'passed': False, 'case': args.case, 'requests': hits, 'events': events, 'transport': state,
              'restore_sha256': hashlib.sha256(args.restore.read_bytes()).hexdigest(),
              'probe_sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}

    def run(path, marker, prefix, timeout=45):
        return subprocess.run([sys.executable, 'scripts/run-native-probe.py', str(path), '--prefix', prefix,
                               '--marker', marker, '--timeout', str(timeout)],
                              cwd=ROOT, capture_output=True, text=True, timeout=timeout + 60)

    try:
        command = [sys.executable, 'scripts/run-native-probe.py', str(archive), '--prefix', '[switch-fault]',
                   '--marker', '"kind":"result"', '--timeout', '65']
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
            for line in process.stdout:
                print(line, end='', flush=True)
                if '[switch-fault] {' in line:
                    event = json.loads(line.split('[switch-fault] ', 1)[1])
                    if event.get('kind') == 'startup-ready':
                        state['startup_race'] = True
                        request = urllib.request.Request(f'http://{host}:8060/input?faultheld=1', data=b'', method='POST')
                        with urllib.request.urlopen(request, timeout=5) as response:
                            state['startup_signal_status'] = response.status
                    else:
                        events.append(event)
                        release_auth.set()
            code = process.wait(timeout=10)
        target = [r for r in hits if r.get('user') == 8]
        expected_target = [{'user': 8, 'path': '/api/accounts/users/me/'}] if args.case in HELD_CASES else []
        if args.case in ROSTER_CASES:
            expected_target = [{'user': 8, 'path': path} for path in [
                '/api/accounts/users/me/', '/api/accounts/users/me/',
                '/api/accounts/users/me/app-data/', '/api/accounts/users/me/app-data/synthetic8.aeriotv/']]
        report['passed'] = code == 0 and len(events) == 1 and events[0].get('passed') is True and events[0].get('no_autoplay') is True and target == expected_target and all(r.get('user') in [7, 8] for r in hits)
        if args.case in HELD_CASES:
            released = auth_released.wait(timeout=5)
            report['passed'] = report['passed'] and released and state.get('auth_held') is True and state.get('signal_status') == 200 and state.get('released_after_verdict') is True
        if args.case.startswith('startup-'):
            expected_count = 2 if args.case == 'startup-read-authority' else 3
            expected_paths = ['/api/accounts/users/me/', '/api/accounts/users/me/', '/api/accounts/users/me/app-data/']
            if expected_count == 3:
                expected_paths.append('/api/accounts/users/me/')
            report['passed'] = report['passed'] and state.get('startup_signal_status') == 200 and state.get('race_me') == expected_count and state.get('race_requests') == [{'user': 7, 'path': path} for path in expected_paths]
    finally:
        release_auth.set()
        try:
            cleaned = run(cleaner, 'cleanup=', '[profile-recovery]')
            report['cleaned'] = cleaned.returncode == 0 and 'cleanup=true' in cleaned.stdout
        finally:
            restored = run(args.restore, 'Running dev', '[restore]')
            report['restored'] = restored.returncode == 0 and primitives.installed_md5(host, password) == expected
            server.shutdown()
            server.server_close()
            report['passed'] = report['passed'] and report.get('cleaned', False) and report['restored']
            (ROOT / f'out/p1-switch-fault-{args.case}.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({k: report.get(k) for k in ['case', 'passed', 'cleaned', 'restored']}), flush=True)
    if not report['passed']:
        raise SystemExit('Native switch fault assertions failed')


if __name__ == '__main__':
    main()
