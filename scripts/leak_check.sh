#!/usr/bin/env bash
# leak_check.sh — the unified-repo guard (2026-07-07): fails if anything
# license-restricted or secret is TRACKED by git. Runs in CI on every
# push/PR; run it locally before any commit touching assets.
#
# Checks:
#  1. No assets_manifest.json path (or its .import sidecar) is tracked.
#  2. No API-key file (docs/*_api_key.txt) is tracked.
#  3. potential_assets/ has no tracked files.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MANIFEST="$ROOT/wandering_inn_game/assets_manifest.json"
FAIL=0

while IFS= read -r p; do
	for f in "wandering_inn_game/$p" "wandering_inn_game/$p.import"; do
		if git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
			echo "LEAK (tracked manifest path): $f"; FAIL=1
		fi
	done
done < <(python3 -c "import json;[print(e['path']) for e in json.load(open('$MANIFEST'))['assets']]")

while IFS= read -r f; do
	echo "LEAK (tracked key file): $f"; FAIL=1
done < <(git -C "$ROOT" ls-files 'docs/*_api_key.txt')

while IFS= read -r f; do
	echo "LEAK (tracked potential_assets): $f"; FAIL=1
done < <(git -C "$ROOT" ls-files 'potential_assets/')

if [ "$FAIL" -ne 0 ]; then
	echo "FATAL: leak check failed — see lines above" >&2
	exit 1
fi
echo "leak_check: clean (manifest paths, key files, potential_assets all untracked)"
