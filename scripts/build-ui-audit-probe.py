"""Isolated on-device UI gallery: production renderers, synthetic data, no app init."""
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent
output = ROOT / "out/ui-audit-probe.zip"
with zipfile.ZipFile(ROOT / "out/aeriotv-roku.zip") as source, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
    for name in source.namelist():
        data = source.read(name)
        if name == "source/Main.brs":
            data = (ROOT / "tests/native/UiAuditMain.brs").read_bytes()
        elif name == "components/AerioScene.brs":
            text = data.decode()
            text, count = re.subn(r"(?ms)^sub init\(\).*?^end sub", "sub init()\n    initUiAudit()\nend sub", text, count=1)
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
        elif name == "source/MetadataCacheStore.brs":
            data = data.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/ui-audit-cache"')
        target.writestr(name, data)
    target.write(ROOT / "tests/native/UiAuditProbe.brs", "components/SetupReceiverProbeUiAudit.brs")
    target.write(ROOT / "tests/native/UiAuditPhone.brs", "components/UiAuditPhone.brs")
    target.write(ROOT / "tests/native/UiAuditSettings.brs", "components/UiAuditSettings.brs")
print(output)
