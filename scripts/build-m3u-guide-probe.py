"""Build an isolated Roku direct-M3U/guide probe from the verified app ZIP."""

import os
from pathlib import Path
import re
import urllib.parse
import zipfile


root = Path(__file__).resolve().parent.parent
playlist = os.environ["M3U_FEED_URL"]
guide = os.environ["XMLTV_FEED_URL"]
mode = os.environ.get("M3U_PROBE_MODE", "m3u")
if mode not in ("m3u", "dispatcharr-override", "api-key-override", "api-key-default"):
    raise SystemExit("Probe mode must be m3u, dispatcharr-override, api-key-override or api-key-default")
api_key = os.environ.get("DISPATCHARR_API_KEY", "") if mode.startswith("api-key-") else ""
if mode.startswith("api-key-") and (not api_key or not api_key.isascii() or not api_key.isprintable() or len(api_key) > 128):
    raise SystemExit("A printable, session-only Dispatcharr API key is required")
for value in (playlist, guide):
    if not re.fullmatch(r"https?://[^/?#@\s]+/[^?#\s]*", value):
        raise SystemExit("Probe requires plain credential-free feed URLs")
referer = urllib.parse.urlsplit(playlist)
origin = f"{referer.scheme}://{referer.netloc}"


def expression(value):
    return " + ".join(f"chr({byte})" for byte in value.encode("utf-8"))


template = (root / "tests/native/M3uGuideProbe.brs").read_text()
for marker, value in {"__PLAYLIST__": playlist, "__XMLTV__": guide, "__REFERER__": origin, "__MODE__": mode}.items():
    if template.count(marker) != 1:
        raise SystemExit("Probe template marker changed")
    template = template.replace(marker, expression(value))
if template.count("__KEY__") != 1:
    raise SystemExit("API-key template marker changed")
template = template.replace("__KEY__", expression(api_key) if api_key else '""')

with zipfile.ZipFile(root / "out/aeriotv-roku.zip") as archive:
    with zipfile.ZipFile(root / "out/m3u-guide-probe.zip", "w", zipfile.ZIP_DEFLATED) as output:
        for entry in archive.infolist():
            data = archive.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                original = b"<children>"
                if data.count(original) != 1:
                    raise SystemExit("Scene insertion point changed")
                data = data.replace(original, b'<script type="text/brightscript" uri="M3uGuideProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                original = b'if m.baseUrl <> "" and m.apiKey <> "" then connectServer()'
                if data.count(original) != 1:
                    raise SystemExit("Startup insertion point changed")
                data = data.replace(original, b'startNativeM3uGuideProbe()', 1)
            output.writestr(entry, data)
        output.writestr("components/M3uGuideProbe.brs", template)
print("Built disposable direct-feed probe under out/")
