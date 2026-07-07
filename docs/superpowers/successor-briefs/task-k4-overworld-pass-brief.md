# Task K4: kit-wide overworld pass + ghost-skill wiring — Skills wave

# ⚠ CHECK-LEDGER-FIRST ⚠
K4 was scheduled for the 2026-07-07 architecture night (NIGHT-GOAL.md
objective 6, post-extraction). Before dispatching ANYTHING from this brief:
`tail -60 .superpowers/sdd/progress.md` and grep it for `K4`. If K4 closed,
this brief is DEAD — archive it mentally and skip to the next rung. If K4
partially landed (e.g. wiring done, [Sweep the Tables] audit not), dispatch
ONLY the remainder and reconcile against the committed state, not this text.

## Goal
Every existing fielded Skill re-checked for a visible overworld read (the
[Light] bar), the cheap wins shipped, honest no-ops documented — plus the
REAL wiring of the four ghost skills the L5 audit exposed.

## Plan text (verbatim, `docs/superpowers/plans/2026-07-06-skills-wave.md` Task K4)
Every existing fielded Skill re-checked: does it DO something visible?
Ship the cheap wins ([Sweep the Tables] on messy-state props; observe's
journal knowledge log if cheap); document honest no-ops (combat-only
skills stay combat-only with their cards saying so).

## Night-charter expansion (NIGHT-GOAL.md objective 6 — this is K4's ratified scope)
Ghost-skill wiring (post-extraction, wires into the new sub-sim homes):
- `heal` / `second_wind` — including the same-side-guard ally-targeting fix.
- The 0-cost `move_pool_bonus` passives (`quick_movement`,
  `battlefield_awareness`) — NOTE these are currently EXCLUDED from combat
  dispatch by a deliberate `ap_cost > 0` gate in `skill_effects.gd` +
  `targeting_controller.gd` + `effect_text.gd` (K2's work; the gate's doc
  comments explain the free-pool exploit it prevents). Wiring the passives
  means replacing that gate with a REAL passive application path (e.g.
  applied at `_start_turn`), not widening the active-cast gate.
- `icy_floor` if it fits; else document + queue.
- Un-suppress the L1 effect lines for whatever gets wired (the
  M-LEGIBILITY LF suppression made the cards honest-blank; wiring makes
  the lines TRUE again) + re-pin `test_effect_text` EXPECTED_SKILLS.
- Balance-harness re-run is MANDATORY (a move-pool passive changes autoplay
  pathing) + expect seed re-derivations: re-run EVERY combat canonical at
  its pinned seed; reds here are expected work, not surprises.

## Context you must load before starting
- `HANDOFF.md` "⚠ GHOST SKILLS" block (what's unwired and who can reach it:
  Warrior L3/L4, ice_mage L10, Tactician L1).
- `task-k2-sneak-report.md` (the ap_cost gate's exact shape + why).
- The current `skill_effects.gd`/`effect_text.gd` — read, don't assume;
  the ARCH-4 extraction may have moved code.

## Design guardrails
- A wired skill's card line must be generated-and-TRUE (the L1 contract):
  wire → un-suppress → re-pin, all in one change.
- [Sweep the Tables]-style overworld reads ride the P1 field-dispatch
  machinery (data tags, K1's tag-not-id convention) — no new seams without
  escalation.
- Honest no-ops: a combat-only skill's card SAYS combat-only (data
  `_comment` + generated line stays combat-shaped); never fake a field read.
- OPACITY: no stat numbers; healing amounts are visible-currency (HP is
  player-visible by standing decision).

## Successor safety rails (spelled out — do not skip)
1. **Ledger first** (see the banner — this brief more than any other).
2. **Exact-pin discipline:** grep `qa/scripts/`, `tests/` for every string/
   value you change; same-edit updates; report old → new.
3. **Registration conditional on ARCH-1:** if
   `wandering_inn_game/qa/manifest.json` exists it is the single source for
   script → seed → fixture; else BOTH CLAUDE.md lists + `ci_sweep.sh` CANON.
   Count, never trust hardcoded numbers.
4. **Alarm-wrap:** `perl -e 'alarm 120; exec @ARGV' /usr/local/bin/godot …`
   (failed asserts HANG; macOS has no `timeout`); kill >2min runs.
5. **Zero-warning grep** on every run: `SCRIPT ERROR|Parse Error|WARNING`,
   units included; never `^PASS` alone.
6. **Windowed shots READ by eyes** for every new visible read;
   `qa_output/<script>/` clobbers per re-run — copy PNGs out immediately.
7. **Worktree-merge intersection rule:** intersect file maps vs `git status`
   AND live-lane reports before any copy-merge; re-gate merged tree; in
   doubt serialize.
8. **NO-COMMIT implementers;** controller stages explicit paths; never
   `git add -A` while a lane is live.
9. **CLAUDE.md sections by NAME;** per-script routing detail possibly in
   `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`.
10. **Seed check is the heart of this task:** combat-data/AI-pathing changes
    flip deterministic fights. Budget for seed re-derivation as real work;
    a script that reds at its pinned seed needs a derivation pass (see
    wi-writing-qa-scripts), not a blind seed bump.

## Verification (FOREGROUND, alarm-wrapped, sequential — never background
## a run and wait; notifications cannot reach you)
1. load_gate + smoke.
2. All unit suites individually (this touches sim core), grep discipline;
   test_effect_text's re-pins proven.
3. Balance harness (`tests/sim_combat_batch.gd`) — gated cells must hold
   0.55–0.95 win / 3–12 median; report every cell.
4. EVERY combat canonical at its pinned seed; then the full
   `bash wandering_inn_game/qa/ci_sweep.sh`.
5. Windowed proof per new visible read; PNGs to
   `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/k4-shots/`,
   READ them.

## Report contract
- NO commit, NO git add. Full report to
  `/Users/gabriel/wandering_inn_rpg/.superpowers/sdd/fp-handoff/task-k4-overworld-report.md`:
  the per-skill audit table (wired / cheap-win shipped / honest no-op
  documented), the passive-wiring design, harness cells before/after, every
  seed re-derivation, every pin moved, gate table, shot names.
- Return only: status, one-line test summary, concerns.

## After K4 (whoever controls the wave)
KF closes the wave per the plan: full gate + windowed set (ice crossing,
burn, sneak translucency, reveal glow) controller-read; VISUAL-LOG drain;
the playtest checklist; opus whole-branch review across K2b..K4.
