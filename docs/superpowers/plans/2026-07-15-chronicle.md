# Chronicle Implementation Plan

> Status: **DONE**
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist and render one results-only latest-run Chronicle outside save data.

**Architecture:** The pure sim derives a stable facts dictionary. Main owns the runtime capture boundary, WISettings owns ConfigFile persistence, and journal/title own their read-only views.

**Tech Stack:** Godot 4.7, typed GDScript, ConfigFile, ObservableBus, declarative QA JSON.

## Global Constraints

- Never read or write Chronicle data through `save.gd` or save-slot metadata.
- Render achieved facts only; no missed-content list or progress-toward copy.
- Keep `title_screen.gd::ROWS`, row indices, and selectable-row counts unchanged.
- Every visible Chronicle surface emits `ui_chronicle_rendered` with full facts.
- Use existing UIChrome/container layout; no hand-authored `.tscn` files.

---

### Task 1: Fact derivation and settings persistence

**Files:**
- Modify: `wandering_inn_game/src/core/wi_game.gd`
- Modify: `wandering_inn_game/src/ui/wi_settings.gd`
- Modify: `wandering_inn_game/tests/test_sim_core.gd`
- Modify: `wandering_inn_game/tests/test_settings.gd`

**Interfaces:**
- Produces: `WIGame.chronicle_facts() -> Dictionary`
- Produces: `WISettings.record_chronicle(facts: Dictionary) -> void`
- Produces: `WISettings.latest_chronicle() -> Dictionary`

- [ ] Add failing sim assertions for schema, identity, class catalog order,
  completed-quest count, victories, sleeps, and exact ending.
- [ ] Add failing settings assertions for empty initial read, round-trip through
  a fresh instance, and deep-copy isolation.
- [ ] Run both unit suites and confirm failures are missing-method failures.
- [ ] Implement the three interfaces with typed dictionaries and deep copies.
- [ ] Re-run both suites; require PASS with zero warnings/errors.
- [ ] Commit the task with DCO and actual tool attribution.

### Task 2: Capture boundary and two renderers

**Files:**
- Modify: `wandering_inn_game/src/core/wi_events.gd`
- Modify: `wandering_inn_game/src/world/main.gd`
- Modify: `wandering_inn_game/src/ui/journal.gd`
- Modify: `wandering_inn_game/src/ui/title_screen.gd`
- Modify: `wandering_inn_game/tests/test_world_visuals.gd`

**Interfaces:**
- Consumes: Task 1's three methods.
- Produces: `WIEvents.UI_CHRONICLE_RENDERED`
- Produces: journal/title payload `{surface, facts}`.

- [ ] Add failing source-contract assertions proving the post-game event capture,
  pre-title recapture, unchanged title `ROWS`, Chronicle journal tail, title
  read-only card, and both render-confirmation emissions.
- [ ] Run `test_world_visuals.gd` and confirm the new assertions fail.
- [ ] Implement capture in `WIMain`, append the journal section, and build the
  420×150 bottom-left title card with containers and `MOUSE_FILTER_IGNORE`.
- [ ] Preserve existing title/journal event fields; emit the dedicated rendered
  event only when facts exist.
- [ ] Run import, load gate, `test_world_visuals.gd`, `test_settings.gd`, and
  `test_sim_core.gd`; require PASS with zero warnings/errors.
- [ ] Commit the task with DCO and actual tool attribution.

### Task 3: End-to-end canonical and visual proof

**Files:**
- Create: `wandering_inn_game/qa/scripts/chronicle_loop.json`
- Modify: `wandering_inn_game/qa/manifest.json`
- Modify: `wandering_inn_game/AGENTS.md`
- Generate: `wandering_inn_game/docs/QA-SCRIPT-NOTES.md`
- Modify: `HANDOFF.md`

**Interfaces:**
- Consumes: `ui_chronicle_rendered`, completed `near_riverfarm` fixture, title
  and pause input routes.

- [ ] Add `chronicle_loop`: load completed fixture, open journal and pin current
  facts, quit to title and pin persisted facts, start New Game, quit to title,
  and pin the same persisted facts again while row counts stay 5.
- [ ] Register seed 9/full tier, derive surfaces, regenerate QA notes, and add
  the canonical seed-table row.
- [ ] Run load gate, `chronicle_loop`, `title_flow`, `journal_history`,
  `arc_flow`, and `settings_loop` headless at their pinned seeds.
- [ ] Run `chronicle_loop` windowed at 100% and 130% text scale; read both journal
  and title frames for clipping, menu overlap, and focus/input regressions.
- [ ] Update HANDOFF to mark #91 complete and remove it from the queue.
- [ ] Run the full issue gate and independent review, fix Important/Critical
  findings, re-gate, and commit `Closes #91`.
