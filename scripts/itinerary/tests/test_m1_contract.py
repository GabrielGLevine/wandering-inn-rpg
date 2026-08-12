from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.itinerary.bridge import OracleBridge
from scripts.itinerary.emit import Emitter
from scripts.itinerary.ledger import Ledger
from scripts.itinerary.planners.dialogue import DialoguePlanner
from scripts.itinerary.planners.route import RoutePlanner
from scripts.itinerary.planners.sleep import SleepPlanner
from scripts.itinerary.schema import SchemaError, load_itinerary


ROOT = Path(__file__).resolve().parents[3]


class FakeBridge:
    def __init__(self) -> None:
        self.queries: list[str] = []

    def query(self, query: str, ledger: Ledger | None = None) -> dict:
        self.queries.append(query)
        if query.startswith("path inn 2,3 7,2"):
            return {
                "reachable": True,
                "target_blocked": True,
                "approach": {
                    "cell": [7, 3],
                    "driver_steps": [{"action": "move", "direction": "right", "steps": 5}],
                    "bump": "up",
                },
            }
        if query == "path inn 14,3 7,3":
            return {
                "reachable": True,
                "target_blocked": False,
                "driver_steps": [{"action": "move", "direction": "left", "steps": 7}],
            }
        if query.startswith("visible_options erin_errand "):
            return {
                "node": query.rsplit(" ", 1)[-1],
                "options": [{"cursor_index": 1, "authored_index": 5, "text": "Leave.", "goto": "", "end": True}],
            }
        if query == "progression_preview":
            return {
                "classes_before": {},
                "classes_after": {},
                "class_gains": [],
                "level_ups": [],
                "consolidation": {},
                "evolutions": [],
            }
        raise AssertionError(f"unexpected fake query: {query}")


class M1ContractTest(unittest.TestCase):
    def test_m1_contract(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            valid = tmp / "valid.yaml"
            valid.write_text(
                """- act: i
  nodes:
    - id: act1.erin
      talk: {npc: erin, choose_path: [Leave.]}
      why: A quiet greeting exercises the dialogue cursor without changing the route.
    - id: act1.sleep
      sleep: {expect_levels: false}
""",
                encoding="utf-8",
            )
            doc = load_itinerary(valid, milestone=1)
            self.assertEqual([node.id for node in doc.nodes], ["act1.erin", "act1.sleep"])

            duplicate = tmp / "duplicate.yaml"
            duplicate.write_text(valid.read_text(encoding="utf-8").replace("act1.sleep", "act1.erin"), encoding="utf-8")
            with self.assertRaisesRegex(SchemaError, "duplicate node id"):
                load_itinerary(duplicate, milestone=1)

            raw = tmp / "raw.yaml"
            raw.write_text("- act: i\n  nodes:\n    - id: hidden\n      raw: []\n", encoding="utf-8")
            with self.assertRaisesRegex(SchemaError, "not available in M1"):
                load_itinerary(raw, milestone=1)

        ledger = Ledger.fresh()
        save = ledger.materialize_save()
        self.assertEqual(save["version"], 8)
        self.assertEqual(save["state"]["current_map"], "inn")
        self.assertIsInstance(save["state"]["rng_state"], str)

        fake = FakeBridge()
        route = RoutePlanner(ROOT / "wandering_inn_game", fake)
        route_ops = route.plan_to("act1.erin", ledger, "inn", [7, 2])
        self.assertEqual(route_ops[-1]["kind"], "face_target")
        self.assertEqual(ledger.cell, [7, 3])

        facing_ledger = Ledger.fresh()
        facing_ledger.set_position("inn", [14, 3], [0, -1])
        route.plan_to("act1.inn.return", facing_ledger, "inn", [7, 3])
        self.assertEqual(facing_ledger.facing, [-1, 0])

        dialogue = DialoguePlanner(ROOT / "wandering_inn_game", fake, route)
        entity = {"id": "erin", "display_name": "Erin", "conversation": "erin_errand", "cell": [7, 2]}
        talk_ops = dialogue.plan("act1.erin", {"npc": "erin", "choose_path": ["Leave."]}, "because", ledger, entity)
        self.assertEqual(talk_ops[-1]["kind"], "dialogue_choose")
        self.assertEqual(talk_ops[-1]["cursor_index"], 1)

        sleep = SleepPlanner(fake)
        sleep_ops = sleep.plan("act1.sleep", {"expect_levels": False}, ledger)
        self.assertEqual(sleep_ops[0]["kind"], "sleep")
        self.assertEqual(ledger.state["pending_consolidation"], {})

        steps = Emitter().emit(
            "act1.erin",
            [
                {"kind": "pool_line", "speaker": "Erin"},
                {"kind": "dialogue_choose", "cursor_index": 1, "destination": "", "end": True, "why": "because"},
            ],
        )
        self.assertTrue(all(step["_itin"] == "act1.erin" for step in steps))
        self.assertIn({"_itin": "act1.erin", "action": "wait_frames", "frames": 30}, steps)
        self.assertEqual(steps[-2]["type"], "ui_dialogue_hidden")

        oracle = OracleBridge(ROOT / "wandering_inn_game")
        answers = oracle.batch([{"query": "state current_map"}, {"query": "progression_preview"}])
        self.assertEqual(answers[0]["value"], "inn")
        self.assertEqual(answers[1]["classes_before"], {})
        self.assertEqual(answers[1]["classes_after"], {})
        self.assertEqual([answer["query"] for answer in answers], ["state", "progression_preview"])


if __name__ == "__main__":
    unittest.main()
