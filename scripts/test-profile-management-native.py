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
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def baseline_retirement_consent_valid(events):
    return len(events) == 1 and all(events[0].get(field) is True for field in ['enabled', 'writerready', 'retirementready'])


def management_probe_activity(host):
    # Read-only evidence; do not emit another app's or screensaver's identity.
    with urllib.request.urlopen(f'http://{host}:8060/query/active-app', timeout=5) as response:
        root = ET.fromstring(response.read(65536))
    app = root.find('app')
    return {'dev_active': app is not None and app.get('id') == 'dev',
            'screensaver_active': root.find('screensaver') is not None}


def launch_profile_probe_after_exit(host):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        activity = management_probe_activity(host)
        if activity['screensaver_active']:
            raise RuntimeError('Cold probe cannot wake an active screensaver')
        if not activity['dev_active']:
            request = urllib.request.Request(f'http://{host}:8060/launch/dev', data=b'', method='POST')
            with urllib.request.urlopen(request, timeout=5):
                return True
        time.sleep(0.1)
    raise RuntimeError('Cold probe did not observe the preceding dev process exit')


def management_probe_user(key):
    if key in ['synthetic-b', 'delayed-b']:
        return 8
    if key in ['synthetic-c', 'synthetic-third']:
        return 9
    return 7


def authority_race_user(state, user):
    result = dict(user)
    if user['id'] == 8:
        state['authority_target_me'] = state.get('authority_target_me', 0) + 1
        if state['authority_target_me'] >= 3:
            result['user_level'] = 10
    return result


def switch_import_pin_envelope():
    # Synthetic fixed fixture salt, never a production salt source.
    salt = '0123456789abcdef0123456789abcdef'
    digest = hashlib.sha256(bytes.fromhex(salt) + b'5678').hexdigest()
    stamp = '2026-11-14T12:00:00Z'
    return {'schemaVersion': 3, 'deviceId': 'synthetic-phone', 'platform': 'android',
            'appVersion': '1', 'updatedAt': stamp,
            'categories': {'profiles': {'updatedAt': stamp, 'data': {
                'rows': [[8, 'Synthetic8', 'Imported target', 'numbers', digest, salt, 'user', 1794657600]]}}}}


def switch_inactive_cleanup_envelope(username='synthetic9'):
    stamp = int(time.time())
    updated = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime(stamp))
    return {'schemaVersion': 3, 'deviceId': 'synthetic-phone', 'platform': 'android',
            'appVersion': '1', 'updatedAt': updated,
            'categories': {'profiles': {'updatedAt': updated, 'data': {
                'rows': [], 'removed': [[username, stamp]]}}}}


def startup_probe_timer(source):
    timer = '''    m.managementProbeClock = m.top.createChild("Timer")
    m.managementProbeClock.duration = 1
    m.managementProbeClock.repeat = true
    m.managementProbeClock.observeField("fire", "onManagementProbeTick")
    m.managementProbePhase = 0
    m.managementProbeClock.control = "start"
'''
    target = '    welcome = connectionWelcomeNeeded(m.connectionStore)'
    if target in source:
        return source.replace(target, timer + target, 1)
    assert source.count('sub init()') == 1
    return source.replace('sub init()', 'sub init()\n' + timer, 1)


def build(output, normal, section, base, directions=False, switching=False, switch_pin=False, cancel_pin=False, reject_active=False, remember_off=False, child_settings=False, reconnect=False, cold_restore=None, default_filter=False, assignment_refresh=False, child_escape=False, child_launch=False, child_available=None, child_retry=None, child_rejected=None, manual_refresh=False, manual_recording=False, manual_mode='changed', favorite_retention=False, switch_recording=None, switch_roster=False, switch_import_pin=False, switch_cleanup=False, switch_target_retirement=False, switch_authority_race=False, switch_active_retirement=False, active_default_mode='usable', switch_writer=False, writer_mode='direct', baseline_readiness=False):
    if baseline_readiness and not (switch_active_retirement or (switch_writer and writer_mode == 'flush-own-retirement')):
        raise ValueError('Baseline readiness is limited to existing retirement fixtures')
    if writer_mode not in ['direct', 'controls', 'controls-restore', 'unchanged', 'schedule', 'schedule-too-large', 'schedule-signin', 'create', 'create-legacy', 'create-proxy404', 'flush', 'flush-failed', 'flush-cancel', 'flush-authority', 'flush-import-pin', 'flush-own-retirement'] or (writer_mode != 'direct' and not switch_writer):
        raise ValueError('Writer mode requires the private writer fixture')
    if switch_writer and (not switching or not switch_roster or any([directions, switch_pin, cancel_pin, reject_active, remember_off, child_settings, reconnect, cold_restore, default_filter, assignment_refresh, child_escape, child_launch, child_available, child_retry, child_rejected, manual_refresh, manual_recording, favorite_retention, switch_recording, switch_import_pin, switch_cleanup, switch_target_retirement, switch_authority_race, switch_active_retirement]) or active_default_mode != 'usable'):
        raise ValueError('Writer fixture requires only --switch --switch-roster')
    if active_default_mode not in ['usable', 'missing', 'held', 'child', 'cold', 'simultaneous', 'import-pin', 'import-child'] or (active_default_mode != 'usable' and not switch_active_retirement):
        raise ValueError('Active default mode requires the active retirement fixture')
    if switch_roster and (not (switching or child_escape) or (switching and child_escape)):
        raise ValueError('Private early-roster mode requires either switch or Child escape fixture')
    if switch_import_pin and (not switching or not switch_roster or any([switch_pin, cancel_pin, reject_active, remember_off, reconnect, child_settings, cold_restore, default_filter, assignment_refresh, child_escape, child_launch, child_available, child_retry, child_rejected, manual_refresh, manual_recording, favorite_retention, switch_recording, directions])):
        raise ValueError('Imported PIN fixture requires only --switch --switch-roster')
    if switch_cleanup and (not switching or not switch_roster or any([switch_pin, cancel_pin, reject_active, remember_off, reconnect, child_settings, cold_restore, default_filter, assignment_refresh, child_escape, child_launch, child_available, child_retry, child_rejected, manual_refresh, manual_recording, favorite_retention, switch_recording, directions, switch_import_pin])):
        raise ValueError('Inactive cleanup fixture requires only --switch --switch-roster')
    if switch_target_retirement and (not switching or not switch_roster or any([switch_pin, cancel_pin, reject_active, remember_off, reconnect, child_settings, cold_restore, default_filter, assignment_refresh, child_escape, child_launch, child_available, child_retry, child_rejected, manual_refresh, manual_recording, favorite_retention, switch_recording, directions, switch_import_pin, switch_cleanup])):
        raise ValueError('Target retirement fixture requires only --switch --switch-roster')
    if switch_authority_race and (not switching or not switch_roster or any([switch_pin, cancel_pin, reject_active, remember_off, reconnect, child_settings, cold_restore, default_filter, assignment_refresh, child_escape, child_launch, child_available, child_retry, child_rejected, manual_refresh, manual_recording, favorite_retention, switch_recording, directions, switch_import_pin, switch_cleanup, switch_target_retirement])):
        raise ValueError('Authority race fixture requires only --switch --switch-roster')
    if switch_active_retirement and (not switching or not switch_roster or any([switch_pin, cancel_pin, reject_active, remember_off, reconnect, child_settings, cold_restore, default_filter, assignment_refresh, child_escape, child_launch, child_available, child_retry, child_rejected, manual_refresh, manual_recording, favorite_retention, switch_recording, directions, switch_import_pin, switch_cleanup, switch_target_retirement, switch_authority_race])):
        raise ValueError('Active retirement fixture requires only --switch --switch-roster')
    recording_probe = bool(manual_recording or switch_recording)
    if manual_refresh:
        assignment_refresh = True
    if child_rejected:
        child_available = child_rejected
    if child_retry:
        child_available = child_retry
    if assignment_refresh or child_escape or child_launch or child_available or favorite_retention or switch_recording:
        cold_restore = 'remembered'
    if child_available:
        default_filter = True
    with zipfile.ZipFile(normal) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            body = original.read(name)
            if switch_writer and name == 'components/DispatcharrSyncWriteTask.brs':
                source = body.decode()
                assert source.count('m.syncWriterReady = false') == 1
                assert source.count('CreateObject("roRegistrySection", "AerioTV")') == 1
                if not baseline_readiness:
                    source = source.replace('m.syncWriterReady = false', 'm.syncWriterReady = true', 1)
                body = source.replace('CreateObject("roRegistrySection", "AerioTV")', f'CreateObject("roRegistrySection", "{section}")', 1).encode()
            if active_default_mode == 'cold' and name == 'components/ProfileDefaultRetirementNavigation.brs':
                target = '    preserveSubmittedRecording()'
                source = body.decode()
                assert source.count(target) == 1
                body = source.replace(target, '''    print "[profile-management] "; FormatJson({kind: "retirement-crash-ready", journal: m.registry.exists(userProfileRetirementKey(context.connection.id)), fenced: loadUserProfileStore(m.registry, context.connection.id).readOnly, retained: m.registry.exists(userProfileKeyName(context.connection.id, selected.outgoingId))})
    m.managementProbeClock.control = "stop"
    m.top.exitRequested = true
    return
''' + target, 1).encode()
            if recording_probe and name == 'components/DvrSettlementNavigation.brs':
                target = b'    showNotice(message)\n'
                assert body.count(target) == 1
                body = body.replace(target, b'    m.probeRecordConfirmed = message = "Server recording scheduled. Open DVR to confirm its status."\n    m.manualRecordingSettled = m.probeRecordConfirmed\n    print "[profile-management] "; FormatJson({kind: "record-settled", confirmed: m.probeRecordConfirmed, operation_only: true, retired: currentUserSessionId() <> m.probeRecordOldSession})\n' + target, 1)
            if recording_probe and name == 'components/DvrNavigation.brs':
                target = b'    result = event.getData()\n'
                assert body.count(target) == 1
                body = body.replace(target, target + b'    m.probeRecordConfirmed = result.ok = true\n    m.manualRecordingSettled = m.probeRecordConfirmed\n    print "[profile-management] "; FormatJson({kind: "record-settled", confirmed: m.probeRecordConfirmed, operation_only: false, retired: currentUserSessionId() <> m.probeRecordOldSession})\n', 1)
            if name == 'manifest':
                body = body.replace(b'title=AerioTV\n', b'title=Aerio Profile Management Probe\n')
                if baseline_readiness:
                    body += b'\naeriotv_profiles_baseline=1\n'
                if directions:
                    body += b'\naeriotv_profile_directions_test=1\n'
            if (child_launch or child_rejected) and name == 'source/Main.brs':
                target = b'                    screen.close()'
                assert body.count(target) == 1
                body = body.replace(target, b'                    print "[profile-management] "; FormatJson({kind: "result", exited: true})\n' + target, 1)
            if name == 'source/MetadataCacheStore.brs':
                assert body.count(b'"cachefs:/aeriotv-metadata-v1"') == 1
                body = body.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/profile-management-cache"')
            if favorite_retention and name == 'components/GuideView.xml':
                body = body.replace(b'</interface>', b'<function name="profileFavoriteProbe" /></interface>', 1)
            if favorite_retention and name == 'components/GuideView.brs':
                body += b'''\nfunction profileFavoriteProbe(action as string) as object
    if action = "edit"
        m.settings.groupSort = "alpha"
        rebuildGuideGroups()
    else if action = "untoggle"
        m.favorites.delete("00000000-0000-4000-8000-000000000008")
        savePreferences()
    end if
    ids = m.savedFavoriteIds
    if type(ids) <> "roArray" then ids = m.top.config.preferences.favoriteIds
    return {ids: ids, selected8: m.favorites.doesExist("00000000-0000-4000-8000-000000000008"), selected99: m.favorites.doesExist("00000000-0000-4000-8000-000000000099")}
end function
'''
            if (switching or assignment_refresh or child_available) and name == 'components/GuideView.xml':
                body = body.replace(b'</interface>', b'<function name="profileSwitchProbeLineup" /></interface>', 1)
            if (switching or assignment_refresh or child_available) and name == 'components/GuideView.brs':
                if switch_roster:
                    source = body.decode()
                    target = 'function onKeyEvent(key as string, press as boolean) as boolean\n'
                    assert source.count(target) == 1
                    source = source.replace(target, target + '''    if m.global.profileswitchpending = true and press
        print "[profile-management] "; FormatJson({kind: "switch-guide-key", key: key, active: m.top.active, has_picker: m.picker <> invalid, mini_active: m.top.miniActive, pending_tune: m.top.pendingTune})
    end if
''', 1)
                    body = source.encode()
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
            if child_settings and name == 'components/GuideView.xml':
                body = body.replace(b'</interface>', b'<function name="childGuideActionsProbe" /></interface>', 1)
            if child_settings and name == 'components/GuideView.brs':
                body += b'''\nfunction childGuideActionsProbe() as boolean
    safe = m.userRole = "child"
    for each advanced in [false, true]
        openOptions(advanced)
        for each item in m.pickerItems
            if not guideProfileActionAllowed("child", item.action) then safe = false
        end for
        closePicker()
    end for
    before = FormatJson(m.settings)
    openGuideSetting("manageGroups")
    handleGuideSetting("manageGroups", {groupId: "forged"})
    return safe and m.picker = invalid and FormatJson(m.settings) = before
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
                source = source.replace(target, '''    if m.managementProbeClock = invalid
    m.managementProbeClock = m.top.createChild("Timer")
    m.managementProbeClock.duration = 1
    m.managementProbeClock.repeat = true
    m.managementProbeClock.observeField("fire", "onManagementProbeTick")
    m.managementProbePhase = 0
    m.managementProbeClock.control = "start"
    end if
''' + target, 1)
                source += '''
function managementProbeEvent(node as object, index as integer) as object
    return {node: node, index: index, getRoSGNode: function() as object
        return m.node
    end function, getData: function() as integer
        return m.index
    end function}
end function

function managementProbeChoose(action as string, id = "" as string) as boolean
    for i = 0 to m.profileManagementChoices.count() - 1
        choice = m.profileManagementChoices[i]
        if choice.action = action and (id = "" or choice.id = id)
            onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, i))
            return true
        end if
    end for
    return false
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
        store = loadUserProfileStore(m.registry, m.selectedConnectionId)
        managementProbeChoose("edit", store.active)
    else if phase = 3
        managementProbeChoose("name")
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
        showConnection()
        m.rokuRfiOffered = true
        for index = 0 to m.setupRows.count() - 1
            if m.setupRows[index].field = "key" then m.setupIndex = index
        end for
        editSetupField()
        m.switchProbeStaleKeyboard = m.top.dialog
        m.switchProbeStaleKeyboard.text = "synthetic-stale-default-key"
        m.switchProbeStaleKeyboard.unobserveField("buttonSelected")
        m.switchProbeStaleKeyboard.unobserveField("wasClosed")
        m.switchProbeStaleKeyboard.close = true
        m.top.dialog = invalid
        m.page = "guide"
        m.screen.visible = false
        m.guide.visible = true
        m.guide.active = true
    else if phase = 2
        started = beginUserProfileSwitch("00000000-0000-4000-8000-000000000002")
        print "[profile-management] "; FormatJson({kind: "switch-start", started: started})
    else if phase = 3
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return
        m.switchProbeB = m.activeUserScope.profileId = "00000000-0000-4000-8000-000000000002" and m.accountPreferences.favoriteIds[0] = "8" and m.devicePreferences.themePreset = "forest" and m.apiKey = "synthetic-b" and m.guide.callFunc("profileSwitchProbeLineup") = "8"
        bindingOwner = currentRequestGateOwner(connectionStoreEntry(m.connectionStore, "slot-a"))
        m.switchProbeB = m.switchProbeB and bindingOwner.account = "8" and bindingOwner.profile = m.activeUserScope.profileId
        beforeConnection = m.registry.read("connectionsV1")
        beforeKey = m.apiKey
        showConnection()
        m.switchProbeSetupHidden = m.page = "setup"
        for each row in m.setupRows
            if row.field = "method" or row.field = "username" or row.field = "password" or row.field = "key" or row.field = "profile" then m.switchProbeSetupHidden = false
        end for
        m.setupRows = [{field: "method", title: "Forged"}]
        m.setupIndex = 0
        beforeMode = m.authMode
        editSetupField()
        m.editingField = "key"
        onKeyboardButton(managementProbeEvent({text: "synthetic-forged-key"}, 0))
        openPermittedProfiles()
        selectPermittedProfile({id: "99"})
        m.switchProbeSetupHidden = m.switchProbeSetupHidden and m.authMode = beforeMode and m.apiKey = beforeKey and m.profileTask = invalid and m.registry.read("connectionsV1") = beforeConnection
        m.switchProbeB = m.switchProbeB and m.switchProbeSetupHidden
        m.page = "guide"
        m.screen.visible = false
        m.guide.visible = true
        m.guide.active = true
        print "[profile-management] "; FormatJson({kind: "switch-b", own: m.switchProbeB, setup_hidden: m.switchProbeSetupHidden})
    else if phase = 4
        if OWN_RECONNECT_PROBE
            if m.switchProbeReconnectStarted <> true
                m.switchProbeReconnectStarted = true
                m.switchProbeBeforeReconnect = currentUserSessionId()
                m.switchProbeDefaultBeforeReconnect = FormatJson(m.userProfileStore.profiles[0])
                connectServer(true)
                m.managementProbePhase--
                return
            end if
            if m.profilePinDialog <> invalid
                m.switchProbeReconnectPin = m.profileGateCover.visible and m.global.profilegateclosed
                m.profilePinDialog.textEditBox.text = "1234"
                onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
                m.managementProbePhase--
                return
            end if
            if m.busy then m.managementProbePhase-- : return
            m.switchProbeReconnected = m.page = "guide" and m.activeUserScope <> invalid
            if m.switchProbeReconnected then m.switchProbeReconnected = m.activeUserScope.accountId = "8" and m.accountPreferences.favoriteIds[0] = "8" and m.devicePreferences.themePreset = "forest" and m.apiKey = "synthetic-b" and currentUserSessionId() <> m.switchProbeBeforeReconnect and FormatJson(m.userProfileStore.profiles[0]) = m.switchProbeDefaultBeforeReconnect
            m.switchProbeB = m.switchProbeB and m.switchProbeReconnected
        end if
        m.switchProbeBackStarted = beginUserProfileSwitch(m.switchProbeDefault)
    else if phase = 5
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return
        m.switchProbeA = m.activeUserScope.profileId = m.switchProbeDefault and m.accountPreferences.favoriteIds[0] = "7" and m.devicePreferences.themePreset = "midnight" and currentUserSessionId() <> m.switchProbeFirstSession and m.apiKey = "synthetic-a" and m.guide.callFunc("profileSwitchProbeLineup") = "7"
        m.switchProbeSecondSession = currentUserSessionId()
        beforeKeyboardKey = m.apiKey
        beforeKeyboardStored = m.registry.read("connKey_slot-a")
        onKeyboardButton(managementProbeEvent(m.switchProbeStaleKeyboard, 0))
        m.switchProbeStaleKeyboardRejected = m.apiKey = beforeKeyboardKey and m.registry.read("connKey_slot-a") = beforeKeyboardStored
        print "[profile-management] "; FormatJson({kind: "switch-a", own: m.switchProbeA, started: m.switchProbeBackStarted})
    else if phase = 6
        m.registry.write(userProfileKeyName("slot-a", "00000000-0000-4000-8000-000000000002"), "rejected-synthetic-key")
        m.profileSessionKeys[preferenceScope(m.baseUrl + "|slot-a|00000000-0000-4000-8000-000000000002")] = "rejected-synthetic-key"
        m.registry.flush()
        m.switchProbeRejectStarted = beginUserProfileSwitch("00000000-0000-4000-8000-000000000002")
    else if phase = 7
        if m.profileSwitchContext <> invalid then m.managementProbePhase-- : return
        store = loadUserProfileStore(m.registry, "slot-a")
        m.switchProbeEvidence = {kind: "result", reconnected: m.switchProbeReconnected = true, b: m.switchProbeB, a: m.switchProbeA, rollback: m.switchProbeRejectStarted and store.active = m.switchProbeDefault and m.activeUserScope.profileId = m.switchProbeDefault and currentUserSessionId() <> m.switchProbeSecondSession and m.apiKey = "synthetic-a", preserved: m.registry.read("connKey_slot-a") = "synthetic-a", uncovered: not m.profileGateCover.visible, no_autoplay: m.playingChannel = invalid}
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
    else if phase = 11
        store = loadUserProfileStore(m.registry, "slot-a")
        observed = m.profileSwitchContext = invalid and store.active = m.switchProbeDefault and m.activeUserScope.profileId = m.switchProbeDefault
        print "[profile-management] "; FormatJson({kind: "switch-cancel-observed", observed: observed})
    else if phase = 15
        m.managementProbeClock.control = "stop"
        store = loadUserProfileStore(m.registry, "slot-a")
        m.switchProbeEvidence.cancelled = m.switchProbeCancelStarted and m.profileSwitchContext = invalid and store.active = m.switchProbeDefault and m.activeUserScope.profileId = m.switchProbeDefault and currentUserSessionId() <> m.switchProbeBeforeCancel and not m.profileGateCover.visible
        m.switchProbeEvidence.cancel_started = m.switchProbeCancelStarted
        m.switchProbeEvidence.cancel_context_cleared = m.profileSwitchContext = invalid
        m.switchProbeEvidence.cancel_store_default = store.active = m.switchProbeDefault
        m.switchProbeEvidence.cancel_scope_default = m.activeUserScope.profileId = m.switchProbeDefault
        m.switchProbeEvidence.cancel_fresh = currentUserSessionId() <> m.switchProbeBeforeCancel
        m.switchProbeEvidence.cancel_uncovered = not m.profileGateCover.visible
        m.switchProbeEvidence.cancel_busy = m.busy
        m.switchProbeEvidence.stale_a = not userEventCurrent(userViewEvent({action: "connection"}, m.switchProbeFirstSession))
        m.switchProbeEvidence.stale_keyboard = m.switchProbeStaleKeyboardRejected
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
                    if switch_cleanup:
                        target = '        store.profiles.push(adult)\n'
                        assert source.count(target) == 1
                        source = source.replace(target, target + '''        third = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000003", {id: 9, username: "Synthetic9", user_level: 1}, 1)
        third = setCanonicalPreference(third, "isDefault", false)
        third = setCanonicalPreference(third, "order", 2)
        store.profiles.push(third)
        m.registry.write(userProfileKeyName("slot-a", third.id), "synthetic-third")
        m.registry.write(userProfilePinBackoffKey("slot-a", third.id), FormatJson({failures: 1, round: 0, until: 0}))
        if type(m.profileSessionKeys) <> "roAssociativeArray" then m.profileSessionKeys = {}
        m.profileSessionKeys[preferenceScope(m.baseUrl + "|slot-a|" + third.id)] = "synthetic-third"
''', 1)
                        target = '        m.registry.write("settingsV1", FormatJson(m.preferenceStore))\n'
                        assert source.count(target) == 1
                        source = source.replace(target, '''        m.preferenceStore.accounts[preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "9"))] = normalizeAccountPreferences({favoriteIds: ["99"]})
        m.preferenceStore.accounts[preferenceScope("https://foreign.test|99|slot-b")] = {future: "retain"}
''' + target, 1)
                        target = '        m.registry.flush()\n        showConnection()\n'
                        assert source.count(target) == 1
                        source = source.replace(target, '''        m.registry.flush()
        seeded = loadUserProfileStore(m.registry, "slot-a")
        seededSettings = ParseJson(m.registry.read("settingsV1"), "d")
        thirdAccount = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "9"))
        m.switchProbeThirdSeeded = seeded.profiles.count() = 3 and m.registry.exists(userProfileKeyName("slot-a", third.id)) and m.registry.exists(userProfilePinBackoffKey("slot-a", third.id)) and m.profileSessionKeys.doesExist(preferenceScope(m.baseUrl + "|slot-a|" + third.id)) and seededSettings.accounts.doesExist(thirdAccount)
        showConnection()
''', 1)
                        target = '        m.switchProbeB = m.switchProbeB and m.switchProbeSetupHidden\n'
                        assert source.count(target) == 1
                        source = source.replace(target, target + '''        cleaned = loadUserProfileStore(m.registry, "slot-a")
        preferences = ParseJson(m.registry.read("settingsV1"), "d")
        thirdId = "00000000-0000-4000-8000-000000000003"
        removedAccount = preferenceScope(connectionPreferenceIdentity(connectionStoreEntry(m.connectionStore, "slot-a"), "9"))
        foreignAccount = preferenceScope("https://foreign.test|99|slot-b")
        m.switchProbeInactiveCleaned = m.switchProbeThirdSeeded and cleaned.profiles.count() = 2 and cleaned.removed.count() = 0 and not m.registry.exists(userProfileKeyName("slot-a", thirdId)) and not m.registry.exists(userProfilePinBackoffKey("slot-a", thirdId)) and not m.profileSessionKeys.doesExist(preferenceScope(m.baseUrl + "|slot-a|" + thirdId)) and not preferences.accounts.doesExist(removedAccount) and preferences.accounts[foreignAccount].future = "retain"
        m.switchProbeB = m.switchProbeB and m.switchProbeInactiveCleaned
''', 1)
                        source = source.replace('kind: "result", reconnected:', 'kind: "result", inactive_cleaned: m.switchProbeInactiveCleaned = true, reconnected:', 1)
                    if switch_target_retirement:
                        target = '    else if phase = 4\n        if OWN_RECONNECT_PROBE\n'
                        assert source.count(target) == 1
                        source = source.replace(target, '''    else if phase = 4
        if not advanceProfileTargetRetirementProbe() then m.managementProbePhase-- : return
        if OWN_RECONNECT_PROBE
''', 1)
                        source += '\n' + (ROOT / 'tests/native/ProfileTargetRetirementFixture.brs').read_text()
                        source = source.replace('kind: "result", reconnected:', 'kind: "result", target_retired: m.switchProbeTargetRetired = true, reconnected:', 1)
                    if cancel_pin:
                        source = source.replace('''    else if phase = 9
        if m.profilePinDialog <> invalid
            m.profilePinDialog.textEditBox.text = "1234"
            onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        end if
''', '''    else if phase = 9
        ' Leave target PIN empty for real ECP Back cancellation.
''')
                    if switch_import_pin:
                        source = source.replace('sub onManagementProbeTick()\n', '''sub onManagementProbeTick()
    if m.profilePinDialog <> invalid
        if m.profilePinContext.continuation = "switch-roster"
            saved = loadUserProfileStore(m.registry, "slot-a")
            imported = invalid
            for each profile in saved.profiles
                if profile.userId = 8 then imported = profile
            end for
            m.switchImportStored = imported <> invalid and saved.active = m.switchProbeDefault and m.profileGateCover.visible and m.global.profilegateclosed
            if imported <> invalid
                m.switchImportStored = m.switchImportStored and imported.pinType = "numbers" and imported.pinHash = userProfilePinHash(imported.pinSalt, "5678")
            end if
            if m.switchImportOldTried <> true
                m.switchImportOldTried = true
                m.profilePinDialog.textEditBox.text = "1234"
                onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
                m.switchImportOldRefused = m.profilePinDialog <> invalid and m.global.profilegateclosed and m.profileSwitchContext.phase = "pin" and m.activeUserScope.profileId = m.switchProbeDefault
                return
            end if
        end if
        m.profilePinDialog.textEditBox.text = "5678"
        onProfilePinSubmit(managementProbeEvent(m.profilePinDialog, 0))
        return
    end if
''', 1)
                        source = source.replace('kind: "result", reconnected:', 'kind: "result", imported_stored: m.switchImportStored = true, imported_old_refused: m.switchImportOldRefused = true, reconnected:', 1)
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
        m.guide.config = setCanonicalPreference(m.guide.config, "userRole", "child")
        openSettingsHub()
    else if phase = 2
        m.childGuideRestricted = m.guide.callFunc("childGuideActionsProbe")
        m.settingsHub.setFocus(true)
        observed = m.settingsHub.callFunc("childSettingsProbe", "connection")
        m.childSettingsRoot = observed.page = "" and observed.pages.count() = 5 and observed.pages[0] = "live" and observed.pages[1] = "player" and observed.pages[2] = "appearance" and observed.pages[3] = "about" and observed.pages[4] = "manage-profiles" and observed.role = "child"
        print "[profile-management] "; FormatJson({kind: "child-settings", restricted: m.childSettingsRoot})
    else if phase = 3
        onSettingsHubSelection(childSettingsProbeEvent("connection"))
        beforeSetup = FormatJson(m.connectionStore)
        showConnection()
        openConnectionPicker()
        openConnectionManager()
        updateConnectionUrl("https://synthetic-forged.invalid")
        changeConnectionRemember(false)
        switchSavedConnection("forged-slot")
        addSavedConnection()
        removeSelectedConnection()
        openPhoneSetup()
        acceptPhoneSetupPayload({})
        startPhoneVerification()
        commitPhoneSetup("add")
        priorCapabilities = m.capabilities
        m.capabilities = setCanonicalPreference(m.capabilities, "switchStreams", "allowed")
        m.playingChannel = {id: "7", uuid: "00000000-0000-4000-8000-000000000007"}
        beginSourceOperation("switch", "forged-stream")
        m.playingChannel = invalid
        m.capabilities = priorCapabilities
        m.childSettingsForged = m.page = "settings" and m.profileManagementDialog = invalid
        m.childSettingsForged = m.childSettingsForged and FormatJson(m.connectionStore) = beforeSetup and m.phonePending = invalid and m.sourceTask = invalid
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
        print "[profile-management] "; FormatJson({kind: "result", guide_restricted: m.childGuideRestricted, restricted: m.childSettingsRoot, forged: m.childSettingsForged, protected: m.childSettingsProtected, management: m.childSettingsManaged, cancelled: m.profileManagementDialog = invalid and m.profileManagementGrant = invalid, preserved: store.profiles[0].role = "child" and m.registry.read("connKey_slot-a") = "synthetic-a"})
    end if
end sub
'''
                if cold_restore:
                    seed_target = '    m.registry.flush()'
                    held = 'true' if cold_restore == 'held' else 'false'
                    key_seed = 'm.registry.write("profKey_slot-a_00000000-0000-4000-8000-000000000002", "synthetic-b")' if cold_restore != 'keyless' else ''
                    source = source.replace(seed_target, f'''    defaultHolder = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000001", {{id: 7, username: "Synthetic7", user_level: 1}}, 1)
    ownHolder = userProfileFromVerified("slot-a", "00000000-0000-4000-8000-000000000002", {{id: 8, username: "Synthetic8", user_level: 1}}, 2)
    ownHolder.isDefault = false
    ownHolder.addressHeld = {held}
    m.registry.write("userProfilesV1_slot-a", FormatJson({{schema: 1, playlistId: "slot-a", active: ownHolder.id, askAtLaunch: false, profiles: [defaultHolder, ownHolder], removed: [], pendingRoster: false}}))
    {key_seed}
    coldSettings = {{schema: 1, device: {{}}, accounts: {{}}}}
    coldSettings.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))] = {{favoriteIds: ["00000000-0000-4000-8000-000000000007"], profileSettings: {{themePreset: "midnight"}}}}
    coldSettings.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))] = {{favoriteIds: ["00000000-0000-4000-8000-000000000008"], profileSettings: {{themePreset: "forest"}}}}
    m.registry.write("settingsV1", strictJsonEncode(coldSettings).text)
''' + seed_target, 1)
                    expected = '8' if cold_restore == 'remembered' else '7'
                    fixture = (ROOT / 'tests/native/ProfileColdRestoreFixture.brs').read_text()
                    fixture = fixture.replace('OWN_COLD_ACCOUNT', f'"{expected}"').replace('OWN_COLD_HELD', held)
                    source = source.split('sub onManagementProbeTick()', 1)[0] + fixture
                if assignment_refresh:
                    fixture_name = 'ProfileManualRefreshFixture.brs' if manual_refresh else 'ProfileAssignmentRefreshFixture.brs'
                    fixture = (ROOT / 'tests/native' / fixture_name).read_text().replace('MANUAL_RECORDING', 'true' if manual_recording else 'false')
                    for variant in ['identity', 'unchanged', 'transient']:
                        fixture = fixture.replace('MANUAL_' + variant.upper(), 'true' if manual_mode == variant else 'false')
                    source = source.split('sub onManagementProbeTick()', 1)[0] + fixture
                if favorite_retention or switch_recording:
                    for account, favorites in [(7, '["7"]'), (8, '["99", "8"]' if favorite_retention else '["8"]')]:
                        target = f'coldSettings.accounts[preferenceScope(connectionPreferenceIdentity(entry, "{account}"))] = {{favoriteIds: ["00000000-0000-4000-8000-{account:012d}"]'
                        assert source.count(target) == 1
                        source = source.replace(target, f'coldSettings.accounts[preferenceScope(connectionPreferenceIdentity(entry, "{account}"))] = {{favoriteIds: {favorites}', 1)
                    fixture_name = 'ProfileFavoriteRetentionFixture.brs' if favorite_retention else 'ProfileSwitchRecordingFixture.brs'
                    fixture = (ROOT / 'tests/native' / fixture_name).read_text().replace('SWITCH_RECORD_PIN', 'true' if switch_recording == 'pin-cancel' else 'false').replace('SWITCH_RECORD_CANCEL', 'true' if switch_recording == 'cancel' else 'false')
                    source = source.split('sub onManagementProbeTick()', 1)[0] + fixture
                    if switch_recording == 'pin-cancel':
                        target = '    m.registry.write("userProfilesV1_slot-a", FormatJson('
                        assert source.count(target) == 1
                        source = source.replace(target, '''    defaultHolder = setCanonicalPreference(defaultHolder, "pinType", "numbers")
    defaultHolder = setCanonicalPreference(defaultHolder, "pinSalt", string(32, "b"))
    defaultHolder = setCanonicalPreference(defaultHolder, "pinHash", userProfilePinHash(defaultHolder.pinSalt, "1234"))
    defaultHolder = setCanonicalPreference(defaultHolder, "pinLength", 4)
''' + target, 1)
                if child_escape:
                    source = source.split('sub onManagementProbeTick()', 1)[0] + (ROOT / 'tests/native/ProfileChildEscapeFixture.brs').read_text()
                    if switch_roster:
                        source = source.replace('setCanonicalPreference(store, "pendingRoster", true)', 'setCanonicalPreference(store, "pendingRoster", false)', 1)
                        source = source.replace('preserved = store.pendingRoster and', 'preserved = not store.pendingRoster and', 1)
                        target = '''    onProfileManagementChoice(managementProbeEvent(m.profileManagementDialog, 0))
    return generic and'''
                        assert source.count(target) == 1
                        source = source.replace(target, '''    if m.childEscapePendingChecked <> true
        m.childEscapePendingChecked = true
        original = m.registry.read(userProfileStoreKey("slot-a"))
        pending = loadUserProfileStore(m.registry, "slot-a")
        pending = setCanonicalPreference(pending, "pendingRoster", true)
        pendingText = FormatJson(pending)
        m.registry.write(userProfileStoreKey("slot-a"), pendingText)
        m.registry.flush()
        started = beginUserProfileSwitch(pending.profiles[0].id, true)
        m.childEscapePendingRefused = not started and m.profileSwitchContext = invalid and m.profilePinDialog = invalid and m.activeUserScope = invalid and m.apiKey = "" and m.global.profilegateclosed and m.registry.read(userProfileStoreKey("slot-a")) = pendingText
        m.registry.write(userProfileStoreKey("slot-a"), original)
        m.registry.flush()
    end if
''' + target, 1)
                        source = source.replace('passed: m.childEscapePassed and own', 'pending_refused: m.childEscapePendingRefused = true, passed: m.childEscapePassed and m.childEscapePendingRefused = true and own', 1)
                if child_launch:
                    source = source.replace('launchGate = selectedUserProfileGate()', 'launchGate = selectedUserProfileGate()\n        print "[profile-management] launch-gate="; launchGate.reason', 1)
                    target = '    m.registry.write("userProfilesV1_slot-a", FormatJson('
                    assert source.count(target) == 1
                    source = source.replace(target, '''    ownHolder = setCanonicalPreference(ownHolder, "role", "child")
    ownHolder = setCanonicalPreference(ownHolder, "addressHeld", true)
    holders = [defaultHolder, ownHolder]
    for holderIndex = 0 to holders.count() - 1
        holder = setCanonicalPreference(holders[holderIndex], "pinType", "numbers")
        holder = setCanonicalPreference(holder, "pinSalt", string(32, "b"))
        holder = setCanonicalPreference(holder, "pinHash", userProfilePinHash(holder.pinSalt, "1234"))
        holders[holderIndex] = holder
    end for
    defaultHolder = holders[0]
    ownHolder = holders[1]
''' + target, 1)
                    source = startup_probe_timer(source)
                    source = source.split('sub onManagementProbeTick()', 1)[0] + (ROOT / 'tests/native/ProfileChildLaunchFixture.brs').read_text()
                if child_available:
                    target = '    m.registry.write("userProfilesV1_slot-a", FormatJson('
                    assert source.count(target) == 1
                    child_index = 0 if child_available.startswith('default') else 1
                    pin = child_available.endswith('-pin')
                    seed = f'''    holders = [defaultHolder, ownHolder]
    for holderIndex = 0 to holders.count() - 1
        holder = holders[holderIndex]
        if holderIndex = {child_index} then holder = setCanonicalPreference(holder, "role", "child")
        if holderIndex <> {child_index} or {'true' if pin else 'false'}
            holder = setCanonicalPreference(holder, "pinType", "numbers")
            holder = setCanonicalPreference(holder, "pinSalt", string(32, "b"))
            holder = setCanonicalPreference(holder, "pinHash", userProfilePinHash(holder.pinSalt, "1234"))
        end if
        holders[holderIndex] = holder
    end for
    defaultHolder = holders[0]
    ownHolder = holders[1]
'''
                    source = source.replace(target, seed + target, 1)
                    if child_index == 0:
                        source = source.replace('active: ownHolder.id', 'active: defaultHolder.id', 1)
                    flag = 'm.profileChildAccessReady = false'
                    assert source.count(flag) == 1
                    source = source.replace(flag, 'm.profileChildAccessReady = true', 1)
                    source = startup_probe_timer(source)
                    fixture_name = 'ProfileChildRetryFixture.brs' if child_retry else 'ProfileChildAvailableFixture.brs'
                    if child_rejected:
                        fixture_name = 'ProfileChildRejectedFixture.brs'
                    fixture = (ROOT / 'tests/native' / fixture_name).read_text().replace('OWN_CHILD_ACCOUNT', '"7"' if child_index == 0 else '"8"').replace('OWN_CHILD_PIN', 'true' if pin else 'false').replace('OWN_CHILD_DEFAULT', 'true' if child_index == 0 else 'false')
                    source = source.split('sub onManagementProbeTick()', 1)[0] + fixture
                if default_filter:
                    source = source.replace('m.registry.write("connectionsV1", FormatJson({schema: 1, selected: "slot-a", entries: [entry]}))', '''entry.channelProfileIds = ["99", "100"]
    m.registry.write("connectionsV1", FormatJson({schema: 1, selected: "slot-a", entries: [entry]}))''', 1)
                if switch_roster:
                    target = 'm.profileSwitchRosterReady = false'
                    assert source.count(target) == 1
                    if not baseline_readiness:
                        source = source.replace(target, 'm.profileSwitchRosterReady = true', 1)
                    target = 'function onKeyEvent(key as string, press as boolean) as boolean\n'
                    assert source.count(target) == 1
                    source = source.replace(target, target + '''    if m.profileSwitchContext <> invalid and press
        print "[profile-management] "; FormatJson({kind: "switch-key", key: key, scene_focus: m.top.isInFocusChain(), guide_focus: m.guide.isInFocusChain(), has_task: m.profileSwitchTask <> invalid})
    end if
''', 1)
                    source = source.replace('kind: "cancel-ready", covered: m.profileGateCover.visible', 'kind: "cancel-ready", guide_active: m.guide.active, scene_owns_focus: m.top.hasFocus(), scene_focus: m.top.isInFocusChain(), guide_focus: m.guide.isInFocusChain(), has_dialog: m.top.dialog <> invalid, covered: m.profileGateCover.visible')
                if switch_authority_race:
                    source = source.split('sub onManagementProbeTick()', 1)[0] + (ROOT / 'tests/native/ProfileAuthorityRaceFixture.brs').read_text()
                if switch_active_retirement:
                    flag = 'm.profileDefaultRetirementReady = false'
                    assert source.count(flag) == 1
                    if not baseline_readiness:
                        source = source.replace(flag, 'm.profileDefaultRetirementReady = true', 1)
                    target = '    else if phase = 4\n        if OWN_RECONNECT_PROBE\n'
                    assert source.count(target) == 1
                    start = source.index(target)
                    end = source.index('    else if phase = 5\n', start)
                    source = source[:start] + '''    else if phase = 4
        advanceProfileActiveRetirementProbe()
        m.managementProbePhase--
''' + source[end:]
                    source += '\n' + (ROOT / 'tests/native/ProfileActiveRetirementFixture.brs').read_text().replace('ACTIVE_DEFAULT_MODE', json.dumps(active_default_mode))
                    if active_default_mode == 'cold':
                        bootstrap = f'''m.registry = CreateObject("roRegistrySection", "{section}")'''
                        source = source.replace(bootstrap, bootstrap + '''
    m.retirementColdBoot = m.registry.exists(userProfileRetirementKey("slot-a"))
    if m.retirementColdBoot
        m.retirementColdIntentId = ParseJson(m.registry.read(userProfileRetirementKey("slot-a"))).intentId
    end if
    if not m.retirementColdBoot''', 1)
                        source = source.replace('    m.registry.flush()\n', '    m.registry.flush()\n    end if\n', 1)
                        source = startup_probe_timer(source)
                        source = source.replace('sub onManagementProbeTick()\n', '''sub onManagementProbeTick()
    if m.retirementColdBoot
        runProfileRetirementColdProbe()
        return
    end if
    if m.page <> "guide" or m.busy then return
''', 1)
                        source += '\n' + (ROOT / 'tests/native/ProfileRetirementColdFixture.brs').read_text()
                if switch_writer:
                    target = '    else if phase = 4\n        if OWN_RECONNECT_PROBE\n'
                    assert source.count(target) == 1
                    start = source.index(target)
                    end = source.index('    else if phase = 5\n', start)
                    source = source[:start] + '''    else if phase = 4
        advanceProfileSyncWriterProbe()
        m.managementProbePhase--
''' + source[end:]
                    source += '\n' + (ROOT / 'tests/native/ProfileSyncWriterFixture.brs').read_text().replace('PROFILE_WRITER_MODE', json.dumps(writer_mode))
                    if writer_mode != 'direct' and not baseline_readiness:
                        assert source.count('m.profileSyncWriterReady = false') == 1
                        source = source.replace('m.profileSyncWriterReady = false', 'm.profileSyncWriterReady = true', 1)
                    if writer_mode == 'flush-own-retirement' and not baseline_readiness:
                        assert source.count('m.profileDefaultRetirementReady = false') == 1
                        source = source.replace('m.profileDefaultRetirementReady = false', 'm.profileDefaultRetirementReady = true', 1)
                    if writer_mode == 'controls-restore':
                        bootstrap = f'''m.registry = CreateObject("roRegistrySection", "{section}")'''
                        source = source.replace(bootstrap, bootstrap + '''
    m.syncControlsColdBoot = m.registry.read("syncSettingsProbeRestore") = "1"
    if not m.syncControlsColdBoot''', 1)
                        source = source.replace('    m.registry.flush()\n', '    m.registry.flush()\n    end if\n', 1)
                        source = source.replace('sub onManagementProbeTick()\n', '''sub onManagementProbeTick()
    if m.syncControlsColdBoot
        runProfileSyncControlsColdProbe()
        return
    end if
''', 1)
                body = source.replace('OWN_RECONNECT_PROBE', 'true' if reconnect else 'false').encode()
            package.writestr(name, body)
        package.writestr('profile-management-probe.json', json.dumps({'synthetic': True}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', required=True)
    parser.add_argument('--directions', action='store_true', help='Exercise numeric-to-Directions adult-type selection under developer opt-in')
    parser.add_argument('--switch', action='store_true', help='Exercise internal same-slot A/B/A and rejected-key rollback without enabling the public picker')
    parser.add_argument('--switch-roster', action='store_true', help='With --switch or --child-escape, opt in ONLY this synthetic package to staged target authentication/own roster read before lineup; no public flag change')
    parser.add_argument('--switch-import-pin', action='store_true', help='Only with --switch --switch-roster: import a previously absent target numeric PIN, reject the old value and admit its real stored v2 value')
    parser.add_argument('--switch-inactive-cleanup', action='store_true', help='Only with --switch --switch-roster: remove a synthetic inactive third holder through own App Data, preserving default/target/foreign data')
    parser.add_argument('--switch-target-retirement', action='store_true', help='Only with --switch --switch-roster: non-default B selects C, whose own tombstone retires C without adopting C or the different default A')
    parser.add_argument('--switch-authority-race', action='store_true', help='Only with --switch --switch-roster: change target authority on final me and require rollback with zero target lineup requests')
    parser.add_argument('--switch-active-retirement', action='store_true', help='Only with --switch --switch-roster: C own roster removes actual B, requiring default A own system adoption without its PIN')
    parser.add_argument('--baseline-readiness', action='store_true', help='For existing retirement fixtures: use actual developer-baseline readiness instead of forced Scene/Task flags')
    parser.add_argument('--switch-writer', action='store_true', help='Only with --switch --switch-roster: private own-B canonical re-read and checked-string PUT')
    parser.add_argument('--writer-mode', choices=['direct', 'controls', 'controls-restore', 'unchanged', 'schedule', 'schedule-too-large', 'schedule-signin', 'create', 'create-legacy', 'create-proxy404', 'flush', 'flush-failed', 'flush-cancel', 'flush-authority', 'flush-import-pin', 'flush-own-retirement'], default='direct', help='Private writer fixture: explicit controls/cold restore, scheduled/direct/unchanged, canonical creation/refusal, outgoing flush, own retirement, imported PIN or refusal')
    parser.add_argument('--active-default-mode', choices=['usable', 'missing', 'held', 'child', 'cold', 'simultaneous', 'import-pin', 'import-child'], default='usable', help='Only with --switch-active-retirement: default own credential/access state')
    parser.add_argument('--reconnect', action='store_true', help='With --switch, reconnect B through early roster read and full activation before returning to A')
    parser.add_argument('--switch-pin', action='store_true', help='With --switch, require the real stored numeric target PIN before each switch')
    parser.add_argument('--cancel-pin', action='store_true', help='With --switch-pin, cancel the final target PIN before any request is sent')
    parser.add_argument('--reject-active', action='store_true', help='With --switch, qualify profile-owned active-key revocation without default setup fallback')
    parser.add_argument('--remember-off', action='store_true', help='With --switch, use address/slot/profile-qualified session credentials only')
    parser.add_argument('--child-settings', action='store_true', help='Exercise restricted Settings and its adult-gated management shortcut in a private Child-role fixture')
    parser.add_argument('--cold-restore', choices=['remembered', 'keyless', 'held'], help='Launch a fresh process with a persisted nondefault selection; unavailable adults restore default')
    parser.add_argument('--default-filter', action='store_true', help='Give default A a two-Channel-Profile choice; nondefault B must never borrow either filter')
    parser.add_argument('--assignment-refresh', action='store_true', help='Qualify active-B assignment and VOD permission revocation through the real CapabilityTask callback and fresh own-session reload')
    parser.add_argument('--manual-refresh', action='store_true', help='Reproduce active-B assignment/VOD authority changes through manual lineup refresh instead of the periodic callback')
    parser.add_argument('--manual-recording', action='store_true', help='Private manual-refresh variant: settle one real delayed synthetic recording POST across authority retirement')
    parser.add_argument('--manual-mode', choices=['changed', 'unchanged', 'identity', 'transient'], default='changed', help='Private manual refresh authority/control outcome')
    parser.add_argument('--favorite-retention', action='store_true', help='Private numeric-ID Guide edit/refresh/explicit favorite toggle, including unavailable favorites and other-holder isolation')
    parser.add_argument('--switch-recording', choices=['commit', 'cancel', 'pin-cancel'], help='Private submitted recording across actual switch/return, delayed-auth Back or target-PIN Back')
    parser.add_argument('--child-escape', action='store_true', help='Qualify held Child adult admission, target PIN cancellation, rejected key, delayed Back and own target activation')
    parser.add_argument('--child-launch', action='store_true', help='Cold protected held Child: own launch PIN, unavailable surface, then separate adult-purpose admission with zero provider requests')
    parser.add_argument('--child-available', choices=['own', 'own-pin', 'default', 'default-pin'], help='Private readiness seam: qualify own Child auth/roster/lineup without enabling shipping Child activation')
    parser.add_argument('--child-retry', choices=['own', 'own-pin', 'default', 'default-pin'], help='Private Child transient failure, own Retry and Back during delayed authentication, followed by own retry')
    parser.add_argument('--child-rejected', choices=['own', 'own-pin', 'default', 'default-pin'], help='Private actual Child rejection: exact cut prompt, permitted own form/dismissal, no stale replay, adult management and real Back exit')
    args = parser.parse_args()
    if args.baseline_readiness and not (args.switch_active_retirement or (args.switch_writer and args.writer_mode == 'flush-own-retirement')):
        parser.error('--baseline-readiness requires an active or own-writer retirement fixture')
    if args.switch_roster and not (args.switch or args.child_escape):
        parser.error('--switch-roster requires --switch or --child-escape')
    if args.switch_import_pin and (not args.switch or not args.switch_roster or any([args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.reconnect, args.child_settings, args.cold_restore, args.default_filter, args.assignment_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected, args.manual_refresh, args.manual_recording, args.favorite_retention, args.switch_recording, args.directions])):
        parser.error('--switch-import-pin requires only --switch --switch-roster')
    if args.switch_inactive_cleanup and (not args.switch or not args.switch_roster or any([args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.reconnect, args.child_settings, args.cold_restore, args.default_filter, args.assignment_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected, args.manual_refresh, args.manual_recording, args.favorite_retention, args.switch_recording, args.directions, args.switch_import_pin])):
        parser.error('--switch-inactive-cleanup requires only --switch --switch-roster')
    if args.switch_target_retirement and (not args.switch or not args.switch_roster or any([args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.reconnect, args.child_settings, args.cold_restore, args.default_filter, args.assignment_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected, args.manual_refresh, args.manual_recording, args.favorite_retention, args.switch_recording, args.directions, args.switch_import_pin, args.switch_inactive_cleanup])):
        parser.error('--switch-target-retirement requires only --switch --switch-roster')
    if args.switch_authority_race and (not args.switch or not args.switch_roster or any([args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.reconnect, args.child_settings, args.cold_restore, args.default_filter, args.assignment_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected, args.manual_refresh, args.manual_recording, args.favorite_retention, args.switch_recording, args.directions, args.switch_import_pin, args.switch_inactive_cleanup, args.switch_target_retirement])):
        parser.error('--switch-authority-race requires only --switch --switch-roster')
    if args.switch_active_retirement and (not args.switch or not args.switch_roster or any([args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.reconnect, args.child_settings, args.cold_restore, args.default_filter, args.assignment_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected, args.manual_refresh, args.manual_recording, args.favorite_retention, args.switch_recording, args.directions, args.switch_import_pin, args.switch_inactive_cleanup, args.switch_target_retirement, args.switch_authority_race])):
        parser.error('--switch-active-retirement requires only --switch --switch-roster')
    if args.active_default_mode != 'usable' and not args.switch_active_retirement:
        parser.error('--active-default-mode requires --switch-active-retirement')
    if args.switch_recording and any([args.switch, args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.reconnect, args.cold_restore, args.child_settings, args.directions, args.default_filter, args.assignment_refresh, args.manual_refresh, args.manual_recording, args.favorite_retention, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected]):
        parser.error('--switch-recording is a separate case')
    if args.favorite_retention and any([args.switch, args.cold_restore, args.child_settings, args.directions, args.default_filter, args.assignment_refresh, args.manual_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected]):
        parser.error('--favorite-retention is a separate case')
    if args.manual_recording and not args.manual_refresh:
        parser.error('--manual-recording requires --manual-refresh')
    if args.manual_recording and args.manual_mode not in ['changed', 'unchanged']:
        parser.error('--manual-recording supports changed or unchanged authority only')
    if args.manual_mode != 'changed' and not args.manual_refresh:
        parser.error('--manual-mode requires --manual-refresh')
    if args.manual_refresh:
        args.assignment_refresh = True
    if args.child_rejected and (args.child_available or args.child_retry or args.switch or args.child_launch or args.child_escape or args.cold_restore or args.child_settings or args.directions or args.assignment_refresh or args.default_filter):
        parser.error('--child-rejected is a separate case')
    if args.child_retry:
        if args.child_available or args.switch or args.child_launch or args.child_escape or args.cold_restore or args.child_settings or args.directions or args.assignment_refresh or args.default_filter:
            parser.error('--child-retry is a separate case')
    if args.child_available and (args.switch or args.cold_restore or args.child_settings or args.directions or args.default_filter or args.assignment_refresh or args.child_escape or args.child_launch):
        parser.error('--child-available is a separate case')
    if args.child_launch and (args.switch or args.cold_restore or args.child_settings or args.directions or args.default_filter or args.assignment_refresh or args.child_escape):
        parser.error('--child-launch is a separate case')
    if args.child_escape and (args.switch or args.cold_restore or args.child_settings or args.directions or args.default_filter or args.assignment_refresh):
        parser.error('--child-escape is a separate case')
    if args.assignment_refresh and (args.switch or args.cold_restore or args.child_settings or args.directions or args.default_filter):
        parser.error('--assignment-refresh is a separate case')
    if args.default_filter and not args.switch:
        parser.error('--default-filter requires --switch')
    if args.reconnect and not args.switch:
        parser.error('--reconnect requires --switch')
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
    fixture_state = {'changed': False}
    cancel_reply_release = threading.Event()
    recording_probe = bool(args.manual_recording or args.switch_recording)

    class Fixture(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_PUT(self):
            user = management_probe_user(self.headers.get('X-API-Key', ''))
            hits.append({'user': user, 'path': self.path, 'method': 'PUT', 'rejected': False, 'delayed': False})
            length = int(self.headers.get('Content-Length', '0'))
            raw = self.rfile.read(length)
            valid = False
            try:
                value = json.loads(raw)
                future = value['categories'].get('FutureCategory', {}).get('data', {})
                roster = value['categories']['profiles']['data']
                valid = args.switch_writer and user == 8 and self.path == '/api/accounts/users/me/app-data/synthetic8.aeriotv/' and self.headers.get('Content-Type', '').startswith('application/json') and length == len(raw) and value['schemaVersion'] == 3 and value['platform'] == 'roku' and {row[0] for row in roster['rows']} == {7, 8}
                if args.writer_mode == 'create':
                    valid = valid and set(value) == {'schemaVersion', 'deviceId', 'platform', 'appVersion', 'updatedAt', 'categories'} and set(value['categories']) == {'profiles'} and 'FutureRoster' not in roster
                else:
                    valid = valid and value['FutureEnvelope'] == 1794675600000 and type(future['KeepDouble']) is float and future['KeepDouble'] == 1.0 and future['Precision'] == 1.3 and future['Emoji'] == '😀' and roster['FutureRoster'] == {'Case': 1, 'case': 2}
                valid = valid and type(value['schemaVersion']) is int and len(value['updatedAt']) == 20 and value['updatedAt'].endswith('Z') and all(type(row[0]) is int and type(row[7]) is int and type(row[9]) is int for row in roster['rows'])
                if args.writer_mode.startswith('schedule'):
                    valid = valid and next(row for row in roster['rows'] if row[0] == 8)[2] == 'Scheduled synthetic B'
                    fixture_state['schedule_put_at'] = time.monotonic()
                if args.writer_mode == 'flush-import-pin':
                    target = next(row for row in roster['rows'] if row[0] == 7)
                    salt = '0123456789abcdef0123456789abcdef'
                    valid = valid and target[3:6] == ['numbers', hashlib.sha256(bytes.fromhex(salt) + b'5678').hexdigest(), salt]
            except (ValueError, KeyError, TypeError, StopIteration, IndexError):
                pass
            fixture_state['writer_body_ok'] = valid
            if valid and args.writer_mode == 'unchanged':
                fixture_state['writer_saved_value'] = value
            if valid and args.writer_mode == 'flush-cancel':
                cancel_started = time.monotonic()
                activity = management_probe_activity(host)
                fixture_state['writer_cancel_query_ms'] = round((time.monotonic() - cancel_started) * 1000)
                fixture_state['writer_cancel_activity'] = activity
                if activity['dev_active'] and not activity['screensaver_active']:
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                    try:
                        with urllib.request.urlopen(request, timeout=2) as response:
                            fixture_state['writer_cancel_sent'] = True
                            fixture_state['writer_cancel_status'] = response.status
                    except (OSError, urllib.error.HTTPError) as error:
                        fixture_state['writer_cancel_error'] = type(error).__name__
                fixture_state['writer_cancel_elapsed_ms'] = round((time.monotonic() - cancel_started) * 1000)
                time.sleep(4)
            try:
                status = (500 if args.writer_mode == 'flush-failed' else 200) if valid else 400
                payload = b'{}'
                if valid and args.writer_mode == 'schedule-too-large':
                    status = 413
                    payload = b'{"code":"value_too_large"}'
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError):
                pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
            user = management_probe_user(self.headers.get('X-API-Key', ''))
            hits.append({'user': user, 'path': self.path, 'method': 'POST', 'rejected': False, 'delayed': True})
            if not recording_probe or self.path != '/api/channels/recordings/':
                self.send_error(404)
                return
            time.sleep(12)
            value = dict(body, id=900, status='scheduled')
            data = json.dumps(value).encode()
            self.send_response(201)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            try:
                self.wfile.write(data)
                fixture_state['recording_replied'] = True
            except (BrokenPipeError, ConnectionResetError):
                fixture_state['recording_replied'] = False

        def do_GET(self):
            key = self.headers.get('X-API-Key', '')
            user = management_probe_user(key)
            if args.child_rejected and fixture_state.get('child_rejected', False) and self.path == '/api/accounts/users/me/':
                fixture_state['child_key_rejected'] = True
            child_rejected = bool(args.child_rejected and fixture_state.get('child_key_rejected', False))
            rejected = key == 'rejected-synthetic-key' or child_rejected or (args.switch_active_retirement and args.active_default_mode == 'held' and fixture_state.get('reject_system_default', False) and user == 7)
            hits.append({'user': user, 'path': self.path, 'rejected': rejected, 'delayed': key in ['delayed-b', 'delayed-a']})
            if key in ['delayed-b', 'delayed-a'] and self.path == '/api/accounts/users/me/':
                if args.switch and not args.cancel_pin:
                    fixture_state['cancel_auth_waiting'] = True
                    # Do not let machine scheduling turn a cancellation test
                    # into Back after a successfully committed switch.
                    fixture_state['cancel_reply_released'] = cancel_reply_release.wait(timeout=12)
                else:
                    time.sleep(4)
            if args.switch_recording == 'cancel' and key == 'synthetic-a' and self.path == '/api/accounts/users/me/':
                fixture_state['switch_auth_delayed'] = True
                time.sleep(4)
            failure = False
            if args.manual_refresh and args.manual_mode == 'transient' and fixture_state['changed'] and self.path == '/api/accounts/users/me/':
                failure = True
            if args.child_retry and self.path == '/api/accounts/users/me/':
                fixture_state['child_auth_attempts'] = fixture_state.get('child_auth_attempts', 0) + 1
                attempt = fixture_state['child_auth_attempts']
                failure = not fixture_state.get('child_retry_started', False)
                if not failure and not fixture_state.get('child_retry_delayed', False):
                    fixture_state['child_retry_delayed'] = True
                    time.sleep(4)
            value = []
            if self.path == '/api/accounts/users/me/':
                value = {'id': user, 'username': 'Synthetic' + str(user), 'user_level': 1}
                if args.switch_writer and args.writer_mode == 'flush-authority' and fixture_state.get('writer_started', False) and user == 8:
                    value['user_level'] = 10
                if args.switch_authority_race:
                    value = authority_race_user(fixture_state, value)
                if failure:
                    value = {'detail': 'Synthetic server unavailable'}
                if args.assignment_refresh and user == 8:
                    changed = fixture_state['changed'] and args.manual_mode != 'unchanged'
                    value['channel_profiles'] = [2 if changed else 1]
                    value['custom_properties'] = {'vod_movies_enabled': not changed}
                    if args.manual_refresh and args.manual_mode == 'identity' and changed:
                        value['id'] = 80
                        value['username'] = 'DifferentUser'
                if recording_probe and user == 8:
                    value.setdefault('custom_properties', {})['dvr_access'] = 'manage'
            if self.path == '/api/accounts/users/me/app-data/':
                value = {'apps': []}
                if args.switch_writer and user == 8 and not args.writer_mode.startswith('create'):
                    value = {'apps': [{'key': 'synthetic8.aeriotv', 'bytes': 100}]}
                if args.switch_writer and user == 8 and args.writer_mode == 'create-legacy':
                    value = {'apps': [{'key': 'app.molinete.aerio', 'bytes': 100}]}
                if args.child_available or ((args.switch_import_pin or args.switch_inactive_cleanup) and user == 8) or ((args.switch_target_retirement or args.switch_active_retirement) and user == 9):
                    value = {'apps': [{'key': f'synthetic{user}.aeriotv', 'bytes': 600}]}
            if args.switch_import_pin and user == 8 and self.path == '/api/accounts/users/me/app-data/synthetic8.aeriotv/':
                value = switch_import_pin_envelope()
            if args.switch_inactive_cleanup and user == 8 and self.path == '/api/accounts/users/me/app-data/synthetic8.aeriotv/':
                value = switch_inactive_cleanup_envelope()
            if args.switch_target_retirement and user == 9 and self.path == '/api/accounts/users/me/app-data/synthetic9.aeriotv/':
                value = switch_inactive_cleanup_envelope()
            if args.switch_active_retirement and user == 9 and self.path == '/api/accounts/users/me/app-data/synthetic9.aeriotv/':
                value = switch_inactive_cleanup_envelope('synthetic8')
                if args.active_default_mode == 'simultaneous':
                    rows = value['categories']['profiles']['data']['removed']
                    rows.append(['synthetic9', rows[0][1]])
                if args.active_default_mode in ['cold', 'import-pin', 'import-child']:
                    salt = '0123456789abcdef0123456789abcdef'
                    role = 'child' if args.active_default_mode == 'import-child' else 'user'
                    value['categories']['profiles']['data']['rows'] = [[7, 'Synthetic7', 'Protected default', 'numbers', hashlib.sha256(bytes.fromhex(salt) + b'5678').hexdigest(), salt, role, int(time.time()), {}, 0]]
            if args.switch_writer and user == 8 and self.path == '/api/accounts/users/me/app-data/synthetic8.aeriotv/':
                value = {'schemaVersion': 3, 'deviceId': 'synthetic-phone', 'platform': 'android', 'appVersion': '1', 'updatedAt': '2026-11-14T17:00:00Z', 'categories': {'profiles': {'updatedAt': '2026-11-14T17:00:00Z', 'data': {'rows': [], 'FutureRoster': {'Case': 1, 'case': 2}}}, 'FutureCategory': {'updatedAt': '2026-11-14T17:00:00Z', 'data': {'KeepDouble': 1.0, 'Precision': 1.3, 'Emoji': '😀'}}}, 'FutureEnvelope': 1794675600000}
                if args.writer_mode == 'flush-import-pin' and fixture_state.get('writer_started', False):
                    stamp = fixture_state.setdefault('writer_import_stamp', int(time.time()))
                    salt = '0123456789abcdef0123456789abcdef'
                    value['categories']['profiles']['data']['rows'] = [[7, 'Synthetic7', 'Synthetic7', 'numbers', hashlib.sha256(bytes.fromhex(salt) + b'5678').hexdigest(), salt, 'user', stamp, {}, 0]]
                if args.writer_mode == 'flush-own-retirement' and fixture_state.get('writer_started', False):
                    salt = '0123456789abcdef0123456789abcdef'
                    value['categories']['profiles']['data']['rows'] = [[7, 'Synthetic7', 'Protected default', 'numbers', hashlib.sha256(bytes.fromhex(salt) + b'5678').hexdigest(), salt, 'user', int(time.time()), {}, 0]]
                    value['categories']['profiles']['data']['removed'] = [['synthetic8', int(time.time())]]
                if args.writer_mode == 'unchanged' and 'writer_saved_value' in fixture_state:
                    value = fixture_state['writer_saved_value']
                if args.writer_mode == 'controls-restore' and fixture_state.get('controls_relaunch_started', False):
                    value['categories']['profiles']['data']['rows'] = [[8, 'Synthetic8', 'Must stay unapplied', 'numbers', 'a' * 64, 'b' * 32, 'child', int(time.time()), {}, 0]]
            if args.child_available and self.path == f'/api/accounts/users/me/app-data/synthetic{user}.aeriotv/':
                stamp = '2026-11-14T12:00:00Z'
                value = {'schemaVersion': 3, 'deviceId': 'synthetic-phone', 'platform': 'android', 'appVersion': '1', 'updatedAt': stamp,
                         'categories': {'profiles': {'updatedAt': stamp, 'data': {'rows': [[user, f'Synthetic{user}', 'Foreign roster rename', 'none', '', '', 'user', 1794657600]]}}}}
            if self.path.split('?', 1)[0] == '/api/channels/profiles/' and user == 7:
                value = [{'id': 99, 'name': 'Synthetic default first', 'channels': [7]}, {'id': 100, 'name': 'Synthetic default second', 'channels': [7]}]
            if self.path.split('?', 1)[0] in ['/api/channels/channels/', '/api/channels/channels/summary/']:
                value = [{'id': user, 'uuid': f'00000000-0000-4000-8000-{user:012d}', 'name': 'Synthetic ' + str(user), 'channel_number': user}]
                if args.favorite_retention and fixture_state.get('favorite_return'):
                    value.append({'id': 99, 'uuid': '00000000-0000-4000-8000-000000000099', 'name': 'Synthetic returned', 'channel_number': 99})
                if args.assignment_refresh and user == 8 and fixture_state['changed'] and args.manual_mode != 'unchanged':
                    value = [{'id': 80, 'uuid': '00000000-0000-4000-8000-000000000080', 'name': 'Synthetic reassigned', 'channel_number': 80}]
            if child_rejected or (args.switch_active_retirement and args.active_default_mode == 'held' and rejected):
                value = {'detail': 'Invalid API key'}
            missing = args.switch_writer and args.writer_mode.startswith('create') and user == 8 and self.path == '/api/accounts/users/me/app-data/synthetic8.aeriotv/'
            if missing:
                value = {'detail': 'Proxy page not found'} if args.writer_mode == 'create-proxy404' else {'code': 'key_not_found'}
            sync_signin_refused = args.switch_writer and args.writer_mode == 'schedule-signin' and fixture_state.get('writer_started', False) and user == 8 and self.path == '/api/accounts/users/me/app-data/'
            if sync_signin_refused:
                value = {'detail': 'Forbidden'}
            body = json.dumps(value).encode()
            self.send_response(503 if failure else (401 if rejected else (403 if sync_signin_refused else (404 if missing else 200))))
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
    build(archive, ROOT / 'out/aeriotv-roku.zip', section, f'http://{local}:{server.server_port}', args.directions, args.switch, args.switch_pin, args.cancel_pin, args.reject_active, args.remember_off, args.child_settings, args.reconnect, args.cold_restore, args.default_filter, args.assignment_refresh, args.child_escape, args.child_launch, args.child_available, args.child_retry, args.child_rejected, args.manual_refresh, args.manual_recording, args.manual_mode, args.favorite_retention, args.switch_recording, args.switch_roster, args.switch_import_pin, args.switch_inactive_cleanup, args.switch_target_retirement, args.switch_authority_race, args.switch_active_retirement, args.active_default_mode, args.switch_writer, args.writer_mode, args.baseline_readiness)
    modules['recovery'].cleanup_package(cleaner, section)
    report = {'passed': False, 'baseline_readiness': args.baseline_readiness}

    def run(path, marker, prefix='[profile-management]'):
        command = ['python3', 'scripts/run-native-probe.py', str(path), '--prefix', prefix, '--marker', marker, '--timeout', '75' if args.writer_mode.startswith('controls') else '45']
        if path != archive:
            return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=100)
        output = []
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
            for line in process.stdout:
                output.append(line)
                report['partial_probe_output'] = ''.join(output)
                if '"kind":"writer-ready"' in line and 'writer_request_boundary' not in report:
                    report['writer_request_boundary'] = len(hits)
                    fixture_state['writer_started'] = True
                if '"kind":"schedule-dirty"' in line:
                    fixture_state['schedule_dirty_at'] = time.monotonic()
                if '"kind":"controls-relaunch-ready"' in line:
                    row = json.loads(line.split('[profile-management] ', 1)[1])
                    report['controls_cold_ready'] = row.get('ready', False)
                    report['controls_cold_boundary'] = len(hits)
                    if not report['controls_cold_ready']:
                        raise RuntimeError('Cold sync-controls checkpoint did not retain the intended choices')
                    fixture_state['controls_relaunch_started'] = True
                    report['controls_cold_relaunched'] = launch_profile_probe_after_exit(host)
                if any('"kind":"' + kind + '"' in line for kind in ['controls-ready', 'controls-enabled', 'controls-profiles-off', 'controls-restored', 'controls-disable-ready']):
                    row = json.loads(line.split('[profile-management] ', 1)[1])
                    report.setdefault('controls_events', []).append(row)
                    if row['kind'] != 'controls-disable-ready':
                        report.setdefault('controls_pre_close_requests', []).append(hits[report['writer_request_boundary']:].copy())
                    if row['kind'] == 'controls-ready':
                        captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', str(ROOT / 'out/profile-sync-controls.jpg')], cwd=ROOT, capture_output=True, text=True, timeout=45)
                        report['controls_screenshot'] = captured.returncode == 0
                    keys = ['Select']
                    if row['kind'] in ['controls-enabled', 'controls-profiles-off']:
                        keys = ['Down', 'Select']
                    if args.writer_mode == 'controls-restore' and row['kind'] == 'controls-profiles-off':
                        keys = []
                    if row['kind'] == 'controls-restored':
                        keys = ['Back']
                    for key in keys:
                        request = urllib.request.Request(f'http://{host}:8060/keypress/{key}', data=b'', method='POST')
                        started = time.monotonic()
                        attempt = {'key': key, 'activity': management_probe_activity(host)}
                        try:
                            with urllib.request.urlopen(request, timeout=2) as response:
                                attempt['status'] = response.status
                                report.setdefault('controls_key_statuses', []).append(response.status)
                        except (OSError, urllib.error.HTTPError) as error:
                            attempt['error'] = type(error).__name__
                        attempt['elapsed_ms'] = round((time.monotonic() - started) * 1000)
                        report.setdefault('controls_key_attempts', []).append(attempt)
                if '"kind":"writer-target-pin-ready"' in line:
                    report['writer_pre_pin_requests'] = hits[report['writer_request_boundary']:].copy()
                    report['writer_target_pin_ready'] = json.loads(line.split('[profile-management] ', 1)[1]).get('ready', False)
                if '"kind":"writer-flush-started"' in line:
                    report['writer_source_admitted'] = json.loads(line.split('[profile-management] ', 1)[1]).get('admitted', False)
                if '"kind":"writer-imported-pin-ready"' in line:
                    report['writer_import_pin_ready'] = json.loads(line.split('[profile-management] ', 1)[1]).get('ready', False)
                    report['writer_before_import_pin'] = hits[report['writer_request_boundary']:].copy()
                if '"kind":"writer-import-old-refused"' in line:
                    report['writer_import_old_refused'] = json.loads(line.split('[profile-management] ', 1)[1]).get('refused', False)
                    report['writer_after_old_import_pin'] = hits[report['writer_request_boundary']:].copy()
                if '"kind":"retirement-crash-ready"' in line:
                    checkpoint = json.loads(line.split('[profile-management] ', 1)[1])
                    report['cold_checkpoint'] = checkpoint
                    report['cold_request_boundary'] = len(hits)
                    if not all(checkpoint.get(key) for key in ['journal', 'fenced', 'retained']):
                        raise RuntimeError('Cold retirement checkpoint did not retain fenced committed intent')
                    report['cold_relaunched'] = launch_profile_probe_after_exit(host)
                if '"kind":"retirement-cold-pin-ready"' in line:
                    report['cold_pre_pin_requests'] = hits[report['cold_request_boundary']:].copy()
                if '"kind":"retirement-cold-old-pin-refused"' in line:
                    report['cold_old_pin_refused'] = json.loads(line.split('[profile-management] ', 1)[1]).get('refused', False)
                    report['cold_old_pin_requests'] = hits[report['cold_request_boundary']:].copy()
                if '"kind":"assignment-ready"' in line:
                    fixture_state['changed'] = True
                if '"kind":"active-default-reject-ready"' in line:
                    fixture_state['reject_system_default'] = True
                if '"kind":"favorite-return-ready"' in line:
                    fixture_state['favorite_return'] = True
                if '"kind":"retry-ready"' in line:
                    fixture_state['child_retry_started'] = True
                if '"kind":"revoke-ready"' in line:
                    fixture_state['child_rejected'] = True
                    fixture_state['child_rejection_boundary'] = len(hits)
                if '"kind":"child-rejection-ready"' in line:
                    fixture_state['child_unavailable_boundary'] = len(hits)
                if '"kind":"child-unavailable"' in line:
                    fixture_state['child_request_boundary'] = len(hits)
                if '"kind":"child-pin-ready"' in line:
                    report['pre_pin_requests'] = list(hits)
                if '"kind":"manage-ready"' in line:
                    captured = subprocess.run(['python3', 'scripts/capture-roku-screenshot.py', '--developer-mode', '--output', str(ROOT / 'out/profile-child-settings.jpg')], cwd=ROOT, capture_output=True, text=True, timeout=45)
                    report['screenshot'] = captured.returncode == 0
                    for key in ['Down', 'Down', 'Down', 'Down', 'Right', 'Select']:
                        request = urllib.request.Request(f'http://{host}:8060/keypress/{key}', data=b'', method='POST')
                        urllib.request.urlopen(request, timeout=10).close()
                        time.sleep(0.1)
                if '"kind":"cancel-ready"' in line:
                    activity = management_probe_activity(host)
                    report['cancel_activity'] = activity
                    if not activity['dev_active'] or activity['screensaver_active']:
                        raise RuntimeError('Cancellation probe is not foreground-ready; refusing to wake or replace another app')
                    request = urllib.request.Request(f'http://{host}:8060/keypress/Back', data=b'', method='POST')
                    urllib.request.urlopen(request, timeout=10).close()
                    report['back_count'] = report.get('back_count', 0) + 1
                if '"kind":"switch-cancel-observed"' in line:
                    row = json.loads(line.split('[profile-management] ', 1)[1])
                    report['switch_cancel_observed'] = row.get('observed') is True
                    if report['switch_cancel_observed']:
                        cancel_reply_release.set()
            stderr = process.stderr.read()
            return subprocess.CompletedProcess(command, process.wait(timeout=100), ''.join(output), stderr)

    try:
        result = run(archive, '"kind":"result"')
        print(result.stdout, end='', flush=True)
        if result.returncode:
            print(result.stderr, end='', flush=True)
        rows = [json.loads(line.split('[profile-management] ', 1)[1]) for line in result.stdout.splitlines() if '[profile-management] {' in line]
        report['baseline_retirement_consent'] = [row for row in rows if row.get('kind') == 'baseline-retirement-consent']
        rows = [row for row in rows if row.get('kind') not in ['baseline-retirement-consent', 'switch-cancel-observed']]
        report['switch_key_events'] = [row for row in rows if row.get('kind') == 'switch-key']
        report['switch_guide_key_events'] = [row for row in rows if row.get('kind') == 'switch-guide-key']
        report['default_rejection_ready'] = any(row.get('kind') == 'active-default-reject-ready' for row in rows)
        rows = [row for row in rows if not row.get('kind', '').startswith('controls-') and row.get('kind') not in ['switch-key', 'switch-guide-key', 'active-default-reject-ready', 'retirement-crash-ready', 'retirement-cold-pin-ready', 'retirement-cold-old-pin-refused', 'writer-ready', 'schedule-dirty', 'writer-target-pin-ready', 'writer-flush-started', 'writer-imported-pin-ready', 'writer-import-old-refused']]
        report['events'] = rows
        if args.child_escape:
            report['requests'] = hits
        report['passed'] = result.returncode == 0 and len(rows) == 5 and rows[0].get('dialog') and rows[1].get('native') and rows[2].get('native') and rows[2].get('covered') and all(rows[4].get(key) for key in ['renamed', 'wrong', 'grant', 'learned', 'management', 'uncovered', 'preserved', 'no_unlock', 'cancelled'])
        if args.switch:
            rejected = [hit for hit in hits if hit['rejected']]
            delayed = [hit for hit in hits if hit['delayed']]
            report['requests'] = hits
            cancelled_requests = not delayed if args.cancel_pin else len(delayed) == 1 and delayed[0]['path'] == '/api/accounts/users/me/'
            report['passed'] = result.returncode == 0 and len(rows) == 5 and rows[0].get('started') and all(rows[4].get(key) for key in ['a', 'b', 'rollback', 'preserved', 'uncovered', 'no_autoplay', 'cancelled', 'stale_a', 'stale_keyboard']) and len(rejected) == 1 and rejected[0]['path'] == '/api/accounts/users/me/' and cancelled_requests
            if not args.cancel_pin and not any([args.reject_active, args.switch_authority_race, args.switch_writer, args.switch_active_retirement]):
                report['cancel_auth_waiting'] = fixture_state.get('cancel_auth_waiting', False)
                report['cancel_reply_released'] = fixture_state.get('cancel_reply_released', False)
                report['passed'] = report['passed'] and report.get('switch_cancel_observed', False) and report['cancel_auth_waiting'] and report['cancel_reply_released']
            if args.reject_active:
                report['passed'] = result.returncode == 0 and len(rows) == 3 and all(rows[2].get(key) for key in ['b', 'active_retained', 'default_preserved', 'own_revoked', 'covered', 'no_default_session'])
            if args.remember_off:
                report['passed'] = report['passed'] and rows[-1].get('no_stored', False)
            if args.reconnect:
                report['passed'] = report['passed'] and rows[-1].get('reconnected', False)
            if args.switch_roster:
                roster = [index for index, hit in enumerate(hits) if hit['user'] == 8 and hit['path'] == '/api/accounts/users/me/app-data/']
                lineup = next((index for index, hit in enumerate(hits) if hit['user'] == 8 and hit['path'].startswith('/api/channels/channels/summary/')), -1)
                report['own_roster_before_lineup'] = bool(roster) and lineup > roster[0]
                report['passed'] = report['passed'] and report['own_roster_before_lineup']
            if args.switch_import_pin:
                own_record = next((index for index, hit in enumerate(hits) if hit['user'] == 8 and hit['path'] == '/api/accounts/users/me/app-data/synthetic8.aeriotv/'), -1)
                report['imported_pin_before_lineup'] = own_record >= 0 and lineup > own_record and rows[-1].get('imported_stored', False) and rows[-1].get('imported_old_refused', False)
                report['passed'] = report['passed'] and report['imported_pin_before_lineup']
            if args.switch_inactive_cleanup:
                own_record = next((index for index, hit in enumerate(hits) if hit['user'] == 8 and hit['path'] == '/api/accounts/users/me/app-data/synthetic8.aeriotv/'), -1)
                report['inactive_cleanup_before_lineup'] = own_record >= 0 and lineup > own_record and rows[-1].get('inactive_cleaned', False) and all(hit['user'] in [7, 8] for hit in hits)
                report['passed'] = report['passed'] and report['inactive_cleanup_before_lineup']
            if args.switch_target_retirement:
                target_paths = [hit['path'] for hit in hits if hit['user'] == 9]
                report['target_own_read_only'] = target_paths == ['/api/accounts/users/me/', '/api/accounts/users/me/', '/api/accounts/users/me/app-data/', '/api/accounts/users/me/app-data/synthetic9.aeriotv/']
                report['passed'] = report['passed'] and report['target_own_read_only'] and rows[-1].get('target_retired', False)
        if args.switch_authority_race:
            target_paths = [hit['path'] for hit in hits if hit['user'] == 8]
            report['target_pre_lineup_only'] = target_paths == ['/api/accounts/users/me/', '/api/accounts/users/me/', '/api/accounts/users/me/app-data/', '/api/accounts/users/me/']
            report['passed'] = result.returncode == 0 and len(rows) == 1 and rows[0].get('authority_race_refused', False) and report['target_pre_lineup_only'] and fixture_state.get('authority_target_me') == 3 and all(not hit['rejected'] for hit in hits)
        if args.switch_writer:
            after = hits[report.get('writer_request_boundary', len(hits)):]
            expected = [('GET', '/api/accounts/users/me/'), ('GET', '/api/accounts/users/me/app-data/'), ('GET', '/api/accounts/users/me/app-data/synthetic8.aeriotv/'), ('PUT', '/api/accounts/users/me/app-data/synthetic8.aeriotv/')]
            report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == expected and all(hit['user'] == 8 for hit in after)
            if args.writer_mode in ['flush', 'flush-import-pin', 'flush-own-retirement']:
                prefix = expected
                if args.writer_mode == 'flush-import-pin':
                    prefix = expected[:3] + expected
                if args.writer_mode == 'flush-own-retirement':
                    prefix = expected[:3]
                incoming = after[len(prefix):]
                roster = next((i for i, hit in enumerate(incoming) if hit['path'] == '/api/accounts/users/me/app-data/'), -1)
                lineup = next((i for i, hit in enumerate(incoming) if hit['path'].startswith('/api/channels/channels/summary/')), -1)
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after[:len(prefix)]] == prefix and all(hit['user'] == 8 for hit in after[:len(prefix)]) and bool(incoming) and all(hit['user'] == 7 for hit in incoming) and roster >= 0 and lineup > roster
            if args.writer_mode in ['flush-failed', 'flush-cancel']:
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after[:4]] == expected and all(hit['user'] == 8 for hit in after) and all(hit['path'].startswith('/api/epg/grid/?') and hit.get('method', 'GET') == 'GET' for hit in after[4:])
            if args.writer_mode == 'flush-authority':
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == expected[:1] and after[0]['user'] == 8
            report['writer_body_ok'] = fixture_state.get('writer_body_ok', False)
            report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('writer', False) and report['writer_own_request_order'] and report['writer_body_ok']
            if args.writer_mode == 'flush-authority':
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('writer', False) and report['writer_own_request_order'] and rows[-1].get('authority_covered', False)
            if args.writer_mode == 'flush-own-retirement':
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('own_retired', False) and report['writer_own_request_order'] and not any(hit.get('method') == 'PUT' for hit in after)
                if args.baseline_readiness:
                    report['passed'] = report['passed'] and baseline_retirement_consent_valid(report['baseline_retirement_consent'])
            if args.writer_mode in ['create-legacy', 'create-proxy404']:
                expected_reads = expected[:2] if args.writer_mode == 'create-legacy' else expected[:3]
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == expected_reads and all(hit['user'] == 8 for hit in after)
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('writer', False) and report['writer_own_request_order'] and not any(hit.get('method') == 'PUT' for hit in after)
            if args.writer_mode in ['schedule', 'schedule-too-large']:
                sequence = expected[:3] + expected + expected[:3] * 3
                if args.writer_mode == 'schedule-too-large':
                    sequence = expected[:3] + expected + expected[:3]
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == sequence and all(hit['user'] == 8 for hit in after)
                elapsed = fixture_state.get('schedule_put_at', 0) - fixture_state.get('schedule_dirty_at', 0)
                report['schedule_dirty_to_put_seconds'] = elapsed
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('scheduled', False) and report['writer_own_request_order'] and report['writer_body_ok'] and elapsed >= 1
            if args.writer_mode == 'schedule-signin':
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == expected[:2] and all(hit['user'] == 8 for hit in after)
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('scheduled', False) and report['writer_own_request_order']
            if args.writer_mode == 'unchanged':
                sequence = expected + expected[:3] * 2
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == sequence and all(hit['user'] == 8 for hit in after)
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('writer', False) and report['writer_own_request_order'] and report['writer_body_ok']
            if args.writer_mode == 'controls':
                report['writer_own_request_order'] = [(hit.get('method', 'GET'), hit['path']) for hit in after] == expected[:3] and all(hit['user'] == 8 for hit in after)
                events = report.get('controls_events', [])
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('controls', False) and report['writer_own_request_order'] and len(events) == 5 and all(row.get('ready', row.get('valid', False)) for row in events) and report.get('controls_pre_close_requests') == [[], [], [], []] and report.get('controls_key_statuses') == [200] * 7 and report.get('controls_screenshot', False)
            if args.writer_mode == 'controls-restore':
                cold = hits[report.get('controls_cold_boundary', len(hits)):]
                own_roster = next((i for i, hit in enumerate(cold) if hit['path'] == '/api/accounts/users/me/app-data/synthetic8.aeriotv/'), -1)
                own_lineup = next((i for i, hit in enumerate(cold) if hit['path'].startswith('/api/channels/channels/summary/')), -1)
                report['writer_own_request_order'] = bool(cold) and all(hit['user'] == 8 and hit.get('method', 'GET') == 'GET' for hit in cold) and own_roster >= 0 and own_lineup > own_roster
                events = report.get('controls_events', [])
                report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('cold_restored', False) and report['writer_own_request_order'] and report.get('controls_cold_ready', False) and report.get('controls_cold_relaunched', False) and len(events) == 3 and all(row.get('ready', row.get('valid', False)) for row in events) and report.get('controls_pre_close_requests') == [[], [], []] and report.get('controls_key_statuses') == [200] * 3 and report.get('controls_screenshot', False)
            if args.writer_mode not in ['direct', 'unchanged'] and not args.writer_mode.startswith(('create', 'schedule', 'controls')):
                report['passed'] = report['passed'] and report.get('writer_target_pin_ready', False) and report.get('writer_pre_pin_requests') == [] and report.get('writer_source_admitted', False) and rows[-1].get('flush', False)
            if args.writer_mode == 'flush-import-pin':
                before_pin = report.get('writer_before_import_pin', [])
                report['passed'] = report['passed'] and report.get('writer_import_pin_ready', False) and report.get('writer_import_old_refused', False) and report.get('writer_after_old_import_pin') == before_pin and [(hit.get('method', 'GET'), hit['path']) for hit in before_pin] == expected[:3] and all(hit['user'] == 8 for hit in before_pin)
            if args.writer_mode in ['flush-failed', 'flush-cancel']:
                report['passed'] = report['passed'] and rows[-1].get('pending_retained', False)
            if args.writer_mode == 'flush-cancel':
                report['writer_cancel_activity'] = fixture_state.get('writer_cancel_activity')
                report['writer_cancel_sent'] = fixture_state.get('writer_cancel_sent', False)
                report['writer_cancel_query_ms'] = fixture_state.get('writer_cancel_query_ms')
                report['writer_cancel_elapsed_ms'] = fixture_state.get('writer_cancel_elapsed_ms')
                report['writer_cancel_status'] = fixture_state.get('writer_cancel_status')
                report['writer_cancel_error'] = fixture_state.get('writer_cancel_error')
                report['passed'] = report['passed'] and fixture_state.get('writer_cancel_sent', False) and any(row.get('key') == 'back' for row in report['switch_key_events'])
        if args.switch_active_retirement:
            source_paths = [hit['path'] for hit in hits if hit['user'] == 9]
            boundary = next((index for index, hit in enumerate(hits) if hit['user'] == 9 and hit['path'] == '/api/accounts/users/me/app-data/synthetic9.aeriotv/'), -1)
            after = hits[boundary + 1:] if boundary >= 0 else []
            own_roster = next((index for index, hit in enumerate(after) if hit['user'] == 7 and hit['path'] == '/api/accounts/users/me/app-data/'), -1)
            own_lineup = next((index for index, hit in enumerate(after) if hit['user'] == 7 and hit['path'].startswith('/api/channels/channels/summary/')), -1)
            default_requests_ok = own_roster >= 0 and own_lineup > own_roster and all(hit['user'] == 7 for hit in after)
            if args.active_default_mode not in ['usable', 'cold', 'simultaneous', 'import-pin']:
                default_requests_ok = not after
            report['system_default_request_order'] = source_paths == ['/api/accounts/users/me/', '/api/accounts/users/me/', '/api/accounts/users/me/app-data/', '/api/accounts/users/me/app-data/synthetic9.aeriotv/'] and boundary >= 0 and default_requests_ok
            report['passed'] = result.returncode == 0 and len(rows) == 3 and rows[-1].get('active_retired', False) and report['system_default_request_order']
            if args.active_default_mode == 'cold':
                report['passed'] = report['passed'] and report.get('cold_relaunched', False) and report.get('cold_pre_pin_requests') == [] and report.get('cold_old_pin_refused', False) and report.get('cold_old_pin_requests') == [] and rows[-1].get('cold_recovered', False)
            if args.active_default_mode == 'held':
                refused = [hit for hit in hits if hit['rejected']]
                report['passed'] = report['passed'] and report['default_rejection_ready'] and len(refused) == 1 and refused[0]['user'] == 7 and refused[0]['path'] == '/api/accounts/users/me/'
        if args.child_settings:
            report['passed'] = result.returncode == 0 and len(rows) == 5 and all(rows[4].get(key) for key in ['guide_restricted', 'restricted', 'forged', 'protected', 'management', 'cancelled', 'preserved']) and rows[2].get('title') == 'Enter a PIN from an Admin or Standard profile' and report.get('screenshot', False)
        if args.cold_restore:
            expected = 8 if args.cold_restore == 'remembered' else 7
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and len(rows) == 1 and rows[0].get('passed') and bool(hits) and all(hit['user'] == expected for hit in hits) and any(hit['path'] == '/api/accounts/users/me/app-data/' for hit in hits)
        if args.default_filter:
            filters = [hit for hit in hits if hit['path'].split('?', 1)[0] == '/api/channels/profiles/']
            report['default_filter'] = len(filters) >= 2 and all(hit['user'] == 7 for hit in filters)
            report['passed'] = report['passed'] and report['default_filter']
        if args.assignment_refresh:
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and len(rows) == 2 and rows[0].get('own') and rows[1].get('passed') and bool(hits) and all(hit['user'] == 8 for hit in hits)
            if args.manual_recording:
                posts = [hit for hit in hits if hit.get('method') == 'POST']
                report['recording_replied'] = fixture_state.get('recording_replied')
                changed = args.manual_mode == 'changed'
                settled = [row for row in rows if row.get('kind') == 'record-settled']
                report['passed'] = result.returncode == 0 and rows[-1].get('passed') and len(settled) == 1 and settled[0].get('confirmed') and settled[0].get('operation_only') is changed and settled[0].get('retired') is changed and len(posts) == 1 and fixture_state.get('recording_replied') is True and all(hit['user'] == 8 for hit in hits)
        if args.favorite_retention:
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and bool(hits) and all(hit['user'] == 8 and hit.get('method', 'GET') == 'GET' for hit in hits) and any(row.get('kind') == 'favorite-edit' and row.get('retained') for row in rows) and any(row.get('kind') == 'favorite-returned' and row.get('passed') for row in rows)
        if args.switch_recording:
            report['requests'] = hits
            report['recording_replied'] = fixture_state.get('recording_replied')
            posts = [hit for hit in hits if hit.get('method') == 'POST']
            settled = [row for row in rows if row.get('kind') == 'record-settled']
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and len(posts) == 1 and posts[0]['user'] == 8 and fixture_state.get('recording_replied') is True and len(settled) == 1 and all(settled[0].get(key) is True for key in ['confirmed', 'operation_only', 'retired']) and all(hit['user'] in [7, 8] for hit in hits)
            if args.switch_recording == 'commit':
                report['passed'] = report['passed'] and rows[-1].get('other_visited') is True and any(row.get('kind') == 'record-withheld' and row.get('passed') for row in rows)
            else:
                report['passed'] = report['passed'] and report.get('back_count') == 1 and rows[-1].get('other_visited') is False
                if args.switch_recording == 'cancel':
                    report['passed'] = report['passed'] and fixture_state.get('switch_auth_delayed') is True
                else:
                    report['passed'] = report['passed'] and all(hit['user'] == 8 for hit in hits) and any(row.get('kind') == 'record-covered' and row.get('passed') for row in rows)
        if args.child_escape:
            rejected = [hit for hit in hits if hit['rejected']]
            delayed = [hit for hit in hits if hit['delayed']]
            boundary = fixture_state.get('child_request_boundary')
            report['no_child_requests'] = boundary is not None and all(hit['user'] == 7 for hit in hits[boundary:])
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and report['no_child_requests'] and len(rejected) == 1 and rejected[0]['path'] == '/api/accounts/users/me/' and len(delayed) == 1 and delayed[0]['path'] == '/api/accounts/users/me/'
            if args.switch_roster:
                after = hits[boundary:] if boundary is not None else []
                own_roster = next((index for index, hit in enumerate(after) if hit['user'] == 7 and hit['path'] == '/api/accounts/users/me/app-data/'), -1)
                own_lineup = next((index for index, hit in enumerate(after) if hit['user'] == 7 and hit['path'].startswith('/api/channels/channels/summary/')), -1)
                report['own_roster_before_lineup'] = own_roster >= 0 and own_lineup > own_roster
                report['passed'] = report['passed'] and report['own_roster_before_lineup'] and rows[-1].get('pending_refused', False)
        if args.child_launch:
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and len(rows) == 4 and rows[0].get('covered') and all(rows[1].get(key) for key in ['passed', 'covered', 'own_pin_then_adult', 'no_scope', 'no_autoplay']) and rows[-1].get('exited') and not hits
        if args.child_available:
            expected = 7 if args.child_available.startswith('default') else 8
            paths = [hit['path'] for hit in hits]
            roster = f'/api/accounts/users/me/app-data/synthetic{expected}.aeriotv/'
            lineup = next((index for index, path in enumerate(paths) if path.startswith('/api/channels/channels/summary/')), -1)
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and bool(hits) and all(hit['user'] == expected for hit in hits) and roster in paths and lineup > paths.index(roster)
            if args.child_available.endswith('-pin'):
                report['passed'] = report['passed'] and report.get('pre_pin_requests') == []
        if args.child_retry:
            expected = 7 if args.child_retry.startswith('default') else 8
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and rows[-1].get('passed') and any(row.get('kind') == 'retry-cancelled' and row.get('passed') for row in rows) and all(hit['user'] == expected for hit in hits) and fixture_state.get('child_auth_attempts', 0) >= 3
        if args.child_rejected:
            expected = 7 if args.child_rejected.startswith('default') else 8
            safe = [row for row in rows if row.get('kind') == 'rejection-safe']
            boundary = fixture_state.get('child_unavailable_boundary')
            rejected = [hit for hit in hits if hit['rejected']]
            report['no_unavailable_requests'] = boundary is not None and not hits[boundary:]
            report['requests'] = hits
            report['passed'] = result.returncode == 0 and len(safe) == 1 and safe[0].get('passed') and rows[-1].get('exited') and bool(hits) and all(hit['user'] == expected for hit in hits) and bool(rejected) and rejected[0]['path'] == '/api/accounts/users/me/' and report['no_unavailable_requests'] and report.get('back_count') == (2 if args.child_rejected.startswith('default') else 1)
            if args.child_rejected.endswith('-pin'):
                report['passed'] = report['passed'] and report.get('pre_pin_requests') == []
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
            if args.favorite_retention:
                name = 'profile-favorite-retention-native.json'
            if args.switch_recording:
                name = f'profile-switch-recording-{args.switch_recording}-native.json'
            if args.cold_restore:
                name = f'profile-cold-{args.cold_restore}-native.json'
            if args.switch:
                name = 'profile-switch-pin-native.json' if args.switch_pin else 'profile-switch-native.json'
                if args.cancel_pin:
                    name = 'profile-switch-pin-cancel-native.json'
                if args.reject_active:
                    name = 'profile-switch-active-reject-native.json'
                if args.remember_off:
                    name = 'profile-switch-memory-native.json'
                if args.reconnect:
                    name = 'profile-reconnect-memory-native.json' if args.remember_off else 'profile-reconnect-saved-native.json'
            if args.child_settings:
                name = 'profile-child-settings-native.json'
            if args.default_filter:
                name = name.replace('-native.json', '-default-filter-native.json')
            if args.assignment_refresh:
                name = 'profile-assignment-refresh-native.json'
                if args.manual_refresh:
                    name = f'profile-manual-refresh-{args.manual_mode}-native.json'
                    if args.manual_recording:
                        name = f'profile-manual-recording-refresh-{args.manual_mode}-native.json'
            if args.child_escape:
                name = 'profile-child-escape-native.json'
            if args.child_launch:
                name = 'profile-child-launch-native.json'
            if args.child_available:
                name = f'profile-child-available-{args.child_available}-native.json'
            if args.child_retry:
                name = f'profile-child-retry-{args.child_retry}-native.json'
            if args.child_rejected:
                name = f'profile-child-rejected-prompt-{args.child_rejected}-native.json'
            if args.switch_roster:
                name = name.replace('-native.json', '-early-roster-native.json')
            if args.switch_import_pin:
                name = name.replace('-native.json', '-imported-pin-native.json')
            if args.switch_inactive_cleanup:
                name = name.replace('-native.json', '-inactive-cleanup-native.json')
            if args.switch_target_retirement:
                name = name.replace('-native.json', '-target-retirement-native.json')
            if args.switch_authority_race:
                name = name.replace('-native.json', '-authority-race-native.json')
            if args.switch_active_retirement:
                name = name.replace('-native.json', f'-active-retirement-{args.active_default_mode}-native.json')
            if args.switch_writer:
                name = name.replace('-native.json', f'-writer-{args.writer_mode}-native.json')
            if args.baseline_readiness:
                name = name.replace('-native.json', '-baseline-readiness-native.json')
            (ROOT / 'out' / name).write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps({key: report.get(key) for key in ['passed', 'cleaned', 'restored']}), flush=True)
            if not report['restored']:
                raise RuntimeError('Exact prior app restore failed')


if __name__ == '__main__':
    main()
