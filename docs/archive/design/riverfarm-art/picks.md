# Riverfarm — licensed-pack picks (PIL-measured region tables)

**8b art-director lane, 2026-07-07.** Format matches
`docs/archive/design/8a-asset-assembly.md` (PIL-measured regions, feet-plane
anchors). **Method note (binding, wi-art-and-sprites discipline):** every
region below comes from a numeric PIL scan — 16px-cell mean-RGB +
luminance-std grid clustering for tile sheets, alpha connected-component
bbox extraction for prop sheets. No pack PNG was rendered or viewed.
**These are candidates, not verified picks** — whoever wires a region
into `sprites.json`/`biomes.json` must confirm it with a windowed QA
screenshot first. PixelLab-generated (owned) assets are NOT in these
tables — see `pixellab-batch.md`.

All source packs licensed (Pixel Crawler, non-redistributable; Admurin,
no-AI-training nuance) — documented only, never extracted/committed.
License verdicts: `FORBIDDEN` (public repo) / `bundle: true` throughout.

## 1. Village floor tiles (biome-level)

| Candidate | Source | Region / cell | Notes |
|---|---|---|---|
| Grass base (primary) | `topdown_floor_tiles_12/grass/grass_01.png` (540x540 whole-image tile) | n/a — whole image, `tile_px: 540` | Mean (105,144,48). Already the IN-USE floodplains floor — reuse keeps overworld continuity; village = floodplains family + field lines on top. |
| Grass variant | `.../grass/grass_03.png` | whole image | Same family, scatter variety if the biome ever supports floor variants. |
| Dirt lane | `.../dirt/dirt_01.png` | whole image | IN-USE street-biome floor — an unpaved lane in the same tile keeps "dirt road" vocabulary consistent. |
| Dirt lane alt (flat, PC16) | `Pixel Crawler - Free Pack 2.1/.../Environment/Tilesets/Floors_Tiles.png` (400x416, 16px grid) | cells (16,0)-(19,4), e.g. `[272,32,16,16]` (17,2) | Flat sandy-grey (116,105,94) std 10.2 — 5x5 plain-dirt block; cooler than dirt_01, use only if the painterly tile clashes at windowed check. |

## 2. Village water (the river) — Free Pack `Water_tiles.png` (400x400, 16px)

| Candidate | Region `[x,y,w,h]` | col,row | Notes |
|---|---|---|---|
| Water fill (primary) | `[32,112,16,16]` | (2,7) | Perfectly flat blue (62,146,209), std 0.0, alpha 1.00. Matches the farmstead benchmark's river `#3080c0` family. |
| Water fill alt (deeper) | `[112,112,16,16]` | (7,7) | Flat (65,133,202) — second 5x5 block's fill, marginally darker. |
| Animated bank edge (grass N of water) | `[32,64,16,16]` (2,4), frames at 6-col stride: `[128,64,16,16]`, `[224,64,16,16]`, `[320,64,16,16]` | (2,4)/(8,4)/(14,4)/(20,4) | Rows 0-4 hold a grass-island-in-water autotile block repeated 4x horizontally = 4 ANIMATION frames (grid-scan verified: cell (2,2) of each block is flat grass (51,117,4)). Bottom-center cell (2,4) = grass-above/water-below shoreline. Orientation/foam needs the windowed check. |

## 3. Village crops + farm props — Free Pack `Farm.png` (400x400)

Sheet layout (grid + CC scan): rows of crops in pairs — cols 0-1 hold a
2-cell-wide planted strip per crop, cols 2-10 the growth-stage
progression (sparse→full, mature at col 10). Six crop color families
top-to-bottom: orange (162,85,24), magenta/beet (151,15,73), green
(93,115,37), leaf green (77,96,34), dark green (37,72,39), teal-grey.

| Candidate | Region `[x,y,w,h]` | Proposed use | Notes |
|---|---|---|---|
| Orange crop row (mature strip) | `[0,0,32,30]` | decor prop over loam | Dens 0.95 blobs; reads pumpkin/carrot tops. Mockup-composited OK. |
| Green crop row (mature strip) | `[0,64,32,30]` | decor prop over loam; ALSO the hollow's herb rows | (93,115,37). |
| Dark-green crop row | `[0,96,32,30]` | herb-garden variant | (77,96,34). |
| Mature single plants | `[160,16,16,16]`, `[160,80,16,16]`, `[160,112,16,16]` | scatter singles | col-10 mature stage per crop row. |
| Tilled plot (licensed alt) | `[304,0,80,64]` | plot base | Ragged-edge alpha (0.31-0.98 cells) — the OWNED PixelLab loam tile (wang id 0) is the primary plot base; this is the fallback. |
| Haystack (small, licensed alt) | `[366,79,22,20]` | scatter | (117,77,21) dense golden blob; PixelLab haystack is primary. |
| Well (licensed alt, UNCONFIRMED read) | `[352,112,32,32]` | prop | Grey-green (79,91,83) — might be a well or stone trough; PixelLab well is primary. |
| Scarecrow/pole (UNCONFIRMED read) | `[288,87,45,89]` | prop | Sparse (dens 0.23) tall blob; PixelLab scarecrow is primary. |
| Cart/plow (UNCONFIRMED read) | `[128,134,48,26]` | decor | (86,81,64) — plausible cart; windowed check before casting. |

## 4. Village trees — Free Pack `Vegetation.png` (400x432)

Four color variants per shape, columns at x=3/51/99/147: green,
yellow-green, **orange, red** (autumn — the "harvest light" edge
dressing).

| Candidate | Region `[x,y,w,h]` | Proposed `render_scale` | Notes |
|---|---|---|---|
| Large tree, orange | `[99,32,42,64]` | 1.0 (2.6x4 cells) | (91,69,15); `shadow: true`, anchor `[0.5,~0.95]` (canopy overhang — measure feet plane at wiring). |
| Large tree, red | `[147,32,42,64]` | 1.0 | (92,46,15). |
| Large tree, green | `[3,32,42,64]` | 1.0 | (62,85,15) — mix ~2 green : 1 autumn. |
| Medium tree, orange | `[98,99,43,43]` | 1.0 | rounder crown. |
| Bush, green/orange | `[2,5,29,27]` / `[98,5,29,27]` | 1.0 | hedgerow scatter. |

## 5. Witch's hollow — Fairy Forest 1.7

### `Assets/Tiles.png` (208x320, 16px)
| Candidate | Region / cell | Notes |
|---|---|---|
| Underwood grass fill | `[32,32,16,16]` (2,2) | Flat (12,82,44) std 1.4 — the hollow's base. |
| Grass textured variant | `[144,144,16,16]` (9,9) | (24,70,40) std 10.3 — sprinkle ~1/7. |
| Forest path | `[144,32,16,16]` (9,2) | Flat (70,66,41) — the single winding path. |
| Pond block (composite) | `[112,192,80,80]` (cells 7-11, rows 12-16) | Water (B2/B3 teal-blue) with grass-lip ring; paste as one 5x5 unit. |
| Path edge variants | cells (7,8)-(11,11) region `[112,128,80,64]` | O2/O1 border block — windowed check for orientation. |

### `Assets/Props.png` (448x384)
| Candidate | Region `[x,y,w,h]` | Proposed scale | Notes |
|---|---|---|---|
| Glow-stone, large | `[293,0,38,46]` | **0.55-0.6** | Purple (96,61,125). At native it reads as a giant bloom next to 16px cells — mockup-verified that ~0.55 restores a "rune stone" read. |
| Glow-stones, small | `[338,16,28,30]`, `[369,20,27,26]`, `[404,22,22,24]`, `[432,28,16,19]` | 0.55 | Ritual-clearing ring pieces. |
| Glow-stone cluster alt | `[293,48,38,48]` | 0.55 | (85,63,113). |
| Mushroom cluster, green-glow | `[65,16,47,32]` | 0.5-0.7 | (23,60,30) w/ glow-green caps (13,85,47). |
| Mushroom clusters, smaller | `[117,18,40,29]`, `[160,25,30,22]` | 0.5-0.7 | scatter. |
| Stump/log, brown | `[65,64,47,32]`, `[117,66,40,29]` | 0.5-0.7 | (72,46,18) family. |
| Glow flowers, small | `[196,108,8,19]`, `[211,101,10,26]`, `[226,97,11,31]` | 1.0 | thin glowing stalks — path-side accents. |

### `Assets/Tree.png` (1248x1664) — canopy enclosure
Row sets by y: y9 bright green / y233 mid / **y457 deep-shade (primary)**
/ y681 night-purple (x<600) + night-teal (x>600). Two column sets: x<600
cool green, x>600 warm olive.
| Candidate | Region `[x,y,w,h]` | Proposed scale | Notes |
|---|---|---|---|
| Big canopy tree, deep shade | `[2,457,186,215]` | ~0.35-0.4 (→ ~4.5 cells wide) | (26,42,31) — the enclosure workhorse, ring the map edge. |
| Medium tree, deep shade | `[336,526,111,146]` | ~0.4-0.45 | variety in the ring. |
| Small tree | `[471,582,50,90]` | 0.6 | interior singles. |
| Night-teal variant | `[626,681,186,215]` | 0.35-0.4 | (29,49,52) — if the wiring pass wants phase-swapped canopy (visual_states), this is the night skin. |
| `Assets/Light.png` (208x160) | glow overlays | n/a | additive light blobs — check at wiring for the cottage window halo. |

## 6. Night wolf pack (village edge encounter) — Admurin Canines

| Candidate | Source | Frames | Notes |
|---|---|---|---|
| Wolf, gray (primary) | `Admurins_Freebies-2/Admurin's Freebies/Canines/Canine_Gray_Idle.png` (192x32) | 6 @ 32x32 | Catalog-cast "best-fitting new WI creature"; night-gated spawn per spec §5. |
| + Run/Attack/Hit/Death | `Canine_Gray_{Run,Attack,Death}.png` (192x64), `_Hit` (192x32) | 192x64 sheets = 6 frames @ 32x64 OR 3 @ 64x64 — **frame_size unverified, windowed check** | |
| Wolf, brown/black (pack variants) | `Canine_Brown_*`, `Canine_Black_*` | same | palette-swap pack of 3-4. |
| ADMURIN family rule | — | — | keep wolves in their OWN encounter (style-family discipline); fine at night grade. |

## 7. Explicitly rejected sources

- **Cute_Fantasy_Free** (`Fences.png`, `Animals/`, FarmLand tiles):
  FORBIDDEN — non-commercial license tier (charter rail). Fence gap
  closed by PixelLab gens instead.
- **Ninja Adventure `TilesetField`** (80x240): field autotiles exist but
  read peach-orange (255,172,93) not wheat-gold, and NINJA16 is an
  unverified third style family — world-layer mixing risk. Owned wheat
  tileset wins. (Ninja's animated `MillPropeller_A_64x64.png` noted as a
  possible animated-sail overlay for the windmill — style seam risk,
  queued as an option only.)
- **Free Pack Buildings Walls/Roofs**: red/green SHINGLE roofs only (grid
  scan: R2-R3 red + G2-G4 green families, no straw hue) — right family,
  wrong material for the handmade thatch identity; kept as fallback if
  PixelLab structures fail windowed review.
- **goblin-huts/watchtower** (CUSTOM-HD): skull-banner hide tents — reads
  "goblin camp," wrong for a human farming village. Not used.
