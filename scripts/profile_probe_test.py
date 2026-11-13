"""Host coverage for fixture generation/isolation; never connects to a Roku."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import subprocess


class ProfileProbeTest(unittest.TestCase):
    def test_management_application_probe_is_private_and_cannot_ship(self):
        root = Path(__file__).resolve().parent.parent
        spec = importlib.util.spec_from_file_location('management_probe', Path(__file__).with_name('test-profile-management-native.py'))
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as tmp:
            normal = Path(tmp) / 'normal.zip'
            with zipfile.ZipFile(normal, 'w') as package:
                package.writestr('manifest', 'title=AerioTV\n')
                package.writestr('components/AerioScene.brs', 'sub init()\nm.registry = CreateObject("roRegistrySection", "AerioTV")\n    m.guide.config = {\n}\nend sub')
                package.writestr('source/MetadataCacheStore.brs', 'return "cachefs:/aeriotv-metadata-v1"')
            output = Path(tmp) / 'probe.zip'
            probe.build(output, normal, 'SyntheticManagementSection', 'http://127.0.0.1:1234')
            with zipfile.ZipFile(output) as package:
                self.assertNotIn('"AerioTV"', package.read('components/AerioScene.brs').decode())
                self.assertNotIn('cachefs:', package.read('source/MetadataCacheStore.brs').decode())
                self.assertIn('profile-management-probe.json', package.namelist())
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
        for name in ['DispatcharrSyncEnvelopeProbeChecks', 'DispatcharrSyncMergeProbeChecks', 'DispatcharrSyncPullStoreProbeChecks', 'UserProfilePinPolicyProbeChecks', 'UserProfileCredentialProbeChecks', 'UserProfileManagementPolicyProbeChecks', 'UserProfileSwitchProbeChecks', 'UserProfileChildAccessProbeChecks']:
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
                probe = package.read('source/UserProfileRegistryProbe.brs').decode()
                self.assertNotIn('getSectionList', probe)
                self.assertIn('registry.delete(sectionName)', probe)


if __name__ == '__main__':
    unittest.main()
