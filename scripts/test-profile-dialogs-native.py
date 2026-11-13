"""Exercise synthetic native PIN/credential dialogs and restore the prior app."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output):
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        package.writestr('manifest', 'title=Aerio Profile Dialog Probe\nmajor_version=0\nminor_version=0\nbuild_version=1\nui_resolutions=fhd\nrsg_version=1.3\nsupports_input_launch=1\n')
        package.write(ROOT / 'tests/native/UserProfileDialogMain.brs', 'source/Main.brs')
        package.write(ROOT / 'source/StartupBeaconModel.brs', 'source/StartupBeaconModel.brs')
        package.write(ROOT / 'source/SceneUi.brs', 'source/SceneUi.brs')
        for suffix in ['xml', 'brs']:
            package.write(ROOT / f'tests/native/UserProfileDialogProbe.{suffix}', f'components/UserProfileDialogProbe.{suffix}')
        package.writestr('profile-probe-config.json', '{"synthetic":true}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    args = parser.parse_args()
    host = os.environ['ROKU_HOST']
    spec = importlib.util.spec_from_file_location('native_primitives', ROOT / 'scripts/test-profile-primitives-native.py')
    primitives = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(primitives)
    restore = Path(args.restore)
    restore_md5 = hashlib.md5(restore.read_bytes()).hexdigest()
    if primitives.installed_md5(host, os.environ['ROKU_DEV_PASSWORD']) != restore_md5:
        raise RuntimeError('Restore ZIP differs from installed app; refusing replacement')
    archive = ROOT / 'out/user-profile-dialog-probe.zip'
    build(archive)
    evidence = []
    stage = 'digits-first'

    def post(path):
        request = urllib.request.Request(f'http://{host}:8060/{path}', data=b'', method='POST')
        urllib.request.urlopen(request, timeout=10).close()

    def mode(value):
        post('input?' + urllib.parse.urlencode({'profileProbeMode': value}))

    def keys(text):
        for char in text:
            post('keypress/' + urllib.parse.quote('Lit_' + char, safe=''))

    def capture(name):
        subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', f'out/profile-dialog-{name}.jpg'], cwd=ROOT, check=True, capture_output=True, timeout=45)

    report = {'passed': False, 'restore_sha256': hashlib.sha256(restore.read_bytes()).hexdigest(),
              'probe_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'events': evidence}
    process = None
    try:
        process = subprocess.Popen(['python3', 'scripts/run-native-probe.py', str(archive), '--prefix', '[profile-dialog]', '--marker', '[profile-dialog] complete', '--timeout', '90'], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end='', flush=True)
            marker = '[profile-dialog] '
            if marker not in line or '{' not in line:
                continue
            row = json.loads(line.split(marker, 1)[1])
            evidence.append(row)
            assert row.get('protected') is False, 'Protected fixture must remain covered'
            if row['kind'] == 'ready':
                if row['mode'] in ['numbers', 'launch', 'password']:
                    assert row['secure'] is True, 'Native masking unavailable'
                    assert row['lastmasked'] is True, 'Last-character masking unavailable on qualification device'
                if row['mode'] in ['numbers', 'launch']:
                    assert row['maximum'] == 6
                if stage == 'digits-first':
                    keys('0123456789')
                elif stage == 'digits-second':
                    keys('6789')
                elif stage == 'password':
                    keys('1234')
                elif stage == 'home':
                    post('keypress/Home')
                    time.sleep(0.5)
                    active = urllib.request.urlopen(f'http://{host}:8060/query/active-app', timeout=10).read()
                    assert b'id="dev"' not in active
                    evidence.append({'kind': 'home-exits-app', 'passed': True})
                    stage = 'restart'
                    post('launch/dev')
                elif stage == 'restart':
                    stage = 'email'
                    mode('email')
                elif stage == 'email':
                    keys('test@example.test')
                elif stage == 'launch':
                    mode('password')
            elif row['kind'] == 'input':
                if stage == 'digits-first' and row['length'] == 6:
                    capture('numbers-masked')
                    post('keypress/Back')
                elif stage == 'digits-second' and row['length'] == 4:
                    post('keypress/Info')  # ECP name for the remote's Options (*) key.
                    time.sleep(0.25)
                    mode('inspect')
                elif stage == 'password' and row['length'] == 4:
                    time.sleep(1.5)  # Native secure mode briefly reveals the last typed character.
                    capture('password-masked')
                    post('keypress/Back')
                elif stage == 'email' and row['length'] == len('test@example.test'):
                    post('keypress/Back')
            elif row['kind'] == 'closed':
                if stage == 'digits-first':
                    stage = 'digits-second'
                    mode('numbers')
                elif stage == 'digits-second':
                    stage = 'password'
                    mode('password')
                elif stage == 'password':
                    stage = 'home'
                    mode('numbers')
                elif stage == 'email':
                    stage = 'beacons'
                    mode('beacons')
                elif stage == 'launch':
                    stage = 'finished'
            elif row['kind'] == 'second-dialog-blocked':
                capture('launch-gate')
                post('keypress/Back')
            elif row['kind'] == 'inspect' and stage == 'digits-second' and row['mode'] == 'numbers' and row['open']:
                evidence.append({'kind': 'options-keeps-native-keypad-open', 'passed': True})
                post('keypress/Back')
            elif row['kind'] == 'beacon-complete':
                assert row['dialogclosed'] is True and row['launchsent'] is True
                assert 2500 <= row['chargedms'] < 15000
                stage = 'launch'
                mode('launch')
        code = process.wait(timeout=10)
        report['passed'] = code == 0 and stage == 'finished'
        assert report['passed'], 'Dialog probe did not complete its native cases'
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        restored = subprocess.run(['python3', 'scripts/run-native-probe.py', str(restore), '--prefix', '[profile-restore]', '--marker', 'Running dev', '--timeout', '30'], cwd=ROOT, capture_output=True, text=True, timeout=80)
        report['restored'] = restored.returncode == 0 and primitives.installed_md5(host, os.environ['ROKU_DEV_PASSWORD']) == restore_md5
        (ROOT / 'out/profile-dialogs-native.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Exact prior developer app restored:', report['restored'], flush=True)
        if not report['restored']:
            raise RuntimeError('Prior developer app restore failed')


if __name__ == '__main__':
    main()
