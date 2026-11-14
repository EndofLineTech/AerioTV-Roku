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


def build(output, normal, section, base, form=False, default_form=False, held=False, active_form=False, active_recheck=False, recheck_cancel=False, identity_change=False, child_form=None, same_key=False, hold_cancel=False, child_rejected=False):
    if active_recheck:
        active_form = True
    if held:
        if default_form:
            raise ValueError('Held fixture covers a non-default holder only')
        form = True
    if default_form:
        form = True
    seeded = output.with_suffix('.seed.zip')
    child_mode = None
    if child_form:
        child_mode = 'default' if child_form.startswith('default') else 'own'
        if child_form.endswith('-pin'):
            child_mode += '-pin'
    module('management').build(seeded, normal, section, base, cold_restore='remembered' if active_form else None, child_available=child_mode)
    fixture_name = 'ProfileDefaultOwnSignInFormFixture.brs' if default_form else ('ProfileOwnSignInFormFixture.brs' if form else 'ProfileOwnSignInFixture.brs')
    if active_form:
        fixture_name = 'ProfileActiveOwnSignInFixture.brs'
    if active_recheck:
        fixture_name = 'ProfileOwnRecheckFixture.brs'
    if child_form:
        fixture_name = 'ProfileChildOwnSignInFormFixture.brs'
    if hold_cancel:
        fixture_name = 'ProfileOwnHeldKeyCancelFixture.brs'
    fixture = (ROOT / 'tests/native' / fixture_name).read_text()
    if same_key:
        recovered_key = 'synthetic-a' if default_form or child_form and child_form.startswith('default') else 'synthetic-b'
        fixture = fixture.replace('synthetic-new-own-key', recovered_key)
    fixture = fixture.replace('OWN_PROBE_HELD', 'true' if held else 'false')
    fixture = fixture.replace('OWN_RECHECK_CANCEL', 'true' if recheck_cancel else 'false')
    fixture = fixture.replace('OWN_ACTIVE_CONNECT', 'true' if identity_change else 'false')
    fixture = fixture.replace('OWN_CHILD_DEFAULT', 'true' if child_form and child_form.startswith('default') else 'false')
    fixture = fixture.replace('OWN_CHILD_PIN', 'true' if child_form and child_form.endswith('-pin') else 'false')
    fixture = fixture.replace('OWN_CHILD_HELD', 'true' if child_form == 'held-keyless' else 'false')
    fixture = fixture.replace('OWN_CHILD_REJECTED', 'true' if child_rejected else 'false')
    if form:
        fixture = fixture.replace('OWN_PROBE_PIN_HASH', hashlib.sha256(bytes.fromhex('bb' * 16) + b'1234').hexdigest())
    with zipfile.ZipFile(seeded) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if hold_cancel and name == 'components/RequestGateTask.brs':
                target = b'    else if action = "own-verified"\n'
                assert body.count(target) == 1
                body = body.replace(target, target + b'        sleep(4000)\n', 1)
            if name == 'components/AerioScene.brs':
                source = body.decode()
                assert source.count('sub onManagementProbeTick()') == 1
                if child_form and not child_rejected:
                    retire = '    m.registry.delete("connKey_slot-a")\n' if child_form.startswith('default') else '    m.registry.delete(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002"))\n'
                    if child_form == 'held-keyless':
                        retire += '''    childStore = loadUserProfileStore(m.registry, "slot-a")
    childStore.profiles[1] = setCanonicalPreference(childStore.profiles[1], "addressHeld", true)
    m.registry.write(userProfileStoreKey("slot-a"), FormatJson(childStore))
'''
                    source = source.replace('    m.registry.flush()', retire + '    m.registry.flush()', 1)
                body = (source.split('sub onManagementProbeTick()', 1)[0] + fixture).encode()
            package.writestr(name, body)
        package.writestr('profile-own-signin-probe.json', '{"synthetic":true}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--form', action='store_true', help='Exercise actual native form/keyboards and delayed-request Back cancellation')
    parser.add_argument('--default-form', action='store_true', help='Switch to B then recover inactive default A through its actual form')
    parser.add_argument('--held', action='store_true', help='Recover an inactive held holder; preserve another hold and show the changed-server message')
    parser.add_argument('--active-form', action='store_true', help='Qualify active nondefault rejection→own prompt/PIN/password→recreated holder reload and delayed Back')
    parser.add_argument('--active-recheck', action='store_true', help='Real one-minute own rejected-key probe behind closed content gates, then a fresh own-session reload')
    parser.add_argument('--recheck-cancel', action='store_true', help='Open the own native sign-in form while its scheduled real /me probe is in flight; reject late restoration')
    parser.add_argument('--identity-change', action='store_true', help='Return a 200 foreign-username /me during a PIN-admitted own reconnect, then qualify the same own recovery form')
    parser.add_argument('--child-form', choices=['own', 'own-pin', 'default', 'default-pin', 'held-keyless'], help='Private keyless Child own login, actual credential failures, delayed Back and fresh own-session activation')
    parser.add_argument('--same-key', action='store_true', help='Active own-form variant: password recovery returns the same previously rejected key hash')
    parser.add_argument('--hold-cancel', action='store_true', help='Cancel while a private delayed broker acknowledgement is pending; stale proof must not lift hold or commit')
    parser.add_argument('--child-rejected', action='store_true', help='Default Child form variant: reject its actual own slot key before recovering with own credentials')
    args = parser.parse_args()
    if args.child_rejected and args.child_form not in ['default', 'default-pin']:
        parser.error('--child-rejected requires --child-form default or default-pin')
    if args.hold_cancel and not (args.same_key and args.active_form):
        parser.error('--hold-cancel requires --active-form --same-key')
    if args.same_key and not args.child_rejected and (not args.active_form or args.active_recheck or args.identity_change or args.child_form or args.default_form or args.held):
        parser.error('--same-key requires a separate --active-form or --child-rejected case')
    if args.child_form:
        if args.default_form or args.held or args.active_form or args.active_recheck or args.identity_change:
            parser.error('--child-form is a separate case')
        args.form = True
        args.default_form = args.child_form.startswith('default')
    if args.identity_change:
        if args.default_form or args.held or args.active_recheck:
            parser.error('--identity-change is separate from default/held/recheck')
        args.active_form = True
    if args.recheck_cancel and not args.active_recheck:
        parser.error('--recheck-cancel requires --active-recheck')
    if args.active_recheck:
        args.active_form = True
    if args.active_form:
        if args.default_form or args.held:
            parser.error('--active-form is separate from default/held forms')
        args.form = True
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
    fixture_state = {'revoke_old': False, 'revoke_new': False}

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
                if args.same_key and scenario == 'correct':
                    fixture_state['revoke_old'] = False
                    fixture_state['same_key_adopted'] = True
                self.reply(200, {'access': 'fixture-' + scenario})

        def do_GET(self):
            bearer = self.headers.get('Authorization', '').removeprefix('Bearer ')
            scenario = bearer.removeprefix('fixture-') if bearer.startswith('fixture-') else ''
            key = self.headers.get('X-API-Key', '')
            returned_key = 'synthetic-a' if args.default_form else 'synthetic-b'
            hits.append({'method': 'GET', 'path': self.path, 'scenario': scenario, 'no_api_key': not key, 'default_key': key == 'synthetic-a', 'old_own_key': key == 'synthetic-b', 'new_own_key': key == 'synthetic-new-own-key' or (args.same_key and key == returned_key and fixture_state.get('same_key_adopted', False)), 'at': int(time.time())})
            value = []
            if self.path == '/api/accounts/users/me/':
                own_rejected = args.active_form and ((key == 'synthetic-b' and fixture_state['revoke_old']) or (key == 'synthetic-new-own-key' and fixture_state['revoke_new']))
                own_rejected = own_rejected or args.child_rejected and key == 'synthetic-a' and fixture_state['revoke_old']
                if not scenario and own_rejected:
                    if args.identity_change:
                        hits[-1]['foreign_identity'] = True
                        self.reply(200, {'id': 8 if key == 'synthetic-b' else 88, 'username': 'SyntheticForeign', 'user_level': 1})
                        return
                    hits[-1]['rejected'] = True
                    self.reply(401, {'detail': 'Invalid API key'})
                    return
                if args.recheck_cancel and fixture_state.get('recheck_boundary') is not None and key == 'synthetic-b' and not fixture_state.get('probe_cancelled'):
                    fixture_state['probe_cancelled'] = True
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Select', data=b'', method='POST')
                    urllib.request.urlopen(request, timeout=10).close()
                    time.sleep(4)
                holder = 8 if (args.default_form or args.active_form or args.child_form) and key == 'synthetic-b' else 7
                if (args.active_form or args.child_form and not args.default_form) and key == 'synthetic-new-own-key':
                    holder = 88
                if args.same_key and key == 'synthetic-b' and fixture_state.get('same_key_adopted', False):
                    holder = 88
                value = {'id': (7 if args.default_form else 88) if scenario else holder, 'username': ('Synthetic7' if args.default_form else 'Synthetic8') if scenario else f'Synthetic{holder}', 'user_level': 1}
                if (args.active_form or args.child_form) and holder == 88:
                    value['username'] = 'Synthetic8'
                if scenario:
                    value['api_key'] = None if scenario == 'no-api' else 'synthetic-new-own-key'
                    if args.same_key and scenario != 'no-api':
                        value['api_key'] = returned_key
                    if scenario == 'name':
                        value['username'] = 'DifferentUser'
                    if scenario == 'id':
                        value['id'] = 88
                    if scenario == 'delayed':
                        time.sleep(4)
                        value['api_key'] = 'synthetic-must-not-save'
            elif self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
            if args.child_form and self.path.split('?', 1)[0] == '/api/channels/profiles/':
                value = [{'id': 99, 'name': 'Synthetic first', 'channels': [7]}, {'id': 100, 'name': 'Synthetic second', 'channels': [7]}]
            if args.child_form and self.path.split('?', 1)[0] in ['/api/channels/channels/', '/api/channels/channels/summary/']:
                content = 7 if args.default_form else 8
                value = [{'id': content, 'uuid': f'00000000-0000-4000-8000-{content:012d}', 'name': 'Synthetic own channel', 'channel_number': content}]
            self.reply(200, value)

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioOwnSignInProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-own-signin-probe.zip'
    cleaner = ROOT / 'out/profile-own-signin-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}', args.form, args.default_form, args.held, args.active_form, args.active_recheck, args.recheck_cancel, args.identity_change, args.child_form, args.same_key, args.hold_cancel, args.child_rejected)
    recovery.cleanup_package(cleaner, section)
    report = {'passed': False}

    def run(path, marker, prefix):
        command = ['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '110' if args.active_recheck and path == archive else '60']
        if path != archive or not args.form:
            return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=110)
        output = []
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
            for line in process.stdout:
                output.append(line)
                if '"kind":"revoke-ready"' in line:
                    fixture_state['revoke_old'] = True
                if '"kind":"revoke-new-ready"' in line:
                    fixture_state['revoke_new'] = True
                    if args.same_key:
                        fixture_state['revoke_old'] = True
                if '"kind":"recheck-ready"' in line:
                    fixture_state['revoke_old'] = False
                    fixture_state['recheck_boundary'] = len(hits)
                if '"kind":"child-pin-ready"' in line:
                    report['pre_pin_requests'] = list(hits)
                if '"kind":"child-form-ready"' in line:
                    report['pre_form_requests'] = list(hits)
                    fixture_state['child_form_boundary'] = len(hits)
                if '"kind":"cancel-ready"' in line:
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                    with urllib.request.urlopen(request, timeout=10) as response:
                        report['back_sent'] = response.status == 200
                        report['back_at'] = time.monotonic()
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
        if args.active_form:
            report['passed'] = result.returncode == 0 and [row.get('scenario') for row in cases] == expected_cases and all(row.get('passed') for row in cases) and rows[-1].get('passed') and all(rows[-1].get(key) for key in ['cancelled', 'default_preserved', 'own_key_absent', 'active_preserved', 'no_autoplay']) and [hit['scenario'] for hit in posts] == expected_posts and all(hit['no_api_key'] and hit['username_ok'] for hit in posts) and all(not hit.get('default_key') for hit in hits) and any(hit.get('new_own_key') and hit['path'] == '/api/accounts/users/me/app-data/' for hit in hits)
            if args.identity_change:
                foreign = [index for index, hit in enumerate(hits) if hit.get('foreign_identity')]
                bounded = len(foreign) == 2 and all(hits[index]['path'] == '/api/accounts/users/me/' for index in foreign)
                for index in foreign:
                    end = next((j for j in range(index + 1, len(hits)) if hits[j]['method'] == 'POST'), len(hits))
                    bounded = bounded and all(hit['no_api_key'] for hit in hits[index + 1:end])
                report['foreign_identity_bounded'] = bounded
                report['passed'] = report['passed'] and bounded
        if args.active_recheck:
            boundary = fixture_state.get('recheck_boundary')
            rejected = [hit for hit in hits if hit.get('rejected')]
            later = hits[boundary:] if boundary is not None else []
            paced = len(rejected) == 1 and bool(later) and later[0]['path'] == '/api/accounts/users/me/' and later[0]['at'] >= rejected[0]['at'] + 60
            report['paced'] = paced
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and rows[-1].get('default_preserved') and paced and not posts and all(not hit.get('default_key') for hit in hits)
            if args.recheck_cancel:
                report['passed'] = report['passed'] and fixture_state.get('probe_cancelled', False) and len(later) == 1 and rows[-1].get('own_key_absent') and rows[-1].get('protected') and rows[-1].get('retired')
        if args.child_form:
            cancelled = [row for row in rows if row.get('kind') == 'cancelled']
            expected_posts = expected_cases[:-1] + ['delayed', 'correct']
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and [row.get('scenario') for row in cases] == expected_cases and all(row.get('passed') for row in cases) and len(cancelled) == 1 and cancelled[0].get('passed') and report.get('pre_form_requests') == [] and [hit['scenario'] for hit in posts] == expected_posts and all(hit['no_api_key'] and hit['username_ok'] for hit in posts) and all(hit['no_api_key'] or hit.get('new_own_key') for hit in hits)
            report['passed'] = report['passed'] and report.get('back_sent') is True and rows[-1].get('runtime_defaults') is True
            if args.child_rejected:
                boundary = fixture_state.get('child_form_boundary')
                later = hits[boundary:] if boundary is not None else []
                report['passed'] = result.returncode == 0 and rows[-1].get('passed') and [row.get('scenario') for row in cases] == expected_cases and all(row.get('passed') for row in cases) and len(cancelled) == 1 and cancelled[0].get('passed') and [hit['scenario'] for hit in posts] == expected_posts and all(hit['no_api_key'] and hit['username_ok'] for hit in posts) and bool(later) and all(hit['no_api_key'] or hit.get('new_own_key') for hit in later) and report.get('back_sent') is True
            if args.child_form.endswith('-pin'):
                report['passed'] = report['passed'] and report.get('pre_pin_requests') == []
        if args.hold_cancel:
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and all(rows[-1].get(key) for key in ['unchanged', 'retired', 'held', 'no_autoplay']) and report.get('back_sent') is True and [hit['scenario'] for hit in posts] == ['correct']
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
            if args.active_form:
                report_name = 'profile-active-own-signin-form-native.json'
                if args.identity_change:
                    report_name = 'profile-active-identity-recovery-native.json'
                if args.same_key:
                    report_name = 'profile-active-same-key-recovery-native.json'
                    if args.hold_cancel:
                        report_name = 'profile-active-same-key-cancel-native.json'
            if args.active_recheck:
                report_name = 'profile-active-own-recheck-native.json'
                if args.recheck_cancel:
                    report_name = 'profile-active-own-recheck-cancel-native.json'
            if args.child_form:
                report_name = f'profile-child-own-form-{args.child_form}-native.json'
                if args.child_rejected:
                    report_name = f'profile-child-rejected-{args.child_form}-native.json'
                    if args.same_key:
                        report_name = f'profile-child-same-key-{args.child_form}-native.json'
            (ROOT / 'out' / report_name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
