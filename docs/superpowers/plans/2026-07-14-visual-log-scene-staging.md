# VISUAL-LOG Wave 2: Scene Staging Implementation Plan

> **Required skills:** `wi-running-the-machine`, `wi-adding-a-scene`,
> `wi-art-and-sprites`, `wi-verifying-changes`,
> `godot-prompter:scene-organization`, and `godot-prompter:godot-testing`.
> **Parent:** `2026-07-14-visual-log-drain-master.md`

**Goal:** Resolve the bounded overlap, presence, zoning, occlusion, arena, and
ruin-route defects without broadening the repo-wide rendering architecture.

**Architecture:** Scene placement remains JSON-first. Renderer work is limited
to an opt-in per-entity Y-sort bias that reuses the existing holder-position
technique, plus invoking the already-existing `present_when` reconciler when
an accomplishment changes a `requires` gate. Shared sprite catalog entries
remain untouched. Arena changes remain deterministic off-grid dressing.

---

## Task 1: Add failing scene and renderer contracts

**Files:**

- Modify: `wandering_inn_game/tests/test_world_visuals.gd`
- Modify: `wandering_inn_game/tests/test_sim_core.gd`
- Modify: `wandering_inn_game/tests/test_combat_visuals.gd`

- [ ] Extend `test_world_visuals.gd` to assert `_make_entity_visual` accepts a
  per-call sort-bias override, `_build_entities`, `_refresh_entity_visual`, and
  `_reconcile_entity_presence` pass
  `ent.get("field_y_sort_bias_px", null)`, and the function falls back to the
  sprite catalog when no override is supplied.
- [ ] Assert the `ACCOMPLISHMENT_RECORDED` event branch calls
  `_reconcile_entity_presence()` after counter-watched visual refresh. The
  current code reconciles `present_when` only on phase changes, so a
  same-map `requires` gate is stale until this contract is added.
- [ ] Add scene-data assertions in `test_sim_core.gd`:
  - `riverfarm_witch.cell == Vector2i(5, 8)` and all four cardinal neighbors
    are not statically blocked.
  - `relc_descent_cameo` is absent before `reached_the_warren`, present after
    it, uses `relc`, and occupies `[13,5]` without replacing the boss-dialogue
    entity.
  - `bread_stall` and `lyonette_door` each carry
    `field_y_sort_bias_px: 20.0`.
  - the new ruin prop/decor cells are distinct from every door landing,
    encounter, and canonical route cell.
- [ ] In `test_combat_visuals.gd`, assert the final Wave-0 arena decision:
  accepted off-grid decor cells remain outside 12×8, sprite ids resolve, and
  the Sewer Bat-competing prop/cell is absent if Wave 0 reproduced it.
- [ ] Run the three tests and confirm RED on the new contracts.

## Task 2: Separate Eloise from the cottage silhouette

**Files:**

- Modify: `wandering_inn_game/data/maps/riverfarm/witch_hollow.json`
- Modify: `wandering_inn_game/qa/scripts/riverfarm_talk.json`
- Modify: `wandering_inn_game/qa/scripts/trader_earn_loop.json`

- [ ] Move `riverfarm_witch` from `[3,8]` to open cell `[5,8]` and face her
  down toward the approach. This creates a two-cell lateral separation from
  `witch_cottage_prop` at `[3,7]` while preserving the cottage threshold props
  at `[2,7]` and `[4,7]`.
- [ ] Re-route both `riverfarm_talk` visits to teleport/approach `[5,9]`, bump
  up, and interact. Update comments and every exact cell assertion.
- [ ] Re-route `trader_earn_loop` to the same `[5,9]` approach.
- [ ] Run both scripts headless, then `riverfarm_talk` windowed. Acceptance:
  cottage, candles, pot, and Eloise each have an independent silhouette;
  interaction remains one blocked bump away; no tree/encounter route breaks.

## Task 3: Add Relc's warren-mouth field cameo

**Files:**

- Modify: `wandering_inn_game/data/maps/sewers/deep_tunnels.json`
- Modify: `wandering_inn_game/qa/scripts/deep_descent.json`

- [ ] Add `relc_descent_cameo` as an NPC at `[13,5]`, facing left, sprite
  `relc`, with `present_when.requires.reached_the_warren: 1`. Give it one
  compact field line that does not replace or duplicate the existing
  `relc_descent` join/veto conversation on `awakened_boss`.
- [ ] Keep the cameo non-gating: no accomplishment effects, no combat roster
  mutation, no `conversation`, and no change to `ally_requires`.
- [ ] In `src/world/world.gd`, extend the existing
  `WIEvents.ACCOMPLISHMENT_RECORDED` branch to call
  `_reconcile_entity_presence()` immediately after
  `_refresh_entities_watching_counter(...)`. Do not add a bespoke Relc spawn
  path; the generic `present_when.requires` contract owns the appearance.
- [ ] After `warren_mouth` banks `reached_the_warren`, make `deep_descent`
  wait for the reconciled `ui_entities_rendered` payload, then capture
  `03b_relc_at_warren_mouth` before moving to the boss.
- [ ] Run `test_combat_data.gd`, `test_sim_core.gd`, and `deep_descent`.
  Windowed acceptance: Relc is physically visible beside the mouth before the
  veto dialogue, does not block the `[11,5] → [11,6] → [12,6]` boss approach,
  and still appears as the correct ally only after the join option.

## Task 4: Zone the upstairs rooms without reopening the bed-rug defect

**Files:**

- Modify: `wandering_inn_game/data/maps/inn/inn_upstairs.json`
- Modify: `wandering_inn_game/qa/scripts/upstairs_walkthrough.json`

- [ ] Add one `rug_tan` decor cue at `[6,2]`, tinted a restrained faded royal
  red/blue that stays in the existing inn palette. Its 80×72 source at scale
  0.4 spans Lyonette's threshold side without touching `your_bed` at `[9,1]`.
- [ ] Do not restore a rug beneath or adjacent to the bed; the prior bed-rug
  issue remains closed.
- [ ] Retain all blocking/entity cells. Add a screenshot immediately before
  the Lyonette-door interaction if `02_lyonette_door`'s toast obscures the
  zoning cue.
- [ ] Run `upstairs_walkthrough` windowed. Acceptance: a first-time viewer can
  distinguish Lyonette's threshold from the player's bed area, the rug does
  not imply an enterable room, and the hallway stays uncluttered.

## Task 5: Add the per-entity sort-only override and wire the two props

**Files:**

- Modify: `wandering_inn_game/src/world/world.gd`
- Modify: `wandering_inn_game/data/maps/liscor/street.json`
- Modify: `wandering_inn_game/data/maps/inn/inn_upstairs.json`
- Modify: `wandering_inn_game/tests/test_world_visuals.gd`

- [ ] Change the signature to:

```gdscript
func _make_entity_visual(
    cell: Vector2i,
    sprite_id: String,
    tint: Variant,
    fallback_color: Color = PROP_COLOR,
    facing: String = "",
    light: Dictionary = {},
    sway: bool = false,
    field_y_sort_bias_override: Variant = null,
) -> Node2D:
```

- [ ] Resolve the bias with an explicit numeric override, else the existing
  catalog value:

```gdscript
var y_sort_bias := (
    float(field_y_sort_bias_override)
    if field_y_sort_bias_override is float or field_y_sort_bias_override is int
    else float(catalog_entry.get("field_y_sort_bias_px", 0.0))
)
```

- [ ] Pass `ent.get("field_y_sort_bias_px", null)` only from real-entity
  build, refresh, and presence-reconcile calls. Player, decor, and scatter
  calls keep their current catalog behavior and argument defaults.
- [ ] Add `field_y_sort_bias_px: 20.0` to `bread_stall` and `lyonette_door`.
  Positive bias sorts the holder later while subtracting the same amount from
  sprite/shadow local position, so pixels do not move.
- [ ] Run `test_world_visuals.gd`, `barracks_walkthrough`, and
  `upstairs_walkthrough` headless then windowed. Compare before/after at the
  same player cells. Acceptance: the prop stays readable when the player is
  south of it, no visible pixel displacement occurs, and shared `food_basket`
  or `door` consumers remain byte-identical.

## Task 6: Resolve sewer silhouette competition and sparse arenas

**Files:**

- Modify only if Wave 0 reproduced a failure:
  `wandering_inn_game/data/arenas.json`
- Modify: `wandering_inn_game/tests/test_combat_visuals.gd`

- [ ] For `sewers_nest`, remove or replace only the exact off-grid prop that
  Wave 0 found competing with Sewer Bat/Shield Spider silhouettes. Prefer the
  existing neutral `boulder`; do not alter blocked cells, spawns, or biome.
- [ ] Treat `cave_mouth`, `sewers_nest`, and `deep_warren` as already dressed
  if the Wave-0 frames meet the bar; document closure rather than adding
  density.
- [ ] If `ruin_court` is the only sparse current frame, add bounded off-grid
  ruin-family dressing using `dungeon_statue` and `dungeon_rubble`, at cells
  outside 12×8 and away from spawn silhouettes. Keep the tactical grid and
  current blocked/spawn arrays byte-identical.
- [ ] Run every affected combat canonical at its pinned seed and compare
  before/after. No balance harness is needed because no sim combat data
  changes; run `test_combat_data.gd` to prove connectivity remains unchanged.

## Task 7: Put ruin architecture on the canonical route

**Files:**

- Modify: `wandering_inn_game/data/maps/ruin/ruin_surface.json`
- Modify: `wandering_inn_game/qa/scripts/ruin_walkthrough.json`

- [ ] Add one solid, interactive `ruin_court_statue` entity using
  `dungeon_statue` at `[14,4]`, with ruin-specific display/observe text. This
  cell is off the canonical row-5 traversal and does not alter the pedestal or
  guardian cells.
- [ ] Add low, non-solid `dungeon_rubble` decor at `[10,4]`. Its low silhouette
  may remain decor because it does not visually claim a full blocked cell.
- [ ] Update the initial `ui_entities_rendered` expectation from four sprites
  plus player to the newly measured count.
- [ ] On leg 3, stop at `[10,5]` and capture
  `01b_ruin_architecture_on_route` before continuing to `[2,5]`; preserve the
  same total endpoint and all later steps.
- [ ] Run `ruin_walkthrough`, `door_chain_fight`, `load_gate`, and map
  reachability tests. Windowed acceptance: the landing/pedestal route reads as
  a specific ruin rather than a generic cave, architecture appears in the
  canonical camera, and neither prop creates a misleading pass-through.

## Task 8: Verify, document, and commit

- [ ] Run from `wandering_inn_game/`:

```bash
/usr/local/bin/godot --headless --path . --script tests/test_world_visuals.gd
/usr/local/bin/godot --headless --path . --script tests/test_sim_core.gd
/usr/local/bin/godot --headless --path . --script tests/test_combat_visuals.gd
/usr/local/bin/godot --headless --path . --script tests/test_combat_data.gd
qa/run_qa.sh load_gate headless
qa/run_qa.sh riverfarm_talk headless --seed=9
qa/run_qa.sh trader_earn_loop headless --seed=9
qa/run_qa.sh deep_descent headless --seed=9
qa/run_qa.sh upstairs_walkthrough headless --seed=9
qa/run_qa.sh barracks_walkthrough headless --seed=9
qa/run_qa.sh ruin_walkthrough headless --seed=9
qa/run_qa.sh door_chain_fight headless --seed=9
```

Expected: all PASS with identical encounter outcomes and zero warnings.

- [ ] Copy windowed after-images, update the relevant VISUAL-LOG rows and
  `HANDOFF.md`, run `git diff --check`, leak check, and comment census.
- [ ] Commit:

```bash
git add wandering_inn_game/data wandering_inn_game/src \
  wandering_inn_game/tests wandering_inn_game/qa/scripts \
  docs/VISUAL-LOG.md HANDOFF.md
git commit -m "Resolve VISUAL-LOG scene staging (#113)"
```
