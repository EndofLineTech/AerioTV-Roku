"""Synthetic LAN receiver probe; no real credentials, registry or provider calls."""
from pathlib import Path
import argparse
import json
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output, production_entropy=False):
    sources = ["SceneUi", "PhoneSetupModel", "PhoneSetupTransport", "PhoneSetupLink",
               "PhoneSetupQr", "PhoneSetupX25519", "PhoneSetupCrypto"]
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("manifest", "title=Aerio Synthetic Setup Receiver\nmajor_version=0\n"
                          "minor_version=0\nbuild_version=1\nui_resolutions=fhd\nrsg_version=1.3\n"
                          "supports_input_launch=1\n")
        package.write(ROOT / "tests/native/SetupReceiverProbe.brs", "source/Main.brs")
        for name in sources:
            package.write(ROOT / f"source/{name}.brs", f"source/{name}.brs")
        entropy = "source/PhoneSetupEntropy.brs" if production_entropy else "tests/native/SetupReceiverFixtureEntropy.brs"
        package.write(ROOT / entropy, "source/PhoneSetupEntropy.brs")
        for name in ["PhoneSetupTask", "PhoneSetupView"]:
            for extension in ["xml", "brs"]:
                package.write(ROOT / f"components/{name}.{extension}", f"components/{name}.{extension}")
        package.write(ROOT / "tests/native/SetupReceiverProbe.xml", "components/SetupReceiverProbe.xml")
        package.write(ROOT / "tests/native/SetupReceiverProbeScene.brs", "components/SetupReceiverProbeScene.brs")
        if not production_entropy:
            package.writestr("fixture-materials.json", json.dumps([
                {"privateHex": "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb",
                 "publicHex": "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f", "code": "000123"},
                {"privateHex": "c8ec57ca39f11a95d59c7e7e0ff0f18fde51add8ba1e2176375c317b604692e9",
                 "publicHex": "130388590da57cdc0c70608a494e46cd8154abe7d731a6a224e49fa05f9d1206", "code": "483920"},
            ]))
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--production-entropy', action='store_true', help='Verify the production fail-closed gate, without fixture material')
    arguments = parser.parse_args()
    name = 'setup-receiver-production-entropy-probe.zip' if arguments.production_entropy else 'setup-receiver-probe.zip'
    print(build(ROOT / 'out' / name, production_entropy=arguments.production_entropy))
