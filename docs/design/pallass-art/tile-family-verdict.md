# PALLASS — engineered-masonry tile family: FINAL VERDICT (8e Phase A, 2026-07-12)

Ratifies the tile family for both Pallass tiers per plan Task A1
(`docs/superpowers/plans/2026-07-12-8e-pallass.md`). This is a
**verdict + asset-landing** pass only — `biomes.json`/`skeleton_scene.json`
wiring stays Phase B's (file-ownership contract, plan §Phases).

## In-hand-packs-first check (BINDING discovery workflow, re-verified)

Independently re-checked `docs/asset-catalog.md` + `docs/asset-index.md`
against the three candidate industrial/engineered packs already in hand
(Castle, Cave, Forge) before accepting any generated tileset:

- **Pixel Crawler — Forge 1.2** (`docs/asset-catalog.md` line ~341-348):
  catalog's own read is "dwarven-foundry hellscape... reads industrial
  fire dungeon", dark RED BRICK walls (not slate), warm palette
  throughout. `picks.md` §1 confirms via PIL scan: dark brick fill
  `rgb(41,16,19)` (maroon), molten fill `rgb(246,85,16)`. **Fails
  quarantine outright as a market-tier source** — its whole sheet is
  warm/red, the nearest-collision risk to Liscor's amber. Usable only
  as a **forge-tier bundle-tier reinforcement** (below), never primary,
  never on the market tier.
- **Pixel Crawler — Castle Environment 0.3** (catalog line ~292-300):
  catalog's read is "dark, regal stone interior... red carpet, purple
  banners... diagonal blue-grey checkered floors". Only the checkered-
  floor family (a small interior-floor alt, `picks.md` §2,
  `rgb(35,44,59)`) is cool/slate-adjacent; the pack has no wall/parapet/
  facade system and no bronze trim vocabulary at all — an interior
  floor alt only, not a tile FAMILY (no walls, no edge tiles, no
  elevator/lamp/board props).
- **Pixel Crawler — Cave** (catalog line ~302-310): "organic cavern...
  mossy green floor... distinctly living cave, not worked stone" — the
  opposite of "engineered, not laid" (bible's own PALLASS discipline).
  Dark-fill candidate only (`picks.md` §3), and even that leans
  warm-olive vs the ratified cool navy.
- **Conclusion: no in-hand pack offers a full engineered bronze-slate
  masonry family** (floor + rising wall + parapet edge + matching
  props). Confirmed independently, matches the 2026-07-07 pallass-art
  lane's own finding (`docs/design/pallass-art/picks.md` role note:
  "Drake-scale industrial masonry doesn't exist in any in-hand pack").
  In-hand packs genuinely fail — `/create-tileset` is warranted.

## `/create-tileset` history: NOT a third attempt

The task brief's general caution ("parked after 2 failed experiments —
a third attempt needs a materially different prompt strategy") does
**not** describe Pallass's own history. Pallass's `/create-tileset` was
run exactly twice by the 2026-07-07 pallass-art direction lane, and
**both succeeded with a KEEP verdict**
(`docs/design/pallass-art/pixellab-batch.md` #1 and #6):

| Candidate | Tier | Verdict |
|---|---|---|
| `tileset_slate_over_void` | market | **KEEP** — engineered slab grid, bronze-trimmed parapet edge, cool navy void with faint glints |
| `tileset_brick_over_molten` | forge | **KEEP** — dark charcoal-navy brick (stays in the slate field, not warm), molten channel via Wang edges |

This is exactly the plan's "cap at 2 candidates" — already spent, both
kept. **No third `/create-tileset` attempt is warranted or needed.**
Visual re-confirmation this pass (mockup + atlas PNGs viewed directly,
not text-guessed): the composed two-tier mockup
(`docs/design/pallass-art/mockup_owned_pallass_two_tiers_4x.png`) reads
as an engineered vertical machine — blue-grey slab plaza, bronze
riveted elevator tower spanning both bands, steady white crystal lamps,
an orange furnace-glow band overhead. Zero amber, zero coin-gold
anywhere in frame.

## Quarantine reasoning (re-confirmed against both other cities)

Full argument already carries in `direction.md` §Palette — restated
verdict-level here since this is the binding check:

- **Bronze (`#A66A33`/`#C98A4B`/`#6E4520`) vs Liscor amber
  (`#F2B450`)**: different ROLE (bronze = a material bolted to slate;
  amber = a light glowing in air) and different temperature FIELD
  (bronze sits on cool 214° slate; amber floats over warm 34-37°
  browns). **Pallass lamplight is steam-white (`#E9EEF2`), never
  amber** — the single check every future screenshot must pass.
- **Bronze vs Invrisil coin-gold (`#E3B341`)**: coin-gold is yellower
  (42° vs 29°) and brighter (V89 vs V65) — mint coinage on pale marble
  vs industrial alloy riveted to dark slate. Field contrast alone
  separates them at 16px.
- **Furnace glow (`#F65510`) scoping**: forge tier ONLY, always a
  LIGHT (PointLight2D on molten channels/furnace mouths), never a trim
  color, never present on the market tier. Nothing flickers unless
  it's a forge (steady crystal lamps everywhere else).
- Generated slab family runs slightly lighter/bluer than the ratified
  slate row (`#39424E`) and the generated molten leans yellower than
  `#F65510` — both flagged already in `direction.md`/`pixellab-batch.md`
  as mood-tint-at-wiring items, not quarantine failures (neither drifts
  toward amber or coin-gold; they're brightness/hue nudges within the
  Pallass family).

**Verdict: PASS.** The family is quarantine-safe as generated.

## Committed assets (TIER-PUBLIC, direct commit — the relc precedent)

PixelLab outputs are user-owned + redistributable per PixelLab ToS
(`assets/LICENSES/pixellab-ai-generated-verdict.md`). Promoted from the
gitignored cache (`potential_assets/pixellab_2026-07-07_pallass/`,
generated by the 2026-07-07 pallass-art lane, zero new generations this
pass) to committed files:

| Committed path | Source | Notes |
|---|---|---|
| `assets/tiles/pallass/tileset_slate_over_void_atlas.png` | `tileset_slate_over_void_0.png` (quantized) | 64×64 = 16 Wang tiles of 16px, row-major |
| `assets/tiles/pallass/tileset_slate_over_void_meta.json` | same job | wang-id → corners/atlas_cell/orig_pos lookup (consumed by the biomes.json wiring pass) |
| `assets/tiles/pallass/tileset_brick_over_molten_atlas.png` | `tileset_brick_over_molten_0.png` | 64×64 = 16 Wang tiles of 16px |
| `assets/tiles/pallass/tileset_brick_over_molten_meta.json` | same job | same lookup shape |
| `assets/sprites/great_lift/Idle-Sheet.png` | `prop_great_elevator.png` | 64×96, the Grand Lift landmark prop |
| `assets/sprites/crystal_lamp/Idle-Sheet.png` | `prop_crystal_lamp.png` | 32×64, steady white light post |
| `assets/sprites/steam_vent/Idle-Sheet.png` | `prop_steam_vent.png` | 32×48, ambience-emitter anchor |
| `assets/sprites/price_board/Idle-Sheet.png` | `prop_price_board.png` | 48×48, the posted-prices tell |
| `assets/sprites/forge_station/Idle-Sheet.png` | `prop_forge_station.png` | 48×64, forge-tier interactable |
| `assets/sprites/market_stall_pallass/Idle-Sheet.png` | `prop_market_stall.png` | 64×48, the uniform-stall tell |
| `assets/sprites/tier_wall/Idle-Sheet.png` | `prop_tier_wall.png` | 128×48, repeatable rising-wall/parapet facade segment |

**Scope boundary (deliberate):** this pass commits the files and
re-measures every prop's PIL alpha bbox (below, superseding
`handoff.md`'s DRAFT table with confirmed values) but does **not** add
`sprites.json` entries for the 7 props or touch `biomes.json` — prop
scale/placement wants real map context (elevator height must match
across two separate tier maps at the same on-screen x; stall rows want
the actual plaza width) that only Phase B's map-composition work can
verify, and the wi-art-and-sprites windowed-screenshot rule can't be
satisfied without a map to place into. This task's own scope (task 5)
is registry wiring for the two character rigs only. `sprites.json`
entries for the character rigs are added by this same pass (see
`character-profiles.md` move + sprites.json diff).

### Re-measured prop anchors (PIL alpha-bbox scan, supersedes handoff.md DRAFT)

| id | native size | alpha bbox | anchor (measured) | handoff.md draft | delta |
|---|---|---|---|---|---|
| `great_lift` | 64×96 | (8,9,56,87) | `[0.5, 0.9062]` | `[0.5,1.0]` | draft assumed full-bleed; real bbox has an 8px margin below the cage — corrected |
| `crystal_lamp` | 32×64 | (9,1,23,62) | `[0.5, 0.9688]` | `[0.5,1.0]` | corrected (2px margin below the post base) |
| `steam_vent` | 32×48 | (0,0,32,46) | `[0.5, 0.9583]` | `[0.5,1.0]` | corrected (2px margin) |
| `price_board` | 48×48 | (11,3,37,45) | `[0.5, 0.9375]` | `[0.5,1.0]` | corrected (3px margin below the stand) |
| `forge_station` | 48×64 | (1,0,46,62) | `[0.4896, 0.9688]` | `[0.5,1.0]` | corrected (2px margin; near-centered x) |
| `market_stall_pallass` | 64×48 | (5,1,54,46) | `[0.4609, 0.9583]` | `[0.5,1.0]` | corrected (2px margin, slight x offset) |
| `tier_wall` | 128×48 | (2,4,126,44) | default `[0.5,1.0]` kept | `[0.5,1.0]` | facade band, not a footed object — default anchor stands (tiles as a strip, not feet-planted) |

These are ready-to-paste `sprites.json` values for whichever lane wires
the props (B at map-placement time, per the scope boundary above) —
still needs the mandatory windowed screenshot once placed (ANCHOR
RULE — measurement alone is never sufficient, this table only removes
the guesswork).

## Manifest / license entries

No `assets_manifest.json` entries needed for the files above (PixelLab
outputs, TIER-PUBLIC). `assets/LICENSES/pixellab-ai-generated-verdict.md`
gets a new dated section recording this promotion (see that file's own
diff this pass). The bundle-tier licensed reinforcements catalogued in
`picks.md` (Forge molten fill, Castle slate-checker floor alt, Cave
dark-void fill) remain **not committed** — still `potential_assets/`-
only picks, consumed later only if the wiring pass wants a bundle-tier
upgrade; `assets/tiles/forge/Tiles.png` manifest entry (picks.md's
"NEW" row) stays unclaimed until that happens.

## Open items carried to Phase B (unchanged from handoff.md)

1. Band-edge rendering (Option A flat-fill vs Option B placeable Wang
   cells) — the one engine decision B's biomes.json wiring depends on.
2. Slab brightness / molten hue mood-tint nudges (flagged, not
   blocking).
3. Two-maps-vs-one-screen composite question — B's layout call.
4. Seed-label mismatch (bible "8f" vs GOAL-CHAIN "8e") — still
   unreconciled, controller's to resolve at a boundary.
