#!/usr/bin/env python3
"""Continuous-journey gate (#515): run every registered journey and report it.

Each journey in qa/journeys.json runs headless at its manifest seed. It fails
on a nonzero exit, a missing or failing result.json, unrun steps, engine noise
(qa/noise_scan.sh), a missing final checkpoint or an exceeded budget. The
registry must match the manifest's `journey` tier exactly and may not be
empty. Writes qa_output/journey_gate/report.{json,md} with build SHA, route,
seed, duration, reached checkpoint, resource-ledger summary and artifacts.

    python3 wandering_inn_game/qa/journey_gate.py [--only a,b] [--out DIR] [--registry FILE]
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

QA = Path(__file__).resolve().parent
GAME = QA.parent
ROOT = GAME.parent
sys.path.insert(0, str(ROOT / "scripts"))
import journey_ledger  # noqa: E402

CHECKPOINT = re.compile(r"^QA_CHECKPOINT: (\S+) -> ")
Runner = Callable[[dict, Path], int]


def registration_errors(registry: list[dict], manifest: list[dict]) -> list[str]:
	errors = [] if registry else ["journey registry is empty"]
	rows = {row.get("script"): row for row in manifest}
	listed = {entry.get("script") for entry in registry}
	for entry in registry:
		row = rows.get(entry.get("script"))
		if row is None:
			errors.append(f"{entry.get('script')}: registered journey missing from manifest")
		elif "journey" not in row.get("tiers", []):
			errors.append(f"{entry.get('script')}: manifest row lacks the journey tier")
		for key in ("route", "checkpoint", "budget_sec"):
			if not entry.get(key):
				errors.append(f"{entry.get('script')}: registry entry lacks {key}")
	for name, row in rows.items():
		if "journey" in row.get("tiers", []) and name not in listed:
			errors.append(f"{name}: manifest journey tier is not in the registry")
	return errors


def run_qa(entry: dict, log: Path) -> int:
	command = ["bash", str(QA / "run_qa.sh"), entry["script"], "headless"]
	if entry.get("seed") is not None:
		command.append(f"--seed={entry['seed']}")
	with log.open("w") as handle:
		return subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT,
			timeout=int(entry["budget_sec"]) * 3).returncode


def evaluate(entry: dict, out: Path, qa_output: Path, runner: Runner) -> dict:
	name = entry["script"]
	log = out / f"{name}.log"
	report = {"script": name, "route": entry["route"], "seed": entry.get("seed"), "budget_sec": entry["budget_sec"],
		"required_checkpoint": entry["checkpoint"], "artifacts": {"log": str(log)}, "errors": []}
	result_path = qa_output / name / "result.json"
	result_path.unlink(missing_ok=True)
	started = time.monotonic()
	try:
		code = runner(entry, log)
	except (OSError, subprocess.SubprocessError) as error:
		report["errors"].append(f"launch failed: {error}")
		return report
	report["duration_sec"] = round(time.monotonic() - started, 1)
	report["exit"] = code
	if code != 0:
		report["errors"].append(f"exit {code}")
	if report["duration_sec"] > entry["budget_sec"]:
		report["errors"].append(f"over budget: {report['duration_sec']}s > {entry['budget_sec']}s")
	if not result_path.exists():
		report["errors"].append("no result.json")
	else:
		result = json.loads(result_path.read_text())
		report["artifacts"]["result"] = str(result_path)
		report["steps"] = f"{result.get('steps_run')}/{result.get('steps_total')}"
		if result.get("passed") is not True:
			report["errors"].append(f"result not passed: {result.get('failures')}")
		if result.get("steps_run") != result.get("steps_total"):
			report["errors"].append(f"steps unrun: {report['steps']}")
	text = log.read_text() if log.exists() else ""
	reached = [match.group(1) for line in text.splitlines() if (match := CHECKPOINT.match(line))]
	report["reached_checkpoint"] = reached[-1] if reached else None
	if entry["checkpoint"] not in reached:
		report["errors"].append(f"checkpoint {entry['checkpoint']} not reached (last: {report['reached_checkpoint']})")
	noise = subprocess.run(["bash", str(QA / "noise_scan.sh"), str(log)], capture_output=True, text=True) if log.exists() else None
	if noise is None or noise.returncode != 0:
		report["errors"].append("engine noise: " + (noise.stdout.strip()[:300] if noise else "no log"))
	events = qa_output / name / "events.jsonl"
	if events.exists():
		report["artifacts"]["events"] = str(events)
		rows = [json.loads(line) for line in events.read_text().splitlines() if line.strip()]
		summary = journey_ledger.build(rows)["summary"]
		report["ledger"] = {key: summary[key] for key in ("fights", "wins", "losses", "retried", "sleeps", "gold_final")}
	return report


def gate(registry: list[dict], manifest: list[dict], out: Path, qa_output: Path, runner: Runner, only: set[str] | None = None) -> dict:
	out.mkdir(parents=True, exist_ok=True)
	rows = {row.get("script"): row for row in manifest}
	errors = registration_errors(registry, manifest)
	selected = [entry for entry in registry if not only or entry["script"] in only]
	if not selected:
		errors.append("no journeys selected")
	if only and (unknown := only - {entry["script"] for entry in registry}):
		errors.append(f"unknown journeys selected: {sorted(unknown)}")
	journeys = []
	for entry in selected:
		entry = dict(entry, seed=rows.get(entry["script"], {}).get("seed"))
		journeys.append(evaluate(entry, out, qa_output, runner))
	try:
		sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
	except OSError:
		sha = ""
	report = {"sha": sha, "errors": errors, "journeys": journeys,
		"passed": not errors and all(not j["errors"] for j in journeys)}
	(out / "report.json").write_text(json.dumps(report, indent=1) + "\n")
	(out / "report.md").write_text(markdown(report))
	return report


def markdown(report: dict) -> str:
	lines = [f"# Journey gate {'PASS' if report['passed'] else 'FAIL'} @ {report['sha'][:12]}", ""]
	lines += [f"- registry: {error}" for error in report["errors"]]
	lines += ["| Route | Script | Seed | Duration / budget | Steps | Checkpoint | Ledger | Result |", "|---|---|---|---|---|---|---|---|"]
	for j in report["journeys"]:
		ledger = j.get("ledger", {})
		ledger_text = f"{ledger.get('wins')}W/{ledger.get('losses')}L, {ledger.get('sleeps')} sleeps, {ledger.get('gold_final')}g" if ledger else "-"
		verdict = "ok" if not j["errors"] else "; ".join(j["errors"])
		lines.append(f"| {j['route']} | {j['script']} | {j['seed']} | {j.get('duration_sec')}s / {j['budget_sec']}s | {j.get('steps')} | {j.get('reached_checkpoint')} | {ledger_text} | {verdict} |")
	return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--only", default="")
	parser.add_argument("--out", type=Path, default=GAME / "qa_output" / "journey_gate")
	parser.add_argument("--registry", type=Path, default=QA / "journeys.json")
	args = parser.parse_args(argv)
	registry = json.loads(args.registry.read_text())["journeys"]
	manifest_data = json.loads((QA / "manifest.json").read_text())
	manifest = manifest_data if isinstance(manifest_data, list) else manifest_data["scripts"]
	only = {name for name in args.only.split(",") if name} or None
	report = gate(registry, manifest, args.out, GAME / "qa_output", run_qa, only)
	sys.stdout.write(markdown(report))
	return 0 if report["passed"] else 1


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
