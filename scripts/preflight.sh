#!/usr/bin/env bash
# preflight.sh -- the wave-close gate bundle (retrospective tooling, 2026-08-09).
#
# WHY: per-gate memory is the weak link. verify-untouched drift sat hidden
# across two waves and the ice-sink bug across many because each gate relied
# on someone remembering it covers this wave's surface. Run THIS at every
# wave close instead; it is the habit, the gates are the details.
#
# Usage:  scripts/preflight.sh          # fast tier (~seconds + one Godot boot)
#         scripts/preflight.sh --full   # + every unit suite (minutes)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="/usr/local/bin/godot"
fail=0
ARTIFACT_DIR="${PREFLIGHT_ARTIFACT_DIR:-}"
say() { printf '%s\n' "$*"; }
artifact_dir() {
	if [ -z "$ARTIFACT_DIR" ]; then
		ARTIFACT_DIR="${TMPDIR:-/tmp}/wi-preflight-$(date -u +%Y%m%dT%H%M%SZ)-$$"
	fi
	umask 077
	if ! mkdir -p "$ARTIFACT_DIR"; then
		say "FAIL cannot create preflight artifact directory: $ARTIFACT_DIR"
		exit 1
	fi
}
run() { # run <label> <cmd...> -- preserve complete logs and process status
	local label="$1" safe log rc; shift
	artifact_dir
	safe=$(printf '%s' "$label" | tr -c 'A-Za-z0-9_.-' '_')
	log="$ARTIFACT_DIR/gate-$safe.log"
	"$@" >"$log" 2>&1
	rc=$?
	printf '%s\n' "$rc" >"$log.process-exit"
	if [ "$rc" -eq 0 ]; then
		say "ok   $label"
	else
		say "FAIL $label (rc=$rc)"
		say "full log: $log"
		tail -8 "$log" | cut -c1-240
		fail=1
	fi
}
unit() { # unit <name> [cmd...] -- rc=0, zero noise, and ^PASS are all required
	local name="$1" safe log rc bad pas verdict=0
	shift
	artifact_dir
	safe=$(printf '%s' "$name" | tr -c 'A-Za-z0-9_.-' '_')
	log="$ARTIFACT_DIR/unit-$safe.log"
	if [ "$#" -gt 0 ]; then
		"$@" >"$log" 2>&1
		rc=$?
	else
		perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path "$ROOT/wandering_inn_game" --script "res://tests/$name.gd" >"$log" 2>&1
		rc=$?
	fi
	printf '%s\n' "$rc" >"$log.process-exit"
	bad=$(grep -cE 'WARNING|SCRIPT ERROR|Parse Error|ERROR:' "$log" || true)
	pas=$(grep -c '^PASS' "$log" || true)
	if [ "$rc" -eq 0 ] && [ "$bad" -eq 0 ] && [ "$pas" -ge 1 ]; then
		say "ok   unit $name"
	else
		verdict=1
		say "FAIL unit $name (rc=$rc badlines=$bad pass=$pas)"
		say "full log: $log"
		grep -E 'WARNING|SCRIPT ERROR|Parse Error|ERROR:' "$log" | head -5 | cut -c1-240
		tail -3 "$log" | cut -c1-240
		fail=1
	fi
	printf '{"process_exit":%s,"noise_lines":%s,"pass_markers":%s,"gate_exit":%s}\n' "$rc" "$bad" "$pas" "$verdict" >"$log.verdict.json"
}

# Process-level regression seam used by scripts/tests/test_preflight.py.
if [ "${1:-}" = "--unit-command" ]; then
	if [ "$#" -lt 3 ]; then
		say "usage: $0 --unit-command <label> <command> [args...]"
		exit 2
	fi
	name="$2"
	shift 2
	unit "$name" "$@"
	exit "$fail"
fi
run "data_lint"            python3 "$ROOT/wandering_inn_game/scripts/data_lint.py"
run "verify-untouched"     python3 "$ROOT/wandering_inn_game/qa/scripts/extract_prose.py" verify-untouched
run "extract_prose self-test" python3 "$ROOT/wandering_inn_game/qa/scripts/extract_prose.py" self-test
run "qa surfaces --check"  python3 "$ROOT/wandering_inn_game/scripts/derive_qa_surfaces.py" --check
run "guidance mirrors"     python3 "$ROOT/scripts/sync_agent_guidance.py"
run "doc drift"            python3 "$ROOT/scripts/check_doc_drift.py"
# GH#429 review LOW-3: the python suites gate the TOOLING -- every data_lint
# tier's own can-fail proof, the reachability promotion fences, the usage/asset
# guards. Nothing invoked them on a schedule, which is how four
# SKILL/ITEM_CODE_GRANTS pins sat rotted-red on main across two waves: the
# allowlist read-back was shouting into a suite no gate ran. Cheap (~8s, no
# Godot boot), so it belongs in the FAST tier rather than behind --full.
run "python tool suites"   python3 -m pytest -q "$ROOT/scripts/tests"
# one Godot suite always: the registry catches missing sheets/regions/uids
unit test_sprite_registry
if [ "${1:-}" = "--full" ]; then
	for t in "$ROOT"/wandering_inn_game/tests/test_*.gd; do
		n=$(basename "$t" .gd)
		[ "$n" = "test_sprite_registry" ] && continue
		unit "$n"
	done
fi
if [ "$fail" -eq 0 ]; then say "PREFLIGHT: ALL GREEN"; else say "PREFLIGHT: FAILURES ABOVE"; fi
exit "$fail"
