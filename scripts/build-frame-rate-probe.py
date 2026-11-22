"""Build an isolated 25/50/60-fps Roku probe from the verified local package.

Inputs and output live in ignored out/. This never edits the normal ZIP,
contacts a provider, or alters display preferences.
"""
import argparse
from pathlib import Path
import re
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument("--transport", choices=("mp4", "ts"), default="mp4")
parser.add_argument("--first-rate", choices=(24, 25, 50), type=int, default=50)
parser.add_argument("--output", help="Unique ZIP path under out/ (defaults to the historical probe name)")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
out = root / "out"
samples = [out / f"frame-rate-{fps}.{args.transport}" for fps in (args.first_rate, 60)]
for sample in samples:
    if not sample.is_file() or not 1024 < sample.stat().st_size < 10_000_000:
        raise SystemExit(f"Missing or oversized synthetic sample: {sample.name}")

with zipfile.ZipFile(out / "aeriotv-roku.zip") as source:
    name = f"frame-rate-{args.first_rate}-probe.zip" if args.first_rate != 50 else (
        "frame-rate-probe.zip" if args.transport == "mp4" else "frame-rate-ts-probe.zip"
    )
    output = (root / args.output).resolve() if args.output else out / name
    if not output.is_relative_to(out.resolve()) or output.suffix != ".zip":
        parser.error("output must be a ZIP under out/")
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Missing package version")
                data = data.replace(match[0], b"build_version=" + str(int(match[1]) + 1).encode(), 1)
            if entry.filename == "source/Main.brs":
                original = b'screen.createScene("AerioScene")'
                if data.count(original) != 1:
                    raise SystemExit("Unexpected main scene")
                data = data.replace(original, b'screen.createScene("FrameRateProbe")', 1)
            target.writestr(entry, data)
        for extension in ("xml", "brs"):
            name = f"FrameRateProbe.{extension}"
            data = (root / "tests/native" / name).read_bytes()
            if extension == "brs":
                data = data.replace(b"frame-rate-50.mp4", f"frame-rate-{args.first_rate}.{args.transport}".encode())
                data = data.replace(b"frame-rate-60.mp4", f"frame-rate-60.{args.transport}".encode())
                if args.first_rate != 50:
                    data = data.replace(b'm.phase = "50"', f'm.phase = "{args.first_rate}"'.encode())
                if args.transport == "ts":
                    data = data.replace(b'content.streamFormat = "mp4"', b'content.streamFormat = "ts"\n    content.live = true')
            target.writestr(f"components/{name}", data)
        for sample in samples:
            target.write(sample, f"fixtures/{sample.name}")
print(f"Built isolated synthetic {args.transport} frame-rate probe: {output.name}")
