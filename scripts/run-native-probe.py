"""Install a developer ZIP and capture only redacted, selected native evidence.

ROKU_HOST and ROKU_DEV_PASSWORD are supplied in the environment, never source.
"""

import argparse
import os
import re
import socket
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive")
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--marker", default="")
    parser.add_argument("--prefix", default="[cache-probe")
    args = parser.parse_args()
    host = os.environ["ROKU_HOST"]
    password = os.environ["ROKU_DEV_PASSWORD"]
    console = socket.create_connection((host, 8085), 5)
    console.settimeout(0.2)
    try:
        while console.recv(65536):
            pass
    except socket.timeout:
        pass
    result = subprocess.run([
        "curl", "--max-time", "40", "--silent", "--show-error", "--digest",
        "--user", "rokudev:" + password, "-F", "mysubmit=Install",
        "-F", "archive=@" + args.archive, "http://" + host + "/plugin_install",
    ], capture_output=True, text=True)
    installed = result.returncode == 0 and "Install Success" in result.stdout
    print("Installed:", installed, flush=True)
    if not installed:
        messages = re.findall(r'"text"\s*:\s*"([^"\n]+)"', result.stdout)
        for message in messages:
            message = re.sub(r'https?://[^\s"<>]+', "[URL]", message)
            print("Installer:", message.replace(password, "[developer password]"), flush=True)
        if result.returncode:
            print("Installer transport exit:", result.returncode, flush=True)
    deadline = time.monotonic() + (args.timeout if installed else 3)
    pending = b""
    complete = False
    while time.monotonic() < deadline:
        try:
            chunk = console.recv(65536)
            if not chunk:
                break
            pending += chunk
            while b"\n" in pending:
                raw, pending = pending.split(b"\n", 1)
                line = raw.decode("utf-8", "replace").strip()
                relevant = args.prefix in line or any(term in line for term in (
                    "ERROR:", "error &h", "Syntax Error", "Running dev",
                ))
                if relevant:
                    line = re.sub(r'https?://[^\s"<>]+', "[URL]", line)
                    line = line.replace(password, "[developer password]")
                    print(line, flush=True)
                if args.marker and args.marker in line:
                    complete = True
            if complete:
                break
        except socket.timeout:
            pass
    console.close()
    if not installed:
        raise SystemExit("Native install failed; inspect compiler evidence above")
    if args.marker and not complete:
        raise SystemExit("Probe did not report completion within its time budget")


if __name__ == "__main__":
    main()
