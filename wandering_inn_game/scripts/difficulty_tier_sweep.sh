#!/usr/bin/env bash
# difficulty_tier_sweep.sh -- GH#360 (a). Runs sim_combat_batch.gd's WHOLE cell
# matrix once per difficulty tier (Bronze 0.75 / Silver 1.0 / Gold 1.3, the
# WISettings.DIFFICULTY_DAMAGE_TAKEN_MULTS ladder) and reports the per-cell
# win-rate delta each tier costs or buys.
#
# WHY A SCRIPT AROUND THE HARNESS, NOT A SECOND HARNESS: the 141 cells, their
# builds, rosters, allies, hp mods, companion boons and bounty scaling all live
# in sim_combat_batch.gd. A parallel tier harness would have to clone every one
# of them and would drift the first time a cell moved. The harness grew ONE env
# hook (WI_DIFFICULTY_MULT, doc-commented there); this script drives it and does
# the cross-tier arithmetic. Same relationship harness_shard_diff.sh has to the
# same file.
#
# Usage:
#   scripts/difficulty_tier_sweep.sh [--runs-note TEXT]
#
# Output: qa_output/difficulty_tier_sweep/{plain,bronze,silver,gold}.txt plus a
# report on stdout. Exit 0 = the sweep ran and the INERT-AT-SILVER proof held.
#
# THE ONE THING THIS SCRIPT ASSERTS (everything else is report-only, per #360's
# harness-first contract): the x1.0 leg must be byte-identical to a plain,
# env-unset run. That is the standing promise the difficulty knob was shipped
# with -- "Silver is 1.0 IS the shipped balance, so every balance cell stays
# byte-identical by construction" (wi_combat.gd's own field comment) -- and it
# is exactly the promise a hook like this could silently break.
#
# GATE PROPOSALS (report-only until ratified, #211 precedent): the report prints
# the three signals #360 named -- monotonicity per cell, the Bronze/Gold extreme
# flips (a cell reaching 0.00 or 1.00 at a tier where Silver did not), and the
# largest tier deltas. Ratified thresholds land as a --gate mode here, never as
# a band inside sim_combat_batch.gd (its bands are Silver's contract).
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"        # wandering_inn_game/
GODOT=/usr/local/bin/godot
SCRIPT_RES="res://tests/sim_combat_batch.gd"
OUTDIR="$HERE/qa_output/difficulty_tier_sweep"
ALARM=900

NOTE=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--runs-note=*) NOTE="${1#*=}" ;;
		--runs-note) shift; NOTE="${1:?--runs-note requires TEXT}" ;;
		*) echo "difficulty_tier_sweep.sh: unknown argument '$1'" >&2; exit 2 ;;
	esac
	shift
done

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

run_leg() {  # $1=label  $2=mult ("" = plain, env unset)
	local label="$1" mult="$2" out="$OUTDIR/$1.txt"
	echo "== leg $label (mult=${mult:-unset}) =="
	if [ -z "$mult" ]; then
		perl -e "alarm $ALARM; exec @ARGV" "$GODOT" --headless --path "$HERE" --script "$SCRIPT_RES" >"$out" 2>&1
	else
		WI_DIFFICULTY_MULT="$mult" perl -e "alarm $ALARM; exec @ARGV" "$GODOT" --headless --path "$HERE" --script "$SCRIPT_RES" >"$out" 2>&1
	fi
	local rc=$?
	if [ "$rc" -ne 0 ]; then
		echo "difficulty_tier_sweep.sh: leg $label exited $rc -- see $out" >&2
		exit 1
	fi
	if grep -qE 'SCRIPT ERROR|Parse Error|WARNING|ERROR:' "$out"; then
		echo "difficulty_tier_sweep.sh: leg $label printed an engine error/warning -- see $out" >&2
		grep -nE 'SCRIPT ERROR|Parse Error|WARNING|ERROR:' "$out" >&2
		exit 1
	fi
}

run_leg plain  ""
run_leg bronze "0.75"
run_leg silver "1.0"
run_leg gold   "1.3"

exec python3 "$HERE/scripts/difficulty_tier_report.py" "$OUTDIR" --note "$NOTE"
