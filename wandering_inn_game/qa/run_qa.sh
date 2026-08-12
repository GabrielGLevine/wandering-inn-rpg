#!/usr/bin/env bash
# Run a declarative QA script against the game.
# Usage: qa/run_qa.sh <script-name> [headless|windowed|fullscreen] [--user-dir DIR] [--fail-fast] [--seed=N ...]
#   script-name: basename of a file in qa/scripts/ (no .json)
#   mode: headless (default; screenshots skipped) or windowed (screenshots saved)
#   --fail-fast: GH#436 AUTHORING mode -- stop at the first failed step instead
#     of running the rest of the script against whatever state the failure left.
#     Equivalent to QA_FAIL_FAST=1 in the environment or "fail_fast": true in the
#     script root. Off by default: a sweep run wants every failure it can show.
#   --checkpoint-at=N[,N...]: GH#435 AUTHORING mode -- serialize the live sim
#     after 1-based step N into qa_output/<script>/checkpoint_step_N.json, which
#     a scratch script can then load as `"fixture_save": "<that path>"` to
#     iterate a late segment without re-walking the prefix. Checkpoints a script
#     WITHOUT editing it (steel_thread's purity gate must stay untouched); a
#     request landing mid-combat/dialogue defers to the next quiet step. The
#     `dump_checkpoint {slot}` step action is the in-script equivalent.
#   extra args are passed through to Godot user args (for example --seed=7)
# Godot 4.7 here does not expose --user-dir. To isolate user:// state for
# concurrent QA runs, this wrapper gives each run a dedicated HOME under the
# repo-root .godot_home/ artifact dir, or uses --user-dir when provided.
set -u
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PROJ/.." && pwd)"
NAME="${1:?usage: run_qa.sh <script-name> [headless|windowed] [--user-dir DIR] [--seed=N ...]}"
shift
MODE="headless"
if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
	MODE="$1"
	shift
fi
OUT="$PROJ/qa_output/$NAME"
rm -rf "$OUT"
mkdir -p "$OUT"
FLAGS=""
if [ "$MODE" = "headless" ]; then
	FLAGS="--headless"
elif [ "$MODE" = "fullscreen" ]; then
	# Windowed semantics (screenshots saved) on a fullscreen window.
	FLAGS="--fullscreen"
fi
USER_DIR=""
EXTRA=()
while [ "$#" -gt 0 ]; do
	case "$1" in
		--user-dir=*)
			USER_DIR="${1#*=}"
			;;
		--user-dir)
			shift
			USER_DIR="${1:?--user-dir requires a directory}"
			;;
		--fail-fast)
			# QAPaths.parse_args only understands --k=v, so the bare human
			# spelling is normalized here rather than taught to the parser.
			EXTRA+=("--fail-fast=1")
			;;
		*)
			EXTRA+=("$1")
			;;
	esac
	shift
done
if [ -z "$USER_DIR" ]; then
	USER_DIR="$REPO_ROOT/.godot_home/qa-${NAME}-$$"
	# Auto per-PID homes are throwaway isolation; without this trap they
	# accumulate one dir per run and .godot_home balloons to GBs over a
	# session. An explicitly passed --user-dir is never touched (the trap
	# is only installed on this auto branch). A SIGALRM kill skips EXIT
	# traps -- flush_artifacts.sh reaps those stale dirs.
	trap 'rm -rf "$USER_DIR"' EXIT
fi
mkdir -p "$USER_DIR"
echo "QA_USER_DIR: $USER_DIR"
# #111 safe-rename: a script proving the migration declares
# "legacy_seed": "<fixture>". Seed a PRE-rename user dir (the "v4" sibling of
# this run's app_userdata) BEFORE launch, so Game._ready() carries it over
# before the title enumerates slots -- the real boot ordering, not a driver
# fake. Platform app_userdata mirrors Godot's own derivation from HOME/XDG.
SEED_FIXTURE="$(grep -o '"legacy_seed"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJ/qa/scripts/$NAME.json" 2>/dev/null | sed -E 's/.*"([^"]*)"$/\1/')"
if [ -n "$SEED_FIXTURE" ]; then
	case "$(uname)" in
		Darwin) APP_UD="$USER_DIR/Library/Application Support/Godot/app_userdata" ;;
		*) APP_UD="$USER_DIR/.local/share/godot/app_userdata" ;;
	esac
	LEGACY_DIR="$APP_UD/Wandering Inn RPG v4"
	mkdir -p "$LEGACY_DIR/saves"
	cp "$PROJ/qa/fixtures/$SEED_FIXTURE.json" "$LEGACY_DIR/saves/manual.json"
	printf '[audio]\nmaster=0.5\n' > "$LEGACY_DIR/settings.cfg"
	echo "QA_LEGACY_SEED: $SEED_FIXTURE -> $LEGACY_DIR"
fi
HOME="$USER_DIR" \
XDG_DATA_HOME="$USER_DIR/.local/share" \
XDG_CONFIG_HOME="$USER_DIR/.config" \
	/usr/local/bin/godot $FLAGS --path "$PROJ" -- "--qa-script=res://qa/scripts/$NAME.json" "--qa-out=$OUT" ${EXTRA[@]+"${EXTRA[@]}"}
CODE=$?
echo "--- result.json ---"
cat "$OUT/result.json" 2>/dev/null || echo "(missing result.json)"
echo ""
exit $CODE
