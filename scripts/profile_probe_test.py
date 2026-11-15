"""Host coverage for fixture generation/isolation; never connects to a Roku."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import subprocess
import contextlib
import io
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


class ProfileProbeTest(unittest.TestCase):
    def test_staged_switch_readiness_is_not_publicly_enabled(self):
        root = Path(__file__).resolve().parent.parent
        scene = (root / 'components/AerioScene.brs').read_text()
        self.assertIn('    m.profileSwitchRosterReady = false', scene)
        self.assertNotIn('\n    m.profileSwitchRosterReady = true', scene)
        self.assertIn('    m.profileChildAccessReady = false', scene)
        self.assertIn('    m.profileDefaultRetirementReady = false', scene)
        self.assertIn('    m.profileSyncWriterReady = false', scene)
        self.assertIn('    m.profileSyncSchedulingReady = false', scene)
        writer = (root / 'components/DispatcharrSyncWriteTask.brs').read_text()
        self.assertIn('    m.syncWriterReady = false', writer)

    def test_imported_switch_pin_wire_uses_raw_salt_v2_and_only_target_row(self):
        import hashlib
        spec = importlib.util.spec_from_file_location('management_import_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        envelope = probe.switch_import_pin_envelope()
        row = envelope['categories']['profiles']['data']['rows'][0]
        self.assertEqual(len(envelope['categories']['profiles']['data']['rows']), 1)
        self.assertEqual(row[:4], [8, 'Synthetic8', 'Imported target', 'numbers'])
        self.assertEqual(row[4], hashlib.sha256(bytes.fromhex(row[5]) + b'5678').hexdigest())
        self.assertNotEqual(row[4], hashlib.sha256(row[5].encode() + b'5678').hexdigest())
        self.assertNotIn('"5678"', json.dumps(envelope))

    def test_inactive_cleanup_wire_has_only_current_remote_tombstone(self):
        spec = importlib.util.spec_from_file_location('management_cleanup_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with patch.object(probe.time, 'time', return_value=1794657600):
            envelope = probe.switch_inactive_cleanup_envelope()
        self.assertEqual(envelope['categories']['profiles']['data'], {'rows': [], 'removed': [['synthetic9', 1794657600]]})
        self.assertEqual(envelope['updatedAt'], '2026-11-14T12:00:00Z')
        self.assertNotIn('apiKey', json.dumps(envelope))

    def test_third_holder_fixture_credentials_are_never_logged_as_default(self):
        spec = importlib.util.spec_from_file_location('management_identity_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        for key in ['synthetic-c', 'synthetic-third']:
            self.assertEqual(probe.management_probe_user(key), 9)
        for key in ['synthetic-b', 'delayed-b']:
            self.assertEqual(probe.management_probe_user(key), 8)
        self.assertEqual(probe.management_probe_user('synthetic-a'), 7)

    def test_authority_race_changes_only_final_target_me(self):
        spec = importlib.util.spec_from_file_location('management_authority_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        state = {}
        user = {'id': 8, 'username': 'Synthetic8', 'user_level': 1}
        for call in range(1, 4):
            result = probe.authority_race_user(state, user)
            self.assertEqual(result['user_level'], 10 if call >= 3 else 1)
        self.assertEqual(user['user_level'], 1)
        self.assertEqual(probe.authority_race_user(state, {'id': 7, 'user_level': 1})['user_level'], 1)

    def test_cancel_activity_reports_no_app_names_and_detects_screensaver(self):
        spec = importlib.util.spec_from_file_location('management_activity_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        for xml, expected in [
            (b'<active-app><app id="dev">Private title</app></active-app>', {'dev_active': True, 'screensaver_active': False}),
            (b'<active-app><app id="dev">Private title</app><screensaver id="42">Private saver</screensaver></active-app>', {'dev_active': True, 'screensaver_active': True}),
        ]:
            response = MagicMock()
            response.__enter__.return_value.read.return_value = xml
            with patch.object(probe.urllib.request, 'urlopen', return_value=response):
                self.assertEqual(probe.management_probe_activity('127.0.0.1'), expected)

    def test_retirement_cold_launch_waits_for_exit_and_never_wakes_saver(self):
        spec = importlib.util.spec_from_file_location('management_cold_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with patch.object(probe, 'management_probe_activity', side_effect=[{'dev_active': True, 'screensaver_active': False}, {'dev_active': False, 'screensaver_active': False}]), patch.object(probe.time, 'sleep'), patch.object(probe.urllib.request, 'urlopen') as send:
            self.assertTrue(probe.launch_profile_probe_after_exit('127.0.0.1'))
            request = send.call_args.args[0]
            self.assertEqual(request.full_url, 'http://127.0.0.1:8060/launch/dev')
            self.assertEqual(request.get_method(), 'POST')
        with patch.object(probe, 'management_probe_activity', return_value={'dev_active': False, 'screensaver_active': True}), patch.object(probe.urllib.request, 'urlopen') as send:
            with self.assertRaises(RuntimeError):
                probe.launch_profile_probe_after_exit('127.0.0.1')
            send.assert_not_called()

    def test_native_timeout_diagnostics_are_boolean_only(self):
        spec = importlib.util.spec_from_file_location('native_runner', Path(__file__).with_name('run-native-probe.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        xml = b'<active-app><app id="private-app-id">Private app name</app></active-app>'
        with patch.object(probe.urllib.request, 'urlopen', return_value=io.BytesIO(xml)):
            self.assertIs(probe.active_dev_app('192.0.2.1'), False)
        with patch.object(probe.urllib.request, 'urlopen', return_value=io.BytesIO(b'<active-app><app id="dev">Private dev title</app></active-app>')):
            self.assertIs(probe.active_dev_app('192.0.2.1'), True)
        with patch.object(probe.urllib.request, 'urlopen', return_value=io.BytesIO(b'malformed')):
            self.assertIsNone(probe.active_dev_app('192.0.2.1'))
        console = MagicMock()
        console.recv.side_effect = probe.socket.timeout
        output = io.StringIO()
        with patch.dict(probe.os.environ, {'ROKU_HOST': '192.0.2.1', 'ROKU_DEV_PASSWORD': 'synthetic-test-password'}), patch.object(probe.socket, 'create_connection', return_value=console), patch.object(probe.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='Install Success')), patch.object(probe.urllib.request, 'urlopen', return_value=io.BytesIO(xml)), patch('sys.argv', ['probe', 'fixture.zip', '--marker', 'missing', '--timeout', '0']), contextlib.redirect_stdout(output):
            with self.assertRaises(SystemExit):
                probe.main()
        text = output.getvalue()
        self.assertIn('Native dev active: False', text)
        self.assertIn('Native launch observed: False', text)
        for secret in ['private-app-id', 'Private app name', '192.0.2.1', 'synthetic-test-password']:
            self.assertNotIn(secret, text)

    def test_child_escape_fixture_cannot_ship(self):
        script = "import {assertPackageEntries} from './scripts/verify-package.mjs'; import assert from 'node:assert/strict'; assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml','images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt','source/ProfileChildEscapeFixture.brs']), /probe/);"
        subprocess.run(['node', '--input-type=module', '-e', script], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileChildLaunchFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileOwnRecheckFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileChildAvailableFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'UserProfileChildActivationProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'UserProfileChildOwnSignInProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileChildOwnSignInFormFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileChildRetryFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'RequestGateOwnCredentialProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileOwnHeldKeyCancelFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'UserProfileChildRejectedPromptProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileChildRejectedFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileChildRecheckFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileDefaultSetupRecoveryFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileManualRefreshFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'LineupHistoryReconciliationProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileFavoriteRetentionFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'GuideFavoriteRetentionProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileSwitchRecordingFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncSwitchRosterProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncUnavailableChildRosterProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileTargetRetirementFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileAuthorityRaceFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileActiveRetirementFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileRetirementColdFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'ProfileSyncWriterFixture')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncSwitchRosterStoreProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncWriteBodyProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncRosterWriteProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncAckStoreProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncScheduleProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'DispatcharrSyncPolicyProbeChecks')], check=True)
        subprocess.run(['node', '--input-type=module', '-e', script.replace('ProfileChildEscapeFixture', 'NetworkStatusProbeChecks')], check=True)

    def test_native_roster_storage_checks_keep_broker_seam_private(self):
        spec = importlib.util.spec_from_file_location('native_store_probe', Path(__file__).with_name('build-profile-probe.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'native-store.zip'
            probe.build(output, 'http://127.0.0.1:1234', model_store=True)
            with zipfile.ZipFile(output) as package:
                checks = package.read('source/DispatcharrSyncSwitchRosterStoreProbeChecks.brs').decode()
                storage = package.read('source/DispatcharrSyncSwitchRosterStore.brs').decode()
                self.assertIn('runDispatcharrSyncSwitchRosterStoreChecks()', checks)
                self.assertIn('function switchRosterStoreFixtureAccessAllowed(', checks)
                self.assertNotIn('function requestGateAccessAllowed(', checks)
                self.assertIn('switchRosterStoreFixtureAccessAllowed(', storage)
                self.assertIn('m.profilePreferenceDecoder = invalid', checks)
                write_checks = package.read('source/DispatcharrSyncWriteBodyProbeChecks.brs').decode()
                self.assertIn('m.syncWriteHostInterpreter = false', write_checks)
                self.assertIn('m.syncWriteParser = invalid', write_checks)
                self.assertNotIn('return ParseJson(raw)', write_checks)

    def test_address_handler_probe_is_private_and_cannot_ship(self):
        spec = importlib.util.spec_from_file_location('address_probe', Path(__file__).with_name('test-profile-address-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            output = Path(tmp) / 'probe.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'sub init()\nm.registry = CreateObject("roRegistrySection", "AerioTV")\n    m.guide.config = {\n}\nend sub')
                package.writestr('source/MetadataCacheStore.brs', 'return "cachefs:/aeriotv-metadata-v1"')
            probe.build(output, normal, 'SyntheticAddressSection', 'http://127.0.0.1:1234', 'http://127.0.0.1:5678')
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('updateConnectionUrl("http://127.0.0.1:5678")', source)
                self.assertIn('m.registry.flushes = 1', source)
                self.assertIn('if m.managementProbeClock = invalid', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-address-probe.json', package.namelist())
            probe.build(output, normal, 'SyntheticLegacySection', 'http://127.0.0.1:1234', 'http://127.0.0.1:5678', legacy=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertNotIn('"slot-a"', source)
                self.assertIn('"preferences", ReadAsciiFile("pkg:/profile-legacy-preferences.json")', source)
                self.assertIn('m.legacyMigrationPassed', source)
                self.assertIn('legacySettings["FutureRoot"]["precise"]', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-legacy-settings.json', package.namelist())
        root = Path(__file__).resolve().parent.parent
        script = "import {assertPackageEntries} from './scripts/verify-package.mjs'; import assert from 'node:assert/strict'; for (const entry of ['profile-address-probe.json','source/ProfileAddressFixture.brs']) assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml','images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt',entry]), /probe/);"
        subprocess.run(['node', '--input-type=module', '-e', script], cwd=root, check=True, capture_output=True)

    def test_own_signin_application_probe_is_private_and_cannot_ship(self):
        root = Path(__file__).resolve().parent.parent
        spec = importlib.util.spec_from_file_location('own_signin_probe', Path(__file__).with_name('test-profile-own-signin-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'sub init()\nm.profileChildAccessReady = false\nm.profileSwitchRosterReady = false\nm.profileDefaultRetirementReady = false\nm.registry = CreateObject("roRegistrySection", "AerioTV")\n    m.guide.config = {\n}\nend sub\nfunction onKeyEvent(key as string, press as boolean) as boolean\nreturn false\nend function\n')
                package.writestr('source/MetadataCacheStore.brs', 'return "cachefs:/aeriotv-metadata-v1"')
                package.writestr('components/RequestGateTask.brs', '    else if action = "own-verified"\n')
            output = Path(tmp) / 'probe.zip'
            probe.build(output, normal, 'SyntheticOwnSignInSection', 'http://127.0.0.1:1234')
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('task.ownProfileSignIn = true', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-own-signin-probe.json', package.namelist())
            probe.build(output, normal, 'SyntheticOwnSignInSection', 'http://127.0.0.1:1234', form=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('beginUserProfileOwnSignIn(target.id)', source)
                self.assertIn('"cancel-ready"', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            probe.build(output, normal, 'SyntheticOwnSignInSection', 'http://127.0.0.1:1234', held=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('OWN_PROBE_HELD', source)
                self.assertIn('m.ownProbeHeld = true', source)
                self.assertIn('actual.profiles[2].addressHeld', source)
                self.assertNotIn('"AerioTV"', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            probe.build(output, normal, 'SyntheticOwnSignInSection', 'http://127.0.0.1:1234', form=True, default_form=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('beginUserProfileSwitch(b.id)', source)
                self.assertIn('expectedUserId = "7"', source)
                self.assertNotIn('OWN_PROBE_PIN_HASH', source)
                self.assertIn('"cancel-ready"', source)
            probe.build(output, normal, 'SyntheticActiveOwnSection', 'http://127.0.0.1:1234', form=True, active_form=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertNotIn('OWN_PROBE_PIN_HASH', source)
                self.assertIn('onActiveUserProfileRecoveryChoice', source)
                self.assertIn('"revoke-new-ready"', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            probe.build(output, normal, 'SyntheticOwnRecheckSection', 'http://127.0.0.1:1234', form=True, active_recheck=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('"recheck-ready"', source)
                self.assertIn('m.ownRecheckProfile', source)
                self.assertNotIn('OWN_RECHECK_', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            probe.build(output, normal, 'SyntheticOwnRecheckCancelSection', 'http://127.0.0.1:1234', form=True, active_recheck=True, recheck_cancel=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('OWN_RECHECK_', source)
                self.assertIn('m.ownRecheckCancelTicks', source)
                self.assertNotIn('"AerioTV"', source)
            probe.build(output, normal, 'SyntheticOwnIdentitySection', 'http://127.0.0.1:1234', form=True, active_form=True, identity_change=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('OWN_ACTIVE_CONNECT', source)
                self.assertIn('bound_identity_recovery', source)
                self.assertNotIn('"AerioTV"', source)
            probe.build(output, normal, 'SyntheticSameOwnKeySection', 'http://127.0.0.1:1234', form=True, active_form=True, same_key=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('synthetic-new-own-key', source)
                self.assertIn('synthetic-b', source)
                self.assertNotIn('"AerioTV"', source)
            probe.build(output, normal, 'SyntheticSameOwnCancelSection', 'http://127.0.0.1:1234', form=True, active_form=True, same_key=True, hold_cancel=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('m.heldCancelRoster', source)
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('sleep(4000)', package.read('components/RequestGateTask.brs').decode())
                self.assertNotIn('OWN_HOLD_', source)
            probe.build(output, normal, 'SyntheticSameOwnTimeoutSection', 'http://127.0.0.1:1234', form=True, active_form=True, same_key=True, hold_timeout=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('"timeout-ready"', source)
                self.assertNotIn('OWN_HOLD_', source)
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('sleep(8000)', package.read('components/RequestGateTask.brs').decode())
            probe.build(output, normal, 'SyntheticChildOwnTimeoutSection', 'http://127.0.0.1:1234', form=True, child_form='default-pin', child_rejected=True, same_key=True, hold_timeout=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('OWN_HOLD_', source)
                self.assertIn('onChildRejectedKeyChoice', source)
                self.assertNotIn('"AerioTV"', source)
            for mode in ['own', 'own-pin', 'default', 'default-pin', 'held-keyless']:
                probe.build(output, normal, 'SyntheticChildOwnSection', 'http://127.0.0.1:1234', form=True, child_form=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertNotIn('OWN_CHILD_', source)
                    self.assertNotIn('"AerioTV"', source)
                    self.assertIn('m.profileChildAccessReady = true', source)
                    self.assertIn('submitChildOwnPassword', source)
                    self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            for mode in ['default', 'default-pin']:
                probe.build(output, normal, 'SyntheticChildSameKeySection', 'http://127.0.0.1:1234', form=True, child_form=mode, child_rejected=True, same_key=True)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertNotIn('OWN_CHILD_', source)
                    self.assertIn('m.childFormRevokeStarted', source)
                    self.assertNotIn('synthetic-new-own-key', source)
                    self.assertNotIn('"AerioTV"', source)
            for mode in ['own', 'own-pin', 'default', 'default-pin']:
                probe.build(output, normal, 'SyntheticChildRecheckSection', 'http://127.0.0.1:1234', form=True, child_form=mode, child_rejected=True, child_recheck=True)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertNotIn('OWN_CHILD_', source)
                    self.assertIn('"child-retry-ready"', source)
                    self.assertNotIn('"AerioTV"', source)
            for same in [False, True]:
                probe.build(output, normal, 'SyntheticDefaultSetupSection', 'http://127.0.0.1:1234', form=True, default_form=True, default_setup=True, same_key=same)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('"default-setup-ready"', source)
                    self.assertNotIn('OWN_SETUP_', source)
                    self.assertNotIn('"AerioTV"', source)
            for mode in ['hold_cancel', 'hold_timeout']:
                probe.build(output, normal, 'SyntheticDefaultSetupWaitSection', 'http://127.0.0.1:1234', form=True, default_form=True, default_setup=True, same_key=True, **{mode: True})
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertNotIn('OWN_SETUP_', source)
                    self.assertIn('m.defaultSetupOldProof', source)
                    self.assertNotIn('"AerioTV"', source)
            probe.build(output, normal, 'SyntheticDefaultReplacementSection', 'http://127.0.0.1:1234', form=True, default_form=True, default_setup=True, setup_replacement=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('OWN_SETUP_', source)
                self.assertIn('Synthetic99', source)
                self.assertNotIn('"AerioTV"', source)
        script = "import {assertPackageEntries} from './scripts/verify-package.mjs'; import assert from 'node:assert/strict'; for (const entry of ['profile-own-signin-probe.json','source/ProfileOwnSignInFixture.brs','source/ProfileOwnSignInFormFixture.brs','source/ProfileDefaultOwnSignInFormFixture.brs','source/ProfileActiveOwnSignInFixture.brs','source/ProfileColdRestoreFixture.brs','source/ProfileAssignmentRefreshFixture.brs']) assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml','images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt',entry]), /probe/);"
        subprocess.run(['node', '--input-type=module', '-e', script], cwd=root, check=True, capture_output=True, text=True)

    def test_management_application_probe_is_private_and_cannot_ship(self):
        root = Path(__file__).resolve().parent.parent
        spec = importlib.util.spec_from_file_location('management_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'sub init()\nm.profileChildAccessReady = false\nm.profileSwitchRosterReady = false\nm.profileDefaultRetirementReady = false\nm.profileSyncWriterReady = false\nm.registry = CreateObject("roRegistrySection", "AerioTV")\n    m.guide.config = {\n}\nend sub\nfunction onKeyEvent(key as string, press as boolean) as boolean\nreturn false\nend function\n')
                package.writestr('source/MetadataCacheStore.brs', 'return "cachefs:/aeriotv-metadata-v1"')
                package.writestr('components/GuideView.xml', '<component name="GuideView"><interface></interface></component>')
                package.writestr('components/GuideView.brs', 'sub init()\nend sub\nfunction onKeyEvent(key as string, press as boolean) as boolean\nreturn false\nend function\n')
                for name in ['components/DvrSettlementNavigation.brs', 'components/DvrNavigation.brs', 'components/DvrRecordingTask.brs', 'components/ProfileDefaultRetirementNavigation.brs', 'source/HttpTransport.brs']:
                    package.writestr(name, (root / name).read_text())
                package.writestr('components/DispatcharrSyncWriteTask.brs', (root / 'components/DispatcharrSyncWriteTask.brs').read_text())
            output = Path(tmp) / 'probe.zip'
            probe.build(output, normal, 'SyntheticManagementSection', 'http://127.0.0.1:1234')
            with zipfile.ZipFile(output) as package:
                self.assertNotIn('"AerioTV"', package.read('components/AerioScene.brs').decode())
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-management-probe.json', package.namelist())
            probe.build(output, normal, 'SyntheticManagementSection', 'http://127.0.0.1:1234', switching=True, reconnect=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('OWN_RECONNECT_PROBE', source)
                self.assertIn('m.switchProbeReconnectStarted = true', source)
                self.assertIn('connectServer(true)', source)
                self.assertNotIn('"AerioTV"', source)
            probe.build(output, normal, 'SyntheticEarlyRosterSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('m.profileSwitchRosterReady = true', source)
                self.assertIn('kind: "switch-key"', source)
                self.assertIn('scene_focus: m.top.isInFocusChain()', source)
                self.assertIn('kind: "switch-guide-key"', package.read('components/GuideView.brs').decode())
                self.assertNotIn('m.profileSwitchRosterReady = false', source)
                self.assertNotIn('"AerioTV"', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticEarlyRosterSection', 'http://127.0.0.1:1234', switch_roster=True)
            probe.build(output, normal, 'SyntheticImportedPinSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_import_pin=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('m.profileSwitchRosterReady = true', source)
                self.assertIn('m.switchImportOldRefused', source)
                self.assertIn('m.switchImportStored', source)
                self.assertIn('"switch-roster"', source)
                self.assertIn('text = "5678"', source)
                self.assertNotIn('adult.pinType = "numbers"', source)
                self.assertNotIn('"AerioTV"', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticImportedPinSection', 'http://127.0.0.1:1234', switching=True, switch_import_pin=True)
            probe.build(output, normal, 'SyntheticInactiveCleanupSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_cleanup=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('m.profileSwitchRosterReady = true', source)
                self.assertIn('m.switchProbeInactiveCleaned', source)
                self.assertIn('m.switchProbeThirdSeeded', source)
                self.assertIn('userProfilePinBackoffKey("slot-a", third.id)', source)
                self.assertIn('inactive_cleaned:', source)
                self.assertNotIn('"AerioTV"', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticInactiveCleanupSection', 'http://127.0.0.1:1234', switching=True, switch_cleanup=True)
            probe.build(output, normal, 'SyntheticTargetRetirementSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_target_retirement=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('advanceProfileTargetRetirementProbe()', source)
                self.assertIn('m.switchProbeTargetRetired', source)
                self.assertIn('target_retired:', source)
                self.assertIn('m.profileSwitchRosterReady = true', source)
                self.assertNotIn('"AerioTV"', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticTargetRetirementSection', 'http://127.0.0.1:1234', switching=True, switch_target_retirement=True)
            probe.build(output, normal, 'SyntheticAuthorityRaceSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_authority_race=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('authority_race_refused:', source)
                self.assertIn('m.authorityRaceStarted', source)
                self.assertNotIn('"AerioTV"', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticAuthorityRaceSection', 'http://127.0.0.1:1234', switching=True, switch_authority_race=True)
            probe.build(output, normal, 'SyntheticActiveRetirementSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_active_retirement=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('advanceProfileActiveRetirementProbe()', source)
                self.assertIn('m.profileDefaultRetirementReady = true', source)
                self.assertIn('active_retired:', source)
                self.assertNotIn('"AerioTV"', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticActiveRetirementSection', 'http://127.0.0.1:1234', switching=True, switch_active_retirement=True)
            probe.build(output, normal, 'SyntheticWriterSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_writer=True)
            with zipfile.ZipFile(output) as package:
                self.assertIn('advanceProfileSyncWriterProbe()', package.read('components/AerioScene.brs').decode())
                writer = package.read('components/DispatcharrSyncWriteTask.brs').decode()
                self.assertIn('m.syncWriterReady = true', writer)
                self.assertNotIn('"AerioTV"', writer)
            probe.build(output, normal, 'SyntheticFlushSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_writer=True, writer_mode='flush')
            with zipfile.ZipFile(output) as package:
                scene = package.read('components/AerioScene.brs').decode()
                self.assertIn('m.profileSyncWriterReady = true', scene)
                self.assertIn('m.writerProbeMode = "flush"', scene)
                self.assertNotIn('PROFILE_WRITER_MODE', scene)
            for mode in ['unchanged', 'schedule', 'schedule-too-large', 'schedule-signin', 'create', 'create-legacy', 'create-proxy404', 'flush-failed', 'flush-cancel', 'flush-authority', 'flush-import-pin', 'flush-own-retirement']:
                probe.build(output, normal, 'SyntheticFlushFailureSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_writer=True, writer_mode=mode)
                with zipfile.ZipFile(output) as package:
                    self.assertIn('m.writerProbeMode = "' + mode + '"', package.read('components/AerioScene.brs').decode())
            for mode in ['missing', 'held', 'child', 'simultaneous', 'import-pin', 'import-child']:
                probe.build(output, normal, 'SyntheticUnavailableDefaultSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_active_retirement=True, active_default_mode=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('m.switchProbeDefaultMode = "' + mode + '"', source)
                    self.assertNotIn('ACTIVE_DEFAULT_MODE', source)
            with self.assertRaises(ValueError):
                probe.build(output, normal, 'SyntheticUnavailableDefaultSection', 'http://127.0.0.1:1234', active_default_mode='held')
            probe.build(output, normal, 'SyntheticColdRetirementSection', 'http://127.0.0.1:1234', switching=True, switch_roster=True, switch_active_retirement=True, active_default_mode='cold')
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                retirement = package.read('components/ProfileDefaultRetirementNavigation.brs').decode()
                self.assertIn('m.retirementColdBoot = m.registry.exists(', source)
                self.assertIn('if not m.retirementColdBoot', source)
                self.assertIn('retirement-cold-pin-ready', source)
                self.assertIn('retirement-crash-ready', retirement)
                self.assertIn('m.top.exitRequested = true', retirement)
                self.assertNotIn('"AerioTV"', source)
            for mode in ['remembered', 'keyless', 'held']:
                probe.build(output, normal, 'SyntheticColdSection', 'http://127.0.0.1:1234', cold_restore=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertNotIn('"AerioTV"', source)
                    self.assertNotIn('OWN_COLD_', source)
                    self.assertIn('active: ownHolder.id', source)
                    self.assertIn('expected = "8"' if mode == 'remembered' else 'expected = "7"', source)
                    self.assertNotIn('beginUserProfileSwitch(', source)
                    self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            probe.build(output, normal, 'SyntheticAssignmentSection', 'http://127.0.0.1:1234', assignment_refresh=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('"assignment-ready"', source)
                self.assertIn('refreshCapabilities()', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            probe.build(output, normal, 'SyntheticManualRefreshSection', 'http://127.0.0.1:1234', manual_refresh=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('refreshChannelLineup()', source)
                self.assertIn('m.manualOldSession', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertNotIn('MANUAL_', source)
            for mode in ['changed', 'unchanged', 'identity', 'transient']:
                probe.build(output, normal, 'SyntheticManualVariantSection', 'http://127.0.0.1:1234', manual_refresh=True, manual_mode=mode, manual_recording=mode in ['changed', 'unchanged'])
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertNotIn('MANUAL_', source)
                    self.assertNotIn('"AerioTV"', source)
                    if mode in ['changed', 'unchanged']:
                        self.assertIn('m.manualRecordingSettled', package.read('components/DvrSettlementNavigation.brs').decode())
            probe.build(output, normal, 'SyntheticFavoriteSection', 'http://127.0.0.1:1234', favorite_retention=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('favoriteIds: ["99", "8"]', source)
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('profileFavoriteProbe', package.read('components/GuideView.xml').decode())
                self.assertIn('profileFavoriteProbe', package.read('components/GuideView.brs').decode())
            for mode in ['commit', 'cancel', 'pin-cancel']:
                probe.build(output, normal, 'SyntheticSwitchRecordingSection', 'http://127.0.0.1:1234', switch_recording=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('m.probeSwitchRecordNode', source)
                    self.assertIn('favoriteIds: ["8"]', source)
                    self.assertNotIn('SWITCH_RECORD_', source)
                    self.assertNotIn('"AerioTV"', source)
                    self.assertIn('m.probeRecordConfirmed', package.read('components/DvrSettlementNavigation.brs').decode())
                    if mode == 'pin-cancel':
                        self.assertIn('userProfilePinHash(defaultHolder.pinSalt, "1234")', source)
            probe.build(output, normal, 'SyntheticChildEscapeSection', 'http://127.0.0.1:1234', child_escape=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('prepareChildEscape', source)
                self.assertIn('showUnavailableChildProfile()', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('preserved = store.pendingRoster and', source)
            probe.build(output, normal, 'SyntheticChildEscapeRosterSection', 'http://127.0.0.1:1234', child_escape=True, switch_roster=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertIn('m.profileSwitchRosterReady = true', source)
                self.assertIn('preserved = not store.pendingRoster and', source)
                self.assertIn('m.childEscapePendingRefused', source)
                self.assertIn('setCanonicalPreference(store, "pendingRoster", false)', source)
                self.assertNotIn('"AerioTV"', source)
            probe.build(output, normal, 'SyntheticChildLaunchSection', 'http://127.0.0.1:1234', child_launch=True)
            with zipfile.ZipFile(output) as package:
                source = package.read('components/AerioScene.brs').decode()
                self.assertNotIn('"AerioTV"', source)
                self.assertIn('"launch_pin"', source)
                self.assertIn('ownHolder, "role", "child"', source)
                self.assertIn('setCanonicalPreference(holders[holderIndex], "pinType"', source)
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
            for mode in ['own', 'own-pin', 'default', 'default-pin']:
                probe.build(output, normal, 'SyntheticChildAvailableSection', 'http://127.0.0.1:1234', child_available=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('m.profileChildAccessReady = true', source)
                    self.assertNotIn('OWN_CHILD_', source)
                    self.assertNotIn('"AerioTV"', source)
                    self.assertIn('child_available', source)
                    self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                probe.build(output, normal, 'SyntheticChildRetrySection', 'http://127.0.0.1:1234', child_retry=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('childRetryUnavailable', source)
                    self.assertNotIn('OWN_CHILD_', source)
                    self.assertNotIn('"AerioTV"', source)
                probe.build(output, normal, 'SyntheticChildRejectedSection', 'http://127.0.0.1:1234', child_rejected=mode)
                with zipfile.ZipFile(output) as package:
                    source = package.read('components/AerioScene.brs').decode()
                    self.assertIn('"rejection-safe"', source)
                    self.assertNotIn('OWN_CHILD_', source)
                    self.assertNotIn('"AerioTV"', source)
        script = "import {assertPackageEntries} from './scripts/verify-package.mjs'; import assert from 'node:assert/strict'; assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml','images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt','profile-management-probe.json']), /probe/);"
        subprocess.run(['node', '--input-type=module', '-e', script], cwd=root, check=True, capture_output=True, text=True)

    def test_pin_application_probe_is_private_and_cannot_ship(self):
        root = Path(__file__).resolve().parent.parent
        path = Path(__file__).with_name('test-profile-pin-native.py')
        spec = importlib.util.spec_from_file_location('pin_probe', path)
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'sub init()\nm.registry = CreateObject("roRegistrySection", "AerioTV")\nend sub')
                package.writestr('components/ProfilePinNavigation.brs', '    dialog.setFocus(true)')
                package.writestr('source/MetadataCacheStore.brs', 'return "cachefs:/aeriotv-metadata-v1"')
            output = Path(tmp) / 'probe.zip'
            probe.build(output, normal, 'SyntheticPinSection', 'http://127.0.0.1:1234')
            with zipfile.ZipFile(output) as package:
                self.assertNotIn('"AerioTV"', package.read('components/AerioScene.brs').decode())
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-pin-probe.json', package.namelist())
        script = "import {assertPackageEntries} from './scripts/verify-package.mjs'; import assert from 'node:assert/strict'; assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml','images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt','profile-pin-probe.json']), /probe/);"
        subprocess.run(['node', '--input-type=module', '-e', script], cwd=root, check=True, capture_output=True, text=True)

    def test_main_does_not_read_scene_before_render_thread_starts(self):
        root = Path(__file__).resolve().parent.parent
        before_show = (root / 'source/Main.brs').read_text().split('screen.show()', 1)[0]
        self.assertNotIn('if scene.exitRequested', before_show)
        self.assertNotIn('scene.observeField("exitRequested", port)', before_show)
        self.assertIn('scene.observeField("exitRequested", port)', (root / 'source/Main.brs').read_text().split('screen.show()', 1)[1])
        self.assertIn('lcase(event.getField()) = "exitrequested"', (root / 'source/Main.brs').read_text())

    def test_sync_discovery_is_own_user_read_only_and_cannot_ship_probe(self):
        root = Path(__file__).resolve().parent.parent
        source = (root / 'components/DispatcharrSyncReadTask.brs').read_text()
        self.assertNotIn('"PUT"', source)
        self.assertNotIn('"DELETE"', source)
        self.assertNotIn('"POST"', source)
        self.assertNotIn('requestJson(', source)
        self.assertNotIn('copyJson(', source)
        self.assertIn('ParseJson(text, "d")', source)
        self.assertNotIn('roRegistry', source)
        script = "import {assertPackageEntries} from './scripts/verify-package.mjs'; import assert from 'node:assert/strict'; assert.throws(() => assertPackageEntries(['manifest','source/Main.brs','components/Scene.xml','images/LICENSE.txt','images/NOTICE.txt','images/material-icons-LICENSE.txt','source/DispatcharrSyncKeyProbeChecks.brs']), /probe/);"
        subprocess.run(['node', '--input-type=module', '-e', script], cwd=root, check=True, capture_output=True, text=True)
        script = script.replace('DispatcharrSyncKeyProbeChecks', 'DispatcharrSyncRosterProbeChecks')
        subprocess.run(['node', '--input-type=module', '-e', script], cwd=root, check=True, capture_output=True, text=True)
        for name in ['DispatcharrSyncEnvelopeProbeChecks', 'DispatcharrSyncMergeProbeChecks', 'DispatcharrSyncPullStoreProbeChecks', 'UserProfilePinPolicyProbeChecks', 'UserProfileCredentialProbeChecks', 'UserProfileManagementPolicyProbeChecks', 'UserProfileSwitchProbeChecks', 'UserProfileOwnSignInProbeChecks', 'UserProfileAddressPolicyProbeChecks', 'UserProfileAddressStoreProbeChecks', 'UserProfileDefaultReplacementProbeChecks', 'UserProfileLiveDefaultProbeChecks', 'UserProfileChildAccessProbeChecks', 'SettingsChildProbeChecks']:
            probe_script = script.replace('DispatcharrSyncRosterProbeChecks', name)
            subprocess.run(['node', '--input-type=module', '-e', probe_script], cwd=root, check=True, capture_output=True, text=True)

    def test_media_controls_observe_immutable_context_events(self):
        root = Path(__file__).resolve().parent.parent
        scene = (root / 'components/AerioScene.brs').read_text()
        player = (root / 'components/OnDemandPlayer.brs').read_text()
        for field, handler in [('closedContext', 'onMediaClosed'), ('archiveSeekContext', 'onArchiveSeek'), ('goLiveContext', 'onArchiveGoLive')]:
            self.assertIn(f'm.mediaPlayer.observeField("{field}", "{handler}")', scene)
            self.assertIn(f'm.top.{field} = userViewEvent(', player)
        for field, handler in [('closed', 'onMediaClosed'), ('archiveSeek', 'onArchiveSeek'), ('goLiveRequested', 'onArchiveGoLive')]:
            self.assertNotIn(f'm.mediaPlayer.observeField("{field}", "{handler}")', scene)

    def test_network_task_constructors_capture_active_user_session(self):
        import re
        root = Path(__file__).resolve().parent.parent
        exempt = {'RequestGateTask', 'LogoCleanupTask', 'CacheClearTask', 'PhoneSetupTask'}
        checked = 0
        for path in (root / 'components').glob('*.brs'):
            lines = path.read_text().splitlines()
            for index, line in enumerate(lines):
                match = re.search(r'(\w+(?:\.\w+)*) = CreateObject\("roSGNode", "(\w+Task)"\)', line)
                if not match or match[2] in exempt:
                    continue
                following = '\n'.join(lines[index + 1:index + 3])
                if match[2] == 'HlsSessionTask' and 'task.operation = "close"' in following:
                    continue  # Own outgoing cleanup must outlive incoming context.
                self.assertIn(f'tagTaskForCurrentUser({match[1]})', following, f'{path}:{index + 1}')
                checked += 1
        self.assertGreaterEqual(checked, 35)

    def test_settings_application_probe_uses_private_registry_and_cache(self):
        path = Path(__file__).with_name('test-profile-settings-native.py')
        spec = importlib.util.spec_from_file_location('settings_probe', path)
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'm.registry = CreateObject("roRegistrySection", "AerioTV")\n    m.guide.config = {\n')
                package.writestr('source/MetadataCacheStore.brs', 'return "cachefs:/aeriotv-metadata-v1"')
            output = Path(tmp) / 'probe.zip'
            probe.build(output, normal, 'SyntheticSettingsSection', 'http://127.0.0.1:1234', 'A')
            with zipfile.ZipFile(output) as package:
                self.assertNotIn('"AerioTV"', package.read('components/AerioScene.brs').decode())
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-settings-probe.json', package.namelist())

    def test_every_metadata_cache_read_checks_current_request_safety(self):
        root = Path(__file__).resolve().parent.parent
        count = 0
        for path in (root / 'components').glob('*.brs'):
            for line in path.read_text().splitlines():
                if 'metadataCacheRead(' in line:
                    count += 1
                    self.assertIn('requestGateAccessAllowed(m.base, m.key)', line, str(path))
        self.assertEqual(count, 6)

    def test_request_mailbox_uses_fresh_wire_nodes_and_sanitized_context(self):
        root = Path(__file__).resolve().parent.parent
        client = (root / 'source/RequestGateClient.brs').read_text()
        exchange = client.split('function requestGateExchange(', 1)[1].split('end function', 1)[0]
        self.assertIn('wire = CreateObject("roSGNode", "RequestGateTicket")', exchange)
        self.assertIn('broker.request = wire', exchange)
        self.assertNotIn('broker.request = ticket', exchange)
        self.assertIn('ticket.url = requestGateTicketUrl(url, probe)', client)
        self.assertNotIn('ticket.body = response.body', client)
        self.assertNotIn('ticket.headers = response.headers', client)

    def test_request_broker_probe_is_standalone_and_non_mutating(self):
        path = Path(__file__).with_name('test-request-gate-native.py')
        spec = importlib.util.spec_from_file_location('gate_probe', path)
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'probe.zip'
            probe.build(output)
            with zipfile.ZipFile(output) as package:
                self.assertNotIn('components/AerioScene.xml', package.namelist())
                self.assertIn('request-gate-probe.json', package.namelist())
                for name in package.namelist():
                    if name.endswith('.brs'):
                        body = package.read(name).decode()
                        self.assertNotIn('roRegistry', body)

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
        self.assertLess(complete.index('prepareUserProfileConnectionSettings(connection, result)'), complete.index('m.guide.config ='))
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
                for name in ['UserProfileModel', 'UserProfileStore', 'UserProfileAvatar', 'UserProfileLifecycle', 'UserProfileForget', 'UserProfileNavigation', 'UserProfileRemoval', 'UserProfileScope', 'UserProfileScopeStore', 'UserProfilePreferenceNavigation']:
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
            for (const name of ['request-gate-probe.json', 'components/RequestGateProbe.brs', 'components/RequestGateProbeWorker.xml', 'source/RequestGateProbeMain.brs']) {
              assert.throws(() => assertPackageEntries([...base, name]), /probe/);
            }
            assert.throws(() => assertPackageEntries([...base, 'source/UserProfileScopeProbeChecks.brs']), /probe/);
            assert.throws(() => assertPackageEntries([...base, 'source/UserProfileScopeStoreProbeChecks.brs']), /probe/);
            assert.throws(() => assertPackageEntries([...base, 'source/UserProfilePreferenceNavigationProbeChecks.brs']), /probe/);
            assert.throws(() => assertPackageEntries([...base, 'profile-settings-probe.json']), /probe/);
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
                    for name, raw in values.items():
                        if not name.startswith('userProfilesV1_'):
                            continue
                        roster = json.loads(raw)
                        identity = {'userId': roster['profiles'][0]['userId'], 'username': roster['profiles'][0]['username']}
                        self.assertEqual(roster['knownDefault'], identity)
                        self.assertEqual(roster['addressChangeSnapshot'], identity)
                        self.assertTrue(all(row['preferenceAnchor'] == f'https://old.example.test|{row["userId"]}|{roster["playlistId"]}' for row in roster['profiles']))
                        self.assertTrue(all(row['addressHeld'] and row['defaultIdentityTag'] == identity for row in roster['profiles'][1:]))
                probe = package.read('source/UserProfileRegistryProbe.brs').decode()
                self.assertNotIn('getSectionList', probe)
                self.assertIn('registry.delete(sectionName)', probe)


if __name__ == '__main__':
    unittest.main()
