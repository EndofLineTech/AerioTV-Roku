"""Exercise the fixture's real HTTP playlist -> file protocol (no Roku auth)."""

import importlib.util
from http.client import HTTPConnection
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from http.server import ThreadingHTTPServer


SPEC = importlib.util.spec_from_file_location(
    "dvr_hls_handoff_fixture", Path(__file__).with_name("dvr-hls-handoff-fixture.py")
)
FIXTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIXTURE)


class HlsHandoffFixtureTest(unittest.TestCase):
    def test_playlist_redirect_and_byte_range(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "seg_00000.ts").write_bytes(b"segment")
            (folder / "finished.mkv").write_bytes(b"finished media")
            handler = FIXTURE.handler_for(
                folder, "#EXTM3U\n#EXTINF:4,\nseg_00000.ts\n", transition_after=0.15, status_delay=0.15
            )
            with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    host, port = server.server_address
                    connection = HTTPConnection(host, port, timeout=3)
                    connection.request("GET", "/hls/index.m3u8")
                    playlist = connection.getresponse()
                    self.assertEqual(playlist.status, 200)
                    self.assertIn("mpegURL", playlist.getheader("Content-Type"))
                    self.assertIn(f"http://{host}:{port}/hls/seg_00000.ts", playlist.read().decode())
                    connection.request("GET", "/hls/seg_00000.ts")
                    segment = connection.getresponse()
                    self.assertEqual(segment.status, 200)
                    self.assertEqual(segment.read(), b"segment")
                    connection.request("GET", "/api/channels/recordings/12/")
                    current = json.loads(connection.getresponse().read())
                    self.assertEqual(current["custom_properties"]["status"], "recording")
                    time.sleep(0.2)
                    connection.request("GET", "/hls/index.m3u8")
                    redirect = connection.getresponse()
                    self.assertEqual(redirect.status, 302)
                    self.assertEqual(redirect.getheader("Location"), "/file/")
                    self.assertEqual(redirect.read(), b"")
                    connection.request("GET", "/api/channels/recordings/12/")
                    current = json.loads(connection.getresponse().read())
                    self.assertEqual(current["custom_properties"]["status"], "recording")
                    time.sleep(0.2)
                    connection.request("GET", "/api/channels/recordings/12/")
                    finished = json.loads(connection.getresponse().read())
                    self.assertEqual(finished["custom_properties"]["status"], "completed")
                    connection.request("GET", "/api/channels/recordings/12/file/", headers={"Range": "bytes=3-9"})
                    final = connection.getresponse()
                    self.assertEqual(final.status, 206)
                    self.assertEqual(final.getheader("Content-Type"), "video/x-matroska")
                    self.assertEqual(final.read(), b"ished m")
                    connection.close()
                finally:
                    server.shutdown()
                    thread.join(timeout=3)


if __name__ == "__main__":
    unittest.main()
