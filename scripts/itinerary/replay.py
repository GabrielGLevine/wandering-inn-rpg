from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}

# Waits that OPEN and CLOSE a cursor surface. While one is open, a `move` step
# steps a menu cursor, not the player -- integrating those into a position
# would be the single easiest way for this check to lie. Each surface is a
# FLAG, not a depth count: a conversation that ends emits both dialogue_ended
# and ui_dialogue_hidden, and counting those as two closes would underflow.
PANELS = {
    # `combat_started` closes the conversation too (M3.6 amendment item 1): a
    # `start_combat` row hands the screen to the board, and the panel it leaves
    # behind is gone whether or not the script waited on its teardown. Without
    # this the replay would keep the dialogue flag raised for the rest of the
    # run and read every later walk as a menu cursor move -- which is exactly
    # what it did the first time `entry: dialogue` compiled.
    "dialogue": ({"dialogue_started"}, {"dialogue_ended", "ui_dialogue_hidden", "combat_started"}),
    "inventory": ({"ui_inventory_shown"}, {"ui_inventory_hidden"}),
    "combat": ({"combat_started"}, {"ui_combat_hidden"}),
    "title": ({"ui_title_gate_rendered"}, {"world_ready"}),
    # The journal has no cursor to walk, but it is still a panel: a `journal`
    # node that opened the book and forgot to close it eats the next press
    # exactly like an open conversation does, and the end-of-script check is
    # what catches that.
    "journal": ({"ui_journal_shown"}, {"ui_journal_hidden"}),
}


class ReplayError(RuntimeError):
    pass


@dataclass(frozen=True)
class Checkpoint:
    """What the LEDGER believed after a node was planned."""

    node: str
    primitive: str
    map_id: str
    cell: list[int]
    facing: list[int]
    gold_interval: tuple[int, int]
    classes: dict[str, Any]
    accomplishments: dict[str, Any]
    equipped: dict[str, Any]
    removed_entities: list[str]
    dormant_encounters: list[str]


@dataclass
class _State:
    map_id: str
    cell: list[int]
    facing: list[int]
    open_panels: set[str] = field(default_factory=set)
    moves: list[dict[str, Any]] = field(default_factory=list)
    saw_dialogue_node: bool = False

    @property
    def in_panel(self) -> bool:
        return bool(self.open_panels)

    @property
    def in_dialogue(self) -> bool:
        return "dialogue" in self.open_panels

    @property
    def in_combat(self) -> bool:
        return "combat" in self.open_panels


def self_check(steps: list[dict[str, Any]], checkpoints: list[Checkpoint], start: Checkpoint) -> list[str]:
    """Re-derive the run from the EMITTED script and compare to the ledger.

    §6.2's gate. The emitter builds steps from semantic operations; the
    planners move the ledger. Those are two code paths that must agree, and
    when they silently stop agreeing the symptom is a script that compiles
    clean and then walks into a wall on a real run. This replays the artifact
    -- positions from its own `move` steps, map from its own `map_changed`
    waits, money and gear from its own pins -- and reports every divergence
    from what the ledger recorded at that node.

    Returns a list of human-readable divergences; empty means green.
    """
    problems: list[str] = []
    by_node = {cp.node: cp for cp in checkpoints}
    order = [cp.node for cp in checkpoints]

    stamped = [step for step in steps if "_itin" in step]
    if len(stamped) != len(steps):
        problems.append(f"{len(steps) - len(stamped)} emitted steps carry no _itin stamp")
    unknown = sorted({str(step.get("_itin")) for step in steps} - set(by_node))
    if unknown:
        problems.append(f"steps stamped with unknown node ids: {unknown}")

    grouped: list[tuple[str, list[dict[str, Any]]]] = []
    for step in steps:
        node = str(step.get("_itin", ""))
        if not grouped or grouped[-1][0] != node:
            grouped.append((node, []))
        grouped[-1][1].append(step)
    seen_nodes = [node for node, _ in grouped]
    if len(seen_nodes) != len(set(seen_nodes)):
        problems.append("a node's steps are not contiguous -- _itin stamps interleave")
    if seen_nodes != [node for node in order if node in set(seen_nodes)]:
        problems.append("emitted node order does not match the planned node order")

    state = _State(start.map_id, list(start.cell), list(start.facing))
    for node, node_steps in grouped:
        checkpoint = by_node.get(node)
        if checkpoint is None:
            continue
        state.moves = []
        problems.extend(_replay_node(state, node, node_steps, checkpoint))
        problems.extend(_reconcile_position(state, checkpoint))
    if state.open_panels:
        problems.append(
            f"script ends with {sorted(state.open_panels)} still open -- the next press would be eaten by the panel"
        )
    return problems


def _replay_node(state: _State, node: str, steps: list[dict[str, Any]], checkpoint: Checkpoint) -> list[str]:
    problems: list[str] = []
    for step in steps:
        action = str(step.get("action", ""))
        if action == "move":
            if state.in_panel:
                continue  # cursor move, not a walk
            state.moves.append(step)
            direction = str(step.get("direction", ""))
            if direction in DIRECTIONS:
                state.facing = list(DIRECTIONS[direction])
        elif action == "wait_for_event":
            problems.extend(_replay_wait(state, node, step))
        elif action == "combat_autoplay":
            if not state.in_combat:
                problems.append(f"{node}: combat_autoplay outside a live combat")
        elif action == "assert_state":
            problems.extend(_check_state_pin(node, step, checkpoint, state.map_id, _live_cell(state)))
    return problems


def _live_cell(state: _State) -> list[int]:
    """Where the replay thinks the player stands RIGHT NOW, mid-node.

    Position pins are emitted the moment a transition lands, not at the end of
    the node, so checking them against the node's closing checkpoint would red
    every `goto` that walks on after arriving.
    """
    cell = list(state.cell)
    for step in state.moves:
        delta = DIRECTIONS.get(str(step.get("direction", "")))
        if delta is None:
            continue
        count = int(step.get("steps", 1))
        cell = [cell[0] + delta[0] * count, cell[1] + delta[1] * count]
    return cell


def _replay_wait(state: _State, node: str, step: dict[str, Any]) -> list[str]:
    problems: list[str] = []
    event = str(step.get("type", ""))
    payload = step.get("payload_contains", {}) or {}
    if event == "dialogue_started":
        if state.in_dialogue:
            problems.append(f"{node}: dialogue_started while a dialogue is already open")
        state.saw_dialogue_node = False
    elif event == "dialogue_node":
        state.saw_dialogue_node = True
    elif event == "ui_dialogue_shown" and state.in_dialogue and not state.saw_dialogue_node:
        # A ui_dialogue_shown waited BEFORE the hub's own dialogue_node
        # advances the since-cursor past it, and every later dialogue_node pin
        # then can never match. Two reds bought this rule.
        problems.append(f"{node}: ui_dialogue_shown waited before the node's own dialogue_node")
    elif event == "combat_started":
        if state.in_combat:
            problems.append(f"{node}: combat_started while a combat is already live")
    elif event == "combat_finished":
        if not state.in_combat:
            problems.append(f"{node}: combat_finished with no live combat")
    elif event == "map_changed":
        if "map" in payload:
            state.map_id = str(payload["map"])
        if "cell" in payload:
            state.cell = [int(part) for part in payload["cell"]]
        state.moves = []
    for panel, (opens, closes) in PANELS.items():
        if event in opens:
            state.open_panels.add(panel)
        elif event in closes:
            state.open_panels.discard(panel)
    return problems


def _reconcile_position(state: _State, checkpoint: Checkpoint) -> list[str]:
    problems: list[str] = []
    if state.map_id != checkpoint.map_id:
        problems.append(
            f"{checkpoint.node}: replayed map {state.map_id!r}, ledger recorded {checkpoint.map_id!r}"
        )
        state.map_id = checkpoint.map_id
    walked = list(state.cell)
    for step in state.moves:
        delta = DIRECTIONS.get(str(step.get("direction", "")))
        if delta is None:
            continue
        count = int(step.get("steps", 1))
        walked = [walked[0] + delta[0] * count, walked[1] + delta[1] * count]
    target = [int(part) for part in checkpoint.cell]
    if walked == target:
        state.cell = walked
    else:
        # The one sanctioned discrepancy: a trailing single-step BUMP into a
        # blocked cell sets facing without moving. Anything else is drift.
        bump = state.moves[-1] if state.moves else None
        undone = walked
        if bump is not None and int(bump.get("steps", 1)) == 1:
            delta = DIRECTIONS.get(str(bump.get("direction", "")), (0, 0))
            undone = [walked[0] - delta[0], walked[1] - delta[1]]
        if undone == target:
            state.cell = target
        else:
            problems.append(
                f"{checkpoint.node}: replayed cell {walked} (or {undone} allowing a trailing bump), "
                f"ledger recorded {target}"
            )
            state.cell = target
    if state.facing != [int(part) for part in checkpoint.facing]:
        problems.append(
            f"{checkpoint.node}: replayed facing {state.facing}, ledger recorded {list(checkpoint.facing)}"
        )
        state.facing = [int(part) for part in checkpoint.facing]
    return problems


def _check_state_pin(node: str, step: dict[str, Any], checkpoint: Checkpoint, live_map: str, live_cell: list[int]) -> list[str]:
    path = str(step.get("path", ""))
    has_equals = "equals" in step
    value = step.get("equals")
    if path == "current_map" and has_equals and value != live_map:
        return [f"{node}: pins current_map={value!r}, replay is on {live_map!r}"]
    if path == "player_cell" and has_equals and [int(p) for p in value] != live_cell:
        return [f"{node}: pins player_cell={value}, replay is standing on {live_cell}"]
    if path == "gold" and has_equals:
        low, high = checkpoint.gold_interval
        if not low <= int(value) <= high:
            return [f"{node}: pins gold={value}, outside the ledger interval [{low}, {high}]"]
    if path == "classes" and has_equals and value != checkpoint.classes:
        return [f"{node}: pins classes={value}, ledger says {checkpoint.classes}"]
    if path.startswith("equipped.") and has_equals:
        slot = path.split(".", 1)[1]
        if str(value) != str(checkpoint.equipped.get(slot, "")):
            return [f"{node}: pins {path}={value!r}, ledger says {checkpoint.equipped.get(slot, '')!r}"]
    if path.startswith("accomplishments.") and has_equals:
        key = path.split(".", 1)[1]
        recorded = int(checkpoint.accomplishments.get(key, 0))
        if int(value) != recorded:
            return [f"{node}: pins {path}={value}, ledger says {recorded}"]
    if path in ("removed_entities", "dormant_encounters") and "contains" in step:
        pool = checkpoint.removed_entities if path == "removed_entities" else checkpoint.dormant_encounters
        if str(step["contains"]) not in pool:
            return [f"{node}: pins {path} contains {step['contains']!r}, ledger has {pool}"]
    return []


def checkpoint_from(ledger: Any, node: str, primitive: str) -> Checkpoint:
    return Checkpoint(
        node=node,
        primitive=primitive,
        map_id=ledger.map_id,
        cell=list(ledger.cell),
        facing=list(ledger.facing),
        gold_interval=tuple(ledger.gold_interval),
        classes=dict(ledger.state["classes"]),
        accomplishments=dict(ledger.state["accomplishments"]),
        equipped=dict(ledger.state["equipped"]),
        removed_entities=list(ledger.state["removed_entities"]),
        dormant_encounters=list(ledger.state["dormant_encounters"]),
    )
