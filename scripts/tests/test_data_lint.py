#!/usr/bin/env python3
"""GH#276: every lint tier proven able to FAIL (deliberately broken
fixtures per check) + clean-on-HEAD subprocess proof. Run manually:
    python3 scripts/tests/test_data_lint.py -v"""

import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME_SCRIPTS = REPO_ROOT / "wandering_inn_game" / "scripts"
sys.path.insert(0, str(GAME_SCRIPTS))
import data_lint  # noqa: E402

GRID = {"grid": {"width": 4, "height": 3}}


class TestBrokenFixtures(unittest.TestCase):
    def _errs(self, fn, *args):
        errors = []
        fn(*args, errors)
        return errors

    def test_blocked_cell_out_of_grid(self):
        # width 4 => x max 3 (the b10 bounds trap, exactly).
        errs = self._errs(data_lint.check_maps,
            {"m": {**GRID, "blocked": [[4, 0]], "entities": []}})
        self.assertEqual(len(errs), 1)
        self.assertIn("blocked cell [4, 0]", errs[0])

    def test_entity_cell_out_of_grid_and_missing(self):
        errs = self._errs(data_lint.check_maps,
            {"m": {**GRID, "blocked": [],
                "entities": [{"id": "a", "cell": [0, 3]}, {"id": "b"}]}})
        self.assertEqual(len(errs), 2)

    def test_missing_grid(self):
        errs = self._errs(data_lint.check_maps, {"m": {"blocked": []}})
        self.assertIn("missing/invalid grid", errs[0])

    def test_portal_bad_map_and_cell(self):
        parsed = {data_lint.DATA / "portals.json": {"portals": [
            {"id": "p1", "map": "nowhere", "cell": [0, 0]},
            {"id": "p2", "map": "m", "cell": [9, 9]},
        ]}}
        errs = self._errs(data_lint.check_portals, parsed, {"m": GRID})
        self.assertEqual(len(errs), 2)
        self.assertIn("'nowhere' does not exist", errs[0])
        self.assertIn("out of 'm' grid", errs[1])

    def test_dialogue_dangling_goto_and_missing_fields(self):
        parsed = {Path("/synthetic/dialogue/x.json"): {
            "start": "gone",
            "nodes": {
                "a": {"speaker": "s", "options": [{"goto": "nope"}]},
            }}}
        errs = self._errs(data_lint.check_dialogue, parsed)
        joined = "\n".join(errs)
        self.assertIn("start 'gone' is not a node", joined)
        self.assertIn("missing text", joined)
        self.assertIn("goto 'nope' targets no node", joined)
        self.assertEqual(len(errs), 3)

    def test_variants_only_node_fails(self):
        # dialogue.gd's _resolved_text reads node["text"] unconditionally
        # (review M1) -- variants without a base text is a guaranteed crash.
        parsed = {Path("/synthetic/dialogue/y.json"): {
            "start": "a",
            "nodes": {"a": {"speaker": "s", "text_variants": [
                {"requires": {"x": 1}, "text": "hi"}]}}}}
        errs = self._errs(data_lint.check_dialogue, parsed)
        self.assertEqual(len(errs), 1)
        self.assertIn("missing text", errs[0])

    def test_integral_float_cells_accepted(self):
        # Godot's JSON parser yields floats; 7.0 is engine-legal (review M2).
        errs = self._errs(data_lint.check_maps,
            {"m": {"grid": {"width": 4.0, "height": 3},
                "blocked": [[3.0, 2.0]],
                "entities": [{"id": "a", "cell": [0.0, 1]}]}})
        self.assertEqual(errs, [])

    def test_malformed_cell_gets_malformed_message(self):
        errs = self._errs(data_lint.check_maps,
            {"m": {**GRID, "blocked": [[3], [1.5, 2], [True, 0]], "entities": []}})
        self.assertEqual(len(errs), 3)
        for e in errs:
            self.assertIn("malformed blocked cell", e)

    def test_duplicate_map_stem_across_regions(self):
        parsed = {
            Path("/syn/maps/region_a/inn.json"): {**GRID},
            Path("/syn/maps/region_b/inn.json"): {**GRID},
        }
        errs = self._errs(data_lint._compose_maps, parsed)
        self.assertEqual(len(errs), 1)
        self.assertIn("duplicate map key 'inn'", errs[0])

    def test_sprites_missing_animations(self):
        parsed = {data_lint.DATA / "sprites.json": {
            "_comment": "x", "good": {"animations": {"idle": {}}}, "bad": {}}}
        errs = self._errs(data_lint.check_sprites, parsed)
        self.assertEqual(len(errs), 1)
        self.assertIn("'bad'", errs[0])

    def test_vacuous_gate_caught_and_allowlist_honored(self):
        maps = {"m": {**GRID, "entities": [
            {"id": "door1", "door_when": {"door_awakened": 1}}]}}
        errs = self._errs(data_lint.check_gate_shapes, maps)
        self.assertEqual(len(errs), 1)
        self.assertIn("VACUOUSLY TRUE", errs[0])
        allowed = {"invrisil_boulevard": {**GRID, "entities": [
            {"id": "invrisil_anchor_stone",
             "portal_menu_when": {"door_awakened": 1}}]}}
        self.assertEqual(self._errs(data_lint.check_gate_shapes, allowed), [])

    def test_wrapped_gate_passes(self):
        maps = {"m": {**GRID, "entities": [
            {"id": "d", "door_when": {"requires": {"door_awakened": 1}}}]}}
        self.assertEqual(self._errs(data_lint.check_gate_shapes, maps), [])


class TestRealTree(unittest.TestCase):
    def test_clean_on_head_and_fast(self):
        result = subprocess.run(
            [sys.executable, str(GAME_SCRIPTS / "data_lint.py")],
            capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("data_lint: OK", result.stdout)

    def test_malformed_json_fails_loud(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "broken.json").write_text("{broken")
            (Path(tmp) / "fine.json").write_text("{}")
            errors = []
            parsed = data_lint.check_wellformed(errors, root=Path(tmp))
            self.assertEqual(len(errors), 1)
            self.assertIn("broken.json: invalid JSON", errors[0])
            self.assertEqual(len(parsed), 1)


if __name__ == "__main__":
    unittest.main()
