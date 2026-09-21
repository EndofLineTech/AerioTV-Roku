"""Read a safe subset of Roku device facts for stability evidence."""

import argparse
import json
import os
import xml.etree.ElementTree as ET
from urllib.error import HTTPError, URLError
from urllib.request import urlopen


SAFE_FIELDS = (
    "model-name",
    "model-number",
    "software-version",
    "software-build",
    "ui-resolution",
    "uptime",
)


def parse_device_info(xml):
    root = ET.fromstring(xml)
    info = {}
    for field in SAFE_FIELDS:
        value = root.findtext(field)
        if value:
            info[field] = value.strip()
    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=10)
    args = parser.parse_args()
    host = os.environ.get("ROKU_HOST")
    if not host:
        raise SystemExit("ROKU_HOST is required")
    try:
        with urlopen(f"http://{host}:8060/query/device-info", timeout=args.timeout) as response:
            xml = response.read(1024 * 1024).decode("utf-8", "replace")
    except HTTPError as error:
        raise SystemExit(f"Roku device-info request failed with HTTP {error.code}")
    except URLError:
        raise SystemExit("Roku device-info request could not reach the configured device")

    print(json.dumps(parse_device_info(xml), sort_keys=True))


if __name__ == "__main__":
    main()
