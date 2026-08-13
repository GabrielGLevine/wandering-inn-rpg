from __future__ import annotations

from pathlib import Path
from typing import Any

from ..ledger import CHALLENGE_WEIGHTED, Ledger
from .route import RoutePlanner


DEFAULT_MAX_TURNS = 300
# The 2026-08-12 ruling (§4): every compiled fight runs the competent policy.
# `dumb` stays reachable per-node for instrument-comparison runs only.
DEFAULT_POLICY = "competent"


class CombatError(RuntimeError):
    pass


class CombatPlanner:
    """Plans a `fight` node against a map encounter entity.

    The planner never predicts a fight's COURSE -- rounds, damage, who downs
    whom and in what order are runtime facts (§2.5), and pinning them is the
    documented way to make a script rot. What it does know, from data alone, is
    the fight's ENTRY (where you stand and what you press), its ROSTER gate
    (`ally_requires` against banked accomplishments), and its VICTORY LEDGER
    (`on_victory` counters, entity removal, the loot interval).
    """

    def __init__(self, project: str | Path, bridge: Any, route: RoutePlanner) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.route = route

    def plan(self, node_id: str, spec: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        encounter_id = str(spec["encounter"])
        map_hint = str(spec.get("at", "")) or None
        map_id, entity = self.route.find_entity(encounter_id, map_hint)
        if str(entity.get("kind", "")) != "encounter":
            raise CombatError(f"{node_id}: {encounter_id} is a {entity.get('kind')!r}, not an encounter")
        if encounter_id in ledger.state["removed_entities"]:
            raise CombatError(f"{node_id}: {encounter_id} was already removed earlier in this itinerary")
        if encounter_id in ledger.state["dormant_encounters"]:
            raise CombatError(f"{node_id}: {encounter_id} is dormant and will not start a fight")

        entry = str(spec.get("entry", "interact"))
        if entry == "proximity":
            ops: list[dict[str, Any]] = []
            if ledger.map_id != map_id:
                ops.extend(self.route.plan_to(node_id, ledger, map_id))
            walk_ops, direction = self.route.plan_trigger_walk(node_id, ledger, entity)
            ops.extend(walk_ops)
            # The step that springs it. Emitted as a plain move because that is
            # all it is -- no interact, no confirm; the board opens by itself.
            ops.append({"kind": "face_target", "direction": direction})
            return self._finish(node_id, spec, ledger, entity, ops, entry)

        ops = self.route.plan_to(node_id, ledger, map_id, [int(part) for part in entity["cell"]])
        if entry == "interact" and (not ops or ops[-1]["kind"] != "face_target"):
            # The approach must end in a bump that faces the encounter. If the
            # oracle walked us ONTO the cell instead, the entity is not a
            # blocker and this fight triggers on proximity mid-walk -- which
            # would fire combat inside the emitted walk steps.
            raise CombatError(
                f"{node_id}: approach to {encounter_id} did not end facing it "
                f"(entry: interact needs a blocked target); last op {ops[-1]['kind'] if ops else 'none'}"
            )

        return self._finish(node_id, spec, ledger, entity, ops, entry)

    def _finish(
        self,
        node_id: str,
        spec: dict[str, Any],
        ledger: Ledger,
        entity: dict[str, Any],
        ops: list[dict[str, Any]],
        entry: str,
    ) -> list[dict[str, Any]]:
        allies = self._fielded_allies(entity, ledger)
        shots = [str(name) for name in spec.get("shots", [])]
        loot = self._loot_interval(entity)
        ledger.apply_victory(entity, loot)
        ops.append({
            "kind": "fight",
            "entry": entry,
            "encounter": str(entity.get("id", "")),
            "allies": allies,
            "shots": shots,
            "policy": str(spec.get("policy", DEFAULT_POLICY)),
            "max_turns": int(spec.get("max_turns", DEFAULT_MAX_TURNS)),
            "victory_pins": self._victory_pins(entity, ledger),
        })
        return ops

    @staticmethod
    def _fielded_allies(entity: dict[str, Any], ledger: Ledger) -> list[str]:
        """One gate for the whole list: any unmet requirement empties it."""
        requirements = entity.get("ally_requires", {})
        accomplishments = ledger.state["accomplishments"]
        met = all(int(accomplishments.get(key, 0)) >= int(amount) for key, amount in requirements.items())
        return [str(ally) for ally in entity.get("allies", [])] if met else []

    @staticmethod
    def _loot_interval(entity: dict[str, Any]) -> tuple[int, int]:
        """Gold loot as an interval: a chance-gated drop parts the ends (§2.3).

        The amounts come from the entity's own `loot` table; whether a given
        roll lands is a runtime fact this compiler refuses to predict, so a
        `chance: 0.5` row contributes [0, gold] and only a certain drop
        contributes an exact amount.
        """
        low = high = 0
        for drop in entity.get("loot", []):
            if "gold" not in drop:
                continue
            gold = int(drop["gold"])
            high += gold
            if float(drop.get("chance", 0.0)) >= 1.0:
                low += gold
        return (low, high)

    @staticmethod
    def _victory_pins(entity: dict[str, Any], ledger: Ledger) -> list[dict[str, Any]]:
        accomplishments = ledger.state["accomplishments"]
        pins: list[dict[str, Any]] = [
            # `victories` banks an integer under BOTH challenge-weighting flag
            # states; `won_combat` deposits fractionally in a gray-band fight
            # and would silently not be there to assert.
            {"path": "accomplishments.victories", "equals": int(accomplishments["victories"])},
        ]
        for raw_banked in entity.get("on_victory", []):
            banked = str(raw_banked)
            if banked in CHALLENGE_WEIGHTED:
                continue
            pins.append({"path": f"accomplishments.{banked}", "equals": int(accomplishments[banked])})
        entity_id = str(entity.get("id", ""))
        if entity_id in ledger.state["removed_entities"]:
            pins.append({"path": "removed_entities", "contains": entity_id})
        elif entity_id in ledger.state["dormant_encounters"]:
            pins.append({"path": "dormant_encounters", "contains": entity_id})
        return pins
