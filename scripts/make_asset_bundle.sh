#!/usr/bin/env bash
# make_asset_bundle.sh — pack the protected (non-redistributable) assets into a
# tarball for the private assets repo (M-RELEASE Task R3).
#
# The tarball preserves the wandering_inn_game/assets/** layout RELATIVE TO
# THE REPO ROOT, so release.yml's overlay step (`tar -xzf … -C .`) drops every
# file straight back into place over the committed fallback art.
#
# WORKFLOW: run this from a checkout of the PRIVATE repo (or the current private
# working tree) whenever the protected assets change, then attach the resulting
# tarball to a GitHub release in the private assets repo. release.yml fetches
# the latest such release with PRIVATE_ASSETS_TOKEN.
#
# The set of protected paths is authored by M-RELEASE Task R2 in
#   wandering_inn_game/assets_manifest.json
# (built from the audit report's FORBIDDEN/NEEDS-ATTESTATION rows). This script
# READS that manifest; it does not invent the list.
#
# Usage:
#   scripts/make_asset_bundle.sh            # -> dist/wi-assets-bundle-<date>.tar.gz
#   scripts/make_asset_bundle.sh OUT.tar.gz # explicit output path
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MANIFEST="$ROOT/wandering_inn_game/assets_manifest.json"
OUT="${1:-$ROOT/dist/wi-assets-bundle-$(date +%Y%m%d).tar.gz}"

if [ ! -f "$MANIFEST" ]; then
  cat >&2 <<EOF
make_asset_bundle.sh: manifest not found:
  $MANIFEST

This file is delivered by M-RELEASE Task R2. It enumerates every protected
(non-redistributable) asset path — the FORBIDDEN / NEEDS-ATTESTATION set from
the audit report (.superpowers/sdd/fp-handoff/release-asset-audit.md), whose
authoritative source→dest map is tools/sync_assets.py.

Expected JSON shape (either form is accepted):
  { "protected_paths": [
      "wandering_inn_game/assets/audio/music/track.ogg",
      "wandering_inn_game/assets/audio/sfx/hit.wav"
  ] }
or an array of objects each with a "path" key:
  { "protected_paths": [ { "path": "…", "bundle": "…", "fallback": "…" } ] }

Once R2 lands the manifest, re-run this script.
EOF
  exit 1
fi

# Extract the protected paths from the manifest. Tolerant of two shapes: an
# array of strings, or an array of objects each carrying a "path" key, under a
# top-level "protected_paths" (preferred) or "entries" key, or a bare top-level
# array. Emits one repo-root-relative path per line.
paths_from_manifest() {
  python3 - "$MANIFEST" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
if isinstance(data, dict):
    # R2's shipped schema: {"assets": [{"path": ..., "bundle": true, ...}]}
    # (paths relative to wandering_inn_game/). Older draft shapes kept
    # as fallbacks.
    items = data.get("assets", data.get("protected_paths", data.get("entries", [])))
elif isinstance(data, list):
    items = data
else:
    items = []
out = []
for it in items:
    if isinstance(it, str):
        out.append(it)
    elif isinstance(it, dict) and "path" in it:
        if it.get("bundle", True):
            p = it["path"]
            if not p.startswith("wandering_inn_game/"):
                p = "wandering_inn_game/" + p
            out.append(p)
            # the .import sidecar rides along when present
            out.append(p + ".import")
if not out:
    sys.stderr.write(
        "make_asset_bundle.sh: manifest parsed but no protected paths found — "
        "check its schema against this script's header.\n")
    sys.exit(3)
for p in out:
    print(p)
PY
}

# macOS ships bash 3.2 (no mapfile) — portable read loop instead.
PATHS=()
while IFS= read -r line; do
  [ -n "$line" ] && PATHS+=("$line")
done < <(paths_from_manifest)

# Verify every listed path exists; a missing protected file is a manifest bug.
missing=0
declare -a REAL=()
for p in ${PATHS[@]+"${PATHS[@]}"}; do
  if [ -e "$ROOT/$p" ]; then
    REAL+=("$p")
  else
    echo "make_asset_bundle.sh: WARNING — manifest path not found in this tree: $p" >&2
    missing=$((missing + 1))
  fi
done

if [ "${#REAL[@]}" -eq 0 ]; then
  echo "make_asset_bundle.sh: no protected paths exist in this tree — nothing to bundle." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
# -C "$ROOT" so stored paths stay repo-root-relative (the overlay contract).
tar -czf "$OUT" -C "$ROOT" "${REAL[@]}"

echo "Bundled ${#REAL[@]} protected path(s) into:"
echo "  $OUT"
if [ "$missing" -gt 0 ]; then
  echo "  (note: $missing manifest path(s) were missing and skipped — see warnings above)"
fi
echo ""
echo "Next: attach this tarball to a release in the PRIVATE assets repo so"
echo "release.yml can fetch it with PRIVATE_ASSETS_TOKEN."
