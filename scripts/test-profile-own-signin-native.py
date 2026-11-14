"""Private normal-app own-user password verification and storage recovery probe."""
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
import time
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'test-profile-{name}-native.py')
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def build(output, normal, section, base, form=False, default_form=False, held=False):
    if held:
        if default_form:
            raise ValueError('Held fixture covers a non-default holder only')
        form = True
    if default_form:
        form = True
    seeded = output.with_suffix('.seed.zip')
    module('management').build(seeded, normal, section, base)
    fixture_name = 'ProfileDefaultOwnSignInFormFixture.brs' if default_form else ('ProfileOwnSignInFormFixture.brs' if form else 'ProfileOwnSignInFixture.brs')
    fixture = (ROOT / 'tests/native' / fixture_name).read_text()
    fixture = fixture.replace('OWN_PROBE_HELD', 'true' if held else 'false')
    if form:
        fixture = fixture.replace('OWN_PROBE_PIN_HASH', hashlib.sha256(bytes.fromhex('bb' * 16) + b'1234').hexdigest())
    with zipfile.ZipFile(seeded) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'components/AerioScene.brs':
                source = body.decode()
                assert source.count('sub onManagementProbeTick()') == 1
                body = (source.split('sub onManagementProbeTick()', 1)[0] + fixture).encode()
            package.writestr(name, body)
        package.writestr('profile-own-signin-probe.json', '{"synthetic":true}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--form', action='store_true', help='Exercise actual native form/keyboards and delayed-request Back cancellation')
    parser.add_argument('--default-form', action='store_true', help='Switch to B then recover inactive default A through its actual form')
    parser.add_argument('--held', action='store_true', help='Recover an inactive held holder; preserve another hold and show the changed-server message')
    args = parser.parse_args()
    if args.held:
        if args.default_form:
            parser.error('--held cannot be combined with --default-form')
        args.form = True
    if args.default_form:
        args.form = True
    host, password = os.environ['ROKU_HOST'], os.environ['ROKU_DEV_PASSWORD']
    primitives, recovery = module('primitives'), module('recovery')
    restore = Path(args.restore)
    checksum = hashlib.md5(restore.read_bytes()).hexdigest()
    if primitives.installed_md5(host, password) != checksum:
        raise RuntimeError('Restore ZIP differs from installed app')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    hits = []

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, status, value):
            body = json.dumps(value).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # The form deliberately cancels its delayed reader.

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
            scenario = body.get('password', '').removeprefix('synthetic-')
            hits.append({'method': 'POST', 'path': self.path, 'scenario': scenario, 'no_api_key': not self.headers.get('X-API-Key'), 'username_ok': body.get('username') == ('Synthetic7' if args.default_form else 'Synthetic8')})
            if self.path != '/api/accounts/token/' or scenario not in ['rejected', 'name', 'id', 'no-api', 'correct', 'delayed']:
                self.reply(400, {})
            elif scenario == 'rejected':
                self.reply(401, {'detail': 'Synthetic refused login'})
            else:
                self.reply(200, {'access': 'fixture-' + scenario})

        def do_GET(self):
            bearer = self.headers.get('Authorization', '').removeprefix('Bearer ')
            scenario = bearer.removeprefix('fixture-') if bearer.startswith('fixture-') else ''
            hits.append({'method': 'GET', 'path': self.path, 'scenario': scenario, 'no_api_key': not self.headers.get('X-API-Key')})
            value = []
            if self.path == '/api/accounts/users/me/':
                holder = 8 if args.default_form and self.headers.get('X-API-Key') == 'synthetic-b' else 7
                value = {'id': (7 if args.default_form else 88) if scenario else holder, 'username': ('Synthetic7' if args.default_form else 'Synthetic8') if scenario else f'Synthetic{holder}', 'user_level': 1}
                if scenario:
                    value['api_key'] = None if scenario == 'no-api' else 'synthetic-new-own-key'
                    if scenario == 'name':
                        value['username'] = 'DifferentUser'
                    if scenario == 'id':
                        value['id'] = 88
                    if scenario == 'delayed':
                        time.sleep(4)
                        value['api_key'] = 'synthetic-must-not-save'
            elif self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
            self.reply(200, value)

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioOwnSignInProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-own-signin-probe.zip'
    cleaner = ROOT / 'out/profile-own-signin-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}', args.form, args.default_form, args.held)
    recovery.cleanup_package(cleaner, section)
    report = {'passed': False}

    def run(path, marker, prefix):
        command = ['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '60']
        if path != archive or not args.form:
            return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=110)
        output = []
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
            for line in process.stdout:
                output.append(line)
                if '"kind":"cancel-ready"' in line:
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                    urllib.request.urlopen(request, timeout=10).close()
            stderr = process.stderr.read()
            return subprocess.CompletedProcess(command, process.wait(timeout=110), ''.join(output), stderr)

    try:
        result = run(archive, '"kind":"result"', '[own-signin]')
        print(result.stdout, end='', flush=True)
        rows = [json.loads(line.split('[own-signin] ', 1)[1]) for line in result.stdout.splitlines() if '[own-signin] {' in line]
        report['events'], report['requests'] = rows, hits
        posts = [hit for hit in hits if hit['method'] == 'POST']
        own_reads = [hit for hit in hits if hit['method'] == 'GET' and hit['scenario']]
        cases = [row for row in rows if row.get('kind') == 'case']
        expected_cases = ['rejected', 'name'] + (['id'] if args.default_form else []) + ['no-api', 'correct']
        expected_posts = expected_cases + (['delayed'] if args.form else [])
        preservation_fields = ['outgoing_preserved', 'settings_preserved'] if args.default_form else ['default_preserved']
        report['passed'] = result.returncode == 0 and len(rows) == len(expected_cases) + (2 if args.form else 1) and [row.get('scenario') for row in cases] == expected_cases and all(row.get('passed') for row in cases) and rows[-1].get('passed') and all(rows[-1].get(key) for key in [*preservation_fields, 'own_saved', 'active_preserved', 'no_autoplay']) and [hit['scenario'] for hit in posts] == expected_posts and all(hit['no_api_key'] and hit['username_ok'] for hit in posts) and len(own_reads) == len(expected_posts) - 1 and all(hit['path'] == '/api/accounts/users/me/' and hit['no_api_key'] for hit in own_reads)
        if args.form:
            report['passed'] = report['passed'] and rows[-1].get('trust_preserved', False)
        if not report['passed']:
            raise RuntimeError('Native own-profile sign-in assertions failed')
    finally:
        try:
            cleaned = run(cleaner, '[profile-recovery] cleanup=', '[profile-recovery]')
            report['cleaned'] = cleaned.returncode == 0 and '[profile-recovery] cleanup=true' in cleaned.stdout
        finally:
            restored = run(restore, 'Running dev', '[own-signin-restore]')
            report['restored'] = restored.returncode == 0 and primitives.installed_md5(host, password) == checksum
            server.shutdown()
            server.server_close()
            report['passed'] = report['passed'] and report.get('cleaned', False) and report['restored']
            report_name = 'profile-default-own-signin-form-native.json' if args.default_form else ('profile-own-signin-form-native.json' if args.form else 'profile-own-signin-native.json')
            if args.held:
                report_name = 'profile-held-own-signin-form-native.json'
            (ROOT / 'out' / report_name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
