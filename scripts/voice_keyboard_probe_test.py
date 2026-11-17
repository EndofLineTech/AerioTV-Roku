import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


class VoiceKeyboardProbeTest(unittest.TestCase):
    def test_minimal_probe_has_no_app_state_and_measures_default_before_override(self):
        root = Path(__file__).resolve().parent.parent
        spec = importlib.util.spec_from_file_location('voice_probe', root / 'scripts/test-voice-keyboard-native.py')
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'probe.zip'
            probe.build(output)
            with zipfile.ZipFile(output) as archive:
                archive.extractall(folder)
                self.assertIn('profile-pin-probe.json', archive.namelist())
                main = archive.read('source/Main.brs').decode()
                self.assertLess(main.index('screen.show()'), main.index('scene.start = true'))
                scene = archive.read('components/VoiceKeyboardDiagnostic.brs').decode()
                self.assertIn('hasFeature("voice_remote")', scene)
                self.assertIn('getUserCountryCode()', scene)
                for kind in ['generic', 'password', 'numeric', 'dynamic']:
                    self.assertIn('"' + kind + '"', scene)
                self.assertLess(scene.index('voiceDiagnosticRecord("created")'), scene.index('voiceEnabled = true'))
                for name in archive.namelist():
                    if name.endswith('.brs'):
                        body = archive.read(name).decode()
                        for forbidden in ['roRegistrySection', 'roUrlTransfer', 'roStreamSocket']:
                            self.assertNotIn(forbidden, body)
            config = Path(folder) / 'bsconfig.json'
            config.write_text(json.dumps({'rootDir': folder, 'files': ['manifest', 'source/**/*', 'components/**/*'], 'createPackage': False, 'copyToStaging': False}))
            result = subprocess.run([str(root / 'node_modules/.bin/bsc'), '--project', str(config)], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            probe.build(output, voice_controls=True)
            with zipfile.ZipFile(output) as archive:
                self.assertIn(b'supports_voice_roinput=1\n', archive.read('manifest'))


if __name__ == '__main__':
    unittest.main()
