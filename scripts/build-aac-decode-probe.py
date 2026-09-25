"""Build a disposable installed-app AAC retry fixture under ignored out/."""

from pathlib import Path
import zipfile


root = Path(__file__).resolve().parent.parent
with zipfile.ZipFile(root / "out/aeriotv-roku.zip") as source:
    with zipfile.ZipFile(root / "out/aac-decode-probe.zip", "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                data = data.replace(
                    b"<children>",
                    b'<script type="text/brightscript" uri="AacDecodeProbe.brs" /><children>',
                    1,
                )
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    installAacDecodeProbe()", 1)
            target.writestr(entry, data)
        target.writestr(
            "components/AacDecodeProbe.brs", (root / "tests/native/AacDecodeProbe.brs").read_bytes()
        )
print("Built out/aac-decode-probe.zip")
