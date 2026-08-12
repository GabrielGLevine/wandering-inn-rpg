from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field
from typing import Any, Iterable


SAVE_VERSION = 8


def _fresh_state() -> dict[str, Any]:
    return {
        "current_map": "inn",
        "player_cell": [2, 3],
        "player_facing": [1, 0],
        "classes": {},
        "accomplishments": {},
        "fractional_bank": {},
        "player_skills": ["basic_cleaning"],
        "removed_entities": [],
        "dormant_encounters": [],
        "generalist_classes": [],
        "started_quests": [],
        "pending_consolidation": {},
        "used_skills": [],
        "seen_statuses": [],
        "lore_notes": [],
        "inventory": ["rusty_sword"],
        "equipped": {"weapon": "rusty_sword", "armor": "", "accessory_1": "", "accessory_2": "", "accessory_3": ""},
        "container_state": {},
        "actions_since_sleep": 0,
        "social_talked": {},
        "entity_first_use": {},
        "gold": 0,
        "resonance_capacity": 2,
        "light_active": False,
        "well_fed": False,
        "pending_meal": {},
        "frozen_cells": {},
        "hotbar_loadout": [],
        "warded_encounters": {},
        "companion": "",
        "companion_source": "",
        "pc_name": "Traveler",
        "pc_race": "human",
        "pc_gender": "m",
        "rng_state": "0",
        "times_slept": 0,
        "accepted_bounty_id": "",
        "accepted_bounty_baseline": {},
        "accepted_bounty_tier": "",
        "board_last_seen_times_slept": 0,
        "accepted_delivery_id": "",
        "accepted_delivery_baseline": {},
        "delivery_failed": False,
        "delivery_last_seen_times_slept": 0,
    }


@dataclass
class Ledger:
    state: dict[str, Any]
    gold_interval: tuple[int, int]
    rng_epoch: int = 0
    pins_pending: list[dict[str, Any]] = field(default_factory=list)

    @classmethod
    def fresh(cls) -> "Ledger":
        state = _fresh_state()
        return cls(state, (0, 0))

    @classmethod
    def from_save(cls, save: dict[str, Any]) -> "Ledger":
        if not isinstance(save.get("state"), dict):
            raise ValueError("save has no state object")
        state = _fresh_state()
        state.update(deepcopy(save["state"]))
        gold = int(state.get("gold", 0))
        return cls(state, (gold, gold))

    @property
    def map_id(self) -> str:
        return str(self.state["current_map"])

    @property
    def cell(self) -> list[int]:
        return list(self.state["player_cell"])

    @property
    def facing(self) -> list[int]:
        return list(self.state["player_facing"])

    def set_position(self, map_id: str, cell: Iterable[int], facing: Iterable[int] | None = None) -> None:
        self.state["current_map"] = map_id
        self.state["player_cell"] = [int(part) for part in cell]
        if facing is not None:
            self.state["player_facing"] = [int(part) for part in facing]

    def face(self, direction: str) -> None:
        self.state["player_facing"] = {
            "up": [0, -1], "down": [0, 1], "left": [-1, 0], "right": [1, 0]
        }[direction]

    def accomplishment(self, key: str, amount: int = 1) -> None:
        accomplishments = self.state["accomplishments"]
        accomplishments[key] = int(accomplishments.get(key, 0)) + amount

    def mark_pool_talk(self, npc_id: str) -> None:
        self.state["social_talked"][npc_id] = True
        self.accomplishment(f"chatted_with_{npc_id}")
        self.accomplishment("heard_gossip")

    def talked_this_waking(self, npc_id: str) -> bool:
        return bool(self.state["social_talked"].get(npc_id, False))

    def apply_effects(self, effects: Iterable[dict[str, Any]]) -> None:
        for effect in effects:
            if "accomplishment" in effect:
                self.accomplishment(str(effect["accomplishment"]))
            elif "quest" in effect:
                quest = str(effect["quest"])
                if quest not in self.state["started_quests"]:
                    self.state["started_quests"].append(quest)
            elif "remove_entity" in effect:
                entity = str(effect["remove_entity"])
                if entity not in self.state["removed_entities"]:
                    self.state["removed_entities"].append(entity)
            elif "dormant_entity" in effect:
                entity = str(effect["dormant_entity"])
                if entity not in self.state["dormant_encounters"]:
                    self.state["dormant_encounters"].append(entity)
            elif "item" in effect:
                item = str(effect["item"])
                if item not in self.state["inventory"]:
                    self.state["inventory"].append(item)
            elif "remove_item" in effect:
                item = str(effect["remove_item"])
                if item in self.state["inventory"]:
                    self.state["inventory"].remove(item)
            elif "gold" in effect:
                amount = int(effect["gold"])
                lo, hi = self.gold_interval
                self.gold_interval = (lo + amount, hi + amount)
                self.state["gold"] = int(self.state.get("gold", 0)) + amount
            elif "bank_first_use" in effect:
                self.state["entity_first_use"][str(effect["bank_first_use"])] = True

    def apply_sleep_preview(self, preview: dict[str, Any]) -> None:
        self.state["times_slept"] = int(self.state.get("times_slept", 0)) + 1
        self.accomplishment("slept")
        self.state["social_talked"] = {}
        self.state["dormant_encounters"] = []
        self.state["actions_since_sleep"] = 0
        self.state["classes"] = deepcopy(preview["classes_after"])
        self.state["generalist_classes"] = deepcopy(preview.get("generalist_classes_after", self.state["generalist_classes"]))
        self.state["pending_consolidation"] = deepcopy(preview.get("consolidation", {}))

    def materialize_save(self) -> dict[str, Any]:
        state = _fresh_state()
        state.update(deepcopy(self.state))
        state["gold"] = int(self.state.get("gold", self.gold_interval[0]))
        state["rng_state"] = str(state["rng_state"])
        return {"version": SAVE_VERSION, "state": state}

