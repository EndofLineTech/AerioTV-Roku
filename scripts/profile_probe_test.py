"""Host coverage for fixture generation/isolation; never connects to a Roku."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import subprocess


class ProfileProbeTest(unittest.TestCase):
    def test_shipping_guard_rejects_profile_fixtures(self):
        result = subprocess.run(['node', '--input-type=module', '-e', '''
            import assert from 'node:assert/strict';
            import {assertPackageEntries} from './scripts/verify-package.mjs';
            const base = ['manifest', 'source/Main.brs', 'components/AerioScene.xml',
              'images/LICENSE.txt', 'images/NOTICE.txt', 'images/material-icons-LICENSE.txt'];
            for (const name of ['profile-probe-config.json', 'profile-wire-fixture.json', 'profile-registry-fixtures.json', 'components/UserProfileProbe.brs', 'source/UserProfileRegistryProbe.brs', 'components/UserProfileDialogProbe.brs']) {
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
