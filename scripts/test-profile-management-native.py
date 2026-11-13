"""Private normal-app profile metadata and adult-purpose native-dialog probe."""
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


def build(output, normal, section, base, directions=False, switching=False, switch_pin=False, cancel_pin=False, reject_active=False, remember_off=False, child_settings=False):
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if name == 'manifest':
                body = body.replace(b'title=AerioTV\n', b'title=Aerio Profile Management Probe\n')
                if directions:
                    body += b'\naeriotv_profile_directions_test=1\n'
            if name == 'source/MetadataCacheStore.brs':
                assert body.count(b'"cachefs:/aeriotv-metadata-v1"') == 1
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/profile-management-cache"')
            if switching and name == 'components/GuideView.xml':
                body = body.replace(b'</interface>', b'<function name="profileSwitchProbeLineup" /></interface>', 1)
            if switching and name == 'components/GuideView.brs':
                body += b'''\nfunction profileSwitchProbeLineup() as string
    if type(m.channels) <> "roArray" then return ""
    if m.channels.count() = 0 then return ""
    return m.channels[0].id
end function
'''
            if child_settings and name == 'components/SettingsHub.xml':
                body = body.replace(b'</interface>', b'<function name="childSettingsProbe" /></interface>', 1)
            if child_settings and name == 'components/SettingsHub.brs':
                body += b'''\nfunction childSettingsProbe(page as string) as object
    m.page = page
    renderSettings()
    pages = []
    for each entry in settingsHubEntries("", m.top.model)
        pages.push(entry.page)
    end for
    return {page: m.page, pages: pages, role: m.top.model.userRole}
end function
'''
            if name == 'components/AerioScene.brs':
                source = body.decode()
                target = 'm.registry = CreateObject("roRegistrySection", "AerioTV")'
                assert source.count(target) == 1
                source = source.replace(target, f'''m.registry = CreateObject("roRegistrySection", "{section}")
    entry = normalizeConnectionEntry({{id: "slot-a", name: "Synthetic", provider: "dispatcharr", url: "{base}", accountId: "7", remember: true}})
    m.registry.write("connectionsV1", FormatJson({{schema: 1, selected: "slot-a", entries: [entry]}}))
    m.registry.write("connKey_slot-a", "synthetic-a")
    m.registry.flush()''', 1)
                target = '    m.guide.config = {\n'
                assert source.count(target) == 1
                source = source.replace(target, '''    m.managementProbeClock = m.top.createChild("Timer")
    m.managementProbeClock.duration = 1
    m.managementProbeClock.repeat = true
    m.managementProbeClock.observeField("fire", "onManagementProbeTick")
    m.managementProbePhase = 0
    m.managementProbeClock.control = "start"
''' + target, 1)
                source += '''
function managementProbeEvent(node as object, index as integer) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.index
    end function}
end function

sub onManagementProbeTick()
    m.managementProbePhase++
    phase = m.managementProbePhase
    if phase = 1
        store = loadUserProfileStore(m.registry, m.selectedConnectionId)
        adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        adult.isDefault = false
        adult.order = 1
        adult.pinType = "numbers"
        adult.pinSalt = string(32, "b")
        adult.pinHash = userProfilePinHash(adult.pinSalt, "1234")
        store.profiles.push(adult)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        openUserProfileManagement()
        print "[profile-management] "; FormatJson({kind: "roster", dialog: m.profileManagementDialog <> invalid, choices: m.profileManagementChoices.count()})
    else if phase = 2
        onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
    else if phase = 3
        onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
        print "[profile-management] "; FormatJson({kind: "keyboard", native: m.profileManagementDialog.subtype() = "StandardKeyboardDialog"})
    else if phase = 4
        m.profileManagementDialog.text = "Renamed Synthetic"
        onProfileManagementName(managementProbeEvent(m.profileManagementDialog, 0))
        store = loadUserProfileStore(m.registry, "slot-a")
        m.managementProbeRenamed = store.profiles[0].displayName = "Renamed Synthetic" and store.profiles[0].displayNameClaimed
        closeProfileManagementDialog()
        m.profileManagementPending = {id: store.profiles[0].id}
        beginAdultProfilePinGate()
        print "[profile-management] "; FormatJson({kind: "adult", native: m.adultPinDialog.subtype() = "StandardPinPadDialog", title: m.adultPinDialog.title, covered: m.profileGateCover.visible})
    else if phase = 5
        m.adultPinDialog.textEditBox.text = "9999"
        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
        m.managementProbeWrong = m.profileManagementGrant = invalid and m.adultPinDialog.textEditBox.text = "" and m.adultPinDialog.title = "Wrong PIN"
    else if phase = 6
        m.adultPinDialog.textEditBox.text = "1234"
        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
        store = loadUserProfileStore(m.registry, "slot-a")
        m.managementProbeEvidence = {kind: "result", renamed: m.managementProbeRenamed, wrong: m.managementProbeWrong, grant: userProfileManagementGrantMatches(store, invalid, m.profileManagementGrant, m.profileManagementNonce, true), learned: store.profiles[1].pinLength = 4, management: m.profileManagementDialog <> invalid, uncovered: not m.profileGateCover.visible, preserved: m.registry.read("connKey_slot-a") = "synthetic-a", no_unlock: m.profileUnlockGrant = invalid}
    else if phase = 7
        closeProfileManagementDialog()
        beginAdultProfilePinGate()
    else if phase = 8
        print "[profile-management] "; FormatJson({kind: "cancel-ready", covered: m.profileGateCover.visible})
    else if phase = 10
        m.managementProbeClock.control = "stop"
        m.managementProbeEvidence.cancelled = m.adultPinDialog = invalid and m.profileManagementGrant = invalid and not m.profileGateCover.visible and not m.global.profilegateclosed and m.top.exitRequested <> true
        m.managementProbeEvidence.cancel_dialog = m.adultPinDialog = invalid
        m.managementProbeEvidence.cancel_grant = m.profileManagementGrant = invalid
        m.managementProbeEvidence.cancel_cover = m.profileGateCover.visible
        m.managementProbeEvidence.cancel_closed = m.global.profilegateclosed
        m.managementProbeEvidence.cancel_exit = m.top.exitRequested
        print "[profile-management] "; FormatJson(m.managementProbeEvidence)
    end if
end sub
'''
                if directions:
                    source = source.replace('adult.pinType = "numbers"', 'adult.pinType = "directions"').replace('userProfilePinHash(adult.pinSalt, "1234")', 'userProfilePinHash(adult.pinSalt, "UDLR")')
                    source = source.replace('store.profiles.push(adult)', '''store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinType", "numbers")
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinSalt", adult.pinSalt)
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "pinHash", userProfilePinHash(adult.pinSalt, "5678"))
        store.profiles.push(adult)''')
                    source = source.replace('        beginAdultProfilePinGate()\n', '        beginAdultProfilePinGate()\n        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 1))\n')
                    source = source.replace('m.adultPinDialog.subtype() = "StandardPinPadDialog"', 'm.adultPinDialog.subtype() = "DirectionsPinPad"')
                    source = source.replace('text = "9999"', 'text = "UUUU"').replace('text = "1234"', 'text = "UDLR"')
                if switching:
                    source = source.split('sub onManagementProbeTick()', 1)[0] + '''sub onManagementProbeTick()
    m.managementProbePhase++
    phase = m.managementProbePhase
    if phase = 1
        store = loadUserProfileStore(m.registry, "slot-a")
        m.switchProbeDefault = store.active
        m.switchProbeFirstSession = currentUserSessionId()
        adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        adult.isDefault = false
        adult.order = 1
        store.profiles.push(adult)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.write(userProfileKeyName("slot-a", adult.id), "synthetic-b")
        m.accountPreferences.favoriteIds = ["7"]
        m.devicePreferences = setCanonicalPreference(m.devicePreferences, "themePreset", "midnight")
        m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "8"))] = normalizeAccountPreferences({favoriteIds: ["8"], profileSettings: {themePreset: "forest"}})
        m.registry.write("settingsV1", FormatJson(m.preferenceStore))
        m.registry.flush()
    else if phase = 2
        started = beginUserProfileSwitch("00000000-0000-4000-8000-000000000002")
        print "[profile-management] "; FormatJson({kind: "switch-start", started: started})
    else if phase = 3
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return
        m.switchProbeB = m.activeUserScope.profileId = "00000000-0000-4000-8000-000000000002" and m.accountPreferences.favoriteIds[0] = "8" and m.devicePreferences.themePreset = "forest" and m.apiKey = "synthetic-b" and m.guide.callFunc("profileSwitchProbeLineup") = "8"
        print "[profile-management] "; FormatJson({kind: "switch-b", own: m.switchProbeB})
    else if phase = 4
        m.switchProbeBackStarted = beginUserProfileSwitch(m.switchProbeDefault)
    else if phase = 5
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return
        m.switchProbeA = m.activeUserScope.profileId = m.switchProbeDefault and m.accountPreferences.favoriteIds[0] = "7" and m.devicePreferences.themePreset = "midnight" and currentUserSessionId() <> m.switchProbeFirstSession and m.apiKey = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "7"
        m.switchProbeSecondSession = currentUserSessionId()
        print "[profile-management] "; FormatJson({kind: "switch-a", own: m.switchProbeA, started: m.switchProbeBackStarted})
    else if phase = 6
        m.registry.write(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002"), "rejected-synthetic-key")
        m.profileSessionKeys[preferenceScope(m.baseUrl + "|slot-a|00000000-0000-4000-8000-000000000002")] = "rejected-synthetic-key"
        m.registry.flush()
        m.switchProbeRejectStarted = beginUserProfileSwitch("00000000-0000-4000-8000-000000000002")
    else if phase = 7
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.switchProbeEvidence = {kind: "result", b: m.switchProbeB, a: m.switchProbeA, rollback: m.switchProbeRejectStarted and store.active = m.switchProbeDefault and m.activeUserScope.profileId = m.switchProbeDefault and currentUserSessionId() <> m.switchProbeSecondSession and m.apiKey = "synthetic-a", preserved: m.registry.read("connKey_slot-a") = "synthetic-a", uncovered: not m.profileGateCover.visible, no_autoplay: m.playingChannel = invalid}
    else if phase = 8
        m.registry.write(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002"), "delayed-b")
        m.profileSessionKeys[preferenceScope(m.baseUrl + "|slot-a|00000000-0000-4000-8000-000000000002")] = "delayed-b"
        m.registry.flush()
        m.switchProbeBeforeCancel = currentUserSessionId()
        m.switchProbeCancelStarted = beginUserProfileSwitch("00000000-0000-4000-8000-000000000002")
    else if phase = 9
        if m.profilePinDialog <> invalid
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        end if
    else if phase = 10
        print "[profile-management] "; FormatJson({kind: "cancel-ready", covered: m.profileGateCover.visible})
    else if phase = 15
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        m.switchProbeEvidence.cancelled = m.switchProbeCancelStarted and m.profileSwitchContext = invalid and store.active = m.switchProbeDefault and m.activeUserScope.profileId = m.switchProbeDefault and currentUserSessionId() <> m.switchProbeBeforeCancel and not m.profileGateCover.visible
        m.switchProbeEvidence.stale_a = not userEventCurrent(userViewEvent({action: "connection"}, m.switchProbeFirstSession))
        print "[profile-management] "; FormatJson(m.switchProbeEvidence)
    end if
end sub
'''
                    if switch_pin:
                        source = source.replace('        store.profiles.push(adult)', '''        adult.pinType = "numbers"
        adult.pinSalt = string(32, "b")
        adult.pinHash = userProfilePinHash(adult.pinSalt, "1234")
        store.profiles.push(adult)''')
                        source = source.replace('        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return', '''        if m.profilePinDialog <> invalid
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        end if
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return''')
                    if cancel_pin:
                        source = source.replace('''    else if phase = 9
        if m.profilePinDialog <> invalid
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        end if
''', '''    else if phase = 9
        ' Leave target PIN empty for real ECP Back cancellation.
''')
                    if reject_active:
                        source = source.rsplit('    else if phase = 4\n', 1)[0] + '''    else if phase = 4
        requireConnectionRelogin("Synthetic own-profile rejection.")
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        print "[profile-management] "; FormatJson({kind: "result", b: m.switchProbeB, active_retained: store.active = "00000000-0000-4000-8000-000000000002", default_preserved: m.registry.read("connKey_slot-a") = "synthetic-a", own_revoked: not m.registry.exists(userProfileKeyName("slot-a", store.active)), covered: m.profileGateCover.visible and m.global.profilegateclosed, no_default_session: m.apiKey = "" and m.activeUserScope = invalid})
    end if
end sub
'''
                    if remember_off:
                        source = source.replace('''        m.registry.write("settingsV1", FormatJson(m.preferenceStore))
        m.registry.flush()''', '''        m.registry.write("settingsV1", FormatJson(m.preferenceStore))
        m.connectionStore = connectionStoreUpdate(m.connectionStore, "slot-a", {remember: false})
        m.remember = false
        m.registry.write("connectionsV1", FormatJson(m.connectionStore))
        m.registry.delete("connKey_slot-a")
        m.registry.delete(userProfileKeyName("slot-a", adult.id))
        m.profileSessionKeys = {}
        m.profileSessionKeys[preferenceScope(m.baseUrl + "|slot-a|" + adult.id)] = "synthetic-b"
        m.registry.flush()''')
                        for key in ['rejected-synthetic-key', 'delayed-b']:
                            source = source.replace(f'        m.registry.write(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002"), "{key}")\n', '')
                        source = source.replace('preserved: m.registry.read("connKey_slot-a") = "synthetic-a"', 'preserved: not m.registry.exists("connKey_slot-a")')
                        source = source.replace('        m.switchProbeEvidence.stale_a =', '        m.switchProbeEvidence.no_stored = not m.registry.exists("connKey_slot-a") and not m.registry.exists(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002"))\n        m.switchProbeEvidence.stale_a =')
                if child_settings:
                    source = source.split('sub onManagementProbeTick()', 1)[0] + '''function childSettingsProbeEvent(action as string) as object
    return {node: m.settingsHub, value: userViewEvent({account: m.accountIdentity, action: action}, currentUserSessionId()), getRoSGNode: function() as object
        return m.node
    end function, getData: function() as object
        return m.value
    end function}
end function

sub onManagementProbeTick()
    m.managementProbePhase++
    phase = m.managementProbePhase
    if phase = 1
        store = loadUserProfileStore(m.registry, "slot-a")
        store.profiles[0] = setCanonicalPreference(store.profiles[0], "role", "child")
        adult = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {id: 8, username: "Synthetic8", user_level: 1}, 1)
        adult.isDefault = false
        adult.order = 1
        adult.pinType = "numbers"
        adult.pinSalt = string(32, "b")
        adult.pinHash = userProfilePinHash(adult.pinSalt, "1234")
        store.profiles.push(adult)
        m.registry.write(userProfileStoreKey("slot-a"), FormatJson(store))
        m.registry.flush()
        m.userProfileStore = loadUserProfileStore(m.registry, "slot-a")
        openSettingsHub()
    else if phase = 2
        observed = m.settingsHub.callFunc("childSettingsProbe", "connection")
        m.childSettingsRoot = observed.page = "" and observed.pages.count() = 5 and observed.pages[0] = "live" and observed.pages[1] = "player" and observed.pages[2] = "appearance" and observed.pages[3] = "about" and observed.pages[4] = "manage-profiles" and observed.role = "child"
        print "[profile-management] "; FormatJson({kind: "child-settings", restricted: m.childSettingsRoot})
    else if phase = 3
        onSettingsHubSelection(childSettingsProbeEvent("connection"))
        m.childSettingsForged = m.page = "settings" and m.profileManagementDialog = invalid
        print "[profile-management] "; FormatJson({kind: "manage-ready"})
    else if phase = 4
        if m.adultPinDialog = invalid then m.managementProbePhase-- : return
        m.childSettingsProtected = m.adultPinDialog <> invalid and m.profileManagementDialog = invalid and m.profileGateCover.visible
        print "[profile-management] "; FormatJson({kind: "adult", protected: m.childSettingsProtected, title: m.adultPinDialog.title})
    else if phase = 5
        m.adultPinDialog.textEditBox.text = "1234"
        onAdultProfilePinSubmit(managementProbeEvent(m.adultPinDialog, 0))
        m.childSettingsManaged = m.profileManagementDialog <> invalid and m.profileManagementChoices.count() = 3
    else if phase = 6
        print "[profile-management] "; FormatJson({kind: "cancel-ready"})
    else if phase = 8
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        print "[profile-management] "; FormatJson({kind: "result", restricted: m.childSettingsRoot, forged: m.childSettingsForged, protected: m.childSettingsProtected, management: m.childSettingsManaged, cancelled: m.profileManagementDialog = invalid and m.profileManagementGrant = invalid, preserved: store.profiles[0].role = "child" and m.registry.read("connKey_slot-a") = "synthetic-a"})
    end if
end sub
'''
                body = source.encode()
            package.writestr(name, body)
        package.writestr('profile-management-probe.json', json.dumps({'synthetic': True}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--directions', action='store_true', help='Exercise numeric-to-Directions adult-type selection under developer opt-in')
    parser.add_argument('--switch', action='store_true', help='Exercise internal same-slot A/B/A and rejected-key rollback without enabling the public picker')
    parser.add_argument('--switch-pin', action='store_true', help='With --switch, require the real stored numeric target PIN before each switch')
    parser.add_argument('--cancel-pin', action='store_true', help='With --switch-pin, cancel the final target PIN before any request is sent')
    parser.add_argument('--reject-active', action='store_true', help='With --switch, qualify profile-owned active-key revocation without default setup fallback')
    parser.add_argument('--remember-off', action='store_true', help='With --switch, use address/slot/profile-qualified session credentials only')
    parser.add_argument('--child-settings', action='store_true', help='Exercise restricted Settings and its adult-gated management shortcut in a private Child-role fixture')
    args = parser.parse_args()
    if args.switch and args.directions:
        parser.error('--switch and --directions are separate cases')
    if args.switch_pin and not args.switch:
        parser.error('--switch-pin requires --switch')
    if args.cancel_pin and not args.switch_pin:
        parser.error('--cancel-pin requires --switch-pin')
    if args.reject_active and (not args.switch or args.switch_pin):
        parser.error('--reject-active requires --switch without --switch-pin')
    if args.remember_off and (not args.switch or args.reject_active):
        parser.error('--remember-off requires --switch without --reject-active')
    if args.child_settings and (args.switch or args.directions):
        parser.error('--child-settings is a separate case')
    host, password = os.environ['ROKU_HOST'], os.environ['ROKU_DEV_PASSWORD']
    modules = {}
    for key in ['primitives', 'recovery']:
        spec = importlib.util.spec_from_file_location(key, ROOT / 'scripts' / f'test-profile-{key}-native.py')
        modules[key] = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modules[key])
    restore = Path(args.restore)
    checksum = hashlib.md5(restore.read_bytes()).hexdigest()
    if modules['primitives'].installed_md5(host, password) != checksum:
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
            user = 8 if key in ['synthetic-b', 'delayed-b'] else 7
            hits.append({'user': user, 'path': self.path, 'rejected': key == 'rejected-synthetic-key', 'delayed': key == 'delayed-b'})
            if key == 'delayed-b' and self.path == '/api/accounts/users/me/':
                time.sleep(4)
            value = []
            if self.path == '/api/accounts/users/me/':
                value = {'id': user, 'username': 'Synthetic' + str(user), 'user_level': 1}
            if self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
            if self.path.split('?', 1)[0] in ['/api/channels/channels/', '/api/channels/channels/summary/']:
                value = [{'id': user, 'uuid': f'00000000-0000-4000-8000-{user:012d}', 'name': 'Synthetic ' + str(user), 'channel_number': user}]
            body = json.dumps(value).encode()
            self.send_response(401 if key == 'rejected-synthetic-key' else 200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # The cancellation fixture deliberately closes this reader.

    server = ThreadingHTTPServer((local, 0), Fixture)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    section = 'AerioManagementProbe-' + str(uuid.uuid4())
    archive = ROOT / 'out/profile-management-probe.zip'
    cleaner = ROOT / 'out/profile-management-cleanup.zip'
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}', args.directions, args.switch, args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.child_settings)
    modules['recovery'].cleanup_package(cleaner, section)
    report = {'passed': False}

    def run(path, marker, prefix='[profile-management]'):
        command = ['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '45']
        if path != archive:
            return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=100)
        output = []
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
            for line in process.stdout:
                output.append(line)
                if '"kind":"manage-ready"' in line:
                    captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', str(ROOT / 'out/profile-child-settings.jpg')], cwd=ROOT, capture_output=True, text=True, timeout=45)
                    report['screenshot'] = captured.returncode == 0
                    for key in ['Down', 'Down', 'Down', 'Down', 'Right', 'Select']:
                        request = urllib.request.Request(f'http://{host}:8060/keypress/{key}', data=b'', method='POST')
                        urllib.request.urlopen(request, timeout=10).close()
                        time.sleep(0.1)
                if '"kind":"cancel-ready"' in line:
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                    urllib.request.urlopen(request, timeout=10).close()
            stderr = process.stderr.read()
            return subprocess.CompletedProcess(command, process.wait(timeout=100), ''.join(output), stderr)

    try:
        result = run(archive, '"kind":"result"')
        print(result.stdout, end='', flush=True)
        rows = [json.loads(line.split('[profile-management] ', 1)[1]) for line in result.stdout.splitlines() if '[profile-management] {' in line]
        report['events'] = rows
        report['passed'] = result.returncode == 0 and len(rows) == 5 and rows[0].get('dialog') and rows[1].get('native') and rows[2].get('native') and rows[2].get('covered') and all(rows[4].get(key) for key in ['renamed', 'wrong', 'grant', 'learned', 'management', 'uncovered', 'preserved', 'no_unlock', 'cancelled'])
        if args.switch:
            rejected = [hit for hit in hits if hit['rejected']]
            delayed = [hit for hit in hits if hit['delayed']]
            report['requests'] = hits
            cancelled_requests = not delayed if args.cancel_pin else len(delayed) == 1 and delayed[0]['path'] == '/api/accounts/users/me/'
            report['passed'] = result.returncode == 0 and len(rows) == 5 and rows[0].get('started') and all(rows[4].get(key) for key in ['a', 'b', 'rollback', 'preserved', 'uncovered', 'no_autoplay', 'cancelled', 'stale_a']) and len(rejected) == 1 and rejected[0]['path'] == '/api/accounts/users/me/' and cancelled_requests
            if args.reject_active:
                report['passed'] = result.returncode == 0 and len(rows) == 3 and all(rows[2].get(key) for key in ['b', 'active_retained', 'default_preserved', 'own_revoked', 'covered', 'no_default_session'])
            if args.remember_off:
                report['passed'] = report['passed'] and rows[-1].get('no_stored', False)
        if args.child_settings:
            report['passed'] = result.returncode == 0 and len(rows) == 5 and all(rows[4].get(key) for key in ['restricted', 'forged', 'protected', 'management', 'cancelled', 'preserved']) and rows[2].get('title') == 'Enter a PIN from an Admin or Standard profile' and report.get('screenshot', False)
        if not report['passed']:
            raise RuntimeError('Native management controller assertions failed')
    finally:
        try:
            cleaned = run(cleaner, '[profile-recovery] cleanup=', '[profile-recovery]')
            report['cleaned'] = cleaned.returncode == 0 and '[profile-recovery] cleanup=true' in cleaned.stdout
        finally:
            restored = run(restore, 'Running dev')
            report['restored'] = restored.returncode == 0 and modules['primitives'].installed_md5(host, password) == checksum
            server.shutdown()
            server.server_close()
            report['passed'] = report['passed'] and report.get('cleaned', False) and report['restored']
            name = 'profile-management-directions-native.json' if args.directions else 'profile-management-native.json'
            if args.switch:
                name = 'profile-switch-pin-native.json' if args.switch_pin else 'profile-switch-native.json'
                if args.cancel_pin:
                    name = 'profile-switch-pin-cancel-native.json'
                if args.reject_active:
                    name = 'profile-switch-active-reject-native.json'
                if args.remember_off:
                    name = 'profile-switch-memory-native.json'
            if args.child_settings:
                name = 'profile-child-settings-native.json'
            (ROOT / 'out' / name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
