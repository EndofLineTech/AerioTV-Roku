"""Build a synthetic-only, standalone Roku setup primitive probe (never install)."""
from pathlib import Path
import zipfile
import subprocess
import argparse


ROOT = Path(__file__).resolve().parent.parent


def build(output, x25519=False, handoff=False):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("manifest", "title=Aerio Setup Compatibility Probe\n"
                         "major_version=0\nminor_version=0\nbuild_version=1\n"
                         "ui_resolutions=fhd\nrsg_version=1.3\n")
        main = "SetupHandoffProbe.brs" if handoff else "SetupX25519Probe.brs" if x25519 else "PhoneSetupProbe.brs"
        package.write(ROOT / "tests/native" / main, "source/Main.brs")
        package.write(ROOT / "tests/native/PhoneSetupProbe.xml", "components/PhoneSetupProbe.xml")
        if x25519 or handoff:
            package.write(ROOT / "tests/native/SetupX25519.brs", "source/SetupX25519.brs")
            if handoff:
                package.write(ROOT / "source/PhoneSetupModel.brs", "source/PhoneSetupModel.brs")
            generator = "setup-handoff-vectors.mjs" if handoff else "setup-x25519-vectors.mjs"
            fixture = "handoff-fixtures.json" if handoff else "x25519-fixtures.json"
            vectors = subprocess.run(["node", str(ROOT / "scripts" / generator)], check=True, capture_output=True, text=True).stdout
            package.writestr(fixture, vectors)
            return output
        package.write(ROOT / "source/PhoneSetupModel.brs", "source/PhoneSetupModel.brs")
        package.write(ROOT / "tests/native/PhoneSetupMatrix.brs", "source/PhoneSetupMatrix.brs")
        vectors = subprocess.run(["node", str(ROOT / "scripts/phone-setup-vectors.mjs")], check=True, capture_output=True, text=True).stdout
        package.writestr("fixtures.json", vectors)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--x25519", action="store_true")
    mode.add_argument("--handoff", action="store_true")
    args = parser.parse_args()
    name = "setup-handoff-probe.zip" if args.handoff else "setup-x25519-probe.zip" if args.x25519 else "phone-setup-probe.zip"
    print(build(ROOT / "out" / name, x25519=args.x25519, handoff=args.handoff))
