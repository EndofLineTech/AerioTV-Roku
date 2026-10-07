"""Overlay the exact existing ZIP with a temporary, token-redacted Roku probe."""
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
with zipfile.ZipFile(source_path) as source:
    with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                data = data.replace(b"<children>", b'<script type="text/brightscript" uri="HlsDisconnectProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    installHlsDisconnectProbe()", 1)
            target.writestr(entry, data)
        for name in ("HlsDisconnectProbe.brs", "HlsDisconnectProbeTask.brs", "HlsDisconnectProbeTask.xml"):
            target.writestr(f"components/{name}", (root / "tests/native" / name).read_bytes())
print("Disposable HLS disconnect probe built")
