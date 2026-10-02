"""Package an isolated OnDemandPlayer HLS control probe under ignored out/."""
import argparse
import ipaddress
from pathlib import Path
import re
from urllib.parse import urlsplit
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument("--completed", action="store_true")
parser.add_argument("--native-controls", action="store_true", help="test Roku native HLS controls without the Aerio player")
parser.add_argument("--status-handoff", action="store_true", help="exercise actual DVR status Task and playback handoff against a local fixture")
parser.add_argument("--media-url", required=True)
parser.add_argument("--output-name", default="", help="new ZIP name under ignored out/")
args = parser.parse_args()
if args.completed and (args.native_controls or args.status_handoff) or (args.native_controls and args.status_handoff):
    parser.error("Native-controls and status-handoff probes each require a growing HLS fixture")
address = urlsplit(args.media_url)
try:
    local_host = ipaddress.ip_address(address.hostname or "")
except ValueError as error:
    raise SystemExit("Fixture URL must use a private IP address") from error
expected_suffix = ".mp4" if args.completed else ".m3u8"
if (address.scheme != "http" or not local_host.is_private or not address.port
        or address.username or address.password or address.query or address.fragment
        or not address.path.endswith(expected_suffix) or len(args.media_url) > 200):
    raise SystemExit("Fixture must be a credential-free local HTTP MP4/HLS URL")
root = Path(__file__).resolve().parent.parent
out = root / "out"
package_name = "completed-controls-probe.zip" if args.completed else "growing-controls-probe.zip"
if args.output_name:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,60}\.zip", args.output_name):
        raise SystemExit("Output name must be a simple lowercase ZIP name")
    package_name = args.output_name
    if (out / package_name).exists():
        raise SystemExit("Refusing to overwrite an existing probe ZIP")
with zipfile.ZipFile(out / "aeriotv-roku.zip") as source:
    with zipfile.ZipFile(out / package_name, "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "manifest":
                match = re.search(rb"(?m)^build_version=(\d+)$", data)
                if match is None:
                    raise SystemExit("Missing package version")
                offset = 3 if args.status_handoff else (2 if args.completed else 1)
                data = data.replace(match[0], b"build_version=" + str(int(match[1]) + offset).encode(), 1)
                growing = b"false" if args.completed else b"true"
                format_name = b"mp4" if args.completed else b"hls"
                data += b"dvr_controls_fixture_url=" + args.media_url.encode("ascii") + b"\n"
                data += b"dvr_controls_fixture_format=" + format_name + b"\n"
                data += b"dvr_controls_fixture_growing=" + growing + b"\n"
                if args.native_controls:
                    data += b"dvr_controls_fixture_native=true\n"
            if entry.filename == "source/Main.brs":
                original = b'screen.createScene("AerioScene")'
                if data.count(original) != 1:
                    raise SystemExit("Unexpected main scene")
                scene = b"DvrStatusHandoffProbe" if args.status_handoff else b"GrowingControlsProbe"
                data = data.replace(original, b'screen.createScene("' + scene + b'")', 1)
            target.writestr(entry, data)
        for extension in ("brs", "xml"):
            name = f"{'DvrStatusHandoffProbe' if args.status_handoff else 'GrowingControlsProbe'}.{extension}"
            target.write(root / "tests/native" / name, f"components/{name}")
print("Built synthetic OnDemandPlayer control probe in ignored out/")
