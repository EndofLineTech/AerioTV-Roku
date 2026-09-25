"""Sample numeric Roku ECP resource counters without retaining bitmap or account data.

Requires Developer Mode and an enabled ECP control policy. This is a read-only
collector: it does not launch apps, press remote keys, or alter Roku settings.
Output is restricted to the ignored out/ directory and contains no raw XML.
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import time
from urllib.error import HTTPError, URLError
from urllib.request import urlopen
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent


def _number(element, path):
    text = element.findtext(path)
    if text is None or not text.isdigit():
        raise ValueError("resource counter unavailable")
    return int(text)


def parse_chanperf(xml):
    root = ET.fromstring(xml)
    if root.findtext("status") != "OK":
        raise ValueError("app memory unavailable")
    for plugin in root.findall("plugin"):
        if plugin.findtext("id") == "dev":
            memory = plugin.find("memory")
            if memory is None:
                break
            return {
                "used_bytes": _number(memory, "used"),
                "resident_bytes": _number(memory, "res"),
                "swap_bytes": _number(memory, "swap"),
                "anonymous_bytes": _number(memory, "anon"),
                "file_bytes": _number(memory, "file"),
                "shared_bytes": _number(memory, "shared"),
                "memory_limit_bytes": _number(memory, "limit"),
            }
    raise ValueError("development app memory unavailable")


def parse_graphics(xml):
    root = ET.fromstring(xml)
    if root.findtext("status") != "OK":
        raise ValueError("graphics memory unavailable")
    instances = root.findall("graphics-instances/rographics")
    if not instances:
        raise ValueError("graphics counters unavailable")
    texture = 0
    instance_peak = 0
    maximum = 0
    system = 0
    bitmaps = 0
    for instance in instances:
        used = _number(instance, "texture-memory/used")
        texture += used
        instance_peak = max(instance_peak, used)
        maximum = max(maximum, _number(instance, "texture-memory/max"))
        value = instance.findtext("sytem-memory/used")
        if value is not None:
            system += _number(instance, "sytem-memory/used")
        bitmaps += len(instance.findall("bitmap"))
    return {
        "texture_bytes": texture, "texture_limit_bytes": maximum,
        "graphics_system_bytes": system, "bitmap_count": bitmaps,
        "graphics_instances": len(instances),
        "peak_instance_texture_bytes": instance_peak,
    }


def _get(host, path):
    with urlopen(f"http://{host}:8060/query/{path}", timeout=5) as response:
        return response.read(2 * 1024 * 1024)


def sample(host):
    return {**parse_chanperf(_get(host, "chanperf")),
            **parse_graphics(_get(host, "r2d2-bitmaps"))}


def summarize(samples):
    if not samples:
        return {}
    fields = ("used_bytes", "resident_bytes", "swap_bytes", "anonymous_bytes",
              "file_bytes", "shared_bytes", "texture_bytes",
              "graphics_system_bytes", "bitmap_count", "graphics_instances",
              "peak_instance_texture_bytes")
    return {"samples": len(samples), "duration_seconds": samples[-1]["elapsed_seconds"],
            "peak": {key: max(s[key] for s in samples) for key in fields},
            "final": {key: samples[-1][key] for key in fields},
            "memory_limit_bytes": samples[-1]["memory_limit_bytes"],
            "texture_limit_bytes": samples[-1]["texture_limit_bytes"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", required=True, choices=["cold", "warm", "guide", "retune", "sustain"])
    parser.add_argument("--duration", required=True, type=int, help="Seconds (1-2400)")
    parser.add_argument("--interval", type=int, default=2, help="Seconds (1-10)")
    parser.add_argument("--lineup-size", type=int, default=0, help="Known authorized channel count; 0 means unmeasured")
    parser.add_argument("--output", required=True, help="JSON filename under out/")
    args = parser.parse_args()
    if args.duration < 1 or args.duration > 2400 or args.interval < 1 or args.interval > 10:
        parser.error("duration must be 1-2400 seconds and interval 1-10 seconds")
    if args.lineup_size < 0:
        parser.error("lineup size cannot be negative")
    host = os.environ.get("ROKU_HOST", "")
    if not host:
        parser.error("ROKU_HOST is required")
    output = Path(args.output).resolve()
    if not output.is_relative_to(ROOT / "out") or output.suffix != ".json":
        parser.error("output must be a JSON file under out/")
    output.parent.mkdir(parents=True, exist_ok=True)
    started_utc = datetime.now(timezone.utc).isoformat()
    start = time.monotonic()
    samples = []
    failures = []
    while True:
        elapsed = round(time.monotonic() - start, 2)
        try:
            samples.append({"elapsed_seconds": elapsed, **sample(host)})
        except (ValueError, ET.ParseError, HTTPError, URLError, TimeoutError) as error:
            failures.append({"elapsed_seconds": elapsed, "kind": type(error).__name__})
        remaining = args.duration - (time.monotonic() - start)
        if remaining <= 0:
            break
        time.sleep(min(args.interval, remaining))
    result = {"phase": args.phase, "started_utc": started_utc,
              "lineup_size": args.lineup_size or None, "summary": summarize(samples),
              "samples": samples, "failures": failures}
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"phase": args.phase, "summary": result["summary"],
                      "failed_samples": len(failures)}))
    if not samples:
        raise SystemExit("No resource samples available; check the app is foreground and ECP access is enabled")


if __name__ == "__main__":
    main()
