"""Serve disposable, credential-free HLS that switches to a finished MKV.

The 302 mirrors Dispatcharr 0.31.0's old-playlist behavior after HLS cleanup.
No Dispatcharr connection or recording is created by this fixture.
"""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import time
from urllib.parse import urlsplit


def build_media(folder: Path, duration: int):
    playlist = folder / "index.m3u8"
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=24",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
            "-t", str(duration), "-c:v", "libx264", "-preset", "ultrafast",
            "-g", "96", "-keyint_min", "96", "-sc_threshold", "0",
            "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k",
            "-f", "hls", "-hls_time", "4", "-hls_list_size", "0",
            "-hls_flags", "omit_endlist+independent_segments",
            "-hls_segment_filename", str(folder / "seg_%05d.ts"), str(playlist),
        ],
        check=True, capture_output=True, timeout=60,
    )
    # The published playlist intentionally has no ENDLIST. Remux from a local
    # finalized copy; otherwise FFmpeg waits indefinitely for new segments.
    finished_playlist = folder / "finished.m3u8"
    finished_playlist.write_text(playlist.read_text(encoding="utf-8") + "#EXT-X-ENDLIST\n", encoding="utf-8")
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
         "-i", str(finished_playlist), "-c", "copy", str(folder / "finished.mkv")],
        check=True, capture_output=True, timeout=60,
    )
    body = playlist.read_text(encoding="utf-8")
    assert body.startswith("#EXTM3U") and "#EXT-X-ENDLIST" not in body
    segments = re.findall(r"(?m)^seg_[0-9]{5}\.ts$", body)
    assert len(segments) >= 4
    return body, len(segments)


def handler_for(folder: Path, playlist: str, transition_after: float, status_delay: float = 0):
    class FixtureHandler(BaseHTTPRequestHandler):
        started = None

        def log_message(self, _format, *_args):
            pass  # Do not log request URLs or client details.

        def do_GET(self):
            route = urlsplit(self.path)
            if route.query or route.fragment:
                self.send_error(400)
                return
            if self.started is None and route.path == "/hls/index.m3u8":
                FixtureHandler.started = time.monotonic()
            elapsed = 0 if self.started is None else time.monotonic() - self.started
            completed = self.started is not None and elapsed >= transition_after
            if route.path == "/api/channels/recordings/12/":
                ready = completed and elapsed >= transition_after + status_delay
                properties = {"status": "completed" if ready else "recording",
                              "file_path": "/data/recordings/synthetic.mkv"}
                if not ready:
                    properties["_hls_dir"] = "/data/recordings/synthetic_hls"
                body = json.dumps({"id": 12, "channel": 1,
                                   "custom_properties": properties}).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                print(f"[hls-fixture] recording status={properties['status']}", flush=True)
                return
            if route.path == "/hls/index.m3u8":
                if completed:
                    self.send_response(302)
                    self.send_header("Location", "/file/")
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    print("[hls-fixture] playlist -> file redirect", flush=True)
                    return
                base = f"http://{self.server.server_address[0]}:{self.server.server_address[1]}/hls/"
                body = "".join(
                    f"{base}{line}\n" if line.startswith("seg_") else f"{line}\n"
                    for line in playlist.splitlines()
                ).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/x-mpegURL")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                print(f"[hls-fixture] playlist bytes={len(body)}", flush=True)
                return
            if re.fullmatch(r"/hls/seg_[0-9]{5}\.ts", route.path):
                if completed:
                    self.send_error(404)
                    return
                path = folder / route.path.rsplit("/", 1)[1]
                return self.serve_file(path, "video/mp2t")
            if route.path in ("/file/", "/api/channels/recordings/12/file/"):
                return self.serve_file(folder / "finished.mkv", "video/x-matroska")
            self.send_error(404)

        def serve_file(self, path: Path, content_type: str):
            if not path.is_file():
                self.send_error(404)
                return
            size = path.stat().st_size
            first, last = 0, size - 1
            requested_range = self.headers.get("Range", "")
            if requested_range:
                match = re.fullmatch(r"bytes=([0-9]+)-([0-9]*)", requested_range)
                if match is None or int(match[1]) >= size:
                    self.send_error(416)
                    return
                first = int(match[1])
                if match[2]:
                    last = min(size - 1, int(match[2]))
                if last < first:
                    self.send_error(416)
                    return
            self.send_response(206 if requested_range else 200)
            self.send_header("Content-Type", content_type)
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Length", str(last - first + 1))
            if requested_range:
                self.send_header("Content-Range", f"bytes {first}-{last}/{size}")
            self.end_headers()
            with path.open("rb") as stream:
                stream.seek(first)
                remaining = last - first + 1
                while remaining:
                    chunk = stream.read(min(65536, remaining))
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        # The Roku HLS parser may abandon the redirected MKV.
                        return
                    remaining -= len(chunk)

    return FixtureHandler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="LAN IPv4 address of this computer")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--duration", type=int, default=40)
    parser.add_argument("--transition-after", type=float, default=25)
    parser.add_argument("--status-delay", type=float, default=0,
                        help="extra seconds before the mock recording status becomes completed")
    args = parser.parse_args()
    host = ipaddress.ip_address(args.host)
    if host.version != 4 or not host.is_private or not 1024 <= args.port <= 65535:
        parser.error("Use a private IPv4 host and a port from 1024 to 65535")
    if not 16 <= args.duration <= 120 or not 0 < args.transition_after <= 120 or not 0 <= args.status_delay <= 60:
        parser.error("Limit media to 16–120 seconds and the transition to 1–120 seconds")
    with tempfile.TemporaryDirectory(prefix="roku-hls-handoff-") as directory:
        folder = Path(directory)
        playlist, segments = build_media(folder, args.duration)
        with ThreadingHTTPServer((args.host, args.port), handler_for(folder, playlist, args.transition_after, args.status_delay)) as server:
            def end_fixture(_signal, _frame):
                raise KeyboardInterrupt

            signal.signal(signal.SIGTERM, end_fixture)
            print(f"[hls-fixture] ready: {segments} segments; transition {args.transition_after:g}s after first playlist request", flush=True)
            print(f"[hls-fixture] URL: http://{args.host}:{args.port}/hls/index.m3u8", flush=True)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass


if __name__ == "__main__":
    main()
