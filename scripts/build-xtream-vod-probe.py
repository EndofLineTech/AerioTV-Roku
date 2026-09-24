"""Build a disposable native VOD probe ZIP; credentials come only from env.

The generated ZIP lives under ignored out/ and must be replaced on the device
with the normal package and removed locally after use. No registry writes.
"""

import os
from pathlib import Path
import re
import zipfile


root = Path(__file__).resolve().parent.parent
source = root / "out/aeriotv-roku.zip"
target = root / "out/xtream-vod-probe.zip"
values = {
    "__PROBE_BASE__": os.environ["XTREAM_BASE_URL"],
    "__PROBE_USER__": os.environ["XTREAM_USERNAME"],
    "__PROBE_PASSWORD__": os.environ["XTREAM_PASSWORD"],
    "__PROBE_KIND__": os.environ.get("XTREAM_PROBE_KIND", "movie"),
}
if values["__PROBE_KIND__"] not in ("movie", "series", "auth-denied", "cancel"):
    raise SystemExit("Probe kind must be movie, series, auth-denied or cancel")
if not re.fullmatch(r"https?://[^/?#@\s]+", values["__PROBE_BASE__"]):
    raise SystemExit("Probe requires a plain http(s) server origin")
if any(not value.isascii() or not value.isprintable() or not value for value in values.values()):
    raise SystemExit("Probe credentials must be nonempty printable ASCII")


def expression(value):
    # Numeric character expressions avoid showing a credential in a compiler
    # source-line diagnostic. The archive is still sensitive until removed.
    return " + ".join(f"chr({byte})" for byte in value.encode("ascii"))


probe = (root / "tests/native/XtreamVodProbe.brs").read_text()
for marker, value in values.items():
    if probe.count(marker) != 1:
        raise SystemExit("Probe template marker missing or duplicated")
    probe = probe.replace(marker, expression(value))

with zipfile.ZipFile(source) as archive:
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as output:
        for entry in archive.infolist():
            data = archive.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                original = b"<children>"
                if data.count(original) != 1:
                    raise SystemExit("Scene script insertion point changed")
                data = data.replace(original, b'<script type="text/brightscript" uri="XtreamVodProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                original = b'if m.baseUrl <> "" and m.apiKey <> "" then connectServer()'
                if data.count(original) != 1:
                    raise SystemExit("Startup insertion point changed")
                data = data.replace(original, b'startNativeXtreamVodProbe()', 1)
            output.writestr(entry, data)
        output.writestr("components/XtreamVodProbe.brs", probe)
print("Built disposable Xtream VOD probe under out/ (contains session credentials)")
