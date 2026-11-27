#!/usr/bin/env python3
"""Compare sim_combat_batch legs cell by cell (rested vs WI_ENTRY_FRACTION legs).

    python3 scripts/harness_entry_report.py rested=a.log 0.75=b.log 0.50=c.log [--baseline rested]

Prints a markdown table of every `[family / cell] ... win_rate=` line, ordered
by the largest drop from the baseline leg, plus a summary per leg.
"""

from __future__ import annotations

import re
import statistics
import sys

CELL = re.compile(r"^\[([^\]]+)\](.*?)win_rate=([0-9.]+)")
BUILD = re.compile(r"build=(\S+)")


def parse(path: str) -> dict[str, dict]:
	cells: dict[str, dict] = {}
	for line in open(path, encoding="utf-8"):
		match = CELL.match(line)
		if match:
			build = BUILD.search(match.group(2))
			cells[match.group(1)] = {"rate": float(match.group(3)), "measured": "(measured)" in match.group(2),
				"build": build.group(1) if build else match.group(1).split(" / ")[-1]}
	return cells


def report(legs: dict[str, dict[str, dict]], baseline: str) -> str:
	base = legs[baseline]
	names = list(legs)
	others = [n for n in names if n != baseline]
	order = sorted(base, key=lambda cell: min(legs[n].get(cell, {"rate": 0})["rate"] for n in others) - base[cell]["rate"]) if others else sorted(base)
	lines = ["| Cell | Build | " + " | ".join(names) + " |", "|---|---|" + "---|" * len(names)]
	for cell in order:
		rates = [f"{legs[n][cell]['rate']:.2f}" if cell in legs[n] else "-" for n in names]
		tag = " (measured)" if base[cell]["measured"] else ""
		lines.append(f"| {cell}{tag} | {base[cell]['build']} | " + " | ".join(rates) + " |")
	lines.append("")
	for name in names:
		shared = [c for c in base if c in legs[name]]
		drop = statistics.mean(base[c]["rate"] - legs[name][c]["rate"] for c in shared) if shared else 0.0
		below = sum(1 for c in shared if legs[name][c]["rate"] < 0.55)
		lines.append(f"- **{name}:** {len(legs[name])} cells; mean drop vs {baseline} {drop:.3f}; cells below 0.55: {below}.")
	return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
	baseline = None
	legs: dict[str, dict[str, dict]] = {}
	args = list(argv)
	if "--baseline" in args:
		index = args.index("--baseline")
		baseline = args[index + 1]
		del args[index:index + 2]
	for arg in args:
		label, _, path = arg.partition("=")
		legs[label] = parse(path)
	if not legs:
		print(__doc__)
		return 2
	sys.stdout.write(report(legs, baseline or next(iter(legs))))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
