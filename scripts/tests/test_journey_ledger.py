"""scripts/journey_ledger.py reads per-fight resources from journey events."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import journey_ledger  # noqa: E402


def vit(hp: int, mp: int, doses: int = 0) -> dict:
	return {"hp": hp, "max_hp": 40, "mp": mp, "max_mp": 10, "mp_potion_doses": doses}


def ev(kind: str, **payload) -> dict:
	return {"type": kind, "payload": payload}


EVENTS = [
	ev("map_changed", map="floodplains", cell=[1, 1]),
	ev("combat_preparing", encounter="goblins"),
	ev("resources_changed", reason="combat_entry", source="goblins", before=vit(40, 10), after=vit(40, 10)),
	ev("resources_changed", reason="combat_action", source="attack_resolved", before=vit(40, 10), after=vit(25, 4)),
	ev("item_use_settled", committed=True, item="mana_potion", context="combat", before=vit(25, 4), after=vit(25, 9, 1),
		dose_number=1, exposure_after=1, ap_cost=1),
	ev("combat_finished", victory=True, draw=False, rounds=4),
	ev("resources_changed", reason="combat_victory", source="goblins", before=vit(25, 9, 1), after=vit(25, 9, 1)),
	ev("gold_changed", delta=6, source="goblins", total=6),
	ev("combat_preparing", encounter="boss"),
	ev("resources_changed", reason="combat_entry", source="boss", before=vit(25, 9, 1), after=vit(25, 9, 1)),
	ev("resources_changed", reason="combat_action", source="attack_resolved", before=vit(25, 9, 1), after=vit(0, 2, 1)),
	ev("combat_finished", victory=False, draw=False, rounds=6),
	ev("game_loaded", reason="defeat"),
	ev("ui_resources_rendered", surface="field", after=vit(25, 9, 1)),
	ev("resources_changed", reason="sleep", source="bed", before=vit(25, 9, 1), after=vit(40, 10)),
	ev("gold_changed", delta=-4, source="meal", total=2),
	ev("resources_changed", reason="service", source="inn_meal", before=vit(30, 10), after=vit(38, 10)),
]


class JourneyLedgerTest(unittest.TestCase):
	def test_fights_carry_entry_exit_and_rollback(self) -> None:
		ledger = journey_ledger.build(EVENTS)
		win, loss = ledger["fights"]
		self.assertEqual((win["encounter"], win["result"], win["entry"]["hp"], win["exit"]["hp"], win["exit"]["mp"]), ("goblins", "win", 40, 25, 9))
		self.assertEqual(win["items"][0]["dose"], 1)
		self.assertEqual((loss["result"], loss["entry"]["hp"], loss["exit"]["hp"], loss["rollback"]["hp"]), ("loss", 25, 0, 25))
		self.assertEqual(win["map"], "floodplains")

	def test_route_summary(self) -> None:
		ledger = journey_ledger.build(EVENTS)
		summary = ledger["summary"]
		self.assertEqual((summary["wins"], summary["losses"], summary["sleeps"]), (1, 1, 1))
		self.assertEqual((summary["gold_earned"], summary["gold_spent"], summary["gold_final"]), (6, 4, 2))
		self.assertEqual([r["source"] for r in ledger["recovery"]], ["inn_meal"])
		self.assertEqual(ledger["reloads"], [{"reason": "defeat", "map": "floodplains"}])
		self.assertIn("| 2 | boss | floodplains | 25/40 HP, 9/10 MP, 1 doses | 0/40 HP, 2/10 MP, 1 doses → rollback", journey_ledger.markdown(ledger))


if __name__ == "__main__":
	unittest.main()
