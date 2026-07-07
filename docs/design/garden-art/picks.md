# Garden of Sanctuary — licensed pick tables (PIL-measured)

Method per `8a-asset-assembly.md`: 16px-cell mean-RGB/luminance-std
clustering + alpha connected-component bbox extraction (scipy label).
**No pack PNG was rendered into context.** These are candidates —
whoever wires a region into `sprites.json`/`biomes.json` must confirm
with a windowed QA screenshot (wi-art-and-sprites mandatory rule).

All sources: **Pixel Crawler — Garden Environment** (licensed,
non-redistributable). License verdict for every row: `FORBIDDEN` —
manifest-only, `bundle: true`, `fallback: "placeholder"`. Sheet paths
below are relative to
`potential_assets/Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/`.

## 1. Ground: grass (`Assets/Tiles.png`, 480×480, 16px grid)

Tile-sheet rows — `{sheet, tile_px:16, floor:[col,row]}` shape, no
render_scale/anchor.

| Role | region `[x,y,w,h]` | col,row | Measured |
|---|---|---|---|
| Grass A (primary floor) | `[0,0,16,16]` | (0,0) | olive `rgb(62,74,27)` std 3.8 |
| Grass B (variant) | `[32,0,16,16]` | (2,0) | `rgb(64,76,29)` std 4.3 |
| Grass C (variant) | `[80,32,16,16]` | (5,2) | `rgb(61,74,26)` std 1.5 |
| Grass D (variant) | `[16,32,16,16]` | (1,2) | `rgb(71,80,35)` std 2.0 |
| Worn/dark grass (track option) | `[64,160,16,16]` | (4,10) | `rgb(46,48,23)` std 9.3 |

## 1b. Ground: beige sandstone path (benchmark-confirmed family)

First-pass scans misread this block as pergola wood; the benchmark's
path spine (mean `(137,119,94)`) matches these cells exactly.

| Role | region `[x,y,w,h]` | col,row | Measured |
|---|---|---|---|
| Path flat A (primary) | `[144,16,16,16]` | (9,1) | `rgb(141,121,96)` std 10.1 |
| Path flat B | `[128,48,16,16]` | (8,3) | `rgb(140,121,96)` std 12.4 |
| Path flat C | `[160,48,16,16]` | (10,3) | `rgb(139,120,95)` std 12.7 |
| Path textured | `[208,96,16,16]` | (13,6) | `rgb(134,116,94)` std 16.6 |
| Path edge/corner autotile block | cols 11–18, rows 0–7 (needs windowed decode) | — | edge cells `rgb(71,65,50)` std ~42 |

## 1c. Enclosure + parterres

| Role | region `[x,y,w,h]` | col,row | Measured |
|---|---|---|---|
| Trimmed hedge top-face (the hem / `blocked`) | `[16,128,16,16]` | (1,8) | `rgb(114,122,35)` std 26.8 (A1's pick, confirmed) |
| Flowerbed fill, magenta (primary accent) | `[16,416,16,16]` | (1,26) | `rgb(143,2,79)` — benchmark's big beds are this family tiled |
| Flowerbed fill, red (alt) | `[64,416,16,16]` | (4,26) | `rgb(144,30,9)` |
| Flowerbed fill, purple (alt) | `[112,416,16,16]` | (7,26) | `rgb(69,3,144)` |
| Fixed flowerbed plot, magenta | `[5,404,38,40]` | — | dens 1.00 (prop-style bed with edges) |
| Fixed flowerbed plot, red | `[53,404,38,40]` | — | dens 1.00 |
| Fixed flowerbed plot, purple | `[101,404,38,40]` | — | dens 1.00 |

## 2. THE FOUNTAIN COMPOSITE (resolves the 8a §5 deferral)

The sheet has **no single tiered-fountain object** — `[320,32,80,126]`
is TWO stacked basins (top `[336,32,48,40]`, large `[320,80,80,78]`),
confirmed by composing both: they read as two separate pools, not a
tiered fountain. The composite that DOES read (mockup-proven):

| Part | Source | region `[x,y,w,h]` | scale/anchor | Notes |
|---|---|---|---|---|
| Basin (large octagon) | `Assets/Tiles.png` | `[320,80,80,78]` | prop, `render_scale 1.0`, anchor `[0.5,1.0]` | 5×5-cell footprint; water fill is the flat teal `[336,112,16,16]` (A1's pick, part of this region) |
| Centerpiece statue | `Enemies/Feminine/Idle-Sheet.png` (256×64, 4 frames) | frame-0 figure bbox `[24,34,16,30]` | `render_scale 1.0`, anchor `[0.5,1.0]` (feet at frame bottom, y63/64 — NO under-feet padding) | pasted centered on the basin's upper water edge; 4-frame idle available if a "statues that move" beat ever wants it |
| Small octagon basin (separate prop: birdbath) | `Assets/Tiles.png` | `[347,5,26,23]` | `0.5`–`1.0`, windowed-check | reads as a small round basin |
| Second small pool (alt water feature, unused in card) | `Assets/Tiles.png` | `[400,2,80,94]` | — | basin+water, kept as spare |

## 3. Verticals + dressing props (`Assets/Tiles.png` component bboxes)

| Role | region `[x,y,w,h]` | dens | Measured / notes |
|---|---|---|---|
| Topiary cypress A | `[152,269,31,98]` | 0.67 | `rgb(35,58,12)` — ~2×6 cells; `shadow: true`, anchor `[0.5,1.0]` minus any skirt-pixel check (windowed) |
| Topiary cypress B | `[194,270,28,97]` | 0.79 | pair for mirroring |
| Small topiary bush | `[120,312,24,38]` | 0.54 | accent |
| Wooden bench (long) | `[67,368,74,32]` | 0.77 | `rgb(81,53,25)`; ~4.5 cells wide, side-on |
| Lily pad w/ flower | `[304,244,31,23]` | 0.82 | pond accent |
| Water rock/pool piece | `[353,244,46,42]` | 0.74 | teal `rgb(37,94,104)`; pairs with lily pad as a small natural pond |
| Stone arch/large ruin piece | `[338,388,78,92]` | 0.55 | unidentified large stone object — needs windowed read before any use |
| Small stone pieces (×4) | `[400,331,16,21]`, `[417,328,14,24]`, `[400,363,16,21]`, `[417,360,14,24]` | 0.7–0.8 | markers/rubble accents |

## 4. Garden statues (the pack's "enemy" sheets — animated stone statues)

Catalog casting note confirmed: Feminine/Masculine/Old are gender-coded/
elderly STONE STATUES (beige `rgb(~130,117,100)`), 4-frame idle, figure
16–17×28–31 in 64×64 frames, **feet plane at frame bottom (y63) — no
under-feet padding, default anchor `[0.5,1.0]` is correct** (measured,
all frames). Use as garden DRESSING statues (statue-island ponds,
path-side elders), NOT as memorial statues (memorial = owned stone-ify
roster; a licensed statue can't depict our beats and must never be
confusable with a remembrance).

| Statue | Sheet | Frame-0 figure bbox `[x,y,w,h]` |
|---|---|---|
| Feminine | `Enemies/Feminine/Idle-Sheet.png` | `[24,34,16,30]` |
| Masculine | `Enemies/Masculine/Idle-Sheet.png` | `[24,33,17,31]` |
| Old | `Enemies/Old/Idle-Sheet.png` | `[24,33,17,31]` |
| Medusa | — | **EXCLUDED** (25px-wide snake-hair crown — monster read, wrong for sanctuary) |

## Manifest entries required (controller lands; regen ignore-block after)

| Manifest path | Source | Status |
|---|---|---|
| `assets/tiles/garden/Tiles.png` | Garden `Assets/Tiles.png` | already added by A1 (8a) |
| `assets/props/garden/Feminine-Idle-Sheet.png` | `Enemies/Feminine/Idle-Sheet.png` | NEW (fountain centerpiece) |
| `assets/props/garden/Old-Idle-Sheet.png` | `Enemies/Old/Idle-Sheet.png` | NEW (dressing statue) |
| `assets/props/garden/Masculine-Idle-Sheet.png` | `Enemies/Masculine/Idle-Sheet.png` | NEW (dressing statue, mirrored pond) |
