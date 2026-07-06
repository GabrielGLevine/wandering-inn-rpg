#!/usr/bin/env bash
# serve_web.sh — serve the Godot wasm build locally with the COOP/COEP headers a
# Godot 4 web export needs for SharedArrayBuffer (M-RELEASE Task R3).
#
# The existing web QA loop (qa/web/run_web_qa.mjs) does NOT run a real HTTP
# server — it feeds the build to headless Chromium via Playwright request
# interception, so there is nothing there to reuse for a browser you open by
# hand. This is that missing piece: a plain static server that sets
#   Cross-Origin-Opener-Policy: same-origin
#   Cross-Origin-Embedder-Policy: require-corp
# on every response (itch.io's "SharedArrayBuffer support" toggle does the same
# thing on the hosted page). Use it to smoke the export in a real browser.
#
# Usage:
#   scripts/serve_web.sh                 # serves wandering_inn_game_v4/build/web on :8000
#   scripts/serve_web.sh 8080            # custom port
#   scripts/serve_web.sh 8080 path/to/web
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PORT="${1:-8000}"
DIR="${2:-$ROOT/wandering_inn_game_v4/build/web}"

if [ ! -d "$DIR" ]; then
  echo "serve_web.sh: build dir not found: $DIR" >&2
  echo "  Export it first, e.g.: wandering_inn_game_v4/qa/web/export_web.sh" >&2
  exit 1
fi
if [ ! -f "$DIR/index.html" ]; then
  echo "serve_web.sh: $DIR has no index.html — is this a finished web export?" >&2
  exit 1
fi

echo "Serving $DIR"
echo "  http://localhost:${PORT}/  (COOP: same-origin, COEP: require-corp)"

exec python3 - "$PORT" "$DIR" <<'PY'
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

port = int(sys.argv[1])
directory = sys.argv[2]


class COOPHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self):
        # The two headers Godot 4 wasm needs for SharedArrayBuffer / threads.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # No caching, so a re-export is always what you see on refresh.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


with ThreadingHTTPServer(("127.0.0.1", port), COOPHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
PY
