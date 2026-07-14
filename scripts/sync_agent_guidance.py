#!/usr/bin/env python3
"""Generate or check provider adapters from model-neutral agent guidance."""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_SKILLS = ROOT / ".agents" / "skills"
CLAUDE_SKILLS = ROOT / ".claude" / "skills"


def skill_files(root: Path) -> list[Path]:
	return sorted(path.relative_to(root) for path in root.glob("*/SKILL.md"))


def check() -> int:
	errors: list[str] = []
	canonical = skill_files(CANONICAL_SKILLS)
	mirror = skill_files(CLAUDE_SKILLS)
	if canonical != mirror:
		errors.append("skill file sets differ")
	for rel in sorted(set(canonical) & set(mirror)):
		if not filecmp.cmp(CANONICAL_SKILLS / rel, CLAUDE_SKILLS / rel, shallow=False):
			errors.append(f"skill mirror drift: {rel}")
	for adapter, target in ((ROOT / "CLAUDE.md", "AGENTS.md"),
		(ROOT / "wandering_inn_game" / "CLAUDE.md", "AGENTS.md")):
		text = adapter.read_text()
		if target not in text or len(text.splitlines()) > 12:
			errors.append(f"not a small adapter to {target}: {adapter.relative_to(ROOT)}")
	if errors:
		print("AGENT GUIDANCE DRIFT")
		for error in errors:
			print(f"- {error}")
		print("Run: python3 scripts/sync_agent_guidance.py --write")
		return 1
	print(f"PASS: agent guidance ({len(canonical)} canonical skills, Claude mirror exact)")
	return 0


def write() -> int:
	if CLAUDE_SKILLS.exists():
		shutil.rmtree(CLAUDE_SKILLS)
	shutil.copytree(CANONICAL_SKILLS, CLAUDE_SKILLS)
	return check()


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--write", action="store_true", help="regenerate provider mirrors")
	args = parser.parse_args()
	return write() if args.write else check()


if __name__ == "__main__":
	sys.exit(main())
