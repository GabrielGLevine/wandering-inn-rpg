# Regional kits: piece allocation (living)

> Living document. Rulings dated 2026-10-09. The sheets were bundled in `bundle-v8` (#621).

Each kept piece goes to the region where it fits best, not to whichever region asked for it first. The rulings judged each piece on its own merits against the visual grammar and region sections of `docs/design/2026-10-05-holistic-art-review.md`, the rollout in `docs/superpowers/plans/2026-10-08-regional-kits-rollout.md`, and the day context shot of every region. List rank and pack theme played no part.

A region's pool read starts here: take that region's section and the scatter lines that name it. A piece allocated to another region moves only with a `docs/CHOICE-LOG.md` ruling, and the PR that moves it updates its line here.

- **Coverage.** 238 kept pieces: 114 plants out of 334 judged, and 124 props out of 270 judged. Rejected pieces are not listed; most were tint-only duplicates, slicer composites, item-icon scale, or had no role in any region. Identity pieces (doors, lamps, sconces, windows) are ruled in their own section below. The re-intake (#624/#627) adds 380 more pieces in its own section at the end: 238 + 380 = 618 allocated pieces.
- **Bundling.** Every source sheet in the table below is bundled (the 238 earlier pieces). 114 pieces sit on five sheets that were already in the bundle, and 124 sit on the 18 sheets that `bundle-v8` added. Fetch the bundle (`scripts/fetch_private_assets.sh`) before wiring, so `tools/wire_asset.py` finds the sheet under `wandering_inn_game/assets/`. Of the 380 re-intake pieces, 284 sit on bundled sheets and 96 sit on 24 sheets that need `bundle-v9` (see Bundle needs in the last section).
- **Destinations.** `region:<region>/<role>` is one region's role. `scatter:<regions>` is ground dressing for the listed regions, best fit first. `common:<kind>` is generic utility for any region's pool.

## Source sheets

| source sheet (under `potential_assets/`) | bundled as (under `wandering_inn_game/`) | kept pieces | bundle |
|---|---|---|---|
| `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `assets/props/cave/Props.png` | 9 | before v8 |
| `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `assets/props/cemetery/Graves.png` | 6 | before v8 |
| `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `assets/props/cemetery/Props.png` | 15 | before v8 |
| `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `assets/props/fairy_forest/Props.png` | 51 | before v8 |
| `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `assets/props/fairy_forest/Tree.png` | 33 | before v8 |
| `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `assets/props/cemetery/Tree.png` | 9 | bundle-v8 (#621) |
| `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `assets/props/desert/Props.png` | 12 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `assets/props/free_pack/Building_Props.png` | 10 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `assets/props/free_pack/Dungeon_Props.png` | 8 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `assets/props/free_pack/Pan.png` | 27 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `assets/props/free_pack/Resources.png` | 11 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `assets/props/free_pack/Tools.png` | 18 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_02.png` | `assets/props/free_pack/Tree_M1_S2.png` | 5 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_03.png` | `assets/props/free_pack/Tree_M1_S3.png` | 1 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png` | `assets/props/free_pack/Tree_M1_S5.png` | 5 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_02.png` | `assets/props/free_pack/Tree_M2_S2.png` | 3 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_03.png` | `assets/props/free_pack/Tree_M2_S3.png` | 3 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png` | `assets/props/free_pack/Tree_M2_S5.png` | 3 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_02.png` | `assets/props/free_pack/Tree_M3_S2.png` | 3 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_03.png` | `assets/props/free_pack/Tree_M3_S3.png` | 3 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_04-export.png` | `assets/props/free_pack/Tree_M3_S4-export.png` | 1 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_04.png` | `assets/props/free_pack/Tree_M3_S4.png` | 1 | bundle-v8 (#621) |
| `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_05.png` | `assets/props/free_pack/Tree_M3_S5.png` | 1 | bundle-v8 (#621) |

## Totals

| destination | kept pieces |
|---|---|
| Invrisil (pilot) | 2 |
| Liscor (R1) | 11 |
| Ruin (R2) | 16 |
| Dungeon (R2) | 14 |
| Sewers (R2) | 7 |
| Inn (R3) | 17 |
| Riverfarm and the witch hollow (R4) | 49 |
| Pallass (R5) | 21 |
| Floodplains (R6) | 20 |
| Garden of Sanctuary (R7) | 12 |
| Scatter | 66 |
| Common | 3 |
| **earlier rulings** | **238** |
| Re-intake (#624/#627), last section | 380 |
| **all allocated** | **618** |

## Identity allocation (door, lamp, sconce, window)

These pieces carry a region's identity, and more than one region listed them. They were ruled on art direction alone. Paths are under `potential_assets/`; `_sliced/` paths are pack slices, and `pixellab_harvest_2026-10/` paths are owned art.

Palette cues behind the rulings:

- Invrisil: cold steel and glass with scarce gold, on pale stone and cream half-timber.
- Liscor: warm brick, timber, copper, lit amber.
- Pallass: beige stone, slate, bronze fixtures, cold white light.
- Inn: dark wood and pools of hearth light.
- Riverfarm: timber, thatch, open flame.
- Underground: dark stone that needs local value separation.

### Lamps

| # | piece | best region | runner-up | current holder keeps it? | reason |
|---|---|---|---|---|---|
| 1 | `_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x176_y451_w14_h20.png` (grey-steel lantern on a wooden arm) | Invrisil | Riverfarm | Invrisil yes, Liscor no | The arm sits on the half-timber facade and the steel reads as the city's cold metal. Nothing in it is warm, so it clashes with Liscor's brick. |
| 2 | `_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x179_y482_w9_h14.png` (grey-steel lantern, no arm) | Invrisil | Pallass | no holder | The same lantern as #1 without the arm, so Invrisil's lantern family stays consistent. |
| 3 | `_sliced/Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x210_y67_w28_h27.png` (steel wheel chandelier) | dungeon | Pallass | no holder | A hanging iron wheel reads as a trapped hall or vault. Its pale highlights give the value separation that dark rooms need. |
| 4 | `_sliced/Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x242_y106_w28_h53.png` (black candelabra on a chain, unlit) | inn | dungeon | no holder | Only reads over a light floor. Use it with a lit overlay only; otherwise skip it. |
| 5 | `_sliced/Pixel Crawler - Sewer/Props/Props__x100_y5_w9_h20.png` (copper bracket lamp, lit amber) | Liscor | inn | Liscor yes, Invrisil no | Copper and an amber pool are Liscor's palette. It is already pinned as `liscor_sconce_copper`. |
| 6 | `_sliced/Pixel Crawler - Sewer/Props/Props__x116_y5_w9_h20.png` (copper bracket lamp, unlit) | Liscor | Pallass | no holder | The unlit sibling of #5. The pair gives Liscor a day/night state. |
| 7 | `pixellab_harvest_2026-10/L2_props/oil_lamp_lit.png` (small cream oil lamp) | Riverfarm | inn | no holder | A small, warm domestic table lamp at cottage scale, which Riverfarm lacks. |
| 8 | `pixellab_harvest_2026-10/L2_props/unlit_lantern__alt4.png` (small grey tin lantern, unlit) | sewers | ruin | no holder | Reads as a maintenance lantern left on a pier, which suits the service channel. |

### Sconces

| # | piece | best region | runner-up | reason |
|---|---|---|---|---|
| 1 | `pixellab_harvest_2026-10/L2_props/sconce.png` (black iron, large cream glow) | inn | Riverfarm | The hearth look at wall scale: black iron on dark wood with a wide warm pool. |
| 2 | `pixellab_harvest_2026-10/L2_props/sconce__alt1.png` (small, white glow, orange flame) | inn | Riverfarm | The small sibling of #1 for guest-room fronts and the landing. |
| 3 | `pixellab_harvest_2026-10/L2_props/sconce__alt2.png` (iron bracket, open flame) | Riverfarm | sewers | An open torch flame reads as a working or rural light, not a hospitable one. |
| 4 | `pixellab_harvest_2026-10/L2_props/sconce__alt3.png` (twin candles) | Riverfarm | inn | Domestic longhouse light that goes with the oil lamp (lamp #7). |

### Doors

| # | piece | best region | runner-up | current holder keeps it? | reason |
|---|---|---|---|---|---|
| 1 | `_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x197_y320_w22_h32.png` (arched green double door) | Invrisil | inn | yes | A residential street door on the timber facade. It is weak as `invrisil_shop_door_2` (no glass, no sign): keep it on `door_street` and give the shop role to a glazed door (see the recut asks). |
| 2 | `pixellab_harvest_2026-10/L2_props/shopfront_door.png` (glass pane, gold knob) | Invrisil | Liscor | yes | Glass and gold on a shop door is Invrisil's brief, word for word. |

### Windows

| # | piece | best region | runner-up | current holder keeps it? | reason |
|---|---|---|---|---|---|
| 1 | `_sliced/Pixel Crawler - Free Pack/Furniture/Furniture__x132_y355_w24_h25.png` (brown-frame four-pane, blue glass) | Invrisil | inn | yes | Already on the converted boulevard's upper storey. |
| 2 | `_sliced/Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x98_y176_w28_h32.png` (grey stone arch, sky-blue glass) | Invrisil | Pallass | yes | Glass on pale stone. Pallass would be the truer home, but it does not list windows yet. |
| 3 | `pixellab_harvest_2026-10/L2_props/window_blue.png` (four-pane, drawn with a tilt) | Invrisil | inn | yes | The tilt passes on an upper storey but would look wrong on an interior wall seen head-on. |
| 4 | `pixellab_harvest_2026-10/L2_props/window_blue__alt1.png` (small four-pane) | Invrisil | inn | yes | The small variant of #3, kept in the same family. |

### Duplicate lamp rulings

- **Lamp #1** was held as both `invrisil_lamp_wall_1` and `liscor_bracket_lantern`. **Invrisil keeps it.** Liscor takes lamp #6 as `liscor_bracket_lantern`, paired with its lit `liscor_sconce_copper` (lamp #5) for the night state.
- **Lamp #5** was held as an Invrisil lamp-pool member and as `liscor_sconce_copper`. **Liscor keeps it.** Invrisil takes lamp #2 in its lamp pool.

### Reassignments still to apply

1. **Invrisil lamp-pool swap:** remove lamp #5 (`Sewer Props__x100_y5_w9_h20`) from the Invrisil lamp pool and put lamp #2 (`Furniture__x179_y482_w9_h14`) in its place.
2. **Liscor FIX loop 2:** re-pin `liscor_bracket_lantern` from lamp #1 (`Furniture__x176_y451_w14_h20`) to lamp #6 (`Sewer Props__x116_y5_w9_h20`).

After both swaps each city still has two identity lamps, neither city has a palette clash, and no new art is needed. Every door and window stays with Invrisil.

### Identity lamps per region after the rulings

- Invrisil 2 (lamps #1 and #2, plus its pinned black-and-gold street lamps). Liscor 2 (#5, #6). Inn 3 (sconces #1 and #2, and lamp #4 only with a lit overlay). Riverfarm 3 (lamp #7, sconces #3 and #4).
- Pallass 0, dungeon 1 (lamp #3), ruin 0 and sewers 1 (lamp #8). These are generation asks below.
- Floodplains and the garden list no lamp or door roles. The garden's brightness comes from the scene grade, not from fixtures.

## Invrisil (pilot): 2

A potion-shelf strip for the enchanter work room and a topiary bush for the formal planters. The bush needs a container (see the asks).

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| other#27 | `Pixel Crawler - Free Pack/Resources/Resources__x32_y0_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `shelf_potions` | 16x16 | Column of coloured bottles: enchanter work-room shelf |
| c#36 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x160_y112_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `topiary` | 31x23 | Compact clipped bush; formal planter fill |

## Liscor (R1): 11

Liscor's first window pair of its own (shutters and a grille), a timber yard gate, a civic interior door, a plank bench, the Watch and Runners' pennants, a stall pot, a street cookpot (lit and unlit) and a planter shrub. These sheets have no facade or roof modules.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| sign#4 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x96_y64_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `banner_runners` | 10x21 | Green pennant: Runners' Guild colour |
| sign#2 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x64_y64_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `banner_watch` | 10x21 | Red pennant: Watch and barracks colour |
| door#10 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x112_y0_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `door_civic` | 14x20 | Cell-scale arched door with pane: guild interiors |
| door#8 | `Pixel Crawler - Free Pack/Props/Props__x32_y20_w32_h44.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `door_street` | 32x44 | Timber-lintel open gateway for yards and barracks |
| c#27 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x112_y112_w48_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `planter_shrub` | 40x29 | Compact green bush for market planters |
| seat#2 | `Pixel Crawler - Free Pack/Props/Props__x32_y64_w32_h12.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `seating` | 32x12 | Two-plank warm bench, 2 cells; guild and street |
| container#32 | `Pixel Crawler - Free Pack/Pan/Pan__x0_y32_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `stall_pot` | 16x15 | Lidded pot for the bread stall |
| container#34 | `Pixel Crawler - Free Pack/Pan/Pan__x130_y79_w13_h17.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `street_cookpot` | 13x17 | Small street pot, unlit |
| container#35 | `Pixel Crawler - Free Pack/Pan/Pan__x144_y64_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `street_cookpot_lit` | 13x17 | Lit state of #34; matches the street brazier |
| window#6 | `Pixel Crawler - Free Pack/Props/Props__x101_y100_w22_h22.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `window_grille` | 22x22 | Mesh grille: barracks armoury and cells |
| window#2 | `Pixel Crawler - Free Pack/Props/Props__x112_y132_w32_h24.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `window_shutter` | 32x24 | Closed timber shutters on brick; Liscor has no window |

## Ruin (R2): 16

Broken masses, the excavation edge and a descent you can read: descent arch, wall stubs, a standing slab, a spoil heap, a shovel in its mound, an ore cart on rail, a dug-up coffin, a chest pair, an overgrowth mound and a dead-tree vocabulary. The ochre wall stubs need desaturating if the ruin field stays cool.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| container#6 | `Pixel Crawler - Desert/Props/Props__x97_y41_w30_h23.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `chest` | 30x23 | Wider closed chest; ochre lifts off the dark field |
| container#7 | `Pixel Crawler - Desert/Props/Props__x97_y9_w30_h23.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `chest_open` | 30x23 | Open state of #6 |
| container#3 | `Pixel Crawler - Cemetery 0.4/Props/Props__x176_y0_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `coffin` | 20x31 | Plain lidded box reads as a dug-up burial |
| a#25 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x160_y312_w46_h103.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `dead_tree` | 46x103 | Mid dead pine, pairs with #20 |
| e#20 | `Pixel Crawler - Free Pack/Model_02_Size_05/Model_02_Size_05__x192_y0_w96_h160.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png` | `dead_tree` | 87x152 | Bare conifer skeleton |
| a#20 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x0_y209_w96_h207.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `dead_tree_landmark` | 96x207 | Dead giant pine for the excavation edge |
| e#12 | `Pixel Crawler - Free Pack/Model_01_Size_05/Model_01_Size_05__x224_y0_w112_h160.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png` | `dead_tree_landmark` | 100x158 | Twisted dead tree, dig-site anchor |
| door#5 | `Pixel Crawler - Cemetery 0.4/Props/Props__x0_y128_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `descent_door` | 24x38 | Small stone arch, dark mouth: the legible descent |
| other#24 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x64_y0_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `dig_cart` | 22x18 | Tipped ore cart with pick: dig-camp kit |
| tool_a#1 | `Pixel Crawler - Cemetery 0.4/Props/Props__x128_y48_w32_h32.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `dig_shovel` | 31x32 | Shovel in a spoil mound: excavation in progress |
| a#23 | `Pixel Crawler - Cemetery 0.4/Props/Props__x64_y112_w80_h80.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `overgrowth` | 78x76 | Mustard moss mound separates from dark ground |
| other#25 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x0_y80_w64_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `rail` | 42x8 | Flat rail length; lays under #24 |
| rock#4 | `Pixel Crawler - Cemetery 0.4/Graves/Graves__x64_y96_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `slab` | 22x39 | Dark panelled slab: standing broken mass |
| debris#2 | `Pixel Crawler - Cemetery 0.4/Props/Props__x96_y64_w32_h16.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `spoil_heap` | 31x16 | Dark earth mound for the excavation edge |
| wall_module#2 | `Pixel Crawler - Desert/Props/Props__x35_y140_w26_h36.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `wall_stub` | 26x36 | Broken-top block wall; pale mass on the dark field |
| wall_module#3 | `Pixel Crawler - Desert/Props/Props__x67_y148_w26_h28.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `wall_stub` | 26x28 | Lower stub, second broken-mass silhouette |

## Dungeon (R2): 14

The seal vault and trapped halls: a vault portal arch, two pale statues on a plinth, steles and a rune stele, a chain, coffin and chest pairs, and two lit cave fungi.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| other#22 | `Pixel Crawler - Free Pack/Tools/Tools__x80_y208_w16_h64.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `chain` | 12x64 | Hanging chain with shackles; rubric names chains |
| container#4 | `Pixel Crawler - Desert/Props/Props__x129_y40_w30_h24.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `chest` | 30x24 | Closed chest, gold buckle; art for the explicit chest id |
| container#5 | `Pixel Crawler - Desert/Props/Props__x129_y8_w30_h24.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `chest_open` | 30x24 | Open state of #4 |
| container#1 | `Pixel Crawler - Cemetery 0.4/Props/Props__x112_y0_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `coffin` | 20x35 | Lidded coffin; pale planks separate on dark vault stone |
| container#2 | `Pixel Crawler - Cemetery 0.4/Props/Props__x144_y0_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `coffin_open` | 20x35 | Open empty coffin; trapped-halls dressing, pairs with #1 |
| a#2 | `Pixel Crawler - Cave/Props/Props__x80_y96_w80_h160.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `fungus_landmark` | 72x147 | Lit drip edge separates a giant silhouette in the dark |
| a#6 | `Pixel Crawler - Cave/Props/Props__x224_y96_w64_h96.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `fungus_tall` | 60x96 | Tall thin stem, distinct from the domes, lit |
| rock#1 | `Pixel Crawler - Cemetery 0.4/Graves/Graves__x32_y144_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `plinth` | 24x42 | Grey pedestal with base; carries statues at the feet plane |
| sign#1 | `Pixel Crawler - Cemetery 0.4/Graves/Graves__x37_y105_w22_h39.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `rune_stele` | 22x39 | Dark stele, red rune panels; ward marker near the seal |
| other#10 | `Pixel Crawler - Cemetery 0.4/Graves/Graves__x32_y192_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `statue` | 32x33 | Pale winged figure separates on dark stone |
| other#11 | `Pixel Crawler - Cemetery 0.4/Graves/Graves__x0_y192_w32_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `statue` | 16x34 | Hooded figure, second statue silhouette |
| other#13 | `Pixel Crawler - Cemetery 0.4/Props/Props__x64_y48_w16_h48.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `stele` | 14x34 | Thin plain stele, cell width |
| rock#2 | `Pixel Crawler - Cemetery 0.4/Graves/Graves__x68_y146_w24_h42.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Graves.png` | `stele_tall` | 24x42 | Tall pale slab, wall-height marker |
| door#2 | `Pixel Crawler - Cemetery 0.4/Props/Props__x0_y176_w64_h80.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `vault_portal` | 50x70 | Pointed stone arch, pale rim: the seal's portal frame |

## Sewers (R2): 7

Two cool grey boulders break up the repeated boulder. There is a barred arch grate for the service-channel wall, and the lit cave fungi are the only self-lit plants for [Light]-off reads. The lit-fixture gap remains (see the asks).

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| a#3 | `Pixel Crawler - Cave/Props/Props__x0_y0_w96_h96.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `fungus` | 87x88 | Already mushroom_purple_l; keep with current holder |
| a#4 | `Pixel Crawler - Cave/Props/Props__x96_y0_w96_h96.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `fungus_lit` | 87x88 | Lit state of #3 for [Light]-off reads |
| a#9 | `Pixel Crawler - Cave/Props/Props__x192_y48_w64_h48.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `fungus_lit_m` | 53x45 | Lit medium dome; day/dark pair with #8 |
| a#8 | `Pixel Crawler - Cave/Props/Props__x192_y0_w64_h48.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `fungus_m` | 53x45 | Already mushroom_purple_m; keep with current holder |
| rock#15 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x208_y224_w48_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock` | 42x40 | Grey-blue boulder; cool palette, replaces the repeated boulder |
| rock#18 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x176_y240_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock` | 28x31 | Small grey boulder; second sewer silhouette |
| window#9 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x96_y0_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `wall_grate` | 14x21 | Barred stone arch: the service-channel grate |

## Inn (R3): 17

Dressing only: a tableware pool, kitchen pans and utensils, two pots and a cell-scale plank door for `door_room`. The hearth and grill stay explicit.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| door#11 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x128_y0_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `door_room` | 14x20 | Plain cell-scale plank door: the door_room brief verbatim |
| tool_a#31 | `Pixel Crawler - Free Pack/Pan/Pan__x16_y160_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_knife` | 12x15 | Kitchen cleaver for the prep counter |
| tool_a#32 | `Pixel Crawler - Free Pack/Pan/Pan__x32_y144_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_ladle` | 7x25 | Long ladle hung by the pots |
| tool_a#14 | `Pixel Crawler - Free Pack/Pan/Pan__x0_y0_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_pan` | 24x13 | Dark frying pan for the hearth wall |
| tool_a#19 | `Pixel Crawler - Free Pack/Pan/Pan__x32_y0_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_pan_small` | 22x12 | Smaller pan; hangs below #14 |
| container#18 | `Pixel Crawler - Free Pack/Pan/Pan__x0_y80_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_pot` | 18x21 | Large open steel pot for the prep zone |
| container#26 | `Pixel Crawler - Free Pack/Pan/Pan__x16_y32_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_pot_wide` | 20x15 | Two-handled stock pot, hearth zone |
| tool_a#25 | `Pixel Crawler - Free Pack/Pan/Pan__x32_y128_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `kitchen_saucepan` | 22x10 | Lidded saucepan, red knob |
| container#40 | `Pixel Crawler - Free Pack/Pan/Pan__x128_y32_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 13x13 | Steel jug for the bar |
| container#42 | `Pixel Crawler - Free Pack/Pan/Pan__x0_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Wooden platter, table dressing |
| container#43 | `Pixel Crawler - Free Pack/Pan/Pan__x16_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Pewter plate, table dressing |
| container#46 | `Pixel Crawler - Free Pack/Pan/Pan__x64_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 8x8 | Ale mug |
| other#39 | `Pixel Crawler - Free Pack/Pan/Pan__x0_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Lidded dish, red knob |
| other#40 | `Pixel Crawler - Free Pack/Pan/Pan__x16_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Plain pewter plate |
| other#41 | `Pixel Crawler - Free Pack/Pan/Pan__x32_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Wooden bowl |
| other#42 | `Pixel Crawler - Free Pack/Pan/Pan__x48_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Bread basket |
| other#43 | `Pixel Crawler - Free Pack/Pan/Pan__x80_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `tableware` | 14x10 | Plate with a meal; the one food-bearing plate |

## Riverfarm and the witch hollow (R4): 49

The largest gap before these rulings. Pieces include pines in three sizes, a village-green canopy, a wood yard, mill machinery, barn and longhouse doors, a louvered vent and small shutters, a trough, a churn, a three-stage crop row and a berry hedge. The hollow gets a hero-trunk module (b#3 base, b#19 trunk, b#45 cap), a canopy pool, a small-tree pool, understorey, glow stones in three sizes and a lit/unlit cauldron. Hollow roles are filed as `hollow_*` because the rollout plan puts the hollow in R4.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| c#39 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x160_y16_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `berry_bush` | 30x22 | Green bush, red berries: garden-patch hedge |
| tool_a#20 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y176_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `churn` | 11x24 | Churn on a wooden stand: longhouse domestic |
| d#26 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x240_y48_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `crop_row` | 12x11 | Curled seedling: crop stage 3 |
| d#48 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x208_y0_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `crop_row` | 11x8 | Two-leaf sprout: crop stage 2 |
| d#56 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x240_y0_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `crop_row` | 10x6 | Leaf pair: crop stage 1 |
| door#4 | `Pixel Crawler - Cemetery 0.4/Props/Props__x64_y192_w32_h64.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `door_barn` | 32x60 | Strapped plank door reads as mill or granary door |
| door#9 | `Pixel Crawler - Free Pack/Props/Props__x1_y23_w30_h41.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `door_open` | 30x41 | Lighter open threshold for the longhouse |
| rock#16 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x208_y272_w48_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `glow_stone` | 42x40 | Rune-eyed boulder, cyan glow: witch-hollow glow_stone |
| rock#19 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x176_y288_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `glow_stone` | 28x31 | Rune-eyed, mid size |
| rock#21 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x160_y304_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `glow_stone` | 15x16 | Rune-eyed, cell size; completes the glow_stone set |
| a#40 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x0_y1120_w192_h224.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_canopy_tree` | 186x215 | Purple canopy; hollow magic hue, same family as #42 |
| a#42 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x0_y448_w192_h224.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_canopy_tree` | 186x215 | Already hollow_canopy_tree; keep with current holder |
| a#53 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x192_y240_w144_h208.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_canopy_tree` | 133x194 | Teal mid canopy; size step below #42 |
| b#16 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x960_y736_w112_h160.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_canopy_tree` | 111x146 | Teal canopy mid; hollow cool palette |
| e#16 | `Pixel Crawler - Free Pack/Model_02_Size_05/Model_02_Size_05__x0_y0_w96_h160.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png` | `hollow_canopy_tree` | 92x157 | Teal conifer: silhouette variety for the pool |
| b#3 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1056_y1552_w192_h112.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_giant_trunk` | 175x108 | Lit root mass; base module of a hero trunk |
| b#19 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1104_y1376_w112_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_giant_trunk` | 94x96 | Lit trunk module, stacks on #3 |
| b#45 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1104_y1488_w112_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_giant_trunk` | 94x48 | Lit trunk cap band, tops #19 |
| c#17 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x288_y0_w48_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `hollow_glow_stone` | 38x46 | Already hollow_glow_stone; keep |
| c#25 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x64_y16_w48_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `hollow_mushroom_cluster` | 47x32 | Already hollow_mushroom_cluster; keep |
| b#27 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x240_y1584_w80_h80.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_shrub` | 74x74 | Teal mass; hollow understorey |
| e#43 | `Pixel Crawler - Free Pack/Model_02_Size_02/Model_02_Size_02__x0_y0_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_02.png` | `hollow_shrub` | 45x47 | Teal conifer clump |
| b#48 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1088_y1024_w64_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_small_tree` | 50x90 | Teal slim tree; hollow pool member |
| b#58 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x464_y576_w64_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_small_tree` | 50x90 | Already hollow_small_tree/bent_tree; keep |
| c#7 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1152_y832_w48_h64.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_small_tree` | 40x59 | Teal slim tree, smaller step |
| e#31 | `Pixel Crawler - Free Pack/Model_02_Size_03/Model_02_Size_03__x0_y0_w48_h80.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_03.png` | `hollow_small_tree` | 37x76 | Teal small conifer |
| e#38 | `Pixel Crawler - Free Pack/Model_01_Size_05/Model_01_Size_05__x352_y320_w80_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png` | `hollow_stump` | 61x42 | Mossy stump; hollow green |
| b#60 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x96_y1392_w64_h64.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hollow_vine_stump` | 55x64 | Vine stump, hollow size |
| c#31 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x16_y1568_w64_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `log` | 51x19 | Fallen cut log: wood-yard dressing |
| container#30 | `Pixel Crawler - Free Pack/Pan/Pan__x112_y48_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `longhouse_pot` | 14x18 | Mid cauldron: longhouse domestic storage |
| tool_a#11 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y48_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `mill_gear` | 20x20 | Toothed wheel: visible mill machinery |
| tool_a#12 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y16_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `millstone` | 18x18 | Plain stone disc, the mill's millstone |
| a#19 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x0_y1_w96_h207.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `pine` | 96x207 | Tall green pine: northern forest-edge village landmark |
| e#3 | `Pixel Crawler - Free Pack/Model_03_Size_04/Model_03_Size_04__x0_y0_w192_h416.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_04.png` | `pine` | 192x416 | 2x2 grid of slim rooted pines; recut, red to floodplains |
| e#17 | `Pixel Crawler - Free Pack/Model_02_Size_05/Model_02_Size_05__x0_y160_w96_h160.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_05.png` | `pine` | 92x157 | Green conifer, large |
| e#25 | `Pixel Crawler - Free Pack/Model_03_Size_03/Model_03_Size_03__x0_y0_w64_h144.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_03.png` | `pine` | 63x143 | Slim rooted pine, mid |
| tool_b#4 | `Pixel Crawler - Free Pack/Tools/Tools__x64_y176_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `pitchfork` | 7x12 | Pitchfork beside the hay; one of eight tints kept |
| rock#17 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x0_y224_w48_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock` | 37x32 | Low ochre boulder |
| rock#11 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x96_y224_w64_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock_large` | 59x44 | Plain ochre boulder; river-bank landmark |
| e#35 | `Pixel Crawler - Free Pack/Model_01_Size_05/Model_01_Size_05__x128_y320_w80_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png` | `stump` | 61x42 | Rooted stump: wood-yard |
| tool_a#2 | `Pixel Crawler - Cemetery 0.4/Props/Props__x80_y48_w16_h32.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `tool_spade` | 11x31 | Standing spade for the garden patch |
| tool_a#56 | `Pixel Crawler - Free Pack/Tools/Tools__x16_y192_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `tool_trowel` | 7x13 | Trowel for the garden patch |
| b#7 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x336_y288_w112_h160.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `tree` | 111x146 | Green canopy at village scale |
| container#24 | `Pixel Crawler - Free Pack/Props/Props__x18_y160_w28_h11.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `trough` | 28x11 | Long wooden trough for the pens |
| a#39 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x0_y0_w192_h224.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `village_tree` | 186x215 | Bright green giant canopy: village green anchor |
| window#3 | `Pixel Crawler - Free Pack/Props/Props__x80_y132_w32_h24.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `window_louver` | 32x24 | Louvered vent for mill and granary |
| window#8 | `Pixel Crawler - Free Pack/Props/Props__x148_y144_w24_h16.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `window_shutter_small` | 24x16 | Small closed shutter for cottages |
| container#21 | `Pixel Crawler - Free Pack/Pan/Pan__x144_y32_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `witch_cauldron` | 16x22 | Unlit state of #20 |
| container#20 | `Pixel Crawler - Free Pack/Pan/Pan__x144_y0_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `witch_cauldron_lit` | 16x22 | Cauldron over embers: witch-hut vocabulary |

## Pallass (R5): 21

The forge gets a station: two anvils, a quench barrel, a grindstone, a tool bench, a tool wall, coal heaps, an ore crate, a dressed stone block and a crucible (lit and unlit). The market gets bronze-lidded urns, a goods basket, a jug, a slate bench and a blue civic pennant. Still missing: the cold white lamp and a stone door (see the asks).

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| tool_a#5 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y112_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `anvil` | 32x24 | Steel anvil on block; forge station anchor |
| tool_a#10 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y80_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `anvil_large` | 26x19 | Larger anvil for the forge hall |
| sign#3 | `Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x80_y64_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Dungeon_Props.png` | `banner` | 10x21 | Blue pennant marks the lift-station civic desk |
| container#28 | `Pixel Crawler - Free Pack/Resources/Resources__x16_y144_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `cargo` | 15x20 | Tall crate of ore: forge material storage |
| rock#34 | `Pixel Crawler - Free Pack/Tools/Tools__x16_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `cargo` | 16x15 | Dressed stone block |
| tool_a#46 | `Pixel Crawler - Free Pack/Tools/Tools__x16_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `chisel` | 7x15 | Chisel for the tool wall |
| rock#33 | `Pixel Crawler - Free Pack/Resources/Resources__x0_y16_w48_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `coal_heap` | 45x26 | Coal pile: forge material storage |
| rock#35 | `Pixel Crawler - Free Pack/Resources/Resources__x48_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `coal_heap_small` | 16x13 | Small coal pile beside the anvil |
| container#36 | `Pixel Crawler - Free Pack/Pan/Pan__x50_y79_w13_h17.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `crucible` | 13x17 | Small pot, unlit: forge crucible |
| container#37 | `Pixel Crawler - Free Pack/Pan/Pan__x64_y64_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `crucible_lit` | 13x17 | Lit crucible: contained molten heat |
| tool_a#13 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y160_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `forge_bench` | 20x16 | Low box with slate top: tool bench |
| tool_a#27 | `Pixel Crawler - Free Pack/Tools/Tools__x112_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `grindstone` | 14x14 | Grindstone wheel for the forge |
| tool_a#33 | `Pixel Crawler - Free Pack/Tools/Tools__x48_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `hammer` | 10x13 | Smith's hammer for the tool wall |
| container#11 | `Pixel Crawler - Desert/Props/Props__x147_y83_w10_h13.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `jug` | 10x13 | Banded jug for the den-shop counter |
| container#10 | `Pixel Crawler - Desert/Props/Props__x129_y83_w14_h13.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `market_goods` | 14x13 | Basket of cloth; wool-market dressing |
| tool_a#42 | `Pixel Crawler - Free Pack/Tools/Tools__x64_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `pliers` | 8x14 | Pliers, second tool-wall silhouette |
| tool_a#6 | `Pixel Crawler - Free Pack/Tools/Tools__x144_y224_w16_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `quench_barrel` | 13x46 | Tall water quench; blue read beside forge heat |
| seat#3 | `Pixel Crawler - Free Pack/Props/Props__x17_y132_w30_h12.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `seating` | 30x12 | Slate-grey bench on stone; parapet rest seat |
| tool_a#29 | `Pixel Crawler - Free Pack/Tools/Tools__x112_y160_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `tongs` | 14x13 | Smith's tongs on the tool wall |
| container#8 | `Pixel Crawler - Desert/Props/Props__x97_y78_w14_h18.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `urn` | 14x18 | Ochre urn, bronze lid: beige stone and bronze palette |
| container#9 | `Pixel Crawler - Desert/Props/Props__x115_y74_w10_h22.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `urn_tall` | 10x22 | Slim sibling of #8 for the market |

## Floodplains (R6): 20

`tree` gets round canopies, slim pines and a tall pine instead of `tree_big` x7. `shrub` gets six trunkless masses at two widths, and `rock` gets three boulder silhouettes. Rags's cooking cluster gets a cookpot pair and a cleaver.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| tool_a#41 | `Pixel Crawler - Free Pack/Pan/Pan__x0_y160_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `camp_cleaver` | 16x7 | Cleaver for Rags's cooking cluster |
| container#23 | `Pixel Crawler - Free Pack/Pan/Pan__x64_y32_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `camp_cookpot` | 16x22 | Unlit state of #22 |
| container#22 | `Pixel Crawler - Free Pack/Pan/Pan__x64_y0_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Pan.png` | `camp_cookpot_lit` | 16x22 | Lit camp pot for Rags's cooking cluster |
| rock#13 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x48_y272_w48_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock` | 43x46 | Mossy boulder, medium |
| rock#14 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x48_y224_w48_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock` | 43x45 | Plain boulder, medium; rock reaches 3 with #10, #13 |
| rock#10 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x96_y272_w64_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `rock_large` | 59x45 | Mossy ochre boulder; new silhouette against boulder x7 |
| b#18 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x0_y0_w64_h144.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `shrub` | 63x144 | Three round bushes stacked; recut into 3 |
| b#26 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x240_y1504_w80_h80.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `shrub` | 74x74 | Mixed green/orange mass, autumn edge |
| b#28 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x320_y1344_w80_h80.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `shrub` | 74x74 | Green leaf mass, trunkless silhouette |
| c#2 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x0_y144_w64_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `shrub` | 63x48 | Orange-brown wide mass; autumn silhouette |
| c#23 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x64_y112_w48_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `shrub` | 47x32 | Wide green bush, distinct from bush_green |
| c#24 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x64_y160_w48_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `shrub` | 47x32 | Wide orange bush; autumn pair of #23 |
| a#22 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x96_y50_w64_h157.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `tree` | 64x157 | Green pine, tall silhouette the pool lacks |
| a#52 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x192_y16_w144_h208.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `tree` | 133x194 | Green round canopy, large |
| b#50 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1088_y128_w64_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `tree` | 50x90 | Yellow-green slim; autumn-lit variant |
| e#7 | `Pixel Crawler - Free Pack/Model_01_Size_03/Model_01_Size_03__x0_y0_w96_h192.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_03.png` | `tree` | 96x192 | 2x2 grid, 48x96 round trees at native scale; recut |
| e#8 | `Pixel Crawler - Free Pack/Model_01_Size_05/Model_01_Size_05__x0_y0_w112_h160.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png` | `tree` | 106x160 | Large green round canopy, tree_round family |
| e#9 | `Pixel Crawler - Free Pack/Model_01_Size_05/Model_01_Size_05__x0_y160_w112_h160.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_05.png` | `tree` | 106x160 | Large orange autumn canopy |
| e#27 | `Pixel Crawler - Free Pack/Model_03_Size_03/Model_03_Size_03__x64_y0_w64_h144.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_03.png` | `tree` | 63x143 | Olive slim pine, autumn |
| e#28 | `Pixel Crawler - Free Pack/Model_03_Size_03/Model_03_Size_03__x64_y144_w64_h144.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_03.png` | `tree` | 63x143 | Red slim pine, autumn accent |

## Garden of Sanctuary (R7): 12

A pink blossom canopy at three sizes and a sparse purple tree, so the pocket is not eight copies of one tree. The purple trumpets are the luminous plant. Hedge breaks and vines add vertical interest. No props: the memorial plinths stay explicit.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | reason |
|---|---|---|---|---|---|
| c#13 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x336_y64_w64_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `blossom_purple_cluster` | 62x32 | Purple trumpets, glowing stamens: luminous plant |
| c#14 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x288_y48_w48_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `blossom_purple_large` | 38x48 | Single large purple trumpet, hero bloom |
| c#33 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x336_y16_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `blossom_purple_small` | 28x30 | Small purple trumpet, cell scale |
| b#10 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x336_y736_w112_h160.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `blossom_tree` | 111x146 | Pink canopy, mid size |
| a#43 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x0_y672_w192_h224.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `blossom_tree_landmark` | 186x215 | Pink canopy giant for the planted-shelter pocket |
| b#59 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x464_y800_w64_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `blossom_tree_small` | 50x90 | Pink slim tree, small step of the family |
| a#37 | `Pixel Crawler - Desert/Props/Props__x0_y262_w64_h74.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `blossom_tree_sparse` | 64x74 | Pale bark, purple tufts: second purple silhouette |
| c#32 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x336_y112_w32_h48.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `climbing_vine` | 22x42 | Slim vine with gold flower, wall climber |
| b#25 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x240_y1424_w80_h80.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `flowering_shrub` | 74x74 | Pink flowering mass, planted pocket |
| b#24 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x240_y1344_w80_h80.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `hedge_mass` | 74x74 | Bright green leaf mass for hedge breaks |
| c#3 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x288_y96_w48_h64.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `ornamental_vine` | 45x62 | Tall vine, gold buds, butterflies: luminous feel |
| b#22 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x0_y1360_w96_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `vine_stump` | 68x96 | Bright vines on stump: Garden brightness |

## Scatter: 66

Cell-scale ground dressing (pebbles, twigs, planks, straw, saplings, tufts, small fungi and flowers). Each line lists the regions whose ground it matches, best fit first. A scatter piece may appear in every region it names.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | regions | size | reason |
|---|---|---|---|---|---|
| c#37 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x160_y160_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains` | 31x23 | Small orange bush |
| e#48 | `Pixel Crawler - Free Pack/Model_01_Size_02/Model_01_Size_02__x32_y64_w32_h64.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_02.png` | `floodplains` | 32x62 | Small orange round tree |
| f#3 | `Pixel Crawler - Free Pack/Model_03_Size_02/Model_03_Size_02__x96_y128_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_02.png` | `floodplains` | 16x32 | Slim red sapling |
| rock#28 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x96_y320_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,garden,riverfarm` | 10x8 | Mossy pebble |
| a#26 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x208_y156_w32_h52.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `floodplains,riverfarm` | 32x52 | Cell-scale green pine |
| a#28 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x240_y176_w16_h17.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `floodplains,riverfarm` | 16x17 | Pine sapling |
| c#10 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x528_y384_w48_h64.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `floodplains,riverfarm` | 40x59 | Green slim tree, cell scale |
| d#44 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x608_y192_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `floodplains,riverfarm` | 9x10 | Green sapling |
| e#39 | `Pixel Crawler - Free Pack/Model_03_Size_02/Model_03_Size_02__x0_y0_w32_h80.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_02.png` | `floodplains,riverfarm` | 30x75 | Olive slim tree |
| e#44 | `Pixel Crawler - Free Pack/Model_02_Size_02/Model_02_Size_02__x0_y48_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_02.png` | `floodplains,riverfarm` | 45x47 | Green conifer clump |
| e#47 | `Pixel Crawler - Free Pack/Model_01_Size_02/Model_01_Size_02__x32_y0_w32_h64.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_02.png` | `floodplains,riverfarm` | 32x62 | Small yellow-green round tree |
| f#2 | `Pixel Crawler - Free Pack/Model_03_Size_02/Model_03_Size_02__x32_y48_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_02.png` | `floodplains,riverfarm` | 16x32 | Slim green sapling |
| rock#22 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x33_y259_w14_h12.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm` | 14x12 | Small ochre rock |
| rock#25 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x0_y320_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm` | 14x9 | Flat ochre pebble |
| rock#29 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x16_y320_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm` | 10x7 | Tiny ochre pebble |
| b#57 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x464_y352_w64_h96.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `floodplains,riverfarm,garden` | 50x90 | Green slim tree, cell-friendly |
| c#50 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x576_y192_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `floodplains,riverfarm,garden` | 17x32 | Green sapling |
| d#18 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x224_y16_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden` | 15x11 | Low grass tuft |
| d#24 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x224_y128_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden` | 12x12 | Orange four-petal flower |
| debris#10 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x256_y16_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden` | 14x9 | Fallen twig |
| debris#11 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x256_y0_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden` | 14x7 | Twig, second silhouette |
| debris#12 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x256_y32_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden` | 12x6 | Twig, third silhouette |
| rock#23 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x33_y307_w14_h12.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden` | 14x12 | Small mossy rock |
| f#9 | `Pixel Crawler - Free Pack/Props/Props__x50_y154_w28_h17.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` | `floodplains,riverfarm,garden,liscor` | 28x17 | Low leafy bush, cell scale |
| d#10 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x272_y96_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `floodplains,riverfarm,garden,liscor,invrisil` | 16x16 | Grass tuft |
| a#30 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x219_y144_w15_h12.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `floodplains,riverfarm,ruin` | 15x12 | Low dark shrub tuft |
| d#4 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x112_y1584_w48_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `floodplains,riverfarm,ruin` | 27x12 | Small fallen log |
| d#8 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x400_y128_w16_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `garden` | 15x19 | Vine curl |
| d#54 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x208_y160_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `garden,floodplains` | 7x9 | Single white flower |
| d#51 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x224_y160_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `garden,floodplains,riverfarm` | 8x8 | White flower pair |
| a#38 | `Pixel Crawler - Desert/Props/Props__x66_y256_w25_h29.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Props.png` | `garden,riverfarm` | 25x29 | Sapling of #37 |
| d#5 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x432_y64_w16_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `garden,riverfarm` | 16x20 | Cell-sized purple trumpet |
| d#1 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x240_y96_w16_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `garden,riverfarm,floodplains` | 11x32 | White-flower stalk |
| a#24 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x160_y104_w46_h103.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `riverfarm,floodplains` | 46x103 | Mid pine, usable without render_scale |
| c#59 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x540_y613_w31_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `riverfarm,floodplains` | 31x16 | Low teal-green clump |
| e#32 | `Pixel Crawler - Free Pack/Model_02_Size_03/Model_02_Size_03__x0_y80_w48_h80.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_03.png` | `riverfarm,floodplains` | 37x76 | Green small conifer |
| f#11 | `Pixel Crawler - Free Pack/Model_03_Size_04-export/Model_03_Size_04-export__x224_y384_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_04-export.png` | `riverfarm,floodplains` | 17x21 | Small brown stump |
| f#21 | `Pixel Crawler - Free Pack/Model_02_Size_02/Model_02_Size_02__x112_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_02.png` | `riverfarm,floodplains` | 9x10 | Green seedling |
| d#2 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x224_y96_w16_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `riverfarm,floodplains,garden` | 11x31 | Green leaf stalk |
| d#13 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x336_y176_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `riverfarm,floodplains,garden` | 13x16 | Red toadstool |
| c#12 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x0_y1616_w96_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `riverfarm,floodplains,ruin` | 68x32 | Root tangle ground dressing |
| debris#16 | `Pixel Crawler - Free Pack/Resources/Resources__x80_y64_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `riverfarm,floodplains,ruin` | 7x9 | Short stick |
| e#56 | `Pixel Crawler - Free Pack/Model_03_Size_05/Model_03_Size_05__x304_y480_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_03/Size_05.png` | `riverfarm,floodplains,ruin` | 27x22 | Small stump |
| c#55 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x288_y160_w32_h32.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `riverfarm,floodplains,sewers` | 18x29 | Tall red toadstool |
| e#57 | `Pixel Crawler - Free Pack/Model_01_Size_02/Model_01_Size_02__x16_y32_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_02.png` | `riverfarm,garden` | 16x32 | Curly green sapling |
| other#44 | `Pixel Crawler - Free Pack/Resources/Resources__x16_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `riverfarm,liscor` | 15x6 | Small straw wisp |
| other#26 | `Pixel Crawler - Free Pack/Resources/Resources__x16_y96_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `riverfarm,liscor,floodplains` | 22x13 | Straw tuft, stable and pen scatter |
| debris#13 | `Pixel Crawler - Free Pack/Resources/Resources__x32_y64_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `riverfarm,liscor,ruin` | 32x7 | Plank: wheelwright yard, dray, dig camp |
| debris#14 | `Pixel Crawler - Free Pack/Resources/Resources__x0_y80_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `riverfarm,liscor,ruin` | 6x32 | Upright plank, leans on walls |
| debris#17 | `Pixel Crawler - Free Pack/Resources/Resources__x16_y64_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `riverfarm,liscor,ruin` | 9x6 | Plank offcut |
| a#27 | `Pixel Crawler - Cemetery 0.4/Tree/Tree__x208_y364_w32_h52.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Tree.png` | `ruin,floodplains` | 32x52 | Cell-scale dead pine |
| e#51 | `Pixel Crawler - Free Pack/Model_01_Size_02/Model_01_Size_02__x160_y16_w32_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_02.png` | `ruin,floodplains` | 26x47 | Bare sapling |
| f#5 | `Pixel Crawler - Free Pack/Model_01_Size_02/Model_01_Size_02__x144_y32_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_01/Size_02.png` | `ruin,floodplains` | 16x30 | Bare sapling |
| debris#3 | `Pixel Crawler - Cemetery 0.4/Props/Props__x160_y64_w16_h16.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `ruin,floodplains,riverfarm` | 10x6 | Dirt clod, path scatter |
| e#30 | `Pixel Crawler - Free Pack/Model_02_Size_03/Model_02_Size_03__x96_y0_w48_h80.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Trees/Model_02/Size_03.png` | `ruin,floodplains,riverfarm` | 40x74 | Small twisted dead tree |
| rock#6 | `Pixel Crawler - Cemetery 0.4/Props/Props__x112_y96_w16_h16.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `ruin,sewers,floodplains,riverfarm` | 11x9 | Pebble |
| rock#7 | `Pixel Crawler - Cemetery 0.4/Props/Props__x144_y80_w16_h16.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `ruin,sewers,floodplains,riverfarm` | 10x8 | Pebble, second |
| rock#8 | `Pixel Crawler - Cemetery 0.4/Props/Props__x144_y96_w16_h16.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Props/Props.png` | `ruin,sewers,floodplains,riverfarm` | 8x8 | Pebble, third |
| a#15 | `Pixel Crawler - Cave/Props/Props__x352_y32_w32_h32.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `sewers,dungeon` | 20x26 | Small lit stem, second cell silhouette |
| rock#27 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x80_y336_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `sewers,dungeon,pallass` | 14x9 | Flat grey pebble |
| rock#31 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x96_y336_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `sewers,dungeon,pallass` | 10x7 | Tiny grey pebble |
| a#11 | `Pixel Crawler - Cave/Props/Props__x288_y32_w32_h32.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `sewers,dungeon,riverfarm` | 27x28 | Cell-sized lit cap; hollow glow dressing too |
| a#16 | `Pixel Crawler - Cave/Props/Props__x257_y64_w14_h16.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Props.png` | `sewers,dungeon,ruin` | 14x16 | Already mushroom_purple_s; tiny cluster |
| rock#20 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x160_y256_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `sewers,dungeon,ruin,pallass` | 15x16 | Small grey rock, cell |
| d#12 | `Pixel Crawler - Fairy Forest 1.7/Props/Props__x272_y0_w16_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Props.png` | `sewers,riverfarm,floodplains` | 16x15 | Orange flat cap |
| d#11 | `Pixel Crawler - Fairy Forest 1.7/Tree/Tree__x1216_y1440_w32_h16.png` | `Pixel Crawler - Fairy Forest 1.7/Pixel Crawler - Fairy Forest 1.7/Assets/Tree.png` | `sewers,ruin,riverfarm` | 32x8 | Red shelf fungus pair |

## Common: 3

Generic utility with no regional identity, for any region's `cargo` or container pool. These sheets have no sacks and no other generic containers.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | kind | size | reason |
|---|---|---|---|---|---|
| container#25 | `Pixel Crawler - Free Pack/Tools/Tools__x0_y112_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `barrel` | 16x19 | Hooped wooden tub, generic utility |
| tool_a#26 | `Pixel Crawler - Free Pack/Tools/Tools__x16_y96_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Tools.png` | `barrel` | 14x15 | Small hooped keg, generic utility |
| container#29 | `Pixel Crawler - Free Pack/Resources/Resources__x0_y144_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Resources.png` | `crate` | 15x19 | Empty tall plank crate, generic utility |

## Recut, recolour and generation asks

These come from the Notes sections of the 2026-10-09 rulings. Every recut below comes from a sheet that is already bundled, so it needs no new art. A recolour of pack art stays bundle-tier, as the rock_crab recolour did in `bundle-v6`. Generation asks are candidates for `docs/art-generation-list.md`. Phase 3 generation needs a batch the user has approved.

### Recuts

- **Invrisil shop door (would beat the current holder).** Lift the arched glass door (about 22x32) from the lower half of door#7 (`Pixel Crawler - Free Pack/Props/Props__x101_y29_w22_h67`, a composite). door#6 (`Props__x128_y25_w64_h71`) has the same door. It replaces the green double door on the shop-door role, and the green door goes back to `door_street` only (see identity door #1).
- **Pallass stone door.** Lift the grey-stone arched doorway (about 24x36) from window#1 (`Pixel Crawler - Free Pack/Props/Props__x32_y20_w63_h124`, a composite) as `pallass/door_stone`. The other windows in that composite duplicate window#2, #3 and #5 and need no recut.
- **door#3** (`Pixel Crawler - Cemetery 0.4/Props/Props__x35_y84_w26_h85`): recut into two. The arched iron-lattice gate goes to `dungeon/trapped_halls_gate`, and the green four-panel door goes to `liscor/door_civic` as a larger sibling of door#10.
- **door#4** (`riverfarm/door_barn`, 32x60): trim it to about 44 high if it has to share a facade with 32-high doors.
- **b#18** (`Pixel Crawler - Fairy Forest 1.7/Props/Props__x0_y0_w64_h144`): three round bushes fused into one slice. Recut into three 64x48 pieces: the orange one goes to the floodplains as an autumn shrub, and the two greens go to the shrub pool.
- **e#3** (`Pixel Crawler - Free Pack/Model_03_Size_04/Model_03_Size_04__x0_y0_w192_h416`): a 2x2 grid of 96x208 slim pines. Recut into four. Green and olive go to `riverfarm/pine`, red goes to `floodplains/tree`, and brown is a shade variant to drop. e#2 (`-export`) was a byte-level duplicate and was rejected.
- **e#7** (`Pixel Crawler - Free Pack/Model_01_Size_03/Model_01_Size_03__x0_y0_w96_h192`): a 2x2 grid of 48x96 round trees. Recut into four. They are the native-scale siblings of `tree_round`, which renders `Tree_M1_S4` at render_scale 0.2. Audition them as its floodplains replacement, so the pixel size stays the same.
- **c#27 `liscor/planter_shrub` and c#36 `invrisil/topiary`:** both are bare bushes and need a container. Liscor wants a wooden half-barrel or a brick tub in the warm palette. Invrisil wants a pale stone urn or the existing boulevard planter. If no container is in hand, generate the two bases (see the generation asks).
- **seat#1** (`Pixel Crawler - Free Pack/Props/Props__x83_y160_w58_h32`): recut the top half as a three-cell long bench, for the Riverfarm longhouse and Liscor guild seating.
- **wall_module#4** (`Pixel Crawler - Free Pack/Props/Props__x6_y176_w68_h80`): a light-timber picket pen. Recut it into EW and NS fence modules plus corners for `riverfarm/fence` (module, three or more). Audition it beside the dark post fence before adopting it.
- **other#21** (`Pixel Crawler - Free Pack/Dungeon_Props/Dungeon_Props__x0_y0_w64_h32`): four ore carts in a row. Recut them into singles. With other#24 and #25 that gives the ruin dig a cart family and a rail.
- **other#20** (`Pixel Crawler - Free Pack/Props/Props__x4_y73_w24_h103`): recut the grey stone chimney stack as `pallass/forge_chimney`.
- **other#4** (`Pixel Crawler - Cemetery 0.4/Props/Props__x64_y0_w48_h48`): recut the dug pit without the shovel as the ruin's excavation edge. tool_a#1 already covers the shovel.
- **tool_a#3/#4** (`Pixel Crawler - Free Pack/Tools/Tools__x0_y160_w16_h64`, `Tools__x0_y32_w16_h56`): two sledgehammers per slice. Recut one grey-head hammer for the Pallass forge hall; the kept hammer (tool_a#33) is only wall-rack scale.
- No recut needed: container#14 to #17 (the kept singles cover them) and rock#12 (the kept boulders #13, #14, #22 and #23 cover it).

### Recolours

- **wall_module#1** (`Pixel Crawler - Desert/Props/Props__x0_y7_w96_h169`): a sandstone obelisk with block-wall courses and blue glyph bands. Shift the courses from desert ochre to Pallass beige-grey for `pallass/tier_wall` modules. The glyph band is a free Drake-city ornament. The kept stubs (wall_module#2 and #3) would also serve Pallass after the same shift.
- **debris#4/#5/#6** (Desert horns, 54x71 down to 29x46): a half-buried giant tusk makes a strong floodplains landmark, but the orange sand and warm bone clash with grass. Cool the bone and replace the sand with turf, or leave them out.
- **Cave mushrooms** (a#2, a#4, a#6, a#9): the lit states carry a cold blue glow. If the sewers want the amber of `liscor_sconce_copper`, the ask is a warm-glow recolour of a#9. Otherwise they serve as the sewers' only lit plant before [Light].
- **Free Pack tools:** many ship in four to eight tints, and only one per shape is kept (tint is not disambiguation). If a region needs a second visible variant, ask for a new shape, not a palette swap.

### Generation asks

- **Pallass lamp:** a bronze post or wall arm with a cold white lamp, in day and lit states, matching the parapet posts in the context shot. No contested candidate fits.
- **Dungeon brazier** (dropped, covered by lamp#5 and container#3, #606 re-intake): a floor brazier for the halls and the vault approach. First check the harvest's uncontested standing brazier.
- **Ruin light:** a dig-camp lantern or brazier with enough pale highlight to stand out from the dark field. Same check first.
- **Sewers light:** one lit fixture for the service channel (a wall pier lamp or a hanging cage lamp with local glow), so [Light]-off reads are not all silhouette. Generate one unless the standing brazier fits a canal wall.
- **Riverfarm mature crop** (dropped, covered by plant_b#5, #8, #10, #19, #39, #13/#14 and plant_c#6, #606 re-intake): a straight 16x16 mature-crop tile (wheat or cabbage) to finish the crop row (d#56, d#48, d#26). No sheet has one.
- **Planter bases** (dropped, covered by plant_d#42, crate#2 and plant_a#39/#40 for Liscor and container#50 for Invrisil, #606 re-intake; reopens for Invrisil only if the urn composite does not read): two 16x12 bottom-anchored bases for c#27 (Liscor) and c#36 (Invrisil), only if no container is in hand.

### Conditional and parked rulings

- **a#40** (purple giant canopy) only earns a place if the hollow canopy pool also gets silhouette variety: e#16 (teal conifer) and the b#3/b#19/b#45 hero trunk. If the pool stays at three round canopies, drop a#40 and keep e#16.
- **Frosted set** (e#14, e#15, e#23, e#37, e#53, e#54, e#55, f#7, f#8, f#10, f#12, f#16, f#19): rejected because no region uses it today. It is a complete winter set, ready for a winter floodplains or Liscor state without generation.
- **door#1** (Cemetery mausoleum composite with a pentagram rose window): rejected outright. The occult ornament has no TWI reading.

## Re-intake allocation (#624/#627, 2026-10-09)

The re-intake (#624, #626, #627) sliced every `potential_assets` PNG and registered or excluded it. Three read-only rulings judged the 1010 pieces that were not already allocated, wired or dropped frames: natural (plants, rocks, debris, fx, resource: 343 judged, 112 kept), goods (containers, food, tools, stations, pipes and the rest: 410 judged, 126 kept) and architecture (doors, windows, wall modules, tables, seats, signs, lamps and the rest: 257 judged, 142 kept). Total **380 new pieces**, on top of the 238 above: **618 allocated pieces**. None of the 238 is re-allocated. Rejected pieces are not listed.

Same rules as above: a piece allocated to one region moves only with a `docs/CHOICE-LOG.md` ruling. `sheet#n` tags are the ruling's own numbering (sheet = the `nk_<sheet>` contact sheet of the re-intake). Eight tags were checked against the slice filename because the contact-sheet index number and the ruling differ (plant_c#25 to #28, container#24, container#31, station#28, station#29); the slice path in each row is the one the ruling named. The `bundled` column says whether the source sheet is already under `wandering_inn_game/assets/`; 96 pieces sit on 24 sheets that need `bundle-v9` (see Bundle needs below).

### Re-intake totals

| destination | kept pieces | natural | goods | architecture |
|---|---|---|---|---|
| Liscor | 62 | 5 | 28 | 29 |
| Invrisil | 48 | 2 | 17 | 29 |
| Inn | 36 | 3 | 14 | 19 |
| Riverfarm and the witch hollow | 42 | 10 | 18 | 14 |
| Pallass | 38 | 0 | 17 | 21 |
| Floodplains | 13 | 2 | 2 | 9 |
| Sewers | 27 | 7 | 16 | 4 |
| Ruin | 19 | 9 | 5 | 5 |
| Dungeon | 9 | 3 | 1 | 5 |
| Garden of Sanctuary | 15 | 9 | 1 | 5 |
| Scatter | 64 | 62 | 0 | 2 |
| Common | 7 | 0 | 7 | 0 |
| **all** | **380** | **112** | **126** | **142** |

### Liscor (62)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#39 | `Pixel Crawler - Free Pack/Farm/Farm__x160_y0_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `planter_crate` | 16x32 | yes | Wooden crate planter with herb sprouts; market timber palette |
| plant_a#40 | `Pixel Crawler - Free Pack/Farm/Farm__x160_y32_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `planter_crate` | 16x32 | yes | Same crate, flowering beets; second content, not a tint |
| plant_a#42 | `Pixel Crawler - Free Pack/Furniture/Furniture__x50_y410_w28_h17.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `planter_trough` | 28x17 | yes | Low trough of greenery; street-level planter, 2 cells wide |
| plant_d#42 | `Pixel Crawler - Library/Tiles/Tiles__x336_y320_w32_h48.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `planter_shrub` | 32x46 | yes | Lush shrub in a wooden stand planter; beats c#27 (needs no base) |
| fx#2 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x368_y192_w16_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `lamp_glow` | 12x25 | yes | Small amber cone; lit night state over the unlit copper bracket (lamp #6) |
| barrel#2 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x112_y272_w16_h32.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `water_barrel` | 16x22 | no | Red-hooped water barrel; warm bands suit brick street |
| crate#2 | `Pixel Crawler - Free Pack/Farm/Farm__x160_y192_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `planter_crate` | 16x32 | yes | Seedlings in crate; warm planter for the base ask |
| crate#3 | `Pixel Crawler - Free Pack/Farm/Farm__x160_y160_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `market_produce` | 16x27 | yes | Crate of greens for the veg stand |
| crate#4 | `Pixel Crawler - Free Pack/Farm/Farm__x160_y128_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `market_produce` | 16x26 | yes | Crate of pale produce; second stall crate |
| sack#1 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x24_y184_w16_h24.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `runner_pack` | 16x24 | yes | Flap knapsack; Runners' Guild delivery sorting |
| container#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x304_y208_w16_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `clay_jar` | 16x21 | yes | Warm clay amphora; potter's stall goods |
| container#2 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x320_y208_w16_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `clay_jar_tall` | 14x24 | yes | Slim amphora sibling; stall pair |
| container#4 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x496_y273_w16_h31.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `basket_stack` | 16x31 | yes | Stacked wicker baskets; fruit stand dressing |
| container#6 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x179_y75_w26_h14.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `barracks_footlocker` | 26x14 | yes | Banded trunk; barracks duty furniture |
| container#21 | `Pixel Crawler - Free Pack/Furniture/Furniture__x787_y108_w10_h20.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `clay_jar_slim` | 10x20 | yes | Narrow clay bottle; third potter silhouette |
| vessel#3 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x432_y225_w32_h14.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `stall_tray` | 32x14 | yes | Two-cell shallow tray; bread stall display |
| vessel#11 | `Pixel Crawler - Free Pack/Farm/Farm__x0_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `preserve_jar` | 15x16 | yes | Labelled orange jar; market preserves |
| food#6 | `Pixel Crawler - Free Pack/Farm/Farm__x128_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `market_produce` | 16x16 | yes | Carrot for the veg stand |
| food#7 | `Pixel Crawler - Free Pack/Farm/Farm__x128_y48_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `market_produce` | 16x16 | yes | Radish; distinct colour and shape |
| food#12 | `Pixel Crawler - Free Pack/Farm/Farm__x128_y80_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `market_produce` | 16x14 | yes | Cabbage head |
| food#22 | `Pixel Crawler - Free Pack/Meat/Meat__x112_y0_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png` | `market_bread` | 13x10 | yes | Round loaf for the bread stall |
| food#24 | `Pixel Crawler - Free Pack/Farm/Farm__x112_y48_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `market_produce` | 11x10 | yes | Tomato |
| item#5 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x98_y261_w28_h9.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `barracks_weapon` | 28x9 | yes | Laid sword; kit-rack table |
| item#6 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x129_y272_w14_h16.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `barracks_shield` | 14x16 | yes | Round shield for the kit rack |
| item#10 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x16_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `guild_quill` | 9x11 | yes | Quill on the reception desk |
| book#3 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x0_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `guild_scroll` | 13x14 | yes | Capped scroll; Runners' delivery sorting |
| book#4 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x0_y160_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `guild_ledger` | 15x12 | yes | Open book; reception desk |
| book#6 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x32_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `guild_papers` | 9x11 | yes | Paper stack; distinct from books |
| book#8 | `Pixel Crawler - Library/Tiles/Tiles__x32_y288_w16_h16.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `guild_book` | 9x11 | yes | Red upright book; guild desk |
| station#16 | `Pixel Crawler - Free Pack/Butchery_Butchery_03/Butchery_Butchery_03__x16_y16_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Butchery/Butchery_03.png` | `butcher_stall` | 48x48 | no | Butcher table with hanging rack |
| station#26 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x54_y263_w36_h51.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `bread_oven_unlit` | 36x51 | yes | Arched brick oven, unlit |
| station#27 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x54_y71_w36_h51.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `bread_oven` | 36x51 | yes | Arched brick oven, lit; bakery |
| station#55 | `Pixel Crawler - Free Pack/Cooking Station_Cooking Station/Cooking Station_Cooking Station__x208_y189_w16_h35.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Cooking Station.png` | `market_hanging_meat` | 16x35 | no | Hanging side of meat; butcher's |
| door#2 | `Pixel Crawler - Free Pack/Furniture/Furniture__x99_y269_w26_h83.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `window_arch` | 26x83 | yes | Recut: brown-arched blue glass, Liscor's first glazed window |
| door#6 | `Pixel Crawler - Free Pack/Furniture/Furniture__x166_y281_w20_h39.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `door_barracks` | 20x39 | yes | Iron-banded arched plank door: armoury and barracks |
| window#13 | `Pixel Crawler - Free Pack/Furniture/Furniture__x32_y132_w48_h12.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `window_box` | 48x12 | yes | Recut two: green window boxes, the planter container Liscor lacks |
| wall_module#4 | `Pixel Crawler - Cemetery 0.4/Roof/Roof__x0_y0_w96_h112.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Roof.png` | `roof` | 78x109 | no | Brown shingle gable module; replaces inn_roof x8 |
| wall_module#5 | `Pixel Crawler - Cemetery 0.4/Roof/Roof__x0_y112_w96_h112.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Roof.png` | `roof` | 78x108 | no | Second brown shingle module, different inner shape |
| wall_module#8 | `Pixel Crawler - Cemetery 0.4/Roof/Roof__x16_y240_w48_h64.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Roof.png` | `facade_wall` | 48x55 | no | Warm brown brick panel: the warm-brick facade module |
| wall_module#14 | `Pixel Crawler - Cemetery 0.4/Walls/Walls__x384_y0_w16_h16.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png` | `facade_brick` | 16x16 | yes | Brick cell; fills facade_wall gaps |
| wall_module#24 | `Pixel Crawler - Free Pack/Furniture/Furniture__x188_y422_w32_h23.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `hitching_rail` | 32x23 | yes | Pole lashed to a post: dray rank |
| fence#10 | `Pixel Crawler - Free Pack/Furniture/Furniture__x220_y422_w17_h23.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `hitching_post` | 17x23 | yes | Rope-tied post with bar for the dray rank |
| structure#5 | `Pixel Crawler - Free Pack/Furniture/Furniture__x147_y448_w27_h46.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `sign_post` | 27x46 | yes | Timber post with arm and brace: hanging-sign bracket |
| table#6 | `Pixel Crawler - Free Pack/Butchery_Butchery_04/Butchery_Butchery_04__x16_y16_w64_h64.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Butchery/Butchery_04.png` | `stall_butcher` | 53x64 | no | Butcher counter with hanging meat rack: market stall |
| table#13 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x144_y160_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `stall_counter` | 48x48 | yes | Cloth-draped empty stall counter, warm timber |
| table#16 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x48_y250_w48_h38.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `guild_counter` | 48x38 | no | Orange timber counter with emblem: guild reception |
| table#22 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x64_y256_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `guild_strongbox` | 32x32 | yes | Dark plank cabinet with lock and hinges |
| table#26 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x80_y182_w32_h26.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `counter_small` | 32x26 | yes | Small orange counter with emblem, pairs with table#16 |
| table#29 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x128_y104_w32_h18.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `runners_desk` | 32x18 | yes | Knee-hole desk: the Runners' Guild desk arrangement |
| table#36 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x352_y128_w48_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `barracks_table` | 40x40 | no | Plain heavy dark table: duty room |
| table#38 | `Pixel Crawler - Library/Tiles/Tiles__x336_y368_w32_h32.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `guild_table` | 32x23 | yes | Orange reading table with green cloth |
| seat#6 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x33_y338_w46_h9.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `barracks_bench` | 46x9 | yes | Low dark plank bench, training order |
| shelf#1 | `Pixel Crawler - Free Pack/Furniture/Furniture__x0_y98_w32_h34.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `runners_sorting_shelf` | 32x34 | yes | Three open rows of warm timber: delivery sorting |
| shelf#5 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x160_y104_w16_h24.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `guild_drawers` | 16x24 | yes | Small two-drawer cabinet beside the desk |
| shelf#6 | `Pixel Crawler - Free Pack/Furniture/Furniture__x720_y73_w16_h23.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `guild_cabinet` | 16x23 | yes | Orange cabinet with dark door, reception storage |
| shelf#10 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x352_y96_w32_h32.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `barracks_locker` | 32x23 | no | Dark two-drawer footlocker for the bunk row |
| shelf#11 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x320_y160_w16_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `barracks_locker_tall` | 16x39 | no | Tall dark locker, pairs with shelf#10 |
| shelf#13 | `Pixel Crawler - Library/Tiles/Tiles__x224_y128_w48_h32.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `runners_peg_rail` | 48x11 | yes | Plank with hanging pegs: delivery hooks |
| bed#4 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x272_y48_w32_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `barracks_bunk` | 20x34 | no | Narrow red-blanket cot; repeat for the bunk row |
| sign#5 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x336_y192_w16_h16.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `watch_crest` | 10x14 | yes | Red and gold shield: Watch colours on the barracks wall |
| sign#6 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x194_y264_w28_h19.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `notice_board` | 28x19 | yes | Blank framed board: the guild board wall |
| sign#7 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x226_y264_w28_h19.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `request_board` | 28x19 | yes | Same board with chalk writing: posted requests |

### Invrisil (48)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#41 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x64_y354_w16_h30.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `potted_plant` | 16x30 | yes | Tall potted plant for the enchanter shop and the Rest |
| plant_d#43 | `Pixel Crawler - Library/Tiles/Tiles__x368_y320_w16_h48.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `planter` | 16x38 | yes | Slim potted shrub on a stand; shop interiors, cell wide |
| container#15 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x0_y80_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `enchanter_jar` | 11x21 | yes | Bell jar with specimen; work-room shelf |
| container#16 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x32_y80_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `enchanter_jar` | 11x21 | yes | Bell jar with plant; second content |
| container#19 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x80_y16_w32_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `enchanter_rack` | 17x13 | yes | Test-tube rack; enchanter work room |
| container#31 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x0_y64_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `enchanter_flask` | 11x14 | yes | Round-bottom flask, green; potion read |
| container#50 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x400_y320_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `planter_urn` | 16x21 | yes | Pale smooth urn; the topiary base ask |
| vessel#16 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x546_y192_w12_h16.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `inkpot` | 12x16 | yes | Corked bottle, metal collar; stationer desk |
| vessel#24 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x532_y245_w9_h10.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `tableware_glass` | 9x10 | yes | Stemmed glass; Invrisil's glass at table |
| vessel#33 | `Pixel Crawler - Sewer/Props/Props__x130_y144_w12_h16.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `enchanter_flask` | 12x16 | yes | Stoppered round flask, blue; second flask shape |
| item#11 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x16_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `stationer_quill` | 9x11 | yes | Upright quill; stationer desk |
| item#18 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x304_y208_w16_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `stationer_scroll` | 11x7 | no | Rolled parchment |
| book#1 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x48_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `enchanter_tome` | 16x16 | yes | Blue rune tome, angled |
| book#5 | `Pixel Crawler - Free Pack/Esoteric/Esoteric__x0_y176_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Esoteric.png` | `stationer_book` | 9x11 | yes | Green upright book |
| tool#12 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x103_y64_w73_h48.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `enchanter_workbench` | 73x48 | no | Tool wall with vials; work room |
| tool#18 | `Pixel Crawler - Free Pack/Anvil_Anvil/Anvil_Anvil__x192_y134_w64_h26.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil.png` | `shop_counter_glass` | 64x26 | no | Steel glass-top counter, 4 cells |
| tool#20 | `Pixel Crawler - Free Pack/Anvil_Anvil/Anvil_Anvil__x96_y132_w48_h28.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil.png` | `shop_counter_glass` | 48x28 | no | Wood-frame glass counter, 3 cells |
| station#33 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x144_y19_w32_h45.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `iron_stove` | 32x45 | yes | Cast-iron range; cold iron interior |
| pipe#4 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x144_y0_w32_h19.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `alley_pipe` | 32x19 | yes | Grey steel drain run; back-alley service |
| door#14 | `Pixel Crawler - Library/Tiles/Tiles__x160_y336_w48_h64.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `door_enchanter` | 36x52 | yes | Teal door with gold tracery: magic-shop threshold |
| door#16 | `Pixel Crawler - Library/Tiles/Tiles__x256_y336_w48_h64.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `door_enchanter_open` | 36x52 | yes | Dark arch, open state of door#14 |
| wall_module#3 | `Pixel Crawler - Cemetery 0.4/Walls/Walls__x6_y361_w84_h113.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png` | `railing_corner` | 84x113 | yes | Recut: black spiked railing corners for the fountain curb |
| wall_module#11 | `Pixel Crawler - Cemetery 0.4/Walls/Walls__x32_y425_w32_h17.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png` | `railing` | 32x17 | yes | Straight black iron railing, 2-cell module |
| wall_module#17 | `Pixel Crawler - Free Pack/Roofs/Roofs__x272_y87_w96_h100.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Roofs.png` | `roof_glass` | 96x100 | yes | Recut halves: pale glass gable, glazier or teahouse |
| table#10 | `Pixel Crawler - Free Pack/Furniture/Furniture__x32_y86_w64_h46.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `display_counter` | 64x46 | yes | Recut: steel glass counter with gold chain trim |
| table#11 | `Pixel Crawler - Free Pack/Alchemy_Alchemy_Table_02-Sheet/Alchemy_Alchemy_Table_02-Sheet__x384_y192_w48_h64.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Alchemy/Alchemy_Table_02-Sheet.png` | `enchanter_bench` | 48x53 | no | Bottle bench with crucible: Hedault's work room |
| table#18 | `Pixel Crawler - Free Pack/Furniture/Furniture__x32_y52_w48_h28.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `display_case` | 48x28 | yes | Glass case on a wooden table, steel handle |
| table#19 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x65_y227_w45_h28.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `sideboard` | 45x28 | yes | Dark wood sideboard, teal steel feet |
| table#24 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x7_y163_w34_h29.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `table` | 34x29 | yes | Blue diamond cloth table: cold palette, teahouse |
| table#25 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x7_y99_w34_h29.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `table` | 34x29 | yes | Dark wood table with steel corners |
| table#30 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x0_y313_w32_h18.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `display_case_small` | 32x18 | no | Small glass display panel with emblem |
| seat#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x272_y0_w32_h64.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `armchair` | 20x51 | yes | Red high-backed chair: Hedault or the parlor |
| seat#3 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x0_y204_w48_h20.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `bench` | 48x20 | yes | Dark plank bench on steel legs, 3 cells |
| seat#5 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x83_y301_w42_h17.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `settee` | 42x17 | yes | Blue padded settee: the Invrisil settee gap |
| seat#19 | `Pixel Crawler - Sewer/Props/Props__x49_y112_w14_h31.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `oak_chair` | 14x31 | yes | Tall carved oak chair, front: the oak chair gap |
| seat#20 | `Pixel Crawler - Sewer/Props/Props__x65_y112_w14_h31.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `oak_chair` | 14x31 | yes | Oak chair, side facing; pairs with seat#19 |
| bed#1 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x33_y293_w46_h45.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `bed` | 46x45 | yes | Blue double bed for the Adventurer's Rest |
| rug#4 | `Pixel Crawler - Free Pack/Tilesets_Floors_Tiles/Tilesets_Floors_Tiles__x0_y192_w80_h80.png` | `Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png` | `rug_pale` | 79x78 | yes | Pale blue-white fur rug, cold parlor floor |
| rug#11 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x96_y400_w48_h48.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `rug` | 38x40 | yes | Purple floral rug, cool rich interior |
| rug#14 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x96_y448_w32_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `rug_small` | 32x32 | yes | Purple rug with dark centre, 2x2 cells |
| sign#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x288_y160_w16_h64.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `banner` | 16x46 | yes | Long purple banner, gold trim: scarce gold on pale |
| sign#2 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x320_y160_w16_h48.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `banner_short` | 16x30 | yes | Short sibling of sign#1 |
| sign#3 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x272_y160_w16_h48.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `pennant` | 10x36 | yes | Narrow purple pennant, gold tip |
| decor#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x342_y75_w20_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `bust` | 20x32 | yes | Helmeted stone bust: Adventurer's Rest hall |
| decor#3 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x304_y112_w32_h48.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `bust` | 18x32 | yes | Plain stone bust, pale stone palette |
| decor#4 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x312_y74_w16_h33.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `bust` | 16x33 | yes | Bust with hair, third silhouette |
| decor#10 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x80_y318_w44_h18.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `wall_painting` | 44x18 | yes | Recut: framed landscape for the parlor wall |
| decor#20 | `Pixel Crawler - Library/Tiles/Tiles__x64_y304_w80_h80.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `curtains` | 76x80 | yes | Recut halves: dark teal floor curtains, enchanter shop |

### Inn (36)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#43 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x17_y352_w14_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `potted_flowers` | 14x32 | yes | Pink flowers in a pot; warm domestic detail for the common room |
| plant_a#46 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x32_y360_w15_h24.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `potted_plant` | 15x24 | yes | Small potted plant for the landing and guest-room fronts |
| resource#12 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x433_y273_w14_h15.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `firewood` | 14x15 | yes | Split-log stack for the hearth zone |
| barrel#6 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x240_y336_w48_h64.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `ale_cask` | 34x50 | no | Dark cask on cradle; back-bar hero, 2x3 cells |
| container#7 | `Pixel Crawler - Free Pack/Furniture/Furniture__x752_y108_w16_h20.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `water_pail` | 16x20 | yes | Lidded wooden pail for the kitchen zone |
| vessel#2 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x402_y230_w28_h20.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `serving_tray` | 28x20 | yes | Deep wooden tray for the bar |
| vessel#7 | `Pixel Crawler - Free Pack/Animated_Pan_04-Sheet/Animated_Pan_04-Sheet__x38_y15_w20_h17.png` | `Pixel Crawler - Free Pack/Environment/Props/Animated/Pan_04-Sheet.png` | `stew_pot` | 20x17 | no | Stew pot with spoon; hearth zone static |
| vessel#26 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x564_y277_w9_h8.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `tableware` | 9x8 | yes | Pewter tankard; distinct from the ale mug |
| food#13 | `Pixel Crawler - Free Pack/Meat/Meat__x32_y80_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png` | `kitchen_meat` | 16x14 | yes | Raw steak on the prep counter |
| food#14 | `Pixel Crawler - Free Pack/Meat/Meat__x32_y96_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png` | `kitchen_poultry` | 13x15 | yes | Plucked bird; prep counter |
| food#18 | `Pixel Crawler - Free Pack/Meat/Meat__x48_y96_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png` | `kitchen_sausage` | 14x11 | yes | Coiled sausage; third prep silhouette |
| food#23 | `Pixel Crawler - Free Pack/Meat/Meat__x96_y0_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png` | `bread_loaf` | 13x10 | yes | Slit loaf on the bar |
| food#28 | `Pixel Crawler - Free Pack/Meat/Meat__x128_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Meat.png` | `tableware` | 10x9 | yes | Meat pie; table dressing |
| tool#26 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x592_y336_w16_h30.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `broom` | 16x30 | yes | Broom by the door |
| station#8 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x210_y70_w78_h74.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `kitchen_station` | 78x74 | yes | Stove and counters as one mass; conditional |
| station#35 | `Pixel Crawler - Free Pack/Cooking Station_Cooking Station/Cooking Station_Cooking Station__x144_y101_w48_h27.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Cooking Station.png` | `prep_counter` | 48x27 | no | Counter with pot and bowls |
| station#45 | `Pixel Crawler - Free Pack/Butchery_Butchery_02/Butchery_Butchery_02__x16_y16_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Butchery/Butchery_02.png` | `butcher_block` | 32x29 | no | Cleaver block with meat; prep zone |
| door#8 | `Pixel Crawler - Free Pack/Furniture/Furniture__x112_y388_w32_h24.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `wall_cupboard` | 32x24 | yes | Two-panel warm wood cupboard for the kitchen wall |
| door#9 | `Pixel Crawler - Free Pack/Furniture/Furniture__x134_y283_w20_h37.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `door_room` | 20x37 | yes | Plain plank door, tall sibling of door_room 14x20 |
| window#10 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x64_y176_w28_h48.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `window_interior` | 28x48 | yes | Head-on brown four-pane with sill; no tilt |
| wall_module#25 | `Pixel Crawler - Free Pack/Interior_Walls_01/Interior_Walls_01__x368_y128_w16_h80.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Walls_01.png` | `pillar` | 12x61 | yes | Grey-capped timber post for the common room |
| table#9 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x0_y32_w48_h64.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `wardrobe` | 48x64 | yes | Recut 32x50 wardrobe from the composite; guest rooms |
| table#20 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x80_y7_w32_h35.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `table_round` | 32x35 | yes | Round pedestal table for the table clusters |
| table#33 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x166_y261_w20_h20.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `chopping_block` | 20x20 | yes | Round wooden block for the prep counter |
| seat#9 | `Pixel Crawler - Free Pack/Furniture/Furniture__x114_y489_w12_h20.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `chair` | 12x20 | yes | Wooden chair, side facing left |
| seat#10 | `Pixel Crawler - Free Pack/Furniture/Furniture__x130_y489_w11_h20.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `chair` | 11x20 | yes | Wooden chair, side facing right |
| seat#13 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x81_y82_w14_h14.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `stool` | 14x14 | yes | Free-standing dark stool |
| shelf#3 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x64_y151_w48_h20.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `hanging_shelf` | 48x20 | yes | Plank on two chains for the back bar |
| shelf#7 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x134_y178_w36_h8.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `wall_shelf` | 36x8 | yes | Pale plank wall shelf for bottles |
| bed#2 | `Pixel Crawler - Free Pack/Furniture/Furniture__x32_y149_w32_h54.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `bed_room` | 32x54 | yes | Single bed, white sheet, dark frame: guest rooms |
| rug#3 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x336_y304_w176_h80.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `rug` | 176x80 | yes | Recut: tan cross rugs; olive mats are a by-product |
| rug#8 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x0_y0_w64_h16.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `doormat` | 64x16 | yes | Recut two dark rounded mats for the thresholds |
| rug#10 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x48_y400_w48_h48.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `rug` | 38x40 | yes | Red floral rug, hearth warmth |
| rug#13 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x48_y448_w32_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `rug_small` | 32x32 | yes | Red rug with dark centre, 2x2 cells |
| lamp#19 | `Pixel Crawler - Free Pack/Bonfire_Fire_02-Sheet/Bonfire_Fire_02-Sheet__x96_y16_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Fire_02-Sheet.png` | `lamp_flame_overlay` | 9x14 | no | Small flame: lit overlay the candelabra ruling requires |
| decor#14 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x584_y7_w16_h17.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `wall_trophy` | 16x17 | yes | Bear head trophy over the hearth |

### Riverfarm and the witch hollow (42)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_b#5 | `Pixel Crawler - Free Pack/Farm/Farm__x80_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `crop_row` | 16x16 | yes | Mature cabbage, straight 16x16; closes the mature-crop generation ask |
| plant_b#8 | `Pixel Crawler - Free Pack/Farm/Farm__x80_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `crop_row` | 16x15 | yes | Mature cauliflower with leaves, no baked soil |
| plant_b#10 | `Pixel Crawler - Free Pack/Farm/Farm__x80_y192_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `crop_row` | 10x23 | yes | Turnip with shoot; root-crop row member |
| plant_b#13 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x96_y176_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `crop_row` | 14x15 | yes | Green corn stalks, growing stage |
| plant_b#14 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x96_y224_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `crop_row` | 14x15 | yes | Ripe yellow corn stalks; growth stage of #13, kept on purpose |
| plant_b#19 | `Pixel Crawler - Free Pack/Farm/Farm__x64_y48_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `crop_row` | 11x14 | yes | Beetroot in the ground |
| plant_b#39 | `Pixel Crawler - Free Pack/Farm/Farm__x64_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `crop_row` | 9x12 | yes | Carrot with top; matches the context's garden patch |
| plant_c#6 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x176_y176_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `crop_row` | 7x11 | yes | Single young stalk; seedling stage before #13 |
| fx#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x384_y192_w32_h64.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `torch_glow` | 26x62 | yes | Tall amber cone; pairs with sconce__alt2 open-flame bracket at night |
| resource#24 | `Pixel Crawler - Sewer/Props/Props__x1_y226_w61_h30.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `lumber_stack` | 61x30 | yes | Stacked lumber, 4 cells; the mill's visible output |
| sack#2 | `Pixel Crawler - Free Pack/Farm/Farm__x0_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `seed_sack` | 15x16 | yes | Tied pouch with grain mark; garden patch |
| sack#8 | `Pixel Crawler - Free Pack/Farm/Farm__x0_y192_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `seed_sack_flat` | 16x12 | yes | Flat tan seed bag; reads on turf |
| container#5 | `Pixel Crawler - Free Pack/Furniture/Furniture__x0_y132_w32_h12.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `mill_trough` | 32x12 | yes | Low open trough; visible mill work equipment |
| container#11 | `Pixel Crawler - Free Pack/Furniture/Furniture__x769_y13_w14_h19.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `well_pail_full` | 14x19 | yes | Hooped pail with water; well and pens |
| container#12 | `Pixel Crawler - Free Pack/Furniture/Furniture__x785_y13_w14_h19.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `well_pail` | 14x19 | yes | Empty state of #11 |
| container#17 | `Pixel Crawler - Free Pack/Furniture/Furniture__x769_y112_w14_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `clay_pot` | 14x16 | yes | Round clay pot; longhouse domestic storage |
| container#18 | `Pixel Crawler - Free Pack/Furniture/Furniture__x769_y80_w14_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `clay_pot_full` | 14x16 | yes | Water-filled state of #17 |
| vessel#14 | `Pixel Crawler - Free Pack/Farm/Farm__x256_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `longhouse_jar` | 15x16 | yes | Plain lidded clay jar |
| vessel#15 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x514_y272_w12_h16.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `harvest_basket` | 12x16 | yes | Handled basket for the garden patch |
| food#5 | `Pixel Crawler - Free Pack/Farm/Farm__x144_y32_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `produce` | 16x24 | yes | Beet with leaves; harvest pile |
| food#11 | `Pixel Crawler - Free Pack/Farm/Farm__x96_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `produce` | 16x15 | yes | Onion; harvest pile |
| food#31 | `Pixel Crawler - Free Pack/Farm/Farm__x112_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `produce` | 9x9 | yes | Pumpkin |
| tool#8 | `Pixel Crawler - Free Pack/Sawmill_Level_2-Sheet/Sawmill_Level_2-Sheet__x560_y323_w80_h54.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Sawmill/Level_2-Sheet.png` | `saw_bench` | 80x54 | no | Crane, log and saw table; wood yard |
| tool#16 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x48_y72_w48_h40.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `wheelwright_bench` | 48x40 | no | Wooden tool-wall bench |
| tool#21 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x0_y84_w32_h28.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `tool_box` | 32x28 | no | Wooden tool box; wheelwright corner |
| tool#24 | `Pixel Crawler - Free Pack/Sawmill_Base/Sawmill_Base__x9_y22_w22_h26.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Sawmill/Base.png` | `chopping_block` | 22x26 | no | Axe in block; wood yard |
| station#37 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x1_y279_w30_h41.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `longhouse_oven_unlit` | 30x41 | yes | Small brick oven, unlit |
| station#38 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x1_y87_w30_h41.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `longhouse_oven` | 30x41 | yes | Small brick oven, lit |
| window#15 | `Pixel Crawler - Free Pack/Furniture/Furniture__x145_y384_w30_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `window_cottage` | 30x16 | yes | Small dark two-pane cottage window |
| wall_module#15 | `Pixel Crawler - Free Pack/Roofs/Roofs__x0_y80_w128_h159.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Roofs.png` | `roof_timber` | 128x159 | yes | Recut: orange plank roof and wall kit for sheds |
| wall_module#23 | `Pixel Crawler - Free Pack/Roofs/Roofs__x48_y209_w32_h31.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Roofs.png` | `roof_timber_cap` | 32x31 | yes | Gable cap of the wall_module#15 kit |
| wall_module#29 | `Pixel Crawler - Free Pack/Walls/Walls__x320_y80_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Walls.png` | `fence_end` | 16x32 | yes | Capped fence end post, left |
| wall_module#30 | `Pixel Crawler - Free Pack/Walls/Walls__x336_y80_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Walls.png` | `fence_end` | 16x32 | yes | Capped fence end post, right |
| fence#11 | `Pixel Crawler - Free Pack/Furniture/Furniture__x162_y422_w12_h23.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `mooring_post` | 12x23 | yes | Rope-looped post for the pier |
| fence#12 | `Pixel Crawler - Free Pack/Furniture/Furniture__x179_y422_w9_h23.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `fence_post` | 9x23 | yes | Tied post, NS fence module filler |
| table#21 | `Pixel Crawler - Free Pack/Alchemy_Alchemy_Table_01-Sheet/Alchemy_Alchemy_Table_01-Sheet__x160_y16_w32_h48.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Alchemy/Alchemy_Table_01-Sheet.png` | `witch_workbench` | 32x33 | no | Small desk with bottles and scales: witch-hut work object |
| seat#2 | `Pixel Crawler - Free Pack/Furniture/Furniture__x83_y432_w58_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `longhouse_bench` | 58x32 | yes | Recut two 58x14 plank benches for the communal table |
| seat#7 | `Pixel Crawler - Free Pack/Furniture/Furniture__x32_y320_w32_h12.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `bench` | 32x12 | yes | Two-cell orange plank bench; Liscor already has one |
| bed#3 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x231_y1_w34_h31.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `longhouse_bed` | 34x31 | yes | Low side-view bed with pillow, domestic |
| rug#5 | `Pixel Crawler - Free Pack/Tilesets_Floors_Tiles/Tilesets_Floors_Tiles__x80_y192_w80_h80.png` | `Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png` | `hide_rug` | 79x78 | yes | Tan hide rug for the longhouse |
| decor#9 | `Pixel Crawler - Free Pack/Farm/Farm__x240_y32_w32_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `scarecrow` | 24x47 | yes | Scarecrow for the garden patch |
| decor#13 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x552_y8_w16_h17.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `longhouse_trophy` | 16x17 | yes | Wolf head trophy, frontier longhouse |

### Pallass (38)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| container#24 | `Pixel Crawler - Free Pack/Furniture/Furniture__x786_y44_w12_h20.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `quench_tub` | 12x20 | yes | Dark tub of water beside forge heat |
| container#53 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x416_y352_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `stone_urn` | 14x24 | yes | Masonry-pattern urn in beige stone |
| item#1 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x192_y32_w16_h16.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `hot_iron` | 10x13 | no | Glowing ring workpiece beside the anvil |
| tool#6 | `Pixel Crawler - Free Pack/Anvil_Anvil_02-Sheet/Anvil_Anvil_02-Sheet__x80_y96_w79_h60.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil_02-Sheet.png` | `smithy_station` | 79x60 | no | Tool wall, bench, anvil as one mass |
| tool#7 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x112_y115_w80_h56.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `forge_hall_bench` | 80x56 | no | Steel pegboard bench; slate palette |
| station#1 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x224_y160_w32_h48.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `crucible_stand` | 28x44 | no | Molten crucible on pedestal; contained heat |
| station#17 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x53_y133_w38_h59.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `forge_furnace` | 38x59 | yes | Iron furnace, lit |
| station#18 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x53_y325_w38_h59.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `forge_furnace_unlit` | 38x59 | yes | Unlit state of #17 |
| station#28 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x52_y207_w37_h49.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `smelter_stone` | 37x49 | yes | Boulder smelter, lit |
| station#29 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x52_y15_w37_h49.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `smelter_stone_unlit` | 37x49 | yes | Unlit state of #28 |
| station#49 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x0_y169_w32_h23.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `forge_hearth` | 32x23 | yes | Squat iron hearth, lit |
| station#50 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x0_y361_w32_h23.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `forge_hearth_unlit` | 32x23 | yes | Unlit state of #49 |
| station#52 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x1_y147_w30_h22.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `forge_basin` | 30x22 | yes | Steel basin pedestal, ember top |
| station#53 | `Pixel Crawler - Free Pack/Furnace_Furnace/Furnace_Furnace__x1_y339_w30_h22.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Furnace/Furnace.png` | `forge_basin_unlit` | 30x22 | yes | Unlit state of #52 |
| pipe#1 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x117_y147_w38_h42.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `forge_pit` | 38x42 | no | Glowing square hatch; molten channel cover |
| pipe#2 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x117_y195_w38_h42.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `forge_pit_unlit` | 38x42 | no | Unlit state of #1 |
| other_b#24 | `Pixel Crawler - Library/Tiles/Tiles__x240_y208_w32_h32.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `bronze_figure` | 22x27 | yes | Copper construct figure; bronze civic ornament, conditional |
| door#7 | `Pixel Crawler - Free Pack/Furniture/Furniture__x198_y281_w20_h39.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `door` | 20x39 | yes | Plain plank door in a pale stone rim; den shop |
| window#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x160_y96_w32_h96.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `window_lancet_lit` | 32x74 | yes | Tall stone lancet lit orange: forge hall at night |
| window#2 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x208_y96_w32_h96.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `window_lancet` | 32x74 | yes | Unlit day state of window#1; stone city facade |
| window#3 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x240_y0_w32_h48.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `blind_arch` | 24x42 | yes | Grey stone blind arch for tier_wall relief |
| window#4 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x192_y96_w16_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `window_small_lit` | 16x32 | yes | Cell-wide lit lancet; forge interior glow outdoors |
| window#5 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x240_y96_w16_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `window_small` | 16x32 | yes | Unlit lattice lancet, day state of window#4 |
| window#6 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x192_y128_w16_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `window_slit` | 12x22 | yes | Small dark arch slit for upper tiers |
| wall_module#6 | `Pixel Crawler - Cemetery 0.4/Roof/Roof__x96_y0_w96_h96.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Roof.png` | `roof` | 72x96 | no | Dark slate gable: Pallass slate vocabulary |
| wall_module#7 | `Pixel Crawler - Cemetery 0.4/Roof/Roof__x96_y96_w96_h96.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Roof.png` | `roof_gable` | 72x96 | no | Slate roof with gable triangle, second module |
| fence#1 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x144_y272_w64_h32.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `ember_channel` | 64x22 | no | Bowl plus ember trough: the contained molten channel |
| fence#2 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x176_y304_w32_h16.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `ember_channel_short` | 32x14 | no | Short ember module, extends fence#1 |
| table#1 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x128_y112_w32_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `stone_counter` | 28x32 | yes | Beige stone block counter for the den shop |
| table#2 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x128_y144_w32_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `permit_desk` | 28x32 | yes | Stone desk with blue slot: lift-station permit desk |
| table#3 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x128_y80_w32_h32.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `stone_counter_low` | 28x26 | yes | Lower beige block, counter end |
| seat#11 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x66_y3_w12_h18.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `chair` | 12x18 | yes | Dark grey tall-back chair, side view |
| seat#12 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x67_y34_w11_h18.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `chair` | 11x18 | yes | Dark grey arched-back chair, front view |
| rug#1 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x272_y0_w48_h80.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `forge_runner` | 28x61 | no | Dark red chevron runner, forge heat palette |
| lamp#3 | `Pixel Crawler - Free Pack/Bonfire_Bonfire_09-Sheet/Bonfire_Bonfire_09-Sheet__x0_y0_w64_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_09-Sheet.png` | `molten_channel` | 61x26 | no | Long stone trough of glowing coals, contained heat |
| lamp#9 | `Pixel Crawler - Free Pack/Bonfire_Bonfire_04-Sheet/Bonfire_Bonfire_04-Sheet__x0_y0_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_04-Sheet.png` | `iron_stove` | 29x19 | no | Red-hot iron stove box, forge dressing |
| lamp#28 | `Pixel Crawler - Library/Tiles/Tiles__x0_y240_w16_h48.png` | `Pixel Crawler - Library/Pixel Crawler - Library/Assets/Tiles.png` | `crystal_lamp` | 12x39 | yes | Bronze chain cage with cold crystal glow, lit |
| decor#11 | `Pixel Crawler - Free Pack/Furniture/Furniture__x772_y165_w8_h41.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `lift_chain` | 8x41 | yes | Hanging chain with hook: lift-station rigging |

### Floodplains (13)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#23 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x0_y96_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `shrub` | 43x43 | yes | Green round bush, native Free Pack style, sibling of bush_green |
| plant_a#24 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x144_y96_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `shrub` | 43x43 | yes | Orange-red bush; matches the orange trees in the context shot |
| item#17 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x352_y176_w32_h12.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `camp_bow` | 32x12 | no | Goblin bow by the lookout |
| station#22 | `Pixel Crawler - Free Pack/Cooking Station_Cooking Station/Cooking Station_Cooking Station__x11_y67_w42_h51.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Cooking Station.png` | `camp_cookpot` | 42x51 | no | Tripod pot over fire; camp cooking |
| fence#6 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x13_y20_w49_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `camp_rack` | 49x32 | yes | Rough timber rail with hooks: goblin drying rack |
| structure#3 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x11_y67_w42_h50.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `camp_tripod` | 42x50 | yes | Stick tripod to hang the camp cookpot |
| structure#13 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x352_y184_w48_h87.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `camp_signboard` | 48x87 | no | Recut: crude braced plank board, goblin camp sign |
| sign#8 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x288_y336_w32_h64.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `camp_banner` | 32x57 | no | Tattered hide banner with red skull: Rags's camp |
| sign#9 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x320_y336_w16_h64.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `camp_banner_narrow` | 16x59 | no | Narrow tattered banner, second silhouette |
| lamp#4 | `Pixel Crawler - Free Pack/Cooking Station_Cooking Station/Cooking Station_Cooking Station__x13_y20_w49_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Cooking Station.png` | `camp_spit` | 49x32 | no | Tripod spit with meat over fire: rubric's cooking spit |
| lamp#12 | `Pixel Crawler - Free Pack/Bonfire_Bonfire/Bonfire_Bonfire__x4_y24_w24_h19.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | `camp_firepit` | 24x19 | no | Small laid fire ring beside the cookpot |
| lamp#15 | `Pixel Crawler - Free Pack/Cooking Station_Cooking Station/Cooking Station_Cooking Station__x22_y35_w20_h19.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Cooking Station.png` | `camp_fire_lit` | 20x19 | no | Small log fire, lit; camp cooking cluster |
| lamp#23 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x272_y160_w48_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `camp_firepit_large` | 38x37 | no | Wide stone ring, dark earth: camp centre pit |

### Sewers (27)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#1 | `Pixel Crawler - Cave/Tiles/Tiles__x177_y208_w76_h80.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `fungus_red` | 76x80 | yes | Red trumpet fungus cluster, L; second fungus family for deep tunnels |
| plant_a#3 | `Pixel Crawler - Cave/Tiles/Tiles__x193_y117_w46_h41.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `fungus_red` | 46x41 | yes | Mid step of the red trumpet family |
| plant_d#27 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x131_y199_w57_h50.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `moss_wall` | 57x50 | no | Dense dark moss mass for canal walls; value drop on grey brick |
| plant_d#33 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x48_y384_w16_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `web` | 16x16 | no | Corner cobweb; the only candidate for the sewers web role |
| plant_d#34 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x96_y384_w16_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `web` | 16x16 | no | Mirrored corner cobweb; second orientation |
| rock_a#1 | `Pixel Crawler - Cave/Tiles/Tiles__x210_y16_w12_h32.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `stalagmite` | 12x32 | yes | Tiered stalagmite, tall; deep-tunnel silhouette |
| rock_a#2 | `Pixel Crawler - Cave/Tiles/Tiles__x226_y32_w12_h16.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `stalagmite` | 12x16 | yes | Short stalagmite, cell step of #1 |
| container#13 | `Pixel Crawler - Free Pack/Furniture/Furniture__x770_y44_w12_h20.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `bucket` | 12x20 | yes | Dark iron pail; service-channel maintenance object |
| container#57 | `Pixel Crawler - Sewer/Props/Props__x129_y40_w29_h42.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `cistern` | 29x42 | yes | Plumbed barrel; service-channel identity |
| tool#34 | `Pixel Crawler - Sewer/Props/Props__x85_y32_w8_h14.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `brush` | 8x14 | yes | Scrub brush; maintenance object |
| pipe#6 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x112_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `floor_grate` | 16x16 | yes | Barred floor drain |
| pipe#9 | `Pixel Crawler - Sewer/Tiles/Tiles__x199_y240_w50_h32.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `outfall_arch` | 50x32 | no | Big barred outfall arch, 3x2 cells |
| pipe#10 | `Pixel Crawler - Sewer/Tiles/Tiles__x299_y3_w26_h47.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `pipe` | 26x47 | no | Riser with valve box |
| pipe#11 | `Pixel Crawler - Sewer/Tiles/Tiles__x272_y3_w16_h67.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `pipe` | 16x67 | no | Tall riser with T head |
| pipe#12 | `Pixel Crawler - Sewer/Props/Props__x1_y160_w13_h64.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `pipe` | 13x64 | yes | Plain vertical run |
| pipe#13 | `Pixel Crawler - Sewer/Tiles/Tiles__x336_y19_w64_h13.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `pipe` | 64x13 | no | Bracketed horizontal run, 4 cells |
| pipe#14 | `Pixel Crawler - Sewer/Props/Props__x130_y4_w28_h28.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `pipe_junction` | 28x28 | yes | Copper junction box |
| pipe#15 | `Pixel Crawler - Sewer/Props/Props__x86_y103_w39_h18.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `pipe` | 39x18 | yes | Inverted-U bridge over the channel |
| pipe#17 | `Pixel Crawler - Sewer/Props/Props__x0_y148_w48_h10.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `pipe` | 48x10 | yes | Plain horizontal run, 3 cells |
| pipe#18 | `Pixel Crawler - Sewer/Tiles/Tiles__x200_y273_w32_h15.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `drain_mouth` | 32x15 | no | Low barred drain at water's edge |
| pipe#19 | `Pixel Crawler - Sewer/Props/Props__x129_y103_w25_h18.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `pipe` | 25x18 | yes | S-bend elbow |
| pipe#21 | `Pixel Crawler - Sewer/Props/Props__x163_y0_w10_h42.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Props.png` | `chain` | 10x42 | yes | Hanging chain; pier dressing |
| pipe#23 | `Pixel Crawler - Sewer/Tiles/Tiles__x340_y3_w24_h13.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `pipe` | 24x13 | no | Short end elbow |
| door#4 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x134_y186_w36_h38.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `service_door` | 36x38 | yes | Riveted plank door with porthole: service-channel maintenance door |
| door#10 | `Pixel Crawler - Free Pack/Interior_Props_01/Interior_Props_01__x434_y116_w28_h22.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Interior/Interior_Props_01.png` | `service_hatch` | 28x22 | yes | Round-cornered steel hatch on the canal wall |
| wall_module#9 | `Pixel Crawler - Cemetery 0.4/Walls/Walls__x96_y209_w32_h55.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png` | `wall_pier` | 32x55 | yes | Grey stone pier for the canal wall |
| structure#2 | `Pixel Crawler - Free Pack/Furniture/Furniture__x99_y624_w42_h111.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `access_ladder` | 42x111 | yes | Trim height: rung ladder between posts, rubric's access ladder |

### Ruin (19)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#20 | `Pixel Crawler - Free Pack/Tilesets_Dungeon_Tiles/Tilesets_Dungeon_Tiles__x163_y7_w57_h50.png` | `Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png` | `ivy_wall` | 57x50 | no | Ivy mass with clear leaves; overgrowth on the ruin's grey masonry |
| rock_a#11 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x112_y178_w64_h59.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `masonry_pile` | 64x59 | no | Dressed grey blocks with carved panel; a broken architectural mass |
| rock_a#14 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x0_y199_w32_h25.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `masonry_pile` | 32x25 | no | Small dressed-block heap; cell-plus step of #11 |
| debris#1 | `Pixel Crawler - Desert/Ground/Ground__x177_y178_w14_h14.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Ground.png` | `debris` | 14x14 | no | Cut stone block; rubble with a masonry read (recolour, Notes) |
| debris#2 | `Pixel Crawler - Desert/Ground/Ground__x162_y180_w13_h9.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Ground.png` | `debris` | 13x9 | no | Fallen block, flat; second rubble silhouette |
| debris#3 | `Pixel Crawler - Desert/Ground/Ground__x180_y196_w8_h9.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Ground.png` | `debris` | 8x9 | no | Upright block fragment; third silhouette |
| debris#5 | `Pixel Crawler - Free Pack/Furniture/Furniture__x736_y129_w32_h15.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `debris` | 32x15 | yes | Charred timber wreck; fourth rubble silhouette, 2 cells |
| debris#25 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x96_y144_w48_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `fallen_beam` | 40x42 | no | Collapsed beam, leaning left; broken-structure mass |
| debris#26 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x144_y144_w48_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `fallen_beam` | 40x41 | no | Collapsed beam, leaning right; pair with #25 |
| container#51 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x400_y352_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `urn` | 16x21 | yes | Blocky weathered urn; excavated pottery |
| vessel#29 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x416_y400_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `debris` | 14x12 | yes | Broken pot half; distinct rubble silhouette |
| vessel#30 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x400_y407_w16_h9.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `debris` | 16x9 | yes | Flat potsherd; second shard shape |
| tool#19 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x48_y14_w48_h34.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `dig_pile` | 48x34 | no | Rubble with tools; excavation edge |
| tool#22 | `Pixel Crawler - Free Pack/Workbench_Workbench/Workbench_Workbench__x0_y23_w32_h25.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | `debris` | 32x25 | no | Small rubble with saw; rubble silhouette |
| wall_module#2 | `Pixel Crawler - Cemetery 0.4/Walls/Walls__x3_y213_w90_h126.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png` | `wall_enclosure` | 90x126 | yes | Recut: grey mossy block walls, broken masses on cool field |
| wall_module#10 | `Pixel Crawler - Cemetery 0.4/Walls/Walls__x32_y261_w32_h30.png` | `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Walls.png` | `wall_stub` | 32x30 | yes | Grey block stub, already cool; no desaturation needed |
| lamp#6 | `Pixel Crawler - Free Pack/Bonfire_Bonfire_02-Sheet/Bonfire_Bonfire_02-Sheet__x0_y0_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_02-Sheet.png` | `campfire_lit` | 30x29 | no | Lit rock-ring fire: the dig camp's light |
| lamp#7 | `Pixel Crawler - Free Pack/Bonfire_Bonfire/Bonfire_Bonfire__x2_y72_w28_h21.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | `campfire` | 28x21 | no | Laid, unlit state of lamp#6 |
| lamp#8 | `Pixel Crawler - Free Pack/Bonfire_Bonfire/Bonfire_Bonfire__x34_y72_w28_h21.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | `campfire_dead` | 28x21 | no | Burnt-out state; abandoned camp |

### Dungeon (9)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| rock_a#18 | `Pixel Crawler - Free Pack/Rocks/Rocks__x144_y272_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `crystal` | 12x25 | yes | Blue crystal spike; self-lit value separation for the vault approach |
| debris#28 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x240_y176_w32_h32.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `fallen_beam` | 32x22 | no | Short diagonal beam; distinct rubble silhouette for halls |
| debris#29 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x160_y112_w48_h32.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `fallen_plank` | 39x18 | no | Low-angle plank, 3 cells; breaks dungeon_rubble repeats |
| container#3 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x128_y272_w16_h32.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `brazier` | 16x19 | no | Lit coal basket; fills the dungeon brazier ask |
| door#12 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x272_y0_w32_h48.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `door_halls` | 30x34 | no | Olive double door, iron band, lock plate: trapped halls |
| lamp#5 | `Pixel Crawler - Free Pack/Bonfire_Bonfire_10-Sheet/Bonfire_Bonfire_10-Sheet__x0_y0_w48_h32.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_10-Sheet.png` | `brazier` | 39x31 | no | Stone coal box, pale rim: the hall floor brazier |
| lamp#24 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x400_y96_w16_h32.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `candle_stand` | 8x22 | no | Lit candle on a stone base; keep one frame |
| decor#2 | `Pixel Crawler - Castle Environment 0.3/Tiles/Tiles__x272_y112_w32_h48.png` | `Pixel Crawler - Castle Environment 0.3/Pixel Crawler - Castle Environment 0.3/Assets/Tiles.png` | `bust_hooded` | 18x32 | yes | Hooded pale bust, cell scale, ward dressing |
| decor#6 | `Pixel Crawler - Forge 1.2/Tiles/Tiles__x192_y144_w32_h64.png` | `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | `idol_lit` | 28x58 | no | Red idol with glowing mouth: lit landmark in dark halls |

### Garden of Sanctuary (15)

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | role | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_c#32 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x144_y256_w48_h112.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `cypress` | 31x98 | yes | Columnar cypress; formal tree the lawn lacks, planted-shelter pocket |
| plant_c#34 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x112_y304_w32_h48.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `hedge` | 24x38 | yes | Clipped column topiary for hedge breaks (trim stray shadow, see Notes) |
| plant_c#35 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x304_y240_w32_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `pond_lily` | 31x23 | yes | Lily pad with pink bud for the fountain pocket (baked water, Notes) |
| plant_c#36 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x160_y368_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `flower_mass` | 16x23 | yes | Blue flower clump; R7 blossom pool |
| plant_c#37 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x160_y416_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `flower_mass` | 16x23 | yes | Orange flower clump |
| plant_c#38 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x192_y368_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `flower_mass` | 16x23 | yes | Pink flower clump |
| plant_c#39 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x192_y416_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `flower_mass` | 16x23 | yes | White flower clump; four colours make the pool |
| rock_b#26 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x368_y352_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `stepping_stone` | 13x13 | yes | Stone on water; path across the fountain pocket |
| rock_b#28 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x384_y352_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `stepping_stone` | 10x12 | yes | Smaller stepping stone; two sizes make a path |
| container#52 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x416_y320_w16_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `memorial_urn` | 14x24 | yes | Tall pale urn; restrained memorial rise |
| structure#10 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x320_y160_w80_h48.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `pool` | 58x39 | yes | Pale stone-rimmed reflecting pool, memorial rise |
| structure#12 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x336_y0_w48_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `small_pool` | 26x23 | yes | Small octagonal basin for the planted pocket |
| seat#18 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x64_y368_w80_h32.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `bench` | 74x32 | yes | Recut two 74x14 slat benches: the resting seat |
| decor#17 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x416_y416_w32_h64.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `statue` | 28x54 | yes | Tall pale classical statue, planted pocket |
| decor#18 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x448_y432_w32_h48.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `statue` | 25x42 | yes | Dancing figure statue, second silhouette |

### Scatter (64)

Ground dressing from the new sheets. The role column lists the regions, best fit first.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | regions | size | bundled | reason |
|---|---|---|---|---|---|---|
| plant_a#5 | `Pixel Crawler - Cave/Tiles/Tiles__x100_y176_w42_h30.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `sewers,dungeon,ruin` | 42x30 | yes | Small red trumpet cluster, low and wide |
| plant_a#8 | `Pixel Crawler - Cave/Tiles/Tiles__x180_y164_w19_h25.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `sewers,dungeon` | 19x25 | yes | Single red horn, cell-plus |
| plant_a#9 | `Pixel Crawler - Cave/Tiles/Tiles__x240_y0_w13_h32.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `sewers,dungeon,riverfarm` | 13x32 | yes | Teal stalk with lit buds; self-lit for [Light]-off reads, hollow too |
| plant_a#11 | `Pixel Crawler - Cave/Tiles/Tiles__x258_y3_w11_h11.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `sewers,dungeon,ruin` | 11x11 | yes | Tiny brown cap, pebble-scale fungus |
| plant_a#18 | `Pixel Crawler - Desert/Ground/Ground__x161_y80_w14_h16.png` | `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Ground.png` | `ruin,floodplains` | 14x16 | no | Dry tan grass tuft; reads on the dark dig field |
| plant_a#27 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x192_y96_w48_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `ruin,floodplains` | 39x46 | yes | Bare dead sapling, cell-plus; ruin field vocabulary |
| plant_a#28 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x192_y64_w48_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `ruin,floodplains` | 34x31 | yes | Wide dead shrub, second bare silhouette |
| plant_a#29 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x112_y160_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm` | 32x26 | yes | Green reed pair; pond and river edge |
| plant_a#31 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x112_y256_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,ruin` | 32x26 | yes | Dry reed pair for autumn edges and the dig field |
| plant_a#32 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x144_y0_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm` | 29x27 | yes | Small orange bush, cell-plus autumn accent |
| plant_a#33 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x48_y0_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden` | 29x27 | yes | Small lime bush, cell-plus |
| plant_a#35 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x80_y144_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `liscor,invrisil,garden,riverfarm` | 31x25 | yes | Broad-leaf plant; the Liscor street already uses this family |
| plant_a#44 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x144_y208_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm` | 15x26 | yes | Tall single cattail |
| plant_a#48 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x64_y176_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden,liscor` | 16x21 | yes | Cell-size leafy plant, small step of #35 |
| plant_b#7 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x208_y160_w16_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `garden,riverfarm,floodplains` | 9x27 | yes | Pink foxglove stalk; tall flower for the planted pocket |
| plant_b#9 | `Pixel Crawler - Free Pack/Farm/Farm__x96_y112_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `riverfarm,liscor,floodplains` | 16x15 | yes | Round hay tangle; new straw silhouette for pens and stalls |
| plant_b#21 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x16_y352_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `sewers,dungeon,riverfarm` | 11x14 | yes | Blue toadstool; cold accent for tunnels and the hollow |
| plant_b#24 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x160_y176_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm` | 9x16 | yes | Short single cattail, cell size |
| plant_b#41 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x80_y176_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden,liscor` | 12x9 | yes | Three-blade sprout tuft, native style |
| plant_b#48 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x32_y144_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden` | 10x9 | yes | Tiny two-leaf tuft, finest scatter grain |
| plant_c#2 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x64_y160_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden,liscor,invrisil` | 11x8 | yes | Low leafy tuft; works on grass and paving |
| plant_c#9 | `Pixel Crawler - Free Pack/Tilesets_Dungeon_Tiles/Tilesets_Dungeon_Tiles__x162_y1_w12_h6.png` | `Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png` | `ruin,dungeon` | 12x6 | no | Dark sprout; only reads on the ruin's mid-brown field |
| plant_c#25 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x96_y368_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `garden,floodplains,riverfarm` | 8x7 | yes | White daisy, four petals |
| plant_c#26 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x96_y384_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `garden,floodplains,riverfarm` | 8x7 | yes | Blue flower, same grain |
| plant_c#27 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x96_y400_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `garden,floodplains,riverfarm` | 8x7 | yes | Yellow flower |
| plant_c#28 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x96_y416_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `garden,floodplains,riverfarm` | 8x7 | yes | Orange-red flower |
| plant_c#44 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x16_y384_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,riverfarm,floodplains` | 13x9 | yes | Dark olive tuft; shadow-side grass |
| plant_c#45 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x224_y304_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm,invrisil` | 9x11 | yes | Single pink flower on stem |
| plant_c#46 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x224_y336_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm,invrisil` | 9x11 | yes | Single blue flower |
| plant_c#47 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x224_y368_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm,invrisil` | 9x11 | yes | Single red flower |
| plant_c#48 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x224_y400_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm,invrisil` | 9x11 | yes | Single white flower |
| plant_d#12 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x304_y272_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains` | 8x10 | yes | Single small lily pad; pond and fountain water |
| plant_d#13 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x256_y304_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm` | 7x11 | yes | Pink square bloom; tulip silhouette, distinct from the round set |
| plant_d#14 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x256_y336_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm` | 7x11 | yes | Blue tulip |
| plant_d#15 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x256_y368_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm` | 7x11 | yes | Red tulip |
| plant_d#16 | `Pixel Crawler - Garden Environment/Tiles/Tiles__x256_y400_w16_h16.png` | `Pixel Crawler - Garden Environment/Pixel Crawler - Garden Environment/Assets/Tiles.png` | `garden,floodplains,riverfarm` | 7x11 | yes | White tulip |
| plant_d#35 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x210_y278_w11_h7.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `sewers,dungeon` | 11x7 | no | Dark moss sprig, cell debris grain |
| plant_d#44 | `Pixel Crawler - Sewer/Tiles/Tiles__x147_y242_w41_h23.png` | `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | `sewers,dungeon,ruin` | 41x23 | no | Sprawling floor moss patch, multi-cell |
| rock_a#3 | `Pixel Crawler - Cave/Tiles/Tiles__x209_y66_w13_h12.png` | `Pixel Crawler - Cave/Pixel Crawler - Cave/Assets/Tiles.png` | `ruin,riverfarm,floodplains` | 13x12 | yes | Brown angular rock, cell |
| rock_a#13 | `Pixel Crawler - Free Pack/Rocks/Rocks__x0_y112_w32_h48.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `floodplains,ruin,riverfarm` | 28x43 | yes | Tall ochre spire; vertical rock the pools lack |
| rock_a#15 | `Pixel Crawler - Free Pack/Rocks/Rocks__x128_y16_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `sewers,dungeon,pallass,ruin` | 26x27 | yes | Grey round boulder; cool palette for underground and stone city |
| rock_a#16 | `Pixel Crawler - Free Pack/Rocks/Rocks__x32_y112_w32_h32.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `floodplains,riverfarm` | 26x27 | yes | Tan round boulder, native Free Pack style |
| rock_a#19 | `Pixel Crawler - Free Pack/Rocks/Rocks__x176_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `sewers,dungeon,pallass,ruin` | 16x14 | yes | Grey angular rock, cell |
| rock_a#21 | `Pixel Crawler - Free Pack/Rocks/Rocks__x80_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `floodplains,riverfarm` | 16x14 | yes | Tan angular rock, cell |
| rock_a#22 | `Pixel Crawler - Free Pack/Rocks/Rocks__x160_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `sewers,dungeon,pallass` | 14x11 | yes | Grey flat rock, second cell silhouette |
| rock_a#24 | `Pixel Crawler - Free Pack/Rocks/Rocks__x64_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `floodplains,riverfarm` | 14x11 | yes | Tan flat rock |
| rock_a#26 | `Pixel Crawler - Free Pack/Rocks/Rocks__x176_y288_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `dungeon,sewers,riverfarm` | 10x15 | yes | Small blue crystal; cell step of #18, hollow glow dressing |
| rock_b#1 | `Pixel Crawler - Free Pack/Rocks/Rocks__x32_y48_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `floodplains,riverfarm` | 10x7 | yes | Tan pebble, native style |
| rock_b#2 | `Pixel Crawler - Free Pack/Rocks/Rocks__x144_y96_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png` | `sewers,dungeon,pallass,ruin` | 8x7 | yes | Grey pebble |
| rock_b#29 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x32_y304_w16_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `ruin,dungeon` | 14x13 | no | Dark brown rock, cell; reads on the ruin field |
| rock_b#31 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x16_y336_w16_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `sewers,dungeon` | 9x7 | no | Grey-violet pebble, cold |
| debris#6 | `Pixel Crawler - Free Pack/Sawmill_Base/Sawmill_Base__x224_y55_w22_h13.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Sawmill/Base.png` | `riverfarm,liscor` | 22x13 | no | Sawdust heap; wood yard and wheelwright corner |
| debris#8 | `Pixel Crawler - Free Pack/Bonfire_Bonfire/Bonfire_Bonfire__x5_y316_w23_h10.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | `floodplains,riverfarm` | 23x10 | no | Kindling pile; Rags's cooking cluster, longhouse yard |
| debris#9 | `Pixel Crawler - Free Pack/Bonfire_Bonfire/Bonfire_Bonfire__x37_y364_w20_h8.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | `floodplains,ruin,dungeon` | 20x8 | no | Cold ash pile; dead campfire for the dig camp |
| debris#11 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x272_y0_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden,ruin` | 11x14 | yes | Forked twig, brighter than the Fairy Forest twigs |
| debris#15 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x288_y16_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `floodplains,riverfarm,garden,ruin` | 13x9 | yes | Bent twig, second silhouette |
| debris#33 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x240_y160_w32_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `ruin,dungeon,sewers` | 32x12 | no | Two crossed planks, flat |
| debris#34 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x240_y208_w48_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `ruin,dungeon,sewers,riverfarm` | 48x8 | no | Long flat plank, 3 cells; pier and dig-camp dressing |
| resource#6 | `Pixel Crawler - Free Pack/Furniture/Furniture__x82_y593_w29_h29.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `riverfarm,liscor,ruin` | 29x29 | yes | Leaning plank, left; yard and dig-camp dressing |
| resource#7 | `Pixel Crawler - Free Pack/Furniture/Furniture__x146_y561_w28_h29.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Furniture.png` | `riverfarm,liscor,ruin` | 28x29 | yes | Leaning plank, right; pair with #6 |
| resource#13 | `Pixel Crawler - Free Pack/Sawmill_Base/Sawmill_Base__x9_y113_w14_h15.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Sawmill/Base.png` | `riverfarm,liscor` | 14x15 | no | Cut log round, end-on; wood yard |
| resource#16 | `Pixel Crawler - Free Pack/Vegetation/Vegetation__x240_y128_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Vegetation.png` | `riverfarm,liscor,ruin` | 12x11 | yes | Bundle of three stakes; survey stakes and fence stock |
| wall_module#36 | `Pixel Crawler - Free Pack/Walls/Walls__x0_y688_w16_h12.png` | `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Walls.png` | `ruin,sewers,dungeon,pallass` | 16x12 | yes | Two grey dressed blocks, rubble scatter |
| lamp#16 | `Pixel Crawler - Free Pack/Bonfire_Bonfire/Bonfire_Bonfire__x1_y123_w30_h11.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | `riverfarm,floodplains,ruin` | 30x11 | no | Plain cut log, ground dressing |

### Common (7)

Generic utility for any region's pool: the shared-pool set below.

| tag | slice (under `potential_assets/_sliced/`) | source sheet (under `potential_assets/`) | kind | size | bundled | reason |
|---|---|---|---|---|---|---|
| barrel#4 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x115_y38_w9_h14.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `barrel` | 9x14 | yes | Small pale keg; smallest pool silhouette |
| barrel#7 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x240_y304_w16_h32.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `barrel` | 16x26 | no | Upright dark barrel, pale hoops; cell scale |
| barrel#8 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x256_y304_w16_h32.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `barrel` | 16x26 | no | Barrel lying on its side; distinct from upright |
| sack#12 | `Pixel Crawler - Free Pack/Farm/Farm__x256_y0_w16_h16.png` | `Pixel Crawler - Free Pack/Environment/Props/Static/Farm.png` | `sack` | 16x12 | yes | Plain brown flat sack, no label |
| sack#14 | `Pixel Crawler - Free Pack/Cooking Station_Estructure/Cooking Station_Estructure__x65_y51_w9_h10.png` | `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Estructure.png` | `sack` | 9x10 | yes | Tiny tied sack; small pool variant |
| sack#15 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x288_y96_w32_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `sack` | 22x15 | no | Wide lumpy olive sack, cross tie |
| sack#16 | `Pixel Crawler - Hideout 1.0/Tiles/Tiles__x320_y96_w16_h16.png` | `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | `sack` | 16x16 | no | Square olive sack; cell scale |

### Shared pool after the re-intake

The common kinds named by the resolver's pool rule (at least 3, ideally 4 to 6, distinct silhouettes) after the 7 common pieces above:

- **barrel: 5.** The existing hooped tub (container#25) and small keg (tool_a#26), plus barrel#4 (pale keg), barrel#7 (upright dark) and barrel#8 (lying on its side). Clears the bar.
- **sack: 4.** sack#12 (plain flat), sack#14 (tiny tied), sack#15 (wide olive), sack#16 (square olive). Clears the bar; none existed before.
- **crate: still 1.** Only the existing empty tall plank crate (container#29). The pool needs at least 3. No new sheet has a generic empty crate that is not already the in-game `crate`: the Farm crates (crate#2 to #4) are produce displays and went to Liscor. The ask is in the generation asks below.
- **container: 0.** Every new container reads as one region's object.

### Flagged (not applied)

Each item below needs a `docs/CHOICE-LOG.md` line or a user ruling before it moves anything.

- **door#14 vs identity door #1 (user ruling pending).** door#14 (`Pixel Crawler - Library/Tiles/Tiles__x160_y336_w48_h64.png`, teal door with gold tracery) is allocated to `invrisil/door_enchanter`. It would beat identity door #1 (the arched green double door) on `invrisil_shop_door_2` for the enchanter shop: the identity ruling already calls the green door weak in that role and parks it on `door_street`, and door#14 fills the shop role without the arched-glass recut ask in the Recuts section above. door#16 is its open state. The glazed `shopfront_door` keeps the other shop fronts. Nothing is moved until the user rules; the second `invrisil | shop_door` row in `docs/art-generation-list.md` stays `open` meanwhile.
- **Five rejects that need a byte check against `Building_Props`.** The architecture ruling rejected these as probably the same art as kept `Building_Props` slices: door#3 (= Liscor `door_street`, 32x44), door#5 (= Riverfarm `door_open`, 30x41), window#12 (= Liscor `window_shutter`, 32x24), window#14 (= Liscor `window_grille`, 22x22) and seat#8 (= Pallass slate bench, 30x12). Run a byte or pixel check against `Pixel Crawler - Free Pack/Environment/Structures/Buildings/Props.png` before dropping them for good. If the bytes differ they are still visual duplicates and stay out.
- **plant_d#42 beats c#27 on `liscor/planter_shrub`.** The Library potted shrub on a wooden stand already has its container; c#27 (`Fairy Forest Props__x112_y112`) is a bare bush that needs a generated tub. c#27 stays usable as a plain shrub elsewhere. crate#2 (seedlings in a crate) is a second answer to the same role.
- **crate#2 and container#50 vs the planter-base ask.** crate#2 (`liscor/planter_crate`) retires c#27 as the Liscor half of the planter-base generation ask. container#50 (`invrisil/planter_urn`, pale smooth urn) is the Invrisil half for c#36 `invrisil/topiary`; its mouth is closed, so the bush must be composited on top (recut below). If either composite does not read, the ask reopens.
- **wall_module#10 and #2 vs the ruin recolour ask.** The Cemetery grey block stub (#10) and the recut enclosure (#2) are already cool grey, so they can take `ruin/wall_stub` and `ruin/wall_enclosure` and the Desert ochre stubs' desaturation ask can be dropped; or the Desert stubs stay as the ochre pair for variety. Conditional.
- **station#8 `inn/kitchen_station`** overlaps the hearth and grill and the owned set pieces (`kitchen_prep_counter`, `inn_hearth`). Kept only as a blockout audition for the inn's north wall or a second kitchen; drop it if the owned set pieces already carry the wall. It does not replace them.
- **container#3 `dungeon/brazier`** is a cell-scale coal basket, not a standing brazier. It and lamp#5 (stone coal box) cover the dungeon brazier ask; the ruin and sewers lit-fixture asks remain open.
- **other_b#24 `pallass/bronze_figure`** (copper construct figure) is conditional on the Pallass civic-ornament read.

### Recuts and recolours from the re-intake Notes

Recuts come from bundled sheets unless noted. A recolour of pack art stays bundle-tier.

**Natural ruling.**

- **debris#1 to #3** (Desert `Ground` cut blocks): cool the warm sandstone ochre to the ruin's grey-brown before they join `ruin/debris`. Unbundled sheet. Without the shift they are still the best rubble silhouettes in hand.
- **plant_c#34** (Garden topiary column): trim the stray shadow ellipse above-left of the crown, left by a neighbour on the sheet. Then it is a clean 24x38 hedge column.
- **plant_c#35** (lily pad) and **rock_b#26 / #28** (stepping stones): each bakes a teal water base. Fine on the Garden fountain if the fountain water is tinted to match; on the floodplains pond replace the base with the pond blue or recut the stones without it.
- **plant_a#21 / #22** (Vegetation `x0_y32`, `x48_y32`): each is two 48x32 bushes stacked, rejected as composites. Recut into four singles for the mid-size step between the 43x43 bushes (#23, #24) and the 29x27 bushes (#32, #33).
- **plant_a#13** (Desert Ground composite, 96x48): recut its two dead tumble-brushes as cell-scale dead scrub for the ruin field; the cacti have no region.
- **plant_c#33** (second Garden cypress, 28x97) and **plant_c#41 to #43** (alternate orange, pink and white clumps): rejected as near-duplicates; take them before generating if the R7 blockout wants a cypress pair or a blossom pool above four.
- **plant_d#28 to #32** (Hideout dark shrubs) and the tint sets: a ready night-state shrub family if a region ever ships a night variant kit. **fx#3 to #8** (Desert sand gusts, six frames): no region; recoloured grey they would serve as wind or smoke wisps. Parked, not asked for.
- **plant_b#3** (cauliflower on a baked soil square): rejected in favour of #8; the baked tile will not match the Riverfarm soil strip.

**Goods ruling.**

- **barrel#1** (Forge 1.2 `Tiles__x112_y240_w32_h32`, unbundled): two red-hooped barrels fused; the right, plain one is a second Liscor water barrel.
- **other_a#11** (Forge 1.2 `Tiles__x128_y304_w48_h16`, unbundled): three lit coal bins in a row; recut one 16x16 bin as `pallass/coal_bin_lit`.
- **other_a#23** (Interior_Props `x208_y121_w32_h23`): crate plus barrel fused; the crate half is the in-game `crate` already, so no new pool crate comes from it.
- **other_b#28** (Sewer `Props__x32_y7_w32_h25`): crate plus water tub fused; the tub half is a third sewer pail if wanted.
- **other_b#17 and #18** (Garden `Tiles__x338_y388_w78_h92`, `Tiles__x320_y274_w80_h78`): composites of pale stone planters, a cushioned seat and a lily pond with a stone rim. Recut the pond rim and the planters for the Garden's fountain and rest pocket before generating any garden furniture.
- **tool#1** (Anvil_Anvil_03 strip, unbundled): an 8-frame smithing animation; the source for a Pallass working smith station instead of a generation.
- **container#50 + c#36:** composite the topiary bush onto the urn top as one 16x~36 sprite, bottom-anchored.
- Recolours: **barrel#2** hoops from Forge red-orange to Liscor copper if it clashes; **station#28 / #29** desaturate slightly if the beige terrace stone makes the grey smelter read blue; **pipe#21** (copper chain) needs an iron-grey shift if the dungeon wants it. station#17/#18, #49/#50 and #52/#53 need no change.

**Architecture ruling.**

- **door#2:** lift the arched blue-glass window (about 20x30) from the lower half; the empty door frame above it has no role.
- **window#13:** split into two 24x12 window boxes.
- **wall_module#2:** cut the stone enclosure into straight, corner and end modules for `ruin/wall_enclosure`. **wall_module#3:** same for the iron railing corners; wall_module#11 is already the straight run.
- **wall_module#15:** split the hut kit into roof halves, plank wall and side trims (wall_module#23 is the separate cap). **wall_module#17:** split the glass roof into two gable halves.
- **table#9:** keep the 32x50 wardrobe, drop the two small cabinets. **table#10:** drop the 44x11 plank under the glass counter.
- **seat#2 and seat#18:** each is two stacked benches; cut into singles.
- **rug#3:** cut the two tan cross rugs for the inn; the four olive square mats are a by-product for the Riverfarm longhouse. **rug#8:** two door mats.
- **decor#10:** keep the 16x14 framed painting, drop the rod. **decor#20:** cut the curtains into left and right panels of about 30x80.
- **structure#2:** trim the ladder to about 48 high if it sits on a 3-cell wall. **structure#13:** keep the braced plank board, drop the bush and the stake (unbundled).
- **lamp#24:** four candle frames (#24 to #27) exist; keep one as the still (unbundled Hideout).
- Recolours: **lamp#28** cyan crystal to cold white if Pallass wants the white signature exactly; **rug#1** lift the dark field if the forge runner reads too black on slate.

### Generation asks that remain after the re-intake

- **Shared pool:** two generic plank crate silhouettes (a squat 16x12 and a strapped 16x20), bundle-tier, to bring `common:crate` from 1 to at least 3.
- **Pallass:** a bronze post or wall arm lamp with a cold white lamp, day and lit (lamp#28 covers only a hanging lit state); a Pallass stone door proper (door#7 is a plank door in a stone rim). The natural sheets gave no bronze fixture, cold white light or beige prop-scale stone.
- **Sewers:** one lit fixture (wall pier lamp or hanging cage lamp with local glow); still 0 lit pieces.
- **Ruin and dungeon lit fixtures:** ruin now has lamp#6, #7, #8 (campfire states) and dungeon has lamp#5, lamp#24 and decor#6, but the cold or pale light asks stand: the two amber fx cones go to Riverfarm and Liscor and do not answer them.
- **Invrisil:** a wall lantern and a tall street lamp (nothing cold steel on a lamp sheet); the Invrisil half of the planter-base ask reopens only if the container#50 composite does not read.
- **Liscor:** a brick facade module with a door or window built in, 48x55 to match wall_module#8; a weapon rack (no sheet has one; the barracks set is otherwise covered); a Runners' Guild pigeonhole grid (shelf#1 and shelf#13 cover sorting and hooks only); a three-part counter set (left, middle, right) in the table#16/#26 timber.
- **Floodplains:** Rags's camp lookout at native pixel scale. The goblin watchtower and hut slices (structure#14 to #21) are painterly art at about four times the game's pixel size and are a composition reference only.

### Generation rows retired by the re-intake

Marked in place, never deleted. `docs/art-generation-list.md` carries the three Invrisil rows; the other asks lived in the Generation asks list above or in the rulings' Notes and are marked there.

- **Riverfarm mature crop:** dropped, covered by plant_b#5 (cabbage), #8 (cauliflower), #10 (turnip), #19 (beetroot), #39 (carrot), #13/#14 (corn growing and ripe) and plant_c#6 (seedling). The three-stage row (d#56, d#48, d#26) keeps its place.
- **Planter bases (Liscor and Invrisil):** dropped. Liscor is covered by plant_d#42, crate#2 and plant_a#39/#40; Invrisil by container#50 composited with c#36.
- **Dungeon brazier:** dropped, covered by lamp#5 (stone coal-box brazier) and container#3 (lit coal basket).
- **Invrisil interior furniture (seating, rugs, display counter):** dropped, covered by seat#19/#20 (oak chair), seat#5 (settee), seat#1 (armchair), seat#3 (bench); rug#4, rug#11, rug#14; table#10, table#18, tool#18, tool#20 and table#30 (glass counters and cases).
- **Liscor barracks set, except the weapon rack:** dropped, covered by bed#4 (cot), shelf#10/#11 (lockers), table#36 (duty table), seat#6 (bench), sign#5 (Watch crest), door#6 (iron-banded door), container#6 (footlocker) and item#5/#6 (sword, shield). The weapon rack stays open.
- **Guild board wall:** dropped, covered by sign#6 (blank board) and sign#7 (written board), with structure#5 as the sign post.

### Bundle needs (bundle-v9)

Kept pieces that sit on source sheets not yet under `wandering_inn_game/assets/`. They need a `bundle-v9` release before `tools/wire_asset.py` can wire them. The other 284 new pieces are on bundled sheets.

| source sheet (under `potential_assets/`) | kept pieces |
|---|---|
| `Pixel Crawler - Hideout 1.0/Pixel Crawler - Hideout/Assets/Tiles.png` | 29 |
| `Pixel Crawler - Forge 1.2/Pixel Crawler - Forge/Assets/Tiles.png` | 10 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Workbench/Workbench.png` | 10 |
| `Pixel Crawler - Sewer/Pixel Crawler - Sewer/Assets/Tiles.png` | 7 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire.png` | 6 |
| `Pixel Crawler - Cemetery 0.4/Pixel Crawler - Cemetery/Environment/Structures/Roof.png` | 5 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Cooking Station.png` | 5 |
| `Pixel Crawler - Desert/Pixel Crawler - Desert/Assets/Ground.png` | 4 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Sawmill/Base.png` | 3 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil.png` | 2 |
| `Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png` | 2 |
| `Pixel Crawler - Free Pack/Environment/Props/Animated/Pan_04-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Alchemy/Alchemy_Table_01-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Alchemy/Alchemy_Table_02-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Anvil/Anvil_02-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_02-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_04-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_09-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Bonfire_10-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Bonfire/Fire_02-Sheet.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Butchery/Butchery_02.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Butchery/Butchery_03.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Cooking Station/Butchery/Butchery_04.png` | 1 |
| `Pixel Crawler - Free Pack/Environment/Structures/Stations/Sawmill/Level_2-Sheet.png` | 1 |
| **24 sheets** | **96** |
