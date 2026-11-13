"""Run synthetic HTTP/JSON probes, restoring the checksum-matched developer app.

ROKU_HOST and ROKU_DEV_PASSWORD must be supplied in the environment. No provider
credentials, owner registry, application startup or real Dispatcharr are used.
"""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import threading
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def wire_valid(body, headers, expected):
    if headers.get('Content-Type') != 'application/json':
        return False
    if headers.get('Content-Length') != str(len(body)):
        return False
    try:
        value = json.loads(body)
        return (body == expected and
                type(value['schemaVersion']) is int and
                type(value['categories']['settings']['data']['mobile']['textScale']) is float and
                value['categories']['syncProviders']['data']['updatedAt'] == 1761700000000 and
                'schemaVersion' in value and 'schemaversion' not in value)
    except (ValueError, KeyError, TypeError):
        return False


def equal_json_types(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(equal_json_types(left[k], right[k]) for k in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(equal_json_types(a, b) for a, b in zip(left, right))
    return left == right


def installed_md5(host, password):
    origin = 'http://' + host
    auth = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    auth.add_password(None, origin, 'rokudev', password)
    client = urllib.request.build_opener(urllib.request.HTTPDigestAuthHandler(auth))
    page = client.open(origin + '/plugin_install', timeout=15).read().decode()
    match = re.search(r'"md5"\s*:\s*"([0-9a-f]{32})"', page)
    if not match:
        raise RuntimeError('Installed developer ZIP checksum unavailable; refusing replacement')
    return match[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--report', default='out/profile-primitives-native.json')
    parser.add_argument('--registry', action='store_true', help='Measure disposable registry fixtures and clean up before restoring')
    args = parser.parse_args()
    host = os.environ['ROKU_HOST']
    password = os.environ['ROKU_DEV_PASSWORD']
    restore = Path(args.restore)
    restore_md5 = hashlib.md5(restore.read_bytes()).hexdigest()
    if installed_md5(host, password) != restore_md5:
        raise RuntimeError('Restore ZIP does not match installed app; refusing replacement')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as discovery:
        discovery.connect((host, 8060))
        local = discovery.getsockname()[0]
    requests = []
    expected = b''

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            if self.client_address[0] != host or self.path != '/refused':
                self.send_error(404)
                return
            body = b'{"detail":"Invalid API key"}'
            self.send_response(401)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            requests.append({'method': 'GET', 'retained_fixture': True})

        def write_fixture(self):
            if self.client_address[0] != host or self.path not in ['/wire', '/roundtrip', '/oversized']:
                self.send_error(404)
                return
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 132096:
                self.send_error(413)
                return
            body = self.rfile.read(size)
            if self.path == '/oversized':
                response = json.dumps({'text': '🦉' * 20}, ensure_ascii=False).encode()
                requests.append({'method': self.command, 'oversized_utf8_response': True})
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(response)))
                self.end_headers()
                self.wfile.write(response)
                return
            if self.path == '/wire':
                valid = wire_valid(body, self.headers, expected)
            else:
                try:
                    valid = (self.headers.get('Content-Length') == str(len(body)) and
                             equal_json_types(json.loads(body), json.loads(expected)))
                except (ValueError, TypeError):
                    valid = False
            requests.append({'method': self.command, 'exact_utf8_json': valid, 'roundtrip': self.path == '/roundtrip'})
            if not valid and self.path == '/roundtrip':
                # Public synthetic fixture numbers only, never response bodies
                # or credentials. This diagnoses native binary64 formatting.
                value = json.loads(body)
                requests[-1]['fixture_numbers'] = {k: value.get('FutureCase', {}).get(k)
                    for k in ['preciseDouble', 'exponentDouble', 'largeInteger']}
            response = json.dumps({'ok': valid}).encode()
            self.send_response(200 if valid else 400)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response)))
            self.end_headers()
            self.wfile.write(response)

        do_PUT = write_fixture
        do_PATCH = write_fixture

        def do_POST(self):
            requests.append({'method': 'POST', 'unexpected_method': True})
            self.send_error(405)

    server = ThreadingHTTPServer((local, 0), Handler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    spec = importlib.util.spec_from_file_location('profile_builder', ROOT / 'scripts/build-profile-probe.py')
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    archive = builder.build(ROOT / 'out/user-profile-probe.zip', f'http://{local}:{server.server_port}', registry=args.registry)
    with zipfile.ZipFile(archive) as package:
        expected = package.read('profile-wire-fixture.json')
    report = {'restore_sha256': hashlib.sha256(restore.read_bytes()).hexdigest(),
              'probe_sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
    try:
        result = subprocess.run(['python3', 'scripts/run-native-probe.py', str(archive),
                                 '--prefix', '[profile-probe]', '--marker', '[profile-probe] complete',
                                 '--timeout', '60'], cwd=ROOT, capture_output=True, text=True, timeout=110)
        print(result.stdout, end='', flush=True)
        report['evidence'] = result.stdout.splitlines()
        report['requests'] = requests
        report['passed'] = (result.returncode == 0 and
                            re.search(r'complete failed=\s*0\b', result.stdout) is not None and
                            [r['method'] for r in requests] == ['GET', 'PUT', 'PATCH', 'PUT', 'PUT'])
    finally:
        server.shutdown()
        server.server_close()
        restored = subprocess.run(['python3', 'scripts/run-native-probe.py', str(restore),
                                   '--marker', 'Running dev', '--prefix', '[profile-restore]',
                                   '--timeout', '30'], cwd=ROOT, capture_output=True, text=True, timeout=80)
        report['restored'] = restored.returncode == 0 and installed_md5(host, password) == restore_md5
        Path(args.report).write_text(json.dumps(report, indent=2) + '\n')
        print('Exact prior developer app restored:', report['restored'], flush=True)
        if not report['restored']:
            raise RuntimeError('Restore failed; owner app needs recovery')
    if not report['passed']:
        raise SystemExit('Native primitive assertions failed; inspect sanitized report')


if __name__ == '__main__':
    main()
