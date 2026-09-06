from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..ledger import Ledger
from ..quests import QuestJoin
from .route import DIRECTION_VECTORS, RoutePlanner


class DialogueError(RuntimeError):
    pass


def _is_purchase_row(option: dict[str, Any]) -> bool:
    """Mirror of `WIDialogue.purchase_offer`'s classification (#504)."""
    req_gold = (option.get("requires") or {}).get("gold")
    if not isinstance(req_gold, (int, float)):
        return False
    if str(option.get("spend", "purchase")) != "purchase":
        return False
    return any(
        isinstance(effect.get("gold"), (int, float)) and int(effect["gold"]) == -int(req_gold)
        for effect in option.get("effects", []) or []
    )


class DialoguePlanner:
    def __init__(self, project: str | Path, bridge: Any, route: RoutePlanner) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.route = route
        self.quests = QuestJoin(self.project)
        self.graphs = {
            path.stem: json.loads(path.read_text(encoding="utf-8"))
            for path in sorted((self.project / "data/dialogue").glob("*.json"))
        }

    # ------------------------------------------------ effect-derived waits --

    def apply_option_effects(
        self, ledger: Ledger, effects: list[dict[str, Any]], conversation: str
    ) -> list[dict[str, Any]]:
        """Move the ledger AND say what the game will announce while it does.

        The 2026-08-13 M3.6 amendment (item 2). The planner already read this
        array to move the ledger -- trust tier 1, exact, data-derived (§2.1) --
        and simply dropped the announcements, so every one of them was a shipped
        claim the compiler could make and did not.

        Mirrors `WIGame.dialogue_choose`'s effect loop verbatim, INCLUDING its
        elif chain: an effect mapping is matched on its first recognised key and
        no other branch runs. What it deliberately does NOT claim is toasts.
        The amendment enumerates the derivable shapes as
        accomplishment/quest_started/beat/completed/item_gained, and a toast is
        a presentation echo of an event already pinned -- `pickup` emits one,
        `earn`/`spend` emit one, `start_quest` emits one, and the corpus waits
        on them at some sites and not others. The purchase, sale and prop
        idioms pin the toasts that carry authored COPY, which is the class
        where the text is the claim.
        """
        waits: list[dict[str, Any]] = []
        for effect in effects:
            if "accomplishment" in effect:
                waits.extend(self.quests.record(ledger, str(effect["accomplishment"])))
            elif "quest" in effect:
                waits.extend(self.quests.start(ledger, str(effect["quest"])))
            elif "remove_entity" in effect:
                entity = str(effect["remove_entity"])
                if entity not in ledger.state["removed_entities"]:
                    ledger.state["removed_entities"].append(entity)
                    waits.append({"type": "entity_removed", "payload_contains": {"id": entity}})
            elif "dormant_entity" in effect:
                entity = str(effect["dormant_entity"])
                if entity not in ledger.state["dormant_encounters"]:
                    ledger.state["dormant_encounters"].append(entity)
            elif "item" in effect:
                item = str(effect["item"])
                # `pickup` no-ops on a duplicate and emits nothing, so a plan
                # that claimed the grant twice would hang on the second.
                if item not in ledger.state["inventory"]:
                    ledger.state["inventory"].append(item)
                    waits.append({
                        "type": "item_gained",
                        "payload_contains": {"item": item, "source": conversation},
                    })
            elif "gold" in effect:
                amount = int(effect["gold"])
                ledger.shift_gold(amount)
                if amount:
                    waits.append({
                        "type": "gold_changed",
                        "payload_contains": {"delta": amount, "source": conversation},
                    })
            elif "bank_first_use" in effect:
                ledger.state["entity_first_use"][str(effect["bank_first_use"])] = True
            elif "remove_item" in effect:
                item = str(effect["remove_item"])
                # A dialogue swap implies consent (GH#142): the engine unequips
                # first, so the worn-gear refusal in `remove_item` cannot fire.
                for slot, worn in list(ledger.state["equipped"].items()):
                    if str(worn) == item:
                        ledger.state["equipped"][slot] = ""
                if item in ledger.state["inventory"]:
                    ledger.state["inventory"].remove(item)
                    waits.append({
                        "type": "item_lost",
                        "payload_contains": {"item": item, "source": conversation},
                    })
        return waits

    def plan(
        self,
        node_id: str,
        spec: dict[str, Any],
        why: str,
        ledger: Ledger,
        entity: dict[str, Any] | None = None,
        map_id: str | None = None,
        start_combat: str = "",
    ) -> list[dict[str, Any]]:
        npc_id = str(spec["npc"])
        if entity is None:
            map_id, entity = self.route.find_entity(npc_id, str(spec.get("at", "")) or None)
        elif map_id is None:
            # A caller that hands over an entity without saying WHERE it
            # stands is asserting the ledger is already on its map. That held
            # for M1, whose every talk followed a goto; it stops holding the
            # moment a planner routes on the author's behalf, so the map now
            # travels with the entity.
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
            effects = list(option.get("effects", []))
            hands_off = any("start_combat" in effect for effect in effects)
            if hands_off and start_combat == "":
                raise DialogueError(
                    f"{node_id}: row {anchor!r} in {graph_id}:{current} carries start_combat "
                    f"({[e['start_combat'] for e in effects if 'start_combat' in e]}). A talk cannot take it -- the "
                    "board opens on this confirm and eats every step the talk would emit after it. Plan the beat as "
                    "fight: {entry: dialogue}."
                )
            effect_waits = self.apply_option_effects(ledger, effects, graph_id)
            next_node: dict[str, Any] = {}
            if destination and not hands_off:
                next_answer = self.bridge.query(f"visible_options {graph_id} {destination}", ledger)
                next_node = {"speaker": next_answer.get("speaker", ""), "text": next_answer.get("text", "")}
            ops.append({
                "kind": "dialogue_choose",
                "cursor_index": int(row["cursor_index"]),
                "destination": destination,
                "end": ended,
                "next_node": next_node,
                "why": why,
                "effect_waits": effect_waits,
                # `entry: dialogue`'s row: the combat board replaces the panel,
                # so the emitter emits neither the teardown pair nor the
                # destination wait -- both would be claims about a conversation
                # that has stopped being the thing on screen.
                "hands_off_to_combat": hands_off,
                # Planner-only bookkeeping (the emitter ignores it): the
                # economy planner has to know WHICH row in a choose_path was
                # the one that moved money, because the money events land
                # between that row's confirm and its destination node -- not
                # after the row that closes the conversation.
                "gold_delta": sum(int(e["gold"]) for e in option.get("effects", []) if "gold" in e),
                "grants": [str(e["item"]) for e in option.get("effects", []) if "item" in e],
                # #504: the priced idiom (requires.gold N + effects gold -N)
                # without a narrative `spend` tag opens the confirmation
                # modal; the emitter owes the offer/arm/confirm idiom BEFORE
                # any effect wait. Mirrors WIDialogue.purchase_offer.
                "purchase": _is_purchase_row(option),
            })
            if hands_off:
                combat_row = str(next(e["start_combat"] for e in effects if "start_combat" in e))
                if combat_row != start_combat:
                    raise DialogueError(
                        f"{node_id}: choose_path reached a row that starts {combat_row!r}, not {start_combat!r}"
                    )
                # The board is the panel now. Nothing after this row belongs to
                # the conversation, and the fight planner owns what follows.
                return ops
            if ended:
                current = ""
                break
            if not destination:
                raise DialogueError(f"choice {anchor!r} neither ends nor names a destination")
            current = destination
        if start_combat:
            raise DialogueError(
                f"{node_id}: choose_path never reached a row whose effects start {start_combat!r} -- "
                "the last anchor of a fight: {entry: dialogue} must BE that row"
            )
        if current:
            # Walking away from an OPEN panel is a hang, not a shortcut: the
            # next `press` is consumed by the conversation's own cursor. Every
            # destination node in the corpus carries a closing row, so this is
            # a missing anchor rather than an impossible ask.
            closing = self._closing_anchors(graph_id, current, ledger)
            raise DialogueError(
                f"{node_id}: choose_path leaves {graph_id}:{current} OPEN. Add a closing anchor; "
                f"rows that end the conversation here: {closing}"
            )
        return ops

    def _closing_anchors(self, graph_id: str, node_id: str, ledger: Ledger) -> list[str]:
        try:
            answer = self.bridge.query(f"visible_options {graph_id} {node_id}", ledger)
        except Exception:  # noqa: BLE001 -- advice only; the real error is above
            return []
        return [str(row.get("text", "")) for row in answer.get("options", []) if row.get("end")]
