#!/usr/bin/env python3
"""#607 lane A: wi_kits_lib mirrors WIKitResolver (index C3/C4/C5).
Pinned picks are the values tests/test_kit_resolver.gd asserts."""
import copy
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME = REPO_ROOT / "wandering_inn_game"
sys.path.insert(0, str(GAME / "scripts"))
import wi_kits_lib as kl  # noqa: E402

KITS = json.loads((GAME / "tests" / "fixtures" / "kits" / "kits.json").read_text())
G = {"width": 7, "height": 7}


def cells(n, role):
    return [{"sprite": "@" + role, "cell": [i % 7, i // 7]} for i in range(n)]


def mk(decor=None, entities=None, **extra):
    return {"grid": G, "decor": decor or [], "entities": entities or [], **extra}


class TestHashScore(unittest.TestCase):
    def test_hash_pins(self):
        for key, want in [("abc", 3128432319), ("x", 762385986),
                          ("invrisil_boulevard|cargo|crate_lidded|12,7", 537148620),
                          ("naïve|ρ|日本", 2814704703)]:
            self.assertEqual(kl.hash32(key), want, key)
        self.assertIs(kl.godot_string_hash, kl.hash32)

    def test_score_formula_and_weight(self):
        h = kl.hash32("m|cargo|c1")
        self.assertAlmostEqual(kl.score("m|cargo|c1", 1.0), -math.log((h + 0.5) / 4294967296.0))
        self.assertLess(kl.score("m|cargo|c1", 2.0), kl.score("m|cargo|c1", 1.0))

    def test_subset_size(self):
        self.assertEqual([kl.subset_size(1, 5), kl.subset_size(12, 5), kl.subset_size(40, 5), kl.subset_size(40, 3)], [2, 4, 4, 3])

    def test_variety(self):
        orders = {tuple(kl.rank_for("m", "r", ["v1", "v2", "v3", "v4"], (x, y))) for x in range(10) for y in range(10)}
        self.assertGreaterEqual(len(orders), 12)
        pool = kl.pool_of(KITS["r"]["roles"]["cargo"])
        self.assertGreater(len({tuple(kl.subset(f"map{i}", "cargo", pool, 4)) for i in range(3)}), 1)

    def test_pool_of_and_radius(self):
        self.assertEqual(kl.pool_of("x"), [["x", 1.0]])
        self.assertEqual(kl.pool_of({"pool": ["a", ["b", 2]]}), [["a", 1.0], ["b", 2.0]])
        self.assertEqual([kl.radius_for("x"), kl.radius_for({"pick": "door"}), kl.radius_for({"module": True}), kl.radius_for({})], [2, 0, 1, 2])


class TestResolve(unittest.TestCase):
    def test_identity_without_refs(self):
        m = mk([{"sprite": "crate", "cell": [1, 1]}], [{"id": "x", "kind": "npc", "sprite": "townswoman", "cell": [2, 2]}])
        errs = []
        self.assertEqual(kl.resolve_map(m, "m", "r", KITS, errs), m)
        self.assertEqual(errs, [])

    def test_cell_mode_exact_picks_and_reorder(self):
        m = mk(cells(14, "cargo"))
        out = kl.resolve_map(m, "m", "r", KITS)
        want = "c4 c3 c2 c4 c1 c3 c4 c1 c3 c3 c2 c1 c4 c2".split()
        self.assertEqual([r["sprite"] for r in out["decor"]], want)
        self.assertTrue(all(r["sprite_role"] == "cargo" for r in out["decor"]))
        self.assertTrue(2 <= len({r["sprite"] for r in out["decor"]}) <= 4)
        k2 = copy.deepcopy(KITS)
        k2["r"]["roles"]["cargo"]["pool"] = ["c5", "c4", "c3", ["c2", 2], "c1"]
        self.assertEqual(kl.resolve_map(m, "m", "r", k2), out)
        self.assertEqual(kl.resolve_map(m, "m", "r", KITS), out)

    def test_neighbour_exclusion_and_forced_fallback(self):
        two = kl.resolve_map(mk([{"sprite": "@facade", "cell": [3, 3]}, {"sprite": "@facade", "cell": [4, 3]}]), "m", "r", KITS)
        self.assertNotEqual(two["decor"][0]["sprite"], two["decor"][1]["sprite"])
        k3 = copy.deepcopy(KITS)
        k3["r"]["roles"]["tri"] = {"pick": "cell", "pool": ["t1", "t2"]}
        tri = kl.resolve_map(mk([{"sprite": "@tri", "cell": [x, 1]} for x in (1, 2, 3)]), "m", "r", k3)
        self.assertEqual(tri["decor"][2]["sprite"], kl.rank_for("m", "tri", ["t1", "t2"], (3, 1))[0])

    def test_radius_exactness(self):
        f2 = kl.resolve_map(mk([{"sprite": "@facade", "cell": [0, 0]}, {"sprite": "@facade", "cell": [2, 0]}]), "m", "r", KITS)
        self.assertEqual([r["sprite"] for r in f2["decor"]], ["f2", "f2"])
        c3 = kl.resolve_map(mk([{"sprite": "@cargo", "cell": [0, 0]}, {"sprite": "@cargo", "cell": [3, 0]}]), "m", "r", KITS)
        self.assertEqual([r["sprite"] for r in c3["decor"]], ["c3", "c3"])
        c2 = kl.resolve_map(mk([{"sprite": "@cargo", "cell": [0, 0]}, {"sprite": "@cargo", "cell": [2, 0]}]), "m", "r", KITS)
        self.assertEqual([r["sprite"] for r in c2["decor"]], ["c3", "c2"])

    def test_map_mode_light_and_yard_pin(self):
        seats = mk(cells(5, "seat"), [{"id": "l1", "kind": "prop", "sprite": "@lamp", "cell": [6, 6]},
                                      {"id": "l2", "kind": "prop", "sprite": "@lamp", "cell": [6, 5], "light": {"energy": 0.1}}])
        out = kl.resolve_map(seats, "m", "r", KITS)
        first = out["decor"][0]["sprite"]
        self.assertIn(first, ["s1", "s2", "s3"])
        self.assertTrue(all(r["sprite"] == first for r in out["decor"]))
        self.assertEqual(out["entities"][0]["light"], KITS["r"]["roles"]["lamp"]["light"])
        self.assertEqual(out["entities"][1]["light"], {"energy": 0.1})
        yard = kl.resolve_map(mk(cells(2, "seat")), "yard", "r", KITS)
        self.assertEqual([r["sprite"] for r in yard["decor"]], ["s3", "s3"])

    def test_door_pair_pins_and_error_row(self):
        d = lambda i, to, c: {"id": i, "kind": "door", "to_map": to, "sprite": "@door_x", "cell": c}
        a = kl.resolve_map(mk(entities=[d("a1", "b", [0, 0]), d("a2", "b", [5, 5])]), "a", "r", KITS)
        b = kl.resolve_map(mk(entities=[d("b1", "a", [3, 1])]), "b", "r", KITS)
        self.assertEqual(a["entities"][0]["sprite"], "d3")
        self.assertEqual({a["entities"][0]["sprite"], a["entities"][1]["sprite"], b["entities"][0]["sprite"]}, {"d3"})
        pool = kl.pool_of(KITS["r"]["roles"]["door_x"])
        for mid in ("a", "b"):
            self.assertNotEqual(kl.subset(mid, "door_x", pool, 1)[0], "d3")
        bad = mk([{"sprite": "@door_x", "cell": [1, 1]}])
        errs = []
        self.assertEqual(kl.resolve_map(bad, "a", "r", KITS, errs), bad)
        self.assertEqual(len(errs), 1)

    def test_decor_and_entities_share_namespace(self):
        mix = mk()
        for i in range(12):
            mix["decor" if i < 6 else "entities"].append({"id": f"p{i}", "sprite": "@cargo", "cell": [(i % 3) * 3, (i // 3) * 3]})
        out = kl.resolve_map(mix, "m", "r", KITS)
        self.assertEqual(len({r["sprite"] for r in out["decor"] + out["entities"]}), 4)
        same = mk([{"sprite": "@cargo", "cell": [1, 1]}], [{"id": "e", "kind": "prop", "sprite": "@cargo", "cell": [1, 1]}])
        o = kl.resolve_map(same, "m", "r", KITS)
        self.assertEqual((o["decor"][0]["sprite"], o["entities"][0]["sprite"]), ("c3", "c2"))

    def test_fixed_and_common_fallback(self):
        fx = mk([{"sprite": "@fixed", "cell": [1, 1]}, {"sprite": "@common_lamp", "cell": [2, 2]}])
        out = kl.resolve_map(fx, "m", "r", KITS)
        self.assertEqual([(r["sprite"], r["sprite_role"]) for r in out["decor"]], [("plaza_fountain", "fixed"), ("street_lamp", "common_lamp")])
        errs = []
        self.assertEqual(kl.resolve_map(fx, "m", "zz", KITS, errs)["decor"][1]["sprite"], "street_lamp")
        self.assertEqual(len(errs), 1)

    def test_material_merge(self):
        m = mk(floor_layers=[{"material": "@floor_a", "cells": "all", "tone": {"base": [0.9, 0.9, 0.9], "detail": 0.1}}],
               walls={"material": "@floor_a", "segments": [{"material": "@floor_a", "from": [0, 0], "to": [3, 0], "cap": [9, 9]}]})
        out = kl.resolve_map(m, "m", "r", KITS)
        fl = out["floor_layers"][0]
        self.assertEqual((fl["sheet"], fl["coords"], fl["cells"]), ("res://a.png", [1, 2], "all"))
        self.assertEqual((fl["tone"]["detail"], fl["tone"]["base"], fl["material_ref"]), (0.1, [0.9, 0.9, 0.9], "floor_a"))
        self.assertNotIn("material", fl)
        self.assertEqual(out["walls"]["sheet"], "res://a.png")
        seg = out["walls"]["segments"][0]
        self.assertEqual((seg["cap"], seg["from"]), ([9, 9], [0, 0]))

    def test_unresolved_rows_untouched_with_errors(self):
        bad = mk([{"sprite": "@nope", "cell": [1, 1]}], [{"id": "e", "kind": "prop", "sprite": "@nope", "cell": [2, 2]}],
                 floor_layers=[{"material": "@nomat", "cells": "all"}])
        errs = []
        out = kl.resolve_map(bad, "m", "r", KITS, errs)
        self.assertEqual(len(errs), 3)
        self.assertEqual(out["decor"][0], {"sprite": "@nope", "cell": [1, 1]})
        self.assertNotIn("sprite_role", out["decor"][0])
        with self.assertRaises(kl.KitResolveError):
            kl.resolve_map(bad, "m", "r", KITS)

    def test_error_paths_leave_rows_untouched(self):
        nm = mk(floor_layers=[{"material": "floor_a", "cells": "all"}])
        errs = []
        self.assertEqual(kl.resolve_map(nm, "m", "r", KITS, errs), nm)
        self.assertEqual(len(errs), 1)
        k4 = copy.deepcopy(KITS)
        k4["r"]["roles"]["empty"] = {"pick": "cell", "pool": []}
        ep = mk([{"sprite": "@empty", "cell": [1, 1]}, {"sprite": "@cargo"}])
        errs = []
        self.assertEqual(kl.resolve_map(ep, "m", "r", k4, errs), ep)
        self.assertEqual(len(errs), 2)


class TestTreeAndLoad(unittest.TestCase):
    def test_resolve_tree_shape_and_load_kits(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / "data" / "maps" / "r").mkdir(parents=True)
            (root / "data" / "maps" / "r" / "m.json").write_text(json.dumps(mk(cells(2, "seat") + [{"sprite": "crate", "cell": [0, 5]}])))
            self.assertEqual(kl.load_kits(root), {})
            self.assertEqual(kl.map_region(root / "data" / "maps" / "r" / "m.json"), "r")
            self.assertEqual(kl.map_kit({"kit": "q"}, Path("x/r/m.json")), "q")
            res = kl.resolve_all(root, KITS)
            self.assertEqual(res["m"], [{"layer": "decor", "cell": [0, 0], "sprite_role": "seat", "sprite": res["m"][0]["sprite"]},
                                        {"layer": "decor", "cell": [1, 0], "sprite_role": "seat", "sprite": res["m"][0]["sprite"]}])
            (root / "data" / "kits.json").write_text(json.dumps(KITS))
            self.assertEqual(kl.load_kits(root), KITS)

    def test_resolve_all_real_tree_resolves(self):
        # #608: real maps carry @refs now; resolve_all raises on any that does not resolve.
        sprites = json.loads((GAME / "data" / "sprites.json").read_text())
        for rows in kl.resolve_all(GAME).values():
            for r in rows:
                self.assertIn(r["sprite"], sprites)


class TestCanonNames(unittest.TestCase):
    def test_profiles_and_sprite_rule(self):
        names = kl.canon_names(REPO_ROOT)
        for n in ["Relc Grasstongue", "Relc", "Octavia Cotton", "Octavia", "Klbkch", "Ceria Springwalker", "Ceria", "Grimalkin", "Wilovan", "Ratici", "Hedault"]:
            self.assertIn(n, names, n)
        for n in ["The PC", "Antinium", "Horns roster note", "Invrisil civilian rigs", "at", "2026-07-12)"]:
            self.assertNotIn(n, names, n)

    def test_generic_first_words_are_not_canon(self):
        names = kl.canon_names(REPO_ROOT)
        for n in ["Master", "Grand", "Tier", "Recruit", "Frazzled", "Gnoll", "Garuda", "Dullahan", "Drake", "Human", "Den-Shop", "Forge-Tier"]:
            self.assertNotIn(n, names, n)
        for n in ["Relc", "Erin", "Klbkch"]:
            self.assertIn(n, names, n)

    def test_sprite_equals_first_name_rule(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / "docs" / "design").mkdir(parents=True)
            (root / "docs" / "design" / "character-profiles.md").write_text("## Foo Bar (x)\n## The PC (y)\n")
            m = root / "wandering_inn_game" / "data" / "maps" / "r"
            m.mkdir(parents=True)
            (m / "a.json").write_text(json.dumps({"entities": [
                {"kind": "npc", "display_name": "Cups Smith", "sprite": "cups"},
                {"kind": "npc", "display_name": "Other One", "sprite": "townswoman"}]}))
            self.assertEqual(kl.canon_names(root), {"Foo Bar", "Foo", "Cups Smith", "Cups"})


if __name__ == "__main__":
    unittest.main()
