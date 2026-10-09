#!/usr/bin/env python3
"""#607 lane A: every kit lint rule proven able to FAIL, and clean on HEAD."""
import copy, json, subprocess, sys, unittest
from unittest import mock
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
GAME = REPO_ROOT / "wandering_inn_game"
sys.path.insert(0, str(GAME / "scripts"))
import data_lint  # noqa: E402

SPRITES = {
    "c1": {"animations": {"idle": {"sheet": "res://assets/x.png", "frame_size": [16, 16]}}, "fallback_sprite": "own_a"},
    "c2": {"animations": {"idle": {"sheet": "res://assets/x.png", "frame_size": [16, 16]}}, "fallback_sprite": "own_b"},
    "c3": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [16, 16]}}},
    "own_a": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [16, 16]}}},
    "own_b": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [16, 16]}}},
    "d1": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [34, 44]}}, "shadow": True},
    "d2": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [35, 45]}}, "shadow": True},
    "d_bad": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [50, 44]}}, "shadow": True},
    "townswoman": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [16, 24]}}},
    "relc": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [16, 24]}}},
    "city_scribe": {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [16, 24]}}},
}
BUNDLE = {"assets/x.png"}
KITS = {"_common": {"materials": {}, "roles": {}, "cast": []},
        "r": {"materials": {"fa": {"sheet": "res://assets/own.png", "tile_px": 16, "coords": [0, 0]}},
              "roles": {"cargo": {"pick": "cell", "pool": ["c1", "c2", "c3"], "deny": ["paper"]},
                        "door_x": {"pick": "door", "pool": ["d1", "d2"]}},
              "cast": ["townswoman", "city_scribe"]}}
GRID = {"grid": {"width": 8, "height": 8}}


def run(kits=KITS, maps=None, arenas=None, canon=frozenset({"Relc", "Relc Grasstongue"})):
    errors, advisories, report = [], [], []
    parsed = {data_lint.DATA / "kits.json": kits, data_lint.DATA / "sprites.json": SPRITES,
              data_lint.DATA / "arenas.json": {"arenas": arenas or []}}
    maps = maps or {}
    for mid, doc in maps.items():
        parsed[data_lint.DATA / "maps" / doc.pop("_region", "r") / f"{mid}.json"] = doc
    data_lint.check_kits(parsed, data_lint._compose_maps(parsed, errors), errors, advisories, report,
                         bundle_paths=BUNDLE, canon=canon)
    return errors


class TestKitRules(unittest.TestCase):
    def test_clean_fixture(self):
        self.assertEqual(run(maps={"m": {**GRID, "decor": [{"sprite": "@cargo", "cell": [1, 1]}], "entities": []}}), [])

    def test_schema_bad_pick_and_weight(self):
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["pick"] = "random"
        self.assertTrue(any("pick" in e for e in run(k)))
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["pool"] = [["c1", 0]]
        self.assertTrue(any("weight" in e for e in run(k)))

    def test_pool_and_cast_ids_must_exist(self):
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["pool"].append("ghost")
        self.assertTrue(any("ghost" in e for e in run(k)))
        k = copy.deepcopy(KITS); k["r"]["cast"].append("ghost")
        self.assertTrue(any("ghost" in e for e in run(k)))

    def test_unresolved_ref_and_bad_material(self):
        errs = run(maps={"m": {**GRID, "decor": [{"sprite": "@nope", "cell": [1, 1]}], "entities": [],
                               "floor_layers": [{"material": "plain", "cells": "all"}]}})
        self.assertTrue(any("@nope" in e for e in errs) and any("material" in e for e in errs))

    def test_refs_forbidden_on_visual_states_arenas_named(self):
        errs = run(maps={"m": {**GRID, "decor": [], "entities": [
            {"id": "a", "kind": "prop", "sprite": "@cargo", "cell": [1, 1], "visual_states": [{"when": {"counter": "x"}, "sprite": "c1"}]},
            {"id": "b", "kind": "npc", "display_name": "Relc", "sprite": "@cargo", "cell": [2, 2]}]}},
                   arenas=[{"id": "ar", "decor": [{"sprite": "@cargo", "cell": [0, 0]}]}])
        self.assertEqual(sum("visual_states" in e for e in errs), 1)
        self.assertEqual(sum("arena" in e for e in errs), 1)
        self.assertEqual(sum("named" in e for e in errs), 1)

    def test_door_pick_rules(self):
        errs = run(maps={"m": {**GRID, "decor": [{"sprite": "@door_x", "cell": [1, 1]}], "entities": [
            {"id": "d", "kind": "door", "sprite": "@door_x", "cell": [2, 2]}]}})
        self.assertEqual(sum("door pick" in e for e in errs), 2)
        k = copy.deepcopy(KITS); k["r"]["roles"]["door_x"]["pool"].append("d_bad")
        self.assertTrue(any("footprint" in e for e in run(k)))
        k = copy.deepcopy(KITS); k["r"]["roles"]["door_x"]["pool"] = ["d1", "c3"]
        self.assertTrue(any("shadow" in e for e in run(k)))

    def test_public_fallback_floor(self):
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["pool"] = ["c1", "c2"]
        k["_sprites_patch"] = None
        sprites = copy.deepcopy(SPRITES); sprites["c2"]["fallback_sprite"] = "own_a"
        errors = []
        parsed = {data_lint.DATA / "kits.json": k, data_lint.DATA / "sprites.json": sprites, data_lint.DATA / "arenas.json": {"arenas": []}}
        data_lint.check_kits(parsed, {}, errors, [], [], bundle_paths=BUNDLE, canon=frozenset())
        self.assertTrue(any("2 distinct owned" in e for e in errors))
        sprites["c1"].pop("fallback_sprite")
        errors = []
        data_lint.check_kits(parsed, {}, errors, [], [], bundle_paths=BUNDLE, canon=frozenset())
        self.assertTrue(any("fallback_sprite" in e for e in errors))

    def test_denylist(self):
        errs = run(maps={"m": {**GRID, "decor": [], "entities": [
            {"id": "p", "kind": "prop", "display_name": "Ruled Paper in Three Weights", "sprite": "@cargo", "cell": [1, 1]}]}})
        self.assertTrue(any("deny" in e and "paper" in e for e in errs))

    def test_cast_rules(self):
        base = {**GRID, "decor": []}
        # anonymous NPC off-cast -> error
        errs = run(maps={"m": {**base, "entities": [{"id": "a", "kind": "npc", "display_name": "A Villager", "sprite": "relc", "cell": [1, 1]}]}})
        self.assertTrue(any("cast" in e and "A Villager" in e for e in errs))
        # canon name on a cast rig -> error
        errs = run(maps={"m": {**base, "entities": [{"id": "b", "kind": "npc", "display_name": "Relc", "sprite": "townswoman", "cell": [1, 1]}]}})
        self.assertTrue(any("canon" in e for e in errs))
        # role-titled NPC on a cast rig -> ok
        self.assertEqual(run(maps={"m": {**base, "entities": [{"id": "c", "kind": "npc", "display_name": "Resting Runner", "sprite": "city_scribe", "cell": [1, 1]}]}}), [])
        # a region with an EMPTY cast is unconstrained (Phase 0 stays green)
        k = copy.deepcopy(KITS); k["r"]["cast"] = []
        self.assertEqual(run(k, maps={"m": {**base, "entities": [{"id": "a", "kind": "npc", "display_name": "A Villager", "sprite": "relc", "cell": [1, 1]}]}}), [])

    def test_sprite_exists_and_stacked_decor(self):
        errs = run(maps={"m": {**GRID, "decor": [{"sprite": "c3", "cell": [1, 1]}] * 3 + [{"sprite": "ghost", "cell": [2, 2]}], "entities": []}})
        self.assertTrue(any("ghost" in e for e in errs) and any("3 decor" in e for e in errs))


def run_with_sprites(sprites, kits=KITS, maps=None):
    errors = []
    parsed = {data_lint.DATA / "kits.json": kits, data_lint.DATA / "sprites.json": sprites,
              data_lint.DATA / "arenas.json": {"arenas": []}}
    for mid, doc in (maps or {}).items():
        parsed[data_lint.DATA / "maps" / "r" / f"{mid}.json"] = doc
    data_lint.check_kits(parsed, data_lint._compose_maps(parsed, errors), errors, [], [], bundle_paths=BUNDLE, canon=frozenset())
    return errors


class TestTask5Gaps(unittest.TestCase):
    def door_sprites(self, a, b):
        s = copy.deepcopy(SPRITES)
        s["d1"].update(a); s["d2"].update(b)
        return s

    def test_door_footprint_uses_rendered_size(self):
        # raw sheets differ (34x44 vs 68x88) but render_scale makes them 34x44 -> pass
        s = self.door_sprites({}, {"animations": {"idle": {"sheet": "res://assets/own.png", "frame_size": [68, 88]}}, "render_scale": 0.5})
        self.assertEqual([e for e in run_with_sprites(s) if "footprint" in e], [])
        # raw sheets match but render_scale makes the footprints differ -> fail
        s = self.door_sprites({}, {"render_scale": 2.0})
        self.assertTrue(any("footprint" in e for e in run_with_sprites(s)))

    def test_denylist_whole_word(self):
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["deny"] = ["sack"]
        def errs(name):
            return run(k, maps={"m": {**GRID, "decor": [], "entities": [
                {"id": "p", "kind": "prop", "display_name": name, "sprite": "@cargo", "cell": [1, 1]}]}})
        self.assertEqual([e for e in errs("Sackcloth bundle") if "deny" in e], [])
        self.assertTrue(any("deny" in e and "sack" in e for e in errs("A Sack")))

    def test_rule11_coords_and_variants(self):
        base = {**GRID, "decor": [], "entities": []}
        errs = run(maps={"m": {**base, "floor_layers": [{"material": "@fa", "variants": [[1, 1]], "cells": "all"}]}})
        self.assertTrue(any("both coords and variants" in e for e in errs))
        errs = run(maps={"m": {**base, "floor_layers": [{"material": "@fa", "cells": "all"}]}})
        self.assertEqual([e for e in errs if "both coords" in e], [])


class TestGates(unittest.TestCase):
    def test_g1_pool_size_and_ceiling(self):
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["pool"] = ["c1", "c2"]
        resolved = {"m": {**GRID, "decor": [{"sprite": "c1", "sprite_role": "cargo", "cell": [i, 0]} for i in range(6)], "entities": []}}
        errors = []
        data_lint.check_kit_gates(resolved, {"m": "r"}, k, [], errors, [], [], base_ref=None, baseline=None)
        self.assertTrue(any("G1" in e and "pool of at least 3" in e for e in errors))
        self.assertTrue(any("G1" in e and "ceil" in e for e in errors))

    def test_g1_clean_and_coverage_report(self):
        decor = [{"sprite": v, "sprite_role": "cargo", "cell": [i, 0]} for i, v in enumerate(["c1", "c2", "c3", "c1", "c2", "c3"])]
        decor.append({"sprite": "c1", "cell": [0, 1]})  # explicit id for a pooled kind
        errors, report = [], []
        data_lint.check_kit_gates({"m": {**GRID, "decor": decor, "entities": []}}, {"m": "r"}, KITS, [], errors, [], report, base_ref=None, baseline=None)
        self.assertEqual([e for e in errors if "G1" in e], [])
        self.assertTrue(any("conversion coverage" in r and "r" in r and "1" in r for r in report))
        self.assertTrue(any(r.startswith("kits:") for r in report))

    def test_g2_identity_share(self):
        resolved = {"m": {**GRID, "decor": [{"sprite": "c1", "sprite_role": "cargo", "cell": [0, 0]}, {"sprite": "c2", "cell": [1, 0]}, {"sprite": "c2", "cell": [2, 0]}], "entities": []},
                    "other": {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}, {"sprite": "c2", "cell": [1, 0]}], "entities": []}}
        errors = []
        data_lint.check_kit_gates(resolved, {"m": "r", "other": "q"}, KITS, [], errors, [], [], base_ref=None, baseline=None)
        self.assertTrue(any("G2" in e for e in errors))

    def test_g2_inactive_without_converted_region(self):
        resolved = {"m": {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}], "entities": []},
                    "o": {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}], "entities": []}}
        errors = []
        data_lint.check_kit_gates(resolved, {"m": "r", "o": "q"}, KITS, [], errors, [], [], base_ref=None, baseline=None)
        self.assertEqual(errors, [])

    def test_g2_material_exclusive(self):
        m = {**GRID, "entities": [], "decor": [{"sprite": "c1", "sprite_role": "cargo", "cell": [0, 0]}],
             "floor_layers": [{"material_ref": "fa", "cells": "all"}]}
        resolved = {"m": m, "o": {**GRID, "entities": [], "decor": [], "floor_layers": [{"material_ref": "fa", "cells": "all"}]}}
        errors = []
        data_lint.check_kit_gates(resolved, {"m": "r", "o": "q"}, KITS, [], errors, [], [], base_ref=None, baseline=None)
        self.assertTrue(any("G2" in e and "fa" in e for e in errors))

    def test_g3_ratchet_and_tolerance(self):
        baseline = {"tolerance": {"placements": 1, "pp": 2}, "generic_class": {"c1": "generic", "c2": "regional"},
                    "regions": {"r": {"placements": 4, "generic_placements": 1, "generic_share_pct": 25.0, "maps": {"m": {"placements": 4, "generic_placements": 1}}}}}
        ok = {"m": {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}, {"sprite": "c1", "cell": [1, 0]}, {"sprite": "c2", "cell": [2, 0]}, {"sprite": "c2", "cell": [3, 0]}], "entities": []}}
        errors, adv = [], []
        data_lint.check_kit_gates(ok, {"m": "r"}, KITS, [], errors, adv, [], base_ref=None, baseline=baseline)
        self.assertTrue(any("G3" in e for e in errors))  # +1 placement is inside tolerance but +25pp is not
        errors, adv = [], []
        data_lint.check_kit_gates({"new_map": ok["m"]}, {"new_map": "r"}, KITS, [], errors, adv, [], base_ref=None, baseline=baseline)
        self.assertEqual([e for e in errors if "G3" in e], [])
        self.assertTrue(any("not in baseline" in a for a in adv))

    def test_g3_within_tolerance_passes(self):
        baseline = {"tolerance": {"placements": 1, "pp": 2}, "generic_class": {"c1": "generic", "c2": "regional"},
                    "regions": {"r": {"placements": 4, "generic_placements": 2, "generic_share_pct": 50.0, "maps": {"m": {"placements": 4, "generic_placements": 2}}}}}
        cur = {"m": {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}, {"sprite": "c1", "cell": [1, 0]}, {"sprite": "c2", "cell": [2, 0]}, {"sprite": "c2", "cell": [3, 0]}], "entities": []}}
        errors = []
        data_lint.check_kit_gates(cur, {"m": "r"}, KITS, [], errors, [], [], base_ref=None, baseline=baseline)
        self.assertEqual([e for e in errors if "G3" in e], [])

    def test_hidden_sprite_entities_are_not_placements(self):
        doc = {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}],
               "entities": [{"id": "a", "sprite": "c2", "hide_sprite": True, "cell": [1, 1]}, {"id": "b", "cell": [2, 2]}]}
        self.assertEqual([p["sprite"] for p in data_lint._placements(doc)], ["c1"])

    def test_g4_structural_diff(self):
        base = {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}], "entities": [], "blocked": [[1, 1]]}
        cur = copy.deepcopy(base); cur["decor"][0]["sprite"] = "@cargo"; cur["blocked"] = [[1, 2]]
        errors = []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors)
        self.assertTrue(any("G4" in e and "blocked" in e for e in errors))
        cur["blocked"] = [[1, 1]]; errors = []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors)
        self.assertEqual(errors, [])

    def test_g4_other_components_and_unconverted_maps(self):
        base = {**GRID, "decor": [{"sprite": "c1", "cell": [0, 0]}], "entities": [], "walls": {"segments": [{"from": [0, 0], "to": [3, 0]}]},
                "scatter": [{"density": 0.1, "cluster": 0.5}]}
        for comp, mutate in (("decor", lambda d: d["decor"].append({"sprite": "@cargo", "cell": [5, 5]})),
                             ("walls", lambda d: d["walls"]["segments"][0].update({"to": [4, 0]})),
                             ("scatter", lambda d: d["scatter"][0].update({"density": 0.2}))):
            cur = copy.deepcopy(base); cur["decor"][0]["sprite"] = "@cargo"; mutate(cur)
            errors = []
            data_lint._g4_compare({"m": cur}, {"m": base}, errors)
            self.assertTrue(any("G4" in e and comp in e for e in errors), comp)
        cur = copy.deepcopy(base); cur["decor"].append({"sprite": "c2", "cell": [5, 5]})  # no @ ref -> not a conversion
        errors = []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors)
        self.assertEqual(errors, [])

    def test_g4_skips_without_base(self):
        adv = []
        self.assertEqual(data_lint._g4_base_maps("refs/does-not-exist", adv), None)
        self.assertTrue(any("G4" in a for a in adv))

    def test_baseline_on_head_is_self_consistent(self):
        path = GAME / "qa" / "baselines" / "scene-repetition.json"
        baseline = json.loads(path.read_text())
        self.assertEqual(set(baseline), {"_comment", "tolerance", "generic_class", "regions"})
        parsed, maps = data_lint._lint_inputs()
        resolved = data_lint.check_kits(parsed, maps, [], [], [])
        regen = data_lint.build_scene_baseline(resolved, data_lint._map_regions(parsed), baseline["tolerance"])
        self.assertEqual(regen["regions"], baseline["regions"])
        self.assertEqual(regen["generic_class"], baseline["generic_class"])

class TestFixRound1(unittest.TestCase):
    def test_base_maps_load_real_ref(self):
        adv = []
        base = data_lint._g4_base_maps("HEAD", adv)
        parsed, maps = data_lint._lint_inputs()
        self.assertIsNotNone(base, adv)
        self.assertGreater(len(base), 30)
        self.assertIn("street", base)
        self.assertEqual(set(base) - {"_shared_talk"}, set(base))
        self.assertTrue(set(maps) <= set(base) | {"_shared_talk"})

    def test_empty_base_is_advisory_none(self):
        adv = []
        with mock.patch.object(data_lint, "_git", return_value=""):
            self.assertIsNone(data_lint._g4_base_maps("HEAD", adv))
        self.assertTrue(any("G4" in a for a in adv))

    def test_g4_through_real_base_loader(self):
        base = data_lint._g4_base_maps("HEAD", [])
        cur = copy.deepcopy(base["street"])
        cur["decor"][0]["sprite"] = "@cargo"
        path = data_lint.DATA / "maps" / "liscor" / "street.json"
        def go(doc):
            errors, report = [], []
            data_lint.check_kit_gates({"street": doc}, {"street": "liscor"}, KITS, {path: doc}, errors, [], report, base_ref="HEAD", baseline=None)
            return errors, report
        errors, report = go(cur)
        self.assertEqual([e for e in errors if "G4" in e], [])
        self.assertTrue(report[-1].endswith("G4 ok"), report[-1])
        cur["decor"].append(copy.deepcopy(cur["decor"][0]))
        errors, _ = go(cur)
        self.assertTrue(any("G4" in e and "decor" in e for e in errors))

    def test_main_base_without_value_exits_2(self):
        r = subprocess.run([sys.executable, str(GAME / "scripts" / "data_lint.py"), "--base"], capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(r.returncode, 2)
        self.assertIn("--base", r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    def test_g1_counts_hidden_role_rows_like_resolver(self):
        # 6 @role entities, all hide_sprite: resolver counts 6 and picks one variant for a map pick
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["pool"] = ["c1", "c2"]
        ents = [{"id": f"e{i}", "sprite": "c1", "sprite_role": "cargo", "hide_sprite": True, "cell": [i, 0]} for i in range(6)]
        errors = []
        data_lint.check_kit_gates({"m": {**GRID, "decor": [], "entities": ents}}, {"m": "r"}, k, [], errors, [], [], base_ref=None, baseline=None)
        self.assertTrue(any("G1" in e and "pool of at least 3" in e for e in errors))
        self.assertTrue(any("G1" in e and "ceil" in e for e in errors))

    def test_has_ref_detects_material_refs(self):
        self.assertTrue(data_lint._has_ref({"floor_layers": [{"material": "@fa"}]}))
        self.assertTrue(data_lint._has_ref({"walls": {"material": "@fa"}}))
        self.assertTrue(data_lint._has_ref({"walls": {"segments": [{"material": "@fa"}]}}))
        self.assertFalse(data_lint._has_ref({"floor_layers": [{"material": "plain"}], "decor": []}))

    def test_g4_na_when_nothing_compared(self):
        report = []
        data_lint.check_kit_gates({"m": {**GRID, "decor": [], "entities": []}}, {"m": "r"}, KITS, {}, [], [], report, base_ref=None, baseline=None)
        self.assertTrue(report[-1].endswith("G4 n/a"), report[-1])

    def test_biome_shared_report_and_advisory(self):
        def doc(): return {**GRID, "biome": "cave", "entities": [], "decor": [{"sprite": "c1", "sprite_role": "cargo", "cell": [0, 0]}]}
        resolved = {"m": doc(), "o": {**GRID, "biome": "cave", "entities": [], "decor": []}}
        errors, adv, report = [], [], []
        data_lint.check_kit_gates(resolved, {"m": "r", "o": "q"}, KITS, {}, errors, adv, report, base_ref=None, baseline=None)
        self.assertTrue(any("biome cave shared with 2 regions" in r for r in report), report)
        self.assertTrue(any("biome cave" in a for a in adv))
        self.assertEqual([e for e in errors if "biome" in e], [])


class TestBiomeRows(unittest.TestCase):
    NEW = ["riverfarm_interior", "liscor_civic", "invrisil_shop", "pallass_interior"]

    def test_rows_copy_inn_sim_and_render_fields(self):
        biomes = json.loads((GAME / "data" / "biomes.json").read_text())
        inn = biomes["inn"]
        for bid in self.NEW:
            row = biomes[bid]
            for key in ("footstep_family", "interior_flavor", "fallback_render", "sheet", "tile_px", "floor", "blocked_sheet", "blocked", "blocked_props", "skirt_sheet", "skirt_tile_px", "skirt"):
                self.assertEqual(row[key], inn[key], f"{bid}.{key}")
            self.assertNotIn("interior_flavor_by_map", row)
        world = (GAME / "src" / "world" / "world.gd").read_text()
        for bid in self.NEW:
            self.assertIn(f'"{bid}": {{"preset": "dust_motes", "phase": ["dusk", "night"]}},', world)
        maps = (GAME / "data" / "maps").glob("*/*.json")
        self.assertEqual([p.name for p in maps if json.loads(p.read_text()).get("biome") in self.NEW], [])  # Phase 0: referenced by no map


class TestRealTree(unittest.TestCase):
    def test_clean_on_head(self):
        r = subprocess.run([sys.executable, str(GAME / "scripts" / "data_lint.py")], capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("kits:", r.stdout)
        self.assertIn("G4 n/a", r.stdout)  # the G-gate REPORT line (Task 6)


if __name__ == "__main__":
    unittest.main()
