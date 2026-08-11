#!/usr/bin/env python3
"""GH#276: every lint tier proven able to FAIL (deliberately broken
fixtures per check) + clean-on-HEAD subprocess proof. Run manually:
    python3 scripts/tests/test_data_lint.py -v"""

import contextlib
import copy
import io
import json
import re
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

    # --- #398-p2 review HIGH-1: the per-carrier counter override ------------
    # One row over every burnable in the game was also ONE world-event id, so
    # burning the sewers debris opened a strongbox two maps down. These arms
    # police the fix's vocabulary; the engine half is proven in
    # tests/test_interactions_table.gd.
    def _override_table(self, **row):
        table = self._mutated()
        table["interactions"][0].update({"counter_from": "target",
            "counter_key": "burn_counter", **row})
        return table

    def _override_maps(self, **entity):
        return {"m": {**GRID, "entities": [
            {"id": "debris", "cell": [0, 0], "burnable": True},
            {"id": "shoring", "cell": [1, 0], "burnable": True, **entity}]}}

    def test_counter_override_passes_when_registered(self):
        errors, _ = self._run(self._override_table(),
            maps=self._override_maps(burn_counter="burned_the_shoring"),
            shipped={"accomplishments": ["burned_the_debris", "burned_the_shoring"]})
        self.assertEqual(errors, [])

    def test_counter_override_opt_out_carrier_is_fine(self):
        # The sewers-debris case: authors no override, keeps the row default.
        errors, _ = self._run(self._override_table(), maps=self._override_maps())
        self.assertEqual(errors, [])

    def test_counter_override_needs_a_counter_key(self):
        table = self._override_table()
        del table["interactions"][0]["counter_key"]
        errors, _ = self._run(table, maps=self._override_maps())
        self.assertTrue(any("names no 'counter_key'" in e for e in errors), errors)

    def test_counter_override_needs_a_row_fallback(self):
        table = self._override_table()
        del table["interactions"][0]["counter"]
        errors, _ = self._run(table, maps=self._override_maps())
        self.assertTrue(any("no row-level 'counter' fallback" in e for e in errors), errors)

    def test_unregistered_override_id_fails(self):
        errors, _ = self._run(self._override_table(),
            maps=self._override_maps(burn_counter="burned_the_shoring"))
        self.assertTrue(any("banks override 'burned_the_shoring'" in e for e in errors), errors)

    def test_override_that_repeats_the_row_default_fails(self):
        # A lookalike override reads as isolation in review while banking the
        # shared id -- exactly the bug, wearing the fix's clothes.
        errors, _ = self._run(self._override_table(),
            maps=self._override_maps(burn_counter="burned_the_debris"))
        self.assertTrue(any("with the row's own 'burned_the_debris'" in e for e in errors), errors)

    def test_bogus_counter_source_fails(self):
        errors, _ = self._run(self._override_table(counter_from="skill"),
            maps=self._override_maps())
        self.assertTrue(any("'counter_from' must be one of" in e for e in errors), errors)

    def test_counter_key_without_counter_from_is_dead_data(self):
        errors, _ = self._run(self._mutated(row_counter_key="burn_counter"))
        self.assertTrue(any("dead data here unless the row declares counter_from" in e
            for e in errors), errors)

    def test_counter_from_on_a_carrier_sourced_verb_is_dead_data(self):
        # state_set has no row default to fall back to, so the discriminator
        # would be a lie: its counter is ALWAYS the carrier's.
        table = self._mutated(
            target_properties={"hearth": "entity"},
            interactions=[{
                "skill_property": "burns", "target_property": "hearth",
                "outcome": "state_set", "persistence": "permanent",
                "counter_key": "state_counter", "counter_from": "target",
                "toast_from": "target", "toast_key": "kindle_toast",
                "toast_default": "It lights.",
            }])
        errors, _ = self._run(table, maps={"m": {**GRID, "entities": [
            {"id": "brazier", "cell": [0, 0], "hearth": True,
             "state_counter": "burned_the_debris",
             "visual_states": [{"when": {"counter": "burned_the_debris", "at": 1}}]}]}})
        self.assertTrue(any("carrier-sourced BY SUBSTRATE" in e for e in errors), errors)


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


class TestContentReachability(unittest.TestCase):
    """GH#424 -- the orphan graph, proven able to fail in every category.

    The mutations are IN MEMORY, over a copy of the real parsed tree: shipped
    data is never touched, and each case is the real check answering a real
    (broken) catalog rather than a toy fixture that could drift from it.
    """

    @classmethod
    def setUpClass(cls):
        cls.errors = []
        cls.parsed = data_lint.check_wellformed(cls.errors)
        cls.maps = data_lint._compose_maps(cls.parsed, cls.errors)
        assert not cls.errors, cls.errors

    def _run(self, mutate=None):
        parsed = copy.deepcopy(self.parsed)
        maps = data_lint._compose_maps(parsed, [])
        if mutate is not None:
            mutate(parsed, maps)
        advisories = []
        counts = data_lint.check_content_reachability(parsed, maps, advisories)
        return counts, advisories

    def test_head_tree_findings_are_the_known_set(self):
        counts, advisories = self._run()
        self.assertEqual(counts.get("map orphan", 0), 0, advisories)
        # GH#429 drained all three promoted categories: kindle -> hedge_witch
        # L2 and frost_touch -> hedge_witch L4 (ruling 33) closed the skill arm,
        # the three item wirings closed the item arm, and riverfarm_hunter.agreed
        # was retired. Every promoted category must read EMPTY on a clean tree,
        # or the shipped build reds -- which is the whole point of promoting it.
        for drained in data_lint.HARD_FAIL_REACHABILITY_CATEGORIES:
            self.assertFalse([line for line in advisories
                if line.startswith(f"[{drained}]")], (drained, advisories))
        # The code-grant allowlist covers the boons, so they must NOT show up
        # -- and no allowlist row may be reporting drift on a clean tree.
        self.assertFalse([line for line in advisories if line.startswith("[code-grant drift]")], advisories)
        for boon in data_lint.SKILL_CODE_GRANTS:
            self.assertFalse([line for line in advisories if f"'{boon}'" in line], boon)

    def test_orphaning_a_granted_skill_is_caught(self):
        # `frost_bolt` is granted by mage L1 on HEAD. Strip every grant of it
        # and the check must say so -- the can-fail proof for the skill arm.
        def mutate(parsed, _maps):
            for cls in parsed[data_lint.DATA / "classes.json"]["classes"]:
                for level in cls.get("levels", []):
                    level["grants"] = [s for s in level.get("grants", []) if s != "frost_bolt"]
                evolution = cls.get("evolution") or {}
                if "balanced_grants" in evolution:
                    evolution["balanced_grants"] = [
                        s for s in evolution["balanced_grants"] if s != "frost_bolt"]
        counts, advisories = self._run(mutate)
        # frost_bolt is in combatant kits too, so ungranting it demotes it to
        # the enemy-kit category -- reachable, but no longer learnable.
        self.assertIn("[enemy-kit only] skills.json 'frost_bolt'",
            "\n".join(advisories))
        self.assertEqual(counts["enemy-kit only"], 4)

    def test_orphaning_a_class_only_skill_reports_as_orphan(self):
        def mutate(parsed, _maps):
            for cls in parsed[data_lint.DATA / "classes.json"]["classes"]:
                for level in cls.get("levels", []):
                    level["grants"] = [s for s in level.get("grants", []) if s != "quick_cast"]
        counts, advisories = self._run(mutate)
        self.assertTrue(any(line.startswith("[skill orphan]") and "'quick_cast'" in line
            for line in advisories), advisories)
        # quick_cast ALONE: GH#429 drained both shipped skill orphans, so the
        # mutation's own victim is the entire tally.
        self.assertEqual(counts["skill orphan"], 1)

    def test_gate_carrier_arm_is_clean_on_head(self):
        counts, _ = self._run()
        self.assertEqual(counts.get("gate carrier orphan", 0), 0)

    def _degrant(self, *skill_ids):
        """Strip every class grant of the named Skill(s). VARIADIC since GH#429:
        a property whose carriers are ALL granted needs all of them stripped
        before its gates can seal, and a one-at-a-time helper silently answered
        "still carried" instead."""
        dropped = set(skill_ids)

        def mutate(parsed, _maps):
            for cls in parsed[data_lint.DATA / "classes.json"]["classes"]:
                for level in cls.get("levels", []):
                    level["grants"] = [s for s in level.get("grants", []) if s not in dropped]
                evolution = cls.get("evolution") or {}
                if "balanced_grants" in evolution:
                    evolution["balanced_grants"] = [
                        s for s in evolution["balanced_grants"] if s not in dropped]
        return mutate

    def test_degranting_the_last_burns_carrier_seals_every_briar(self):
        # `burns` ships two carriers and GH#429 granted the second: flame_jet
        # (mage) and kindle (hedge_witch L2). De-grant BOTH and nothing
        # learnable clears a burnable blocker any more -- every briar seals
        # whatever is behind it, and this is the arm that says so. The review
        # I-3 case, exactly.
        counts, advisories = self._run(self._degrant("flame_jet", "kindle"))
        sealed = [line for line in advisories if line.startswith("[gate carrier orphan]")]
        self.assertGreater(counts["gate carrier orphan"], 0, advisories)
        self.assertTrue(any("briar_arch_west" in line for line in sealed), sealed)

    def test_outcome_class_covers_the_shipped_outcome_vocabulary(self):
        # The WIFieldSkills.OUTCOMES mirror-contract shape (its GDScript twin is
        # test_interactions_table.gd:194). A new outcome REDS here until someone
        # classifies it, instead of being silently treated as "does not clear" --
        # which is exactly how `state_set`, and with it BOTH shipped traversal
        # seams, went missing from the first cut of this arm.
        table = self.parsed[data_lint.DATA / "interactions.json"]
        self.assertEqual(set(data_lint.OUTCOME_CLASS), {str(o) for o in table["outcomes"]})
        self.assertEqual(data_lint.CLEARING_OUTCOMES,
            {"remove_scorch", "freeze_cell", "state_set"})

    def test_degranting_rope_work_seals_the_span_stub(self):
        # `anchors x gap -> state_set`: rope_work is the only carrier, and the
        # span stub is how the trapped_halls gallery is crossed.
        _counts, advisories = self._run(self._degrant("rope_work"))
        sealed = [line for line in advisories if line.startswith("[gate carrier orphan]")]
        self.assertTrue(any("halls_span_stub" in line for line in sealed), sealed)

    def test_degranting_basic_repair_seals_the_bank_stringer(self):
        # `repairs x broken -> state_set`: basic_repair is the only carrier.
        _counts, advisories = self._run(self._degrant("basic_repair"))
        sealed = [line for line in advisories if line.startswith("[gate carrier orphan]")]
        self.assertTrue(any("riverfarm_bank_stringer" in line for line in sealed), sealed)

    def test_unknown_placement_is_reported_not_dropped(self):
        # The review's no-else finding: a computed orphan whose placement is
        # neither `entity` nor an enumerable cell class used to fall off the end
        # of the if/elif and vanish.
        def mutate(parsed, _maps):
            table = parsed[data_lint.DATA / "interactions.json"]
            table["target_properties"]["burnable"] = "somewhere_new"
            for cls in parsed[data_lint.DATA / "classes.json"]["classes"]:
                for level in cls.get("levels", []):
                    level["grants"] = [s for s in level.get("grants", [])
                        if s not in ("flame_jet", "kindle")]
        _counts, advisories = self._run(mutate)
        sealed = [line for line in advisories if line.startswith("[gate carrier orphan]")]
        self.assertTrue(any("'somewhere_new'" in line for line in sealed), sealed)

    def test_degranting_the_last_freezes_carrier_seals_the_water(self):
        # `freezes` ships two carriers and GH#429 ruling 33 granted the second:
        # icy_floor (ice_mage) and frost_touch (hedge_witch L4). Both must go
        # before the water can seal -- the burns pair's own shape.
        _counts, advisories = self._run(self._degrant("icy_floor", "frost_touch"))
        sealed = [line for line in advisories if line.startswith("[gate carrier orphan]")]
        self.assertTrue(any("carries `freezable` cells" in line for line in sealed), sealed)
        # pond_island's first mode is a `property` mode on `freezes`, so the
        # skill_gates half must light up on the same mutation.
        self.assertTrue(any("skill_gates['pond_island']" in line for line in sealed), sealed)

    def test_comment_mentioning_the_id_is_not_a_grant(self):
        # Review M-1: the read-back must not be satisfied by a comment that
        # merely names the id -- that is exactly how a deleted grant would keep
        # its allowlist row looking alive.
        self.assertFalse(data_lint._grants_on_line(
            '\t# grants "sworn_fang_boon" here', "sworn_fang_boon"))
        self.assertFalse(data_lint._grants_on_line(
            "\tvar x := sworn_fang_boon_other", "sworn_fang_boon"))
        self.assertTrue(data_lint._grants_on_line(
            '\tpc_skills.append("sworn_fang_boon")', "sworn_fang_boon"))

    def test_orphaning_an_item_is_caught(self):
        def mutate(parsed, maps):
            for map_doc in maps.values():
                for entity in map_doc.get("entities", []):
                    if isinstance(entity, dict):
                        entity.pop("contains", None)
                        entity.pop("loot", None)
                        entity.pop("item", None)
            for path in list(parsed):
                if path.parent.name == "dialogue":
                    for node in (parsed[path].get("nodes", {}) or {}).values():
                        for option in node.get("options", []):
                            option["effects"] = [e for e in option.get("effects", [])
                                if not (isinstance(e, dict) and "item" in e)]
            parsed[data_lint.DATA / "fence_stock.json"]["stock"] = []
        counts, _ = self._run(mutate)
        self.assertGreater(counts["item orphan"], 40)

    def test_stale_code_grant_row_reports_drift(self):
        advisories = []
        granted = data_lint._code_grants(
            {"no_such_content_id_anywhere": ("src/core/wi_game.gd", 1, "synthetic row")},
            "skill", advisories)
        self.assertEqual(granted, set())
        self.assertEqual(len(advisories), 1)
        self.assertIn("is granted nowhere in", advisories[0])

    def test_moved_code_grant_row_reports_a_repin(self):
        content_id, (rel, line_no, _note) = sorted(data_lint.SKILL_CODE_GRANTS.items())[0]
        advisories = []
        granted = data_lint._code_grants({content_id: (rel, line_no + 500, "moved row")},
            "skill", advisories)
        self.assertEqual(granted, {content_id})
        self.assertIn("repin the row", advisories[0])

    def test_unreachable_dialogue_node_is_caught(self):
        def mutate(parsed, _maps):
            for path in list(parsed):
                if path.parent.name != "dialogue":
                    continue
                for node in (parsed[path].get("nodes", {}) or {}).values():
                    for option in node.get("options", []):
                        option.pop("goto", None)
        counts, _ = self._run(mutate)
        self.assertGreater(counts["dialogue node orphan"], 100)

    def test_severed_door_graph_is_caught(self):
        def mutate(parsed, maps):
            for map_doc in maps.values():
                map_doc["entities"] = [entity for entity in map_doc.get("entities", [])
                    if not (isinstance(entity, dict) and (
                        "to_map" in entity or "door_when" in entity
                        or entity.get("portal_menu") or entity.get("portal_menu_when")))]
        counts, advisories = self._run(mutate)
        # Everything but the start map: the graph has no edges left at all.
        self.assertEqual(counts["map orphan"], len(self.maps) - 1)
        self.assertTrue(all("is named by no door" in line
            for line in advisories if line.startswith("[map orphan]")), advisories)

    def test_nested_door_when_transition_counts_as_an_edge(self):
        # street's sewer_grate carries its to_map/to_cell INSIDE door_when.
        # A key-path scan would miss it and call `sewers` unplayable.
        counts, _ = self._run()
        self.assertEqual(counts.get("map orphan", 0), 0)
        pairs = []
        data_lint._walk_pairs(self.maps["street"]["entities"], "to_map", "to_cell", pairs)
        self.assertIn("sewers", {row["to_map"] for row in pairs})


class TestReachabilityPromotion(unittest.TestCase):
    """GH#429 -- the promoted categories genuinely fail the run.

    `main()` is driven for real (no fixture), with ONE in-memory de-wire per
    case, so the rc contract is proved end to end rather than asserted about a
    constant. A promoted category that could not red would be a lint that
    reads like a gate and behaves like a comment.
    """

    def _main_rc(self, patch_attr=None, replacement=None):
        original = getattr(data_lint, patch_attr) if patch_attr else None
        if patch_attr:
            setattr(data_lint, patch_attr, replacement)
        argv = sys.argv
        sys.argv = ["data_lint.py"]
        try:
            with contextlib.redirect_stdout(io.StringIO()) as out, \
                    contextlib.redirect_stderr(io.StringIO()) as err:
                rc = data_lint.main()
            return rc, out.getvalue() + err.getvalue()
        finally:
            sys.argv = argv
            if patch_attr:
                setattr(data_lint, patch_attr, original)

    def test_head_tree_passes(self):
        rc, _ = self._main_rc()
        self.assertEqual(rc, 0)

    def test_promoted_categories_are_the_drained_three(self):
        # The membership IS the contract. `map orphan` and `enemy-kit only`
        # must stay OUT: both have honest "yes, deliberately" answers, and
        # promoting either would red the shipped tree on a design position.
        self.assertEqual(set(data_lint.HARD_FAIL_REACHABILITY_CATEGORIES),
            {"item orphan", "dialogue node orphan", "skill orphan"})

    def test_de_wiring_an_item_hard_fails(self):
        original = data_lint._item_sources
        rc, text = self._main_rc("_item_sources", lambda parsed, maps: {
            key: value for key, value in original(parsed, maps).items()
            if key != "solid_oak_spear"})
        self.assertEqual(rc, 1)
        self.assertIn("FAIL -- reachability [item orphan]", text)
        self.assertIn("solid_oak_spear", text)

    def test_re_orphaning_a_dialogue_node_hard_fails(self):
        original = data_lint.check_content_reachability

        def patched(parsed, maps, advisories):
            nodes = parsed[data_lint.DATA / "dialogue" / "riverfarm_hunter.json"]["nodes"]
            nodes["agreed"] = {"speaker": "A Shepherd", "text": "x", "options": []}
            return original(parsed, maps, advisories)

        rc, text = self._main_rc("check_content_reachability", patched)
        self.assertEqual(rc, 1)
        self.assertIn("FAIL -- reachability [dialogue node orphan]", text)

    def test_an_advisory_category_still_cannot_change_the_verdict(self):
        # `enemy-kit only` rows are live on HEAD (slam, raskghar_maul,
        # flame_bolt) and the run is green. That IS the proof the un-promoted
        # categories kept their tier when the third category was promoted.
        rc, text = self._main_rc()
        self.assertEqual(rc, 0)
        self.assertIn("ADVISORY -- reachability [enemy-kit only]", text)

    def test_de_granting_a_skill_hard_fails(self):
        # Ruling 33's own regression fence: with the skill arm promoted, the
        # [Firefly] finding this whole check generalizes cannot recur quietly.
        original = data_lint.check_content_reachability

        def patched(parsed, maps, advisories):
            for cls in parsed[data_lint.DATA / "classes.json"]["classes"]:
                for level in cls.get("levels", []):
                    level["grants"] = [s for s in level.get("grants", [])
                        if s != "frost_touch"]
            return original(parsed, maps, advisories)

        rc, text = self._main_rc("check_content_reachability", patched)
        self.assertEqual(rc, 1)
        self.assertIn("FAIL -- reachability [skill orphan]", text)
        self.assertIn("frost_touch", text)

    def test_a_crash_inside_the_check_can_never_promote(self):
        # The crash row carries no `[category]` prefix, so the tier's
        # "an advisory can never fail the run" contract survives promotion.
        def boom(_parsed, _maps, _advisories):
            raise RuntimeError("synthetic")

        rc, text = self._main_rc("check_content_reachability", boom)
        self.assertEqual(rc, 0)
        self.assertIn("check crashed: RuntimeError: synthetic", text)


class TestPropArmKeys(unittest.TestCase):
    """GH#424 review I-1 -- WIInteractions.PROP_ARM_KEYS held to dispatch itself.

    The const used to be a hand-copy inside the test suite, carrying hand-typed
    `# interactions.gd:NN` citations that were ALL eight stale. A comment cannot
    police a match block. This does: it re-extracts the arms from the `"prop":`
    case's own text and fails when the two disagree in either direction.
    """

    INTERACTIONS_GD = REPO_ROOT / "wandering_inn_game" / "src" / "core" / "interactions.gd"

    # Keys the `"prop":` case reads off `target` that are NOT arms -- each one
    # rides an arm rather than opening one, and each is listed with its reason
    # so growing this list is an argument, never a shrug.
    NOT_AN_ARM = {
        "sleep_toast": "copy for the sleep arm",
        "contains_when": "gate on the contains arm",
        "portal_menu_when": "gate on the portal_menu arm",
        "fence_menu_when": "gate on the fence_menu arm",
        "requires_weapon_family": "gate on the plain-interact arm",
        "requires_item": "gate on the plain-interact arm",
        "item_hint_toast": "refusal copy for those two gates",
        "once_per_waking": "rate limit on the plain-interact arm",
        "once_per_waking_toast": "copy for that rate limit",
        "skill_hint_toast": "copy for the requires_skill arm",
        "toast": "payload of the plain-interact arm",
        "lore": "payload flag of the plain-interact arm",
        "gold": "payload of the plain-interact arm",
        "item": "payload of the plain-interact arm",
        "variants": "payload resolution of the plain-interact arm",
    }
    # Arms a prop is AIMED AT through WIGame.use_skill rather than dispatched
    # to, so they never appear in the match block and cannot be extracted.
    USE_SKILL_TARGET_KEYS = {"on_skill_use", "skill_uses", "cookware", "conversation", "dialogue"}

    def _source(self):
        return self.INTERACTIONS_GD.read_text().splitlines()

    def _sole_index(self, lines, token):
        hits = [n for n, line in enumerate(lines) if line.strip() == token]
        self.assertEqual(len(hits), 1, f"{token!r} must be a unique whole-line marker, got {hits}")
        return hits[0]

    def _extracted_arms(self):
        lines = self._source()
        start = self._sole_index(lines, '"prop":')
        end = self._sole_index(lines, '"encounter":')
        self.assertLess(start, end, "the prop case must precede the encounter case")
        body = "\n".join(lines[start + 1:end])
        return set(re.findall(r'target\.(?:get|has)\(\s*"([a-z_]+)"', body))

    def _declared_keys(self):
        text = self.INTERACTIONS_GD.read_text()
        # Split on "= [" rather than the const name: `Array[String]` carries a
        # `]` of its own, and slicing on that returned an empty list -- which
        # would have made every comparison below vacuously agree.
        block = text.split("const PROP_ARM_KEYS", 1)[1].split("= [", 1)[1].split("\n]", 1)[0]
        return re.findall(r'"([a-z_]+)"', block)

    def test_every_extracted_key_is_an_arm_or_a_named_non_arm(self):
        extracted = self._extracted_arms()
        self.assertGreater(len(extracted), 20, extracted)
        unaccounted = extracted - set(self.NOT_AN_ARM) - set(self._declared_keys())
        self.assertEqual(unaccounted, set(),
            "dispatch's prop case reads key(s) that are neither declared in "
            "WIInteractions.PROP_ARM_KEYS nor named in NOT_AN_ARM -- a new arm "
            "shipped without joining the reachability predicate")

    def test_declared_const_equals_extracted_arms_plus_use_skill_targets(self):
        declared = self._declared_keys()
        self.assertEqual(len(declared), len(set(declared)), f"duplicate key in the const: {declared}")
        residual = self._extracted_arms() - set(self.NOT_AN_ARM)
        self.assertEqual(set(declared), residual | self.USE_SKILL_TARGET_KEYS,
            "WIInteractions.PROP_ARM_KEYS has drifted from dispatch's own text")
        # Pin the shape too, so a shrinking extraction cannot quietly agree with
        # a shrinking const.
        self.assertEqual(len(residual), 9, sorted(residual))

    def test_not_an_arm_rows_are_all_live(self):
        extracted = self._extracted_arms()
        stale = sorted(set(self.NOT_AN_ARM) - extracted)
        self.assertEqual(stale, [], f"NOT_AN_ARM row(s) no longer read by dispatch: {stale}")


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
