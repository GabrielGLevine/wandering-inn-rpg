"""Pass-2 harvest: what a real run actually did, keyed by itinerary node (§5).

Pass 1 plans against PROJECTIONS -- a fight's victory is assumed, a
chance-gated loot drop parts the gold interval, a challenge-weighted counter
is refused outright and queued as a `pins_pending` row. Those are the three
things a compiler cannot know without playing, and this module is how it
finds out.

The harvest source is a PROBE BUILD: the same itinerary compiled with a
`dump_state {label: <node-id>}` step after every node. That action (GH#436)
emits a `qa_state_dump` domain event carrying the sim's whole snapshot, so
`events.jsonl` from a probe run is a sequence of node-labelled state
readings with the run's ordinary domain events interleaved between them.

Why probes rather than ordinal-aligned domain events: attributing a
`gold_changed` to the node that caused it means counting occurrences and
hoping the count is stable, which is exactly the kind of derived arithmetic
§0 refuses -- and it goes wrong silently the first time an unmodelled toast
or a second vendor row moves the ordinal. A label is not a guess. The probes
exist only in the harvest build; the pass-2 SHIPPED script has none, which
is what the fixed-point test proves.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path
from typing import Any, Iterable


PROBE_ACTION = "dump_state"
PROBE_EVENT = "qa_state_dump"


class HarvestError(RuntimeError):
    pass


@dataclass(frozen=True)
class NodeHarvest:
    """What the sim held when a node finished, and what happened inside it."""

    node: str
    order: int
    snapshot: dict[str, Any]
    events: list[dict[str, Any]] = field(default_factory=list)

    @property
    def gold(self) -> int:
        return int(self.snapshot.get("gold", 0))

    @property
    def accomplishments(self) -> dict[str, int]:
        return {str(key): int(value) for key, value in (self.snapshot.get("accomplishments") or {}).items()}

    def accomplishment(self, key: str) -> int:
        return int(self.accomplishments.get(key, 0))

    def events_of(self, event_type: str) -> list[dict[str, Any]]:
        return [event for event in self.events if str(event.get("type", "")) == event_type]


@dataclass
class Harvest:
    """Per-node actuals from one recorded run, in the order the run took them."""

    nodes: dict[str, NodeHarvest]
    order: list[str]
    source: str = ""

    def __contains__(self, node_id: object) -> bool:
        return str(node_id) in self.nodes

    def get(self, node_id: str) -> NodeHarvest | None:
        return self.nodes.get(node_id)

    def require(self, node_id: str) -> NodeHarvest:
        found = self.nodes.get(node_id)
        if found is None:
            raise HarvestError(
                f"the recorded run has no reading for node {node_id!r}. Harvests come from a PROBE build "
                f"(compile with --probe); a ship-mode run carries no {PROBE_EVENT} events. Known nodes: "
                f"{len(self.nodes)}"
            )
        return found

    def before(self, node_id: str) -> NodeHarvest | None:
        """The reading taken at the node BEFORE this one, if the run has one."""
        try:
            index = self.order.index(node_id)
        except ValueError:
            return None
        return self.nodes[self.order[index - 1]] if index > 0 else None

    @property
    def empty(self) -> bool:
        return not self.nodes


def load_events(path: str | Path) -> list[dict[str, Any]]:
    source = Path(path)
    try:
        text = source.read_text(encoding="utf-8")
    except OSError as exc:
        raise HarvestError(f"could not read event log {source}: {exc}") from exc
    events: list[dict[str, Any]] = []
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        try:
            parsed = json.loads(stripped)
        except json.JSONDecodeError as exc:
            # A run killed mid-write leaves a torn last line. That is a
            # truncated log, not a corrupt one, so it is dropped rather than
            # failing the whole harvest -- but only ever the LAST line.
            if number == len(text.splitlines()):
                break
            raise HarvestError(f"{source}:{number} is not JSON: {exc}") from exc
        if isinstance(parsed, dict):
            events.append(parsed)
    return events


def harvest_from(events: Iterable[dict[str, Any]], source: str = "") -> Harvest:
    """Split a run's event stream into per-node readings at the probe markers.

    Every event since the previous marker belongs to the node the next marker
    names: the probe is emitted AFTER the node's own steps, so the window that
    closes at a marker is exactly that node's run.
    """
    nodes: dict[str, NodeHarvest] = {}
    order: list[str] = []
    window: list[dict[str, Any]] = []
    for event in events:
        if str(event.get("type", "")) != PROBE_EVENT:
            window.append(event)
            continue
        payload = event.get("payload") or {}
        label = str(payload.get("label", ""))
        if not label:
            raise HarvestError(f"a {PROBE_EVENT} event carries no label -- the probe build stamps every one")
        snapshot = payload.get("snapshot")
        if not isinstance(snapshot, dict):
            raise HarvestError(f"{PROBE_EVENT} for {label!r} carries no snapshot")
        if label in nodes:
            raise HarvestError(
                f"node {label!r} was probed twice in one run. Probe labels are node ids and node ids are "
                "unique, so a duplicate means the harvest is reading two runs concatenated."
            )
        nodes[label] = NodeHarvest(node=label, order=len(order), snapshot=dict(snapshot), events=list(window))
        order.append(label)
        window = []
    return Harvest(nodes=nodes, order=order, source=str(source))


def load_harvest(path: str | Path) -> Harvest:
    return harvest_from(load_events(path), source=str(path))
