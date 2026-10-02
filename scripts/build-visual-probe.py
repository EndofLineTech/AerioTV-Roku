"""Build an isolated screen-capture fixture from the verified application ZIP."""
import argparse
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('screen', choices=['settings', 'vod', 'vod-data', 'dvr-sections', 'epg-details', 'pills', 'lavender', 'light', 'large', 'large-vod', 'large-guide-options', 'welcome'])
parser.add_argument('--output', default='out/visual-probe.zip', help='Disposable ZIP path under out/')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = (root / args.output).resolve()
if not output.is_relative_to((root / 'out').resolve()) or output.suffix != '.zip':
    parser.error('output must be a ZIP under out/')
with zipfile.ZipFile(root / 'out/aeriotv-roku.zip') as source:
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == 'components/AerioScene.xml':
                data = data.replace(b'<children>', b'<script type="text/brightscript" uri="VisualProbe.brs" /><children>', 1)
            if entry.filename == 'components/AerioScene.brs':
                data = data.replace(b'sub init()', f'sub init()\n    m.visualProbeScreen = "{args.screen}"\n    installVisualProbe()'.encode(), 1)
            if entry.filename in ('components/VodView.xml', 'components/DvrView.xml') and args.screen in ('vod-data', 'dvr-sections'):
                name = 'Vod' if entry.filename == 'components/VodView.xml' else 'Dvr'
                if (args.screen == 'vod-data' and name == 'Vod') or (args.screen == 'dvr-sections' and name == 'Dvr'):
                    data = data.replace(b'</interface>', b'<function name="seedVisualProbe" /></interface>', 1)
                    data = data.replace(b'<children>', f'<script type="text/brightscript" uri="{name}VisualProbe.brs" /><children>'.encode(), 1)
            target.writestr(entry, data)
        target.writestr('components/VisualProbe.brs', (root / 'tests/native/VisualProbe.brs').read_bytes())
        if args.screen == 'vod-data':
            target.writestr('components/VodVisualProbe.brs', (root / 'tests/native/VodVisualProbe.brs').read_bytes())
        if args.screen == 'dvr-sections':
            target.writestr('components/DvrVisualProbe.brs', (root / 'tests/native/DvrVisualProbe.brs').read_bytes())
print('Built disposable visual probe for', args.screen)
