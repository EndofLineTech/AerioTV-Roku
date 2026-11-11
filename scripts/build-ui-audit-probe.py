"""Isolated on-device UI gallery: production renderers, synthetic data, no app init."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def isolate_entry(name, data):
    if name == "source/Main.brs":
        data = (ROOT / "tests/native/UiAuditMain.brs").read_bytes()
    elif name == "components/AerioScene.brs":
        text, count = re.subn(r"(?ms)^sub init\(\).*?^end sub", "sub init()\n    initUiAudit()\nend sub", data.decode(), count=1)
        assert count == 1
        assert text.count('function onKeyEvent(key as string, press as boolean) as boolean') == 1
        text = text.replace('function onKeyEvent(key as string, press as boolean) as boolean', 'function unusedApplicationKeyEvent(key as string, press as boolean) as boolean')
        data = text.encode()
    elif name == "components/AerioScene.xml":
        data = data.replace(b'</interface>', b'<field id="auditScreen" type="string" alwaysNotify="true" onChange="showUiAudit" /><field id="auditCheck" type="string" alwaysNotify="true" onChange="uiAuditCheck" /></interface>', 1)
        data = data.replace(b'<children>', b'<script type="text/brightscript" uri="SetupReceiverProbeUiAudit.brs" /><children>', 1)
    elif name == "components/PhoneSetupView.xml":
        data = data.replace(b'onChange="onSetupActive"', b'onChange="auditPhoneActive"')
        data = data.replace(b'</interface>', b'<function name="seedUiAuditPhone" /></interface>', 1)
        data = data.replace(b'<children>', b'<script type="text/brightscript" uri="UiAuditPhone.brs" /><children>', 1)
    elif name == "components/GuideView.xml":
        data = data.replace(b'</interface>', b'<function name="openPicker" /></interface>', 1)
    elif name == "components/SettingsHub.xml":
        data = data.replace(b'</interface>', b'<function name="seedUiAuditSettings" /></interface>', 1)
        data = data.replace(b'<children>', b'<script type="text/brightscript" uri="UiAuditSettings.brs" /><children>', 1)
    elif name in ["components/VodView.xml", "components/DvrView.xml"]:
        kind = "Vod" if name.endswith("/VodView.xml") else "Dvr"
        data = data.replace(b'</interface>', ('<function name="seedUiAudit' + kind + '" /><function name="uiAuditLibraryState" /></interface>').encode(), 1)
        data = data.replace(b'<children>', ('<script type="text/brightscript" uri="UiAudit' + kind + '.brs" /><children>').encode(), 1)
    elif name == "source/VodModel.brs":
        # Posters are otherwise a network path independent of Tasks.
        text, count = re.subn(r'(?ms)^function vodArtworkUrl\(.*?^end function', 'function vodArtworkUrl(base as string, item as object) as string\n    return "pkg:/images/channel-icon-hd.png"\nend function', data.decode(), count=1)
        assert count == 1
        data = text.encode()
    elif name == "source/MetadataCacheStore.brs":
        data = data.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/ui-audit-cache"')
    if name.endswith('.xml'):
        node = ET.fromstring(data)
        if node.get('extends') == 'Task':
            # Keep the production interface/callbacks, but not one byte of
            # executable provider, receiver, registry or mutation code.
            for script in list(node.findall('script')):
                node.remove(script)
            for uri in ['UiAuditLibraryData.brs', 'UiAuditFixtureTask.brs']:
                ET.SubElement(node, 'script', {'type': 'text/brightscript', 'uri': uri})
            data = ET.tostring(node, encoding='utf-8', xml_declaration=True)
    return data


def build(input_path, output):
    if Path(input_path).resolve() == Path(output).resolve():
        raise ValueError("Gallery output must not overwrite its base application")
    with zipfile.ZipFile(input_path) as source, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
        for name in source.namelist():
            target.writestr(name, isolate_entry(name, source.read(name)))
        target.write(ROOT / "tests/native/UiAuditProbe.brs", "components/SetupReceiverProbeUiAudit.brs")
        for name in ['UiAuditPhone', 'UiAuditSettings', 'UiAuditLibraryData', 'UiAuditFixtureTask', 'UiAuditVod', 'UiAuditDvr']:
            target.write(ROOT / ('tests/native/' + name + '.brs'), 'components/' + name + '.brs')
        target.writestr('ui-audit-build.json', json.dumps({'kind': 'isolated-ui-audit', 'syntheticTasksOnly': True, 'baseSha256': hashlib.sha256(Path(input_path).read_bytes()).hexdigest()}))
    return Path(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=ROOT / 'out/aeriotv-roku.zip')
    parser.add_argument('--output', type=Path, default=ROOT / 'out/ui-audit-probe.zip')
    args = parser.parse_args()
    print(build(args.input, args.output))
