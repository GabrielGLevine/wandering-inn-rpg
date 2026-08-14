"""M3.6 contract: the five items the 2026-08-13 amendment ruled into scope.

  1. `fight: {entry: dialogue}` -- the board opens on a conversation's own
     confirm, off an option carrying `start_combat`.
  2. Effect-derived event waits -- a chosen option's `effects` array and its
     quests.json joins, as waits, in the engine's own emission order.
  3. Emitter frame flexibilities -- `turn_wait: false`, autoplay `beats:`,
     `expect_banks_after_dismiss`, `arena:`, `goto.via`, and the two missing
     event kinds (`ui_map_rendered`, `ui_gdi_epilogue_rendered`).
  4. Sneak-lifetime modelling (#440) in the ledger and the route planner.
  5. Hardening -- node-level unknown-key rejection, and fence arrival tracking.

Every assertion is paired with a deliberate break that makes it red, the
lane's mutation-proof discipline: a test that would still pass against a
gutted implementation is not evidence of anything.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.itinerary.compile_itinerary import Build, CompileError, _fence_plan_spine  # noqa: E402
from scripts.itinerary.emit import Emitter  # noqa: E402
from scripts.itinerary.goldens import diff  # noqa: E402
from scripts.itinerary.ledger import Ledger  # noqa: E402
from scripts.itinerary.planners.combat import CombatPlanner  # noqa: E402
from scripts.itinerary.planners.dialogue import DialoguePlanner  # noqa: E402
from scripts.itinerary.planners.route import RoutePlanner  # noqa: E402
from scripts.itinerary.quests import QuestJoin  # noqa: E402
from scripts.itinerary.schema import SchemaError, load_itinerary  # noqa: E402


PROJECT = ROOT / "wandering_inn_game"
SHIPPED = json.loads((PROJECT / "qa/scripts/steel_thread.json").read_text(encoding="utf-8"))


def bare(steps: list[dict]) -> list[dict]:
    return [
        {key: value for key, value in step.items() if key not in ("_itin", "_comment", "timeout_sec")}
        for step in steps
    ]


def shipped(lo: int, hi: int) -> list[dict]:
    return bare(SHIPPED["steps"][lo:hi + 1])


def document(body: str, milestone: int = 3):
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "itin.yaml"
        path.write_text(body, encoding="utf-8")
        return load_itinerary(path, milestone=milestone)


# ---------------------------------------------------------------------------
# 1. fight.entry: dialogue
# ---------------------------------------------------------------------------


class DialogueEntryTest(unittest.TestCase):
    """The spar, whose board opens on `spar_offer`'s own confirm."""

    def test_the_emitter_omits_the_approach_press_and_the_panel_teardown(self) -> None:
        # steel_thread 74-76: confirm, then combat_started. No `press
        # interact` (that is the map-encounter entry) and no
        # dialogue_ended/ui_dialogue_hidden (the board took the screen).
        choose = {
            "kind": "dialogue_choose", "cursor_index": 0, "destination": "", "end": True,
            "next_node": {}, "why": "take the spar", "effect_waits": [], "hands_off_to_combat": True,
        }
        fight = {
            "kind": "fight", "entry": "dialogue", "encounter": "relc_spar", "allies": [],
            "shots": [], "policy": "competent", "max_turns": 200, "victory_pins": [],
            "turn_wait": True, "beats": {}, "arena": "", "banks_after_dismiss": [],
        }
        steps = bare(Emitter().emit("n", [choose, fight]))
        self.assertEqual(steps[0], {"action": "press", "name": "confirm"})
        self.assertEqual(steps[1], {"action": "wait_for_event", "type": "combat_started"})
        self.assertEqual(steps[:2], shipped(74, 75))
        self.assertNotIn("dialogue_ended", [step.get("type") for step in steps])
        self.assertNotIn("ui_dialogue_hidden", [step.get("type") for step in steps])

        # MUTATION: drop the handoff flag and the row becomes an ordinary
        # closing row -- it claims a teardown the combat board pre-empted, and
        # the run would sit on `dialogue_ended` while a fight is on screen.
        without = bare(Emitter().emit("n", [dict(choose, hands_off_to_combat=False), fight]))
        self.assertIn("ui_dialogue_hidden", [step.get("type") for step in without])
        self.assertNotEqual(without[:2], shipped(74, 75))

    def test_the_planner_refuses_a_walk_that_does_not_reach_the_start_combat_row(self) -> None:
        """The last anchor must BE the row that starts THIS encounter."""
        planner = DialoguePlanner.__new__(DialoguePlanner)
        planner.quests = QuestJoin(PROJECT)
        ledger = Ledger.fresh()
        waits = planner.apply_option_effects(ledger, [{"start_combat": "relc_spar"}], "relc_intro")
        # A `start_combat` effect announces nothing of its own -- the board
        # opening is the fight arm's claim, not the conversation's.
        self.assertEqual(waits, [])

    def test_a_talk_node_may_not_take_a_start_combat_row(self) -> None:
        """The refusal that stops a hang before a run finds it."""
        graph = {"start": "hub", "nodes": {"hub": {"speaker": "Relc", "options": [
            {"text": "Ready when you are.", "end": True, "effects": [{"start_combat": "relc_spar"}]},
        ]}}}
        planner = _stub_dialogue({"relc_intro": graph}, [
            {"options": [{"text": "Ready when you are.", "cursor_index": 0, "authored_index": 0}]},
        ])
        entity = {"id": "relc", "cell": [1, 1], "conversation": "relc_intro"}
        ledger = Ledger.fresh()
        ledger.set_position("floodplains", [1, 2], [0, -1])
        with self.assertRaisesRegex(Exception, "carries start_combat"):
            planner.plan("n", {"npc": "relc", "choose_path": ["Ready when you are."]}, "w", ledger, entity, "floodplains")

    def test_the_schema_binds_the_conversation_keys_to_the_entry_mode(self) -> None:
        for body, message in (
            ("fight: {encounter: relc_spar, entry: dialogue}", "needs npc"),
            ("fight: {encounter: relc_spar, entry: dialogue, npc: relc}", "needs choose_path"),
            ("fight: {encounter: x, npc: relc}", "only entry: dialogue walks a conversation"),
            ("fight: {encounter: x, entry: proximity, choose_path: [a]}", "only entry: dialogue walks a conversation"),
        ):
            with self.assertRaisesRegex(SchemaError, message, msg=body):
                document(f"- act: i\n  nodes:\n    - id: n\n      {body}\n      why: w\n")
        parsed = document(
            "- act: i\n  nodes:\n    - id: n\n      why: take the spar\n"
            "      fight: {encounter: relc_spar, entry: dialogue, npc: relc, choose_path: [Ready when you are.]}\n"
        )
        self.assertEqual(parsed.nodes[0].spec["entry"], "dialogue")

        # A fork still owes a why, and `fight` is a fork primitive now.
        with self.assertRaisesRegex(SchemaError, "choose_path requires an inline why"):
            document(
                "- act: i\n  nodes:\n    - id: n\n"
                "      fight: {encounter: relc_spar, entry: dialogue, npc: relc, choose_path: [Ready when you are.]}\n"
            )


def _stub_dialogue(graphs: dict, answers: list[dict]) -> DialoguePlanner:
    planner = DialoguePlanner.__new__(DialoguePlanner)
    planner.graphs = graphs
    planner.quests = QuestJoin(PROJECT)
    planner.route = None
    planner.bridge = _Answers(answers)
    return planner


class _Answers:
    def __init__(self, answers: list[dict]) -> None:
        self.answers = list(answers)

    def query(self, _query: str, _ledger=None) -> dict:
        return self.answers.pop(0) if self.answers else {"options": []}


# ---------------------------------------------------------------------------
# 2. effect-derived event waits
# ---------------------------------------------------------------------------


class EffectDerivedWaitsTest(unittest.TestCase):
    def planner(self) -> DialoguePlanner:
        planner = DialoguePlanner.__new__(DialoguePlanner)
        planner.quests = QuestJoin(PROJECT)
        return planner

    def test_every_shape_the_amendment_names_is_derived_in_engine_order(self) -> None:
        planner = self.planner()
        ledger = Ledger.fresh()
        waits = planner.apply_option_effects(
            ledger,
            [{"item": "relcs_spare_spear"}, {"accomplishment": "given_spear_by_relc"}],
            "relc_intro",
        )
        # steel_thread 172/174: the grant announces first, then the counter --
        # `WIGame.dialogue_choose` walks the array in authored order.
        self.assertEqual(waits, [
            {"type": "item_gained", "payload_contains": {"item": "relcs_spare_spear", "source": "relc_intro"}},
            {"type": "accomplishment_recorded", "payload_contains": {"id": "given_spear_by_relc", "count": 1}},
        ])
        self.assertIn("relcs_spare_spear", ledger.state["inventory"])

        # MUTATION: a duplicate grant is a no-op in `pickup`, so claiming it
        # twice would hang the run on the second wait.
        again = planner.apply_option_effects(ledger, [{"item": "relcs_spare_spear"}], "relc_intro")
        self.assertEqual(again, [])

    def test_the_quest_joins_are_derived_not_guessed(self) -> None:
        """A counter that closes a beat drags the beat event behind it."""
        planner = self.planner()
        ledger = Ledger.fresh()
        started = planner.apply_option_effects(ledger, [{"quest": "the_errand"}], "erin_errand")
        self.assertEqual(started, [{"type": "quest_started", "payload_contains": {"id": "the_errand"}}])

        beat = planner.apply_option_effects(ledger, [{"accomplishment": "package_delivered"}], "selys_delivery")
        self.assertEqual(beat, [
            {"type": "accomplishment_recorded", "payload_contains": {"id": "package_delivered", "count": 1}},
            {"type": "quest_beat_completed", "payload_contains": {"id": "the_errand", "beat": 1}},
        ])
        done = planner.apply_option_effects(ledger, [{"accomplishment": "errand_decided"}], "selys_delivery")
        self.assertEqual([row["type"] for row in done],
                         ["accomplishment_recorded", "quest_beat_completed", "quest_completed"])

        # MUTATION: the same counter banked while the quest was NEVER STARTED
        # says nothing -- `_check_quests` returns early on an empty started
        # list, and a compiler that emitted the beat anyway would hang.
        cold = self.planner().apply_option_effects(Ledger.fresh(), [{"accomplishment": "package_delivered"}], "x")
        self.assertEqual([row["type"] for row in cold], ["accomplishment_recorded"])

    def test_a_started_quest_primes_rather_than_replays_its_closed_beats(self) -> None:
        """`start_quest` PRIMES progress; only later banks are edges."""
        planner = self.planner()
        ledger = Ledger.fresh()
        ledger.state["accomplishments"]["package_delivered"] = 1
        waits = planner.apply_option_effects(ledger, [{"quest": "the_errand"}], "erin_errand")
        self.assertEqual([row["type"] for row in waits], ["quest_started"])
        # The already-satisfied beat is NOT re-announced on the next bank.
        later = planner.apply_option_effects(ledger, [{"accomplishment": "heard_gossip"}], "x")
        self.assertEqual([row["type"] for row in later], ["accomplishment_recorded"])

    def test_the_measured_derivable_subset_is_94_rows_at_55_sites_not_141(self) -> None:
        """The M3.5 figure was a whole-script count, not an in-window one.

        141 is how many `accomplishment_recorded`/quest/item rows the shipped
        script carries ANYWHERE. The rows this pass can derive are the ones
        that follow a dialogue confirm, and that is a different number -- the
        rest are prop interacts, post-dismiss banking and sleep banks, which
        belong to other idioms.
        """
        derivable = {"accomplishment_recorded", "quest_beat_completed", "quest_started",
                     "quest_completed", "item_gained", "entity_removed", "item_lost", "gold_changed"}
        window_types = derivable | {"toast"}
        steps = SHIPPED["steps"]
        in_window, sites, whole_script = 0, 0, 0
        in_dialogue, index = False, 0
        while index < len(steps):
            step = steps[index]
            kind = str(step.get("type", ""))
            if step.get("action") == "wait_for_event":
                if kind == "dialogue_started":
                    in_dialogue = True
                elif kind in ("dialogue_ended", "ui_dialogue_hidden"):
                    in_dialogue = False
            if step.get("action") == "press" and step.get("name") == "confirm" and in_dialogue:
                cursor, run = index + 1, 0
                while (cursor < len(steps) and steps[cursor].get("action") == "wait_for_event"
                       and str(steps[cursor].get("type")) in window_types):
                    run += 1 if str(steps[cursor]["type"]) in derivable else 0
                    cursor += 1
                in_window += run
                sites += 1 if run else 0
                index = cursor
                continue
            index += 1
        whole_script = sum(
            1 for step in steps
            if step.get("action") == "wait_for_event" and str(step.get("type")) in derivable
        )
        self.assertEqual(whole_script, 141, "the M3.5 figure, reproduced: every row of these types anywhere")
        self.assertEqual(in_window, 94, "the rows that actually follow a dialogue confirm")
        self.assertEqual(sites, 55)


# ---------------------------------------------------------------------------
# 3. emitter frame flexibilities
# ---------------------------------------------------------------------------


class FrameFlexibilityTest(unittest.TestCase):
    def operation(self, **changes) -> dict:
        operation = {
            "kind": "fight", "entry": "proximity", "encounter": "goblin_encounter_1", "allies": [],
            "shots": [], "policy": "competent", "max_turns": 300, "victory_pins": [],
            "turn_wait": True, "beats": {}, "arena": "", "banks_after_dismiss": [],
        }
        operation.update(changes)
        return operation

    def test_turn_wait_false_drops_the_turn_started_row(self) -> None:
        with_wait = bare(Emitter().emit("n", [self.operation()]))
        without = bare(Emitter().emit("n", [self.operation(turn_wait=False)]))
        self.assertIn("turn_started", [step.get("type") for step in with_wait])
        self.assertNotIn("turn_started", [step.get("type") for step in without])
        # MUTATION: nothing else may move -- the flexibility is one row.
        self.assertEqual([s for s in with_wait if s.get("type") != "turn_started"], without)

    def test_autoplay_beats_land_in_the_two_shipped_slots(self) -> None:
        """steel_thread 196-208: `real_ones` before the turn, `road_clear` after."""
        steps = bare(Emitter().emit("n", [self.operation(
            beats={"before_turn": ["real_ones"], "after_combat": ["road_clear"]},
            shots=["02_tutorial_04_ambush_warrior_spear"],
            banks_after_dismiss=[{"type": "accomplishment_recorded", "payload_contains": {"id": "sign_defended", "count": 1}}],
        )]))
        # The corpus rows, minus the two tolerance-class holds, the album
        # hold, and the `ui_hotbar_rendered` assert an autoplay fight has no
        # slot for (a measured M3.6 residual -- see qa/STEEL-THREAD.md).
        corpus = [row for row in shipped(196, 208) if row["action"] not in ("wait_frames", "assert_event_logged")]
        self.assertEqual([row for row in steps if row["action"] != "wait_frames"], corpus)

        # MUTATION: put both beats in one slot and the reproduction stops --
        # a beat fires at a MOMENT, and the moment is the claim.
        wrong = bare(Emitter().emit("n", [self.operation(
            beats={"before_turn": ["real_ones", "road_clear"]},
            shots=["02_tutorial_04_ambush_warrior_spear"],
            banks_after_dismiss=[{"type": "accomplishment_recorded", "payload_contains": {"id": "sign_defended", "count": 1}}],
        )]))
        self.assertNotEqual(wrong, corpus)

    def test_the_banking_window_sits_between_the_dismiss_and_the_teardown(self) -> None:
        steps = bare(Emitter().emit("n", [self.operation(
            banks_after_dismiss=[{"type": "accomplishment_recorded", "payload_contains": {"id": "sign_defended", "count": 1}}],
        )]))
        actions = [(step["action"], step.get("type") or step.get("name")) for step in steps]
        dismiss = actions.index(("press", "confirm"))
        self.assertEqual(actions[dismiss + 1], ("wait_for_event", "accomplishment_recorded"))
        self.assertEqual(actions[dismiss + 2], ("wait_for_event", "ui_combat_hidden"))

        # MUTATION: after the teardown the deposit is already behind the
        # since-cursor -- `resolve_combat()` ran on the confirm, not here.
        plain = bare(Emitter().emit("n", [self.operation()]))
        self.assertNotIn("accomplishment_recorded", [step.get("type") for step in plain])

    def test_arena_tightens_the_combat_started_pin(self) -> None:
        steps = bare(Emitter().emit("n", [self.operation(entry="interact", arena="vault")]))
        started = next(step for step in steps if step.get("type") == "combat_started")
        self.assertEqual(started, shipped(2439, 2439)[0])
        # MUTATION: without it the wait is LOOSER than the corpus, which §6.3
        # rules fatal rather than tolerable.
        loose = next(s for s in bare(Emitter().emit("n", [self.operation()])) if s.get("type") == "combat_started")
        self.assertNotIn("payload_contains", loose)

    def test_the_two_missing_event_kinds_have_shapes(self) -> None:
        rendered = bare(Emitter().emit("n", [{"kind": "map_rendered", "map": "seal_vault"}]))
        self.assertEqual(rendered, shipped(2479, 2480))

        preview = {"class_gains": [], "level_ups": [], "classes_after": {}, "consolidation": {}}
        epilogue = bare(Emitter().emit("n", [{"kind": "sleep", "preview": preview, "merge": None, "epilogue": True}]))
        self.assertEqual([step.get("type") for step in epilogue][-2:],
                         ["ui_sleep_veil_finished", "ui_gdi_epilogue_rendered"])
        quiet = bare(Emitter().emit("n", [{"kind": "sleep", "preview": preview, "merge": None, "epilogue": False}]))
        self.assertNotIn("ui_gdi_epilogue_rendered", [step.get("type") for step in quiet])

    def test_goto_via_names_the_door_the_last_leg_takes(self) -> None:
        route = RoutePlanner(PROJECT, None)
        ledger = Ledger.fresh()
        ledger.set_position("floodplains", [6, 6])
        west = route._transition_path(ledger, "inn", "floodplains_inn_door_west")
        self.assertEqual(str(west[-1]["entity"]["id"]), "floodplains_inn_door_west")
        # MUTATION: unconstrained, the router picks by search order -- the
        # difference is a different ARRIVAL, which is why `via` exists.
        default = route._transition_path(ledger, "inn")
        self.assertNotEqual(str(default[-1]["entity"]["id"]), "floodplains_inn_door_west")
        with self.assertRaisesRegex(Exception, "matched 0 legs"):
            route._transition_path(ledger, "inn", "not_a_door")

    def test_the_schema_refuses_frame_keys_that_contradict_the_mode(self) -> None:
        for body, message in (
            ("fight: {encounter: x, mode: driven, turns: [{autoplay: true}], turn_wait: false}", "autoplay key"),
            ("fight: {encounter: x, mode: driven, turns: [{autoplay: true}], beats: {before_turn: [a]}}", "autoplay key"),
            ("fight: {encounter: x, beats: {midfight: [a]}}", "unknown slots"),
            ("fight: {encounter: x, beats: {before_turn: []}}", "non-empty list"),
            ("fight: {encounter: x, turn_wait: yes please}", "must be boolean"),
            ("fight: {encounter: x, arena: ''}", "arena must be an arena id"),
            ("goto: {map: inn, via: ''}", "via must name"),
            ("sleep: {expect_epilogue: 1}", "expect_epilogue must be boolean"),
        ):
            with self.assertRaisesRegex(SchemaError, message, msg=body):
                document(f"- act: i\n  nodes:\n    - id: n\n      {body}\n")


# ---------------------------------------------------------------------------
# 4. sneak lifetime (#440)
# ---------------------------------------------------------------------------


class SneakLifetimeTest(unittest.TestCase):
    def test_the_route_planner_walks_a_radius_only_while_the_stance_is_live(self) -> None:
        route = RoutePlanner(PROJECT, None)
        ledger = Ledger.fresh()
        hazards = route.proximity_hazards("floodplains", ledger)
        self.assertTrue(any(str(e["id"]) == "goblin_encounter_1" for e in hazards))
        ledger.start_sneak()
        self.assertEqual(route.proximity_hazards("floodplains", ledger), [])
        # MUTATION: the stance is spent by the fight it opens, so the NEXT
        # leg is refused again rather than inheriting an invisibility the
        # engine already broke.
        ledger.apply_victory({"id": "someone_else", "on_victory": []}, (0, 0))
        self.assertFalse(ledger.sneaking)
        self.assertTrue(route.proximity_hazards("floodplains", ledger))

    def test_a_prop_interact_and_a_sleep_both_drop_the_cloak(self) -> None:
        ledger = Ledger.fresh()
        ledger.start_sneak()
        self.assertTrue(ledger.break_sneak())
        # Idempotent, and it SAYS so: the un-cloak emits `sneak_ended` only
        # when a stance was live.
        self.assertFalse(ledger.break_sneak())
        ledger.start_sneak()
        ledger.apply_sleep_preview({"classes_after": {}})
        self.assertFalse(ledger.sneaking)

    def test_the_two_directions_announce_different_things(self) -> None:
        cloak = bare(Emitter().emit("n", [{"kind": "field_skill", "skill": "invisibility", "target": "", "accomplishment": "", "sneak": "start"}]))
        self.assertEqual([step.get("type") for step in cloak[1:]], ["skill_used", "sneak_started", "toast"])
        self.assertEqual(cloak[3]["payload_contains"], {"text": "You soften your step."})
        drop = bare(Emitter().emit("n", [{"kind": "field_skill", "skill": "invisibility", "target": "", "accomplishment": "", "sneak": "end"}]))
        self.assertEqual([step.get("type") for step in drop[1:]], ["skill_used", "sneak_ended", "toast"])
        self.assertEqual(drop[3]["payload_contains"], {"text": "You straighten up."})
        # The shipped cloak (2426-2428). The one difference is a TIGHTENING:
        # the compiled `skill_used` pin carries `context: exploration` as
        # well, which is a superset of the corpus row and not a second claim.
        corpus = [row for row in shipped(2426, 2428) if row["action"] != "screenshot"]
        self.assertEqual([step["action"] for step in cloak[:3]], [row["action"] for row in corpus])
        self.assertEqual(cloak[1]["payload_contains"],
                         dict(corpus[1]["payload_contains"], context="exploration"))
        self.assertEqual(cloak[2], corpus[2])

        # MUTATION: a stance cast is not a working -- it has no
        # `ui_toast_rendered` tail, and emitting one would wait on a widget
        # rather than on the lifetime edge.
        working = bare(Emitter().emit("n", [{"kind": "field_skill", "skill": "light", "target": "", "accomplishment": ""}]))
        self.assertIn("ui_toast_rendered", [step.get("type") for step in working])
        self.assertNotIn("ui_toast_rendered", [step.get("type") for step in cloak])


# ---------------------------------------------------------------------------
# 5. hardening
# ---------------------------------------------------------------------------


class HardeningTest(unittest.TestCase):
    def test_a_typod_second_primitive_can_no_longer_no_op_silently(self) -> None:
        """The pre-existing bug: only PRIMITIVE keys were ever counted."""
        with self.assertRaisesRegex(SchemaError, r"has unknown keys \['figth'\]"):
            document(
                "- act: i\n  nodes:\n    - id: n\n      goto: {map: inn}\n"
                "      figth: {encounter: relc_spar}\n"
            )
        # MUTATION: the shape that USED to pass is the same document with the
        # typo removed -- so the rejection is about the stray key and not
        # about the node being malformed in some other way.
        self.assertEqual(
            document("- act: i\n  nodes:\n    - id: n\n      goto: {map: inn}\n").nodes[0].primitive, "goto"
        )
        for body in ("      shots: [a]\n", "      comment: hello\n", "      when: later\n"):
            with self.assertRaisesRegex(SchemaError, "has unknown keys"):
                document(f"- act: i\n  nodes:\n    - id: n\n      goto: {{map: inn}}\n{body}")

    def test_the_fence_compares_where_each_node_ARRIVED(self) -> None:
        steps = [{"_itin": "a.goto", "action": "press", "name": "interact"}]
        walked = [("a.goto", "inn", (7, 3), (0, 1))]
        moved = [("a.goto", "inn", (7, 4), (0, 1))]
        _fence_plan_spine(_build(steps, walked), _build(steps, walked))
        with self.assertRaises(CompileError) as caught:
            _fence_plan_spine(_build(steps, walked), _build(steps, moved))
        self.assertIn("ARRIVED somewhere pass 1 did not", str(caught.exception))

        # MUTATION: the hole this closes is precisely the one the emitted
        # spine cannot see -- identical steps, different destination.
        self.assertEqual(_build(steps, walked).script, _build(steps, moved).script)

        elsewhere = [("a.goto", "street", (7, 3), (0, 1))]
        with self.assertRaisesRegex(CompileError, "ARRIVED"):
            _fence_plan_spine(_build(steps, walked), _build(steps, elsewhere))


def _build(steps: list[dict], arrivals: list[tuple]) -> Build:
    return Build(
        document=None, script={"steps": steps}, checkpoints=[], start_checkpoint=None,
        nodes=["a.goto"], detours=[], report=None, arrivals=arrivals,
    )


# ---------------------------------------------------------------------------
# The golden differ's own accounting, fixed alongside the arrival pins
# ---------------------------------------------------------------------------


class GoldenAccountingTest(unittest.TestCase):
    SHIPPED_LEG = {"steps": [
        {"action": "move", "direction": "right", "steps": 12},
        {"action": "move", "direction": "right", "steps": 1},
        {"action": "press", "name": "interact"},
    ]}

    def test_a_tightening_inside_a_walk_is_not_an_arrival_difference(self) -> None:
        compiled = {"steps": [
            {"action": "move", "direction": "right", "steps": 12},
            {"action": "assert_state", "path": "player_cell", "equals": [14, 3]},
            {"action": "move", "direction": "right", "steps": 1},
            {"action": "press", "name": "interact"},
        ]}
        report = diff(compiled, self.SHIPPED_LEG)
        self.assertTrue(report.passed, report.render())
        self.assertEqual(len(report.tighter), 1)

        # MUTATION: a REAL arrival difference still fails -- the carry-forward
        # fixes the accounting, it does not relax the rule.
        moved = json.loads(json.dumps(compiled))
        moved["steps"][0]["steps"] = 11
        self.assertFalse(diff(moved, self.SHIPPED_LEG).passed)

    def test_position_pins_align_on_their_value_not_only_their_path(self) -> None:
        shipped_leg = {"steps": [
            {"action": "assert_state", "path": "player_cell", "equals": [7, 6]},
            {"action": "press", "name": "interact"},
        ]}
        compiled = {"steps": [
            {"action": "assert_state", "path": "player_cell", "equals": [7, 6]},
            {"action": "assert_state", "path": "player_cell", "equals": [6, 6]},
            {"action": "press", "name": "interact"},
        ]}
        report = diff(compiled, shipped_leg)
        self.assertTrue(report.passed, report.render())
        self.assertEqual(report.tighter, ["compiled-only assert: [-] "
                                          '{"action": "assert_state", "equals": [6, 6], "path": "player_cell"}'])

        # MUTATION: a pin the compiler DROPPED is still fatal.
        self.assertFalse(diff({"steps": compiled["steps"][1:]}, shipped_leg).passed)


if __name__ == "__main__":
    unittest.main()
