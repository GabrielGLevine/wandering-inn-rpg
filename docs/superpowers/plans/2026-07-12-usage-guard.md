# Usage Guard Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Usage-aware graceful wind-down: a status script reading official `claude -p /usage` percentages with burn-rate projection, an escalation-only PostToolUse hook, and a `wi-usage-guard` skill so sessions drain to quiescence instead of dying mid-flight at usage cutoffs.

**Architecture:** One Python module (`scripts/usage_guard.py`) holds all logic — parse, rolling-sample cache, tier computation, hook. Two thin bash wrappers (`usage_status.sh`, `usage_hook.sh`) are the public entry points. A project-settings hook notifies the model only on tier changes. A skill documents the per-tier protocol.

**Tech Stack:** Python 3 stdlib only (json, re, subprocess, zoneinfo), bash wrappers, Claude Code PostToolUse hooks, unittest.

**Spec:** `docs/superpowers/specs/2026-07-12-usage-guard-design.md` — read it before starting.

## Global Constraints

- Fail-soft EVERYWHERE: no failure of query, parse, cache, or hook may ever block a tool call or return a blocking exit code from the hook. Hook always exits 0.
- No new dependencies: Python stdlib only; no jq, no ccusage, no pip installs.
- Tier bands (exact): session CAUTION ≥70 / WINDDOWN ≥85 / QUIESCE ≥95; weekly CAUTION ≥60 / WINDDOWN ≥75 / QUIESCE ≥90 (worse of week-all and week-Fable). Worst of session/weekly wins.
- Near-reset softening: session reset ≤15 min away caps the session component at CAUTION. Weekly is never softened.
- Dynamic escalation: burn rate projects exhaustion ≤60 min away AND before the session reset → +1 tier (never past QUIESCE).
- Exit codes: 0 OK / 10 CAUTION / 20 WINDDOWN / 30 QUIESCE / 0 UNKNOWN.
- Cache: `~/.claude/usage-guard-cache.json` (env `USAGE_GUARD_CACHE` overrides), rolling samples, 5-min TTL, 24h retention, atomic writes (temp file + `os.replace`).
- Test overrides: `USAGE_GUARD_FAKE` (kv string), `USAGE_GUARD_NOW` (epoch), `USAGE_GUARD_CACHE` (path). Tests must never invoke the real `claude` CLI.
- This repo is PUBLIC and settings.json is committed: the hook must no-op silently on machines without the `claude` CLI or python3.
- Commit after each task. Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Core logic — parse, tiers, burn rate

**Files:**
- Create: `scripts/usage_guard.py`
- Test: `scripts/tests/test_usage_guard.py`

**Interfaces:**
- Produces (used by Tasks 2–3): `parse_usage(text: str, now_ts: float) -> dict|None` (keys: `ts, session_pct, week_pct, fable_pct, session_reset_ts, week_reset_ts`); `compute_tier(session_pct, week_pct, fable_pct, mins_to_reset, rate_per_min) -> (tier_name: str, reasons: list[str])`; `burn_rate(samples: list[dict], now_ts: float) -> float|None` (session %/minute); constants `TIERS`, `EXIT_CODES`, `HINTS`, `SESSION_BANDS`, `WEEK_BANDS`, `CACHE_TTL_SECS`, `STALE_LIMIT_SECS`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/tests/test_usage_guard.py`:

```python
"""Tests for usage_guard core logic. Run: python3 scripts/tests/test_usage_guard.py -v"""
import importlib.util
import os
import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

HERE = os.path.dirname(os.path.abspath(__file__))
GUARD_PATH = os.path.join(HERE, "..", "usage_guard.py")
_spec = importlib.util.spec_from_file_location("usage_guard", GUARD_PATH)
ug = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ug)

# 02:40 America/Chicago on Jul 12 2026 — 120 min before the fixture's session reset
NOW = datetime(2026, 7, 12, 2, 40, tzinfo=ZoneInfo("America/Chicago")).timestamp()

FIXTURE = """You are currently using your subscription to power your Claude Code usage

Current session: 11% used · resets Jul 12 at 4:40am (America/Chicago)
Current week (all models): 3% used · resets Jul 18 at 8pm (America/Chicago)
Current week (Fable): 5% used · resets Jul 18 at 8pm (America/Chicago)

What's contributing to your limits usage?
"""


class TestParse(unittest.TestCase):
    def test_parse_fixture(self):
        s = ug.parse_usage(FIXTURE, NOW)
        self.assertEqual(s["session_pct"], 11)
        self.assertEqual(s["week_pct"], 3)
        self.assertEqual(s["fable_pct"], 5)
        self.assertAlmostEqual(s["session_reset_ts"] - NOW, 120 * 60, delta=1)

    def test_parse_no_minutes_reset(self):
        # "8pm" (no :MM) must parse — the weekly line uses this form
        s = ug.parse_usage(FIXTURE, NOW)
        self.assertIsNotNone(s["week_reset_ts"])
        self.assertGreater(s["week_reset_ts"], NOW)

    def test_parse_garbage_returns_none(self):
        self.assertIsNone(ug.parse_usage("no usage info here", NOW))


class TestTiers(unittest.TestCase):
    def tier(self, *a, **kw):
        return ug.compute_tier(*a, **kw)[0]

    def test_session_bands(self):
        self.assertEqual(self.tier(69, 0, 0, None, None), "OK")
        self.assertEqual(self.tier(70, 0, 0, None, None), "CAUTION")
        self.assertEqual(self.tier(85, 0, 0, None, None), "WINDDOWN")
        self.assertEqual(self.tier(95, 0, 0, None, None), "QUIESCE")

    def test_weekly_bands_stricter(self):
        self.assertEqual(self.tier(0, 60, 0, None, None), "CAUTION")
        self.assertEqual(self.tier(0, 0, 75, None, None), "WINDDOWN")
        self.assertEqual(self.tier(0, 92, 0, None, None), "QUIESCE")

    def test_worst_wins(self):
        self.assertEqual(self.tier(72, 80, 0, None, None), "WINDDOWN")

    def test_near_reset_softening(self):
        self.assertEqual(self.tier(96, 0, 0, 10, None), "CAUTION")

    def test_weekly_never_softened(self):
        self.assertEqual(self.tier(96, 92, 0, 10, None), "QUIESCE")

    def test_dynamic_escalation(self):
        # 55% used, 0.75%/min -> exhaustion in 60m, reset 120m away -> escalate
        self.assertEqual(self.tier(55, 0, 0, 120, 0.75), "CAUTION")

    def test_no_escalation_when_reset_comes_first(self):
        self.assertEqual(self.tier(55, 0, 0, 30, 0.75), "OK")

    def test_escalation_never_past_quiesce(self):
        self.assertEqual(self.tier(96, 0, 0, None, 5.0), "QUIESCE")


class TestBurnRate(unittest.TestCase):
    def test_basic_rate(self):
        samples = [
            {"ts": NOW - 1200, "session_pct": 50},
            {"ts": NOW, "session_pct": 60},
        ]
        self.assertAlmostEqual(ug.burn_rate(samples, NOW), 0.5)

    def test_reset_drop_discards_prefix(self):
        samples = [
            {"ts": NOW - 1500, "session_pct": 90},
            {"ts": NOW - 900, "session_pct": 5},
            {"ts": NOW - 300, "session_pct": 8},
        ]
        self.assertAlmostEqual(ug.burn_rate(samples, NOW), 3 / 10.0)

    def test_insufficient_samples(self):
        self.assertIsNone(ug.burn_rate([{"ts": NOW, "session_pct": 40}], NOW))

    def test_old_samples_excluded(self):
        samples = [
            {"ts": NOW - 7200, "session_pct": 10},
            {"ts": NOW, "session_pct": 60},
        ]
        self.assertIsNone(ug.burn_rate(samples, NOW))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 scripts/tests/test_usage_guard.py -v`
Expected: FAIL at import (`FileNotFoundError` / cannot load `usage_guard.py`).

- [ ] **Step 3: Write the core module**

Create `scripts/usage_guard.py`:

```python
#!/usr/bin/env python3
"""Usage guard — usage-aware wind-down signal for Claude Code sessions.

Official source: `claude -p /usage` (works in print mode). A rolling
sample cache enables burn-rate projection. Tier ladder: OK -> CAUTION ->
WINDDOWN -> QUIESCE. Protocol: .claude/skills/wi-usage-guard/SKILL.md.
Spec: docs/superpowers/specs/2026-07-12-usage-guard-design.md
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pre-3.9: fall back to naive local time
    ZoneInfo = None

# --- Tunable thresholds ---
SESSION_BANDS = (70, 85, 95)   # CAUTION / WINDDOWN / QUIESCE
WEEK_BANDS = (60, 75, 90)      # stricter: weekly has no quick reset
SOFTEN_MINS = 15               # session reset this close -> cap session tier at CAUTION
RATE_WINDOW_MINS = 30          # burn-rate lookback
DYNAMIC_HORIZON_MINS = 60      # projected exhaustion within this -> +1 tier
CACHE_TTL_SECS = 300           # sample fresh enough to reuse
STALE_LIMIT_SECS = 3600        # older than this -> UNKNOWN rather than guess
CACHE_KEEP_SECS = 24 * 3600
FETCH_TIMEOUT_SECS = 90
REFRESH_LOCK_SECS = 120

TIERS = ("OK", "CAUTION", "WINDDOWN", "QUIESCE")
EXIT_CODES = {"OK": 0, "CAUTION": 10, "WINDDOWN": 20, "QUIESCE": 30, "UNKNOWN": 0}
HINTS = {
    "OK": "normal operations",
    "CAUTION": "no new lanes/workflows; finish in-flight; prefer cheap ops",
    "WINDDOWN": "drain lanes, commit WIP seams, update HANDOFF",
    "QUIESCE": "state-saving actions only, then wait for reset (session) or stop (weekly)",
    "UNKNOWN": "usage query failed; proceed, re-check within the hour",
}

SESSION_RE = re.compile(
    r"Current session:\s*(\d+)%\s*used(?:\s*·\s*resets\s+(.+?)\s+\(([^)]+)\))?")
WEEK_ALL_RE = re.compile(
    r"Current week \(all models\):\s*(\d+)%\s*used(?:\s*·\s*resets\s+(.+?)\s+\(([^)]+)\))?")
WEEK_MODEL_RE = re.compile(
    r"Current week \((?!all models)[^)]+\):\s*(\d+)%\s*used")


def parse_reset(text_dt, tz_name, now_ts):
    """'Jul 12 at 4:40am' + 'America/Chicago' -> epoch seconds, or None."""
    if not text_dt:
        return None
    tz = ZoneInfo(tz_name) if (ZoneInfo and tz_name) else None
    for fmt in ("%b %d at %I:%M%p", "%b %d at %I%p"):
        try:
            dt = datetime.strptime(text_dt.strip(), fmt)
            break
        except ValueError:
            continue
    else:
        return None
    now = datetime.fromtimestamp(now_ts, tz)
    dt = dt.replace(year=now.year, tzinfo=tz)
    if dt < now:  # year rollover (Dec sample, Jan reset)
        dt = dt.replace(year=now.year + 1)
    return dt.timestamp()


def parse_usage(text, now_ts):
    """Parse `claude -p /usage` output into a sample dict, or None."""
    m = SESSION_RE.search(text)
    if not m:
        return None
    sample = {
        "ts": now_ts,
        "session_pct": int(m.group(1)),
        "session_reset_ts": parse_reset(m.group(2), m.group(3), now_ts),
        "week_pct": 0,
        "fable_pct": 0,
        "week_reset_ts": None,
    }
    w = WEEK_ALL_RE.search(text)
    if w:
        sample["week_pct"] = int(w.group(1))
        sample["week_reset_ts"] = parse_reset(w.group(2), w.group(3), now_ts)
    f = WEEK_MODEL_RE.search(text)
    if f:
        sample["fable_pct"] = int(f.group(1))
    return sample


def band_tier(pct, bands):
    tier = 0
    for i, threshold in enumerate(bands):
        if pct >= threshold:
            tier = i + 1
    return tier


def compute_tier(session_pct, week_pct, fable_pct, mins_to_reset, rate_per_min):
    """Pure tier computation. Returns (tier_name, [reasons])."""
    reasons = []
    s = band_tier(session_pct, SESSION_BANDS)
    if s > 1 and mins_to_reset is not None and mins_to_reset <= SOFTEN_MINS:
        s = 1
        reasons.append("session reset in %dm; softened to CAUTION" % mins_to_reset)
    w = band_tier(max(week_pct, fable_pct), WEEK_BANDS)
    if w > 0 and w >= s:
        reasons.append("weekly band drives tier")
    tier = max(s, w)
    if rate_per_min and rate_per_min > 0 and session_pct < 100 and tier < 3:
        eta_mins = (100 - session_pct) / rate_per_min
        if eta_mins <= DYNAMIC_HORIZON_MINS and (
            mins_to_reset is None or eta_mins < mins_to_reset
        ):
            tier += 1
            reasons.append("burn %.0f%%/hr -> exhaustion ~%dm, before reset"
                           % (rate_per_min * 60, eta_mins))
    return TIERS[tier], reasons


def burn_rate(samples, now_ts):
    """Session %/min over the trailing window; None if <2 usable samples.
    A session_pct DROP means the window reset — only the run after the
    last drop counts."""
    recent = [s for s in samples if now_ts - s["ts"] <= RATE_WINDOW_MINS * 60]
    recent.sort(key=lambda s: s["ts"])
    start = 0
    for i in range(1, len(recent)):
        if recent[i]["session_pct"] < recent[i - 1]["session_pct"]:
            start = i
    recent = recent[start:]
    if len(recent) < 2:
        return None
    span_mins = (recent[-1]["ts"] - recent[0]["ts"]) / 60.0
    if span_mins <= 0:
        return None
    return (recent[-1]["session_pct"] - recent[0]["session_pct"]) / span_mins
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 scripts/tests/test_usage_guard.py -v`
Expected: all tests PASS (16 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/usage_guard.py scripts/tests/test_usage_guard.py
git commit -m "Usage guard core: /usage parsing, tier bands, burn-rate projection

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Cache, fetch, status command, `usage_status.sh`

**Files:**
- Modify: `scripts/usage_guard.py` (append below `burn_rate`)
- Create: `scripts/usage_status.sh`
- Test: `scripts/tests/test_usage_guard.py` (append), `scripts/tests/test_usage_status_cli.py` (create)

**Interfaces:**
- Consumes: everything from Task 1.
- Produces: CLI `scripts/usage_status.sh [--fresh]` printing one status line, exit code per `EXIT_CODES`; module functions `load_cache() -> list`, `save_cache(samples) -> list`, `refresh() -> dict|None`, `fake_sample() -> dict|None`, `assemble(sample, samples, stale_secs=0) -> dict` (keys: `tier, reasons, session_pct, week_pct, fable_pct, mins_to_reset, rate_per_min, stale_secs`), `format_line(st) -> str`, `now_ts() -> float`, `cmd_status(argv) -> int`, and a `main(argv)` dispatcher (`status` | `refresh`).

- [ ] **Step 1: Write the failing CLI tests**

Create `scripts/tests/test_usage_status_cli.py`:

```python
"""CLI tests for usage_status.sh. Run: python3 scripts/tests/test_usage_status_cli.py -v
Never invokes the real `claude` CLI (PATH is restricted)."""
import json
import os
import subprocess
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
STATUS_SH = os.path.join(HERE, "..", "usage_status.sh")
SAFE_PATH = "/usr/bin:/bin"  # python3 lives here on macOS; `claude` does not


def run_status(env_extra, args=()):
    env = {"PATH": SAFE_PATH, "HOME": env_extra.pop("HOME", "/tmp")}
    env.update(env_extra)
    return subprocess.run(["bash", STATUS_SH, *args],
                          capture_output=True, text=True, env=env)


class TestStatusCLI(unittest.TestCase):
    def test_fake_winddown_exit_20(self):
        r = run_status({"USAGE_GUARD_FAKE": "session=90 week=10"})
        self.assertEqual(r.returncode, 20)
        self.assertTrue(r.stdout.startswith("WINDDOWN"), r.stdout)

    def test_fake_quiesce_exit_30(self):
        r = run_status({"USAGE_GUARD_FAKE": "session=96 week=10"})
        self.assertEqual(r.returncode, 30)

    def test_fake_dynamic_escalation(self):
        r = run_status(
            {"USAGE_GUARD_FAKE": "session=55 week=10 rate=0.75 mins_to_reset=120"})
        self.assertEqual(r.returncode, 10)
        self.assertIn("burn", r.stdout)

    def test_fresh_cache_used_without_claude(self):
        now = time.time()
        with tempfile.TemporaryDirectory() as td:
            cache = os.path.join(td, "cache.json")
            with open(cache, "w") as fh:
                json.dump([{"ts": now - 60, "session_pct": 72, "week_pct": 5,
                            "fable_pct": 5, "session_reset_ts": now + 3600,
                            "week_reset_ts": None}], fh)
            r = run_status({"USAGE_GUARD_CACHE": cache, "HOME": td})
            self.assertEqual(r.returncode, 10)
            self.assertTrue(r.stdout.startswith("CAUTION"), r.stdout)

    def test_unknown_when_no_cache_and_no_claude(self):
        with tempfile.TemporaryDirectory() as td:
            cache = os.path.join(td, "cache.json")
            r = run_status({"USAGE_GUARD_CACHE": cache, "HOME": td})
            self.assertEqual(r.returncode, 0)
            self.assertTrue(r.stdout.startswith("UNKNOWN"), r.stdout)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 scripts/tests/test_usage_status_cli.py -v`
Expected: FAIL — `usage_status.sh` does not exist.

- [ ] **Step 3: Append cache/fetch/status to `scripts/usage_guard.py`**

Append below `burn_rate`:

```python
def now_ts():
    fake = os.environ.get("USAGE_GUARD_NOW")
    return float(fake) if fake else time.time()


def cache_path():
    return os.environ.get(
        "USAGE_GUARD_CACHE",
        os.path.expanduser("~/.claude/usage-guard-cache.json"))


def load_cache():
    try:
        with open(cache_path()) as fh:
            data = json.load(fh)
        if not isinstance(data, list):
            return []
        data.sort(key=lambda s: s.get("ts", 0))
        return data
    except Exception:
        return []


def save_cache(samples):
    cutoff = now_ts() - CACHE_KEEP_SECS
    samples = [s for s in samples if s.get("ts", 0) >= cutoff]
    path = cache_path()
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".")
    with os.fdopen(fd, "w") as fh:
        json.dump(samples, fh)
    os.replace(tmp, path)  # atomic vs concurrent sessions
    return samples


def fetch_usage_text():
    out = subprocess.run(
        ["claude", "-p", "/usage"],
        capture_output=True, text=True, timeout=FETCH_TIMEOUT_SECS,
        cwd=os.path.expanduser("~"))  # outside any project: no hook recursion
    return out.stdout


def refresh():
    """Fetch + parse + append to cache. Returns the new sample or None."""
    try:
        sample = parse_usage(fetch_usage_text(), now_ts())
    except Exception:
        sample = None
    if sample:
        save_cache(load_cache() + [sample])
    return sample


def fake_sample():
    """USAGE_GUARD_FAKE='session=90 week=10 fable=5 rate=0.5 mins_to_reset=120'
    (rate is %/min). Returns a sample dict, or None if the env var is unset."""
    raw = os.environ.get("USAGE_GUARD_FAKE")
    if not raw:
        return None
    kv = dict(p.split("=", 1) for p in raw.split())
    t = now_ts()
    return {
        "ts": t,
        "session_pct": int(kv.get("session", 0)),
        "week_pct": int(kv.get("week", 0)),
        "fable_pct": int(kv.get("fable", 0)),
        "session_reset_ts": (t + float(kv["mins_to_reset"]) * 60
                             if "mins_to_reset" in kv else None),
        "week_reset_ts": None,
        "_fake_rate": float(kv["rate"]) if "rate" in kv else None,
    }


def assemble(sample, samples, stale_secs=0):
    t = now_ts()
    reset_ts = sample.get("session_reset_ts")
    mins_to_reset = (reset_ts - t) / 60.0 if reset_ts else None
    session_pct = sample["session_pct"]
    if mins_to_reset is not None and mins_to_reset < 0:
        # window reset since this sample was taken; its session % is history
        session_pct, mins_to_reset = 0, None
    rate = sample.get("_fake_rate")
    if rate is None:
        rate = burn_rate(samples, t)
    tier, reasons = compute_tier(
        session_pct, sample["week_pct"], sample["fable_pct"],
        mins_to_reset, rate)
    return {"tier": tier, "reasons": reasons, "session_pct": session_pct,
            "week_pct": sample["week_pct"], "fable_pct": sample["fable_pct"],
            "mins_to_reset": mins_to_reset, "rate_per_min": rate,
            "stale_secs": stale_secs}


def format_line(st):
    parts = ["%s session=%d%%" % (st["tier"], st["session_pct"])]
    if st["mins_to_reset"] is not None:
        parts.append("reset~%dm" % st["mins_to_reset"])
    parts.append("week=%d%%" % st["week_pct"])
    parts.append("fable=%d%%" % st["fable_pct"])
    if st["rate_per_min"] and st["rate_per_min"] > 0:
        parts.append("rate=%.0f%%/hr" % (st["rate_per_min"] * 60))
        if st["session_pct"] < 100:
            parts.append("eta=exh~%dm"
                         % ((100 - st["session_pct"]) / st["rate_per_min"]))
    if st["stale_secs"] > CACHE_TTL_SECS:
        parts.append("(stale %dm)" % (st["stale_secs"] / 60))
    line = " ".join(parts) + " | " + HINTS[st["tier"]]
    if st["reasons"]:
        line += " [" + "; ".join(st["reasons"]) + "]"
    return line


def cmd_status(argv):
    fake = fake_sample()
    if fake:
        st = assemble(fake, [fake])
        print(format_line(st))
        return EXIT_CODES[st["tier"]]
    samples = load_cache()
    newest = samples[-1] if samples else None
    age = (now_ts() - newest["ts"]) if newest else None
    if "--fresh" in argv or newest is None or age > CACHE_TTL_SECS:
        fresh = refresh()
        if fresh:
            samples = load_cache()
            newest, age = fresh, 0.0
    if newest is None or age > STALE_LIMIT_SECS:
        print("UNKNOWN | " + HINTS["UNKNOWN"])
        return EXIT_CODES["UNKNOWN"]
    st = assemble(newest, samples, stale_secs=age)
    print(format_line(st))
    return EXIT_CODES[st["tier"]]


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "status":
        return cmd_status(argv[2:])
    if cmd == "refresh":
        return 0 if refresh() else 1
    print("usage: usage_guard.py [status [--fresh]|refresh]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Create `scripts/usage_status.sh`**

```bash
#!/bin/bash
# Usage tier check — OK/CAUTION/WINDDOWN/QUIESCE. Protocol: wi-usage-guard skill.
# Exit codes: 0 OK|UNKNOWN, 10 CAUTION, 20 WINDDOWN, 30 QUIESCE.
command -v python3 >/dev/null 2>&1 || { echo "UNKNOWN | python3 missing"; exit 0; }
exec python3 "$(cd "$(dirname "$0")" && pwd)/usage_guard.py" status "$@"
```

Then: `chmod +x scripts/usage_status.sh`

- [ ] **Step 5: Run tests to verify they pass**

Run: `python3 scripts/tests/test_usage_status_cli.py -v && python3 scripts/tests/test_usage_guard.py -v`
Expected: all PASS.

- [ ] **Step 6: Live smoke test (real /usage — one query)**

Run: `scripts/usage_status.sh --fresh; echo "exit=$?"`
Expected: one line like `OK session=NN% reset~NNNm week=N% fable=N% | normal operations`, sensible percentages, exit code matching tier. Cache file appears at `~/.claude/usage-guard-cache.json`.

- [ ] **Step 7: Commit**

```bash
git add scripts/usage_guard.py scripts/usage_status.sh scripts/tests/
git commit -m "Usage guard status CLI: rolling cache, sync fetch, one-line tier output

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Hook — escalation-only notifications

**Files:**
- Modify: `scripts/usage_guard.py` (append `hook` support)
- Create: `scripts/usage_hook.sh`
- Modify: `.claude/settings.json`
- Test: `scripts/tests/test_usage_hook.py` (create)

**Interfaces:**
- Consumes: Task 2's `load_cache`, `assemble`, `format_line`, `fake_sample`, `now_ts`, `refresh`.
- Produces: `usage_guard.py hook` subcommand (stdin: PostToolUse JSON; stdout: hook JSON with `additionalContext` ONLY on tier change; always exits 0); `scripts/usage_hook.sh` wrapper; hook registration in `.claude/settings.json`.

- [ ] **Step 1: Write the failing hook tests**

Create `scripts/tests/test_usage_hook.py`:

```python
"""Hook behavior tests. Run: python3 scripts/tests/test_usage_hook.py -v"""
import json
import os
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HOOK_SH = os.path.join(HERE, "..", "usage_hook.sh")
SAFE_PATH = "/usr/bin:/bin"


def run_hook(home, env_extra, stdin_json=None):
    env = {"PATH": SAFE_PATH, "HOME": home}
    env.update(env_extra)
    payload = json.dumps(stdin_json or {"session_id": "testsess"})
    return subprocess.run(["bash", HOOK_SH], input=payload,
                          capture_output=True, text=True, env=env)


class TestHook(unittest.TestCase):
    def test_notifies_once_on_escalation(self):
        with tempfile.TemporaryDirectory() as home:
            env = {"USAGE_GUARD_FAKE": "session=90 week=10"}
            first = run_hook(home, env)
            self.assertEqual(first.returncode, 0)
            out = json.loads(first.stdout)
            ctx = out["hookSpecificOutput"]["additionalContext"]
            self.assertIn("WINDDOWN", ctx)
            self.assertIn("wi-usage-guard", ctx)
            second = run_hook(home, env)
            self.assertEqual(second.returncode, 0)
            self.assertEqual(second.stdout.strip(), "")

    def test_silent_on_initial_ok(self):
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, {"USAGE_GUARD_FAKE": "session=10 week=5"})
            self.assertEqual(r.returncode, 0)
            self.assertEqual(r.stdout.strip(), "")

    def test_deescalation_notifies(self):
        with tempfile.TemporaryDirectory() as home:
            run_hook(home, {"USAGE_GUARD_FAKE": "session=90 week=10"})
            r = run_hook(home, {"USAGE_GUARD_FAKE": "session=5 week=5"})
            out = json.loads(r.stdout)
            self.assertIn("OK", out["hookSpecificOutput"]["additionalContext"])

    def test_fail_soft_corrupt_cache(self):
        with tempfile.TemporaryDirectory() as home:
            cache = os.path.join(home, "cache.json")
            with open(cache, "w") as fh:
                fh.write("{not json")
            r = run_hook(home, {"USAGE_GUARD_CACHE": cache})
            self.assertEqual(r.returncode, 0)

    def test_fail_soft_empty_stdin(self):
        with tempfile.TemporaryDirectory() as home:
            env = {"PATH": SAFE_PATH, "HOME": home}
            r = subprocess.run(["bash", HOOK_SH], input="",
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 scripts/tests/test_usage_hook.py -v`
Expected: FAIL — `usage_hook.sh` does not exist.

- [ ] **Step 3: Append hook support to `scripts/usage_guard.py`**

Append below `cmd_status` (above `main`):

```python
def stamp_path(session_id):
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", session_id)[:64] or "global"
    return os.path.expanduser("~/.claude/usage-guard-notify-%s" % safe)


def kick_background_refresh():
    """Detached refresh so hook calls never wait on `claude -p /usage`.
    A lockfile stops concurrent hook fires from stampeding."""
    lock = os.path.expanduser("~/.claude/usage-guard-refresh.lock")
    try:
        if (os.path.exists(lock)
                and time.time() - os.path.getmtime(lock) < REFRESH_LOCK_SECS):
            return
        os.makedirs(os.path.dirname(lock), exist_ok=True)
        with open(lock, "w") as fh:
            fh.write(str(os.getpid()))
        subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), "refresh"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True)
    except Exception:
        pass


def cmd_hook():
    """PostToolUse hook: read cache only, notify ONLY on tier change.
    Every path exits 0 — the hook must never block tools."""
    try:
        raw = sys.stdin.read()
        session_id = "global"
        if raw.strip():
            try:
                session_id = json.loads(raw).get("session_id") or "global"
            except Exception:
                pass
        fake = fake_sample()
        if fake:
            st = assemble(fake, [fake])
        else:
            samples = load_cache()
            newest = samples[-1] if samples else None
            age = (now_ts() - newest["ts"]) if newest else None
            if newest is None or age > CACHE_TTL_SECS:
                kick_background_refresh()
            if newest is None or age > STALE_LIMIT_SECS:
                return 0  # nothing trustworthy; stay silent
            st = assemble(newest, samples, stale_secs=age)
        prev = None
        try:
            with open(stamp_path(session_id)) as fh:
                prev = fh.read().strip()
        except Exception:
            pass
        if st["tier"] == prev or (prev is None and st["tier"] == "OK"):
            if prev is None:
                with open(stamp_path(session_id), "w") as fh:
                    fh.write(st["tier"])
            return 0
        with open(stamp_path(session_id), "w") as fh:
            fh.write(st["tier"])
        prev_idx = TIERS.index(prev) if prev in TIERS else 0
        direction = ("escalated" if TIERS.index(st["tier"]) > prev_idx
                     else "de-escalated")
        context = ("USAGE-GUARD %s to %s: %s — follow the wi-usage-guard "
                   "skill checklist for this tier."
                   % (direction, st["tier"], format_line(st)))
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context}}))
        return 0
    except Exception:
        return 0
```

And extend `main`'s dispatch — replace the `usage:` error block context so `main` reads:

```python
def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "status":
        return cmd_status(argv[2:])
    if cmd == "refresh":
        return 0 if refresh() else 1
    if cmd == "hook":
        return cmd_hook()
    print("usage: usage_guard.py [status [--fresh]|refresh|hook]",
          file=sys.stderr)
    return 2
```

- [ ] **Step 4: Create `scripts/usage_hook.sh`**

```bash
#!/bin/bash
# PostToolUse hook: injects a notice ONLY when the usage tier changes.
# Fail-soft by design — must never block a tool call (public repo:
# contributors without the claude CLI or python3 get a silent no-op).
command -v python3 >/dev/null 2>&1 || exit 0
python3 "$(cd "$(dirname "$0")" && pwd)/usage_guard.py" hook 2>/dev/null
exit 0
```

Then: `chmod +x scripts/usage_hook.sh`

- [ ] **Step 5: Update `.claude/settings.json`**

Replace the full file content with:

```json
{
  "permissions": {
    "allow": [
      "Bash(gh release edit:*)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/scripts/usage_hook.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `python3 scripts/tests/test_usage_hook.py -v && python3 scripts/tests/test_usage_status_cli.py -v && python3 scripts/tests/test_usage_guard.py -v`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/usage_guard.py scripts/usage_hook.sh .claude/settings.json scripts/tests/test_usage_hook.py
git commit -m "Usage guard hook: escalation-only PostToolUse notifications

Reads cache only (background refresh keeps tool calls latency-free);
notifies once per tier change per session; fail-soft everywhere.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Note: the hook takes effect for NEW sessions (hooks snapshot at session start). The controller session verifies via the direct CLI tests above; live hook firing is confirmed next session.

---

### Task 4: Skill, pointers, HANDOFF

**Files:**
- Create: `.claude/skills/wi-usage-guard/SKILL.md`
- Modify: `.claude/skills/wi-running-the-machine/SKILL.md` (Usage-aware pacing section, after the sentence ending "never run two agents on one file concurrently." at ~line 78)
- Modify: `.claude/skills/wi-start-here/SKILL.md` (Read order list, after item 4)
- Modify: `HANDOFF.md` (new section directly under the `# Wandering Inn RPG Handoff` title line)

**Interfaces:**
- Consumes: `scripts/usage_status.sh` CLI contract from Task 2 (one line + exit codes).
- Produces: documentation only — no code contracts.

- [ ] **Step 1: Create `.claude/skills/wi-usage-guard/SKILL.md`**

```markdown
---
name: wi-usage-guard
description: Use before dispatching any lane/workflow/agent wave, at session start, when a USAGE-GUARD hook notification appears, or when deciding how to wind down before a usage cutoff.
---

# Usage Guard — graceful wind-down before usage cutoffs

**Check:** `scripts/usage_status.sh` (`--fresh` forces a re-query; plain
call reuses a ≤5-min-old sample). One line out:
`TIER session=..% reset~..m week=..% fable=..% rate=..%/hr eta=exh~..m | hint`
Exit code: 0 OK/UNKNOWN, 10 CAUTION, 20 WINDDOWN, 30 QUIESCE.
A PostToolUse hook injects a `USAGE-GUARD escalated/de-escalated to ...`
notice whenever the tier CHANGES mid-flight — treat that notice as this
skill firing and act on the new tier immediately.

## When to check explicitly (mandatory)
- Session start (wi-start-here read order).
- BEFORE dispatching any lane, workflow, or agent wave.
- At merge points and milestone boundaries.

## Tiers
| Tier | Session % | Weekly % | Protocol |
|------|-----------|----------|----------|
| OK | <70 | <60 | Normal operations. |
| CAUTION | ≥70 | ≥60 | No NEW lanes/workflows/waves. Finish in-flight work. Prefer cheap/delegated ops (see wi-running-the-machine delegation ladder). |
| WINDDOWN | ≥85 | ≥75 | Drain: stop feeding running lanes new tasks; let current tasks land; commit WIP on lane branches (WIP-tagged messages — NO un-gated merges to main); update HANDOFF RUNNING/QUEUE. |
| QUIESCE | ≥95 | ≥90 | State-saving actions ONLY: commit WIP, write HANDOFF. Then see end-state below. |

Two automatic adjustments (already in the script — read the line's `[...]`
reasons): burn-rate projection escalates one tier early when exhaustion is
projected before the reset and within 60 min; near-reset softening caps the
session component at CAUTION when the reset is ≤15 min away (waiting for
the reset beats a hard drain — weekly is never softened).

## QUIESCE end-state
- **Session window** (resets within hours): after state is saved, wait for
  the reset — chained ScheduleWakeup hops of ≤1h ("waiting for usage window
  reset") until `scripts/usage_status.sh --fresh` shows the new window,
  then resume the HANDOFF queue.
- **Weekly limit** (reset days away): hard stop. Save state, write HANDOFF,
  report to the user, end the turn.

## UNKNOWN
The query failed (exit 0, line starts `UNKNOWN`). Proceed, but re-check
within the hour; if UNKNOWN persists >1h, note it in HANDOFF and treat
long dispatches as CAUTION.

## Wind-down invariants
- Never merge to main just to "save work" — WIP lives on lane branches;
  main only takes gated merges.
- HANDOFF.md must let a FRESH session resume without this session's
  context: RUNNING (what's mid-flight, exact state), QUEUE (what's next).
- Running lanes get one clear "land what you have and stop" instruction,
  not silence.
```

- [ ] **Step 2: Add pointer to `wi-running-the-machine`**

In `.claude/skills/wi-running-the-machine/SKILL.md`, in the "## Usage-aware pacing (user directive 2026-07-04)" section, immediately after the sentence ending `never run two agents on one file concurrently.`, insert:

```markdown
**Hard tiers (2026-07-12): run `scripts/usage_status.sh` before EVERY
lane/workflow/wave dispatch and at merge points — wi-usage-guard has the
tier checklists (CAUTION = no new dispatch, WINDDOWN = drain + commit
seams, QUIESCE = state-saving only, then wait-for-reset or weekly hard
stop). The PostToolUse hook injects tier CHANGES mid-flight; act on them
immediately.**
```

- [ ] **Step 3: Add read-order item to `wi-start-here`**

In `.claude/skills/wi-start-here/SKILL.md`, in "## Read order (every fresh session)", after item 4 (the GitHub Issues item), add:

```markdown
5. `scripts/usage_status.sh` — usage tier BEFORE planning dispatch scale
   (wi-usage-guard has the tier protocol; CAUTION+ changes the plan).
```

- [ ] **Step 4: Add HANDOFF.md section**

In `HANDOFF.md`, directly below the `# Wandering Inn RPG Handoff` title line, insert:

```markdown
## 🛡️ USAGE GUARD LIVE (2026-07-12)
`scripts/usage_status.sh` = tier check (OK/CAUTION/WINDDOWN/QUIESCE, exit
0/10/20/30); PostToolUse hook injects tier CHANGES mid-flight; protocol in
wi-usage-guard skill. Check before every dispatch. QUIESCE = commit WIP
seams + HANDOFF update + wait-for-reset (session) or hard stop (weekly).
```

- [ ] **Step 5: Verify docs render and nothing broke**

Run: `python3 scripts/tests/test_usage_guard.py && python3 scripts/tests/test_usage_status_cli.py && python3 scripts/tests/test_usage_hook.py && head -12 HANDOFF.md && head -8 .claude/skills/wi-usage-guard/SKILL.md`
Expected: all suites PASS; HANDOFF shows the new section under the title; skill frontmatter intact.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/wi-usage-guard/SKILL.md .claude/skills/wi-running-the-machine/SKILL.md .claude/skills/wi-start-here/SKILL.md HANDOFF.md
git commit -m "wi-usage-guard skill + pointers: tiered wind-down protocol

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
