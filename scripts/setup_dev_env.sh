#!/usr/bin/env bash
# setup_dev_env.sh — bring a fresh clone up to a working dev environment.
#
# WHY: `git clone` gets the code, the tracked skill mirrors and .claude/
# settings — and nothing else. Godot itself, the licensed asset overlay, the
# API-key files, the git hooks (worktree-scoped config, never cloned) and the
# Python tool deps all live outside the repo, and the reconstruction list was
# folklore spread across README.md, AGENTS.md and docs/SECRETS-SETUP.md. This
# script IS that list: it does what can be automated, and names precisely what
# a human must still do by hand.
#
# Usage:
#   bash scripts/setup_dev_env.sh              # full setup
#   bash scripts/setup_dev_env.sh --check      # report only, change nothing
#   bash scripts/setup_dev_env.sh --no-assets  # skip the licensed overlay
#   bash scripts/setup_dev_env.sh --no-import  # skip the Godot import pass
#
# Idempotent: safe to re-run. Exits non-zero if a HARD requirement is missing
# (the ones without which the QA gates cannot run); soft gaps only warn.
# bash 3.2 / macOS: no mapfile, no timeout(1), no associative arrays.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="/usr/local/bin/godot"
GODOT_MAJOR_MINOR="4.7"
ASSETS_REPO="GabrielGLevine/wandering-inn-rpg-assets"

CHECK_ONLY=0
DO_ASSETS=1
DO_IMPORT=1
for arg in "$@"; do
	case "$arg" in
		--check)     CHECK_ONLY=1 ;;
		--no-assets) DO_ASSETS=0 ;;
		--no-import) DO_IMPORT=0 ;;
		-h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
		*) echo "unknown flag: $arg (see --help)" >&2; exit 2 ;;
	esac
done

hard_fail=0
soft=0
ok()   { printf 'ok    %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; soft=1; }
bad()  { printf 'FAIL  %s\n' "$*"; hard_fail=1; }
step() { printf '\n== %s\n' "$*"; }

# ---------------------------------------------------------------- 1. engine
step "Godot $GODOT_MAJOR_MINOR"
if [ ! -x "$GODOT" ]; then
	bad "$GODOT missing. Install Godot $GODOT_MAJOR_MINOR and symlink it there —"
	printf '      the path is hardcoded in preflight.sh, the QA runners and AGENTS.md.\n'
else
	ver="$("$GODOT" --version 2>/dev/null | head -1)"
	case "$ver" in
		"$GODOT_MAJOR_MINOR".*) ok "godot $ver" ;;
		*) bad "godot $ver at $GODOT — project is pinned to $GODOT_MAJOR_MINOR, other versions are not supported" ;;
	esac
fi

# ------------------------------------------------------------ 2. python deps
step "Python tooling"
if command -v python3 >/dev/null 2>&1; then
	ok "python3 $(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')"
	# HARD: scripts/preflight.sh runs the tool suites in its FAST tier.
	if python3 -c "import pytest" >/dev/null 2>&1; then
		ok "python module pytest"
	else
		bad "python module pytest missing — pip3 install pytest"
	fi
	# SOFT: yaml backs the itinerary compiler suites, which only the
	# full-corpus `pytest -q scripts/` (CI parity) collects; preflight runs
	# scripts/tests and never touches them. Absent yaml, the full corpus dies
	# at COLLECTION -- errors, not skips -- so this warns rather than passes
	# silently. Pillow is lazily imported by data_lint's sprite-alpha probe
	# (advisory) and the palette tools; without it they degrade to silence.
	if python3 -c "import yaml" >/dev/null 2>&1; then
		ok "python module yaml"
	else
		warn "python module yaml absent — pip3 install pyyaml; without it \`pytest -q scripts/\` cannot collect the itinerary suites"
	fi
	if python3 -c "import PIL" >/dev/null 2>&1; then
		ok "python module Pillow"
	else
		warn "python module Pillow absent — pip3 install Pillow; data_lint's sprite-alpha probe and the palette tools go quiet without it"
	fi
else
	bad "python3 missing — every lint/QA gate shells out to it"
fi

# ---------------------------------------------------------------- 3. gh CLI
step "GitHub CLI"
gh_ready=0
if ! command -v gh >/dev/null 2>&1; then
	warn "gh missing — needed for the licensed asset overlay and PR work"
elif ! gh auth status >/dev/null 2>&1; then
	warn "gh present but not authenticated — run: gh auth login"
else
	ok "gh authenticated"
	gh_ready=1
fi

# -------------------------------------------------------------- 4. git hooks
step "Git hooks"
current_hooks="$(git -C "$ROOT" config --get core.hooksPath 2>/dev/null || true)"
if [ "$current_hooks" = "scripts/git-hooks" ]; then
	ok "hooks already pointed at scripts/git-hooks"
elif [ "$CHECK_ONLY" = "1" ]; then
	warn "hooks not installed — run: bash scripts/install_git_hooks.sh"
else
	bash "$ROOT/scripts/install_git_hooks.sh" && ok "hooks installed" || bad "hook install failed"
fi

# ------------------------------------------------------------- 5. key files
# Gitignored by design; leak_check.sh (CI job 1) fails if one is ever tracked.
step "Local API keys (docs/SECRETS-SETUP.md)"
for key in butler pixellab siliconflow retrodiffusion; do
	f="$ROOT/docs/${key}_api_key.txt"
	if [ -s "$f" ]; then
		ok "docs/${key}_api_key.txt"
	else
		warn "docs/${key}_api_key.txt absent — recreate by hand (raw string, no quotes); mirrors live in repo Actions secrets"
	fi
done

# --------------------------------------------------------- 6. asset overlay
# Without it the game boots on committed placeholders and every gate still
# runs; with it you get the licensed art/music locally.
step "Licensed asset overlay"
overlay_probe="$(python3 -c "import json;print(json.load(open('$ROOT/wandering_inn_game/assets_manifest.json'))['assets'][0]['path'])" 2>/dev/null || true)"
overlay_present=0
if [ -n "$overlay_probe" ] && [ -e "$ROOT/wandering_inn_game/$overlay_probe" ]; then
	overlay_present=1
fi
if [ "$DO_ASSETS" = "0" ]; then
	ok "skipped (--no-assets); placeholders in use"
elif [ "$overlay_present" = "1" ]; then
	ok "overlay already extracted — refresh with scripts/fetch_private_assets.sh"
elif [ "$CHECK_ONLY" = "1" ]; then
	warn "overlay absent — run: scripts/fetch_private_assets.sh"
elif [ "$gh_ready" = "0" ]; then
	warn "overlay skipped: gh not ready. Placeholders in use; rerun after gh auth login"
elif bash "$ROOT/scripts/fetch_private_assets.sh"; then
	ok "overlay fetched + verified"
	overlay_present=1
else
	warn "overlay fetch failed — needs read access to $ASSETS_REPO. Placeholders in use; the game and every gate still run"
fi

# --------------------------------------------------------- 7. import pass
# Rebuilds the gitignored .godot/ cache. Required before windowed work, and
# after any overlay fetch (new PNGs/OGGs need importing).
step "Godot import pass"
if [ "$DO_IMPORT" = "0" ]; then
	ok "skipped (--no-import)"
elif [ "$CHECK_ONLY" = "1" ]; then
	if [ -d "$ROOT/wandering_inn_game/.godot" ]; then
		ok ".godot/ cache present"
	else
		warn "no .godot/ cache — run: $GODOT --headless --path wandering_inn_game --import"
	fi
elif [ ! -x "$GODOT" ]; then
	warn "import skipped: no engine"
else
	if "$GODOT" --headless --path "$ROOT/wandering_inn_game" --import >/dev/null 2>&1; then
		ok "assets imported"
	else
		warn "import pass returned non-zero — rerun by hand and read the output"
	fi
fi

# ------------------------------------------------------------ 8. plugins note
# User-level (~/.claude), not in this repo, so no script can install them from
# here. AGENTS.md expects godot-prompter alongside Superpowers.
step "Agent plugins (manual, user-level)"
printf '      Claude Code marketplaces to add on a new machine:\n'
printf '        anthropics/claude-plugins-official  (superpowers)\n'
printf '        jame581/skillsmith                  (godot-prompter — AGENTS.md expects it)\n'
printf '        openai/codex-plugin-cc              (Codex delegation)\n'
printf '      Repo-local skills (.claude/skills/wi-*) are tracked and need nothing.\n'

# ------------------------------------------------------------------ verdict
step "Result"
if [ "$hard_fail" -ne 0 ]; then
	echo "SETUP: BLOCKED — fix the FAIL lines above, then re-run."
	exit 1
fi
if [ "$soft" -ne 0 ]; then
	echo "SETUP: USABLE with gaps — the WARN lines are optional surfaces (assets, keys, gh)."
else
	echo "SETUP: COMPLETE."
fi
echo "Verify with:  scripts/preflight.sh        # fast gate bundle"
echo "              wandering_inn_game/qa/ci_sweep.sh   # the full CI gate"
exit 0
