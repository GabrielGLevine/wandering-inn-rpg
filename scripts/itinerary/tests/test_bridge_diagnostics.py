from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from scripts.itinerary.bridge import OracleBridge, OracleError


class OracleDiagnosticsTest(unittest.TestCase):
    def test_diagnostic_words_in_answer_text_are_not_engine_output(self) -> None:
        answer = [{"value": "WARNING: the sign says ERROR: keep out."}]
        stdout = "Godot Engine\nORACLE_JSON: " + json.dumps(answer) + "\n"
        with patch("scripts.itinerary.bridge.subprocess.run", return_value=SimpleNamespace(returncode=0, stdout=stdout)):
            self.assertEqual(OracleBridge(Path.cwd()).batch([{"query": "state"}]), answer)

    def test_engine_diagnostics_reject_an_otherwise_successful_answer(self) -> None:
        for diagnostic in ("WARNING: warning", "ERROR: failure", "SCRIPT ERROR: failure", "Parse Error: failure"):
            with self.subTest(diagnostic=diagnostic):
                stdout = "ORACLE_JSON: [{\"value\": 1}]\n" + diagnostic + "\n"
                with patch("scripts.itinerary.bridge.subprocess.run", return_value=SimpleNamespace(returncode=0, stdout=stdout)):
                    with self.assertRaises(OracleError):
                        OracleBridge(Path.cwd()).batch([{"query": "state"}])


if __name__ == "__main__":
    unittest.main()
