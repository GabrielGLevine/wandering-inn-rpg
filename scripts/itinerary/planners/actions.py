from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..ledger import Ledger
from .route import RoutePlanner


ACCESSORY_SLOTS = ("accessory_1", "accessory_2", "accessory_3")


class ActionError(RuntimeError):
    pass


class ActionPlanner:
    """The small primitives: equip/unequip, field-skill casts, prop interacts.

    Each one is a cursor or a keypress whose correctness depends on live sim
    state -- which inventory row an item sits on, which hotbar slot a Skill
    landed in, whether a prop's gate is open. All three questions go to the
    oracle or to map data; none are recomputed here.
    """

    def __init__(self, project: str | Path, bridge: Any, route: RoutePlanner) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.route = route
        catalog = json.loads((self.project / "data/items.json").read_text(encoding="utf-8"))
        self.items = {str(row["id"]): row for row in catalog["items"]}

    # ------------------------------------------------------------ equipment --

    def plan_equip(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        item_id = str(spec["item"])
        row = self._inventory_row(node_id, ledger, item_id)
        slot = self._target_slot(node_id, item_id, ledger)
        if ledger.state["equipped"].get(slot, "") == item_id:
            raise ActionError(f"{node_id}: {item_id} is already worn in {slot} -- confirm would UNEQUIP it")
        ledger.equip(slot, item_id)
        return [
            {"kind": "inventory_open"},
            {"kind": "inventory_cursor", "cursor_index": int(row["cursor_index"]), "item": item_id},
            {"kind": "inventory_equip", "item": item_id, "slot": slot},
            {"kind": "inventory_close"},
        ]

    def plan_unequip(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        slot = str(spec["slot"])
        item_id = str(ledger.state["equipped"].get(slot, ""))
        if not item_id:
            raise ActionError(f"{node_id}: nothing is worn in {slot}")
        row = self._inventory_row(node_id, ledger, item_id)
        ledger.unequip(slot)
        return [
            {"kind": "inventory_open"},
            {"kind": "inventory_cursor", "cursor_index": int(row["cursor_index"]), "item": item_id},
            # Confirm on an ALREADY-equipped row is the engine's own
            # toggle-to-unequip grammar, not a second equip call.
            {"kind": "inventory_unequip", "slot": slot},
            {"kind": "inventory_close"},
        ]

    def _target_slot(self, node_id: str, item_id: str, ledger: Ledger) -> str:
        """Which slot `equip()` would put this item in.

        The slot is the item's `kind` -- the catalog carries no `slot` field
        (the oracle's inventory rows report it empty for exactly that reason).
        Accessories take the first FREE accessory slot, which is the engine's
        own scan order.

        NOT modelled: the resonance-capacity refusal. An accessory equip that
        would exceed capacity is refused at runtime with a toast, and this
        compiler does not predict it -- that is a pass-2 harvest, and until
        then a capacity-blocked accessory node reds its run honestly rather
        than compiling a wrong pin.
        """
        record = self.items.get(item_id)
        if record is None:
            raise ActionError(f"{node_id}: {item_id} is not in the item catalog")
        kind = str(record.get("kind", ""))
        if kind in ("weapon", "armor"):
            return kind
        if kind != "accessory":
            raise ActionError(f"{node_id}: {item_id} is a {kind!r} -- equip() only takes weapon/armor/accessory")
        for slot in ACCESSORY_SLOTS:
            if not str(ledger.state["equipped"].get(slot, "")):
                return slot
        raise ActionError(f"{node_id}: every accessory slot is full, so equipping {item_id} would be refused")

    def _inventory_row(self, node_id: str, ledger: Ledger, item_id: str) -> dict[str, Any]:
        # Insertion order IS the picker's cursor order, and the ledger's own
        # inventory list is only a mirror of it -- ask the game.
        answer = self.bridge.query("inventory", ledger)
        rows = [row for row in answer.get("items", []) if str(row.get("id", "")) == item_id]
        if len(rows) != 1:
            carried = [str(row.get("id", "")) for row in answer.get("items", [])]
            raise ActionError(f"{node_id}: {item_id} matched {len(rows)} inventory rows; carried: {carried}")
        return rows[0]

    # ---------------------------------------------------------- field skills --

    def plan_use_field(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        skill_id = str(spec["skill"])
        answer = self.bridge.query("field_bar", ledger)
        slots = [slot for slot in answer.get("slots", []) if str(slot.get("skill", "")) == skill_id]
        if not slots:
            bar = [str(slot.get("skill", "")) for slot in answer.get("slots", [])]
            raise ActionError(f"{node_id}: {skill_id} is not on the field bar; bar is {bar}")
        if not bool(slots[0].get("number_key_reachable", False)):
            raise ActionError(f"{node_id}: {skill_id} sits in slot {slots[0].get('slot')} -- past the 9 number keys")

        # A field skill aimed at a prop needs that prop faced first; the target
        # and its banked counter both come from the prop's own `on_skill_use`.
        target_id = ""
        accomplishment = ""
        entity = self._faced_prop(ledger)
        if entity is not None and str(entity.get("requires_skill", "")) == skill_id:
            target_id = str(entity.get("id", ""))
            on_use = entity.get("on_skill_use", {})
            accomplishment = str(on_use.get("accomplishment", ""))
            if accomplishment:
                ledger.accomplishment(accomplishment)
            if "gold" in on_use:
                ledger.shift_gold(int(on_use["gold"]))
        if skill_id not in self.state_skills(ledger):
            ledger.state["used_skills"].append(skill_id)
        return [{"kind": "field_skill", "skill": skill_id, "target": target_id, "accomplishment": accomplishment}]

    @staticmethod
    def state_skills(ledger: Ledger) -> list[str]:
        return [str(skill) for skill in ledger.state.get("used_skills", [])]

    # ----------------------------------------------------------------- props --

    def plan_interact(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        prop_id = str(spec["prop"])
        map_hint = str(spec.get("at", "")) or None
        map_id, entity = self.route.find_entity(prop_id, map_hint)
        # Every refusal is decided BEFORE any routing: a node that cannot work
        # should say so without spending oracle queries walking to it.
        if entity.get("requires_skill"):
            raise ActionError(
                f"{node_id}: {prop_id} is skill-gated ({entity['requires_skill']}); interact only HINTS at it. "
                "Use a use_field node."
            )
        if entity.get("door_when") and self._door_open(entity, ledger):
            raise ActionError(f"{node_id}: {prop_id}'s door gate is open -- door_when short-circuits the interact bank. Use goto.")
        accomplishment = str(entity.get("on_interact_accomplishment", ""))
        expected = str(spec.get("expect_accomplishment", ""))
        if expected and expected != accomplishment:
            raise ActionError(f"{node_id}: expected {expected!r} but {prop_id} banks {accomplishment!r}")
        if not accomplishment:
            raise ActionError(f"{node_id}: {prop_id} banks no accomplishment -- nothing to pin")
        ops = self.route.plan_to(node_id, ledger, map_id, [int(part) for part in entity["cell"]])
        ledger.accomplishment(accomplishment)
        ops.append({
            "kind": "prop_interact",
            "accomplishment": accomplishment,
            "count": int(ledger.state["accomplishments"][accomplishment]),
            "toast": str(entity.get("toast", "")),
        })
        return ops

    @staticmethod
    def _door_open(entity: dict[str, Any], ledger: Ledger) -> bool:
        requirements = entity.get("door_when", {}).get("requires", {})
        accomplishments = ledger.state["accomplishments"]
        return all(int(accomplishments.get(key, 0)) >= int(amount) for key, amount in requirements.items())

    def _faced_prop(self, ledger: Ledger) -> dict[str, Any] | None:
        facing = ledger.facing
        target = [ledger.cell[0] + facing[0], ledger.cell[1] + facing[1]]
        for entity in self.route.maps[ledger.map_id].get("entities", []):
            if [int(part) for part in entity.get("cell", [])] == target:
                return entity
        return None
