#!/bin/bash
# PostToolUse hook: injects a notice ONLY when the usage tier changes.
# Fail-soft by design — must never block a tool call (public repo:
# contributors without the claude CLI or python3 get a silent no-op).
command -v python3 >/dev/null 2>&1 || exit 0
if [ -n "${CODEX_CI:-}${CODEX_THREAD_ID:-}" ] || [ "${WI_AGENT_PROVIDER:-}" = "codex" ]; then
	python3 "$(cd "$(dirname "$0")" && pwd)/codex_usage_guard.py" hook 2>/dev/null
	exit 0
fi
python3 "$(cd "$(dirname "$0")" && pwd)/usage_guard.py" hook 2>/dev/null
exit 0
