#!/usr/bin/env python3
"""Run the browser-only manifest registry, preserving each emulated profile."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

GAME = Path(__file__).resolve().parents[2]
MANIFEST = GAME / "qa/manifest.json"
PROFILES = {"iphone", "android"}
PROOFS = {"hold": "holdProof", "pre_arm": "preArmProof"}
NOISE = re.compile(r"SCRIPT ERROR|Parse Error|WARNING|ERROR:|\[console:error\]|\[console:warning\]|\[pageerror\]")


# Screenshot readback stalls are renderer telemetry; the SVG warning is the
# existing Ubuntu web-CI exception. Keep both in artifacts, fail other warnings.
def known_renderer_warning(line: str) -> bool:
    message = line.removeprefix("[console:warning] ")
    return bool(re.fullmatch(
        r"\[\.WebGL-0x[0-9a-fA-F]+\]GL Driver Message \(OpenGL, Performance, GL_CLOSE_PATH_NV, High\): GPU stall due to ReadPixels(?: \(this message will no longer repeat\))?",
        message,
    )) or ("ImageLoaderSVG: Target canvas dimensions 51500" in message
           and not re.search(r"SCRIPT ERROR|Parse Error|ERROR:", message))


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
        if any(not isinstance(entry.get(key), str) or not entry[key] for key in ("fixture", "note")):
            raise ValueError(f"{name}: fixture and note are required")
        profiles, proofs = entry.get("profiles"), entry.get("required_touch_proofs")
        if not isinstance(profiles, list) or not profiles or any(p not in PROFILES for p in profiles) or len(set(profiles)) != len(profiles):
            raise ValueError(f"{name}: profiles must be unique known emulated profiles")
        if not isinstance(proofs, list) or not proofs or any(p not in PROOFS for p in proofs) or len(set(proofs)) != len(proofs):
            raise ValueError(f"{name}: required_touch_proofs must name known proofs")
        result.extend((entry, profile) for profile in profiles)
    return result


def evaluate_run(entry: dict, profile: str, returncode: int, log: str, result: dict, evidence: dict) -> list[str]:
    failures = []
    if returncode != 0 or result.get("passed") is not True or "QA_RESULT: PASS" not in log:
        failures.append("runner failed or produced no successful game result")
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-export", action="store_true")
    parser.add_argument("--list", action="store_true", help="validate and print browser cases without launching them")
    args = parser.parse_args()
    try:
        selected = cases(json.loads(MANIFEST.read_text()))
        for entry, _ in selected:
            script = json.loads((GAME / "qa/scripts" / f"{entry['script']}.json").read_text())
            if script.get("fixture_save") != entry["fixture"]:
                raise ValueError(f"{entry['script']}: fixture differs from script fixture_save")
    except (OSError, ValueError, TypeError) as exc:
        print(f"BROWSER SUITE INVALID: {exc}", file=sys.stderr)
        return 2
    if args.list:
        for entry, profile in selected:
            print(f"{entry['script']} seed={entry['seed']} profile={profile} --touch")
        return 0
    if not args.skip_export:
        subprocess.run(["bash", str(GAME / "qa/web/export_web.sh")], check=True)
    output = GAME / "qa_output/browser_suite"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    results = []
    for entry, profile in selected:
        name = entry["script"]
        destination = output / profile / name
        destination.mkdir(parents=True)
        command = ["bash", str(GAME / "qa/web/run_web_qa.sh"), name, str(entry["seed"]), "--skip-export", "--touch", f"--device={profile}"]
        try:
            run = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
            returncode, log = run.returncode, run.stdout
        except subprocess.TimeoutExpired as exc:
            returncode, log = 124, (exc.stdout or b"").decode(errors="replace")
        (destination / "runner.log").write_text(log)
        source = GAME / "qa_output" / f"web_{name}"
        if source.exists():
            shutil.copytree(source, destination, dirs_exist_ok=True)
        try:
            result = json.loads((destination / "result.json").read_text())
            evidence = json.loads((destination / "browser-evidence.json").read_text())
            failures = evaluate_run(entry, profile, returncode, log, result, evidence)
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            failures = [f"missing or malformed browser evidence: {exc}"]
        row = {"script": name, "profile": profile, "passed": not failures, "runner_exit": returncode, "failures": failures}
        results.append(row)
        print(f"BROWSER CASE {'PASS' if not failures else 'FAIL'}: {name} {profile}", flush=True)
        for failure in failures:
            print(f"  {failure}", flush=True)
    passed = all(row["passed"] for row in results)
    (output / "result.json").write_text(json.dumps({"passed": passed, "cases": results}, indent=2) + "\n")
    print(f"BROWSER SUITE {'PASS' if passed else 'FAIL'}: {len(results)} cases; artifacts {output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
