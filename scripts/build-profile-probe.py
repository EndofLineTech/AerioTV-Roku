"""Build an isolated synthetic profile primitive probe; never install it."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def registry_fixtures():
    cases = []
    for count in [1, 2, 4, 6, 8]:
        values = {}
        accounts = {}
        slots = []
        for slot in range(4):
            slot_id = f'fixture-slot-{slot}'
            rows = []
            for index in range(count):
                ident = f'00000000-0000-4000-8000-{slot * 100 + index:012d}'
                row = {'id': ident, 'playlistId': slot_id, 'userId': slot * 100 + index + 1,
                       'username': f'fixture-{slot}-{index}', 'displayName': f'Synthetic profile {index}',
                       'isDefault': index == 0, 'role': 'user', 'userLevel': 1,
                       'order': index, 'createdAt': 1794416000, 'updatedAt': 1794416400,
                       'isStaff': False, 'isSuperuser': False, 'addOrigin': 'plain', 'addressHeld': False,
                       'avatar': {'icon': 'star', 'color': 'teal'},
                       'pinType': 'numbers', 'pinHash': 'a' * 64, 'pinSalt': 'b' * 32}
                row['preferenceAnchor'] = f'https://old.example.test|{row["userId"]}|{slot_id}'
                rows.append(row)
                # Deterministic public test data, with key-like compression
                # characteristics. These bytes are never used for networking.
                key = base64.b64encode(hashlib.sha512(ident.encode()).digest()).decode()[:54]
                key_name = f'connKey_{slot_id}' if index == 0 else f'profKey_{slot_id}_{ident}'
                values[key_name] = key
                accounts[f'account_fixture_{slot}_{index}'] = {
                    'favoriteIds': [str(n) for n in range(20)], 'recent': [],
                    'startupBehavior': 'guide', 'guide': {'showLogos': True},
                }
            identity = {'userId': rows[0]['userId'], 'username': rows[0]['username']}
            for row in rows[1:]:
                row['defaultIdentityTag'] = dict(identity)
                row['addressHeld'] = True
            values[f'userProfilesV1_{slot_id}'] = json.dumps({'schema': 1, 'playlistId': slot_id,
                'profiles': rows, 'active': rows[0]['id'], 'askAtLaunch': False, 'removed': [], 'pendingRoster': False,
                'knownDefault': identity, 'addressChangeSnapshot': dict(identity)})
            slots.append({'id': slot_id, 'name': 'Synthetic slot', 'provider': 'dispatcharr',
                          'url': 'https://example.test', 'remember': True})
        values['connectionsV1'] = json.dumps({'schema': 1, 'selected': slots[0]['id'], 'entries': slots})
        preferences = {'schema': 1, 'device': {}, 'accounts': accounts, 'fixturePadding': ''}
        # Fill the uncompressed 24KB preference ceiling with high-entropy public
        # synthetic bytes, rather than unrealistically compressible repeated 'x'.
        padding_size = max(0, 24000 - len(json.dumps(preferences).encode()))
        padding = ''.join(base64.b64encode(hashlib.sha512(f'padding-{i}'.encode()).digest()).decode()
                          for i in range(400))
        preferences['fixturePadding'] = padding[:padding_size]
        values['settingsV1'] = json.dumps(preferences)
        cases.append({'profilesPerSlot': count, 'values': values})
    return cases


def build(output, base_url, registry=False, model_store=False):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    fixture = {
        'schemaVersion': 3, 'deviceId': '6F1C2A9E-4B7D-4C1E-9E1A-0D2B8C3F5A11', 'platform': 'android',
        'appVersion': '0.5.14', 'updatedAt': '2026-11-11T18:00:00Z',
        'categories': {
            'profiles': {'updatedAt': '2026-11-11T18:00:00Z', 'data': {
                'rows': [
                    [3, 'alice', 'Alice 🦉', 'numbers', '1e9d1c5f6cb5e79f17f4e38816915772a54116ba66a05f9521d262c5718db5c1', '000102030405060708090a0b0c0d0e0f', 'admin', 1794416400, {'icon': 'star', 'color': 'teal'}, 0, {'FutureCase': True}],
                    [7, 'sam', 'Sam', 'directions', '3ea9be0818449911ef5780edfe9d3a36b030efa593f1116922e88e687f04915f', 'b81e4c2a9d07f3e1a5c6d8e90f1b2c3d', 'child', 1794416700, {'icon': 'paw'}, 1],
                    [9, 'kim', 'kim', 'none', '', '', 'user', 1794303000, {}, 2],
                ], 'removed': [['lee', 1794420000, 12]]}},
            'favorites': {'updatedAt': '2026-11-11T17:30:00Z', 'data': {'ids': [1042, 77, 903]}},
            'syncProviders': {'updatedAt': '2026-11-11T18:00:00Z',
                              'data': {'updatedAt': 1761700000000}},
            'settings': {'data': {'v': {'selectedTheme': 'Midnight'}, 'tv': {'textScale': 1.3}, 'mobile': {'textScale': 1.0}, 'FutureNull': None}},
        },
        'FutureCase': {'MixedCase': [True, None, 1, 1.0],
                       'preciseDouble': 1.234567891234567, 'exponentDouble': 1.234567891234567e-30,
                       'largeInteger': 1234567890123},
    }
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
        package.writestr('manifest', 'title=Aerio Profile Primitive Probe\n'
                          'major_version=0\nminor_version=0\nbuild_version=1\n'
                          'ui_resolutions=fhd\nrsg_version=1.3\n')
        package.write(ROOT / 'tests/native/UserProfileProbe.brs', 'source/Main.brs')
        package.write(ROOT / 'tests/native/UserProfileRegistryProbe.brs', 'source/UserProfileRegistryProbe.brs')
        package.write(ROOT / 'source/DispatcharrSyncKey.brs', 'source/DispatcharrSyncKey.brs')
        package.write(ROOT / 'source/DispatcharrSyncRoster.brs', 'source/DispatcharrSyncRoster.brs')
        package.write(ROOT / 'source/DispatcharrSyncEnvelope.brs', 'source/DispatcharrSyncEnvelope.brs')
        package.write(ROOT / 'source/DispatcharrSyncMerge.brs', 'source/DispatcharrSyncMerge.brs')
        package.write(ROOT / 'source/DispatcharrSyncPullStore.brs', 'source/DispatcharrSyncPullStore.brs')
        package.write(ROOT / 'source/UserProfilePinPolicy.brs', 'source/UserProfilePinPolicy.brs')
        package.write(ROOT / 'source/UserProfileCredential.brs', 'source/UserProfileCredential.brs')
        package.write(ROOT / 'source/UserProfileManagementPolicy.brs', 'source/UserProfileManagementPolicy.brs')
        package.write(ROOT / 'source/UserProfileSwitch.brs', 'source/UserProfileSwitch.brs')
        package.write(ROOT / 'source/UserProfileOwnSignIn.brs', 'source/UserProfileOwnSignIn.brs')
        package.write(ROOT / 'source/UserProfileAddressPolicy.brs', 'source/UserProfileAddressPolicy.brs')
        package.write(ROOT / 'source/UserProfileAddressStore.brs', 'source/UserProfileAddressStore.brs')
        package.write(ROOT / 'source/UserProfileChildAccess.brs', 'source/UserProfileChildAccess.brs')
        package.write(ROOT / 'source/SettingsModel.brs', 'source/SettingsModel.brs')
        package.write(ROOT / 'source/GuideModel.brs', 'source/GuideModel.brs')
        package.write(ROOT / 'tests/native/PhoneSetupProbe.xml', 'components/PhoneSetupProbe.xml')
        for name in ['DispatcharrModel', 'HttpPolicy', 'HttpTransport', 'DispatcharrHttp', 'RequestGateClient', 'RequestGateModel', 'StrictJson', 'UserProfilePin', 'UserProfileModel', 'UserProfileStore', 'UserProfileAvatar', 'UserProfileLifecycle', 'UserProfileCleanup', 'UserProfileScope', 'UserProfileScopeStore', 'PreferenceModel', 'ConnectionStoreModel', 'RemoteMapModel', 'GuideSettingsModel', 'ReminderModel']:
            package.write(ROOT / f'source/{name}.brs', f'source/{name}.brs')
        if model_store:
            sync_checks = (ROOT / 'tests/DispatcharrSyncKey.test.brs').read_text().split('sub check(', 1)[0]
            sync_checks = sync_checks.replace('sub main()', 'sub runDispatcharrSyncKeyChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/DispatcharrSyncKeyProbeChecks.brs', sync_checks)
            roster_checks = (ROOT / 'tests/DispatcharrSyncRoster.test.brs').read_text().split('sub check(', 1)[0]
            roster_checks = roster_checks.replace('sub main()', 'sub runDispatcharrSyncRosterChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/DispatcharrSyncRosterProbeChecks.brs', roster_checks)
            envelope_checks = (ROOT / 'tests/DispatcharrSyncEnvelope.test.brs').read_text().split('sub check(', 1)[0]
            envelope_checks = envelope_checks.replace('sub main()', 'sub runDispatcharrSyncEnvelopeChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/DispatcharrSyncEnvelopeProbeChecks.brs', envelope_checks)
            merge_checks = (ROOT / 'tests/DispatcharrSyncMerge.test.brs').read_text().split('sub check(', 1)[0]
            merge_checks = merge_checks.replace('sub main()', 'sub runDispatcharrSyncMergeChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/DispatcharrSyncMergeProbeChecks.brs', merge_checks)
            pull_checks = (ROOT / 'tests/DispatcharrSyncPullStore.test.brs').read_text().split('sub check(', 1)[0]
            pull_checks = pull_checks.replace('sub main()', 'sub runDispatcharrSyncPullStoreChecks()').replace('check(', 'profileAssert(')
            pull_checks = pull_checks.replace('m.profilePreferenceDecoder = function(raw as string) as dynamic\n        return ParseJson(raw)\n    end function', 'm.profilePreferenceDecoder = invalid')
            pull_checks = pull_checks.replace('    print "ALL TESTS PASSED"', '''    store.active = a.id
    registry = syncPullRegistry(connection, store, "")
    kept = ["https://example.test|7|slot-a", "https://example.test|8|slot-b"]
    profileSeedPrecisionSettings(registry, kept)
    result = commitDispatcharrRosterPull(registry, connection, store, data, true, 300, scope, scope)
    profileAssert(result.ok and profilePrecisionSettingsMatch(registry, kept), "roster tombstone cleanup retains untouched root and foreign settings precision and future known values")
    print "ALL TESTS PASSED"''')
            package.writestr('source/DispatcharrSyncPullStoreProbeChecks.brs', pull_checks)
            pin_checks = (ROOT / 'tests/UserProfilePinPolicy.test.brs').read_text().split('sub check(', 1)[0]
            pin_checks = pin_checks.replace('sub main()', 'sub runUserProfilePinPolicyChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/UserProfilePinPolicyProbeChecks.brs', pin_checks)
            credential_checks = (ROOT / 'tests/UserProfileCredential.test.brs').read_text().split('sub check(', 1)[0]
            credential_checks = credential_checks.replace('sub main()', 'sub runUserProfileCredentialChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/UserProfileCredentialProbeChecks.brs', credential_checks)
            management_checks = (ROOT / 'tests/UserProfileManagementPolicy.test.brs').read_text().split('sub check(', 1)[0]
            management_checks = management_checks.replace('sub main()', 'sub runUserProfileManagementPolicyChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/UserProfileManagementPolicyProbeChecks.brs', management_checks)
            switch_checks = (ROOT / 'tests/UserProfileSwitch.test.brs').read_text().split('sub check(', 1)[0]
            switch_checks = switch_checks.replace('sub main()', 'sub runUserProfileSwitchChecks()').replace('check(', 'profileAssert(')
            switch_checks = switch_checks.replace('m.profilePreferenceDecoder = function(raw as string) as dynamic\n        return ParseJson(raw)\n    end function', 'm.profilePreferenceDecoder = invalid')
            package.writestr('source/UserProfileSwitchProbeChecks.brs', switch_checks)
            own_login_checks = (ROOT / 'tests/UserProfileOwnSignIn.test.brs').read_text().split('sub check(', 1)[0]
            own_login_checks = own_login_checks.replace('sub main()', 'sub runUserProfileOwnSignInChecks()').replace('check(', 'profileAssert(')
            own_login_checks = own_login_checks.replace('m.profileOwnSignInSettingsDecoder = function(raw as string) as dynamic\n        return ParseJson(raw)\n    end function', 'm.profileOwnSignInSettingsDecoder = invalid')
            own_login_checks = own_login_checks.replace('    print "ALL TESTS PASSED"', '''    precisionStore = copyJson(store)
    precisionStore.profiles[1] = setCanonicalPreference(precisionStore.profiles[1], "preferenceAnchor", "https://old.test|8|slot-a")
    registry = ownSignInRegistry(entry, precisionStore)
    rawSettings = registry.read("settingsV1")
    rawSettings = left(rawSettings, len(rawSettings) - 1) + "," + chr(34) + "futureDouble" + chr(34) + ":1.2345678901234567," + chr(34) + "futureIntegralDouble" + chr(34) + ":3.0}"
    precisionSeed = ParseJson(rawSettings, "d")
    precisionSeed.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))]["futureDouble"] = ParseJson("1.2345678901234567", "d")
    precisionSeed.accounts[preferenceScope("https://old.test|8|slot-a")] = precisionSeed.accounts[preferenceScope(connectionPreferenceIdentity(entry, "8"))]
    precisionSeed.accounts.delete(preferenceScope(connectionPreferenceIdentity(entry, "8")))
    precisionSeedText = strictJsonEncode(precisionSeed)
    registry.write("settingsV1", precisionSeedText.text)
    saved = commitUserProfileOwnSignIn(registry, entry, precisionStore, b.id, result, 100, nonce, nonce)
    precisionSettings = ParseJson(registry.read("settingsV1"), "d")
    profileAssert(saved.ok and precisionSettings["futureDouble"] = ParseJson("1.2345678901234567", "d"), "own user-ID migration round-trips unknown binary64 settings without shortening")
    numericKind = type(precisionSettings["futureIntegralDouble"])
    profileAssert(numericKind = "Double" or numericKind = "roDouble" or numericKind = "Float" or numericKind = "roFloat", "own user-ID migration preserves unknown integral-floating JSON number kind")
    actorScope = userProfileSessionScope(entry, a.id, 7, "own-recovery-actor-generation", nonce)
    actorPreferences = normalizeAccountPreferences(precisionSettings.accounts[preferenceScope(connectionPreferenceIdentity(entry, "7"))])
    actorSaved = commitUserProfilePreferences(registry, precisionSettings, actorPreferences, normalizeDevicePreferences(precisionSettings.device), actorScope, actorScope)
    afterActor = ParseJson(registry.read("settingsV1"), "d")
    profileAssert(actorSaved.ok and afterActor["futureDouble"] = ParseJson("1.2345678901234567", "d") and afterActor.accounts[preferenceScope(connectionPreferenceIdentity(entry, "88"))]["futureDouble"] = ParseJson("1.2345678901234567", "d"), "subsequent outgoing preference write preserves migrated foreign-profile binary64 settings")
    actorKey = preferenceScope(actorScope.preferenceIdentity)
    afterActor.accounts[actorKey]["futureDouble"] = ParseJson("1.2345678901234567", "d")
    afterActor.accounts[actorKey]["profileSettings"]["FutureCase"] = {nested: [ParseJson("1.2345678901234567", "d"), ParseJson("3.0", "d")]}
    restartSeed = strictJsonEncode(afterActor)
    registry.write("settingsV1", restartSeed.text)
    cold = loadPreferenceStore(registry, true)
    coldPreferences = accountPreferences(cold, actorScope.preferenceIdentity)
    coldPreferences = recordWatched(coldPreferences, "new-current-channel")
    coldSaved = commitUserProfilePreferences(registry, cold, coldPreferences, normalizeDevicePreferences(cold.device), actorScope, actorScope)
    afterCold = ParseJson(registry.read("settingsV1"), "d")
    profileAssert(coldSaved.ok and afterCold["futureDouble"] = ParseJson("1.2345678901234567", "d") and afterCold.accounts[actorKey]["futureDouble"] = ParseJson("1.2345678901234567", "d") and afterCold.accounts[actorKey]["profileSettings"]["FutureCase"].nested[0] = ParseJson("1.2345678901234567", "d") and afterCold.accounts[preferenceScope(connectionPreferenceIdentity(entry, "88"))]["futureDouble"] = ParseJson("1.2345678901234567", "d"), "cold load and active-account normalization retain root own nested and foreign binary64 extensions")
    registry.write("settingsV1", restartSeed.text)
    switchVerified = {ok: true, apiKey: "synthetic-switch-key", verifiedUser: {id: 88, username: "Bob", user_level: 1}, accountId: "88", accountUsername: "Bob", channels: [], groups: [], profileId: "", channelProfileIds: [], generation: "strict-switch"}
    switchPin = {slot: "slot-a", id: b.id, pinType: b.pinType, pinHash: b.pinHash, pinSalt: b.pinSalt}
    switched = commitUserProfileSwitch(registry, entry, loadUserProfileStore(registry, "slot-a"), b.id, switchVerified, switchPin, invalid, "", nonce, nonce, actorScope, actorScope)
    afterSwitch = ParseJson(registry.read("settingsV1"), "d")
    profileAssert(switched.ok and afterSwitch["futureDouble"] = ParseJson("1.2345678901234567", "d") and afterSwitch.accounts[actorKey]["profileSettings"]["FutureCase"].nested[0] = ParseJson("1.2345678901234567", "d") and afterSwitch.accounts[preferenceScope(connectionPreferenceIdentity(entry, "88"))]["futureDouble"] = ParseJson("1.2345678901234567", "d"), "profile switch retains precision-parsed own and outgoing settings extensions")
    distinctCase = ParseJson("{" + chr(34) + "FutureCase" + chr(34) + ":1," + chr(34) + "futurecase" + chr(34) + ":2}", "d")
    distinctCopy = copyPreferenceValue(distinctCase)
    profileAssert(distinctCopy.count() = 2 and distinctCopy["FutureCase"] = 1 and distinctCopy["futurecase"] = 2, "settings structural copy preserves distinct case-sensitive extension keys")
    registry.write("settingsV1", restartSeed.text)
    legacySaved = savePreferenceStore(registry, loadPreferenceStore(registry, true))
    afterLegacy = ParseJson(registry.read("settingsV1"), "d")
    profileAssert(legacySaved and afterLegacy["futureDouble"] = ParseJson("1.2345678901234567", "d") and afterLegacy.accounts[actorKey]["futureDouble"] = ParseJson("1.2345678901234567", "d"), "legacy device-settings writer also preserves foreign profile precision")
    for each unreadable in ["", "not-json", FormatJson({schema: 2, device: {}, accounts: {}}), FormatJson({schema: 1, device: {}, accounts: {foreign: "preserve-unreadable"}})]
        registry.write("settingsV1", unreadable)
        readonlySettings = loadPreferenceStore(registry, true)
        profileAssert(readonlySettings.readOnly = true and registry.read("settingsV1") = unreadable, "strict settings cold load retains malformed or newer data without a writable empty fallback")
    end for
    print "ALL TESTS PASSED"''')
            package.writestr('source/UserProfileOwnSignInProbeChecks.brs', own_login_checks)
            child_checks = (ROOT / 'tests/UserProfileChildAccess.test.brs').read_text().split('sub check(', 1)[0]
            child_checks = child_checks.replace('sub main()', 'sub runUserProfileChildAccessChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/UserProfileChildAccessProbeChecks.brs', child_checks)
            settings_child_checks = (ROOT / 'tests/SettingsChildModel.test.brs').read_text().split('sub check(', 1)[0]
            settings_child_checks = settings_child_checks.replace('sub main()', 'sub runSettingsChildModelChecks()').replace('check(', 'profileAssert(')
            package.writestr('source/SettingsChildProbeChecks.brs', settings_child_checks)
            package.write(ROOT / 'components/UserProfileNavigation.brs', 'source/UserProfileNavigation.brs')
            package.write(ROOT / 'components/UserProfilePreferenceNavigation.brs', 'source/UserProfilePreferenceNavigation.brs')
            for name in ['UserProfileModel', 'UserProfileStore', 'UserProfileAvatar', 'UserProfileLifecycle', 'UserProfileForget', 'UserProfileNavigation', 'UserProfileRemoval', 'UserProfileScope', 'UserProfileScopeStore', 'UserProfilePreferenceNavigation', 'UserProfileAddressPolicy', 'UserProfileAddressStore']:
                source = (ROOT / f'tests/{name}.test.brs').read_text().split('sub check(', 1)[0]
                source = source.replace('sub main()', f'sub run{name}Checks()').replace('check(', 'profileAssert(')
                source = source.replace('m.profilePreferenceDecoder = function(raw as string) as dynamic\n        return ParseJson(raw)\n    end function', 'm.profilePreferenceDecoder = invalid')
                if name == 'UserProfileForget':
                    source = source.replace('    print "ALL TESTS PASSED"', '''    registry = forgetRegistry()
    before = normalizeConnectionStore(ParseJson(registry.read("connectionsV1")))
    kept = ["https://example.test|7|slot-b"]
    profileSeedPrecisionSettings(registry, kept)
    result = forgetUserProfileConnection(registry, before, "slot-a")
    profileAssert(result.ok and profilePrecisionSettingsMatch(registry, kept), "whole-slot Forget preserves foreign settings precision and future known values")
    print "ALL TESTS PASSED"''')
                if name == 'UserProfileRemoval':
                    source = source.replace('    print "ALL TESTS PASSED"', '''    resetRemovalFixture()
    kept = ["https://example.test|1|slot-a", "https://example.test|2|slot-b"]
    profileSeedPrecisionSettings(m.registry, kept)
    result = removeUserProfile(m.registry, m.connection, m.store, m.other.id, 200, "normal")
    profileAssert(result.ok and profilePrecisionSettingsMatch(m.registry, kept), "profile removal preserves outgoing and foreign settings precision and future known values")
    print "ALL TESTS PASSED"''')
                package.writestr(f'source/{name}ProbeChecks.brs', source)
        else:
            package.writestr('source/DispatcharrSyncKeyProbeChecks.brs', 'sub runDispatcharrSyncKeyChecks()\nend sub\n')
            package.writestr('source/DispatcharrSyncRosterProbeChecks.brs', 'sub runDispatcharrSyncRosterChecks()\nend sub\n')
            package.writestr('source/DispatcharrSyncEnvelopeProbeChecks.brs', 'sub runDispatcharrSyncEnvelopeChecks()\nend sub\n')
            package.writestr('source/DispatcharrSyncMergeProbeChecks.brs', 'sub runDispatcharrSyncMergeChecks()\nend sub\n')
            package.writestr('source/DispatcharrSyncPullStoreProbeChecks.brs', 'sub runDispatcharrSyncPullStoreChecks()\nend sub\n')
            package.writestr('source/UserProfilePinPolicyProbeChecks.brs', 'sub runUserProfilePinPolicyChecks()\nend sub\n')
            package.writestr('source/UserProfileCredentialProbeChecks.brs', 'sub runUserProfileCredentialChecks()\nend sub\n')
            package.writestr('source/UserProfileManagementPolicyProbeChecks.brs', 'sub runUserProfileManagementPolicyChecks()\nend sub\n')
            package.writestr('source/UserProfileSwitchProbeChecks.brs', 'sub runUserProfileSwitchChecks()\nend sub\n')
            package.writestr('source/UserProfileOwnSignInProbeChecks.brs', 'sub runUserProfileOwnSignInChecks()\nend sub\n')
            package.writestr('source/UserProfileAddressPolicyProbeChecks.brs', 'sub runUserProfileAddressPolicyChecks()\nend sub\n')
            package.writestr('source/UserProfileAddressStoreProbeChecks.brs', 'sub runUserProfileAddressStoreChecks()\nend sub\n')
            package.writestr('source/UserProfileChildAccessProbeChecks.brs', 'sub runUserProfileChildAccessChecks()\nend sub\n')
            package.writestr('source/SettingsChildProbeChecks.brs', 'sub runSettingsChildModelChecks()\nend sub\n')
            package.writestr('source/UserProfileModelProbeChecks.brs', 'sub runUserProfileModelChecks()\nend sub\nsub testProfileNativeNames()\nend sub\n')
            package.writestr('source/UserProfileStoreProbeChecks.brs', 'sub runUserProfileStoreChecks()\nend sub\nsub testProfileNativeStoreNames()\nend sub\n')
            package.writestr('source/UserProfileAvatarProbeChecks.brs', 'sub runUserProfileAvatarChecks()\nend sub\nsub testProfileNativeAvatar()\nend sub\n')
            package.writestr('source/UserProfileLifecycleProbeChecks.brs', 'sub runUserProfileLifecycleChecks()\nend sub\n')
            package.writestr('source/UserProfileForgetProbeChecks.brs', 'sub runUserProfileForgetChecks()\nend sub\n')
            package.writestr('source/UserProfileNavigationProbeChecks.brs', 'sub runUserProfileNavigationChecks()\nend sub\n')
            package.writestr('source/UserProfileRemovalProbeChecks.brs', 'sub runUserProfileRemovalChecks()\nend sub\n')
            package.writestr('source/UserProfileScopeProbeChecks.brs', 'sub runUserProfileScopeChecks()\nend sub\n')
            package.writestr('source/UserProfileScopeStoreProbeChecks.brs', 'sub runUserProfileScopeStoreChecks()\nend sub\n')
            package.writestr('source/UserProfilePreferenceNavigationProbeChecks.brs', 'sub runUserProfilePreferenceNavigationChecks()\nend sub\n')
        package.writestr('profile-probe-config.json', json.dumps({'baseUrl': base_url, 'registry': registry, 'modelStore': model_store}))
        package.writestr('profile-wire-fixture.json', json.dumps(fixture, ensure_ascii=False))
        package.writestr('profile-registry-fixtures.json', json.dumps(registry_fixtures()))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', required=True)
    args = parser.parse_args()
    print(build(ROOT / 'out/user-profile-probe.zip', args.base_url))
