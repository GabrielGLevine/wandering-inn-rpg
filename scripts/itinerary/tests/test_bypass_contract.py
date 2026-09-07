"""#543 eligibility is measured through the real oracle and WIGame moves.

These focused saved states establish projection parity, never discovery.
Fresh-character acquisition and rendered feedback need their runtime routes.
"""
from __future__ import annotations

import unittest
from copy import deepcopy

from scripts.itinerary.bridge import OracleBridge, OracleError
from scripts.itinerary.emit import Emitter
from scripts.itinerary.ledger import Ledger
from scripts.itinerary.planners.actions import ActionPlanner
from scripts.itinerary.planners.route import RouteError, RoutePlanner
from scripts.itinerary.tests.pipeline import FakeOracle, PROJECT


class TestBandBypass(unittest.TestCase):
	def setUp(self) -> None:
		self.bridge = OracleBridge(PROJECT)
		self.route = RoutePlanner(PROJECT, self.bridge)
		self.ledger = Ledger.fresh()
		self.ledger.set_position("floodplains", [26, 22], [1, 0])

	def test_an_unserved_crossing_is_still_refused(self) -> None:
		with self.assertRaises(RouteError):
			self.route.plan_to("n", self.ledger, "floodplains", [31, 22])

	def test_a_warded_crossing_never_banks_a_bypass(self) -> None:
		self.ledger.start_sneak()
		self.ledger.state["warded_encounters"]["goblin_encounter_1"] = {"sleeps": 1, "map": "floodplains", "cell": [30, 23]}
		ops = self.route.plan_to("n", self.ledger, "floodplains", [31, 22])
		self.assertEqual([op for op in ops if op["kind"] == "bypass_bank"], [])
		self.assertNotIn("sneaked_past_danger", self.ledger.state["accomplishments"])

	def test_a_served_cover_prop_turns_the_band_into_a_walk_that_banks_once(self) -> None:
		self.ledger.state["entity_first_use"]["serve:gate_road_drain_cut"] = True
		ops = self.route.plan_to("n", self.ledger, "floodplains", [31, 22])
		banks = [op for op in ops if op["kind"] == "bypass_bank"]
		self.assertEqual([b["encounter"] for b in banks], ["goblin_encounter_1"])
		self.assertEqual(banks[0]["waits"][0]["payload_contains"], {"id": "crossed_under_cover", "count": 1})
		self.assertEqual(self.ledger.state["accomplishments"]["crossed_under_cover"], 1)
		# Back and across again the same waking: no second credit (once per encounter per waking).
		self.ledger.set_position("floodplains", [26, 22], [1, 0])
		again = self.route.plan_to("n", self.ledger, "floodplains", [31, 22])
		self.assertEqual([op for op in again if op["kind"] == "bypass_bank"], [])

	def test_sleep_rearms_the_cover(self) -> None:
		self.ledger.state["entity_first_use"]["serve:gate_road_drain_cut"] = True
		self.route.plan_to("n", self.ledger, "floodplains", [31, 22])
		self.ledger.apply_sleep_preview(self.bridge.query("progression_preview", self.ledger))
		self.assertEqual(self.ledger.state["entity_first_use"], {})
		self.ledger.set_position("floodplains", [26, 22], [1, 0])
		with self.assertRaises(RouteError):
			self.route.plan_to("n", self.ledger, "floodplains", [31, 22])

	def test_a_sneaking_crossing_banks_the_growth_counter_and_pins_the_bypass_toast(self) -> None:
		self.ledger.start_sneak()
		ops = self.route.plan_to("n", self.ledger, "floodplains", [31, 22])
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

	def test_supported_eligibility_table_matches_real_move_events(self) -> None:
		cases = [
			("live", {}, True, "sneaked_past_danger"),
			("warded_sneak", {"warded_encounters": {"goblin_encounter_1": {"sleeps": 1}}}, True, None),
			("warded_cover", {"warded_encounters": {"goblin_encounter_1": {"sleeps": 1}}, "entity_first_use": {"serve:gate_road_drain_cut": True}}, False, None),
			("removed", {"removed_entities": ["goblin_encounter_1"]}, True, None),
			("dormant", {"dormant_encounters": ["goblin_encounter_1"]}, True, None),
			("credited", {"entity_first_use": {"danger:goblin_encounter_1": True}, "accomplishments": {"sneaked_past_danger": 7}}, True, None),
			("cover", {"entity_first_use": {"serve:gate_road_drain_cut": True}}, False, "crossed_under_cover"),
			("sneak_before_cover", {"entity_first_use": {"serve:gate_road_drain_cut": True}}, True, "sneaked_past_danger"),
			("exit_grace_leaves", {"warded_encounters": {"goblin_encounter_1": {"until_exit": True, "map": "floodplains"}}}, True, "sneaked_past_danger"),
		]
		cells = [[x, 22] for x in range(26, 32)]
		for label, state, sneaking, counter in cases:
			with self.subTest(label=label):
				ledger = Ledger.fresh()
				ledger.state.update(deepcopy(state))
				ledger.set_position("floodplains", cells[0])
				ledger.sneaking = sneaking
				stance = "sneaking" if sneaking else "visible"
				actual = self.bridge.query(f"bypass_walk {stance} known " + " ".join(f"{x},{y}" for x, y in cells), ledger)
				ops = self.route._bank_bypasses(ledger, cells)
				waits = [wait for op in ops for wait in op["waits"]]
				actual_waits = [event for event in actual["events"] if event["type"] in ("accomplishment_recorded", "toast")]
				self.assertEqual(waits, actual_waits)
				self.assertEqual([wait["payload_contains"]["id"] for wait in waits if wait["type"] == "accomplishment_recorded"], [] if counter is None else [counter])
				self.assertEqual(ledger.state["entity_first_use"], actual["entity_first_use"])
				self.assertEqual(ledger.state["warded_encounters"], actual["warded_encounters"])

	def test_phase_and_effective_radius_use_sim_semantics(self) -> None:
		cells = [[x, 13] for x in range(21, 25)]
		query = "bypass_walk sneaking known " + " ".join(f"{x},{y}" for x, y in cells)
		self.ledger.set_position("floodplains", cells[0])
		self.ledger.start_sneak()
		day = self.bridge.query(query, self.ledger)
		self.assertTrue(day["supported"])
		self.assertEqual(day["banks"], [])
		self.ledger.state["actions_since_sleep"] = 900
		night = self.bridge.query(query, self.ledger)
		self.assertEqual([bank["encounter"] for bank in night["banks"]], ["road_mothbears"])
		with self.assertRaisesRegex(RouteError, "exact action clock"):
			self.route._bank_bypasses(self.ledger, cells)
		self.ledger.state["player_skills"].append("wild_affinity")
		reduced = self.bridge.query(query, self.ledger)
		self.assertEqual(reduced["banks"], [])
		self.assertEqual(self.route._bank_bypasses(self.ledger, cells), [])

	def test_actual_sleep_expires_wards_and_rearms_a_new_sneak(self) -> None:
		self.ledger.state["warded_encounters"] = {"goblin_encounter_1": {"sleeps": 1}, "goblin_night_patrol": {"sleeps": 2}}
		self.ledger.state["entity_first_use"] = {"danger:goblin_encounter_1": True, "serve:gate_road_drain_cut": True}
		self.ledger.state["accomplishments"]["sneaked_past_danger"] = 1
		self.ledger.start_sneak()
		self.ledger.apply_sleep_preview(self.bridge.query("progression_preview", self.ledger))
		self.assertFalse(self.ledger.sneaking)
		self.assertEqual(self.ledger.state["entity_first_use"], {})
		self.assertEqual(self.ledger.state["warded_encounters"], {"goblin_night_patrol": {"sleeps": 1}})
		self.ledger.start_sneak()
		ops = self.route.plan_to("n", self.ledger, "floodplains", [31, 22])
		self.assertEqual([op["waits"][0]["payload_contains"] for op in ops if op["kind"] == "bypass_bank"], [{"id": "sneaked_past_danger", "count": 2}])

	def test_visible_exit_clears_grace_before_a_later_sneaking_return(self) -> None:
		self.ledger.set_position("floodplains", [28, 22])
		self.ledger.state["warded_encounters"]["goblin_encounter_1"] = {"until_exit": True, "map": "floodplains"}
		out = self.route.plan_to("leave", self.ledger, "floodplains", [27, 22])
		self.assertEqual([op for op in out if op["kind"] == "bypass_bank"], [])
		self.assertEqual(self.ledger.state["warded_encounters"], {})
		self.ledger.start_sneak()
		back = self.route.plan_to("return", self.ledger, "floodplains", [28, 22])
		self.assertEqual([op["encounter"] for op in back if op["kind"] == "bypass_bank"], ["goblin_encounter_1"])

	def test_blocked_or_noncardinal_walks_cannot_invent_credit(self) -> None:
		self.ledger.set_position("floodplains", [28, 24])
		self.ledger.start_sneak()
		with self.assertRaisesRegex(RouteError, "walk is blocked"):
			self.route._bank_bypasses(self.ledger, [[28, 24], [29, 24]])
		self.assertNotIn("sneaked_past_danger", self.ledger.state["accomplishments"])
		with self.assertRaisesRegex(OracleError, "adjacent cardinal"):
			self.bridge.query("bypass_walk sneaking known 28,24 30,24", self.ledger)


class TestTransitionEdges(unittest.TestCase):
	def test_kind_dispatch_never_adds_both_destinations(self) -> None:
		route = RoutePlanner(PROJECT, FakeOracle())
		ledger = Ledger.fresh()
		entity = {"id": "gate", "kind": "door", "cell": [3, 10], "to_map": "inn", "to_cell": [2, 3],
			"door_when": {"requires": {"gate_open": 1}, "to_map": "street", "to_cell": [1, 3], "open_toast": "The gate opens."}}
		route.maps["test"] = {"entities": [entity]}
		ledger.accomplishment("gate_open")
		self.assertEqual([edge["to_map"] for edge in route._edges("test", ledger)], ["inn"])
		self.assertNotIn("open_toast", route._edges("test", ledger)[0])
		entity["kind"] = "prop"
		self.assertEqual([edge["to_map"] for edge in route._edges("test", ledger)], ["street"])
		self.assertEqual(route._edges("test", ledger)[0]["open_toast"], "The gate opens.")
		ledger.state["accomplishments"].clear()
		self.assertEqual(route._edges("test", ledger), [])


if __name__ == "__main__":
	unittest.main()
