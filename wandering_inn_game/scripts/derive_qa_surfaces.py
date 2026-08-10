#!/usr/bin/env python3
"""derive_qa_surfaces.py -- mechanically derives qa/manifest.json's
per-script "surfaces" (maps/fixtures/skills/systems touched) FROM the
script + fixture + data files themselves. Never hand-author a surfaces
block -- re-run this generator, which is also what the ci_sweep.sh drift
check does (--check mode) so a stale tag is always caught (vacuous-
selective is the exact failure mode this guards).

Signal collection walks each qa/scripts/<name>.json's real DSL fields only
(action names, event "type"s, payload_contains keys+values, assert_state
path/equals) -- "_comment" prose is never scanned, so authored narrative
text can never leak a false tag. maps/skills are cross-checked against the
live catalogs (data/skeleton_scene.json's "maps" keys, data/skills.json's
ids) so an unrelated string that happens to collide is never mistaken for
a reference. Fixtures come from BOTH the harness pre-seed (`fixture_save`/
`legacy_seed`/the manifest row's `fixture`) AND every mid-script
`install_fixture` action's `fixture` (#417) -- each of those is loaded for
real, so each one's map/skills enrich the surface exactly like the
pre-seed's. "systems" is the one taxonomy that needs an authored marker
table (the game has no per-system metadata to mine beyond skills.json's
coarse combat/exploration "contexts") -- everything else is pure lookup.

Usage:
  scripts/derive_qa_surfaces.py            regenerate qa/manifest.json in place
  scripts/derive_qa_surfaces.py --check     compute fresh, diff vs committed, FATAL on drift
  scripts/derive_qa_surfaces.py --touching a.json,b.json   print crossing script names (one per line)

--touching path coverage (GH#281): qa/scripts, qa/fixtures, data/dialogue/,
data/maps/, scene_root (= full sweep), skills/classes/progression (all-skill
fallback), and the monolithic catalogs via MONOLITH_SYSTEMS (portals, quests,
acts, leads, bounties, deliveries, combatants, arenas, audio, items,
fence_stock -> manifest "systems" tags). Anything else warns LOUDLY on
stderr and derives
nothing -- never treat empty output as "no re-gate needed".
"""
from __future__ import annotations

import json
import os
import re
import sys

import wi_data_lib

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_ROOT = os.path.dirname(HERE)
MANIFEST_PATH = os.path.join(GAME_ROOT, "qa", "manifest.json")
SCRIPTS_DIR = os.path.join(GAME_ROOT, "qa", "scripts")
FIXTURES_DIR = os.path.join(GAME_ROOT, "qa", "fixtures")
DIALOGUE_DIR = os.path.join(GAME_ROOT, "data", "dialogue")
MAPS_DIR = os.path.join(GAME_ROOT, "data", "maps")
SCENE_ROOT_PATH = os.path.join(GAME_ROOT, "data", "scene_root.json")
SKILLS_PATH = os.path.join(GAME_ROOT, "data", "skills.json")

# Authored once: maps a signal token (action name / event type / payload
# key / payload value) to the "systems" tag(s) it proves. A script earns a
# tag iff ANY of its own signals intersects the set below -- pure lookup,
# zero per-script judgment.
SYSTEM_MARKERS: dict[str, set[str]] = {
	"combat": {
		"combat_autoplay", "assert_world_labels_in_view",
		"combat_started", "combat_finished", "combat_resolved",
		"turn_started", "turn_ended", "attack_resolved", "skill_resolved",
		"combatant_moved", "dashed", "reaction_triggered", "windup_declared",
		"terrain_added", "terrain_changed", "ui_combat_shown", "ui_combat_hidden",
		"ui_targeting_shown", "ui_aim_preview_rendered", "ui_slot_info_rendered",
		"action_refused", "ui_combat_hint_rendered", "status_applied",
		"status_expired", "sneak_started", "sneak_ended", "ui_sneak_rendered",
		"ui_hotbar_rendered",
	},
	"dialogue": {
		"dialogue_started", "dialogue_node", "dialogue_ended", "dialogue_line",
		"dialogue_choice", "ui_dialogue_shown", "ui_dialogue_hidden",
		"ui_dialogue_rendered", "click_dialogue_option",
	},
	"quests": {"quest_started", "quest_completed", "quest_beat_completed"},
	"boards": {
		"guild_board", "runner_board", "delivery_board", "the_request_board",
		"posting_title", "posting_status", "posting_gold",
	},
	"portals": {"portal_menu"},
	"save": {
		"assert_save_exists", "click_pause_slot_row", "click_slot",
		"ui_slot_picker_rendered", "ui_slot_picker_hidden", "game_reset",
	},
	"settings": {
		"ui_settings_rendered", "ui_settings_shown", "ui_settings_hidden",
		"ui_controls_rendered", "ui_help_rendered", "ui_hints_replayed",
		"click_settings_row", "assert_settings_file_exists",
		"assert_settings_value",
	},
	"economy": {
		"gold_changed", "item_gained", "item_lost", "loot_dropped",
		"item_equipped", "item_unequipped", "click_inventory_row",
		"ui_inventory_shown", "ui_inventory_hidden",
	},
	"traps": {"disarm_trap", "trap_disarmed", "trap_kit"},
	"night_phase": {"phase_changed", "phase"},
	"audio": {
		"audio_played", "assert_audio_bus_volume_db", "assert_audio_bus_send",
		"assert_audio_bus_volume",
	},
}
# Prefix-matched systems (action/type family, not a fixed vocabulary).
SYSTEM_PREFIX_MARKERS: dict[str, list[str]] = {
	"char_creation": ["click_char_creation", "ui_char_creation"],
	"input": ["click"],
}
ATTUNED_RE = re.compile(r"^[a-z_]+_attuned$")
# skills.json "contexts" -> a coarse systems fallback (the "skills
# mechanically" half of derivation: a script using a combat-context skill
# earns "combat", an exploration-context skill earns "exploration").
CONTEXT_TO_SYSTEM = {"combat": "combat", "exploration": "exploration"}


def _load(path: str) -> dict:
	with open(path) as f:
		return json.load(f)


# Issue #100 split layout; the composition contract (sorted glob, stem
# keys, dup = ValueError) lives in wi_data_lib -- the ONE Python mirror of
# src/core/scene_catalog.gd's WISceneCatalog.compose() (GH#281).
def _known_maps() -> set[str]:
	return wi_data_lib.known_maps()


def _known_skills() -> tuple[set[str], dict[str, list[str]]]:
	skills = _load(SKILLS_PATH)["skills"]
	ids = {s["id"] for s in skills}
	contexts = {s["id"]: s.get("contexts", []) for s in skills}
	return ids, contexts


def _known_dialogue_ids() -> set[str]:
	if not os.path.isdir(DIALOGUE_DIR):
		return set()
	return {os.path.splitext(f)[0] for f in os.listdir(DIALOGUE_DIR) if f.endswith(".json")}


def _collect_signals(node, keys: set, values: set, path_equals: list) -> None:
	"""Walk a parsed script's steps. Never descends into "_comment" --
	prose can never leak a tag. Collects action names, event types,
	payload_contains keys/values, assert_state (path, equals), and
	press_field_skill/teleport's own top-level "skill"/"map" fields."""
	if isinstance(node, dict):
		for k, v in node.items():
			if k == "_comment":
				continue
			if k in ("action", "type", "skill", "map", "name") and isinstance(v, str):
				values.add(v)
			if k == "payload_contains" and isinstance(v, dict):
				for pk, pv in v.items():
					keys.add(pk)
					if isinstance(pv, str):
						values.add(pv)
					elif isinstance(pv, list):
						values.update(x for x in pv if isinstance(x, str))
			if k == "path" and isinstance(v, str) and "equals" in node:
				eq = node["equals"]
				if isinstance(eq, str):
					path_equals.append((v, eq))
					values.add(eq)
			_collect_signals(v, keys, values, path_equals)
	elif isinstance(node, list):
		for item in node:
			_collect_signals(item, keys, values, path_equals)


def _fixture_save_names(spec) -> list[str]:
	"""A script's `fixture_save` normalized to the fixture name(s) it seeds.
	qa/test_driver.gd's _install_fixture_saves() accepts BOTH a bare String and
	an ARRAY of {fixture, slot} Dictionaries (test_driver.gd:146-153). No script
	uses the array form today, but reading it as a plain string silently dropped
	EVERY fixture such a script seeds -- the same false-safe #417 fixed for
	install_fixture, just waiting for the first author to use the shape the
	driver already supports. Anything else (the driver's own _fail case) names
	nothing."""
	if isinstance(spec, str):
		return [spec] if spec else []
	if isinstance(spec, list):
		return [e["fixture"] for e in spec
			if isinstance(e, dict) and isinstance(e.get("fixture"), str) and e["fixture"]]
	return []


def _collect_installed_fixtures(node, out: set) -> None:
	"""#417: a mid-script `install_fixture` action swaps a DIFFERENT fixture
	into a save slot and loads it -- that fixture is every bit as real a
	dependency as `fixture_save`/`legacy_seed`, but it used to be invisible
	here, so `--touching qa/fixtures/<it>.json` selected NOTHING (a false-safe:
	briar_arch_locked installs near_briar_arch_cut in PHASE 2 while its row
	named only near_briar_arch_locked). Recurses through the step tree it is
	handed (the call site passes `script["steps"]`) rather than scanning only
	its top level, so a step nested inside any future container shape is
	covered by construction; "_comment" is skipped at every level exactly as
	in _collect_signals, so prose naming a fixture can never leak a tag."""
	if isinstance(node, dict):
		if node.get("action") == "install_fixture":
			fixture = node.get("fixture")
			if isinstance(fixture, str) and fixture:
				out.add(fixture)
		for k, v in node.items():
			if k == "_comment":
				continue
			_collect_installed_fixtures(v, out)
	elif isinstance(node, list):
		for item in node:
			_collect_installed_fixtures(item, out)


def derive_surfaces_for(entry: dict, known_maps: set, known_skills: set,
		skill_contexts: dict, known_dialogue: set) -> dict:
	script_name = entry["script"]
	script_path = os.path.join(SCRIPTS_DIR, f"{script_name}.json")
	if not os.path.isfile(script_path):
		raise FileNotFoundError(f"no such QA script: {script_path}")
	script = _load(script_path)

	keys: set = set()
	values: set = set()
	path_equals: list = []
	_collect_signals(script.get("steps", []), keys, values, path_equals)
	signals = keys | values

	# #111: `legacy_seed` (a pre-rename user-dir fixture placed by run_qa.sh)
	# is a real fixture dependency, same as fixture_save.
	seed_fixtures = _fixture_save_names(script.get("fixture_save"))
	if not seed_fixtures:
		fallback = script.get("legacy_seed") or entry.get("fixture")
		if isinstance(fallback, str) and fallback:
			seed_fixtures = [fallback]
	maps = {v for v in values if v in known_maps}
	skills = {v for v in values if v in known_skills}
	dialogue = {v for v in values if v in known_dialogue}
	fixtures: set = set(seed_fixtures)
	# #417: mid-script install_fixture swaps count as fixture dependencies too.
	_collect_installed_fixtures(script.get("steps", []), fixtures)

	for fixture_name in sorted(fixtures):
		fixture_path = os.path.join(FIXTURES_DIR, f"{fixture_name}.json")
		if os.path.isfile(fixture_path):
			state = _load(fixture_path).get("state", {})
			cur_map = state.get("current_map")
			if isinstance(cur_map, str) and cur_map in known_maps:
				maps.add(cur_map)
			for s in state.get("player_skills", []) or []:
				if s in known_skills:
					skills.add(s)

	systems: set = set()
	for system, markers in SYSTEM_MARKERS.items():
		if signals & markers:
			systems.add(system)
	for system, prefixes in SYSTEM_PREFIX_MARKERS.items():
		for token in signals:
			if any(token.startswith(p) for p in prefixes):
				systems.add(system)
				break
	if any(ATTUNED_RE.match(v) for v in values):
		systems.add("portals")
	for skill_id in skills:
		for ctx in skill_contexts.get(skill_id, []):
			if ctx in CONTEXT_TO_SYSTEM:
				systems.add(CONTEXT_TO_SYSTEM[ctx])

	return {
		"maps": sorted(maps),
		"fixtures": sorted(fixtures),  # #417: seeded + mid-script install_fixture
		"skills": sorted(skills),
		"dialogue": sorted(dialogue),
		"systems": sorted(systems),
	}


def derive_all() -> dict:
	manifest = _load(MANIFEST_PATH)
	known_maps = _known_maps()
	known_skills, skill_contexts = _known_skills()
	known_dialogue = _known_dialogue_ids()
	result = {}
	for entry in manifest["scripts"]:
		result[entry["script"]] = derive_surfaces_for(
			entry, known_maps, known_skills, skill_contexts, known_dialogue)
	return result


def fixture_field_disagreements() -> list[tuple[str, str, str]]:
	"""#396 close-wave ruling (from the Lane D review): a manifest row's own
	`fixture` field and its script's `fixture_save` are two hand-maintained
	copies of ONE fact, and derive_surfaces_for prefers the script's -- so a
	stale row survives every green drift check. That is exactly what happened
	at thicket_keeps_talk, whose row still named thicket_talk_start after the
	script had moved to thicket_legacy_start. Rule: when BOTH are present they
	must MATCH. One side absent stays legal (a script may carry fixture_save
	with no row field, and a row may name the fixture for a script that seeds
	via `legacy_seed`), so this only ever fires on a real contradiction. Array-
	form `fixture_save` (test_driver.gd:148-153) seeds several fixtures at once,
	so the row agrees when it names ANY of them; for the string form that is
	byte-identically the old `own != row` test."""
	manifest = _load(MANIFEST_PATH)
	out: list[tuple[str, str, str]] = []
	for entry in manifest["scripts"]:
		name = entry["script"]
		row = entry.get("fixture")
		script_path = os.path.join(SCRIPTS_DIR, f"{name}.json")
		if not row or not os.path.isfile(script_path):
			continue
		own = _fixture_save_names(_load(script_path).get("fixture_save"))
		if own and row not in own:
			out.append((name, str(row), ", ".join(own)))
	return out


def cmd_write() -> int:
	for name, row, own in fixture_field_disagreements():
		print(f"derive_qa_surfaces: WARNING -- {name}: manifest row fixture "
			f"'{row}' contradicts the script's fixture_save '{own}'; the "
			"derivation uses the script's. Fix one of them -- --check is FATAL "
			"on this.", file=sys.stderr)
	surfaces_by_script = derive_all()
	manifest = _load(MANIFEST_PATH)
	for entry in manifest["scripts"]:
		entry["surfaces"] = surfaces_by_script[entry["script"]]
	with open(MANIFEST_PATH, "w") as f:
		json.dump(manifest, f, indent=1)
		f.write("\n")
	total_maps = sum(len(s["maps"]) for s in surfaces_by_script.values())
	total_skills = sum(len(s["skills"]) for s in surfaces_by_script.values())
	print(f"derive_qa_surfaces: wrote surfaces for {len(surfaces_by_script)} script(s) "
		f"({total_maps} map refs, {total_skills} skill refs total)")
	return 0


def cmd_check() -> int:
	fresh = derive_all()
	manifest = _load(MANIFEST_PATH)
	disagreements = fixture_field_disagreements()
	if disagreements:
		print("derive_qa_surfaces: FATAL -- manifest row `fixture` contradicts the "
			"script's own `fixture_save` (both present must match; the derivation "
			"silently prefers the script's, so this hides a stale row):", file=sys.stderr)
		for name, row, own in disagreements:
			print(f"  {name}: manifest row '{row}' vs script fixture_save '{own}'", file=sys.stderr)
		print("  fix: correct whichever field is stale, then re-run "
			"scripts/derive_qa_surfaces.py.", file=sys.stderr)
		return 1
	drift = []
	for entry in manifest["scripts"]:
		name = entry["script"]
		committed = entry.get("surfaces")
		if committed != fresh.get(name):
			drift.append((name, committed, fresh.get(name)))
	if not drift:
		print(f"derive_qa_surfaces: --check OK, {len(manifest['scripts'])} script(s) match freshly-derived surfaces.")
		return 0
	print("derive_qa_surfaces: FATAL -- surfaces DRIFTED from a fresh derivation "
		"(stale/hand-edited tags, or the script/fixture/data files changed underneath them):", file=sys.stderr)
	for name, committed, fresh_val in drift:
		print(f"  {name}:", file=sys.stderr)
		print(f"    committed: {json.dumps(committed)}", file=sys.stderr)
		print(f"    fresh:     {json.dumps(fresh_val)}", file=sys.stderr)
	print("  fix: python3 scripts/derive_qa_surfaces.py (from wandering_inn_game/), then commit.", file=sys.stderr)
	return 1


# GH#281: monolithic data catalogs used to fall through every branch below
# and print NOTHING (exit 0) -- a silent-empty false-safe for lane re-gates.
# Each one now maps to the manifest "systems" tag(s) its consumers carry
# (qa/manifest.json surfaces are derived, so the tag set is trustworthy).
# classes.json/progression.json instead join skills.json's conservative
# all-skill-tags fallback below (classes/progression are skill-grant and
# leveling carriers -- a changed line can't be attributed narrower from the
# path alone). Anything STILL unmapped warns loudly on stderr.
MONOLITH_SYSTEMS: dict[str, set[str]] = {
	"portals.json": {"portals"},
	"quests.json": {"quests"},
	"acts.json": {"quests"},
	"leads.json": {"quests"},
	"bounties.json": {"boards"},
	"deliveries.json": {"boards"},
	"combatants.json": {"combat"},
	"arenas.json": {"combat"},
	"audio.json": {"audio"},
	"items.json": {"economy"},
	"fence_stock.json": {"economy"},
	# #348: the property table resolves inside field-skill dispatch, so a row
	# or vocabulary edit crosses every canonical that casts in the field.
	"interactions.json": {"exploration"},
}
ALL_SKILLS_FALLBACK = ("skills.json", "classes.json", "progression.json")


def cmd_touching(paths_arg: str) -> int:
	"""Maps a comma-separated list of changed paths to surface tags, then
	to the canonical scripts whose OWN surfaces intersect those tags.
	A script whose filename IS one of the touched paths is always
	included (editing a QA script trivially "touches" itself).
	NEVER SILENT (GH#281): an input path yielding zero mappings warns on
	stderr, and an empty final crossing set gets an explicit NOTE --
	callers must not read empty output as "no re-gate needed"."""
	surfaces_by_script = derive_all()
	touched_tags: set = set()
	touched_script_names: set = set()
	known_maps = _known_maps()
	known_skills, _ = _known_skills()
	known_dialogue = _known_dialogue_ids()

	all_scripts = False
	unmapped: list = []
	for raw in paths_arg.split(","):
		p = raw.strip()
		if not p:
			continue
		base = os.path.basename(p)
		stem, ext = os.path.splitext(base)
		norm = p.replace("\\", "/")
		if "/qa/scripts/" in norm or norm.startswith("qa/scripts/"):
			touched_script_names.add(stem)
			continue
		if "/qa/fixtures/" in norm or norm.startswith("qa/fixtures/"):
			# Validate like the dialogue/maps branches (review GH#281): a
			# typo'd/deleted fixture must warn, not vanish into the tag set.
			if os.path.isfile(os.path.join(FIXTURES_DIR, f"{stem}.json")):
				touched_tags.add(("fixtures", stem))
			else:
				unmapped.append(p)
			continue
		if "/data/dialogue/" in norm or norm.startswith("data/dialogue/"):
			if stem in known_dialogue:
				touched_tags.add(("dialogue", stem))
			else:
				unmapped.append(p)
			continue
		# data/maps/<region>/<map>.json (issue #100 split layout): the map
		# key is the file STEM -- the region dir level is organizational
		# only (WISceneCatalog.compose() / generate_postings.py load_scene()
		# both key by stem across the sorted */*.json glob).
		if "/data/maps/" in norm or norm.startswith("data/maps/"):
			if stem in known_maps:
				touched_tags.add(("maps", stem))
			else:
				unmapped.append(p)
			continue
		# data/scene_root.json (start_map + the player template): consumed
		# at EVERY world boot, before any map composes on top -- there is no
		# narrower honest mapping than "every canonical" (even load_gate
		# loads it as a resource). DECISION: scene_root.json crosses ALL
		# scripts, i.e. --touching it = the full sweep, stated loudly.
		# Same treatment for a stale reference to the deleted pre-split
		# monolith (its diff-deletion "touched" everything too).
		if base in ("scene_root.json", "skeleton_scene.json"):
			all_scripts = True
			print(f"derive_qa_surfaces: NOTE -- {base} affects every world boot; "
				"crossing = ALL canonical scripts (full sweep).", file=sys.stderr)
			continue
		matched = False
		if stem in known_maps:
			touched_tags.add(("maps", stem))
			matched = True
		if stem in known_skills:
			touched_tags.add(("skills", stem))
			matched = True
		# Monolithic catalogs (GH#281): route to the systems tag(s) their
		# consumers carry -- e.g. portals.json crosses every script whose
		# derived surfaces include the "portals" system.
		if base in MONOLITH_SYSTEMS:
			touched_tags.update(("systems", tag) for tag in MONOLITH_SYSTEMS[base])
			matched = True
		# Whole-catalog skill carriers (skills.json, classes.json,
		# progression.json): conservative fallback -- touch EVERY skill
		# surface tag that exists across the whole manifest, since the
		# changed line inside a monolithic file can't be attributed to one
		# skill from the path.
		if base in ALL_SKILLS_FALLBACK:
			for s in surfaces_by_script.values():
				touched_tags.update(("skills", sk) for sk in s["skills"])
			matched = True
		if not matched:
			unmapped.append(p)

	if unmapped:
		for p in unmapped:
			print(f"derive_qa_surfaces: WARNING -- no surface mapping for '{p}'; "
				"its crossing scripts are NOT derived here. src/** and unmapped "
				"data files need `--tier smoke` minimum plus hand-picked "
				"canonicals (see wi-verifying-changes).", file=sys.stderr)

	if all_scripts:
		for name in sorted(surfaces_by_script):
			print(name)
		return 0

	crossing = set(touched_script_names)
	for name, surf in surfaces_by_script.items():
		for category, tag in touched_tags:
			if tag in surf.get(category, []):
				crossing.add(name)
				break

	if not crossing:
		print("derive_qa_surfaces: NOTE -- zero crossing scripts derived; do NOT "
			"read this as 'no re-gate needed' (GH#281).", file=sys.stderr)
	for name in sorted(crossing):
		print(name)
	return 0


def main(argv: list[str]) -> int:
	if not argv:
		return cmd_write()
	if argv[0] == "--check":
		return cmd_check()
	if argv[0] == "--touching":
		if len(argv) < 2:
			print("usage: derive_qa_surfaces.py --touching <path>[,<path>...]", file=sys.stderr)
			return 2
		return cmd_touching(argv[1])
	print(f"derive_qa_surfaces.py: unknown argument '{argv[0]}'", file=sys.stderr)
	return 2


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
