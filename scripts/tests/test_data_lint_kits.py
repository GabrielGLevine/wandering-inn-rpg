#!/usr/bin/env python3
"""#607 lane A: every kit lint rule proven able to FAIL, and clean on HEAD."""
import copy, json, subprocess, sys, unittest
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


class TestRealTree(unittest.TestCase):
    def test_clean_on_head(self):
        r = subprocess.run([sys.executable, str(GAME / "scripts" / "data_lint.py")], capture_output=True, text=True, cwd=str(REPO_ROOT))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("kits:", r.stdout)  # the G-gate REPORT line (Task 6)


if __name__ == "__main__":
    unittest.main()
