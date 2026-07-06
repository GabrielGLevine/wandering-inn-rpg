#!/usr/bin/env bash
# check_fallback_boot.sh — the R2 fallback-art CONTRACT proof.
#
# Simulates a PUBLIC checkout (no private asset bundle): rsyncs the project to a
# throwaway scratch dir MINUS every path listed in assets_manifest.json (and its
# .import sidecar) AND the .godot import cache (so nothing resolves a
# now-missing sheet from a stale cache), then boots + runs a representative
# slice of the QA gate there. A public contributor without the bundle must get:
# a game that BOOTS, renders legible placeholder chips (WISpriteRegistry), runs
# silent (WIAudio), and passes QA — no assert/crash on any missing asset.
#
# Grep discipline mirrors qa/ci_sweep.sh (SCRIPT ERROR|Parse Error|WARNING is a
# failure) with ONE extra exemption scoped to THIS script: the expected
# "[fallback_art] ..." lines the fallback path prints for each missing asset.
#
# Usage:   qa/check_fallback_boot.sh
# Env:     FALLBACK_BOOT_TIMEOUT=300  (per-run alarm seconds, default 240)
# Exit:    0 iff every step ran green AND no log tripped the grep; nonzero else.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/.." && pwd)"
MANIFEST="$PROJ/assets_manifest.json"
GODOT="/usr/local/bin/godot"
PER_RUN_TIMEOUT="${FALLBACK_BOOT_TIMEOUT:-240}"

if [ ! -f "$MANIFEST" ]; then
	echo "check_fallback_boot: no manifest at $MANIFEST" >&2
	exit 2
fi

SCRATCH="$(mktemp -d -t wi_fallback_boot.XXXXXX)"
LOGDIR="$PROJ/qa_output/fallback_boot_logs"
rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

echo "==> fallback-boot scratch: $SCRATCH"
echo "==> logs:                  $LOGDIR"

# --- Build the scratch copy = a faithful PUBLIC checkout -------------------
# A real public repo is a `git clone`: exactly the git-TRACKED files, nothing
# else (no untracked scratch, no .godot import
# cache). So we drive rsync from `git ls-files` MINUS the manifest paths (and
# their .import sidecars) — that is precisely "what a contributor gets, minus
# the private bundle". Anything untracked never enters the scratch.
INCLUDE="$LOGDIR/rsync-include.txt"
TRACKED="$LOGDIR/tracked.txt"
git -C "$PROJ" ls-files > "$TRACKED"
python3 - "$MANIFEST" "$TRACKED" "$INCLUDE" <<'PY'
import json, sys
manifest, tracked_file, out = sys.argv[1], sys.argv[2], sys.argv[3]
protected = set()
for e in json.load(open(manifest))["assets"]:
    protected.add(e["path"]); protected.add(e["path"] + ".import")
tracked = [l.rstrip("\n") for l in open(tracked_file) if l.strip()]
kept = [p for p in tracked if p not in protected]
open(out, "w").write("\n".join(kept) + "\n")
print("tracked=%d protected-stripped=%d kept=%d"
      % (len(tracked), len(protected), len(kept)))
PY
echo "==> scratch = tracked files minus $(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["assets"]))' "$MANIFEST") manifest path(s)"

rsync -a --files-from="$INCLUDE" "$PROJ/" "$SCRATCH/"

# Sanity: the protected files really are gone from the scratch tree.
LEAKS=0
while IFS= read -r rel; do
	case "$rel" in /.godot/*|/.godot_home/*|/qa_output/*|/.import/*) continue ;; esac
	if [ -e "$SCRATCH$rel" ]; then
		echo "LEAK  $rel still present in scratch" ; LEAKS=$((LEAKS+1))
	fi
done < <(python3 -c 'import json,sys;[print("/"+e["path"]) for e in json.load(open(sys.argv[1]))["assets"]]' "$MANIFEST")
if [ "$LEAKS" -ne 0 ]; then
	echo "check_fallback_boot: $LEAKS protected path(s) leaked into scratch — abort" >&2
	exit 3
fi

FAILURES=0
FAILED=()

# run_step NAME LOGFILE -- alarm-wrap a command, capture its log, grep it.
# The command is whatever follows after the two positional args.
run_step() {
	local name="$1" log="$2"; shift 2
	echo "==> $name"
	perl -e 'alarm shift; exec @ARGV' "$PER_RUN_TIMEOUT" "$@" >"$log" 2>&1
	local rc=$?
	local step_fail=0
	if [ "$rc" -ne 0 ]; then
		echo "FAIL  $name — exit $rc (124=alarm/timeout)"
		step_fail=1
	fi
	# Grep discipline: fallback_art lines are EXPECTED here and exempt.
	local hits
	hits="$(grep -nE 'SCRIPT ERROR|Parse Error|WARNING' "$log" \
		| grep -v '\[fallback_art\]' || true)"
	if [ -n "$hits" ]; then
		echo "FAIL  $name — log tripped the error/warning grep:"
		echo "$hits" | sed 's/^/        /'
		step_fail=1
	fi
	if [ "$step_fail" -ne 0 ]; then
		FAILURES=$((FAILURES+1)); FAILED+=("$name")
	else
		echo "ok    $name"
	fi
}

# --- 1. Fresh import (no .godot cache carried over) --------------------------
run_step "import" "$LOGDIR/import.log" \
	"$GODOT" --headless --path "$SCRATCH" --import

# --- 2. Boot smoke ----------------------------------------------------------
run_step "smoke" "$LOGDIR/smoke.log" \
	"$GODOT" --headless --path "$SCRATCH" --quit

# --- 3. Representative QA scripts (run against the SCRATCH project) ----------
RUN_QA="$SCRATCH/qa/run_qa.sh"
run_step "load_gate"          "$LOGDIR/load_gate.log"          bash "$RUN_QA" load_gate headless
run_step "inn_walkthrough"    "$LOGDIR/inn_walkthrough.log"    bash "$RUN_QA" inn_walkthrough headless --seed=9
run_step "tutorial_flow"      "$LOGDIR/tutorial_flow.log"      bash "$RUN_QA" tutorial_flow headless --seed=9
run_step "combat_walkthrough" "$LOGDIR/combat_walkthrough.log" bash "$RUN_QA" combat_walkthrough headless --seed=9

# --- 4. One WINDOWED inn_walkthrough for controller-read screenshots ---------
run_step "inn_walkthrough_windowed" "$LOGDIR/inn_walkthrough_windowed.log" \
	bash "$RUN_QA" inn_walkthrough windowed --seed=9

# The windowed shots live inside the (soon-deleted) scratch tree; copy them out
# so a controller can read them after the run.
SHOTS_OUT="$PROJ/qa_output/fallback_boot_shots"
rm -rf "$SHOTS_OUT"; mkdir -p "$SHOTS_OUT"
if [ -d "$SCRATCH/qa_output/inn_walkthrough" ]; then
	cp "$SCRATCH/qa_output/inn_walkthrough/"*.png "$SHOTS_OUT/" 2>/dev/null || true
fi
echo "==> windowed fallback shots copied to: $SHOTS_OUT"

echo ""
echo "=================================================================="
if [ "$FAILURES" -eq 0 ]; then
	echo "check_fallback_boot: PASS — public checkout boots + passes the slice on placeholder art."
	echo "shots: $SHOTS_OUT"
	exit 0
fi
echo "check_fallback_boot: ${FAILURES} step(s) FAILED: ${FAILED[*]}"
echo "logs: $LOGDIR"
exit 1
