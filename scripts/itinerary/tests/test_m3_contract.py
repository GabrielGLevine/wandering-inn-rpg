"""M3 contract: two-pass refine, the provenance failure loop, golden tolerance.

Every check here is a MUTATION PROOF in the lane's sense: the assertion is
paired with a deliberate break that makes it red, so a test that would pass
against a gutted implementation does not count. The three subjects are the
three things M3 adds -- harvest/refine, failure-to-node mapping, and the
tolerance classifier that decides whether a recompile still tells the same
story as the script it is meant to reproduce.

These are pure-python: they run against recorded event fixtures and hand-built
step lists, no Godot boot. The LIVE half of M3 -- probe run, refine, re-run,
fixed point -- is a lane gate, not a unit test, because it costs four headless
runs and its evidence is the quoted transcript.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.itinerary.goldens import diff  # noqa: E402
from scripts.itinerary.harvest import Harvest, HarvestError, harvest_from  # noqa: E402
from scripts.itinerary.ledger import CHALLENGE_WEIGHTED, Ledger  # noqa: E402
from scripts.itinerary.provenance import Failure, explain, map_failures, parse_failure  # noqa: E402
from scripts.itinerary.refine import RefineError, Refiner  # noqa: E402
from scripts.itinerary.schema import Node, load_itinerary  # noqa: E402


def probe(label: str, gold: int, accomplishments: dict[str, int] | None = None) -> dict:
    return {
        "type": "qa_state_dump",
        "payload": {
            "label": label,
            "step": 0,
            "snapshot": {"gold": gold, "accomplishments": dict(accomplishments or {})},
        },
    }


def node(node_id: str, primitive: str = "fight", spec: dict | None = None) -> Node:
    return Node(node_id, primitive, spec or {"encounter": "goblins"}, "because", "i", "act.yaml", 12)


class HarvestTest(unittest.TestCase):
    def test_windows_close_at_the_probe_that_names_them(self) -> None:
        events = [
            {"type": "combat_started", "payload": {}},
            probe("a.fight", 4, {"victories": 1}),
            {"type": "gold_changed", "payload": {"delta": -3, "source": "peddler_stall", "total": 1}},
            probe("a.buy", 1, {"victories": 1}),
        ]
        got = harvest_from(events)
        self.assertEqual(got.order, ["a.fight", "a.buy"])
        # The window that CLOSES at a probe is that node's run: the combat
        # belongs to the fight, the money to the purchase.
        self.assertEqual([e["type"] for e in got.require("a.fight").events], ["combat_started"])
        self.assertEqual([e["type"] for e in got.require("a.buy").events], ["gold_changed"])
        self.assertEqual(got.require("a.buy").gold, 1)
        self.assertEqual(got.before("a.buy").node, "a.fight")
        self.assertIsNone(got.before("a.fight"))

        # MUTATION: two runs concatenated would silently double a node's
        # window and hand pass 2 the wrong reading.
        with self.assertRaisesRegex(HarvestError, "probed twice"):
            harvest_from(events + [probe("a.fight", 99, {})])
        # MUTATION: a ship-mode log carries no probes at all.
        with self.assertRaisesRegex(HarvestError, "PROBE build"):
            harvest_from([{"type": "gold_changed", "payload": {}}]).require("a.fight")


class RefineTest(unittest.TestCase):
    def _ledger(self, gold: tuple[int, int]) -> Ledger:
        ledger = Ledger.fresh()
        ledger.gold_interval = gold
        ledger.state["gold"] = gold[0]
        return ledger

    def test_pending_counter_is_pinned_from_the_harvest(self) -> None:
        self.assertIn("won_combat", CHALLENGE_WEIGHTED)
        harvest = harvest_from([probe("a.prev", 2, {}), probe("a.fight", 2, {"won_combat": 2})])
        ledger = self._ledger((2, 2))
        ledger.pins_pending.append({"counter": "won_combat", "encounter": "goblins", "reason": "weighted"})
        ops = [{"kind": "fight", "victory_pins": [{"path": "accomplishments.victories", "equals": 1}]}]
        refiner = Refiner(harvest)
        refiner.after_node(node("a.fight"), ledger, ops, 0)

        self.assertIn({"path": "accomplishments.won_combat", "equals": 2}, ops[0]["victory_pins"])
        self.assertEqual(ledger.state["accomplishments"]["won_combat"], 2)
        self.assertEqual(refiner.report.resolved_count, 1)
        self.assertTrue(refiner.report.resolutions[0].queued)
        self.assertEqual(ledger.pins_pending[0]["harvested"], 2)

        # MUTATION: a fractional deposit that never reached a whole unit must
        # NOT be pinned -- assert_state on a missing key reds on "path not
        # found", so a zero pin would turn a correct run red.
        harvest_zero = harvest_from([probe("a.prev", 2, {}), probe("a.fight", 2, {})])
        ledger_zero = self._ledger((2, 2))
        ledger_zero.pins_pending.append({"counter": "won_combat", "encounter": "goblins", "reason": "weighted"})
        ops_zero = [{"kind": "fight", "victory_pins": []}]
        report_zero = Refiner(harvest_zero)
        report_zero.after_node(node("a.fight"), ledger_zero, ops_zero, 0)
        self.assertEqual(ops_zero[0]["victory_pins"], [])
        self.assertEqual(report_zero.report.pinned_count, 0)
        self.assertEqual(report_zero.report.resolved_count, 1)

    def test_an_unqueued_deposit_is_pinned_and_reported_as_a_modelling_gap(self) -> None:
        """The Act II finding: a quest close banks won_combat with no fight."""
        harvest = harvest_from([probe("a.fight", 4, {"won_combat": 0}), probe("a.report", 4, {"won_combat": 1})])
        ledger = self._ledger((4, 4))
        ops: list[dict] = [{"kind": "dialogue_choose", "cursor_index": 0}]
        refiner = Refiner(harvest)
        refiner.after_node(node("a.report", "talk", {"npc": "krshia"}), ledger, ops, 0)

        # No fight in the node, so the pin lands as a plain state assert.
        self.assertEqual(ops[-1], {"kind": "assert_state", "path": "accomplishments.won_combat", "equals": 1})
        self.assertFalse(refiner.report.resolutions[0].queued)
        self.assertIn("resolution-path grant", refiner.report.resolutions[0].describe())

        # MUTATION: an UNCHANGED counter must not be pinned at every node --
        # that would bury the beat that actually moved under 2500 asserts.
        quiet = harvest_from([probe("a.report", 4, {"won_combat": 1}), probe("a.next", 4, {"won_combat": 1})])
        quiet_ops: list[dict] = []
        Refiner(quiet).after_node(node("a.next", "goto", {"map": "inn"}), self._ledger((4, 4)), quiet_ops, 0)
        self.assertEqual(quiet_ops, [])

    def test_gold_is_read_as_truth_but_never_re_decides_the_plan(self) -> None:
        harvest = harvest_from([probe("a.buy", 4, {})])
        ledger = self._ledger((2, 6))
        ops = [{"kind": "purchase", "price": 3, "item": "trap_kit", "conversation": "peddler_stall", "total": None}]
        refiner = Refiner(harvest)
        refiner.after_node(node("a.buy", "buy", {"item": "trap_kit"}), ledger, ops, 0)

        # state.gold is what the materialized save (and so every downstream
        # oracle answer) carries: the truth.
        self.assertEqual(ledger.state["gold"], 4)
        # gold_interval is the DECISION variable and stays projected, so pass 2
        # cannot silently drop an earn-detour pass 1 spliced in and invalidate
        # the very run it is refining from.
        self.assertEqual(ledger.gold_interval, (2, 6))

    def test_a_projection_that_does_not_bracket_reality_is_a_planner_bug(self) -> None:
        harvest = harvest_from([probe("a.buy", 40, {})])
        with self.assertRaisesRegex(RefineError, "outside the ledger's projected interval"):
            Refiner(harvest).after_node(node("a.buy", "buy"), self._ledger((2, 6)), [], 0)

    def test_a_stale_harvest_is_refused_rather_than_partly_applied(self) -> None:
        with self.assertRaisesRegex(RefineError, "STALE harvest"):
            Refiner(harvest_from([probe("other", 1, {})])).after_node(node("a.buy", "buy"), self._ledger((1, 1)), [], 0)

    def test_total_is_filled_from_the_transaction_not_the_node_boundary(self) -> None:
        events = [
            {"type": "gold_changed", "payload": {"delta": -3, "source": "peddler_stall", "total": 4}},
            {"type": "gold_changed", "payload": {"delta": 5, "source": "board_bounty", "total": 9}},
            probe("a.buy", 9, {}),
        ]
        ledger = self._ledger((0, 20))
        ops = [{"kind": "purchase", "price": 3, "item": "trap_kit", "conversation": "peddler_stall", "total": None}]
        Refiner(harvest_from(events)).after_node(node("a.buy", "buy"), ledger, ops, 0)
        # 4 (the purchase's own total), NOT 9 (where the node happened to end).
        self.assertEqual(ops[0]["total"], 4)

        # MUTATION: an ambiguous match is left unpinned rather than guessed.
        twice = [
            {"type": "gold_changed", "payload": {"delta": -3, "source": "peddler_stall", "total": 4}},
            {"type": "gold_changed", "payload": {"delta": -3, "source": "peddler_stall", "total": 1}},
            probe("a.buy", 1, {}),
        ]
        ops2 = [{"kind": "purchase", "price": 3, "item": "trap_kit", "conversation": "peddler_stall", "total": None}]
        refiner2 = Refiner(harvest_from(twice))
        refiner2.after_node(node("a.buy", "buy"), self._ledger((0, 20)), ops2, 0)
        self.assertIsNone(ops2[0]["total"])
        self.assertTrue(any("left unpinned rather than guessed" in row for row in refiner2.report.notes))

    def test_an_unnecessary_detour_is_flagged_and_not_removed(self) -> None:
        harvest = harvest_from([probe("a.prev", 6, {}), probe("a.buy", 3, {})])
        refiner = Refiner(harvest)
        refiner.review_detours([{"node": "a.buy", "detour": "inn_chore_dirty_table", "asking": 3, "floor": 2, "item": "trap_kit"}])
        self.assertTrue(any("DETOUR/UNNECESSARY" in note for note in refiner.report.notes))

        # MUTATION: a detour the run genuinely needed must NOT be flagged.
        lean = Refiner(harvest_from([probe("a.prev", 1, {}), probe("a.buy", 1, {})]))
        lean.review_detours([{"node": "a.buy", "detour": "inn_chore_dirty_table", "asking": 3, "floor": 1, "item": "trap_kit"}])
        self.assertEqual([note for note in lean.report.notes if "DETOUR" in note], [])


class ProvenanceTest(unittest.TestCase):
    STEPS = [
        {"_itin": "a.goto", "action": "move", "direction": "up", "steps": 2},
        {"_itin": "a.talk", "action": "press", "name": "interact"},
        {"_itin": "a.talk", "action": "wait_for_event", "type": "dialogue_node"},
        {"_itin": "ghost", "action": "press", "name": "confirm"},
    ]
    NODES = [
        Node("a.goto", "goto", {"map": "inn"}, "", "i", "act.yaml", 3),
        Node("a.talk", "talk", {"npc": "erin"}, "Erin's errand is the act's other thread", "i", "act.yaml", 7),
    ]

    def test_a_failure_maps_to_its_node_primitive_planner_and_line(self) -> None:
        failure = 'timed out waiting for dialogue_node | state={"step": 2, "map": "inn"}'
        message, index = parse_failure(failure)
        self.assertEqual(index, 2)
        self.assertEqual(message, "timed out waiting for dialogue_node")

        mapped = map_failures(self.STEPS, self.NODES, [failure])[0]
        self.assertTrue(mapped.mapped)
        rendered = mapped.render()
        for expected in ("a.talk", "(talk)", "planner    dialogue", "act.yaml:7", "Erin's errand", "step 3/4"):
            self.assertIn(expected, rendered)

        # MUTATION: strip the _itin stamps and the report must SAY it cannot
        # map, never quietly attribute the red to the wrong node.
        stripped = [{k: v for k, v in step.items() if k != "_itin"} for step in self.STEPS]
        blind = map_failures(stripped, self.NODES, [failure])[0]
        self.assertFalse(blind.mapped)
        self.assertIn("UNMAPPED", blind.render())

    def test_a_stamp_no_itinerary_declares_is_reported_not_invented(self) -> None:
        failure = 'assert_state: path not found | state={"step": 3}'
        mapped = map_failures(self.STEPS, self.NODES, [failure])[0]
        self.assertFalse(mapped.mapped)
        self.assertIn("hand-patched", mapped.render())

    def test_a_failure_with_no_state_suffix_still_reports_the_driver_line(self) -> None:
        mapped = map_failures(self.STEPS, self.NODES, ["could not parse qa script: x.json"])[0]
        self.assertIsNone(mapped.step_index)
        self.assertIn("could not parse qa script", mapped.render())
        self.assertIn("step ?", mapped.render())

    def test_explain_reports_green_and_red_differently(self) -> None:
        green = explain({"steps": self.STEPS}, self.NODES, {"failures": []})
        self.assertIn("GREEN", green)
        red = explain(
            {"steps": self.STEPS}, self.NODES,
            {"failures": ['boom | state={"step": 2}'], "steps_run": 3, "steps_total": 4, "aborted": True},
        )
        self.assertIn("ITINERARY RUN RED", red)
        self.assertIn("fail-fast", red)


class GoldenToleranceTest(unittest.TestCase):
    SHIPPED = {
        "starts_at_title": True,
        "steps": [
            {"action": "move", "direction": "down", "steps": 3},
            {"action": "press", "name": "interact"},
            {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": "erin_errand"}, "timeout_sec": 5},
            {"action": "wait_frames", "frames": 30},
            {"action": "screenshot", "name": "02_inn"},
            {"action": "assert_state", "path": "gold", "equals": 4},
        ],
    }

    def _compiled(self, **changes) -> dict:
        steps = json.loads(json.dumps(self.SHIPPED["steps"]))
        for step in steps:
            step["_itin"] = "a.talk"
        script = {"starts_at_title": True, "steps": steps}
        script.update(changes)
        return script

    def test_split_walks_timeouts_comments_and_stamps_are_tolerance(self) -> None:
        compiled = self._compiled()
        compiled["steps"][0] = {"_itin": "a.talk", "action": "move", "direction": "down", "steps": 1}
        compiled["steps"].insert(1, {"_itin": "a.talk", "action": "move", "direction": "down", "steps": 2})
        compiled["steps"][3]["timeout_sec"] = 20
        compiled["steps"][3]["_comment"] = "CHOICE: because the spine needs the coin"
        report = diff(compiled, self.SHIPPED)
        self.assertTrue(report.passed, report.render())
        self.assertTrue(report.tolerance)

    def test_a_press_spelled_cursor_move_equals_a_move_step(self) -> None:
        """`press move_down` x3 and `move down steps:3` reach the same row."""
        shipped = json.loads(json.dumps(self.SHIPPED))
        shipped["steps"][0:1] = [{"action": "press", "name": "move_down"}] * 3
        report = diff(self._compiled(), shipped)
        self.assertTrue(report.passed, report.render())

    def test_a_different_arrival_is_fatal_even_though_routes_are_tolerant(self) -> None:
        compiled = self._compiled()
        compiled["steps"][0]["steps"] = 4
        report = diff(compiled, self.SHIPPED)
        self.assertFalse(report.passed)
        self.assertTrue(any("different place" in row for row in report.net))

    def test_a_tighter_pin_passes_and_a_looser_one_fails(self) -> None:
        tighter = self._compiled()
        tighter["steps"][2]["payload_contains"]["entity"] = "erin"
        tighter["steps"].append({"_itin": "a.talk", "action": "assert_state", "path": "current_map", "equals": "inn"})
        report = diff(tighter, self.SHIPPED)
        self.assertTrue(report.passed, report.render())
        self.assertEqual(len(report.tighter), 2)

        looser = self._compiled()
        looser["steps"][2]["payload_contains"] = {}
        self.assertFalse(diff(looser, self.SHIPPED).passed)

    def test_a_dropped_claim_and_a_changed_claim_are_both_fatal(self) -> None:
        dropped = self._compiled()
        del dropped["steps"][5]
        report = diff(dropped, self.SHIPPED)
        self.assertFalse(report.passed)
        self.assertTrue(any("compiler dropped this claim" in row for row in report.exact))

        changed = self._compiled()
        changed["steps"][4]["name"] = "02_inn_but_different"
        self.assertFalse(diff(changed, self.SHIPPED).passed)

        root = self._compiled(starts_at_title=False)
        self.assertFalse(diff(root, self.SHIPPED).passed)

    def test_the_shipped_acts_are_their_own_goldens(self) -> None:
        """A script always reproduces itself -- the classifier's zero point."""
        for name in ("act1", "act2"):
            shipped = json.loads((ROOT / f"scripts/itinerary/generated/{name}.json").read_text(encoding="utf-8"))
            report = diff(shipped, shipped)
            self.assertTrue(report.passed, f"{name}: {report.render()}")
            self.assertEqual(report.exact, [])


class NodeSourceLineTest(unittest.TestCase):
    def test_every_shipped_act_node_carries_the_line_that_declares_it(self) -> None:
        for name in ("act1", "act2"):
            document = load_itinerary(ROOT / f"scripts/itinerary/{name}.yaml", milestone=3)
            for entry in document.nodes:
                self.assertGreater(entry.source_line, 0, f"{name}:{entry.id} has no source line")
                self.assertTrue(entry.source_file.endswith(f"{name}.yaml"))
            text = (ROOT / f"scripts/itinerary/{name}.yaml").read_text(encoding="utf-8").splitlines()
            for entry in document.nodes:
                self.assertIn(entry.id, text[entry.source_line - 1])


if __name__ == "__main__":
    unittest.main()
