#!/usr/bin/env bash
# ci_sweep.sh — run every canonical QA playtest at its pinned seed and fail on
# ANY red run OR any SCRIPT ERROR / Parse Error / WARNING in a run's log.
# This is the grep discipline (wandering_inn_game_v4/CLAUDE.md: "ZERO
# known-harmless warnings") enforced IN CI, not just by convention.
#
# Usage:
#   qa/ci_sweep.sh                       # full canonical sweep
#   qa/ci_sweep.sh --only a,b,c          # restrict to a comma-separated subset
#   CI_SWEEP_TIMEOUT=300 qa/ci_sweep.sh  # override per-script alarm (seconds)
#
# Exit: 0 iff every selected script ran green AND no log tripped the grep;
#       nonzero (count of failures) otherwise.
#
# --- CANONICAL LIST ---------------------------------------------------------
# No qa/ manifest exists, so this list is HARDCODED and MIRRORS the
# "Canonical QA seed table" in wandering_inn_game_v4/CLAUDE.md (37 headless
# scripts as of Content Wave C3 — C1 added sewers_walkthrough [34]; C3 adds
# cisterns_fight / cisterns_talk / cisterns_scout [35-37] — tutorial_flow is
# canonical; level_up_loop / defeat_ally_alive / combat_move_input / crate_fight /
# crate_talk / field_skills_loop / social_loop / sewers_walkthrough / cisterns_*
# are fixture-based, their fixture rng overrides the CLI seed, the listed seed is
# convention). Keep the two in sync when scripts/seeds change. Peek-only
# utilities (title_peek, street_peek) are intentionally excluded. A seed of
# "none" means the script takes no --seed.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_QA="$HERE/run_qa.sh"
SCRIPTS_DIR="$HERE/scripts"
LOGDIR="$HERE/../qa_output/ci_sweep_logs"
PER_SCRIPT_TIMEOUT="${CI_SWEEP_TIMEOUT:-240}"

# script:seed pairs — mirrors the CLAUDE.md canonical table.
CANON=(
	"load_gate:none"
	"inn_walkthrough:9"
	"dialogue_walkthrough:9"
	"dialogue_hub_loop:9"
	"quest_errand_fight:9"
	"quest_errand_parley:9"
	"save_load_roundtrip:9"
	"combat_walkthrough:9"
	"tutorial_flow:9"
	"level_up_loop:9"
	"mage_unlock_loop:9"
	"line_of_sight_denial:9"
	"defeat_reload:1"
	"defeat_ally_alive:3"
	"title_flow:9"
	"combat_move_input:9"
	"class_evolution_loop:9"
	"consolidation_flow:9"
	"save_migration:1"
	"consolidation_reload:9"
	"generalist_loop:9"
	"lantern_check:9"
	"gate_district_walkthrough:9"
	"relc_tutorial:9"
	"work_loop:9"
	"crate_fight:9"
	"crate_talk:9"
	"crate_light:9"
	"journal_skills:9"
	"inventory_loop:9"
	"atmosphere_check:9"
	"field_skills_loop:9"
	"social_loop:9"
	"sewers_walkthrough:9"
	"cisterns_fight:9"
	"cisterns_talk:9"
	"cisterns_scout:9"
)

ONLY=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--only=*) ONLY="${1#*=}" ;;
		--only) shift; ONLY="${1:?--only requires a comma-separated script list}" ;;
		*) echo "ci_sweep.sh: unknown argument '$1'" >&2; exit 2 ;;
	esac
	shift
done

# Build the run list (respecting --only, preserving order + validating names).
declare -a RUNLIST=()
if [ -n "$ONLY" ]; then
	IFS=',' read -r -a WANT <<< "$ONLY"
	for w in "${WANT[@]}"; do
		found=""
		for pair in "${CANON[@]}"; do
			if [ "${pair%%:*}" = "$w" ]; then RUNLIST+=("$pair"); found=1; break; fi
		done
		if [ -z "$found" ]; then
			# Not a known canonical name — keep it with an "unknown" seed so the
			# per-script guard below reports it as a real failure (this is how a
			# deliberately-bad --only name is caught, not silently skipped).
			RUNLIST+=("$w:none")
		fi
	done
else
	RUNLIST=("${CANON[@]}")
fi

rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"

FAILURES=0
FAILED_NAMES=()

for pair in "${RUNLIST[@]}"; do
	NAME="${pair%%:*}"
	SEED="${pair#*:}"
	LOG="$LOGDIR/$NAME.log"

	# Pre-flight: a missing script file is an immediate failure (also the
	# deterministic path for catching a bad --only name).
	if [ ! -f "$SCRIPTS_DIR/$NAME.json" ]; then
		echo "FAIL  $NAME — no such QA script ($SCRIPTS_DIR/$NAME.json)"
		FAILURES=$((FAILURES + 1)); FAILED_NAMES+=("$NAME(missing)")
		continue
	fi

	# Assemble the run_qa.sh invocation (load_gate takes no seed).
	ARGS=("$NAME" "headless")
	if [ "$SEED" != "none" ]; then ARGS+=("--seed=$SEED"); fi

	echo "==> $NAME (seed=$SEED, timeout=${PER_SCRIPT_TIMEOUT}s)"
	# Alarm-wrap the whole run so a hung script can never wedge the sweep.
	perl -e 'alarm shift; exec @ARGV' "$PER_SCRIPT_TIMEOUT" \
		bash "$RUN_QA" "${ARGS[@]}" >"$LOG" 2>&1
	RC=$?

	SCRIPT_FAIL=0
	if [ "$RC" -ne 0 ]; then
		echo "FAIL  $NAME — run_qa.sh exit $RC (124=alarm/timeout)"
		SCRIPT_FAIL=1
	fi

	# Grep discipline: any SCRIPT ERROR / Parse Error / WARNING is a failure.
	# The godot_ai MCP capture-registration line is the ONE exempt line
	# ("[godot_ai game_helper] registered mcp capture ...").
	HITS="$(grep -nE 'SCRIPT ERROR|Parse Error|WARNING' "$LOG" | grep -v 'godot_ai game_helper' || true)"
	if [ -n "$HITS" ]; then
		echo "FAIL  $NAME — log tripped the error/warning grep:"
		echo "$HITS" | sed 's/^/        /'
		SCRIPT_FAIL=1
	fi

	if [ "$SCRIPT_FAIL" -ne 0 ]; then
		FAILURES=$((FAILURES + 1)); FAILED_NAMES+=("$NAME")
	else
		echo "ok    $NAME"
	fi
done

echo ""
echo "=================================================================="
if [ "$FAILURES" -eq 0 ]; then
	echo "ci_sweep: ALL ${#RUNLIST[@]} script(s) green, no grep hits."
	exit 0
fi
echo "ci_sweep: ${FAILURES} of ${#RUNLIST[@]} script(s) FAILED: ${FAILED_NAMES[*]}"
echo "logs: $LOGDIR"
exit 1
