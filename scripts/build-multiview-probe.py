"""Build isolated two-Video native capacity probe from the verified normal ZIP."""
import argparse
from pathlib import Path
import re
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--same-source", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
archive = root / "out/aeriotv-roku.zip"
probe_version = None
version_offset = 2 if args.same_source else 1
target_name = "multiview-same-source.zip" if args.same_source else "multiview-probe.zip"
with zipfile.ZipFile(archive) as source:
    with zipfile.ZipFile(root / "out" / target_name, "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Normal package manifest has no build version")
                probe_version = int(match[1]) + version_offset
                data = data.replace(match[0], b"build_version=" + str(probe_version).encode(), 1)
            if entry.filename == "components/AerioScene.xml":
                data = data.replace(b"<children>", b'<script type="text/brightscript" uri="MultiviewProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    installMultiviewProbe()", 1)
            target.writestr(entry, data)
        fixture = (root / "tests/native/MultiviewProbe.brs").read_bytes()
        if args.same_source:
            fixture = fixture.replace(b"second = livePlaybackDescriptor(m.baseUrl, channels[1])", b"second = first", 1)
            fixture = fixture.replace(b"started two-source trial", b"started same-source trial", 1)
        target.writestr("components/MultiviewProbe.brs", fixture)
        target.writestr("components/MultiviewHttpTask.xml", (root / "tests/native/MultiviewHttpTask.xml").read_bytes())
        target.writestr("components/MultiviewHttpTask.brs", (root / "tests/native/MultiviewHttpTask.brs").read_bytes())
print("Built isolated two-Video probe (build " + str(probe_version) + "); reinstall a newer normal build afterward")
