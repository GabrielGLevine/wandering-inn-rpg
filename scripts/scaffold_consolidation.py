#!/usr/bin/env python3
"""scaffold_consolidation.py -- propose (never ship) the full artifact set for a
new consolidation class, #452 layer 3.

It answers the question #449 answered by hand: a lineage pair is reachable and
has no authored target (data_lint's `check_lineage_completeness` reds, or an
`_exempt` row is standing in for a ruling), so what does the [Spellsword] ->
[Spellspear] pattern say every one of its artifacts must look like?

THE TOOL PROPOSES, THE HUMAN AUTHORS THE FLAVOR. Everything mechanical is
DERIVED from data already in the repo -- the merge floor from
`WIProgression._consolidation_merged_level`, the level table and stat_growth
from the baseline class the pair currently falls through to, the twin skills'
costs/effects from that baseline's own grants, the fixture's counters from the
held classes' own `requires` curves. Everything nameable is a loud TODO: class
display name, skill names, prose, icon art. Those are the human gates the #452
plan preserves (canon names off the wiki + spoiler bar, distinct icon
silhouettes, no-treadmill review, balance-window ratification).

NOTHING LANDS IN data/. Output is stdout JSON by default, or a staging tree
under --out; writing into the game's data/ or qa/ trees is refused outright.

Usage:
  scripts/scaffold_consolidation.py --parents spearmaster,mage --target spellspear
  scripts/scaffold_consolidation.py --parents rogue,archer --target scout --issue 452 --out scaffold/
  scripts/scaffold_consolidation.py --parents spearmaster,mage --target spellspear --checklist
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "wandering_inn_game"
DATA = GAME / "data"

# The one fixture-format constant with a reason attached. `WISave._migrated`'s
# `version == 4` arm OVERWRITES `inventory` and `equipped` with the rusty_sword
# starter defaults, so a fixture authored below 5 cannot carry a chosen weapon
# at all -- and `WICombatBuild.weapon_gated_kit` then strips every
# weapon-gated grant the canonical exists to prove. #449 shipped a v3 fixture
# first and lost its whole spear kit to exactly this.
FIXTURE_VERSION = 5

# `test_fixture_coherence.gd::_check_post_tutorial`: any fixture holding
# classes is post-tutorial, and the tutorial that grants classes cannot have
# run without met_relc.
POST_TUTORIAL_COUNTERS = {"met_relc": 1}

FIXTURE_MAP = "inn"
FIXTURE_CELL = [2, 3]
FIXTURE_FACING = [1, 0]
FIXTURE_SKILLS = ["basic_cleaning", "frost_bolt"]
ICON_FRAME = [16, 16]

TODO_NAME = "TODO_NAME_ME"
TODO_PROSE = "TODO: canon prose, never a stat readout (wiki-verified, Book 17 spoiler bar)."
TODO_RNG = "TODO_DERIVE_VIA_tests/_derive_rng_state.gd"


def merged_level(level_a: int, level_b: int) -> int:
	"""MIRROR of `WIProgression._consolidation_merged_level`
	(src/core/progression.gd:245-248). Integer math only; the `+ 2` is the
	integer ceil of 2*sum/3. Drift here silently mis-floors every scaffolded
	level table, which is why the golden test pins it against shipped data."""
	total = level_a + level_b
	two_thirds = (2 * total + 2) // 3
	return max(two_thirds, max(level_a, level_b))


def cheapest_legal_pair(min_parent_level: int, min_combined_level: int) -> tuple[int, int]:
	"""MIRROR of `test_content.gd::_validate_class_level_tables`'s floor
	derivation: the cheapest pair the gate admits, split as evenly as the
	integer sum allows. The class table's lowest authored entry must be
	EXACTLY this pair's merged level (GH#54 sparse-table convention)."""
	s_min = max(min_combined_level, 2 * min_parent_level)
	level_a = s_min // 2
	return level_a, s_min - level_a


def consolidation_floor(min_parent_level: int, min_combined_level: int) -> int:
	return merged_level(*cheapest_legal_pair(min_parent_level, min_combined_level))


def lineage_members(seed_ids: list, classes_by_id: dict) -> list:
	"""MIRROR of `data_lint._lineage_members`: a parent line is its base id
	plus the evolution closure of that id, in canon (declaration) order."""
	out: list[str] = []
	pending = list(seed_ids)
	while pending:
		class_id = pending.pop(0)
		if not isinstance(class_id, str) or not class_id or class_id in out:
			continue
		out.append(class_id)
		targets = (classes_by_id.get(class_id, {}).get("evolution", {}) or {}).get("targets", {})
		if isinstance(targets, dict):
			pending.extend(targets.values())
	return out


def load_catalogs(root: Path = ROOT) -> dict:
	data = root / "wandering_inn_game" / "data"
	return {
		"classes": json.loads((data / "classes.json").read_text()),
		"skills": json.loads((data / "skills.json").read_text()),
		"items": json.loads((data / "items.json").read_text()),
	}


def _rules(classes_doc: dict) -> list:
	return [row for row in classes_doc.get("consolidations", [])
		if isinstance(row, dict) and "_exempt" not in row]


def find_baseline(parents: tuple, target: str, classes_doc: dict) -> dict:
	"""The class the pair falls through to TODAY -- the mechanical baseline the
	twin is derived from. `check_consolidation` returns the FIRST matching row,
	so this is that row, with the target's own row skipped (the scaffolder must
	give the same answer before and after its proposal lands, which is what
	makes the #449 golden test runnable against post-#469 main)."""
	classes_by_id = {row["id"]: row for row in classes_doc.get("classes", []) if "id" in row}
	for row in _rules(classes_doc):
		if str(row.get("target", "")) == target:
			continue
		lines = row.get("parent_lines", [])
		if not (isinstance(lines, list) and len(lines) == 2):
			continue
		members = [lineage_members(line, classes_by_id) for line in lines]
		for a, b in ((0, 1), (1, 0)):
			if parents[0] in members[a] and parents[1] in members[b]:
				return row
	raise SystemExit(
		f"scaffold_consolidation: no existing consolidation rule reaches "
		f"'{parents[0]}' x '{parents[1]}' -- this pair is not lineage-reachable, so there is "
		"no mechanical baseline to derive from. Pass --baseline <target> to name one deliberately.")


def _line_weapon(class_row: dict, skills_by_id: dict) -> str:
	"""The lineage's weapon gate, read off the skills the class itself grants
	(spearmaster grants four `weapon: spear` skills). Only used to RE-GATE a
	baseline twin that already carried a `weapon` key -- never to mint a gate
	where the baseline had none (that would be a mechanical divergence dressed
	as flavor, and `weapon_gated_kit` would strip the class's own marquee grant
	from a holder who switched weapons)."""
	tally: dict[str, int] = {}
	for lvl in class_row.get("levels", []):
		for grant in lvl.get("grants", []):
			weapon = skills_by_id.get(grant, {}).get("weapon")
			if isinstance(weapon, str) and weapon:
				tally[weapon] = tally.get(weapon, 0) + 1
	if not tally:
		return ""
	return max(sorted(tally), key=lambda w: tally[w])


def _best_weapon_item(family: str, items_doc: dict) -> str:
	best = ""
	best_mod = -(10 ** 6)
	for item in items_doc.get("items", []):
		if item.get("kind") != "weapon" or item.get("weapon_family") != family:
			continue
		mod = int(item.get("damage_mod", 0))
		if mod > best_mod:
			best, best_mod = str(item.get("id", "")), mod
	return best


def _own_grants(class_row: dict) -> list:
	out = []
	for lvl in class_row.get("levels", []):
		for grant in lvl.get("grants", []):
			out.append((int(lvl["level"]), str(grant)))
	return out


def _inherit_chain(class_id: str, classes_by_id: dict) -> list:
	"""class id + every ancestor via `inherits` (a class's own `requires`
	curve does not stand alone: spearmaster 11 is a player who walked warrior's
	melee_hit curve to get there)."""
	out: list[str] = []
	pending = [class_id]
	while pending:
		cid = pending.pop(0)
		if cid in out or cid not in classes_by_id:
			continue
		out.append(cid)
		raw = classes_by_id[cid].get("inherits", [])
		pending.extend([raw] if isinstance(raw, str) else list(raw or []))
	return out


def derive_fixture_counters(held: dict, classes_by_id: dict) -> dict:
	"""MIRROR of `test_fixture_coherence.gd::_check_class_requirements`, widened
	along `inherits`: every held class's gained_by counters, plus the highest
	`requires` threshold each counter reaches at or below the held level, for
	the class AND its ancestors."""
	counters: dict[str, int] = dict(POST_TUTORIAL_COUNTERS)

	def bump(key: str, value: int) -> None:
		counters[key] = max(counters.get(key, 0), int(value))

	for class_id, level in held.items():
		for cid in _inherit_chain(class_id, classes_by_id):
			row = classes_by_id[cid]
			for acc_id, need in (row.get("gained_by", {}) or {}).get("accomplishment", {}).items():
				bump(acc_id, need)
			for lvl in row.get("levels", []):
				if int(lvl.get("level", 0)) > int(level):
					continue
				for counter, need in (lvl.get("requires", {}) or {}).items():
					bump(counter, need)
	return dict(sorted(counters.items()))


def build_proposal(parents: tuple, target: str, catalogs: dict, *,
		baseline_id: str = "", issue: int = 452, allow_existing: bool = False) -> dict:
	classes_doc = catalogs["classes"]
	classes_by_id = {row["id"]: row for row in classes_doc.get("classes", []) if "id" in row}
	skills_by_id = {row["id"]: row for row in catalogs["skills"].get("skills", []) if "id" in row}

	for parent in parents:
		if parent not in classes_by_id:
			raise SystemExit(f"scaffold_consolidation: '{parent}' has no classes.json row")
	# `allow_existing` has exactly ONE legitimate caller: the golden test, which
	# re-derives a SHIPPED target from scratch to prove the tool still emits the
	# ruled pattern. Everyday use scaffolds NEW targets, and quietly re-emitting
	# over a shipped class is how a scaffold would overwrite authored flavor.
	if target in classes_by_id and not allow_existing:
		raise SystemExit(
			f"scaffold_consolidation: '{target}' already has a classes.json row -- this tool "
			"scaffolds NEW consolidation targets; edit the shipped row directly instead "
			"(--allow-existing re-derives a shipped target, for the golden test).")

	if baseline_id:
		rule = next((r for r in _rules(classes_doc) if str(r.get("target", "")) == baseline_id), None)
		if rule is None:
			raise SystemExit(f"scaffold_consolidation: no consolidation rule targets '{baseline_id}'")
	else:
		rule = find_baseline(parents, target, classes_doc)
	baseline = str(rule["target"])
	baseline_row = classes_by_id[baseline]

	min_parent = int(rule.get("min_parent_level", 0))
	min_combined = int(rule.get("min_combined_level", 0))
	pair = cheapest_legal_pair(min_parent, min_combined)
	floor = merged_level(*pair)
	ref = f"#{issue}"

	# #472: a live row may list ONLY pairs whose no-Skill-loss is PROVEN, and the
	# target `inherits` exactly this pair -- so the row is exactly this pair, not
	# the parents' evolution closures. The closure ids are NOT lost: lineage
	# completeness keeps enumerating them as pairs needing their own targets.
	parent_lines = [[p] for p in parents]
	consolidation_row = {
		"_comment": (
			f"SCAFFOLD ({ref}, scripts/scaffold_consolidation.py). Gate shape copied VERBATIM from "
			f"[{baseline_row.get('display_name', baseline)}]'s row (min_parent_level {min_parent}, "
			f"min_combined_level {min_combined}) -- new consolidations follow the SAME gate, never a "
			"bespoke one. ORDER IS LOAD-BEARING: `WIProgression.check_consolidation` returns the FIRST "
			f"matching row, so if the '{baseline}' row can also reach '{parents[0]}' x "
			f"'{parents[1]}' THIS ROW MUST BE PLACED ABOVE IT or the target is unreachable. Pin that "
			"with an assertion in tests/test_progression.gd -- a comment does not gate a reorder. "
			"#472: parent_lines list EXACTLY this pair, because consolidation is automatic and a live "
			"row may only fire pairs the target demonstrably covers (data_lint's coverage arm hard-reds "
			"any other); the evolved siblings wait for their own targets."),
		"id": target,
		"target": target,
		"parent_lines": parent_lines,
		"min_parent_level": min_parent,
		"min_combined_level": min_combined,
	}

	baseline_grants = _own_grants(baseline_row)
	twin_ids = {gid: f"todo_twin__{gid}" for _lvl, gid in baseline_grants}
	twin_weapon = _line_weapon(classes_by_id[parents[0]], skills_by_id)

	levels = []
	for lvl in baseline_row.get("levels", []):
		row = {k: (dict(v) if isinstance(v, dict) else v) for k, v in lvl.items() if k != "grants"}
		row["grants"] = [twin_ids[g] for g in lvl.get("grants", [])]
		levels.append(row)

	class_row = {
		"_comment": (
			f"SCAFFOLD ({ref}). SPARSE TABLE (GH#54): consolidation-only, so `accept_consolidation` "
			f"writes the merged level in directly and the table starts AT its floor. Floor = {floor}, "
			"DERIVED (never hardcoded elsewhere) from `WIProgression._consolidation_merged_level` over "
			f"this class's own consolidations row: the cheapest legal pair under min_parent_level "
			f"{min_parent} + min_combined_level {min_combined} is {pair}, and "
			f"max(ceil(2*{sum(pair)}/3), max{pair}) == {floor} -- test_content.gd's "
			"`_validate_class_level_tables` re-derives exactly that from the SAME data. `stat_growth` "
			f"and the whole requires curve are [{baseline_row.get('display_name', baseline)}]'s "
			"VERBATIM: the baseline is the mechanical anchor and only the grants re-flavor, so the two "
			"lineages cost the same. TODO: replace display_name + the todo_twin__ grant ids."),
		"id": target,
		"display_name": TODO_NAME,
		"stat_growth": dict(baseline_row.get("stat_growth", {})),
		"inherits": list(parents),
		"levels": levels,
	}

	twins = []
	for _lvl, gid in baseline_grants:
		src = skills_by_id.get(gid, {})
		twin_id = twin_ids[gid]
		twin = {k: (json.loads(json.dumps(v))) for k, v in src.items() if k != "_comment"}
		twin["id"] = twin_id
		twin["display_name"] = f"[{TODO_NAME}]"
		twin["description"] = TODO_PROSE
		if "icon" in twin:
			twin["icon"] = f"icon_{twin_id}"
		if "weapon" in twin:
			twin["weapon"] = twin_weapon or TODO_NAME
		twin = {"_comment": (
			f"SCAFFOLD ({ref}). The flavored TWIN of [{src.get('display_name', gid)}] ({gid}). "
			"ap_cost/mp_cost/effect/cooldown_rounds are that skill's VERBATIM -- the baseline is the "
			"mechanical anchor, and a 'small' tuning difference here is a balance change wearing "
			"flavor's clothes. " + (
				f"`weapon` is the ONE mirrored mechanical field: the gate IS the lineage "
				f"({src.get('weapon')} -> {twin.get('weapon')})."
				if "weapon" in twin else
				"DELIBERATELY UNGATED, exactly like its baseline: no `weapon` key there means no "
				"`weapon` key here -- minting one would let `WICombatBuild.weapon_gated_kit` strip "
				"the class's own marquee grant from a holder who changed weapons."
			) + " TODO: display_name (canon, wiki-verified) + description prose."), **twin}
		twins.append(twin)

	icon_slots = {}
	for twin in twins:
		icon = twin.get("icon")
		if not icon:
			continue
		icon_slots[icon] = {
			"_comment": (
				f"SCAFFOLD ({ref}). TODO: a NEW code-drawn shape in tools/sync_assets.py::"
				"_draw_placeholder, never a recolour of the baseline twin's glyph -- tint is not "
				"disambiguation (user directive 2026-08-02), shade variants never read as separate "
				"things. PixelLab pass is user-gated; VISUAL-LOG carries the drain row."),
			"animations": {"idle": {
				"sheet": f"res://assets/ui/icons/{icon}.png",
				"frame_size": list(ICON_FRAME),
				"fps": 1,
			}},
		}

	held = {parents[0]: pair[1], parents[1]: pair[0]}
	weapon_family = twin_weapon
	weapon_item = _best_weapon_item(weapon_family, catalogs["items"]) if weapon_family else ""
	fixture_name = f"near_{target}_consolidation"
	fixture = {
		"_comment": (
			f"SCAFFOLD ({ref}). Standing AT the offer threshold, one sleep away. "
			f"{parents[0]} {pair[1]} + {parents[1]} {pair[0]} is the CHEAPEST legal pair -- "
			f"min_parent_level {min_parent} gates both, min_combined_level {min_combined} rules out "
			f"the even split below it, and max(ceil(2*{sum(pair)}/3), max{pair}) == {floor} is the "
			"sparse table's derived floor. Counters are DERIVED from the held classes' own gained_by + "
			"`requires` curves along `inherits` (test_fixture_coherence.gd::_check_class_requirements). "
			f"VERSION {FIXTURE_VERSION}, NOT lower: `WISave._migrated`'s version==4 arm OVERWRITES "
			"`inventory`/`equipped` with the rusty_sword starter defaults, so a lower fixture cannot "
			"carry a chosen weapon and `weapon_gated_kit` then hides every weapon-gated grant this "
			"fixture exists to prove. TODO: derive rng_state; add the chosen weapon's in-world "
			"provenance counter (an equipped item a player never received is not a story position)."),
		"state": {
			"accomplishments": derive_fixture_counters(held, classes_by_id),
			"actions_since_sleep": 0,
			"classes": held,
			"container_state": {},
			"current_map": FIXTURE_MAP,
			"dormant_encounters": [],
			"equipped": {"weapon": weapon_item, "armor": ""},
			"generalist_classes": [],
			"inventory": [weapon_item] if weapon_item else [],
			"player_cell": list(FIXTURE_CELL),
			"player_facing": list(FIXTURE_FACING),
			"player_skills": list(FIXTURE_SKILLS),
			"removed_entities": [],
			"rng_state": TODO_RNG,
			"started_quests": [],
			"used_skills": [],
		},
		"version": FIXTURE_VERSION,
	}

	inherited = []
	for parent in parents:
		reachable = [gid for lvl, gid in _own_grants(classes_by_id[parent]) if lvl <= floor]
		if reachable:
			inherited.append(reachable[-1])
	# One INHERITED grant per parent line (the highest rung the floor reaches,
	# arriving via `inherits`) with the consolidation's OWN grant between them:
	# the kit assert has to prove all three fold, which is the M6 F1 bug's shape.
	kit = inherited[:1] + ([twins[0]["id"]] if twins else []) + inherited[1:]

	script_name = f"{target}_consolidation_loop"
	qa_script = {
		"_comment": (
			f"SCAFFOLD ({ref}). The consolidation, end to end -- modelled on "
			"qa/scripts/spellspear_consolidation_loop.json, the #449 canonical. THE ROW IT REALLY "
			"GATES is the ORDER of classes.json's `consolidations[]`: `check_consolidation` is "
			f"first-match and [{baseline_row.get('display_name', baseline)}]'s lines still reach this "
			"pair, so if this rule ever sinks below it the script reds on `target` instead of silently "
			"handing the player the wrong class. Consolidation is AUTOMATIC (#472): the merge applies "
			"INSIDE the sleep beat, strictly before the veil renders, and there is no prompt to answer. "
			"The OPAQUE-UNTIL-SLEEP lock is PROVED before the bed (no consolidation event on a freshly "
			"loaded save at the threshold), not asserted in prose. The closing fight is the kit proof: an INHERITED "
			"lineage grant and the consolidation's OWN new grant, both fielded. TODO: replace the "
			"fight beat below with an act-appropriate encounter for this lineage, and re-derive the "
			"screenshot names."),
		"fixture_save": fixture_name,
		"starts_at_title": True,
		"steps": [
			{"action": "wait_for_event", "type": "ui_title_gate_rendered", "timeout_sec": 5},
			{"action": "press", "name": "confirm"},
			{"action": "wait_for_event", "type": "ui_title_rendered", "timeout_sec": 5},
			{"action": "move", "direction": "down", "steps": 1},
			{"action": "press", "name": "confirm"},
			{"action": "wait_for_event", "type": "game_loaded", "timeout_sec": 5},
			{"action": "wait_for_event", "type": "world_ready", "timeout_sec": 5},
			{"action": "assert_state", "path": "current_map", "equals": FIXTURE_MAP},
			{"action": "assert_state", "path": "classes", "equals": dict(held)},
			{"action": "assert_event_absent", "type": "consolidation_accepted"},
			{"action": "teleport", "map": "inn_upstairs", "cell": [9, 2]},
			{"action": "move", "direction": "up", "steps": 1},
			{"action": "press", "name": "interact"},
			{"action": "wait_for_event", "type": "consolidation_accepted",
				"payload_contains": {"target": target, "level": floor}, "timeout_sec": 5},
			{"action": "assert_event_absent", "type": "consolidation_offered"},
			{"action": "wait_for_event", "type": "ui_sleep_veil_rendered",
				"payload_contains": {"lines": 1}, "timeout_sec": 5},
			{"action": "wait_for_event", "type": "ui_sleep_veil_finished", "timeout_sec": 5},
			{"action": "screenshot", "name": f"01_{target}_merge_veil"},
			{"_comment": "wi_game.gd's _apply_consolidation composes this from the three display names -- it reds the "
				"moment the TODO_NAME_ME placeholders are replaced, which is the point.",
				"action": "wait_for_event", "type": "ui_toast_rendered",
				"payload_contains": {"text": "[%s] and [%s] merge into [%s]!" % (
					classes_by_id[parents[0]].get("display_name", parents[0]),
					classes_by_id[parents[1]].get("display_name", parents[1]),
					TODO_NAME)}, "timeout_sec": 5},
			{"action": "assert_state", "path": "classes", "equals": {target: floor}},
			{"action": "screenshot", "name": f"02_merged_{target}"},
			{"_comment": "TODO: an act-appropriate fight for this lineage. The asserts below are the "
				"contract; the walk to them is content.",
				"action": "wait_for_event", "type": "turn_started",
				"payload_contains": {"id": "pc"}, "timeout_sec": 10},
			{"action": "assert_state", "path": "combat.combatants.pc.skills", "contains": kit},
			{"action": "screenshot", "name": f"03_{target}_kit_combat"},
			{"action": "combat_autoplay", "max_turns": 300},
			{"action": "wait_for_event", "type": "combat_finished",
				"payload_contains": {"victory": True}, "timeout_sec": 10},
			{"action": "press", "name": "confirm"},
			{"action": "wait_for_event", "type": "ui_combat_hidden", "timeout_sec": 5},
		],
	}

	manifest_row = {
		"_comment": (
			f"SCAFFOLD ({ref}). Its real subject is the order of classes.json `consolidations[]`: "
			"check_consolidation is first-match, so this row reds if the rule ever sinks below its "
			"baseline. NO `surfaces` BLOCK HERE ON PURPOSE -- surfaces are DERIVED; run "
			"scripts/derive_qa_surfaces.py then scripts/render_qa_notes.py --write, in that order."),
		"script": script_name,
		"seed": issue,
		"fixture": fixture_name,
		"note": f"{parents[0]}+{parents[1]} -> [{TODO_NAME}] {floor}, inherited + own grants fielded",
		"tiers": ["full"],
	}

	checklist = _checklist(target, parents, baseline, floor, twins, fixture_name,
		script_name, consolidation_row, classes_by_id, catalogs)

	return {
		"target": target,
		"parents": list(parents),
		"baseline": baseline,
		"gate": {"min_parent_level": min_parent, "min_combined_level": min_combined},
		"cheapest_legal_pair": list(pair),
		"floor": floor,
		"consolidation_row": consolidation_row,
		"class_row": class_row,
		"skill_twins": twins,
		"icon_slots": icon_slots,
		"fixture_name": fixture_name,
		"fixture": fixture,
		"qa_script_name": script_name,
		"qa_script": qa_script,
		"manifest_row": manifest_row,
		"checklist": checklist,
	}


def _checklist(target, parents, baseline, floor, twins, fixture_name, script_name,
		consolidation_row, classes_by_id, catalogs) -> list:
	"""THE REGISTRATION MATRIX (wi-adding-a-class-or-skill), instantiated for
	this proposal. Every line names the real pin, because each was discovered
	the expensive way -- serially, one failed boot at a time."""
	twin_ids = [t["id"] for t in twins]
	line_maxes = [max((int(l["level"]) for l in classes_by_id[p].get("levels", [])), default=0)
		for p in parents]
	ceiling = merged_level(line_maxes[0], line_maxes[1])
	table_max = max(int(l["level"]) for l in classes_by_id[baseline]["levels"])
	verdict = ("the table HOLDS it" if table_max >= ceiling
		else f"TOO SHORT -- extend the table to at least {ceiling}")
	return [
		f"ORDER: place the `{target}` consolidations[] row ABOVE `{baseline}` "
		"(check_consolidation is first-match) AND pin the order with an assertion in "
		"tests/test_progression.gd -- both directions (the new pair reaches the new target; the "
		"baseline's own unevolved pair still reaches the baseline).",
		f"data_lint: drop any `_exempt` row for {parents[0]} x {parents[1]} in the same commit "
		"(check_lineage_completeness reds on a stale exemption once the target lands).",
		f"CEILING: parent line table maxes are {line_maxes}, so the merge formula's top end is "
		f"{ceiling} and the proposed table runs {floor}..{table_max} -- {verdict}. test_content.gd "
		"fails a target that cannot hold a maxed pair (GH#61).",
		f"tests/test_effect_text.gd::EXPECTED_SKILLS -- one pinned entry per new skill id "
		f"({', '.join(twin_ids) or 'none'}); passives pin [].",
		"tests/test_combat_data.gd -- combat-context skills need ap_cost AND effect (hidden boon "
		"carriers pin ap_cost: 0).",
		"tests/test_sprite_registry.gd::_build_expected_counts -- a frame-count pin per new "
		"sprites.json entry, and the icon PNG must exist (tools/sync_assets.py::_draw_placeholder "
		"needs a NEW shape, not a recolour).",
		f"tests/test_fixture_coherence.gd -- {fixture_name}.json needs a DERIVED rng_state "
		"(tests/_derive_rng_state.gd; a hand-typed small int fails the magnitude check) and the "
		"equipped weapon must be in `inventory` with an in-world provenance counter.",
		f"qa/manifest.json -- add the {script_name} row (script/seed/fixture/tiers/note), then run "
		"wandering_inn_game/scripts/derive_qa_surfaces.py, then scripts/render_qa_notes.py --write, "
		"IN THAT ORDER. Never hand-author a `surfaces` block.",
		"tests/sim_spine_viability.gd::SPINE_WEAPONS -- the spine roster DERIVES from "
		f"consolidations[], so `{target}` needs an act-appropriate five-weapon loadout the moment "
		"the rule lands or the suite asserts out (#456/#461).",
		"Code-banked counters -> STRUCTURAL_LITERALS in BOTH tests/test_shipped_ids.gd and "
		"scripts/generate_shipped_ids.py, at the moment the call site lands.",
		"Shipped-JSON edits go through wandering_inn_game/scripts/splice_json.py -- never json.dump "
		"a shipped file.",
		"HUMAN GATES (none of these are the tool's to decide): the class + skill display names are "
		"CANON, wiki-verified and inside the Book 17 spoiler bar; icon art needs DISTINCT "
		"SILHOUETTES (tint is not disambiguation); every counter the level curve reads needs a "
		"no-treadmill producer; the balance window is ratified by a human, not inferred.",
	]


def render_files(proposal: dict) -> dict:
	def dumped(obj) -> str:
		return json.dumps(obj, indent=1, ensure_ascii=False) + "\n"

	target = proposal["target"]
	files = {
		"README.md": _render_readme(proposal),
		"classes.consolidations.row.json": dumped(proposal["consolidation_row"]),
		"classes.class.row.json": dumped(proposal["class_row"]),
		"skills.twins.json": dumped(proposal["skill_twins"]),
		"sprites.icons.json": dumped(proposal["icon_slots"]),
		f"qa/fixtures/{proposal['fixture_name']}.json": dumped(proposal["fixture"]),
		f"qa/scripts/{proposal['qa_script_name']}.json": dumped(proposal["qa_script"]),
		"qa/manifest.row.json": dumped(proposal["manifest_row"]),
	}
	return {f"{target}/{name}": text for name, text in files.items()}


def _render_readme(proposal: dict) -> str:
	lines = [
		f"# Consolidation scaffold: `{proposal['target']}`",
		"",
		"PROPOSAL ONLY -- generated by `scripts/scaffold_consolidation.py` (#452 layer 3). "
		"Nothing here is shipped: every file is a paste-source for the real catalog, and every "
		"`TODO_NAME_ME` / `todo_twin__` id is a human gate the tool must not close.",
		"",
		f"- parents: `{proposal['parents'][0]}` x `{proposal['parents'][1]}`",
		f"- mechanical baseline: `{proposal['baseline']}` (the class this pair falls through to today)",
		f"- gate: min_parent_level {proposal['gate']['min_parent_level']}, "
		f"min_combined_level {proposal['gate']['min_combined_level']}",
		f"- cheapest legal pair: {tuple(proposal['cheapest_legal_pair'])} -> derived floor "
		f"**{proposal['floor']}**",
		"",
		"## Registration matrix",
		"",
	]
	lines += [f"- [ ] {item}" for item in proposal["checklist"]]
	lines.append("")
	return "\n".join(lines)


REFUSED_PARTS = ("data", "qa")


def _guard_out_dir(out: Path) -> None:
	"""The tool proposes. A staging dir inside the game's data/ or qa/ trees is
	not staging -- it is shipping with extra steps."""
	try:
		rel = out.resolve().relative_to(GAME.resolve())
	except ValueError:
		return
	if rel.parts and rel.parts[0] in REFUSED_PARTS:
		raise SystemExit(
			f"scaffold_consolidation: refusing to write into wandering_inn_game/{rel.parts[0]}/ -- "
			"this tool PROPOSES; a human splices its output into the shipped catalogs.")


def main(argv: list[str]) -> int:
	ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	ap.add_argument("--parents", required=True,
		help="the lineage pair, comma-separated (e.g. spearmaster,mage)")
	ap.add_argument("--target", required=True, help="new class id (snake_case)")
	ap.add_argument("--baseline", default="",
		help="override the derived mechanical baseline (a shipped consolidation target)")
	ap.add_argument("--issue", type=int, default=452, help="issue number for refs + the QA seed")
	ap.add_argument("--out", default="", help="staging dir to write the proposal tree into")
	ap.add_argument("--checklist", action="store_true", help="print only the registration checklist")
	ap.add_argument("--allow-existing", action="store_true",
		help="re-derive a target that already ships (the golden test's mode)")
	args = ap.parse_args(argv)

	parents = tuple(p.strip() for p in args.parents.split(",") if p.strip())
	if len(parents) != 2:
		raise SystemExit("scaffold_consolidation: --parents needs exactly two class ids")

	proposal = build_proposal(parents, args.target.strip(), load_catalogs(),
		baseline_id=args.baseline.strip(), issue=args.issue,
		allow_existing=args.allow_existing)

	if args.checklist:
		for item in proposal["checklist"]:
			print(f"- [ ] {item}")
		return 0
	if not args.out:
		print(json.dumps(proposal, indent=1, ensure_ascii=False))
		return 0

	out = Path(args.out)
	if not out.is_absolute():
		out = ROOT / out
	_guard_out_dir(out)
	for rel, text in render_files(proposal).items():
		path = out / rel
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(text)
		print(path)
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
