#!/usr/bin/env python3
"""#607 lane A: every kit lint rule proven able to FAIL, and clean on HEAD."""
import copy, json, os, subprocess, sys, unittest
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

    def test_schema_radius_is_a_non_negative_int(self):
        for bad in (-1, "3", True, 1.5, None):
            k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["radius"] = bad
            self.assertTrue(any("radius" in e for e in run(k)), bad)
        for ok in (0, 3):
            k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["radius"] = ok
            self.assertEqual([e for e in run(k) if "radius" in e or "unknown keys" in e], [], ok)

    def test_schema_radius_rejected_on_door_and_map_picks(self):
        # #608 final review M8b: only cell picks read radius; a door or map pick would silently ignore it
        for role in ("door_x", "cargo"):
            for pick in ("door", "map"):
                k = copy.deepcopy(KITS); k["r"]["roles"][role]["pick"] = pick; k["r"]["roles"][role]["radius"] = 2
                self.assertTrue(any("radius applies only to cell picks" in e for e in run(k)), (role, pick))
        k = copy.deepcopy(KITS); k["r"]["roles"]["cargo"]["radius"] = 2
        self.assertEqual([e for e in run(k) if "radius" in e], [])

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

    def test_null_blocks_only_wall_segment_face_and_cap(self):
        k = copy.deepcopy(KITS)
        k["r"]["materials"]["wb"] = {"sheet": "res://assets/own.png", "tile_px": 16, "cap": [0, 0], "face": [1, 0]}
        base = {**GRID, "decor": [], "entities": []}
        def errs(**doc):
            return [e for e in run(k, maps={"m": {**base, **doc}}) if "null" in e]
        self.assertEqual(errs(walls={"segments": [{"material": "@wb", "face": None, "from": [0, 0], "to": [1, 0]}]}), [])
        self.assertEqual(errs(walls={"segments": [{"material": "@wb", "cap": None, "from": [0, 0], "to": [1, 0]}]}), [])
        bad = errs(walls={"segments": [{"material": "@wb", "tone": None, "from": [0, 0], "to": [1, 0]}]})
        self.assertTrue(any("walls.segments[0]" in e and "'tone'" in e for e in bad), bad)
        bad = errs(floor_layers=[{"material": "@fa", "face": None, "cells": "all"}])
        self.assertTrue(any("floor_layers[0]" in e and "'face'" in e for e in bad), bad)

    def test_null_with_fallback_render_is_an_error(self):
        k = copy.deepcopy(KITS)
        k["r"]["materials"]["wb"] = {"sheet": "res://assets/own.png", "tile_px": 16, "cap": [0, 0], "face": [1, 0],
                                     "fallback_render": {"sheet": "res://assets/own.png", "tile_px": 16, "cap": [0, 0], "face": [1, 0]}}
        seg = {"material": "@wb", "face": None, "from": [0, 0], "to": [1, 0]}
        errs = run(k, maps={"m": {**GRID, "decor": [], "entities": [], "walls": {"segments": [seg]}}})
        self.assertTrue(any("walls.segments[0]" in e and "fallback_render" in e and "'face'" in e for e in errs), errs)
        del k["r"]["materials"]["wb"]["fallback_render"]
        errs = run(k, maps={"m": {**GRID, "decor": [], "entities": [], "walls": {"segments": [dict(seg)]}}})
        self.assertEqual([e for e in errs if "fallback_render" in e], [])


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

    def test_g2_share_counts_only_converted_maps(self):
        # #608 ruling: the >=50% share is over the region's CONVERTED maps (an @ sprite or
        # material ref); unconverted maps of the same region only feed the report-only share.
        conv = {**GRID, "entities": [], "decor": [{"sprite": "c3", "sprite_role": "cargo", "cell": [0, 0]},
                                                 {"sprite": "c3", "sprite_role": "cargo", "cell": [3, 0]},
                                                 {"sprite": "c1", "cell": [5, 5]}]}
        plain = {**GRID, "entities": [], "decor": [{"sprite": s, "cell": [i, 0]} for i, s in enumerate(["c1", "c2", "c1"])]}
        resolved = {"conv": conv, "plain1": plain, "plain2": copy.deepcopy(plain),
                    "other": {**GRID, "entities": [], "decor": [{"sprite": "c1", "cell": [0, 0]}, {"sprite": "c2", "cell": [1, 0]}]}}
        errors, report = [], []
        data_lint.check_kit_gates(resolved, {"conv": "r", "plain1": "r", "plain2": "r", "other": "q"}, KITS, [], errors, [], report,
                                  base_ref=None, baseline=None)
        self.assertEqual([e for e in errors if "G2" in e], [])  # 2/3 over the converted map; 2/9 region-wide
        line = next(r for r in report if r.startswith("kits G2: r identity"))
        self.assertIn("66.67% unique art over 1 converted map(s)", line)
        self.assertIn("22.22% region-wide (report only)", line)

    def test_g2_converted_map_below_half_fails_even_when_region_passes(self):
        conv = {**GRID, "entities": [], "decor": [{"sprite": "c3", "sprite_role": "cargo", "cell": [0, 0]},
                                                 {"sprite": "c1", "cell": [3, 0]}, {"sprite": "c2", "cell": [5, 0]}]}
        mat_only = {**GRID, "entities": [], "decor": [{"sprite": "c1", "cell": [0, 0]}],
                    "floor_layers": [{"material_ref": "fa", "cells": "all"}]}
        unique = {**GRID, "entities": [], "decor": [{"sprite": "c3", "cell": [i, 1]} for i in range(8)]}
        resolved = {"conv": conv, "mat_only": mat_only, "unique": unique,
                    "other": {**GRID, "entities": [], "decor": [{"sprite": "c1", "cell": [0, 0]}, {"sprite": "c2", "cell": [1, 0]}]}}
        errors, report = [], []
        data_lint.check_kit_gates(resolved, {"conv": "r", "mat_only": "r", "unique": "r", "other": "q"}, KITS, [], errors, [], report,
                                  base_ref=None, baseline=None)
        # converted maps = conv + mat_only (a material ref counts): 1/4 unique; region-wide 9/12 would pass
        self.assertTrue(any("G2" in e and "25.0%" in e for e in errors), errors)
        self.assertTrue(any("75.0% region-wide" in r for r in report), report)

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

    def _recompose_case(self, cur_marker, base_marker):
        base = {**GRID, "decor": [{"sprite": "@cargo", "cell": [0, 0]}], "entities": [], "blocked": [[1, 1]]}
        if base_marker is not None:
            base["_kits_recompose"] = base_marker
        cur = copy.deepcopy(base); cur["blocked"] = [[1, 2]]
        cur.pop("_kits_recompose", None)
        if cur_marker is not None:
            cur["_kits_recompose"] = cur_marker
        errors, report = [], []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors, report)
        return errors, report

    def test_g4_recompose_new_marker_is_advisory(self):
        errors, report = self._recompose_case("#608 - lamp composition fix", None)
        self.assertEqual(errors, [])
        self.assertTrue(any("G4" in r and "m" in r and "#608 - lamp composition fix" in r for r in report), report)
        errors, report = self._recompose_case("#608 - second reason", "#608 - lamp composition fix")  # changed value
        self.assertEqual(errors, [])
        self.assertTrue(report)

    def test_g4_recompose_reports_every_component(self):
        # #608 final review I1: a marker waives the whole map, so every differing component is named
        base = {**GRID, "decor": [{"sprite": "@cargo", "cell": [0, 0]}], "entities": [], "blocked": [[1, 1]]}
        cur = copy.deepcopy(base)
        cur["decor"].append({"sprite": "@cargo", "cell": [4, 4]}); cur["decor"][0]["cell"] = [2, 0]
        cur["blocked"].append([4, 4])
        cur["_kits_recompose"] = "#608 - lamps"
        errors, report, advised = [], [], []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors, report, advised)
        self.assertEqual(errors, [])
        self.assertEqual(advised, ["m"])
        self.assertEqual(len(report), 1, report)
        self.assertIn("decor/entities cells +2/-1, blocked +1 changed", report[0])
        cur.pop("_kits_recompose"); errors = []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors)
        self.assertEqual(len(errors), 1, errors)
        self.assertIn("decor/entities cells +2/-1, blocked +1", errors[0])

    def test_g4_new_marker_that_waives_nothing_is_reported(self):
        base = {**GRID, "decor": [{"sprite": "@cargo", "cell": [0, 0]}], "entities": [], "blocked": [[1, 1]]}
        cur = copy.deepcopy(base); cur["_kits_recompose"] = "#608 - sprite swap only"
        errors, report, advised = [], [], []
        data_lint._g4_compare({"m": cur}, {"m": base}, errors, report, advised)
        self.assertEqual(errors, [])
        self.assertEqual(advised, ["m"])
        self.assertTrue(any("waives nothing" in r for r in report), report)
        base["_kits_recompose"] = cur["_kits_recompose"]; report = []
        data_lint._g4_compare({"m": cur}, {"m": base}, [], report)
        self.assertEqual(report, [])

    def test_g4_recompose_marker_unchanged_from_base_enforces(self):
        errors, report = self._recompose_case("#608 - lamp composition fix", "#608 - lamp composition fix")
        self.assertTrue(any("G4" in e and "blocked" in e for e in errors), errors)
        self.assertEqual(report, [])

    def test_g4_no_marker_enforces(self):
        errors, _ = self._recompose_case(None, None)
        self.assertTrue(any("G4" in e and "blocked" in e for e in errors), errors)

    def test_g4_malformed_marker_errors(self):
        for bad in ("", "   ", "no issue number here", 608, ["#608"]):
            errors, _ = self._recompose_case(bad, None)
            self.assertTrue(any("_kits_recompose" in e for e in errors), (bad, errors))

    def test_g4_recompose_through_real_base_loader(self):
        base = data_lint._g4_base_maps("HEAD", [])
        cur = copy.deepcopy(base["street"])
        cur["decor"][0]["sprite"] = "@cargo"
        cur["decor"].append(copy.deepcopy(cur["decor"][0]))
        cur["_kits_recompose"] = "#608 - add lamp"
        path = data_lint.DATA / "maps" / "liscor" / "street.json"
        errors, report = [], []
        data_lint.check_kit_gates({"street": cur}, {"street": "liscor"}, KITS, {path: cur}, errors, [], report, base_ref="HEAD", baseline=None)
        self.assertEqual([e for e in errors if "G4" in e], [])
        self.assertTrue(any("G4" in r and "#608 - add lamp" in r for r in report), report)
        self.assertTrue(report[-1].endswith("G4 ok (1 advisory: street)"), report[-1])

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
        regen = data_lint.build_scene_baseline(resolved, data_lint._map_regions(parsed), baseline["tolerance"],
                                               data_lint.ArtIdent.from_parsed(parsed))
        self.assertEqual(regen["regions"], baseline["regions"])
        self.assertEqual(regen["generic_class"], baseline["generic_class"])

class TestGatesArtMode(TestGates):
    """#623 review M4: every TestGates case again with an art ident, as production runs them
    (in SPRITES, c1 = c2 and c3 = own_a = own_b are one picture each)."""

    def setUp(self):
        real, ident = data_lint.check_kit_gates, data_lint.ArtIdent(SPRITES, lambda _path: None)

        def with_art(*args, **kwargs):
            kwargs.setdefault("ident", ident)
            return real(*args, **kwargs)
        patcher = mock.patch.object(data_lint, "check_kit_gates", with_art)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_converted_scope_counts_art_where_ids_diverge(self):
        conv = {**GRID, "entities": [], "decor": [row("c3", 0, role="cargo"), row("c3", 3, role="cargo"), row("c1", 5, 5)]}
        resolved = {"conv": conv, "other": {**GRID, "entities": [], "decor": [row("c2", 0)]}}
        report = []
        data_lint.check_kit_gates(resolved, {"conv": "r", "other": "q"}, KITS, [], [], [], report, base_ref=None, baseline=None)
        self.assertIn("66.67% unique art", next(r for r in report if r.startswith("kits G2: r identity")))
        report = []
        data_lint.check_kit_gates(resolved, {"conv": "r", "other": "q"}, KITS, [], [], [], report, base_ref=None, baseline=None, ident=None)
        self.assertIn("100.0% unique art", next(r for r in report if r.startswith("kits G2: r identity")), "id mode: c1 looks unique")


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


PACK = {"sheet": "res://assets/pack.png", "frame_size": [16, 32]}
ART_SPRITES = {**copy.deepcopy(SPRITES),
               "lamp_r": {"animations": {"idle": {**PACK, "region": [0, 0, 16, 32]}}},
               "lamp_q": {"animations": {"idle": {**PACK, "region": [0, 0, 16, 32]}}, "render_scale": 0.5, "fallback_sprite": "own_b"},
               "lamp_mine": {"animations": {"idle": {**PACK, "region": [16, 0, 16, 32]}}},
               "door": {"animations": {"idle": {**PACK, "region": [32, 0, 16, 32]}}},
               "barrel": {"animations": {"idle": {**PACK, "region": [48, 0, 16, 32]}}}}
ART_SPRITES["c1"]["kind"] = ART_SPRITES["c2"]["kind"] = "crate"   # recorded kinds, as wire_asset writes them
UTIL_KITS = copy.deepcopy(KITS)
UTIL_KITS["_common"]["roles"]["utility"] = {"kind": "crate", "pick": "cell", "pool": ["c1", "c2", "c3"]}


def gates(resolved, regions, kits=KITS, art=True, baseline=None):
    errors, advisories, report = [], [], []
    ident = data_lint.ArtIdent(ART_SPRITES, lambda _path: None) if art else None
    data_lint.check_kit_gates(resolved, regions, kits, [], errors, advisories, report,
                              base_ref=None, baseline=baseline, ident=ident)
    return errors, advisories, report


def row(sprite, x, y=0, role=""):
    return {"sprite": sprite, "cell": [x, y], **({"sprite_role": role} if role else {})}


class TestArtIdentityG2(unittest.TestCase):
    """#623: G2 counts art identity; _common holds the utility Tier A only, capped at 30%."""

    def test_two_ids_of_one_picture_in_two_regions_are_exclusive_to_neither(self):
        resolved = {"m": {**GRID, "entities": [], "decor": [row("c3", 0, role="cargo"), row("lamp_r", 1), row("lamp_r", 2)]},
                    "o": {**GRID, "entities": [], "decor": [row("lamp_q", 0)]}}
        regions = {"m": "r", "o": "q"}
        errors, _, report = gates(resolved, regions, art=False)
        self.assertEqual([e for e in errors if "G2" in e], [], "by id, lamp_r looks exclusive to r")
        errors, _, report = gates(resolved, regions)
        self.assertTrue(any("G2 identity" in e and "33.33%" in e for e in errors), errors)
        resolved["o"]["decor"] = [row("lamp_mine", 0)]
        errors, _, _ = gates(resolved, regions)
        self.assertEqual([e for e in errors if "G2" in e], [], "different art in q leaves r exclusive")

    def _util_map(self, n_util):
        decor = [row("c1", i, 1, "utility") for i in range(n_util)]
        decor += [row("c3", i, 2, "cargo") for i in range(4)] + [row("c2", i, 3) for i in range(3)]
        return {"m": {**GRID, "entities": [], "decor": decor},
                "o": {**GRID, "entities": [], "decor": [row("c1", 0), row("c2", 1)]}}

    def test_tier_a_common_placements_leave_numerator_and_denominator(self):
        errors, _, report = gates(self._util_map(3), {"m": "r", "o": "q"}, UTIL_KITS)
        self.assertEqual([e for e in errors if "G2" in e], [], errors)
        line = next(r for r in report if r.startswith("kits G2: r identity"))
        self.assertIn("57.14% unique art", line)  # 4 of 7: the 3 utility rows are out of both sides
        self.assertIn("_common utility 3/10 (30.0%, cap 30%", line)
        kits = copy.deepcopy(UTIL_KITS)
        kits["r"]["roles"]["utility"] = {"pick": "cell", "pool": ["c1", "c2", "c3"]}
        errors, _, _ = gates(self._util_map(3), {"m": "r", "o": "q"}, kits)
        self.assertTrue(any("G2 identity" in e and "40.0%" in e for e in errors), "a region role of the same name counts")

    def test_region_unique_utility_art_leaves_the_numerator_too(self):
        # #623 review M5: counted, the 3 utility rows (art unique to r) would lift 3/7 to 6/10 and pass
        decor = ([row("lamp_mine", i, 1, "utility") for i in range(3)] + [row("c3", i, 2, "cargo") for i in range(3)]
                 + [row("c2", i, 3) for i in range(4)])
        resolved = {"m": {**GRID, "entities": [], "decor": decor}, "o": {**GRID, "entities": [], "decor": [row("c2", 0)]}}
        errors, _, report = gates(resolved, {"m": "r", "o": "q"}, UTIL_KITS)
        self.assertTrue(any("G2 identity" in e and "42.86%" in e for e in errors), errors)
        self.assertTrue(any("_common utility 3/10" in r for r in report), report)

    def test_non_tier_a_common_role_placements_are_counted(self):
        # #623 review M5: the old code excluded every _common role name; only Tier A leaves G2 now
        kits = copy.deepcopy(KITS)
        kits["_common"]["roles"]["street_lamp"] = {"kind": "lamp", "pick": "cell", "pool": ["lamp_mine", "c3"]}
        decor = ([row("lamp_mine", i, 1, "street_lamp") for i in range(3)] + [row("c3", i, 2, "cargo") for i in range(3)]
                 + [row("c2", i, 3) for i in range(4)])
        resolved = {"m": {**GRID, "entities": [], "decor": decor}, "o": {**GRID, "entities": [], "decor": [row("c2", 0)]}}
        errors, _, report = gates(resolved, {"m": "r", "o": "q"}, kits)
        self.assertEqual([e for e in errors if "G2" in e], [], errors)
        line = next(r for r in report if r.startswith("kits G2: r identity"))
        self.assertIn("60.0% unique art", line)
        self.assertIn("_common utility 0/10", line)

    def test_common_cap_passes_at_30_and_fails_above(self):
        errors, _, _ = gates(self._util_map(3), {"m": "r", "o": "q"}, UTIL_KITS)
        self.assertEqual([e for e in errors if "cap" in e], [])
        errors, _, _ = gates(self._util_map(4), {"m": "r", "o": "q"}, UTIL_KITS)
        self.assertTrue(any("G2 _common cap" in e and "4/11" in e and "over 30%" in e for e in errors), errors)

    def test_cap_holds_for_a_region_whose_own_kit_has_no_pools(self):
        kits = copy.deepcopy(UTIL_KITS); kits["q"] = {"materials": {}, "roles": {}, "cast": []}
        resolved = {"o": {**GRID, "entities": [], "decor": [row("c1", 0, 0, "utility"), row("c2", 1)]}}
        errors, _, _ = gates(resolved, {"o": "q"}, kits)
        self.assertTrue(any("G2 _common cap: q" in e for e in errors), errors)


class TestArtIdentityG3(unittest.TestCase):
    """#623: G3 classes generic/regional on art identity."""
    THREE = {"m": {**GRID, "entities": [], "decor": [row("lamp_r", 0)]},
             "o": {**GRID, "entities": [], "decor": [row("lamp_q", 0)]},
             "p": {**GRID, "entities": [], "decor": [row("lamp_q", 0), row("lamp_mine", 1)]}}
    REGIONS = {"m": "r", "o": "q", "p": "s"}

    def test_baseline_classes_each_id_by_its_art(self):
        ident = data_lint.ArtIdent(ART_SPRITES, lambda _path: None)
        art = data_lint.build_scene_baseline(self.THREE, self.REGIONS, {"placements": 1, "pp": 2}, ident)
        self.assertEqual(art["generic_class"], {"lamp_r": "generic", "lamp_q": "generic", "lamp_mine": "regional"})
        self.assertEqual(art["regions"]["r"]["generic_placements"], 1)
        by_id = data_lint.build_scene_baseline(self.THREE, self.REGIONS, {"placements": 1, "pp": 2})
        self.assertEqual(by_id["generic_class"]["lamp_r"], "regional", "by id, lamp_r sits in one region")

    def test_unbaselined_id_is_classed_on_the_fly_by_its_art(self):
        baseline = {"tolerance": {"placements": 1, "pp": 2}, "generic_class": {"lamp_mine": "regional"},
                    "regions": {"s": {"placements": 2, "generic_placements": 0, "generic_share_pct": 0.0,
                                      "maps": {"p": {"placements": 2, "generic_placements": 0}}}}}
        errors, _, report = gates(self.THREE, self.REGIONS, baseline=baseline)
        self.assertTrue(any("G3 ratchet: s generic share 50.0%" in e for e in errors), errors)
        self.assertTrue(any("classed on the fly" in r for r in report), report)
        errors, _, _ = gates(self.THREE, self.REGIONS, baseline=baseline, art=False)
        self.assertEqual([e for e in errors if "G3" in e], [], "by id, lamp_q sits in two regions and stays regional")


class TestSharedArtReport(unittest.TestCase):
    """#623: a REPORT line lists art carried by more than one sprite id (never an error)."""

    def test_groups_cross_region_and_alias_marks(self):
        sprites = copy.deepcopy(ART_SPRITES)
        sprites["lamp_alias"] = {**copy.deepcopy(sprites["lamp_mine"]), "_alias_of": "lamp_mine", "_alias_reason": "test"}
        ident = data_lint.ArtIdent(sprites, kl_hasher_missing())
        resolved = {"m": {**GRID, "entities": [], "decor": [row("lamp_r", 0), row("lamp_mine", 1)]},
                    "o": {**GRID, "entities": [], "decor": [row("lamp_q", 0)]}}
        report = []
        data_lint.report_shared_art(ident, resolved, {"m": "r", "o": "q"}, report)
        self.assertEqual(len(report), 1)
        line = report[0]
        self.assertTrue(line.startswith("kits art: 5 art identities carry more than one sprite id (1 cross-region; report only): "), line)
        self.assertIn("lamp_q = lamp_r CROSS-REGION [q, r]", line)
        self.assertIn("lamp_alias (alias) = lamp_mine;", line)
        self.assertNotIn("lamp_mine CROSS", line, "both ids of that picture sit in r only")
        self.assertIn("c1 = c2;", line)
        self.assertTrue(line.endswith("frame sheet(s) absent on disk, keyed by path"), line)

    def test_alias_must_name_a_live_twin_with_a_reason(self):
        sprites = copy.deepcopy(ART_SPRITES)
        sprites["lamp_alias"] = {**copy.deepcopy(sprites["lamp_mine"]), "_alias_of": "lamp_mine", "_alias_reason": "quest pin"}
        sprites["dangling"] = {**copy.deepcopy(sprites["lamp_mine"]), "_alias_of": "ghost", "_alias_reason": "x"}
        sprites["drifted"] = {**copy.deepcopy(sprites["lamp_r"]), "_alias_of": "lamp_mine", "_alias_reason": "x"}
        sprites["no_reason"] = {**copy.deepcopy(sprites["lamp_mine"]), "_alias_of": "lamp_mine", "_alias_reason": " "}
        sprites["reason_only"] = {**copy.deepcopy(sprites["lamp_mine"]), "_alias_reason": "x"}
        errors = []
        data_lint.check_aliases(data_lint.ArtIdent(sprites, lambda _p: None), errors)
        self.assertEqual([e for e in errors if "lamp_alias" in e], [])
        self.assertTrue(any("sprites.dangling: _alias_of 'ghost' is not a sprites.json id" in e for e in errors), errors)
        self.assertTrue(any("sprites.drifted: _alias_of 'lamp_mine' no longer draws the same art" in e for e in errors), errors)
        self.assertTrue(any("sprites.no_reason: _alias_of needs a non-empty _alias_reason" in e for e in errors), errors)
        self.assertTrue(any("sprites.reason_only: _alias_of 'None' is not a sprites.json id" in e for e in errors), errors)

    def test_real_tree_reports_the_twelve_groups(self):
        r = subprocess.run([sys.executable, str(GAME / "scripts" / "data_lint.py")], capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(r.returncode, 0, r.stderr)
        line = next(l for l in r.stdout.splitlines() if "REPORT -- kits art:" in l)
        self.assertIn("invrisil_facade_window_1 = window_blue CROSS-REGION [inn, invrisil, riverfarm]", line)
        self.assertRegex(line, r"kits art: 1[12] art identities")  # 11 without the overlay: body_a's sheet is bundle-only


def kl_hasher_missing():
    """A SheetHasher rooted where no sheet exists, so every frame sheet keys on its path."""
    return data_lint.kl.SheetHasher(Path("/nonexistent-wi-623"))


class TestCommonTierA(unittest.TestCase):
    def errs(self, role, where="_common"):
        k = copy.deepcopy(KITS); k[where]["roles"]["utility"] = role
        return [e for e in run_with_sprites(ART_SPRITES, k) if "utility" in e]

    def test_tier_a_roles_pass(self):
        for kind in ("crate", "barrel", "sack", "container"):
            self.assertEqual(self.errs({"kind": kind, "pool": ["c1", "c2", "barrel"]}), [], kind)

    def test_other_kinds_are_rejected(self):
        self.assertTrue(any("not a _common utility kind" in e for e in self.errs({"kind": "lamp", "pool": ["c1", "c2"]})))
        self.assertTrue(any("closed vocabulary" in e for e in self.errs({"kind": "spaceship", "pool": ["c1", "c2"]})))

    def test_kind_is_required_on_common_roles(self):
        self.assertTrue(any('declaring "kind"' in e for e in self.errs({"pool": ["c1", "c2"]})))
        self.assertTrue(any('declaring "kind"' in e for e in self.errs("c3")))
        self.assertEqual(self.errs({"pool": ["c1", "c2"]}, where="r"), [], "region roles need no kind")

    def test_wired_kind_vocabulary_rejects_a_door_in_a_crate_role(self):
        self.assertEqual(data_lint.kl.WIRED_KINDS["door"], "door")
        errs = self.errs({"kind": "crate", "pool": ["c1", "c2", "door"]})
        self.assertTrue(any("pool id 'door' is a door" in e for e in errs), errs)

    def test_region_role_kind_must_be_in_the_vocabulary(self):
        self.assertTrue(any("closed vocabulary" in e for e in self.errs({"kind": "spaceship", "pool": ["c1", "c2"]}, where="r")))
        self.assertEqual(self.errs({"kind": "lamp", "pool": ["c1", "c2"]}, where="r"), [])

    def test_unknown_kind_fails_closed(self):
        # #623 review I2: c3 has neither a recorded kind nor a WIRED_KINDS row
        errs = self.errs({"kind": "crate", "pool": ["c1", "c2", "c3"]})
        self.assertTrue(any("pool id 'c3' has no kind on record" in e for e in errs), errs)
        self.assertEqual([e for e in errs if "'c1'" in e or "'c2'" in e], [], "recorded crates pass")

    def test_recorded_kind_wins_over_wired_kinds(self):
        sprites = copy.deepcopy(ART_SPRITES)
        sprites["door"]["kind"] = "crate"     # a hand-declared, reviewable per-id kind
        sprites["c1"]["kind"] = "lamp"
        k = copy.deepcopy(KITS); k["_common"]["roles"]["utility"] = {"kind": "crate", "pool": ["c2", "door", "c1"]}
        errs = [e for e in run_with_sprites(sprites, k) if "utility" in e]
        self.assertEqual([e for e in errs if "'door'" in e], [])
        self.assertTrue(any("pool id 'c1' is a lamp" in e for e in errs), errs)

    def test_sprite_kind_must_be_in_the_vocabulary(self):
        sprites = copy.deepcopy(ART_SPRITES); sprites["c3"]["kind"] = "spaceship"
        self.assertTrue(any("sprites.c3: kind 'spaceship'" in e for e in run_with_sprites(sprites)))

    def test_real_common_pool_stays_empty_until_its_read(self):
        kits = json.loads((GAME / "data" / "kits.json").read_text())
        self.assertEqual(kits["_common"]["roles"], {})


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
            row = f'"{bid}": {{"preset": "dust_motes", "phase": ["dusk", "night"]}},'
            # #608 1b night read: invrisil_shop drops its mote default (sourceless discs); the others keep it.
            (self.assertNotIn if bid == "invrisil_shop" else self.assertIn)(row, world)
        maps = (GAME / "data" / "maps").glob("*/*.json")
        # Pilot 1b adopted invrisil_shop on the Rest only; any other adoption must be planned.
        self.assertEqual(sorted(f"{p.parent.name}/{p.name}" for p in maps if json.loads(p.read_text()).get("biome") in self.NEW), ["invrisil/adventurers_rest.json"])


class TestRealTree(unittest.TestCase):
    def test_clean_on_head(self):
        r = subprocess.run([sys.executable, str(GAME / "scripts" / "data_lint.py")], capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("kits:", r.stdout)
        # The G-gate REPORT line (Task 6). #608: real maps carry @refs now, so G4 compares
        # against the base tree ("skipped" only where no origin/main resolves). CI's python-suites
        # job is the one place G4 runs (fetch-depth: 0), so there it must compare, as TestLiveParity
        # refuses to skip Godot.
        g4 = "ok" if os.environ.get("CI") else "(ok|skipped)"
        self.assertRegex(r.stdout, r"kits: .*; G1 ok, G2 ok, G3 ok \(\d+ maps advisory\), G4 " + g4)


if __name__ == "__main__":
    unittest.main()
