"""Capture a Roku ECP screenshot without writing device details to the output."""

import argparse
import os
import subprocess
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="out/native-screenshot.jpg")
    parser.add_argument("--timeout", type=int, default=10)
    parser.add_argument("--developer-mode", action="store_true", help="Use the authenticated Developer Mode screenshot facility")
    args = parser.parse_args()
    host = os.environ["ROKU_HOST"]

    if args.developer_mode:
        password = os.environ["ROKU_DEV_PASSWORD"]
        common = ["curl", "--silent", "--show-error", "--max-time", str(args.timeout), "--digest", "--user", "rokudev:" + password]
        capture = subprocess.run(common + ["--fail", "-F", "mysubmit=Screenshot", f"http://{host}/plugin_inspect"], capture_output=True)
        if capture.returncode:
            raise SystemExit("Developer screenshot request failed")
        for extension in ("jpg", "png"):
            result = subprocess.run(common + ["--fail", f"http://{host}/pkgs/dev.{extension}"], capture_output=True)
            image = result.stdout
            valid = image.startswith(b'\xff\xd8\xff') or image.startswith(b'\x89PNG\r\n\x1a\n')
            if result.returncode == 0 and valid and len(image) <= 5 * 1024 * 1024:
                output = Path(args.output)
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(image)
                print(f"Screenshot captured: {output}")
                return
        raise SystemExit("Developer screenshot unavailable; no image was returned")

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
