"""Pass 2: replace projections with what the run actually did (§5).

Pass 1 is honest about its ignorance -- it widens gold into an interval when
a drop is chance-gated, and it refuses to pin a challenge-weighted counter at
all, queueing a `pins_pending` row instead. Pass 2 is where that ignorance is
paid off from a recorded run rather than guessed at.

The refinement runs INTERLEAVED with planning, not as a patch over emitted
JSON. That is not a style preference: collapsing the gold interval at node N
changes what the economy planner decides at node N+1 (an earn-detour it no
longer needs) and what the oracle is asked at every node after it (queries are
asked under the materialized save, whose gold the interval floor sets). A
post-hoc patcher could tighten the pins and would still ship the detour.

What refine may do:
  * collapse a projected gold interval to the harvested actual;
  * pin a challenge-weighted counter to its harvested value, resolving the
    `pins_pending` row that pass 1 queued;
  * fill a `total` that pass 1 dropped because the interval was open;
  * report a detour the run proved unnecessary, and any place the ledger's
    own projection disagreed with reality.

What refine may NOT do: loosen a pin, invent one the ledger cannot see, or
silently delete a detour. §2.4 governs the last one -- removing a node moves
every rng draw after it, so a detour removal is an ITINERARY edit whose
recompile is re-verified wholesale, never a quiet rewrite of one output.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .harvest import Harvest, NodeHarvest
from .ledger import CHALLENGE_WEIGHTED, Ledger
from .schema import Node


class RefineError(RuntimeError):
    pass


@dataclass
class Resolution:
    """One challenge-weighted counter, paid off from the run."""

    node: str
    counter: str
    encounter: str
    harvested: int
    pinned: bool
    queued: bool = True

    def describe(self) -> str:
        if not self.queued:
            return (
                f"{self.node}: {self.counter} moved to {self.harvested} here and pass 1 queued NO pins_pending "
                "row for it -- the deposit came from a quest resolution-path grant, not a fight "
                "(combat_banking.grant, GH#211 §5), which the ledger does not model. Pinned from the harvest; "
                "the modelling gap is real and belongs to the dialogue planner."
            )
        if self.pinned:
            return (
                f"{self.node}: {self.counter} harvested at {self.harvested} after {self.encounter} "
                f"-- pinned (pass 1 refused to guess it)"
            )
        return (
            f"{self.node}: {self.counter} banked no whole unit at {self.encounter} (fractional deposit still "
            f"under 1); resolved as UNPINNED -- assert_state on an unbanked counter reds on `path not found`, "
            "so the honest pin is no pin"
        )


@dataclass
class RefineReport:
    resolutions: list[Resolution] = field(default_factory=list)
    tightened: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    @property
    def resolved_count(self) -> int:
        return len(self.resolutions)

    @property
    def pinned_count(self) -> int:
        return sum(1 for row in self.resolutions if row.pinned)


class Refiner:
    """Applies a recorded run's actuals to the ledger and the planned ops."""

    def __init__(self, harvest: Harvest) -> None:
        self.harvest = harvest
        self.report = RefineReport()

    # ------------------------------------------------------------- per node --

    def after_node(self, node: Node, ledger: Ledger, ops: list[dict[str, Any]], pending_before: int) -> None:
        reading = self.harvest.get(node.id)
        if reading is None:
            raise RefineError(
                f"the recorded run has no reading for node {node.id!r}. A harvest that is missing nodes is a "
                "STALE harvest -- the itinerary changed since the probe run, and §2.4's rule is that an edit "
                "invalidates every pin after it. Recompile with --probe, re-run, and refine from the new log."
            )
        self._apply_gold(node, ledger, reading)
        self._resolve_pending(node, ledger, ops, reading, pending_before)
        self._fill_totals(node, ops, reading)
        self._compare_projection(node, ledger, reading)

    # ------------------------------------------------------------------ gold --

    def _apply_gold(self, node: Node, ledger: Ledger, reading: NodeHarvest) -> None:
        """Set the ledger's gold to the harvested truth -- WITHOUT re-deciding.

        The ledger carries two gold numbers and pass 2 touches only one of
        them. `state["gold"]` is what the materialized save holds, so it is
        what every downstream oracle query is asked under: replacing a
        conservative floor with the run's actual number makes those answers
        truer, and changes nothing about the shape of the script.

        `gold_interval` is the DECISION variable -- the economy planner splices
        an earn-detour when its floor cannot cover a price -- and pass 2
        deliberately leaves it projected. Collapsing it would let pass 2 drop a
        detour pass 1 inserted, and a pass that removes a node is a pass that
        invalidates its own evidence: every rng draw behind that node moves
        (§2.4), so the harvest it is refining from describes a run that no
        longer exists. The unnecessary detour is FLAGGED instead
        (`review_detours`), which is what §2.3 asks for, and removing it is an
        itinerary edit whose recompile gets re-verified wholesale.

        Bracketing is still checked: a projection that fails to contain the
        actual is a planner bug, and the honest fix is a wider projection, not
        a refine that quietly papers over it.
        """
        low, high = ledger.gold_interval
        actual = reading.gold
        if not low <= actual <= high:
            raise RefineError(
                f"{node.id}: the run ended this node holding {actual} gold, outside the ledger's projected "
                f"interval [{low}, {high}]. That is a PLANNER bug, not a loose pin -- the interval is supposed "
                "to bound every outcome, so widen the projection rather than refining around it."
            )
        if low != high and ledger.state.get("gold") != actual:
            self.report.tightened.append(
                f"{node.id}: gold read as {actual} (pass 1 carried the interval floor {low} of [{low}, {high}])"
            )
        ledger.state["gold"] = actual

    # -------------------------------------------------------- pending counters --

    def _resolve_pending(
        self, node: Node, ledger: Ledger, ops: list[dict[str, Any]], reading: NodeHarvest, pending_before: int
    ) -> None:
        """Pin every challenge-weighted counter that MOVED during this node.

        Pass 1 queues a `pins_pending` row from `apply_victory`, which is the
        only place it can see one of these deposits coming. That turned out
        not to be the only place they happen: a quest's resolution path can
        grant one too (`WICombatBanking.grant`, GH#211 §5), and the crate
        report in Act II banks `won_combat` at Krshia's counter with no fight
        anywhere near it. So the harvest -- not the queue -- decides what gets
        pinned, and an unqueued move is reported as the modelling gap it is.
        """
        fresh = {str(row["counter"]): row for row in ledger.pins_pending[pending_before:]}
        previous = self.harvest.before(node.id)
        fight = next((op for op in reversed(ops) if str(op.get("kind", "")) == "fight"), None)
        for counter in sorted(set(CHALLENGE_WEIGHTED) | set(fresh)):
            actual = reading.accomplishment(counter)
            was = previous.accomplishment(counter) if previous is not None else 0
            row = fresh.get(counter)
            if actual == was and row is None:
                continue
            if row is not None:
                row["harvested"] = actual
                row["resolved_at"] = node.id
            if actual:
                # The harvest is the truth for a counter the ledger refused to
                # model, so it replaces the ledger's silence rather than
                # sitting beside it -- later nodes read this value.
                ledger.state["accomplishments"][counter] = actual
            pin = {"path": f"accomplishments.{counter}", "equals": actual}
            pinned = actual > 0 and actual != was
            if pinned and fight is not None:
                fight.setdefault("victory_pins", []).append(pin)
            elif pinned:
                # No fight in this node: the deposit came from somewhere else,
                # so the pin is a plain state assert at the node's end.
                ops.append({"kind": "assert_state", **pin})
            self.report.resolutions.append(
                Resolution(
                    node.id,
                    counter,
                    str(row.get("encounter", "")) if row is not None else "",
                    actual,
                    pinned,
                    queued=row is not None,
                )
            )

    # ----------------------------------------------------------------- totals --

    def _fill_totals(self, node: Node, ops: list[dict[str, Any]], reading: NodeHarvest) -> None:
        """Give a purchase/sale back the `total` pass 1 dropped.

        Read off the node's own `gold_changed` event rather than off the
        node-boundary snapshot: a node may move money more than once, and the
        pin belongs to the transaction, not to where the node happened to end.
        """
        changes = reading.events_of("gold_changed")
        for op in ops:
            kind = str(op.get("kind", ""))
            if kind not in ("purchase", "sale") or op.get("total") is not None:
                continue
            delta = -int(op["price"]) if kind == "purchase" else int(op["price"])
            source = str(op["conversation"])
            matches = [
                event for event in changes
                if int((event.get("payload") or {}).get("delta", 0)) == delta
                and str((event.get("payload") or {}).get("source", "")) == source
            ]
            if len(matches) != 1:
                self.report.notes.append(
                    f"{node.id}: {kind} of {op['item']} matched {len(matches)} gold_changed events "
                    f"(delta {delta}, source {source!r}) -- `total` left unpinned rather than guessed"
                )
                continue
            total = (matches[0].get("payload") or {}).get("total")
            if total is None:
                continue
            op["total"] = int(total)
            self.report.tightened.append(
                f"{node.id}: {kind} total pinned to {int(total)} (pass 1 dropped it -- the interval was open)"
            )

    # ------------------------------------------------------------ divergence --

    def _compare_projection(self, node: Node, ledger: Ledger, reading: NodeHarvest) -> None:
        """Report where the ledger's own model and the run disagree.

        Only keys the LEDGER carries are compared: a real run banks dozens of
        action-tally counters (`melee_hit`, `spell_cast`) that §2.5 puts
        deliberately outside the model, and reporting those as divergences
        would bury the one that matters under noise.
        """
        actual = reading.accomplishments
        for key, projected in sorted(ledger.state["accomplishments"].items()):
            if key not in actual:
                self.report.notes.append(
                    f"{node.id}: ledger projects accomplishments.{key}={projected}, the run banked none"
                )
            elif int(actual[key]) != int(projected):
                self.report.notes.append(
                    f"{node.id}: ledger projects accomplishments.{key}={projected}, the run holds {actual[key]}"
                )

    # ------------------------------------------------------------- detours --

    def review_detours(self, insertions: list[dict[str, Any]]) -> None:
        """Flag an earn-detour the run proved unnecessary (§2.3).

        Flagged, never removed. A detour is a node, and removing a node moves
        every rng draw behind it (§2.4) -- so the removal is an edit to the
        YAML whose recompile is re-verified wholesale, not something pass 2
        gets to do to one output behind the author's back.
        """
        for insertion in insertions:
            node_id = str(insertion["node"])
            before = self.harvest.before(node_id)
            if before is None:
                continue
            asking = int(insertion["asking"])
            if before.gold >= asking:
                self.report.notes.append(
                    f"DETOUR/UNNECESSARY: {node_id} asked {asking} and the run arrived holding {before.gold} "
                    f"before detour {insertion['detour']!r} ran. Pass 1 inserted it because the projected floor "
                    f"was {insertion['floor']}. Remove it from the itinerary if you want it gone -- doing that "
                    "moves every rng draw after it, so the recompile is re-verified wholesale (§2.4)."
                )
