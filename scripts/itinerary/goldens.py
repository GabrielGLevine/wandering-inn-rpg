"""Golden corpus diff: compiled script vs shipped script, under tolerance (§6.3).

Byte-identity is the wrong bar and the design says so. Two scripts can be the
same PLAYTHROUGH while differing in how a walk was split into run-length
`move` steps, in how long a wait is willing to sit there, or in the prose of a
`_comment`. What they may NOT differ in is what the run asserts, what it
presses, what it screenshots, and where it ends up.

So the diff sorts every difference into three buckets:

  EXACT      asserts, presses, event waits and their payload pins, screenshot
             names, combat autoplay policy. Any divergence here fails the
             golden -- these are the script's claims about the game.
  NET        the destination a run of `move` steps arrives at (walk endpoint,
             menu cursor index). §6.3 allows a different ROUTE between two
             anchors; it does not allow a different ARRIVAL, because the
             arrival is what the next press acts on.
  TOLERANCE  everything left: how a walk was split, wait timeouts, settle
             frames, comment text, `_itin` stamps. Reported, never fatal.

Pins may be TIGHTER on the compiled side and never looser (§6.3). A compiled
`wait_for_event` whose `payload_contains` is a superset of the shipped one is
a tightening and passes; a subset is a loosening and fails. An extra compiled
assert is a tightening; a shipped assert with no compiled counterpart is a
claim the compiler dropped, and fails.

The allowance EXTENDS to a compiled-only `wait_for_event` (user ruling,
2026-08-14). Such a wait is strictly stricter and it cannot hide: if the event
never fires the run does not finish, and `ITINERARY_RUN_GREEN` gates that. The
asymmetry is the whole safety property -- the compiler may claim MORE, never
less. So a compiled-only step of any OTHER action is still extra behaviour and
still exact-class fatal, and a SHIPPED-only step of any action at all is a
dropped claim and stays fatal in every case. Reclassified rows are not waved
through silently: each one is logged individually, untruncated, in its own
report block, so a reader can audit exactly what the allowance absorbed.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import difflib
import json
from pathlib import Path
from typing import Any


# Steps whose SHAPE is tolerance-class. Their net effect is still checked --
# see `_net` -- but how they were split is not the compiler's promise.
TOLERANCE_ACTIONS = {"move", "wait_frames"}
# A cursor can be walked two ways and the corpus uses both: `move {direction,
# steps: N}` and N repeats of `press {name: move_N}` reach the same row. §6.3
# puts cursor PATHS in tolerance, so the diff normalizes the press spelling
# into the move spelling rather than reading it as a different claim -- what
# the run then acts on is the row it lands on, and that is the net.
CURSOR_PRESSES = {"move_up": "up", "move_down": "down", "move_left": "left", "move_right": "right"}
# Keys that never carry a claim about the game.
IGNORED_KEYS = {"_itin", "_comment", "timeout_sec"}
# Compiled-only steps that are pure TIGHTENING rather than extra behaviour.
ASSERT_ACTIONS = {"assert_state", "assert_event_logged", "assert_event_absent", "assert_event_count"}
# The one action the 2026-08-14 ruling adds to that set. Kept separate from
# ASSERT_ACTIONS because its rows are logged in their own report block: the
# ruling permits them, it does not make them invisible. NEVER widen this to a
# state-CHANGING action -- a compiled-only `press` is extra behaviour, not a
# stricter claim about the same run.
TIGHTENING_WAIT_ACTION = "wait_for_event"

DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}


@dataclass
class GoldenDiff:
    exact: list[str] = field(default_factory=list)
    net: list[str] = field(default_factory=list)
    tolerance: list[str] = field(default_factory=list)
    tighter: list[str] = field(default_factory=list)
    # Compiled-only `wait_for_event` rows the 2026-08-14 ruling moved out of
    # exact-class. Its own list, its own counted line, its own untruncated
    # block -- an allowance that stopped being auditable is a hole.
    tightened_waits: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not self.exact and not self.net

    def summary(self) -> str:
        verdict = "GOLDEN PASS (within tolerance)" if self.passed else "GOLDEN FAIL"
        return (
            f"{verdict}: {len(self.exact)} exact-class, {len(self.net)} net-class, "
            f"{len(self.tolerance)} tolerance-class, {len(self.tighter)} tightening(s), "
            f"{len(self.tightened_waits)} compiled-only wait(s) reclassified"
        )

    def render(self, limit: int = 40) -> str:
        blocks = [self.summary()]
        # `None` = never truncate. The reclassified waits are the one block a
        # reader is being asked to audit, so a `... and N more` tail there
        # would defeat the point of logging them.
        for label, rows, cap in (
            ("EXACT (fatal)", self.exact, limit),
            ("NET (fatal)", self.net, limit),
            ("TIGHTER: compiled-only waits, reclassified per the 2026-08-14 ruling", self.tightened_waits, None),
            ("TIGHTER (allowed)", self.tighter, limit),
            ("TOLERANCE (allowed)", self.tolerance, limit),
        ):
            if not rows:
                continue
            shown = rows if cap is None else rows[:cap]
            body = "\n".join(f"  {row}" for row in shown)
            if cap is not None and len(rows) > cap:
                body += f"\n  ... and {len(rows) - cap} more"
            blocks.append(f"{label}: {len(rows)}\n{body}")
        return "\n\n".join(blocks)


def _as_move(step: dict[str, Any]) -> dict[str, Any] | None:
    """The step as a cursor/walk move, in the one spelling the diff compares."""
    action = str(step.get("action", ""))
    if action == "move":
        return step
    if action == "press" and str(step.get("name", "")) in CURSOR_PRESSES:
        return {"action": "move", "direction": CURSOR_PRESSES[str(step["name"])], "steps": 1}
    return None


def _significant(step: dict[str, Any]) -> bool:
    if str(step.get("action", "")) in TOLERANCE_ACTIONS:
        return False
    return _as_move(step) is None


def _normalize(step: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in step.items() if key not in IGNORED_KEYS}


def _key(step: dict[str, Any]) -> str:
    """A coarse identity for alignment: what KIND of claim this step makes."""
    normalized = _normalize(step)
    parts = [str(normalized.get("action", ""))]
    for field_name in ("type", "path", "name", "skill", "slot", "label"):
        if field_name in normalized:
            parts.append(f"{field_name}={normalized[field_name]}")
    # NOT included: the pinned VALUE. Every `assert_state player_cell` is
    # therefore the same alignment token, and the matcher can pair an arrival
    # with whichever one it reaches first -- a real weakness, and the reason
    # two net-class rows in the M3.6 golden report an arrival difference for a
    # leg whose compiled walk is step-for-step the corpus walk. Adding the
    # value fixes that pairing, and M3.6 tried it: it also moves a legitimate
    # SUBSUMING tightening (compiled `equals={a,b}` over shipped `equals={a}`)
    # out of the TIGHTER class and into exact-class fatal, because the two keys
    # stop matching and the shipped row reads as a dropped claim. That is a
    # change to which class is fatal -- policy, not accounting -- so it was
    # reverted rather than shipped inside the milestone it gates.
    return "|".join(parts)


def _net(steps: list[dict[str, Any]]) -> tuple[int, int]:
    dx = dy = 0
    for step in steps:
        moved = _as_move(step)
        if moved is None:
            continue
        vector = DIRECTIONS.get(str(moved.get("direction", "")))
        if vector is None:
            continue
        count = int(moved.get("steps", 1))
        dx += vector[0] * count
        dy += vector[1] * count
    return dx, dy


def _subsumes(compiled: Any, shipped: Any) -> bool:
    """True when `compiled` claims everything `shipped` does, and maybe more."""
    if isinstance(shipped, dict):
        if not isinstance(compiled, dict):
            return False
        return all(key in compiled and _subsumes(compiled[key], value) for key, value in shipped.items())
    if isinstance(shipped, list):
        if not isinstance(compiled, list) or len(compiled) != len(shipped):
            return False
        return all(_subsumes(left, right) for left, right in zip(compiled, shipped))
    return compiled == shipped


def _describe(step: dict[str, Any]) -> str:
    node = str(step.get("_itin", ""))
    body = json.dumps(_normalize(step), ensure_ascii=False, sort_keys=True)
    return f"[{node or '-'}] {body}" if len(body) <= 220 else f"[{node or '-'}] {body[:217]}..."


def _describe_wait(step: dict[str, Any], index: int) -> str:
    """A reclassified wait, spelled so nothing about it can be hidden.

    `_describe` truncates at 220 chars and sorts keys, which puts `type` AFTER
    a long `payload_contains` and drops it off the end -- the audit's most
    load-bearing field, gone. So the event type leads, the payload shape
    follows in full, and the compiled step index says where to go look.
    """
    body = _normalize(step)
    body.pop("action", None)
    event = str(body.pop("type", "?"))
    payload = body.pop("payload_contains", None)
    shape = "no payload pin" if payload is None else f"payload_contains={json.dumps(payload, ensure_ascii=False, sort_keys=True)}"
    node = str(step.get("_itin", "")) or "-"
    rest = f" {json.dumps(body, ensure_ascii=False, sort_keys=True)}" if body else ""
    return f"compiled step {index} [{node}] wait_for_event type={event} {shape}{rest}"


def diff(compiled: dict[str, Any], shipped: dict[str, Any]) -> GoldenDiff:
    report = GoldenDiff()
    compiled_steps = list(compiled.get("steps", []))
    shipped_steps = list(shipped.get("steps", []))

    for key in ("fixture_save", "starts_at_title", "creation_ui"):
        left, right = compiled.get(key), shipped.get(key)
        if left != right:
            report.exact.append(f"script root {key}: compiled {left!r}, shipped {right!r}")

    # The tolerance-class steps between two significant ones are that gap's
    # ROUTE; the significant steps themselves are the spine the diff aligns on.
    compiled_spine, compiled_gaps, compiled_at = _split(compiled_steps)
    shipped_spine, shipped_gaps, _ = _split(shipped_steps)

    matcher = difflib.SequenceMatcher(
        None, [_key(step) for step in compiled_spine], [_key(step) for step in shipped_spine], autojunk=False
    )
    # A gap is the walk/cursor run BEFORE a spine step, and an UNMATCHED spine
    # step splits one side's gap without splitting the other's. That is an
    # accounting artifact, not an arrival difference: a compiled-only
    # `assert_state player_cell` inserted mid-walk pins where the leg landed
    # and moves nobody. So an unmatched step's gap is carried forward into the
    # next matched anchor, where the two sides are comparable again -- without
    # this, every allowed TIGHTENING inside a walk reported as a net-class
    # fatal, which would make §6.3's "pins may be tighter" untrue in practice.
    pending_compiled: list[dict[str, Any]] = []
    pending_shipped: list[dict[str, Any]] = []
    for tag, c_lo, c_hi, s_lo, s_hi in matcher.get_opcodes():
        if tag == "equal":
            for offset in range(c_hi - c_lo):
                anchor = compiled_spine[c_lo + offset]
                _compare_pair(report, anchor, shipped_spine[s_lo + offset])
                _compare_gap(
                    report,
                    pending_compiled + compiled_gaps[c_lo + offset],
                    pending_shipped + shipped_gaps[s_lo + offset],
                    anchor,
                )
                pending_compiled, pending_shipped = [], []
            continue
        for index in range(c_lo, c_hi):
            step = compiled_spine[index]
            pending_compiled.extend(compiled_gaps[index])
            action = str(step.get("action", ""))
            if action in ASSERT_ACTIONS:
                report.tighter.append(f"compiled-only assert: {_describe(step)}")
            elif action == TIGHTENING_WAIT_ACTION:
                report.tightened_waits.append(_describe_wait(step, compiled_at[index]))
            else:
                report.exact.append(f"compiled-only step (shipped has no counterpart): {_describe(step)}")
        # The other direction is NOT symmetric and must never be made so: a
        # shipped-only `wait_for_event` is a claim the compiler stopped making.
        for index in range(s_lo, s_hi):
            pending_shipped.extend(shipped_gaps[index])
            report.exact.append(
                f"shipped-only step (compiler dropped this claim): {_describe(shipped_spine[index])}"
            )
    return report


def _split(
    steps: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[list[dict[str, Any]]], list[int]]:
    """Spine of significant steps, the tolerance run BEFORE each, and where each sat.

    The third list is the spine step's index in the ORIGINAL script, kept only
    so a reported row can name the step a reader should open.
    """
    spine: list[dict[str, Any]] = []
    gaps: list[list[dict[str, Any]]] = []
    at: list[int] = []
    pending: list[dict[str, Any]] = []
    for index, step in enumerate(steps):
        if _significant(step):
            spine.append(step)
            gaps.append(pending)
            at.append(index)
            pending = []
        else:
            pending.append(step)
    return spine, gaps, at


def _compare_pair(report: GoldenDiff, compiled: dict[str, Any], shipped: dict[str, Any]) -> None:
    left, right = _normalize(compiled), _normalize(shipped)
    if left == right:
        return
    if _subsumes(left, right):
        report.tighter.append(
            f"tighter pin: {_describe(compiled)}  (shipped: "
            f"{json.dumps(right, ensure_ascii=False, sort_keys=True)})"
        )
        return
    report.exact.append(
        f"{_describe(compiled)}  !=  shipped {json.dumps(right, ensure_ascii=False, sort_keys=True)}"
    )


def _compare_gap(
    report: GoldenDiff,
    compiled_gap: list[dict[str, Any]],
    shipped_gap: list[dict[str, Any]],
    anchor: dict[str, Any],
) -> None:
    node = str(anchor.get("_itin", "")) or "-"
    compiled_net, shipped_net = _net(compiled_gap), _net(shipped_gap)
    if compiled_net != shipped_net:
        report.net.append(
            f"[{node}] walk/cursor arrives at a different place before {_key(anchor)}: "
            f"compiled net {compiled_net}, shipped net {shipped_net}"
        )
        return
    if compiled_gap != shipped_gap:
        c_moves = sum(1 for step in compiled_gap if _as_move(step) is not None)
        s_moves = sum(1 for step in shipped_gap if _as_move(step) is not None)
        c_frames = sum(int(step.get("frames", 0)) for step in compiled_gap if step.get("action") == "wait_frames")
        s_frames = sum(int(step.get("frames", 0)) for step in shipped_gap if step.get("action") == "wait_frames")
        detail = []
        if c_moves != s_moves:
            detail.append(f"{c_moves} move steps vs {s_moves} (same net {compiled_net})")
        if c_frames != s_frames:
            detail.append(f"{c_frames} settle frames vs {s_frames}")
        if detail:
            report.tolerance.append(f"[{node}] before {_key(anchor)}: " + "; ".join(detail))


def diff_files(compiled_path: str | Path, shipped_path: str | Path) -> GoldenDiff:
    compiled = json.loads(Path(compiled_path).read_text(encoding="utf-8"))
    shipped = json.loads(Path(shipped_path).read_text(encoding="utf-8"))
    return diff(compiled, shipped)


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Tolerance diff a compiled script against a shipped golden")
    parser.add_argument("compiled", type=Path)
    parser.add_argument("shipped", type=Path)
    parser.add_argument("--limit", type=int, default=40)
    args = parser.parse_args(argv)
    report = diff_files(args.compiled, args.shipped)
    print(report.render(args.limit))
    return 0 if report.passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
