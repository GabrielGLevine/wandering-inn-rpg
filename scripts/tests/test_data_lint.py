#!/usr/bin/env python3
"""GH#276: every lint tier proven able to FAIL (deliberately broken
fixtures per check) + clean-on-HEAD subprocess proof. Run manually:
    python3 scripts/tests/test_data_lint.py -v"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME_SCRIPTS = REPO_ROOT / "wandering_inn_game" / "scripts"
sys.path.insert(0, str(GAME_SCRIPTS))
import data_lint  # noqa: E402

GRID = {"grid": {"width": 4, "height": 3}}


class TestBrokenFixtures(unittest.TestCase):
    def _errs(self, fn, *args):
        errors = []
        fn(*args, errors)
        return errors

    def test_blocked_cell_out_of_grid(self):
        # width 4 => x max 3 (the b10 bounds trap, exactly).
        errs = self._errs(data_lint.check_maps,
            {"m": {**GRID, "blocked": [[4, 0]], "entities": []}})
        self.assertEqual(len(errs), 1)
        self.assertIn("blocked cell [4, 0]", errs[0])

    def test_entity_cell_out_of_grid_and_missing(self):
        errs = self._errs(data_lint.check_maps,
            {"m": {**GRID, "blocked": [],
                "entities": [{"id": "a", "cell": [0, 3]}, {"id": "b"}]}})
        self.assertEqual(len(errs), 2)

    def test_missing_grid(self):
        errs = self._errs(data_lint.check_maps, {"m": {"blocked": []}})
        self.assertIn("missing/invalid grid", errs[0])

    def test_portal_bad_map_and_cell(self):
        parsed = {data_lint.DATA / "portals.json": {"portals": [
            {"id": "p1", "map": "nowhere", "cell": [0, 0]},
            {"id": "p2", "map": "m", "cell": [9, 9]},
        ]}}
        errs = self._errs(data_lint.check_portals, parsed, {"m": GRID})
        self.assertEqual(len(errs), 2)
        self.assertIn("'nowhere' does not exist", errs[0])
        self.assertIn("out of 'm' grid", errs[1])

    def test_portal_arrival_on_blocked_or_occupied_cell(self):
        # The shipped pallass class: travel assigns player_cell raw, so an
        # arrival cell holding a solid thing strands the player inside it.
        dest = {**GRID, "blocked": [[1, 1]], "entities": [
            {"id": "bench", "cell": [2, 2]},
            {"id": "ghost", "cell": [3, 2], "present_when": {"requires": {"x": 1}}},
        ]}
        parsed = {data_lint.DATA / "portals.json": {"portals": [
            {"id": "onblocked", "map": "m", "cell": [1, 1]},
            {"id": "onprop", "map": "m", "cell": [2, 2]},
            {"id": "onconditional", "map": "m", "cell": [3, 2]},
            {"id": "clear", "map": "m", "cell": [0, 0]},
        ]}}
        errs = self._errs(data_lint.check_portals, parsed, {"m": dest})
        self.assertEqual(len(errs), 2, errs)
        self.assertIn("'onblocked' arrival cell [1, 1] is a blocked cell", errs[0])
        self.assertIn("'onprop' arrival cell [2, 2] is occupied by entity 'bench'", errs[1])

    def test_dialogue_dangling_goto_and_missing_fields(self):
        parsed = {Path("/synthetic/dialogue/x.json"): {
            "start": "gone",
            "nodes": {
                "a": {"speaker": "s", "options": [{"goto": "nope"}]},
            }}}
        errs = self._errs(data_lint.check_dialogue, parsed)
        joined = "\n".join(errs)
        self.assertIn("start 'gone' is not a node", joined)
        self.assertIn("missing text", joined)
        self.assertIn("goto 'nope' targets no node", joined)
        self.assertEqual(len(errs), 3)

    def test_variants_only_node_fails(self):
        # dialogue.gd's _resolved_text reads node["text"] unconditionally
        # (review M1) -- variants without a base text is a guaranteed crash.
        parsed = {Path("/synthetic/dialogue/y.json"): {
            "start": "a",
            "nodes": {"a": {"speaker": "s", "text_variants": [
                {"requires": {"x": 1}, "text": "hi"}]}}}}
        errs = self._errs(data_lint.check_dialogue, parsed)
        self.assertEqual(len(errs), 1)
        self.assertIn("missing text", errs[0])

    def test_integral_float_cells_accepted(self):
        # Godot's JSON parser yields floats; 7.0 is engine-legal (review M2).
        errs = self._errs(data_lint.check_maps,
            {"m": {"grid": {"width": 4.0, "height": 3},
                "blocked": [[3.0, 2.0]],
                "entities": [{"id": "a", "cell": [0.0, 1]}]}})
        self.assertEqual(errs, [])

    def test_malformed_cell_gets_malformed_message(self):
        errs = self._errs(data_lint.check_maps,
            {"m": {**GRID, "blocked": [[3], [1.5, 2], [True, 0]], "entities": []}})
        self.assertEqual(len(errs), 3)
        for e in errs:
            self.assertIn("malformed blocked cell", e)

    def test_duplicate_map_stem_across_regions(self):
        parsed = {
            Path("/syn/maps/region_a/inn.json"): {**GRID},
            Path("/syn/maps/region_b/inn.json"): {**GRID},
        }
        errs = self._errs(data_lint._compose_maps, parsed)
        self.assertEqual(len(errs), 1)
        self.assertIn("duplicate map key 'inn'", errs[0])

    def test_sprites_missing_animations(self):
        parsed = {data_lint.DATA / "sprites.json": {
            "_comment": "x", "good": {"animations": {"idle": {}}}, "bad": {}}}
        errs = self._errs(data_lint.check_sprites, parsed)
        self.assertEqual(len(errs), 1)
        self.assertIn("'bad'", errs[0])

    def test_vacuous_gate_caught_with_no_exemptions(self):
        maps = {"m": {**GRID, "entities": [
            {"id": "door1", "door_when": {"door_awakened": 1}}]}}
        errs = self._errs(data_lint.check_gate_shapes, maps)
        self.assertEqual(len(errs), 1)
        self.assertIn("VACUOUSLY TRUE", errs[0])
        # The last shipped exemption (invrisil_anchor_stone) was wrapped for
        # real; the allowlist is empty by design and the arm now catches it too.
        self.assertEqual(data_lint.VACUOUS_GATE_ALLOWLIST, {})
        formerly = {"invrisil_boulevard": {**GRID, "entities": [
            {"id": "invrisil_anchor_stone",
             "portal_menu_when": {"door_awakened": 1}}]}}
        self.assertEqual(len(self._errs(data_lint.check_gate_shapes, formerly)), 1)

    def test_wrapped_gate_passes(self):
        maps = {"m": {**GRID, "entities": [
            {"id": "d", "door_when": {"requires": {"door_awakened": 1}}}]}}
        self.assertEqual(self._errs(data_lint.check_gate_shapes, maps), [])


# --- W1 / issue #348: the interactions-table tier ---------------------------
W1_TABLE = {
    "skill_properties": ["burns"],
    "target_properties": {"burnable": "entity"},
    "outcomes": list(data_lint.ENGINE_OUTCOMES),
    "interactions": [{
        "skill_property": "burns", "target_property": "burnable",
        "outcome": "remove_scorch", "persistence": "permanent",
        "counter": "burned_the_debris", "terrain": "scorched",
        "toast_from": "target", "toast_key": "burn_toast",
        "toast_default": "It burns.",
    }],
}
W1_SKILLS = {"skills": [{"id": "kindle", "burns": True}]}
# The counter registry data_lint cross-refs (spec §5c producer/consumer).
W1_SHIPPED = {"accomplishments": ["burned_the_debris"]}
W1_MAPS = {"m": {**GRID, "entities": [{"id": "debris", "cell": [0, 0], "burnable": True}]}}


class TestInteractionsTable(unittest.TestCase):
    def _run(self, table=None, skills=None, maps=None, shipped=None):
        parsed = {
            data_lint.DATA / "skills.json": skills if skills is not None else W1_SKILLS,
            data_lint.DATA / "shipped_ids.json": W1_SHIPPED if shipped is None else shipped,
        }
        if table is not None:
            parsed[data_lint.DATA / "interactions.json"] = table
        errors, report = [], []
        data_lint.check_interactions(
            parsed, W1_MAPS if maps is None else maps, errors, report)
        return errors, report

    def _mutated(self, **overrides):
        table = json.loads(json.dumps(W1_TABLE))
        for key, value in overrides.items():
            if key.startswith("row_"):
                table["interactions"][0][key[4:]] = value
            else:
                table[key] = value
        return table

    def test_clean_table_passes_and_reports_totality(self):
        errors, report = self._run(W1_TABLE)
        self.assertEqual(errors, [])
        self.assertIn("totality census 1/1 cells authored", report[0])

    def test_missing_file_fails(self):
        errors, _ = self._run(None)
        self.assertIn("missing", errors[0])

    def test_outcome_mirror_drift_fails(self):
        errors, _ = self._run(self._mutated(outcomes=["remove_scorch"]))
        self.assertIn("MIRROR CONTRACT", errors[0])

    def test_unregistered_vocabulary_fails(self):
        errors, _ = self._run(self._mutated(row_skill_property="melts"))
        self.assertTrue(any("unregistered skill property" in e for e in errors))

    def test_bad_placement_and_unknown_outcome_fail(self):
        errors, _ = self._run(self._mutated(target_properties={"burnable": "aura"}))
        self.assertTrue(any("must be one of ['entity', 'cell']" in e for e in errors))
        errors, _ = self._run(self._mutated(row_outcome="cook_yield"))
        self.assertTrue(any("unknown outcome" in e for e in errors))

    def test_wrong_persistence_class_fails(self):
        errors, _ = self._run(self._mutated(row_persistence="until_sleep"))
        self.assertTrue(any("claims persistence" in e for e in errors))

    def test_missing_copy_fields_fail(self):
        errors, _ = self._run(self._mutated(row_toast_from="vibes", row_terrain=""))
        self.assertTrue(any("'toast_from' must be one of" in e for e in errors))
        self.assertTrue(any("missing non-empty 'terrain'" in e for e in errors))

    def test_carrierless_row_is_dead_data(self):
        # No skills.json row carries `burns`, and no map entity is burnable.
        errors, _ = self._run(W1_TABLE, skills={"skills": [{"id": "kindle"}]},
            maps={"m": {**GRID, "entities": []}})
        self.assertTrue(any("no skills.json row carries it" in e for e in errors))
        self.assertTrue(any("no map carries it as a entity property" in e for e in errors))
        self.assertTrue(any("has no skill carrier" in e for e in errors))
        self.assertTrue(any("has no shipped target carrier" in e for e in errors))

    def test_staged_target_property_allows_phase_split_then_lapses(self):
        table = self._mutated()
        table["staged_target_properties"] = ["burnable"]
        errors, _ = self._run(table, maps={"m": {**GRID, "entities": []}})
        self.assertEqual(errors, [])
        errors, _ = self._run(table)
        self.assertTrue(any("now has shipped carriers" in e for e in errors), errors)

    def test_duplicate_row_is_unreachable(self):
        table = self._mutated()
        table["interactions"].append(json.loads(json.dumps(table["interactions"][0])))
        errors, _ = self._run(table)
        self.assertTrue(any("unreachable" in e for e in errors))

    def test_cell_placement_carrier_reads_map_cell_classes(self):
        table = self._mutated(
            skill_properties=["freezes"], target_properties={"freezable": "cell"},
            interactions=[{
                "skill_property": "freezes", "target_property": "freezable",
                "outcome": "freeze_cell", "persistence": "until_sleep",
                "terrain": "ice", "toast_from": "skill",
                "toast_key": "freeze_toast", "toast_default": "It freezes.",
            }])
        errors, _ = self._run(table, skills={"skills": [{"id": "f", "freezes": True}]},
            maps={"m": {**GRID, "entities": [], "freezable": [[1, 1]]}})
        self.assertEqual(errors, [])

    # --- v0.18 W1 review fix: verb/placement binding + counter registration ---
    def test_entity_verb_on_a_cell_property_fails(self):
        # The PROVEN crash row: remove_scorch dereferences target[id], but a
        # cell-placement property never populates `target`, so this row used to
        # lint clean and then SCRIPT ERROR on a live cast.
        table = self._mutated(
            target_properties={"burnable": "entity", "freezable": "cell"},
            row_target_property="freezable")
        errors, _ = self._run(table,
            maps={"m": {**GRID, "entities": [{"id": "d", "cell": [0, 0], "burnable": True}],
                "freezable": [[1, 1]]}})
        self.assertTrue(any("acts on the faced entity" in e for e in errors), errors)

    def test_cell_verb_on_an_entity_property_fails(self):
        # The silent mirror: freeze_cell bound to an entity flag freezes the
        # faced CELL whenever the entity carries the flag -- and a frozen cell is
        # walkable unconditionally (is_cell_blocked), i.e. a wall-phase primitive.
        table = self._mutated(
            skill_properties=["freezes"], target_properties={"burnable": "entity"},
            interactions=[{
                "skill_property": "freezes", "target_property": "burnable",
                "outcome": "freeze_cell", "persistence": "until_sleep",
                "terrain": "ice", "toast_from": "skill",
                "toast_key": "freeze_toast", "toast_default": "It freezes.",
            }])
        errors, _ = self._run(table, skills={"skills": [{"id": "f", "freezes": True}]})
        self.assertTrue(any("acts on the faced cell" in e for e in errors), errors)

    def test_unregistered_counter_fails(self):
        errors, _ = self._run(self._mutated(row_counter="lit_the_hearths"))
        self.assertTrue(any("not in data/shipped_ids.json" in e for e in errors), errors)

    def test_counter_on_a_non_banking_verb_is_dead_data(self):
        table = self._mutated(
            skill_properties=["freezes"], target_properties={"freezable": "cell"},
            interactions=[{
                "skill_property": "freezes", "target_property": "freezable",
                "outcome": "freeze_cell", "persistence": "until_sleep",
                "counter": "burned_the_debris", "terrain": "ice",
                "toast_from": "skill", "toast_key": "freeze_toast",
                "toast_default": "It freezes.",
            }])
        errors, _ = self._run(table, skills={"skills": [{"id": "f", "freezes": True}]},
            maps={"m": {**GRID, "entities": [], "freezable": [[1, 1]]}})
        self.assertTrue(any("banks no counter" in e for e in errors), errors)

    def test_absent_counter_registry_is_a_failure_not_a_pass(self):
        errors, _ = self._run(W1_TABLE, shipped={})
        self.assertTrue(any("cannot verify" in e for e in errors), errors)

    def test_counter_is_optional_on_a_banking_verb(self):
        table = self._mutated()
        del table["interactions"][0]["counter"]
        errors, _ = self._run(table)
        self.assertEqual(errors, [])


# --- Issue #398 Phase 0: descriptive skill-gate registry --------------------
SKILL_GATE_PARSED = {
    data_lint.DATA / "skills.json": {"skills": [
        {"id": "freeze", "freezes": True},
        {"id": "blink", "blinks": True, "blink_range": 2},
        {"id": "cut", "cuts": True},
    ]},
    data_lint.DATA / "classes.json": {"classes": [
        {"id": "mage", "levels": [{"level": 1, "grants": ["freeze"]}]},
        {"id": "runner", "levels": [{"level": 1, "grants": ["blink"]}]},
        {"id": "warrior", "levels": [{"level": 1, "grants": ["cut"]}]},
    ]},
}


def _good_skill_gate_map():
    return {**GRID, "entities": [
        {"id": "cache", "cell": [3, 1]},
        {"id": "guide", "cell": [0, 2]},
    ], "skill_gates": {"pocket": {
        "modes": [
            {"mechanism": "property", "skill_property": "freezes", "cells": [[1, 1]]},
            {"mechanism": "blink", "min_range": 2, "from": [0, 1], "to": [2, 1]},
        ],
        "rewards": ["cache"],
    }}}


def _arm_pair_map():
    """Two M-ARM modes in the #398-P3 shape: named skill + named prop, and no
    skill_property anywhere in the registry."""
    return {**GRID, "entities": [
        {"id": "cache", "cell": [3, 1]},
        {"id": "plate_a", "cell": [1, 1], "requires_skill": "freeze"},
        {"id": "plate_b", "cell": [2, 1], "requires_skill": "cut"},
    ], "skill_gates": {"pocket": {
        "modes": [
            {"mechanism": "arm", "skill": "freeze", "prop": "plate_a", "cells": [[1, 1]]},
            {"mechanism": "arm", "skill": "cut", "prop": "plate_b", "cells": [[2, 1]]},
        ],
        "rewards": ["cache"],
    }}}


class TestSkillGates(unittest.TestCase):
    def _run(self, map_doc):
        errors = []
        data_lint.check_skill_gates(SKILL_GATE_PARSED, {"m": map_doc}, errors)
        return errors

    def test_good_registry_passes(self):
        self.assertEqual(self._run(_good_skill_gate_map()), [])

    ARM_1 = "distinct mechanisms"

    def test_arm_1_modes_need_distinct_mechanisms_or_properties(self):
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["modes"][1] = {
            "mechanism": "property", "skill_property": "freezes", "cells": [[2, 1]]}
        errors = self._run(doc)
        self.assertTrue(any(self.ARM_1 in error for error in errors), errors)

    # --- #398-P3 review M9: an M-ARM mode's signature is (mechanism,
    # skill-or-gate, prop). Two arm modes sharing BOTH are one mode written
    # twice; sharing only the skill is a real two-carrier gate (the class
    # overlap is arm 2's call, not arm 1's); and an arm mode carries no
    # skill_property at all, which is what the invented "trapwork"/"force"
    # labels were papering over.
    def test_arm_1_arm_modes_need_no_skill_property(self):
        doc = _arm_pair_map()
        for mode in doc["skill_gates"]["pocket"]["modes"]:
            self.assertNotIn("skill_property", mode)
        self.assertEqual(self._run(doc), [])

    def test_arm_1_two_arm_modes_sharing_skill_and_prop_go_red(self):
        doc = _arm_pair_map()
        doc["skill_gates"]["pocket"]["modes"][1] = {
            "mechanism": "arm", "skill": "freeze", "prop": "plate_a", "cells": [[2, 1]]}
        errors = self._run(doc)
        self.assertTrue(any(self.ARM_1 in error for error in errors), errors)

    def test_arm_1_two_arm_modes_sharing_only_the_skill_stay_distinct(self):
        doc = _arm_pair_map()
        doc["skill_gates"]["pocket"]["modes"][1]["skill"] = "freeze"
        errors = self._run(doc)
        self.assertFalse(any(self.ARM_1 in error for error in errors), errors)
        # Clean overall: the carrier unions still differ (plate_b answers
        # [Cut]), and that judgement is arm 2's, not arm 1's.
        self.assertEqual(errors, [])

    def test_arm_1_property_mode_signature_is_unchanged(self):
        """A property mode still keys on its skill_property, carriers ignored."""
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["modes"][1] = {
            "mechanism": "property", "skill_property": "freezes", "props": ["cache"]}
        errors = self._run(doc)
        self.assertTrue(any(self.ARM_1 in error for error in errors), errors)
        doc["skill_gates"]["pocket"]["modes"][1]["skill_property"] = "cuts"
        errors = self._run(doc)
        self.assertFalse(any(self.ARM_1 in error for error in errors), errors)

    def test_arm_2_class_unions_are_pairwise_distinct_across_all_modes(self):
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["modes"].append({
            "mechanism": "arm", "skill": "freeze", "cells": [[3, 2]]})
        errors = self._run(doc)
        self.assertTrue(any("identical class unions" in error for error in errors), errors)

    def test_arm_2_empty_union_needs_explicit_non_skill_gate(self):
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["modes"][1] = {
            "mechanism": "social", "props": ["guide"]}
        errors = self._run(doc)
        self.assertTrue(any("empty skill-granter union" in error and "gate" in error
            for error in errors), errors)
        doc["skill_gates"]["pocket"]["modes"][1]["gate"] = "dialogue"
        self.assertEqual(self._run(doc), [])

    def test_arm_3_carriers_and_blink_range_must_be_real(self):
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["modes"][0]["props"] = ["missing"]
        doc["skill_gates"]["pocket"]["modes"][0]["cells"] = [[4, 0]]
        doc["skill_gates"]["pocket"]["modes"][1]["min_range"] = 3
        errors = self._run(doc)
        joined = "\n".join(errors)
        self.assertIn("does not resolve", joined)
        self.assertIn("not a real cell", joined)
        self.assertIn("exceeds shipped blink range", joined)

    def test_blink_none_reports_invalid_value_not_exceeded_range(self):
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["modes"][1]["min_range"] = None
        errors = self._run(doc)
        self.assertTrue(any("positive integer" in error for error in errors), errors)
        self.assertFalse(any("None exceeds" in error for error in errors), errors)

    def test_arm_4_rewards_must_resolve_on_the_same_map(self):
        doc = _good_skill_gate_map()
        doc["skill_gates"]["pocket"]["rewards"] = ["elsewhere"]
        errors = self._run(doc)
        self.assertTrue(any("rewards do not resolve" in error for error in errors), errors)

    def test_arm_5_missing_registry_is_report_only(self):
        map_doc = {**GRID, "entities": [
            {"id": "brush", "cell": [1, 1], "burnable": True},
        ]}
        advisories = []
        data_lint.advise_missing_skill_gates({"m": map_doc}, advisories)
        self.assertEqual(len(advisories), 1)
        self.assertIn("burnable blocker", advisories[0])


class TestRealTree(unittest.TestCase):
    def test_clean_on_head_and_fast(self):
        result = subprocess.run(
            [sys.executable, str(GAME_SCRIPTS / "data_lint.py")],
            capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("data_lint: OK", result.stdout)

    def test_malformed_json_fails_loud(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "broken.json").write_text("{broken")
            (Path(tmp) / "fine.json").write_text("{}")
            errors = []
            parsed = data_lint.check_wellformed(errors, root=Path(tmp))
            self.assertEqual(len(errors), 1)
            self.assertIn("broken.json: invalid JSON", errors[0])
            self.assertEqual(len(parsed), 1)


if __name__ == "__main__":
    unittest.main()
