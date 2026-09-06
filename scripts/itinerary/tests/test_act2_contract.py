"""#434 Act II contract: the rules that took Act II (shipped steps 218-558)
to GOLDEN PASS and the compiled Act I-II script to a green headless run.

Each test names the corpus row or runtime failure it stands on. Two of the
rules exist because the DIFFER cannot see them (a compiled-only claim is
"tighter" by policy, so a WRONG compiled-only claim never reds the diff):
the class-gained render pinned before the veil, and the whole-dict class pin.
"""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.itinerary import goldens  # noqa: E402
from scripts.itinerary.emit import Emitter  # noqa: E402
from scripts.itinerary.goldens import diff  # noqa: E402
from scripts.itinerary.ledger import Ledger  # noqa: E402
from scripts.itinerary.planners.dialogue import DialoguePlanner  # noqa: E402
from scripts.itinerary.planners.sleep import SleepPlanner, TREMOR_QUEST, TREMOR_TOAST  # noqa: E402
from scripts.itinerary.schema import SchemaError, load_itinerary  # noqa: E402
from scripts.itinerary.tests.pipeline import FakeOracle, Pipeline, act, bare  # noqa: E402

PROJECT = ROOT / "wandering_inn_game"


def document(body: str):
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "itin.yaml"
        path.write_text(body, encoding="utf-8")
        return load_itinerary(path, milestone=3)


def fight_node(shots: str) -> str:
    return (
        "- act: ii\n  nodes:\n    - id: n\n      fight:\n        encounter: crate_scavengers\n"
        f"        at: street\n        entry: interact\n{shots}"
    )


class ApproachShotTest(unittest.TestCase):
    """steel_thread 377-383: the south-square shot lands with the PC facing
    the encounter and the board not yet open; the mage-kit shot on turn one."""

    def operation(self, **changes) -> dict:
        operation = {
            "kind": "fight", "entry": "interact", "encounter": "crate_scavengers", "allies": [],
            "shots": ["turn_shot"], "approach_shots": ["approach_shot"], "policy": "competent",
            "max_turns": 300, "victory_pins": [], "turn_wait": True, "beats": {}, "arena": "",
            "banks_after_dismiss": [],
        }
        operation.update(changes)
        return operation

    def test_approach_shot_precedes_the_entry_press_and_turn_shot_follows_the_turn(self) -> None:
        steps = bare(Emitter().emit("n", [self.operation()]))
        names = [(s["action"], s.get("name") or s.get("type")) for s in steps]
        self.assertEqual(names[:2], [("screenshot", "approach_shot"), ("press", "interact")])
        turn = names.index(("wait_for_event", "turn_started"))
        self.assertEqual(names[turn + 1], ("screenshot", "turn_shot"))

    def test_schema_splits_the_album_by_slot(self) -> None:
        node = document(fight_node("        shots: {approach: [a], turn: [b]}\n")).nodes[0]
        self.assertEqual(node.spec["shots"], {"approach": ["a"], "turn": ["b"]})
        with self.assertRaisesRegex(SchemaError, "slots must be among"):
            document(fight_node("        shots: {before: [a]}\n"))
        # MUTATION: a proximity board has no stand cell to shoot from.
        with self.assertRaisesRegex(SchemaError, "needs entry: interact"):
            document(fight_node("        shots: {approach: [a]}\n").replace("entry: interact", "entry: proximity"))


class MergedBumpTest(unittest.TestCase):
    """steel_thread 376: `right 2` walks one cell and bumps the encounter."""

    def test_same_direction_overshoot_is_discounted_when_it_reconciles(self) -> None:
        compiled = [{"action": "move", "direction": "right", "steps": 1},
                    {"action": "move", "direction": "right", "steps": 1, "_bump": True}]
        shipped = [{"action": "move", "direction": "right", "steps": 2}]
        self.assertEqual(goldens._strip_mirrored_bump(compiled, shipped), [{"action": "move", "direction": "right", "steps": 1}])

    def test_a_walk_that_already_faces_the_target_is_not_discounted(self) -> None:
        """steel_thread 396: `up 10` ends ON Krshia's stand cell; the compiled
        bump adds nothing, so discounting would hide a one-cell drift."""
        compiled = [{"action": "move", "direction": "up", "steps": 10},
                    {"action": "move", "direction": "up", "steps": 1, "_bump": True}]
        shipped = [{"action": "move", "direction": "up", "steps": 10}]
        self.assertEqual(goldens._strip_mirrored_bump(compiled, shipped), shipped)

    def test_a_different_direction_is_never_discounted(self) -> None:
        compiled = [{"action": "move", "direction": "right", "steps": 1},
                    {"action": "move", "direction": "up", "steps": 1, "_bump": True}]
        shipped = [{"action": "move", "direction": "right", "steps": 2}]
        self.assertEqual(goldens._strip_mirrored_bump(compiled, shipped), shipped)


def spine(*keys: str) -> list[dict]:
    return [{"action": "wait_for_event", "type": key} for key in keys]


class AlignmentTest(unittest.TestCase):
    """difflib's longest-block matcher re-paired Selys' delivery with Olesm's
    brief the moment an arrival pin was inserted between them. The LCS pays
    exactly one row per insertion."""

    def test_an_insertion_leaves_every_other_row_paired(self) -> None:
        shipped = spine("a", "b", "c", "d", "e", "f", "g", "h")
        compiled = shipped[:4] + [{"action": "assert_state", "path": "player_cell", "equals": [1, 1]}] + shipped[4:]
        opcodes = goldens._align([goldens._key(s) for s in compiled], [goldens._key(s) for s in shipped])
        paired = sum(hi - lo for tag, lo, hi, _, _ in opcodes if tag == "equal")
        self.assertEqual(paired, len(shipped))
        self.assertEqual([tag for tag, *_ in opcodes], ["equal", "delete", "equal"])

    def test_a_named_shot_outweighs_a_run_of_presses(self) -> None:
        shot = {"action": "screenshot", "name": "s"}
        press = {"action": "press", "name": "confirm"}
        compiled = [shot, press, press]
        shipped = [press, press, shot]
        opcodes = goldens._align([goldens._key(s) for s in compiled], [goldens._key(s) for s in shipped])
        equal = [(c_lo, s_lo) for tag, c_lo, _, s_lo, _ in opcodes if tag == "equal"]
        self.assertEqual(equal, [(0, 2)])

    def test_from_start_is_delivery_not_a_different_claim(self) -> None:
        """steel_thread 143: the corpus pins the class-gained RENDER with
        from_start because it races the veil (v0.15: never pin toast order)."""
        ordered = {"steps": [{"action": "wait_for_event", "type": "ui_toast_rendered", "payload_contains": {"text": "t"}}]}
        anytime = {"steps": [{"action": "wait_for_event", "type": "ui_toast_rendered", "payload_contains": {"text": "t"}, "from_start": True}]}
        self.assertTrue(diff(ordered, anytime).passed)
        self.assertTrue(diff(anytime, ordered).passed)


class SleepOrderTest(unittest.TestCase):
    """The compiled Act I-II run timed out at step 161 waiting for the veil:
    the render wait sat BEFORE the veil wait and the veil fires first."""

    def emit(self, **changes) -> list[dict]:
        operation = {"kind": "sleep", "merge": None, "preview": {
            "classes_after": {"warrior": 3, "mage": 1}, "class_gains": ["mage"], "level_ups": [], "consolidation": {}},
            "class_gained_toasts": {"mage": "[Mage] class gained! — [Frost Bolt]"}}
        operation.update(changes)
        return bare(Emitter().emit("n", [operation]))

    def test_render_and_level_pins_follow_the_veil(self) -> None:
        steps = self.emit()
        types = [s.get("type") or s.get("path") for s in steps if s["action"] in ("wait_for_event", "assert_state")]
        self.assertEqual(types, ["phase_changed", "class_gained", "toast", "ui_sleep_veil_rendered", "ui_toast_rendered", "classes.mage"])
        rendered = next(s for s in steps if s.get("type") == "ui_toast_rendered")
        self.assertTrue(rendered["from_start"])

    def test_plain_sleep_never_pins_the_whole_class_dict(self) -> None:
        """Warrior slept 1 -> 3 on combat counters the ledger does not model;
        the corpus pins `classes.mage` alone (steel_thread 296)."""
        self.assertNotIn("classes", [s.get("path") for s in self.emit()])
        merged = self.emit(merge={"target": "spearmaster", "level": 14}, preview={
            "classes_after": {"spearmaster": 14}, "class_gains": [], "level_ups": [],
            "consolidation": {"target": "spearmaster", "level": 14, "parents": ["warrior", "spearman"]}})
        self.assertEqual(merged[-1]["path"], "classes")

    def test_tremor_pointer_lands_in_beat_order_before_the_veil(self) -> None:
        """steel_thread 555-558 / sleep_beat.gd _maybe_fire_tremor_pointer."""
        steps = self.emit(tremor_pointer=True)
        types = [s.get("type") for s in steps if s["action"] == "wait_for_event"]
        self.assertEqual(types[:6], ["phase_changed", "class_gained", "toast", "accomplishment_recorded", "quest_started", "toast"])
        pointer = [s for s in steps if s.get("type") in ("accomplishment_recorded", "quest_started")]
        self.assertEqual(pointer[0]["payload_contains"], {"id": "watch_runner_pointed", "count": 1})
        self.assertEqual(pointer[1]["payload_contains"], {"id": TREMOR_QUEST})
        self.assertEqual([s for s in steps if s.get("type") == "toast"][1]["payload_contains"], {"text": TREMOR_TOAST})
        self.assertLess(types.index("quest_started"), types.index("ui_sleep_veil_rendered"))


class SleepPlannerLedgerTest(unittest.TestCase):
    def test_the_preview_banks_the_pointer_and_starts_its_quest(self) -> None:
        preview = {"class_gains": [], "level_ups": [], "classes_after": {"warrior": 3, "mage": 3}, "consolidation": {},
                   "reached_two_classes": True, "tremor_pointer": True}
        ledger = Ledger.fresh()
        ops = SleepPlanner(FakeOracle(preview=preview), PROJECT).plan("n", {}, ledger)
        self.assertTrue(ops[0]["tremor_pointer"])
        self.assertEqual(ledger.state["accomplishments"]["watch_runner_pointed"], 1)
        self.assertEqual(ledger.state["accomplishments"]["reached_two_classes"], 1)
        self.assertIn(TREMOR_QUEST, ledger.state["started_quests"])
        # MUTATION: a preview without the pointer plans a quiet night.
        quiet = dict(preview, tremor_pointer=False)
        ops = SleepPlanner(FakeOracle(preview=quiet), PROJECT).plan("n", {}, Ledger.fresh())
        self.assertFalse(ops[0]["tremor_pointer"])


class ExplicitCellGotoTest(unittest.TestCase):
    """steel_thread 477: the corpus pins (13,3) on the way to the grate."""

    def test_a_goto_that_names_a_walkable_cell_pins_its_arrival(self) -> None:
        pipeline = Pipeline(FakeOracle())
        pipeline.ledger.set_position("street", [1, 3])
        steps = pipeline.run(act("    - id: n\n      goto: {map: street, cell: [13, 3]}\n", "ii"))
        self.assertEqual(steps[-1], {"action": "assert_state", "path": "player_cell", "equals": [13, 3]})
        self.assertEqual(steps[:-1], [{"action": "move", "direction": "right", "steps": 12}])

    def test_a_blocked_target_keeps_its_single_stand_pin(self) -> None:
        pipeline = Pipeline(FakeOracle(blocked={(13, 2)}))
        pipeline.ledger.set_position("street", [13, 4])
        steps = pipeline.run(act("    - id: n\n      goto: {map: street, cell: [13, 2]}\n", "ii"))
        pins = [s for s in steps if s["action"] == "assert_state"]
        self.assertEqual(pins, [{"action": "assert_state", "path": "player_cell", "equals": [13, 3]}])


class GrantToastTest(unittest.TestCase):
    """steel_thread 173: `pickup()` voices every grant as "Got: <name>"."""

    def test_the_planner_knows_item_names(self) -> None:
        planner = DialoguePlanner(PROJECT, FakeOracle(), None)
        self.assertEqual(planner.item_names["relcs_spare_spear"], "Relc's Spare Spear")


if __name__ == "__main__":
    unittest.main()
