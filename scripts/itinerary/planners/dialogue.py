from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..ledger import Ledger
from .route import DIRECTION_VECTORS, RoutePlanner


class DialogueError(RuntimeError):
    pass


class DialoguePlanner:
    def __init__(self, project: str | Path, bridge: Any, route: RoutePlanner) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.route = route
        self.graphs = {
            path.stem: json.loads(path.read_text(encoding="utf-8"))
            for path in sorted((self.project / "data/dialogue").glob("*.json"))
        }

    def plan(self, node_id: str, spec: dict[str, Any], why: str, ledger: Ledger, entity: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        npc_id = str(spec["npc"])
        if entity is None:
            map_id, entity = self.route.find_entity(npc_id, str(spec.get("at", "")) or None)
        else:
            map_id = ledger.map_id
        target = [int(part) for part in entity["cell"]]
        expected_facing = [target[0] - ledger.cell[0], target[1] - ledger.cell[1]]
        adjacent_and_facing = expected_facing in DIRECTION_VECTORS.values() and expected_facing == ledger.facing
        ops: list[dict[str, Any]] = []
        if not adjacent_and_facing:
            ops.extend(self.route.plan_to(node_id, ledger, map_id, target))

        has_pool = bool(entity.get("talk_pool"))
        if has_pool and not ledger.talked_this_waking(npc_id):
            ops.append({"kind": "pool_line", "speaker": str(entity.get("display_name", npc_id))})
            ledger.mark_pool_talk(npc_id)

        anchors = [str(value) for value in spec.get("choose_path", [])]
        if not anchors:
            return ops
        graph_id = str(entity.get("conversation", ""))
        if not graph_id or graph_id not in self.graphs:
            raise DialogueError(f"npc {npc_id} has no file-backed conversation")
        graph = self.graphs[graph_id]
        current = str(graph["start"])
        ops.append({"kind": "dialogue_open", "conversation": graph_id, "entity": npc_id})
        for anchor in anchors:
            answer = self.bridge.query(f"visible_options {graph_id} {current}", ledger)
            options = [row for row in answer.get("options", []) if str(row.get("goto", "")) == anchor or str(row.get("text", "")) == anchor]
            if len(options) != 1:
                options = [row for row in answer.get("options", []) if anchor in str(row.get("text", ""))]
            if len(options) != 1:
                raise DialogueError(f"anchor {anchor!r} matched {len(options)} visible rows in {graph_id}:{current}")
            row = options[0]
            authored_index = int(row.get("authored_index", -1))
            authored = graph["nodes"][current]["options"]
            if authored_index < 0:
                matches = [index for index, option in enumerate(authored) if str(option.get("text", "")) == str(row.get("text", ""))]
                if len(matches) != 1:
                    raise DialogueError(f"cannot map visible row to authored row in {graph_id}:{current}")
                authored_index = matches[0]
            option = authored[authored_index]
            destination = str(option.get("goto", ""))
            ended = bool(option.get("end", False))
            ledger.apply_effects(option.get("effects", []))
            next_node: dict[str, Any] = {}
            if destination:
                next_answer = self.bridge.query(f"visible_options {graph_id} {destination}", ledger)
                next_node = {"speaker": next_answer.get("speaker", ""), "text": next_answer.get("text", "")}
            ops.append({
                "kind": "dialogue_choose",
                "cursor_index": int(row["cursor_index"]),
                "destination": destination,
                "end": ended,
                "next_node": next_node,
                "why": why,
            })
            if ended:
                current = ""
                break
            if not destination:
                raise DialogueError(f"choice {anchor!r} neither ends nor names a destination")
            current = destination
        return ops
