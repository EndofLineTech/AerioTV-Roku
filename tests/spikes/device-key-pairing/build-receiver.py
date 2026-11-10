"""Disposable standalone receiver experiment; never modifies production source."""
import importlib.util
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('receiver', root / 'scripts/build-setup-receiver-probe.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
base = module.build(root / 'out/devicecrypto-experiment-base.zip', production_entropy=True)
production = (root / 'source/PhoneSetupEntropy.brs').read_text()
start = production.index('function phoneSetupRandomBytes(')
end = production.index('end function', start) + len('end function')
replacement = (Path(__file__).parent / 'ExperimentalEntropy.brs').read_text()
entropy = production[:start] + replacement + production[end:]
output = root / 'out/devicecrypto-receiver-experiment.zip'
with zipfile.ZipFile(base) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
    for name in original.namelist():
        data = original.read(name)
        if name == 'source/PhoneSetupEntropy.brs':
            data = entropy.encode()
        if name == 'components/SetupReceiverProbe.xml':
            data = data.replace(b'SYNTHETIC TEST KEYS', b'EXPERIMENTAL DEVICE-KEY SOURCE')
        if name == 'components/PhoneSetupTask.brs':
            marker = b'sub phoneSetupPublishReady()\n'
            assert data.count(marker) == 1
            data = data.replace(marker, marker + b'    print "[setup-receiver] "; formatJson({kind: "key_encoding", lowercase: m.material.privateHex = lcase(m.material.privateHex)})\n')
        package.writestr(name, data)
with zipfile.ZipFile(output) as package:
    assert 'fixture-materials.json' not in package.namelist()
    assert package.read('components/PhoneSetupTask.xml') == (root / 'components/PhoneSetupTask.xml').read_bytes()
    for name in ['PhoneSetupCrypto', 'PhoneSetupX25519', 'PhoneSetupModel']:
        assert package.read(f'source/{name}.brs') == (root / f'source/{name}.brs').read_bytes()
print('Built isolated device-key receiver experiment; production entropy file unchanged')
