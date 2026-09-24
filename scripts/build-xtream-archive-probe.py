"""Build a disposable Roku XC archive probe using a real completed EPG entry.

Credentials are environment-only and appear only as numeric expressions inside
the ignored out/ ZIP. Restore the normal app and remove the ZIP after the probe.
"""

import json
import os
from pathlib import Path
import re
import time
import urllib.parse
import urllib.request
import zipfile


root = Path(__file__).resolve().parent.parent
base = os.environ["XTREAM_BASE_URL"].rstrip("/")
username = os.environ["XTREAM_USERNAME"]
password = os.environ["XTREAM_PASSWORD"]
if not re.fullmatch(r"https?://[^/?#@\s]+", base):
    raise SystemExit("Plain Xtream server origin required")
if any(not value or not value.isascii() or not value.isprintable() for value in (username, password)):
    raise SystemExit("Printable nonempty Xtream credentials required")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


opener = urllib.request.build_opener(NoRedirect)


def get(action, **params):
    query = urllib.parse.urlencode({"username": username, "password": password, "action": action, **params})
    request = urllib.request.Request(base + "/player_api.php?" + query)
    with opener.open(request, timeout=20) as response:
        body = response.read(4 * 1024 * 1024 + 1)
        if len(body) > 4 * 1024 * 1024:
            raise SystemExit("XC response exceeds the bounded native budget")
        return json.loads(body)


channels = get("get_live_streams")
if not isinstance(channels, list):
    raise SystemExit("Live channels unavailable")
selected = None
for row in channels:
    if str(row.get("tv_archive")) != "1" or not int(row.get("tv_archive_duration") or 0):
        continue
    epg = get("get_simple_data_table", stream_id=row["stream_id"])
    if not isinstance(epg, dict) or not isinstance(epg.get("epg_listings"), list):
        continue
    now = int(time.time())
    eligible = [
        item for item in epg["epg_listings"]
        if str(item.get("has_archive")) == "1"
        and int(item.get("stop_timestamp") or 0) < now - 600
        and 600 <= int(item.get("stop_timestamp") or 0) - int(item.get("start_timestamp") or 0) <= 14400
        and int(item.get("start_timestamp") or 0) >= now - int(row["tv_archive_duration"]) * 86400
    ]
    if eligible:
        selected = (row, eligible[-1])
        break
if selected is None:
    raise SystemExit("No currently advertised, completed archive fixture")


def expression(value):
    return " + ".join(f"chr({byte})" for byte in value.encode("ascii"))


channel, programme = selected
template = (root / "tests/native/XtreamArchiveProbe.brs").read_text()
replacements = {
    "__BASE__": expression(base),
    "__USER__": expression(username),
    "__PASSWORD__": expression(password),
    "__CHANNEL_ID__": str(int(channel["stream_id"])),
    "__DAYS__": str(min(30, int(channel["tv_archive_duration"]))),
    "__START__": str(int(programme["start_timestamp"])),
    "__END__": str(int(programme["stop_timestamp"])),
}
for marker, value in replacements.items():
    if template.count(marker) != 1:
        raise SystemExit("Archive probe template changed")
    template = template.replace(marker, value)

source = root / "out/aeriotv-roku.zip"
target = root / "out/xtream-archive-probe.zip"
with zipfile.ZipFile(source) as archive:
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as output:
        for entry in archive.infolist():
            data = archive.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                original = b"<children>"
                if data.count(original) != 1:
                    raise SystemExit("Scene insertion point changed")
                data = data.replace(original, b'<script type="text/brightscript" uri="XtreamArchiveProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                original = b'if m.baseUrl <> "" and m.apiKey <> "" then connectServer()'
                if data.count(original) != 1:
                    raise SystemExit("Startup insertion point changed")
                data = data.replace(original, b'startNativeXtreamArchiveProbe()', 1)
            output.writestr(entry, data)
        output.writestr("components/XtreamArchiveProbe.brs", template)
print("Built disposable archive probe with one advertised completed programme")
