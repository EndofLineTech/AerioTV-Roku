"""Qualify the serialized cross-Task request broker with synthetic data only."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import socket
import threading
import time
import urllib.parse
import urllib.request
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def build(output):
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        package.writestr('manifest', 'title=Aerio Request Gate Probe\nmajor_version=0\nminor_version=0\nbuild_version=1\nui_resolutions=fhd\nrsg_version=1.3\nsupports_input_launch=1\n')
        package.write(ROOT / 'tests/native/RequestGateProbeMain.brs', 'source/Main.brs')
        for name in ['RequestGateTask.xml', 'RequestGateTask.brs', 'RequestGateTicket.xml', 'RequestGateRecheckTask.xml', 'RequestGateRecheckTask.brs']:
            package.write(ROOT / 'components' / name, 'components/' + name)
        for name in ['RequestGateProbe.xml', 'RequestGateProbe.brs', 'RequestGateProbeWorker.xml', 'RequestGateProbeWorker.brs']:
            package.write(ROOT / 'tests/native' / name, 'components/' + name)
        for name in ['RequestGateModel', 'RequestGateClient', 'RequestGateRenderer', 'HttpPolicy', 'DispatcharrModel', 'HttpTransport', 'DispatcharrHttp', 'TaskSupport']:
            package.write(ROOT / f'source/{name}.brs', f'source/{name}.brs')
        package.write(ROOT / 'source/SessionHttp.brs', 'source/SessionHttp.brs')
        package.write(ROOT / 'components/MappingDetailFetch.brs', 'components/MappingDetailFetch.brs')
        for name in ['HlsSessionTask', 'LogoCacheTask', 'PlaybackBridgeTask', 'DispatcharrSyncReadTask']:
            relative = f'components/{name}.xml'
            package.write(ROOT / relative, relative)
            for script in ET.parse(ROOT / relative).findall('script'):
                uri = script.attrib['uri']
                relative = uri.removeprefix('pkg:/') if uri.startswith('pkg:/') else 'components/' + uri
                if relative not in package.namelist():
                    package.write(ROOT / relative, relative)
        package.writestr('request-gate-probe.json', '{"synthetic":true}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    args = parser.parse_args()
    host = os.environ['ROKU_HOST']
    password = os.environ['ROKU_DEV_PASSWORD']
    spec = importlib.util.spec_from_file_location('primitives', ROOT / 'scripts/test-profile-primitives-native.py')
    primitives = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(primitives)
    restore = Path(args.restore)
    restore_md5 = hashlib.md5(restore.read_bytes()).hexdigest()
    if primitives.installed_md5(host, password) != restore_md5:
        raise RuntimeError('Restore ZIP differs from installed app')
    archive = ROOT / 'out/request-gate-probe.zip'
    build(archive)
    operations = ['generic', 'reject', 'parallel-report', 'parallel-held', 'sync-read', 'session-retire', 'park', 'parallel-park', 'transport', 'direct-bypasses', 'bypasses', 'renderers', 'recheck', 'video']
    hits = []

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            hits.append({'path': self.path, 'mixed_auth': bool(self.headers.get('Authorization') and self.headers.get('X-API-Key'))})
            status = {'/generic': 401, '/forbidden': 403, '/reject': 401, '/park': 429, '/video-park': 429}.get(self.path, 200)
            body = b'{"ok":true}'
            if self.path == '/generic':
                body = b'<html>Invalid API key</html>'
            if self.path in ['/reject', '/forbidden']:
                body = b'{"detail":"Invalid API key"}'
            if self.path == '/api/accounts/users/me/':
                body = b'{"id":7}'
            content_type = 'application/json'
            if self.path.startswith('/sync/'):
                _, _, scenario, *tail = self.path.split('/')
                endpoint = '/' + '/'.join(tail)
                status = 200
                value = {'schemaVersion': 3, 'categories': {'settings': {'data': {'tv': {'textScale': 1.3}}}, 'syncProviders': {'data': {'updatedAt': 1761700000000}}}}
                if endpoint == '/api/accounts/users/me/':
                    value = {'id': 8 if scenario == 'identity' else 7, 'username': 'Alice'}
                    if scenario == 'username':
                        value['username'] = 'Other'
                    if scenario == 'string-identity':
                        value['id'] = '7'
                elif endpoint == '/api/accounts/users/me/app-data/':
                    value = {'apps': [{'key': 'alice.aeriotv', 'bytes': 100}]}
                    if scenario == 'legacy':
                        value = {'apps': [{'key': 'app.molinete.aerio', 'bytes': 100}]}
                    if scenario == 'missing':
                        value = {'apps': []}
                    if scenario in ['forbidden', 'unsupported']:
                        status = 403 if scenario == 'forbidden' else 404
                elif endpoint == '/api/accounts/users/me/app-data/alice.aeriotv/':
                    if scenario in ['key-missing', 'proxy404']:
                        status = 404
                        value = {'code': 'key_not_found'} if scenario == 'key-missing' else {'detail': 'not found'}
                    if scenario == 'malformed':
                        value = []
                    if scenario == 'newer':
                        value['schemaVersion'] = 4
                    if scenario == 'float-schema':
                        value['schemaVersion'] = 3.0
                else:
                    status = 500
                body = json.dumps(value, ensure_ascii=False).encode()
            if self.path == '/movie.mp4':
                body = (ROOT / 'tests/native/fixtures/4by3.mp4').read_bytes()
                content_type = 'video/mp4'
            if self.path == '/poster.png':
                body = (ROOT / 'images/channel-icon-hd.png').read_bytes()
                content_type = 'image/png'
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            if self.command == 'HEAD':
                return
            if self.path == '/slow':
                time.sleep(2)  # Native cancellation during an actual response.
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

        do_HEAD = do_GET

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    fixture_base = f'http://{local}:{server.server_port}'
    completed = []
    evidence = []
    report = {'passed': False, 'probe_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
              'restore_sha256': hashlib.sha256(restore.read_bytes()).hexdigest(), 'events': evidence}
    process = None

    def command(value):
        request = urllib.request.Request(f'http://{host}:8060/input?' + urllib.parse.urlencode({'gateProbeCommand': value, 'gateFixtureBase': fixture_base}), data=b'', method='POST')
        urllib.request.urlopen(request, timeout=10).close()

    try:
        process = subprocess.Popen(['python3', 'scripts/run-native-probe.py', str(archive), '--prefix', '[request-gate]',
                                    '--marker', '[request-gate] complete', '--timeout', '150'], cwd=ROOT,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end='', flush=True)
            if '[request-gate] {' not in line:
                continue
            row = json.loads(line.split('[request-gate] ', 1)[1])
            evidence.append(row)
            if row['kind'] == 'ready':
                command(operations[0])
            elif row['kind'] == 'result':
                if not row['passed'] or row['operation'] != operations[len(completed)]:
                    raise RuntimeError('Synthetic native broker assertion failed')
                completed.append(row['operation'])
                if len(completed) < len(operations):
                    command(operations[len(completed)])
        report['passed'] = process.wait(timeout=10) == 0 and completed == operations
        paths = [row['path'] for row in hits]
        allowed = ['/generic', '/forbidden', '/reject', '/ok', '/park', '/api/accounts/users/me/', '/poster.png', '/movie.mp4', '/video-park', '/slow']
        sync_paths = [path for path in paths if path.startswith('/sync/')]
        sync_expected = []
        for scenario in ['canonical', 'legacy', 'missing', 'key-missing', 'forbidden', 'unsupported', 'proxy404', 'identity', 'username', 'string-identity', 'float-schema', 'malformed', 'newer']:
            prefix = f'/sync/{scenario}/api/accounts/users/me/'
            sync_expected.append(prefix)
            if scenario not in ['identity', 'username', 'string-identity']:
                sync_expected.append(prefix + 'app-data/')
            if scenario in ['canonical', 'key-missing', 'proxy404', 'float-schema', 'malformed', 'newer']:
                sync_expected.append(prefix + 'app-data/alice.aeriotv/')
        normal_paths = [path for path in paths if not path.startswith('/sync/')]
        report['passed'] = report['passed'] and sync_paths == sync_expected and [path for path in normal_paths if path != '/slow'][:6] == allowed[:6] and paths.count('/slow') == 1 and '/movie.mp4' in paths and paths.count('/video-park') == 1 and all(path in allowed for path in normal_paths) and not any(row['mixed_auth'] for row in hits)
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        restored = subprocess.run(['python3', 'scripts/run-native-probe.py', str(restore), '--prefix', '[request-gate-restore]',
                                   '--marker', 'Running dev', '--timeout', '30'], cwd=ROOT,
                                  capture_output=True, text=True, timeout=80)
        report['restored'] = restored.returncode == 0 and primitives.installed_md5(host, password) == restore_md5
        server.shutdown()
        server.server_close()
        report['requests'] = hits
        (ROOT / 'out/request-gate-native.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Exact prior developer app restored:', report['restored'], flush=True)
        if not report['restored']:
            raise RuntimeError('Prior developer app restore failed')
    if not report['passed']:
        raise SystemExit('Native request gate did not complete its broker cases')


if __name__ == '__main__':
    main()
