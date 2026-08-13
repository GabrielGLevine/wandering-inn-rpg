from __future__ import annotations

from copy import deepcopy
from typing import Any, Iterable


PANEL_SETTLE_FRAMES = 30
# combat_walkthrough/crate_fight/second_wind_loop all let the board finish
# tearing down before reading post-fight state; the banking itself is
# synchronous and earlier, so this is settle, not a race workaround.
COMBAT_SETTLE_FRAMES = 5
# `turn_started {id: pc}` and `combat_finished` are the two waits that span a
# whole AI playback, so they carry the corpus's longer ceilings rather than the
# 5s default every other wait uses.
TURN_TIMEOUT_SEC = 10
COMBAT_TIMEOUT_SEC = 20


class EmitError(RuntimeError):
    pass


class Emitter:
    def emit(self, node_id: str, operations: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
        emitted: list[dict[str, Any]] = []
        for operation in operations:
            steps = self._emit_operation(operation)
            # An op may name its OWN provenance -- detour nodes are planned
            # inside the node that needed them, but a failure in one must map
            # back to the detour, not to the purchase that pulled it in.
            stamp = str(operation.get("itin") or node_id)
            for step in steps:
                step["_itin"] = stamp
            if operation.get("note") and steps:
                steps[0]["_comment"] = str(operation["note"])
            emitted.extend(steps)
        return emitted

    def _emit_operation(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        steps: list[dict[str, Any]] = []
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
            elif operation.get("destination") and not operation.get("defer_destination"):
                steps.append(self._destination_wait(operation.get("next_node", {})))
        elif kind == "dialogue_node_wait":
            # The deferred half of a `dialogue_choose`: used when engine
            # events (a purchase's gold/toast/item chain) land BETWEEN the
            # confirm and the destination node.
            steps.append(self._destination_wait(operation.get("next_node", {})))
        elif kind == "sleep":
            steps.extend(self._sleep_steps(operation))
        elif kind == "fixture_prelude":
            steps.extend(self._fixture_prelude_steps(operation))
        elif kind == "fight":
            steps.extend(self._fight_steps(operation))
        elif kind == "shot":
            steps.append({"action": "screenshot", "name": str(operation["name"])})
        elif kind == "assert_state":
            steps.append(self._assert_state_step(operation))
        elif kind == "assert_event":
            steps.append(self._event_assert_step("assert_event_logged", operation))
        elif kind == "assert_event_absent":
            steps.append(self._event_assert_step("assert_event_absent", operation))
        elif kind == "inventory_open":
            steps.extend([
                {"action": "press", "name": "inventory"},
                {"action": "wait_for_event", "type": "ui_inventory_shown", "timeout_sec": 5},
            ])
        elif kind == "inventory_cursor":
            cursor = int(operation["cursor_index"])
            if cursor:
                steps.append({"action": "move", "direction": "down", "steps": cursor})
            steps.append({
                "action": "wait_for_event", "type": "ui_inventory_selection_rendered",
                "payload_contains": {"cursor": cursor, "item": str(operation["item"])}, "timeout_sec": 5,
            })
        elif kind == "inventory_equip":
            steps.extend([
                {"action": "press", "name": "confirm"},
                {"action": "wait_for_event", "type": "item_equipped", "payload_contains": {"item": str(operation["item"]), "slot": str(operation["slot"])}, "timeout_sec": 5},
                {"action": "assert_state", "path": f"equipped.{operation['slot']}", "equals": str(operation["item"])},
            ])
        elif kind == "inventory_unequip":
            # ITEM_UNEQUIPPED carries only {slot} -- no item id -- so the
            # state assert is what proves WHICH slot cleared.
            steps.extend([
                {"action": "press", "name": "confirm"},
                {"action": "wait_for_event", "type": "item_unequipped", "payload_contains": {"slot": str(operation["slot"])}, "timeout_sec": 5},
                {"action": "assert_state", "path": f"equipped.{operation['slot']}", "equals": ""},
            ])
        elif kind == "inventory_close":
            steps.extend([
                {"action": "press", "name": "inventory"},
                {"action": "wait_for_event", "type": "ui_inventory_hidden", "timeout_sec": 5},
            ])
        elif kind == "field_skill":
            steps.extend(self._field_skill_steps(operation))
        elif kind == "prop_interact":
            steps.extend(self._prop_interact_steps(operation))
        elif kind == "purchase":
            steps.extend(self._purchase_steps(operation))
        elif kind == "sell_open":
            steps.extend([
                {"action": "wait_for_event", "type": "dialogue_started", "payload_contains": {"conversation": str(operation["conversation"]), "entity": str(operation["entity"])}, "timeout_sec": 5},
                {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5},
                {"action": "wait_for_event", "type": "ui_dialogue_shown", "timeout_sec": 5},
            ])
        elif kind == "sale":
            steps.extend(self._sale_steps(operation))
        elif kind == "raw":
            steps.extend(deepcopy(operation["steps"]))
        else:
            raise EmitError(f"unknown semantic operation: {kind}")
        return steps

    # ------------------------------------------------------------ M2 shapes --

    def _fixture_prelude_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        """Drive the title to CONTINUE so the seeded fixture is what loads.

        This is UI-cursor knowledge, not world knowledge, so it lives here as a
        fixed prelude (§8's ruling for the creation choreography, same class).
        It is required, not optional: the driver's own `_skip_title` presses
        confirm twice and starts a NEW GAME, which would discard the fixture
        entirely and run the itinerary against a blank sim.
        """
        return [
            {"action": "wait_for_event", "type": "ui_title_gate_rendered", "timeout_sec": 5},
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_title_rendered", "timeout_sec": 5},
            {"action": "move", "direction": "down", "steps": 1},
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "game_loaded", "timeout_sec": 5},
            {"action": "wait_for_event", "type": "world_ready", "timeout_sec": 5},
            {"action": "assert_state", "path": "current_map", "equals": str(operation["map"])},
            {"action": "assert_state", "path": "player_cell", "equals": list(operation["cell"])},
        ]

    def _fight_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        steps: list[dict[str, Any]] = []
        if operation.get("entry", "interact") == "interact":
            steps.append({"action": "press", "name": "interact"})
        steps.extend([
            {"action": "wait_for_event", "type": "combat_started", "timeout_sec": 5},
            {"action": "wait_for_event", "type": "ui_combat_shown", "timeout_sec": 5},
        ])
        for ally in operation.get("allies", []):
            steps.append({"action": "assert_state", "path": f"combat.combatants.{ally}.side", "equals": "player"})
        steps.append({"action": "wait_for_event", "type": "turn_started", "payload_contains": {"id": "pc"}, "timeout_sec": TURN_TIMEOUT_SEC})
        for name in operation.get("shots", []):
            steps.append({"action": "screenshot", "name": str(name)})
        steps.extend([
            {"action": "combat_autoplay", "max_turns": int(operation["max_turns"]), "policy": str(operation["policy"])},
            {"action": "wait_for_event", "type": "combat_finished", "payload_contains": {"victory": True}, "timeout_sec": COMBAT_TIMEOUT_SEC},
            # The result banner eats the next press until it is dismissed.
            {"action": "press", "name": "confirm"},
            {"action": "wait_for_event", "type": "ui_combat_hidden", "timeout_sec": 5},
            {"action": "wait_frames", "frames": COMBAT_SETTLE_FRAMES},
        ])
        # on_victory counters bank SYNCHRONOUSLY inside resolve_combat, before
        # ui_combat_hidden -- so they are read as STATE here. A wait_for_event
        # would be searching past the since-cursor for an event already gone.
        for pin in operation.get("victory_pins", []):
            steps.append(self._assert_state_step(pin))
        return steps

    def _field_skill_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        payload: dict[str, Any] = {"skill": str(operation["skill"])}
        if operation.get("target"):
            payload["target"] = str(operation["target"])
        else:
            payload["context"] = "exploration"
        steps: list[dict[str, Any]] = [
            # press_field_skill resolves the hotbar slot from the live bar --
            # never hand-press hotbar_N, the index is equipment-dependent.
            {"action": "press_field_skill", "skill": str(operation["skill"])},
            {"action": "wait_for_event", "type": "skill_used", "payload_contains": payload, "timeout_sec": 5},
        ]
        if operation.get("accomplishment"):
            steps.append({"action": "wait_for_event", "type": "accomplishment_recorded", "payload_contains": {"id": str(operation["accomplishment"])}, "timeout_sec": 5})
        steps.append({"action": "wait_for_event", "type": "ui_toast_rendered", "timeout_sec": 5})
        return steps

    def _prop_interact_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        steps: list[dict[str, Any]] = [{"action": "press", "name": "interact"}]
        if operation.get("accomplishment"):
            steps.append({"action": "wait_for_event", "type": "accomplishment_recorded", "payload_contains": {"id": str(operation["accomplishment"]), "count": int(operation["count"])}, "timeout_sec": 5})
        if operation.get("toast"):
            steps.append({"action": "wait_for_event", "type": "toast", "payload_contains": {"text": str(operation["toast"])}, "timeout_sec": 5})
        steps.append({"action": "wait_for_event", "type": "ui_toast_rendered", "timeout_sec": 5})
        return steps

    def _purchase_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        # Emission order is the engine's, not a preference: spend_gold emits
        # gold_changed BEFORE the "Paid N gold." toast, and the item grant
        # lands after both.
        gold_payload: dict[str, Any] = {"delta": -int(operation["price"]), "source": str(operation["conversation"])}
        if operation.get("total") is not None:
            gold_payload["total"] = int(operation["total"])
        return [
            {"action": "wait_for_event", "type": "gold_changed", "payload_contains": gold_payload, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "toast", "payload_contains": {"text": f"Paid {int(operation['price'])} gold."}, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "item_gained", "payload_contains": {"item": str(operation["item"])}, "timeout_sec": 5},
        ]

    def _sale_steps(self, operation: dict[str, Any]) -> list[dict[str, Any]]:
        # sell_item removes the item FIRST (item_lost), then pays (gold_changed
        # + "Earned N gold."), then banks deliberate_commerce.
        gold_payload: dict[str, Any] = {"delta": int(operation["price"]), "source": str(operation["conversation"])}
        if operation.get("total") is not None:
            gold_payload["total"] = int(operation["total"])
        return [
            {"action": "wait_for_event", "type": "item_lost", "payload_contains": {"item": str(operation["item"]), "source": str(operation["conversation"])}, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "gold_changed", "payload_contains": gold_payload, "timeout_sec": 5},
            {"action": "wait_for_event", "type": "toast", "payload_contains": {"text": f"Earned {int(operation['price'])} gold."}, "timeout_sec": 5},
        ]

    @staticmethod
    def _destination_wait(next_node: dict[str, Any]) -> dict[str, Any]:
        payload = {key: value for key, value in next_node.items() if value != ""}
        wait: dict[str, Any] = {"action": "wait_for_event", "type": "dialogue_node", "timeout_sec": 5}
        if payload:
            wait["payload_contains"] = payload
        return wait

    @staticmethod
    def _assert_state_step(operation: dict[str, Any]) -> dict[str, Any]:
        step: dict[str, Any] = {"action": "assert_state", "path": str(operation["path"])}
        if "contains" in operation:
            step["contains"] = deepcopy(operation["contains"])
        elif "equals" in operation:
            step["equals"] = deepcopy(operation["equals"])
        else:
            raise EmitError(f"assert_state on {operation['path']!r} needs equals or contains")
        return step

    @staticmethod
    def _event_assert_step(action: str, operation: dict[str, Any]) -> dict[str, Any]:
        step: dict[str, Any] = {"action": action, "type": str(operation["type"])}
        payload = operation.get("payload_contains") or {}
        if payload:
            step["payload_contains"] = deepcopy(payload)
        return step

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
