#!/usr/bin/env python3
"""GH#277: ship_asset_scan release gate. Run manually:
    python3 scripts/tests/test_ship_asset_scan.py -v"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME_SCRIPTS = REPO_ROOT / "wandering_inn_game" / "scripts"
sys.path.insert(0, str(GAME_SCRIPTS))
import ship_asset_scan  # noqa: E402


def make_root(tmp: Path, sprites: dict, audio: dict, assets: list) -> Path:
    (tmp / "data").mkdir()
    (tmp / "data" / "sprites.json").write_text(json.dumps(sprites))
    (tmp / "data" / "audio.json").write_text(json.dumps(audio))
    for rel in assets:
        p = tmp / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("x")
    return tmp


class TestShipAssetScan(unittest.TestCase):
    def test_all_present_no_pending_is_clean(self):
        with tempfile.TemporaryDirectory() as d:
            root = make_root(Path(d),
                {"hero": {"animations": {"idle": {"sheet": "res://assets/sprites/h.png"}}}},
                {"events": [{"id": "e1", "stream": "res://assets/audio/sfx/a.wav"}]},
                ["assets/sprites/h.png", "assets/audio/sfx/a.wav"])
            self.assertEqual(ship_asset_scan.scan(root), [])

    def test_missing_sheet_fails(self):
        with tempfile.TemporaryDirectory() as d:
            root = make_root(Path(d),
                {"hero": {"animations": {"idle": {"sheet": "res://assets/sprites/gone.png"}}}},
                {"events": []}, [])
            errs = ship_asset_scan.scan(root)
            self.assertEqual(len(errs), 1)
            self.assertIn("gone.png", errs[0])

    def test_pending_row_fails_even_if_nothing_missing(self):
        with tempfile.TemporaryDirectory() as d:
            root = make_root(Path(d), {},
                {"music": [{"id": "boss_theme", "pending": True}]}, [])
            errs = ship_asset_scan.scan(root)
            self.assertEqual(len(errs), 1)
            self.assertIn("boss_theme", errs[0])
            self.assertIn("pending", errs[0])

    def test_comment_keys_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            root = make_root(Path(d),
                {"_comment": "example: res://assets/sprites/example_only.png"},
                {"events": [], "_comment_music_order": "res://assets/audio/x.ogg"}, [])
            self.assertEqual(ship_asset_scan.scan(root), [])

    def test_real_tree_scan_runs(self):
        # Local dev trees carry the real overlay (user directive 2026-07-07),
        # so this asserts the scan RUNS and reports; a public checkout would
        # legitimately fail it (it is a ship gate, not a CI lint).
        errors = ship_asset_scan.scan(ship_asset_scan.GAME_ROOT)
        for e in errors:
            self.assertNotIn("pending", e, "no pending rows expected on HEAD")


if __name__ == "__main__":
    unittest.main()
