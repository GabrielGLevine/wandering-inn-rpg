#!/usr/bin/env python3
"""wi_data_lib.py -- the ONE shared pure-Python mirror of the game's data
composition (GH#281, dev-arch wave phase 0). Before this module, the
scene-compose contract lived hand-synced in three copies
(generate_shipped_ids.py, generate_postings.py, derive_qa_surfaces.py);
each new offline tool grew a fourth. Import from here instead.

Contract (mirrors src/core/scene_catalog.gd's WISceneCatalog.compose(),
issue #100 split layout -- the GDScript loader is canonical, this is the
read-only offline mirror):
  - composed scene = data/scene_root.json (start_map + player template)
    with a "maps" dict layered in from the sorted data/maps/*/*.json glob
  - map key = file STEM; the region directory level is organizational only
  - duplicate stem anywhere across regions = ValueError, never last-wins

Determinism: the sorted() glob is part of the contract (byte-identical
outputs for generators that serialize composition order).
"""
from __future__ import annotations

import json
from pathlib import Path

GAME_ROOT = Path(__file__).resolve().parent.parent
DATA = GAME_ROOT / "data"
MAPS_DIR = DATA / "maps"
DIALOGUE_DIR = DATA / "dialogue"


def load_json(path: Path) -> dict:
    return json.loads(Path(path).read_text())


def load_scene() -> dict:
    """Composed scene catalog: scene_root + all region maps (contract above)."""
    root = load_json(DATA / "scene_root.json")
    root["maps"] = load_maps()
    return root


def load_maps() -> dict:
    """The composed "maps" dict alone (stem-keyed, dup = ValueError)."""
    maps: dict = {}
    for map_path in sorted(MAPS_DIR.glob("*/*.json")):
        map_id = map_path.stem
        if map_id in maps:
            raise ValueError(f"duplicate map key '{map_id}' ({map_path})")
        maps[map_id] = load_json(map_path)
    return maps


def known_maps() -> set:
    """Map keys only, without parsing map bodies -- same dup check."""
    maps: set = set()
    for map_path in sorted(MAPS_DIR.glob("*/*.json")):
        map_id = map_path.stem
        if map_id in maps:
            raise ValueError(f"duplicate map key '{map_id}' ({map_path})")
        maps.add(map_id)
    return maps


def load_shared_dialogue_banks() -> dict:
    """The cross-conversation line bank (data/dialogue/_shared_lines.json)."""
    p = DIALOGUE_DIR / "_shared_lines.json"
    return load_json(p).get("banks", {}) if p.exists() else {}


def expand_dialogue_graph(graph: dict, shared: dict) -> dict:
    """Resolve "@<name>" refs in text / text_variants / options[].text.
    File-local text_banks win over the shared bank; an unresolvable ref
    raises -- a silently shipped "@foo" string is a content bug."""
    local = graph.get("text_banks", {})
    def rep(t):
        if isinstance(t, str) and t.startswith("@"):
            name = t[1:]
            if name in local:
                return local[name]
            if name in shared:
                return shared[name]
            raise KeyError(f"dialogue ref '@{name}' does not resolve")
        return t
    for node in graph.get("nodes", {}).values():
        if not isinstance(node, dict):
            continue
        if "text" in node:
            node["text"] = rep(node.get("text"))
        tv = node.get("text_variants")
        if isinstance(tv, list):
            for i, v in enumerate(tv):
                tv[i] = rep(v) if isinstance(v, str) else v
        for o in node.get("options", []) or []:
            if isinstance(o, dict) and "text" in o:
                o["text"] = rep(o.get("text"))
    return graph


def load_dialogue_graphs() -> dict:
    """Every data/dialogue/*.json graph, stem-keyed, with "@" line refs
    EXPANDED (underscore-prefixed files are banks/config, never graphs)."""
    shared = load_shared_dialogue_banks()
    graphs: dict = {}
    for path in sorted(DIALOGUE_DIR.glob("*.json")):
        if path.stem.startswith("_"):
            continue
        graphs[path.stem] = expand_dialogue_graph(load_json(path), shared)
    return graphs
