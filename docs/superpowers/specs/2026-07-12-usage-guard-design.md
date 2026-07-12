# Usage Guard — usage-aware graceful wind-down (design)

**Date:** 2026-07-12
**Status:** Approved design (brainstormed with user)

## Problem

Subscription usage limits (5-hour session window, weekly caps) can cut
off a session mid-flight: parallel worktree lanes die with uncommitted
work, workflows are killed mid-wave, HANDOFF.md goes stale, and code is
left in a bad state. The model has no built-in awareness of remaining
usage, so it works at full burn until the hard cutoff.

Goal: the model works **usage-aware** — when the window is close to
exhaustion it gracefully winds down (stops dispatching, drains in-flight
work, commits clean seams, updates HANDOFF.md) and quiesces ready to
restart, instead of being non-gracefully killed.

## Key discovery

`claude -p /usage` works from a script (print mode serves the /usage
command) and returns the **official** usage percentages:

```
Current session: 11% used · resets Jul 12 at 4:40am (America/Chicago)
Current week (all models): 3% used · resets Jul 18 at 8pm (America/Chicago)
Current week (Fable): 3% used · resets Jul 18 at 8pm (America/Chicago)
```

This supersedes all JSONL-summing / ccusage-style estimation. The text
format is the only contract — parsing must fail soft (see Error
handling).

## Components

### 1. `scripts/usage_status.sh` — single source of truth

- Runs `claude -p /usage`, parses: session %, session reset time,
  week-all %, week-Fable %, weekly reset time.
- **Cache:** rolling sample history at `~/.claude/usage-guard-cache.json`
  — array of `{ts, session_pct, week_pct, fable_pct, session_reset,
  week_reset}`, trailing ~24h retained. TTL 5 min: fresh-enough newest
  sample is reused; `--fresh` forces a re-query.
- **Static tier bands** (worst of the two wins):
  - Session %: OK < 70, CAUTION ≥ 70, WINDDOWN ≥ 85, QUIESCE ≥ 95
  - Weekly % (stricter — no quick reset): OK < 60, CAUTION ≥ 60,
    WINDDOWN ≥ 75, QUIESCE ≥ 90. Weekly tier is computed from the worse
    of week-all and week-Fable.
- **Near-reset softening:** if the session window resets ≤ 15 min from
  now, the session component is capped at CAUTION (waiting for reset
  beats a hard drain). Weekly is never softened.
- **Burn-rate projection:**
  - Rate = Δ session % over the trailing 30 min of samples (needs ≥ 2
    usable samples, else `rate=n/a`).
  - A negative delta means the window reset — the history baseline
    resets and pairs spanning the reset are discarded.
  - `mins_to_exhaustion = (100 − session%) / rate` (per minute).
  - **Dynamic escalation:** if exhaustion is projected BEFORE the
    session reset AND within 60 min, escalate one tier beyond the
    static band (e.g. 55% used but burning fast with 2h to reset →
    CAUTION now).
  - Weekly rate is computed and reported but never auto-escalates.
- **Output:** one line, machine- and human-readable:
  `WINDDOWN session=87% reset=04:40 week=42% fable=41% rate=12%/hr eta=exhaust~03:10` +
  a short action hint. Exit code encodes tier: 0 OK / 10 CAUTION /
  20 WINDDOWN / 30 QUIESCE. UNKNOWN exits 0.
- **Config:** threshold values in variables at the top of the script
  (committed; tunable without redesign).
- **Test hook:** `USAGE_GUARD_FAKE="session=90 week=10 rate=20"` env
  override injects fake values so all tiers, softening, and dynamic
  escalation can be exercised without burning the window.

### 2. Hook — escalation-only, zero added latency

- Project `.claude/settings.json`: `PostToolUse` hook, matcher `*`,
  running `scripts/usage_hook.sh`.
- Reads the cache only. If stale (> 5 min), kicks a **detached
  background refresh** (`claude -p /usage` → cache) and uses the old
  value — tool calls never wait on the query; status is at most ~10 min
  old.
- Emits `hookSpecificOutput.additionalContext` **only when the tier
  changes** vs a last-notified stamp keyed by session id (hook input
  provides `session_id`). Escalation AND de-escalation (window reset →
  "resume normal ops") each notify once. Silent otherwise.
- Fail-soft everywhere: script missing, `claude` CLI absent (external
  contributors — settings.json is committed to a public repo), parse
  failure, cache corruption → exit 0, no output, tools never blocked.

### 3. Skill — `wi-usage-guard` + wiring

New skill `.claude/skills/wi-usage-guard/SKILL.md`:

- Tier table + what each tier means.
- **Mandatory explicit check** (`scripts/usage_status.sh`) BEFORE
  dispatching any lane, workflow, or agent wave, and at merge points.
- Wind-down checklists:
  - **CAUTION:** no new lanes/workflows; finish in-flight work; prefer
    cheap/delegated ops (per the existing usage-aware-pacing directive).
  - **WINDDOWN:** stop feeding running lanes new tasks; let current
    tasks land; commit WIP on lane branches (WIP-tagged messages, no
    un-gated merges to main); update HANDOFF.md RUNNING/QUEUE; drain to
    quiescence.
  - **QUIESCE:** state-saving actions only (commit WIP, HANDOFF write).
    Then: session-window case → schedule resume past reset via chained
    ScheduleWakeup hops (≤ 1h each) until the reset passes, then resume
    the queue; weekly-limit case → hard stop + report to the user
    (reset is days away).
- `wi-running-the-machine` and `wi-start-here` get short pointer
  sections (session-start check; pre-dispatch checkpoint).

### 4. Explicitly out of scope

No new daemons, no ccusage/npx dependency, no per-message JSONL token
accounting (official percentages supersede it), no changes to QA gates.

## Data flow

```
claude -p /usage ──parse──> cache (rolling samples, ~/.claude/)
                                │
        usage_status.sh ◄───────┤  explicit checks (skill checkpoints)
        usage_hook.sh   ◄───────┘  PostToolUse: tier-change notifications
```

## Error handling

- Any failure in query/parse → tier `UNKNOWN`, exit 0; never blocks
  work. Explicit status checks print `UNKNOWN`; the hook stays SILENT on
  UNKNOWN (notifying would spam fresh machines with no cache). UNKNOWN
  persisting > 1h is itself worth surfacing in HANDOFF.
- Concurrent cache writes (multiple sessions/subagents): write via
  temp-file + atomic `mv`.
- Subagents fire the same hook; the per-session stamp keeps
  notifications deduped per context.

## Testing

- Live: manual `usage_status.sh` run against real /usage output.
- Fake-tier env tests: every band, near-reset softening, dynamic
  burn-rate escalation, reset-detection (negative delta), UNKNOWN path.
- Hook: fake escalation → verify additionalContext fires once and only
  on change; verify silence in steady-state OK; verify fail-soft with
  cache removed and with `claude` absent from PATH.
