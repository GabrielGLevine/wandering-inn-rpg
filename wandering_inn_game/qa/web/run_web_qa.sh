#!/usr/bin/env bash
# Full headless web QA: (re-)export, then drive under headless Chromium.
# Usage: qa/web/run_web_qa.sh <script-name> [seed] [--skip-export] [--touch] [--device=iphone|android] [--portrait-entry]
# --touch (issue #105, the #106 prerequisite): drives the run through a
# Playwright touch-capable browser context (hasTouch) instead of the default
# mouse-reporting one -- see run_web_qa.mjs's hasTouch comment for exactly
# what this does and doesn't prove.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:?usage: run_web_qa.sh <script-name> [seed] [--skip-export] [--touch]}"
SEED=""
SKIP_EXPORT=""
TOUCH=""
PASS=()
for arg in "${@:2}"; do
	if [ "$arg" = "--skip-export" ]; then
		SKIP_EXPORT="1"
	elif [ "$arg" = "--touch" ]; then
		TOUCH="1"
	elif [[ "$arg" == --device=* ]] || [ "$arg" = "--portrait-entry" ]; then
		# #503: emulated phone preset / portrait-entry rotation probe (see run_web_qa.mjs).
		PASS+=("$arg")
	else
		SEED="$arg"
	fi
done
if [ -z "$SKIP_EXPORT" ]; then
	"$HERE/export_web.sh"
fi
cd "$HERE" && node run_web_qa.mjs "$NAME" "$SEED" ${TOUCH:+--touch} ${PASS[@]+"${PASS[@]}"}
