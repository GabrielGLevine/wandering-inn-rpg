"""A spec -> planner -> emitter harness, and the fake oracle it runs against.

WHY THIS EXISTS. The first M3.6 suite tested the emitter's rendering of
hand-built operation dicts, which is half a pipeline: every link between a
node SPEC and that dict -- the schema key, the planner branch that reads it,
the operation field it lands in -- could be severed with the suite green. An
audit cut eight of them and nothing went red. A guard that only watches the
last stage is not a guard on the feature; it is a guard on one function.

So every M3.6 criterion is now pinned from a YAML node spec through to emitted
steps. What is stubbed is the ORACLE and nothing else: `FakeOracle` answers the
five query shapes the planners ask (`path`, `visible_options`,
`progression_preview`, `inventory`, `field_bar`, `portal_rows`) and every other
thing -- map entities, dialogue graphs, item and skill catalogs, quest joins --
comes from the real project data the compiler itself reads. The oracle is not
the link under test; the chain from spec to step is.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.itinerary.compile_itinerary import NodePlanner  # noqa: E402
from scripts.itinerary.detours import DetourLibrary  # noqa: E402
from scripts.itinerary.emit import Emitter  # noqa: E402
from scripts.itinerary.ledger import Ledger  # noqa: E402
from scripts.itinerary.schema import load_itinerary_document  # noqa: E402

PROJECT = ROOT / "wandering_inn_game"

DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}


class FakeOracle:
    """The five query shapes, answered from canned data.

    `path` is the only one with any logic, and it is deliberately the dumbest
    router that can exist: walk x, then walk y. Routing is not what these tests
    pin -- they pin that a spec key reaches the step it is supposed to produce
    -- and a dumb router keeps the expected step lists readable.
    """

    def __init__(
        self,
        blocked: set[tuple[int, int]] | None = None,
        options: dict[str, dict[str, Any]] | None = None,
        preview: dict[str, Any] | None = None,
        inventory: list[dict[str, Any]] | None = None,
        field_bar: list[dict[str, Any]] | None = None,
    ) -> None:
        self.blocked = set(blocked or ())
        self.options = dict(options or {})
        self.preview = preview or {"class_gains": [], "level_ups": [], "classes_after": {}, "consolidation": {}}
        self.inventory = list(inventory or [])
        self.field_bar = list(field_bar or [])
        self.asked: list[str] = []

    def query(self, query: str, ledger: Any = None) -> dict[str, Any]:
        self.asked.append(query)
        if query.startswith("path "):
            return self._path(query)
        if query.startswith("visible_options "):
            _, graph, node = query.split()
            if f"{graph}:{node}" not in self.options:
                raise AssertionError(f"FakeOracle has no visible_options for {graph}:{node}")
            return self.options[f"{graph}:{node}"]
        if query == "progression_preview":
            return dict(self.preview)
        if query == "inventory":
            return {"items": list(self.inventory)}
        if query == "field_bar":
            return {"slots": list(self.field_bar)}
        if query == "portal_rows":
            return {"rows": []}
        raise AssertionError(f"FakeOracle got an unmodelled query: {query!r}")

    def _path(self, query: str) -> dict[str, Any]:
        _, _map, start, target = query.split()
        sx, sy = (int(part) for part in start.split(","))
        tx, ty = (int(part) for part in target.split(","))
        cells = [[sx, sy]]
        while cells[-1][0] != tx:
            cells.append([cells[-1][0] + (1 if tx > cells[-1][0] else -1), cells[-1][1]])
        while cells[-1][1] != ty:
            cells.append([cells[-1][0], cells[-1][1] + (1 if ty > cells[-1][1] else -1)])
        answer: dict[str, Any] = {"reachable": True, "cells": cells, "driver_steps": _compress(cells)}
        if (tx, ty) in self.blocked:
            stop = cells[-2] if len(cells) > 1 else cells[0]
            delta = (tx - stop[0], ty - stop[1])
            bump = next(name for name, vector in DIRECTIONS.items() if vector == delta)
            answer["target_blocked"] = True
            answer["approach"] = {"cell": stop, "bump": bump, "driver_steps": _compress(cells[:-1])}
        return answer


def _compress(cells: list[list[int]]) -> list[dict[str, Any]]:
    steps: list[dict[str, Any]] = []
    for index in range(1, len(cells)):
        delta = (cells[index][0] - cells[index - 1][0], cells[index][1] - cells[index - 1][1])
        name = next((key for key, vector in DIRECTIONS.items() if vector == delta), "")
        if not name:
            continue
        if steps and steps[-1]["direction"] == name:
            steps[-1]["steps"] += 1
        else:
            steps.append({"action": "move", "direction": name, "steps": 1})
    return steps


def bare(steps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {key: value for key, value in step.items() if key not in ("_itin", "_comment", "timeout_sec")}
        for step in steps
    ]


class Pipeline:
    """One compile, held open so a test can read the ledger after it."""

    def __init__(self, oracle: FakeOracle, ledger: Ledger | None = None) -> None:
        self.oracle = oracle
        self.planner = NodePlanner(PROJECT, oracle, DetourLibrary())
        self.emitter = Emitter()
        self.ledger = ledger or Ledger.fresh()

    def inject_npc(self, map_id: str, entity: dict[str, Any], graph: dict[str, Any]) -> None:
        """Add an NPC and its conversation to the LOADED project data.

        Used where the shape under test needs a controlled graph rather than
        a corpus site buried behind ten acts of state. Everything else about
        the run stays real.
        """
        self.planner.route.maps[map_id]["entities"].append(entity)
        self.planner.dialogue.graphs[str(entity["conversation"])] = graph

    def run(self, body: str) -> list[dict[str, Any]]:
        document = load_itinerary_document(yaml.safe_load(body), milestone=3)
        steps: list[dict[str, Any]] = []
        for node in document.nodes:
            steps.extend(self.emitter.emit(node.id, self.planner.plan(node, self.ledger)))
        return bare(steps)


def act(nodes: str, act_label: str = "i") -> str:
    return f"- act: {act_label}\n  nodes:\n{nodes}"
