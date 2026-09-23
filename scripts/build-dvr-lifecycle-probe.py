"""Build a single-use short-recording fixture only in ignored out/."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent.parent
fixture = (root / "tests/native/DvrLifecycleProbe.brs").read_bytes()
with zipfile.ZipFile(root / "out/aeriotv-roku.zip") as source:
    with zipfile.ZipFile(root / "out/dvr-lifecycle.zip", "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Missing package version")
                data = data.replace(match[0], b"build_version=" + str(int(match[1]) + 1).encode(), 1)
            if entry.filename == "components/AerioScene.xml":
                data = data.replace(b"<children>", b'<script type="text/brightscript" uri="DvrLifecycleProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    installDvrLifecycleProbe()", 1)
            target.writestr(entry, data)
        target.writestr("components/DvrLifecycleProbe.brs", fixture)
print("Built single-use disposable DVR lifecycle fixture in ignored out/")
