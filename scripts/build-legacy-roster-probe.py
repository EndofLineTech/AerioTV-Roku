"""Build a disposable native registry migration probe using an isolated section."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent.parent
with zipfile.ZipFile(root / "out/aeriotv-roku.zip") as source:
    with zipfile.ZipFile(root / "out/legacy-roster-probe.zip", "w", zipfile.ZIP_DEFLATED) as target:
        for entry in source.infolist():
            data = source.read(entry.filename)
            if entry.filename == "components/AerioScene.xml":
                data = data.replace(b"<children>", b'<script type="text/brightscript" uri="LegacyRosterProbe.brs" /><children>', 1)
            if entry.filename == "components/AerioScene.brs":
                data = data.replace(b"sub init()", b"sub init()\n    runLegacyRosterProbe()", 1)
            target.writestr(entry, data)
        target.writestr("components/LegacyRosterProbe.brs", (root / "tests/native/LegacyRosterProbe.brs").read_bytes())
        target.writestr("components/LegacyRosterProbeTask.xml", (root / "tests/native/LegacyRosterProbeTask.xml").read_bytes())
        target.writestr("components/LegacyRosterProbeTask.brs", (root / "tests/native/LegacyRosterProbeTask.brs").read_bytes())
print("Built out/legacy-roster-probe.zip")
