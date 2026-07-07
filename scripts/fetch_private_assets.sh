#!/usr/bin/env bash
# fetch_private_assets.sh — local-dev overlay for the licensed asset bundle
# (unified-repo transition, 2026-07-07).
#
# Downloads the newest bundle-vN release from the PRIVATE assets repo and
# extracts it at the repo root (the tarball preserves the
# wandering_inn_game/assets/** layout — same overlay release.yml performs in
# CI). Without this overlay the game still boots on committed placeholder
# fallbacks; with it you get the licensed art/music locally.
#
# The extracted paths are covered by the generated block in .gitignore
# (see scripts/gen_asset_ignores.sh) and can never be committed; this
# script verifies that after extraction and fails loud if any path is
# not ignored.
#
# Requires: gh CLI authenticated as a user with access to
#   GabrielGLevine/wandering-inn-rpg-assets
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MANIFEST="$ROOT/wandering_inn_game/assets_manifest.json"
ASSETS_REPO="GabrielGLevine/wandering-inn-rpg-assets"

[ -f "$MANIFEST" ] || { echo "FATAL: $MANIFEST missing" >&2; exit 1; }

TAG="$(gh release list -R "$ASSETS_REPO" --json tagName --jq '[.[] | select(.tagName | startswith("bundle-v"))][0].tagName')"
[ -n "$TAG" ] || { echo "FATAL: no bundle-vN release found on $ASSETS_REPO" >&2; exit 1; }
echo "== fetching $TAG from $ASSETS_REPO"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
gh release download "$TAG" -R "$ASSETS_REPO" --dir "$TMP" --pattern '*.tar.gz'
TARBALL="$(ls "$TMP"/*.tar.gz | head -1)"
tar -xzf "$TARBALL" -C "$ROOT"

# Verify: every manifest path present AND git-ignored.
FAIL=0
while IFS= read -r p; do
	full="wandering_inn_game/$p"
	[ -e "$ROOT/$full" ] || { echo "MISSING after overlay: $full"; FAIL=1; }
	if ! git -C "$ROOT" check-ignore -q "$full"; then
		# Tracked copies (the frozen private repo) are exempt; a path that is
		# neither tracked nor ignored is one commit away from a public leak.
		if ! git -C "$ROOT" ls-files --error-unmatch "$full" >/dev/null 2>&1; then
			echo "NOT IGNORED (leak risk): $full"; FAIL=1
		fi
	fi
done < <(python3 -c "import json;[print(e['path']) for e in json.load(open('$MANIFEST'))['assets']]")
[ "$FAIL" -eq 0 ] || { echo "FATAL: overlay verification failed" >&2; exit 1; }

echo "== overlay complete + verified ($TAG). Run an --import pass before windowed work:"
echo "   /usr/local/bin/godot --headless --path wandering_inn_game --import"
