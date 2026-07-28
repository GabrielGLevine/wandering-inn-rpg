#!/usr/bin/env python3
"""data_lint.py -- GH#276: the engine-free structural tier over data/**.

Sub-second, pure-Python, no Godot. Owns ONLY checks derivable from the
JSON alone; semantic/cross-file rules that need sim knowledge stay in the
GDScript suites (tests/test_content.gd, test_combat_data.gd,
test_reachability.gd) -- this lint is a PRE-check, never a substitute for
the Godot gates. Scope was deliberately trimmed at adjudication
(docs/design/2026-07-26-dev-arch-eval-275-280.md, #276 section): the
ID-cross-ref and counter-hygiene tiers were CUT as duplicates of the
GDScript layers; do not grow them back here.

Checks:
  1. well-formedness  -- every data/**/*.json parses (malformed JSON fails
     here in milliseconds instead of burning a Godot gate run); deeper
     tiers are skipped when this fails (they'd only cascade).
  2. map bounds       -- grid present/positive; blocked cells and entity
     cells in-grid (the b10 out-of-grid saga: the engine reports an
     out-of-grid cell as a plain player_blocked, invisible until a
     canonical happens to pin it).
  3. portals          -- every row's destination map exists in the composed
     catalog, its cell is in that map's grid, AND that cell is not statically
     blocked or held by an unconditional entity (transition() assigns
     player_cell raw, so an occupied arrival strands the player inside a prop
     -- the shipped pallass (4,7)-on-a-bench class).
  4. dialogue         -- graph has start; start is a node; nodes carry
     speaker and text-or-text_variants; every present goto targets a node
     in the same graph (goto is OPTIONAL -- absent = end conversation).
  5. sprites          -- every entry carries a non-empty animations dict.
  6. gate shape       -- the *_when family (door_when / contains_when /
     portal_menu_when / fence_menu_when) must wrap "requires":
     _door_gate_met (src/core/interactions.gd) reads .get("requires", {}),
     so a bare counter dict is VACUOUSLY TRUE (masked gate). The one shipped
     instance (invrisil_anchor_stone) was wrapped for real, so the arm now
     has zero exemptions -- keep it that way.

Wiring: ci_sweep.sh pre-flight (fails the sweep before any Godot boot) and
ci.yml's leak-check job (the no-Godot CI lane). Run standalone after any
data edit:  python3 scripts/data_lint.py   (from wandering_inn_game/).
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from wi_data_lib import DATA

GATE_KEYS = ("door_when", "contains_when", "portal_menu_when", "fence_menu_when")
# (map_id, entity_id, gate_key) -> the follow-up issue that owns the fix.
# EMPTY BY DESIGN: a masked always-true gate is a shipped bug, never a waiver.
VACUOUS_GATE_ALLOWLIST: dict = {}


def check_wellformed(errors: list, root: Path = DATA) -> dict:
	"""Parse every <root>/**/*.json individually; return {path: parsed}."""
	parsed = {}
	for path in sorted(root.rglob("*.json")):
		try:
			parsed[path] = json.loads(path.read_text())
		except (json.JSONDecodeError, UnicodeDecodeError) as exc:
			errors.append(f"{path.name}: invalid JSON -- {exc}")
	return parsed


def _compose_maps(parsed: dict, errors: list) -> dict:
	"""Stem-keyed map catalog from the already-parsed cache (the
	wi_data_lib.load_maps contract, including the dup-stem rule).
	Selects by .../maps/<region>/<map>.json position in the parsed keys so
	tests can inject synthetic trees."""
	maps = {}
	for path in sorted(parsed):
		if path.parent.parent.name != "maps":
			continue
		if path.stem in maps:
			errors.append(f"maps/{path.parent.name}/{path.name}: duplicate map "
				f"key '{path.stem}' across regions")
			continue
		maps[path.stem] = parsed[path]
	return maps


def _int_like(v) -> bool:
	# Godot's JSON parser yields floats for every number and the engine
	# int()-casts cells/dims, so 7.0 is engine-legal; true/false is not.
	return (isinstance(v, (int, float)) and not isinstance(v, bool)
		and float(v).is_integer())


def _cell_shape_ok(cell) -> bool:
	return (isinstance(cell, list) and len(cell) == 2
		and all(_int_like(v) for v in cell))


def _in_grid(cell, grid: dict) -> bool:
	"""Bounds only -- callers gate on _cell_shape_ok first."""
	return (0 <= int(cell[0]) < int(grid["width"])
		and 0 <= int(cell[1]) < int(grid["height"]))


def check_maps(maps: dict, errors: list) -> None:
	for map_id, m in sorted(maps.items()):
		grid = m.get("grid")
		if not (isinstance(grid, dict)
				and _int_like(grid.get("width")) and int(grid["width"]) > 0
				and _int_like(grid.get("height")) and int(grid["height"]) > 0):
			errors.append(f"maps/{map_id}: missing/invalid grid {{width,height}}")
			continue
		w, h = int(grid["width"]), int(grid["height"])
		for cell in m.get("blocked", []):
			if not _cell_shape_ok(cell):
				errors.append(f"maps/{map_id}: malformed blocked cell {cell!r}")
			elif not _in_grid(cell, grid):
				errors.append(f"maps/{map_id}: blocked cell {cell} out of grid "
					f"{w}x{h} (x max {w - 1})")
		for entity in m.get("entities", []):
			eid = entity.get("id", "<no id>")
			cell = entity.get("cell")
			if not _cell_shape_ok(cell):
				errors.append(f"maps/{map_id}: entity '{eid}' malformed cell {cell!r}")
			elif not _in_grid(cell, grid):
				errors.append(f"maps/{map_id}: entity '{eid}' cell "
					f"{cell} out of grid {w}x{h}")


def check_portals(parsed: dict, maps: dict, errors: list) -> None:
	portals_path = DATA / "portals.json"
	if portals_path not in parsed:
		return
	for row in parsed[portals_path].get("portals", []):
		rid = row.get("id", "<no id>")
		dest = row.get("map")
		if dest not in maps:
			errors.append(f"portals.json: row '{rid}' destination map '{dest}' does not exist")
			continue
		grid = maps[dest].get("grid", {})
		if not (isinstance(grid, dict) and _int_like(grid.get("width"))
				and _int_like(grid.get("height"))):
			continue  # already reported by check_maps
		cell = row.get("cell")
		if not _cell_shape_ok(cell):
			errors.append(f"portals.json: row '{rid}' malformed cell {cell!r}")
		elif not _in_grid(cell, grid):
			errors.append(f"portals.json: row '{rid}' cell {cell} "
				f"out of '{dest}' grid {int(grid['width'])}x{int(grid['height'])}")
		else:
			_check_arrival_free(rid, cell, maps[dest], errors)


def _check_arrival_free(rid: str, cell: list, dest_map: dict, errors: list) -> None:
	"""Travel must not land the player inside something solid.

	_travel_to_portal -> transition() ASSIGNS player_cell raw (wi_game.gd); there
	is no nudge and no nearest-free search, while is_cell_blocked() blocks on any
	present entity regardless of kind. So an arrival cell that is statically
	blocked or holds an unconditional entity strands the player inside a prop:
	they can walk off it and never back on. Shipped that way for the whole life
	of the pallass row (4,7) == alchemy_bench_reduction.

	UNCONDITIONAL blockers only -- an entity carrying present_when may be absent
	in the arriving state, and this tier cannot read counters. That case belongs
	to the Godot reachability gate, not here.
	"""
	target = [int(cell[0]), int(cell[1])]
	if any(_cell_shape_ok(b) and [int(b[0]), int(b[1])] == target
			for b in dest_map.get("blocked", [])):
		errors.append(f"portals.json: row '{rid}' arrival cell {cell} is a blocked cell")
		return
	for entity in dest_map.get("entities", []):
		ecell = entity.get("cell")
		if not _cell_shape_ok(ecell) or [int(ecell[0]), int(ecell[1])] != target:
			continue
		if entity.get("present_when") is None:
			errors.append(f"portals.json: row '{rid}' arrival cell {cell} is occupied by "
				f"entity '{entity.get('id', '<no id>')}' -- travel would strand the player inside it")
			return


def check_dialogue(parsed: dict, errors: list) -> None:
	for path in sorted(parsed):
		if path.parent.name != "dialogue":
			continue
		graph = parsed[path]
		name = f"dialogue/{path.stem}"
		nodes = graph.get("nodes")
		if not isinstance(nodes, dict) or "start" not in graph:
			errors.append(f"{name}: graph must carry 'start' + 'nodes'")
			continue
		if graph["start"] not in nodes:
			errors.append(f"{name}: start '{graph['start']}' is not a node")
		for nid, node in nodes.items():
			if not isinstance(node, dict):
				errors.append(f"{name}: node '{nid}' is not an object")
				continue
			if "speaker" not in node:
				errors.append(f"{name}: node '{nid}' missing speaker")
			# text is UNCONDITIONAL: dialogue.gd's _resolved_text does
			# String(node["text"]) even when text_variants override -- a
			# variants-only node is a guaranteed SCRIPT ERROR (review M1).
			if "text" not in node:
				errors.append(f"{name}: node '{nid}' missing text")
			for i, option in enumerate(node.get("options", [])):
				goto = option.get("goto")
				if goto is not None and goto not in nodes:
					errors.append(f"{name}: node '{nid}' option {i} goto "
						f"'{goto}' targets no node")


def check_sprites(parsed: dict, errors: list) -> None:
	sprites_path = DATA / "sprites.json"
	if sprites_path not in parsed:
		return
	for key, entry in parsed[sprites_path].items():
		if key.startswith("_"):
			continue
		if not isinstance(entry, dict) or not entry.get("animations"):
			errors.append(f"sprites.json: entry '{key}' missing non-empty animations")


def _walk_gates(node, map_id: str, entity_id: str, errors: list) -> None:
	if isinstance(node, dict):
		for k, v in node.items():
			if k in GATE_KEYS and isinstance(v, dict) and "requires" not in v:
				if (map_id, entity_id, k) in VACUOUS_GATE_ALLOWLIST:
					continue
				errors.append(f"maps/{map_id}: entity '{entity_id}' {k} lacks a "
					"'requires' wrap -- _door_gate_met reads .get('requires', {}), "
					"so this gate is VACUOUSLY TRUE")
			_walk_gates(v, map_id, entity_id, errors)
	elif isinstance(node, list):
		for item in node:
			_walk_gates(item, map_id, entity_id, errors)


def check_gate_shapes(maps: dict, errors: list) -> None:
	for map_id, m in sorted(maps.items()):
		for entity in m.get("entities", []):
			_walk_gates(entity, map_id, entity.get("id", "<no id>"), errors)


def main() -> int:
	start = time.monotonic()
	errors: list = []
	parsed = check_wellformed(errors)
	if errors:
		for e in errors:
			print(f"data_lint: FAIL -- {e}", file=sys.stderr)
		print(f"data_lint: {len(errors)} well-formedness error(s); "
			"deeper tiers skipped.", file=sys.stderr)
		return 1
	maps = _compose_maps(parsed, errors)
	check_maps(maps, errors)
	check_portals(parsed, maps, errors)
	check_dialogue(parsed, errors)
	check_sprites(parsed, errors)
	check_gate_shapes(maps, errors)
	elapsed_ms = (time.monotonic() - start) * 1000
	if errors:
		for e in errors:
			print(f"data_lint: FAIL -- {e}", file=sys.stderr)
		print(f"data_lint: {len(errors)} error(s) in {elapsed_ms:.0f}ms "
			"(structural tier only -- the Godot gates still apply).", file=sys.stderr)
		return 1
	print(f"data_lint: OK -- {len(parsed)} files, {len(maps)} maps clean "
		f"in {elapsed_ms:.0f}ms (structural tier only -- Godot gates still apply).")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
