#!/usr/bin/env python3
"""#607 parity, Python half: golden regeneration + live Godot vs Python on the real tree."""
import json, os, subprocess, sys, tempfile, unittest
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME = REPO_ROOT / "wandering_inn_game"
FIX = GAME / "tests" / "fixtures" / "kits"
GODOT = "/usr/local/bin/godot"
sys.path.insert(0, str(GAME / "scripts"))
import wi_kits_lib as kl  # noqa: E402


class TestGolden(unittest.TestCase):
    def test_committed_golden_matches_python(self):
        kits = json.loads((FIX / "kits.json").read_text())
        self.assertEqual(kl.resolve_tree_parity(FIX / "maps", kits), json.loads((FIX / "golden.json").read_text()))

    def test_golden_exercises_every_mode(self):
        golden = json.loads((FIX / "golden.json").read_text())
        roles = {r["sprite_role"] for m in golden.values() for r in m["rows"]}
        self.assertTrue({"cargo", "facade", "seat", "lamp", "door_x", "fixed", "common_lamp", "wide"} <= roles, roles)

    def test_radius_override_in_the_golden(self):
        # fx_radius: a module role with "radius": 3 on a 3-cell pitch -- neighbours never share
        golden = json.loads((FIX / "golden.json").read_text())
        picks = [r["sprite"] for r in golden["fx_radius"]["rows"]]
        self.assertGreaterEqual(len(picks), 5)
        self.assertTrue(all(a != b for a, b in zip(picks, picks[1:])), picks)

    def test_door_pair_shares_variant_across_both_sides(self):
        golden = json.loads((FIX / "golden.json").read_text())
        variants = {r["sprite"] for m in ("fx_door_a", "fx_door_b") for r in golden[m]["rows"]}
        self.assertEqual(len(variants), 1, variants)


    def test_module_cap_in_the_golden(self):
        # fx_module_cap: 9 module placements on a 3-cell pitch (the old rule drew f1 x6) are capped at
        # ceil(9/3) = 3 per variant; the 9 non-module cargo rows beside them keep their c4 x7.
        golden = json.loads((FIX / "golden.json").read_text())
        rows = golden["fx_module_cap"]["rows"]
        facade = Counter(r["sprite"] for r in rows if r["sprite_role"] == "facade")
        cargo = Counter(r["sprite"] for r in rows if r["sprite_role"] == "cargo")
        self.assertEqual(sum(facade.values()), 9)
        self.assertLessEqual(max(facade.values()), 3, facade)
        self.assertEqual(cargo["c4"], 7, cargo)

    def test_weighted_pool_entry_is_picked(self):
        golden = json.loads((FIX / "golden.json").read_text())
        self.assertIn("c2", {r["sprite"] for r in golden["fx_weighted"]["rows"]})

    def test_material_merge_and_light_are_in_the_golden(self):
        golden = json.loads((FIX / "golden.json").read_text())
        mats = {m["layer"]: m for m in golden["fx_material"]["materials"]}
        self.assertEqual(set(mats), {"floor_layers[0]", "floor_layers[1]", "walls", "walls.segments[0]", "walls.segments[1]"})
        self.assertEqual(mats["floor_layers[1]"]["fields"]["tile_px"], 32)  # explicit field beats the material's 16
        self.assertEqual(mats["floor_layers[0]"]["fields"]["tile_px"], 16)
        self.assertEqual(mats["walls.segments[0]"]["fields"]["tone"]["detail"], 0)
        self.assertEqual(set(mats["walls"]["fields"]), {"sheet", "tile_px", "variants", "wang_corners", "cap", "face", "fallback_render"})
        lights = [r["light"] for r in golden["fx_map"]["rows"] if r["sprite_role"] == "lamp"]
        self.assertEqual([l["energy"] for l in lights], [0.9, 2])  # role default, then the row's own


class TestLiveParity(unittest.TestCase):
    def test_real_tree_resolves_identically(self):
        if not os.path.exists(GODOT):
            if os.environ.get("CI"):
                self.fail("godot binary missing in CI: the parity gate must not skip")
            self.skipTest("godot binary not installed (CI python-suites installs it)")
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "real.json"
            r = subprocess.run([GODOT, "--headless", "--path", str(GAME), "--script", "res://tests/test_kit_parity.gd"],
                               capture_output=True, text=True, timeout=300, env={**os.environ, "WI_KIT_PARITY_OUT": str(out)})
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("PASS test_kit_parity", r.stdout)
            for bad in ("SCRIPT ERROR", "Parse Error", "ERROR:", "WARNING"):
                self.assertNotIn(bad, r.stdout + r.stderr)
            godot_rows = json.loads(out.read_text())
        self.assertEqual(godot_rows, kl.resolve_tree_parity(GAME / "data" / "maps", kl.load_kits(GAME)))


if __name__ == "__main__":
    unittest.main()
