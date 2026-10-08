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


ABANDON = [
	ev("map_changed", map="sewers", cell=[1, 1]),
	ev("combat_preparing", encounter="spiders"),
	ev("resources_changed", reason="combat_entry", source="spiders", before=vit(30, 6), after=vit(30, 6)),
	ev("resources_changed", reason="combat_action", source="attack_resolved", before=vit(30, 6), after=vit(12, 6)),
	ev("game_loaded", reason=""),
	ev("ui_resources_rendered", surface="field", after=vit(30, 6)),
	ev("item_use_settled", committed=True, item="mending_draught", context="field", before=vit(30, 6), after=vit(38, 6),
		dose_number=0, exposure_after=0, ap_cost=0),
	ev("resources_changed", reason="item_use", source="mending_draught", before=vit(30, 6), after=vit(38, 6)),
	ev("combat_preparing", encounter="rats"),
	ev("resources_changed", reason="combat_entry", source="rats", before=vit(38, 6), after=vit(38, 6)),
	ev("combat_preparing", encounter="sneaked_past"),
	ev("combat_preparing", encounter="bats"),
	ev("resources_changed", reason="combat_entry", source="bats", before=vit(38, 6), after=vit(38, 6)),
	ev("combat_finished", victory=True, draw=False, rounds=2),
]


ACTS = [
	{"id": "act_i", "advance_when": {"min_classes": 1, "accomplishments": {"reached_town": 1}}},
	{"id": "act_ii", "advance_when": {"quests_completed": 1, "accomplishments": {"boss_down": 1}}},
	{"id": "act_iii", "advance_when": {}},
]
PROGRESS = [
	ev("map_changed", map="town", cell=[0, 0]),
	ev("accomplishment_recorded", id="reached_town", count=1),
	ev("class_gained", **{"class": "mage"}),
	ev("gold_changed", delta=5, source="job", total=5),
	ev("class_level_up", **{"class": "mage", "level": 4}),
	ev("class_evolved", **{"from": "mage", "to": "ice_mage", "level": 4}),
	ev("accomplishment_recorded", id="boss_down", count=1),
	ev("quest_completed", id="q1"),
]


class JourneyLedgerTest(unittest.TestCase):
	def test_act_boundaries_follow_acts_gates(self) -> None:
		ledger = journey_ledger.build(PROGRESS, ACTS)
		self.assertEqual([a["entered"] for a in ledger["acts"]], ["act_ii", "act_iii"])
		self.assertEqual(ledger["acts"][0]["classes"], {"mage": 1})
		self.assertEqual((ledger["acts"][1]["classes"], ledger["acts"][1]["gold"]), ({"ice_mage": 4}, 5))
		self.assertIn("Act boundaries: act_ii @ town: mage 1; 0g", journey_ledger.markdown(ledger))

	def test_abandon_and_unfinished_fights_are_kept(self) -> None:
		ledger = journey_ledger.build(ABANDON)
		results = [(f["encounter"], f["result"]) for f in ledger["fights"]]
		self.assertEqual(results, [("spiders", "abandoned"), ("rats", "abandoned"), ("bats", "win")])
		spiders = ledger["fights"][0]
		self.assertEqual((spiders["exit"]["hp"], spiders["rollback"]["hp"]), (12, 30))
		self.assertEqual([r["source"] for r in ledger["recovery"]], ["mending_draught"])
		self.assertEqual(ledger["summary"]["abandoned"], 2)
		self.assertEqual(ledger["reloads"], [{"reason": "load", "map": "sewers"}])

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
