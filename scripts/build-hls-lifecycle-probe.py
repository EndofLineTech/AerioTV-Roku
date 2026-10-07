"""Overlay a saved app ZIP with the HLS fix; optional one-tune probe."""
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
probe = "--no-probe" not in sys.argv[3:]
overlays = {
    name: (root / name).read_bytes()
    for name in (
        "components/AerioScene.brs", "components/AerioScene.xml",
        "components/HlsSessionTask.brs", "components/HlsSessionTask.xml",
        "components/HlsSessionLifecycle.brs", "source/PlaybackModel.brs",
    )
}
if probe:
    overlays["components/AerioScene.xml"] = overlays["components/AerioScene.xml"].replace(
        b"<children>",
        b'<script type="text/brightscript" uri="HlsSessionLifecycleProbe.brs" /><children>',
        1,
    )
    overlays["components/AerioScene.brs"] = overlays["components/AerioScene.brs"].replace(
        b"sub init()", b"sub init()\n    installHlsSessionLifecycleProbe()", 1,
    )
    overlays["components/HlsSessionLifecycleProbe.brs"] = (
        root / "tests/native/HlsSessionLifecycleProbe.brs"
    ).read_bytes()
with zipfile.ZipFile(source_path) as source:
    with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            target.writestr(entry, overlays.pop(entry.filename, source.read(entry.filename)))
        for name, data in overlays.items():
            target.writestr(name, data)
print("HLS lifecycle ZIP built; probe=" + str(probe))
