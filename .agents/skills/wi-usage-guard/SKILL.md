---
name: wi-usage-guard
description: Use before dispatching any lane/workflow/agent wave, at session start, when a USAGE-GUARD hook notification appears, or when deciding how to wind down before a usage cutoff.
---

# Usage Guard — provider-scoped graceful wind-down

**Claude sessions:** check `scripts/usage_status.sh` (`--fresh` forces a re-query; plain
call reuses a ≤5-min-old sample). One line out:
`TIER session=..% reset~..m week=..% fable=..% rate=..%/hr eta=exh~..m | hint`
For Codex, the command prints `N/A provider=codex` and exits 0; Claude
telemetry must never constrain Codex. Exit codes for Claude: 0 OK/UNKNOWN, 10 CAUTION, 20 WINDDOWN, 30 QUIESCE.
A PostToolUse hook injects a `USAGE-GUARD escalated/de-escalated to ...`
notice whenever the tier CHANGES mid-flight — treat that notice as this
skill firing and act on the new tier immediately.

## When to check explicitly (mandatory)
- Claude session start (wi-start-here read order); Codex records N/A.
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
