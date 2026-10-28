"""Build a synthetic-only, standalone Roku setup primitive probe (never install)."""
from pathlib import Path
import zipfile
import subprocess


ROOT = Path(__file__).resolve().parent.parent


def build(output):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("manifest", "title=Aerio Setup Compatibility Probe\n"
                         "major_version=0\nminor_version=0\nbuild_version=1\n"
                         "ui_resolutions=fhd\nrsg_version=1.3\n")
        package.write(ROOT / "tests/native/PhoneSetupProbe.brs", "source/Main.brs")
        package.write(ROOT / "tests/native/PhoneSetupProbe.xml", "components/PhoneSetupProbe.xml")
        package.write(ROOT / "source/PhoneSetupModel.brs", "source/PhoneSetupModel.brs")
        package.write(ROOT / "tests/native/PhoneSetupMatrix.brs", "source/PhoneSetupMatrix.brs")
        vectors = subprocess.run(["node", str(ROOT / "scripts/phone-setup-vectors.mjs")], check=True, capture_output=True, text=True).stdout
        package.writestr("fixtures.json", vectors)
    return output


if __name__ == "__main__":
    print(build(ROOT / "out/phone-setup-probe.zip"))
