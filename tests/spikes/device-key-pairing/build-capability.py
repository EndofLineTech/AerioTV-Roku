"""Build a disposable no-registry/no-network device-crypto measurement."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[3]
source = (Path(__file__).parent / 'CapabilityProbe.brs').read_bytes()
assert b'roRegistry' not in source and b'roUrlTransfer' not in source
output = root / 'out/entropy-capability-probe.zip'
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
    package.writestr('manifest', 'title=Aerio Entropy Capability Probe\nmajor_version=0\nminor_version=0\nbuild_version=2\nui_resolutions=fhd\nrsg_version=1.3\n')
    package.writestr('source/Main.brs', source)
    package.write(root / 'tests/native/PhoneSetupProbe.xml', 'components/PhoneSetupProbe.xml')
print('Built disposable capability probe')
