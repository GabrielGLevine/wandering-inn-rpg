#!/usr/bin/env bash
# ci_sweep.sh — run every canonical QA playtest at its pinned seed and fail on
# ANY red run OR any SCRIPT ERROR / Parse Error / WARNING in a run's log.
# This is the grep discipline (wandering_inn_game/AGENTS.md: "ZERO
# known-harmless warnings") enforced IN CI, not just by convention.
#
# Usage:
#   qa/ci_sweep.sh                       # full canonical sweep (tier=full, unchanged)
#   qa/ci_sweep.sh --only a,b,c          # restrict to a comma-separated subset
#   qa/ci_sweep.sh --tier smoke          # only manifest entries tagged "smoke"
#   qa/ci_sweep.sh --touching a.json,b.json  # only canonicals whose derived
#                                         # surfaces (maps/fixtures/skills/
#                                         # systems) cross the given paths
#   CI_SWEEP_TIMEOUT=300 qa/ci_sweep.sh  # override per-script alarm (seconds)
# --tier default "full" is a no-op (every manifest entry carries "full" —
# ARCH-1 tier task): unflagged behavior is byte-identical to before tiering.
# --only and --touching both set an explicit run list and IGNORE --tier (an
# explicit ask always wins; --touching's own derivation is already precise).
# --touching + --tier together is not supported in this version — pass one.
#
# Exit: 0 iff every selected script ran green AND no log tripped the grep;
#       nonzero (count of failures) otherwise.
#
# --- CANONICAL LIST (ARCH-1) -------------------------------------------------
# qa/manifest.json is the ONE source of truth (script/seed/fixture/note per
# entry). This script parses it (python3) instead of carrying a hardcoded
# array. wandering_inn_game/AGENTS.md's "Canonical QA seed table" is generated
# FROM the manifest for human reading — the drift check below (startup, every
# invocation) parses that table back out of AGENTS.md and hard-fails the sweep
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
AGENTS_MD="$HERE/../AGENTS.md"

# A full sweep regenerates every artifact anyway — start from a clean slate
# so qa_output/.godot_home never balloon across sessions (the regular flush
# stage). Skipped for --only/--touching subset runs (a tier-filtered run
# with neither flag is still a "start clean" run), which may sit alongside
# a prior full sweep's artifacts a controller is still reading.
case " $* " in
	*" --only"*|*" --touching"*) : ;;
	*) "$HERE/flush_artifacts.sh" ;;
esac

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
	# Optional per-script user args (#119): space-joined third field, forwarded
	# to run_qa.sh verbatim. Args must be --key=value tokens without spaces.
	args = entry.get("args", [])
	if not isinstance(args, list) or any(" " in str(a) for a in args):
		print(f"ci_sweep: FATAL — {name} 'args' must be a list of space-free tokens", file=sys.stderr)
		sys.exit(1)
	out.append(f"{name}:{seed_str}:{' '.join(str(a) for a in args)}")

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

# --- Drift check: AGENTS.md's canonical seed table must agree with the
# manifest (script + seed set) or the sweep hard-fails with the diff printed.
# This is the "two hand-synced sources of truth" gap (consultant finding 4) —
# the manifest is authoritative; AGENTS.md's table is documentation generated
# from it, and this check is what keeps it honest going forward.
DRIFT_OUTPUT="$(MANIFEST_PATH="$MANIFEST" AGENTS_MD_PATH="$AGENTS_MD" python3 - <<'PY'
import json, os, re, sys

manifest_path = os.environ["MANIFEST_PATH"]
agents_md_path = os.environ["AGENTS_MD_PATH"]

with open(manifest_path) as f:
	manifest = json.load(f)
manifest_pairs = set()
for entry in manifest["scripts"]:
	seed = entry["seed"]
	manifest_pairs.add((entry["script"], "none" if seed is None else str(seed)))

if not os.path.isfile(agents_md_path):
	print(f"ci_sweep: FATAL — AGENTS.md not found at {agents_md_path}", file=sys.stderr)
	sys.exit(1)

with open(agents_md_path) as f:
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
	print("ci_sweep: FATAL — could not locate/parse AGENTS.md's canonical seed table", file=sys.stderr)
	sys.exit(1)

only_manifest = sorted(manifest_pairs - table_pairs)
only_table = sorted(table_pairs - manifest_pairs)
if only_manifest or only_table:
	print("ci_sweep: FATAL — qa/manifest.json and AGENTS.md's canonical seed table have DRIFTED:", file=sys.stderr)
	if only_manifest:
		print("  in manifest.json but not (or mismatched seed in) AGENTS.md table:", file=sys.stderr)
		for name, seed in only_manifest:
			print(f"    {name}:{seed}", file=sys.stderr)
	if only_table:
		print("  in AGENTS.md table but not (or mismatched seed in) manifest.json:", file=sys.stderr)
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

# --- Tier drift check: every entry >=1 tier, every tier name known, smoke
# is a structural SUBSET of full (never a script tagged smoke-not-full).
# Runs on every invocation, same as the manifest/AGENTS.md check above —
# tiering must never silently drift once curated (ARCH-1 QA-tiering task).
TIER_PAIRS="$(MANIFEST_PATH="$MANIFEST" python3 - <<'PY'
import json, os, sys

path = os.environ["MANIFEST_PATH"]
with open(path) as f:
	data = json.load(f)

ALLOWED = {"smoke", "full"}
out = []
for entry in data["scripts"]:
	name = entry["script"]
	tiers = entry.get("tiers")
	if not isinstance(tiers, list) or not tiers:
		print(f"ci_sweep: FATAL — {name} has no non-empty 'tiers' array", file=sys.stderr)
		sys.exit(1)
	unknown = [t for t in tiers if t not in ALLOWED]
	if unknown:
		print(f"ci_sweep: FATAL — {name} has unknown tier name(s) {unknown} (allowed: {sorted(ALLOWED)})", file=sys.stderr)
		sys.exit(1)
	if "smoke" in tiers and "full" not in tiers:
		print(f"ci_sweep: FATAL — {name} is tagged 'smoke' but not 'full' — smoke must be a structural subset of full", file=sys.stderr)
		sys.exit(1)
	out.append(f"{name}:{','.join(tiers)}")

print("\n".join(out))
PY
)"
TIER_RC=$?
if [ "$TIER_RC" -ne 0 ] || [ -z "$TIER_PAIRS" ]; then
	echo "ci_sweep: FATAL — tier drift check failed (see above); exiting." >&2
	exit 1
fi
declare -a TIER_ENTRIES=()
while IFS= read -r line; do
	[ -n "$line" ] && TIER_ENTRIES+=("$line")
done <<< "$TIER_PAIRS"

# has_tier NAME TIER -> 0 iff NAME's manifest entry carries TIER. Linear
# scan (103 entries, called O(103) times worst case) — bash 3.2 on macOS
# has no associative arrays, same constraint the --only lookup below lives
# under.
has_tier() {
	local want="$1" tier="$2" e t
	for e in "${TIER_ENTRIES[@]}"; do
		if [ "${e%%:*}" = "$want" ]; then
			t="${e#*:}"
			case ",$t," in *",$tier,"*) return 0 ;; esac
			return 1
		fi
	done
	return 1
}

# --- Surfaces drift check: re-runs the generator and fails on ANY stale
# per-script tag (vacuous-selective is the exact danger the ARCH-1 task
# names — a --touching gate that quietly stops matching reality is worse
# than no selective gate at all).
if ! python3 "$HERE/../scripts/derive_qa_surfaces.py" --check; then
	echo "ci_sweep: FATAL — qa/manifest.json 'surfaces' drifted from a fresh derivation (see above)." >&2
	exit 1
fi

ONLY=""
TIER="full"
TOUCHING=""
while [ "$#" -gt 0 ]; do
	case "$1" in
		--only=*) ONLY="${1#*=}" ;;
		--only) shift; ONLY="${1:?--only requires a comma-separated script list}" ;;
		--tier=*) TIER="${1#*=}" ;;
		--tier) shift; TIER="${1:?--tier requires smoke or full}" ;;
		--touching=*) TOUCHING="${1#*=}" ;;
		--touching) shift; TOUCHING="${1:?--touching requires a comma-separated path list}" ;;
		*) echo "ci_sweep.sh: unknown argument '$1'" >&2; exit 2 ;;
	esac
	shift
done

case "$TIER" in
	smoke|full) : ;;
	*) echo "ci_sweep.sh: FATAL — unknown --tier '$TIER' (allowed: smoke, full)" >&2; exit 2 ;;
esac
if [ -n "$ONLY" ] && [ -n "$TOUCHING" ]; then
	echo "ci_sweep.sh: FATAL — --only and --touching are mutually exclusive, pass one" >&2
	exit 2
fi

# --touching: derive_qa_surfaces.py maps the given paths to surface tags
# (maps/fixtures/skills/systems) then to the canonical scripts whose OWN
# derived surfaces cross them — becomes an --only list from here on.
if [ -n "$TOUCHING" ]; then
	TOUCH_NAMES="$(python3 "$HERE/../scripts/derive_qa_surfaces.py" --touching "$TOUCHING")"
	TOUCH_RC=$?
	if [ "$TOUCH_RC" -ne 0 ]; then
		echo "ci_sweep.sh: FATAL — derive_qa_surfaces.py --touching '$TOUCHING' failed (see above)" >&2
		exit 1
	fi
	if [ -z "$TOUCH_NAMES" ]; then
		echo "ci_sweep: --touching '$TOUCHING' crossed ZERO canonical scripts; nothing to run."
		exit 0
	fi
	ONLY="$(echo "$TOUCH_NAMES" | paste -sd, -)"
fi

# Build the run list. --only (explicit or --touching-derived) always means
# exactly those names — --tier is NOT applied on top (an explicit ask wins;
# --touching's own derivation is already precise). No --only: --tier
# filters the full canon ("full" is every entry's mandatory baseline tier,
# so the default is a structural no-op — unflagged behavior is unchanged).
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
	for pair in "${CANON[@]}"; do
		if has_tier "${pair%%:*}" "$TIER"; then RUNLIST+=("$pair"); fi
	done
fi

rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"

FAILURES=0
FAILED_NAMES=()

# Launches one script's run (alarm-wrapped) writing its log + an rc file.
# Runs are fully isolated already (per-PID user:// HOMEs in run_qa.sh,
# per-script qa_output dirs), so parallel launches cannot collide.
run_one() {
	local NAME="$1" SEED="$2" SCRIPT_ARGS="${3:-}"
	local LOG="$LOGDIR/$NAME.log"
	local ARGS=("$NAME" "headless")
	if [ "$SEED" != "none" ]; then ARGS+=("--seed=$SEED"); fi
	if [ -n "$SCRIPT_ARGS" ]; then
		# shellcheck disable=SC2206 — tokens are validated space-free at parse
		ARGS+=($SCRIPT_ARGS)
	fi
	perl -e 'alarm shift; exec @ARGV' "$PER_SCRIPT_TIMEOUT" \
		bash "$RUN_QA" "${ARGS[@]}" >"$LOG" 2>&1
	echo $? >"$LOGDIR/$NAME.rc"
}

# WI_SWEEP_JOBS>1 runs scripts concurrently (local speedup: the 80-script
# sweep drops from ~3-4 min serial to <1 min at -j8). Default stays 1:
# CI keeps deterministic streaming output, and the aggregation below is
# identical either way (it reads only the per-script log + rc files).
JOBS="${WI_SWEEP_JOBS:-1}"

# Phase 1: launch. Missing scripts fail immediately (also the
# deterministic path for catching a bad --only name).
LAUNCHED=()
for pair in "${RUNLIST[@]}"; do
	NAME="${pair%%:*}"
	rest="${pair#*:}"
	SEED="${rest%%:*}"
	# Optional third field (#119): space-joined per-script user args.
	SCRIPT_ARGS=""
	case "$rest" in *:*) SCRIPT_ARGS="${rest#*:}" ;; esac
	if [ ! -f "$SCRIPTS_DIR/$NAME.json" ]; then
		echo "FAIL  $NAME — no such QA script ($SCRIPTS_DIR/$NAME.json)"
		FAILURES=$((FAILURES + 1)); FAILED_NAMES+=("$NAME(missing)")
		continue
	fi
	echo "==> $NAME (seed=$SEED, timeout=${PER_SCRIPT_TIMEOUT}s, jobs=$JOBS${SCRIPT_ARGS:+, args=$SCRIPT_ARGS})"
	if [ "$JOBS" -gt 1 ]; then
		# macOS ships bash 3.2: `wait -n` is unsupported there (it errors and
		# the loop busy-spins). Sleep-poll instead — throttle behavior is
		# identical, just coarser-grained.
		while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 0.2; done
		run_one "$NAME" "$SEED" "$SCRIPT_ARGS" &
	else
		run_one "$NAME" "$SEED" "$SCRIPT_ARGS"
	fi
	LAUNCHED+=("$pair")
done
wait

# Phase 2: aggregate (serial; reads logs + rc files only).
for pair in "${LAUNCHED[@]}"; do
	NAME="${pair%%:*}"
	LOG="$LOGDIR/$NAME.log"
	RC="$(cat "$LOGDIR/$NAME.rc" 2>/dev/null || echo 99)"

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

	# #256: a rc=0 run that never wrote a passing result.json proved NOTHING
	# (a script that get_tree().quit()s mid-run exits clean, trips no grep,
	# and used to be reported "ok"). Require the result to EXIST and passed.
	if [ "$SCRIPT_FAIL" -eq 0 ]; then
		RESULT_JSON="$HERE/../qa_output/$NAME/result.json"
		if [ ! -f "$RESULT_JSON" ]; then
			echo "FAIL  $NAME — no result.json (script quit/crashed before finishing?)"
			SCRIPT_FAIL=1
		elif ! python3 -c "import json,sys; sys.exit(0 if json.load(open('$RESULT_JSON')).get('passed') is True else 1)" 2>/dev/null; then
			echo "FAIL  $NAME — result.json passed != true"
			SCRIPT_FAIL=1
		fi
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
