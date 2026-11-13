"""Prove the real app's corrupt-roster startup sends zero provider requests.

Builds a branded normal-app fixture with a unique registry section, a public
synthetic key and a local HTTP trap. Cleans only that section, then restores the
checksum-matched previous developer ZIP, including on failure.
"""
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
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output, normal, section, base):
    entry = {'id': 'slot-a', 'name': 'Synthetic recovery fixture', 'provider': 'dispatcharr',
             'url': base, 'remember': True, 'accountId': '7'}
    roster = json.dumps({'schema': 1, 'selected': 'slot-a', 'entries': [entry]})
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'manifest':
                body = body.replace(b'title=AerioTV\n', b'title=Aerio Profile Recovery Probe\n')
            if name == 'components/AerioScene.brs':
                source = body.decode()
                target = 'm.registry = CreateObject("roRegistrySection", "AerioTV")'
                if source.count(target) != 1:
                    raise RuntimeError('Registry isolation hook no longer matches; refusing build')
                seed = f'''m.registry = CreateObject("roRegistrySection", "{section}")
    m.registry.write("connectionsV1", ReadAsciiFile("pkg:/profile-recovery-probe.json"))
    m.registry.write("connKey_slot-a", "synthetic-never-send-key")
    m.registry.write("userProfilesV1_slot-a", "corrupt-profile-fixture")
    m.registry.flush()'''
                source = source.replace(target, seed, 1)
                target = 'm.status = userProfileGateMessage(profileGate)'
                if source.count(target) != 1:
                    raise RuntimeError('Startup gate evidence hook no longer matches')
                source = source.replace(target, target + '\n        print "[profile-recovery] blocked="; profileGate.reason; " no-task="; m.task = invalid', 1)
                body = source.encode()
            package.writestr(name, body)
        package.writestr('profile-recovery-probe.json', roster)


def cleanup_package(output, section):
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        package.writestr('manifest', 'title=Aerio Profile Registry Cleanup\nmajor_version=0\nminor_version=0\nbuild_version=1\n')
        package.writestr('source/Main.brs', f'''sub Main()
    registry = CreateObject("roRegistry")
    removed = registry.delete("{section}")
    removed = registry.flush() and removed
    print "[profile-recovery] cleanup="; removed
end sub
''')
        package.writestr('profile-recovery-probe.json', '{}')


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
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
        route.connect((host, 8060))
        local = route.getsockname()[0]
    hits = []

    class Trap(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            hits.append({'method': self.command})
            self.send_error(503)

        do_POST = do_GET
        do_PUT = do_GET
        do_PATCH = do_GET
        do_DELETE = do_GET

    server = ThreadingHTTPServer((local, 0), Trap)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    archive = ROOT / 'out/profile-recovery-app-probe.zip'
    cleaner = ROOT / 'out/profile-recovery-cleanup.zip'
    section = 'AerioProfileAppProbe-' + str(uuid.uuid4())
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}')
    cleanup_package(cleaner, section)
    report = {'passed': False, 'restore_sha256': hashlib.sha256(restore.read_bytes()).hexdigest(),
              'probe_sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}

    def run(path, marker, timeout=30):
        return subprocess.run(['python3', 'scripts/run-native-probe.py', str(path), '--prefix', '[profile-recovery]',
                               '--marker', marker, '--timeout', str(timeout)], cwd=ROOT,
                              capture_output=True, text=True, timeout=90)

    try:
        result = run(archive, '[profile-recovery] blocked=', 45)
        print(result.stdout, end='', flush=True)
        report['evidence'] = result.stdout.splitlines()
        report['passed'] = result.returncode == 0 and '[profile-recovery] blocked=recovery no-task=true' in result.stdout
        time.sleep(3)  # Allow the OS splash and first SceneGraph paint to settle.
        captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode',
                                   '--output', 'out/profile-recovery-native.jpg'], cwd=ROOT, capture_output=True,
                                  text=True, timeout=45)
        report['screenshot_captured'] = captured.returncode == 0
    finally:
        try:
            cleanup = run(cleaner, '[profile-recovery] cleanup=')
            report['cleaned'] = cleanup.returncode == 0 and '[profile-recovery] cleanup=true' in cleanup.stdout
        finally:
            restored = run(restore, 'Running dev')
            report['restored'] = restored.returncode == 0 and primitives.installed_md5(host, password) == restore_md5
            server.shutdown()
            server.server_close()
            report['requests'] = hits
            report['passed'] = report['passed'] and not hits and report.get('cleaned', False) and report['restored']
            (ROOT / 'out/profile-recovery-native.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({k: report.get(k) for k in ['passed', 'cleaned', 'restored', 'requests']}), flush=True)
    if not report['passed']:
        raise SystemExit('Native corrupt-roster application gate failed')


if __name__ == '__main__':
    main()
