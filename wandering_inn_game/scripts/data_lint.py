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
  7. mood language    -- moods.json keys must name a real map/arena, and each
     card must obey the v0.17 R2 lighting language (see check_moods).

ADVISORIES (v0.17 L3, GH#335 item 3) are a SECOND, non-failing tier. They
never touch the exit code and can never break a sweep, because they measure a
DESIGN gap, not a defect: an advisory row is a question ("should this have
persistent state?"), and plenty of honest answers are "no". A hard error would
force 90-odd waivers and teach everyone to stop reading the output. Default
output is one summary line; `--advisories` prints the full list.

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
SKILL_GATE_MECHANISMS = {"property", "blink", "arm", "social", "endure"}
SKILL_GATE_NON_SKILL_GATES = {"dialogue", "item", "endure"}
MOOD_PHASES = ("day", "dusk", "night")
# world.gd's own SKY_GRADE_EPSILON -- the two must agree or the lint would
# police a different sealed/sky split than the engine reads.
SKY_GRADE_EPSILON = 0.01
WARM_GRADE_CEILING = 0.03  # RULE 2: a sealed grade may be cool or neutral, never warm
MONO_EPS = 1e-9  # float-noise guard on the strict-monotone comparisons
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
		# Playtest fix wave (user ruling 2026-08-04): ALL water is freezable.
		# The loader derives `freezable` from walls segments tagged
		# `water: true`; this arm keeps the tag in lockstep with the water
		# sheet in BOTH directions, so a future pond cannot ship as
		# unfreezable water (the "no standing water" confusion) or as a
		# water-flagged segment wearing non-water art.
		walls = m.get("walls", {})
		for seg in (walls.get("segments", []) if isinstance(walls, dict) else []):
			if not isinstance(seg, dict):
				continue
			is_water_sheet = "Water_tiles" in str(seg.get("sheet", ""))
			has_flag = bool(seg.get("water", False))
			if is_water_sheet and not has_flag:
				errors.append(f"maps/{map_id}: walls segment {seg.get('from')}–{seg.get('to')} "
					f"uses the water sheet but lacks `water: true` — its cells would not be freezable")
			elif has_flag and not is_water_sheet:
				errors.append(f"maps/{map_id}: walls segment {seg.get('from')}–{seg.get('to')} "
					f"is tagged `water: true` but does not use the water sheet")


def _catalog_rows(parsed: dict, filename: str, key: str) -> list:
	doc = parsed.get(DATA / filename) or {}
	rows = doc.get(key, []) if isinstance(doc, dict) else []
	return [row for row in rows if isinstance(row, dict)]


def _skill_granters(parsed: dict) -> dict:
	out: dict[str, set[str]] = {}
	for cls in _catalog_rows(parsed, "classes.json", "classes"):
		class_id = str(cls.get("id", ""))
		for level in cls.get("levels", []):
			if not isinstance(level, dict):
				continue
			for skill_id in level.get("grants", []):
				out.setdefault(str(skill_id), set()).add(class_id)
	return out


def _mode_skill_ids(mode: dict, skills: list, entities: dict) -> set[str]:
	mechanism = str(mode.get("mechanism", ""))
	if mechanism == "property":
		prop = str(mode.get("skill_property", ""))
		return {str(skill.get("id")) for skill in skills if skill.get(prop) is True}
	if mechanism == "blink":
		minimum = int(mode.get("min_range", 0)) if _int_like(mode.get("min_range", 0)) else 0
		return {str(skill.get("id")) for skill in skills
			if skill.get("blinks") is True and int(skill.get("blink_range", 0)) >= minimum}
	out: set[str] = set()
	raw_skills = mode.get("skills", [])
	if isinstance(raw_skills, str):
		raw_skills = [raw_skills]
	if isinstance(raw_skills, list):
		out.update(str(skill_id) for skill_id in raw_skills)
	if isinstance(mode.get("skill"), str):
		out.add(str(mode["skill"]))
	raw_props = mode.get("props", [])
	if isinstance(raw_props, str):
		raw_props = [raw_props]
	if isinstance(mode.get("prop"), str):
		raw_props = list(raw_props) + [mode["prop"]]
	for prop_id in raw_props if isinstance(raw_props, list) else []:
		entity = entities.get(str(prop_id), {})
		if isinstance(entity.get("requires_skill"), str):
			out.add(str(entity["requires_skill"]))
		out.update(str(skill_id) for skill_id in (entity.get("skill_uses", {}) or {}))
	return out


def check_skill_gates(parsed: dict, maps: dict, errors: list) -> None:
	"""Validate the descriptive two-mode registry; runtime never reads it."""
	skills = _catalog_rows(parsed, "skills.json", "skills")
	granters = _skill_granters(parsed)
	max_blink = max((int(skill.get("blink_range", 0)) for skill in skills
		if skill.get("blinks") is True), default=0)
	for map_id, map_doc in sorted(maps.items()):
		registry = map_doc.get("skill_gates")
		if registry is None:
			continue
		if not isinstance(registry, dict):
			errors.append(f"maps/{map_id}: skill_gates must be an object")
			continue
		grid = map_doc.get("grid", {})
		entities = {str(entity.get("id", "")): entity
			for entity in map_doc.get("entities", []) if isinstance(entity, dict)}
		for gate_id, gate in sorted(registry.items()):
			label = f"maps/{map_id}: skill_gates.{gate_id}"
			if not isinstance(gate, dict):
				errors.append(f"{label} must be an object")
				continue
			modes = gate.get("modes")
			if not isinstance(modes, list) or len(modes) < 2 or not all(isinstance(mode, dict) for mode in modes):
				errors.append(f"{label} needs at least two object modes")
				continue
			signatures = {(str(mode.get("mechanism", "")), str(mode.get("skill_property", "")))
				for mode in modes}
			if len(signatures) < 2:
				errors.append(f"{label} modes need distinct mechanisms or distinct skill properties")
			class_sets: list[frozenset[str]] = []
			for index, mode in enumerate(modes):
				mode_label = f"{label}.modes[{index}]"
				mechanism = str(mode.get("mechanism", ""))
				if mechanism not in SKILL_GATE_MECHANISMS:
					errors.append(f"{mode_label} mechanism {mechanism!r} is not one of {sorted(SKILL_GATE_MECHANISMS)}")
				skill_ids = _mode_skill_ids(mode, skills, entities)
				class_union = frozenset(class_id for skill_id in skill_ids
					for class_id in granters.get(skill_id, set()))
				class_sets.append(class_union)
				non_skill_gate = mode.get("gate")
				if non_skill_gate is not None and non_skill_gate not in SKILL_GATE_NON_SKILL_GATES:
					errors.append(f"{mode_label} gate {non_skill_gate!r} is not one of "
						f"{sorted(SKILL_GATE_NON_SKILL_GATES)}")
				if not class_union and non_skill_gate not in SKILL_GATE_NON_SKILL_GATES:
					errors.append(f"{mode_label} has an empty skill-granter union; declare an explicit "
						f"non-skill gate with gate: dialogue|item|endure")
				if mechanism == "property" and not skill_ids:
					errors.append(f"{mode_label} skill_property {mode.get('skill_property')!r} has no skill carrier")
				raw_props = mode.get("props", [])
				if isinstance(raw_props, str):
					raw_props = [raw_props]
				if isinstance(mode.get("prop"), str):
					raw_props = list(raw_props) + [mode["prop"]]
				for prop_id in raw_props if isinstance(raw_props, list) else []:
					if str(prop_id) not in entities:
						errors.append(f"{mode_label} prop {prop_id!r} does not resolve on this map")
				cells = mode.get("cells", [])
				if not isinstance(cells, list):
					errors.append(f"{mode_label} cells must be an array")
					cells = []
				for key in ("from", "to"):
					if key in mode:
						cells = list(cells) + [mode[key]]
				for cell in cells:
					if not _cell_shape_ok(cell) or not _in_grid(cell, grid):
						errors.append(f"{mode_label} cell {cell!r} is not a real cell in this map's grid")
				if not cells and not raw_props:
					errors.append(f"{mode_label} names no cell or prop carrier")
				if mechanism == "blink":
					minimum = mode.get("min_range")
					if not _int_like(minimum) or int(minimum) < 1:
						errors.append(f"{mode_label} min_range {minimum!r} must be a positive integer "
							f"no greater than shipped blink range {max_blink}")
					elif int(minimum) > max_blink:
						errors.append(f"{mode_label} min_range {minimum!r} exceeds shipped blink range {max_blink}")
			seen_class_sets: dict[frozenset[str], int] = {}
			duplicate_pairs: list[tuple[int, int, frozenset[str]]] = []
			for index, class_union in enumerate(class_sets):
				if class_union in seen_class_sets:
					duplicate_pairs.append((seen_class_sets[class_union], index, class_union))
				else:
					seen_class_sets[class_union] = index
			for first, second, class_union in duplicate_pairs:
				errors.append(f"{label} modes[{first}] and [{second}] have identical class unions "
					f"{sorted(class_union)}; every mode pair must differ")
			rewards = gate.get("rewards")
			if not isinstance(rewards, list) or not rewards:
				errors.append(f"{label} rewards must name at least one same-map entity")
			elif any(not isinstance(reward, str) or reward not in entities for reward in rewards):
				missing = [reward for reward in rewards if not isinstance(reward, str) or reward not in entities]
				errors.append(f"{label} rewards do not resolve on this map: {missing}")


def _water_cells(map_doc: dict) -> set[tuple[int, int]]:
	out = {tuple(map(int, cell)) for cell in map_doc.get("freezable", []) if _cell_shape_ok(cell)}
	for seg in (map_doc.get("walls", {}) or {}).get("segments", []):
		if not isinstance(seg, dict) or seg.get("water") is not True:
			continue
		start, end = seg.get("from"), seg.get("to")
		if not _cell_shape_ok(start) or not _cell_shape_ok(end):
			continue
		x1, y1, x2, y2 = int(start[0]), int(start[1]), int(end[0]), int(end[1])
		if x1 == x2:
			out.update((x1, y) for y in range(min(y1, y2), max(y1, y2) + 1))
		elif y1 == y2:
			out.update((x, y1) for x in range(min(x1, x2), max(x1, x2) + 1))
	return out


def advise_missing_skill_gates(maps: dict, advisories: list) -> None:
	for map_id, map_doc in sorted(maps.items()):
		if map_doc.get("skill_gates"):
			continue
		water = _water_cells(map_doc)
		blocked = {tuple(map(int, cell)) for cell in map_doc.get("blocked", []) if _cell_shape_ok(cell)} | water
		blocked.update(tuple(map(int, entity["cell"])) for entity in map_doc.get("entities", [])
			if isinstance(entity, dict) and _cell_shape_ok(entity.get("cell")))
		grid = map_doc.get("grid", {})
		crossing = False
		for x, y in water:
			for (dx, dy) in ((1, 0), (0, 1)):
				a, b = (x - dx, y - dy), (x + dx, y + dy)
				if _in_grid(a, grid) and _in_grid(b, grid) and a not in blocked and b not in blocked:
					crossing = True
		burn_line = any(isinstance(entity, dict) and entity.get("burnable") is True
			for entity in map_doc.get("entities", []))
		if crossing or burn_line:
			kinds = "/".join(part for part, present in (("freezable crossing", crossing), ("burnable blocker", burn_line)) if present)
			advisories.append(f"maps/{map_id}: {kinds} but no skill_gates registry")


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
	# Dialogue line banks (2026-08-05): every "@<name>" ref in a text slot
	# must resolve (file-local text_banks first, then _shared_lines.json);
	# local names may not shadow shared ones (silent divergence); banks may
	# not reference banks; no bank rots unused.
	shared_path = DATA / "dialogue" / "_shared_lines.json"
	shared = (parsed.get(shared_path) or {}).get("banks", {})
	shared_used = set()
	for path in sorted(parsed):
		if path.parent.name != "dialogue":
			continue
		if path.stem.startswith("_"):
			for bname, bline in shared.items():
				if not isinstance(bline, str) or not bline:
					errors.append(f"dialogue/_shared_lines: banks['{bname}'] must be a non-empty string")
				elif bline.startswith("@"):
					errors.append(f"dialogue/_shared_lines: banks['{bname}'] is a ref -- banks may not reference banks")
			continue
		graph = parsed[path]
		local = graph.get("text_banks", {})
		local_used = set()
		for lname, lline in (local.items() if isinstance(local, dict) else []):
			if lname in shared:
				errors.append(f"dialogue/{path.stem}: text_banks['{lname}'] shadows a shared bank name")
			if not isinstance(lline, str) or not lline:
				errors.append(f"dialogue/{path.stem}: text_banks['{lname}'] must be a non-empty string")
			elif lline.startswith("@"):
				errors.append(f"dialogue/{path.stem}: text_banks['{lname}'] is a ref -- banks may not reference banks")
		def scan_ref(t, where):
			if isinstance(t, str) and t.startswith("@"):
				rname = t[1:]
				if rname in local:
					local_used.add(rname)
				elif rname in shared:
					shared_used.add(rname)
				else:
					errors.append(f"dialogue/{path.stem}: {where}: ref '@{rname}' does not resolve")
		for nid, node in (graph.get("nodes", {}) or {}).items():
			if not isinstance(node, dict):
				continue
			scan_ref(node.get("text"), f"nodes.{nid}.text")
			for i, v in enumerate(node.get("text_variants", []) or []):
				scan_ref(v if isinstance(v, str) else (v or {}).get("text") if isinstance(v, dict) else None, f"nodes.{nid}.text_variants[{i}]")
			for i, o in enumerate(node.get("options", []) or []):
				if isinstance(o, dict):
					scan_ref(o.get("text"), f"nodes.{nid}.options[{i}]")
		for lname in (local if isinstance(local, dict) else {}):
			if lname not in local_used:
				errors.append(f"dialogue/{path.stem}: text_banks['{lname}'] is never referenced")
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


def check_prose_duplication(parsed: dict, maps: dict, errors: list) -> None:
	"""THE ANTI-DUPLICATION GATE (user directive 2026-08-05). The bank
	mechanisms exist so a line is written once; this arm makes new
	copy-paste a HARD FAIL that points at them. Scope: prose strings over
	20 chars (the migration threshold -- shorter strings are idiom, not
	drift risk), exact match only (a near-duplicate with one word changed
	is a rewrite, not a copy). Dialogue is checked corpus-wide (file-local
	text_banks + _shared_lines both exist); map talk lines corpus-wide
	(map-local talk_banks + _shared_talk both exist). Bank VALUES are
	exempt -- they are the single source."""
	MIN_LEN = 21
	def flag(counter, banked, kind, bank_hint):
		for t, cnt in counter.items():
			if cnt > 1:
				errors.append(f"{kind}: prose duplicated x{cnt} -- bank it ({bank_hint}): \"{t[:70]}\"")
			elif t in banked:
				errors.append(f"{kind}: prose already banked as '{banked[t]}' -- use the @ref: \"{t[:70]}\"")
	# bank VALUES: a raw copy of one is duplication even at count 1
	dlg_banked = {}
	shared_lines_path = DATA / "dialogue" / "_shared_lines.json"
	if shared_lines_path.exists():
		try:
			for name, val in json.loads(shared_lines_path.read_text()).get("banks", {}).items():
				if isinstance(val, str):
					dlg_banked[val] = name
		except Exception:
			pass
	dlg = {}
	for path in sorted(parsed):
		if path.parent.name != "dialogue" or path.stem.startswith("_"):
			continue
		for name, val in (parsed[path].get("text_banks", {}) or {}).items():
			if isinstance(val, str):
				dlg_banked.setdefault(val, name)
		for node in (parsed[path].get("nodes", {}) or {}).values():
			if not isinstance(node, dict):
				continue
			texts = [node.get("text")]
			for v in node.get("text_variants", []) or []:
				texts.append(v if isinstance(v, str) else (v or {}).get("text") if isinstance(v, dict) else None)
			for o in node.get("options", []) or []:
				if isinstance(o, dict):
					texts.append(o.get("text"))
			for t in texts:
				if isinstance(t, str) and len(t) >= MIN_LEN and not t.startswith("@"):
					dlg[t] = dlg.get(t, 0) + 1
	flag(dlg, dlg_banked, "dialogue", "text_banks or _shared_lines.json")
	map_banked = {}
	shared_talk_path = DATA / "maps" / "_shared_talk.json"
	if shared_talk_path.exists():
		try:
			for name, lines in json.loads(shared_talk_path.read_text()).get("banks", {}).items():
				for ln in lines if isinstance(lines, list) else []:
					if isinstance(ln, str):
						map_banked[ln] = name
		except Exception:
			pass
	mp = {}
	for map_id, m in sorted(maps.items()):
		for name, lines in (m.get("talk_banks", {}) or {}).items():
			for ln in lines if isinstance(lines, list) else []:
				if isinstance(ln, str):
					map_banked.setdefault(ln, name)
		for e in m.get("entities", []):
			pools = [e.get("talk_pool")] + [st.get("lines") for st in e.get("talk_pool_stages", []) or [] if isinstance(st, dict)]
			for pool in pools:
				if isinstance(pool, list):
					for t in pool:
						if isinstance(t, str) and len(t) >= MIN_LEN and not t.startswith("@"):
							mp[t] = mp.get(t, 0) + 1
	flag(mp, map_banked, "maps", "talk_banks or _shared_talk.json")


def check_shared_dialogue_banks_used(parsed: dict, errors: list) -> None:
	"""Companion to check_dialogue: a shared bank line nobody references."""
	shared_path = DATA / "dialogue" / "_shared_lines.json"
	shared = (parsed.get(shared_path) or {}).get("banks", {})
	if not shared:
		return
	used = set()
	for path in sorted(parsed):
		if path.parent.name != "dialogue" or path.stem.startswith("_"):
			continue
		local = parsed[path].get("text_banks", {})
		def scan(t):
			if isinstance(t, str) and t.startswith("@") and t[1:] not in local:
				used.add(t[1:])
		for node in (parsed[path].get("nodes", {}) or {}).values():
			if not isinstance(node, dict):
				continue
			scan(node.get("text"))
			for v in node.get("text_variants", []) or []:
				scan(v if isinstance(v, str) else (v or {}).get("text") if isinstance(v, dict) else None)
			for o in node.get("options", []) or []:
				if isinstance(o, dict):
					scan(o.get("text"))
	for bname in shared:
		if bname not in used:
			errors.append(f"dialogue/_shared_lines: banks['{bname}'] is never referenced")


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


def advise_sub_legible_props(parsed: dict, maps: dict, advisories: list) -> None:
	"""Playtest fix wave (finding 15, user directive 2026-08-04): a prop that
	occupies ~a third of a tile is NOT legible -- the [Even Footing] chute
	shipped dressed in 9.6px pebbles and the playtest read the nearby cairn as
	the feature. Advisory tier: flags any map-referenced sprite whose rendered
	frame height lands under 10px (16px cell * ~0.6). Decor dressing and props
	alike; icons/tiles are not map rows so they never trip it."""
	sprites_path = DATA / "sprites.json"
	sprites = parsed.get(sprites_path) or {}
	flagged = set()
	for map_id, m in sorted(maps.items()):
		for row_key in ("entities", "decor"):
			for row in m.get(row_key, []):
				sid = str(row.get("sprite", ""))
				if not sid or sid in flagged or sid not in sprites:
					continue
				entry = sprites[sid]
				if not isinstance(entry, dict):
					continue
				anims = entry.get("animations", {})
				rec = anims.get("idle") or (next(iter(anims.values())) if anims else None)
				if not isinstance(rec, dict):
					continue
				region = rec.get("region")
				fs = rec.get("frame_size", [16, 16])
				src_h = float(region[3]) if isinstance(region, list) and len(region) == 4 else float(fs[1])
				rendered = src_h * float(entry.get("render_scale", 1.0))
				if rendered < 10.0:
					flagged.add(sid)
					advisories.append(f"sprite '{sid}' renders {rendered:.1f}px tall on {map_id}/{row.get('id', row_key)} "
						"-- under the 10px legibility floor (finding 15: a third of a tile does not read)")


def check_talk_banks(maps: dict, errors: list) -> None:
	"""Talk-line banks (2026-08-05): a map's talk_banks entries are spliced
	into talk_pool / talk_pool_stages lines at compose time via "@<name>"
	refs. This arm keeps the seam honest: every ref resolves, banks are
	non-empty string lists, banks do not reference banks (no nesting), and
	no bank rots unused."""
	shared_path = DATA / "maps" / "_shared_talk.json"
	try:
		shared = json.loads(shared_path.read_text()).get("banks", {}) if shared_path.exists() else {}
	except Exception:
		shared = {}
		errors.append("maps/_shared_talk.json: invalid JSON")
	shared_used = set()
	for name, lines in shared.items():
		if not (isinstance(lines, list) and lines and all(isinstance(x, str) for x in lines)):
			errors.append(f"maps/_shared_talk: banks['{name}'] must be a non-empty list of strings")
		elif any(x.startswith("@") for x in lines):
			errors.append(f"maps/_shared_talk: banks['{name}'] contains a ref -- banks may not reference banks")
	for map_id, m in sorted(maps.items()):
		banks = m.get("talk_banks", {})
		if not isinstance(banks, dict):
			errors.append(f"maps/{map_id}: talk_banks must be an object")
			continue
		for name in banks:
			if name in shared:
				errors.append(f"maps/{map_id}: talk_banks['{name}'] shadows a _shared_talk bank name")
		for name, lines in banks.items():
			if not (isinstance(lines, list) and lines and all(isinstance(x, str) for x in lines)):
				errors.append(f"maps/{map_id}: talk_banks['{name}'] must be a non-empty list of strings")
				continue
			for x in lines:
				if x.startswith("@"):
					errors.append(f"maps/{map_id}: talk_banks['{name}'] contains a ref '{x}' -- banks may not reference banks")
		used = set()
		def scan(pool):
			for x in pool:
				if isinstance(x, str) and x.startswith("@"):
					name = x[1:]
					if name in banks:
						used.add(name)
					elif name in shared:
						shared_used.add(name)
					else:
						errors.append(f"maps/{map_id}: talk ref '@{name}' does not resolve")
		for e in m.get("entities", []):
			if isinstance(e.get("talk_pool"), list):
				scan(e["talk_pool"])
			for st in e.get("talk_pool_stages", []) or []:
				if isinstance(st, dict) and isinstance(st.get("lines"), list):
					scan(st["lines"])
		for name in banks:
			if name not in used:
				errors.append(f"maps/{map_id}: talk_banks['{name}'] is never referenced")
	for name in shared:
		if name not in shared_used:
			errors.append(f"maps/_shared_talk: banks['{name}'] is never referenced")


def check_skill_icons(parsed: dict, errors: list) -> None:
	"""Playtest fix wave (finding 3, 2026-08-04): every field-usable skill
	renders on the exploration hotbar, and a missing `icon` degrades to a
	two-letter fallback label -- five of the six martial skills shipped that
	way and the user called it non-shippable. Gate: `field: true` requires an
	`icon`, and the icon id must exist in sprites.json. Passives (no field
	key) are exempt -- they never occupy a hotbar slot."""
	skills_path = DATA / "skills.json"
	sprites_path = DATA / "sprites.json"
	rows = (parsed.get(skills_path) or {}).get("skills", [])
	# sprites.json is FLAT (id -> entry), same access as check_sprites.
	sprites = parsed.get(sprites_path) or {}
	for s in rows:
		if not isinstance(s, dict) or s.get("field") is not True:
			continue
		sid = str(s.get("id", "<no id>"))
		icon = str(s.get("icon") or "")
		if not icon:
			errors.append(f"skills/{sid}: field skill has no `icon` -- it renders "
				"as a two-letter fallback on the hotbar (finding 3 class)")
		elif icon not in sprites:
			errors.append(f"skills/{sid}: icon '{icon}' not in sprites.json")


def check_gate_shapes(maps: dict, errors: list) -> None:
	for map_id, m in sorted(maps.items()):
		for entity in m.get("entities", []):
			_walk_gates(entity, map_id, entity.get("id", "<no id>"), errors)


def _mood_triples(card: dict, label: str, errors: list):
	"""Return (day, dusk, night) as float triples, or None once reported."""
	out = []
	for phase in MOOD_PHASES:
		rgb = card.get(phase)
		if not (isinstance(rgb, list) and len(rgb) == 3
				and all(isinstance(c, (int, float)) and not isinstance(c, bool) for c in rgb)):
			errors.append(f"moods.json: {label} '{phase}' must be a 3-number RGB triple")
			return None
		out.append([float(c) for c in rgb])
	return out


def _light_row_counts(maps: dict) -> dict:
	"""Light rows per map -- decor and entities both carry them (world.gd
	_build_decor / _build_entities each call _attach_light)."""
	counts = {}
	for map_id, m in maps.items():
		n = 0
		for key in ("decor", "entities"):
			for row in m.get(key) or []:
				if isinstance(row, dict) and isinstance(row.get("light"), dict):
					n += 1
		counts[map_id] = n
	return counts


def check_moods(parsed: dict, maps: dict, errors: list) -> None:
	"""GH v0.17 R2 -- the lighting language, enforced instead of asserted.

	Three failure classes, all of them shipped at least once:

	(a) DEAD DATA. `moods.moods.garden` named no map for the life of the
	    project, so a hand-authored card was never once read -- invisible
	    because a missing card silently falls through apply()'s identity
	    fallback. A key here must name a real map (arena cards, a real arena).

	(b) RULE 1, a map WITH a sky (`day != dusk`, which is world.gd's own
	    `_map_has_sky` test): the sky owns the grade, so temperature
	    `t = r - b` and value `v = mean(rgb)` both fall monotonically
	    day -> dusk -> night. Four shipped maps finished the night WARMER
	    than their own dusk before this landed.

	(c) RULE 2, a map WITHOUT one (`day == dusk`): the FLAME owns the warmth,
	    so the grade never tips warm (`t <= 0.03`), and a sealed room that owns
	    light rows must carry `lights_by_day: true` -- otherwise
	    meta.light_energy_by_phase.day = 0.0 deletes the only source the room
	    has and it reads as a cold unlit oven at noon (the adventurers_rest /
	    riverfarm_longhouse defect). The mirror holds too: a map with a sky
	    must NOT opt in, because a lantern adds nothing at noon.

	This is deliberately NOT the cut ID-cross-ref tier: it duplicates no
	GDScript layer (nothing else in the suite reads a moods key at all), it is
	derivable from the JSON alone, and tests/test_world_visuals.gd can only
	hand-pin ids one at a time. Keep the rule here and the pins there.
	"""
	moods_path = DATA / "moods.json"
	if moods_path not in parsed:
		return
	doc = parsed[moods_path]
	lights = _light_row_counts(maps)
	for map_id, card in sorted((doc.get("moods") or {}).items()):
		if map_id.startswith("_") or not isinstance(card, dict):
			continue
		label = f"moods.{map_id}"
		if map_id not in maps:
			errors.append(f"moods.json: '{map_id}' names no map -- the card is dead data "
				"(a missing card falls through to the identity fallback, so nothing looks wrong)")
			continue
		triples = _mood_triples(card, label, errors)
		if triples is None:
			continue
		day, dusk, night = triples
		temps = [rgb[0] - rgb[2] for rgb in triples]
		values = [sum(rgb) / 3.0 for rgb in triples]
		has_sky = any(abs(day[i] - dusk[i]) > SKY_GRADE_EPSILON for i in range(3))
		opts_in = bool(card.get("lights_by_day", False))
		if has_sky:
			for name, series in (("temperature (r-b)", temps), ("value", values)):
				if not (series[0] - series[1] > MONO_EPS and series[1] - series[2] > MONO_EPS):
					errors.append(f"moods.json: '{map_id}' has a sky (day != dusk) but its "
						f"{name} is not monotone day>dusk>night "
						f"({series[0]:+.3f}/{series[1]:+.3f}/{series[2]:+.3f}) -- RULE 1")
			if opts_in:
				errors.append(f"moods.json: '{map_id}' has a sky yet sets lights_by_day -- "
					"a lantern adds nothing at noon (RULE 2 mirror)")
		else:
			for phase, temp in zip(MOOD_PHASES, temps):
				if temp > WARM_GRADE_CEILING + MONO_EPS:
					errors.append(f"moods.json: sealed map '{map_id}' tips its {phase} grade WARM "
						f"(t={temp:+.3f} > {WARM_GRADE_CEILING}) -- warmth belongs to the light "
						"rows, never to the grade (RULE 2)")
			if lights.get(map_id, 0) > 0 and not opts_in:
				errors.append(f"moods.json: sealed map '{map_id}' owns {lights[map_id]} light row(s) "
					"but no lights_by_day -- meta.light_energy_by_phase.day = 0.0 switches them "
					"all off at noon (RULE 2)")
	# (d) THE CLOCK'S OWN PRECONDITION (#359). WIGame.phase_for derives the
	# looping cycle as 2*night, day == night == dusk, dusk band == night - dusk.
	# dusk <= 0 or night <= dusk leaves no band to wrap through: the sim falls
	# back to the pre-loop monotone read (safe, but the clock silently stops
	# looping), so shipped data may never carry it.
	thresholds = (doc.get("meta") or {}).get("phase_thresholds") or {}
	dusk_at, night_at = thresholds.get("dusk"), thresholds.get("night")
	if not isinstance(dusk_at, int) or not isinstance(night_at, int):
		errors.append("moods.json: meta.phase_thresholds needs int 'dusk' and 'night' -- "
			"WIGame.phase_for reads them as the looping clock's only inputs (#359)")
	elif not 0 < dusk_at < night_at:
		errors.append(f"moods.json: meta.phase_thresholds must satisfy 0 < dusk ({dusk_at}) "
			f"< night ({night_at}) -- otherwise the cycle has no dusk band to wrap through "
			"and phase_for drops back to the pre-loop monotone read (#359)")
	arenas_path = DATA / "arenas.json"
	arena_ids = set()
	if arenas_path in parsed:
		arena_ids = {str(a.get("id")) for a in parsed[arenas_path].get("arenas", [])
			if isinstance(a, dict)}
	for arena_id, card in sorted((doc.get("arena_moods") or {}).items()):
		if arena_id.startswith("_") or not isinstance(card, dict):
			continue
		if arena_ids and arena_id not in arena_ids:
			errors.append(f"moods.json: arena_moods '{arena_id}' names no arena -- dead data")
			continue
		_mood_triples(card, f"arena_moods.{arena_id}", errors)


# --- interactions.json (issue #348 slice 1) ----------------------------------
# MIRROR CONTRACT: the engine's closed outcome-verb set lives in
# src/core/field_skills.gd (WIFieldSkills.OUTCOMES). This copy lets the
# engine-free tier reject an unknown verb; tests/test_interactions_table.gd
# asserts the JSON's own "outcomes" equals the GDScript const, so the three can
# never drift silently. A new verb touches all three, deliberately.
ENGINE_OUTCOMES = ("remove_scorch", "freeze_cell", "thaw_cell", "state_set", "refuse")
PLACEMENTS = ("entity", "cell")
# "row" = the pair itself owns the line (what a refusal cell is); the other two
# read `toast_key` off the target entity / the casting skill.
TOAST_SOURCES = ("skill", "target", "row")
# Persistence classes each verb may claim (spec §4.1's table). `immediate` =
# thaw_cell, which ERASES a frozen_cells entry and creates no timed state of its
# own; `none` = the verbs that write no world state at all.
OUTCOME_PERSISTENCE = {
	"remove_scorch": {"permanent"},
	"freeze_cell": {"until_sleep"},
	"thaw_cell": {"immediate"},
	"state_set": {"permanent"},
	"refuse": {"none"},
}
# VERB/PLACEMENT BINDING -- mirrors WIFieldSkills.OUTCOME_PLACEMENT. Each verb's
# body has a fixed target shape: `remove_scorch`/`state_set` dereference the
# faced ENTITY, `freeze_cell`/`thaw_cell` write the faced CELL and never read
# the entity, `refuse` reads neither and so binds to "any". Binding them is what
# makes "a new ROW is data alone" TRUE: without it a lint-clean row could
# hard-error a live cast (remove_scorch on a cell class, which reaches
# `target[id]` with target == {}) or silently flip an arbitrary cell's
# walkability (freeze_cell on an entity class -- `is_cell_blocked` treats every
# frozen cell as passable, so that row is a wall-phase primitive).
PLACEMENT_ANY = "any"
OUTCOME_PLACEMENT = {
	"remove_scorch": "entity",
	"freeze_cell": "cell",
	"thaw_cell": "cell",
	"state_set": "entity",
	"refuse": PLACEMENT_ANY,
}
# Verbs whose body emits TERRAIN_CHANGED and therefore need a `terrain` value.
# `terrain` on any other verb is dead data (the field is never read).
OUTCOME_EMITS_TERRAIN = {"remove_scorch", "freeze_cell", "thaw_cell"}
# Verbs whose BODY actually banks a counter (WIFieldSkills._outcome_*). A
# counter field on any other verb is dead data: it is silently dropped at
# dispatch. The two banking verbs source the id DIFFERENTLY, and the split is
# deliberate:
#   remove_scorch -- row-level `counter` (one burn counter for every burnable).
#   state_set     -- row-level `counter_key` NAMING A FIELD ON THE CARRIER, so
#                    each prop banks its own id. A shared row-level counter
#                    would make lighting one lamp flip every sibling lamp's
#                    visual_states, which is durable wrong state in a save.
OUTCOME_BANKS_COUNTER = {"remove_scorch", "state_set"}
OUTCOME_COUNTER_ON_CARRIER = {"state_set"}
# DYNAMIC cell classes: not authored on any map, produced at runtime by another
# verb. Their carriers are the carriers of the class that PRODUCES them, so a
# row targeting one is reachable exactly when the producer's own class is
# carried. `frozen` is written by freeze_cell over map-authored `freezable`.
DYNAMIC_CELL_PROPERTIES = {"frozen": "freezable"}


def _skill_property_carriers(parsed: dict, prop: str) -> list:
	skills_path = DATA / "skills.json"
	rows = (parsed.get(skills_path) or {}).get("skills", []) if skills_path in parsed else []
	return [str(s.get("id")) for s in rows if isinstance(s, dict) and s.get(prop) is True]


def _entity_carriers(maps: dict, prop: str) -> list:
	"""(map_id, entity) pairs for every entity carrying an entity-placed flag."""
	out = []
	for map_id, m in sorted(maps.items()):
		for entity in m.get("entities", []):
			if entity.get(prop) is True:
				out.append((map_id, entity))
	return out


def _target_property_carriers(maps: dict, prop: str, placement: str) -> list:
	"""Shipped carriers of a target property: entity flags, or map cell classes."""
	out = []
	source = DYNAMIC_CELL_PROPERTIES.get(prop, prop)
	for map_id, m in sorted(maps.items()):
		if placement == "entity":
			for entity in m.get("entities", []):
				if entity.get(prop) is True:
					out.append(f"{map_id}:{entity.get('id', '<no id>')}")
		elif placement == "cell" and m.get(source):
			out.append(f"{map_id}:{len(m[source])}")
	return out


def _shipped_accomplishments(parsed: dict) -> set:
	path = DATA / "shipped_ids.json"
	rows = (parsed.get(path) or {}).get("accomplishments") or []
	return {str(a) for a in rows}


def _check_carrier_counters(row: dict, tp: str, label: str, maps: dict, parsed: dict, errors: list) -> None:
	"""`state_set`'s counter is authored PER CARRIER, so the check runs per prop.

	Three things have to hold or the one-way set is either invisible or wrong:
	the row must name the carrier field (`counter_key`); every carrier must
	author that field with a REGISTERED accomplishment id (same freeze-list
	discipline the row-level `counter` gets); and the carrier must watch that
	same id from a `visual_states` row, because with field name tags retired a
	state change the world does not SHOW is a bank the player never sees.
	"""
	key = row.get("counter_key")
	if not isinstance(key, str) or not key:
		errors.append(f"interactions.json: {label} outcome 'state_set' banks the counter named by "
			"'counter_key' (a FIELD on each carrier) -- add a non-empty 'counter_key'")
		return
	if row.get("counter") not in (None, ""):
		errors.append(f"interactions.json: {label} outcome 'state_set' reads its counter off the "
			"CARRIER, never the row -- drop 'counter' (dead data; a shared id would flip every "
			"sibling carrier's visual_states at once)")
	shipped = _shipped_accomplishments(parsed)
	for map_id, entity in _entity_carriers(maps, tp):
		eid = entity.get("id", "<no id>")
		counter = entity.get(key)
		if not isinstance(counter, str) or not counter:
			errors.append(f"interactions.json: {label} carrier maps/{map_id}:{eid} authors no "
				f"non-empty '{key}' -- the row is inert on it (no counter, no state)")
			continue
		if shipped and counter not in shipped:
			errors.append(f"interactions.json: {label} carrier maps/{map_id}:{eid} banks "
				f"'{counter}', which is not in data/shipped_ids.json's accomplishments -- "
				"regenerate via scripts/generate_shipped_ids.py")
		watched = any(isinstance(s, dict)
			and str((s.get("when") or {}).get("counter", "")) == counter
			for s in entity.get("visual_states", []))
		if not watched:
			errors.append(f"maps/{map_id}: entity '{eid}' carries the '{tp}' property but no "
				f"visual_states row watches its own '{counter}' -- state_set is ONE-WAY and "
				"permanent, so a set the world never shows is invisible durable state")


def _check_row_counter(row: dict, outcome: str, label: str, parsed: dict, errors: list) -> None:
	"""Spec §5(c): a row's `counter` gets the standard producer/consumer treatment.

	`counter` is the ONE table field the engine banks into the save
	(WIFieldSkills._outcome_remove_scorch -> _record_accomplishment), and nothing
	else in the repo reads interactions.json -- generate_shipped_ids.py's census
	is hand-maintained. So an unregistered counter used to bank into saves as an
	id no registry knows, and the first quest beat or class gate naming it would
	trip test_content's unproduced-counter tripwire with no pointer back to the
	table. Registration is the cure: a new row's counter joins
	scripts/generate_shipped_ids.py STRUCTURAL_LITERALS (+ its
	tests/test_shipped_ids.gd mirror), then data/shipped_ids.json is regenerated.
	Also catches the other direction -- a counter on a verb whose body never
	banks one is silently dropped at dispatch, i.e. dead data.
	"""
	counter = row.get("counter")
	if outcome not in OUTCOME_BANKS_COUNTER:
		for dead in ("counter", "counter_key"):
			if row.get(dead) not in (None, ""):
				errors.append(f"interactions.json: {label} outcome '{outcome}' banks no counter, "
					f"but the row declares {dead} {row[dead]!r} -- dead data (the field is "
					"dropped at dispatch); drop it or use a counter-banking verb")
		return
	if outcome in OUTCOME_COUNTER_ON_CARRIER:
		return  # handled per carrier by _check_carrier_counters
	if row.get("counter_key") not in (None, ""):
		errors.append(f"interactions.json: {label} outcome '{outcome}' banks the ROW's 'counter' -- "
			"'counter_key' is dead data here (only the carrier-sourced verbs read it)")
	if counter is None:
		return  # optional: a burn row may legitimately bank nothing
	if not isinstance(counter, str) or not counter:
		errors.append(f"interactions.json: {label} 'counter' must be a non-empty string when present")
		return
	shipped = _shipped_accomplishments(parsed)
	if shipped and counter not in shipped:
		errors.append(f"interactions.json: {label} banks counter '{counter}', which is not in "
			"data/shipped_ids.json's accomplishments -- register it in "
			"scripts/generate_shipped_ids.py STRUCTURAL_LITERALS (and the matching const "
			"in tests/test_shipped_ids.gd), then regenerate")
	elif not shipped:
		errors.append(f"interactions.json: {label} banks counter '{counter}' but "
			"data/shipped_ids.json carries no accomplishments list -- cannot verify "
			"registration, which is a broken census, not a pass")


def check_interactions(parsed: dict, maps: dict, errors: list, report: list) -> None:
	"""Vocabulary registration + row shape + carrier cross-ref + totality census.

	The combinatorial fear (N properties x M objects) is answered by making the
	TABLE the QA surface: rows are finite and each must be REACHABLE, so a
	carrier-less row is dead data and fails HERE rather than rotting. K4 applies
	-- if this arm ever seems to need an allowlist, the vocabulary is wrong.
	"""
	uncovered = [v for v in ENGINE_OUTCOMES
		if v not in OUTCOME_PLACEMENT or v not in OUTCOME_PERSISTENCE]
	if uncovered:
		errors.append(f"data_lint: outcome verb(s) {uncovered} are in ENGINE_OUTCOMES but carry no "
			"OUTCOME_PLACEMENT/OUTCOME_PERSISTENCE row -- a new verb fills BOTH tables here")
		return
	path = DATA / "interactions.json"
	if path not in parsed:
		errors.append("interactions.json: missing -- the property table is required "
			"(WISceneCatalog composes it into every scene_config)")
		return
	doc = parsed[path]
	skill_props = doc.get("skill_properties")
	target_props = doc.get("target_properties")
	staged_target_props = doc.get("staged_target_properties", [])
	rows = doc.get("interactions")
	if not (isinstance(skill_props, list) and skill_props
			and all(isinstance(p, str) for p in skill_props)):
		errors.append("interactions.json: 'skill_properties' must be a non-empty list of names")
		return
	if not (isinstance(target_props, dict) and target_props):
		errors.append("interactions.json: 'target_properties' must be a non-empty {name: placement} map")
		return
	if not isinstance(staged_target_props, list) or any(not isinstance(prop, str)
			for prop in staged_target_props) or len(set(staged_target_props)) != len(staged_target_props):
		errors.append("interactions.json: 'staged_target_properties' must be a duplicate-free string list")
		staged_target_props = []
	for prop in staged_target_props:
		if prop not in target_props:
			errors.append(f"interactions.json: staged target property '{prop}' is not registered")
	if not isinstance(rows, list) or not rows:
		errors.append("interactions.json: 'interactions' must be a non-empty list of rows")
		return
	if list(doc.get("outcomes") or []) != list(ENGINE_OUTCOMES):
		errors.append(f"interactions.json: 'outcomes' {doc.get('outcomes')!r} must mirror the "
			f"engine's WIFieldSkills.OUTCOMES {list(ENGINE_OUTCOMES)!r} (MIRROR CONTRACT)")
		return
	if len(set(skill_props)) != len(skill_props):
		errors.append("interactions.json: duplicate entry in 'skill_properties'")
	for prop, placement in sorted(target_props.items()):
		if placement not in PLACEMENTS:
			errors.append(f"interactions.json: target property '{prop}' declares placement "
				f"'{placement}' -- must be one of {list(PLACEMENTS)}")
	# Vocabulary must be CARRIED on both sides: an uncarried term is dead data.
	for prop in sorted(set(skill_props)):
		if not _skill_property_carriers(parsed, prop):
			errors.append(f"interactions.json: skill property '{prop}' is registered but no "
				"skills.json row carries it -- dead vocabulary")
	for prop, placement in sorted(target_props.items()):
		carriers = _target_property_carriers(maps, prop, placement) if placement in PLACEMENTS else []
		if prop in staged_target_props and carriers:
			errors.append(f"interactions.json: staged target property '{prop}' now has shipped carriers; "
				"remove it from staged_target_properties")
		elif placement in PLACEMENTS and not carriers and prop not in staged_target_props:
			errors.append(f"interactions.json: target property '{prop}' is registered but no "
				f"map carries it as a {placement} property -- dead vocabulary")
	seen = set()
	for i, row in enumerate(rows):
		if not isinstance(row, dict):
			errors.append(f"interactions.json: row {i} is not an object")
			continue
		sp, tp = row.get("skill_property"), row.get("target_property")
		label = f"row {i} ({sp} x {tp})"
		if sp not in skill_props:
			errors.append(f"interactions.json: {label} names unregistered skill property {sp!r}")
		if tp not in target_props:
			errors.append(f"interactions.json: {label} names unregistered target property {tp!r}")
			continue
		if (sp, tp) in seen:
			errors.append(f"interactions.json: {label} duplicates an earlier row -- "
				"first match wins, so the later one is unreachable")
		seen.add((sp, tp))
		outcome = row.get("outcome")
		if outcome not in ENGINE_OUTCOMES:
			errors.append(f"interactions.json: {label} names unknown outcome {outcome!r}")
			continue
		# VERB/PLACEMENT BINDING: the verb's body dereferences one shape or the
		# other, so the pairing is a correctness question, not a style one -- see
		# OUTCOME_PLACEMENT above for the two failure modes it forecloses.
		want = OUTCOME_PLACEMENT[outcome]
		got = target_props.get(tp)
		if want != PLACEMENT_ANY and got != want:
			errors.append(f"interactions.json: {label} outcome '{outcome}' acts on the faced "
				f"{want}, but target property '{tp}' is declared placement {got!r} -- bind "
				f"'{outcome}' to a '{want}'-placement property; WIFieldSkills.OUTCOME_PLACEMENT "
				"is the engine mirror of this rule and makes such a row inert")
		allowed = OUTCOME_PERSISTENCE[outcome]
		if row.get("persistence") not in allowed:
			errors.append(f"interactions.json: {label} outcome '{outcome}' claims persistence "
				f"{row.get('persistence')!r} -- allowed: {sorted(allowed)}")
		toast_from = row.get("toast_from")
		if toast_from not in TOAST_SOURCES:
			errors.append(f"interactions.json: {label} 'toast_from' must be one of {list(TOAST_SOURCES)}")
		required = ["toast_default"]
		# `toast_key` names a field on the chosen side, so it is required exactly
		# when there IS a side; a toast_from:"row" cell owns its line outright.
		if toast_from in ("skill", "target"):
			required.append("toast_key")
		if outcome in OUTCOME_EMITS_TERRAIN:
			required.append("terrain")
		for key in required:
			if not isinstance(row.get(key), str) or not row[key]:
				errors.append(f"interactions.json: {label} missing non-empty '{key}'")
		for dead_key, live in (("toast_key", toast_from in ("skill", "target")),
				("terrain", outcome in OUTCOME_EMITS_TERRAIN)):
			if not live and row.get(dead_key) not in (None, ""):
				errors.append(f"interactions.json: {label} declares '{dead_key}' but nothing reads "
					"it for this row -- dead data")
		_check_row_counter(row, outcome, label, parsed, errors)
		if outcome in OUTCOME_COUNTER_ON_CARRIER:
			_check_carrier_counters(row, tp, label, maps, parsed, errors)
		# Per-row carrier cross-ref (spec §5b): a row nothing can reach is dead.
		if sp in skill_props and not _skill_property_carriers(parsed, sp):
			errors.append(f"interactions.json: {label} has no skill carrier")
		if tp not in staged_target_props and not _target_property_carriers(maps, tp, target_props.get(tp, "")):
			errors.append(f"interactions.json: {label} has no shipped target carrier")
	# TOTALITY CENSUS (spec §4.2 tier 3): the whole cross-product, classified.
	# Report-only by design -- a null cell is the SHIPPED fallthrough
	# (field_ambient/refusal), not a gap. Its job is to keep the surface finite
	# and visible, so K2 (abstraction failure) stays measurable.
	authored = {(str(r.get("skill_property")), str(r.get("target_property")))
		for r in rows if isinstance(r, dict)}
	cells = len(set(skill_props)) * len(target_props)
	report.append(f"interactions.json: totality census {len(authored)}/{cells} cells authored "
		f"({len(set(skill_props))} skill x {len(target_props)} target properties); "
		"the rest fall through to field_ambient/refusal by design")


def advise_unlit_sealed_rooms(maps: dict, parsed: dict, advisories: list) -> None:
	"""The riverfarm_longhouse class: a map with light rows and NO mood card.

	`_map_has_sky` falls to TRUE for a card-less map (the conservative
	direction for particles), so its lamps are zeroed at noon and its grade is
	identity at every hour -- which is how the longhouse ended up measurably
	brighter at midnight than at midday. Advisory, not an error: an exterior
	with a campfire is a perfectly honest answer.
	"""
	moods_path = DATA / "moods.json"
	cards = (parsed.get(moods_path) or {}).get("moods", {}) if moods_path in parsed else {}
	for map_id, n in sorted(_light_row_counts(maps).items()):
		if n > 0 and map_id not in cards:
			advisories.append(f"maps/{map_id}: {n} light row(s) but no moods.json card -- "
				"the map is treated as sky-bearing, so those lights are dark at day")


def advise_acted_on_state(maps: dict, advisories: list) -> int:
	"""GH#335 item 3 -- persistent acted-on state.

	A prop with `on_interact_accomplishment` is one the player CHANGES: they
	interact, a counter banks, and the world is different afterwards. With
	field name tags retired (R3), the ONLY way that difference can reach the
	player is a `visual_states` row -- otherwise the prop looks byte-identical
	before and after, and every later visit invites the same pointless press.

	Report-only, and deliberately so: "should this prop show its state?" is a
	design question with real "no" answers (a pond edge you merely looked at
	does not change). This tier's job is to keep the ratio VISIBLE so the gap
	is chosen rather than forgotten. Returns the total interacted-prop count so
	the caller can print the ratio, not a bare scary number.
	"""
	total = 0
	for map_id, m in sorted(maps.items()):
		for entity in m.get("entities", []):
			if not entity.get("on_interact_accomplishment"):
				continue
			total += 1
			if not entity.get("visual_states"):
				advisories.append(f"maps/{map_id}: entity "
					f"'{entity.get('id', '<no id>')}' banks on_interact_accomplishment "
					"but carries no visual_states row -- the world cannot show it was acted on")
	return total


def main() -> int:
	start = time.monotonic()
	list_advisories = "--advisories" in sys.argv
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
	check_skill_gates(parsed, maps, errors)
	# MERGE NOTE (v0.18 W1): this pair is parked HERE, at the top of the check_*
	# block, and its REPORT print at the very bottom of main() -- both as far as
	# possible from the advisory region a sibling lane is extending this wave, so
	# the two arms auto-merge instead of colliding inside one function.
	report: list = []
	check_interactions(parsed, maps, errors, report)
	check_portals(parsed, maps, errors)
	check_dialogue(parsed, errors)
	check_shared_dialogue_banks_used(parsed, errors)
	check_prose_duplication(parsed, maps, errors)
	check_sprites(parsed, errors)
	check_skill_icons(parsed, errors)
	check_talk_banks(maps, errors)
	check_gate_shapes(maps, errors)
	check_moods(parsed, maps, errors)
	advisories: list = []
	skill_gate_advisories: list = []
	advise_missing_skill_gates(maps, skill_gate_advisories)
	advise_unlit_sealed_rooms(maps, parsed, advisories)
	advise_sub_legible_props(parsed, maps, advisories)
	interacted_props = advise_acted_on_state(maps, advisories)
	elapsed_ms = (time.monotonic() - start) * 1000
	if errors:
		for e in errors:
			print(f"data_lint: FAIL -- {e}", file=sys.stderr)
		print(f"data_lint: {len(errors)} error(s) in {elapsed_ms:.0f}ms "
			"(structural tier only -- the Godot gates still apply).", file=sys.stderr)
		return 1
	print(f"data_lint: OK -- {len(parsed)} files, {len(maps)} maps clean "
		f"in {elapsed_ms:.0f}ms (structural tier only -- Godot gates still apply).")
	if advisories:
		# ONE line by default. A 90-row wall printed on every sweep is a wall
		# nobody reads, and this tier's whole value is that someone reads it.
		if list_advisories:
			for a in advisories:
				print(f"data_lint: ADVISORY -- {a}")
		print(f"data_lint: ADVISORY -- {len(advisories)}/{interacted_props} props that bank "
			"an interact accomplishment show no visual change for it (GH#335 item 3); "
			"re-run with --advisories to list them. Report-only, never fails.")
	if skill_gate_advisories:
		if list_advisories:
			for advisory in skill_gate_advisories:
				print(f"data_lint: ADVISORY -- {advisory}")
		print(f"data_lint: ADVISORY -- {len(skill_gate_advisories)} map(s) show a likely traversal gate "
			"but carry no skill_gates registry. Report-only, never fails.")
	for line in report:
		print(f"data_lint: REPORT -- {line}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
