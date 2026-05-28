#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from json import dumps, loads
from time import strftime

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
        except Exception:
            self.send_response(400)
            self.end_headers()
            return

        # Loki push API format: { "streams": [{ "stream": {...}, "values": [[ts, json_line], ...] }] }
        for stream in data.get("streams", []):
            for entry in stream.get("values", []):
                line = entry[1] if len(entry) > 1 else "{}"
                try:
                    fields = loads(line)
                except Exception:
                    fields = {"message": line}
                print_log(
                    fields.get("turtle_id", "unknown"),
                    fields.get("level", "info"),
                    fields.get("message", ""),
                )

        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        body = b"ok\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt, *args):
        return


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Listening for turtle logs on {HOST}:{PORT}", flush=True)
    server.serve_forever()
