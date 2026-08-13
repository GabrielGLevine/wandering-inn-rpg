from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Any

import yaml


PRIMITIVES = {
    "goto",
    "talk",
    "fight",
    "sleep",
    "equip",
    "unequip",
    "buy",
    "sell",
    "use_field",
    "interact",
    "journal",
    "shot",
    "assert",
    "detour",
    "raw",
}
# The design freezes the primitive set for M1-M3 (§3.2): M2 is the "full
# primitives" milestone, and M3/M4 add compiler passes (refine, goldens,
# variants), not language. So M2 unlocks everything and there is no
# still-future primitive left to reject -- the rejection surface that remains
# is an UNKNOWN primitive key, plus M1's own narrower set.
#
# The 2026-08-13 pre-M4 design note reopened §3.2 for exactly two idioms the
# M3 golden measured missing in 2569 corpus steps -- `fight.mode: driven` and
# `journal` -- and re-froze behind them. `journal` is the only new PRIMITIVE
# key (driven is a mode of the existing `fight`), and it lands in the same
# unlocked-from-M2 tier as the rest: the milestone gate exists to stage M1's
# spine, not to stage post-M3 amendments.
MILESTONE_PRIMITIVES = {1: {"goto", "talk", "sleep"}, 2: set(PRIMITIVES), 3: set(PRIMITIVES)}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")

# Every spec key a primitive accepts. Unknown keys are REJECTED rather than
# ignored: a typo'd `encouter:` that silently no-ops is the failure mode this
# language cannot afford (a mis-planned fight compiles green and hangs a run).
SPEC_KEYS: dict[str, set[str]] = {
    "goto": {"map", "cell", "why"},
    "talk": {"npc", "at", "choose_path", "why"},
    "fight": {"encounter", "at", "entry", "mode", "turns", "policy", "expect", "max_turns", "shots", "why"},
    "sleep": {"expect_levels", "expect_merge", "shot", "why"},
    "equip": {"item", "why"},
    "unequip": {"slot", "why"},
    "buy": {"vendor", "at", "item", "choose_path", "why"},
    "sell": {"vendor", "at", "item", "choose_path", "why"},
    "use_field": {"skill", "why"},
    "interact": {"prop", "at", "expect_accomplishment", "why"},
    # No `hold`: §3.2 sketches "name + hold", but the driver's `screenshot`
    # arm takes ONLY `name` (qa/test_driver.gd), the capture hold is a
    # CONSTANT-derived ceiling (`capture_hold_ceiling_msec`) rather than
    # something a script's waits can extend, and hand-padding frames in front
    # of a capture is explicitly banned (GH#324). Accepting `hold` would mean
    # silently ignoring it, so the schema rejects it instead.
    "shot": {"name", "why"},
    # The shipped press-journal idiom (steel_thread 561-566 / 2317-2322): open,
    # optionally capture, close. `act` tightens the `ui_journal_shown` pin to
    # the act page the book opened on -- the corpus reads it both ways, and a
    # journal beat that means "the book knows we are in Act V" should say so.
    "journal": {"capture", "act", "why"},
    "assert": {"state", "event", "event_absent", "why"},
    "detour": {"id", "why"},
    "raw": {"steps", "why"},
}

EQUIP_SLOTS = {"weapon", "armor", "accessory_1", "accessory_2", "accessory_3"}
# qa/combat_policies.gd names these; `competent` is the 2026-08-12 default
# ruling and `dumb` exists only for instrument-comparison runs (§4).
COMBAT_POLICIES = {"competent", "dumb"}
# `interact` = stand adjacent and press; `proximity` = the ambush springs
# from a step into its trigger radius, so the walk is split around it.
FIGHT_ENTRIES = {"interact", "proximity"}
# `autoplay` is the default and stays it (2026-08-13 amendment): a fight whose
# COURSE is not the content hands the board to WICombatPolicies and pins only
# the outcome. `driven` is for the fights whose CHOREOGRAPHY is the content --
# the classless spar exists to fire tutor beats in order, and an autoplayed
# spar would prove nothing about them.
FIGHT_MODES = {"autoplay", "driven"}
# One turn-list entry names exactly one action. `where` is the only modifier,
# and only `await`/`logged` take it.
TURN_ACTIONS = {"press", "beat", "await", "logged", "pin", "settle", "shot", "autoplay"}
TURN_MODIFIERS = {"where"}
# What a hand-driven combat turn may press. Deliberately NOT the whole input
# map: `interact` and `journal` on a live board are how a driven turn desyncs
# from the script, and a walk `move` step is the overworld spelling -- the
# board takes `move_<dir>` presses.
COMBAT_PRESSES = (
    {"move_up", "move_down", "move_left", "move_right", "cycle", "confirm", "cancel", "end_turn"}
    | {f"hotbar_{index}" for index in range(1, 10)}
)
# The compiled-script raw budget (§3.2): raw is where corpus knowledge goes to
# hide, so it is capped rather than banned.
RAW_STEP_BUDGET = 0.02

# Primitives whose `choose_path` is a real fork and therefore owes a `why`
# (§3.4 CHOICE-LOG discipline at the language level).
FORK_PRIMITIVES = {"talk", "buy", "sell"}


class SchemaError(ValueError):
    pass


@dataclass(frozen=True)
class Node:
    id: str
    primitive: str
    spec: dict[str, Any]
    why: str
    act: str
    # Where this node was WRITTEN. The provenance failure loop (§5) reports a
    # red run as "node X, primitive Y, spec line Z" rather than as a raw driver
    # error, and a node id with no source line is only two thirds of that
    # answer. Empty when the document came from memory (detour fragments,
    # tests) rather than from a file.
    source_file: str = ""
    source_line: int = 0


@dataclass(frozen=True)
class Itinerary:
    acts: list[dict[str, Any]]
    nodes: list[Node]
    start: str | None = None
    # §8: the creation choreography is a fixed emitter prelude keyed by these
    # scalars. Mutually exclusive with `start` -- an itinerary either CREATES a
    # PC or loads one, and a document claiming both is asking the run to do two
    # incompatible things at the title screen.
    creation: dict[str, Any] | None = None


# The `creation:` scalars §8 names, plus the two the corpus actually needs:
# `name` (typed into the NAME step) and `tap_back` (the pointer-path round trip
# that the keyboard route never covers). `shots` names the album beats, because
# a fixed prelude cannot invent an album's naming scheme.
CREATION_KEYS = {"race", "gender", "name", "difficulty", "hints", "tap_back", "shots"}
CREATION_SHOT_SLOTS = {"gate", "menu", "picker", "name", "difficulty", "hints", "world"}


@dataclass(frozen=True)
class Detour:
    """An itinerary fragment with entry/exit map contracts (§8).

    Detours are not a second language: the `nodes` list is parsed by exactly
    the node validator the acts use. What a detour adds is the CONTRACT a
    planner matches against -- where it may be spliced in (`entry_map`), where
    it leaves the player (`exit_map`), what it is worth (`earns`), and the
    accomplishment state that makes it available at all.
    """

    id: str
    entry_map: str
    exit_map: str
    earns: tuple[int, int]
    requires: dict[str, int]
    forbids: dict[str, int]
    why: str
    nodes: list[Node]


DETOUR_KEYS = {"id", "entry", "exit", "earns", "requires", "forbids", "why", "nodes"}


def load_detour(path: str | Path) -> Detour:
    source = Path(path)
    try:
        raw = yaml.safe_load(source.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise SchemaError(f"could not read detour {source}: {exc}") from exc
    if not isinstance(raw, dict):
        raise SchemaError(f"detour {source} must be a mapping")
    unknown = sorted(set(raw) - DETOUR_KEYS)
    if unknown:
        raise SchemaError(f"detour {source} has unknown keys {unknown}")
    detour_id = str(raw.get("id", "")).strip()
    if not ID_RE.fullmatch(detour_id):
        raise SchemaError(f"detour {source} has an invalid id: {detour_id!r}")
    if detour_id != source.stem:
        raise SchemaError(f"detour {source} id {detour_id!r} must match its filename stem")
    why = str(raw.get("why", "")).strip()
    if not why:
        # A detour is an inserted CHOICE the author never wrote down, so it
        # owes the same provenance a `choose_path` does (§3.4).
        raise SchemaError(f"detour {detour_id} needs a why: it is spliced in without an author asking")
    entry_map = str((raw.get("entry") or {}).get("map", ""))
    exit_map = str((raw.get("exit") or {}).get("map", ""))
    if not entry_map or not exit_map:
        raise SchemaError(f"detour {detour_id} needs entry.map and exit.map")
    earns = raw.get("earns") or {}
    if not isinstance(earns, dict) or "min" not in earns or "max" not in earns:
        raise SchemaError(f"detour {detour_id} needs earns.min and earns.max")
    low, high = int(earns["min"]), int(earns["max"])
    if low > high:
        raise SchemaError(f"detour {detour_id} earns.min exceeds earns.max")
    nodes = _detour_nodes(detour_id, raw.get("nodes"))
    return Detour(
        id=detour_id,
        entry_map=entry_map,
        exit_map=exit_map,
        earns=(low, high),
        requires={str(key): int(value) for key, value in (raw.get("requires") or {}).items()},
        forbids={str(key): int(value) for key, value in (raw.get("forbids") or {}).items()},
        why=why,
        nodes=nodes,
    )


def _detour_nodes(detour_id: str, raw_nodes: Any) -> list[Node]:
    if not isinstance(raw_nodes, list) or not raw_nodes:
        raise SchemaError(f"detour {detour_id} needs a non-empty nodes list")
    # Reuse the act validator verbatim by wrapping the fragment in a
    # single-act document -- one node grammar, not two.
    document = load_itinerary_document([{"act": f"detour:{detour_id}", "nodes": raw_nodes}], milestone=2)
    return [
        Node(f"detour.{detour_id}.{node.id}", node.primitive, node.spec, node.why, node.act)
        for node in document.nodes
    ]


def load_itinerary(path: str | Path, milestone: int = 1) -> Itinerary:
    source = Path(path)
    try:
        text = source.read_text(encoding="utf-8")
        raw = yaml.safe_load(text)
    except (OSError, yaml.YAMLError) as exc:
        raise SchemaError(f"could not read itinerary {source}: {exc}") from exc
    document = load_itinerary_document(raw, milestone)
    lines = _id_lines(text)
    located = [
        Node(node.id, node.primitive, node.spec, node.why, node.act, str(source), lines.get(node.id, 0))
        for node in document.nodes
    ]
    return Itinerary(document.acts, located, document.start, document.creation)


ID_LINE_RE = re.compile(r"^\s*-?\s*id:\s*[\"']?([a-z0-9][a-z0-9._-]*)[\"']?\s*(?:#.*)?$")


def _id_lines(text: str) -> dict[str, int]:
    """Map every node id to the 1-based line that declares it.

    Read off the raw text rather than out of the parse tree because PyYAML's
    safe loader hands back plain dicts with no marks attached, and the two
    alternatives -- a mark-carrying custom loader, or a side table keyed on
    dict identity -- either pollute the mapping that the unknown-key check
    reads or depend on object lifetimes. Node ids are unique per document and
    the grammar for one is narrow, so the line is unambiguous.
    """
    found: dict[str, int] = {}
    for number, line in enumerate(text.splitlines(), start=1):
        match = ID_LINE_RE.match(line)
        if match is not None:
            found.setdefault(match.group(1), number)
    return found


def load_itinerary_document(raw: Any, milestone: int = 1) -> Itinerary:
    if not isinstance(raw, list) or not raw:
        raise SchemaError("itinerary root must be a non-empty list of acts")
    allowed = MILESTONE_PRIMITIVES.get(milestone)
    if allowed is None:
        raise SchemaError(f"unknown compiler milestone: {milestone}")

    seen: set[str] = set()
    nodes: list[Node] = []
    start: str | None = None
    creation: dict[str, Any] | None = None
    for act_index, act in enumerate(raw):
        if not isinstance(act, dict) or not str(act.get("act", "")).strip():
            raise SchemaError(f"act {act_index + 1} needs a non-empty act label")
        if act_index == 0 and act.get("start") is not None:
            start = str(act["start"])
        if act_index == 0 and act.get("creation") is not None:
            creation = _creation(act["creation"])
        if act_index and (act.get("start") is not None or act.get("creation") is not None):
            raise SchemaError(f"act {act['act']}: start/creation belong to the FIRST act -- a run has one opening")
        if start is not None and creation is not None:
            raise SchemaError(
                "an itinerary either creates a PC (`creation:`) or loads one (`start:`), not both -- "
                "the title screen cannot take New Game and Continue in the same run"
            )
        act_nodes = act.get("nodes")
        if not isinstance(act_nodes, list) or not act_nodes:
            raise SchemaError(f"act {act['act']} needs a non-empty nodes list")
        for node_index, raw_node in enumerate(act_nodes):
            if not isinstance(raw_node, dict):
                raise SchemaError(f"act {act['act']} node {node_index + 1} must be a mapping")
            node_id = str(raw_node.get("id", "")).strip()
            if not ID_RE.fullmatch(node_id):
                raise SchemaError(f"invalid node id: {node_id!r}")
            if node_id in seen:
                raise SchemaError(f"duplicate node id: {node_id}")
            seen.add(node_id)
            present = [key for key in PRIMITIVES if key in raw_node]
            if len(present) != 1:
                raise SchemaError(f"node {node_id} needs exactly one primitive, found {present}")
            primitive = present[0]
            if primitive not in allowed:
                raise SchemaError(f"primitive {primitive!r} is not available in M{milestone} (node {node_id})")
            spec = raw_node[primitive]
            if spec is None:
                spec = {}
            if not isinstance(spec, dict):
                raise SchemaError(f"node {node_id} {primitive} value must be a mapping")
            unknown = sorted(set(spec) - SPEC_KEYS[primitive])
            if unknown:
                raise SchemaError(f"node {node_id} {primitive} has unknown keys {unknown}")
            why = str(raw_node.get("why", spec.get("why", ""))).strip()
            if primitive in FORK_PRIMITIVES and spec.get("choose_path") and not why:
                raise SchemaError(f"node {node_id} choose_path requires an inline why")
            _validate_primitive(node_id, primitive, spec)
            nodes.append(Node(node_id, primitive, dict(spec), why, str(act["act"])))
    return Itinerary(list(raw), nodes, start, creation)


def _creation(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise SchemaError("creation: must be a mapping of scalars")
    unknown = sorted(set(raw) - CREATION_KEYS)
    if unknown:
        raise SchemaError(f"creation: has unknown keys {unknown}")
    for required in ("race", "gender", "name", "difficulty"):
        if not str(raw.get(required, "")).strip():
            raise SchemaError(f"creation: needs {required}")
    if not isinstance(raw.get("hints", True), bool):
        raise SchemaError("creation: hints must be boolean")
    if not isinstance(raw.get("tap_back", False), bool):
        raise SchemaError("creation: tap_back must be boolean")
    shots = raw.get("shots") or {}
    if not isinstance(shots, dict):
        raise SchemaError("creation: shots must be a mapping of slot -> screenshot name")
    unknown_slots = sorted(set(shots) - CREATION_SHOT_SLOTS)
    if unknown_slots:
        raise SchemaError(f"creation: shots has unknown slots {unknown_slots}; slots are {sorted(CREATION_SHOT_SLOTS)}")
    if any(not str(name).strip() for name in shots.values()):
        raise SchemaError("creation: every shots entry needs a screenshot name")
    return {
        "race": str(raw["race"]),
        "gender": str(raw["gender"]),
        "name": str(raw["name"]),
        "difficulty": str(raw["difficulty"]),
        "hints": bool(raw.get("hints", True)),
        "tap_back": bool(raw.get("tap_back", False)),
        "shots": {str(slot): str(name) for slot, name in shots.items()},
    }


def _validate_primitive(node_id: str, primitive: str, spec: dict[str, Any]) -> None:
    if primitive == "goto":
        if not str(spec.get("map", "")):
            raise SchemaError(f"node {node_id} goto needs map")
        if "cell" in spec and not _cell(spec["cell"]):
            raise SchemaError(f"node {node_id} goto cell must be [x, y] integers")
    elif primitive == "talk":
        if not str(spec.get("npc", "")):
            raise SchemaError(f"node {node_id} talk needs npc")
        _choose_path(node_id, spec)
    elif primitive == "sleep":
        if "expect_levels" in spec and not isinstance(spec["expect_levels"], bool):
            raise SchemaError(f"node {node_id} expect_levels must be boolean")
        merge = spec.get("expect_merge")
        if merge is not None and not (isinstance(merge, dict)
                and set(merge) == {"target", "level"}
                and isinstance(merge["target"], str) and isinstance(merge["level"], int)):
            raise SchemaError(f"node {node_id} expect_merge must be {{target, level}} -- #472 "
                "consolidation is automatic, so a plan DECLARES the merge, never answers for it")
    elif primitive == "fight":
        if not str(spec.get("encounter", "")):
            raise SchemaError(f"node {node_id} fight needs encounter")
        policy = str(spec.get("policy", "competent"))
        if policy not in COMBAT_POLICIES:
            raise SchemaError(f"node {node_id} fight policy must be one of {sorted(COMBAT_POLICIES)}")
        if str(spec.get("entry", "interact")) not in FIGHT_ENTRIES:
            raise SchemaError(f"node {node_id} fight entry must be one of {sorted(FIGHT_ENTRIES)}")
        # Only `victory` is plannable: a defeat leg reloads the save and every
        # downstream pin becomes fiction. Defeat coverage stays hand-written
        # (qa/scripts/defeat_reload.json).
        if str(spec.get("expect", "victory")) != "victory":
            raise SchemaError(f"node {node_id} fight expect must be victory (defeat legs are not compilable)")
        if "max_turns" in spec and not (isinstance(spec["max_turns"], int) and spec["max_turns"] > 0):
            raise SchemaError(f"node {node_id} fight max_turns must be a positive integer")
        shots = spec.get("shots", [])
        if not isinstance(shots, list) or any(not str(name).strip() for name in shots):
            raise SchemaError(f"node {node_id} fight shots must be a list of screenshot names")
        _fight_mode(node_id, spec)
    elif primitive in ("buy", "sell"):
        if not str(spec.get("vendor", "")):
            raise SchemaError(f"node {node_id} {primitive} needs vendor")
        if not str(spec.get("item", "")):
            raise SchemaError(f"node {node_id} {primitive} needs item")
        _choose_path(node_id, spec)
    elif primitive == "equip":
        if not str(spec.get("item", "")):
            raise SchemaError(f"node {node_id} equip needs item")
    elif primitive == "unequip":
        slot = str(spec.get("slot", ""))
        if slot not in EQUIP_SLOTS:
            raise SchemaError(f"node {node_id} unequip slot must be one of {sorted(EQUIP_SLOTS)}")
    elif primitive == "use_field":
        if not str(spec.get("skill", "")):
            raise SchemaError(f"node {node_id} use_field needs skill")
    elif primitive == "interact":
        if not str(spec.get("prop", "")):
            raise SchemaError(f"node {node_id} interact needs prop")
    elif primitive == "shot":
        if not str(spec.get("name", "")):
            raise SchemaError(f"node {node_id} shot needs name")
    elif primitive == "journal":
        # `capture` is optional by design -- the corpus opens the book once as
        # an album beat and once as a state reading -- but an EMPTY string is a
        # typo, not a choice, and would emit a nameless screenshot.
        if "capture" in spec and not str(spec["capture"]).strip():
            raise SchemaError(f"node {node_id} journal capture must be a screenshot name")
        if "act" in spec and not str(spec["act"]).strip():
            raise SchemaError(f"node {node_id} journal act must be an act id")
    elif primitive == "assert":
        state = spec.get("state", {})
        event = spec.get("event", {})
        absent = spec.get("event_absent", {})
        if not isinstance(state, dict) or not isinstance(event, dict) or not isinstance(absent, dict):
            raise SchemaError(f"node {node_id} assert state/event/event_absent must be mappings")
        if not state and not event and not absent:
            raise SchemaError(f"node {node_id} assert needs state, event, or event_absent")
        for label, payload in (("event", event), ("event_absent", absent)):
            if payload and not str(payload.get("type", "")):
                raise SchemaError(f"node {node_id} assert {label} needs a type")
    elif primitive == "detour":
        if not str(spec.get("id", "")):
            raise SchemaError(f"node {node_id} detour needs id")
    elif primitive == "raw":
        steps = spec.get("steps", [])
        if not isinstance(steps, list) or not steps or any(not isinstance(step, dict) for step in steps):
            raise SchemaError(f"node {node_id} raw needs a non-empty list of step mappings")
        if any(not str(step.get("action", "")) for step in steps):
            raise SchemaError(f"node {node_id} raw steps each need an action")


def _fight_mode(node_id: str, spec: dict[str, Any]) -> None:
    """Validate the 2026-08-13 `driven` mode and its turn list.

    The turn list is EXACT-CLASS in goldens (the design note says so), which
    means every entry has to name one unambiguous emitted step -- there is no
    room for a shape the emitter gets to interpret. So an entry is a mapping
    carrying exactly one action key, and the whole list is refused rather than
    partly understood.

    The one structural rule beyond that: a driven list must contain exactly one
    `autoplay` entry. Not zero -- a fight the script never finishes leaves the
    board open and eats every step after it, and the victory pin is the
    emitter's own guarantee, not something an author can forget. Not two --
    the second would wait for a `combat_finished` that already fired.
    """
    mode = str(spec.get("mode", "autoplay"))
    if mode not in FIGHT_MODES:
        raise SchemaError(f"node {node_id} fight mode must be one of {sorted(FIGHT_MODES)}")
    turns = spec.get("turns")
    if mode == "autoplay":
        if turns is not None:
            raise SchemaError(
                f"node {node_id} fight has turns but mode is autoplay -- a turn list the board never plays is a "
                "choreography nobody watches; set mode: driven"
            )
        return
    if spec.get("shots"):
        # Placement is the whole point of driven mode: `shots` has one fixed
        # slot (after the opening turn) and a driven fight's album beat is
        # usually somewhere else. A `shot:` turn entry says exactly where.
        raise SchemaError(
            f"node {node_id} driven fight uses `shot:` turn entries, not `shots:` -- the turn list is where "
            "placement is decided"
        )
    if not isinstance(turns, list) or not turns:
        raise SchemaError(f"node {node_id} fight mode: driven needs a non-empty turns list")
    autoplays = 0
    for index, entry in enumerate(turns):
        if not isinstance(entry, dict):
            raise SchemaError(f"node {node_id} turn {index + 1} must be a mapping")
        actions = sorted(set(entry) & TURN_ACTIONS)
        if len(actions) != 1:
            raise SchemaError(
                f"node {node_id} turn {index + 1} needs exactly one of {sorted(TURN_ACTIONS)}, found {actions}"
            )
        unknown = sorted(set(entry) - TURN_ACTIONS - TURN_MODIFIERS)
        if unknown:
            raise SchemaError(f"node {node_id} turn {index + 1} has unknown keys {unknown}")
        action = actions[0]
        if "where" in entry:
            if action not in ("await", "logged"):
                raise SchemaError(f"node {node_id} turn {index + 1}: `where` only qualifies await/logged")
            if not isinstance(entry["where"], dict) or not entry["where"]:
                raise SchemaError(f"node {node_id} turn {index + 1}: `where` must be a non-empty mapping")
        if action == "press":
            name = str(entry["press"])
            if name not in COMBAT_PRESSES:
                raise SchemaError(
                    f"node {node_id} turn {index + 1}: {name!r} is not a combat-board press "
                    f"({sorted(COMBAT_PRESSES)})"
                )
        elif action in ("beat", "await", "logged", "shot"):
            if not str(entry[action]).strip():
                raise SchemaError(f"node {node_id} turn {index + 1}: {action} needs a name")
        elif action == "settle":
            if not (isinstance(entry["settle"], int) and entry["settle"] > 0):
                raise SchemaError(f"node {node_id} turn {index + 1}: settle must be a positive frame count")
        elif action == "pin":
            pin = entry["pin"]
            if not isinstance(pin, dict) or not str(pin.get("path", "")).strip():
                raise SchemaError(f"node {node_id} turn {index + 1}: pin needs a path")
            if "equals" not in pin and "contains" not in pin:
                raise SchemaError(f"node {node_id} turn {index + 1}: pin needs equals or contains")
        elif action == "autoplay":
            if entry["autoplay"] is not True:
                raise SchemaError(
                    f"node {node_id} turn {index + 1}: write `autoplay: true` -- max_turns and policy are the "
                    "fight's, not the turn's"
                )
            autoplays += 1
    if autoplays != 1:
        raise SchemaError(
            f"node {node_id} driven fight has {autoplays} autoplay entries, needs exactly 1 -- the hand-driven "
            "turns are the opening choreography, and the board still has to finish and be pinned victorious"
        )


def _choose_path(node_id: str, spec: dict[str, Any]) -> None:
    path = spec.get("choose_path", [])
    if not isinstance(path, list) or any(not str(anchor).strip() for anchor in path):
        raise SchemaError(f"node {node_id} choose_path must be a list of labels or option text")


def _cell(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(isinstance(part, int) for part in value)

