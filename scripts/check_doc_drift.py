#!/usr/bin/env python3
"""Cheap structural checks for agent-facing documentation."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
	errors: list[str] = []
	doc_map = ROOT / "docs" / "DOC-MAP.md"
	if not doc_map.exists() or "Last verified: **2026-07-13**" not in doc_map.read_text():
		errors.append("docs/DOC-MAP.md missing its verified-date marker")

	for plan in sorted((ROOT / "docs" / "superpowers" / "plans").glob("*.md")):
		header = "\n".join(plan.read_text().splitlines()[:8])
		if "> Status: **DONE**" not in header and "> Status: **ACTIVE**" not in header:
			errors.append(f"plan lacks DONE/ACTIVE header: {plan.relative_to(ROOT)}")

	stub = ROOT / "docs" / "design" / "character-profiles-staging.md"
	if not stub.exists() or len(stub.read_text().splitlines()) > 20:
		errors.append("character-profiles-staging.md must remain a pointer stub")

	if errors:
		print("DOCUMENTATION DRIFT")
		for error in errors:
			print(f"- {error}")
		return 1
	print("PASS: documentation structure")
	return 0


if __name__ == "__main__":
	sys.exit(main())
