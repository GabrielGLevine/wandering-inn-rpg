#!/usr/bin/env bash
# prepare_public_export.sh — build the curated, fresh-history public tree
# (M-RELEASE Task R6). Exports the repo MINUS: every asset path in
# wandering_inn_game/assets_manifest.json (FORBIDDEN + NEEDS-ATTESTATION),
# potential_assets/, all gitignored scratch, credentials, and internal-only
# files — then git-inits it as commit one of the public repo.
#
# Usage:
#   scripts/prepare_public_export.sh [DEST]        # default DEST=../wandering-inn-rpg-public
#   DRY_RUN=1 scripts/prepare_public_export.sh     # report only, no git init
#
# The export is REVIEWABLE before any push: the script prints an in/out
# report and runs a secrets scan; pushing is a separate, human-initiated act.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="${1:-$ROOT/../wandering-inn-rpg-public}"
MANIFEST="$ROOT/wandering_inn_game/assets_manifest.json"

[ -f "$MANIFEST" ] || { echo "FATAL: $MANIFEST missing" >&2; exit 1; }

# --- exclusion list -----------------------------------------------------------
EXCLUDES="$(mktemp)"
# Manifest asset paths (repo-relative under wandering_inn_game/).
python3 - "$MANIFEST" >>"$EXCLUDES" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for e in m["assets"]:
    print("wandering_inn_game/" + e["path"])
    print("wandering_inn_game/" + e["path"] + ".import")
PY
# Non-public infrastructure + scratch + credentials + internal docs.
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
MORNING_SUMMARY.md
NIGHT-GOAL.md
HANDOFF.md
.claude
__pycache__
*.pyc
.DS_Store
EOF

echo "== Exporting to: $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
rsync -a --exclude-from="$EXCLUDES" "$ROOT/" "$DEST/"

# --- verification -------------------------------------------------------------
echo "== Verifying no manifest path leaked"
LEAKS=0
while IFS= read -r p; do
	case "$p" in wandering_inn_game/*) [ -e "$DEST/$p" ] && { echo "LEAK: $p"; LEAKS=1; } ;; esac
done < <(python3 -c "import json;[print('wandering_inn_game/'+e['path']) for e in json.load(open('$MANIFEST'))['assets']]")
[ "$LEAKS" -eq 0 ] || { echo "FATAL: manifest paths leaked into the export" >&2; exit 1; }

echo "== Secrets scan"
if grep -rInE "(api[_-]?key|secret|token)[\"']?\s*[:=]\s*[\"'][A-Za-z0-9_\-]{16,}" "$DEST" \
	--include='*.gd' --include='*.sh' --include='*.py' --include='*.json' --include='*.yml' --include='*.md' \
	| grep -v 'secrets\.\|PRIVATE_ASSETS_TOKEN\|BUTLER_API_KEY\|ANTHROPIC_API_KEY\|api_key.txt'; then
	echo "FATAL: possible secret above — review before proceeding" >&2; exit 1
fi
echo "   clean."

echo "== Export report"
echo "   files: $(find "$DEST" -type f | wc -l | tr -d ' ')  size: $(du -sh "$DEST" | cut -f1)"
echo "   top-level: $(ls "$DEST" | tr '\n' ' ')"

if [ "${DRY_RUN:-0}" = "1" ]; then
	echo "== DRY RUN — no git init. Review $DEST"; exit 0
fi

echo "== Fresh history init"
cd "$DEST"
git init -q -b main
git add -A
git commit -q -m "The Wandering Inn RPG — initial public release

An unofficial, non-commercial fan game set in The Wandering Inn by
pirateaba. Code MIT; media licensing per-asset (see ATTRIBUTION.md).
Some assets used in official builds are not redistributable and are not
included; the game builds and runs fully with the included fallback art.
See CONTRIBUTING.md to get involved."
echo "== Done: $(git rev-parse --short HEAD) in $DEST (push is YOUR move: gh repo create / git push)"
