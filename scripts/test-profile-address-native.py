"""Private manual URL transaction and two-origin real-HTTP reconnect fixture."""
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


def build(output, normal, section, old_url, new_url, replacement=False, legacy=False):
    seed = output.with_suffix('.seed.zip')
    module('management').build(seed, normal, section, old_url)
    fixture = (ROOT / 'tests/native/ProfileAddressFixture.brs').read_text().replace('OWN_ADDRESS_NEW_URL', json.dumps(new_url))
    fixture = fixture.replace('OWN_ADDRESS_REPLACE', 'true' if replacement else 'false')
    if legacy:
        fixture = fixture.replace('"slot-a"', '"legacy"').replace('"|slot-a|"', '"|legacy|"').replace('connKey_slot-a', 'connKey_legacy')
        fixture = fixture.replace('m.addressPassed = persistCurrentUserProfilePreferences()', '''m.addressPassed = persistCurrentUserProfilePreferences() and m.legacyMigrationPassed
        print "[profile-address] legacy-owner="; m.legacyMigrationPassed''')
        fixture = fixture.replace('m.addressOldSession = currentUserSessionId()', '''m.legacyMigrationPassed = not m.registry.exists("preferences") and m.accountPreferences.favoriteIds.count() = 1
        if m.legacyMigrationPassed then m.legacyMigrationPassed = m.accountPreferences.favoriteIds[0] = "legacy-private"
        ownKey = preferenceScope(connectionPreferenceIdentity(m.addressOldEntry, "7"))
        legacySettings = ParseJson(m.registry.read("settingsV1"), "d")
        m.legacyMigrationPassed = m.legacyMigrationPassed and not legacySettings.accounts.doesExist(preferenceScope(m.addressOldEntry.url + "|7")) and legacySettings.accounts[ownKey]["FutureCase"]["precise"] = ParseJson("1.234567891234567", "d") and legacySettings["FutureRoot"]["precise"] = ParseJson("1.234567891234567", "d") and legacySettings.accounts["foreign"]["private"] = "foreign-only"
        m.addressOldSession = currentUserSessionId()''')
    with zipfile.ZipFile(seed) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'components/AerioScene.brs':
                source = body.decode()
                assert source.count('sub onManagementProbeTick()') == 1
                if legacy:
                    source = source.replace('id: "slot-a", name: "Synthetic"', 'id: "legacy", name: "Synthetic"', 1)
                    source = source.replace('selected: "slot-a", entries: [entry]', 'selected: "legacy", entries: [entry]', 1)
                    source = source.replace('m.registry.write("connKey_slot-a", "synthetic-a")', '''m.registry.write("connKey_legacy", "synthetic-a")
    m.registry.write("serverUrl", entry.url)
    m.registry.write("accountIdentity", entry.url + "|7")
    m.registry.write("preferences", ReadAsciiFile("pkg:/profile-legacy-preferences.json"))
    initialSettings = ParseJson(ReadAsciiFile("pkg:/profile-legacy-settings.json"), "d")
    initialSettings.accounts[preferenceScope(entry.url + "|7")] = {guide: {showLogos: false}}
    encodedSettings = strictJsonEncode(initialSettings)
    m.registry.write("settingsV1", encodedSettings.text)''', 1)
                body = (source.split('sub onManagementProbeTick()', 1)[0] + fixture).encode()
            package.writestr(name, body)
        package.writestr('profile-address-probe.json', '{"synthetic":true}')
        if legacy:
            package.writestr('profile-legacy-preferences.json', json.dumps({'favoriteIds': ['legacy-private'], 'FutureCase': {'precise': 1.234567891234567}}))
            package.writestr('profile-legacy-settings.json', json.dumps({'schema': 1, 'device': {}, 'accounts': {'foreign': {'private': 'foreign-only'}}, 'FutureRoot': {'precise': 1.234567891234567}}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--replace-default', action='store_true', help='New origin verifies a different default account; preserve holds and seed settings only')
    parser.add_argument('--legacy', action='store_true', help='Qualify original-owner legacy startup migration before the real address handler')
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

        def do_GET(self):
            key = self.headers.get('X-API-Key', '')
            hits.append({'server': self.server.identity, 'path': self.path, 'old_key': key in ['synthetic-a', 'synthetic-b', 'synthetic-old-memory'], 'new_key': key == 'synthetic-new-default'})
            value = []
            status = 200
            if self.server.identity == 'new' and key != 'synthetic-new-default':
                status, value = 401, {'detail': 'Invalid API key'}
            elif self.path == '/api/accounts/users/me/':
                identity = 70 if args.replace_default and self.server.identity == 'new' else 7
                value = {'id': identity, 'username': f'Synthetic{identity}', 'user_level': 1}
            elif self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
            body = json.dumps(value).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # The handler intentionally retires outgoing readers.

    servers = []
    for identity in ['old', 'new']:
        server = ThreadingHTTPServer((local, 0), Fixture)
        server.identity = identity
        threading.Thread(target=server.serve_forever, daemon=True).start()
        servers.append(server)
    section = 'AerioAddressProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-address-probe.zip'
    cleaner = ROOT / 'out/profile-address-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, *(f'http://{local}:{server.server_port}' for server in servers), replacement=args.replace_default, legacy=args.legacy)
    recovery.cleanup_package(cleaner, section)
    report = {'passed': False}

    def run(path, marker, prefix):
        return subprocess.run(['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '75'], cwd=ROOT, capture_output=True, text=True, timeout=125)

    try:
        result = run(archive, '"kind":"result"', '[profile-address]')
        print(result.stdout, end='', flush=True)
        print(result.stderr, end='', flush=True)
        rows = [json.loads(line.split('[profile-address] ', 1)[1]) for line in result.stdout.splitlines() if '[profile-address] {' in line]
        new_hits = [hit for hit in hits if hit['server'] == 'new']
        report.update(events=rows, requests=hits)
        report['passed'] = result.returncode == 0 and len(rows) == 1 and rows[0].get('passed') and bool(new_hits) and all(hit['new_key'] and not hit['old_key'] for hit in new_hits)
        if not report['passed']:
            raise RuntimeError('Native address transition assertions failed')
    finally:
        try:
            cleaned = run(cleaner, '[profile-recovery] cleanup=', '[profile-recovery]')
            report['cleaned'] = cleaned.returncode == 0 and '[profile-recovery] cleanup=true' in cleaned.stdout
        finally:
            restored = run(restore, 'Running dev', '[profile-address-restore]')
            report['restored'] = restored.returncode == 0 and primitives.installed_md5(host, password) == checksum
            for server in servers:
                server.shutdown()
                server.server_close()
            report['passed'] = report['passed'] and report.get('cleaned', False) and report['restored']
            report_name = 'profile-address-replacement-native.json' if args.replace_default else 'profile-address-handler-native.json'
            if args.legacy:
                report_name = 'profile-address-legacy-native.json'
            (ROOT / 'out' / report_name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
