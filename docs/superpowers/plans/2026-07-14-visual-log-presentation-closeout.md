# VISUAL-LOG Wave 3: Presentation and Closeout Implementation Plan

> **Required skills:** `wi-running-the-machine`, `wi-writing-qa-scripts`,
> `wi-verifying-changes`, `godot-prompter:godot-testing`, and
> `godot-prompter:godot-ui`.
> **Parent:** `2026-07-14-visual-log-drain-master.md`
> Status: **DONE**

**Goal:** Fix the terrain-expiry sentence, add the Garden diagonal regression,
promote the three broad redesigns with evidence, and close #113 only after the
entire tree and final windowed scene set pass.

**Architecture:** Terrain source identity is copied into the transient status
record and emitted on application/consumption; the HUD chooses one ice-specific
sentence and keeps the generic fallback unchanged. Garden coverage extends the
existing canonical without a new fixture. Broad UI/rendering redesigns remain
issues, not code in this wave.

---

## Task 1: Add failing source-aware terrain tests

**Files:**

- Modify: `wandering_inn_game/tests/test_combat_sim.gd`
- Modify: `wandering_inn_game/tests/test_combat_visuals.gd`

- [ ] Extend case `c70` in `test_combat_sim.gd` to capture the exact
  `status_applied` and `status_expired` payloads and assert both include
  `source_kind: "icy_floor"`, with applied emitted before expired.
- [ ] Add a generic slowed status case with no terrain source and assert its
  expiry payload either omits `source_kind` or carries an empty string.
- [ ] In `test_combat_visuals.gd`, use `dedup_hud.feed_line_for_event` to pin:

```text
STATUS_EXPIRED {id: pc, status: slowed, source_kind: icy_floor}
→ "Traveler is still gripped by the ice."

STATUS_EXPIRED {id: pc, status: slowed}
→ "Traveler shakes it off."
```

- [ ] Run both tests and confirm RED before changing implementation.

## Task 2: Carry terrain source metadata to the HUD

**Files:**

- Modify: `wandering_inn_game/src/core/combat/wi_combat.gd`
- Modify: `wandering_inn_game/src/combat/combat_hud.gd`
- Modify: `wandering_inn_game/qa/scripts/ice_floor_loop.json`

- [ ] In `_apply_terrain_status`, duplicate each applied status, stamp
  `source_kind` from the terrain entry, store it, and emit the same value:

```gdscript
var status_data := (applies[status_id] as Dictionary).duplicate(true)
var source_kind := String(entry.get("kind", ""))
status_data["source_kind"] = source_kind
(c["statuses"] as Dictionary)[status_id] = status_data
_emit(WIEvents.STATUS_APPLIED, {
    "id": String(c[WIKeys.ID]),
    "status": status_id,
    "source_kind": source_kind,
})
```

- [ ] In `_start_turn`, retain the slowed dictionary before erase and include
  its `source_kind` in `STATUS_EXPIRED`. Do not change AP, move-pool, event
  order, status lifetime, terrain duration, or snapshot shape.
- [ ] In `combat_hud.gd`'s `STATUS_EXPIRED` branch, choose the ice sentence
  only when `status == "slowed"` and `source_kind == "icy_floor"`; otherwise
  preserve `"%s shakes it off."` exactly.
- [ ] In `ice_floor_loop`, pin `source_kind: "icy_floor"` on the player's
  turn-start application and immediate expiry events, then add
  `02_ice_reapplication_copy` while the combat feed line is visible.
- [ ] Run both unit suites and `ice_floor_loop` headless and windowed.
  Acceptance: the feed no longer falsely claims the character escaped while
  the same ice immediately reapplies slow; generic expiry copy is unchanged.

## Task 3: Extend Garden canonical with an internal diagonal

**File:**

- Modify: `wandering_inn_game/qa/scripts/garden_walkthrough.json`

- [ ] Immediately after the `[7,10]` arrival assertion, insert:

```json
{ "action": "move_diag", "a": "move_right", "b": "move_up" },
{ "action": "assert_state", "path": "player_cell", "equals": [9,9] },
{ "action": "screenshot", "name": "00b_garden_diagonal_y_sort" },
{ "action": "move_diag", "a": "move_left", "b": "move_down" },
{ "action": "assert_state", "path": "player_cell", "equals": [7,10] }
```

- [ ] Keep all subsequent route cells and assertions byte-identical.
- [ ] Run `garden_walkthrough` and one untouched canonical such as
  `atmosphere_check` headless to prove the action/harness remains stable.
- [ ] Run Garden windowed and inspect the diagonal frame for Y-sort, fountain/
  statue overlap, camera centering, and collision honesty.

## Task 4: File the three promoted redesign issues

Use the Wave-0 evidence index and current source traces. Create each issue with
labels `task` and an evidence-derived size. Bodies must include symptom,
screenshots, affected code/data/canonicals, explicit non-goals, risks, and
measurable acceptance criteria.

### 4a. Board and delivery picker redesign

- [ ] Title: `Redesign bounty and delivery pickers for scanability and input parity`.
- [ ] Trace at minimum: `src/core/wi_game.gd` code-built `board_picker` and
  delivery graphs, the dialogue presentation component, `delivery_loop`,
  `board_loop`, and one bounty picker canonical.
- [ ] Acceptance: distinct selected/unselected rows, visible reward/destination
  hierarchy, keyboard/gamepad/mouse parity, no hidden overflow at supported
  viewport, and no changes to slate determinism or acceptance effects.

### 4b. Field readout collapse/expand

- [ ] Title: `Add accessible collapse and expand behavior to the field readout`.
- [ ] Trace at minimum: `src/ui/world_labels.gd`, its world/combat publishers,
  current first-waking screenshots, and affected input-hint surfaces.
- [ ] Acceptance: explicit discoverable control, keyboard/gamepad/mouse parity,
  persisted or deliberately reset state, readable icon-recognition fallback,
  safe-area/viewport coverage, and no loss of essential combat identity/HP.

### 4c. Field blocked-cell prop rendering

- [ ] Title: `Replace generic field blocked-cell covers with biome-aware props`.
- [ ] Trace at minimum: `src/world/world.gd` blocked-layer construction and
  `cover_skip`, `src/combat/board_renderer.gd`'s existing
  `BLOCKED_PROPS_BY_BIOME` precedent, representative inn/street/cave maps, and
  map/render regression tests.
- [ ] Acceptance: deterministic biome-aware props on multiple field maps,
  collision/visual honesty, no route or save change, bounded draw/import cost,
  no sprite-through-floor artifacts, and a migration plan for `cover_skip`.

- [ ] Add the three URLs to the matching VISUAL-LOG entries immediately after
  creation. Do not implement any of them in #113.

## Task 5: Reconcile all twenty VISUAL-LOG rows

**Files:**

- Modify: `docs/VISUAL-LOG.md`
- Modify: `HANDOFF.md`

- [ ] For each original row, write its final disposition in present tense:
  `FIXED` with before/after evidence and commit; `CLOSED` with current-state
  non-reproduction/already-fixed evidence; or `PROMOTED` with one of the three
  issue URLs.
- [ ] Convert every resolved checkbox to `- [x]`.
- [ ] Prove zero unchecked entries:

```bash
rg -n '^- \[ \]' docs/VISUAL-LOG.md
```

Expected: no output and exit status 1 from `rg` because there are no matches.
- [ ] Keep the historic Fixed section intact except for concise new #113 rows;
  do not turn the log into a session transcript.
- [ ] Update `HANDOFF.md` with only the three live promoted issues and any
  genuine taste calls; remove #113 execution history after it is committed.

## Task 6: Run targeted and composed verification

Run targeted tests first:

```bash
cd wandering_inn_game
/usr/local/bin/godot --headless --path . --script tests/test_combat_sim.gd
/usr/local/bin/godot --headless --path . --script tests/test_combat_visuals.gd
qa/run_qa.sh ice_floor_loop headless --seed=9
qa/run_qa.sh garden_walkthrough headless --seed=9
qa/run_qa.sh atmosphere_check headless --seed=9
```

Expected: PASS; terrain payload/copy exact, Garden returns to its original route,
untouched action harness remains green.

Then run the full composed gate from `wandering_inn_game/`:

```bash
qa/run_qa.sh load_gate headless
qa/ci_sweep.sh
for t in tests/test_*.gd; do
  /usr/local/bin/godot --headless --path . --script "$t" || exit 1
done
/usr/local/bin/godot --headless --path . --quit
cd ..
scripts/leak_check.sh
scripts/comment_census.py --check
git diff --check
```

Expected: every suite/canonical PASS, smoke clean, leak/comment checks clean,
zero `SCRIPT ERROR`, parse error, or in-run warning.

Run `qa/ci_sweep.sh` in a persistent command session and poll it so progress
updates remain possible; it is too long for a single foreground wait.

## Task 7: Final multi-scene windowed judgment

Run the final affected surface set windowed, preserving each result before a
rerun can clobber it:

```bash
wandering_inn_game/qa/run_qa.sh delve_skill windowed --seed=9
wandering_inn_game/qa/run_qa.sh riverfarm_talk windowed --seed=9
wandering_inn_game/qa/run_qa.sh deep_descent windowed --seed=9
wandering_inn_game/qa/run_qa.sh cisterns_fight windowed --seed=9
wandering_inn_game/qa/run_qa.sh upstairs_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh delivery_loop windowed --seed=9
wandering_inn_game/qa/run_qa.sh barracks_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh guild_interior_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh garden_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh ice_floor_loop windowed --seed=9
wandering_inn_game/qa/run_qa.sh ruin_walkthrough windowed --seed=9
wandering_inn_game/qa/run_qa.sh crab_cull_loop windowed --seed=9
```

- [ ] Read all relevant frames at original resolution.
- [ ] For animated crab/spider surfaces, inspect at least two frames/actions,
  not one still.
- [ ] Reject completion for clipping, player occlusion, palette clash,
  semantically wrong icon/animation, anchor/contact drift, misleading solidity,
  or placeholder-grade art.
- [ ] Confirm the documented post-result windowed shutdown leak only by its
  established result/artifact rule; any earlier warning is a regression.

## Task 8: Commit and close

- [ ] Commit Wave 3:

```bash
git add wandering_inn_game/src wandering_inn_game/tests \
  wandering_inn_game/qa/scripts docs/VISUAL-LOG.md HANDOFF.md
git commit -m "Close the VISUAL-LOG drain (#113)"
```

- [ ] Re-run `git status --short --branch`, `git log -4 --oneline`, and the
  zero-unchecked `rg` proof.
- [ ] Close #113 with a concise summary containing the four commits, three
  promoted issue URLs, full-gate result, and final windowed evidence root.
- [ ] Do not push without the user's explicit instruction if the current
  session has not already authorized pushing.
