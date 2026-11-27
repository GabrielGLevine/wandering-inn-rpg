"""scripts/harness_entry_report.py parses every harness cell format and ranks drops."""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import harness_entry_report as report_module  # noqa: E402

RESTED = """[goblin_ambush / warrior2] win_rate=0.98 median_rounds=3 min=2 max=5
[loadout / warrior2_sword] comp=goblin_ambush build=warrior2 weapon=rusty_sword armor=(none) accessories=(none) (measured) win_rate=0.90 median_rounds=3
[party / vault_construct_t4_party] arena=trapped_halls build=t4_spellsword11_party win_rate=0.85 median_rounds=7
noise line without a cell
"""
DEPLETED = RESTED.replace("0.98", "0.80").replace("0.85", "0.20")


def write(text: str) -> str:
	with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as handle:
		handle.write(text)
	return handle.name


class HarnessEntryReportTest(unittest.TestCase):
	def test_parses_every_cell_format(self) -> None:
		cells = report_module.parse(write(RESTED))
		self.assertEqual(set(cells), {"goblin_ambush / warrior2", "loadout / warrior2_sword", "party / vault_construct_t4_party"})
		self.assertTrue(cells["loadout / warrior2_sword"]["measured"])
		self.assertEqual(cells["party / vault_construct_t4_party"]["build"], "t4_spellsword11_party")

	def test_orders_by_largest_drop_and_summarises(self) -> None:
		legs = {"rested": report_module.parse(write(RESTED)), "0.50": report_module.parse(write(DEPLETED))}
		text = report_module.report(legs, "rested")
		rows = [line for line in text.splitlines() if line.startswith("| ") and "Cell" not in line]
		self.assertTrue(rows[0].startswith("| party / vault_construct_t4_party |"))
		self.assertIn("| 0.85 | 0.20 |", rows[0])
		self.assertIn("**0.50:** 3 cells; mean drop vs rested 0.277; cells below 0.55: 1.", text)


if __name__ == "__main__":
	unittest.main()
