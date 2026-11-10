"""Build an explicitly opted-in full-app developer pairing ZIP, never a release."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parent.parent
WARNING = "PAIRING TEST BUILD - DEVICE-KEY SOURCE NOT SECURITY-QUALIFIED"
MARKER = "pairing-test-build.json"


def build(input_path, output_directory=None, *, enable_device_key_test=False):
    if not enable_device_key_test:
        raise ValueError("Device-key pairing tests require explicit opt-in")
    source = Path(input_path).resolve()
    directory = Path(output_directory or ROOT / "out/pairing-tests").resolve()
    release = (ROOT / "out/release").resolve()
    if directory == release or release in directory.parents:
        raise ValueError("Pairing test builds cannot be written into the release directory")
    original = source.read_bytes()
    with zipfile.ZipFile(source) as package:
        names = package.namelist()
        if len(names) != len(set(names)) or len(names) > 1000:
            raise ValueError("Invalid or duplicate package entries")
        if sum(info.file_size for info in package.infolist()) > 128 * 1024 * 1024:
            raise ValueError("Oversized base package")
        if MARKER in names:
            raise ValueError("Input is already a pairing test build, not a shipping base")
        for name in names:
            parts = name.split("/")
            if ".." in parts or "\\" in name or not (name == "manifest" or parts[0] in ["source", "components", "images"]):
                raise ValueError("Base contains development or probe files")
            if re.search(r"(^|/)(SetupReceiver|SetupApply(?:Probe|Fixture)|.*FixtureEntropy|fixture-materials|apply-cases)", name, re.I):
                raise ValueError("Base contains development or probe files")
        required = ["source/Main.brs", "components/AerioScene.xml", "components/AerioScene.brs",
                    "source/PhoneSetupEntropy.brs", "source/PhoneSetupX25519.brs", "source/PhoneSetupStore.brs",
                    "components/PhoneSetupView.xml", "components/PhoneSetupNavigation.brs", "components/PhoneSetupTask.brs",
                    "components/DispatcharrTask.brs", "components/M3uTask.brs", "components/XtreamTask.brs"]
        if not all(name in names for name in required):
            raise ValueError("Input must be a full application package")
        manifest = package.read("manifest").decode()
        fields = dict(line.split("=", 1) for line in manifest.splitlines() if "=" in line)
        if fields.get("title") != "AerioTV" or "aeriotv_pairing_test" in fields:
            raise ValueError("Input must be a normal shipping base, not a test build")
        version = ".".join(fields.get(key, "") for key in ["major_version", "minor_version", "build_version"])
        if not re.fullmatch(r"\d+\.\d+\.\d+", version):
            raise ValueError("Base package has an invalid version")
        entropy = package.read("source/PhoneSetupEntropy.brs").decode()
        gate = "function phoneSetupRandomBytes(count as integer) as dynamic\n    return invalid\nend function"
        if entropy.count(gate) != 1:
            raise ValueError("Base does not contain the unchanged fail-closed shipping entropy provider")
        if b"value = lcase(value)" not in package.read("source/PhoneSetupX25519.brs"):
            raise ValueError("Base is missing the native uppercase private-key encoding fix")
        candidate = (ROOT / "tests/pairing/DeviceKeyEntropy.brs").read_text()
        view = package.read("components/PhoneSetupView.xml").decode()
        warning = '<field id="warning" type="string" />'
        if view.count(warning) != 1:
            raise ValueError("Cannot safely add the pairing test warning")
        metadata = {"kind": "full-app-pairing-test", "version": version, "shippingApproved": False,
                    "realApplicationRegistry": True, "baseZipSha256": hashlib.sha256(original).hexdigest(),
                    "entropySourceSha256": hashlib.sha256(candidate.encode()).hexdigest()}
        replacements = {
            "manifest": ("\n".join("title=AerioTV Pairing Test" if line == "title=AerioTV" else line for line in manifest.splitlines()).rstrip() + "\naeriotv_pairing_test=1\n").encode(),
            "source/PhoneSetupEntropy.brs": entropy.replace(gate, candidate.rstrip()).encode(),
            "components/PhoneSetupView.xml": view.replace(warning, '<field id="warning" type="string" value="' + WARNING + '" />').encode(),
        }
        filename = f"aeriotv-roku-v{version}-pairing-test.zip"
        directory.mkdir(parents=True, exist_ok=True)
        output = directory / filename
        if output.exists():
            with zipfile.ZipFile(output) as previous:
                if MARKER not in previous.namelist():
                    raise ValueError("Refusing to overwrite an unrelated package")
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as result:
            for info in package.infolist():
                result.writestr(info, replacements.get(info.filename, package.read(info.filename)))
            info = zipfile.ZipInfo(MARKER)
            info.compress_type = zipfile.ZIP_DEFLATED
            result.writestr(info, json.dumps(metadata, sort_keys=True, indent=2) + "\n")
    checksum = hashlib.sha256(output.read_bytes()).hexdigest()
    checksums = directory / f"SHA256SUMS-pairing-test-v{version}"
    checksums.write_text(checksum + "  " + filename + "\n")
    return {"zip": str(output), "checksums": str(checksums), "sha256": checksum, "version": version}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=ROOT / "out/aeriotv-roku.zip")
    parser.add_argument("--output-directory", type=Path)
    parser.add_argument("--enable-device-key-test", action="store_true")
    args = parser.parse_args()
    print(json.dumps(build(args.input, args.output_directory, enable_device_key_test=args.enable_device_key_test), indent=2))
