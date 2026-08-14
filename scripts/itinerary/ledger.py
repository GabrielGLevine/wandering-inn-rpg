from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field
from typing import Any, Iterable


SAVE_VERSION = 9

# Counters whose deposit is CHALLENGE-WEIGHTED, so their banked value is not a
# count of anything a compiler can derive: a gray-band win deposits a fraction
# (and may bank nothing at all until a whole unit accumulates), while a
# low-power player beating a real fight banks at the adversity cap. The ledger
# refuses to guess them and the emitter refuses to pin them -- `victories`,
# which banks an integer under both flag states, is the counter that answers
# "a win happened". Each skipped bank leaves a pins_pending row for pass 2.
CHALLENGE_WEIGHTED = {"won_combat"}


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
    # Compiler-only bookkeeping, not sim state. `WISave.serialize` does NOT
    # carry `sneaking` (it is runtime-only -- `sleep()` clears it and a load
    # starts uncloaked), so a materialized save cannot tell the oracle about a
    # live stance and the ledger has to carry the lifetime itself (#440,
    # 2026-08-13 M3.6 amendment item 4). The QA state dump DOES expose it,
    # which is why `assert_state sneaking` is a legal pin even though no save
    # round-trips the flag.
    sneaking: bool = False
    # `WIGame._quest_progress`: quest id -> {beat_index, completed}. The beat
    # and completion events are edge-triggered off this table, so deriving them
    # needs the previous reading and not just the counters (see quests.py).
    quest_progress: dict[str, dict[str, Any]] = field(default_factory=dict)

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

    # ---------------------------------------------------------------- sneak --

    def start_sneak(self) -> None:
        self.sneaking = True

    def break_sneak(self) -> bool:
        """`WIGame._break_sneak`: idempotent, and it says whether it fired.

        The return value is the whole reason this is a method rather than an
        assignment: the un-cloak emits `sneak_ended` ONLY when a stance was
        live, so an emitter that pinned the event unconditionally would claim
        an event the engine never sent.
        """
        was = self.sneaking
        self.sneaking = False
        return was

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
                self.shift_gold(int(effect["gold"]))
            elif "bank_first_use" in effect:
                self.state["entity_first_use"][str(effect["bank_first_use"])] = True

    # ------------------------------------------------------------- economy --

    def shift_gold(self, amount: int) -> None:
        """An EXACT, data-derived gold move: both interval ends shift together."""
        lo, hi = self.gold_interval
        self.gold_interval = (lo + amount, hi + amount)
        self.state["gold"] = int(self.state.get("gold", 0)) + amount

    def widen_gold(self, low: int, high: int) -> None:
        """A PROJECTED gold move (a chance-gated loot drop): the ends part.

        `gold` in the materialized save follows the LOW end, so every oracle
        answer downstream of a widened interval is asked under the poorest
        world the run could be in -- a gold-gated dialogue row that resolves
        visible under `min` is visible under every outcome.
        """
        lo, hi = self.gold_interval
        self.gold_interval = (lo + low, hi + high)
        self.state["gold"] = self.gold_interval[0]

    @property
    def gold_min(self) -> int:
        return self.gold_interval[0]

    @property
    def gold_certain(self) -> bool:
        return self.gold_interval[0] == self.gold_interval[1]

    # -------------------------------------------------------- inventory/gear --

    def equip(self, slot: str, item_id: str) -> None:
        self.state["equipped"][slot] = item_id

    def unequip(self, slot: str) -> None:
        self.state["equipped"][slot] = ""

    # ---------------------------------------------------------------- combat --

    def apply_victory(
        self, entity: dict[str, Any], loot_gold: tuple[int, int], quests: Any = None
    ) -> list[dict[str, Any]]:
        """Project a won fight onto the ledger (§2.2 trust tier 2).

        `victories` banks integer under both challenge-weighting flag states,
        which is why it -- not `won_combat`, whose deposit is fractional in a
        gray-band fight -- is what a compiled pin may assert.

        Returns the BANK WAITS in `WICombatBanking.resolve`'s own order, for
        the `expect_banks_after_dismiss` frame (M3.6 amendment item 3): the
        deposits run inside `resolve_combat()`, which fires on the banner
        dismiss, so they land between that confirm and `ui_combat_hidden`.
        `victories` is deliberately absent from the returned list -- the
        emitter already pins it as STATE after the teardown, and one claim per
        fact is the rule that keeps a golden diff readable.
        """
        self.accomplishment("victories")
        waits: list[dict[str, Any]] = []
        for raw_banked in entity.get("on_victory", []):
            banked = str(raw_banked)
            if banked in CHALLENGE_WEIGHTED:
                self.pins_pending.append({
                    "counter": banked,
                    "encounter": str(entity.get("id", "")),
                    "reason": "challenge-weighted deposit -- harvest the actual from a run (pass 2)",
                })
                continue
            if quests is None:
                self.accomplishment(banked)
            else:
                waits.extend(quests.record(self, banked))
        entity_id = str(entity.get("id", ""))
        if bool(entity.get("respawns", False)):
            if entity_id not in self.state["dormant_encounters"]:
                self.state["dormant_encounters"].append(entity_id)
        elif not bool(entity.get("persistent", False)):
            if entity_id not in self.state["removed_entities"]:
                self.state["removed_entities"].append(entity_id)
                waits.append({"type": "entity_removed", "payload_contains": {"id": entity_id}})
        # `start_combat` reads the stance and then breaks it (wi_game.gd:2410).
        # A plan that thought the cloak survived a fight would route its next
        # leg through a trigger radius it is no longer invisible to.
        self.break_sneak()
        if loot_gold != (0, 0):
            self.widen_gold(*loot_gold)
        # Combat CONSTRUCTION draws from the one global stream, so every fight
        # is an epoch boundary: any itinerary edit before it invalidates the
        # pins after it. Loot does NOT count -- `WIEconomy.roll_loot` seeds a
        # private RandomNumberGenerator from hash("<run_seed>:<entity_id>")
        # and never touches the world stream (src/core/economy.gd:47-53).
        self.rng_epoch += 1
        return waits

    def apply_sleep_preview(self, preview: dict[str, Any]) -> None:
        self.state["times_slept"] = int(self.state.get("times_slept", 0)) + 1
        self.accomplishment("slept")
        self.state["social_talked"] = {}
        self.state["dormant_encounters"] = []
        self.state["actions_since_sleep"] = 0
        # `sleep()` drops the cloak (wi_game.gd: `sneaking = false`), so a plan
        # that walks a radius after a night has to re-cast rather than inherit.
        self.sneaking = False
        # #472: consolidation is AUTOMATIC and resolves INSIDE the sleep beat, so
        # the oracle's `classes_after` ALREADY carries the merge (parents retired,
        # target at its merged level). Assigning it is the whole of the ledger's
        # consolidation handling -- there is no pending state to mirror any more,
        # and no caller may re-apply the merge on top of this.
        self.state["classes"] = deepcopy(preview["classes_after"])
        self.state["generalist_classes"] = deepcopy(preview.get("generalist_classes_after", self.state["generalist_classes"]))

    def materialize_save(self) -> dict[str, Any]:
        state = _fresh_state()
        state.update(deepcopy(self.state))
        state["gold"] = int(self.state.get("gold", self.gold_interval[0]))
        state["rng_state"] = str(state["rng_state"])
        return {"version": SAVE_VERSION, "state": state}

