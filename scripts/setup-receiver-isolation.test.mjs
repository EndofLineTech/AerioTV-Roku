import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

test('receiver fixture material can only enter an explicitly isolated probe ZIP', () => {
  const result = spawnSync('python3', ['-c', `
import importlib.util, pathlib, tempfile, zipfile
root = pathlib.Path.cwd()
spec = importlib.util.spec_from_file_location('receiver', root / 'scripts/build-setup-receiver-probe.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    fixture = module.build(pathlib.Path(directory) / 'fixture.zip')
    production = module.build(pathlib.Path(directory) / 'production.zip', production_entropy=True)
    with zipfile.ZipFile(fixture) as package:
        assert 'fixture-materials.json' in package.namelist()
        assert b'ISOLATED PROBE ONLY' in package.read('source/PhoneSetupEntropy.brs')
        assert b'SYNTHETIC TEST KEYS' in package.read('components/SetupReceiverProbe.xml')
        assert b'kind: "task_" + m.exitInfo.kind' in package.read('components/PhoneSetupTask.brs')
        assert 'components/DispatcharrTask.brs' not in package.namelist()
    with zipfile.ZipFile(production) as package:
        assert 'fixture-materials.json' not in package.namelist()
        assert package.read('source/PhoneSetupEntropy.brs') == (root / 'source/PhoneSetupEntropy.brs').read_bytes()
    entropy = (root / 'source/PhoneSetupEntropy.brs').read_text()
    assert 'function phoneSetupRandomBytes(count as integer) as dynamic\\n    return invalid\\nend function' in entropy
    assert 'fixture-materials' not in entropy
    assert '"task_"' not in (root / 'components/PhoneSetupTask.brs').read_text()
    config = (root / 'bsconfig.json').read_text()
    assert 'tests/native' not in config
print('isolated')
`], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /isolated/);
});
