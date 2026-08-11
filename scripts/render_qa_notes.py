#!/usr/bin/env python3
"""Render the canonical QA inventory from qa/manifest.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "wandering_inn_game" / "qa" / "manifest.json"
OUTPUT = ROOT / "wandering_inn_game" / "docs" / "QA-SCRIPT-NOTES.md"


def _cell(value: object) -> str:
	return str(value).replace("|", "\\|").replace("\n", " ")


def render() -> str:
	data = json.loads(MANIFEST.read_text())
	rows = []
	for entry in data["scripts"]:
		seed = "none" if entry.get("seed") is None else entry["seed"]
		fixture = entry.get("fixture", "—")
		tiers = ", ".join(entry["tiers"])
		rows.append(
			f"| `{_cell(entry['script'])}` | {_cell(seed)} | {_cell(tiers)} | "
			f"`{_cell(fixture)}` | {_cell(entry['note'])} |"
		)
	return "\n".join([
		"# QA Script Notes",
		"",
		"> Generated from `qa/manifest.json` by `scripts/render_qa_notes.py`; do not edit by hand.",
		"",
		f"This is the human index for all {len(rows)} canonical QA scripts. The manifest is the",
		"source of truth for seed, tier, fixture, purpose, and derived surfaces; each",
		"`qa/scripts/<name>.json` is the source of truth for its exact route and assertions.",
		"",
		"| script | seed | tiers | fixture | purpose |",
		"|---|---:|---|---|---|",
		*rows,
		"",
	])


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--write", action="store_true", help="replace the generated inventory")
	args = parser.parse_args()
	expected = render()
	if args.write:
		OUTPUT.write_text(expected)
	if not OUTPUT.exists() or OUTPUT.read_text() != expected:
		print("QA NOTES DRIFT")
		print("Run: python3 scripts/render_qa_notes.py --write")
		return 1
	print("PASS: QA notes match manifest")
	return 0


if __name__ == "__main__":
	sys.exit(main())
