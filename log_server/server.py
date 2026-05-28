#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from json import dumps, loads
from time import strftime
from urllib.parse import parse_qs

HOST = "0.0.0.0"
PORT = 80


def print_log(turtle_id, level, message):
    timestamp = strftime("%Y-%m-%d %H:%M:%S")
    print(
        f"[{timestamp}] turtle={turtle_id or 'unknown'} "
        f"level={level or 'info'} {message or ''}",
        flush=True,
    )


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length).decode("utf-8", errors="replace")

        try:
            data = loads(raw)
            turtle_id = data.get("id")
            level = data.get("level")
            message = data.get("message")
        except Exception:
            data = parse_qs(raw)
            turtle_id = (data.get("id") or ["unknown"])[0]
            level = (data.get("level") or ["info"])[0]
            message = (data.get("message") or [""])[0]

        print_log(turtle_id, level, message)

        body = dumps({"ok": True}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        body = b"ok\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Listening for turtle logs on {HOST}:{PORT}", flush=True)
    server.serve_forever()
