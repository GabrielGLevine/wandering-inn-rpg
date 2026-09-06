"""#434 Act III contract: the rules that took Act III (shipped steps 559-772)
to GOLDEN PASS with the compiled Act I-III script green headless at seed 37.

Each test names the corpus row it stands on. The stand-cell-on-both-sides
rule and its two differ companions (last-of-run pairing, post-pin bump
discount) exist because the corpus pins a bump from either side: 413 pins
BEFORE the bump, 591-593 and 622-624 pin on BOTH sides, 663 merges the bump
into the walk and pins AFTER.
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
from scripts.itinerary.goldens import diff, parse_slice, slice_diff  # noqa: E402
from scripts.itinerary.ledger import Ledger  # noqa: E402
from scripts.itinerary.planners.sleep import SleepPlanner  # noqa: E402
from scripts.itinerary.schema import SchemaError, load_itinerary  # noqa: E402
from scripts.itinerary.tests.pipeline import FakeOracle, Pipeline, act, bare  # noqa: E402

PROJECT = ROOT / "wandering_inn_game"


def document(body: str):
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "itin.yaml"
        path.write_text(body, encoding="utf-8")
        return load_itinerary(path, milestone=3)


def move(direction: str, steps: int = 1, bump: bool = False) -> dict:
    step = {"action": "move", "direction": direction, "steps": steps}
    if bump:
        step["_bump"] = True
    return step


PIN = {"action": "assert_state", "path": "player_cell", "equals": [5, 15]}
PRESS = {"action": "press", "name": "interact"}


class GatedDoorTest(unittest.TestCase):
    """steel_thread 623-629: bump the fissure, shoot it, press, the door's
    open_toast, then map_changed."""

    def test_door_shot_and_open_toast_land_around_the_press(self) -> None:
        pipeline = Pipeline(FakeOracle(blocked={(8, 12)}))
        pipeline.ledger.set_position("sewers", [8, 11])
        pipeline.ledger.accomplishment("heard_the_deep_tremor")
        steps = pipeline.run(act("    - id: n\n      goto: {map: deep_tunnels, door_shot: fissure_lip}\n", "iii"))
        kinds = [s.get("type") or f"{s['action']}:{s.get('name', '')}" for s in steps]
        shot = kinds.index("screenshot:fissure_lip")
        self.assertEqual(kinds[shot + 1], "press:interact")
        self.assertEqual(kinds[shot + 2], "toast")
        self.assertTrue(steps[shot + 2]["payload_contains"]["text"].startswith("You lower yourself into the fissure."))
        self.assertEqual(kinds[shot + 3], "map_changed")
        # The bump precedes the shot: the PC stands on the lip facing down.
        self.assertEqual(steps[shot - 1], {"action": "assert_state", "path": "player_cell", "equals": [8, 11]})
        self.assertTrue(steps[shot - 2].get("_bump"))

    def test_door_shot_needs_a_door(self) -> None:
        pipeline = Pipeline(FakeOracle())
        pipeline.ledger.set_position("street", [1, 3])
        with self.assertRaisesRegex(Exception, "crosses no door"):
            pipeline.run(act("    - id: n\n      goto: {map: street, cell: [5, 3], door_shot: x}\n", "iii"))


class FightVocabularyTest(unittest.TestCase):
    def test_open_shot_needs_a_dialogue_entry(self) -> None:
        body = ("- act: iii\n  nodes:\n    - id: n\n      why: veto\n      fight:\n        encounter: awakened_boss\n"
                "        entry: {entry}\n        npc: awakened_boss\n        choose_path: [a]\n        open_shot: veto\n")
        self.assertEqual(document(body.format(entry="dialogue")).nodes[0].spec["open_shot"], "veto")
        with self.assertRaisesRegex(SchemaError, "needs entry: dialogue"):
            document(body.format(entry="interact").replace("        npc: awakened_boss\n        choose_path: [a]\n", ""))

    def test_the_board_closes_where_it_opened(self) -> None:
        """steel_thread 659-660 and 702: current_map and player_cell after the teardown."""
        operation = {
            "kind": "fight", "entry": "interact", "encounter": "raskghar_scouts", "allies": [],
            "shots": [], "approach_shots": [], "policy": "competent", "max_turns": 200, "victory_pins": [],
            "turn_wait": False, "beats": {}, "arena": "", "banks_after_dismiss": [],
            "map": "deep_tunnels", "cell": [8, 3],
        }
        steps = bare(Emitter().emit("n", [operation]))
        self.assertEqual(steps[-2:], [
            {"action": "assert_state", "path": "current_map", "equals": "deep_tunnels"},
            {"action": "assert_state", "path": "player_cell", "equals": [8, 3]},
        ])
        self.assertNotIn("turn_started", [s.get("type") for s in steps])


class DialogueStatePinTest(unittest.TestCase):
    """steel_thread 742: `accomplishments.raskghar_sealed == 1` lands after the
    teardown of the CLOSING row, not between the seal row and its node."""

    GRAPH = {"start": "hub", "nodes": {
        "hub": {"speaker": "Tester", "text": "Well?", "options": [
            {"text": "It's done.", "goto": "seal", "effects": [{"accomplishment": "sealed_test"}]},
        ]},
        "seal": {"speaker": "Tester", "text": "Good.", "options": [{"text": "Captain.", "end": True}]},
    }}
    ROWS = {
        "tester_graph:hub": {"speaker": "Tester", "text": "Well?", "options": [
            {"text": "It's done.", "goto": "seal", "cursor_index": 0, "authored_index": 0}]},
        "tester_graph:seal": {"speaker": "Tester", "text": "Good.", "options": [
            {"text": "Captain.", "cursor_index": 0, "authored_index": 0, "end": True}]},
    }

    def test_the_pin_follows_the_whole_conversation(self) -> None:
        pipeline = Pipeline(FakeOracle(blocked={(9, 6)}, options=self.ROWS))
        pipeline.ledger.set_position("floodplains", [9, 5], [0, 1])
        pipeline.inject_npc("floodplains", {"id": "tester", "kind": "npc", "cell": [9, 6], "display_name": "Tester", "conversation": "tester_graph"}, self.GRAPH)
        steps = pipeline.run(act("    - id: t\n      why: the seal\n      talk: {npc: tester, at: floodplains, choose_path: [\"It's done.\", Captain.]}\n", "iii"))
        self.assertEqual(steps[-1], {"action": "assert_state", "path": "accomplishments.sealed_test", "equals": 1})
        kinds = [s.get("type") or s["action"] for s in steps]
        self.assertLess(kinds.index("ui_dialogue_hidden"), len(kinds) - 1)
        self.assertEqual(kinds.count("assert_state"), 1 + kinds[:kinds.index("dialogue_started")].count("assert_state"))


class PostSealSleepTest(unittest.TestCase):
    """steel_thread 768-770: the first sleep after the seal banks post_game."""

    def test_preview_banks_and_emitter_pins_post_game_before_the_veil(self) -> None:
        preview = {"class_gains": [], "level_ups": [], "classes_after": {"warrior": 8, "mage": 4}, "consolidation": {}, "post_game": True}
        ledger = Ledger.fresh()
        ops = SleepPlanner(FakeOracle(preview=preview), PROJECT).plan("n", {}, ledger)
        self.assertTrue(ops[0]["post_game"])
        self.assertEqual(ledger.state["accomplishments"]["post_game"], 1)
        steps = bare(Emitter().emit("n", ops))
        kinds = [s.get("type") or s.get("path") for s in steps if s["action"] in ("wait_for_event", "assert_state")]
        self.assertEqual(kinds[:4], ["phase_changed", "accomplishment_recorded", "accomplishments.post_game", "ui_sleep_veil_rendered"])
        quiet = SleepPlanner(FakeOracle(preview=dict(preview, post_game=False)), PROJECT).plan("n", {}, Ledger.fresh())
        self.assertFalse(quiet[0]["post_game"])


class BumpSidesTest(unittest.TestCase):
    """The compiler pins the stand cell on both sides of its bump; the corpus
    pins from whichever side it likes."""

    def test_corpus_pins_before_the_bump(self) -> None:
        """steel_thread 413-415: pin, bump, press."""
        compiled = {"steps": [move("left", 5), PIN, move("down", bump=True), PIN, PRESS]}
        shipped = {"steps": [move("left", 5), PIN, move("down"), PRESS]}
        self.assertTrue(diff(compiled, shipped).passed)
        # MUTATION: a real step down is not a bump.
        drift = {"steps": [move("left", 5), PIN, move("down", 2), PRESS]}
        self.assertFalse(diff(compiled, drift).passed)

    def test_corpus_pins_on_both_sides(self) -> None:
        """steel_thread 622-624: pin, bump, pin."""
        compiled = {"steps": [move("left", 5), PIN, move("down", bump=True), PIN, PRESS]}
        shipped = {"steps": [move("left", 5), PIN, move("down"), PIN, PRESS]}
        self.assertTrue(diff(compiled, shipped).passed)

    def test_corpus_merges_the_bump_and_pins_after(self) -> None:
        """steel_thread 663-665: `down 3` onto the gnaw pile, pin, press."""
        compiled = {"steps": [move("down", 2), PIN, move("down", bump=True), PIN, PRESS]}
        shipped = {"steps": [move("down", 3), PIN, PRESS]}
        self.assertTrue(diff(compiled, shipped).passed)
        drift = {"steps": [move("down", 4), PIN, PRESS]}
        self.assertFalse(diff(compiled, drift).passed)

    def test_a_run_of_identical_keys_pairs_the_last(self) -> None:
        opcodes = goldens._align(["pin", "pin", "press"], ["pin", "press"])
        equal = [(c_lo, s_lo) for tag, c_lo, _, s_lo, _ in opcodes if tag == "equal"]
        self.assertEqual(equal, [(1, 0)])

    def test_the_one_step_discount_is_directional(self) -> None:
        """steel_thread 726-727: `left 1` to Zevara's column is a real step;
        the compiled bump is `down`."""
        compiled = [move("up", 2), move("down", bump=True)]
        shipped = [move("up", 2), move("left")]
        self.assertEqual(goldens._strip_mirrored_bump(compiled, shipped), shipped)


class SliceCliTest(unittest.TestCase):
    def test_parse_and_slice(self) -> None:
        self.assertEqual(parse_slice("itinerary.start,act1.=0:218"), (["itinerary.start", "act1."], 0, 218))
        with self.assertRaises(ValueError):
            parse_slice("act2.=218")
        compiled = {"steps": [dict(PRESS, _itin="act1.a"), dict(PRESS, _itin="act2.b")]}
        shipped = {"steps": [PRESS, PRESS, {"action": "screenshot", "name": "later"}]}
        self.assertTrue(slice_diff(compiled, shipped, ["act1."], 0, 1).passed)
        self.assertFalse(slice_diff(compiled, shipped, ["act1."], 0, 3).passed)


if __name__ == "__main__":
    unittest.main()
