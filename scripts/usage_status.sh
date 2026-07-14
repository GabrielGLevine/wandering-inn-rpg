#!/bin/bash
# Usage tier check — OK/CAUTION/WINDDOWN/QUIESCE. Protocol: wi-usage-guard skill.
# Exit codes: 0 OK|UNKNOWN, 10 CAUTION, 20 WINDDOWN, 30 QUIESCE.
# Claude telemetry is provider-scoped. Codex must never inherit it.
command -v python3 >/dev/null 2>&1 || { echo "UNKNOWN | python3 missing"; exit 0; }
if [ -n "${CODEX_CI:-}${CODEX_THREAD_ID:-}" ] || [ "${WI_AGENT_PROVIDER:-}" = "codex" ]; then
	exec python3 "$(cd "$(dirname "$0")" && pwd)/codex_usage_guard.py" "$@"
fi
exec python3 "$(cd "$(dirname "$0")" && pwd)/usage_guard.py" status "$@"
