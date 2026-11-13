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
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'test-profile-{name}-native.py')
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def build(output, normal, section, base):
    seeded = output.with_suffix('.seed.zip')
    module('management').build(seeded, normal, section, base)
    fixture = (ROOT / 'tests/native/ProfileOwnSignInFixture.brs').read_text()
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
    args = parser.parse_args()
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
            self.wfile.write(body)

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
            scenario = body.get('password', '').removeprefix('synthetic-')
            hits.append({'method': 'POST', 'path': self.path, 'scenario': scenario, 'no_api_key': not self.headers.get('X-API-Key'), 'username_ok': body.get('username') == 'Synthetic8'})
            if self.path != '/api/accounts/token/' or scenario not in ['rejected', 'name', 'no-api', 'correct']:
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
                value = {'id': 88 if scenario else 7, 'username': 'Synthetic8' if scenario else 'Synthetic7', 'user_level': 1}
                if scenario:
                    value['api_key'] = None if scenario == 'no-api' else 'synthetic-new-own-key'
                    if scenario == 'name':
                        value['username'] = 'DifferentUser'
            elif self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
            self.reply(200, value)

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioOwnSignInProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-own-signin-probe.zip'
    cleaner = ROOT / 'out/profile-own-signin-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}')
    recovery.cleanup_package(cleaner, section)
    report = {'passed': False}

    def run(path, marker, prefix):
        return subprocess.run(['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '60'], cwd=ROOT, capture_output=True, text=True, timeout=110)

    try:
        result = run(archive, '"kind":"result"', '[own-signin]')
        print(result.stdout, end='', flush=True)
        rows = [json.loads(line.split('[own-signin] ', 1)[1]) for line in result.stdout.splitlines() if '[own-signin] {' in line]
        report['events'], report['requests'] = rows, hits
        posts = [hit for hit in hits if hit['method'] == 'POST']
        own_reads = [hit for hit in hits if hit['method'] == 'GET' and hit['scenario']]
        report['passed'] = result.returncode == 0 and len(rows) == 5 and all(row.get('passed') for row in rows) and all(rows[-1].get(key) for key in ['default_preserved', 'own_saved', 'active_preserved', 'no_autoplay']) and [hit['scenario'] for hit in posts] == ['rejected', 'name', 'no-api', 'correct'] and all(hit['no_api_key'] and hit['username_ok'] for hit in posts) and len(own_reads) == 3 and all(hit['path'] == '/api/accounts/users/me/' and hit['no_api_key'] for hit in own_reads)
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
            (ROOT / 'out/profile-own-signin-native.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
