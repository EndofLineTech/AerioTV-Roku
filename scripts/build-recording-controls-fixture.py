"""Inject a one-shot, owner-approved DVR fixture hook into an ignored ZIP."""
import argparse
from pathlib import Path
import re
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument("--approved", action="store_true", help="Confirm owner approval for one disposable server recording")
args = parser.parse_args()
if not args.approved:
    parser.error("owner approval is required before building the one-shot server fixture")
root = Path(__file__).resolve().parent.parent
out = root / "out"
hook = (root / "tests/native/RecordingControlsFixture.brs").read_bytes()
with zipfile.ZipFile(out / "aeriotv-roku.zip") as source:
    with zipfile.ZipFile(out / "recording-controls-fixture.zip", "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Missing package version")
                data = data.replace(match[0], b"build_version=" + str(int(match[1]) + 3).encode(), 1)
            if entry.filename == "components/AerioScene.xml":
                anchor = b"  <children>"
                if data.count(anchor) != 1:
                    raise SystemExit("Unexpected scene XML")
                data = data.replace(anchor, b'  <script type="text/brightscript" uri="RecordingControlsFixture.brs" />\n' + anchor, 1)
            if entry.filename == "components/AerioScene.brs":
                anchor = b"    if m.baseUrl <> \"\" and m.apiKey <> \"\" then connectServer()\nend sub"
                if data.count(anchor) != 1:
                    raise SystemExit("Unexpected scene startup")
                data = data.replace(anchor, anchor.replace(b"\nend sub", b"\n    installRecordingControlsFixture()\nend sub"), 1)
            target.writestr(entry, data)
        target.writestr("components/RecordingControlsFixture.brs", hook)
print("Built one-shot DVR fixture ZIP in ignored out/")
