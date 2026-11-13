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
            values[f'userProfilesV1_{slot_id}'] = json.dumps({'schema': 1, 'playlistId': slot_id,
                'profiles': rows, 'active': rows[0]['id'], 'askAtLaunch': False, 'removed': [], 'pendingRoster': False})
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
            package.write(ROOT / 'components/UserProfileNavigation.brs', 'source/UserProfileNavigation.brs')
            package.write(ROOT / 'components/UserProfilePreferenceNavigation.brs', 'source/UserProfilePreferenceNavigation.brs')
            for name in ['UserProfileModel', 'UserProfileStore', 'UserProfileAvatar', 'UserProfileLifecycle', 'UserProfileForget', 'UserProfileNavigation', 'UserProfileRemoval', 'UserProfileScope', 'UserProfileScopeStore', 'UserProfilePreferenceNavigation']:
                source = (ROOT / f'tests/{name}.test.brs').read_text().split('sub check(', 1)[0]
                source = source.replace('sub main()', f'sub run{name}Checks()').replace('check(', 'profileAssert(')
                package.writestr(f'source/{name}ProbeChecks.brs', source)
        else:
            package.writestr('source/DispatcharrSyncKeyProbeChecks.brs', 'sub runDispatcharrSyncKeyChecks()\nend sub\n')
            package.writestr('source/DispatcharrSyncRosterProbeChecks.brs', 'sub runDispatcharrSyncRosterChecks()\nend sub\n')
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
