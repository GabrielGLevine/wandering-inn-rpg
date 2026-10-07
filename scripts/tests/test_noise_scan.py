"""qa/noise_scan.sh defers only the exact #586 shutdown leak line."""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCAN = ROOT / "wandering_inn_game" / "qa" / "noise_scan.sh"
LEAK = "ERROR: 4 RID allocations of type 'N13RendererDummy15MaterialStorage11DummyShaderE' were leaked at exit."


def scan(text: str) -> subprocess.CompletedProcess:
	with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as log:
		log.write(text)
	return subprocess.run(["bash", str(SCAN), log.name], capture_output=True, text=True)


class NoiseScanTest(unittest.TestCase):
	def test_clean_log_passes(self) -> None:
		result = scan("QA_RESULT: PASS\n")
		self.assertEqual(result.returncode, 0)
		self.assertEqual(result.stdout, "")

	def test_exact_586_leak_is_deferred(self) -> None:
		for count in ("3", "4", "17"):
			result = scan("QA_RESULT: PASS\n" + LEAK.replace("4", count, 1) + "\n")
			self.assertEqual(result.returncode, 0, count)

	def test_other_noise_still_fails(self) -> None:
		for line in (
			"ERROR: 4 RID allocations of type 'N13RendererDummy15MaterialStorage11CanvasItemE' were leaked at exit.",
			LEAK + " extra",
			"ERROR: Condition \"!shader\" is true.",
			"SCRIPT ERROR: Invalid call.",
			"WARNING: ObjectDB instances leaked at exit.",
			"Parse Error: Unexpected token.",
		):
			result = scan("QA_RESULT: PASS\n" + LEAK + "\n" + line + "\n")
			self.assertEqual(result.returncode, 1, line)
			self.assertIn(line, result.stdout)
			self.assertNotIn(LEAK + "\n", result.stdout.replace(line, ""))


if __name__ == "__main__":
	unittest.main()
