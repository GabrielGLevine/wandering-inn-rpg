# Regional kits: design (user-approved sections, 2026-10-08)

> Status: **§1, §1b, §2 and §3 approved by the user** in brainstorming on
> 2026-10-08. Each section passed an automatic Fable design review (verdicts
> recorded inline). This document pins the HOW; the implementation plan follows
> separately.

## 0. Intent

**User, verbatim:** "Available assets feel heavily underutilized, especially
given the amount of asset reuse in the game. How can we address this at a
structural level to leverage the full scope of the available art (without the
experience becoming cluttered)?" Follow-on rulings from the same session:

- Success means **regional identity**: each region reads distinct at a glance
  through floors, walls, doors and clutter.
- Avoid within-region monotony as well: regions must not swap one shared crate
  for one regional crate repeated thirty times.
- Scope v1 covers **environment plus anonymous townsfolk**. Enemy rosters come
  later in their own spec.
- **Pool first.** Use the existing assets in `potential_assets/` before
  generating anything. When the pool truly lacks variants, record the gap on a
  generation list; generation runs later as one approved batch.
- Pre-process pack atlases into individual sprites so they can be indexed and
  selected.
- Final scenes are **evaluated holistically for art direction** through Fable
  windowed reads. "I don't want something that passes statistically but looks
  bad."
- A Fable agent reviews every design section.

Binding prior rulings: `docs/CHOICE-LOG.md` "best art wins per asset … no quota
wiring", "tint is not identity", and "blocked board cells use biome prop data";
the approved `docs/design/2026-10-05-holistic-art-review.md` (recompose regional
scenes, ground lowest contrast, its visual-grammar table). **Usage percentage is
a diagnostic, never a target.**

**Paths:** `tools/` and `docs/` are at the repo root. `scripts/`, `qa/`,
`data/`, `src/`, `tests/` and `assets/` are under `wandering_inn_game/`. Note
that `wandering_inn_game/tools/` also exists and holds `scene_dynamism.gd` and
`sync_assets.py`.

## 1. Diagnosis (main `83fc6c63`)

| Finding | Evidence |
|---|---|
| Generic sprites dominate | 37 sprites appear in 3+ regions and carry 40% of 839 placements; `door` alone has 48 placements across 8 regions |
| One terrain everywhere | Pixel Crawler `Interior_Walls_01` is the floor in 12/33 maps and the walls in 14 |
| Biome is not region | The `inn` biome backs ~10 maps (Riverfarm mill/longhouse/witch hut, Liscor barracks/guilds, Invrisil Rest, Pallass den shop) |
| Within-region repeats | Invrisil: timber_panel 16x, upper_window 16x, door 14x, sconce 11x, crate 10x; Liscor facade_plaster 14x |
| Stand-ins | The `crate` sprite renders 18 named non-crates ("Ruled Paper in Three Weights", "A Factor-Sealed Bale", "A Carrying Yoke"…) |
| Starved variety hooks | `blocked_props` pools in 6/13 biomes (2–4 sprites); `scatter` on 3 maps; no kits, weighted pools or per-placement picks |
| Wiring cost asymmetry | A new prop touches ~7 files by hand, while reusing `crate` takes 1 line; `wandering_inn_game/tools/sync_assets.py` has been stale since 2026-08-13 |
| Idle supply | PixelLab candidates 18.6% used (535 READY idle; icons 6%); Pixel Crawler ~55 of ~1,028 atlas sub-sprites wired (~5%); other packs 3% |

Generic-core share by region (diagnostic baseline): ruin 78%, inn 59%, sewers
57%, liscor 54%, dungeon 53%, invrisil 51%, pallass 35%, floodplains 32%,
riverfarm 28%, garden 3%.

## 2. Kit model (§1; Fable: approve-with-revisions, adopted)

### 2.1 Data

`wandering_inn_game/data/kits.json` holds one kit per region plus `_common`:

```json
"invrisil": {
  "materials": {
    "floor_street": {"sheet": "res://…/tileset_marble_wang4x4.png", "tile_px": 16, "coords": [0, 0], "tone": {…}, "fallback_render": {…}},
    "wall_shop":    {"sheet": "res://…", "tile_px": 16, "cap": [14, 6], "face": [14, 7], "fallback_render": {…}}
  },
  "roles": {
    "door_street": {"pick": "door", "pool": ["invrisil_door_oak", "invrisil_door_glazed"]},
    "cargo":       {"pick": "cell", "pool": [["parcel_stack", 3], ["crate_iron_bound", 2], ["crate_lidded", 2], ["barrel_hooped", 1]]},
    "seating":     {"pick": "map",  "pool": ["chair_turned", "bench_carved"]},
    "facade_window": {"pick": "cell", "module": true, "pool": ["upper_window_a", "upper_window_shutter", "upper_window_box"]},
    "lamp":        {"pick": "map", "pool": ["street_lamp", "street_lamp_bracket"], "light": {"color": [1, 0.85, 0.5], "energy": 0.9, "radius": 32}}
  },
  "cast": ["townswoman", "human_laborer", "city_scribe", "invrisil_lady_client", "city_runner"]
}
```

Sprite ids above are illustrative. Real pools come from `fill_kit` (§4.2). A
role value is either a plain string (one sprite) or a pool object. Pool
entries take the form `id` or `[id, weight]`. A role may carry a default
`light`, which a placement's own `light` overrides. Enemy pools are deferred;
the format has no key reserved for them.

### 2.2 Binding and references

- A map's kit is its region folder (`data/maps/<region>/`). An optional
  top-level `"kit"` overrides it.
- References are opt-in, one row at a time, and never bulk-converted by
  sprite id:
  - decor and entity sprites: `"sprite": "@cargo"`;
  - floor layers, walls and wall segments: `"material": "@floor_street"`.
- An explicit `sprite` or material field always wins.
- A role or material missing from the region kit falls back to `_common`. If
  `_common` lacks it too, that is a hard assert at compose time.
- **Materials supply the look and maps keep the geometry.** The merge fills
  only absent fields: `sheet`, `tile_px`, `coords|variants`, `tone`,
  `wang_corners`, `cap/face` and `fallback_render`. `cells`,
  `terrain_lower_cells`, `from/to` and `band_rows` stay authored.
- No references are allowed on:
  - entities with `visual_states` (world.gd:1432 overrides `sprite` per state);
  - arenas;
  - named NPCs;
  - rows whose text names a specific look (§3.4).

### 2.3 Biomes stay the single owner of blocked cover

Kits do not carry blocked-cell fill, because blocked cover feeds both the field
(world.gd:979) and the combat board (board_renderer.gd:266). New
`data/biomes.json` rows fix the borrowing of the inn look: `riverfarm_interior`,
`liscor_civic`, `invrisil_shop` and `pallass_interior`.
- They copy `inn`'s simulation fields (`footstep_family`, `interior_flavor`,
  `fallback_render`).
- They carry regional render fields and `blocked_props`.
- Each gets an entry in `BIOME_DEFAULT_AMBIENCE` (world.gd:76-101).
- They use already-owned fallback tiles.

The `BIOME_DEFAULT_AMBIENCE` entry for each new row is a copy of `inn`'s.

### 2.4 Anonymous townsfolk

Anonymous extras' names describe their costumes ("A Rose-Cloaked Shopper"), so
**they get no runtime pick**. Each kit lists the `cast` of allowed anonymous
rigs, and tint stays authored per entity. Lint enforces two rules:
- an `npc` whose `display_name` begins with "A " or "An " must use a sprite in
  the region `cast` ∪ `_common.cast`;
- no named NPC may use a cast rig.

`garuda_runner` joins the Pallass cast. `wool_trader` and `dullahan_examiner`
stay explicit.

### 2.5 Resolution

`WISceneCatalog._compose()` (src/core/scene_catalog.gd:24-33) resolves
references beside `_expand_talk_banks`.
- The world, the simulation, the QA driver and saves see concrete ids; saves
  store no sprite ids.
- Compose writes `sprite` (the picked id) and `sprite_role`.
- The kits cache joins the reset list (pattern at sprite_registry.gd:20-27;
  covered by test_reload_caches.gd).
- There is no runtime randomness.

## 3. Within-region variation (§1b; Fable: sound with rules, adopted)

### 3.1 Kind vs variant

A role names a **kind**. Its pool holds 4–8 **variants**, which may differ in
silhouette detail (banding, lid, stacked, open, sacks on top). **No variant may
read as a different kind**; for example, a cargo variant must never resemble
the tagged cargo pallet.

### 3.2 Pick algorithm

Picks are edit-stable: they depend only on (map, role, cell), never on array
order.

`H` is the first 32 bits of SHA-256 over the UTF-8 key
`"%s|%s|%s[|%d,%d]" % [map, role, variant(, cell.x, cell.y)]`:
- GDScript: `key.sha256_text().substr(0, 8).hex_to_int()`;
- Python: `int(hashlib.sha256(key.encode("utf-8")).hexdigest()[:8], 16)`.

The two were verified identical on 2026-10-08, including non-ASCII keys, and
the parity test pins them. *Not* `String.hash()`: djb2 is linear, so a shared
suffix (the cell) shifts every variant's hash by about the same amount, and
picks collapse to a few patterns. The Task 2 review measured 3 of 24 rank
orders over a 40x30 map and identical subsets on all 12 map ids. The weighted
rendezvous score is `-ln((H + 0.5) / 2^32) / weight`, and the k **smallest**
scores win.

1. **Map subset:** take the `k` pool variants with the smallest variant-key
   score, using weighted rendezvous. `k = min(|pool|, 2 + n_map_role // 6)`,
   with a floor of 2 and a cap of 4. Adding a pool variant evicts at most one
   incumbent per map.
2. **Per-placement rank:** `rank_p` is the subset sorted by placement-key
   score, ascending, with ties broken by variant id.
3. **Resolve:**
   - Visit placements in `(y, x)` cell order.
   - Take the first `rank_p` entry not used by an already-visited same-role
     placement within radius `r`. `r` is 2 for props, 1 for `module` roles
     (facades, windows) and 0 for doors.
   - If no entry qualifies, fall back to `rank_p[0]`.

   An edit therefore changes only cells within `r`, plus any contiguous chain
   of forced fallbacks. The exception is when a role's placement count in a
   map crosses a multiple of 6: k changes, the subset grows, and picks can
   shift across the whole map.
4. **`pick` modes:**
   - `"cell"` runs steps 1–3.
   - `"map"` takes the subset's top-ranked variant for the whole map, so a
     room's chairs match.
   - `"door"` is described in §3.3.
   - A plain string is a fixed sprite.

### 3.3 Doors

The door family applies only to `kind: "door"` entities that have a `to_map`.
- The family has 2–3 variants on a shared frame and material.
- The pick is seeded on the unordered portal pair `{map, to_map}`, so both
  sides of a portal match. The seed is the pair, not the cell, so every portal
  between the same two maps shares one variant.
- Lint requires family members to share a rendered footprint within ±2px,
  anchor `[0.5, 1.0]` and `shadow`.
- Story and special-function doors ("The Barred Rear Door") stay explicit.

### 3.4 Conversion rules

- `"sprite": "@role"` is itself the conversion marker; there is no heuristic
  rewrite.
- Each role has a word denylist checked against `display_name` and `observe`
  (`@cargo`: `tray|paper|bale|sack|dock|yoke|stash|nook|vantage|satchel`).
- The 18 `crate` stand-ins get dedicated sprites, from the pool first and
  otherwise via the generation list.
- Story-specific props stay explicit: Pallass `wool_bale_stack`, which must
  stay off the wool trader's cardinal axes, and quest crates.

### 3.5 Python mirror

`scripts/wi_kits_lib.py` is owned by lane A. It loads kits, validates
references and computes the reference pick for lint and `fill_kit` previews.
**Lint never chooses art.** It only checks and reports the same picks Godot
makes, and a parity test pins the two together.

## 4. Pool-first supply pipeline (§2; Fable: approve-with-revisions, adopted)

### 4.1 Lane B: slice atlases into individual sprites

`tools/slice_atlases.py` processes each static multi-sprite pack atlas. It skips
animation strips (`*-Sheet.png`) and tileset, wang or terrain sheets.
- **Grid-first:** many Pixel Crawler sheets use a 16px grid, e.g. Furniture.png
  at 800x864.
- **Packed sheets:** components are split on outline-colour seams, not alpha
  alone. The `crate._comment` (#398) records two crates and a barrel fusing into
  one alpha component.
- `--split` manual overrides are recorded per slice.
- Byte-identical sheets are deduped by content hash; `Free Pack` and
  `Free Pack 2.1` are identical.
- Slices get a `has_shadow` tag, because Cemetery ships `Shadows.png`
  separately.
- **Output (untracked):**
  - each sprite as a trimmed PNG at
    `potential_assets/_sliced/<pack>/<sheet-stem>/<sheet-stem>__x736_y73_w16_h23.png` (a top-level `_sliced/` root, because some pack folders are read-only on disk);
  - `SLICES.json` in the standard MANIFEST schema
    (`assets[{path, kind, targets, verdict, notes, source_sheet, region, sheet_sha256, method}]`);
  - a numbered contact sheet.
- The stable key is (sheet sha256, x, y, w, h).
- **Labeling:**
  - A vision subagent labels the numbered contact sheets with a closed
    vocabulary of about 15 kinds (crate, barrel, sack, door, window, lamp,
    table, seat, shelf, bed, plant, rock, debris, tool, sign) plus size class
    and confidence, at about 100k tokens.
  - The ~55 already-wired regions serve as the accuracy check.
  - Labels land in `targets`.
- **Tool changes:**
  - `tools/asset_candidates.py` `find_batches` (:426) accepts `_sliced/` with
    tier `pack-bundle`, family via `pack_family`.
  - `tools/asset_index.py` excludes `_sliced/` to avoid double counting.
  - `tools/find_asset.py` works unchanged.

### 4.2 Lane C: wiring

`tools/wire_asset.py <candidate…> [--dry-run]` is idempotent. For each
candidate:
- **Owned PNG:** copied to `assets/sprites/<id>/`, with provenance appended to
  `assets/LICENSES/v019-owned-art-provenance.txt`.
- **Pack slice:** a `region` row on the **already-bundled** pack sheet. Loose
  pack copies are never written into `assets/`. A pack sheet that isn't bundled
  yet gets one sheet-level `assets_manifest.json` row. Provenance records the
  source sheet and region from `SLICES.json`.
- The anchor's feet plane comes from `scripts/sprite_alpha_probe.py`, and frame
  size and count come from the sheet's dimensions.
- It writes the `sprites.json` entry and the frame-count pin, then regenerates
  `docs/asset-candidates.*`.
- Pack variants require a `fallback_sprite`. **Each pool's set of public
  fallbacks contains at least 2 distinct owned sprites**, so the public build
  does not collapse a pool into one sprite.

The frame-count pins move to `qa/fixtures/sprite_frame_counts.json`. It is
generated once from `_build_expected_counts` (tests/test_sprite_registry.gd:254)
and keeps the fail-on-missing-key contract (:23-24). `wire_asset` writes new
rows, and the test still compares them against real `SpriteFrames`.

`tools/fill_kit.py <region> <role> --need N` works pool first.
1. Query owned and sliced candidates by kind.
2. Filter by size class, license tier and verdict; REJECTED is never eligible.
3. Render a contact sheet at gameplay scale beside the region's materials.
4. Hold the **pool art-direction read** (§5.2).
5. Select under best art wins; close calls go to CHOICE-LOG.
6. Wire the selection and update `kits.json`.
7. If fewer than N variants qualify, append a row to
   `docs/art-generation-list.md`; nothing is generated.

Default N is 4. Doors and `module` roles use N=2–3.

### 4.3 Generation list

`docs/art-generation-list.md` has these columns: region · role · have (ids) ·
need · what the pool lacked · base sprite for PixelLab object-state variants ·
status. Generation runs only as a user-approved batch (Phase 3).

## 5. Gates and QA (§3; Fable: approve-with-revisions, adopted, plus the user's art-direction gate)

### 5.1 Metric gates (data_lint, required CI job, ci.yml:77)

- **G1 repetition.**
  - Every role with ≥5 placements in a region has a pool of at least 3
    variants.
  - For each (map, role), the most-used variant appears at most
    `ceil(n / k) + 1` times, where k is the subset size actually used.
  - Each region reports **conversion coverage**: explicit ids remaining for
    kinds that have a pool.
- **G2 identity (primary).**
  - In converted regions, at least 50% of placements use a variant found in no
    other region. Kinds in `_common` are excluded.
  - Each converted map's floor and blocked materials are exclusive to its
    region.
  - Generic-core share and `scene_dynamism`'s Jaccard
    (`wandering_inn_game/tools/scene_dynamism.gd`: `_score_distinctiveness`
    :651, `_jaccard` :567) stay diagnostics.
- **G3 ratchet.**
  - `qa/baselines/scene-repetition.json` freezes each sprite's generic-or-not
    class and ratchets per-region counters, with a tolerance of +1 placement or
    +2pp.
  - Maps missing from the baseline are advisory.
  - The baseline is regenerated only via an explicit flag plus a CHOICE-LOG
    line.
- **G4 clutter.**
  - On a conversion PR, each map's multiset of (layer, cell), `blocked`,
    `walls` and scatter density must stay identical; only sprite, material and
    tint fields may change.
  - The "3+ decor on one cell" rule (scene_dynamism.gd `_score_clutter` :759)
    becomes a hard lint.
- **G5 public build.**
  - `qa/check_fallback_boot.sh` runs explicitly and is logged in each PR,
    because no CI job calls it.
  - `scripts/ship_asset_scan.py` runs on the overlay at each region close.

### 5.2 Art-direction gate (blocking; the user's requirement)

Metrics are necessary but never sufficient. **A region closes only on a passing
holistic read.**

**Owners:**
- `fill_kit` step 4 runs the pool read.
- The lane converting a map runs the scene read before opening its PR.
- The reader is a Fable agent and is **never the implementer of that PR**.

Visual findings follow wi-machine-playtest conventions: overlay off,
`docs/VISUAL-LOG.md` rows, preserving `qa_output` and the prepared-save line.
This section adds only what is specific to kits.

- **Pool read (at selection):** a Fable agent reads each role's candidate
  contact sheet at gameplay scale beside the region's materials. It checks:
  - style coherence across mixed sources (PixelLab next to Pixel Crawler);
  - that no variant reads as another kind;
  - apparent pixel size, outline and light direction.

  Incoherent candidates are dropped before wiring.
- **Captures (per converted map):** one QA script per converted map,
  `qa/scripts/kits_<region>_<map>.json`.
  - It walks the same route and camera on main (before) and on the branch
    (after).
  - Each `screenshot` step is named `kits_<region>_<map>_<build>_<phase>_<view>`:
    - build: `official` or `public`;
    - phase: `day`, plus `dusk` or `night` where the map has phase ambience;
    - view: `arrival`, `landmark` (unoccluded) or `focus` (one interaction),
      always with the full HUD.
  - Copy the shots out of `qa_output/<script>/`, which the next run
    overwrites, into untracked `qa_output/kits/<region>/{before,after}/`.
  - The gallery is attached to the PR with `gh`, **not committed**.
  - At region close, a **region strip** places the converted region's arrival
    views beside two neighbouring regions.
- **Scene read:** a **fresh** Fable subagent reads the captures. Its prompt
  contains only:
  - the rubric;
  - the region's direction section;
  - the paths to the after-shots and the strip.

  It gets **no G1–G5 output and no before-shots.** That is how the blindness is
  enforced; before-shots and metrics enter only at reconcile. The rubric is the
  visual-grammar table and the region's direction in
  `docs/design/2026-10-05-holistic-art-review.md`, plus these checks:
  - Does the region read as itself at a glance (strip)?
  - Is there visible repetition, or confetti noise?
  - Does the ground take the lowest contrast?
  - Do interactive things read as interactive, and does decorative brightness
    avoid imitating actionable feedback?
  - Do doors read as doors?
  - Is style coherent across sources?
  - Are anchors, crops and scale consistent?
  - Is there one focal structure per composition?

  The output is one line per view:
  `<capture name> | PASS|FIX|REJECT | sprite_id | cell | problem | proposed fix`.
  - FIX and REJECT lines are appended to `docs/VISUAL-LOG.md` as `(P1)` rows
    and closed in the fixing commit.
  - Only the views that were fixed get re-captured and re-read.
  - **No region closes with an open FIX or REJECT.**
- **Reconcile:** a follow-up message to the reader adds the before-shots and
  the G1–G5 output.
  - If the read fails but the metrics pass, the read wins.
  - If the read passes but a metric fails, question the metric and record the
    ruling in CHOICE-LOG.
- **User eye-gate:** a prepared save at `qa/playtest_saves/<date>-kits-<region>`
  plus the before/after gallery, with a "load X, do Y, judge Z" line. Taste
  calls beyond the rubric go to the user.
- **Cost (to be recalibrated in the pilot):** Invrisil 1a is 3 maps × 2 builds
  × up to 2 phases × 3 views, about 36 after-shots plus the strip. With about
  6 pool reads, that comes to roughly 150–200k Fable tokens per region before
  any re-capture rounds.

### 5.3 QA

- A Godot ↔ Python parity test resolves every map in both and compares.
- Entity pins on converted maps assert `sprite_role`: the emitter
  (world.gd:1397-1405) adds `sprite_role`, and `payload_contains` is a subset
  match. The key `role` stays free for NPC jobs.
- Decor emits no per-row event (world.gd:1201-1210). Add one per-map aggregate
  `ui_decor_rendered {map, roles: {role: [variants]}}`.
- `--touching` sweeps cover the affected `full` scripts, and
  `qa/journey_gate.py --only` runs the affected journeys before merge.
- Expected churn for Invrisil: one sprite pin
  (`qa/scripts/stationer_room_loop.json:29-36`), zero fixtures, ~43 scripts to
  re-run and 5 journeys.
- `extract_prose` treats `sprite` as non-prose (qa/scripts/extract_prose.py:274). **Never
  re-sort map rows**, which keeps the prose baselines stable.

## 6. Rollout

| Phase | Work | Exit |
|---|---|---|
| 0 (parallel lanes) | **A, code:** scene_catalog resolver, `sprite_role`, `scripts/wi_kits_lib.py`, data_lint kit rules and G1–G5, emitter `sprite_role` + `ui_decor_rendered`, biome rows. **B, supply:** slice_atlases, labeling, asset_candidates/asset_index changes. **C, wiring:** frame-count fixture migration, wire_asset, fill_kit, generation list | Fixture migration landed. The parity test resolves every map in both runtimes with identical `(map, cell, sprite_role, sprite)` sets and runs in the units sweep. Slices are indexed with ≥90% kind agreement on the ~55 wired regions, and every miss is listed in `SLICES.json` `notes`. Existing maps are unchanged (no references yet) |
| 1a | **Invrisil streets** (boulevard, cross_street, mercantile_alleys): street floor material, transit-door family (8 doors), facade modules (16+16), lamps (8), cargo pool, street stand-ins | G1–G5 green, art-direction gate passed, QA green, user eye-gate |
| 1b | **Invrisil interiors:** `invrisil_shop` biome row and materials, cast for the anonymous NPCs, interior stand-ins (enchanter tray, stationer paper, factor bale) | Same as 1a |
| 2 | One PR per region in this order: Liscor → ruin/dungeon/sewers → inn → Riverfarm (`riverfarm_interior`) → Pallass (keep the wool constraints; canonicals `pallass_peek` market 29 / forge 21 and `pallass_row_help`) → floodplains → garden | Same as 1a for each region |
| 3 | Generation batch from `docs/art-generation-list.md` after user approval; fold results into the pools | Same as 1a for the touched regions |

The lanes own disjoint files:
- **A:** `src/core/scene_catalog.gd`, `scripts/data_lint.py`,
  `scripts/wi_kits_lib.py`, `src/world/world.gd` (emitter), `data/biomes.json`.
- **B:** `tools/slice_atlases.py`, `tools/asset_candidates.py`,
  `tools/asset_index.py`, and untracked `potential_assets/`.
- **C:** `tools/wire_asset.py`, `tools/fill_kit.py`,
  `tests/test_sprite_registry.gd`, `qa/fixtures/`.

C imports A's `wi_kits_lib`. Coordinate with any active lane before converting
a map it touches; this was cleared on 2026-10-08, when every map was free.

Decisions are logged to CHOICE-LOG under wave autonomy. The user sees the
eye-gates and region closes.

**Plans.** This spec gets three implementation plans:
1. Phase 0 foundations: lanes A, B and C in parallel, with the fixture and
   parity exits.
2. The Invrisil pilot (1a + 1b): the first full run of §5.2. It recalibrates
   the rubric and its cost before any other region converts.
3. A per-region checklist template for Phase 2.

Phase 3 is gated separately, on user approval of the generation list.

## 7. Diagnostics

`tools/asset_usage.py` productizes the 2026-10-08 audit and writes
`docs/asset-usage.md` at each region close.
- v1 uses exact, frame-tile and provenance-UUID matching only; silhouette
  matching is deferred.
- It reports PixelLab per candidate and pack art per slice.
- It reports only and is never a gate.

## 8. Out of scope / follow-ups

- Enemy rosters and combat-arena kits: a future spec.
- Deriving `scene_dynamism` REGION_GROUPS from folders: follow-up issue (its
  report has been stale since 2026-08-03).
- Migrating the existing ~55 region registrations to slices: not needed.
- The 59 code-drawn icons with READY PixelLab replacements: a separate icon
  drain. Kits do not cover icons.

## 9. Risks

| Severity | Risk | Mitigation |
|---|---|---|
| High | Wrong-kind art under prose (a crate drawn under "paper") | Opt-in per row; denylist lint; stand-ins get dedicated sprites |
| High | Scenes pass the metrics but look bad | §5.2 blocking art-direction gate; the read beats the metrics |
| High | Style clash between mixed sources in one pool | Pool read before wiring; best art wins |
| Medium | Slicing mis-cuts (#398 class) | Grid-first, seam split, overrides, label check against wired regions |
| Medium | Fixture missing-key hang blocks wiring PRs | The fixture migration is the Phase 0 exit |
| Medium | Ratchet blocks unrelated PRs | Frozen classes, tolerance, unlisted maps advisory |
| Low | Prose baseline churn | Never re-sort map rows |
