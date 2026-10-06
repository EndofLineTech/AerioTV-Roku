"""Repeat Roku guide launches and record only aggregate EPG timing markers.

No account values, provider URLs, raw console lines or screenshots are retained.
The device must already have a saved authorized connection in the dev slot.
"""

import argparse
import json
import os
import re
import socket
import statistics
import time
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


MARKERS = {
    "[guide-paint] first-grid-ms=": "grid",
    "[guide-paint] first-program-ms=": "program",
    "[guide-logos] initial-prefetch=": "logo_count",
    "[guide-logos] first-asset-ms=": "logo_file",
    "[guide-logos] initial-batch-ready=": "logo_batch",
    "[guide-logos] first-poster-ready-ms=": "logo_first_poster",
    "[guide-logos] visible-posters-ready=": "logo_all_posters",
    "[startup] authorized lineup ms=": "lineup",
    "[guide-mapping] source=": "mapping",
    "[guide-cache] source=": "window",
}


def ecp(opener, host, path, post=False):
    url = f"http://{host}:8060/{path}"
    request = urllib.request.Request(url, data=b"" if post else None, method="POST" if post else "GET")
    with opener.open(request, timeout=8) as response:
        return response.read(1024 * 1024)


def device_state(opener, host):
    device = ET.fromstring(ecp(opener, host, "query/device-info"))
    active = ET.fromstring(ecp(opener, host, "query/active-app"))
    app = active.find("app")
    return {"uptime": int(device.findtext("uptime", "0")), "app": app.get("id") if app is not None else "", "version": app.get("version") if app is not None else ""}


def sample(sock, seconds, started, result):
    pending = b""
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            chunk = sock.recv(65536)
            if not chunk:
                break
            pending += chunk
        except socket.timeout:
            continue
        if len(pending) > 131072:
            pending = pending[-65536:]
        while b"\n" in pending:
            raw, pending = pending.split(b"\n", 1)
            line = raw.decode("utf-8", "replace")
            if "ERROR:" in line:
                result["runtime_error_count"] = result.get("runtime_error_count", 0) + 1
            if "AppLaunchComplete" in line and "launch" not in result:
                result["launch"] = round(time.monotonic() - started, 2)
            for prefix, key in MARKERS.items():
                if prefix not in line:
                    continue
                source = re.search(r"source=(cache|network)", line)
                field = {
                    "grid": "first-grid-ms", "program": "first-program-ms",
                    "logo_count": "initial-prefetch", "logo_file": "first-asset-ms",
                    "logo_batch": "elapsed_ms", "logo_first_poster": "first-poster-ready-ms",
                    "logo_all_posters": "elapsed_ms", "lineup": "ms", "mapping": "ms-after-lineup",
                    "window": "ms-after-lineup",
                }[key]
                value = re.search(r"(?:^|\s)" + re.escape(field) + r"=\s*(\d+)", line)
                if key in ("window",):
                    result.setdefault(key, []).append({"ms": int(value.group(1)) if value else None, "source": source.group(1) if source else None})
                elif key not in result:
                    result[key] = {"ms": int(value.group(1)) if value else None, "source": source.group(1) if source else None}
                    if key == "program":
                        result[key]["first_has_category"] = "has-category= true" in line
                        result[key]["first_focused"] = "focused= true" in line


def run(opener, host, duration):
    sock = socket.create_connection((host, 8085), 5)
    sock.settimeout(0.1)
    try:
        sample(sock, 0.3, time.monotonic(), {})  # Drain the prior app session.
        ecp(opener, host, "keypress/Home", True)
        time.sleep(1)
        result = {}
        started = time.monotonic()
        ecp(opener, host, "launch/dev", True)
        sample(sock, duration, started, result)
        result["state"] = device_state(opener, host)
        return result
    finally:
        sock.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=4)
    parser.add_argument("--duration", type=int, default=12)
    parser.add_argument("--output", default="out/guide-first-paint-timings.json")
    args = parser.parse_args()
    if args.runs < 1 or args.runs > 12 or args.duration < 5 or args.duration > 40:
        parser.error("runs must be 1-12 and duration 5-40 seconds")
    output = Path(args.output)
    if len(output.parts) < 2 or output.parts[0] != "out" or ".." in output.parts or output.suffix != ".json":
        parser.error("output must be a JSON file under ignored out/")
    host = os.environ["ROKU_HOST"]
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    results = []
    for index in range(args.runs):
        result = run(opener, host, args.duration)
        results.append(result)
        print(f"run {index + 1}: {json.dumps(result, sort_keys=True)}", flush=True)
    summary = {}
    for key in ("grid", "program", "logo_file", "logo_batch", "logo_first_poster", "logo_all_posters"):
        values = [item[key]["ms"] for item in results if item.get(key, {}).get("ms") is not None]
        if values:
            summary[key] = {"median_ms": statistics.median(values), "min_ms": min(values), "max_ms": max(values), "samples": len(values)}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"runs": results, "summary": summary}, indent=2) + "\n")
    print("summary:", json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
