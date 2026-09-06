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

    def __init__(self, project: str | Path, bridge: Any, route: RoutePlanner, dialogue: Any = None) -> None:
        self.project = Path(project)
        self.bridge = bridge
        self.route = route
        # `entry: dialogue` walks a conversation, and there is exactly one
        # conversation walker. Sharing it rather than growing a second is what
        # keeps the pool-line rule, the visible-row oracle query and the
        # leaves-a-panel-open refusal in ONE place.
        self.dialogue = dialogue

    def plan(self, node_id: str, spec: dict[str, Any], ledger: Ledger, why: str = "") -> list[dict[str, Any]]:
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
        if entry == "dialogue":
            # The 2026-08-13 M3.6 amendment item 1. The board opens on the
            # conversation's own confirm, so there is no approach to the
            # encounter entity and no press: the walk is to the NPC, and the
            # dialogue planner refuses the whole node unless the chosen path
            # ends on the row whose effects start THIS encounter.
            if self.dialogue is None:
                raise CombatError(f"{node_id}: entry: dialogue needs the dialogue planner wired")
            talk_spec = {
                "npc": str(spec["npc"]),
                "at": str(spec.get("at", "")),
                "choose_path": list(spec.get("choose_path", [])),
            }
            ops = self.dialogue.plan(node_id, talk_spec, why, ledger, start_combat=encounter_id)
            return self._finish(node_id, spec, ledger, entity, ops, entry)
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
        raw_shots = spec.get("shots", [])
        if isinstance(raw_shots, dict):
            approach_shots = [str(name) for name in (raw_shots.get("approach") or [])]
            shots = [str(name) for name in (raw_shots.get("turn") or [])]
        else:
            approach_shots = []
            shots = [str(name) for name in raw_shots]
        loot = self._loot_interval(entity)
        banks_after_dismiss = bool(spec.get("expect_banks_after_dismiss", False))
        quests = getattr(self.dialogue, "quests", None) if banks_after_dismiss else None
        banks = ledger.apply_victory(entity, loot, quests)
        operation: dict[str, Any] = {
            "kind": "fight",
            "entry": entry,
            "encounter": str(entity.get("id", "")),
            "allies": allies,
            "shots": shots,
            "approach_shots": approach_shots,
            "policy": str(spec.get("policy", DEFAULT_POLICY)),
            "max_turns": int(spec.get("max_turns", DEFAULT_MAX_TURNS)),
            "victory_pins": self._victory_pins(entity, ledger),
            # The frame flexibilities (M3.6 amendment item 3). Each says which
            # of the frame's optional rows THIS board has; none of them changes
            # what a fight is.
            "turn_wait": bool(spec.get("turn_wait", True)),
            "beats": {str(slot): [str(name) for name in names] for slot, names in (spec.get("beats") or {}).items()},
            "arena": str(spec.get("arena", "")),
            "banks_after_dismiss": banks,
        }
        # A driven fight is planned EXACTLY like an autoplayed one -- same
        # approach, same roster gate, same victory ledger, same rng epoch. The
        # only thing `driven` changes is who plays the opening turns, which is
        # an emitter concern; the planner carries the list across untouched
        # rather than interpreting it, because interpreting it is how a second
        # copy of the board's rules would grow in Python (§0).
        if str(spec.get("mode", "autoplay")) == "driven":
            operation["mode"] = "driven"
            operation["turns"] = [dict(turn) for turn in spec.get("turns", [])]
        ops.append(operation)
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
