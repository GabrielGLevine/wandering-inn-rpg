"""M2 contract: the emitter unit table, the planners, and the replay self-check.

§6.1 wants the emitter tested in ISOLATION -- primitive + ledger state in,
exact step list out -- so this suite is pure: no Godot boot except the one
oracle test at the bottom that proves the sell-picker extension answers. The
table below is exhaustive over the primitive set on purpose; a primitive whose
emitted shape nobody pinned is a primitive that can drift silently.
"""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.itinerary.bridge import OracleBridge
from scripts.itinerary.detours import DetourLibrary
from scripts.itinerary.emit import Emitter
from scripts.itinerary.ledger import Ledger
from scripts.itinerary.planners.actions import ActionPlanner
from scripts.itinerary.planners.combat import CombatError, CombatPlanner
from scripts.itinerary.planners.economy import EconomyError, EconomyPlanner
from scripts.itinerary.planners.dialogue import DialogueError, DialoguePlanner
from scripts.itinerary.planners.route import RouteError, RoutePlanner
from scripts.itinerary.replay import Checkpoint, checkpoint_from, self_check
from scripts.itinerary.schema import PRIMITIVES, SchemaError, load_detour, load_itinerary


ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / "wandering_inn_game"
DETOURS = ROOT / "scripts" / "itinerary" / "detours"


def actions(steps: list[dict]) -> list[str]:
    return [str(step["action"]) for step in steps]


class SchemaTest(unittest.TestCase):
    def test_m2_unlocks_every_frozen_primitive_and_m1_still_does_not(self) -> None:
        specs = {
            "goto": "{map: inn}",
            "talk": "{npc: erin}",
            "fight": "{encounter: crate_scavengers}",
            "sleep": "{}",
            "equip": "{item: rusty_sword}",
            "unequip": "{slot: weapon}",
            "buy": "{vendor: peddler, item: trap_kit}",
            "sell": "{vendor: krshia, item: trap_kit}",
            "use_field": "{skill: basic_cleaning}",
            "interact": "{prop: krshia_stall}",
            # Added by the 2026-08-13 pre-M4 amendment, which reopened §3.2 for
            # this idiom and `fight.mode: driven` and re-froze behind them.
            "journal": "{capture: 05_journal_acts}",
            "shot": "{name: a_shot}",
            "assert": "{state: {gold: 1}}",
            "detour": "{id: inn_chore_dirty_table}",
            "raw": "{steps: [{action: wait_frames, frames: 1}]}",
        }
        self.assertEqual(set(specs), PRIMITIVES, "every frozen primitive needs an M2 acceptance row")
        with tempfile.TemporaryDirectory() as td:
            for primitive, spec in specs.items():
                path = Path(td) / f"{primitive}.yaml"
                path.write_text(
                    f"- act: ii\n  nodes:\n    - id: n1\n      {primitive}: {spec}\n      why: because the table says so\n",
                    encoding="utf-8",
                )
                document = load_itinerary(path, milestone=2)
                self.assertEqual(document.nodes[0].primitive, primitive)
                # M1's own gate is untouched: it still refuses everything it
                # refused before. The only rejection surface M2 loses is the
                # "still future" one, because M3 adds passes, not language.
                if primitive not in ("goto", "talk", "sleep"):
                    with self.assertRaisesRegex(SchemaError, "not available in M1"):
                        load_itinerary(path, milestone=1)

            # M3.6 moved this rejection one step EARLIER and made it stronger:
            # the node-key allow-list refuses `teleport:` by name before the
            # exactly-one-primitive count ever runs. Same refusal, and now it
            # also covers the case the count could never see -- a stray key
            # BESIDE a valid primitive (see the M3.6 suite's own row).
            unknown = Path(td) / "unknown.yaml"
            unknown.write_text("- act: ii\n  nodes:\n    - id: n1\n      teleport: {map: inn}\n", encoding="utf-8")
            for milestone in (1, 2):
                with self.assertRaisesRegex(SchemaError, "has unknown keys"):
                    load_itinerary(unknown, milestone=milestone)
            empty = Path(td) / "empty.yaml"
            empty.write_text("- act: ii\n  nodes:\n    - id: n1\n      why: nothing at all\n", encoding="utf-8")
            with self.assertRaisesRegex(SchemaError, "needs exactly one primitive"):
                load_itinerary(empty, milestone=2)

            typo = Path(td) / "typo.yaml"
            typo.write_text("- act: ii\n  nodes:\n    - id: n1\n      fight: {encouter: x}\n", encoding="utf-8")
            with self.assertRaisesRegex(SchemaError, "unknown keys"):
                load_itinerary(typo, milestone=2)

    def test_fight_rejects_uncompilable_shapes(self) -> None:
        cases = [
            ("fight: {encounter: x, policy: reckless}", "policy must be"),
            ("fight: {encounter: x, entry: teleport}", "entry must be"),
            ("fight: {encounter: x, expect: defeat}", "expect must be victory"),
            ("shot: {}", "shot needs name"),
            ("assert: {}", "needs state, event"),
            ("unequip: {slot: hat}", "slot must be one of"),
            ("raw: {steps: []}", "non-empty list"),
        ]
        with tempfile.TemporaryDirectory() as td:
            for index, (body, message) in enumerate(cases):
                path = Path(td) / f"c{index}.yaml"
                path.write_text(f"- act: ii\n  nodes:\n    - id: n{index}\n      {body}\n", encoding="utf-8")
                with self.assertRaisesRegex(SchemaError, message):
                    load_itinerary(path, milestone=2)


class EmitterTableTest(unittest.TestCase):
    """primitive/operation -> exact emitted step shape. The complete table."""

    def setUp(self) -> None:
        self.emitter = Emitter()

    def emit(self, operation: dict) -> list[dict]:
        return self.emitter.emit("n", [operation])

    def test_fixture_prelude_drives_the_title_to_continue(self) -> None:
        steps = self.emit({"kind": "fixture_prelude", "map": "street", "cell": [1, 3]})
        self.assertEqual(actions(steps), [
            "wait_for_event", "press", "wait_for_event", "move", "press",
            "wait_for_event", "wait_for_event", "assert_state", "assert_state",
        ])
        self.assertEqual(steps[0]["type"], "ui_title_gate_rendered")
        self.assertEqual(steps[3], {"action": "move", "direction": "down", "steps": 1, "_itin": "n"})
        self.assertEqual(steps[5]["type"], "game_loaded")
        self.assertEqual(steps[-1], {"action": "assert_state", "path": "player_cell", "equals": [1, 3], "_itin": "n"})

    def test_fight_interact_entry_full_shape(self) -> None:
        steps = self.emit({
            "kind": "fight", "entry": "interact", "encounter": "crate_scavengers",
            "allies": ["klbkch"], "shots": ["01_fight"], "policy": "competent", "max_turns": 300,
            "victory_pins": [{"path": "accomplishments.victories", "equals": 1},
                             {"path": "removed_entities", "contains": "crate_scavengers"}],
        })
        self.assertEqual(actions(steps), [
            "press", "wait_for_event", "wait_for_event", "assert_state", "wait_for_event",
            "screenshot", "combat_autoplay", "wait_for_event", "press", "wait_for_event",
            "wait_frames", "assert_state", "assert_state",
        ])
        self.assertEqual(steps[0], {"action": "press", "name": "interact", "_itin": "n"})
        self.assertEqual(steps[1]["type"], "combat_started")
        self.assertEqual(steps[2]["type"], "ui_combat_shown")
        self.assertEqual(steps[3]["path"], "combat.combatants.klbkch.side")
        self.assertEqual(steps[4], {"action": "wait_for_event", "type": "turn_started",
                                    "payload_contains": {"id": "pc"}, "timeout_sec": 10, "_itin": "n"})
        self.assertEqual(steps[6], {"action": "combat_autoplay", "max_turns": 300, "policy": "competent", "_itin": "n"})
        self.assertEqual(steps[7], {"action": "wait_for_event", "type": "combat_finished",
                                    "payload_contains": {"victory": True}, "timeout_sec": 20, "_itin": "n"})
        self.assertEqual(steps[8], {"action": "press", "name": "confirm", "_itin": "n"})
        self.assertEqual(steps[9]["type"], "ui_combat_hidden")
        self.assertEqual(steps[11]["path"], "accomplishments.victories")
        self.assertEqual(steps[12], {"action": "assert_state", "path": "removed_entities",
                                     "contains": "crate_scavengers", "_itin": "n"})
        # `victories`, never `won_combat`: the latter deposits fractionally.
        self.assertNotIn("accomplishments.won_combat", [s.get("path") for s in steps])

    def test_fight_proximity_entry_presses_nothing(self) -> None:
        steps = self.emit({
            "kind": "fight", "entry": "proximity", "encounter": "goblin_encounter_1",
            "allies": [], "shots": [], "policy": "competent", "max_turns": 300, "victory_pins": [],
        })
        self.assertEqual(actions(steps)[0], "wait_for_event")
        self.assertEqual(steps[0]["type"], "combat_started")

    def test_purchase_orders_money_before_the_item(self) -> None:
        steps = self.emit({"kind": "purchase", "price": 3, "item": "trap_kit",
                           "conversation": "peddler_stall", "total": 4})
        self.assertEqual([s["type"] for s in steps], ["gold_changed", "toast", "item_gained"])
        self.assertEqual(steps[0]["payload_contains"], {"delta": -3, "source": "peddler_stall", "total": 4})
        self.assertEqual(steps[1]["payload_contains"], {"text": "Paid 3 gold."})
        self.assertEqual(steps[2]["payload_contains"], {"item": "trap_kit"})

    def test_purchase_drops_total_when_the_interval_is_open(self) -> None:
        steps = self.emit({"kind": "purchase", "price": 3, "item": "trap_kit",
                           "conversation": "peddler_stall", "total": None})
        self.assertEqual(steps[0]["payload_contains"], {"delta": -3, "source": "peddler_stall"})

    def test_sale_removes_then_pays(self) -> None:
        steps = self.emit({"kind": "sale", "price": 2, "item": "traveler_charm",
                           "conversation": "krshia_sell", "total": 4})
        self.assertEqual([s["type"] for s in steps], ["item_lost", "gold_changed", "toast"])
        self.assertEqual(steps[0]["payload_contains"], {"item": "traveler_charm", "source": "krshia_sell"})
        self.assertEqual(steps[1]["payload_contains"], {"delta": 2, "source": "krshia_sell", "total": 4})
        self.assertEqual(steps[2]["payload_contains"], {"text": "Earned 2 gold."})

    def test_sell_open_waits_the_code_built_graph(self) -> None:
        steps = self.emit({"kind": "sell_open", "conversation": "krshia_sell", "entity": "krshia"})
        self.assertEqual([s["type"] for s in steps], ["dialogue_started", "dialogue_node", "ui_dialogue_shown"])
        self.assertEqual(steps[0]["payload_contains"], {"conversation": "krshia_sell", "entity": "krshia"})

    def test_equip_cycle(self) -> None:
        steps = self.emitter.emit("n", [
            {"kind": "inventory_open"},
            {"kind": "inventory_cursor", "cursor_index": 1, "item": "relcs_spare_spear"},
            {"kind": "inventory_equip", "item": "relcs_spare_spear", "slot": "weapon"},
            {"kind": "inventory_close"},
        ])
        self.assertEqual(actions(steps), [
            "press", "wait_for_event", "move", "wait_for_event",
            "press", "wait_for_event", "assert_state", "press", "wait_for_event",
        ])
        self.assertEqual(steps[0], {"action": "press", "name": "inventory", "_itin": "n"})
        self.assertEqual(steps[3]["payload_contains"], {"cursor": 1, "item": "relcs_spare_spear"})
        self.assertEqual(steps[5]["payload_contains"], {"item": "relcs_spare_spear", "slot": "weapon"})
        self.assertEqual(steps[6], {"action": "assert_state", "path": "equipped.weapon",
                                    "equals": "relcs_spare_spear", "_itin": "n"})
        self.assertEqual(steps[8]["type"], "ui_inventory_hidden")

    def test_unequip_proves_the_slot_by_state(self) -> None:
        steps = self.emit({"kind": "inventory_unequip", "slot": "weapon"})
        # item_unequipped carries only {slot}, so the state assert is the proof.
        self.assertEqual(steps[1]["payload_contains"], {"slot": "weapon"})
        self.assertEqual(steps[2], {"action": "assert_state", "path": "equipped.weapon", "equals": "", "_itin": "n"})

    def test_field_skill_uses_press_field_skill_not_a_hotbar_digit(self) -> None:
        steps = self.emit({"kind": "field_skill", "skill": "basic_cleaning",
                           "target": "dirty_table", "accomplishment": "cleaned_the_inn"})
        self.assertEqual(actions(steps), ["press_field_skill", "wait_for_event", "wait_for_event", "wait_for_event"])
        self.assertEqual(steps[0], {"action": "press_field_skill", "skill": "basic_cleaning", "_itin": "n"})
        self.assertEqual(steps[1]["payload_contains"], {"skill": "basic_cleaning", "target": "dirty_table"})
        self.assertEqual(steps[2]["payload_contains"], {"id": "cleaned_the_inn"})
        self.assertEqual(steps[3]["type"], "ui_toast_rendered")

    def test_field_skill_self_targeted_carries_exploration_context(self) -> None:
        steps = self.emit({"kind": "field_skill", "skill": "double_step", "target": "", "accomplishment": ""})
        self.assertEqual(steps[1]["payload_contains"], {"skill": "double_step", "context": "exploration"})

    def test_prop_interact(self) -> None:
        steps = self.emit({"kind": "prop_interact", "accomplishment": "browsed_market",
                           "count": 1, "toast": "The Gnoll who keeps the stall..."})
        self.assertEqual(actions(steps), ["press", "wait_for_event", "wait_for_event", "wait_for_event"])
        self.assertEqual(steps[1]["payload_contains"], {"id": "browsed_market", "count": 1})
        self.assertEqual(steps[2]["payload_contains"], {"text": "The Gnoll who keeps the stall..."})

    def test_shot_takes_only_a_name(self) -> None:
        steps = self.emit({"kind": "shot", "name": "01_beat"})
        self.assertEqual(steps, [{"action": "screenshot", "name": "01_beat", "_itin": "n"}])

    def test_assert_shapes(self) -> None:
        self.assertEqual(
            self.emit({"kind": "assert_state", "path": "gold", "equals": 4}),
            [{"action": "assert_state", "path": "gold", "equals": 4, "_itin": "n"}],
        )
        self.assertEqual(
            self.emit({"kind": "assert_state", "path": "removed_entities", "contains": "x"}),
            [{"action": "assert_state", "path": "removed_entities", "contains": "x", "_itin": "n"}],
        )
        self.assertEqual(
            self.emit({"kind": "assert_event", "type": "accomplishment_recorded", "payload_contains": {"id": "x"}}),
            [{"action": "assert_event_logged", "type": "accomplishment_recorded",
              "payload_contains": {"id": "x"}, "_itin": "n"}],
        )
        self.assertEqual(
            self.emit({"kind": "assert_event_absent", "type": "combat_started", "payload_contains": {}}),
            [{"action": "assert_event_absent", "type": "combat_started", "_itin": "n"}],
        )

    def test_raw_passes_through_stamped(self) -> None:
        steps = self.emit({"kind": "raw", "steps": [{"action": "wait_frames", "frames": 3}], "note": "RAW: because"})
        self.assertEqual(steps, [{"action": "wait_frames", "frames": 3, "_itin": "n", "_comment": "RAW: because"}])

    def test_deferred_destination_splits_the_choose(self) -> None:
        node = {"speaker": "Peddler", "text": "Sold."}
        deferred = self.emit({"kind": "dialogue_choose", "cursor_index": 2, "destination": "bought",
                              "end": False, "next_node": node, "why": "w", "defer_destination": True})
        self.assertEqual(actions(deferred), ["move", "press"])
        wait = self.emit({"kind": "dialogue_node_wait", "next_node": node})
        self.assertEqual(wait[0]["payload_contains"], node)

    def test_operation_may_carry_its_own_provenance_stamp(self) -> None:
        steps = self.emitter.emit("act2.buy", [{"kind": "shot", "name": "s", "itin": "detour.chore.wipe"}])
        self.assertEqual(steps[0]["_itin"], "detour.chore.wipe")

    # -- the M1 rows, carried into the table so it is exhaustive over the ---
    # -- whole operation vocabulary rather than only over M2's additions. ---

    def test_walk_passes_the_oracle_steps_through_unchanged(self) -> None:
        steps = self.emit({"kind": "walk", "steps": [{"action": "move", "direction": "right", "steps": 12}]})
        self.assertEqual(steps, [{"action": "move", "direction": "right", "steps": 12, "_itin": "n"}])

    def test_face_target_is_a_single_blocked_bump(self) -> None:
        steps = self.emit({"kind": "face_target", "direction": "up"})
        self.assertEqual(steps, [{"action": "move", "direction": "up", "steps": 1, "_bump": True, "_itin": "n"}])

    def test_door_transition_pins_both_halves_of_the_arrival(self) -> None:
        steps = self.emit({"kind": "transition", "map": "floodplains", "cell": [7, 6]})
        self.assertEqual(actions(steps), ["press", "wait_for_event", "assert_state", "assert_state"])
        self.assertEqual(steps[0], {"action": "press", "name": "interact", "_itin": "n"})
        self.assertEqual(steps[1]["payload_contains"], {"map": "floodplains", "cell": [7, 6]})
        self.assertEqual(steps[2]["equals"], "floodplains")
        self.assertEqual(steps[3]["equals"], [7, 6])

    def test_portal_transition_counts_the_menu_from_one(self) -> None:
        first = self.emit({"kind": "portal_transition", "entity": "anchor", "menu_index": 1,
                           "map": "invrisil_boulevard", "cell": [4, 4]})
        # Row one is already under the cursor: no move.
        self.assertEqual(actions(first), [
            "press", "wait_for_event", "wait_for_event", "wait_for_event",
            "press", "wait_for_event", "wait_for_event", "assert_state", "assert_state",
        ])
        third = self.emit({"kind": "portal_transition", "entity": "anchor", "menu_index": 3,
                           "map": "invrisil_boulevard", "cell": [4, 4]})
        self.assertEqual(third[4], {"action": "move", "direction": "down", "steps": 2, "_itin": "n"})

    def test_pool_line_settles_before_the_next_press(self) -> None:
        steps = self.emit({"kind": "pool_line", "speaker": "Krshia"})
        self.assertEqual(actions(steps), ["press", "wait_for_event", "wait_for_event", "wait_frames"])
        self.assertEqual(steps[1]["type"], "dialogue_line")
        self.assertEqual(steps[1]["payload_contains"], {"speaker": "Krshia"})
        # A press inside a closing panel's teardown frames is silently eaten.
        self.assertEqual(steps[3], {"action": "wait_frames", "frames": 30, "_itin": "n"})

    def test_dialogue_open_waits_the_node_before_the_panel(self) -> None:
        steps = self.emit({"kind": "dialogue_open", "conversation": "krshia_crate", "entity": "krshia"})
        self.assertEqual([s.get("type") for s in steps[1:]],
                         ["dialogue_started", "dialogue_node", "ui_dialogue_shown"])

    def test_dialogue_choose_stamps_the_fork_reason(self) -> None:
        steps = self.emit({"kind": "dialogue_choose", "cursor_index": 0, "destination": "",
                           "end": True, "next_node": {}, "why": "keep the fee"})
        self.assertEqual(steps[0]["_comment"], "CHOICE: keep the fee")
        self.assertEqual([s.get("type") for s in steps[1:3]], ["dialogue_ended", "ui_dialogue_hidden"])
        self.assertEqual(steps[3]["frames"], 30)

    def test_sleep_without_a_merge_asserts_no_merge_happened(self) -> None:
        steps = self.emit({"kind": "sleep", "merge": None, "preview": {
            "classes_after": {}, "class_gains": [], "level_ups": [], "consolidation": {}}})
        self.assertEqual(actions(steps), ["press", "wait_for_event", "wait_for_event",
                                          "assert_event_absent", "assert_state"])
        self.assertEqual(steps[1]["payload_contains"], {"slept": True})
        # #472: the retired `pending_consolidation` pin meant "no merge is
        # QUEUED"; this says the stronger thing -- none HAPPENED.
        self.assertEqual(steps[3], {"action": "assert_event_absent",
                                    "type": "consolidation_accepted", "_itin": "n"})

    def test_sleep_with_levels_and_an_automatic_merge(self) -> None:
        steps = self.emit({"kind": "sleep", "merge": {"target": "spearmaster", "level": 14},
            "preview": {
                "classes_after": {"spearmaster": 14}, "class_gains": ["mage"],
                "level_ups": [{"class": "warrior", "level": 5}],
                "consolidation": {"target": "spearmaster", "level": 14, "parents": ["warrior", "spearman"]}}})
        types = [s.get("type") for s in steps if s["action"] == "wait_for_event"]
        # The merge event lands INSIDE the sleep beat, so it precedes the veil --
        # and wait_for_event's cursor is forward-only, so this list IS the
        # beat-order pin. No prompt events survive; there is no modal.
        self.assertEqual(types, [
            "phase_changed", "class_gained", "class_level_up", "consolidation_accepted",
            "ui_sleep_veil_rendered", "ui_sleep_veil_finished",
        ])
        self.assertEqual([s for s in steps if s["action"] == "press"], [steps[0]])
        self.assertEqual(steps[-1], {"action": "assert_state", "path": "classes",
                                     "equals": {"spearmaster": 14}, "_itin": "n"})


class FakeBridge:
    """Answers exactly what the M2 planners ask, and nothing more."""

    def __init__(self, answers: dict[str, dict]) -> None:
        self.answers = answers
        self.asked: list[str] = []

    def query(self, query: str, ledger: Ledger | None = None) -> dict:
        self.asked.append(query)
        for prefix, answer in self.answers.items():
            if query.startswith(prefix):
                return answer
        raise AssertionError(f"unexpected query: {query}")


class CombatPlannerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.bridge = FakeBridge({
            "path street": {
                "reachable": True, "target_blocked": True,
                "cells": [[13, 3], [13, 15], [12, 15]],
                "approach": {"cell": [12, 15], "driver_steps": [{"action": "move", "direction": "down", "steps": 12}],
                             "bump": "down"},
            },
        })
        self.route = RoutePlanner(PROJECT, self.bridge)
        self.planner = CombatPlanner(PROJECT, self.bridge, self.route)
        self.ledger = Ledger.fresh()
        self.ledger.set_position("street", [13, 3], [0, 1])
        self.ledger.accomplishment("chatted_with_klbkch")

    def test_plans_the_crate_fight_with_its_ally_and_loot_interval(self) -> None:
        ops = self.planner.plan("n", {"encounter": "crate_scavengers", "at": "street"}, self.ledger)
        fight = ops[-1]
        self.assertEqual(fight["kind"], "fight")
        self.assertEqual(fight["allies"], ["klbkch"], "ally_requires is met, so Klbkch fields")
        self.assertEqual(fight["policy"], "competent")
        # loot is {gold: 2, chance: 0.5} -> the interval parts, it does not add 2.
        self.assertEqual(self.ledger.gold_interval, (0, 2))
        self.assertEqual(self.ledger.rng_epoch, 1)
        self.assertIn("crate_scavengers", self.ledger.state["removed_entities"])
        pins = {pin["path"] for pin in fight["victory_pins"]}
        self.assertIn("accomplishments.victories", pins)
        self.assertIn("accomplishments.recovered_crate_force", pins)
        self.assertIn("removed_entities", pins)

    def test_unmet_ally_gate_empties_the_roster(self) -> None:
        self.ledger.state["accomplishments"].pop("chatted_with_klbkch")
        ops = self.planner.plan("n", {"encounter": "crate_scavengers", "at": "street"}, self.ledger)
        self.assertEqual(ops[-1]["allies"], [])

    def test_refuses_to_refight_a_removed_encounter(self) -> None:
        self.planner.plan("n", {"encounter": "crate_scavengers", "at": "street"}, self.ledger)
        with self.assertRaisesRegex(CombatError, "already removed"):
            self.planner.plan("n2", {"encounter": "crate_scavengers", "at": "street"}, self.ledger)


class ProximityTest(unittest.TestCase):
    """The hazard that turned a compiled run into a mid-walk fight."""

    def setUp(self) -> None:
        # A straight walk north from the Liscor gate, straight through
        # goblin_encounter_1's radius-2 ring around (30, 23).
        self.cells = [[31, 25], [31, 24], [31, 23], [31, 22], [31, 21], [31, 20]]
        self.bridge = FakeBridge({"path floodplains": {
            "reachable": True, "target_blocked": False, "cells": self.cells,
            "driver_steps": [{"action": "move", "direction": "up", "steps": 5}],
        }})
        self.route = RoutePlanner(PROJECT, self.bridge)
        self.ledger = Ledger.fresh()
        self.ledger.set_position("floodplains", [31, 25], [0, -1])

    def test_a_route_that_clips_an_ambush_is_refused_at_compile_time(self) -> None:
        with self.assertRaisesRegex(RouteError, "goblin_encounter_1"):
            self.route.plan_to("n", self.ledger, "floodplains", [31, 20])

    def test_standing_inside_the_radius_is_not_itself_a_trigger(self) -> None:
        # The gate DROPS the player at (31, 25), already within Chebyshev 2 of
        # (30, 23). Transitions do not run the proximity check, so arriving is
        # safe; only a completed move springs it.
        self.assertEqual(self.route._chebyshev([31, 25], [30, 23]), 2)
        self.assertIsNone(self.route._first_trigger([[31, 25]], self.route.proximity_hazards("floodplains", self.ledger)))

    def test_trigger_walk_stops_one_cell_short_and_hands_back_the_step(self) -> None:
        entity = self.route.find_entity("goblin_encounter_1", "floodplains")[1]
        self.bridge.answers["path floodplains"]["cells"] = [[31, 25], [31, 24], [31, 23]]
        ops, direction = self.route.plan_trigger_walk("n", self.ledger, entity)
        self.assertEqual(direction, "up")
        # (31,24) is the first in-radius cell, so the emitted walk is empty and
        # the single step in is the trigger.
        self.assertEqual(ops, [])
        self.assertEqual(self.ledger.cell, [31, 24])
        self.assertEqual(self.ledger.facing, [0, -1])

    def test_night_gated_ambushes_are_not_treated_as_always_live(self) -> None:
        hazards = {str(e["id"]) for e in self.route.proximity_hazards("floodplains", self.ledger)}
        self.assertIn("goblin_encounter_1", hazards)
        self.assertNotIn("goblin_night_patrol", hazards, "present_when/encounter_when gates are not modelled")
        self.assertNotIn("road_mothbears", hazards)

    def test_a_removed_encounter_stops_being_a_hazard(self) -> None:
        self.ledger.state["removed_entities"].append("goblin_encounter_1")
        self.assertEqual(self.route.proximity_hazards("floodplains", self.ledger), [])


class DetourLibraryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.library = DetourLibrary(DETOURS)
        self.ledger = Ledger.fresh()

    def test_the_shipped_detour_parses_with_the_act_node_grammar(self) -> None:
        detour = self.library.get("inn_chore_dirty_table")
        self.assertEqual((detour.entry_map, detour.exit_map), ("inn", "inn"))
        self.assertEqual(detour.earns, (1, 1))
        self.assertEqual([node.id for node in detour.nodes],
                         ["detour.inn_chore_dirty_table.approach", "detour.inn_chore_dirty_table.wipe"])
        self.assertEqual([node.primitive for node in detour.nodes], ["goto", "use_field"])

    def test_match_needs_a_CERTAIN_earn_not_a_hopeful_one(self) -> None:
        self.assertIsNotNone(self.library.match(self.ledger, 1, set()))
        self.assertIsNone(self.library.match(self.ledger, 2, set()),
                          "earns.min is 1, so a 2-coin shortfall is not certainly closed")
        # The shipped detour pays a flat coin, so min == max and it cannot tell
        # the two matching rules apart. This one can: a detour worth 1-to-5
        # MIGHT cover a 3-coin gap and is therefore not allowed to claim it --
        # matching on earns.max would leave the purchase unaffordable in
        # exactly the world the interval exists to warn about.
        with tempfile.TemporaryDirectory() as td:
            (Path(td) / "wide_spread.yaml").write_text(
                "id: wide_spread\nwhy: a synthetic contract whose payout is a range, not a coin\n"
                "entry: {map: inn}\nexit: {map: inn}\nearns: {min: 1, max: 5}\n"
                "nodes:\n  - id: step\n    shot: {name: s}\n",
                encoding="utf-8",
            )
            library = DetourLibrary(td)
            self.assertIsNotNone(library.match(self.ledger, 1, set()))
            self.assertIsNone(library.match(self.ledger, 3, set()),
                              "3 is inside [1, 5] but only guaranteed by earns.max -- not good enough")

    def test_forbids_retires_a_spent_detour(self) -> None:
        self.ledger.accomplishment("cleaned_the_inn")
        self.assertIsNone(self.library.match(self.ledger, 1, set()))

    def test_an_already_used_detour_is_not_offered_twice(self) -> None:
        self.assertIsNone(self.library.match(self.ledger, 1, {"inn_chore_dirty_table"}))

    def test_cheapest_sufficient_detour_wins(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            for name, earn in (("cheap_one", 1), ("rich_one", 5)):
                (Path(td) / f"{name}.yaml").write_text(
                    f"id: {name}\nwhy: a synthetic contract for the matcher test\n"
                    f"entry: {{map: inn}}\nexit: {{map: inn}}\nearns: {{min: {earn}, max: {earn}}}\n"
                    "nodes:\n  - id: step\n    shot: {name: s}\n",
                    encoding="utf-8",
                )
            library = DetourLibrary(td)
            self.assertEqual(library.match(self.ledger, 1, set()).id, "cheap_one")
            self.assertEqual(library.match(self.ledger, 3, set()).id, "rich_one")

    def test_a_detour_without_a_why_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "silent.yaml"
            path.write_text(
                "id: silent\nentry: {map: inn}\nexit: {map: inn}\nearns: {min: 1, max: 1}\n"
                "nodes:\n  - id: step\n    shot: {name: s}\n",
                encoding="utf-8",
            )
            with self.assertRaisesRegex(SchemaError, "needs a why"):
                load_detour(path)


class EconomyPlannerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.bridge = FakeBridge({})
        self.route = RoutePlanner(PROJECT, self.bridge)
        self.dialogue = DialoguePlanner(PROJECT, self.bridge, self.route)
        self.planner = EconomyPlanner(PROJECT, self.bridge, self.route, self.dialogue, DetourLibrary(DETOURS))
        self.ledger = Ledger.fresh()

    def test_asking_price_takes_the_DEAREST_row_for_the_item(self) -> None:
        # Krshia lists the charm twice: 5 base, 4 at friend's price. The
        # affordability bar has to be the one the run might actually pay.
        self.assertEqual(self.planner._asking_price("n", "krshia_crate", "traveler_charm"), 5)

    def test_no_matching_detour_names_the_shortfall_and_the_candidates(self) -> None:
        self.planner.plan_node = lambda node, ledger: []
        with self.assertRaisesRegex(EconomyError, "asks 20 gold, the ledger guarantees only 0"):
            self.planner._earn_detour("n", self.ledger, 20, 20, "watch_issue_gambeson")

    def test_sell_refuses_worn_gear(self) -> None:
        self.ledger.state["inventory"].append("leather_jerkin")
        self.ledger.equip("armor", "leather_jerkin")
        with self.assertRaisesRegex(EconomyError, "equipped"):
            self.planner.plan_sell("n", {"vendor": "krshia", "item": "leather_jerkin",
                                         "choose_path": ["Buying?", "Sell:"]}, "w", self.ledger)

    def test_sell_reads_its_price_off_the_row_the_game_rendered(self) -> None:
        self.bridge.answers["visible_options krshia_sell"] = {"options": [
            {"cursor_index": 0, "text": "Sell: Leather Jerkin. (+12 gold)"},
            {"cursor_index": 1, "text": "Never mind."},
        ]}
        row = self.planner._sell_row("n", "krshia_sell", self.ledger, "Leather Jerkin", "leather_jerkin")
        self.assertEqual((row["cursor_index"], row["price"]), (0, 12))

    def test_transaction_splices_at_the_BUYING_row_not_the_closing_one(self) -> None:
        ops = [
            {"kind": "dialogue_open", "conversation": "peddler_stall", "entity": "peddler"},
            {"kind": "dialogue_choose", "cursor_index": 2, "destination": "bought", "end": False,
             "next_node": {"speaker": "Peddler"}, "gold_delta": -3, "grants": ["trap_kit"]},
            {"kind": "dialogue_choose", "cursor_index": 1, "destination": "", "end": True,
             "next_node": {}, "gold_delta": 0, "grants": []},
        ]
        spliced = self.planner._splice_transaction("n", ops, "trap_kit", {"kind": "purchase"})
        self.assertEqual([op["kind"] for op in spliced], [
            "dialogue_open", "dialogue_choose", "purchase", "dialogue_node_wait", "dialogue_choose",
        ])
        self.assertTrue(spliced[1]["defer_destination"])


class ActionPlannerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.bridge = FakeBridge({"inventory": {"items": [
            {"cursor_index": 0, "id": "rusty_sword", "slot": ""},
            {"cursor_index": 1, "id": "relcs_spare_spear", "slot": ""},
        ]}})
        self.route = RoutePlanner(PROJECT, self.bridge)
        self.planner = ActionPlanner(PROJECT, self.bridge, self.route)
        self.ledger = Ledger.fresh()
        self.ledger.state["inventory"] = ["rusty_sword", "relcs_spare_spear"]

    def test_equip_slot_comes_from_the_item_kind_not_the_empty_slot_field(self) -> None:
        ops = self.planner.plan_equip("n", {"item": "relcs_spare_spear"}, self.ledger)
        self.assertEqual([op["kind"] for op in ops],
                         ["inventory_open", "inventory_cursor", "inventory_equip", "inventory_close"])
        self.assertEqual(ops[2]["slot"], "weapon")
        self.assertEqual(self.ledger.state["equipped"]["weapon"], "relcs_spare_spear")

    def test_equipping_what_is_already_worn_is_refused_because_confirm_TOGGLES(self) -> None:
        with self.assertRaisesRegex(Exception, "already worn"):
            self.planner.plan_equip("n", {"item": "rusty_sword"}, self.ledger)

    def test_interact_refuses_a_skill_gated_prop(self) -> None:
        with self.assertRaisesRegex(Exception, "skill-gated"):
            self.planner.plan_interact("n", {"prop": "dirty_table", "at": "inn"}, self.ledger)


class ReplaySelfCheckTest(unittest.TestCase):
    """§6.2. Red first, then green -- an always-green checker proves nothing."""

    def setUp(self) -> None:
        self.start = Checkpoint("itinerary.start", "start", "inn", [2, 3], [1, 0], (0, 0), {}, {}, {}, [], [])
        self.after = Checkpoint("n1", "goto", "inn", [7, 3], [1, 0], (0, 0), {}, {}, {}, [], [])
        self.steps = [
            {"action": "move", "direction": "right", "steps": 5, "_itin": "n1"},
            {"action": "assert_state", "path": "player_cell", "equals": [7, 3], "_itin": "n1"},
        ]

    def test_green_when_the_walk_lands_where_the_ledger_says(self) -> None:
        self.assertEqual(self_check(self.steps, [self.start, self.after], self.start), [])

    def test_red_when_the_emitted_walk_and_the_ledger_disagree(self) -> None:
        steps = [dict(self.steps[0], steps=4), self.steps[1]]
        problems = self_check(steps, [self.start, self.after], self.start)
        self.assertTrue(any("replayed cell [6, 3]" in p for p in problems), problems)

    def test_red_when_a_position_pin_contradicts_the_walk(self) -> None:
        steps = [self.steps[0], dict(self.steps[1], equals=[9, 3])]
        problems = self_check(steps, [self.start, self.after], self.start)
        self.assertTrue(any("pins player_cell=[9, 3]" in p for p in problems), problems)

    def test_red_when_a_conversation_is_left_open(self) -> None:
        checkpoint = Checkpoint("n1", "talk", "inn", [2, 3], [1, 0], (0, 0), {}, {}, {}, [], [])
        steps = [
            {"action": "press", "name": "interact", "_itin": "n1"},
            {"action": "wait_for_event", "type": "dialogue_started", "_itin": "n1"},
            {"action": "wait_for_event", "type": "dialogue_node", "_itin": "n1"},
            {"action": "wait_for_event", "type": "ui_dialogue_shown", "_itin": "n1"},
        ]
        problems = self_check(steps, [self.start, checkpoint], self.start)
        self.assertTrue(any("still open" in p for p in problems), problems)

    def test_red_when_ui_dialogue_shown_is_waited_before_the_node(self) -> None:
        checkpoint = Checkpoint("n1", "talk", "inn", [2, 3], [1, 0], (0, 0), {}, {}, {}, [], [])
        steps = [
            {"action": "wait_for_event", "type": "dialogue_started", "_itin": "n1"},
            {"action": "wait_for_event", "type": "ui_dialogue_shown", "_itin": "n1"},
            {"action": "wait_for_event", "type": "dialogue_ended", "_itin": "n1"},
        ]
        problems = self_check(steps, [self.start, checkpoint], self.start)
        self.assertTrue(any("before the node's own dialogue_node" in p for p in problems), problems)

    def test_red_when_a_gold_pin_falls_outside_the_interval(self) -> None:
        checkpoint = Checkpoint("n1", "buy", "inn", [2, 3], [1, 0], (2, 4), {}, {}, {}, [], [])
        steps = [{"action": "assert_state", "path": "gold", "equals": 9, "_itin": "n1"}]
        problems = self_check(steps, [self.start, checkpoint], self.start)
        self.assertTrue(any("outside the ledger interval [2, 4]" in p for p in problems), problems)
        ok = [{"action": "assert_state", "path": "gold", "equals": 3, "_itin": "n1"}]
        self.assertEqual(self_check(ok, [self.start, checkpoint], self.start), [])

    def test_red_when_autoplay_runs_outside_a_fight(self) -> None:
        checkpoint = Checkpoint("n1", "fight", "inn", [2, 3], [1, 0], (0, 0), {}, {}, {}, [], [])
        steps = [{"action": "combat_autoplay", "max_turns": 300, "policy": "competent", "_itin": "n1"}]
        problems = self_check(steps, [self.start, checkpoint], self.start)
        self.assertTrue(any("outside a live combat" in p for p in problems), problems)

    def test_red_on_an_unstamped_step(self) -> None:
        problems = self_check([{"action": "wait_frames", "frames": 1}], [self.start], self.start)
        self.assertTrue(any("no _itin stamp" in p for p in problems), problems)

    def test_a_trailing_bump_is_the_one_allowed_discrepancy(self) -> None:
        after = Checkpoint("n1", "talk", "inn", [7, 3], [0, -1], (0, 0), {}, {}, {}, [], [])
        steps = [
            {"action": "move", "direction": "right", "steps": 5, "_itin": "n1"},
            {"action": "move", "direction": "up", "steps": 1, "_itin": "n1"},
        ]
        self.assertEqual(self_check(steps, [self.start, after], self.start), [])


class LedgerTest(unittest.TestCase):
    def test_a_chance_gated_drop_parts_the_interval_and_gold_follows_the_floor(self) -> None:
        ledger = Ledger.fresh()
        ledger.shift_gold(2)
        ledger.apply_victory({"id": "e", "on_victory": [], "loot": [{"gold": 2, "chance": 0.5}]}, (0, 2))
        self.assertEqual(ledger.gold_interval, (2, 4))
        self.assertFalse(ledger.gold_certain)
        # Every oracle question downstream is asked under the poorest world.
        self.assertEqual(ledger.materialize_save()["state"]["gold"], 2)

    def test_won_combat_is_never_banked_and_leaves_a_pending_pin(self) -> None:
        ledger = Ledger.fresh()
        ledger.apply_victory({"id": "goblin_encounter_1", "on_victory": ["won_combat", "sign_defended"]}, (0, 0))
        self.assertEqual(ledger.state["accomplishments"].get("won_combat"), None)
        self.assertEqual(ledger.state["accomplishments"]["sign_defended"], 1)
        self.assertEqual(ledger.state["accomplishments"]["victories"], 1)
        self.assertEqual([p["counter"] for p in ledger.pins_pending], ["won_combat"])

    def test_a_respawning_encounter_goes_dormant_rather_than_removed(self) -> None:
        ledger = Ledger.fresh()
        ledger.apply_victory({"id": "rock_crab_nest", "on_victory": [], "respawns": True}, (0, 0))
        self.assertEqual(ledger.state["dormant_encounters"], ["rock_crab_nest"])
        self.assertEqual(ledger.state["removed_entities"], [])


class OracleSellGraphTest(unittest.TestCase):
    """The one additive oracle change, proven against the real game."""

    def test_visible_options_answers_the_code_built_sell_picker(self) -> None:
        import json

        ledger = Ledger.fresh()
        ledger.state["inventory"] = ["rusty_sword", "leather_jerkin"]
        oracle = OracleBridge(PROJECT)
        with tempfile.TemporaryDirectory() as td:
            save = Path(td) / "state.json"
            save.write_text(json.dumps(ledger.materialize_save()), encoding="utf-8")
            answers = oracle.batch([
                {"query": "visible_options krshia_sell hub", "save": str(save)},
                {"query": "state current_map"},
            ])
        rows = [str(row["text"]) for row in answers[0]["options"]]
        # leather_jerkin is priced 24 and unworn, so it sells at floor(24*0.5).
        self.assertIn("Sell: Leather Jerkin. (+12 gold)", rows)
        self.assertEqual(rows[-1], "Never mind.")
        self.assertEqual(answers[0]["speaker"], "Krshia")
        self.assertEqual(answers[0]["graph"], "krshia_sell")
        # The pre-existing query still answers exactly as before.
        self.assertEqual(answers[1]["value"], "inn")


if __name__ == "__main__":
    unittest.main()
