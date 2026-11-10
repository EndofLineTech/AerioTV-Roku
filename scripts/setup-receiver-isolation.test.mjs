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

test('apply probe cannot contact a provider or open the application registry', () => {
  const result = spawnSync('python3', ['-c', `
import importlib.util, pathlib, tempfile, zipfile
root = pathlib.Path.cwd()
spec = importlib.util.spec_from_file_location('apply_probe', root / 'scripts/build-setup-apply-probe.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    path = module.build(pathlib.Path(directory) / 'probe.zip')
    with zipfile.ZipFile(path) as package:
        assert 'apply-cases.json' in package.namelist()
        assert 'fixture-materials.json' not in package.namelist()
        assert package.read('source/PhoneSetupEntropy.brs') == (root / 'source/PhoneSetupEntropy.brs').read_bytes()
        for name in ['DispatcharrTask', 'M3uTask', 'XtreamTask']:
            assert b'SetupApplyFixtureTask.brs' in package.read('components/' + name + '.xml')
        for name in package.namelist():
            if name.endswith('.brs'):
                source = package.read(name).lower()
                assert b'createobject("roregistrysection"' not in source
                assert b'createobject("rourltransfer"' not in source
print('isolated')
`], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /isolated/);
});

test('HTTP apply probe keeps real Tasks intact and isolates fixture listener/cache', () => {
  const result = spawnSync('python3', ['-c', `
import importlib.util, pathlib, tempfile, zipfile
root = pathlib.Path.cwd()
spec = importlib.util.spec_from_file_location('apply_probe', root / 'scripts/build-setup-apply-probe.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as directory:
    path = module.build(pathlib.Path(directory) / 'http.zip', real_http=True)
    with zipfile.ZipFile(path) as package:
        for name in ['DispatcharrTask', 'M3uTask', 'XtreamTask', 'GuideTask']:
            for extension in ['brs', 'xml']:
                relative = 'components/' + name + '.' + extension
                assert package.read(relative) == (root / relative).read_bytes()
        assert 'components/SetupApplyFixtureTask.brs' not in package.namelist()
        server = package.read('components/SetupApplyFixtureHttpTask.brs')
        assert b'setAddress("127.0.0.1:0")' in server
        cache = package.read('source/MetadataCacheStore.brs')
        assert b'cachefs:/aeriotv-metadata-v1' not in cache
        assert b'tmp:/setup-apply-http-cache' in cache
        assert package.read('source/PhoneSetupEntropy.brs') == (root / 'source/PhoneSetupEntropy.brs').read_bytes()
        for name in package.namelist():
            if name.endswith('.brs'):
                assert b'createobject("roregistrysection"' not in package.read(name).lower()
print('isolated')
`], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /isolated/);
});
