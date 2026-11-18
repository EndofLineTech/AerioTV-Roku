import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parent.parent


class ProfileFaultProbeTest(unittest.TestCase):
    def test_cleanup_rollback_uses_real_preferences_persistence_after_pin_cancel(self):
        spec = importlib.util.spec_from_file_location('fault_probe', ROOT / 'scripts/test-profile-switch-fault-native.py')
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        self.assertIn('cleanup-rollback', probe.CASES)
        self.assertIn('roster-stale-pin', probe.CASES)
        self.assertIn('adult-purpose-change', probe.CASES)
        self.assertIn('unavailable-actor-change', probe.CASES)
        self.assertIn('unavailable-actor-state', probe.CASES)
        fixture = (ROOT / 'tests/native/ProfileSwitchRosterFaultFixture.brs').read_text()
        self.assertIn('onProfilePinClosed(managementProbeEvent', fixture)
        self.assertIn('persistCurrentUserProfilePreferences()', fixture)
        self.assertIn('m.preferenceStore.accounts.doesExist', fixture)

    def test_fault_driver_keeps_real_controllers_and_isolates_storage(self):
        spec = importlib.util.spec_from_file_location('fault_probe', ROOT / 'scripts/test-profile-switch-fault-native.py')
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as folder:
            normal, output = Path(folder) / 'normal.zip', Path(folder) / 'fault.zip'
            controllers = ['ProfilePinNavigation', 'ProfileSwitchNavigation', 'ProfileSwitchRosterNavigation']
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                for name in ['components/AerioScene.brs', 'source/MetadataCacheStore.brs'] + [f'components/{name}.brs' for name in controllers]:
                    package.writestr(name, (ROOT / name).read_bytes())
            for case in probe.CASES:
                probe.build(output, normal, 'PrivateFaultSection', 'http://127.0.0.1:1234', case)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('PrivateFaultSection', source)
                    self.assertNotIn('CreateObject("roRegistrySection", "AerioTV")', source)
                    self.assertNotIn('OWN_FAULT_CASE', source)
                    self.assertIn('managementProbeEvent(m.profilePinDialog, 0)', source)
                    self.assertIn('profile-switch-fault-probe.json', package.namelist())
                    for name in controllers:
                        self.assertEqual(package.read(f'components/{name}.brs'), (ROOT / f'components/{name}.brs').read_bytes())
                    self.assertNotIn('m.profilePinVerifier =', source)
                    self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())

    def test_standalone_fault_fixture_cannot_ship(self):
        script = """import {assertPackageEntries} from './scripts/verify-package.mjs';
import assert from 'node:assert/strict';
assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml',
'images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt','source/ProfileSwitchFaultFixture.brs']), /fault/i);"""
        for fixture in ['ProfileSwitchFaultFixture', 'ProfileSwitchRosterFaultFixture']:
            subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileSwitchFaultFixture', fixture)], cwd=ROOT, check=True)


if __name__ == '__main__':
    unittest.main()
