"""qa/journey_gate.py fails every way a journey can be missing or broken (#515)."""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("journey_gate", ROOT / "wandering_inn_game" / "qa" / "journey_gate.py")
gate_module = importlib.util.module_from_spec(SPEC)
sys.modules["journey_gate"] = gate_module
SPEC.loader.exec_module(gate_module)

LEAK = "ERROR: 4 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit."
REGISTRY = [{"script": "journey_a", "route": "rogue", "checkpoint": "a_end", "budget_sec": 60}]
MANIFEST = [{"script": "journey_a", "seed": 9, "tiers": ["full", "journey"]}]


def stub(qa_output: Path, *, code=0, passed=True, steps=(10, 10), checkpoint="a_end", noise="", result=True, raise_error=None):
	def runner(entry, log):
		if raise_error:
			raise raise_error
		log.write_text(f"QA_CHECKPOINT: {checkpoint} -> x.json (step 9, inn (1, 1))\nQA_RESULT: PASS\n{LEAK}\n{noise}")
		if result:
			out = qa_output / entry["script"]
			out.mkdir(parents=True, exist_ok=True)
			(out / "result.json").write_text(json.dumps({"passed": passed, "steps_run": steps[0], "steps_total": steps[1], "failures": []}))
			(out / "events.jsonl").write_text(json.dumps({"type": "gold_changed", "payload": {"delta": 3, "source": "x", "total": 3}}) + "\n")
		return code
	return runner


class JourneyGateTest(unittest.TestCase):
	def run_gate(self, registry=REGISTRY, manifest=MANIFEST, only=None, **runner):
		tmp = Path(tempfile.mkdtemp())
		qa_output = tmp / "qa_output"
		return gate_module.gate(registry, manifest, tmp / "gate", qa_output, stub(qa_output, **runner), only)

	def errors(self, report) -> str:
		return " | ".join(report["errors"] + [e for j in report["journeys"] for e in j["errors"]])

	def test_passing_journey_reports_identity_and_artifacts(self) -> None:
		report = self.run_gate()
		self.assertTrue(report["passed"], self.errors(report))
		journey = report["journeys"][0]
		self.assertEqual((journey["route"], journey["seed"], journey["reached_checkpoint"], journey["steps"]), ("rogue", 9, "a_end", "10/10"))
		self.assertEqual(journey["ledger"]["gold_final"], 3)
		self.assertIn("result", journey["artifacts"])

	def test_failures_fail_the_gate(self) -> None:
		cases = {
			"exit 1": {"code": 1},
			"result not passed": {"passed": False},
			"no result.json": {"result": False},
			"steps unrun": {"steps": (5, 10)},
			"checkpoint a_end not reached": {"checkpoint": "a_mid"},
			"engine noise": {"noise": "ERROR: something else\n"},
			"launch failed": {"raise_error": OSError("no such file")},
		}
		for expected, runner in cases.items():
			report = self.run_gate(**runner)
			self.assertFalse(report["passed"], expected)
			self.assertIn(expected, self.errors(report))

	def test_registration_cannot_silently_drop_a_journey(self) -> None:
		dropped_tier = [{"script": "journey_a", "seed": 9, "tiers": ["full"]}]
		self.assertIn("lacks the journey tier", self.errors(self.run_gate(manifest=dropped_tier)))
		self.assertIn("missing from manifest", self.errors(self.run_gate(manifest=[])))
		unlisted = MANIFEST + [{"script": "journey_b", "seed": 3, "tiers": ["full", "journey"]}]
		self.assertIn("journey_b: manifest journey tier is not in the registry", self.errors(self.run_gate(manifest=unlisted)))
		self.assertIn("journey registry is empty", self.errors(self.run_gate(registry=[], manifest=[])))
		self.assertIn("no journeys selected", self.errors(self.run_gate(registry=[], manifest=[])))
		self.assertIn("unknown journeys selected", self.errors(self.run_gate(only={"journey_z"})))

	def test_shipped_registry_matches_manifest(self) -> None:
		qa = ROOT / "wandering_inn_game" / "qa"
		registry = json.loads((qa / "journeys.json").read_text())["journeys"]
		manifest = json.loads((qa / "manifest.json").read_text())["scripts"]
		self.assertEqual(gate_module.registration_errors(registry, manifest), [])

	def test_over_budget_fails(self) -> None:
		registry = [dict(REGISTRY[0], budget_sec=-1)]
		self.assertIn("over budget", self.errors(self.run_gate(registry=registry)))


if __name__ == "__main__":
	unittest.main()
