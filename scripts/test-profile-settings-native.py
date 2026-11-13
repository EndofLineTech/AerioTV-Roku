"""Exercise normal-app account settings A/B/A using private synthetic slots."""
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


def build(output, normal, section, base, case):
    connections = {'schema': 1, 'selected': 'slot-b' if case == 'B' else 'slot-a', 'entries': [
        {'id': 'slot-a', 'name': 'Synthetic A', 'provider': 'dispatcharr', 'url': base, 'remember': True, 'accountId': '7'},
        {'id': 'slot-b', 'name': 'Synthetic B', 'provider': 'dispatcharr', 'url': base, 'remember': True, 'accountId': '8'}]}
    seed = {'case': case, 'connections': connections}
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'manifest':
                body = body.replace(b'title=AerioTV\n', b'title=Aerio Profile Settings Probe\n')
            if name == 'components/AerioScene.brs':
                source = body.decode()
                target = 'm.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert source.count(target) == 1
                hook = f'''m.registry = CreateObject("roRegistrySection", "{section}")
    fixture = ParseJson(ReadAsciiFile("pkg:/profile-settings-probe.json"))
    if not m.registry.exists("settingsV1")
        prefs = defaultPreferenceStore()
        prefs.device = normalizeDevicePreferences({{themePreset: "sunset"}})
        a = normalizeAccountPreferences({{favoriteIds: ["7"]}})
        b = normalizeAccountPreferences({{favoriteIds: ["8"]}})
        history = vodHistory([{{id: "1", uuid: "00000000-0000-4000-8000-000000000099", kind: "movie", title: "Synthetic history"}}])
        a = setCanonicalPreference(a, "vodRecent", history)
        b = setCanonicalPreference(b, "vodRecent", history)
        b = setCanonicalPreference(b, "profileSettings", normalizeUserProfileSettings({{themePreset: "forest"}}))
        prefs.accounts[preferenceScope("{base}|7|slot-a")] = a
        prefs.accounts[preferenceScope("{base}|8|slot-b")] = b
        m.registry.write("settingsV1", FormatJson(prefs))
    end if
    m.registry.write("connectionsV1", FormatJson(fixture.connections))
    m.registry.write("connKey_slot-a", "synthetic-a")
    m.registry.write("connKey_slot-b", "synthetic-b")
    m.registry.flush()'''
                source = source.replace(target, hook, 1)
                target = '    m.guide.config = {\n'
                assert source.count(target) == 1
                evidence = '''    fixture = ParseJson(ReadAsciiFile("pkg:/profile-settings-probe.json"))
    beforeTheme = m.devicePreferences.themePreset
    rollback = true
    if fixture.case = "A"
        m.devicePreferences = setCanonicalPreference(m.devicePreferences, "themePreset", "midnight")
        if not persistPreferences() then stop
        applyDevicePreferences()
        real = m.registry
        beforeFailure = real.read("settingsV1")
        m.registry = {section: real, failonce: true
            exists: function(key as string) as boolean
                return m.section.exists(key)
            end function
            read: function(key as string) as string
                return m.section.read(key)
            end function
            write: function(key as string, value as string) as boolean
                return m.section.write(key, value)
            end function
            delete: function(key as string) as boolean
                return m.section.delete(key)
            end function
            flush: function() as boolean
                if m.failonce
                    m.failonce = false
                    return false
                end if
                return m.section.flush()
            end function
        }
        failed = not persistRemoteMap(setRemoteAction(defaultRemoteMap(), "guide", "replay", "openOptions"))
        m.registry = real
        rollback = failed and beforeFailure = real.read("settingsV1") and m.preferenceStore.device.themePreset = "sunset" and m.devicePreferences.themePreset = "midnight"
    end if
    stableDefault = true
    if fixture.case = "A" then m.registry.write("fixtureAProfile", m.activeUserScope.profileId)
    if fixture.case = "Aagain" then stableDefault = m.registry.read("fixtureAProfile") = m.activeUserScope.profileId
    m.registry.flush()
    lineup = ""
    if result.channels.count() = 1 then lineup = result.channels[0].id
    m.scopeFixtureEvidence = {kind: "result", case: fixture.case, before: beforeTheme, theme: m.devicePreferences.themePreset, applied: m.global.appearance.themePreset, baseline: m.preferenceStore.device.themePreset, favorite: m.accountPreferences.favoriteIds[0], accounts: m.preferenceStore.accounts.count(), lineup: lineup, rollback: rollback, stabledefault: stableDefault, scoped: m.activeUserScope.preferenceIdentity = m.accountIdentity}
    m.scopeFixturePhase = 0
    m.scopeFixtureAttempts = 0
    m.scopeFixtureTimer = m.top.createChild("Timer")
    m.scopeFixtureTimer.duration = 0.25
    m.scopeFixtureTimer.repeat = true
    m.scopeFixtureTimer.observeField("fire", "onScopeFixturePhase")
    m.scopeFixtureTimer.control = "start"
'''
                source = source.replace(target, evidence + target, 1)
                source += '''
sub onScopeFixturePhase()
    m.scopeFixtureAttempts++
    ok = true
    if m.scopeFixturePhase = 0
        if not m.guide.callFunc("scopeFixtureToggleFavorite")
            if m.scopeFixtureAttempts < 20 then return
            ok = false
        end if
        m.scopeFixturePhase = 1
        if ok then return
    else if m.scopeFixturePhase = 1
        ok = m.accountPreferences.favoriteIds.count() = 0
        if ok
            m.guide.callFunc("scopeFixtureToggleFavorite")
            m.scopeFixturePhase = 2
            return
        end if
    else if m.scopeFixturePhase = 2
        ok = m.accountPreferences.favoriteIds.count() = 1
        if ok
            openSettingsHub()
            m.guide.preferences = userViewEvent({favoriteIds: ["stale-injected"]}, "stale-fixture-session")
            m.vod.stateChange = userViewEvent({scope: normalizeBaseUrl(m.baseUrl) + "|" + m.serverAccountId, clearHistory: true}, "stale-fixture-session")
            m.settingsHub.selection = userViewEvent({account: m.accountIdentity, scope: "device", key: "themePreset", value: "sunset"}, "stale-fixture-session")
            m.scopeFixturePhase = 3
            return
        end if
    else if m.scopeFixturePhase = 3
        ok = m.accountPreferences.favoriteIds.count() = 1
        if ok then ok = m.accountPreferences.favoriteIds[0] = m.scopeFixtureEvidence.favorite
        ok = ok and m.accountPreferences.vodRecent.count() = 1 and m.devicePreferences.themePreset = m.scopeFixtureEvidence.theme
        ok = ok and instr(1, m.registry.read("settingsV1"), "aeriosession") = 0
        closeSettingsHub()
        if ok
            m.scopeFixturePlayback = m.playingChannel
            m.guide.watchChannel = userViewEvent(m.guide.config.channels[0], "stale-fixture-session")
            m.browser.channelSelected = userViewEvent(m.guide.config.channels[0], "stale-fixture-session")
            m.guide.historyRequest = userViewEvent({account: m.accountIdentity, uuid: m.guide.config.channels[0].uuid}, "stale-fixture-session")
            m.scopeFixturePhase = 4
            return
        end if
    else if m.scopeFixturePhase = 4
        ok = m.playingChannel = invalid and m.top.dialog = invalid and m.page = "guide"
        if ok
            m.page = "onDemand"
            m.mediaPlayer.closedContext = userViewEvent({closed: true}, "stale-fixture-session")
            m.mediaPlayer.archiveSeekContext = userViewEvent({target: 60}, "stale-fixture-session")
            m.mediaPlayer.goLiveContext = userViewEvent({requested: true}, "stale-fixture-session")
            m.scopeFixturePhase = 5
            return
        end if
    else
        ok = m.page = "onDemand" and m.playingChannel = invalid
        m.page = "guide"
    end if
    m.scopeFixtureTimer.control = "stop"
    m.scopeFixtureEvidence.events = ok
    print "[profile-settings] "; FormatJson(m.scopeFixtureEvidence)
end sub
'''
                body = source.encode()
            if name == 'components/GuideView.xml':
                body = body.replace(b'<interface>', b'<interface>\n    <function name="scopeFixtureToggleFavorite" />', 1)
            if name == 'components/GuideView.brs':
                body += b'''
function scopeFixtureToggleFavorite() as boolean
    if not m.ready or m.channels.count() <> 1 then return false
    uuid = m.channels[0].uuid
    if m.favorites.doesExist(uuid) then m.favorites.delete(uuid) else m.favorites[uuid] = true
    savePreferences()
    return true
end function
'''
            if name == 'source/MetadataCacheStore.brs':
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/profile-settings-fixture-cache"')
            package.writestr(name, body)
        package.writestr('profile-settings-probe.json', json.dumps(seed))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    args = parser.parse_args()
    host = os.environ['ROKU_HOST']
    password = os.environ['ROKU_DEV_PASSWORD']
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

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            key = self.headers.get('X-API-Key')
            if not key:
                key = self.headers.get('Authorization', '').removeprefix('API-Key ')
            user = 8 if key == 'synthetic-b' else 7
            path = self.path.split('?', 1)[0]
            response = []
            if path == '/api/accounts/users/me/':
                response = {'id': user, 'username': 'Synthetic' + str(user), 'user_level': 1,
                            'custom_properties': {'dvr_access': 'none', 'vod_movies_enabled': False, 'vod_series_enabled': False}}
            elif path in ['/api/channels/channels/', '/api/channels/channels/summary/']:
                response = [{'id': user, 'uuid': f'00000000-0000-4000-8000-{user:012d}', 'name': 'Synthetic ' + str(user), 'channel_number': user}]
            status = 200
            if key not in ['synthetic-a', 'synthetic-b']:
                status = 401
                response = {'detail': 'Invalid API key'}
            body = json.dumps(response).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f'http://{local}:{server.server_port}'
    section = 'AerioProfileSettingsProbe-' + str(uuid.uuid4())
    cleaner = ROOT / 'out/profile-settings-cleanup.zip'
    modules['recovery'].cleanup_package(cleaner, section)
    report = {'passed': False, 'cases': [], 'restore_sha256': hashlib.sha256(restore.read_bytes()).hexdigest()}

    def run(path, marker, prefix='[profile-settings]'):
        return subprocess.run(['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix,
                               '--marker', marker, '--timeout', '40'], cwd=ROOT, capture_output=True, text=True, timeout=90)

    def restore_prior():
        restored = run(restore, 'Running dev')
        ok = restored.returncode == 0 and modules['primitives'].installed_md5(host, password) == checksum
        if not ok:
            raise RuntimeError('Exact prior app restore failed')

    try:
        for case, before, theme, favorite in [('A', 'sunset', 'midnight', '7'), ('B', 'forest', 'forest', '8'), ('Aagain', 'midnight', 'midnight', '7')]:
            archive = ROOT / f'out/profile-settings-{case}-probe.zip'
            build(archive, ROOT / 'out/aeriotv-roku.zip', section, base, case)
            try:
                result = run(archive, '[profile-settings] {')
                print(result.stdout, end='', flush=True)
                rows = [json.loads(line.split('[profile-settings] ', 1)[1]) for line in result.stdout.splitlines() if '[profile-settings] {' in line]
                if result.returncode or len(rows) != 1:
                    raise RuntimeError('Normal-app settings fixture did not complete')
                row = rows[0]
                report['cases'].append(row)
                if row.get('before') != before or row.get('theme') != theme or row.get('applied') != theme or row.get('baseline') != 'sunset' or row.get('favorite') != favorite or row.get('lineup') != favorite or row.get('accounts') != 2 or not row.get('events') or not row.get('rollback') or not row.get('stabledefault') or not row.get('scoped'):
                    raise RuntimeError('Normal-app scoped A/B/A assertion failed')
                time.sleep(3)  # Allow the real guide's first rendered frame.
                captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', f'out/profile-settings-{case}.jpg'], cwd=ROOT, capture_output=True, text=True, timeout=45)
                row['screenshot'] = captured.returncode == 0
                if not row['screenshot']:
                    raise RuntimeError('Synthetic settings screenshot capture failed')
            finally:
                restore_prior()
        report['passed'] = True
    finally:
        try:
            result = run(cleaner, '[profile-recovery] cleanup=', '[profile-recovery]')
            report['cleaned'] = result.returncode == 0 and '[profile-recovery] cleanup=true' in result.stdout
        finally:
            restore_prior()
            report['restored'] = True
            server.shutdown()
            server.server_close()
            report['passed'] = report['passed'] and report.get('cleaned', False)
            (ROOT / 'out/profile-settings-native.json').write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
    if not report['passed']:
        raise SystemExit('Normal-app settings isolation failed')


if __name__ == '__main__':
    main()
