# Regional Kits Phase 2 Rollout (per-region template) Implementation Plan

> Status: **ACTIVE**
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert every remaining region to its kit after the Invrisil pilot, one PR per region, each closed by a blind Fable art-direction read.

**Architecture:**
- Each region repeats the pilot procedure, Tasks 1–7 of `docs/superpowers/plans/2026-10-08-regional-kits-invrisil-pilot.md`, with that region's maps, roles and traps.
- Calibration from the pilot is applied first: rubric wording, capture cell choice, cost and reader prompts.
- Region work runs in parallel up to the shared-catalog merge point.

**Tech Stack:** As in the pilot.

**Spec:** `docs/superpowers/specs/2026-10-08-regional-kits-design.md` (§6 Phase 2)

## Global Constraints

- Every Global Constraint in the pilot plan applies verbatim.
- **Shared files serialize at merge:** `data/kits.json`, `data/biomes.json`, `data/sprites.json`, `qa/fixtures/sprite_frame_counts.json`, `qa/baselines/scene-repetition.json`, `docs/art-generation-list.md`, `docs/art-bundle-pending.md`, `docs/VISUAL-LOG.md`, `docs/CHOICE-LOG.md` and `assets/LICENSES/v019-owned-art-provenance.txt`.
  - A region branch rebases onto main before its final gates, then regenerates derived files: `python3 tools/asset_candidates.py`, plus the G3 baseline only via the explicit flag and a CHOICE-LOG line.
- **Parallelism (cap: two implementation workers):**
  - Region N+1's Tasks 1–3 (before-captures, pool selection, pool reads) may run while region N is in conversion or review, provided they use different map folders.
  - Map conversion and merge stay serialized in the order below.
- Each region gets its own issue (`Regional kits: <region>`, part of #606) and branch `issue/<n>-kits-<region>`.
- **Out of scope:** enemy rosters, arena kits and Phase 3 generation. Generation needs a user-approved batch, and the PixelLab subscription has lapsed.

## Allocation table

Each region's pool read starts from `docs/kits-allocation.md`. That table gives every kept piece to the region where it fits best, not to the first region that asks for it. To use a candidate that is allocated to another region, get a `docs/CHOICE-LOG.md` ruling first; the PR that moves it also updates its line in the table. Since `bundle-v8` (#621), every source sheet in the table is bundled.

## Review Focus

1. **Shared rigs between region casts and canon characters:** for example inn guests, and Liscor's role NPCs on `gnoll_traveler`. Pinned by the cast lint, which is re-run on the composed main after each merge.
2. **A region's new exclusive floor material leaking into another region's maps** through `_common`. Pinned by G2's exclusive-material check across all converted maps.
3. **Story and gameplay props swapped into pools:**
   - pressure plates, wardstones and dungeon statues are interactive;
   - Pallass `wool_bale_stack` and `wool_trader` must stay explicit.

   Pinned by the opt-in rule and the per-region skip list in each PR.
4. **Combat-board blocked cover changing look when a biome row changes** (inn-borrowing maps). Pinned by a combat capture in any region that changes a biome (Liscor, Riverfarm, Pallass).
5. **Ratchet regression in an already-converted region** caused by a later region's pool sharing a variant. Pinned by G3 on the composed tree and by G2 re-run for every converted region.

---

## Region order and specifics

For each region below, open the issue, then run pilot Tasks 1–7 with these substitutions.

### R1. Liscor (`street`, `guild`, `runners_guild`, `barracks`)

- **Problem:** `facade_plaster` 14x and `inn_roof` 8x on `street`; the interiors borrow the `inn` biome.
- **Biome:** `guild`, `runners_guild` and `barracks` move to `liscor_civic`.
- **Roles:**
  - `facade_wall` (module, ≥4) and `roof` (module, ≥3);
  - `door_street` family;
  - `cargo` (`grain_sacks` stays explicit where the text says sacks);
  - civic interiors: `counter` (map: `counter_left/mid/right` form one set, so pool by set, never mix halves), `notice` (`note_pinned`, cell), `seating`.
- **Direction:** holistic art review section "Liscor: rebuild the market and give civic rooms their jobs".
- **Traps:**
  - `barracks` was touched by #602 rest signposting; keep its rest props explicit.
  - Watch Guard and Resting Runner are role NPCs and may share cast rigs.

### R2. Underground: ruin, dungeon, sewers (`ruin_surface`, `dungeon_approach`, `seal_vault`, `trapped_halls`, `sewers`, `deep_tunnels`)

- **Problem:** `dungeon_rubble` makes up 41% of ruin placements and 27% of dungeon placements; `boulder` repeats in the sewers.
- **Kits:** three separate kits (`ruin`, `dungeon`, `sewers`), so the underground places don't share one look. `cave` remains the sewers' and ruin's biome for simulation.
- **Roles:**
  - `debris` (cell, ≥4, distinct rubble silhouettes) and `rock` (cell);
  - `brazier` (map);
  - `web` (cell, sewers only).
  - Explicit: `pressure_plate`, `wardstone_anchor`, `dormant_guardian_statue`, `dungeon_statue` (encounter-bearing), `chest` (loot containers) and `snare_coil` (trap).
- **Traps:** `#602` rest props in `dungeon_approach`, `ruin_surface`, `sewers` and `deep_tunnels` stay explicit, as do the encounter trigger cells.

### R3. Inn (`inn`, `inn_upstairs`, `inn_player_room`)

- **Problem:** 59% generic core; `door` and `window_blue` shared everywhere.
- **Kit:** `inn` is the canonical warm interior. Its look must stay the most familiar one, so keep the hearth and grill explicit.
- **Roles:** `door_room` family (upstairs has 3 doors), `window_interior`, `rug`, `seating`, `lamp_wall`.
- **Direction:** holistic art review section "The inn: the strongest first pilot". Preserve the warm hearth pools; this is a subtle pass.
- **Traps:** guest NPCs are canon; no cast list is needed for the inn.

### R4. Riverfarm (`riverfarm_village`, `riverfarm_longhouse`, `riverfarm_mill`, `witch_hollow`, `witch_hut`)

- **Biome:** `riverfarm_longhouse`, `riverfarm_mill` and `witch_hut` move to `riverfarm_interior`.
- **Roles:**
  - `fence` (module, ≥3, EW/NS kept as separate roles since their orientation differs), `crop_row` (cell), `cargo`;
  - interior `seating`/`table`/`lamp_wall`;
  - hollow `canopy_tree` (cell, ≥3) and `glow_stone` (cell).
- **Direction:** holistic art review section "Riverfarm and the witch hollow". Keep the canopy framing.
- **Traps:**
  - Interiors already use `*_owned` hero pieces, which stay explicit.
  - Eloise, Former Headman and The Tallyman stay explicit.

### R5. Pallass (`pallass_market`, `pallass_forge`, `pallass_forge_hall`, `pallass_den_shop`)

- **Biome:** `pallass_den_shop` moves to `pallass_interior`.
- **Roles:** `lamp` (`crystal_lamp`, map; the region signature is a cold white light), `tier_wall` (module), `cargo`, `shelf`.
- **Cast:** `garuda_runner` and any other anonymous residents.
- **Direction:** holistic art review section "Pallass: show the city under the player".
- **Traps (from the #513 lane):**
  - `wool_trader`, `dullahan_examiner` and `wool_bale_stack` stay explicit, and the stack stays off the trader's cardinal axes.
  - The canonicals `pallass_peek` pin sprite counts (market 29, forge 21; these count entities only, so substitution keeps them).
  - `pallass_row_help` routes to the stack; it must pass unchanged.

### R6. Floodplains (`floodplains`, `rags_camp`)

- **Problem:** `bush_green` 8x, `tree_big` 7x, `boulder` 7x.
- **Roles:** `shrub` (cell, ≥4), `tree` (cell, ≥3), `rock` (cell, ≥3), plus the existing scatter pools converted to `@scatter_*` pools.
- **Explicit:** the camp's `*_owned` palisade and tents.
- **Direction:** holistic art review section "Floodplains, Rags's camp and the ruin".
- **Traps:** the `#602` rest props on `floodplains` stay explicit; Rags's camp encounter cells are untouched.

### R7. Garden (`garden_sanctuary`)

- **Problem:** already 97% exclusive; its within-map repeats are blossom ×8 and ×6.
- **Roles:** `blossom` (cell, ≥4; white and purple stay separate kinds only if their identity matters, otherwise one pool), `hedge` (module).
- **Direction:** holistic art review section "Garden of Sanctuary".
- **Traps:** the memorial plinths are story props and stay explicit.

### Invrisil carry-over (pilot 1b deviations, #608 final review)

Logged in `docs/CHOICE-LOG.md` (Regional kits). Land both before another map adopts `invrisil_shop` or the enchanter rooms change, each with a scoped read.

- [ ] `invrisil_shop` (`data/biomes.json`): replace the `inn` render clone with its own floor, skirt and blocked look from the Invrisil materials (`floor_rest`, `wall_shop`) and its own `blocked_props` from the pool.
- [x] `enchanter_shop` and `enchanter_work_room`: author `floor_layers` geometry. Done in #632: the shop on `@floor_marble`, the work room on `@floor_checker`.

### #632 rulings (Invrisil rebuild, 2026-10-11)

Controller rulings:
1. **Decision 4.** No dialogue or observe text in `mercantile_alleys` names a workbench. The read's "workbench cluster" is the Apothecary Corner at (1,6), whose text names a burner on the bench, so it stays. The cargo-yard cluster goes on alley cells that are already blocked, built from the `_common` `barrel`, `sack` and `crate` roles once #631 (PR #640) merges. No new blocking without a visible reason.
2. **Window night state (decision 2).** A decor row's `night_glow` draws an additive, phase-gated sibling (`world.gd`), using the owned procedural `window_glow_warm`. Lights could not do it: the boulevard's 8 street lamps fill `LIGHT_BUDGET`. Extra decor rows could not either: the facade cells already carry two rows, and a third trips the one-cell decor lint.
3. **Sealed bale.** The owned PixelLab `invrisil_sealed_bale` (controller generation). sack#15 is not pixel-edited, because a derived FORBIDDEN asset would need a new bundle.
4. **`_common` pieces.** barrel#8, sack#15 and container#29 are not registered in this lane; #631 replaces the `_common` members.
5. **door#14/#16.** Still waiting on the user's ruling; unused.

Implementer rulings:
- **Rest sign.** `invrisil_rest_sign` is an owned hand-pixel edit of `invrisil_hanging_sign` (three face-down cards and a hat on a peg). It is pinned at cross-street (13,1) and not pooled.
- **`lamp_wall` pool.** `sconce` (a campfire sheet) leaves the pool for `invrisil_lamp_wall_cold`, an alias of `lamp_wall_cold_owned` at 0.7 (about 13x20, level with `invrisil_lamp_wall_1`). The alley lights turn cool white. `invrisil_lamp_wall_1` keeps `owned_fallback_unlit_lantern`, because lint needs two distinct owned fallbacks per pool.
- **`door_street`.** `door_street_townhouse_owned` joins the pool at 0.55, and `invrisil_door_street_3` falls back to it. The boulevard–alleys portal now draws the townhouse door in both builds.
- **Marble curb.** A Wang edge-ring floor layer over the plaza patch, in the street's own tone. A null `wang_corners` entry leaves its vertex unpainted (`tile_board_builder.gd`). The same ring runs round the cross-street walks, which closes `paving_apron`.
- **Shop walls and floors.** `wall_dado` (Building_Walls plaster (24,13)) with the owned `cornice_gold_line` as a material `trim` goes on the stationer's and enchanter shop's north walls; caps-only side walls stay `@wall_shop`. `floor_marble` (Floors_Tiles pale marble, toned to limestone) covers both shops, and the work room gets `floor_checker`. The parlor keeps its flagstone and the Rest its honey plank and timber. The work room wall stays timber, because `ashlar_over_checker_v1` has no wall face.
- **Decor `lift`.** Tabletop pieces (inkpot, quill, scroll, book, glass, test-tube rack, bell jar) sit on their surface through the row's `lift`, so their public fallbacks lift too.
- **Work-room door pair.** Both pinned to `invrisil_door_street_3` (a plain framed interior door). `door_locked_heavy` read as a barred cabinet (#610).
- **Parapet line (#610 c3).** The Castle cornice band (5-7,3) runs over the flat roof mass on both streets, with an owned fallback. It reopens c3 if the blind read fails.
- **Skipped, with reasons:**
  - other#27 potion column: at 16px it reads as stacked coloured blocks.
  - book#1 tome: floats as a blue kite over the order-book desk.
  - rug#11: a loud flat purple square that breaks lowest-contrast ground.
  - plant_c#45 to #48 blooms: upright stems on paving read as giant flowers, and no map has a bed.
  - seat#1 armchair: throne height.
  - bed#1: no bed in the eight maps; the parlor's cots are cots by their text.
  - rug#4 and rug#14: a 5x5 fur rug has no room, and rug#14 has a hole in it.
  - tool#12 and table#11: three to five cells wide, with no room in the 8x6 work room.
  - tool#18, tool#20, table#10 and table#30: the front counters are wood by their text, and table#18 took the case.
  - station#33: the stationer stove is pinned to `cold_hearth` by the #608 read.
  - decor#3 and decor#4: one bust is enough.
  - decor#20 curtains: five cells tall.
  - decor#10 painting: needs a recut and has no owned fallback.
  - wall_module#3, #11 and #17: railings would need a new blocked ring round the fountain beside the porter, and the glass gable is six cells tall.
  - container#15, container#31 and vessel#33: the work-room surface reads cluttered past two items.
  - sign#2 and sign#3: two banners already frame the cross-street door.
  - pipe#4: lands with the cargo cluster.

## G3 regen log (moved from CHOICE-LOG, 2026-10-09)

Per-regen numbers for the `scene-repetition.json` ratchet. CHOICE-LOG keeps one summary line per region and the rulings.

- **G3 regens (#608 pilot 1a, controller):** each regen follows a
  reviewed conversion and never hides repetition. The Invrisil generic
  placements went 84 → 76 after the street conversions (share 43.3% →
  39.18%), → 75 with the dedicated rigged-crate-stack sprite, held at 75
  when the art-read fixes added three cross-street lamps and dropped the
  stationery bundle, and → 74 when the boulevard's generic door at (4,1)
  was pinned to the Invrisil shop door (share 37.76%). It held at 74 when
  the counting-room guard took the new regional `invrisil_enforcer` rig
  (one new class row, no counter change).
- **G3 regen (#608 pilot 1b, Task 9c):** the enchanter tray and stationer
  paper stand left the generic `crate` for dedicated regional sprites
  (`invrisil_returned_work_tray`, `invrisil_paper_stand`): Invrisil generic
  placements 74 → 72 (share 36.73%), two new regional class rows.
- **G3 regen (#608 pilot 1b, Task 11):** the interior conversions (tables,
  rugs, interior windows, one cargo row) and the pool-member reclassification
  (`window_blue`, `table_brown__alt1`, `window_blue__alt1`,
  `enchanter_floor_mat` now count as regional): Invrisil generic placements
  72 → 63 (share 32.14%). The same reclassification moved `inn` 39 → 35
  (50.0%) and `riverfarm` 30 → 29 (24.79%) with no map edit in either;
  `window_blue` is the only shared id. Sconces stayed explicit: `lamp_wall`
  has 4 street placements and a pool of 2, so a fifth trips G1.
  Frozen-class residual: `window_blue` stays in the `window_interior` pool
  while all three Invrisil maps pick `__alt1`, so a future map that draws
  it places a three-region sprite that G3's frozen class keeps counting as
  regional until the next regen.
- **G3 regens (#608 pilot 1b FIX loop, art read):** the stationer desk and
  stove pins left the generic ids, with one new regional class row
  (`owned_fallback_library_desk`), and the deleted parlor rug took the
  Invrisil placement count 196 → 195: generic placements 63 → 61 (share
  31.28%). The r2 identity-cue pins (lamps and doors off `sconce`/`door`)
  took it 61 → 52 (share 26.67%) with one new regional class row
  (`invrisil_lamp_wall_1`).
- **G3 regens (#620 R1 Liscor):** the Liscor conversion pins the five wall
  sconces to `liscor_sconce_copper`/`liscor_bracket_lantern`, the guild and
  barracks tables to `bonus_round_table`/`inn_table_dirty__before`, and the
  two stools to `liscor_side_chair`.
  - Liscor's own generic placements fell 48 → 35 (share 44.86% → 32.71%).
  - With `table_brown` and `stool` no longer placed in Liscor, the
    classifier reads them as regional. That lowered the inn's generic count
    (35 → 33, share 50.0% → 47.14%) and Invrisil's share (26.67% → 23.08%).
    Neither map was edited and nothing visual changed; these are classifier
    artifacts.
  - G2 for Liscor is 53.27%.
  - **FIX loop 1 (art read):** Liscor's own generic placements fell
    35 → 19 (share 32.71% → 18.63%, placements 107 → 102): doors pinned
    to `door__alt2`/`door__alt3`, owned crates, roofs and facades, and the
    deleted repeats, trees and rug. The other regions moved only through
    the classifier, with no map edits:
    - floodplains 21 → 17 (24.14% → 19.54%) and pallass 28 → 27
      (29.17% → 28.12%): `tree_round` is no longer placed in Liscor and
      reads as regional.
    - inn 33 → 32 (47.14% → 45.71%): the deleted guild rug left
      `rug_woven_cream` regional.
    - riverfarm 29 → 28 (24.79% → 23.93%): same classifier shift.
    - Invrisil is unchanged (23.08%). The guild rug was deleted instead of
      swapped to `rug_woven_red`, which would have made that id generic
      and added three Invrisil generic placements.
  - **FIX loop 1 deviations from the art read:** Krshia stays at (13,2)
    (the ruled move to (13,3) blocks the street's y3 lane and the
    bump-from-(13,3) approach used by about 35 QA scripts). Street dusk is
    [0.62,0.54,0.63], not [0.72,0.56,0.5] (lint RULE 1 needs day>dusk
    temperature and day is neutral). The Runners' wall lamp, hearth and mud
    table keep their art (their copy says dry, cold and muddy). The barracks
    sconce sits at (7,1) because the veteran's note takes (8,1). Barracks
    dusk is [0.64,0.7,0.8] for the same RULE 1 monotone check.
    Scatter now honours a `cells` key in `_build_scatter`.
  - **Global pebble scale:** `owned_fallback_pebble` `render_scale` 0.53 →
    0.3 applies wherever the fallback shows, not only on the Liscor street
    (ruled acceptable; it read as boulders everywhere).
  - **R1 land (merge of #625 art identity, then FIX loop 2):** under art
    counting Invrisil fell to 47.18% G2 because Liscor reused its art under
    new ids.
    - The 14 street facades went back to `facade_plaster`, untinted.
      `owned_fallback_facade_plaster` is the same art as
      `invrisil_timber_panel` (sha 5bd39a03). This is an interim state: a
      follow-up issue builds Liscor's sandstone-brick identity from
      Cemetery Walls (decision 1 above).
    - `liscor_bracket_lantern` keeps its id, but now draws lamp #6
      (`Sewer Props__x116_y5_w9_h20`) instead of `invrisil_lamp_wall_1`'s
      Furniture slice. The light block is unchanged.
    - Left as they are: `bonus_round_table` (≡ `inn_round_table`) and
      `inn_table_dirty__before` (≡ `inn_table_soiled`) are inn art. The
      inn is not converted, so no gate fails yet. This is a follow-up for
      the inn conversion.
    - N3: the barracks cargo at (3,2) is pinned to `crate_owned`. A deny
      word cannot do the job, because kit deny lists screen row prose,
      not pool picks. That pin was the barracks' only @ref, so the
      barracks has left G2's converted set.
    - N5: the `floor_civic` trial of [22,3] kept the same dark tile lip
      on every row and added a vertical seam (headless capture row-mean
      sd 5.29-6.48). So `carpet_over_floorboards_v2_square` [2,1] became
      the primary (row-mean sd 0.18-0.20).
    - N2: `anchor_waystone` 0.4 → 0.55 is global. It also changes the
      Invrisil boulevard, Riverfarm village and the inn's mounted-door
      state.
    - G2 is now 68.83% for Liscor (street and guild converted) and
      56.92% for Invrisil.
    - The G3 regen (once, against main's art-counted baseline) puts
      Liscor at 19/102 (18.63%). The classifier moved the other regions
      with no map edit: floodplains 21 → 17, inn 39 → 36 (51.43%),
      invrisil 58 → 51 (26.15%), pallass 28 → 27, riverfarm 30 → 29.

- **#620 r3 N8 (Runners' Guild counter ends → `counter_segment_owned`):** Liscor generic placements 19 → 17 (18.63% → 16.67%); no other region moved. Regenerated with `--regen-scene-baseline`.
  - **Final review (#620):** the Runners' counter returned to the Selys pattern (Vess back at (5,2), the filled (5,2) counter segment removed): Liscor placements 102 → 101 with 17 generic (share 16.67% → 16.83%), `runners_guild` 11 → 10; the waystone scale reverted to 0.4 (Liscor-only alias is a #629 follow-up).

## Per-region checklist (copy into each region issue)

- [ ] Issue opened; branch and worktree created; overlay copied; import pass done.
- [ ] Capture scripts written; before-captures preserved in `qa_output/kits/<region>/before/`.
- [ ] `python3 tools/asset_coverage.py --check` shows 0 UNCLASSIFIED; pool read starts from `docs/kits-allocation.md`.
- [ ] Materials: region-exclusive floor and walls selected (pool read PASS) and wired; or a generation-list row added.
- [ ] Null rule (spec §2.2): a map field set to `null` blocks the material's value, and only wall-segment `face`/`cap` may be nulled (caps-only or face-only segments). `data_lint` rejects any other null, and a nulled key on a material that carries a `fallback_render`.
- [ ] Roles: each pool selected via `fill_kit` with a pool read; fallback set ≥2 distinct owned sprites; lint and commit per role.
- [ ] Rows converted opt-in; skip list with reasons recorded; stand-ins replaced or listed; cardinal-axis check done.
- [ ] `data_lint --base origin/main` green: G1–G5, cast and denylist rules.
- [ ] G2/G3 count art; check `wire_asset` duplicate refusals.
- [ ] `preflight --full`, `ci_sweep --touching <maps, kits.json, biomes.json>` and `journey_gate --only <affected>` green.
- [ ] Combat capture where a biome row changed.
- [ ] Official and public after-captures plus the region strip.
- [ ] Dusk/night views captured and read wherever ambience is phase-gated: check each map's `ambience` rows for `phase` and the biome's row in `BIOME_DEFAULT_AMBIENCE` (`src/world/world.gd`). Equal mood grades do not make night identical: four pilot interiors share one grade across phases but add dust motes at dusk and night.
- [ ] Blind Fable scene read: all PASS after the FIX loop; reconcile done; CHOICE-LOG entries made.
- [ ] Prepared save `qa/playtest_saves/<date>-kits-<region>` with a "load X, do Y, judge Z" line.
- [ ] Identity cues pinned explicitly (as Invrisil pinned `invrisil_lamp_wall_1` ×3 and `invrisil_door_street_2`/`_3`) are invisible to G1's per-role check; only its coverage line counts them. List them in the PR.
- [ ] PR (issue-close template): independent review, CI green, squash-merge.
- [ ] `tools/asset_usage.py` delta posted on #606.

## Phase close (after R7)

- [ ] Re-run `tools/asset_usage.py`. Post the final before/after usage by source on #606: PixelLab candidates, Pixel Crawler slices and other packs.
- [ ] Post the consolidated `docs/art-generation-list.md` and `docs/art-bundle-pending.md` on #606, labelled for the user decision. Phase 3 generation needs a PixelLab renewal and user approval; a bundle release needs `wi-shipping` and user approval.
- [ ] Update `HANDOFF.md` and add the user eye-gate list: one prepared save per region.
