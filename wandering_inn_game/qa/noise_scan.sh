#!/usr/bin/env bash
# Print the engine-noise lines in a Godot log (`grep -n` form); exit 1 if any.
#
# Noise is any SCRIPT ERROR / Parse Error / WARNING / bare `ERROR:` line.
# ONE deferral (user ruling 2026-10-07, #586): the exact macOS headless
# shutdown leak of particle DummyShader RIDs, printed after QA_RESULT by long
# journeys. Any other wording, type or engine line still counts as noise.
set -euo pipefail

LOG="${1:?usage: noise_scan.sh <log>}"
KNOWN_586="^[0-9]+:ERROR: [0-9]+ RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit\.$"

HITS="$(grep -nE 'SCRIPT ERROR|Parse Error|WARNING|ERROR:' "$LOG" | grep -vE "$KNOWN_586" || true)"
if [ -n "$HITS" ]; then
	printf '%s\n' "$HITS"
	exit 1
fi
