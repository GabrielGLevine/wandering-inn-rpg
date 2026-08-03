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
ENGINE_OUTCOMES = ("remove_scorch", "freeze_cell")
PLACEMENTS = ("entity", "cell")
TOAST_SOURCES = ("skill", "target")
# Persistence classes each verb may claim (spec §4.1's table).
OUTCOME_PERSISTENCE = {
	"remove_scorch": {"permanent"},
	"freeze_cell": {"until_sleep"},
}


def _skill_property_carriers(parsed: dict, prop: str) -> list:
	skills_path = DATA / "skills.json"
	rows = (parsed.get(skills_path) or {}).get("skills", []) if skills_path in parsed else []
	return [str(s.get("id")) for s in rows if isinstance(s, dict) and s.get(prop) is True]


def _target_property_carriers(maps: dict, prop: str, placement: str) -> list:
	"""Shipped carriers of a target property: entity flags, or map cell classes."""
	out = []
	for map_id, m in sorted(maps.items()):
		if placement == "entity":
			for entity in m.get("entities", []):
				if entity.get(prop) is True:
					out.append(f"{map_id}:{entity.get('id', '<no id>')}")
		elif placement == "cell" and m.get(prop):
			out.append(f"{map_id}:{len(m[prop])}")
	return out


def check_interactions(parsed: dict, maps: dict, errors: list, report: list) -> None:
	"""Vocabulary registration + row shape + carrier cross-ref + totality census.

	The combinatorial fear (N properties x M objects) is answered by making the
	TABLE the QA surface: rows are finite and each must be REACHABLE, so a
	carrier-less row is dead data and fails HERE rather than rotting. K4 applies
	-- if this arm ever seems to need an allowlist, the vocabulary is wrong.
	"""
	path = DATA / "interactions.json"
	if path not in parsed:
		errors.append("interactions.json: missing -- the property table is required "
			"(WISceneCatalog composes it into every scene_config)")
		return
	doc = parsed[path]
	skill_props = doc.get("skill_properties")
	target_props = doc.get("target_properties")
	rows = doc.get("interactions")
	if not (isinstance(skill_props, list) and skill_props
			and all(isinstance(p, str) for p in skill_props)):
		errors.append("interactions.json: 'skill_properties' must be a non-empty list of names")
		return
	if not (isinstance(target_props, dict) and target_props):
		errors.append("interactions.json: 'target_properties' must be a non-empty {name: placement} map")
		return
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
		if placement in PLACEMENTS and not _target_property_carriers(maps, prop, placement):
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
		allowed = OUTCOME_PERSISTENCE[outcome]
		if row.get("persistence") not in allowed:
			errors.append(f"interactions.json: {label} outcome '{outcome}' claims persistence "
				f"{row.get('persistence')!r} -- allowed: {sorted(allowed)}")
		if row.get("toast_from") not in TOAST_SOURCES:
			errors.append(f"interactions.json: {label} 'toast_from' must be one of {list(TOAST_SOURCES)}")
		for key in ("toast_key", "toast_default", "terrain"):
			if not isinstance(row.get(key), str) or not row[key]:
				errors.append(f"interactions.json: {label} missing non-empty '{key}'")
		# Per-row carrier cross-ref (spec §5b): a row nothing can reach is dead.
		if sp in skill_props and not _skill_property_carriers(parsed, sp):
			errors.append(f"interactions.json: {label} has no skill carrier")
		if not _target_property_carriers(maps, tp, target_props.get(tp, "")):
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
	check_portals(parsed, maps, errors)
	check_dialogue(parsed, errors)
	check_sprites(parsed, errors)
	check_gate_shapes(maps, errors)
	check_moods(parsed, maps, errors)
	report: list = []
	check_interactions(parsed, maps, errors, report)
	advisories: list = []
	advise_unlit_sealed_rooms(maps, parsed, advisories)
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
	for line in report:
		print(f"data_lint: REPORT -- {line}")
	if advisories:
		# ONE line by default. A 90-row wall printed on every sweep is a wall
		# nobody reads, and this tier's whole value is that someone reads it.
		if list_advisories:
			for a in advisories:
				print(f"data_lint: ADVISORY -- {a}")
		print(f"data_lint: ADVISORY -- {len(advisories)}/{interacted_props} props that bank "
			"an interact accomplishment show no visual change for it (GH#335 item 3); "
			"re-run with --advisories to list them. Report-only, never fails.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
