from __future__ import annotations

import json
from collections import deque
from pathlib import Path
from typing import Any

from ..ledger import Ledger


DIRECTION_VECTORS = {"up": [0, -1], "down": [0, 1], "left": [-1, 0], "right": [1, 0]}


class RouteError(RuntimeError):
    pass


class RoutePlanner:
    def __init__(self, project: str | Path, bridge: Any) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.maps = self._load_maps()
        portals_data = json.loads((self.project / "data/portals.json").read_text(encoding="utf-8"))
        self.portals = {str(row["id"]): row for row in portals_data.get("portals", [])}

    def _load_maps(self) -> dict[str, dict[str, Any]]:
        maps: dict[str, dict[str, Any]] = {}
        for path in sorted((self.project / "data/maps").glob("*/*.json")):
            data = json.loads(path.read_text(encoding="utf-8"))
            map_id = str(data.get("id", path.stem))
            maps[map_id] = data
        return maps

    def find_entity(self, entity_id: str, map_id: str | None = None) -> tuple[str, dict[str, Any]]:
        candidates: list[tuple[str, dict[str, Any]]] = []
        for candidate_map, data in self.maps.items():
            if map_id is not None and candidate_map != map_id:
                continue
            for entity in data.get("entities", []):
                if str(entity.get("id", "")) == entity_id:
                    candidates.append((candidate_map, entity))
        if len(candidates) != 1:
            raise RouteError(f"entity {entity_id!r} resolved to {len(candidates)} maps")
        return candidates[0]

    def plan_to(self, node_id: str, ledger: Ledger, map_id: str, cell: list[int] | None = None) -> list[dict[str, Any]]:
        if map_id not in self.maps:
            raise RouteError(f"unknown destination map: {map_id}")
        ops: list[dict[str, Any]] = []
        if ledger.map_id != map_id:
            for edge in self._transition_path(ledger, map_id):
                transition = edge["entity"]
                ops.extend(self._walk(ledger, transition["cell"]))
                destination = [int(part) for part in edge["to_cell"]]
                if edge["kind"] == "portal":
                    ops.append({"kind": "portal_transition", "entity": transition["id"], "menu_index": edge["menu_index"], "map": edge["to_map"], "cell": destination})
                else:
                    ops.append({"kind": "transition", "map": edge["to_map"], "cell": destination})
                ledger.set_position(str(edge["to_map"]), destination)
                if transition.get("on_enter_accomplishment"):
                    ledger.accomplishment(str(transition["on_enter_accomplishment"]))
        if cell is not None:
            ops.extend(self._walk(ledger, [int(part) for part in cell]))
        return ops

    def _transition_path(self, ledger: Ledger, goal: str) -> list[dict[str, Any]]:
        start = ledger.map_id
        frontier = deque([start])
        prior: dict[str, tuple[str, dict[str, Any]] | None] = {start: None}
        while frontier:
            current = frontier.popleft()
            if current == goal:
                break
            for edge in self._edges(current, ledger):
                to_map = str(edge["to_map"])
                if to_map not in self.maps or to_map in prior:
                    continue
                prior[to_map] = (current, edge)
                frontier.append(to_map)
        if goal not in prior:
            raise RouteError(f"no static door/travel-prop route from {start} to {goal}")
        path: list[dict[str, Any]] = []
        current = goal
        while current != start:
            edge = prior[current]
            assert edge is not None
            previous, entity = edge
            path.append(entity)
            current = previous
        path.reverse()
        return path

    def _edges(self, map_id: str, ledger: Ledger) -> list[dict[str, Any]]:
        edges: list[dict[str, Any]] = []
        portal_carrier: dict[str, Any] | None = None
        for entity in self.maps[map_id].get("entities", []):
            if entity.get("to_map"):
                edges.append({"kind": "transition", "entity": entity, "to_map": entity["to_map"], "to_cell": entity["to_cell"]})
            door_when = entity.get("door_when", {})
            if door_when and self._requirements_met(door_when.get("requires", {}), ledger):
                edges.append({"kind": "transition", "entity": entity, "to_map": door_when["to_map"], "to_cell": door_when["to_cell"]})
            portal_when = entity.get("portal_menu_when", {})
            if entity.get("portal_menu") and self._requirements_met(portal_when.get("requires", {}), ledger):
                portal_carrier = entity
        if portal_carrier is None:
            return edges
        probe = Ledger.from_save(ledger.materialize_save())
        probe.set_position(map_id, portal_carrier["cell"])
        answer = self.bridge.query("portal_rows", probe)
        for row in answer.get("rows", []):
            menu_index = row.get("menu_index")
            portal = self.portals.get(str(row.get("id", "")))
            if menu_index is None or portal is None:
                continue
            edges.append({
                "kind": "portal",
                "entity": portal_carrier,
                "menu_index": int(menu_index),
                "to_map": row["map"],
                "to_cell": portal["cell"],
            })
        return edges

    @staticmethod
    def _requirements_met(requirements: dict[str, Any], ledger: Ledger) -> bool:
        accomplishments = ledger.state["accomplishments"]
        return all(int(accomplishments.get(key, 0)) >= int(amount) for key, amount in requirements.items())

    def _walk(self, ledger: Ledger, target: list[int]) -> list[dict[str, Any]]:
        start = ledger.cell
        query = f"path {ledger.map_id} {start[0]},{start[1]} {target[0]},{target[1]}"
        answer = self.bridge.query(query, ledger)
        if not answer.get("reachable"):
            raise RouteError(f"oracle found no route: {query}: {answer}")
        ops: list[dict[str, Any]] = []
        if answer.get("target_blocked"):
            approach = answer.get("approach")
            if not isinstance(approach, dict):
                raise RouteError(f"target has no interact approach: {query}: {answer}")
            driver_steps = list(approach.get("driver_steps", []))
            if driver_steps:
                ops.append({"kind": "walk", "steps": driver_steps})
            stand = [int(part) for part in approach["cell"]]
            ledger.set_position(ledger.map_id, stand)
            bump = str(approach["bump"])
            ledger.face(bump)
            ops.append({"kind": "face_target", "direction": bump})
        else:
            driver_steps = list(answer.get("driver_steps", []))
            if driver_steps:
                ops.append({"kind": "walk", "steps": driver_steps})
            ledger.set_position(ledger.map_id, target)
            for step in reversed(driver_steps):
                direction = str(step.get("direction", ""))
                if step.get("action") == "move" and direction in DIRECTION_VECTORS:
                    ledger.face(direction)
                    break
        return ops
