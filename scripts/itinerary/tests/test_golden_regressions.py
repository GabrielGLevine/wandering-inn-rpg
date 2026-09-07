"""Independent counterexamples for ordered checkpoints and movement accounting."""

from __future__ import annotations

import unittest

from scripts.itinerary.goldens import diff


def move(direction="down", steps=1, *, bump=False):
    return {"action": "move", "direction": direction, "steps": steps, **({"_bump": True} if bump else {})}


def wait(event="quest_started", **extra):
    return {"action": "wait_for_event", "type": event, "payload_contains": {"id": "job"}, **extra}


INTERACT = {"action": "press", "name": "interact"}
JOURNAL = {"action": "press", "name": "journal"}
PIN = {"action": "assert_state", "path": "player_cell", "equals": [5, 15]}
LOGGED = {"action": "assert_event_logged", "type": "quest_started", "payload_contains": {"id": "job"}}


class GoldenRegressionTest(unittest.TestCase):
    def compare(self, compiled, shipped):
        return diff({"steps": compiled}, {"steps": shipped})

    def assertEquivalent(self, compiled, shipped):
        report = self.compare(compiled, shipped)
        self.assertTrue(report.passed, report.render())

    def assertDifferent(self, compiled, shipped):
        report = self.compare(compiled, shipped)
        self.assertFalse(report.passed, report.render())
        return report

    def test_repeated_domain_wait_cannot_reuse_the_first_event(self):
        event = {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"speaker": "Selys"}}
        report = self.assertDifferent([event, INTERACT, {**event, "from_start": True}], [event, INTERACT, event])
        self.assertTrue(report.exact)

    def test_from_start_default_and_explicit_false_are_equivalent(self):
        self.assertEquivalent([wait(from_start=False), INTERACT, wait()], [wait(), INTERACT, wait(from_start=False)])

    def test_unchanged_history_waits_are_equivalent(self):
        steps = [wait(), INTERACT, wait(from_start=True)]
        self.assertEquivalent(steps, steps)

    def test_render_waits_do_not_erase_cursor_semantics(self):
        render = {"action": "wait_for_event", "type": "ui_toast_rendered", "payload_contains": {"text": "Paid"}}
        for compiled, shipped in [(render, {**render, "from_start": True}), ({**render, "from_start": True}, render)]:
            with self.subTest(compiled=compiled):
                self.assertDifferent([wait(), compiled, INTERACT, wait()], [wait(), shipped, INTERACT, wait()])

    def test_future_wait_does_not_cover_a_pre_interaction_assertion(self):
        self.assertDifferent([INTERACT, wait()], [LOGGED, INTERACT])

    def test_wait_at_the_same_checkpoint_covers_logged_assertion(self):
        self.assertEquivalent([wait(), INTERACT], [LOGGED, INTERACT])

    def test_an_earlier_completed_wait_covers_a_later_logged_assertion(self):
        self.assertEquivalent([wait(), INTERACT], [INTERACT, LOGGED])

    def test_checkpoint_substitution_requires_the_payload(self):
        self.assertDifferent([wait(payload_contains={}), INTERACT], [LOGGED, INTERACT])
        self.assertEquivalent([wait(payload_contains={"id": "job", "source": "Selys"}), INTERACT], [LOGGED, INTERACT])

    def test_wait_cannot_move_an_assertion_past_a_walk(self):
        self.assertDifferent([move(), wait(), INTERACT], [LOGGED, move(), INTERACT])

    def test_out_and_back_movement_cannot_supply_an_earlier_event(self):
        self.assertDifferent(
            [INTERACT, move(), move("up"), wait(), JOURNAL],
            [INTERACT, LOGGED, move(), move("up"), JOURNAL],
        )

    def test_overshoot_and_return_cannot_supply_an_earlier_event(self):
        self.assertDifferent(
            [move(steps=2), move("up"), wait(), move(), INTERACT],
            [move(), LOGGED, move(), INTERACT],
        )

    def test_cursor_presses_preserve_the_same_movement_prefix(self):
        self.assertEquivalent(
            [{"action": "press", "name": "move_down"}, move(), wait(), INTERACT],
            [move(steps=2), LOGGED, INTERACT],
        )

    def test_equivalent_walks_to_the_assertion_checkpoint_are_allowed(self):
        self.assertEquivalent([move(steps=2), wait(), INTERACT], [move(), move(), LOGGED, INTERACT])

    def test_dropped_tail_movement_is_fatal(self):
        report = self.assertDifferent([JOURNAL], [JOURNAL, move(steps=10)])
        self.assertTrue(report.net)

    def test_added_tail_movement_is_fatal(self):
        self.assertDifferent([JOURNAL, move(steps=10)], [JOURNAL])

    def test_tail_after_an_unmatched_tightening_is_not_lost(self):
        self.assertDifferent([JOURNAL, PIN, move(steps=3)], [JOURNAL, move(steps=2)])

    def test_a_script_with_only_movement_still_has_a_destination(self):
        self.assertDifferent([move(steps=3)], [move(steps=4)])
        self.assertEquivalent([move(), move(steps=2)], [move(steps=3)])

    def test_equivalent_tail_routes_and_settle_time_are_allowed(self):
        self.assertEquivalent([JOURNAL, move(), {"action": "wait_frames", "frames": 3}, move()], [JOURNAL, move(steps=2)])

    def test_a_bump_does_not_discount_movement_after_interaction(self):
        self.assertDifferent([move(bump=True), INTERACT, JOURNAL], [move(), INTERACT, move(), JOURNAL])

    def test_an_unmirrored_bump_cannot_cross_an_interaction(self):
        self.assertDifferent([move(bump=True), INTERACT, JOURNAL], [INTERACT, move(), JOURNAL])

    def test_a_mirrored_bump_cannot_be_spent_again_after_a_pin(self):
        self.assertDifferent([move(bump=True), PIN, JOURNAL], [move(), PIN, move(), JOURNAL])

    def test_bump_before_or_after_the_same_pin_is_equivalent(self):
        compiled = [move("left", 5), PIN, move(bump=True), PIN, INTERACT]
        for shipped in [
            [move("left", 5), PIN, move(), INTERACT],
            [move("left", 5), PIN, move(), PIN, INTERACT],
            [move("left", 5), move(), PIN, INTERACT],
        ]:
            with self.subTest(shipped=shipped):
                self.assertEquivalent(compiled, shipped)

    def test_a_merged_bump_preserves_the_actual_walk(self):
        compiled = [move(steps=2), PIN, move(bump=True), PIN, INTERACT]
        self.assertEquivalent(compiled, [move(steps=3), PIN, INTERACT])
        self.assertDifferent(compiled, [move(steps=4), PIN, INTERACT])

    def test_post_pin_bump_discount_is_only_one_step_and_directional(self):
        compiled = [move(bump=True), PIN, INTERACT]
        self.assertEquivalent(compiled, [PIN, move(), INTERACT])
        self.assertDifferent(compiled, [PIN, move(steps=2), INTERACT])
        self.assertDifferent(compiled, [PIN, move("left"), INTERACT])

    def test_a_bump_may_be_mirrored_at_the_tail_but_not_after_interact(self):
        self.assertEquivalent([move(bump=True), PIN], [PIN, move()])
        self.assertDifferent([move(bump=True), INTERACT], [move(), INTERACT, move()])


if __name__ == "__main__":
    unittest.main()
