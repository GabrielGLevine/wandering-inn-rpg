"""Map a red run back to the itinerary line that caused it (§5).

A compiled script's failure is reported by the driver in the driver's own
terms: a step index, an action, and a message about an event that never
arrived. That is the wrong altitude for a compiled artifact -- nobody edits
step 1,184 of a generated JSON, and the rule that keeps the corpus
recompilable is precisely that nobody may. The author edits a NODE.

Every emitted step carries an `_itin` stamp (§4) for exactly this. The driver
ignores it; this module reads it. Given the compiled script, the itinerary it
came from, and the driver's `result.json`, it answers each failure as:

    which node, which primitive, which planner owns that primitive, which
    line of which YAML file declared it, and what the node said it was for

The `why` is in the report on purpose. §3.4 makes every fork write down its
reason at authoring time; a failure is the moment that reason is worth most,
because half of these reds are the itinerary asking for something the game
stopped offering, and the `why` is what tells you whether to re-route or to
drop the beat.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Any, Iterable

from .schema import Node


# `_fail` suffixes every driver failure with the state that produced it
# (GH#436), and that state carries the 0-based index of the step that was
# running. It is the only step number a failure line contains, so it is the
# hinge the whole mapping turns on.
STATE_SUFFIX_RE = re.compile(r"\s\|\s+state=(\{.*\})\s*$", re.DOTALL)

# Which planner owns a primitive -- §5's failure loop routes a red to a
# planner category before anyone asks whether it is a knowledge-base gap or an
# itinerary error.
PLANNER_OF = {
    "goto": "route",
    "talk": "dialogue",
    "fight": "combat",
    "sleep": "sleep",
    "buy": "economy",
    "sell": "economy",
    "equip": "actions",
    "unequip": "actions",
    "use_field": "actions",
    "interact": "actions",
    "shot": "emitter",
    "assert": "emitter",
    "detour": "economy",
    "raw": "raw (escape hatch -- no planner owns it)",
}


class ProvenanceError(RuntimeError):
    pass


@dataclass(frozen=True)
class Failure:
    """One driver failure, resolved as far as the evidence allows."""

    message: str
    step_index: int | None
    step: dict[str, Any] | None
    node: Node | None
    total_steps: int

    @property
    def mapped(self) -> bool:
        return self.node is not None

    def render(self) -> str:
        lines: list[str] = []
        where = "step ?" if self.step_index is None else f"step {self.step_index + 1}/{self.total_steps}"
        action = ""
        if self.step:
            action = " ".join(
                f"{key}={self.step[key]}" for key in ("action", "type", "path", "name") if key in self.step
            )
        lines.append(f"ITINERARY FAILURE  {where}  {action}".rstrip())
        if self.node is None:
            lines.append(
                "  node       UNMAPPED -- the failing step carries no _itin stamp this itinerary declares. "
                "A step with no stamp is either hand-patched into the JSON (which the corpus rule forbids) "
                "or emitted from a different itinerary than the one passed here."
            )
            lines.append(f"  driver     {self.message}")
            return "\n".join(lines)
        node = self.node
        lines.append(f"  node       {node.id}   ({node.primitive})")
        planner = PLANNER_OF.get(node.primitive, "unknown")
        lines.append(f"  planner    {planner}")
        if node.source_file:
            lines.append(f"  written at {node.source_file}:{node.source_line or '?'}")
        lines.append(f"  spec       {json.dumps(node.spec, ensure_ascii=False, sort_keys=True)}")
        if node.why:
            lines.append(f"  why        {' '.join(node.why.split())}")
        lines.append(f"  driver     {self.message}")
        return "\n".join(lines)


def parse_failure(text: str) -> tuple[str, int | None]:
    """Split a driver failure line into its message and the step it ran on."""
    match = STATE_SUFFIX_RE.search(text)
    if match is None:
        return text.strip(), None
    message = text[: match.start()].strip()
    try:
        state = json.loads(match.group(1))
    except json.JSONDecodeError:
        return message, None
    step = state.get("step")
    return message, int(step) if isinstance(step, int) else None


def map_failures(
    steps: list[dict[str, Any]], nodes: Iterable[Node], failures: Iterable[str]
) -> list[Failure]:
    by_id = {node.id: node for node in nodes}
    mapped: list[Failure] = []
    for raw in failures:
        message, index = parse_failure(str(raw))
        step: dict[str, Any] | None = None
        node: Node | None = None
        if index is not None and 0 <= index < len(steps):
            step = steps[index]
            node = by_id.get(str(step.get("_itin", "")))
        mapped.append(Failure(message, index, step, node, len(steps)))
    return mapped


def explain(script: dict[str, Any], nodes: Iterable[Node], result: dict[str, Any]) -> str:
    """The whole report for one driver run: every failure, at node altitude."""
    steps = list(script.get("steps", []))
    failures = map_failures(steps, nodes, result.get("failures", []))
    if not failures:
        return "ITINERARY RUN GREEN: no failures to map."
    header = (
        f"ITINERARY RUN RED: {len(failures)} failure(s) over {int(result.get('steps_run', 0))}"
        f"/{int(result.get('steps_total', len(steps)))} steps"
    )
    if result.get("aborted"):
        header += " (fail-fast aborted the run at the first red)"
    unmapped = sum(1 for failure in failures if not failure.mapped)
    if unmapped:
        header += f"; {unmapped} could not be mapped to a node"
    return "\n\n".join([header] + [failure.render() for failure in failures])


def explain_run(script_path: str | Path, nodes: Iterable[Node], result_path: str | Path) -> str:
    script = json.loads(Path(script_path).read_text(encoding="utf-8"))
    result = json.loads(Path(result_path).read_text(encoding="utf-8"))
    return explain(script, nodes, result)
