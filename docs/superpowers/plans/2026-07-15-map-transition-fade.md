# Map Transition Fade Implementation Plan

> Status: **ACTIVE**
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:test-driven-development` and the repository WI verification
> skills task-by-task.

**Goal:** Ship #87's remaining two-sided field map fade with zero sim or
headless-QA drift.

**Architecture:** Main owns the persistent veil and timing; World delegates its
`MAP_CHANGED` rebuild and includes Main's active state in its existing input
gate.

---

### Task 1: Transition seam and contracts

**Files:**
- Modify: `wandering_inn_game/src/world/main.gd`
- Modify: `wandering_inn_game/src/world/world.gd`
- Modify: `wandering_inn_game/tests/test_world_visuals.gd`

- [x] Add failing contracts for persistent overlay ownership, 0.125+0.125
  timing, full-cover rebuild ordering, QA collapse, visual opt-in, Main-wide
  input consumption, and World movement gating.
- [x] Implement the persistent CanvasLayer/ColorRect and async
  `transition_map(rebuild)` seam.
- [x] Route only `MAP_CHANGED` rebuilds through it; keep initial world build
  synchronous.
- [x] Run world visual/unit, load gate, and representative crossing scripts.
- [x] Commit and independently review; fix all Critical/Important findings.

### Task 2: Focused visual proof and issue close

**Files:**
- Create: `wandering_inn_game/qa/scripts/map_transition_fade.json`
- Modify: `wandering_inn_game/qa/manifest.json`
- Modify: `wandering_inn_game/AGENTS.md`
- Generate: `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`
- Modify: `HANDOFF.md`
- Update: this plan and its design spec status headers

- [x] Add a seed-9 full-tier inn-to-floodplains crossing canonical with midpoint
  and post-reveal screenshots; register and derive surfaces.
- [x] Prove headless collapse plus unchanged crossing scripts.
- [x] Run it windowed with `--map-transition-visual=1`; read both frames.
- [ ] Mark #87/spec/plan complete, run the issue gate and whole-issue review,
  and commit `Closes #87` with DCO and actual tool attribution.
