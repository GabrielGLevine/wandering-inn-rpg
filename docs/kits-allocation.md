# Regional kits: piece allocation (living)

> Living document. Rulings dated 2026-10-09. The sheets were bundled in `bundle-v8` (#621).

Each kept piece goes to the region where it fits best, not to whichever region asked for it first. The rulings judged each piece on its own merits against the visual grammar and region sections of `docs/design/2026-10-05-holistic-art-review.md`, the rollout in `docs/superpowers/plans/2026-10-08-regional-kits-rollout.md`, and the day context shot of every region. List rank and pack theme played no part.

A region's pool read starts here: take that region's section and the scatter lines that name it. A piece allocated to another region moves only with a `docs/CHOICE-LOG.md` ruling, and the PR that moves it updates its line here.

- **Coverage.** 238 kept pieces: 114 plants out of 334 judged, and 124 props out of 270 judged. Rejected pieces are not listed; most were tint-only duplicates, slicer composites, item-icon scale, or had no role in any region. Identity pieces (doors, lamps, sconces, windows) are ruled in their own section below.
- **Bundling.** Every source sheet below is bundled. 114 pieces sit on five sheets that were already in the bundle, and 124 sit on the 18 sheets that `bundle-v8` added. Fetch the bundle (`scripts/fetch_private_assets.sh`) before wiring, so `tools/wire_asset.py` finds the sheet under `wandering_inn_game/assets/`.
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
| **all** | **238** |

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
- **Dungeon brazier:** a floor brazier for the halls and the vault approach. First check the harvest's uncontested standing brazier.
- **Ruin light:** a dig-camp lantern or brazier with enough pale highlight to stand out from the dark field. Same check first.
- **Sewers light:** one lit fixture for the service channel (a wall pier lamp or a hanging cage lamp with local glow), so [Light]-off reads are not all silhouette. Generate one unless the standing brazier fits a canal wall.
- **Riverfarm mature crop:** a straight 16x16 mature-crop tile (wheat or cabbage) to finish the crop row (d#56, d#48, d#26). No sheet has one.
- **Planter bases:** two 16x12 bottom-anchored bases for c#27 (Liscor) and c#36 (Invrisil), only if no container is in hand.

### Conditional and parked rulings

- **a#40** (purple giant canopy) only earns a place if the hollow canopy pool also gets silhouette variety: e#16 (teal conifer) and the b#3/b#19/b#45 hero trunk. If the pool stays at three round canopies, drop a#40 and keep e#16.
- **Frosted set** (e#14, e#15, e#23, e#37, e#53, e#54, e#55, f#7, f#8, f#10, f#12, f#16, f#19): rejected because no region uses it today. It is a complete winter set, ready for a winter floodplains or Liscor state without generation.
- **door#1** (Cemetery mausoleum composite with a pentagram rose window): rejected outright. The occult ornament has no TWI reading.
