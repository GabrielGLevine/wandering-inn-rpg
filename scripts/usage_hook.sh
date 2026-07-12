#!/bin/bash
# PostToolUse hook: injects a notice ONLY when the usage tier changes.
# Fail-soft by design — must never block a tool call (public repo:
# contributors without the claude CLI or python3 get a silent no-op).
command -v python3 >/dev/null 2>&1 || exit 0
python3 "$(cd "$(dirname "$0")" && pwd)/usage_guard.py" hook 2>/dev/null
exit 0
