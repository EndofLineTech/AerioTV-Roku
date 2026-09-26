"""Package an isolated native VOD registry probe in ignored out/."""
import argparse
from pathlib import Path
import re
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument("--revision", choices=(0, 1), type=int, default=0)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
out = root / "out"
package_name = "vod-retention-probe.zip" if args.revision == 0 else "vod-retention-relaunch.zip"
with zipfile.ZipFile(out / "aeriotv-roku.zip") as source:
    with zipfile.ZipFile(out / package_name, "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Missing package version")
                data = data.replace(match[0], b"build_version=" + str(int(match[1]) + 1 + args.revision).encode(), 1)
            if entry.filename == "source/Main.brs":
                original = b'screen.createScene("AerioScene")'
                if data.count(original) != 1:
                    raise SystemExit("Unexpected main scene")
                data = data.replace(original, b'screen.createScene("VodRetentionProbe")', 1)
            target.writestr(entry, data)
        for extension in ("brs", "xml"):
            name = f"VodRetentionProbe.{extension}"
            target.write(root / "tests/native" / name, f"components/{name}")
print("Built isolated VOD retention probe in ignored out/")
