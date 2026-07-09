#!/usr/bin/env bash
# Run a declarative QA script against the game.
# Usage: qa/run_qa.sh <script-name> [headless|windowed] [--user-dir DIR] [--seed=N ...]
#   script-name: basename of a file in qa/scripts/ (no .json)
#   mode: headless (default; screenshots skipped) or windowed (screenshots saved)
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
HOME="$USER_DIR" \
XDG_DATA_HOME="$USER_DIR/.local/share" \
XDG_CONFIG_HOME="$USER_DIR/.config" \
	/usr/local/bin/godot $FLAGS --path "$PROJ" -- "--qa-script=res://qa/scripts/$NAME.json" "--qa-out=$OUT" ${EXTRA[@]+"${EXTRA[@]}"}
CODE=$?
echo "--- result.json ---"
cat "$OUT/result.json" 2>/dev/null || echo "(missing result.json)"
echo ""
exit $CODE
