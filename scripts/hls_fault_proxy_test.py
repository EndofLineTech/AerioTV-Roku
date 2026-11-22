import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest

spec = importlib.util.spec_from_file_location("hls_fault_proxy", Path(__file__).with_name("hls_fault_proxy.py"))
proxy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proxy)

TOKEN = "Zm9vYmFyc2VjcmV0dG9rZW4"
UUID = "0f8fad5b-d9cb-469f-a165-70867728950e"


class Upstream(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        if self.path.startswith("/proxy/ts/stream/"):
            self.send_response(302)
            self.send_header("Location", f"http://{self.server.public}/proxy/hls/{TOKEN}/index.m3u8")
            self.send_header("X-Dispatcharr-Session-Token", TOKEN)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        body = b"x" * 200000
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_DELETE(self):
        self.send_response(204)
        self.end_headers()


class FaultProxyTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        root = Path(self.folder.name)
        self.log, self.rules = root / "log.jsonl", root / "rules.json"
        self.upstream = ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
        self.upstream.public = f"127.0.0.1:{self.upstream.server_port}"
        handler = proxy.make_handler(f"http://{self.upstream.public}", proxy.Rules(str(self.rules)), str(self.log), threading.Lock())
        self.relay = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        for server in (self.upstream, self.relay):
            threading.Thread(target=server.serve_forever, daemon=True).start()

    def tearDown(self):
        for server in (self.upstream, self.relay):
            server.shutdown()
            server.server_close()
        self.folder.cleanup()

    def request(self, method, path):
        connection = http.client.HTTPConnection("127.0.0.1", self.relay.server_port, timeout=5)
        connection.request(method, path, headers={"X-API-Key": "secret-key"})
        response = connection.getresponse()
        try:
            body = response.read()
        except http.client.IncompleteRead as error:
            body = error.partial
        except ConnectionResetError:
            body = b""
        return response, body

    def rows(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_mint_redirect_is_rewritten_and_logs_are_redacted(self):
        response, _ = self.request("GET", f"/proxy/ts/stream/{UUID}?output_format=hls&api_key=secret-key")
        self.assertEqual(response.status, 302)
        self.assertEqual(response.getheader("Location"), f"http://127.0.0.1:{self.relay.server_port}/proxy/hls/{TOKEN}/index.m3u8")
        self.assertEqual(response.getheader("X-Dispatcharr-Session-Token"), TOKEN)
        response, _ = self.request("DELETE", f"/api/proxy/hls/sessions/{TOKEN}/")
        self.assertEqual(response.status, 204)
        text = self.log.read_text()
        for secret in (TOKEN, UUID, "secret-key"):
            self.assertNotIn(secret, text)
        self.assertEqual([row["kind"] for row in self.rows()], ["hls-mint", "hls-close"])
        self.assertEqual(self.rows()[0]["path"], "/proxy/ts/stream/{uuid}?api_key=…&output_format=…")

    def test_counted_status_fault_then_passthrough(self):
        self.rules.write_text(json.dumps({"rules": [{"match": "hls-mint", "status": 503, "count": 1, "headers": {"Retry-After": "5"}}]}))
        response, _ = self.request("GET", f"/proxy/ts/stream/{UUID}?output_format=hls")
        self.assertEqual((response.status, response.getheader("Retry-After")), (503, "5"))
        response, _ = self.request("GET", f"/proxy/ts/stream/{UUID}?output_format=hls")
        self.assertEqual(response.status, 302)
        self.assertEqual([row.get("injected") for row in self.rows()], [True, None])

    def test_segment_reset_truncates_body(self):
        self.rules.write_text(json.dumps({"rules": [{"match": "hls-segment", "action": "reset", "after_bytes": 1000}]}))
        _, body = self.request("GET", f"/proxy/hls/{TOKEN}/seg-1.ts")
        self.assertLessEqual(len(body), 1000)
        _, body = self.request("GET", f"/proxy/hls/{TOKEN}/seg-2.ts")
        self.assertEqual(len(body), 200000)
        self.assertEqual(self.rows()[0]["injected"], "reset")


if __name__ == "__main__":
    unittest.main()
