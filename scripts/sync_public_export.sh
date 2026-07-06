#!/usr/bin/env bash
# sync_public_export.sh — mirror the current private tree into the LIVE public
# repo working copy (../wandering-inn-rpg-public) WITHOUT touching its git
# history (prepare_public_export.sh is init-only; this is the post-push sync).
#
# Same exclusion set as the initial export: manifest-protected assets,
# credentials, scratch, internal docs. Deletes files that vanished privately
# (--delete) but NEVER deletes the public .git.
#
# Usage:
#   scripts/sync_public_export.sh                 # sync + report, no commit
#   scripts/sync_public_export.sh -m "message"    # sync + commit + push
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="$ROOT/../wandering-inn-rpg-public"
MANIFEST="$ROOT/wandering_inn_game_v4/assets_manifest.json"

[ -d "$DEST/.git" ] || { echo "FATAL: $DEST is not the pushed public repo (no .git)" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "FATAL: $MANIFEST missing" >&2; exit 1; }

EXCLUDES="$(mktemp)"
python3 - "$MANIFEST" >>"$EXCLUDES" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for e in m["assets"]:
    print("wandering_inn_game_v4/" + e["path"])
    print("wandering_inn_game_v4/" + e["path"] + ".import")
PY
cat >>"$EXCLUDES" <<'EOF'
.git
.godot
.godot_home
.superpowers
.codex
potential_assets
qa_output
node_modules
godot-open-rpg
docs/siliconflow_api_key.txt
docs/pixellab_api_key.txt
docs/retrodiffusion_api_key.txt
docs/butler_api_key.txt
MORNING_SUMMARY.md
NIGHT-GOAL.md
HANDOFF.md
.claude
__pycache__
*.pyc
.DS_Store
EOF

# Sync from COMMITTED HEAD, never the live working tree: a running
# implementer lane's uncommitted files must never ship (this exact leak
# put half-finished PC sprites into a release build, 2026-07-06).
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
git -C "$ROOT" archive HEAD | tar -x -C "$STAGE"
rsync -a --delete --exclude-from="$EXCLUDES" "$STAGE/" "$DEST/"

# Leak check (same as the initial export).
LEAKS=0
while IFS= read -r p; do
	[ -e "$DEST/$p" ] && { echo "LEAK: $p"; LEAKS=1; }
done < <(python3 -c "import json;[print('wandering_inn_game_v4/'+e['path']) for e in json.load(open('$MANIFEST'))['assets']]")
[ "$LEAKS" -eq 0 ] || { echo "FATAL: manifest paths leaked" >&2; exit 1; }

cd "$DEST"
git status --short | head -20
if [ "${1:-}" = "-m" ]; then
	shift
	git add -A
	git commit -m "$*"
	git push
	echo "== synced + pushed: $(git rev-parse --short HEAD)"
else
	echo "== synced (uncommitted). Commit+push with: scripts/sync_public_export.sh -m \"msg\""
fi
