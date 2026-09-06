#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import json
from pathlib import Path
import sys
from typing import Any


if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from scripts.itinerary.bridge import OracleBridge
    from scripts.itinerary.detours import DetourLibrary
    from scripts.itinerary.emit import CREATION_DIFFICULTY_OPTIONS, Emitter
    from scripts.itinerary.ledger import Ledger
    from scripts.itinerary.planners.actions import ActionPlanner
    from scripts.itinerary.planners.combat import CombatPlanner
    from scripts.itinerary.planners.dialogue import DialoguePlanner
    from scripts.itinerary.planners.economy import EconomyPlanner
    from scripts.itinerary.planners.route import RoutePlanner
    from scripts.itinerary.planners.sleep import SleepPlanner
    from scripts.itinerary.harvest import PROBE_ACTION, Harvest, load_harvest
    from scripts.itinerary.provenance import explain
    from scripts.itinerary.refine import Refiner
    from scripts.itinerary.replay import checkpoint_from, self_check
    from scripts.itinerary.schema import RAW_STEP_BUDGET, Node, load_itinerary
else:
    from .bridge import OracleBridge
    from .detours import DetourLibrary
    from .emit import CREATION_DIFFICULTY_OPTIONS, Emitter
    from .ledger import Ledger
    from .planners.actions import ActionPlanner
    from .planners.combat import CombatPlanner
    from .planners.dialogue import DialoguePlanner
    from .planners.economy import EconomyPlanner
    from .planners.route import RoutePlanner
    from .planners.sleep import SleepPlanner
    from .harvest import PROBE_ACTION, Harvest, load_harvest
    from .provenance import explain
    from .refine import Refiner
    from .replay import checkpoint_from, self_check
    from .schema import RAW_STEP_BUDGET, Node, load_itinerary


MILESTONE = 3
START_NODE = "itinerary.start"


class CompileError(RuntimeError):
    pass


class NodePlanner:
    """One dispatcher, so a detour's nodes plan exactly like an act's do."""

    def __init__(self, project: Path, bridge: Any, library: DetourLibrary) -> None:
        self.library = library
        # Every node this dispatcher plans leaves a checkpoint -- including the
        # ones a detour splices in, which no act ever names.
        self.checkpoints: list[Any] = []
        self.route = RoutePlanner(project, bridge)
        self.dialogue = DialoguePlanner(project, bridge, self.route)
        self.sleep = SleepPlanner(bridge, project)
        self.combat = CombatPlanner(project, bridge, self.route, self.dialogue)
        self.actions = ActionPlanner(project, bridge, self.route)
        self.economy = EconomyPlanner(project, bridge, self.route, self.dialogue, library)
        self.economy.plan_node = self.plan

    def plan(self, node: Node, ledger: Ledger) -> list[dict[str, Any]]:
        ops = self._dispatch(node, ledger)
        for operation in ops:
            # Ops planned inside another node (a spliced detour) keep their own
            # provenance; everything else inherits the node it came from.
            operation.setdefault("itin", node.id)
        self.checkpoints.append(checkpoint_from(ledger, node.id, node.primitive))
        return ops

    def _dispatch(self, node: Node, ledger: Ledger) -> list[dict[str, Any]]:
        spec = node.spec
        if node.primitive == "goto":
            ops = self.route.plan_to(node.id, ledger, str(spec["map"]), spec.get("cell"), str(spec.get("via", "")))
            if spec.get("expect_render"):
                ops.append({"kind": "map_rendered", "map": str(spec["map"])})
            return ops
        if node.primitive == "talk":
            npc_map, entity = self.route.find_entity(str(spec["npc"]), str(spec.get("at", "")) or None)
            return self.dialogue.plan(node.id, spec, node.why, ledger, entity, npc_map)
        if node.primitive == "sleep":
            ops = self.sleep.plan(node.id, spec, ledger)
            if spec.get("shot"):
                ops.append({"kind": "shot", "name": str(spec["shot"])})
            return ops
        if node.primitive == "fight":
            return self.combat.plan(node.id, spec, ledger, node.why)
        if node.primitive == "buy":
            return self.economy.plan_buy(node.id, spec, node.why, ledger)
        if node.primitive == "sell":
            return self.economy.plan_sell(node.id, spec, node.why, ledger)
        if node.primitive == "equip":
            return self.actions.plan_equip(node.id, spec, ledger)
        if node.primitive == "unequip":
            return self.actions.plan_unequip(node.id, spec, ledger)
        if node.primitive == "use_field":
            return self.actions.plan_use_field(node.id, spec, ledger)
        if node.primitive == "interact":
            return self.actions.plan_interact(node.id, spec, ledger)
        if node.primitive == "journal":
            # No planner: a journal read banks nothing, moves nothing and draws
            # no rng, so there is no decision for one to make. It goes straight
            # to the emitter, which owns the open/close pair.
            return [{"kind": "journal", "capture": str(spec.get("capture", "")), "act": str(spec.get("act", ""))}]
        if node.primitive == "shot":
            return [{"kind": "shot", "name": str(spec["name"])}]
        if node.primitive == "assert":
            return self._plan_assert(node, ledger)
        if node.primitive == "detour":
            return self.plan_detour(node.id, str(spec["id"]), ledger)
        if node.primitive == "raw":
            return [{"kind": "raw", "steps": list(spec["steps"]), "note": f"RAW: {node.why}" if node.why else None}]
        raise CompileError(f"no planner for primitive {node.primitive!r} (node {node.id})")

    def plan_detour(self, node_id: str, detour_id: str, ledger: Ledger) -> list[dict[str, Any]]:
        detour = self.library.get(detour_id)
        self.economy.used_detours.add(detour.id)
        ops = self.plan(Node(f"detour.{detour.id}.entry", "goto", {"map": detour.entry_map}, detour.why, "detour"), ledger)
        for inner in detour.nodes:
            ops.extend(self.plan(inner, ledger))
        if ledger.map_id != detour.exit_map:
            raise CompileError(
                f"{node_id}: detour {detour.id} promised to exit on {detour.exit_map} but left the ledger on {ledger.map_id}"
            )
        return ops

    def _plan_assert(self, node: Node, ledger: Ledger) -> list[dict[str, Any]]:
        ops: list[dict[str, Any]] = []
        for path, expectation in node.spec.get("state", {}).items():
            operation: dict[str, Any] = {"kind": "assert_state", "path": str(path)}
            if isinstance(expectation, dict) and set(expectation) <= {"equals", "contains"} and expectation:
                operation.update(expectation)
            else:
                operation["equals"] = expectation
            ops.append(operation)
        event = node.spec.get("event") or {}
        if event:
            ops.append({"kind": "assert_event", "type": str(event["type"]), "payload_contains": event.get("payload_contains", {})})
        absent = node.spec.get("event_absent") or {}
        if absent:
            ops.append({"kind": "assert_event_absent", "type": str(absent["type"]), "payload_contains": absent.get("payload_contains", {})})
        return ops


def _fixture_reference(start_path: Path, project: Path) -> str:
    """Prefer the bare fixture NAME over an absolute path.

    The driver resolves a bare name under `qa/fixtures/`, and a compiled
    script that hardcodes one machine's absolute path is not a script anyone
    else can run -- nor one whose recompile is byte-comparable across trees.
    """
    fixtures = (project / "qa" / "fixtures").resolve()
    resolved = start_path.resolve()
    if resolved.parent == fixtures and resolved.suffix == ".json":
        return resolved.stem
    return str(resolved)


def _creation_operation(creation: dict[str, Any]) -> dict[str, Any]:
    """The `creation:` scalars, resolved into the emitter's prelude operation.

    The one resolution that happens here rather than in the emitter is the
    difficulty CURSOR. §346 made both setup prompts open on the live setting
    rather than on a fixed row, so the script's job is to say which rank the
    run expects and let the pin prove the prompt agreed -- naming the rank and
    deriving its index keeps the itinerary readable without the compiler
    pretending it can read the player's settings file.
    """
    rank = str(creation["difficulty"])
    if rank not in CREATION_DIFFICULTY_OPTIONS:
        raise CompileError(
            f"creation: difficulty {rank!r} is not one of {CREATION_DIFFICULTY_OPTIONS}"
        )
    return {
        "kind": "creation_prelude",
        "itin": START_NODE,
        "race": str(creation["race"]),
        "gender": str(creation["gender"]),
        "name": str(creation["name"]),
        "difficulty_step": CREATION_DIFFICULTY_OPTIONS.index(rank),
        "hints": bool(creation["hints"]),
        "tap_back": bool(creation["tap_back"]),
        "shots": dict(creation.get("shots", {})),
    }


def _probe_step(node_id: str) -> dict[str, Any]:
    """The harvest marker: a node-labelled reading of the whole sim.

    `dump_state` (GH#436) emits `qa_state_dump` on the bus, so it lands in
    `events.jsonl` of a PASSING run -- which is the only kind of run a harvest
    may be taken from. It asserts nothing and draws no rng, so a probe build
    plays the same run the ship build does.
    """
    return {"_itin": node_id, "action": PROBE_ACTION, "label": node_id}


def compile_itinerary(
    source: Path,
    output: Path,
    project: Path,
    authoring: bool = False,
    probe: bool = False,
    harvest: Harvest | None = None,
) -> dict[str, Any]:
    return compile_with_report(source, output, project, authoring, probe, harvest)[0]


def compile_with_report(
    source: Path,
    output: Path,
    project: Path,
    authoring: bool = False,
    probe: bool = False,
    harvest: Harvest | None = None,
) -> tuple[dict[str, Any], Any]:
    """Plan and emit one itinerary, and on pass 2 fence the plan (§3.2).

    `probe` builds the HARVEST script: the same run with a `dump_state` after
    every node, so a pass-2 refine has a node-labelled reading of the sim to
    work from (§5). `harvest` runs that pass 2 -- the recorded actuals replace
    the projections that pass 1 could only guess at.

    The two combine on purpose. Refining a script and then probing it again is
    how §5's convergence contract stops being an argument and becomes a test:
    harvest the refined run, refine from THAT, and the output must be
    byte-identical to the one you already had.

    Pass 2 additionally plans the itinerary TWICE -- once with the harvest and
    once without -- and refuses to emit if the two plans differ in their spine.
    That is the 2026-08-13 fence: refine may tighten pins, never re-plan. The
    second plan is cheap because the oracle bridge caches on (query, save), and
    two plans that agree ask identical questions under identical saves; the
    moment they stop agreeing, the queries diverge and so does the spine, which
    is the thing being caught.
    """
    bridge = OracleBridge(project)
    if harvest is not None:
        baseline = _build(source, project, bridge, authoring, probe, None)
        refined = _build(source, project, bridge, authoring, probe, harvest)
        _fence_plan_spine(baseline, refined)
        build = refined
    else:
        build = _build(source, project, bridge, authoring, probe, None)
    script = build.script
    _validate(script["steps"], build.checkpoints, build.start_checkpoint, build.document, probe)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(script, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return script, build.report


@dataclass
class Build:
    """One planning pass's whole output, before it is validated or written."""

    document: Any
    script: dict[str, Any]
    checkpoints: list[Any]
    start_checkpoint: Any
    nodes: list[str]
    detours: list[dict[str, Any]]
    report: Any
    # Where the LEDGER stood after each node (map, cell, facing). The emitted
    # spine cannot see this on its own: a `goto` whose destination depends on
    # ledger state re-plans into the SAME `move` runs when the two passes
    # happen to agree on distance, and a `press interact` reads identical in
    # both. The arrival is the state-dependent-destination hole, and closing it
    # before M4's portal-heavy variant is the 2026-08-13 M3.6 amendment's
    # item 5.
    arrivals: list[tuple[str, str, tuple[int, int], tuple[int, int]]] = field(default_factory=list)


def _build(
    source: Path,
    project: Path,
    bridge: Any,
    authoring: bool,
    probe: bool,
    harvest: Harvest | None,
) -> Build:
    document = load_itinerary(source, milestone=MILESTONE)
    planner = NodePlanner(project, bridge, DetourLibrary())
    emitter = Emitter()
    ledger = Ledger.fresh()
    refiner = Refiner(harvest) if harvest is not None else None

    script: dict[str, Any] = {
        "_comment": "Generated by scripts/itinerary/compile_itinerary.py. Edit the itinerary YAML, never this JSON.",
        "steps": [],
    }
    prelude: list[dict[str, Any]] = []
    if document.start:
        start_path = Path(document.start)
        if not start_path.is_absolute():
            start_path = (source.parent / start_path).resolve()
        ledger = Ledger.from_save(json.loads(start_path.read_text(encoding="utf-8")))
        # `WIGame.reprime_quests`: a fixture arrives mid-story with quests
        # already started and beats already closed. Without this the first
        # accomplishment the run banks would look like it closed every one of
        # them at once, and the compiler would emit beat events the game will
        # never send.
        planner.dialogue.quests.reprime(ledger)
        script["fixture_save"] = _fixture_reference(start_path, project)
        # A fixture only reaches the sim if the run CONTINUES from the title;
        # the driver's own title auto-skip starts a new game instead.
        script["starts_at_title"] = True
        prelude = [{"kind": "fixture_prelude", "map": ledger.map_id, "cell": ledger.cell, "itin": START_NODE}]
    elif document.creation:
        prelude = [_creation_operation(document.creation)]
        # `creation_ui` is the driver's opt-in: without it the title auto-skip
        # runs New Game straight past the creation screen the prelude drives.
        script["starts_at_title"] = True
        script["creation_ui"] = True
        ledger.state["pc_name"] = str(document.creation["name"])
        ledger.state["pc_race"] = str(document.creation["race"])
        ledger.state["pc_gender"] = str(document.creation["gender"])

    start_checkpoint = checkpoint_from(ledger, START_NODE, "start")
    planner.checkpoints.append(start_checkpoint)
    if prelude:
        script["steps"].extend(emitter.emit(START_NODE, prelude))
        if probe:
            script["steps"].append(_probe_step(START_NODE))

    previous_act = ""
    for node in document.nodes:
        if authoring and node.act != previous_act:
            script["steps"].append({"_itin": node.id, "action": "dump_checkpoint", "slot": f"act_{node.act}"})
        previous_act = node.act
        pending_before = len(ledger.pins_pending)
        operations = planner.plan(node, ledger)
        if refiner is not None:
            refiner.after_node(node, ledger, operations, pending_before)
            # The checkpoint is "what the ledger believed after this node", and
            # after pass 2 the ledger believes the harvest. Re-taking it is not
            # a way around the replay self-check -- it is what keeps that check
            # meaningful, because a refined pin asserting a harvested counter
            # must still be reconciled against the ledger that now holds it.
            planner.checkpoints[-1] = checkpoint_from(ledger, node.id, node.primitive)
        script["steps"].extend(emitter.emit(node.id, operations))
        if probe:
            script["steps"].append(_probe_step(node.id))

    if refiner is not None:
        refiner.review_detours(planner.economy.insertions)

    if planner.economy.notes:
        script["_pacing_notes"] = list(planner.economy.notes)
    if refiner is not None:
        # Only when there is something to say: an itinerary with no projections
        # to pay off refines to exactly its pass-1 self, and a stray empty key
        # would make that identity look like a difference.
        refine_notes = (
            [row.describe() for row in refiner.report.resolutions]
            + list(refiner.report.tightened)
            + list(refiner.report.notes)
        )
        if refine_notes:
            script["_refine_notes"] = refine_notes

    return Build(
        document=document,
        script=script,
        checkpoints=planner.checkpoints,
        start_checkpoint=start_checkpoint,
        nodes=[node.id for node in document.nodes],
        detours=[dict(row) for row in planner.economy.insertions],
        report=(refiner.report if refiner is not None else None),
        arrivals=[
            (cp.node, cp.map_id, (int(cp.cell[0]), int(cp.cell[1])), (int(cp.facing[0]), int(cp.facing[1])))
            for cp in planner.checkpoints
        ],
    )


# What the fence compares. Everything refine is ALLOWED to touch is excluded:
# the assert actions it appends, the `payload_contains` pins it tightens, the
# probe markers a probe build carries, and the prose it writes into comments.
# What remains is the plan -- which nodes ran, in what order, and what the run
# pressed and walked between them.
SPINE_EXCLUDED_ACTIONS = {"assert_state", "assert_event_logged", "assert_event_absent", PROBE_ACTION}
# The identity of a non-assert step, minus every pin surface. `steps`/`frames`
# ride along because a changed ROUTE is exactly what this fence exists to catch.
SPINE_FIELDS = ("action", "type", "name", "direction", "steps", "frames", "skill", "slot", "card", "text", "policy")


def _plan_spine(script: dict[str, Any]) -> list[tuple[Any, ...]]:
    spine: list[tuple[Any, ...]] = []
    for step in script.get("steps", []):
        if str(step.get("action", "")) in SPINE_EXCLUDED_ACTIONS:
            continue
        spine.append(tuple([str(step.get("_itin", ""))] + [step.get(field) for field in SPINE_FIELDS]))
    return spine


def _fence_plan_spine(baseline: Build, refined: Build) -> None:
    """Pass 2 refines PINS, not the PLAN -- enforced, not asked for (§3.2).

    The audited latent path is real: refine collapses harvested values into the
    ledger so that downstream oracle answers are asked under the world the run
    was really in, and those same ledger values are what the route, ally-gate
    and progression-preview planners read. Nothing stops a harvested counter
    from opening a door pass 1 found shut -- except this.

    The comparison is the plan SPINE: the node list, the emitted route and
    presses between nodes, and the detours the economy planner spliced in.
    Pins, asserts and probe markers are excluded, because tightening those is
    the entire job pass 2 is for. A difference is a CompileError rather than a
    warning: a re-planned pass 2 has invalidated its own evidence (every rng
    draw behind a moved node moves with it, §2.4), so its output is not a
    tighter version of the run that was harvested -- it is a different run
    wearing that run's pins.
    """
    if baseline.nodes != refined.nodes:
        raise CompileError(
            "PLAN-SPINE FENCE: pass 2 planned a different NODE LIST than pass 1.\n"
            f"  pass 1: {len(baseline.nodes)} nodes\n  pass 2: {len(refined.nodes)} nodes\n"
            f"  first difference: {_first_difference(baseline.nodes, refined.nodes)}"
        )
    left = [(row.get("node"), row.get("detour")) for row in baseline.detours]
    right = [(row.get("node"), row.get("detour")) for row in refined.detours]
    if left != right:
        raise CompileError(
            "PLAN-SPINE FENCE: pass 2 spliced a different set of earn-DETOURS than pass 1.\n"
            f"  pass 1: {left}\n  pass 2: {right}\n"
            "  Refine may FLAG an unnecessary detour (§2.3) and may never drop one: removing a node moves every "
            "rng draw behind it, so the harvest being refined from describes a run that no longer exists."
        )
    if baseline.arrivals != refined.arrivals:
        raise CompileError(
            "PLAN-SPINE FENCE: pass 2 ARRIVED somewhere pass 1 did not.\n"
            f"  first difference: {_first_difference(baseline.arrivals, refined.arrivals)}\n"
            "  A node's end position is part of the plan even when the emitted steps between two nodes read the "
            "same: a state-dependent destination (a gated door, a portal row that appeared) re-routes without "
            "changing a single `move` run's length. Pass 2 refines PINS, not the PLAN."
        )
    baseline_spine, refined_spine = _plan_spine(baseline.script), _plan_spine(refined.script)
    if baseline_spine != refined_spine:
        raise CompileError(
            "PLAN-SPINE FENCE: pass 2 emitted a different ROUTE than pass 1.\n"
            f"  pass 1: {len(baseline_spine)} plan steps\n  pass 2: {len(refined_spine)} plan steps\n"
            f"  first difference: {_first_difference(baseline_spine, refined_spine)}\n"
            "  Pass 2 refines PINS, not the PLAN. A harvested value reached a planner -- route, ally gate or "
            "progression preview -- and re-decided something pass 1 had already decided."
        )


def _first_difference(left: list[Any], right: list[Any]) -> str:
    for index in range(max(len(left), len(right))):
        one = left[index] if index < len(left) else None
        two = right[index] if index < len(right) else None
        if one != two:
            return f"[{index}] pass 1 {one!r} vs pass 2 {two!r}"
    return "(same prefix, different length)"


def _validate(
    steps: list[dict[str, Any]], checkpoints: list[Any], start: Any, document: Any, probe: bool = False
) -> None:
    probes = [step for step in steps if str(step.get("action", "")) == PROBE_ACTION]
    if probes and not probe:
        # The harvest markers are scaffolding, and scaffolding that ships is
        # how the stitched-album mistake happened. A ship build carries none.
        raise CompileError(
            f"{len(probes)} {PROBE_ACTION} step(s) in a SHIP build. Harvest probes belong to --probe only; "
            "the refined script that ships must be pure."
        )
    raw_nodes = {node.id for node in document.nodes if node.primitive == "raw"}
    raw_steps = sum(1 for step in steps if str(step.get("_itin", "")) in raw_nodes)
    if steps and raw_steps / len(steps) > RAW_STEP_BUDGET:
        raise CompileError(
            f"raw budget blown: {raw_steps}/{len(steps)} steps ({raw_steps / len(steps):.1%}) exceed "
            f"{RAW_STEP_BUDGET:.0%}. Raw is where corpus knowledge goes to hide -- teach the emitter instead."
        )
    problems = self_check(steps, checkpoints, start)
    if problems:
        raise CompileError(
            "ledger replay self-check FAILED -- the emitted script and the ledger disagree:\n  "
            + "\n  ".join(problems)
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile a Wandering Inn QA itinerary (M3)")
    parser.add_argument("itinerary", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2] / "wandering_inn_game")
    parser.add_argument("--authoring", action="store_true")
    parser.add_argument(
        "--probe", action="store_true",
        help="build the HARVEST script: a dump_state after every node, for --refine to read back",
    )
    parser.add_argument(
        "--refine", type=Path, default=None, metavar="EVENTS",
        help="pass 2: collapse projections onto the actuals recorded in a probe run's events.jsonl",
    )
    parser.add_argument(
        "--run", action="store_true",
        help="run the compiled script headless and report any failure at NODE altitude (§5's failure loop)",
    )
    parser.add_argument("--seed", type=int, default=9)
    parser.add_argument("--run-out", type=Path, default=None)
    args = parser.parse_args()
    output = args.out or args.itinerary.with_suffix(".json")
    harvest = load_harvest(args.refine) if args.refine is not None else None
    script, report = compile_with_report(
        args.itinerary.resolve(), output.resolve(), args.project.resolve(), args.authoring, args.probe, harvest
    )
    document = load_itinerary(args.itinerary, MILESTONE)
    raw_nodes = {node.id for node in document.nodes if node.primitive == "raw"}
    raw_steps = sum(1 for step in script["steps"] if str(step.get("_itin", "")) in raw_nodes)
    mode = "probe" if args.probe else ("refined" if harvest is not None else "ship")
    print(
        f"ITINERARY_COMPILED: {output.resolve()} nodes={len(document.nodes)} "
        f"steps={len(script['steps'])} raw_steps={raw_steps} replay_self_check=ok mode={mode}"
    )
    for note in script.get("_pacing_notes", []):
        print(f"  {note}")
    if report is not None:
        print(
            f"ITINERARY_REFINED: pins_pending resolved={report.resolved_count} "
            f"(pinned={report.pinned_count}) tightened={len(report.tightened)} notes={len(report.notes)}"
        )
        for row in script.get("_refine_notes", []):
            print(f"  {row}")
    if args.run:
        return _run_and_explain(args, output, script, document)
    return 0


def _run_and_explain(args: Any, output: Path, script: dict[str, Any], document: Any) -> int:
    """§5's failure loop: a red run is reported as a NODE, not as a step index."""
    bridge = OracleBridge(args.project.resolve())
    run_out = (args.run_out or (output.parent / f"run_{output.stem}")).resolve()
    try:
        result, _ = bridge.run_driver(output, run_out, seed=args.seed, fail_fast=True)
    except Exception as exc:  # noqa: BLE001 -- the driver's own failure is the payload
        result_path = run_out / "result.json"
        if not result_path.exists():
            print(f"ITINERARY_RUN_ERROR: {exc}")
            return 1
        result = json.loads(result_path.read_text(encoding="utf-8"))
        print(explain(script, document.nodes, result))
        return 1
    print(
        f"ITINERARY_RUN_GREEN: seed={args.seed} steps={result.get('steps_run')}/{result.get('steps_total')} "
        f"events_seen={result.get('events_seen')} out={run_out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
