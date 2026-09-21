"""Capture a Roku ECP screenshot without writing device details to the output."""

import argparse
import os
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="out/native-screenshot.jpg")
    parser.add_argument("--timeout", type=int, default=10)
    args = parser.parse_args()
    host = os.environ["ROKU_HOST"]

    try:
        with urlopen(f"http://{host}:8060/query/screenshot", timeout=args.timeout) as response:
            content_type = response.headers.get_content_type()
            image = response.read(5 * 1024 * 1024 + 1)
    except HTTPError as error:
        if error.code in (401, 403):
            raise SystemExit("Screenshot blocked by the current Roku ECP policy; use a physical camera instead")
        raise SystemExit(f"Roku screenshot request failed with HTTP {error.code}")
    except URLError:
        raise SystemExit("Roku screenshot request could not reach the configured device")

    if not content_type.startswith("image/"):
        raise SystemExit("Roku screenshot response was not an image")
    if len(image) > 5 * 1024 * 1024:
        raise SystemExit("Roku screenshot exceeded the 5 MiB capture limit")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(image)
    print(f"Screenshot captured: {output}")


if __name__ == "__main__":
    main()
