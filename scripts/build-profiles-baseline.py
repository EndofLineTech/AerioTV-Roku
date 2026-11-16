#!/usr/bin/env python3
"""Create an unsigned developer-only baseline from the normal compiled ZIP."""
import argparse
import hashlib
import re
import zipfile
from pathlib import Path


def build(source, destination, directions=False):
    with zipfile.ZipFile(source) as original:
        manifest = original.read("manifest").decode()
        if re.search(r"^\s*(aeriotv_profiles_baseline|aeriotv_profile_directions_test)\s*=", manifest, re.M):
            raise ValueError("Input must be a normal build, not an existing baseline")
        manifest = re.sub(r"^title=.*$", "title=AerioTV Profiles Baseline", manifest, flags=re.M)
        manifest = manifest.rstrip() + "\naeriotv_profiles_baseline=1\n"
        if directions:
            manifest += "aeriotv_profile_directions_test=1\n"
        destination.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as output:
            for item in original.infolist():
                output.writestr(item, manifest.encode() if item.filename == "manifest" else original.read(item.filename))
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(f"{digest}  {destination.name}\n")
    print(f"Developer-only baseline: {destination}\nSHA256 {digest}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("out/aeriotv-roku.zip"))
    parser.add_argument("--output", type=Path, default=Path("out/profiles-baseline/aeriotv-roku-profiles-baseline.zip"))
    parser.add_argument("--directions", action="store_true", help="Explicit developer-only D-pad qualification; not public Directions certification")
    args = parser.parse_args()
    build(args.source, args.output, directions=args.directions)
