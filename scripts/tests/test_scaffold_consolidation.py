#!/usr/bin/env python3
"""#452 layer 3 -- the GOLDEN TEST for scripts/scaffold_consolidation.py.

Run the scaffolder for the pair #449 solved by hand (spearmaster x mage ->
spellspear) and diff its proposal against the artifacts #469 actually SHIPPED.
The scaffolder is only worth having if it emits the ruled pattern, and "the
ruled pattern" has exactly one non-prose definition: the shipped [Spellspear].

THE SPLIT THIS TEST ENFORCES:
  PATTERN (pinned equal) -- class-row structure, derived floor, stat_growth,
    inherits, the whole level table incl. requires_any thresholds and which
    rungs carry grants, twin-stub mechanical fields and key ORDER, icon-slot
    shape, fixture shape + derived counters + version, the QA skeleton's
    assert spine, the manifest row's script/seed/fixture/tiers.
  FLAVOR (pinned DIFFERENT, or not pinned at all) -- display names, skill ids,
    prose, icon art, the fight beat. The tool must never author these, so the
    golden test must never demand them.

Run:  python3 -m pytest -q scripts/tests/test_scaffold_consolidation.py
"""

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))
import scaffold_consolidation as scaffold  # noqa: E402

GAME = REPO_ROOT / "wandering_inn_game"
DATA = GAME / "data"

SHIPPED_TARGET = "spellspear"
SHIPPED_PARENTS = ("spearmaster", "mage")
SHIPPED_BASELINE = "spellsword"
SHIPPED_ISSUE = 449
# id -> the shipped twin #449 authored from it. The tool emits `todo_twin__<id>`
# placeholders instead; this map is the flavor bridge the human crosses.
SHIPPED_TWINS = {"keener_edge": "keener_point", "spellbound_strike": "spellbound_thrust"}


def _load(path):
	return json.loads(path.read_text())


def _strip(obj):
	return {k: v for k, v in obj.items() if k != "_comment"}


class GoldenBase(unittest.TestCase):
	@classmethod
	def setUpClass(cls):
		cls.classes = _load(DATA / "classes.json")
		cls.skills = {row["id"]: row for row in _load(DATA / "skills.json")["skills"]}
		cls.sprites = _load(DATA / "sprites.json")
		cls.proposal = scaffold.build_proposal(
			SHIPPED_PARENTS, SHIPPED_TARGET, scaffold.load_catalogs(),
			issue=SHIPPED_ISSUE, allow_existing=True)
		cls.shipped_class = next(row for row in cls.classes["classes"]
			if row["id"] == SHIPPED_TARGET)
		cls.shipped_rule = next(row for row in cls.classes["consolidations"]
			if row.get("target") == SHIPPED_TARGET)


class TestGoldenConsolidationRule(GoldenBase):
	def test_rule_row_is_the_shipped_row(self):
		# Whole row, field for field: id, target, both parent lines in canon
		# order (the mage line's evolution closure included), and the gate.
		self.assertEqual(_strip(self.proposal["consolidation_row"]), _strip(self.shipped_rule))

	def test_baseline_is_the_class_the_pair_used_to_fall_through_to(self):
		self.assertEqual(self.proposal["baseline"], SHIPPED_BASELINE)

	def test_rule_must_precede_its_baseline_and_shipped_data_agrees(self):
		# check_consolidation is FIRST-MATCH, so the whole #449 ruling hangs on
		# row order. The checklist says place it above; classes.json does.
		order = [row.get("target") for row in self.classes["consolidations"] if "target" in row]
		self.assertLess(order.index(SHIPPED_TARGET), order.index(SHIPPED_BASELINE))
		self.assertTrue(any("ABOVE `spellsword`" in item for item in self.proposal["checklist"]),
			self.proposal["checklist"])


class TestGoldenClassRow(GoldenBase):
	def test_derived_floor_matches_the_shipped_tables_lowest_rung(self):
		# THE FLOOR MATH. Perturbing merged_level() reds here first.
		self.assertEqual(self.proposal["floor"], 14)
		self.assertEqual(self.proposal["cheapest_legal_pair"], [10, 11])
		self.assertEqual(min(l["level"] for l in self.shipped_class["levels"]),
			self.proposal["floor"])

	def test_key_order_and_mechanical_fields_match(self):
		scaffolded = _strip(self.proposal["class_row"])
		shipped = _strip(self.shipped_class)
		self.assertEqual(list(scaffolded), list(shipped))
		self.assertEqual(scaffolded["id"], shipped["id"])
		self.assertEqual(scaffolded["stat_growth"], shipped["stat_growth"])
		self.assertEqual(scaffolded["inherits"], shipped["inherits"])

	def test_level_table_is_the_shipped_table_with_grants_re_slotted(self):
		scaffolded = self.proposal["class_row"]["levels"]
		shipped = self.shipped_class["levels"]
		self.assertEqual([l["level"] for l in scaffolded], [l["level"] for l in shipped])
		self.assertEqual([l.get("requires_any") for l in scaffolded],
			[l.get("requires_any") for l in shipped])
		# Same rungs carry grants, same COUNT per rung -- only the ids differ.
		self.assertEqual([len(l["grants"]) for l in scaffolded], [len(l["grants"]) for l in shipped])

	def test_display_name_is_left_to_the_human(self):
		# FLAVOR: [Spellspear] is a canon name off the wiki, not a titlecase of
		# the id, and a tool that guesses it is a tool that ships lore.
		self.assertEqual(self.proposal["class_row"]["display_name"], scaffold.TODO_NAME)
		self.assertNotEqual(self.proposal["class_row"]["display_name"],
			self.shipped_class["display_name"])


class TestGoldenSkillTwins(GoldenBase):
	def _pairs(self):
		grants = [g for l in self.proposal["class_row"]["levels"] for g in l["grants"]]
		self.assertEqual(len(grants), len(SHIPPED_TWINS))
		out = []
		for twin, (baseline_id, shipped_id) in zip(self.proposal["skill_twins"],
				SHIPPED_TWINS.items()):
			out.append((twin, self.skills[baseline_id], self.skills[shipped_id]))
		return out

	def test_stub_key_order_matches_the_shipped_twin(self):
		for twin, _baseline, shipped in self._pairs():
			self.assertEqual(list(_strip(twin)), list(_strip(shipped)), twin["id"])

	def test_mechanical_fields_are_the_baselines_verbatim(self):
		for twin, baseline, shipped in self._pairs():
			for field in ("contexts", "ap_cost", "mp_cost", "effect", "cooldown_rounds"):
				self.assertEqual(twin.get(field), baseline.get(field), (twin["id"], field))
				self.assertEqual(twin.get(field), shipped.get(field), (twin["id"], field))

	def test_weapon_gate_is_mirrored_never_minted(self):
		# keener_edge carries `weapon: sword`, so its twin carries the LINEAGE's
		# weapon; spellbound_strike carries none, so its twin carries none. Both
		# halves are what #449 shipped, and inventing a gate on the second would
		# let weapon_gated_kit strip the class's marquee grant.
		for twin, baseline, shipped in self._pairs():
			self.assertEqual("weapon" in twin, "weapon" in baseline, twin["id"])
			self.assertEqual("weapon" in twin, "weapon" in shipped, twin["id"])
			if "weapon" in twin:
				self.assertEqual(twin["weapon"], "spear")
				self.assertEqual(twin["weapon"], shipped["weapon"])
				self.assertNotEqual(twin["weapon"], baseline["weapon"])

	def test_names_and_prose_are_left_to_the_human(self):
		for twin, _baseline, shipped in self._pairs():
			self.assertTrue(twin["id"].startswith("todo_twin__"), twin["id"])
			self.assertNotEqual(twin["id"], shipped["id"])
			self.assertIn(scaffold.TODO_NAME, twin["display_name"])
			self.assertTrue(twin["description"].startswith("TODO"), twin["description"])


class TestGoldenIconSlots(GoldenBase):
	def test_slot_shape_matches_the_shipped_sprites_entries(self):
		# One slot per twin, paired in emission order with the twins #449
		# authored from the same baselines. Only the sheet path (which follows
		# the un-named id) may differ.
		self.assertEqual(len(self.proposal["icon_slots"]), len(SHIPPED_TWINS))
		pairs = zip(self.proposal["icon_slots"].values(),
			(self.sprites[f"icon_{sid}"] for sid in SHIPPED_TWINS.values()))
		for raw_scaffolded, raw_shipped in pairs:
			scaffolded, shipped = _strip(raw_scaffolded), _strip(raw_shipped)
			self.assertEqual(list(scaffolded), list(shipped))
			mine = dict(scaffolded["animations"]["idle"])
			theirs = dict(shipped["animations"]["idle"])
			self.assertEqual(list(mine), list(theirs))
			self.assertNotEqual(mine.pop("sheet"), theirs.pop("sheet"))
			self.assertEqual(mine, theirs)

	def test_sheet_path_follows_the_icon_id(self):
		for icon_id, slot in self.proposal["icon_slots"].items():
			self.assertEqual(slot["animations"]["idle"]["sheet"],
				f"res://assets/ui/icons/{icon_id}.png")


class TestGoldenFixture(GoldenBase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		cls.shipped = _load(GAME / "qa" / "fixtures" / "near_spellspear_consolidation.json")

	def test_name_and_version(self):
		self.assertEqual(self.proposal["fixture_name"], "near_spellspear_consolidation")
		self.assertEqual(self.proposal["fixture"]["version"], self.shipped["version"])
		self.assertEqual(self.proposal["fixture"]["version"], 5)

	def test_state_key_set_matches(self):
		self.assertEqual(sorted(self.proposal["fixture"]["state"]), sorted(self.shipped["state"]))

	def test_held_pair_is_the_shipped_cheapest_legal_pair(self):
		self.assertEqual(self.proposal["fixture"]["state"]["classes"],
			self.shipped["state"]["classes"])
		self.assertEqual(self.proposal["fixture"]["state"]["classes"],
			{"spearmaster": 11, "mage": 10})

	def test_derived_counters_reproduce_the_shipped_ledger(self):
		# EXACT, minus one: given_spear_by_relc is the equipped weapon's
		# in-world PROVENANCE, which no curve implies -- the checklist asks for
		# it by name and the human supplies it. Everything else (warrior's
		# melee_hit 68 at L11 via `inherits`, spearmaster's own spear_skill_used
		# 16, mage's spell_cast 45 + won_combat 3, the gained_by ones, met_relc)
		# falls straight out of the same rule test_fixture_coherence enforces.
		derived = self.proposal["fixture"]["state"]["accomplishments"]
		shipped = dict(self.shipped["state"]["accomplishments"])
		self.assertEqual(shipped.pop("given_spear_by_relc"), 1)
		self.assertEqual(derived, shipped)

	def test_lineage_weapon_is_equipped_and_carried(self):
		state = self.proposal["fixture"]["state"]
		self.assertEqual(state["equipped"]["weapon"],
			self.shipped["state"]["equipped"]["weapon"])
		self.assertEqual(state["equipped"]["weapon"], "relcs_spare_spear")
		self.assertIn(state["equipped"]["weapon"], state["inventory"])

	def test_rng_state_is_a_loud_todo_not_a_hand_typed_int(self):
		self.assertIn("_derive_rng_state", self.proposal["fixture"]["state"]["rng_state"])
		self.assertTrue(self.shipped["state"]["rng_state"].lstrip("-").isdigit())


class TestGoldenCanonicalSkeleton(GoldenBase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		cls.shipped = _load(GAME / "qa" / "scripts" / "spellspear_consolidation_loop.json")

	def _spine(self, script):
		"""The assert spine: every step that PROVES something, in order, with
		the prose and the content walk (teleports/moves/screenshots) dropped."""
		keep = {"assert_state", "assert_event_absent", "wait_for_event"}
		out = []
		for step in script["steps"]:
			if step["action"] not in keep:
				continue
			row = {k: v for k, v in step.items() if k not in ("_comment", "timeout_sec")}
			out.append(row)
		return out

	def test_name_and_fixture_binding(self):
		self.assertEqual(self.proposal["qa_script_name"], "spellspear_consolidation_loop")
		self.assertEqual(self.proposal["qa_script"]["fixture_save"], self.shipped["fixture_save"])
		self.assertTrue(self.proposal["qa_script"]["starts_at_title"])

	def test_offer_and_accept_beats_pin_target_and_derived_floor(self):
		spine = self._spine(self.proposal["qa_script"])
		shipped = self._spine(self.shipped)
		for event in ("consolidation_offered", "consolidation_accepted"):
			mine = next(s for s in spine if s.get("type") == event and "payload_contains" in s)
			theirs = next(s for s in shipped if s.get("type") == event and "payload_contains" in s)
			self.assertEqual(mine["payload_contains"], theirs["payload_contains"])
			self.assertEqual(mine["payload_contains"]["level"], 14)

	def test_opaque_until_sleep_lock_is_proved_before_the_bed(self):
		spine = self._spine(self.proposal["qa_script"])
		absent = [s for s in spine if s["action"] == "assert_event_absent"]
		self.assertEqual([s["type"] for s in absent], ["consolidation_offered"])
		pending = next(i for i, s in enumerate(spine)
			if s.get("path") == "pending_consolidation" and s.get("equals") == {})
		offered = next(i for i, s in enumerate(spine)
			if s.get("type") == "consolidation_offered")
		self.assertLess(pending, offered)

	def test_merged_state_assertions_match_the_shipped_script(self):
		spine = self._spine(self.proposal["qa_script"])
		shipped = self._spine(self.shipped)
		merged = [s for s in spine if s.get("path") == "classes"]
		self.assertEqual([s["equals"] for s in merged],
			[s["equals"] for s in shipped if s.get("path") == "classes"])

	def test_kit_assert_carries_both_inherited_lines_and_the_own_grant(self):
		mine = next(s for s in self.proposal["qa_script"]["steps"]
			if s.get("path") == "combat.combatants.pc.skills")
		theirs = next(s for s in self.shipped["steps"]
			if s.get("path") == "combat.combatants.pc.skills")
		self.assertEqual(len(mine["contains"]), len(theirs["contains"]))
		# Inherited grants are DERIVED (highest rung <= floor on each parent
		# line) and must match #449's hand-picked pair exactly; only the
		# consolidation's OWN grant is the un-named placeholder.
		self.assertEqual([mine["contains"][0], mine["contains"][2]],
			[theirs["contains"][0], theirs["contains"][2]])
		self.assertEqual([mine["contains"][0], mine["contains"][2]],
			["pierce_thrust", "flash_step"])
		self.assertTrue(mine["contains"][1].startswith("todo_twin__"))


class TestGoldenManifestRow(GoldenBase):
	def test_row_matches_the_shipped_manifest_minus_derived_surfaces(self):
		shipped = next(row for row in _load(GAME / "qa" / "manifest.json")["scripts"]
			if row.get("script") == "spellspear_consolidation_loop")
		mine = _strip(self.proposal["manifest_row"])
		for field in ("script", "seed", "fixture", "tiers"):
			self.assertEqual(mine[field], shipped[field], field)
		self.assertEqual(mine["seed"], SHIPPED_ISSUE)
		# `surfaces` is DERIVED by derive_qa_surfaces.py; hand-authoring it is
		# the vacuous-selective failure mode, so the scaffolder omits it.
		self.assertNotIn("surfaces", mine)
		self.assertIn("surfaces", shipped)


class TestGoldenChecklist(GoldenBase):
	# The registration surfaces #469 actually had to touch, plus the two the
	# derivation lanes added (#456/#461 spine roster, #454 exemption rows). A
	# checklist that stops naming one of these stops being the matrix.
	REQUIRED = [
		"tests/test_effect_text.gd",
		"tests/test_combat_data.gd",
		"tests/test_sprite_registry.gd",
		"tests/test_fixture_coherence.gd",
		"qa/manifest.json",
		"derive_qa_surfaces.py",
		"render_qa_notes.py",
		"tests/sim_spine_viability.gd",
		"test_shipped_ids.gd",
		"splice_json.py",
		"_exempt",
		"tests/test_progression.gd",
	]

	def test_every_registration_surface_is_named(self):
		blob = "\n".join(self.proposal["checklist"])
		for needle in self.REQUIRED:
			self.assertIn(needle, blob)

	def test_human_gates_are_named_as_human_gates(self):
		blob = "\n".join(self.proposal["checklist"]).lower()
		for needle in ("canon", "spoiler bar", "silhouettes", "treadmill", "balance window"):
			self.assertIn(needle, blob)

	def test_ceiling_check_uses_real_table_maxes(self):
		line = next(i for i in self.proposal["checklist"] if i.startswith("CEILING"))
		self.assertIn("[16, 16]", line)
		self.assertIn("14..22", line)


class TestMergedLevelMathParity(unittest.TestCase):
	"""The scaffolder's floor math is a MIRROR of GDScript the game actually
	runs. Mirrors rot silently, so pin both the values and the source."""

	def test_values(self):
		self.assertEqual(scaffold.merged_level(10, 11), 14)
		self.assertEqual(scaffold.merged_level(11, 10), 14)
		# ceil, not floor: 2*20/3 == 13.33 -> 14.
		self.assertEqual(scaffold.merged_level(10, 10), 14)
		# the max(a, b) arm wins when one parent towers over the other
		self.assertEqual(scaffold.merged_level(1, 20), 20)
		self.assertEqual(scaffold.merged_level(16, 16), 22)

	def test_gdscript_source_still_says_the_same_thing(self):
		src = (GAME / "src" / "core" / "progression.gd").read_text()
		body = re.search(
			r"static func _consolidation_merged_level\(.*?\n(.*?)\n\n", src, re.S).group(1)
		self.assertIn("(2 * sum + 2) / 3", body)
		self.assertIn("maxi(two_thirds, maxi(level_a, level_b))", body)

	def test_floor_derivation_mirrors_test_content(self):
		src = (GAME / "tests" / "test_content.gd").read_text()
		self.assertIn("var s_min := maxi(min_combined_level, 2 * min_parent_level)", src)
		self.assertEqual(scaffold.cheapest_legal_pair(10, 21), (10, 11))
		self.assertEqual(scaffold.consolidation_floor(10, 21), 14)


class TestGuards(unittest.TestCase):
	def setUp(self):
		self.catalogs = scaffold.load_catalogs()

	def test_existing_target_is_refused_without_the_golden_flag(self):
		with self.assertRaises(SystemExit) as ctx:
			scaffold.build_proposal(SHIPPED_PARENTS, SHIPPED_TARGET, self.catalogs)
		self.assertIn("already has a classes.json row", str(ctx.exception))

	def test_unknown_parent_is_refused(self):
		with self.assertRaises(SystemExit) as ctx:
			scaffold.build_proposal(("nope", "mage"), "x", self.catalogs)
		self.assertIn("no classes.json row", str(ctx.exception))

	def test_unreachable_pair_has_no_baseline_to_derive_from(self):
		with self.assertRaises(SystemExit) as ctx:
			scaffold.build_proposal(("mage", "ice_mage"), "x", self.catalogs)
		self.assertIn("not lineage-reachable", str(ctx.exception))

	def test_writing_into_the_shipped_trees_is_refused(self):
		for part in ("data", "qa"):
			with self.assertRaises(SystemExit) as ctx:
				scaffold._guard_out_dir(GAME / part / "scaffold")
			self.assertIn("refusing to write", str(ctx.exception))

	def test_a_real_orphan_pair_scaffolds_end_to_end(self):
		# swordsman x mage is one of the `_exempt` rows awaiting a naming pass:
		# the tool's actual job, not just the golden re-derivation.
		proposal = scaffold.build_proposal(("swordsman", "mage"), "spellblade_placeholder",
			self.catalogs, issue=452)
		self.assertEqual(proposal["baseline"], SHIPPED_BASELINE)
		self.assertEqual(proposal["floor"], 14)
		self.assertEqual(proposal["class_row"]["inherits"], ["swordsman", "mage"])
		self.assertEqual(proposal["skill_twins"][0]["weapon"], "sword")


class TestCli(unittest.TestCase):
	def test_out_tree_is_written_and_parses(self):
		with tempfile.TemporaryDirectory() as tmp:
			out = subprocess.run(
				[sys.executable, str(REPO_ROOT / "scripts" / "scaffold_consolidation.py"),
					"--parents", "swordsman,mage", "--target", "spellblade_placeholder",
					"--issue", "452", "--out", tmp],
				capture_output=True, text=True, check=True)
			written = [Path(line) for line in out.stdout.split("\n") if line.strip()]
			self.assertTrue(written)
			for path in written:
				self.assertTrue(path.exists(), path)
				if path.suffix == ".json":
					json.loads(path.read_text())
			readme = next(p for p in written if p.name == "README.md")
			self.assertIn("PROPOSAL ONLY", readme.read_text())

	def test_stdout_mode_writes_nothing(self):
		out = subprocess.run(
			[sys.executable, str(REPO_ROOT / "scripts" / "scaffold_consolidation.py"),
				"--parents", "spearmaster,mage", "--target", SHIPPED_TARGET,
				"--issue", str(SHIPPED_ISSUE), "--allow-existing"],
			capture_output=True, text=True, check=True)
		self.assertEqual(json.loads(out.stdout)["floor"], 14)
		self.assertEqual(
			subprocess.run(["git", "status", "--porcelain", "wandering_inn_game/data",
				"wandering_inn_game/qa"], cwd=REPO_ROOT, capture_output=True, text=True).stdout,
			"")


if __name__ == "__main__":
	unittest.main()
