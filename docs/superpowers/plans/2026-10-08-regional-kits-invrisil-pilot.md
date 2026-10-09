# Regional Kits Invrisil Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Invrisil a recognisable regional kit and remove within-region repetition, in two PRs (1a streets, 1b interiors), each closed by a blind Fable art-direction read (issue #608).

**Architecture:**
- Pools are selected from the existing asset pool with `tools/fill_kit.py`.
- Map rows are converted one at a time to `@role` and `material: @x` references, resolved at compose time by Phase 0's `WIKitResolver`.
- Gates G1–G5 run in `data_lint`.
- The pass/fail authority is a fresh Fable reader looking at windowed after-captures, blind to the metrics.

**Tech Stack:** `data/kits.json`, map JSON, `tools/fill_kit.py` / `tools/wire_asset.py` / `tools/find_asset.py`, declarative QA capture scripts (windowed), Fable subagents for the pool and scene reads.

**Spec:** `docs/superpowers/specs/2026-10-08-regional-kits-design.md` (§2, §3, §4.2, §5, §6 1a/1b)

## Global Constraints

- **Starts only after #607 is merged.**
  - 1a branch: `issue/608-invrisil-streets` from the merge commit, worktree `/private/tmp/wi-608a`.
  - 1b branch: `issue/608-invrisil-interiors`, from main after 1a merges, worktree `/private/tmp/wi-608b`.
  - Copy the private overlay (`git ls-files --others --ignored --exclude-standard wandering_inn_game/assets`) and run `--import` before any QA.
- **Pool first.**
  - Owned art and pack slices on already-bundled sheets only.
  - A shortfall goes to `docs/art-generation-list.md`, and an unbundled sheet goes to `docs/art-bundle-pending.md`.
  - Never call PixelLab: the subscription lapsed and there is no bundle release.
- **Opt-in conversion, one row at a time.**
  - Never bulk-replace by sprite id, and never re-sort rows.
  - Keep explicit: entities with `visual_states` (boulevard `boulevard_night_footpads`, `boulevard_duel_ring`; alleys `alley_footpads_a/b`), named NPCs, story or special-function doors, and rows whose `display_name`/`observe` names a specific look.
- **G4 structural invariance.** Per map, cells, `blocked`, `walls` geometry and scatter density stay identical; only `sprite`, `material`, `tint` and `light` fields change.
- **Never edit a QA pin to hide a change.**
  - The only expected pin edit is `qa/scripts/stationer_room_loop.json:29-36`, in 1b, where `sprite` becomes `sprite_role` if that NPC is converted.
  - Any other pin failure is a finding.
- **Pallass-lane trap (generalized):** keep props off an NPC's cardinal axes. Dialogue separation pushes the NPC away from the player, so it can end up hidden behind a prop.
- **Windowed QA serializes:** one Godot process class per tree. Copy screenshots out of `qa_output/` before the next run.
- **The art-direction read is authoritative.**
  - A region half closes only when every view is PASS.
  - When the read and the metrics disagree, the read wins and the metric ruling is logged in `docs/CHOICE-LOG.md`.

## Review Focus

1. **Wrong-kind art under prose:** a pool variant lands under text that names something else. Pinned by the role `deny` lint plus the Task 4 manual sweep of every converted row's `display_name`/`observe`.
2. **Style clash between mixed sources** (PixelLab vs Pixel Crawler) in one pool. Pinned by the Task 3 pool read, which drops incoherent candidates before wiring.
3. **The public build collapses a pool to one sprite.** Pinned by G5 and by each pool's fallback set having ≥2 distinct owned sprites; Task 6 runs `qa/check_fallback_boot.sh`.
4. **A converted door no longer reads as a door, or its two sides differ.** Pinned by the door family lint (footprint ±2px, anchor, shadow, portal-pair seed) and by a landmark/focus capture on both sides of one portal (Task 2).
5. **Facade modules tile periodically** (ABCABC) on 16-panel runs. Pinned by `module: true` (r=1), pools of ≥3 variants, and the scene read's repetition check.

---

## Part 1a: Invrisil streets (`invrisil_boulevard`, `invrisil_cross_street`, `mercantile_alleys`)

Baseline facts (main `83fc6c63`):
- **Boulevard (28x18):** timber_panel 9, upper_window 9, street_lamp 8, roofline 5, door 3, 7 anonymous NPCs, named `master_coyle`.
- **Cross-street (22x14):** timber_panel 7, upper_window 7, invrisil_shop_door 3, roofline 2, hanging_sign 2, ornate_bench 2.
- **Alleys (20x14):** crate 7, door 5 (2 are transit), sconce 4, plus the stand-ins "A Shadowed Nook", "A Rigged Crate Stack" and "A Factor-Sealed Bale"; floor `Floors_Tiles.png`, which is generic across 7 maps.

### Task 1: Branch, overlay, capture scripts, before-captures

**Files:**
- Create: `wandering_inn_game/qa/scripts/kits_invrisil_invrisil_boulevard.json`
- Create: `wandering_inn_game/qa/scripts/kits_invrisil_invrisil_cross_street.json`
- Create: `wandering_inn_game/qa/scripts/kits_invrisil_mercantile_alleys.json`

These are non-canonical windowed utilities like `qa/scripts/mood_sheet_night.json`: they are **not** added to `qa/manifest.json`, so no surface regeneration is needed.

- [ ] **Step 1: Create the worktree.**

```bash
cd /Users/gabriel/wandering-inn-rpg && git fetch -q && git worktree add -b issue/608-invrisil-streets /private/tmp/wi-608a origin/main
cd /Users/gabriel/wandering-inn-rpg && git ls-files --others --ignored --exclude-standard wandering_inn_game/assets | rsync -a --files-from=- ./ /private/tmp/wi-608a/
/usr/local/bin/godot --headless --path /private/tmp/wi-608a/wandering_inn_game --import
```

- [ ] **Step 2: Write one capture script per map.**
  - Each script has three phase legs, day, dusk and night, using the fixtures `feel_peek_day_start`, `feel_peek_dusk_start` and `feel_peek_night_start`, exactly as the mood-sheet scripts do. Copy their title-gate preamble verbatim from `qa/scripts/mood_sheet_night.json`.
  - A script runs one fixture, so a single script cannot hold three phases. Create one file per phase per map, `kits_invrisil_<map>_<phase>.json`, nine files in all.
  - Each leg teleports to three cells and takes one screenshot each.
  - Screenshot names follow `kits_invrisil_<map>_official_<phase>_<view>`; the `public` variant is the same script run on the fallback tree (Task 6).
  - Choose the cells by reading the map JSON and keep them clear of encounter triggers:
    - `arrival`: the portal cell the player enters from;
    - `landmark`: the unoccluded focal structure (boulevard: `plaza_fountain`; cross-street: the shop row; alleys: the parlor door);
    - `focus`: next to one converted interactive row.

  Template for the boulevard day leg (use the same shape for every map and phase):

```json
{"_comment": "Regional kits #608 capture utility (non-canonical, windowed only, absent from qa/manifest.json). Same route before/after conversion; screenshots feed the blind art-direction read (spec §5.2).",
 "fixture_save": "feel_peek_day_start", "starts_at_title": true,
 "steps": [
  {"action": "wait_for_event", "type": "ui_title_gate_rendered", "timeout_sec": 5},
  {"action": "press", "name": "confirm"},
  {"action": "wait_for_event", "type": "ui_title_rendered", "timeout_sec": 5},
  {"action": "move", "direction": "down", "steps": 1},
  {"action": "press", "name": "confirm"},
  {"action": "wait_for_event", "type": "game_loaded", "timeout_sec": 5},
  {"action": "wait_for_event", "type": "world_ready", "timeout_sec": 10},
  {"action": "teleport", "map": "invrisil_boulevard", "cell": [ARRIVAL_X, ARRIVAL_Y]},
  {"action": "wait_frames", "frames": 30},
  {"action": "screenshot", "name": "kits_invrisil_invrisil_boulevard_official_day_arrival"},
  {"action": "teleport", "map": "invrisil_boulevard", "cell": [LANDMARK_X, LANDMARK_Y]},
  {"action": "wait_frames", "frames": 30},
  {"action": "screenshot", "name": "kits_invrisil_invrisil_boulevard_official_day_landmark"},
  {"action": "teleport", "map": "invrisil_boulevard", "cell": [FOCUS_X, FOCUS_Y]},
  {"action": "wait_frames", "frames": 30},
  {"action": "screenshot", "name": "kits_invrisil_invrisil_boulevard_official_day_focus"}
 ]}
```

  `ARRIVAL_*`, `LANDMARK_*` and `FOCUS_*` are cells you pick from the map JSON while writing the file; the committed file contains integers. Check each cell is walkable (not in `blocked`, not on a solid entity).

- [ ] **Step 3: Run every capture before any conversion and preserve the shots.**

```bash
cd /private/tmp/wi-608a && for m in invrisil_boulevard invrisil_cross_street mercantile_alleys; do for p in day dusk night; do
  wandering_inn_game/qa/run_qa.sh kits_invrisil_${m}_${p} windowed; echo "exit $?";
  mkdir -p wandering_inn_game/qa_output/kits/invrisil/before && cp wandering_inn_game/qa_output/kits_invrisil_${m}_${p}/*.png wandering_inn_game/qa_output/kits/invrisil/before/;
done; done
```

  Expected: every run exits 0 with a passing `result.json`, and there are 27 PNGs in `before/`. Read 3 of them to confirm the HUD is visible, the camera is correct and nothing is occluded.

- [ ] **Step 4: Commit the scripts.**

```bash
git add wandering_inn_game/qa/scripts/kits_invrisil_*.json && git commit -m "qa: Invrisil street capture utilities for the kits read (#608)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Street materials (floor) from the pool

**Files:**
- Modify: `wandering_inn_game/data/kits.json` (add the `invrisil` kit `materials`)
- Possibly create: `wandering_inn_game/assets/tiles/harvest/<owned tile>.png` + provenance line

- [ ] **Step 1: Find region-exclusive floor candidates.**
  - The boulevard and cross-street marble (`tileset_marble_wang4x4.png`) is already Invrisil-only; confirm with `grep -l marble_wang4x4 wandering_inn_game/data/maps/*/*.json`.
  - The alleys use generic `Floors_Tiles.png`, so search:

```bash
python3 tools/find_asset.py cobble alley --kind tileset
python3 tools/find_asset.py worn flagstone --kind tileset
```

- [ ] **Step 2: Hold the pool read (§5.2) for the alley floor.**
  - Render the 2–4 best tileset candidates at gameplay scale beside a boulevard after-shot crop.
  - Dispatch a fresh Fable subagent with the pool-read prompt (Appendix A).
  - Keep only PASS candidates, and pick one under best art wins: the ground should have the lowest contrast and suit the back-alley character.
- [ ] **Step 3: Wire the material.**
  - Owned tileset: copy it to `wandering_inn_game/assets/tiles/harvest/` and append its provenance (source path and sha256) to `assets/LICENSES/v019-owned-art-provenance.txt`.
  - Add `invrisil.materials.floor_alley` with `sheet`, `tile_px`, `coords|variants|wang_corners`, `tone` and `fallback_render`, following the pattern of the existing floor layers.
  - Add `invrisil.materials.floor_street` copying the boulevard's current marble descriptor fields.
- [ ] **Step 4: Convert the floor rows.**
  - Replace each converted `floor_layers[]` row's material fields with `"material": "@floor_street"` (boulevard and cross-street base rows) or `"@floor_alley"` (alleys). Leave `cells` and `terrain_lower_cells` untouched.
  - The patch rows (`coords [3,3]` plaza) stay explicit.
  - If no alley candidate passes the pool read, leave the alleys explicit and add a row to `docs/art-generation-list.md` ("invrisil · floor_alley · have: — · need 1 · pool lacked a quiet worn-cobble tileset that reads below the marble · base: tileset_marble_wang4x4 · open").
- [ ] **Step 5: Lint.**

```bash
python3 wandering_inn_game/scripts/data_lint.py; echo "exit $?"
```

  Expected: exit 0. G2's exclusive-material check passes for each converted map, or for the boulevard and cross-street only when the alleys floor is listed on the generation list.

- [ ] **Step 6: Commit** (`feat(kits): Invrisil street floor materials (#608)`).

### Task 3: Role pools for the streets (pool-first plus pool read)

Roles and target counts:

| Role | `pick` | Current explicit ids | Need |
|---|---|---|---|
| `door_street` | `door` | `door` (transit doors with `to_map` on the 3 maps) | 2–3 |
| `shop_door` | `cell` | `invrisil_shop_door` (decor) | 3 |
| `facade_panel` | `cell`, `module: true` | `invrisil_timber_panel` | 4 |
| `facade_window` | `cell`, `module: true` | `invrisil_upper_window` | 4 |
| `roofline` | `cell`, `module: true` | `invrisil_roofline` | 3 |
| `lamp_street` | `map` | `street_lamp` | 2 |
| `lamp_wall` | `map` | `sconce` (alleys) | 2 |
| `cargo` | `cell` | `crate`, `barrel` (alleys, generic rows only) | 4 |
| `shop_sign` | `cell` | `invrisil_hanging_sign` | 3 |

For each role:

- [ ] **Step 1: Generate the candidate contact sheet.**

```bash
python3 tools/fill_kit.py invrisil <role> --need <N> --kind <tag> --contact-sheet wandering_inn_game/qa_output/kits/invrisil/pool_<role>.png
```

  Kind tags (C8 vocabulary): door, door, wall_module, window, wall_module, lamp, lamp, crate, sign. Include the role's current explicit id as a candidate so the pool keeps it when it wins.
- [ ] **Step 2: Pool read.** A fresh Fable subagent reads the sheet with the Appendix A prompt, given the role, its kind, the region direction (holistic art review "Invrisil" section) and a boulevard before-shot for context. Drop every candidate it marks FIX or REJECT.
- [ ] **Step 3: Select and wire.**

```bash
python3 tools/fill_kit.py invrisil <role> --need <N> --select <id,id,…> [--pick <mode>] [--module] --lacked "<what the pool lacked>"
```

  Pack slices need `--fallback` owned ids, and each pool's fallback set must contain ≥2 distinct owned sprites. If no owned public alternative exists, the pool fails G5: record it on the generation list and keep the role on its current explicit sprite.
- [ ] **Step 4: Lint after each role** (`data_lint` exit 0), then **commit per role** (`feat(kits): Invrisil <role> pool (#608)`).

Door-specific checks:
- Every family member must render within ±2px of `door`'s 17x22 footprint at its scale, with anchor `[0.5, 1.0]` and the same `shadow`.
- Story doors stay explicit: alleys "A Plain Door, Better Locks Than It Looks", and boulevard "An Enchanter's Frontage", which names a specific frontage.

### Task 4: Convert the street rows

**Files:** Modify the three street map JSONs (surgical edits, no re-sorting).

- [ ] **Step 1: List candidate rows.**

```bash
python3 - <<'EOF'
import json
for m in ["invrisil_boulevard", "invrisil_cross_street", "mercantile_alleys"]:
    d = json.load(open(f"wandering_inn_game/data/maps/invrisil/{m}.json"))
    for layer in ("decor", "entities"):
        for i, r in enumerate(d.get(layer) or []):
            print(m, layer, i, r.get("id", ""), r.get("sprite"), r.get("kind", ""), r.get("display_name", ""), bool(r.get("visual_states")))
EOF
```

- [ ] **Step 2: Convert eligible rows by hand.**
  - `"sprite": "<id>"` becomes `"sprite": "@<role>"` when the row is generic for that role.
  - Skip: rows with `visual_states`, named NPCs, story doors, and rows whose `display_name`/`observe` names a look (e.g. "A Rigged Crate Stack").
  - Write the skipped rows and the reasons into the PR body.
- [ ] **Step 3: Replace the stand-ins with dedicated sprites, from the pool first.**
  - Boulevard "A Good Vantage" uses `crate`.
  - Alleys "A Shadowed Nook", "A Rigged Crate Stack" and "A Factor-Sealed Bale" use `crate`.
  - Search for each:

```bash
python3 tools/find_asset.py bale sealed
python3 tools/find_asset.py crate stack
python3 tools/find_asset.py nook shadow
python3 tools/find_asset.py vantage ledge
```

  - Wire the best candidate with `tools/wire_asset.py --id <new_id>`, after a pool read on a mini contact sheet, and set the row's `sprite` to the new id (explicit, not a role).
  - With no candidate, keep `crate` and add a generation-list row.
- [ ] **Step 4: Check the cardinal-axis trap.** For every converted entity next to an NPC, confirm no solid prop sits on that NPC's cardinal axes within 1 cell, as in the #604 trap.
- [ ] **Step 5: Lint and run the structural diff.**

```bash
python3 wandering_inn_game/scripts/data_lint.py --base origin/main; echo "exit $?"
```

  Expected: exit 0. G4 reports no structural change, G1 passes, and G2 reports Invrisil's street maps at ≥50% region-exclusive share. If G2 fails, list the roles that still resolve to cross-region variants and decide (CHOICE-LOG) whether the shared kind belongs in `_common`.
- [ ] **Step 6: Commit** (`feat(kits): convert Invrisil street rows to roles (#608)`).

### Task 5: Logical QA

- [ ] **Step 1:** Run `scripts/preflight.sh --full` and expect `PREFLIGHT OK` with the parity test green.
- [ ] **Step 2:** Run the affected scripts:

```bash
wandering_inn_game/qa/ci_sweep.sh --touching wandering_inn_game/data/maps/invrisil/invrisil_boulevard.json,wandering_inn_game/data/maps/invrisil/invrisil_cross_street.json,wandering_inn_game/data/maps/invrisil/mercantile_alleys.json,wandering_inn_game/data/kits.json
```

  Expected: every derived `full` script passes. Any `ui_entity_visual_rendered` pin failure is a finding, not a pin edit.
- [ ] **Step 3:** Run `python3 wandering_inn_game/qa/journey_gate.py --only journey_rogue,journey_worker,journey_caster,journey_imperfect,steel_thread` and expect all to pass.
- [ ] **Step 4:** Run `scripts/leak_check.sh` and `python3 scripts/comment_census.py --check`; both must exit 0.

### Task 6: After-captures (official and public) and the blind art-direction read

- [ ] **Step 1: Official captures.** Re-run the 9 capture scripts and copy the shots into `wandering_inn_game/qa_output/kits/invrisil/after/`.
- [ ] **Step 2: Public captures.**
  - Run `bash wandering_inn_game/qa/check_fallback_boot.sh` and record its exit code and marker for the PR.
  - On the stripped tree it prepares (read the script for its path), run the same capture scripts and rename the shots `…_public_…` into `after/`.
- [ ] **Step 3: Region strip.** Compose the arrival views of `invrisil_boulevard` (day) with the arrival views of Liscor `street` and Pallass `pallass_market` (day; capture them with a teleport utility on the same fixture) into `after/strip_invrisil_day.png`, using PIL side by side.
- [ ] **Step 4: Blind read.** Dispatch a **fresh** Fable subagent with the Appendix B prompt. It gets only the rubric, the "Invrisil" direction section and the paths of the `after/*.png` files and the strip: no metrics and no before-shots. It returns one line per view: `name | PASS|FIX|REJECT | sprite_id | cell | problem | proposed fix`.
- [ ] **Step 5: FIX loop.**
  - Append each FIX or REJECT line to `docs/VISUAL-LOG.md` as a `(P1)` row (respect its insertion rule).
  - Fix it by swapping a pool member, moving a row back to explicit or adjusting tint/light, and close the row in the same commit.
  - Re-capture only the affected views and re-read them with the **same** reader agent.
  - Repeat until every view is PASS.
- [ ] **Step 6: Reconcile.**
  - Send the reader the before-shots and the `data_lint` G1–G5 report.
  - If the read passes but a metric fails, either fix the scene or argue the metric, and record the ruling in `docs/CHOICE-LOG.md`.
  - If the read fails but the metrics pass, the read has already won.
- [ ] **Step 7: Prepared save for the user eye-gate.**
  - Save a fixture at the boulevard, dusk, in front of the fountain, as `wandering_inn_game/qa/playtest_saves/2026-10-XX-kits-invrisil-streets`. Use the date of the run, following existing `qa/playtest_saves` entries.
  - Add a "load X, walk boulevard → cross-street → alleys, judge regional identity/repetition/clutter" line to the PR body.

### Task 7: PR for 1a

- [ ] Fill `.github/PULL_REQUEST_TEMPLATE/issue-close.md` with `Refs #608`, since 1b closes it. Include:
  - choices: pool picks, skipped rows with reasons, stand-in replacements, generation-list rows;
  - validation: exact commands and results, G1–G5 report;
  - player-visible proof: the before/after gallery uploaded via `gh`, the read verdict table and the strip;
  - new context: none expected;
  - deferrals.
- [ ] Get an independent code review (a fresh agent, not the implementer). It should refute the claims, check the pin and fixture diff, and confirm the structural diff.
- [ ] Read `gh pr checks`; squash-merge only when the required CI is green.

---

## Part 1b: Invrisil interiors

Maps:
- `adventurers_rest` (biome `inn`, 13x9; floor and walls `Interior_Walls_01.png`, which is generic);
- `stationer`, `enchanter_shop` and `enchanter_work_room` (biome `brothers_parlor`, which is already Invrisil-only; floors are generic `Interior_Walls_01.png` or empty);
- `brothers_parlor` (biome `brothers_parlor`).

Anonymous NPCs:
- rest: `gnoll_ranger`, `human_laborer`, `invrisil_gentlewoman_2`;
- parlor: `gentleman_bowler`, `gnoll_traveler`, `drake_patron`;
- stationer: `invrisil_lady_client`, `city_scribe`;
- boulevard (from 1a): `townswoman` ×2, `human_laborer`, `city_scribe`, `hired_blade`, `invrisil_lady_client`, `gnoll_traveler`;
- cross-street: `city_runner`, `townswoman`.

Role-titled NPCs on shared rigs, which the cast rule allows: "The Counting-Room Factor" on `city_scribe`, "The House Factor" on `house_factor`.

### Task 8: Branch, biome row and interior capture scripts

- [ ] **Step 1:** Create `/private/tmp/wi-608b` from main after 1a merges, then run the same overlay and import steps as Task 1.
- [ ] **Step 2:** Point `adventurers_rest.json`'s top-level `"biome"` at `invrisil_shop`, the Phase 0 row. That row starts as a copy of `inn`; give it Invrisil render fields: its own `blocked_props` from the pool, chosen in Task 9.
- [ ] **Step 3:** Write capture scripts `kits_invrisil_<map>_<phase>.json` for the 5 interiors, using day and night only (interiors have no dusk grade; confirm in `data/moods.json`) and the same view set. Run them on main **before** any change into `before/`, as in Task 1.

### Task 9: Interior materials and pools

- [ ] **Step 1: Interior materials.**
  - Find and pool-read an Invrisil interior floor and wall material that differs from generic `Interior_Walls_01`:

```bash
python3 tools/find_asset.py interior floor plank --kind tileset
python3 tools/find_asset.py shop floor --kind tileset
```

  - Add `invrisil.materials.floor_shop` and `wall_shop`, and convert the interiors' `floor_layers` and `walls` to `material` references. Geometry stays authored.
- [ ] **Step 2: Interior roles**, using the Task 3 procedure (pool read and lint per role, then commit):

| Role | `pick` | Current ids | Need |
|---|---|---|---|
| `seating` | `map` | `stool`, `bench` | 2–3 |
| `table` | `map` | `table_brown` | 2–3 |
| `shelf` | `cell` | `library_shelf`, `shelf_bottles` | 3 |
| `lamp_wall` | `map` | `sconce` (shared with 1a) | — |
| `rug` | `map` | `rug_woven_red`, `rug_woven_cream` | 3 |
| `window_interior` | `map` | `window_blue` | 2 |
| `cargo` | `cell` | `barrel` (generic only, shared with 1a) | — |

- [ ] **Step 3: Interior stand-ins.** "A Tray of Returned Work" (`enchanter_shop`) and "Ruled Paper in Three Weights" (`stationer`) currently use `crate`. Find dedicated sprites with `find_asset.py tray`, `find_asset.py paper stack` and `find_asset.py ream`; otherwise add a generation-list row.

### Task 10: Cast for anonymous townsfolk

- [ ] **Step 1:** Add `invrisil.cast` with every rig used by an Invrisil "A …"/"An …" NPC: `townswoman`, `human_laborer`, `city_scribe`, `hired_blade`, `invrisil_lady_client`, `gnoll_traveler`, `gnoll_ranger`, `invrisil_gentlewoman_2`, `gentleman_bowler`, `drake_patron` and `city_runner`.
- [ ] **Step 2:** Run `data_lint` and expect the cast rule to pass. If a canon character uses one of these rigs anywhere, lint fails: give that character a dedicated rig from the pool (`find_asset.py <name> --kind rig`) or log a generation-list row, and remove the rig from the cast.
- [ ] **Step 3:** Check each anonymous NPC's costume-describing name against its rig (e.g. "A Lady in Plum Silk" must still read as plum silk at the authored tint) in the Task 11 captures. No rig is changed by the cast list itself.
- [ ] **Step 4: Commit** (`feat(kits): Invrisil cast (#608)`).

### Task 11: Convert the interiors, QA, read and PR

- [ ] **Step 1:** Convert the interior rows using the Task 4 procedure (opt-in, explicit exceptions, cardinal-axis check, `--base origin/main` structural lint).
- [ ] **Step 2:** Update `qa/scripts/stationer_room_loop.json:29-36` only if `cross_street_shopper` was converted. NPCs are not converted by the cast, so expect no change; note it in the PR either way.
- [ ] **Step 3:** Run the Task 5 gates with `--touching` on the 5 interior maps, `data/kits.json` and `data/biomes.json`.
- [ ] **Step 4:** Run the Task 6 captures and blind read for the 5 interiors. The region strip now includes one interior arrival view per map. Run the FIX loop to all-PASS, reconcile, and prepare the save `…-kits-invrisil-interiors` at the stationer, day.
- [ ] **Step 5:** Open a PR `Closes #608` with the same template contents as Task 7, plus the region-level G2 report, which must show ≥50% across all 8 Invrisil maps. Get an independent review, check CI, and squash-merge.
- [ ] **Step 6:** Run `python3 tools/asset_usage.py` (Phase 0 lane-C diagnostic; if it isn't built yet, run the audit scripts recorded in #606) and post the before/after usage delta on #606.

---

## Appendix A: Pool-read prompt (fresh Fable subagent, read-only)

> You are the art-direction reader for a regional kit pool in a 16px top-down pixel RPG. Read ONLY the images listed. Rubric (from docs/design/2026-10-05-holistic-art-review.md "Proposed visual grammar"; read that table and the region section "<Region>"): coherent material family; crisp clusters and consistent apparent pixel size at gameplay scale; consistent outline weight and light direction; no candidate may read as a different kind than **<kind>** (e.g. a cargo variant must not resemble the tagged cargo pallet or a bale); must suit <Region>'s direction. Images: <contact sheet path> (numbered candidates), <context crop path> (the region as it looks now). Output one line per candidate number: `n | PASS|FIX|REJECT | reason`, then a ranked list of up to <N> PASS candidates that work together as one family. Do not consider repetition statistics or asset counts.

## Appendix B: Scene-read prompt (fresh Fable subagent, blind)

> You are the art-direction reader for converted game scenes. You must judge ONLY from these images and this rubric; you have no metrics. Read docs/design/2026-10-05-holistic-art-review.md sections "Proposed visual grammar" and "<Region>". For each image below, judge: does the region read as itself at a glance (use the strip); visible repetition or confetti noise; ground has the lowest contrast; interactive things read interactive and decorative brightness does not imitate actionable feedback; doors read as doors; style coherence across sources; anchors/crops/scale consistent (feet on cells, no floating, no clipped tops); one focal structure per composition; clutter (nothing crowding paths or NPCs). Images: <list of after/*.png and strip>. Output exactly one line per image: `<file name> | PASS|FIX|REJECT | sprite_id or - | cell or - | problem | proposed fix`, then a 3-sentence overall verdict on regional identity. Be strict: "passes statistically but looks bad" must be a REJECT.
