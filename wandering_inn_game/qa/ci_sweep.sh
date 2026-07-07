#!/usr/bin/env bash
# ci_sweep.sh — run every canonical QA playtest at its pinned seed and fail on
# ANY red run OR any SCRIPT ERROR / Parse Error / WARNING in a run's log.
# This is the grep discipline (wandering_inn_game/CLAUDE.md: "ZERO
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
# --- CANONICAL LIST (ARCH-1) -------------------------------------------------
# qa/manifest.json is the ONE source of truth (script/seed/fixture/note per
# entry). This script parses it (python3) instead of carrying a hardcoded
# array. wandering_inn_game/CLAUDE.md's "Canonical QA seed table" is generated
# FROM the manifest for human reading — the drift check below (startup, every
# invocation) parses that table back out of CLAUDE.md and hard-fails the sweep
# if its script/seed set disagrees with the manifest, so the two can never
# silently drift apart again (consultant finding 4). Peek-only utilities
# (title_peek, street_peek) are intentionally excluded from both. A seed of
# "none"/null means the script takes no --seed.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
RUN_QA="$HERE/run_qa.sh"
SCRIPTS_DIR="$HERE/scripts"
LOGDIR="$HERE/../qa_output/ci_sweep_logs"
PER_SCRIPT_TIMEOUT="${CI_SWEEP_TIMEOUT:-240}"
MANIFEST="$HERE/manifest.json"
CLAUDE_MD="$HERE/../CLAUDE.md"

# --- Load LOUD: manifest missing/unparseable is an immediate exit 1, never a
# silent zero-script run (the load_gate "scanned zero resources" precedent). --
if [ ! -f "$MANIFEST" ]; then
	echo "ci_sweep: FATAL — manifest not found at $MANIFEST" >&2
	echo "ci_sweep: refusing to run zero scripts silently; exiting." >&2
	exit 1
fi

MANIFEST_PAIRS="$(MANIFEST_PATH="$MANIFEST" python3 - <<'PY'
import json, os, sys

path = os.environ["MANIFEST_PATH"]
try:
	with open(path) as f:
		data = json.load(f)
except Exception as e:
	print(f"ci_sweep: FATAL — could not parse {path}: {e}", file=sys.stderr)
	sys.exit(1)

scripts = data.get("scripts")
if not isinstance(scripts, list) or not scripts:
	print(f"ci_sweep: FATAL — {path} has no non-empty 'scripts' array", file=sys.stderr)
	sys.exit(1)

out = []
for i, entry in enumerate(scripts):
	name = entry.get("script")
	if not name:
		print(f"ci_sweep: FATAL — {path} entry {i} missing 'script'", file=sys.stderr)
		sys.exit(1)
	if "seed" not in entry:
		print(f"ci_sweep: FATAL — {path} entry '{name}' missing 'seed'", file=sys.stderr)
		sys.exit(1)
	seed = entry["seed"]
	seed_str = "none" if seed is None else str(seed)
	out.append(f"{name}:{seed_str}")

print("\n".join(out))
PY
)"
MANIFEST_RC=$?
if [ "$MANIFEST_RC" -ne 0 ] || [ -z "$MANIFEST_PAIRS" ]; then
	echo "ci_sweep: FATAL — manifest parse failed (see above); exiting." >&2
	exit 1
fi

declare -a CANON=()
while IFS= read -r line; do
	[ -n "$line" ] && CANON+=("$line")
done <<< "$MANIFEST_PAIRS"

if [ "${#CANON[@]}" -eq 0 ]; then
	echo "ci_sweep: FATAL — manifest parsed to zero entries; refusing to run zero scripts." >&2
	exit 1
fi

# --- Drift check: CLAUDE.md's canonical seed table must agree with the
# manifest (script + seed set) or the sweep hard-fails with the diff printed.
# This is the "two hand-synced sources of truth" gap (consultant finding 4) —
# the manifest is authoritative; CLAUDE.md's table is documentation generated
# from it, and this check is what keeps it honest going forward.
DRIFT_OUTPUT="$(MANIFEST_PATH="$MANIFEST" CLAUDE_MD_PATH="$CLAUDE_MD" python3 - <<'PY'
import json, os, re, sys

manifest_path = os.environ["MANIFEST_PATH"]
claude_md_path = os.environ["CLAUDE_MD_PATH"]

with open(manifest_path) as f:
	manifest = json.load(f)
manifest_pairs = set()
for entry in manifest["scripts"]:
	seed = entry["seed"]
	manifest_pairs.add((entry["script"], "none" if seed is None else str(seed)))

if not os.path.isfile(claude_md_path):
	print(f"ci_sweep: FATAL — CLAUDE.md not found at {claude_md_path}", file=sys.stderr)
	sys.exit(1)

with open(claude_md_path) as f:
	lines = f.readlines()

table_pairs = set()
in_table = False
row_re = re.compile(r"^\|\s*`([a-zA-Z0-9_]+)`\s*\|\s*([^|]+?)\s*\|")
for line in lines:
	stripped = line.strip()
	if stripped == "| script | seed | purpose |":
		in_table = True
		continue
	if not in_table:
		continue
	if stripped.startswith("|---"):
		continue
	if not stripped.startswith("|"):
		break
	m = row_re.match(stripped)
	if not m:
		break
	name = m.group(1)
	seed_cell = m.group(2)
	seed_token = seed_cell.split()[0].strip(chr(96))
	table_pairs.add((name, seed_token))

if not table_pairs:
	print("ci_sweep: FATAL — could not locate/parse CLAUDE.md's canonical seed table", file=sys.stderr)
	sys.exit(1)

only_manifest = sorted(manifest_pairs - table_pairs)
only_table = sorted(table_pairs - manifest_pairs)
if only_manifest or only_table:
	print("ci_sweep: FATAL — qa/manifest.json and CLAUDE.md's canonical seed table have DRIFTED:", file=sys.stderr)
	if only_manifest:
		print("  in manifest.json but not (or mismatched seed in) CLAUDE.md table:", file=sys.stderr)
		for name, seed in only_manifest:
			print(f"    {name}:{seed}", file=sys.stderr)
	if only_table:
		print("  in CLAUDE.md table but not (or mismatched seed in) manifest.json:", file=sys.stderr)
		for name, seed in only_table:
			print(f"    {name}:{seed}", file=sys.stderr)
	sys.exit(1)

sys.exit(0)
PY
)"
DRIFT_RC=$?
if [ "$DRIFT_RC" -ne 0 ]; then
	echo "$DRIFT_OUTPUT" >&2
	exit 1
fi

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
		# Evidence dump: on CI the qa_output dir dies with the runner — print
		# the failing assertions + the run log tail so the workflow log alone
		# is diagnosable (added after two undiagnosable release-run reds).
		RESULT="$HERE/../qa_output/$NAME/result.json"
		if [ -f "$RESULT" ]; then
			echo "----- $NAME result.json failures -----"
			python3 -c "import json;d=json.load(open('$RESULT'));[print('  ' + str(f)) for f in d.get('failures', [])[:10]]" 2>/dev/null || true
		fi
		echo "----- $NAME run log tail -----"
		tail -n 25 "$LOG" | sed 's/^/    /'
		EVENTS="$HERE/../qa_output/$NAME/events.jsonl"
		if [ -f "$EVENTS" ]; then
			echo "----- $NAME last 15 events (what happened before the stall) -----"
			tail -n 15 "$EVENTS" | sed 's/^/    /'
		fi
		echo "----- end $NAME evidence -----"
	fi

	# Grep discipline: any SCRIPT ERROR / Parse Error / WARNING is a failure.
	# Zero exemptions — the tree is clean.
	HITS="$(grep -nE 'SCRIPT ERROR|Parse Error|WARNING' "$LOG" || true)"
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
