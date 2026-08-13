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

DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}


@dataclass
class GoldenDiff:
    exact: list[str] = field(default_factory=list)
    net: list[str] = field(default_factory=list)
    tolerance: list[str] = field(default_factory=list)
    tighter: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not self.exact and not self.net

    def summary(self) -> str:
        verdict = "GOLDEN PASS (within tolerance)" if self.passed else "GOLDEN FAIL"
        return (
            f"{verdict}: {len(self.exact)} exact-class, {len(self.net)} net-class, "
            f"{len(self.tolerance)} tolerance-class, {len(self.tighter)} tightening(s)"
        )

    def render(self, limit: int = 40) -> str:
        blocks = [self.summary()]
        for label, rows in (
            ("EXACT (fatal)", self.exact),
            ("NET (fatal)", self.net),
            ("TIGHTER (allowed)", self.tighter),
            ("TOLERANCE (allowed)", self.tolerance),
        ):
            if not rows:
                continue
            shown = rows[:limit]
            body = "\n".join(f"  {row}" for row in shown)
            if len(rows) > limit:
                body += f"\n  ... and {len(rows) - limit} more"
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
    compiled_spine, compiled_gaps = _split(compiled_steps)
    shipped_spine, shipped_gaps = _split(shipped_steps)

    matcher = difflib.SequenceMatcher(
        None, [_key(step) for step in compiled_spine], [_key(step) for step in shipped_spine], autojunk=False
    )
    for tag, c_lo, c_hi, s_lo, s_hi in matcher.get_opcodes():
        if tag == "equal":
            for offset in range(c_hi - c_lo):
                _compare_pair(report, compiled_spine[c_lo + offset], shipped_spine[s_lo + offset])
                _compare_gap(
                    report,
                    compiled_gaps[c_lo + offset],
                    shipped_gaps[s_lo + offset],
                    compiled_spine[c_lo + offset],
                )
            continue
        for step in compiled_spine[c_lo:c_hi]:
            if str(step.get("action", "")) in ASSERT_ACTIONS:
                report.tighter.append(f"compiled-only assert: {_describe(step)}")
            else:
                report.exact.append(f"compiled-only step (shipped has no counterpart): {_describe(step)}")
        for step in shipped_spine[s_lo:s_hi]:
            report.exact.append(f"shipped-only step (compiler dropped this claim): {_describe(step)}")
    return report


def _split(steps: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[list[dict[str, Any]]]]:
    """Spine of significant steps, plus the tolerance-class run BEFORE each."""
    spine: list[dict[str, Any]] = []
    gaps: list[list[dict[str, Any]]] = []
    pending: list[dict[str, Any]] = []
    for step in steps:
        if _significant(step):
            spine.append(step)
            gaps.append(pending)
            pending = []
        else:
            pending.append(step)
    return spine, gaps


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
