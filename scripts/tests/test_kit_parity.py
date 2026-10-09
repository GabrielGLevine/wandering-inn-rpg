#!/usr/bin/env python3
"""#607 parity, Python half: golden regeneration + live Godot vs Python on the real tree."""
import json, os, subprocess, sys, tempfile, unittest
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
        self.assertEqual(kl.resolve_tree(FIX / "maps", kits), json.loads((FIX / "golden.json").read_text()))

    def test_golden_exercises_every_mode(self):
        golden = json.loads((FIX / "golden.json").read_text())
        roles = {r["sprite_role"] for rows in golden.values() for r in rows}
        self.assertTrue({"cargo", "facade", "seat", "lamp", "door_x", "fixed", "common_lamp"} <= roles, roles)

    def test_door_pair_shares_variant_across_both_sides(self):
        golden = json.loads((FIX / "golden.json").read_text())
        variants = {r["sprite"] for m in ("fx_door_a", "fx_door_b") for r in golden[m]}
        self.assertEqual(len(variants), 1, variants)


class TestLiveParity(unittest.TestCase):
    @unittest.skipUnless(os.path.exists(GODOT), "godot binary not installed (CI python-suites installs it)")
    def test_real_tree_resolves_identically(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "real.json"
            r = subprocess.run([GODOT, "--headless", "--path", str(GAME), "--script", "res://tests/test_kit_parity.gd"],
                               capture_output=True, text=True, timeout=300, env={**os.environ, "WI_KIT_PARITY_OUT": str(out)})
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("PASS test_kit_parity", r.stdout)
            for bad in ("SCRIPT ERROR", "Parse Error", "ERROR:", "WARNING"):
                self.assertNotIn(bad, r.stdout + r.stderr)
            godot_rows = json.loads(out.read_text())
        self.assertEqual(godot_rows, kl.resolve_all(GAME))


if __name__ == "__main__":
    unittest.main()
