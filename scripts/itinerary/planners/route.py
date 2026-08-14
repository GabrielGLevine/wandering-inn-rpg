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

    def plan_to(
        self, node_id: str, ledger: Ledger, map_id: str, cell: list[int] | None = None, via: str = ""
    ) -> list[dict[str, Any]]:
        if map_id not in self.maps:
            raise RouteError(f"unknown destination map: {map_id}")
        ops: list[dict[str, Any]] = []
        if ledger.map_id != map_id:
            for edge in self._transition_path(ledger, map_id, via):
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

    def _transition_path(self, ledger: Ledger, goal: str, via: str = "") -> list[dict[str, Any]]:
        """The map-to-map legs, with `via` naming WHICH door takes the last one.

        The router picks a door by search order, and where a map pair has two
        the pick is arbitrary -- both are oracle-valid, both land somewhere on
        the destination, and §6.3 would call the difference a tolerated route.
        It is not tolerable: the two doors ARRIVE on different cells, and the
        arrival is what the next press acts on. GH#375 is the shipped case --
        the west inn door exists to be pinned reachable, and a route that takes
        the main door proves nothing about it.

        `via` therefore constrains the FINAL leg only. Constraining the whole
        search would be a different feature (a waypoint), and naming the door
        you arrive by is the thing the corpus actually needs.
        """
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
        if via:
            path[-1] = self._named_edge(path, goal, via, ledger)
        return path

    def _named_edge(
        self, path: list[dict[str, Any]], goal: str, via: str, ledger: Ledger
    ) -> dict[str, Any]:
        source = path[-1]
        if str(source["entity"].get("id", "")) == via:
            return source
        # The leg's ORIGIN map is where the named door has to stand: substituting
        # a door on some other map would silently re-route the whole path.
        origin = next(
            (map_id for map_id, data in self.maps.items()
             if any(str(e.get("id", "")) == via for e in data.get("entities", []))),
            "",
        )
        candidates = [
            edge for edge in self._edges(origin, ledger)
            if str(edge["entity"].get("id", "")) == via and str(edge["to_map"]) == goal
        ] if origin else []
        if len(candidates) != 1:
            raise RouteError(
                f"goto via {via!r} matched {len(candidates)} legs into {goal} from {origin or '(no map)'}. "
                "`via` names a door/travel-prop on the map the last leg LEAVES, and its gate must be open at "
                "this point in the ledger."
            )
        return candidates[0]

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

    # ------------------------------------------------- proximity encounters --

    def proximity_hazards(self, map_id: str, ledger: Ledger) -> list[dict[str, Any]]:
        """Encounters that spring by being WALKED NEAR, not interacted with.

        `_check_trigger_radius` fires after the move lands, so a route that
        clips one of these starts a fight in the middle of an emitted walk and
        every step after it is eaten by the combat board. The engine measures
        the distance as CHEBYSHEV.

        Phase-gated encounters (`present_when`/`encounter_when`) are skipped:
        the ledger carries no phase, and treating a night-only ambush as
        always-live would refuse legitimate daytime routes. A
        [Wild Affinity]-style radius reduction is likewise unmodelled -- it
        only ever SHRINKS the radius, so ignoring it keeps this check
        conservative in the safe direction.
        """
        if ledger.sneaking:
            # #440's whole point, and M3.6 amendment item 4: a live sneak makes
            # the proximity pass `continue` instead of springing (wi_game.gd
            # 538-547) -- it credits `sneaked_past_danger` and walks on. So a
            # cloaked route may cross a radius the same route would be refused
            # for uncloaked. The stance's LIFETIME is what makes this safe to
            # model: the ledger drops it at a fight, at a non-door interact and
            # at every sleep, so it can never leak past the leg it was cast for.
            return []
        hazards: list[dict[str, Any]] = []
        for entity in self.maps[map_id].get("entities", []):
            if str(entity.get("kind", "")) != "encounter" or "trigger_radius" not in entity:
                continue
            if entity.get("present_when") or entity.get("encounter_when"):
                continue
            entity_id = str(entity.get("id", ""))
            if entity_id in ledger.state["removed_entities"] or entity_id in ledger.state["dormant_encounters"]:
                continue
            if not self._requirements_met(entity.get("gate_when", {}).get("requires", {}), ledger):
                continue
            hazards.append(entity)
        return hazards

    @staticmethod
    def _chebyshev(a: list[int], b: list[int]) -> int:
        return max(abs(int(a[0]) - int(b[0])), abs(int(a[1]) - int(b[1])))

    def _first_trigger(self, cells: list[list[int]], hazards: list[dict[str, Any]]) -> tuple[int, dict[str, Any]] | None:
        # Index 0 is where the player already STANDS. Only a completed move
        # runs the proximity check, so a door that lands you inside a radius is
        # safe until you take a step -- and a step OUT of the radius is safe
        # too, because the check reads the distance after the move.
        for index in range(1, len(cells)):
            for entity in hazards:
                if self._chebyshev(cells[index], [int(p) for p in entity["cell"]]) <= int(entity["trigger_radius"]):
                    return index, entity
        return None

    def plan_trigger_walk(self, node_id: str, ledger: Ledger, entity: dict[str, Any]) -> tuple[list[dict[str, Any]], str]:
        """Walk to the edge of a proximity encounter and hand back the step in.

        Returns the ops that get the player to the last cell OUTSIDE the
        radius, plus the direction of the single move that springs the ambush.
        Splitting the walk here is the whole trick: the emitted steps stop
        before the fight, so nothing is left queued behind the combat board.
        """
        entity_id = str(entity.get("id", ""))
        target = [int(part) for part in entity["cell"]]
        start = ledger.cell
        query = f"path {ledger.map_id} {start[0]},{start[1]} {target[0]},{target[1]}"
        answer = self.bridge.query(query, ledger)
        if not answer.get("reachable"):
            raise RouteError(f"oracle found no route to the ambush: {query}: {answer}")
        cells = [[int(p) for p in cell] for cell in answer.get("cells", [])]
        trigger = self._first_trigger(cells, [entity])
        if trigger is None:
            raise RouteError(
                f"{node_id}: the route to {entity_id} never enters its trigger radius, so entry: proximity "
                "would never spring it"
            )
        index, _ = trigger
        others = [e for e in self.proximity_hazards(ledger.map_id, ledger) if str(e.get("id", "")) != entity_id]
        clipped = self._first_trigger(cells[:index + 1], others)
        if clipped is not None:
            raise RouteError(
                f"{node_id}: the approach to {entity_id} clips {clipped[1]['id']!r} first -- plan that fight before this one"
            )
        stop = cells[index - 1]
        step_in = cells[index]
        delta = (step_in[0] - stop[0], step_in[1] - stop[1])
        direction = next((key for key, vector in DIRECTION_VECTORS.items() if tuple(vector) == delta), "")
        if not direction:
            raise RouteError(f"{node_id}: ambush step {stop} -> {step_in} is not cardinal")
        ops: list[dict[str, Any]] = []
        driver_steps = self.compress(cells[:index])
        if driver_steps:
            ops.append({"kind": "walk", "steps": driver_steps})
        # The trigger move COMPLETES before the proximity check runs, so the
        # player is standing on the in-radius cell when the board opens.
        ledger.set_position(ledger.map_id, step_in, DIRECTION_VECTORS[direction])
        return ops, direction

    @staticmethod
    def compress(cells: list[list[int]]) -> list[dict[str, Any]]:
        """Cell list -> the driver's own run-length `move` steps."""
        steps: list[dict[str, Any]] = []
        for index in range(1, len(cells)):
            delta = (cells[index][0] - cells[index - 1][0], cells[index][1] - cells[index - 1][1])
            name = next((key for key, vector in DIRECTION_VECTORS.items() if tuple(vector) == delta), "")
            if not name:
                continue
            if steps and steps[-1]["direction"] == name:
                steps[-1]["steps"] += 1
            else:
                steps.append({"action": "move", "direction": name, "steps": 1})
        return steps

    def _walk(self, ledger: Ledger, target: list[int], allow_encounter: str | None = None) -> list[dict[str, Any]]:
        start = ledger.cell
        query = f"path {ledger.map_id} {start[0]},{start[1]} {target[0]},{target[1]}"
        answer = self.bridge.query(query, ledger)
        if not answer.get("reachable"):
            raise RouteError(f"oracle found no route: {query}: {answer}")
        hazards = [e for e in self.proximity_hazards(ledger.map_id, ledger) if str(e.get("id", "")) != allow_encounter]
        trigger = self._first_trigger([[int(p) for p in c] for c in answer.get("cells", [])], hazards)
        if trigger is not None:
            index, entity = trigger
            raise RouteError(
                f"route {query} walks within {entity['trigger_radius']} of the proximity encounter "
                f"{entity['id']!r} at {entity['cell']} (path cell {answer['cells'][index]}). That fight would start "
                "mid-walk and eat every step after it. Plan it: add a fight node with entry: proximity before "
                "this leg, or route around it."
            )
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
