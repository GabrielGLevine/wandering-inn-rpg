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
