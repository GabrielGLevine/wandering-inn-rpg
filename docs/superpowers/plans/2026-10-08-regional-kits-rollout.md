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
- [ ] `enchanter_shop` and `enchanter_work_room`: author `floor_layers` geometry on `@floor_shop`; they render the `brothers_parlor` biome floor (the inn plank) today.

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
