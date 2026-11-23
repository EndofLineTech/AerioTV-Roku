"""Local Mac relay between a test Roku and Dispatcharr with opt-in faults.

The relay forwards every method to DISPATCHARR_BASE, rewrites upstream
Location headers to itself and appends one redacted JSON line per request to
--log. Tokens, UUIDs, query values and credentials are never logged. Faults
come from --rules, re-read on each request so a runner can change them live:

    {"rules": [{"match": "hls-mint", "status": 503, "count": 1,
                "headers": {"Retry-After": "5"}},
               {"match": "hls-segment", "action": "reset", "count": 1}]}

It never calls Dispatcharr admin endpoints itself and changes no server state
beyond what the Roku requests.
"""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import socket
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade", "host", "content-length"}
TOKEN = re.compile(r"^/proxy/hls/[^/]+/")
SESSION = re.compile(r"/api/proxy/hls/sessions/[^/]+/")
UUID = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
NUMBER = re.compile(r"/[0-9]+(?=/|$)")


def classify(method, target):
    path, _, query = target.partition("?")
    if method == "DELETE" and SESSION.search(path):
        return "hls-close"
    if path.startswith("/proxy/ts/stream/"):
        return "hls-mint" if "output_format=hls" in query else "ts-stream"
    if path.startswith("/proxy/hls/"):
        return "hls-playlist" if path.endswith(".m3u8") else "hls-segment"
    if path.startswith("/api/accounts/token/"):
        return "login"
    if path.startswith("/api/accounts/users/me/app-data"):
        return "app-data"
    if path.startswith("/api/accounts/users/me/"):
        return "me"
    if path.startswith("/api/"):
        return "api"
    return "other"


def redact(target):
    path, _, query = target.partition("?")
    path = SESSION.sub("/api/proxy/hls/sessions/{token}/", TOKEN.sub("/proxy/hls/{token}/", path))
    path = NUMBER.sub("/{n}", UUID.sub("{uuid}", path))
    if query:
        path += "?" + "&".join(sorted(f"{key}=…" for key in urllib.parse.parse_qs(query, keep_blank_values=True)))
    return path


class Rules:
    """Counted fault rules; a rule with count 0 or less is spent."""

    def __init__(self, path):
        self.path, self.lock, self.used, self.stamp, self.rules = path, threading.Lock(), {}, None, []

    def take(self, kind):
        with self.lock:
            if self.path is not None:
                try:
                    stamp = os.stat(self.path).st_mtime_ns
                except FileNotFoundError:
                    stamp = None
                if stamp != self.stamp:
                    self.stamp, self.used = stamp, {}
                    self.rules = json.loads(Path(self.path).read_text()).get("rules", []) if stamp else []
            for index, rule in enumerate(self.rules):
                if rule.get("match") != kind:
                    continue
                if self.used.get(index, 0) >= int(rule.get("count", 1)):
                    continue
                self.used[index] = self.used.get(index, 0) + 1
                return rule
        return None


def make_handler(upstream, rules, log, lock, api_key=""):
    origin = urllib.parse.urlsplit(upstream)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    class Relay(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_args):
            pass

        def record(self, kind, **fields):
            row = {"t": round(time.time(), 3), "method": self.command, "kind": kind, "path": redact(self.path), **fields}
            with lock, open(log, "a", encoding="utf-8") as handle:
                handle.write(json.dumps(row) + "\n")

        def relay(self):
            kind = classify(self.command, self.path)
            rule = rules.take(kind)
            if rule and rule.get("action") != "reset" and "status" in rule:
                body = b'{"detail":"injected"}'
                self.send_response(int(rule["status"]))
                for name, value in rule.get("headers", {}).items():
                    self.send_header(name, value)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                self.record(kind, status=int(rule["status"]), injected=True)
                return
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else None
            headers = {name: value for name, value in self.headers.items() if name.lower() not in HOP}
            # Optional: authenticate on the Mac so a test package holds no key.
            if api_key and not any(name.lower() in ("x-api-key", "authorization") for name in headers):
                headers["X-API-Key"] = api_key
            request = urllib.request.Request(upstream.rstrip("/") + self.path, data=body, headers=headers, method=self.command)
            started = time.monotonic()
            try:
                response = opener.open(request, timeout=30)
            except urllib.error.HTTPError as error:
                response = error
            except OSError as error:
                self.send_error(502)
                self.record(kind, status=502, upstream_error=type(error).__name__)
                return
            with response:
                self.send_response(response.status)
                for name, value in response.headers.items():
                    lower = name.lower()
                    if lower in HOP:
                        continue
                    if lower == "location":
                        value = rewrite_location(value, origin, self.headers.get("Host", ""))
                    self.send_header(name, value)
                if response.status in (204, 304) or self.command == "HEAD":
                    self.end_headers()
                    self.record(kind, status=response.status, bytes=0, ms=round((time.monotonic() - started) * 1000))
                    return
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                sent, reset = 0, rule is not None and rule.get("action") == "reset"
                limit = int(rule.get("after_bytes", 65536)) if reset else None
                try:
                    while True:
                        chunk = response.read(65536)
                        if not chunk:
                            break
                        if limit is not None and sent + len(chunk) >= limit:
                            self.wfile.write(b"%x\r\n" % (limit - sent) + chunk[:limit - sent] + b"\r\n")
                            sent = limit
                            self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, b"\x01\x00\x00\x00\x00\x00\x00\x00")
                            self.close_connection = True
                            self.record(kind, status=response.status, bytes=sent, injected="reset")
                            return
                        self.wfile.write(b"%x\r\n" % len(chunk) + chunk + b"\r\n")
                        sent += len(chunk)
                    self.wfile.write(b"0\r\n\r\n")
                except OSError as error:
                    self.record(kind, status=response.status, bytes=sent, client_error=type(error).__name__)
                    return
            self.record(kind, status=response.status, bytes=sent, ms=round((time.monotonic() - started) * 1000))

        do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = relay

    return Relay


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


def rewrite_location(value, origin, host):
    target = urllib.parse.urlsplit(value)
    if target.netloc and target.netloc != origin.netloc:
        return value
    if not target.netloc or not host:
        return value
    return urllib.parse.urlunsplit(("http", host, target.path, target.query, target.fragment))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--bind", required=True, help="Mac LAN address the Roku can reach")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--log", required=True)
    parser.add_argument("--rules")
    parser.add_argument("--api-key-env", help="Environment variable whose API key is added to requests that carry none")
    args = parser.parse_args()
    upstream = os.environ["DISPATCHARR_BASE"]
    api_key = os.environ.get(args.api_key_env, "") if args.api_key_env else ""
    server = ThreadingHTTPServer((args.bind, args.port), make_handler(upstream, Rules(args.rules), args.log, threading.Lock(), api_key))
    print(json.dumps({"listening": f"http://{args.bind}:{server.server_port}"}), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
