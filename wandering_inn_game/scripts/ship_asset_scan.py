#!/usr/bin/env python3
"""ship_asset_scan.py -- GH#277: the "placeholders never ship" release gate.

Run in release.yml's `release` (itch) job AFTER the private-bundle overlay:
every res://assets/ path referenced by data/sprites.json + data/audio.json
must exist ON DISK, and no audio row may still carry `pending: true`.

DISK ONLY, deliberately: never honor the assets_manifest.json relaxation.
_stream_ok-style manifest membership proves nothing about the bundle
actually containing the file, so a manifest row whose file never reached
the bundle would ship silent with zero other CI signal -- this scan is the
one place that catches manifest-vs-bundle gaps.

Scope guards:
  - `release` itch job ONLY. desktop-exports/steampipe intentionally ship
    the committed fallback tree (pipeline proofs) and must NOT run this.
  - On main / public checkouts this FAILS by design (fallback art is
    absent) -- it is a ship gate, not a CI lint. Do not wire into ci.yml.
  - Strings under keys starting with "_" (comment conventions) are skipped.

Standalone:  python3 scripts/ship_asset_scan.py  [--root <game-root>]
(--root exists for the unit tests; default is the real game tree.)
"""
from __future__ import annotations

import sys
from pathlib import Path

from wi_data_lib import GAME_ROOT, load_json

# sprites+audio are the adjudicated core; biomes/arenas/maps joined at
# review (122 more res://assets/ refs, all currently resolving -- the
# walker is schema-agnostic so wider coverage is free).
SCANNED_FILES = ("sprites.json", "audio.json", "biomes.json", "arenas.json")


def _collect_res_paths(node, out: list) -> None:
	if isinstance(node, dict):
		for k, v in node.items():
			if isinstance(k, str) and k.startswith("_"):
				continue
			_collect_res_paths(v, out)
	elif isinstance(node, list):
		for item in node:
			_collect_res_paths(item, out)
	elif isinstance(node, str) and node.startswith("res://assets/"):
		out.append(node)


def _pending_rows(audio: dict) -> list:
	rows = []
	for tier in ("events", "music", "ambience"):
		for row in audio.get(tier, []):
			if isinstance(row, dict) and row.get("pending"):
				rows.append((tier, row.get("id", "<no id>")))
	return rows


def scan(root: Path) -> list:
	errors: list = []
	all_paths: list = []
	targets = [(name, root / "data" / name) for name in SCANNED_FILES]
	targets += [(f"maps/{p.parent.name}/{p.name}", p)
		for p in sorted((root / "data" / "maps").glob("*/*.json"))]
	for name, path in targets:
		if not path.is_file():
			continue  # synthetic test roots carry only the core files
		data = load_json(path)
		file_paths: list = []
		_collect_res_paths(data, file_paths)
		all_paths.extend(file_paths)
		for res_path in file_paths:
			disk = root / res_path[len("res://"):]
			if not disk.is_file():
				errors.append(f"{name}: referenced asset missing on disk: {res_path}")
	for tier, rid in _pending_rows(load_json(root / "data" / "audio.json")):
		errors.append(
			f"audio.json: {tier} row '{rid}' is still pending: true -- a "
			"pending slot reached the release cut; fill it or pull the row")
	print(f"ship_asset_scan: {len(all_paths)} referenced asset paths checked.")
	return errors


def main(argv: list) -> int:
	root = GAME_ROOT
	if len(argv) >= 2 and argv[0] == "--root":
		root = Path(argv[1])
	errors = scan(root)
	if errors:
		for e in errors:
			print(f"ship_asset_scan: FAIL -- {e}", file=sys.stderr)
		print(f"ship_asset_scan: {len(errors)} error(s) -- this build must "
			"not ship (placeholders/pending slots never reach itch).", file=sys.stderr)
		return 1
	print("ship_asset_scan: OK -- every referenced asset exists on disk, no pending slots.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
