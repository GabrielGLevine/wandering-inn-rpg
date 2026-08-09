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
say() { printf '%s\n' "$*"; }
run() { # run <label> <cmd...> -- rc!=0 fails the bundle, output shown on failure
	local label="$1"; shift
	local out
	if out=$("$@" 2>&1); then
		say "ok   $label"
	else
		say "FAIL $label"; printf '%s\n' "$out" | tail -8; fail=1
	fi
}
run "data_lint"            python3 "$ROOT/wandering_inn_game/scripts/data_lint.py"
run "verify-untouched"     python3 "$ROOT/wandering_inn_game/qa/scripts/extract_prose.py" verify-untouched
run "extract_prose self-test" python3 "$ROOT/wandering_inn_game/qa/scripts/extract_prose.py" self-test
run "qa surfaces --check"  python3 "$ROOT/wandering_inn_game/scripts/derive_qa_surfaces.py" --check
run "guidance mirrors"     python3 "$ROOT/scripts/sync_agent_guidance.py"
run "doc drift"            python3 "$ROOT/scripts/check_doc_drift.py"
# one Godot suite always: the registry catches missing sheets/regions/uids
unit() { # unit <name> -- grep discipline: SCRIPT ERROR|Parse Error|ERROR: FAIL == 0 AND ^PASS present
	local name="$1" out bad pas
	out=$(perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path "$ROOT/wandering_inn_game" --script "res://tests/$name.gd" 2>&1)
	bad=$(printf '%s' "$out" | grep -cE 'SCRIPT ERROR|Parse Error|ERROR: FAIL')
	pas=$(printf '%s' "$out" | grep -c '^PASS')
	if [ "$bad" -eq 0 ] && [ "$pas" -ge 1 ]; then say "ok   unit $name"; else
		say "FAIL unit $name (badlines=$bad pass=$pas)"; printf '%s\n' "$out" | grep -E 'SCRIPT ERROR|ERROR: FAIL' | head -5; fail=1; fi
}
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
