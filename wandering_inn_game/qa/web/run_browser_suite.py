#!/usr/bin/env python3
"""Run the browser-only manifest registry, preserving each emulated profile."""

from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

GAME = Path(__file__).resolve().parents[2]
MANIFEST = GAME / "qa/manifest.json"
COSTS = GAME / "qa/web/browser_case_seconds.json"
PROFILES = {"iphone", "android"}
PROOFS = {"hold": "holdProof", "pre_arm": "preArmProof", "tap": "tapProof", "drag": "dragProof", "cancel": "cancelProof"}
NOISE = re.compile(r"SCRIPT ERROR|Parse Error|WARNING|ERROR:|\[console:error\]|\[console:warning\]|\[pageerror\]")


# Screenshot readback stalls are renderer telemetry; the SVG warning is the
# existing Ubuntu web-CI exception. Keep both in artifacts, fail other warnings.
def known_renderer_warning(line: str) -> bool:
    message = line.removeprefix("[console:warning] ")
    return bool(re.fullmatch(
        r"\[\.WebGL-0x[0-9a-fA-F]+\]GL Driver Message \(OpenGL, Performance, GL_CLOSE_PATH_NV, High\): GPU stall due to ReadPixels(?: \(this message will no longer repeat\))?",
        message,
    )) or bool(re.fullmatch(
        r"(?:WARNING: )?ImageLoaderSVG: Target canvas dimensions 51500[×x]51500 \(with scale 1\.00\) exceed the max supported dimensions 16384[×x]16384\. The target canvas will be scaled down\.", message,
    ))


def cases(manifest: dict) -> list[tuple[dict, str]]:
    if not isinstance(manifest, dict) or set(manifest) - {"_comment", "scripts", "browser_scripts"}:
        raise ValueError("unknown or malformed manifest section")
    native, browser = manifest.get("scripts"), manifest.get("browser_scripts")
    if not isinstance(native, list) or not isinstance(browser, list) or not browser:
        raise ValueError("scripts and nonempty browser_scripts arrays are required")
    if any(not isinstance(row, dict) or not isinstance(row.get("script"), str) for row in native):
        raise ValueError("malformed native script registry")
    seen = {row["script"] for row in native}
    result = []
    allowed = {"script", "seed", "fixture", "profiles", "required_touch_proofs", "note", "surfaces"}
    for entry in browser:
        if not isinstance(entry, dict) or set(entry) - allowed:
            raise ValueError("unknown or malformed browser script field")
        name = entry.get("script")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", name) or name in seen:
            raise ValueError(f"invalid, duplicate or native browser script: {name!r}")
        seen.add(name)
        if type(entry.get("seed")) is not int:
            raise ValueError(f"{name}: integer seed is required")
        if ("fixture" not in entry or (entry["fixture"] is not None and (not isinstance(entry["fixture"], str) or not entry["fixture"]))
                or not isinstance(entry.get("note"), str) or not entry["note"]):
            raise ValueError(f"{name}: explicit fixture (null for fresh creation) and note are required")
        profiles, proofs = entry.get("profiles"), entry.get("required_touch_proofs")
        if not isinstance(profiles, list) or not profiles or any(p not in PROFILES for p in profiles) or len(set(profiles)) != len(profiles):
            raise ValueError(f"{name}: profiles must be unique known emulated profiles")
        if not isinstance(proofs, list) or not proofs or any(p not in PROOFS for p in proofs) or len(set(proofs)) != len(proofs):
            raise ValueError(f"{name}: required_touch_proofs must name known proofs")
        result.extend((entry, profile) for profile in profiles)
    return result


def evaluate_run(entry: dict, profile: str, returncode: int, log: str, result: dict, evidence: dict, expected_steps: int | None = None) -> list[str]:
    failures = []
    if returncode != 0 or result.get("passed") is not True or "QA_RESULT: PASS" not in log:
        failures.append("runner failed or produced no successful game result")
    count = result.get("steps_run")
    if (type(count) is not int or count <= 0 or count != result.get("steps_total")
            or (expected_steps is not None and count != expected_steps)
            or result.get("script") != f"res://qa/scripts/{entry['script']}.json"
            or result.get("aborted") is not False or result.get("failures") != []):
        failures.append("game result is incomplete, aborted or names the wrong script")
    unexpected_log = any(NOISE.search(line) and not known_renderer_warning(line) for line in log.splitlines())
    unexpected_warnings = [line for line in evidence.get("warnings", []) if not known_renderer_warning(line)]
    if unexpected_log or evidence.get("errors") or unexpected_warnings:
        failures.append("browser/game diagnostics contain an error or warning")
    if evidence.get("emulated") is not True or evidence.get("device") != profile or evidence.get("touchMode") is not True:
        failures.append("missing matching emulated browser-touch context")
    events = evidence.get("runtime", {}).get("events", [])
    contacts = [event for event in events if event.get("type") == "touchstart"]
    if not contacts or any(event.get("trusted") is not True for event in events):
        failures.append("no trusted browser contacts or an untrusted contact was recorded")
    if evidence.get("timedTouchPassed") is not True:
        failures.append("browser touch timing verdict is missing or failed")
    for required in entry["required_touch_proofs"]:
        proofs = [request[PROOFS[required]] for request in evidence.get("requests", []) if PROOFS[required] in request]
        if not proofs or any(proof.get("passed") is not True for proof in proofs):
            failures.append(f"missing or failed {required} touch proof")
    return failures


def script_timeout(name: str) -> int:
    seconds = json.loads((GAME / "qa/scripts" / f"{name}.json").read_text()).get("qa_timeout_sec", 120)
    if type(seconds) is not int or not 1 <= seconds <= 600:
        raise ValueError(f"{name}: qa_timeout_sec must be 1..600")
    return seconds + 60


def validated_cases() -> list[tuple[dict, str]]:
    selected = cases(json.loads(MANIFEST.read_text()))
    for entry, _ in selected:
        script = json.loads((GAME / "qa/scripts" / f"{entry['script']}.json").read_text())
        script_timeout(entry["script"])
        if script.get("fixture_save") != entry["fixture"]:
            raise ValueError(f"{entry['script']}: fixture differs from script fixture_save")
    return selected


# Hints only balance CI shards; an unhinted script costs its full timeout.
def case_costs(selected: list[tuple[dict, str]], hints: dict) -> list[int]:
    if not isinstance(hints, dict) or set(hints) - {"_comment", "seconds"} or not isinstance(hints.get("seconds"), dict):
        raise ValueError("malformed browser case cost hints")
    names = {entry["script"] for entry, _ in selected}
    for name, seconds in hints["seconds"].items():
        if name not in names or type(seconds) is not int or not 1 <= seconds <= 660:
            raise ValueError(f"{name}: cost hint must name a registered browser script with 1..660 seconds")
    return [hints["seconds"].get(entry["script"], script_timeout(entry["script"])) for entry, _ in selected]


def parse_shard(text: str, total: int) -> tuple[int, int]:
    match = re.fullmatch(r"([1-9][0-9]*)/([1-9][0-9]*)", text)
    if not match or int(match[1]) > int(match[2]) or int(match[2]) > total:
        raise ValueError(f"shard must be K/N with 1 <= K <= N <= {total} cases: {text!r}")
    return int(match[1]), int(match[2])


# Longest case first onto the least-loaded shard, ties by registry position, so
# every job of one checkout derives the same partition. Returns registry order.
def shard_cases(selected: list[tuple[dict, str]], costs: list[int], index: int, count: int) -> list[tuple[dict, str]]:
    loads, owner = [0] * count, {}
    for position in sorted(range(len(selected)), key=lambda i: (-costs[i], i)):
        shard = min(range(count), key=lambda k: (loads[k], k))
        loads[shard] += costs[position]
        owner[position] = shard
    return [case for position, case in enumerate(selected) if owner[position] == index - 1]


# Wall time minus in_page_ms is browser launch, audio probe, teardown and copy.
def case_timing(destination: Path, seconds: float) -> dict:
    timing = {"seconds": round(seconds, 1)}
    try:
        evidence = json.loads((destination / "browser-evidence.json").read_text())
        events = json.loads((destination / "events.json").read_text())
        requests = evidence.get("requests", [])
        timing |= {
            "startup_ready_ms": round(evidence["startup"]["ready_at_ms"], 1),
            "in_page_ms": round(max([event.get("browser_time_ms", 0) for event in events] + [request.get("finished", 0) for request in requests]), 1),
            "touch_requests": len(requests),
            "contact_ms": round(sum(request["finished"] - request["started"] for request in requests), 1),
        }
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        pass
    return timing


def run(selected: list[tuple[dict, str]], shard: tuple[int, int], output: Path) -> bool:
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    results = []
    for entry, profile in selected:
        name = entry["script"]
        destination = output / profile / name
        destination.mkdir(parents=True)
        source = GAME / "qa_output" / f"web_{name}"
        # The other profile of this script wrote here; never copy its evidence.
        shutil.rmtree(source, ignore_errors=True)
        command = ["bash", str(GAME / "qa/web/run_web_qa.sh"), name, str(entry["seed"]), "--skip-export", "--touch", f"--device={profile}"]
        started = time.monotonic()
        try:
            completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=script_timeout(entry["script"]))
            returncode, log = completed.returncode, completed.stdout
        except subprocess.TimeoutExpired as exc:
            returncode, log = 124, (exc.stdout or b"").decode(errors="replace")
        elapsed = time.monotonic() - started
        (destination / "runner.log").write_text(log)
        if source.exists():
            shutil.copytree(source, destination, dirs_exist_ok=True)
        try:
            result = json.loads((destination / "result.json").read_text())
            evidence = json.loads((destination / "browser-evidence.json").read_text())
            expected_steps = len(json.loads((GAME / "qa/scripts" / f"{name}.json").read_text())["steps"])
            failures = evaluate_run(entry, profile, returncode, log, result, evidence, expected_steps)
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            failures = [f"missing or malformed browser evidence: {exc}"]
        row = {"script": name, "profile": profile, "passed": not failures, "runner_exit": returncode, "failures": failures,
               "timing": case_timing(destination, elapsed)}
        results.append(row)
        print(f"BROWSER CASE {'PASS' if not failures else 'FAIL'}: {name} {profile} ({elapsed:.1f}s)", flush=True)
        for failure in failures:
            print(f"  {failure}", flush=True)
    passed = all(row["passed"] for row in results)
    summary = {"passed": passed, "shard": {"index": shard[0], "count": shard[1]}, "cases": results}
    (output / "result.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"BROWSER SUITE {'PASS' if passed else 'FAIL'}: {len(results)} cases (shard {shard[0]}/{shard[1]}); artifacts {output}")
    return passed


# Re-derives the partition and re-evaluates every case from its own artifacts,
# so a shard verdict, a dropped case or a second export cannot pass the merge.
def merge(shard_dirs: list[Path], output: Path, expected_pck: str | None) -> list[str]:
    selected = validated_cases()
    costs = case_costs(selected, json.loads(COSTS.read_text()))
    entries = {(entry["script"], profile): entry for entry, profile in selected}
    problems, summaries = [], {}
    for directory in shard_dirs:
        try:
            summary = json.loads((directory / "result.json").read_text())
            index, count = summary["shard"]["index"], summary["shard"]["count"]
            if type(index) is not int or type(count) is not int or not isinstance(summary["cases"], list):
                raise TypeError("shard index/count and cases are required")
        except (OSError, ValueError, TypeError, KeyError) as exc:
            problems.append(f"{directory}: malformed shard summary: {exc}")
            continue
        if index in summaries:
            problems.append(f"{directory}: shard {index} reported twice")
        summaries[index] = (directory, count, summary)
    output.mkdir(parents=True, exist_ok=True)
    counts = {count for _, count, _ in summaries.values()}
    if len(counts) != 1 or set(summaries) != set(range(1, max(counts, default=0) + 1)):
        problems.append(f"shards {sorted(summaries)} with counts {sorted(counts)} are not one complete set")
        (output / "result.json").write_text(json.dumps({"passed": False, "problems": problems}, indent=2) + "\n")
        return problems
    count = counts.pop()
    rows, pcks, ran = {}, set(), Counter()
    for index in sorted(summaries):
        directory, _, summary = summaries[index]
        planned = [(entry["script"], profile) for entry, profile in shard_cases(selected, costs, index, count)]
        reported = [(row.get("script"), row.get("profile")) for row in summary["cases"] if isinstance(row, dict)]
        if reported != planned or len(reported) != len(summary["cases"]):
            problems.append(f"shard {index}/{count} ran {reported}, planned {planned}")
        ran.update(reported)
        for row in summary["cases"]:
            key = (row.get("script"), row.get("profile")) if isinstance(row, dict) else None
            if key not in entries:
                continue
            case = directory / key[1] / key[0]
            try:
                result = json.loads((case / "result.json").read_text())
                evidence = json.loads((case / "browser-evidence.json").read_text())
                log = (case / "runner.log").read_text()
                steps = len(json.loads((GAME / "qa/scripts" / f"{key[0]}.json").read_text())["steps"])
                failures = evaluate_run(entries[key], key[1], row.get("runner_exit"), log, result, evidence, steps)
                pcks.add(evidence.get("buildPckSha256"))
            except (OSError, ValueError, TypeError, AttributeError) as exc:
                failures = [f"missing or malformed browser evidence: {exc}"]
            if row.get("passed") is not True or row.get("failures") != []:
                failures.append("shard reported this case as failed")
            problems.extend(f"{key[0]} {key[1]}: {failure}" for failure in failures)
            if key not in rows:
                rows[key] = row | {"shard": index, "passed": not failures, "failures": failures}
                if case.is_dir():
                    shutil.copytree(case, output / key[1] / key[0])
    expected = Counter(list(entries))
    if ran != expected:
        problems.append(f"cases not run exactly once: {sorted((ran - expected) + (expected - ran))}")
    if len(pcks) != 1 or not expected_pck or pcks != {expected_pck}:
        problems.append(f"cases used exports {sorted(map(str, pcks))}, expected one export {expected_pck!r}")
    merged = {"passed": not problems, "shards": count, "build_pck_sha256": expected_pck,
              "cases": [rows[key] for key in entries if key in rows], "problems": problems}
    (output / "result.json").write_text(json.dumps(merged, indent=2) + "\n")
    for index in sorted(summaries):
        seconds = sum(row.get("timing", {}).get("seconds", 0) for row in summaries[index][2]["cases"] if isinstance(row, dict))
        print(f"BROWSER SHARD {index}/{count}: {len(summaries[index][2]['cases'])} cases, {seconds:.1f}s")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-export", action="store_true")
    parser.add_argument("--list", action="store_true", help="validate and print browser cases without launching them")
    parser.add_argument("--shard", metavar="K/N", help="run only the Kth of N cost-balanced case partitions")
    parser.add_argument("--merge", nargs="+", type=Path, metavar="SHARD_DIR", help="verify and combine every shard's artifacts")
    parser.add_argument("--expect-pck-sha256", help="with --merge: the export every case must have loaded")
    args = parser.parse_args()
    output = GAME / "qa_output/browser_suite"
    try:
        selected = validated_cases()
        if args.merge:
            if args.shard or args.list or args.skip_export:
                raise ValueError("--merge cannot combine with --shard, --list or --skip-export")
            shutil.rmtree(output, ignore_errors=True)
            problems = merge(args.merge, output, args.expect_pck_sha256)
            for problem in problems:
                print(f"  {problem}", flush=True)
            print(f"BROWSER SUITE {'FAIL' if problems else 'PASS'}: {len(selected)} cases merged; artifacts {output}")
            return 1 if problems else 0
        shard = parse_shard(args.shard, len(selected)) if args.shard else (1, 1)
        selected = shard_cases(selected, case_costs(selected, json.loads(COSTS.read_text())), *shard)
    except (OSError, ValueError, TypeError) as exc:
        print(f"BROWSER SUITE INVALID: {exc}", file=sys.stderr)
        return 2
    if args.list:
        for entry, profile in selected:
            print(f"{entry['script']} seed={entry['seed']} profile={profile} --touch")
        return 0
    if not args.skip_export:
        subprocess.run(["bash", str(GAME / "qa/web/export_web.sh")], check=True)
    return 0 if run(selected, shard, output) else 1


if __name__ == "__main__":
    raise SystemExit(main())
