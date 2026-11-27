"""Browser registry routing and evidence must fail closed."""

import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "wandering_inn_game"
spec = importlib.util.spec_from_file_location("browser_suite", GAME / "qa/web/run_browser_suite.py")
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)


class BrowserRegistryTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((GAME / "qa/manifest.json").read_text())
        self.entry = next(e for e in self.manifest["browser_scripts"] if e["script"] == "purchase_touch_static")

    def test_registry_routes_browser_cases_outside_native_tiers(self):
        cases = suite.cases(self.manifest)
        self.assertEqual(len(cases), sum(len(row["profiles"]) for row in self.manifest["browser_scripts"]))
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
            lambda m: m["browser_scripts"][0].pop("fixture"),
            lambda m: m["browser_scripts"][0].update(fixture=""),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                data = copy.deepcopy(self.manifest)
                mutate(data)
                with self.assertRaises(ValueError):
                    suite.cases(data)

    def test_fresh_routes_require_explicit_null_fixture_and_full_timeout(self):
        entry = next(row for row in self.manifest["browser_scripts"] if row["script"] == "touch_opening_continuous")
        self.assertIsNone(entry["fixture"])
        self.assertEqual({profile for row, profile in suite.cases(self.manifest) if row is entry}, {"iphone", "android"})
        self.assertEqual(suite.script_timeout("touch_opening_continuous"), 660)

    def test_cancel_proof_cannot_be_replaced_by_an_ordinary_tap(self):
        entry = self.entry | {"required_touch_proofs": ["cancel"]}
        evidence = self.evidence() | {"requests": [{"cancelProof": {"passed": True}}]}
        self.assertEqual(suite.evaluate_run(entry, "iphone", 0, "QA_RESULT: PASS", self.result(), evidence), [])
        for requests in [[{"tapProof": {"passed": True}}], [{"cancelProof": {"passed": False}}], []]:
            self.assertTrue(suite.evaluate_run(entry, "iphone", 0, "QA_RESULT: PASS", self.result(), evidence | {"requests": requests}))

    def test_touching_never_selects_browser_only_scripts_for_native_execution(self):
        names = {entry["script"] for entry in self.manifest["browser_scripts"]}
        for path in ["qa/scripts/purchase_touch_static.json", "data/items.json", "src/core/wi_game.gd"]:
            with self.subTest(path=path):
                run = subprocess.run([sys.executable, str(GAME / "scripts/derive_qa_surfaces.py"), "--touching", path], capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertFalse(names & set(run.stdout.split()))

    def result(self):
        return {"passed": True, "aborted": False, "failures": [], "steps_run": 1,
                "steps_total": 1, "script": f"res://qa/scripts/{self.entry['script']}.json"}

    def test_incomplete_or_wrong_stage_green_result_is_rejected(self):
        for patch in [{"steps_run": 0}, {"steps_total": 2}, {"script": "wrong"},
                      {"aborted": True}, {"failures": ["failure"]}]:
            result = self.result() | patch
            self.assertTrue(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", result, self.evidence()))
        self.assertTrue(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", self.result(), self.evidence(), 2))

    def evidence(self):
        return {"emulated": True, "device": "iphone", "touchMode": True, "timedTouchPassed": True,
                "runtime": {"events": [{"type": "touchstart", "trusted": True}]},
                "requests": [{"holdProof": self.result()}, {"preArmProof": self.result()}], "errors": [], "warnings": []}

    def test_game_pass_needs_trusted_contacts_and_each_required_timing_proof(self):
        good = self.evidence()
        self.assertEqual(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", self.result(), good), [])
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
                self.assertTrue(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", self.result(), evidence))

    def test_only_known_renderer_warning_is_exempted_and_retained(self):
        warning = "[.WebGL-0x123abc]GL Driver Message (OpenGL, Performance, GL_CLOSE_PATH_NV, High): GPU stall due to ReadPixels"
        for text in [warning, warning + " (this message will no longer repeat)",
                     "WARNING: ImageLoaderSVG: Target canvas dimensions 51500x51500 (with scale 1.00) exceed the max supported dimensions 16384x16384. The target canvas will be scaled down."]:
            evidence = self.evidence()
            evidence["warnings"] = [text]
            self.assertEqual(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS\n[console:warning] " + text, self.result(), evidence), [])
            self.assertEqual(evidence["warnings"], [text])
        for text in ["Unknown renderer warning", warning + " unexpected error", "ERROR: ImageLoaderSVG: Target canvas dimensions 51500", "WARNING: ImageLoaderSVG: Target canvas dimensions 51500x51500 scaled down"]:
            evidence = self.evidence()
            evidence["warnings"] = [text]
            self.assertTrue(suite.evaluate_run(self.entry, "iphone", 0, "QA_RESULT: PASS", self.result(), evidence))

    def test_false_green_exit_or_error_output_is_rejected(self):
        for rc, log, result in [(1, "QA_RESULT: PASS", self.result()), (0, "", self.result()),
                                (0, "QA_RESULT: PASS\nERROR: failed", self.result()),
                                (0, "QA_RESULT: PASS\nWARNING: failed", self.result()),
                                (0, "QA_RESULT: PASS", {"passed": False})]:
            with self.subTest(rc=rc, log=log):
                self.assertTrue(suite.evaluate_run(self.entry, "iphone", rc, log, result, self.evidence()))


class BrowserShardTest(unittest.TestCase):
    def setUp(self):
        self.cases = suite.validated_cases()
        self.costs = suite.case_costs(self.cases, json.loads(suite.COSTS.read_text()))

    def keys(self, selected):
        return [(entry["script"], profile) for entry, profile in selected]

    def test_every_shard_count_partitions_the_registry_in_order(self):
        everything = self.keys(self.cases)
        for count in range(1, len(self.cases) + 1):
            shards = [self.keys(suite.shard_cases(self.cases, self.costs, index, count)) for index in range(1, count + 1)]
            with self.subTest(count=count):
                self.assertTrue(all(shards))
                self.assertEqual(sorted(sum(shards, [])), sorted(everything))
                self.assertEqual(len(sum(shards, [])), len(everything))
                for shard in shards:
                    self.assertEqual(shard, [key for key in everything if key in shard])

    def test_longest_routes_never_share_a_shard(self):
        for count in range(2, 7):
            owners = [index for index in range(1, count + 1)
                      for entry, _ in suite.shard_cases(self.cases, self.costs, index, count)
                      if entry["script"] == "touch_opening_continuous"]
            self.assertEqual(len(set(owners)), 2, count)

    def test_shards_stay_within_the_longest_first_bound(self):
        for count in range(2, 9):
            loads = [sum(self.costs[self.cases.index(case)] for case in suite.shard_cases(self.cases, self.costs, index, count))
                     for index in range(1, count + 1)]
            with self.subTest(count=count):
                self.assertLessEqual(max(loads), 4 / 3 * max(max(self.costs), sum(self.costs) / count))

    def test_shard_specs_and_cost_hints_fail_closed(self):
        for text in ["0/6", "7/6", "1/0", "a/b", "1/6/2", " 1/6", f"1/{len(self.cases) + 1}"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                suite.parse_shard(text, len(self.cases))
        self.assertEqual(suite.parse_shard("6/6", len(self.cases)), (6, 6))
        good = json.loads(suite.COSTS.read_text())
        for hints in [[], {"seconds": []}, {"secs": {}}, good | {"extra": 1},
                      {"seconds": {"save_load_roundtrip": 30}}, {"seconds": {"purchase_touch_static": 0}},
                      {"seconds": {"purchase_touch_static": 30.5}}, {"seconds": {"purchase_touch_static": True}}]:
            with self.subTest(hints=hints), self.assertRaises(ValueError):
                suite.case_costs(self.cases, hints)
        unhinted = suite.case_costs(self.cases, {"seconds": {}})
        self.assertEqual(unhinted, [suite.script_timeout(entry["script"]) for entry, _ in self.cases])


class BrowserMergeTest(unittest.TestCase):
    PCK = "a" * 64
    COUNT = 3

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.cases = suite.validated_cases()
        self.costs = suite.case_costs(self.cases, json.loads(suite.COSTS.read_text()))
        self.shards = [self.write_shard(index) for index in range(1, self.COUNT + 1)]

    def tearDown(self):
        self.tmp.cleanup()

    def write_shard(self, index):
        directory = self.root / f"browser-suite-shard-{index}"
        rows = []
        for entry, profile in suite.shard_cases(self.cases, self.costs, index, self.COUNT):
            name = entry["script"]
            case = directory / profile / name
            case.mkdir(parents=True)
            steps = len(json.loads((GAME / "qa/scripts" / f"{name}.json").read_text())["steps"])
            (case / "result.json").write_text(json.dumps({
                "passed": True, "aborted": False, "failures": [], "steps_run": steps, "steps_total": steps,
                "script": f"res://qa/scripts/{name}.json"}))
            (case / "browser-evidence.json").write_text(json.dumps({
                "emulated": True, "device": profile, "touchMode": True, "timedTouchPassed": True,
                "buildPckSha256": self.PCK, "errors": [], "warnings": [],
                "runtime": {"events": [{"type": "touchstart", "trusted": True}]},
                "requests": [{suite.PROOFS[proof]: {"passed": True}} for proof in entry["required_touch_proofs"]]}))
            (case / "runner.log").write_text("[game] QA_RESULT: PASS\n")
            rows.append({"script": name, "profile": profile, "passed": True, "runner_exit": 0, "failures": [],
                         "timing": {"seconds": 1.0}})
        (directory / "result.json").write_text(json.dumps(
            {"passed": True, "shard": {"index": index, "count": self.COUNT}, "cases": rows}))
        return directory

    def merge(self, shards=None, expected=PCK):
        output = self.root / "merged"
        shutil.rmtree(output, ignore_errors=True)
        return suite.merge(self.shards if shards is None else shards, output, expected), output

    def edit_json(self, path, change):
        data = json.loads(path.read_text())
        change(data)
        path.write_text(json.dumps(data))

    def test_complete_shards_merge_into_one_verified_suite(self):
        problems, output = self.merge()
        self.assertEqual(problems, [])
        merged = json.loads((output / "result.json").read_text())
        self.assertTrue(merged["passed"])
        self.assertEqual(merged["shards"], self.COUNT)
        self.assertEqual(merged["build_pck_sha256"], self.PCK)
        self.assertEqual([(row["script"], row["profile"]) for row in merged["cases"]],
                         [(entry["script"], profile) for entry, profile in self.cases])
        for entry, profile in self.cases:
            self.assertTrue((output / profile / entry["script"] / "browser-evidence.json").is_file())

    def test_missing_duplicate_or_misplaced_cases_are_rejected(self):
        first = self.shards[0] / "result.json"
        moved = json.loads(first.read_text())["cases"][0]
        self.assertTrue(self.merge(self.shards[:-1])[0])
        self.assertTrue(self.merge(self.shards + [self.shards[0]])[0])
        self.edit_json(first, lambda data: data["cases"].pop(0))
        self.assertTrue(self.merge()[0])
        self.edit_json(first, lambda data: data["cases"].insert(0, moved))
        self.assertEqual(self.merge()[0], [])
        self.edit_json(self.shards[1] / "result.json", lambda data: data["cases"].append(moved))
        self.assertTrue(self.merge()[0])
        self.edit_json(first, lambda data: data["cases"].pop(0))
        shutil.copytree(self.shards[0] / moved["profile"] / moved["script"], self.shards[1] / moved["profile"] / moved["script"])
        self.assertTrue(self.merge()[0])

    def test_shard_count_and_index_must_describe_one_complete_set(self):
        for change in [lambda data: data["shard"].update(count=self.COUNT + 1),
                       lambda data: data["shard"].update(index=2),
                       lambda data: data.pop("shard")]:
            path = self.shards[0] / "result.json"
            original = path.read_text()
            self.edit_json(path, change)
            with self.subTest(change=change):
                self.assertTrue(self.merge()[0])
            path.write_text(original)

    def test_artifacts_are_reverified_rather_than_trusting_shard_verdicts(self):
        row = json.loads((self.shards[0] / "result.json").read_text())["cases"][0]
        case = self.shards[0] / row["profile"] / row["script"]
        for name, change in [("browser-evidence.json", lambda data: data["runtime"]["events"][0].update(trusted=False)),
                             ("browser-evidence.json", lambda data: data.update(requests=[])),
                             ("browser-evidence.json", lambda data: data.update(buildPckSha256="b" * 64)),
                             ("result.json", lambda data: data.update(steps_run=1))]:
            original = (case / name).read_text()
            self.edit_json(case / name, change)
            with self.subTest(name=name, change=change):
                self.assertTrue(self.merge()[0])
            (case / name).write_text(original)
        (case / "runner.log").write_text("[game] QA_RESULT: PASS\nERROR: hidden\n")
        self.assertTrue(self.merge()[0])
        (case / "runner.log").unlink()
        self.assertTrue(self.merge()[0])

    def test_shard_failure_or_nonzero_exit_is_not_laundered(self):
        path = self.shards[2] / "result.json"
        self.edit_json(path, lambda data: data["cases"][0].update(runner_exit=1))
        self.assertTrue(self.merge()[0])
        self.edit_json(path, lambda data: data["cases"][0].update(runner_exit=0, passed=False))
        self.assertTrue(self.merge()[0])
        for runner_exit in [False, 0.0, None, "0"]:
            self.edit_json(path, lambda data: data["cases"][0].update(runner_exit=runner_exit, passed=True))
            with self.subTest(runner_exit=runner_exit):
                self.assertTrue(self.merge()[0])

    def test_malformed_timing_cannot_leave_a_green_summary_behind_a_crash(self):
        self.edit_json(self.shards[0] / "result.json", lambda data: data["cases"][0].update(timing={"seconds": "slow"}))
        problems, output = self.merge()
        self.assertEqual(problems, [])
        self.assertTrue(json.loads((output / "result.json").read_text())["passed"])

    def test_every_case_must_use_the_one_expected_export(self):
        self.assertTrue(self.merge(expected="c" * 64)[0])
        self.assertTrue(self.merge(expected="")[0])


if __name__ == "__main__":
    unittest.main()
