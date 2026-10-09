#!/usr/bin/env python3
"""wi_kits_lib.py -- Python mirror of src/core/kit_resolver.gd (#607, index C3-C5).

Lint never chooses art: this module only reproduces the picks Godot makes so
data_lint and fill_kit can report them. Any change to a pick rule must land in
both runtimes together; tests/test_wi_kits_lib.py pins the shared outcomes.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path

MATERIAL_FIELDS = ["sheet", "tile_px", "coords", "variants", "tone", "wang_corners", "cap", "face", "fallback_render"]
TWO_32 = 4294967296.0
NON_PERSON_HEADINGS = {"The PC", "Antinium", "Horns roster note", "Invrisil civilian rigs"}
# Title/race words that open a heading ("Master Ilvriss", "Gnoll Tribe") but
# name no one: adding them as canon would ban every "Master"/"Gnoll" NPC.
GENERIC_FIRST_WORDS = {"Master", "Grand", "Tier", "Recruit", "Frazzled", "Gnoll", "Garuda", "Dullahan",
                       "Drake", "Human", "Den-Shop", "Forge-Tier"}
_HEADING_NAME = re.compile(r"^[A-Z][A-Za-z'\-]*( [A-Za-z'\-]+)*$")


class KitResolveError(ValueError):
    pass


def hash32(key: str) -> int:
    # djb2 is linear and correlates variants across cells; SHA-256 prefix must match the GD side.
    return int(hashlib.sha256(key.encode("utf-8")).hexdigest()[:8], 16)


godot_string_hash = hash32


def score(key: str, weight: float) -> float:
    return -math.log((hash32(key) + 0.5) / TWO_32) / weight


def subset_size(n_placements: int, pool_size: int) -> int:
    return min(max(2, min(4, 2 + n_placements // 6)), pool_size)


def load_kits(game_root: Path) -> dict:
    p = Path(game_root) / "data" / "kits.json"
    return json.loads(p.read_text()) if p.exists() else {}


def map_region(map_path: Path) -> str:
    return Path(map_path).parent.name


def map_kit(map_doc: dict, map_path: Path) -> str:
    return str(map_doc.get("kit", map_region(map_path)))


def lookup(kits: dict, region: str, section: str, name: str):
    for scope in (region, "_common"):
        table = (kits.get(scope) or {}).get(section) or {}
        if name in table:
            return table[name]
    return None


def pool_of(role) -> list:
    if isinstance(role, str):
        return [[role, 1.0]]
    return [[str(e[0]), float(e[1])] if isinstance(e, list) else [str(e), 1.0] for e in role.get("pool", [])]


def subset(map_key: str, role_name: str, pool: list, k: int) -> list:
    scored = sorted((score(f"{map_key}|{role_name}|{vid}", w), vid) for vid, w in pool)
    return [vid for _, vid in scored[:k]]


def rank_for(map_id: str, role_name: str, variants: list, cell) -> list:
    x, y = int(cell[0]), int(cell[1])
    return [v for _, v in sorted((score(f"{map_id}|{role_name}|{v}|{x},{y}", 1.0), v) for v in variants)]


def radius_for(role) -> int:
    if isinstance(role, dict):
        if str(role.get("pick", "cell")) == "door":
            return 0
        if bool(role.get("module", False)):
            return 1
    return 2


def _apply(row: dict, role_name: str, role, variant: str) -> None:
    row["sprite"] = variant
    row["sprite_role"] = role_name
    if isinstance(role, dict) and "light" in role and "light" not in row:
        row["light"] = json.loads(json.dumps(role["light"]))


def _resolve_materials(out: dict, map_id: str, region: str, kits: dict, errors: list) -> None:
    targets = [(f"floor_layers[{i}]", r) for i, r in enumerate(out.get("floor_layers") or [])]
    walls = out.get("walls")
    if isinstance(walls, dict):
        targets.append(("walls", walls))
        targets += [(f"walls.segments[{i}]", s) for i, s in enumerate(walls.get("segments") or [])]
    for label, row in targets:
        if not isinstance(row, dict) or "material" not in row:
            continue
        ref = str(row["material"])
        if not ref.startswith("@"):
            errors.append(f"maps/{map_id}: {label} material '{ref}' must be an @reference")
            continue
        mat = lookup(kits, region, "materials", ref[1:])
        if not isinstance(mat, dict):
            errors.append(f"maps/{map_id}: {label} material '{ref}' does not resolve (region {region}, _common)")
            continue
        for key in MATERIAL_FIELDS:
            if key in mat and key not in row:
                row[key] = json.loads(json.dumps(mat[key]))
        del row["material"]
        row["material_ref"] = ref[1:]


def resolve_map(map: dict, map_id: str, region: str, kits: dict, errors: list | None = None) -> dict:
    collected: list = [] if errors is None else errors
    out = json.loads(json.dumps(map))
    _resolve_materials(out, map_id, region, kits, collected)
    by_role: dict = {}
    for layer in ("decor", "entities"):
        for i, row in enumerate(out.get(layer) or []):
            if not isinstance(row, dict):
                continue
            spr = str(row.get("sprite", ""))
            if not spr.startswith("@"):
                continue
            cell = row.get("cell")
            if not isinstance(cell, list) or len(cell) < 2:
                collected.append(f"maps/{map_id}: {layer}[{i}] sprite '{spr}' has no cell")
                continue
            by_role.setdefault(spr[1:], []).append({"layer": layer, "index": i, "row": row,
                                                    "cell": (int(cell[0]), int(cell[1]))})
    for role_name, placements in by_role.items():
        role = lookup(kits, region, "roles", role_name)
        if role is None:
            for p in placements:
                collected.append(f"maps/{map_id}: {p['layer']}[{p['index']}] sprite '@{role_name}' does not resolve (region {region}, _common)")
            continue
        if not pool_of(role):
            for p in placements:
                collected.append(f"maps/{map_id}: {p['layer']}[{p['index']}] role '{role_name}' has an empty pool")
            continue
        placements.sort(key=lambda p: (p["cell"][1], p["cell"][0], p["layer"], p["index"]))
        _resolve_role(placements, role_name, role, map_id, collected)
    if errors is None and collected:
        raise KitResolveError("; ".join(collected))
    return out


def _resolve_role(placements: list, role_name: str, role, map_id: str, errors: list) -> None:
    pool = pool_of(role)
    pick = str(role.get("pick", "cell")) if isinstance(role, dict) else "fixed"
    if pick == "door":
        for p in placements:
            row = p["row"]
            if str(row.get("kind", "")) != "door" or "to_map" not in row:
                errors.append(f"maps/{map_id}: {p['layer']}[{p['index']}] '@{role_name}' is a door pick on a row that is not a door with to_map")
                continue
            to_map = str(row["to_map"])
            pair = f"{min(map_id, to_map)}<>{max(map_id, to_map)}"
            _apply(row, role_name, role, subset(pair, role_name, pool, 1)[0])
        return
    sub = subset(map_id, role_name, pool, subset_size(len(placements), len(pool)))
    if pick in ("map", "fixed"):
        for p in placements:
            _apply(p["row"], role_name, role, sub[0])
        return
    r = radius_for(role)
    chosen: list = []
    for p in placements:
        cx, cy = p["cell"]
        rank = rank_for(map_id, role_name, sub, p["cell"])
        taken = {v for (ox, oy), v in chosen if max(abs(ox - cx), abs(oy - cy)) <= r}
        variant = next((v for v in rank if v not in taken), rank[0])
        chosen.append(((cx, cy), variant))
        _apply(p["row"], role_name, role, variant)


def rows_of(resolved: dict) -> list:
    out = []
    for layer in ("decor", "entities"):
        for row in resolved.get(layer) or []:
            if isinstance(row, dict) and "sprite_role" in row:
                out.append({"layer": layer, "cell": [int(row["cell"][0]), int(row["cell"][1])],
                            "sprite_role": row["sprite_role"], "sprite": row["sprite"]})
    return out


def resolve_tree(maps_dir: Path, kits: dict) -> dict:
    result: dict = {}
    for path in sorted(Path(maps_dir).glob("*/*.json")):
        doc = json.loads(path.read_text())
        result[path.stem] = rows_of(resolve_map(doc, path.stem, map_kit(doc, path), kits))
    return result


def resolve_all(game_root: Path, kits: dict | None = None) -> dict:
    game_root = Path(game_root)
    return resolve_tree(game_root / "data" / "maps", load_kits(game_root) if kits is None else kits)


def canon_names(repo_root: Path) -> set:
    """Canon character names: character-profiles.md '## ' headings (parenthetical
    stripped; non-person headings excluded) as full name and first word, plus any
    npc whose sprite id equals its lowercased first name."""
    names: set = set()
    profile = Path(repo_root) / "docs" / "design" / "character-profiles.md"
    for line in profile.read_text().splitlines():
        if not line.startswith("## "):
            continue
        name = line[3:].split("(")[0].split(":")[0].strip().rstrip(",")
        if not name or name in NON_PERSON_HEADINGS or not _HEADING_NAME.match(name):
            continue
        names.add(name)
        if name.split(" ")[0] not in GENERIC_FIRST_WORDS:
            names.add(name.split(" ")[0])
    for path in sorted((Path(repo_root) / "wandering_inn_game" / "data" / "maps").glob("*/*.json")):
        for e in json.loads(path.read_text()).get("entities") or []:
            dn = str(e.get("display_name", ""))
            if e.get("kind") == "npc" and dn and str(e.get("sprite", "")) == dn.split(" ")[0].lower():
                names.add(dn)
                names.add(dn.split(" ")[0])
    return names


if __name__ == "__main__":
    import argparse, sys
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--maps", type=Path, help="maps root (default data/maps)")
    ap.add_argument("--kits", type=Path, help="kits.json (default data/kits.json)")
    ap.add_argument("--out", type=Path, help="write the resolution JSON here (stdout otherwise)")
    a = ap.parse_args()
    game = Path(__file__).resolve().parent.parent
    kits = json.loads(a.kits.read_text()) if a.kits else load_kits(game)
    result = resolve_tree(a.maps or game / "data" / "maps", kits)
    text = json.dumps(result, indent=1, sort_keys=True) + "\n"
    (a.out.write_text(text) if a.out else sys.stdout.write(text))
