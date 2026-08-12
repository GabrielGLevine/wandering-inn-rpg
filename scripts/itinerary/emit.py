from __future__ import annotations

from copy import deepcopy
from typing import Any, Iterable


PANEL_SETTLE_FRAMES = 30


class EmitError(RuntimeError):
    pass


class Emitter:
    def emit(self, node_id: str, operations: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
        steps: list[dict[str, Any]] = []
        for operation in operations:
            kind = str(operation.get("kind", ""))
            if kind == "walk":
                steps.extend(deepcopy(operation["steps"]))
            elif kind == "face_target":
                steps.append({"action": "move", "direction": operation["direction"], "steps": 1})
            elif kind == "transition":
                steps.extend([
                    {"action": "press", "name": "interact"},
                    {"action": "wait_for_event", "type": "map_changed", "payload_contains": {"map": operation["map"], "cell": operation["cell"]}, "timeout_sec": 5},
                    {"action": "assert_state", "path": "current_map", "equals": operation["map"]},
                    {"action": "assert_state", "path": "player_cell", "equals": operation["cell"]},
                ])
            elif kind == "portal_transition":
                steps.extend([
                    {"action": "press", "name": "interact"},
                    {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": "portal_menu", "entity": operation["entity"]}, "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "ui_dialogue_shown", "timeout_sec": 5},
                ])
                if int(operation["menu_index"]) > 1:
                    steps.append({"action": "move", "direction": "down", "steps": int(operation["menu_index"]) - 1})
                steps.extend([
                    {"action": "press", "name": "confirm"},
                    {"action": "wait_for_event", "type": "dialogue_ended", "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "map_changed", "payload_contains": {"map": operation["map"], "cell": operation["cell"]}, "timeout_sec": 5},
                    {"action": "assert_state", "path": "current_map", "equals": operation["map"]},
                    {"action": "assert_state", "path": "player_cell", "equals": operation["cell"]},
                ])
            elif kind == "pool_line":
                steps.extend([
                    {"action": "press", "name": "interact"},
                    {"action": "wait_for_event", "type": "dialogue_line", "payload_contains": {"speaker": operation["speaker"]}, "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "ui_dialogue_rendered", "timeout_sec": 5},
                    {"action": "wait_frames", "frames": PANEL_SETTLE_FRAMES},
                ])
            elif kind == "dialogue_open":
                steps.extend([
                    {"action": "press", "name": "interact"},
                    {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": operation["conversation"], "entity": operation["entity"]}, "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5},
                    {"action": "wait_for_event", "type": "ui_dialogue_shown", "timeout_sec": 5},
                ])
            elif kind == "dialogue_choose":
                cursor = int(operation["cursor_index"])
                if cursor:
                    steps.append({"action": "move", "direction": "down", "steps": cursor})
                confirm: dict[str, Any] = {"action": "press", "name": "confirm"}
                if operation.get("why"):
                    confirm["_comment"] = f"CHOICE: {operation['why']}"
                steps.append(confirm)
                if operation.get("end"):
                    steps.extend([
                        {"action": "wait_for_event", "type": "dialogue_ended", "timeout_sec": 5},
                        {"action": "wait_for_event", "type": "ui_dialogue_hidden", "timeout_sec": 5},
                        {"action": "wait_frames", "frames": PANEL_SETTLE_FRAMES},
                    ])
                elif operation.get("destination"):
                    payload = {key: value for key, value in operation.get("next_node", {}).items() if value != ""}
                    wait: dict[str, Any] = {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5}
                    if payload:
                        wait["payload_contains"] = payload
                    steps.append(wait)
            elif kind == "sleep":
                steps.extend(self._sleep_steps(operation))
            else:
                raise EmitError(f"unknown semantic operation: {kind}")
        for step in steps:
            step["_itin"] = node_id
        return steps

    def _sleep_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        preview = operation["preview"]
        steps: list[dict[str, Any]] = [
            {"action": "press", "name": "interact"},
            {"action": "wait_for_event", "type": "phase_changed", "payload_contains": {"slept": True}, "timeout_sec": 5},
        ]
        for class_id in preview.get("class_gains", []):
            steps.append({"action": "wait_for_event", "type": "class_gained", "payload_contains": {"class": class_id}, "timeout_sec": 5})
        for gain in preview.get("level_ups", []):
            steps.append({"action": "wait_for_event", "type": "class_level_up", "payload_contains": {"class": gain["class"], "level": gain["level"]}, "timeout_sec": 5})
        consolidation = preview.get("consolidation", {})
        if consolidation:
            steps.extend([
                {"action": "wait_for_event", "type": "consolidation_offered", "payload_contains": {"target": consolidation["target"], "level": consolidation["level"]}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_sleep_veil_rendered", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_sleep_veil_finished", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_consolidation_prompt_rendered", "payload_contains": {"target": consolidation["target"]}, "timeout_sec": 5},
                {"action": "press", "name": "confirm" if operation["consolidation_choice"] == "accept" else "cancel"},
                {"action": "wait_for_event", "type": "ui_consolidation_prompt_hidden", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "consolidation_accepted" if operation["consolidation_choice"] == "accept" else "consolidation_declined", "timeout_sec": 5},
            ])
        else:
            steps.extend([
                {"action": "wait_for_event", "type": "ui_sleep_veil_rendered", "timeout_sec": 5},
                {"action": "assert_state", "path": "pending_consolidation", "equals": {}},
                {"action": "assert_state", "path": "classes", "equals": preview["classes_after"]},
            ])
        return steps
