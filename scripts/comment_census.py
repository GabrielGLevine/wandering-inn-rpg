#!/usr/bin/env python3
"""Measure repository GDScript and game-data comment weight."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "wandering_inn_game"
GD_LIMIT = 0.24
JSON_LIMIT = 0.18
# Ceilings raised 15%->18% / 20%->24% (user ruling 2026-08-09): the old
# margins sat permanently exhausted, so every wave paid a comment tax and two
# mechanical trim passes mangled load-bearing docs (anchor math, canon
# pointers) trying to buy 200 chars. A tripwire should catch RUNAWAY bloat,
# not meter engineering notes char-by-char. If a wave blows through THESE
# ceilings, that is a real conversation, not a trim.


@dataclass(frozen=True)
class GdCount:
	path: Path
	code: int
	comments: int

	@property
	def ratio(self) -> float:
		total = self.code + self.comments
		return self.comments / total if total else 0.0


@dataclass(frozen=True)
class JsonCount:
	path: Path
	characters: int
	comment_characters: int

	@property
	def ratio(self) -> float:
		return self.comment_characters / self.characters if self.characters else 0.0


def gd_count(path: Path) -> GdCount:
	code = 0
	comments = 0
	for line in path.read_text().splitlines():
		stripped = line.strip()
		if not stripped:
			continue
		if stripped.startswith("#"):
			comments += 1
		else:
			code += 1
	return GdCount(path, code, comments)


def comment_characters(value: Any) -> int:
	if isinstance(value, dict):
		return sum(
			len(item) if key.startswith("_") and "comment" in key and isinstance(item, str) else comment_characters(item)
			for key, item in value.items()
		)
	if isinstance(value, list):
		return sum(comment_characters(item) for item in value)
	return 0


def json_count(path: Path) -> JsonCount:
	text = path.read_text()
	return JsonCount(path, len(text), comment_characters(json.loads(text)))


def percent(value: float) -> str:
	return f"{value * 100:.1f}%"


def relative(path: Path) -> str:
	return str(path.relative_to(ROOT))


def group(path: Path) -> str:
	parts = path.relative_to(GAME).parts
	if parts[0] == "data":
		return "/".join(parts[:3]) if len(parts) > 2 and parts[1] == "maps" else "/".join(parts[:2])
	if parts[0] == "src":
		return "/".join(parts[:2])
	return parts[0]


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--check", action="store_true", help="fail when either repository target is exceeded")
	parser.add_argument("--top", type=int, default=10, help="show this many worst files per class")
	args = parser.parse_args()

	gd = [gd_count(path) for path in sorted(GAME.rglob("*.gd"))]
	data = [json_count(path) for path in sorted((GAME / "data").rglob("*.json"))]

	gd_code = sum(item.code for item in gd)
	gd_comments = sum(item.comments for item in gd)
	gd_ratio = gd_comments / (gd_code + gd_comments)
	json_chars = sum(item.characters for item in data)
	json_comment_chars = sum(item.comment_characters for item in data)
	json_ratio = json_comment_chars / json_chars

	print(f"GDSCRIPT code={gd_code} comments={gd_comments} ratio={percent(gd_ratio)} target<={percent(GD_LIMIT)}")
	for name in sorted({group(item.path) for item in gd}):
		items = [item for item in gd if group(item.path) == name]
		code = sum(item.code for item in items)
		comments = sum(item.comments for item in items)
		print(f"  DIR {percent(comments / (code + comments)):>6} {comments:>5}c {code:>5}code  {name}")
	for item in sorted(gd, key=lambda count: (count.ratio, count.comments), reverse=True)[: args.top]:
		print(f"  {percent(item.ratio):>6} {item.comments:>5}c {item.code:>5}code  {relative(item.path)}")
	print(f"DATA chars={json_chars} _comment_chars={json_comment_chars} ratio={percent(json_ratio)} target<={percent(JSON_LIMIT)}")
	for name in sorted({group(item.path) for item in data}):
		items = [item for item in data if group(item.path) == name]
		characters = sum(item.characters for item in items)
		comments = sum(item.comment_characters for item in items)
		print(f"  DIR {percent(comments / characters):>6} {comments:>7}c {characters:>8}all  {name}")
	for item in sorted(data, key=lambda count: (count.ratio, count.comment_characters), reverse=True)[: args.top]:
		print(f"  {percent(item.ratio):>6} {item.comment_characters:>7}c {item.characters:>8}all  {relative(item.path)}")

	if args.check and (gd_ratio > GD_LIMIT or json_ratio > JSON_LIMIT):
		return 1
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
