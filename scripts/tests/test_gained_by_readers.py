"""#477: every reader of classes.json `gained_by` must parse BOTH arms.

`accomplishment_any` (the entry-side twin of a level row's `requires_any`)
is exclusive with `accomplishment` in WIProgression. Four consumers once read
only the plain arm and were blind to [Rogue]'s any-gated entry. This guard is
grep-shaped so the NEXT consumer cannot be authored blind: any file that reads
`gained_by` and the plain arm must also mention the any arm.
"""
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import scaffold_consolidation as scaffold  # noqa: E402

SCAN_ROOTS = [REPO_ROOT / "wandering_inn_game" / "tests", REPO_ROOT / "wandering_inn_game" / "src",
              REPO_ROOT / "wandering_inn_game" / "scripts", REPO_ROOT / "scripts"]
PLAIN_ARM = re.compile(r'gained_by.*\.get\(\s*"accomplishment"')


class TestGainedByReaders(unittest.TestCase):
	def test_every_plain_arm_reader_also_reads_the_any_arm(self):
		blind = []
		for root in SCAN_ROOTS:
			for path in root.rglob("*"):
				if path.suffix not in (".gd", ".py") or "node_modules" in path.parts or path.name == Path(__file__).name:
					continue
				text = path.read_text(encoding="utf-8", errors="replace")
				if not PLAIN_ARM.search(text):
					continue
				if "accomplishment_any" not in text:
					blind.append(str(path.relative_to(REPO_ROOT)))
		self.assertEqual(blind, [], f"gained_by readers blind to accomplishment_any: {blind}")

	def test_shipped_rogue_is_any_gated_and_no_class_authors_both_arms(self):
		import json
		classes = json.loads((REPO_ROOT / "wandering_inn_game/data/classes.json").read_text(encoding="utf-8"))["classes"]
		by_id = {c["id"]: c for c in classes}
		self.assertIn("accomplishment_any", by_id["rogue"].get("gained_by", {}))
		both = [c["id"] for c in classes if {"accomplishment", "accomplishment_any"} <= set((c.get("gained_by") or {}).keys())]
		self.assertEqual(both, [], "a class authoring both arms silently loses its plain arm")

	def test_scaffold_derives_one_key_of_the_any_arm(self):
		classes_by_id = {
			"rogue_like": {"id": "rogue_like", "gained_by": {"accomplishment_any": {"first_key": 2, "second_key": 5}}, "levels": []},
		}
		counters = scaffold.derive_fixture_counters({"rogue_like": 1}, classes_by_id)
		self.assertGreaterEqual(counters.get("first_key", 0), 2)
		self.assertNotIn("second_key", counters, "banking every any-arm key overstates what the player did")


if __name__ == "__main__":
	unittest.main()
