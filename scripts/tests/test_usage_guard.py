"""Tests for usage_guard core logic. Run: python3 scripts/tests/test_usage_guard.py -v"""
import importlib.util
import os
import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD_PATH = os.path.join(HERE, "..", "usage_guard.py")
_spec = importlib.util.spec_from_file_location("usage_guard", GUARD_PATH)
ug = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ug)

# 02:40 America/Chicago on Jul 12 2026 — 120 min before the fixture's session reset
NOW = datetime(2026, 7, 12, 2, 40, tzinfo=ZoneInfo("America/Chicago")).timestamp()

FIXTURE = """You are currently using your subscription to power your Claude Code usage

Current session: 11% used · resets Jul 12 at 4:40am (America/Chicago)
Current week (all models): 3% used · resets Jul 18 at 8pm (America/Chicago)
Current week (Fable): 5% used · resets Jul 18 at 8pm (America/Chicago)

What's contributing to your limits usage?
"""


class TestParse(unittest.TestCase):
    def test_parse_fixture(self):
        s = ug.parse_usage(FIXTURE, NOW)
        self.assertEqual(s["session_pct"], 11)
        self.assertEqual(s["week_pct"], 3)
        self.assertEqual(s["fable_pct"], 5)
        self.assertAlmostEqual(s["session_reset_ts"] - NOW, 120 * 60, delta=1)

    def test_parse_no_minutes_reset(self):
        # "8pm" (no :MM) must parse — the weekly line uses this form
        s = ug.parse_usage(FIXTURE, NOW)
        self.assertIsNotNone(s["week_reset_ts"])
        self.assertGreater(s["week_reset_ts"], NOW)

    def test_parse_garbage_returns_none(self):
        self.assertIsNone(ug.parse_usage("no usage info here", NOW))


class TestTiers(unittest.TestCase):
    def tier(self, *a, **kw):
        return ug.compute_tier(*a, **kw)[0]

    def test_session_bands(self):
        self.assertEqual(self.tier(69, 0, 0, None, None), "OK")
        self.assertEqual(self.tier(70, 0, 0, None, None), "CAUTION")
        self.assertEqual(self.tier(85, 0, 0, None, None), "WINDDOWN")
        self.assertEqual(self.tier(95, 0, 0, None, None), "QUIESCE")

    def test_weekly_bands(self):
        # User override 2026-07-19 (2nd raise): weekly CAUTION not
        # before 90% (WEEK_BANDS 90/94/97); below 90 stays OK.
        self.assertEqual(self.tier(0, 79, 0, None, None), "OK")
        self.assertEqual(self.tier(0, 90, 0, None, None), "CAUTION")
        self.assertEqual(self.tier(0, 0, 94, None, None), "WINDDOWN")
        self.assertEqual(self.tier(0, 97, 0, None, None), "QUIESCE")

    def test_worst_wins(self):
        self.assertEqual(self.tier(72, 94, 0, None, None), "WINDDOWN")

    def test_near_reset_softening(self):
        self.assertEqual(self.tier(96, 0, 0, 10, None), "CAUTION")

    def test_weekly_never_softened(self):
        self.assertEqual(self.tier(96, 97, 0, 10, None), "QUIESCE")

    def test_dynamic_escalation(self):
        # 55% used, 0.75%/min -> exhaustion in 60m, reset 120m away -> escalate
        self.assertEqual(self.tier(55, 0, 0, 120, 0.75), "CAUTION")

    def test_no_escalation_when_reset_comes_first(self):
        self.assertEqual(self.tier(55, 0, 0, 30, 0.75), "OK")

    def test_escalation_never_past_quiesce(self):
        self.assertEqual(self.tier(96, 0, 0, None, 5.0), "QUIESCE")


class TestBurnRate(unittest.TestCase):
    def test_basic_rate(self):
        samples = [
            {"ts": NOW - 1200, "session_pct": 50},
            {"ts": NOW, "session_pct": 60},
        ]
        self.assertAlmostEqual(ug.burn_rate(samples, NOW), 0.5)

    def test_reset_drop_discards_prefix(self):
        samples = [
            {"ts": NOW - 1500, "session_pct": 90},
            {"ts": NOW - 900, "session_pct": 5},
            {"ts": NOW - 300, "session_pct": 8},
        ]
        self.assertAlmostEqual(ug.burn_rate(samples, NOW), 3 / 10.0)

    def test_insufficient_samples(self):
        self.assertIsNone(ug.burn_rate([{"ts": NOW, "session_pct": 40}], NOW))

    def test_old_samples_excluded(self):
        samples = [
            {"ts": NOW - 7200, "session_pct": 10},
            {"ts": NOW, "session_pct": 60},
        ]
        self.assertIsNone(ug.burn_rate(samples, NOW))


if __name__ == "__main__":
    unittest.main()
