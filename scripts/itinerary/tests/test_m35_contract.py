"""M3.5 contract: the two amended primitives, the creation prelude, the fence.

The 2026-08-13 pre-M4 design note ruled three things into existence, and this
suite is the mechanical half of each:

  1. `fight: {mode: driven, turns: [...]}` and `journal` -- the two idioms the
     M3 golden measured missing in 2569 corpus steps. Both are EXACT-CLASS in
     goldens, which means their emitted shape is a promise and not a
     preference, so each is pinned step for step against the corpus rows it was
     shaped from (steel_thread 74-115 and 561-566 / 2317-2322).
  2. The `creation:` prelude §8 already ruled buildable-as-a-pass.
  3. The pass-2 plan-spine equality fence: refine may tighten pins, never
     re-plan.

Every assertion here is paired with a deliberate break that makes it red --
the lane's mutation-proof discipline. A test that would still pass against a
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

from scripts.itinerary.compile_itinerary import (  # noqa: E402
    Build,
    CompileError,
    _creation_operation,
    _fence_plan_spine,
    _plan_spine,
)
from scripts.itinerary.emit import Emitter  # noqa: E402
from scripts.itinerary.ledger import Ledger  # noqa: E402
from scripts.itinerary.planners.combat import CombatPlanner  # noqa: E402
from scripts.itinerary.replay import checkpoint_from, self_check  # noqa: E402
from scripts.itinerary.schema import SchemaError, load_itinerary  # noqa: E402


PROJECT = ROOT / "wandering_inn_game"
SHIPPED = json.loads((PROJECT / "qa/scripts/steel_thread.json").read_text(encoding="utf-8"))


def bare(steps: list[dict]) -> list[dict]:
    """Steps as the golden differ reads them: no stamps, no timeouts."""
    return [
        {key: value for key, value in step.items() if key not in ("_itin", "_comment", "timeout_sec")}
        for step in steps
    ]


def shipped(lo: int, hi: int) -> list[dict]:
    """The shipped corpus rows [lo, hi], inclusive, comment-free."""
    return bare(SHIPPED["steps"][lo:hi + 1])


def document(body: str, milestone: int = 3):
    with tempfile.TemporaryDirectory() as td:
        path = Path(td) / "itin.yaml"
        path.write_text(body, encoding="utf-8")
        return load_itinerary(path, milestone=milestone)


# ---------------------------------------------------------------------------
# 1a. fight.driven
# ---------------------------------------------------------------------------


# The Relc spar, transcribed. Steps 74-115 of the shipped script are the shape
# this primitive was ruled into existence to express, so the acceptance row IS
# that transcription rather than a convenient smaller example.
SPAR_TURNS = [
    {"logged": "ui_hotbar_rendered", "where": {"slots": 3}},
    {"beat": "opening"},
    {"await": "turn_started", "where": {"id": "pc"}},
    {"settle": 5},
    {"pin": {"path": "combat.active", "equals": "pc"}},
    {"pin": {"path": "combat.combatants.pc.cell", "equals": [2, 3]}},
    {"press": "move_right"},
    {"await": "combatant_moved", "where": {"id": "pc", "cell": [3, 3]}},
    {"beat": "first_step"},
    {"press": "move_right"},
    {"await": "combatant_moved", "where": {"id": "pc", "cell": [4, 3]}},
    {"press": "move_right"},
    {"await": "combatant_moved", "where": {"id": "pc", "cell": [5, 3]}},
    {"beat": "pool_empty"},
    {"pin": {"path": "combat.combatants.pc.move_pool", "equals": 0}},
    {"press": "hotbar_2"},
    {"press": "confirm"},
    {"await": "dashed", "where": {"id": "pc", "move_pool": 3}},
    {"beat": "dash"},
    {"press": "move_right"},
    {"await": "combatant_moved", "where": {"id": "pc", "cell": [6, 3]}},
    {"press": "hotbar_1"},
    {"await": "ui_targeting_shown"},
    {"beat": "aim"},
    {"press": "cycle"},
    {"press": "confirm"},
    {"await": "attack_resolved", "where": {"attacker": "pc"}},
    {"beat": "first_blood"},
    {"press": "end_turn"},
    {"await": "turn_ended", "where": {"id": "pc"}},
    {"beat": "watch"},
    {"autoplay": True},
    {"beat": "wrap"},
]


class DrivenFightTest(unittest.TestCase):
    def operation(self, **changes) -> dict:
        operation = {
            "kind": "fight", "mode": "driven", "entry": "interact", "encounter": "relc_spar",
            "allies": [], "policy": "competent", "max_turns": 200,
            "turns": [dict(turn) for turn in SPAR_TURNS],
            "victory_pins": [{"path": "accomplishments.sparred_with_relc", "equals": 1}],
        }
        operation.update(changes)
        return operation

    def test_the_turn_list_reproduces_the_shipped_spar_beat_for_beat(self) -> None:
        """steel_thread 75-114, minus the entry press the spar takes from dialogue."""
        steps = bare(Emitter().emit("n", [self.operation(entry="proximity")]))
        self.assertEqual(steps, shipped(75, 114))

        # MUTATION: drop one tutor beat and the reproduction stops being one.
        # This is the whole reason the primitive exists -- an autoplayed spar
        # fires no beats in order, so a turn list that silently loses one is
        # indistinguishable from the gap this amendment closed.
        thinner = [turn for turn in SPAR_TURNS if turn.get("beat") != "dash"]
        self.assertNotEqual(bare(Emitter().emit("n", [self.operation(entry="proximity", turns=thinner)])), shipped(75, 114))

    def test_the_emitter_still_owns_the_frame_around_the_turns(self) -> None:
        """Open, dismiss and victory-pin are the emitter's in BOTH modes."""
        steps = bare(Emitter().emit("n", [self.operation()]))
        self.assertEqual(steps[0], {"action": "press", "name": "interact"})
        self.assertEqual(steps[1]["type"], "combat_started")
        self.assertEqual(steps[2]["type"], "ui_combat_shown")
        # ... turns ... then the banner dismiss the author never writes.
        self.assertEqual(steps[-4], {"action": "press", "name": "confirm"})
        self.assertEqual(steps[-3]["type"], "ui_combat_hidden")
        self.assertEqual(steps[-2], {"action": "wait_frames", "frames": 5})
        self.assertEqual(steps[-1], {"action": "assert_state", "path": "accomplishments.sparred_with_relc", "equals": 1})

        # The victory wait rides with the autoplay handover, so `expect:
        # victory` cannot be forgotten by an author writing the turns.
        victory = [step for step in steps if step.get("type") == "combat_finished"]
        self.assertEqual(victory, [{"action": "wait_for_event", "type": "combat_finished", "payload_contains": {"victory": True}}])

        # MUTATION: an ally gate still fires in driven mode -- driven changes
        # who plays the turns, not who is on the board.
        allied = bare(Emitter().emit("n", [self.operation(allies=["relc"])]))
        self.assertIn({"action": "assert_state", "path": "combat.combatants.relc.side", "equals": "player"}, allied)

    def test_a_driven_fight_is_planned_exactly_like_an_autoplayed_one(self) -> None:
        """The planner carries the list across; it does not interpret it."""
        planner = CombatPlanner.__new__(CombatPlanner)
        entity = {"id": "crate_scavengers", "kind": "encounter", "cell": [5, 5], "on_victory": ["victories"]}
        ledger = Ledger.fresh()
        ops = CombatPlanner._finish(
            planner, "n", {"mode": "driven", "turns": SPAR_TURNS}, ledger, entity, [], "interact"
        )
        self.assertEqual(ops[-1]["mode"], "driven")
        self.assertEqual(ops[-1]["turns"], SPAR_TURNS)
        # Same victory ledger, same rng epoch: a driven fight is still a fight.
        self.assertEqual(ledger.rng_epoch, 1)
        self.assertIn("crate_scavengers", ledger.state["removed_entities"])

        # MUTATION: autoplay mode must NOT carry a turn list into the emitter,
        # or a stray `turns` key would silently switch shapes.
        autoplayed = CombatPlanner._finish(
            planner, "n", {"turns": SPAR_TURNS}, Ledger.fresh(), entity, [], "interact"
        )
        self.assertNotIn("mode", autoplayed[-1])
        self.assertNotIn("turns", autoplayed[-1])

    def test_the_schema_refuses_every_shape_that_would_hang_or_lie(self) -> None:
        cases = [
            ("fight: {encounter: x, mode: manual}", "mode must be one of"),
            ("fight: {encounter: x, turns: [{press: end_turn}]}", "mode is autoplay"),
            ("fight: {encounter: x, mode: driven, turns: []}", "needs a non-empty turns list"),
            # No autoplay entry: the board never finishes and every step after
            # it is eaten by a live combat.
            ("fight: {encounter: x, mode: driven, turns: [{press: end_turn}]}", "needs exactly 1"),
            ("fight: {encounter: x, mode: driven, turns: [{autoplay: true}, {autoplay: true}]}", "needs exactly 1"),
            # `interact` on a live board is how a driven turn desyncs.
            ("fight: {encounter: x, mode: driven, turns: [{press: interact}, {autoplay: true}]}", "not a combat-board press"),
            ("fight: {encounter: x, mode: driven, turns: [{press: a, beat: b}, {autoplay: true}]}", "needs exactly one of"),
            ("fight: {encounter: x, mode: driven, turns: [{beat: b, where: {a: 1}}, {autoplay: true}]}", "only qualifies await/logged"),
            ("fight: {encounter: x, mode: driven, turns: [{pin: {equals: 1}}, {autoplay: true}]}", "pin needs a path"),
            ("fight: {encounter: x, mode: driven, turns: [{settle: 0}, {autoplay: true}]}", "positive frame count"),
            ("fight: {encounter: x, mode: driven, turns: [{autoplay: {max_turns: 4}}]}", "autoplay: true"),
            ("fight: {encounter: x, mode: driven, shots: [a], turns: [{autoplay: true}]}", "not `shots:`"),
            ("fight: {encounter: x, mode: driven, turns: [{jump: 1}, {autoplay: true}]}", "needs exactly one of"),
        ]
        for body, message in cases:
            with self.assertRaisesRegex(SchemaError, message, msg=body):
                document(f"- act: i\n  nodes:\n    - id: n\n      {body}\n")

        # And the shape the corpus actually uses parses.
        parsed = document(
            "- act: i\n  nodes:\n    - id: n\n      fight:\n        encounter: relc_spar\n        mode: driven\n"
            "        turns: [{beat: opening}, {press: end_turn}, {autoplay: true}, {beat: wrap}]\n"
        )
        self.assertEqual(parsed.nodes[0].spec["mode"], "driven")
        self.assertEqual(len(parsed.nodes[0].spec["turns"]), 4)


# ---------------------------------------------------------------------------
# 1b. journal
# ---------------------------------------------------------------------------


class JournalTest(unittest.TestCase):
    def test_it_reproduces_both_shipped_journal_reads(self) -> None:
        # steel_thread 561-566: an album beat, no act pin. The 240-frame hold
        # after the capture is tolerance-class (§6.3), so the pinned shape is
        # the corpus row with its hold removed.
        acts = bare(Emitter().emit("n", [{"kind": "journal", "capture": "05_act_iii_01_journal_acts", "act": ""}]))
        self.assertEqual(acts, [row for row in shipped(561, 566) if row["action"] != "wait_frames"])

        # steel_thread 2317-2322: the same idiom, tightened to the act page the
        # book opened on.
        act_v = bare(Emitter().emit("n", [{"kind": "journal", "capture": "08_act_v_00_journal_act_v", "act": "act_v"}]))
        self.assertEqual(act_v, [row for row in shipped(2317, 2322) if row["action"] != "wait_frames"])

        # MUTATION: the `act` pin is a real claim, not decoration -- dropping
        # it turns the Act V read into the Act III one.
        self.assertNotIn("payload_contains", acts[1])
        self.assertEqual(act_v[1]["payload_contains"], {"act_id": "act_v"})

    def test_the_close_is_the_emitters_and_a_capture_is_optional(self) -> None:
        quiet = bare(Emitter().emit("n", [{"kind": "journal", "capture": "", "act": ""}]))
        self.assertEqual([step["action"] for step in quiet], ["press", "wait_for_event", "press", "wait_for_event"])
        self.assertEqual(quiet[-1]["type"], "ui_journal_hidden")

        # MUTATION: a journal left open eats the next press, and the replay
        # self-check is what says so rather than a live run finding out.
        ledger = Ledger.fresh()
        checkpoint = checkpoint_from(ledger, "n", "journal")
        opened = [dict(step, _itin="n") for step in quiet[:2]]
        problems = self_check(opened, [checkpoint], checkpoint)
        self.assertTrue(any("still open" in row for row in problems), problems)
        self.assertEqual(self_check([dict(step, _itin="n") for step in quiet], [checkpoint], checkpoint), [])

    def test_the_schema_refuses_a_nameless_capture(self) -> None:
        for body, message in (
            ("journal: {capture: ''}", "capture must be a screenshot name"),
            ("journal: {act: ''}", "act must be an act id"),
            ("journal: {page: 2}", "unknown keys"),
        ):
            with self.assertRaisesRegex(SchemaError, message):
                document(f"- act: i\n  nodes:\n    - id: n\n      {body}\n")
        self.assertEqual(document("- act: i\n  nodes:\n    - id: n\n      journal: {}\n").nodes[0].primitive, "journal")


# ---------------------------------------------------------------------------
# 2. the creation prelude (§8)
# ---------------------------------------------------------------------------


class CreationPreludeTest(unittest.TestCase):
    CREATION = {
        "race": "drake", "gender": "f", "name": "Sella", "difficulty": "Silver Rank",
        "hints": True, "tap_back": True,
        "shots": {
            "gate": "00_title_gate", "menu": "00_title_menu",
            "picker": "01_creation_00_picker_grid_drake_f_selected",
            "name": "01_creation_01_name_step_begin_control",
            "difficulty": "01_creation_02_creation_difficulty", "hints": "02_creation_hints",
            "world": "01_creation_char_creation_drake_f_inn",
        },
    }

    def test_it_reproduces_the_shipped_creation_beat_for_beat(self) -> None:
        """steel_thread 0-40: the whole title-to-world opening."""
        steps = bare(Emitter().emit("start", [_creation_operation(self.CREATION)]))
        self.assertEqual(steps, shipped(0, 40))

    def test_the_card_index_is_derived_from_the_picker_grid_not_written_down(self) -> None:
        """PC_OPTIONS is row-major 2x3, and the driver taps card_rect(n-1)."""
        for race, gender, right, down, card in (
            ("human", "m", 0, 0, 1), ("drake", "m", 1, 0, 2), ("gnoll", "m", 2, 0, 3),
            ("human", "f", 0, 1, 4), ("drake", "f", 1, 1, 5), ("gnoll", "f", 2, 1, 6),
        ):
            operation = dict(self.CREATION, race=race, gender=gender, shots={})
            steps = bare(Emitter().emit("start", [_creation_operation(operation)]))
            moves = [step for step in steps if step["action"] == "move"]
            self.assertEqual(sum(s["steps"] for s in moves if s["direction"] == "right"), right)
            self.assertEqual(sum(s["steps"] for s in moves if s["direction"] == "down"), down)
            taps = [step for step in steps if step["action"] == "click_char_creation_card"]
            self.assertEqual(taps[0]["card"], card, f"{race}/{gender}")
            self.assertIn({"action": "assert_state", "path": "pc_sprite", "equals": f"pc_{race}_{gender}"}, steps)

        # MUTATION: a card index that does not track the cursor would tap a
        # DIFFERENT PC than the one the picker highlighted, and the confirmed
        # payload is what would have caught it on a live run.
        gnoll = bare(Emitter().emit("start", [_creation_operation(dict(self.CREATION, race="gnoll", shots={}))]))
        self.assertNotEqual(
            [step for step in gnoll if step["action"] == "click_char_creation_card"][0]["card"],
            [step for step in bare(Emitter().emit("start", [_creation_operation(dict(self.CREATION, shots={}))]))
             if step["action"] == "click_char_creation_card"][0]["card"],
        )

    def test_the_scalars_that_would_compile_a_lie_are_refused(self) -> None:
        for body, message in (
            ("{gender: f, name: S, difficulty: Silver Rank}", "needs race"),
            ("{race: drake, gender: f, name: S, difficulty: Platinum}", "is not one of"),
            ("{race: drake, gender: f, name: S, difficulty: Silver Rank, hints: maybe}", "hints must be boolean"),
            ("{race: drake, gender: f, name: S, difficulty: Silver Rank, shots: {epilogue: x}}", "unknown slots"),
            ("{race: drake, gender: f, name: S, difficulty: Silver Rank, sprite: x}", "unknown keys"),
        ):
            with self.assertRaises((SchemaError, CompileError), msg=body):
                creation = document(f"- act: i\n  creation: {body}\n  nodes:\n    - id: n\n      shot: {{name: s}}\n").creation
                _creation_operation(creation)

    def test_an_itinerary_cannot_both_create_a_pc_and_load_one(self) -> None:
        with self.assertRaisesRegex(SchemaError, "either creates a PC"):
            document(
                "- act: i\n  start: ../../wandering_inn_game/qa/fixtures/post_tutorial_street.json\n"
                "  creation: {race: drake, gender: f, name: S, difficulty: Silver Rank}\n"
                "  nodes:\n    - id: n\n      shot: {name: s}\n"
            )


# ---------------------------------------------------------------------------
# 3. the pass-2 plan-spine equality fence
# ---------------------------------------------------------------------------


def build(steps: list[dict], nodes: list[str] | None = None, detours: list[dict] | None = None) -> Build:
    return Build(
        document=None, script={"steps": steps}, checkpoints=[], start_checkpoint=None,
        nodes=nodes if nodes is not None else ["a.goto", "a.fight"],
        detours=detours or [], report=None,
    )


class PlanSpineFenceTest(unittest.TestCase):
    PASS1 = [
        {"_itin": "a.goto", "action": "move", "direction": "up", "steps": 4},
        {"_itin": "a.goto", "action": "press", "name": "interact"},
        {"_itin": "a.goto", "action": "wait_for_event", "type": "map_changed", "payload_contains": {"map": "inn"}},
        {"_itin": "a.fight", "action": "combat_autoplay", "max_turns": 300, "policy": "competent"},
        {"_itin": "a.fight", "action": "wait_for_event", "type": "combat_finished", "payload_contains": {"victory": True}},
    ]

    def refined(self) -> list[dict]:
        """What pass 2 is ALLOWED to do: append asserts, tighten payloads."""
        steps = json.loads(json.dumps(self.PASS1))
        steps[2]["payload_contains"]["cell"] = [7, 3]
        steps.append({"_itin": "a.fight", "action": "assert_state", "path": "accomplishments.won_combat", "equals": 2})
        return steps

    def test_tightening_pins_passes_the_fence(self) -> None:
        _fence_plan_spine(build(self.PASS1), build(self.refined()))
        # The excluded surface really is excluded, not merely tolerated.
        self.assertEqual(_plan_spine({"steps": self.PASS1}), _plan_spine({"steps": self.refined()}))
        probed = self.PASS1 + [{"_itin": "a.fight", "action": "dump_state", "label": "a.fight"}]
        self.assertEqual(_plan_spine({"steps": probed}), _plan_spine({"steps": self.PASS1}))

    def test_a_re_planned_route_is_a_compile_error_not_a_warning(self) -> None:
        """MUTATION: a harvested value reaches a planner and moves the walk."""
        replanned = json.loads(json.dumps(self.PASS1))
        replanned[0]["steps"] = 2  # the gate opened, so pass 2 took a shorter leg
        with self.assertRaises(CompileError) as caught:
            _fence_plan_spine(build(self.PASS1), build(replanned))
        self.assertIn("different ROUTE", str(caught.exception))
        self.assertIn("refines PINS, not the PLAN", str(caught.exception))

    def test_a_changed_node_list_and_a_dropped_detour_are_both_fatal(self) -> None:
        with self.assertRaisesRegex(CompileError, "different NODE LIST"):
            _fence_plan_spine(build(self.PASS1), build(self.PASS1, nodes=["a.goto"]))

        # §2.3 resolves to FLAG-only: pass 2 may report an unnecessary detour
        # and may never drop it, because every rng draw behind it moves.
        with self.assertRaisesRegex(CompileError, "different set of earn-DETOURS"):
            _fence_plan_spine(
                build(self.PASS1, detours=[{"node": "a.buy", "detour": "inn_chore_dirty_table"}]),
                build(self.PASS1, detours=[]),
            )

    def test_an_extra_press_is_caught_even_when_the_route_length_matches(self) -> None:
        """A re-plan need not be longer to be a different run."""
        swapped = json.loads(json.dumps(self.PASS1))
        swapped[1]["name"] = "confirm"
        with self.assertRaisesRegex(CompileError, "different ROUTE"):
            _fence_plan_spine(build(self.PASS1), build(swapped))


if __name__ == "__main__":
    unittest.main()
