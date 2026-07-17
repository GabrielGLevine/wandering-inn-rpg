---
name: wi-machine-playtest
description: Use after any wave touching a player-facing surface (sprites, panels, copy, maps, mood) and at every milestone close — plays the game with player eyes via windowed QA screenshots, as opposed to the logic-proving sweep.
---

# Machine-Driven Playtest

**Canonical protocol: `wandering_inn_game/qa/MACHINE-PLAYTEST.md`** — read
and follow it verbatim (isolation decision, script coverage matrix,
per-screenshot checklist, event-log copy diff, report format). This skill
is the loop-integration wrapper.

## When (binding, user-ratified 2026-07-07)
- After ANY wave that touched a player-facing surface — BEFORE claiming
  the wave done. The sweep proves logic; it is structurally blind to
  baked sheet artifacts, fold clipping, dark-scene legibility, and UI
  furniture accumulation (all four shipped green before this protocol
  caught them).
- At every milestone close: full rotation.
- ~15-20 min for a 6-8 script pass; rotate the subset, ALWAYS include one
  dark map, one panel-heavy script, one script covering the newest
  feature.

## Iron rules
- Dirty tree or mid-refactor session → detached worktree at a known-good
  commit (`git worktree add --detach /tmp/wi-playtest HEAD` + `--import`
  pass), never a mid-surgery tree. Remove the worktree when done.
- READ every PNG as a first-time player (the protocol's checklist);
  diff rendered text against the events.jsonl payload — a punchline that
  only exists in the payload is a bug.
- Findings ranked player-visible-first; every claim cites its screenshot;
  visual findings → docs/VISUAL-LOG.md; blockers → HANDOFF next-steps.

## Targeted playtest requests (user directive 2026-07-17)
Any request for USER eyes/ears on a specific surface (an eye-gate, an
ear-gate, a taste call) MUST ship with a **prepared Playtest State**: a
named save/fixture the user loads that lands them AT the thing being
judged (right map, right cell, right counters, the feature armed) plus
a one-line "load X, do Y, judge Z" instruction. Never ask the user to
navigate there themselves — staging cost belongs to the agent. Fixture
authoring per wi-writing-qa-scripts; park the save under
playtest_saves/ with a dated name.

