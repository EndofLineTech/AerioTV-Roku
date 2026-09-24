"""Package an isolated, credential-free native XMLTV file/fragment probe."""
import os
import json
import gzip
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent.parent
with zipfile.ZipFile(root / "out/aeriotv-roku.zip") as source:
    with zipfile.ZipFile(root / "out/xmltv-probe.zip", "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                scripts = b'<script type="text/brightscript" uri="XmltvProbe.brs" />'
                data = data.replace(b"<children>", scripts + b"<children>", 1)
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    runXmltvProbe()", 1)
            target.writestr(entry, data)
        scene_probe = (root / "tests/native/XmltvProbe.brs").read_bytes()
        feed_url = os.environ.get("XMLTV_FEED_URL", "")
        if feed_url:
            if not feed_url.startswith(("http://", "https://")) or any(c in feed_url for c in "?#@\n\r"):
                raise SystemExit("Invalid probe feed URL")
            insertion = f'm.xmltvProbeTask.feedUrl = {json.dumps(feed_url)}\n    '.encode()
            scene_probe = scene_probe.replace(b'm.xmltvProbeTask.control = "RUN"', insertion + b'm.xmltvProbeTask.control = "RUN"', 1)
        target.writestr("components/XmltvProbe.brs", scene_probe)
        target.writestr("components/XmltvProbeTask.xml", (root / "tests/native/XmltvProbeTask.xml").read_bytes())
        target.writestr("components/XmltvProbeTask.brs", (root / "tests/native/XmltvProbeTask.brs").read_bytes())
        fixture = (root / "tests/native/XmltvProbeFixture.txt").read_bytes()
        target.writestr("data/xmltv-probe.txt", fixture)
        target.writestr("data/xmltv-probe.gz", gzip.compress(fixture, mtime=0))
print("Built out/xmltv-probe.zip")
