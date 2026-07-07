#!/usr/bin/env bash
# fetch_potential_assets.sh — restore the parked source-asset packs
# (unified-repo transition, 2026-07-07).
#
# potential_assets/ holds user-sourced pack originals whose licenses forbid
# redistribution — they are NEVER tracked (gitignored) and are parked as the
# potential-assets-vN release on the PRIVATE assets repo. This restores the
# local cache on a fresh machine. Extracted pack dirs re-derive from their
# zips (unzip on demand); zip-less dirs are stored as-is.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ASSETS_REPO="GabrielGLevine/wandering-inn-rpg-assets"
DEST="$ROOT/potential_assets"

TAG="$(gh release list -R "$ASSETS_REPO" --json tagName --jq '[.[] | select(.tagName | startswith("potential-assets-v"))][0].tagName')"
[ -n "$TAG" ] || { echo "FATAL: no potential-assets-vN release on $ASSETS_REPO" >&2; exit 1; }
echo "== fetching $TAG (~1GB) from $ASSETS_REPO"

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
gh release download "$TAG" -R "$ASSETS_REPO" --dir "$TMP" --pattern '*.tar.gz'
tar -xzf "$TMP"/*.tar.gz -C "$DEST"
git -C "$ROOT" check-ignore -q potential_assets || { echo "FATAL: potential_assets/ is not gitignored" >&2; exit 1; }
echo "== restored to potential_assets/ ($TAG). See POTENTIAL-ASSETS-MANIFEST.txt inside."
