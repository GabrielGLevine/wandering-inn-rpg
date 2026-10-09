#!/usr/bin/env python3
"""#607 lane A: wi_kits_lib mirrors WIKitResolver (index C3/C4/C5).
Pinned picks are the values tests/test_kit_resolver.gd asserts."""
import collections
import copy
import hashlib
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


TRIO = [{"sprite": "@facade", "cell": [0, 0]}, {"sprite": "@facade", "cell": [2, 0]}, {"sprite": "@facade", "cell": [6, 6]}]


def uncapped(map_id, role_name, rows, kits):
    """The pre-#608-cap cell pick (radius exclusion only), for before/after comparisons."""
    role = kits["r"]["roles"][role_name]
    pool = kl.pool_of(role)
    sub = kl.subset(map_id, role_name, pool, kl.subset_size(len(rows), len(pool)))
    r, chosen, out = kl.radius_for(role), [], []
    for c in sorted((tuple(x["cell"]) for x in rows), key=lambda c: (c[1], c[0])):
        rank = kl.rank_for(map_id, role_name, sub, c)
        taken = {v for o, v in chosen if max(abs(o[0] - c[0]), abs(o[1] - c[1])) <= r}
        v = next((x for x in rank if x not in taken), rank[0])
        chosen.append((c, v))
        out.append(v)
    return out


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
        # #608: a role's own "radius" overrides the door/module/prop default (JSON may hand it over as a float)
        self.assertEqual([kl.radius_for({"radius": 3}), kl.radius_for({"module": True, "radius": 3}), kl.radius_for({"module": True, "radius": 0}),
                          kl.radius_for({"pick": "door", "radius": 1}), kl.radius_for({"radius": 3.0})], [3, 3, 0, 1, 3])


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
        # three placements, so the #608 module cap (ceil(3/2) = 2) leaves room for the reuse
        f2 = kl.resolve_map(mk(TRIO), "m", "r", KITS)
        self.assertEqual([r["sprite"] for r in f2["decor"]], ["f2", "f2", "f3"])
        c3 = kl.resolve_map(mk([{"sprite": "@cargo", "cell": [0, 0]}, {"sprite": "@cargo", "cell": [3, 0]}]), "m", "r", KITS)
        self.assertEqual([r["sprite"] for r in c3["decor"]], ["c3", "c3"])
        c2 = kl.resolve_map(mk([{"sprite": "@cargo", "cell": [0, 0]}, {"sprite": "@cargo", "cell": [2, 0]}]), "m", "r", KITS)
        self.assertEqual([r["sprite"] for r in c2["decor"]], ["c3", "c2"])

    def test_radius_override_widens_exclusion(self):
        trio = mk(TRIO)
        self.assertEqual([r["sprite"] for r in kl.resolve_map(trio, "m", "r", KITS)["decor"]], ["f2", "f2", "f3"])  # module r=1 reuses at 2
        wide = copy.deepcopy(KITS)
        wide["r"]["roles"]["facade"]["radius"] = 3
        got = [r["sprite"] for r in kl.resolve_map(trio, "m", "r", wide)["decor"]]
        self.assertEqual(got, ["f2", "f3", "f3"])  # radius 3 excludes the distance-2 neighbour (GD pins the same)
        far = mk([{"sprite": "@facade", "cell": [0, 0]}, {"sprite": "@facade", "cell": [4, 0]}])
        self.assertEqual(kl.resolve_map(far, "m", "r", wide)["decor"], kl.resolve_map(far, "m", "r", KITS)["decor"])  # beyond 3: untouched

    def test_module_cap_limits_each_variant_per_map(self):
        # #608 ruling: a module role's variant is used at most ceil(n/k) times per map, on top of the radius.
        row = [{"sprite": "@facade", "cell": [3 * i, 1]} for i in range(9)]
        self.assertEqual(max(collections.Counter(uncapped("m", "facade", row, KITS)).values()), 5)  # the old rule: f3 x5
        got = collections.Counter(r["sprite"] for r in kl.resolve_map(mk(row), "m", "r", KITS)["decor"])
        self.assertLessEqual(max(got.values()), 3, got)  # ceil(9/3)
        self.assertEqual(sum(got.values()), 9)

    def test_module_cap_leaves_non_module_roles_alone(self):
        row = [{"sprite": "@cargo", "cell": [3 * i, 3]} for i in range(9)]
        want = uncapped("m", "cargo", row, KITS)
        self.assertEqual(collections.Counter(want)["c3"], 5)  # over ceil(9/3), and still allowed
        self.assertEqual([r["sprite"] for r in kl.resolve_map(mk(row), "m", "r", KITS)["decor"]], want)

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
        resolved = kl.resolve_all(GAME)
        for rows in resolved.values():
            for r in rows:
                self.assertIn(r["sprite"], sprites)
        self.assertTrue(any(resolved.values()), "no kit row resolves on the real tree")


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


def _region(sheet, rect, **extra):
    return {"animations": {"idle": {"sheet": "res://" + sheet, "frame_size": rect[2:], "region": rect, "fps": 1}}, **extra}


def _frames(sheet, size, **extra):
    return {"animations": {"idle": {"sheet": "res://" + sheet, "frame_size": size, "fps": 6}}, **extra}


class TestArtIdentity(unittest.TestCase):
    """#623: G2/G3 count art, not ids."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.game = Path(self._tmp.name)
        (self.game / "assets").mkdir()
        for name, payload in (("a.png", b"sheet-a"), ("copy_of_a.png", b"sheet-a"), ("b.png", b"sheet-b")):
            (self.game / "assets" / name).write_bytes(payload)
        self.sha = kl.SheetHasher(self.game)

    def tearDown(self):
        self._tmp.cleanup()

    def ident(self, entry, sid="x"):
        return kl.art_identity(sid, entry, self.sha)

    def test_region_rows_key_on_sheet_path_and_rect(self):
        a = self.ident(_region("assets/props/Furniture.png", [132, 355, 24, 25]), "window_blue")
        b = self.ident(_region("assets/props/Furniture.png", [132, 355, 24, 25]), "invrisil_facade_window_1")
        self.assertEqual(a, b)
        self.assertEqual(a, ("R", "assets/props/Furniture.png", (132, 355, 24, 25)))
        self.assertNotEqual(a, self.ident(_region("assets/props/Furniture.png", [132, 355, 24, 26])))
        self.assertNotEqual(a, self.ident(_region("assets/props/Other.png", [132, 355, 24, 25])))

    def test_frame_sheets_key_on_bytes_and_frame_size(self):
        a = self.ident(_frames("assets/a.png", [32, 32]))
        self.assertEqual(a, self.ident(_frames("assets/copy_of_a.png", [32, 32])), "byte-identical copies are one picture")
        self.assertEqual(a[1], hashlib.sha256(b"sheet-a").hexdigest())
        self.assertNotEqual(a, self.ident(_frames("assets/a.png", [16, 32])), "a different frame size cuts different frames")
        self.assertNotEqual(a, self.ident(_frames("assets/b.png", [32, 32])))

    def test_same_sheet_at_another_scale_or_tint_is_the_same_art(self):
        base = _frames("assets/a.png", [32, 32])
        scaled = _frames("assets/a.png", [32, 32], render_scale=0.62, anchor=[0.5, 0.8], field_tint_override=[1, 0, 0, 1])
        self.assertEqual(self.ident(base), self.ident(scaled))
        self.assertEqual(self.ident(_region("assets/p.png", [0, 0, 16, 16])),
                         self.ident(_region("assets/p.png", [0, 0, 16, 16], render_scale=2.0, shadow=True)))

    def test_fallback_sprite_is_ignored(self):
        own = _region("assets/p.png", [0, 0, 16, 16], fallback_sprite="owned_a")
        self.assertEqual(self.ident(own), self.ident(_region("assets/p.png", [0, 0, 16, 16], fallback_sprite="owned_b")))
        self.assertNotEqual(self.ident(own), self.ident(_region("assets/p.png", [16, 0, 16, 16], fallback_sprite="owned_a")),
                            "a shared fallback never merges two different pictures")

    def test_absent_sheet_keys_on_path_and_is_reported(self):
        a = self.ident(_frames("assets/bundle_only.png", [32, 32]))
        self.assertEqual(a, ("S", "path:assets/bundle_only.png", (32, 32)))
        self.assertEqual(self.sha.missing, {"assets/bundle_only.png"})

    def test_idle_first_directional_region_and_no_art(self):
        entry = {"animations": {"walk": {"sheet": "res://assets/b.png", "frame_size": [8, 8]},
                                "idle": {"sheet_down": "res://assets/g.png", "region_down": [0, 32, 16, 16], "frame_size": [16, 16]}}}
        self.assertEqual(self.ident(entry), ("R", "assets/g.png", (0, 32, 16, 16)))
        self.assertEqual(self.ident({"animations": {"walk": {"sheet": "res://assets/b.png", "frame_size": [8, 8]}}})[0], "S")
        self.assertEqual(self.ident({"animations": {}}, "ghost"), ("id", "ghost"))

    def test_identity_label(self):
        self.assertEqual(kl.identity_label(("R", "assets/p.png", (1, 2, 3, 4))), "assets/p.png region [1, 2, 3, 4]")
        self.assertEqual(kl.identity_label(("S", "ab" * 32, (32, 32))), "frame sheet sha256 abababababab at 32x32")

    def test_real_catalog_has_the_twelve_measured_groups(self):
        sprites = json.loads((GAME / "data" / "sprites.json").read_text())
        groups = collections.defaultdict(set)
        for sid, ident in kl.art_identities(sprites, kl.SheetHasher(GAME)).items():
            groups[ident].add(sid)
        shared = {frozenset(ids) for ids in groups.values() if len(ids) > 1}
        # region-row twins need no overlay; frame-sheet twins of tracked owned sheets need none either
        for pair in ({"window_blue", "invrisil_facade_window_1"}, {"sconce", "campfire"},
                     {"invrisil_door_street_4", "invrisil_shop_door_2"}, {"invrisil_facade_window_2", "window_blue__alt1"}):
            self.assertIn(frozenset(pair), shared)


if __name__ == "__main__":
    unittest.main()
