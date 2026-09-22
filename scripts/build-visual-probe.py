"""Build an isolated screen-capture fixture from the verified application ZIP."""
import argparse
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('screen', choices=['settings', 'vod', 'pills', 'lavender', 'light'])
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
with zipfile.ZipFile(root / 'out/aeriotv-roku.zip') as source:
    with zipfile.ZipFile(root / 'out/visual-probe.zip', 'w', zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == 'components/AerioScene.xml':
                data = data.replace(b'<children>', b'<script type="text/brightscript" uri="VisualProbe.brs" /><children>', 1)
            if entry.filename == 'components/AerioScene.brs':
                data = data.replace(b'sub init()', f'sub init()\n    m.visualProbeScreen = "{args.screen}"\n    installVisualProbe()'.encode(), 1)
            target.writestr(entry, data)
        target.writestr('components/VisualProbe.brs', (root / 'tests/native/VisualProbe.brs').read_bytes())
print('Built out/visual-probe.zip for', args.screen)
