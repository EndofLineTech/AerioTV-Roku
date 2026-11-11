"""Synthetic loopback logo probe; full production components, no app scene/registry."""
import argparse
from pathlib import Path
import struct
import zlib
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(base, output):
    with zipfile.ZipFile(base) as original, zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as package:
        for name in original.namelist():
            if name != "source/Main.brs":
                data = original.read(name)
                if name == "source/MetadataCacheStore.brs":
                    data = data.replace(b'"cachefs:/aeriotv-metadata-v1"', b'"tmp:/channel-logo-probe-cache"')
                package.writestr(name, data)
        package.writestr("source/Main.brs", 'sub Main()\n screen = CreateObject("roSGScreen")\n port = CreateObject("roMessagePort")\n screen.setMessagePort(port)\n scene = screen.createScene("ChannelLogoProbe")\n screen.show()\n while true\n event = wait(0, port)\n if type(event) = "roSGScreenEvent"\n if event.isScreenClosed() then return\n end if\n end while\nend sub\n')
        # Existing shipping guards reject this unmistakable isolated probe marker.
        package.writestr("source/SetupReceiverProbeLogo.brs", "' Isolated synthetic logo probe; never ship.\n")
        for component in ["ChannelLogoProbe", "ChannelLogoFixtureTask"]:
            for suffix in ["brs", "xml"]:
                package.write(ROOT / f"tests/native/{component}.{suffix}", f"components/{component}.{suffix}")
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 32, 32, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress((b"\x00" + b"\x1a\xc4\xd8" * 32) * 32)) + chunk(b"IEND", b"")
        import base64
        package.writestr("logo-fixture.base64", base64.b64encode(png))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=ROOT / "out/aeriotv-roku.zip")
    parser.add_argument("--output", type=Path, default=ROOT / "out/channel-logo-probe.zip")
    args = parser.parse_args()
    build(args.base, args.output)
    print(args.output)
