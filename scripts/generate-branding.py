"""Generate committed Roku artwork from the pinned upstream Apple TV icon.

Optional maintainer tool: python3 -m pip install Pillow==11.3.0
Normal Roku builds use the generated PNGs and do not require Pillow.
"""

from hashlib import sha1
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "images/upstream/aeriotv-tvos-icon.png"
EXPECTED_BLOB = "87ecec5c042366797947490efd0830ad07c6536d"


def main():
    data = SOURCE.read_bytes()
    blob = sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if blob != EXPECTED_BLOB:
        raise SystemExit("Upstream artwork does not match the documented pinned blob")
    with Image.open(SOURCE) as original:
        source = original.convert("RGB")
    outputs = {
        "channel-icon-fhd.png": (540, 405),
        "channel-icon-hd.png": (290, 218),
        "splash-fhd.png": (1920, 1080),
        "splash-hd.png": (1280, 720),
        "splash-sd.png": (720, 480),
    }
    for name, size in outputs.items():
        # Contain, never crop/stretch the upstream wordmark. Extend its edge
        # colours into any letterbox area so every required aspect ratio fits.
        fitted = ImageOps.contain(source, size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", size, source.getpixel((0, 0)))
        x = (size[0] - fitted.width) // 2
        y = (size[1] - fitted.height) // 2
        if y:
            bottom = Image.new("RGB", (size[0], size[1] - y - fitted.height), source.getpixel((0, source.height - 1)))
            canvas.paste(bottom, (0, y + fitted.height))
        canvas.paste(fitted, (x, y))
        canvas.save(ROOT / "images" / name, optimize=True)
        print(f"{name}: {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
