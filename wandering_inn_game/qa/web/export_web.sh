#!/usr/bin/env bash
# Export the web build. Usage: qa/web/export_web.sh
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$PROJ/build/web"
/usr/local/bin/godot --headless --path "$PROJ" --export-release "Web" build/web/index.html
ls -la "$PROJ/build/web"
