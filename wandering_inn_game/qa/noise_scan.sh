#!/usr/bin/env bash
# Print the engine-noise lines in a Godot log (`grep -n` form); exit 1 if any.
#
# Noise is any SCRIPT ERROR / Parse Error / WARNING / bare `ERROR:` line.
# Deferred (user rulings 2026-10-07, #586): the exact particle-shader leak
# lines Godot prints at shutdown after long journeys -- the headless
# DummyShader RID leak and the windowed (Metal/RD) ParticlesShaderRD and
# RD ShaderE leaks. Any other wording, type or engine line still counts.
set -euo pipefail

LOG="${1:?usage: noise_scan.sh <log>}"
if [ ! -r "$LOG" ]; then
	echo "noise_scan.sh: cannot read $LOG" >&2
	exit 2
fi
KNOWN_586="^[0-9]+:ERROR: [0-9]+ (RID allocations of type '(N13RendererDummy15MaterialStorage11DummyShaderE|N10RendererRD15MaterialStorage6ShaderE)' were leaked at exit\.|shaders of type ParticlesShaderRD were never freed)$"

HITS="$(grep -nE 'SCRIPT ERROR|Parse Error|WARNING|ERROR:' "$LOG" | grep -vE "$KNOWN_586" || true)"
if [ -n "$HITS" ]; then
	printf '%s\n' "$HITS"
	exit 1
fi
