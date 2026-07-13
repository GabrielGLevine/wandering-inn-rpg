#!/usr/bin/env bash
# harness_shard_diff.sh -- formalizes the stash-baseline byte-identity
# method ("Nx cells byte-identical to pre-wave main" HANDOFF entries):
# partitions sim_combat_batch.gd's cells across N godot processes
# (WI_CELL_RANGE) and diffs each shard's stdout between the current tree
# and a baseline git ref, run in parallel. tests/sim_combat_batch.gd stays
# the single-process source of truth for gating (this is speed + a
# regression-proof harness AROUND it, never a replacement).
#
# Usage:
#   scripts/harness_shard_diff.sh [--shards N] [--baseline-ref REF]
#   Defaults: --shards 4 --baseline-ref main
#
# A shard is "byte-identical" iff nothing outside its own cell range
# changed the fights in it -- per-cell seeds are local (1..RUNS_PER_CELL
# every cell, never a shared stream), so a real balance change should only
# perturb the shard(s) holding the cells it actually touches; every other
# shard diffing clean is the same regression proof the manual `git stash`
# + full-run diff always gave, now parallel and partial-range capable.
#
# CAVEAT: --baseline-ref must point at a commit whose OWN
# tests/sim_combat_batch.gd already understands WI_CELL_RANGE (this
# script's own feature) -- an older baseline ignores the env var and runs
# the FULL harness for every shard request, which this script detects and
# refuses (a partial-range current shard against a full-range baseline
# shard is not a meaningful diff).
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"        # wandering_inn_game/
REPO_ROOT="$(cd "$HERE/.." && pwd)"
GODOT=/usr/local/bin/godot
SCRIPT_RES="res://tests/sim_combat_batch.gd"
LOGDIR="$HERE/qa_output/harness_shard_logs"

SHARDS=4
BASELINE_REF="main"
while [ "$#" -gt 0 ]; do
	case "$1" in
		--shards=*) SHARDS="${1#*=}" ;;
		--shards) shift; SHARDS="${1:?--shards requires N}" ;;
		--baseline-ref=*) BASELINE_REF="${1#*=}" ;;
		--baseline-ref) shift; BASELINE_REF="${1:?--baseline-ref requires a git ref}" ;;
		*) echo "harness_shard_diff.sh: unknown argument '$1'" >&2; exit 2 ;;
	esac
	shift
done
case "$SHARDS" in
	''|*[!0-9]*) echo "harness_shard_diff.sh: --shards must be a positive integer, got '$SHARDS'" >&2; exit 2 ;;
esac
if [ "$SHARDS" -lt 1 ]; then
	echo "harness_shard_diff.sh: --shards must be >= 1" >&2
	exit 2
fi

rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"

cell_count() {  # $1=project path -> prints WI_CELL_COUNT or "" on failure
	local proj="$1"
	WI_CELL_COUNT_ONLY=1 "$GODOT" --headless --path "$proj" --script "$SCRIPT_RES" 2>/dev/null \
		| grep -oE 'WI_CELL_COUNT: [0-9]+' | grep -oE '[0-9]+'
}

TOTAL="$(cell_count "$HERE")"
if [ -z "$TOTAL" ]; then
	echo "harness_shard_diff: FATAL -- could not read WI_CELL_COUNT from the current tree's sim_combat_batch.gd" >&2
	echo "  (WI_CELL_COUNT_ONLY support missing? this script requires it -- see ARCH-1 QA-tiering task)" >&2
	exit 1
fi

# Baseline checkout: a detached linked worktree at BASELINE_REF -- never
# touches the caller's own working tree, index, or stash.
BASE_WT="$(mktemp -d "${TMPDIR:-/tmp}/wi-harness-baseline-XXXXXX")"
if ! git -C "$REPO_ROOT" worktree add -f --detach "$BASE_WT" "$BASELINE_REF" >/dev/null 2>&1; then
	echo "harness_shard_diff: FATAL -- 'git worktree add' failed for ref '$BASELINE_REF'" >&2
	rmdir "$BASE_WT" 2>/dev/null
	exit 1
fi
cleanup() { git -C "$REPO_ROOT" worktree remove --force "$BASE_WT" >/dev/null 2>&1; }
trap cleanup EXIT
BASE_PROJ="$BASE_WT/wandering_inn_game"

BASE_TOTAL="$(cell_count "$BASE_PROJ")"
if [ -z "$BASE_TOTAL" ]; then
	echo "harness_shard_diff: FATAL -- baseline ref '$BASELINE_REF' has no WI_CELL_COUNT_ONLY support" >&2
	echo "  (its tests/sim_combat_batch.gd predates the WI_CELL_RANGE sharding hooks -- pick a newer baseline ref)" >&2
	exit 1
fi
if [ "$BASE_TOTAL" != "$TOTAL" ]; then
	echo "harness_shard_diff: NOTE -- cell count differs (current=$TOTAL baseline=$BASE_TOTAL);"
	echo "  shard boundaries are computed from the CURRENT tree's count, baseline cells beyond it are its own business."
fi
echo "harness_shard_diff: $TOTAL cells (current) / $BASE_TOTAL cells (baseline '$BASELINE_REF'), $SHARDS shard(s)"

PER=$(( (TOTAL + SHARDS - 1) / SHARDS ))
FAILURES=0

for i in $(seq 0 $((SHARDS - 1))); do
	LO=$((i * PER))
	if [ "$LO" -ge "$TOTAL" ]; then break; fi
	HI=$((LO + PER - 1))
	if [ "$HI" -ge "$TOTAL" ]; then HI=$((TOTAL - 1)); fi
	RANGE="$LO:$HI"
	CUR_LOG="$LOGDIR/shard_${i}_current.log"
	BASE_LOG="$LOGDIR/shard_${i}_baseline.log"
	echo "==> shard $i: cells $RANGE"
	WI_CELL_RANGE="$RANGE" "$GODOT" --headless --path "$HERE" --script "$SCRIPT_RES" >"$CUR_LOG" 2>&1 &
	CUR_PID=$!
	WI_CELL_RANGE="$RANGE" "$GODOT" --headless --path "$BASE_PROJ" --script "$SCRIPT_RES" >"$BASE_LOG" 2>&1 &
	BASE_PID=$!
	wait "$CUR_PID"; CUR_RC=$?
	wait "$BASE_PID"; BASE_RC=$?
	# rc 1 = the harness's own gated-cell bounds FAIL, still a valid run to
	# diff (a shard-local balance regression IS the finding); anything else
	# (crash, WITestWatchdog timeout) is a hard tooling failure, not a diff.
	if [ "$CUR_RC" -gt 1 ]; then
		echo "FAIL  shard $i -- current tree exit $CUR_RC (crash/timeout, not a normal PASS/FAIL)"
		FAILURES=$((FAILURES + 1)); continue
	fi
	if [ "$BASE_RC" -gt 1 ]; then
		echo "FAIL  shard $i -- baseline tree exit $BASE_RC (crash/timeout, not a normal PASS/FAIL)"
		FAILURES=$((FAILURES + 1)); continue
	fi
	if diff -q "$BASE_LOG" "$CUR_LOG" >/dev/null; then
		echo "same  shard $i"
	else
		echo "DIFF  shard $i -- current tree differs from '$BASELINE_REF':"
		diff -u "$BASE_LOG" "$CUR_LOG" | sed 's/^/    /'
		FAILURES=$((FAILURES + 1))
	fi
done

echo ""
if [ "$FAILURES" -eq 0 ]; then
	echo "harness_shard_diff: all shards byte-identical to '$BASELINE_REF'."
	exit 0
fi
echo "harness_shard_diff: $FAILURES shard(s) differ from '$BASELINE_REF' -- logs in $LOGDIR"
exit 1
