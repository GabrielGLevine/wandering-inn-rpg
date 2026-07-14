# Invrisil — licensed-pack pick tables (PIL-measured)

Method (binding, wi-art-and-sprites discipline): every region below
comes from a numeric PIL scan — 16px-cell mean-RGB/luminance-stddev/
alpha-coverage grids for tile sheets, alpha connected-component bboxes
for prop sheets. **No pack PNG was rendered into context.** These are
CANDIDATES: whoever wires a region into `sprites.json`/`biomes.json`
must confirm it with a windowed QA screenshot first (the mandatory
rule). Where a pick was additionally proven by the (gitignored)
mockup composite, it is marked **MOCKUP-PROVEN** — still not a
substitute for the in-engine windowed check.

License verdict for every row: pack-licensed, non-redistributable —
manifest-only (`bundle: true`, `fallback: "placeholder"`), never
extract/commit. All named packs are user-attested licensed
(tree-wide standing decision). `Cute_Fantasy_Free` was not used
(FORBIDDEN as source).

## 1. Boulevard facade family — `Building_Walls.png`
(Free Pack 2.1, `Environment/Structures/Buildings/Walls.png`, 672×800,
16px grid; manifest path `assets/props/free_pack/Building_Walls.png`,
already present)

| Piece | Native region `[x,y,w,h]` | cell (col,row) | Scale | Anchor | Status |
|---|---|---|---|---|---|
| Cream plaster fill (upper floor) | `[416,32,16,16]` | (26,2) | tile-fill | n/a | MOCKUP-PROVEN — flat `#ddccb8`, std 0.0 |
| Leaded storefront-glass fill (ground floor) | `[208,560,16,16]` | (13,35) | tile-fill | n/a | MOCKUP-PROVEN — reads as glass-pane wall; USE SPARINGLY (one shopfront band, not whole walls) |
| Framed plate-window bay | `[208,560,64,48]` | (13-16, 35-37) | 0.5 → 32×24 | `[0.5,1.0]` | scan-derived; overlaps the fill cell — needs windowed read to separate frame cleanly |
| Muted/shuttered window pair variant | `[288,464,96,32]` | (18-23, 29-30) | 0.5 | `[0.5,1.0]` | candidate only (grey `#606a69`/`#7a959d` family) — for alley-side backs |
| **REJECTED:** 6×7-cell "storefront modules" `[96,432,96,112]`, `[192,432,96,112]`, `[192,544,96,128]`, `[480,112,96,128]` | — | — | — | — | composed as autotile fragments in mockup v1 — do NOT wire module-sized crops from this sheet without an editor read |
| **BANNED (quarantine):** warm timber band rows 0–14 cols 0–17 (`#6d533d` family) | — | — | — | — | Liscor's material; never on an Invrisil facade |

## 2. Cornice/pilaster stone — `Wall_Tiles.png`
(Free Pack 2.1, `Environment/Tilesets/Wall_Tiles.png`, 400×400, 16px;
manifest path `assets/tiles/free_pack/Wall_Tiles.png`, already present)

| Piece | Native region | cell | Scale | Status |
|---|---|---|---|---|
| Cool blue-grey stone top-face (cornice band + pilaster strips) | `[128,32,16,16]` | (8,2) | tile-fill; pilaster = 6px-wide crop | MOCKUP-PROVEN — flat `#516467`, std 1.2 |
| Masonry face variant (textured) | `[128,272,16,16]` | (8,17) | tile-fill | candidate (`#3c484a`, std 23.7) — darker alley-wall band |
| First-try REJECT: `[32,32,16,16]` (2,2) | — | — | — | renders warm brown at composite scale (it's the inn's warm blocked tile) — wrong temperature for Invrisil |

## 3. The Brothers' parlor ("borrowed elegance")

| Piece | Sheet | Native region | Scale | Status |
|---|---|---|---|---|
| The absurdly good rug (teal+gold ornate) | Library `Assets/Tiles.png` (400×400) — manifest `assets/tiles/library/Tiles.png`, present | `[64,304,80,80]` (cells 4-8 × 19-23) | 0.5 → 40×40 (2.5 cells) | scan-derived: `#1f5b5b` flat teal field + `#869186`/`#7a7764` pale border — windowed check required |
| Warm wood floor (wealthy interior) | Library `Assets/Tiles.png` | floor cell `(23,4)` = `[368,64,16,16]` | biome tile | flat `#8c5934` — parlor floor candidate |
| Parlor wall fill (dark cellar stone) | Hideout `Assets/Tiles.png` (416×400) — manifest `assets/tiles/hideout/Tiles.png`, **NEW** | wall cell `(2,1)` = `[32,16,16,16]`; alt `(1,1)` | biome blocked | flat `#251e12`/`#1e1b12` — LOW-CONFIDENCE numerically (dark cells are ambiguous in scan); windowed check mandatory |
| Wine-purple accent (banner rags/stains) | Hideout `Assets/Tiles.png` | cells `(8,16)`–`(9,18)` family = `[128,256,32,48]` | 0.5 | `#42082a` flat wine — the shabby-sinister accent, use once |
| Card table / fine furniture / tea service | Free Pack `Furniture.png` — manifest present | existing wired `table_brown` `[?]` + candidates from blob scan: `[0,86,96,58]` (large dark furniture), `[736,165,32,27]` (grey-steel item `#373937`) | per-prop | blob scan cannot name furniture semantically — parlor dressing picks need a windowed pass; tea service queued as an owned PixelLab gen instead (pixellab-batch.md) |

## 4. Alley dressing

| Piece | Sheet | Native region | Scale | Status |
|---|---|---|---|---|
| Wall lantern pair | Sewer `Assets/Props.png` (176×256) — manifest `assets/props/sewer/Props.png`, **NEW** | `[100,5,9,20]` and `[116,5,9,20]` | 1.0 | alpha-bbox pair, plausible lanterns; known-thin-sprite risk (unlit_lantern precedent 9×14) — windowed check + consider the OWNED streetlamp scaled down instead |
| Crate stack / barrel | Free Pack `Furniture.png` | already wired: `crate` `[690,71,38,26]` @0.45, `barrel` `[730,14,19,22]` @0.7 | as wired | reuse, no new picks |
| Fence run (spec's "fence-lit" card) | Free Pack `Farm.png` (400×400) — would be NEW manifest entry | blob candidates `[273,0,127,80]`, `[288,87,45,89]` (low-solidity = post-and-rail shapes) | 0.5 | SPECULATIVE — semantics unconfirmable numerically; if the windowed read fails, drop fences (crates + lantern pools carry the maze read) and skip the manifest entry |

## 5. Counting-house interior (quest STEALTH path, stage-2 of wiring)

| Piece | Sheet | Native region | Status |
|---|---|---|---|
| Dressed-stone floor | Castle `Assets/Tiles.png` (416×400) — manifest `assets/tiles/castle/Tiles.png`, present | floor cell `(3,13)` = `[48,208,16,16]`, family cols 0-6 rows 11-16 `#5e574b`/`#61594c` | candidate |
| **BANNED (quarantine):** Castle gold-bronze trim cells cols 10-11 rows 7-10 (`#b67d46`/`#bb7e45`) | — | — | that IS Pallass's forge-bronze hue — never in Invrisil |

## Scan artifacts

Raw per-cell JSON grids for every sheet named above live at the
session scratchpad (`scans/*.json`, session-local, not tracked):
castle_tiles, fp_bwalls, fp_roofs, library_tiles, hideout_tiles,
fp_floors, fp_walltiles, fp_bprops, fp_furniture, fp_farm,
sewer_props, p16_interiors. Re-derivable in minutes with the same
16px-cell scan; numbers quoted in the tables are the load-bearing
subset. Note: `Pixel Crawler - Free Pack 2.1` was scanned (the
byte-identical `Free Pack/` dir ignored, per catalog note).
`Pixel_16_interiors_v2_free` scanned at 8px — grid remains
UNRESOLVED (200×200 doesn't factor by 16); left out of all picks.
Free Pack `Roofs.png`: the grey block at cells 17-22 × 5-11
(`[272,80,96,112]`) composed as a glass-skylight pattern, NOT slate —
REJECTED for the boulevard; Invrisil v1 postcard crops the roofline
off-frame instead (facades loom out the top of the shot).
