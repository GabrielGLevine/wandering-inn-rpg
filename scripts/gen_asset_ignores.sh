#!/usr/bin/env bash
# gen_asset_ignores.sh — regenerate the GENERATED gitignore block from
# wandering_inn_game/assets_manifest.json (the unified-repo licensed-asset
# discipline; see wi-shipping skill + AGENTS.md "Licensed assets & secrets").
#
# The block is delimited by:
#   # === GENERATED: licensed asset overlay (unified-repo transition 2026-07-07) ===
#   ...
#   # === END GENERATED ===
# and lists every manifest path plus its .import sidecar, in manifest order
# (the manifest is itself kept alphabetically sorted by path). Referenced by
# name in scripts/fetch_private_assets.sh's header comment since the unified
# transition but never checked in until 8a Task A1 -- this script now exists
# so "regenerate this block when assets_manifest.json changes" is a real,
# repeatable command instead of hand-editing.
#
# Usage: scripts/gen_asset_ignores.sh   (run from anywhere; edits .gitignore in place)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MANIFEST="$ROOT/wandering_inn_game/assets_manifest.json"
GITIGNORE="$ROOT/.gitignore"
START="# === GENERATED: licensed asset overlay (unified-repo transition 2026-07-07) ==="
END="# === END GENERATED ==="

[ -f "$MANIFEST" ] || { echo "FATAL: $MANIFEST missing" >&2; exit 1; }
grep -qF "$START" "$GITIGNORE" || { echo "FATAL: start marker not found in $GITIGNORE" >&2; exit 1; }
grep -qF "$END" "$GITIGNORE" || { echo "FATAL: end marker not found in $GITIGNORE" >&2; exit 1; }

python3 - "$GITIGNORE" "$START" "$END" "$MANIFEST" <<'PYEOF'
import json, sys
path, start, end, manifest_path = sys.argv[1:5]
with open(path) as f:
    lines = f.read().splitlines()
d = json.load(open(manifest_path))
gen_lines = []
for e in d["assets"]:
    p = e["path"]
    gen_lines.append(f"/wandering_inn_game/{p}")
    gen_lines.append(f"/wandering_inn_game/{p}.import")

out = []
i = 0
in_block = False
while i < len(lines):
    line = lines[i]
    if line == start:
        out.append(start)
        out.append("# These ship ONLY via the private bundle (scripts/fetch_private_assets.sh);")
        out.append("# regenerate this block with scripts/gen_asset_ignores.sh when assets_manifest.json changes.")
        out.extend(gen_lines)
        in_block = True
        i += 1
        continue
    if line == end:
        out.append(end)
        in_block = False
        i += 1
        continue
    if in_block:
        i += 1
        continue
    out.append(line)
    i += 1

with open(path, "w") as f:
    f.write("\n".join(out) + "\n")
print(f"gen_asset_ignores: regenerated GENERATED block from {len(d['assets'])} manifest entries")
PYEOF
