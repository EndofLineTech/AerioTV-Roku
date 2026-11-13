"""Host coverage for fixture generation/isolation; never connects to a Roku."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import subprocess


class ProfileProbeTest(unittest.TestCase):
    def test_recovery_application_probe_replaces_the_only_application_registry_hook(self):
        path = Path(__file__).with_name('test-profile-recovery-native.py')
        spec = importlib.util.spec_from_file_location('recovery_probe', path)
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'm.registry = CreateObject("roRegistrySection", "AerioTV")\nm.status = userProfileGateMessage(profileGate)\n')
            output = Path(tmp) / 'probe.zip'
            probe.build(output, normal, 'SyntheticSection', 'http://127.0.0.1:1234')
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('"SyntheticSection"', source)
                self.assertIn('synthetic-never-send-key', source)
                self.assertIn('profile-recovery-probe.json', package.namelist())

    def test_connection_and_channel_profile_tasks_are_after_saved_profile_gate(self):
        root = Path(__file__).resolve().parent.parent
        scene = (root / 'components/AerioScene.brs').read_text()
        connect = scene.split('sub connectServer(', 1)[1].split('end sub', 1)[0]
        self.assertLess(connect.index('selectedUserProfileGate()'), connect.index('cancelProfileTask()'))
        self.assertLess(connect.index('selectedUserProfileGate()'), connect.index('"DispatcharrTask"'))
        complete = scene.split('sub completeConnection(', 1)[1].split('end sub', 1)[0]
        self.assertLess(complete.index('ensureConnectedUserProfile(result)'), complete.index('m.apiKey = result.apiKey'))
        navigation = (root / 'components/ConnectionNavigation.brs').read_text()
        permitted = navigation.split('sub openPermittedProfiles()', 1)[1].split('end sub', 1)[0]
        self.assertLess(permitted.index('selectedUserProfileGate()'), permitted.index('"ProfileTask"'))
        phone = (root / 'components/PhoneSetupNavigation.brs').read_text()
        verification = phone.split('sub startPhoneVerification()', 1)[1].split('end sub', 1)[0]
        self.assertLess(verification.index('selectedUserProfileGate()'), verification.index('CreateObject('))

    def test_optional_model_store_checks_use_shared_tests_and_private_section(self):
        path = Path(__file__).with_name('build-profile-probe.py')
        spec = importlib.util.spec_from_file_location('profile_builder', path)
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as tmp:
            output = builder.build(Path(tmp) / 'probe.zip', 'http://127.0.0.1:1234', model_store=True)
            with zipfile.ZipFile(output) as package:
                for name in ['UserProfileModel', 'UserProfileStore', 'UserProfileAvatar', 'UserProfileLifecycle', 'UserProfileForget', 'UserProfileNavigation', 'UserProfileRemoval']:
                    source = package.read(f'source/{name}ProbeChecks.brs').decode()
                    self.assertIn(f'sub run{name}Checks()', source)
                    self.assertIn('profileAssert(', source)
                    self.assertNotIn('roRegistry', source)
                probe = package.read('source/UserProfileRegistryProbe.brs').decode()
                self.assertNotIn('getSectionList', probe)
                self.assertIn('AerioProfileStoreProbe-', probe)

    def test_shipping_guard_rejects_profile_fixtures(self):
        result = subprocess.run(['node', '--input-type=module', '-e', '''
            import assert from 'node:assert/strict';
            import {assertPackageEntries} from './scripts/verify-package.mjs';
            const base = ['manifest', 'source/Main.brs', 'components/AerioScene.xml',
              'images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt'];
            for (const name of ['profile-probe-config.json', 'profile-wire-fixture.json', 'profile-registry-fixtures.json', 'profile-recovery-probe.json', 'components/UserProfileProbe.brs', 'source/UserProfileRegistryProbe.brs', 'components/UserProfileDialogProbe.brs', 'source/UserProfileModelProbeChecks.brs', 'source/UserProfileStoreProbeChecks.brs']) {
              assert.throws(() => assertPackageEntries([...base, name]), /probe/);
            }
        '''], cwd=Path(__file__).resolve().parent.parent, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_dialog_package_never_initializes_the_real_app(self):
        path = Path(__file__).with_name('test-profile-dialogs-native.py')
        spec = importlib.util.spec_from_file_location('dialog_native', path)
        native = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(native)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'dialog.zip'
            native.build(output)
            with zipfile.ZipFile(output) as package:
                self.assertNotIn('components/AerioScene.xml', package.namelist())
                for name in package.namelist():
                    if name.endswith('.brs'):
                        source = package.read(name).decode()
                        for forbidden in ['roRegistry', 'roUrlTransfer', 'connectServer(', 'phoneSetupRandomBytes']:
                            self.assertNotIn(forbidden, source)

    def test_wire_validation_rejects_quoted_or_changed_json(self):
        path = Path(__file__).with_name('test-profile-primitives-native.py')
        spec = importlib.util.spec_from_file_location('profile_native', path)
        native = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(native)
        body = b'{"schemaVersion":3,"categories":{"settings":{"data":{"mobile":{"textScale":1.0}}},"syncProviders":{"data":{"updatedAt":1761700000000}}}}'
        headers = {'Content-Type': 'application/json', 'Content-Length': str(len(body))}
        self.assertTrue(native.wire_valid(body, headers, body))
        self.assertFalse(native.wire_valid(json.dumps(body.decode()).encode(), headers, body))
        self.assertFalse(native.wire_valid(body.replace(b'1.0', b'1'), headers, body))
        self.assertFalse(native.wire_valid(body, {**headers, 'Content-Length': '1'}, body))
        self.assertTrue(native.equal_json_types({'FutureCase': [1, 1.0, None]}, {'FutureCase': [1, 1.0, None]}))
        self.assertFalse(native.equal_json_types({'FutureCase': [1, 1.0]}, {'FutureCase': [1, 1]}))
        self.assertFalse(native.equal_json_types({'FutureCase': None}, {'futurecase': None}))

    def test_package_is_synthetic_and_preserves_fixture_literal_types(self):
        path = Path(__file__).with_name('build-profile-probe.py')
        spec = importlib.util.spec_from_file_location('profile_builder', path)
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as tmp:
            output = builder.build(Path(tmp) / 'probe.zip', 'http://127.0.0.1:1234')
            with zipfile.ZipFile(output) as package:
                fixture = json.loads(package.read('profile-wire-fixture.json'))
                self.assertEqual(fixture['categories']['syncProviders']['data']['updatedAt'], 1761700000000)
                self.assertIs(type(fixture['categories']['settings']['data']['mobile']['textScale']), float)
                self.assertIsNone(fixture['categories']['settings']['data']['FutureNull'])
                self.assertEqual(fixture['categories']['profiles']['data']['rows'][0][2], 'Alice 🦉')
                main = package.read('source/Main.brs').decode()
                for forbidden in ['roRegistry', 'connectServer(', 'AerioScene', 'getRandomUUID']:
                    self.assertNotIn(forbidden, main)
                self.assertNotIn('components/AerioScene.xml', package.namelist())
                self.assertNotIn('source/PhoneSetupEntropy.brs', package.namelist())
                for case in json.loads(package.read('profile-registry-fixtures.json')):
                    values = case['values']
                    self.assertEqual(len(values['settingsV1'].encode()), 24000)
                    keys = [v for k, v in values.items() if k.startswith(('connKey_', 'profKey_'))]
                    self.assertEqual(len(keys), 4 * case['profilesPerSlot'])
                    self.assertTrue(all(len(key) == 54 for key in keys))
                probe = package.read('source/UserProfileRegistryProbe.brs').decode()
                self.assertNotIn('getSectionList', probe)
                self.assertIn('registry.delete(sectionName)', probe)


if __name__ == '__main__':
    unittest.main()
