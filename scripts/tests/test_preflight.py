"""Process-level contracts for preflight's Godot unit wrapper."""

import os
import json
import subprocess
import tempfile
import unittest


HERE = os.path.dirname(os.path.abspath(__file__))
PREFLIGHT = os.path.join(HERE, "..", "preflight.sh")


class TestUnitWrapper(unittest.TestCase):
    def run_case(self, mode):
        with tempfile.TemporaryDirectory() as td:
            helper = os.path.join(td, "unit-fixture.sh")
            with open(helper, "w") as fh:
                fh.write("""#!/bin/bash
case "$1" in
  clean) printf 'setup complete\\nPASS fixture\\n' ;;
  exit42) printf 'PASS fixture\\n'; exit 42 ;;
  warning) printf 'PASS fixture\\nWARNING: noisy fixture\\n' ;;
  script_error) printf 'PASS fixture\\nSCRIPT ERROR: fixture broke\\n' ;;
  parse_error) printf 'PASS fixture\\nParse Error: fixture broke\\n' ;;
  fail_error) printf 'PASS fixture\\nERROR: FAIL fixture broke\\n' ;;
  bare_error) printf 'PASS fixture\\nERROR: Error loading resource\\n' ;;
  missing) printf 'setup complete\\n' ;;
  long) i=0; while [ "$i" -lt 40 ]; do printf 'detail-%02d\\n' "$i"; i=$((i + 1)); done
        printf 'PASS fixture\\nWARNING: final marker\\n' ;;
esac
""")
            os.chmod(helper, 0o755)
            artifact_dir = os.path.join(td, "artifacts")
            env = os.environ.copy()
            env["PREFLIGHT_ARTIFACT_DIR"] = artifact_dir
            result = subprocess.run(
                ["bash", PREFLIGHT, "--unit-command", "fixture", helper, mode],
                capture_output=True, text=True, env=env, timeout=10)
            log_path = os.path.join(artifact_dir, "unit-fixture.log")
            with open(log_path) as fh:
                log = fh.read()
            with open(log_path + '.verdict.json') as fh:
                verdict = json.load(fh)
            self.assertEqual(verdict['gate_exit'], result.returncode)
            if mode == 'warning':
                self.assertEqual(verdict['process_exit'], 0)
                self.assertEqual(verdict['noise_lines'], 1)
            return result, log

    def test_clean_pass_succeeds(self):
        result, log = self.run_case("clean")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("ok   unit fixture", result.stdout)
        self.assertEqual(log, "setup complete\nPASS fixture\n")

    def test_pass_with_nonzero_process_status_fails(self):
        result, log = self.run_case("exit42")
        self.assertEqual(result.returncode, 1)
        self.assertIn("rc=42", result.stdout)
        self.assertIn("PASS fixture", log)

    def test_pass_with_any_zero_noise_marker_fails(self):
        for mode, marker in (
                ("warning", "WARNING"),
                ("script_error", "SCRIPT ERROR"),
                ("parse_error", "Parse Error"),
                ("fail_error", "ERROR: FAIL"),
                ("bare_error", "ERROR: Error loading resource")):
            with self.subTest(marker=marker):
                result, log = self.run_case(mode)
                self.assertEqual(result.returncode, 1)
                self.assertIn("badlines=1", result.stdout)
                self.assertIn(marker, log)

    def test_missing_pass_fails(self):
        result, _ = self.run_case("missing")
        self.assertEqual(result.returncode, 1)
        self.assertIn("pass=0", result.stdout)

    def test_failure_summary_is_bounded_and_full_log_is_preserved(self):
        result, log = self.run_case("long")
        self.assertEqual(result.returncode, 1)
        self.assertLessEqual(len(result.stdout.splitlines()), 12, result.stdout)
        self.assertIn("detail-00", log)
        self.assertIn("WARNING: final marker", log)
        self.assertIn("full log:", result.stdout)


if __name__ == "__main__":
    unittest.main()
