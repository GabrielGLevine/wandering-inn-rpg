from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Any

import yaml


PRIMITIVES = {
    "goto",
    "talk",
    "fight",
    "sleep",
    "equip",
    "unequip",
    "buy",
    "sell",
    "use_field",
    "interact",
    "shot",
    "assert",
    "detour",
    "raw",
}
MILESTONE_PRIMITIVES = {1: {"goto", "talk", "sleep"}}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")


class SchemaError(ValueError):
    pass


@dataclass(frozen=True)
class Node:
    id: str
    primitive: str
    spec: dict[str, Any]
    why: str
    act: str


@dataclass(frozen=True)
class Itinerary:
    acts: list[dict[str, Any]]
    nodes: list[Node]
    start: str | None = None


def load_itinerary(path: str | Path, milestone: int = 1) -> Itinerary:
    source = Path(path)
    try:
        raw = yaml.safe_load(source.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise SchemaError(f"could not read itinerary {source}: {exc}") from exc
    if not isinstance(raw, list) or not raw:
        raise SchemaError("itinerary root must be a non-empty list of acts")
    allowed = MILESTONE_PRIMITIVES.get(milestone)
    if allowed is None:
        raise SchemaError(f"unknown compiler milestone: {milestone}")

    seen: set[str] = set()
    nodes: list[Node] = []
    start: str | None = None
    for act_index, act in enumerate(raw):
        if not isinstance(act, dict) or not str(act.get("act", "")).strip():
            raise SchemaError(f"act {act_index + 1} needs a non-empty act label")
        if act_index == 0 and act.get("start") is not None:
            start = str(act["start"])
        act_nodes = act.get("nodes")
        if not isinstance(act_nodes, list) or not act_nodes:
            raise SchemaError(f"act {act['act']} needs a non-empty nodes list")
        for node_index, raw_node in enumerate(act_nodes):
            if not isinstance(raw_node, dict):
                raise SchemaError(f"act {act['act']} node {node_index + 1} must be a mapping")
            node_id = str(raw_node.get("id", "")).strip()
            if not ID_RE.fullmatch(node_id):
                raise SchemaError(f"invalid node id: {node_id!r}")
            if node_id in seen:
                raise SchemaError(f"duplicate node id: {node_id}")
            seen.add(node_id)
            present = [key for key in PRIMITIVES if key in raw_node]
            if len(present) != 1:
                raise SchemaError(f"node {node_id} needs exactly one primitive, found {present}")
            primitive = present[0]
            if primitive not in allowed:
                raise SchemaError(f"primitive {primitive!r} is not available in M{milestone} (node {node_id})")
            spec = raw_node[primitive]
            if spec is None:
                spec = {}
            if not isinstance(spec, dict):
                raise SchemaError(f"node {node_id} {primitive} value must be a mapping")
            why = str(raw_node.get("why", spec.get("why", ""))).strip()
            if primitive == "talk" and spec.get("choose_path") and not why:
                raise SchemaError(f"node {node_id} choose_path requires an inline why")
            _validate_primitive(node_id, primitive, spec)
            nodes.append(Node(node_id, primitive, dict(spec), why, str(act["act"])))
    return Itinerary(list(raw), nodes, start)


def _validate_primitive(node_id: str, primitive: str, spec: dict[str, Any]) -> None:
    if primitive == "goto":
        if not str(spec.get("map", "")):
            raise SchemaError(f"node {node_id} goto needs map")
        if "cell" in spec and not _cell(spec["cell"]):
            raise SchemaError(f"node {node_id} goto cell must be [x, y] integers")
    elif primitive == "talk":
        if not str(spec.get("npc", "")):
            raise SchemaError(f"node {node_id} talk needs npc")
        path = spec.get("choose_path", [])
        if not isinstance(path, list) or any(not str(anchor).strip() for anchor in path):
            raise SchemaError(f"node {node_id} choose_path must be a list of labels or option text")
    elif primitive == "sleep":
        if "expect_levels" in spec and not isinstance(spec["expect_levels"], bool):
            raise SchemaError(f"node {node_id} expect_levels must be boolean")
        if spec.get("consolidation") not in (None, "accept", "decline"):
            raise SchemaError(f"node {node_id} consolidation must be accept or decline")


def _cell(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(isinstance(part, int) for part in value)

