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
# `from_start` is delivery-vs-order, not a different claim: the corpus pins a
# toast's RENDER with it wherever the render races a veil (v0.15 lesson --
# never pin toast order across a hold), and the compiler does the same.
IGNORED_KEYS = {"_itin", "_comment", "timeout_sec", "_bump", "from_start"}
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
    # #434 residue: ARRIVAL pins carry their cell in the key. `player_cell` is
    # equals-only (a cell subsumes nothing), so pairing by value cannot move a
    # legitimate tightening into the fatal class -- the objection that kept
    # values out of the key in M3.6 -- while it stops the matcher pairing an
    # arrival with whichever same-kind assert it reaches first (the source of
    # every net-class row in the Act I golden).
    if str(normalized.get("action", "")) == "assert_state" and str(normalized.get("path", "")) == "player_cell":
        cell = normalized.get("equals")
        if isinstance(cell, list):
            # JSON coordinates may parse as floats on one side (7.0) and ints
            # on the other (7); the key must not split on that (replay.py
            # normalizes the same way).
            cell = [int(part) for part in cell]
        parts.append(f"equals={json.dumps(cell, sort_keys=True)}")
    # The pinned VALUE stays out of the key for every path but one. Keying a
    # dict path (`classes`) by value would move a legitimate SUBSUMING
    # tightening (compiled `equals={a,b}` over shipped `equals={a}`) out of
    # the TIGHTER class into exact-class fatal -- the two keys stop matching
    # and the shipped row reads as a dropped claim -- which is policy, not
    # accounting (M3.6's finding). `player_cell` is the exception below: a
    # cell subsumes nothing, so its value can pair arrivals without touching
    # any class boundary. `IGNORED_KEYS` (`_bump` included) is stripped by
    # `_normalize` BEFORE this runs, so marks never reach a key either.
    return "|".join(parts)


def _is_bump(step: dict[str, Any]) -> bool:
    """A facing bump: a 1-step move the compiler marked as blocked."""
    moved = _as_move(step)
    return moved is not None and int(moved.get("steps", 1)) == 1 and bool(step.get("_bump", False))


def _strip_mirrored_bump(compiled_gap: list[dict[str, Any]], shipped_gap: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """The corpus bumps too (`right 12` then `right 1` before Relc, `up 1`
    before a door) but never marks it. When the COMPILED gap ends in a marked
    bump and the shipped gap ends in a 1-step move, that move is the corpus's
    bump: drop it from the shipped net. Symmetric by construction -- the
    compiled side's knowledge is what licenses discounting the shipped step,
    so a real 1-step arrival on the shipped side is never discounted unless
    the compiler bumped at the same anchor (#434 residue)."""
    if not compiled_gap or not shipped_gap or not _is_bump(compiled_gap[-1]):
        return shipped_gap
    last = _as_move(shipped_gap[-1])
    if last is None:
        return shipped_gap
    if int(last.get("steps", 1)) == 1:
        return shipped_gap[:-1]
    # The corpus also MERGES a bump into the walk that precedes it (`right 2`
    # before the south-square scavengers: one step onto the cell, one into
    # the encounter). Same licence, same direction: discount one step.
    if str(last.get("direction", "")) != str(compiled_gap[-1].get("direction", "")):
        return shipped_gap
    shortened = dict(shipped_gap[-1])
    shortened["steps"] = int(last.get("steps", 1)) - 1
    candidate = shipped_gap[:-1] + [shortened]
    # Only when the discount is what reconciles the two arrivals: a walk that
    # ends ON the stand cell already facing the target (`up 10` to Krshia's
    # counter) merged nothing, and discounting it would hide a real drift.
    return candidate if _net(candidate) == _net(compiled_gap) else shipped_gap


def _net(steps: list[dict[str, Any]]) -> tuple[int, int]:
    dx = dy = 0
    for step in steps:
        moved = _as_move(step)
        if moved is None:
            continue
        if _is_bump(step):
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

    opcodes = _align([_key(step) for step in compiled_spine], [_key(step) for step in shipped_spine])
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
    for tag, c_lo, c_hi, s_lo, s_hi in opcodes:
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
        # ONE reclassification (#434 Act II): a shipped `assert_event_logged`
        # whose event a compiled `wait_for_event` of the same type claims with
        # a payload that subsumes it is not dropped -- an ordered wait is the
        # STRONGER claim about the same event.
        for index in range(s_lo, s_hi):
            pending_shipped.extend(shipped_gaps[index])
            shipped_step = shipped_spine[index]
            if _wait_subsumes_logged_assert(compiled_steps, shipped_step):
                report.tighter.append(f"logged-assert covered by an ordered wait: {_describe(shipped_step)}")
                continue
            report.exact.append(
                f"shipped-only step (compiler dropped this claim): {_describe(shipped_step)}"
            )
    return report


# Alignment weights: what a paired spine step is WORTH. difflib's
# longest-block-first heuristic (Ratcliff/Obershelp) was the M3.6 matcher; it
# re-paired Selys' delivery with Olesm's brief the moment Act II grew a
# compiled-only arrival pin between them, because an insertion splits the
# longest block and the recursion then anchors on whichever same-key run is
# longest elsewhere. A longest-common-subsequence over the same coarse keys
# has no such cliff: every extra insertion costs exactly its own row. The
# weights keep a named shot or a valued arrival pin from being traded away
# for a run of `press confirm` pairings of equal count.
_HEAVY_KEY_MARKS = ("screenshot|", "equals=", "type=map_changed", "type=combat_started", "type=dialogue_started")


def _weight(key: str) -> int:
    if any(mark in key for mark in _HEAVY_KEY_MARKS):
        return 4
    if key.startswith("wait_for_event") or key.startswith("assert_"):
        return 2
    return 1


def _align(compiled_keys: list[str], shipped_keys: list[str]) -> list[tuple[str, int, int, int, int]]:
    """difflib-shaped opcodes from a weighted LCS: `equal` blocks pair one
    compiled spine step with one shipped step of the same key; the runs
    between two blocks come back as `replace`/`delete`/`insert` exactly the
    way `SequenceMatcher.get_opcodes()` spelled them, so the accounting
    below reads either matcher unchanged."""
    n, m = len(compiled_keys), len(shipped_keys)
    # score[i][j] = best weight aligning compiled[i:] with shipped[j:].
    score = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n - 1, -1, -1):
        row, below = score[i], score[i + 1]
        key = compiled_keys[i]
        weight = _weight(key)
        for j in range(m - 1, -1, -1):
            best = below[j] if below[j] >= row[j + 1] else row[j + 1]
            if key == shipped_keys[j]:
                diagonal = below[j + 1] + weight
                if diagonal > best:
                    best = diagonal
            row[j] = best
    pairs: list[tuple[int, int]] = []
    i = j = 0
    while i < n and j < m:
        if compiled_keys[i] == shipped_keys[j] and score[i][j] == score[i + 1][j + 1] + _weight(compiled_keys[i]):
            pairs.append((i, j))
            i += 1
            j += 1
        elif score[i + 1][j] >= score[i][j + 1]:
            i += 1
        else:
            j += 1
    opcodes: list[tuple[str, int, int, int, int]] = []
    c_prev = s_prev = 0

    def flush(c_hi: int, s_hi: int) -> None:
        nonlocal c_prev, s_prev
        if c_hi > c_prev and s_hi > s_prev:
            opcodes.append(("replace", c_prev, c_hi, s_prev, s_hi))
        elif c_hi > c_prev:
            opcodes.append(("delete", c_prev, c_hi, s_prev, s_prev))
        elif s_hi > s_prev:
            opcodes.append(("insert", c_prev, c_prev, s_prev, s_hi))
        c_prev, s_prev = c_hi, s_hi

    for ci, si in pairs:
        flush(ci, si)
        if opcodes and opcodes[-1][0] == "equal" and opcodes[-1][2] == ci and opcodes[-1][4] == si:
            tag, c_lo, _, s_lo, _ = opcodes[-1]
            opcodes[-1] = (tag, c_lo, ci + 1, s_lo, si + 1)
        else:
            opcodes.append(("equal", ci, ci + 1, si, si + 1))
        c_prev, s_prev = ci + 1, si + 1
    flush(n, m)
    return opcodes


def _wait_subsumes_logged_assert(compiled_steps: list[dict[str, Any]], shipped_step: dict[str, Any]) -> bool:
    if str(shipped_step.get("action", "")) != "assert_event_logged":
        return False
    wanted = _normalize(shipped_step)
    for step in compiled_steps:
        if str(step.get("action", "")) != "wait_for_event" or str(step.get("type", "")) != str(wanted.get("type", "")):
            continue
        if _subsumes(step.get("payload_contains", {}), wanted.get("payload_contains", {})):
            return True
    return False


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
    shipped_gap = _strip_mirrored_bump(compiled_gap, shipped_gap)
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
