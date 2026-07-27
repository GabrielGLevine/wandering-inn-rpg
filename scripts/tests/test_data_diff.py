#!/usr/bin/env python3
"""GH#275: data_diff renderers + the D5 fallback invariant. Run manually:
    python3 scripts/tests/test_data_diff.py -v"""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME_SCRIPTS = REPO_ROOT / "wandering_inn_game" / "scripts"
sys.path.insert(0, str(GAME_SCRIPTS))
import data_diff  # noqa: E402


class TestDeepDiff(unittest.TestCase):
    def test_dict_recursion_and_kinds(self):
        entries = data_diff.deep_diff(
            {"a": 1, "b": {"x": 1}, "c": 2}, {"a": 1, "b": {"x": 2}, "d": 3})
        kinds = {(p, k) for p, k, *_ in entries}
        self.assertEqual(kinds, {("b.x", "changed"), ("c", "removed"), ("d", "added")})

    def test_lists_compare_whole(self):
        entries = data_diff.deep_diff({"l": [1, 2]}, {"l": [2, 1]})
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0][0], "l")


class TestRenderers(unittest.TestCase):
    def test_map_entity_add_move_remove_blocked(self):
        old = {"grid": {"width": 5, "height": 5},
               "blocked": [[1, 1]],
               "entities": [{"id": "a", "cell": [0, 0]}, {"id": "b", "cell": [2, 2]}]}
        new = {"grid": {"width": 5, "height": 5},
               "blocked": [[3, 3]],
               "entities": [{"id": "a", "cell": [1, 0]},
                            {"id": "c", "cell": [4, 4], "kind": "prop", "door_when": {}}]}
        text = "\n".join(data_diff.render_map("m", old, new))
        self.assertIn("**a** moved [0, 0] -> [1, 0]", text)
        self.assertIn("**b** REMOVED", text)
        self.assertIn("**c** added at [4, 4]", text)
        self.assertIn("[door/portal wiring]", text)
        self.assertIn("ADDED: [(3, 3)]", text)
        self.assertIn("UNBLOCKED: [(1, 1)]", text)

    def test_dialogue_gating_and_new_counter(self):
        old = {"start": "a", "nodes": {"a": {"speaker": "s", "text": "t",
            "options": [{"text": "o1", "goto": "a"}]}}}
        new = {"start": "a", "nodes": {"a": {"speaker": "s", "text": "t",
            "options": [{"text": "o1", "goto": "a",
                "requires": {"accomplishment": {"x": 1}},
                "effects": [{"accomplishment": "brand_new_counter"}]}]}}}
        text = "\n".join(data_diff.render_dialogue("d", old, new, {"served_customer"}))
        self.assertIn("GATING", text)
        self.assertIn("NEW counter name `brand_new_counter` (first write)", text)

    def test_dialogue_shipped_counter_not_flagged_new(self):
        old = {"start": "a", "nodes": {}}
        new = {"start": "a", "nodes": {"n": {"speaker": "s", "text": "t",
            "options": [{"text": "o", "effects": [{"accomplishment": "served_customer"}]}]}}}
        text = "\n".join(data_diff.render_dialogue("d", old, new, {"served_customer"}))
        self.assertIn("already shipped/frozen", text)
        self.assertNotIn("NEW counter", text)

    def test_option_count_change_warns_repin(self):
        old = {"nodes": {"a": {"options": [{"text": "x"}]}}}
        new = {"nodes": {"a": {"options": [{"text": "x"}, {"text": "y"}]}}}
        text = "\n".join(data_diff.render_dialogue("d", old, new, set()))
        self.assertIn("option count 1 -> 2", text)
        self.assertIn("re-pins", text)

    def test_catalog_row_order_change_flagged(self):
        old = {"portals": [{"id": "p1", "map": "a"}, {"id": "p2", "map": "b"}]}
        new = {"portals": [{"id": "p2", "map": "b"}, {"id": "p1", "map": "a"}]}
        text = "\n".join(data_diff.render_id_catalog("portals.json", "portals", old, new))
        self.assertIn("row ORDER changed", text)

    def test_catalog_gating_change(self):
        old = {"quests": [{"id": "q", "complete_when": {"x": 1}}]}
        new = {"quests": [{"id": "q", "complete_when": {"x": 2}}]}
        text = "\n".join(data_diff.render_id_catalog("quests.json", "quests", old, new))
        self.assertIn("GATING", text)
        self.assertIn("complete_when", text)


class TestFallbackInvariant(unittest.TestCase):
    """D5 pins run END-TO-END through summarize_file -- the reviewer's
    constructed counterexamples that the first cut hid entirely."""

    def _section(self, rel, old, new):
        md, leftover, _ = data_diff.summarize_file(rel, old, new, set())
        return "\n".join(md), leftover

    def test_unclaimed_map_key_lands_in_leftover(self):
        text, leftover = self._section("maps/inn/inn.json",
            {"grid": {"width": 2, "height": 2}, "ambience": "old"},
            {"grid": {"width": 2, "height": 2}, "ambience": "new"})
        self.assertEqual(leftover, 1)
        self.assertIn("`ambience` changed", text)

    def test_idless_entity_move_is_not_hidden(self):
        text, leftover = self._section("maps/inn/inn.json",
            {"entities": [{"kind": "trap", "cell": [0, 0]}]},
            {"entities": [{"kind": "trap", "cell": [4, 4]}]})
        self.assertIn("id-less/duplicate-id/non-dict", text)
        self.assertGreaterEqual(leftover, 1)
        self.assertIn("[4, 4]", text)

    def test_duplicate_id_gate_edit_is_not_hidden(self):
        old = {"entities": [
            {"id": "door", "door_when": {"x": 1}, "cell": [1, 1]},
            {"id": "door", "cell": [2, 2]}]}
        new = {"entities": [
            {"id": "door", "door_when": {"x": 999}, "cell": [1, 1]},
            {"id": "door", "cell": [2, 2]}]}
        text, leftover = self._section("maps/inn/inn.json", old, new)
        self.assertGreaterEqual(leftover, 1)
        self.assertIn("999", text)

    def test_idless_catalog_row_is_not_hidden(self):
        text, leftover = self._section("quests.json",
            {"quests": [{"id": "q1"}]},
            {"quests": [{"id": "q1"}, {"name": "ghost quest"}]})
        self.assertGreaterEqual(leftover, 1)
        self.assertIn("ghost quest", text)

    def test_nondict_node_does_not_crash_or_hide(self):
        text, leftover = self._section("dialogue/x.json",
            {"start": "a", "nodes": {"a": {"text": "hi"}, "weird": "same"}},
            {"start": "a", "nodes": {"a": {"text": "ho"}, "weird": "same"}})
        self.assertGreaterEqual(leftover, 1)
        self.assertIn("non-object", text)
        self.assertIn('"ho"', text)


class TestEndToEnd(unittest.TestCase):
    def test_head_vs_worktree_runs(self):
        out = data_diff.summarize("HEAD", data_diff.WORKTREE)
        self.assertIn("data/ semantic diff", out)

    def test_historic_commit_summary(self):
        # FotI guests PR: two new dialogue graphs + two inn entities.
        out = data_diff.summarize("f0596ea^", "f0596ea")
        self.assertIn("krshia_inn_guest** added", out)
        self.assertIn("node **greet** added", out)

    def test_historic_raw_fallthrough(self):
        # shipped-ids regen: no renderer -- must fall through raw, e2e.
        out = data_diff.summarize("dc8b9cf^", "dc8b9cf")
        self.assertIn("unsummarized changes", out)
        self.assertIn("`release` changed", out)

    def test_bogus_ref_clean_error(self):
        import subprocess
        result = subprocess.run(
            [sys.executable, str(GAME_SCRIPTS / "data_diff.py"),
             "not-a-real-ref", "also-fake"],
            capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(result.returncode, 2)
        self.assertIn("git failed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
