"""Browser registry routing and evidence must fail closed."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "wandering_inn_game"
spec = importlib.util.spec_from_file_location("browser_suite", GAME / "qa/web/run_browser_suite.py")
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)


class BrowserRegistryTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((GAME / "qa/manifest.json").read_text())
        self.entry = self.manifest["browser_scripts"][0]

    def test_registry_routes_six_browser_cases_outside_native_tiers(self):
        cases = suite.cases(self.manifest)
        self.assertEqual(len(cases), 6)
        native = {row["script"] for row in self.manifest["scripts"]}
        self.assertTrue(all(entry["script"] not in native for entry, _ in cases))
        self.assertEqual({profile for _, profile in cases}, {"iphone", "android"})
        self.assertTrue(all("tiers" not in entry for entry, _ in cases))

    def test_malformed_and_unknown_registry_data_is_rejected(self):
        mutations = [
            lambda m: m.pop("browser_scripts"),
            lambda m: m.update(browser_scripts=[]),
            lambda m: m.update(browzer_scripts=[]),
            lambda m: m["browser_scripts"][0].update(profiles=["safari"]),
            lambda m: m["browser_scripts"][0].update(profiles=["iphone", "iphone"]),
            lambda m: m["browser_scripts"][0].update(required_touch_proofs=["unknown"]),
            lambda m: m["browser_scripts"][0].update(script=m["scripts"][0]["script"]),
            lambda m: m["browser_scripts"][0].update(tiers=["full"]),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                data = copy.deepcopy(self.manifest)
                mutate(data)
                with self.assertRaises(ValueError):
                    suite.cases(data)

    def test_touching_never_selects_browser_only_scripts_for_native_execution(self):
        names = {entry["script"] for entry in self.manifest["browser_scripts"]}
        for path in ["qa/scripts/purchase_touch_static.json", "data/items.json", "src/core/wi_game.gd"]:
            with self.subTest(path=path):
                run = subprocess.run([sys.executable, str(GAME / "scripts/derive_qa_surfaces.py"), "--touching", path], capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertFalse(names & set(run.stdout.split()))

    def evidence(self):
        return {"emulated": True, "device": "iphone", "touchMode": True, "timedTouchPassed": True,
                "runtime": {"events": [{"type": "touchstart", "trusted": True}]},
                "requests": [{"holdProof": {"passed": True}}, {"preArmProof": {"passed": True}}], "errors": [], "warnings": []}

    def test_game_pass_needs_trusted_contacts_and_each_required_timing_proof(self):
        good = self.evidence()
        self.assertEqual(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", {"passed": True}, good), [])
        mutations = [
            lambda e: e.update(requests=[]),
            lambda e: e["requests"].pop(),
            lambda e: e["runtime"].update(events=[]),
            lambda e: e["runtime"]["events"][0].update(trusted=False),
            lambda e: e.update(timedTouchPassed=False),
            lambda e: e.update(device="android"),
            lambda e: e.update(touchMode=False),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                evidence = copy.deepcopy(good)
                mutate(evidence)
                self.assertTrue(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", {"passed": True}, evidence))

    def test_false_green_exit_or_error_output_is_rejected(self):
        for rc, log, result in [(1, "QA_RESULT: PASS", {"passed": True}), (0, "", {"passed": True}),
                                (0, "QA_RESULT: PASS\nERROR: failed", {"passed": True}),
                                (0, "QA_RESULT: PASS\nWARNING: failed", {"passed": True}),
                                (0, "QA_RESULT: PASS", {"passed": False})]:
            with self.subTest(rc=rc, log=log):
                self.assertTrue(suite.evaluate_run(self.entry, "iphone", rc, log, result, self.evidence()))


if __name__ == "__main__":
    unittest.main()
