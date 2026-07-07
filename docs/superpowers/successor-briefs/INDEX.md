# Successor briefs — deferred content ladder (staged 2026-07-07 night)

Dispatch-ready implementation briefs for the content waves deferred by the
2026-07-07 architecture-first night (user-ratified). Written by the Fable
staging lane; each brief is self-contained — the safety rails are SPELLED
OUT in every file because a successor controller may not load every skill.

## THE ONE RULE BEFORE ANYTHING ELSE
**`tail -60 .superpowers/sdd/progress.md` first, every session** — the
ledger tail is the exact position; trust it over this index, over
HANDOFF prose, and over memory. The night run may have executed any rung
below (NIGHT-GOAL.md objective 9 orders the FULL charter after the
architecture track).

## Execution order (the ratified ladder)
| # | Brief | Task | Precondition / tree-state assumption |
|---|---|---|---|
| 1 | `task-k2b-loadout-brief.md` | K2b hotbar loadout | K2 committed (49 canonicals, `stealth_loop` green). Assumes the ARCH-4 extraction MAY have moved `wi_game.gd` code — grep, don't trust file shapes. Must land BEFORE K3. |
| 2 | `task-k3-canon-skills-brief.md` | K3 canon names + new Skills + [Rogue]-line | K2b landed. HANDOFF "RESOLVED 2026-07-07" rulings 4/5/9 BIND it. Check whether K4 ran first (ghost-skill gate landmine, named in the brief). |
| 3 | `task-k4-overworld-pass-brief.md` | K4 overworld pass + ghost wiring | **CHECK-LEDGER-FIRST banner** — K4 was scheduled for the night itself (Fable-level); this brief exists only as insurance if the night didn't reach it. If done: skip. KF (wave close: full gate + windowed set + opus whole-branch) follows K2b/K3/K4 per the skills-wave plan. |
| 4 | `task-social-2-brief.md` | Social Pillar II (LINEAR stages) | K-wave closed (KF). Staged copy at `docs/design/social-2-staging/` is the single content source; 18 ⚑ flags ship OPEN. Phase C (Erin/Relc pools, ~28 script reds) is its own budgeted wave. |
| 5 | `task-m-depth-dp1-brief.md` | M-DEPTH DP1 (Guild interior + Selys move) | Social II closed (or consciously reordered — DP1 is independent of Social II except Selys' pool surface; if reordering, re-check the Selys blast radius against the then-current scripts). DP2→DPF pointer at the brief's tail; board staging at `docs/design/board-staging/` feeds DP2/DP5. |

## Universal assumptions all five briefs share
- The 2026-07-07 architecture night may have landed: `qa/manifest.json`
  (ARCH-1 — if it exists it is THE registration surface; every brief
  phrases registration conditionally), the wi_game extraction (ARCH-4 —
  grep for functions, never trust remembered file/line locations), the
  key catalog (ARCH-3), de-mirrored helpers (ARCH-2), and a slimmed
  `wandering_inn_game/CLAUDE.md` (reference sections by NAME; per-script
  routing detail may live in `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`
  if it exists).
- Counts are never trusted: count `ci_sweep.sh`'s CANON (or the manifest)
  and `tests/test_*.gd` at execution time (49 canonicals / 17 unit files
  at K2 close).
- FIXTURE-FIRST policy (ratified 2026-07-07) binds every NEW canonical.
- User taste/canon gates never block a run: ship the staged/recommended
  default + a ⚑ HANDOFF entry; check HANDOFF's "RESOLVED" blocks before
  flagging duplicates; never resolve taste flags yourself.
- NO-COMMIT implementers; controller commits per green task with explicit
  staged paths; FOREGROUND-only verification everywhere.
