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

Two tiers, and the second one is the point. The classes above the PIPELINE
banner pin one stage each -- a schema refusal, an emitter shape, a planner
helper. The classes below it pin the CHAIN, from a YAML node spec through the
planner to emitted steps, because that is what a criterion actually promises.

The first version of this suite had only the first tier, and an audit severed
eight links between spec and step -- the branch that reads `turn_wait`, the one
that reads `via`, the one that toggles a sneak, the assignment that carries
effect waits into the operation, the emitter's placement of those waits
relative to the teardown -- with the suite green through every one. A guard
that watches only the last stage is a guard on one function, not on a feature.
Every assertion here is paired with a deliberate break that makes it red.
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

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pipeline import FakeOracle, Pipeline, act  # noqa: E402


PROJECT = ROOT / "wandering_inn_game"
SHIPPED = json.loads((PROJECT / "qa/scripts/steel_thread.json").read_text(encoding="utf-8"))

# The shapes the amendment names as derivable from an option's own effects,
# plus the three the corpus measures alongside them.
DERIVABLE_TYPES = {
    "accomplishment_recorded", "quest_beat_completed", "quest_started", "quest_completed",
    "item_gained", "entity_removed", "item_lost", "gold_changed",
}


def _wait_type(step: dict) -> str:
    return str(step.get("type", "")) if step.get("action") == "wait_for_event" else ""


def _preceding_press(steps: list[dict], index: int) -> str:
    """The press this announcement is hanging off, skipping its own siblings."""
    cursor = index - 1
    while cursor >= 0 and _wait_type(steps[cursor]) in DERIVABLE_TYPES | {"toast"}:
        cursor -= 1
    return str(steps[cursor].get("name", "")) if steps[cursor].get("action") == "press" else ""


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

    def test_the_emitters_placement_rule_is_what_defines_the_window(self) -> None:
        """The MODEL the census below scans with, asserted rather than assumed.

        A row that CONTINUES puts its announcements between the confirm and
        the destination node; a row that CLOSES puts them after the teardown
        pair, because `choose()` emits `dialogue_ended` before the owner
        applies the effects. The first census of this window was written as a
        standalone scanner that knew only the first of those two placements,
        so it could not see a closing row's announcements at all and undercounted
        by nine. Deriving the scan from the emitter is what stops that
        recurring: invert the placement and this test reds first.
        """
        waits = [{"type": "accomplishment_recorded", "payload_contains": {"id": "x", "count": 1}}]
        base = {"kind": "dialogue_choose", "cursor_index": 0, "why": "", "effect_waits": waits}

        continuing = [step.get("type") or step.get("action")
                      for step in bare(Emitter().emit("n", [dict(base, destination="next", end=False,
                                                                 next_node={"speaker": "A"})]))]
        self.assertEqual(continuing, ["press", "accomplishment_recorded", "dialogue_node"])

        closing = [step.get("type") or step.get("action")
                   for step in bare(Emitter().emit("n", [dict(base, destination="", end=True, next_node={})]))]
        self.assertEqual(closing, ["press", "dialogue_ended", "ui_dialogue_hidden",
                                   "accomplishment_recorded", "wait_frames"])

    def test_the_derivable_subset_is_105_rows_at_60_sites_not_141(self) -> None:
        """The M3.5 figure was a whole-script count, not a window one.

        141 is how many `accomplishment_recorded`/quest/item rows the shipped
        script carries ANYWHERE. The rows this pass derives are the ones a
        dialogue confirm announces, in either of the emitter's two placements
        (the test above). The rest belong to other idioms and say so.
        """
        derivable, teardown = DERIVABLE_TYPES, ("dialogue_ended", "ui_dialogue_hidden")
        steps = SHIPPED["steps"]
        immediate, closing = [], []
        immediate_sites = closing_sites = 0
        in_dialogue, index = False, 0
        while index < len(steps):
            kind = _wait_type(steps[index])
            # A conversation opens on `dialogue_started` -- OR, where the corpus
            # never waited for one (the Ksmvr plates, 872), on the node/panel
            # rows that only a live conversation can emit. The first census
            # tracked only the first spelling and so never saw steps 876-877.
            if kind in ("dialogue_started", "dialogue_node", "ui_dialogue_shown"):
                in_dialogue = True
            elif kind in teardown:
                in_dialogue = False
            step = steps[index]
            if step.get("action") == "press" and step.get("name") == "confirm" and in_dialogue:
                cursor, closed = index + 1, False
                while cursor < len(steps) and _wait_type(steps[cursor]) in teardown:
                    closed, cursor = True, cursor + 1
                run: list[int] = []
                while cursor < len(steps):
                    at = _wait_type(steps[cursor])
                    if at in derivable:
                        run.append(cursor)
                    elif at != "toast" and steps[cursor].get("action") not in ("assert_event_logged", "assert_state"):
                        break
                    cursor += 1
                if run:
                    (closing if closed else immediate).extend(run)
                    if closed:
                        closing_sites += 1
                    else:
                        immediate_sites += 1
                if closed:
                    in_dialogue = False
                index = cursor
                continue
            index += 1

        census = [index for index, step in enumerate(steps) if _wait_type(step) in derivable]
        outside = [index for index in census if index not in set(immediate) | set(closing)]
        self.assertEqual(len(census), 141, "the M3.5 figure, reproduced: every row of these types anywhere")
        self.assertEqual((len(immediate), immediate_sites), (96, 56), "continuing-row announcements")
        self.assertEqual((len(closing), closing_sites), (9, 4), "closing-row announcements, after the teardown")
        self.assertEqual(len(immediate) + len(closing), 105, "the derivable subset")
        self.assertEqual(len(outside), 36, "rows that belong to other idioms")
        # The closing rows are corpus sites, not a category: naming them is
        # what makes the 9 auditable.
        self.assertEqual(closing, [1040, 1041, 1123, 1124, 1125, 1950, 1951, 2149, 2150])
        # And the post-dismiss eight are the ones `expect_banks_after_dismiss`
        # owns -- exactly the list the superseded M3.5 table carried.
        after_dismiss = [index for index in outside if _preceding_press(steps, index) == "confirm"]
        self.assertEqual(after_dismiss, [207, 388, 389, 500, 501, 1059, 1612, 1626])
        self.assertEqual(len(outside) - len(after_dismiss), 28, "26 prop interacts + 2 sleep banks")


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

    def test_the_carry_forward_cannot_MASK_a_difference_because_it_drops_nothing(self) -> None:
        """The proof that this is a correctness fix and not a loosening.

        A gate change made inside the milestone it gates owes more than "it
        made the number smaller". The invariant is COVERAGE: every
        tolerance-class step on BOTH sides reaches exactly one `_compare_gap`
        call. The old accounting dropped the gap of any UNMATCHED spine step on
        the floor, so a walk sitting behind a compiled-only assert was never
        compared to anything at all -- which is a way to miss a real
        difference, not a way to catch one. Carrying it forward can only ADD
        movement to a comparison, never remove it.

        BOTH SIDES, and this test used to say "both" while checking one. A
        re-audit dropped the SHIPPED-side carry-forward and all 132 tests
        stayed green -- the same defect class as the inert guards this suite
        was rebuilt to close, one level down, in the very test whose job is to
        prove the gate was not weakened. The shipped side is the direction that
        matters most: losing a shipped gap loses the CORPUS's walk from the
        comparison, which is exactly how a real difference hides.
        """
        corpus = json.loads((PROJECT / "qa/scripts/steel_thread.json").read_text(encoding="utf-8"))["steps"][:400]
        shipped_script = {"steps": list(corpus)}

        # TWO fixtures, because the two carry-forwards run on different
        # branches and a fixture that exercises one leaves the other dead.
        #   compiled-only spine steps: an assert after every walk run.
        thickened: list[dict] = []
        for step in corpus:
            thickened.append(step)
            if step.get("action") == "move":
                thickened.append({"action": "assert_state", "path": "player_cell", "equals": [0, 0]})
        #   shipped-only spine steps: the corpus's own pins, dropped. This is
        #   the real compiler's commonest divergence (330 position pins it does
        #   not emit), and every one of them sits behind a walk.
        thinned = [step for step in corpus if step.get("action") != "assert_state"]
        self.assertLess(len(thinned), len(corpus), "the fixture must actually drop shipped spine steps")

        for label, compiled in (("compiled-only spine", {"steps": thickened}),
                                ("shipped-only spine", {"steps": thinned})):
            self._assert_full_coverage(label, compiled, shipped_script)

    def _assert_full_coverage(self, label: str, compiled: dict, shipped_script: dict) -> None:
        seen_compiled: list[list[dict]] = []
        seen_shipped: list[list[dict]] = []
        import scripts.itinerary.goldens as goldens_module
        original = goldens_module._compare_gap

        def recording(report, compiled_gap, shipped_gap, anchor):
            seen_compiled.append(list(compiled_gap))
            seen_shipped.append(list(shipped_gap))
            return original(report, compiled_gap, shipped_gap, anchor)

        goldens_module._compare_gap = recording
        try:
            goldens_module.diff(compiled, shipped_script)
        finally:
            goldens_module._compare_gap = original

        def walked(gaps: list[list[dict]]) -> int:
            return sum(int(s.get("steps", 1)) for gap in gaps for s in gap if s.get("action") == "move")

        def total(script: dict) -> int:
            return sum(int(s.get("steps", 1)) for s in script["steps"] if s.get("action") == "move")

        # Every walked cell on EACH side reached a comparison. (A gap trailing
        # the LAST spine step would be the one exception; both scripts here end
        # on `press interact`, a spine step, so neither has one.)
        self.assertGreater(total(compiled), 0)
        self.assertEqual(walked(seen_compiled), total(compiled), f"{label}: compiled-side coverage")
        self.assertEqual(walked(seen_shipped), total(shipped_script), f"{label}: shipped-side coverage")

    def test_repeated_position_pins_pair_by_cell(self) -> None:
        """#434 residue accounting (was: the MIS-PAIR known limitation).

        `_key` omits the pinned VALUE, so every `assert_state` of one path was
        one alignment token and the matcher paired an arrival with whichever it
        reached first -- the source of every net-class row in the Act I golden.
        M3.6 declined to key by value because a SUBSUMING tightening on a dict
        path (`classes`) would stop matching and read as a dropped claim.

        The fix is scoped to `player_cell`: a cell is equals-only, it subsumes
        nothing, so keying it by value cannot reclassify a tightening. Every
        other path keeps the kind-only key, and the subsumption case below
        still holds. Measured on the Act I golden: NET 9 -> 5, and the five
        that remain are genuine one-cell arrival differences (router vs corpus)
        plus two shipped `[12,12]` pins the compiler never emits -- honest
        residue, not accounting.
        """
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
        # PAIRED BY CELL: shipped [7,6] meets compiled [7,6]; compiled [6,6] is a
        # compiled-only tightening, never a changed pin.
        self.assertTrue(report.passed, report.render())
        self.assertEqual(report.exact, [])
        self.assertTrue(any("[6, 6]" in row for row in report.tighter), report.render())

        # Subsumption on a dict path is untouched: a compiled pin that SUBSUMES
        # the shipped one stays a tightening rather than becoming a dropped claim.
        tighter = diff(
            {"steps": [{"action": "assert_state", "path": "classes", "equals": {"warrior": 1, "mage": 3}},
                       {"action": "press", "name": "interact"}]},
            {"steps": [{"action": "assert_state", "path": "classes", "equals": {"warrior": 1}},
                       {"action": "press", "name": "interact"}]},
        )
        self.assertTrue(tighter.passed, tighter.render())
        self.assertEqual(len(tighter.tighter), 1)
        self.assertEqual(tighter.exact, [])

        # MUTATION: a pin the compiler DROPPED is still fatal, either way -- and
        # a DIFFERENT cell is a dropped claim plus a new one, never a silent pair.
        self.assertFalse(diff({"steps": compiled["steps"][2:]}, shipped_leg).passed)
        moved = diff({"steps": [{"action": "assert_state", "path": "player_cell", "equals": [6, 6]},
                                {"action": "press", "name": "interact"}]}, shipped_leg)
        self.assertFalse(moved.passed)
        self.assertTrue(any("dropped this claim" in row for row in moved.exact), moved.render())
        # Review (#434): a float-typed cell on one side is the SAME cell.
        floaty = diff({"steps": [{"action": "assert_state", "path": "player_cell", "equals": [7.0, 6.0]},
                                 {"action": "press", "name": "interact"}]}, shipped_leg)
        self.assertTrue(floaty.passed, floaty.render())


# ---------------------------------------------------------------------------
# §6.3's tightening allowance, extended to `wait_for_event` (ruling 2026-08-14)
# ---------------------------------------------------------------------------


class WaitTighteningTest(unittest.TestCase):
    """The ruling that unblocked M4's measurement, and the asymmetry it rests on.

    A compiled-only `wait_for_event` is strictly STRICTER than the shipped
    script and it cannot hide: if the event never fires the run does not
    finish, and `ITINERARY_RUN_GREEN` gates that. So it is a tightening.

    Every assertion below is paired with the direction that must NOT move. The
    allowance is one-way -- the compiler may claim MORE, never less -- and a
    lane that widens it symmetrically has removed the gate, not relaxed it.
    """

    ANCHOR = {"action": "press", "name": "interact"}

    def test_a_compiled_only_wait_is_a_tightening(self) -> None:
        report = diff(
            {"steps": [{"action": "wait_for_event", "type": "map_changed"}, self.ANCHOR]},
            {"steps": [self.ANCHOR]},
        )
        self.assertTrue(report.passed, report.render())
        self.assertEqual(report.exact, [])
        self.assertEqual(len(report.tightened_waits), 1)

    def test_the_allowance_does_NOT_run_the_other_way(self) -> None:
        """A wait the compiler stopped making is a DROPPED CLAIM. Still fatal."""
        report = diff(
            {"steps": [self.ANCHOR]},
            {"steps": [{"action": "wait_for_event", "type": "map_changed"}, self.ANCHOR]},
        )
        self.assertFalse(report.passed)
        self.assertEqual(len(report.exact), 1)
        self.assertIn("compiler dropped this claim", report.exact[0])
        self.assertEqual(report.tightened_waits, [])

    def test_the_allowance_covers_ONLY_the_wait_action(self) -> None:
        """A compiled-only step of any other kind is extra BEHAVIOUR, not a
        stricter claim about the same run, and stays exact-class fatal."""
        for extra in (
            {"action": "press", "name": "confirm"},
            {"action": "screenshot", "name": "99_extra"},
            {"action": "combat_autoplay", "policy": "competent"},
        ):
            with self.subTest(action=extra["action"]):
                report = diff({"steps": [self.ANCHOR, extra]}, {"steps": [self.ANCHOR]})
                self.assertFalse(report.passed, report.render())
                self.assertIn("shipped has no counterpart", report.exact[0])

    def test_a_LOOSER_compiled_wait_is_still_fatal(self) -> None:
        """The allowance is about a wait the shipped side does not MAKE. A wait
        it makes more tightly than the compiler is the loosening §6.3 forbids,
        and it is a matched pair, so it never reaches this branch at all."""
        report = diff(
            {"steps": [{"action": "wait_for_event", "type": "map_changed"}, self.ANCHOR]},
            {"steps": [{"action": "wait_for_event", "type": "map_changed",
                        "payload_contains": {"map": "inn"}}, self.ANCHOR]},
        )
        self.assertFalse(report.passed)
        self.assertEqual(report.tightened_waits, [])

    def test_every_reclassified_row_is_LOGGED_and_never_truncated(self) -> None:
        """The ruling's own condition: absorbed rows stay visible.

        `render(limit)` caps the other blocks, and a report that says "... and
        118 more" about the class it just stopped failing on is a silent pass
        wearing a receipt. So this block ignores the limit -- pinned at
        limit=1, the setting that would hide 49 of 50 rows.
        """
        waits = [{"action": "wait_for_event", "type": f"event_{n}"} for n in range(50)]
        report = diff({"steps": waits + [self.ANCHOR]}, {"steps": [self.ANCHOR]})
        self.assertTrue(report.passed, report.summary())
        self.assertEqual(len(report.tightened_waits), 50)
        rendered = report.render(limit=1)
        self.assertIn("50 compiled-only wait(s) reclassified", rendered)
        for n in range(50):
            self.assertIn(f"type=event_{n} ", rendered, f"event_{n} was not logged")

    def test_the_log_line_names_the_TYPE_even_behind_a_long_payload(self) -> None:
        """The trap `_describe` walks into, which is why waits get their own.

        `_describe` sorts keys and truncates at 220 chars, so a wait pinned on
        a 200-character line of dialogue loses `type` off the end -- the one
        field an auditor of this allowance needs most. The wait line leads with
        it instead.
        """
        step = {"action": "wait_for_event", "type": "dialogue_node", "_itin": "act1.spar",
                "payload_contains": {"speaker": "Relc", "text": "x" * 400}}
        report = diff({"steps": [step, self.ANCHOR]}, {"steps": [self.ANCHOR]})
        row = report.tightened_waits[0]
        self.assertIn("type=dialogue_node", row)
        self.assertIn("[act1.spar]", row)
        self.assertIn("compiled step 0", row)
        self.assertIn('"speaker": "Relc"', row)

    def test_the_allowance_absorbs_TWELVE_rows_of_the_authored_golden(self) -> None:
        """The measurement the ruling was made on, re-derived from the corpus.

        Not a compile (that needs the Godot oracle); the shipped prefix diffed
        against ITSELF plus the twelve waits the compiler emits and the corpus
        does not. What is pinned is the accounting: twelve compiled-only waits
        leave exact-class, and nothing else moves with them.
        """
        prefix = SHIPPED["steps"][:218]
        extra_waits = [
            ("ui_dialogue_rendered", None), ("dialogue_node", None),
            ("dialogue_node", {"speaker": "Relc"}), ("map_changed", {"map": "inn"}),
            ("phase_changed", {"slept": True}), ("class_gained", {"class": "warrior"}),
            ("ui_sleep_veil_rendered", None), ("map_changed", {"map": "inn"}),
            ("ui_dialogue_rendered", None), ("dialogue_node", None),
            ("ui_inventory_selection_rendered", {"cursor": 1}),
            ("entity_removed", {"id": "goblin_encounter_1"}),
        ]
        compiled = list(prefix)
        for event, payload in extra_waits:
            step = {"action": "wait_for_event", "type": event}
            if payload is not None:
                step["payload_contains"] = payload
            compiled.append(step)
        report = diff({"steps": compiled}, {"steps": list(prefix)})
        self.assertEqual(len(report.tightened_waits), 12, report.summary())
        self.assertEqual(report.exact, [], report.render())
        self.assertEqual(report.net, [], report.render())

        # MUTATION: turn one of them around -- a wait only the CORPUS makes --
        # and the accounting must swing to fatal rather than absorb it.
        dropped = diff({"steps": list(prefix)}, {"steps": compiled})
        self.assertFalse(dropped.passed)
        self.assertEqual(len(dropped.exact), 12, dropped.render())
        self.assertEqual(dropped.tightened_waits, [])


# ---------------------------------------------------------------------------
# THE PIPELINE TIER: node spec -> planner -> emitted steps
# ---------------------------------------------------------------------------
#
# Everything above pins one stage. These pin the CHAIN, which is what the
# criteria actually promise: an author writes a key and the run does a thing.
# An audit of the first suite severed eight links between spec and step -- the
# planner branch that reads `turn_wait`, the one that reads `via`, the one that
# toggles a sneak, the assignment that carries effect waits into the operation
# -- and the suite stayed green through every one, because it only ever tested
# the emitter's rendering of dicts a test had built by hand.


RELC_ROWS = {
    "relc_intro:meet": {"speaker": "Relc", "text": "Oi.", "options": [
        {"text": "Just a traveler. Staying at the inn, heading for Liscor.",
         "goto": "banter", "cursor_index": 0, "authored_index": 0},
    ]},
    "relc_intro:banter": {"speaker": "Relc", "text": "Ha!", "options": [
        {"text": "You any good with that spear? (Spar)", "goto": "spar_offer", "cursor_index": 0, "authored_index": 0},
    ]},
    "relc_intro:spar_offer": {"speaker": "Relc", "text": "Rules are you move and you hit.", "options": [
        {"text": "Ready when you are.", "cursor_index": 0, "authored_index": 0, "end": True},
    ]},
}
# Relc stands on (12,13) and the dummies on (13,12); both block, so an approach
# ends in a bump. The two inn doors and the sign block for the same reason.
FLOODPLAINS_BLOCKED = {(12, 13), (13, 12), (5, 6), (6, 5), (7, 5), (30, 23)}


def floodplains_pipeline(**kwargs) -> Pipeline:
    oracle = FakeOracle(blocked=FLOODPLAINS_BLOCKED, options=dict(RELC_ROWS), **kwargs)
    pipeline = Pipeline(oracle)
    pipeline.ledger.set_position("floodplains", [7, 6], [0, 1])
    return pipeline


class PipelineDialogueEntryTest(unittest.TestCase):
    """Criterion 1, from the YAML key to the emitted press."""

    SPEC = act(
        "    - id: spar\n"
        "      why: take the spar\n"
        "      fight:\n"
        "        encounter: relc_spar\n"
        "        at: floodplains\n"
        "        entry: dialogue\n"
        "        npc: relc\n"
        "        choose_path:\n"
        "          - 'Just a traveler. Staying at the inn, heading for Liscor.'\n"
        "          - 'You any good with that spear? (Spar)'\n"
        "          - 'Ready when you are.'\n"
    )

    def test_the_spec_key_produces_a_board_that_opens_on_the_confirm(self) -> None:
        steps = floodplains_pipeline().run(self.SPEC)
        kinds = [step.get("type") or f"{step['action']}:{step.get('name', '')}" for step in steps]
        # The board opens on the conversation's own confirm. The two
        # `press:interact` rows before it are the pool line and the
        # conversation open; there is no THIRD one walking to the dummies,
        # which is what `entry: interact` would have emitted here.
        opened = kinds.index("combat_started")
        self.assertEqual(kinds[opened - 1], "press:confirm")
        self.assertEqual(kinds[:opened].count("press:interact"), 2)
        self.assertNotIn("dialogue_ended", kinds)
        self.assertNotIn("ui_dialogue_hidden", kinds)

    def test_the_ledger_banks_the_spars_victory_and_spends_its_rng_epoch(self) -> None:
        pipeline = floodplains_pipeline()
        pipeline.run(self.SPEC)
        self.assertEqual(pipeline.ledger.rng_epoch, 1)
        self.assertEqual(int(pipeline.ledger.state["accomplishments"]["sparred_with_relc"]), 1)


class PipelineEffectWaitsTest(unittest.TestCase):
    """Criterion 2, from the option's effects to the emitted waits."""

    GRAPH = {"start": "hub", "nodes": {
        "hub": {"speaker": "Tester", "text": "Well?", "options": [
            {"text": "Take the parcel.", "goto": "thanks",
             "effects": [{"quest": "the_errand"}, {"accomplishment": "met_erin"}]},
        ]},
        "thanks": {"speaker": "Tester", "text": "Good.", "options": [
            {"text": "Done.", "end": True,
             "effects": [{"accomplishment": "package_delivered"}]},
        ]},
    }}
    ROWS = {
        "tester_graph:hub": {"speaker": "Tester", "text": "Well?", "options": [
            {"text": "Take the parcel.", "goto": "thanks", "cursor_index": 0, "authored_index": 0}]},
        "tester_graph:thanks": {"speaker": "Tester", "text": "Good.", "options": [
            {"text": "Done.", "cursor_index": 0, "authored_index": 0, "end": True}]},
    }
    SPEC = act(
        "    - id: talk\n"
        "      why: the errand\n"
        "      talk: {npc: tester, at: floodplains, choose_path: ['Take the parcel.', 'Done.']}\n"
    )

    def pipeline(self) -> Pipeline:
        oracle = FakeOracle(blocked=FLOODPLAINS_BLOCKED | {(9, 6)}, options=dict(RELC_ROWS, **self.ROWS))
        pipeline = Pipeline(oracle)
        pipeline.ledger.set_position("floodplains", [7, 6], [0, 1])
        pipeline.inject_npc(
            "floodplains",
            {"id": "tester", "kind": "npc", "cell": [9, 6], "display_name": "Tester", "conversation": "tester_graph"},
            self.GRAPH,
        )
        return pipeline

    def test_both_placements_reach_the_emitted_script_from_the_spec(self) -> None:
        steps = self.pipeline().run(self.SPEC)
        kinds = [step.get("type") or f"{step['action']}:{step.get('name', '')}" for step in steps]
        confirms = [index for index, kind in enumerate(kinds) if kind == "press:confirm"]
        self.assertEqual(len(confirms), 2)
        # CONTINUING row: quest_started then the counter, THEN the destination.
        self.assertEqual(kinds[confirms[0] + 1:confirms[0] + 4],
                         ["quest_started", "accomplishment_recorded", "dialogue_node"])
        # CLOSING row: the teardown pair FIRST, then the announcements. This
        # is the inversion the emitter's own comment calls fatal. The shipped
        # graphs carry plenty of end-rows with effects and the corpus pins
        # four such sites (1038-1041, 1122-1125, 1948-1951, 2147-2150); what
        # no AUTHORED ITINERARY reaches yet is any of them, so without this
        # assertion the inversion would compile a byte-identical golden.
        self.assertEqual(kinds[confirms[1] + 1:confirms[1] + 6],
                         ["dialogue_ended", "ui_dialogue_hidden",
                          "accomplishment_recorded", "quest_beat_completed", "wait_frames:"])

    def test_the_quest_join_payloads_are_derived_end_to_end(self) -> None:
        steps = self.pipeline().run(self.SPEC)
        pinned = {
            str(step["type"]): step.get("payload_contains")
            for step in steps if step.get("action") == "wait_for_event"
        }
        self.assertEqual(pinned["quest_started"], {"id": "the_errand"})
        self.assertEqual(pinned["accomplishment_recorded"], {"id": "package_delivered", "count": 1})
        self.assertEqual(pinned["quest_beat_completed"], {"id": "the_errand", "beat": 1})


class PipelineFrameKeyTest(unittest.TestCase):
    """Criterion 3, one spec key at a time, spec -> step."""

    def fight(self, extra: str) -> list[dict]:
        spec = act(
            "    - id: ambush\n"
            "      why: the climax\n"
            "      fight:\n"
            "        encounter: goblin_encounter_1\n"
            "        at: floodplains\n"
            "        entry: proximity\n"
            f"{extra}"
        )
        return floodplains_pipeline().run(spec)

    def test_turn_wait_beats_arena_and_banks_all_travel_from_the_spec(self) -> None:
        plain = self.fight("")
        self.assertIn("turn_started", [step.get("type") for step in plain])

        quiet = self.fight("        turn_wait: false\n")
        self.assertNotIn("turn_started", [step.get("type") for step in quiet])

        beaten = self.fight("        beats: {before_turn: [real_ones], after_combat: [road_clear]}\n")
        tutor = [step["payload_contains"]["beat"] for step in beaten if step.get("type") == "ui_tutor_line_rendered"]
        self.assertEqual(tutor, ["real_ones", "road_clear"])
        kinds = [step.get("type") or f"{step['action']}:{step.get('name', '')}" for step in beaten]
        self.assertLess(kinds.index("ui_tutor_line_rendered"), kinds.index("turn_started"))
        self.assertGreater(len(kinds) - 1 - kinds[::-1].index("ui_tutor_line_rendered"), kinds.index("combat_finished"))

        arena = self.fight("        arena: goblin_ambush_tutorial\n")
        started = next(step for step in arena if step.get("type") == "combat_started")
        self.assertEqual(started.get("payload_contains"), {"arena": "goblin_ambush_tutorial"})
        self.assertIsNone(next(step for step in plain if step.get("type") == "combat_started").get("payload_contains"))

        banked = self.fight("        expect_banks_after_dismiss: true\n")
        kinds = [step.get("type") or f"{step['action']}:{step.get('name', '')}" for step in banked]
        dismiss = len(kinds) - 1 - kinds[::-1].index("press:confirm")
        self.assertEqual(kinds[dismiss + 1], "accomplishment_recorded")
        self.assertEqual(kinds[dismiss + 2], "entity_removed")
        self.assertEqual(kinds[dismiss + 3], "ui_combat_hidden")
        self.assertNotIn("accomplishment_recorded", [step.get("type") for step in plain])

    def test_goto_via_and_expect_render_travel_from_the_spec(self) -> None:
        west = floodplains_pipeline().run(act("    - id: g\n      goto: {map: inn, via: floodplains_inn_door_west}\n"))
        default = floodplains_pipeline().run(act("    - id: g\n      goto: {map: inn}\n"))
        # Both enter the inn; they walk to DIFFERENT doors, which is the whole
        # point -- (6,5) is one cell west of (7,5).
        self.assertNotEqual([step for step in west if step["action"] == "move"],
                            [step for step in default if step["action"] == "move"])
        self.assertEqual(sum(s["steps"] for s in west if s["action"] == "move" and s["direction"] == "left"), 1)
        self.assertEqual(sum(s["steps"] for s in default if s["action"] == "move" and s["direction"] == "left"), 0)

        rendered = floodplains_pipeline().run(act("    - id: g\n      goto: {map: inn, expect_render: true}\n"))
        self.assertEqual(rendered[-2:], [
            {"action": "wait_frames", "frames": 10},
            {"action": "assert_event_logged", "type": "ui_map_rendered", "payload_contains": {"map": "inn"}},
        ])
        self.assertNotIn("ui_map_rendered", [step.get("type") for step in default])

    def test_expect_epilogue_travels_from_the_spec(self) -> None:
        pipeline = floodplains_pipeline()
        loud = pipeline.run(act("    - id: s\n      sleep: {expect_epilogue: true}\n"))
        self.assertEqual([step.get("type") for step in loud][-2:],
                         ["ui_sleep_veil_finished", "ui_gdi_epilogue_rendered"])
        quiet = floodplains_pipeline().run(act("    - id: s\n      sleep: {}\n"))
        self.assertNotIn("ui_gdi_epilogue_rendered", [step.get("type") for step in quiet])


class PipelineSneakTest(unittest.TestCase):
    """Criterion 4: the stance is cast, spent, and re-refused, from specs."""

    BAR = [{"skill": "invisibility", "slot": 4, "number_key_reachable": True}]

    def pipeline(self) -> Pipeline:
        oracle = FakeOracle(blocked=FLOODPLAINS_BLOCKED, options=dict(RELC_ROWS), field_bar=self.BAR)
        pipeline = Pipeline(oracle)
        pipeline.ledger.set_position("floodplains", [30, 18], [0, 1])
        return pipeline

    # (30,21) is inside goblin_encounter_1's Chebyshev-2 radius around (30,23);
    # it is the exact cell the shipped script steps into to spring it (195).
    NEAR_AMBUSH = act("    - id: creep\n      goto: {map: floodplains, cell: [30, 21]}\n")
    CLOAK = act("    - id: cloak\n      use_field: {skill: invisibility}\n")
    SIGN = act("    - id: sign\n      interact: {prop: inn_sign, at: floodplains}\n")

    def test_the_walk_is_refused_uncloaked_and_allowed_cloaked(self) -> None:
        with self.assertRaisesRegex(Exception, "proximity encounter"):
            self.pipeline().run(self.NEAR_AMBUSH)

        pipeline = self.pipeline()
        cast = pipeline.run(self.CLOAK)
        self.assertEqual([step.get("type") for step in cast[1:]], ["skill_used", "sneak_started", "toast"])
        self.assertTrue(pipeline.ledger.sneaking)
        # Same walk, same map, same encounter -- the stance is the difference.
        pipeline.run(self.NEAR_AMBUSH)

    def test_a_prop_interact_spends_the_stance_and_the_refusal_returns(self) -> None:
        pipeline = self.pipeline()
        pipeline.run(self.CLOAK)
        pipeline.run(self.SIGN)
        self.assertFalse(pipeline.ledger.sneaking)
        with self.assertRaisesRegex(Exception, "proximity encounter"):
            pipeline.run(self.NEAR_AMBUSH)

    def test_casting_again_drops_it_and_says_the_other_line(self) -> None:
        pipeline = self.pipeline()
        pipeline.run(self.CLOAK)
        drop = pipeline.run(self.CLOAK)
        self.assertEqual([step.get("type") for step in drop[1:]], ["skill_used", "sneak_ended", "toast"])
        self.assertEqual(drop[3]["payload_contains"], {"text": "You straighten up."})
        self.assertFalse(pipeline.ledger.sneaking)


if __name__ == "__main__":
    unittest.main()
