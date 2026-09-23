"""Build a temporary, single-schedule DVR task probe in ignored out/.

The fixture is excluded from the normal package. It uses the already signed-in
Roku session and never exports credentials, hostnames or program labels.
"""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parent.parent
archive = root / "out/aeriotv-roku.zip"
fixture = (root / "tests/native/DvrRecordingProbe.brs").read_bytes()
probe_version = None
with zipfile.ZipFile(archive) as source:
    with zipfile.ZipFile(root / "out/dvr-probe.zip", "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Normal package manifest has no build version")
                probe_version = int(match[1]) + 1
                data = data.replace(match[0], b"build_version=" + str(probe_version).encode(), 1)
            if entry.filename == "components/AerioScene.xml":
                data = data.replace(b"<children>", b'<script type="text/brightscript" uri="DvrRecordingProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    installDvrRecordingProbe()", 1)
            target.writestr(entry, data)
        target.writestr("components/DvrRecordingProbe.brs", fixture)
print("Built isolated DVR probe package (build " + str(probe_version) + "); reinstall a newer normal build afterward")
