"""Offline archive isolation checks; never contacts a Roku or provider."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("audit_builder", ROOT / "scripts/build-ui-audit-probe.py")
builder = importlib.util.module_from_spec(spec)


class LibraryAuditPackageTest(unittest.TestCase):
    def test_never_overwrites_input(self):
        spec.loader.exec_module(builder)
        with self.assertRaises(ValueError):
            builder.build(ROOT / "out/not-opened.zip", ROOT / "out/not-opened.zip")

    def test_production_renderers_and_task_barrier(self):
        spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory(dir=ROOT / "out", prefix="audit-package-test-") as folder:
            base, output = Path(folder) / "base.zip", Path(folder) / "probe.zip"
            with zipfile.ZipFile(base, "w") as z:
                for directory in ["source", "components"]:
                    for path in (ROOT / directory).glob("*"):
                        if path.suffix in [".brs", ".xml"]:
                            z.write(path, str(path.relative_to(ROOT)))
                z.write(ROOT / "manifest", "manifest")
            builder.build(base, output)
            with zipfile.ZipFile(base) as original, zipfile.ZipFile(output) as probe:
                self.assertIn("ui-audit-build.json", probe.namelist())
                for name in original.namelist():
                    if name.endswith(".xml"):
                        node = ET.fromstring(original.read(name))
                        if node.get("extends") == "Task":
                            scripts = [n.get("uri") for n in ET.fromstring(probe.read(name)).findall("script")]
                            self.assertEqual(scripts, ["UiAuditLibraryData.brs", "UiAuditFixtureTask.brs"], name)
                for name in ["VodView.brs", "DvrView.brs", "VodMetadata.brs", "DvrNavigation.brs", "DvrSeriesNavigation.brs", "GuideView.brs", "GuideSettings.brs", "GuideRemoteInput.brs", "PlayerOptions.brs", "PlayerInfo.brs", "ChannelBrowser.brs"]:
                    self.assertEqual(probe.read("components/" + name), original.read("components/" + name))
                scene = probe.read("components/AerioScene.brs").decode()
                self.assertIn("initUiAudit()", scene)
                self.assertNotIn('CreateObject("roRegistrySection"', scene.split("end sub", 1)[0])

    def test_fixture_code_cannot_open_network_registry_or_media(self):
        for name in ["UiAuditLibraryData.brs", "UiAuditFixtureTask.brs", "UiAuditVod.brs", "UiAuditDvr.brs", "UiAuditGuide.brs", "UiAuditGuideData.brs"]:
            text = (ROOT / "tests/native" / name).read_text()
            for forbidden in ['"roRegistry', '"roUrlTransfer', '"roStreamSocket', '"roDatagramSocket', '"Video"', '"Audio"']:
                self.assertNotIn(forbidden, text, name)
        task = (ROOT / "tests/native/UiAuditFixtureTask.brs").read_text()
        self.assertIn('forbidden: true', task)
        self.assertIn('action <> "list" and action <> "series-list"', task)

    def test_populated_guide_seed_keeps_real_renderers_and_disconnects_io(self):
        seed = (ROOT / "tests/native/UiAuditGuide.brs").read_text()
        self.assertIn('m.top.config =', seed)
        self.assertIn('guideCachePut(', seed)
        self.assertIn('m.loadDelay.unobserveField("fire")', seed)
        self.assertNotIn('sub drawGuide', seed)


if __name__ == "__main__":
    unittest.main()
