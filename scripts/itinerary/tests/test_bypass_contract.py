"""#508: band crossings the engine lets through are planned WALKS that bank.

wi_game.gd's proximity pass has two arms above `start_combat`: a live sneak
credits `sneaked_past_danger` and walks on; a served `cover_prop`
(`serve:<prop>` in entity_first_use, banked by the prop's once_per_waking
interact) credits `crossed_under_cover` and walks on. The route planner used
to refuse every in-band path; now it mirrors both arms and the emitter pins
the bank (and the bypass toast) after the walk.
"""
from __future__ import annotations

import unittest
from pathlib import Path

from scripts.itinerary.emit import Emitter
from scripts.itinerary.ledger import Ledger
from scripts.itinerary.planners.actions import ActionPlanner
from scripts.itinerary.planners.route import RouteError, RoutePlanner
from scripts.itinerary.tests.pipeline import FakeOracle, PROJECT


class TestBandBypass(unittest.TestCase):
	def setUp(self) -> None:
		# The dumb router walks x first: (26,24) -> (31,24) passes (29,24), Chebyshev 1
		# from goblin_encounter_1 at (30,23) -- squarely inside its band.
		self.bridge = FakeOracle()
		self.route = RoutePlanner(PROJECT, self.bridge)
		self.ledger = Ledger.fresh()
		self.ledger.set_position("floodplains", [26, 24], [1, 0])

	def test_an_unserved_crossing_is_still_refused(self) -> None:
		with self.assertRaises(RouteError):
			self.route.plan_to("n", self.ledger, "floodplains", [31, 24])

	def test_a_served_cover_prop_turns_the_band_into_a_walk_that_banks_once(self) -> None:
		self.ledger.state["entity_first_use"]["serve:gate_road_drain_cut"] = True
		ops = self.route.plan_to("n", self.ledger, "floodplains", [31, 24])
		banks = [op for op in ops if op["kind"] == "bypass_bank"]
		self.assertEqual([b["encounter"] for b in banks], ["goblin_encounter_1"])
		self.assertEqual(banks[0]["waits"][0]["payload_contains"], {"id": "crossed_under_cover", "count": 1})
		self.assertEqual(self.ledger.state["accomplishments"]["crossed_under_cover"], 1)
		# Back and across again the same waking: no second credit (once per encounter per waking).
		self.ledger.set_position("floodplains", [26, 24], [1, 0])
		again = self.route.plan_to("n", self.ledger, "floodplains", [31, 24])
		self.assertEqual([op for op in again if op["kind"] == "bypass_bank"], [])

	def test_sleep_rearms_the_cover(self) -> None:
		self.ledger.state["entity_first_use"]["serve:gate_road_drain_cut"] = True
		self.route.plan_to("n", self.ledger, "floodplains", [31, 24])
		self.ledger.apply_sleep_preview({"classes_after": {}})
		self.assertEqual(self.ledger.state["entity_first_use"], {})
		self.ledger.set_position("floodplains", [26, 24], [1, 0])
		with self.assertRaises(RouteError):
			self.route.plan_to("n", self.ledger, "floodplains", [31, 24])

	def test_a_sneaking_crossing_banks_the_growth_counter_and_pins_the_bypass_toast(self) -> None:
		self.ledger.start_sneak()
		ops = self.route.plan_to("n", self.ledger, "floodplains", [31, 24])
		bank = [op for op in ops if op["kind"] == "bypass_bank"][0]
		self.assertEqual(bank["waits"][0]["payload_contains"], {"id": "sneaked_past_danger", "count": 1})
		self.assertEqual(bank["waits"][1], {"type": "toast", "payload_contains": {"text": "Whatever was watching that stretch never saw you pass."}})
		steps = Emitter().emit("n", ops)
		kinds = [(s["action"], s.get("type", "")) for s in steps]
		self.assertIn(("wait_for_event", "accomplishment_recorded"), kinds)
		self.assertIn(("wait_for_event", "toast"), kinds)
		self.assertLess(kinds.index(("move", "")), kinds.index(("wait_for_event", "accomplishment_recorded")), "the bank waits follow the walk")

	def test_the_cut_interact_banks_the_serve_key(self) -> None:
		actions = ActionPlanner(PROJECT, self.bridge, self.route)
		self.ledger.set_position("floodplains", [26, 24], [1, 0])
		actions.plan_interact("n", {"prop": "gate_road_drain_cut", "at": "floodplains", "expect_accomplishment": "took_the_low_road"}, self.ledger)
		self.assertTrue(self.ledger.state["entity_first_use"].get("serve:gate_road_drain_cut"))


if __name__ == "__main__":
	unittest.main()
