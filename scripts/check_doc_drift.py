#!/usr/bin/env python3
"""Cheap structural checks for agent-facing documentation."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
	errors: list[str] = []
	doc_map = ROOT / "docs" / "DOC-MAP.md"
	if not doc_map.exists() or "Last verified: **2026-08-10**" not in doc_map.read_text():
		errors.append("docs/DOC-MAP.md missing its verified-date marker")

	# docs/ROADMAP.md UN-RETIRED 2026-07-17: recreated deliberately as the
	# living milestone doc (roadmap-ownership directive); it was retired when
	# planning moved to GitHub issues, but issue boards don't hold the
	# next-release SHAPE -- the roadmap does.
	for retired in (
		"GOAL-CHAIN.md",
		"docs/FULL-GAME-PLAYTEST.md",
		"docs/superpowers/successor-briefs",
		"docs/archive/HANDOVER-FABLE-TO-OPUS-2026-07-02.md",
	):
		path = ROOT / retired
		if path.is_file() or (path.is_dir() and any(child.is_file() for child in path.rglob("*"))):
			errors.append(f"retired documentation still present: {retired}")

	readme = (ROOT / "README.md").read_text()
	if "https://gabrielglevine.github.io/wandering-inn-rpg/" not in readme:
		errors.append("README.md missing the live GitHub Pages demo URL")
	if "[▶ Play the demo](#)" in readme:
		errors.append("README.md still carries the placeholder demo link")

	retired_references = (
		"GOAL-CHAIN.md",
		"FULL-GAME-PLAYTEST.md",
		"successor-briefs",
		"HANDOVER-FABLE-TO-OPUS-2026-07-02.md",
	)
	live_docs = [
		ROOT / "AGENTS.md",
		ROOT / "HANDOFF.md",
		ROOT / "docs" / "DOC-MAP.md",
		ROOT / "docs" / "README.md",
		ROOT / "wandering_inn_game" / "AGENTS.md",
		ROOT / "wandering_inn_game" / "qa" / "MACHINE-PLAYTEST.md",
	]
	live_docs.extend(sorted((ROOT / ".agents" / "skills").glob("*/SKILL.md")))
	live_docs.extend(sorted((ROOT / "docs" / "design").glob("*.md")))
	for folder in ("plans", "specs"):
		for path in sorted((ROOT / "docs" / "superpowers" / folder).glob("*.md")):
			header = "\n".join(path.read_text().splitlines()[:8])
			if "> Status: **ACTIVE" in header:
				live_docs.append(path)
	for path in live_docs:
		text = path.read_text()
		for retired in retired_references:
			if retired in text:
				errors.append(f"live documentation references retired {retired}: {path.relative_to(ROOT)}")

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
