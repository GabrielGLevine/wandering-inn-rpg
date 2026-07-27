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


def load_dialogue_graphs() -> dict:
    """Every data/dialogue/*.json graph, stem-keyed."""
    graphs: dict = {}
    for path in sorted(DIALOGUE_DIR.glob("*.json")):
        graphs[path.stem] = load_json(path)
    return graphs
