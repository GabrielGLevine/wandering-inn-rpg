from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
from typing import Any, Iterable

from .ledger import Ledger


class OracleError(RuntimeError):
    pass


class OracleBridge:
    def __init__(self, project: str | Path, godot: str = "/usr/local/bin/godot") -> None:
        self.project = Path(project).resolve()
        self.godot = godot
        # A question asked twice under the SAME save has the same answer: the
        # oracle boots a fresh sim per batch, reads a serialized WISave and
        # exits, so there is no carried state for a repeat to observe
        # differently. Caching on (query, save) is what makes the pass-2 spine
        # fence affordable -- it plans the itinerary twice, and the two plans
        # agree at almost every node by construction, which is exactly the
        # case where every query is a repeat.
        self._answers: dict[tuple[str, str], dict[str, Any]] = {}
        self.queries_asked = 0
        self.queries_served = 0

    def query(self, query: str, ledger: Ledger | None = None) -> dict[str, Any]:
        request: dict[str, Any] = {"query": query}
        save_json = "" if ledger is None else json.dumps(ledger.materialize_save(), sort_keys=True)
        key = (query, save_json)
        self.queries_asked += 1
        cached = self._answers.get(key)
        if cached is not None:
            self.queries_served += 1
            return json.loads(json.dumps(cached))
        with tempfile.TemporaryDirectory(prefix="wi-itinerary-") as td:
            if ledger is not None:
                save_path = Path(td) / "state.json"
                save_path.write_text(save_json, encoding="utf-8")
                request["save"] = str(save_path)
            answer = self.batch([request], temp_dir=Path(td))[0]
        self._answers[key] = answer
        return json.loads(json.dumps(answer))

    def batch(self, requests: Iterable[dict[str, Any]], temp_dir: Path | None = None) -> list[dict[str, Any]]:
        owned = tempfile.TemporaryDirectory(prefix="wi-itinerary-batch-") if temp_dir is None else None
        work = Path(owned.name) if owned is not None else temp_dir
        assert work is not None
        query_path = work / "queries.json"
        query_path.write_text(json.dumps(list(requests)), encoding="utf-8")
        home = work / "home"
        (home / ".local/share").mkdir(parents=True, exist_ok=True)
        (home / ".config").mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CONFIG_HOME": str(home / ".config")})
        cmd = [self.godot, "--headless", "--path", str(self.project), "--script", "res://qa/oracle.gd", "--", f"--queries={query_path}"]
        run = subprocess.run(cmd, cwd=self.project.parent, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        line = next((item for item in run.stdout.splitlines() if item.startswith("ORACLE_JSON: ")), "")
        if not line:
            raise OracleError(f"oracle produced no ORACLE_JSON (rc={run.returncode}):\n{run.stdout}")
        parsed = json.loads(line.removeprefix("ORACLE_JSON: "))
        if not isinstance(parsed, list):
            raise OracleError(f"batch oracle answer is not an array: {parsed!r}")
        errors = [answer for answer in parsed if isinstance(answer, dict) and "error" in answer]
        if run.returncode != 0 or errors:
            raise OracleError(f"oracle batch failed (rc={run.returncode}): {errors}\n{run.stdout}")
        if owned is not None:
            owned.cleanup()
        return parsed

    def run_driver(
        self,
        script: str | Path,
        out_dir: str | Path,
        seed: int = 9,
        fail_fast: bool = True,
        timeout: int = 300,
    ) -> tuple[dict[str, Any], str]:
        script_path = Path(script).resolve()
        output = Path(out_dir).resolve()
        output.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="wi-itinerary-run-") as td:
            home = Path(td) / "home"
            (home / ".local/share").mkdir(parents=True)
            (home / ".config").mkdir(parents=True)
            env = os.environ.copy()
            env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CONFIG_HOME": str(home / ".config")})
            user_args = [f"--qa-script={script_path}", f"--qa-out={output}", f"--seed={seed}"]
            if fail_fast:
                user_args.append("--fail-fast=1")
            cmd = [self.godot, "--headless", "--path", str(self.project), "--", *user_args]
            run = subprocess.run(cmd, cwd=self.project.parent, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
        result_path = output / "result.json"
        if not result_path.exists():
            raise OracleError(f"driver produced no result.json (rc={run.returncode}):\n{run.stdout}")
        result = json.loads(result_path.read_text(encoding="utf-8"))
        if run.returncode != 0 or not result.get("passed"):
            raise OracleError(f"driver failed (rc={run.returncode}): {result}\n{run.stdout}")
        return result, run.stdout
