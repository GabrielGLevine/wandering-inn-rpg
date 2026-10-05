#!/usr/bin/env python3
"""tools/asset_candidates.py + tools/find_asset.py: the use-case asset
registry. Fixture batches only (CI has no potential_assets/). Run manually:
    python3 scripts/tests/test_asset_candidates.py -v"""

import json
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
import asset_candidates as ac  # noqa: E402
import find_asset as fa  # noqa: E402


def png(path: Path, w: int = 16, h: int = 16) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    chunk = b"IHDR" + ihdr
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", len(ihdr)) + chunk
                     + struct.pack(">I", zlib.crc32(chunk)))


class Fixture(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.assets = self.root / "potential_assets"
        self.assets.mkdir()

    def tearDown(self):
        self._tmp.cleanup()

    def build(self, write=False):
        return ac.build(self.assets, self.root, write)

    def rows(self, reg, batch):
        return {Path(r["path"]).name + ("/" if r["path"].endswith("/") else ""): r
                for r in reg["assets"] if r["batch"] == batch}


class TestMarkdownManifest(Fixture):
    def test_path_table_targets_verdicts_and_globs(self):
        lane = self.assets / "pixellab_harvest_x" / "L2_props"
        png(lane / "crate.png", 64, 64)
        png(lane / "crate__alt1.png", 32, 32)
        png(lane / "camp_carry_yoke.png")
        for i in range(3):
            png(lane / "icons" / f"icon_{i}.png")
        (lane / "MANIFEST.md").write_text(
            "| batch | gens |\n|---|---|\n| A | 20 |\n\n"
            "| file | PixelLab id | target / need | prompt | verdict | notes |\n"
            "|---|---|---|---|---|---|\n"
            "| crate.png | 3bce8a00-eeb7-4036-8b3d-b0354aeb9f58 | P1 `crate` (sprites.json:920) | wooden crate | **READY** | |\n"
            "| crate__alt1.png | 3bce8a01-eeb7-4036-8b3d-b0354aeb9f58 | `crate` | small | ALT | |\n"
            "| camp_carry_yoke.png | x | `camp_carry_yoke` borrows bundle `crate` | yoke | USABLE (fix) | |\n"
            "| icons/*.png (3 files) | pack | glyphs | g | READY | |\n")
        reg = self.build()
        rows = self.rows(reg, "pixellab_harvest_x/L2_props")
        self.assertEqual(rows["crate.png"]["verdict"], "READY")
        self.assertEqual(rows["crate.png"]["w"], 64)
        self.assertEqual(rows["crate.png"]["pixellab_id"], "3bce8a00-eeb7-4036-8b3d-b0354aeb9f58")
        self.assertEqual(rows["crate__alt1.png"]["verdict"], "ALT")
        self.assertEqual(rows["crate__alt1.png"]["targets"], ["crate"])
        # only the FIRST backticked id is a target; the borrowed one is context
        self.assertEqual(rows["camp_carry_yoke.png"]["targets"], ["camp_carry_yoke"])
        self.assertEqual(rows["camp_carry_yoke.png"]["verdict"], "USABLE-WITH-FIX")
        self.assertTrue({"icon_0.png", "icon_1.png", "icon_2.png"} <= rows.keys())
        self.assertTrue(rows["crate.png"]["manifest_ref"].endswith("MANIFEST.md:7"))
        self.assertEqual(len(reg["batches"]), 1, "lanes are batches; the parent is not")


class TestFallbackAndOverlays(Fixture):
    def test_frame_dir_collapses_to_one_rig_row(self):
        b = self.assets / "pixellab_2026-07-06"
        for d in ("down", "side", "up"):
            for i in range(4):
                png(b / "pc_variants_work" / "human_f" / f"walk_{d}_{i}.png")
        png(b / "dirtytable.png")
        rows = self.rows(self.build(), "pixellab_2026-07-06")
        self.assertEqual(rows["human_f/"]["kind"], "rig")
        self.assertEqual(rows["human_f/"]["notes"], "12 frames/sheets")
        self.assertIn("dirtytable.png", rows)
        self.assertEqual(len(rows), 2)

    def test_icon_versions_do_not_collapse_and_pick_table_sets_verdicts(self):
        b = self.assets / "pixellab_2026-07-16_drain"
        for name in ("hedge_remedy", "keen_eye", "keener_edge", "observe"):
            for v in (1, 2):
                png(b / f"icon_{name}_v{v}.png")
                png(b / f"icon_{name}_v{v}_32.png", 32, 32)
        (b / "MANIFEST.md").write_text(
            "| Icon | Glyph prompt | PICK | Why |\n|---|---|---|---|\n"
            "| hedge_remedy (x3) | ladle in cauldron | **v1** | herbal |\n"
            "| keen_eye | eye | **v2** | sharper |\n")
        rows = self.rows(self.build(), "pixellab_2026-07-16_drain")
        self.assertEqual(len(rows), 16, "versioned icons stay individual rows")
        self.assertEqual(rows["icon_hedge_remedy_v1.png"]["verdict"], "READY")
        self.assertEqual(rows["icon_hedge_remedy_v1_32.png"]["verdict"], "READY")
        self.assertEqual(rows["icon_hedge_remedy_v2.png"]["verdict"], "ALT")
        self.assertEqual(rows["icon_keen_eye_v2.png"]["verdict"], "READY")
        self.assertIn("hedge_remedy", rows["icon_hedge_remedy_v1.png"]["targets"])
        # keen_eye must not bleed onto keener_edge
        self.assertEqual(rows["icon_keener_edge_v1.png"]["verdict"], "UNREVIEWED")

    def test_legacy_generations_json_overlays_prompt(self):
        b = self.assets / "pixellab_2026-07-07_pallass"
        png(b / "prop_crystal_lamp.png")
        (b / "manifest.json").write_text(json.dumps({"generations": [
            {"name": "prop_crystal_lamp", "params": {"description": "brass crystal lamp"},
             "result": {"files": ["/abs/prop_crystal_lamp.png"]}}]}))
        row = self.rows(self.build(), "pixellab_2026-07-07_pallass")["prop_crystal_lamp.png"]
        self.assertEqual(row["prompt"], "brass crystal lamp")


class TestStandardManifest(Fixture):
    def test_manifest_json_wins_and_conversion_round_trips(self):
        b = self.assets / "pixellab_2026-09-01"
        png(b / "barrel.png")
        (b / "MANIFEST.md").write_text(
            "| file | target | verdict |\n|---|---|---|\n| barrel.png | `barrel` | READY |\n")
        first = self.build(write=True)
        self.assertTrue((b / "MANIFEST.json").exists())
        data = json.loads((b / "MANIFEST.json").read_text())
        self.assertEqual(data["schema"], ac.SCHEMA)
        self.assertEqual(data["assets"][0]["targets"], ["barrel"])
        second = self.build()
        self.assertEqual(second["batches"][0]["origin"], "MANIFEST.json")
        strip = lambda reg: [{k: v for k, v in r.items() if k != "manifest_ref"}  # noqa: E731
                             for r in reg["assets"]]
        self.assertEqual(strip(first), strip(second))

    def test_conversion_never_clobbers_legacy_lowercase_manifest(self):
        # Regression: on case-insensitive macOS, writing MANIFEST.json
        # overwrote three legacy manifest.json files.
        b = self.assets / "pixellab_2026-07-07_garden"
        png(b / "statue.png")
        legacy = json.dumps({"jobs": {"statue": {"file": "statue.png",
                                                 "params": {"description": "stone statue"}}}})
        (b / "manifest.json").write_text(legacy)
        self.build(write=True)
        self.assertEqual((b / "manifest.json").read_text(), legacy)
        self.assertNotIn("MANIFEST.json", ac.present(b))


class TestShipped(Fixture):
    def test_sprites_json_rows_are_tiered_by_bundle(self):
        game = self.root / "wandering_inn_game"
        (game / "data").mkdir(parents=True)
        png(game / "assets" / "props" / "free_pack" / "Furniture.png", 800, 864)
        png(game / "assets" / "sprites" / "door_heavy" / "Idle-Sheet.png", 64, 64)
        (game / "data" / "sprites.json").write_text(json.dumps({
            "_comment": "x",
            "crate": {"animations": {"idle": {"sheet": "res://assets/props/free_pack/Furniture.png"}}},
            "door_heavy": {"animations": {"idle": {"sheet": "res://assets/sprites/door_heavy/Idle-Sheet.png"}}},
        }))
        (game / "assets_manifest.json").write_text(json.dumps({"assets": [
            {"path": "assets/props/free_pack/Furniture.png", "bundle": True}]}))
        rows = {r["sprite_id"]: r for r in ac.shipped_rows(self.root)}
        self.assertEqual(rows["crate"]["tier"], "shipped-bundle")
        self.assertEqual(rows["door_heavy"]["tier"], "shipped-public")
        self.assertEqual(rows["crate"]["verdict"], "SHIPPED")


class TestFindAsset(unittest.TestCase):
    ROWS = [
        {"path": "potential_assets/b/crate__alt1.png", "kind": "prop", "targets": ["crate"],
         "verdict": "ALT", "tier": "owned-public"},
        {"path": "potential_assets/b/crate.png", "kind": "prop", "targets": ["crate"],
         "verdict": "READY", "tier": "owned-public"},
        {"path": "potential_assets/b/crate_stack_alley.png", "kind": "setpiece",
         "targets": ["alley_crate_stack"], "verdict": "READY", "tier": "owned-public"},
        {"path": "potential_assets/b/yoke.png", "kind": "prop", "targets": ["camp_carry_yoke"],
         "verdict": "READY", "tier": "owned-public", "notes": "borrows bundle crate"},
        {"path": "potential_assets/Pack/crate_pack.png", "kind": "prop", "targets": ["crate_pack"],
         "verdict": "UNREVIEWED", "tier": "pack-bundle"},
        {"path": "potential_assets/b/bad_crate.png", "kind": "prop", "targets": ["crate"],
         "verdict": "REJECTED", "tier": "owned-public"},
        {"path": "potential_assets/b/icon_flame_bolt.png", "kind": "icon",
         "targets": ["flame_bolt", "icon_flame_bolt"], "verdict": "READY", "tier": "owned-public"},
    ]

    def paths(self, *query, **kw):
        return [Path(r["path"]).name for _, r in fa.search(self.ROWS, list(query), **kw)]

    def test_exact_target_then_verdict_then_weaker_matches(self):
        got = self.paths("crate")
        self.assertEqual(got[:2], ["crate.png", "crate__alt1.png"])
        self.assertEqual(got[-1], "yoke.png", "notes-only match ranks last")
        self.assertNotIn("bad_crate.png", got)
        self.assertIn("bad_crate.png", self.paths("crate", include_rejected=True))

    def test_every_word_must_match_and_multiword_exact(self):
        self.assertEqual(self.paths("flame", "bolt"), ["icon_flame_bolt.png"])
        self.assertEqual(self.paths("flame", "crate"), [])

    def test_filters(self):
        self.assertEqual(self.paths("crate", kind="setpiece"), ["crate_stack_alley.png"])
        self.assertNotIn("crate_pack.png", self.paths("crate", tier="owned"))
        self.assertEqual(self.paths("crate", tier="pack"), ["crate_pack.png"])
        self.assertIn("crate.png", self.paths("crate", tier="public"))


class TestDump(unittest.TestCase):
    def test_one_row_per_line_and_valid_json(self):
        reg = {"schema": 1, "batches": [], "assets": [{"path": "a|b", "targets": ["x"]},
                                                       {"path": "c", "notes": "line\nbreak"}]}
        text = ac.dump_registry(reg)
        self.assertEqual(json.loads(text), reg)
        self.assertEqual(len(text.strip().splitlines()), 4)


class TestHelpers(unittest.TestCase):
    def test_stem_target(self):
        for raw, want in [("icon_advanced_cooking_v1_32.png", "icon_advanced_cooking"),
                          ("crate__alt1.png", "crate"), ("briar_wall_32px.png", "briar_wall"),
                          ("inn_table_dirty__after.png", "inn_table_dirty"),
                          ("goblin_raider/7be8ec3a-b3ab-443b-85e8-a30fd2ef4c2c/", "goblin_raider")]:
            self.assertEqual(ac.stem_target(raw), want, raw)

    def test_normalize_verdict(self):
        for raw, want in [("**READY**", "READY"), ("USABLE-WITH-FIX (tint)", "USABLE-WITH-FIX"),
                          ("ALT", "ALT"), ("rejected: blank", "REJECTED"),
                          ("SUPERSEDED by v3", "SUPERSEDED"), ("", "UNREVIEWED")]:
            self.assertEqual(ac.normalize_verdict(raw), want, raw)


if __name__ == "__main__":
    unittest.main()
