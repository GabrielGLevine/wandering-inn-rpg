#!/usr/bin/env bash
# Full headless web QA: (re-)export, then drive under headless Chromium.
# Usage: qa/web/run_web_qa.sh <script-name> [seed] [--skip-export]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:?usage: run_web_qa.sh <script-name> [seed] [--skip-export]}"
SEED=""
SKIP_EXPORT=""
for arg in "${@:2}"; do
	if [ "$arg" = "--skip-export" ]; then
		SKIP_EXPORT="1"
	else
		SEED="$arg"
	fi
done
if [ -z "$SKIP_EXPORT" ]; then
	"$HERE/export_web.sh"
fi
cd "$HERE" && node run_web_qa.mjs "$NAME" "$SEED"
