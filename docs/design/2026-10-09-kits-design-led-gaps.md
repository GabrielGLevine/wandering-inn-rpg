# Design-led generation gaps (Fable art director, read-only, 2026-10-09)

Question answered: if every allocated piece, every Pixel Crawler sheet cell, every owned PixelLab tileset and every harvest set piece were composed into each region's scenes, and the design were allowed to bend where identity still holds, what would still have to be generated?

Inputs read: `generation-review.md`, `gen-crosscheck.md`, `docs/kits-allocation.md` (identity + 238 dormant), `newpieces/ALLOC-{natural,goods,architecture}.md` (380 new), `TILESET_LABELS.json` (105 sheets), `pc-ext/INDEX.md` + sheets, the holistic art review, the nine context shots, the R1 Liscor captures and the 1b Invrisil strip. Images opened only where a ruling depended on them: the owned tilesets (`olddark_*`, `marble_wang4x4`, `brick_over_molten`, `slate_over_void`, `ashlar_over_checker_v1`, `cobble_over_dirt_v1`, `city_wall/Tiles.png`, `prop_tier_wall`), the Pallass lamp family (`crystal_lamp`, `streetlamp_v2`, Library lamp#28), Desert Ground, Cemetery Walls, Cemetery Roof, Castle Environment Tiles, Forge Tiles, Building_Walls, Building_Roofs, Garden Tiles, Ninja Desert/House, Pixel_16 interiors.

Three findings the earlier passes missed, and that drive most of the removals:

1. **A warm brick wall system already exists, bundled.** `assets/tiles/cemetery/Walls.png` cells (12,0)-(17,12) are a tan sandstone-brick enclosure with a pale cap, face courses and corners (label brick 0.8; the dungeon uses only the dark-olive columns 0-11, so the tan cells are free). (12,12)-(14,15) adds a brick pier with a small arched door and an iron fence. Together with the owned `city_gate_arch` / `city_gatehouse` (GH#184, grey, recolourable because they are owned) this is Liscor's city wall and gate without a generation.
2. **Owned tilesets cover two Invrisil asks.** `assets/tiles/harvest/ashlar_over_checker_v1.png` is literally "pale/dark checker floor under a dark ashlar wall" (the 3b ashlar work-room variant and a checker floor in one); `tileset_marble_wang4x4.png` is a 16-id Wang set, so its edge and corner ids are the marble curb the #608 read asked for. The boulevard draws only the full-marble id today; the curb is a data fix.
3. **Pallass already owns its identity lamp.** `crystal_lamp` (owned, 32x64, placed 10x) is a bronze post with a white lamp, exactly the brief. Its "lit state" is a glow overlay, not a new object. The Castle sheet (bundled) carries the glow cones (fx#1/#2 at (23-24,12-15)) and a lit lancet pair; a cold-white copy of a glow cone is a light effect, not a second silhouette, so the tint rule does not apply.

Cost basis (brief): tileset 3-4, Pro Flash object 5-6, object state 10-25, building kit 10-25, pro character 10-25 + 8 per animation; 2-3 attempts per asset.

---

## Liscor (R1)

**Current read (R1 captures):** tan plaster band, copper sconces, cream half-timber facades under orange hipped roofs, cobble-and-dirt street, grey castle wall framing every shot. The R1 reader's verdict: "brick appears only on roofs."

### Scene plan
- **City wall and gate:** replace `city_wall/Tiles.png` (grey, 64x32) on `street.json` and `floodplains.json` with Cemetery Walls tan brick: cap row (12-17,0) and (12-17,8), face courses (13-16,1-4) and (13-16,9-12), corner piers (12,1-4) and (17,1-4). Gate: recolour the owned `city_gate_arch` (64x96) and `city_gatehouse` (192x128) from grey to the Cemetery tan (owned art, recolour is free). Flank the gate with Desert Ground sandstone pylons (0-3,15-19) only if the gatehouse needs towers (Desert Ground is unbundled; optional).
- **Facades:** keep `facade_plaster` (Building_Walls (18-23,12-14) and the brick-footed plaster (30-35,0-11)) as the upper storey. Under it, a ground-storey band of the same Cemetery brick face (13-16,1-2), two cells high, with openings overlaid as props: `door_street`, `window_shutter` (32x24, already drawn on brick), `window_grille`, door#2 arched blue-glass window, window#13 window boxes, structure#5 sign post with the pennants. wall_module#8 (Cemetery Roof brick panel 48x55, dull brown brick in a timber frame) and wall_module#14 brick cell break the band at corners and alley mouths. Roofs: wall_module#4/#5 brown shingle gables (Cemetery Roof, unbundled) replace `inn_roof` x8; Building_Roofs plank gable (0-7,0-5) is the second roof silhouette.
- **Street:** Floors_Tiles orange packed-earth Wang blob (10-13,0-11) with its stone-rim edges for the lane; the owned `cobble_over_dirt_v1` stays as the paved spine. Market from purpose props: table#6 butcher stall + station#55 hanging meat, station#26/#27 bread oven pair, table#13 cloth-draped counter, crate#3/#4 + food#6/#7/#12/#24 produce, container#1/#2/#21 clay family, container#4 basket stack, barrel#2 water barrel, plant_d#42 planter shrub, plant_a#39/#40 planter crates, plant_a#42 trough, wall_module#24 + fence#10 dray rank, fx#2 amber cone over the unlit copper bracket at night.
- **Barracks:** walls in the same Cemetery tan brick (the barracks is in the wall, which is why it is brick where the guild is plaster); floor Desert grey flag (1,8)-(3,10) or keep `wall_over_flagstone_v1`. bed#4 cot x3, shelf#10/#11 lockers, container#6 footlocker, table#36 duty table, seat#6 low bench, sign#5 Watch crest, door#6 iron-banded door, window#6 grille. **Kit rack composed:** shelf#13 peg rail (Library plank with pegs, 48x32) with item#6 round shield and item#5 laid sword hung on it, plus tool_a#3 recut hammer; a second rail with two shields is the "spears and shields" wall. Hideout chart (22-25,12-15) is the duty map.
- **Runners' Guild:** Library straight boards (20-21,10-11) floor; `plaster_wall` (owned) stays. shelf#1 three-row sorting shelf with sack#1 knapsack, book#3 scroll, book#6 papers on its rows (sorting read), shelf#13 second peg rail with sack#1 hung, table#29 knee-hole desk + shelf#5 drawers + book#4 ledger + item#10 quill, Hideout satchel (17-18,7-8) pile at the door, sign#4 green pennant.
- **Adventurers' Guild:** Library parquet floor as now; table#16 + table#26 orange counter pair with emblem as the second counter set (different silhouette from counter_left/mid/right), Library panelled counter run (16-19,1-2) as the back counter, sign#6/#7 blank and written boards repeated as the board wall with sign#2/#4 pennants either side, shelf#6 cabinet + table#22 strongbox, Library plain chair (19-20,19-21), seat#2 plank bench, table#38 reading table.

### Design changes
| change | asks removed | trade-off | canon/identity check |
|---|---|---|---|
| Liscor's signature material becomes **tan sandstone-brick walls + brick ground storey + cream plaster upper storey + shingle roofs** (Cemetery Walls / Building_Walls / Cemetery Roof) instead of full-brick facades | brick facade kit + clay roof run (35-85); gate arch module (12-18); civic plain-brick face (8-12); Building_Walls interior waiver | buildings are brick-and-plaster, not brick to the eaves; the brick is a tan/sand brick, not red | The city wall is the defining feature and it becomes warm brick with a matching gate; the review asks for "warm stone, timber and worn streets", which this is. Canon describes Liscor as a walled Drake city, not a red-brick one. **User decision 1.** |
| Barracks kit rack and weapon rack **composed** from the Library peg rail + shield + sword + recut hammer | kit rack + weapon rack (20-36) | a hung-kit rail, not a freestanding spear rack | Watch barracks with kit on the wall reads; no canon text names a rack type. Contingent generation if the composed rail reads as a coat rail. |
| Guild board wall from the sign#6/#7 pair + pennants; Runners' sorting from shelf#1 with parcels on it; second counter from table#16/#26 + Library counter run | request board (10-18), pigeonhole shelf (10-18), counter pigeonhole back (0-18) | a 2-cell board rather than a 3-cell handbill wall; open shelf rather than a compartment grid | ALLOC-architecture already rules these "filled"; the reader's "visible job" is met by the props on the shelf, not the shelf's joinery. |
| Market square paving stays packed earth + the owned cobble spine | sandstone sett atlas (8-12) | no sett texture under the stalls | Worn streets are the brief; setts were a nicety. |
| Street-lamp night via fx#2 amber cone (already allocated) | none new | - | - |
| cold_hearth and dirty_table fixed by hand pixel (`pixelart_workbench`, free) rather than `edit_image` | 0-24 | agent pixel time | Owned sprites, prose unchanged. |

### True gaps
- **Antinium worker rig at gameplay scale.** The harvest rig is 116x126 frames at render_scale 0.551 (a downscale, which the fidelity rule forbids as a destination) and reads as a spider. No pack has an Antinium. Pro character, 32-48 px tall, idle + one 4-direction walk. Owned by construction.
- **Owned stool with legs** (official Liscor seat and the public fallback stool in one; the Library chair covers the chair). Pro Flash.
- **Contingent:** Liscor brick-with-opening facade module only if the user rejects decision 1 (building kit 35-85); kit rack only if the composed rail fails (Pro Flash 0-18).

---

## Pallass (R5)

**Current read:** slate floor, bronze-and-blue parapet with crystal posts, lower-city backdrop; grey tier walls; forge heat as an exposed strip.

### Scene plan
- **Structure:** tier walls from Castle Environment Tiles (bundled, Pallass's own sheet in ALLOC-architecture): beige-grey ashlar cap and face (0-3,0-10), cornice band with dentils (0-7,3-4) as the terrace edge, window#2/#3/#5/#6 lancets and blind arches as relief, wall_module#6/#7 dark slate gables (Cemetery Roof) as rooftops above. `prop_tier_wall` (owned) stays the parapet. Floors stay `slate_over_void`. R10 recut (window#1 composite) gives the stone door; door#7 is the den shop door.
- **Light:** `crystal_lamp` (owned bronze post, white lamp) outdoors as now; night = cold-white recolour of the Castle fx#1 cone (32x64) under each post, modulated like Liscor's amber cones. Interiors (lift station, forge hall): lamp#28 Library bronze chain cage, crystal shifted to white. Lit lancets window#1/#4 for the forge hall at night.
- **Civic station:** table#2 permit desk with blue slot, sign#3 blue pennant, decor#11 lift chain, other_b#24 bronze figure, `prop_great_elevator`, container#53 stone urn, seat#11/#12 grey chairs, seat#3 slate bench.
- **Forge:** fence#1/#2 ember channel + pipe#1/#2 forge pit + station#1 crucible stand + lamp#3 coal trough = the contained molten channel; station#17/#18 furnace, #49/#50 hearth, #28/#29 smelter, #52/#53 basin, tool#6 smithy station, tool#7 pegboard bench, tool_a#5/#10 anvils, container#24 quench tub, rock#33/#35 coal, item#1 hot iron, rug#1 runner, other_a#11 recut coal bin, other#20 recut chimney, tool#1 8-frame smithing strip if a working smith is wanted.
- **Market:** container#8/#9 urns, #10 goods, #11 jug, table#1/#3 stone counters, `prop_market_stall`, `prop_price_board`, `prop_steam_vent`.

### Design changes
| change | asks removed | trade-off | canon/identity check |
|---|---|---|---|
| `crystal_lamp` is the identity lamp; night = cold-white glow cone overlay; no bronze wall-arm variant (chain cage indoors instead) | lit object state + wall-arm Pro Flash (30-62) | one outdoor lamp silhouette; indoor lamp hangs rather than arms | Bronze fixtures and cold white light, as the grammar table says. **User decision 3 (minor).** |
| Tier walls from Castle ashlar instead of the Desert recolour (R2 dropped, as the cross-check already preferred) | none (R2 was 0-gen) | - | Beige structural stone preserved, no shared silhouette with Liscor's wall. |

### True gaps
- None. Pallass needs bundling (Forge Tiles, Cemetery Roof) and composition, not generation.

---

## Invrisil (pilot)

**Current read (1b strip):** white half-timber boulevard, grey marble square, dark interiors with blue-grey floors and brown timber walls.

### Scene plan
- **Boulevard:** Building_Walls storefront variants (0-23,32-39) and the brick-footed plaster (30-35,0-11) break the 14x window repeat; Building_Roofs glass gable (17-22,6-12) + wall_module#17 glass gable halves as rooftop masses; `invrisil_roofline` (owned) stays; Castle cornice band (0-7,3-4) auditioned as a parapet line above the plaster. Curb: switch the square to the full marble Wang id set so its edge/corner ids draw against `cobble_over_dirt_v1`; Garden Tiles pale-stone kerb (8-11,0-4) is the fallback. wall_module#3/#11 iron railings round the fountain, container#50 urn + c#36 topiary composited, `streetlamp_v2` posts, lamp #1/#2 steel lanterns on the facades, sign#1/#2/#3 purple-and-gold banners.
- **Cross-street / alleys:** door#14/#16 teal enchanter door (open/closed) replaces the glazed `invrisil_shop_door_1`; `shopfront_door` keeps the other fronts; Dungeon_Tiles recess (0-2,3-4) is the shadowed nook; two container#29 crates per stack for "A Good Vantage"; pipe#4 alley drain; Castle arch frame (16-17,0-3) trimmed as the framed work-room door.
- **Interiors:** `ashlar_over_checker_v1` (owned) for the work room (ashlar wall, checker floor); Floors_Tiles white marble blob (0-4,12-25) for shop and stationer floors; Building_Walls plaster-over-dado (24-29,12-14) as the wainscot wall with a 1-px gold cornice line as a data overlay; seat#19/#20 oak chairs, seat#5 settee, seat#1 armchair, table#10/#18/#30 glass cases, tool#18/#20 glass-top counters, rug#4/#11/#14 + Library key-border rug (23-26,17-20), table#11 bench + tool#12 enchanter workbench + container#15/#16/#19/#31 + vessel#33 + book#1 for Hedault; bed#1, station#33 iron range, decor#1/#3/#4 busts for the Rest; vessel#16 inkpot, item#11 quill, item#18 scroll, book#5 for the stationer; decor#20 curtains, decor#10 painting.

### Design changes
| change | asks removed | trade-off | canon/identity check |
|---|---|---|---|
| Curb from the marble Wang's own edge ids | curb tiles + paving apron (16-24) | the apron uses the same edge | Pale stone on pale stone; nothing new. |
| Work-room wall and floor from `ashlar_over_checker_v1`; cornice as a data line | wall_shop ashlar + cornice tile (8-12) | the checker is grey/slate, not cream | Cold, wealthy, glass-and-gold stays on the props. |
| Roofline from Castle cornice band (audition) | roofline Pro Flash (12-18), contingent | khaki-grey stone band on a pale city | Pale stone city; if it reads warm, generate. |
| Third shop door = door#14 (bundled) instead of the Hideout leaf recut | c3 (0-18) | - | Teal and gold tracery is the magic-shop threshold. |
| Framed work-room door from the Castle arch frame (bundled) | c5 (0-18) and the Hideout dependency | - | - |
| Seating, rugs, display counter, settee filled by ALLOC-architecture | c1, c2 (0-54) | - | - |
| Tall street lamp: `streetlamp_v2` (owned, navy and gold) is the formal post lamp; no second variant | lamp_street (10-18) | one post silhouette | Tint is not disambiguation; a second variant was variety, not identity. |
| Alley workbench cluster becomes a cargo-yard cluster (container#29 x2, barrel#8 on its side, sack#15, pipe#4) **if** the sneak-encounter prose does not name a workbench | workbench set-piece (10-18) | prose check needed | **User decision 4.** |
| Sealed bale = hand-pixel edit of sack#15 (add wax seal + two tallies); third sign = hand-pixel of the cards-and-hat motif on the blank `invrisil_hanging_sign` | bale (10-18), sign (10-18), both contingent | agent pixel time; pack edit at bundle tier | Prose imagery is kept exactly. |

### True gaps
- **Invrisil cold wall lantern, owned** (bracket, glass, flame; serves as the public fallback for `lamp_wall`). Pro Flash; lit via a cold glow overlay rather than an object state.
- **Second owned street door** (public-build variety contract). Pro Flash, low identity impact.
- Contingent: roofline band, workbench, bale, sign (Pro Flash each) if the auditions or pixel edits fail.

---

## Ruin, dungeon, sewers (R2)

### Scene plan
- **Ruin:** wall_module#2 enclosure recut + wall_module#10 stub + rock_a#11/#14 masonry piles + debris#25/#26 fallen beams as the broken masses; a#20/e#12 dead giants; door#5 descent arch; other#4 recut pit, tool_a#1 shovel, other#24/#25 cart and rail, other#21 recut carts, tool#19/#22 rubble with tools, debris#1-#3 cooled blocks + debris#5 charred timber + vessel#29/#30 sherds + container#51 urn as the four-plus debris silhouettes; plant_a#20 ivy; lamp#6/#7/#8 campfire states and `dungeon_brazier_owned` as the camp's light; `dig_camp_tent_owned`.
- **Dungeon:** `dungeon_brazier_owned` + lamp#5 coal box + lamp#24 candle + decor#6 lit idol + rock_a#18 crystal for value separation; door#2 vault portal, rune_stele, plinth + statues, door#12 double door, R11 lattice gate, other#22 chain, debris#28/#29 timbers, decor#2 hooded bust, lamp #3 wheel chandelier.
- **Sewers:** wall_module#9 piers, structure#2 ladder, door#4/#10 service door and hatch, window#9 grate, the 10-piece pipe family + pipe#9 outfall + pipe#18 drain mouth + pipe#6 grate + container#57 cistern + container#13 bucket + tool#34 brush + pipe#21 chain; Hideout bracket torch (24-25,0-1) with the Hideout Light cone slice 2 as the one warm fixture; lamp #8 tin lantern on a pier; a#4/a#9 lit fungi, plant_a#1/#3 red trumpets, rock_a#1/#2 stalagmites, plant_d#27 moss wall, plant_d#33/#34 webs. Optional: `olddark_attempt1_wallbrick` (owned, cool dark brick) as a deep-tunnel wall variant.

### Design changes
None needed beyond what the cross-check already ruled (8a/8b/8c REMOVE). The sewers' only fixture depends on the Hideout bundle; if that bundle is refused, the fallback is lamp#28's chain cage in iron-grey (a different metal from Pallass's bronze, so not a tint sibling).

### True gaps
- None.

---

## Inn (R3)

### Scene plan
Owned set pieces (`inn_hearth`, `bar_counter_stools`, `back_bar_shelf`, `kitchen_prep_counter`, `long_tavern_table`, dirty/clean tables) carry the north wall; barrel#6 ale cask, shelf#3 hanging shelf, shelf#7 wall shelf, container#7 pail, station#45 butcher block, vessel#7 stew pot, food#13/#14/#18/#23, resource#12 firewood, table#20 round tables, seat#9/#10 chairs, seat#13 stool, rug#3/#10/#13 recuts, rug#8 door mats, window#10 interior window, wall_module#25 pillar, decor#14 trophy, plant_a#43/#46 pots, tool#26 broom, sconces #1/#2, lamp#4 candelabra with lamp#19 flame overlay; upstairs bed#2, table#9 wardrobe, door#9 room doors, door#8 cupboard. station#8 only as a blockout audition.

### Design changes / true gaps
None. The inn is composition work.

---

## Riverfarm and the witch hollow (R4)

### Scene plan
Longhouse: seat#2 benches, bed#3, container#17/#18 pots, vessel#14 jar, station#37/#38 oven, rug#5 hide rug, decor#13 trophy, lamp #7 oil lamp, sconces #3/#4, window#15. Mill and yards: tool#8 saw bench, tool#24 chopping block, container#5 trough, tool#16 wheelwright bench, tool#21 tool box, resource#24 lumber stack, tool_a#11/#12 gear and millstone, debris#6 sawdust, resource#13 log round, wall_module#15/#23 timber shed kit, door#4 barn door, window#3 louver, R3 picket fence recut, wall_module#29/#30 posts, fence#11 mooring post, container#11/#12 well pails. Garden patch: plant_b#5/#8/#10/#19/#39 mature crops + corn stages, decor#9 scarecrow, sack#2/#8 seed sacks, vessel#15 basket, c#39 berry hedge. Hollow: unchanged hero hut, b#3/b#19/b#45 trunk, canopy pool, table#21 witch workbench, cauldron pair, glow stones. fx#1 torch cone at night.

### Design changes / true gaps
Mature crop ask closed by ALLOC-natural. None remaining.

---

## Floodplains and Rags's camp (R6)

### Scene plan
Trees and shrubs from the floodplains pool (e#7 recut, e#8/#9, a#52, pines, plant_a#23/#24 shrubs, b#18 recut), reeds and cattails at the pond, rock#10/#13/#14, Cemetery tan wall for the Liscor exterior (same material as inside the gate, so the approach and the street agree). Camp: `camp_hide_tent_owned`, `camp_palisade_owned`, `camp_lookout_owned`, `camp_weapon_rack_owned` (all owned, already registered), lamp#4 spit, station#22 cookpot, structure#3 tripod, lamp#23 central firepit, lamp#12/#15 small fires, fence#6 drying rack, structure#13 signboard, sign#8/#9 banners, item#17 bow, debris#8 kindling.

### Design changes / true gaps
The "lookout at native scale" ask is answered by `camp_lookout_owned` (80x112 at 0.46; a downscale, but an owned rig, so it is a scale-convention question for the roster lane, not a kit gap). None.

---

## Garden of Sanctuary (R7)

### Scene plan
Three pockets from Garden Tiles and the allocations: fountain/rest = structure#10 reflecting pool or the octagonal basins (20-23,0-8), seat#18 benches, rock_b#26/#28 stepping stones, plant_c#35 lily; planted shelter = a#43 blossom giant, b#10/b#59 blossoms, plant_c#32 cypress (and #33 for a pair), plant_c#34 hedge columns, b#24 hedge mass, `hedge_over_lawn`, plant_c#36-#39 flower masses, b#25 flowering shrub; memorial rise = container#52 tall urn, decor#17/#18 statues, structure#12 small basin, existing plinths. Paths from `gravel_over_lawn_v1`, flowers from the tulip and round sets, other_b#17/#18 recut planters and pond rim.

### Design changes / true gaps
None.

---

## Revised generation list

Ranked by identity impact. Firm items generate regardless; contingent items only if the named audition or pixel edit fails.

| rank | item | region | states / variants | kind | generations |
|---|---|---|---|---|---|
| 1 | Antinium worker rig at gameplay scale (32-48 px) | Liscor | idle + 4-dir walk | pro character + 1 anim | 40-80 |
| 2 | Cold wall lantern, owned (bracket, glass, flame; public fallback for `lamp_wall`) | Invrisil | day; lit via overlay | Pro Flash | 10-18 |
| 3 | Owned stool with legs (official Liscor seat + public fallback) | Liscor / public | 1 | Pro Flash | 10-18 |
| 4 | Second owned street door (public-build variety) | Invrisil / public | 1 | Pro Flash | 10-18 |
| | **Firm subtotal** | | | | **70-134** |
| c1 | Liscor brick-with-opening facade kit (only if decision 1 is refused) | Liscor | plain, window, door, corner + roof run | building kit + tileset | 0-85 |
| c2 | Barracks kit rack (if the peg-rail composite reads as a coat rail) | Liscor | 1 | Pro Flash | 0-18 |
| c3 | Invrisil roofline/parapet band (if the Castle cornice audition fails) | Invrisil | 1 | Pro Flash | 0-18 |
| c4 | Alley workbench set-piece (if prose keeps the workbench) | Invrisil | 1 | Pro Flash | 0-18 |
| c5 | Sealed factor's bale (if the sack#15 pixel edit fails) | Invrisil | 1 | Pro Flash | 0-18 |
| c6 | Cards-and-hat shop sign (if the pixel edit on the blank sign fails) | Invrisil | 1 | Pro Flash | 0-18 |
| c7 | cold_hearth + dirty_table via `edit_image` (if hand pixel is declined) | Liscor | 2 | edit_image | 0-24 |
| | **Contingent subtotal** | | | | **0-199 (0-114 if decision 1 is accepted)** |
| | **Total** | | | | **about 70-250; midpoint about 130** |

Against the review's ~550-750 and the cross-check's ~330-780 this removes every tileset ask (facade kit, gate arch, civic brick, sett atlas, curb/apron, ashlar wall, crop tile), both object-state asks (Pallass lit lamp, window night state: both become glow overlays), the Pallass wall-arm lamp, the tall street lamp, the request board, pigeonhole shelf, counter back, weapon rack, settee/stool/display counter, third shop door, framed door, crate stack, nook, and the lookout. The only firm generations left are a character rig and three owned public-fallback objects.

Zero-generation work this plan depends on (bundle-tier, no PixelLab): recolour the owned `city_gate_arch` / `city_gatehouse` to the Cemetery tan; cold-white copy of the Castle glow cone for Pallass; hand-pixel edits of `cold_hearth`, `dirty_table`, sack#15 (seal + tallies) and the blank hanging sign; the recuts already listed in ALLOC-architecture/goods/natural and `docs/kits-allocation.md`; the marble Wang id wiring; the gold cornice data line.

## Bundle needs

Unbundled sheets the plan depends on (copy sha-identical under `wandering_inn_game/assets/`, as `pc-ext/INDEX.md` does):

- **Hideout 1.0 `Tiles.png` + `Light.png`:** sewers torch and cone; barracks cot bed#4, lockers shelf#10/#11, duty table table#36, chart; Runners' satchel; door#12; camp banners sign#8/#9, firepit lamp#23, candle lamp#24, timbers debris#25/#26/#28/#29, sacks #15/#16, barrels #6/#7/#8, moss wall, webs.
- **Cemetery 0.4 `Structures/Roof.png`:** Liscor shingle roofs wall_module#4/#5, brick panel #8, Pallass slate gables #6/#7.
- **Forge 1.2 `Tiles.png`:** Pallass ember channel fence#1/#2, forge pit pipe#1/#2, crucible stand station#1, runner rug#1, idol decor#6, coal basket container#3, Liscor water barrel barrel#2, hot iron item#1, coal bin recut.
- **Free Pack station sheets:** `Bonfire*`, `Cooking Station*`, `Butchery_*`, `Alchemy_Table_01/02`, `Workbench`, `Anvil_*`, `Sawmill_*`, `Furnace` level sheets, `Animated_Pan_04` (lamp#3-#19, table#6/#11/#16/#21/#30, tool#6-#24, station#16/#22/#35/#45/#55, vessel#7, rock_a#11/#14, debris#6/#8/#9, resource#13).
- **Sewer `Tiles.png`:** pipe#9/#10/#11/#13/#18/#23, plant_d#44.
- **Free Pack `Dungeon_Tiles.png`:** shadowed nook, ivy plant_a#20.
- **Optional:** Desert `Ground.png` (gate pylons, barracks flag floor); Free Pack `Vegetation` / `Farm` / `Rocks` / `Esoteric` / `Meat` / `Interior_Props_01` / `Furniture` are listed "bundled y" in the ALLOC notes and need no action.

Already bundled and load-bearing: Cemetery `Walls.png` (tan brick), Castle `Tiles.png` (ashlar, lancets, glow cones, busts, urns, banners), Library `Tiles.png`, Building_Walls, Building_Roofs, Floors_Tiles, Garden `Tiles.png`, the owned `ashlar_over_checker_v1`, `tileset_marble_wang4x4`, `cobble_over_dirt_v1`, `crystal_lamp`, `streetlamp_v2`, `city_gate_arch`, `city_gatehouse`, `camp_*_owned`, `dungeon_brazier_owned`. Pixel_16 interiors (licence UNRESOLVED in `docs/asset-catalog.md`) and the Ninja Adventure tilesets were judged and rejected: both are a different pixel grammar (cartoon outlines, cute proportions) and would break the consistent-pixel rule.

## Decisions for the user

1. **Liscor signature material.** Accept "tan sandstone-brick city wall and gate (Cemetery Walls, recoloured owned gatehouse) + brick ground storey under the existing cream plaster upper storey + shingle roofs" as Liscor's warm-brick identity, instead of generating a full-brick facade kit. Removes 35-85 generations and the Building_Walls interior waiver (the barracks takes the wall's brick, the guild keeps plaster). If refused, c1 returns.
2. **Window night state (#618) by glow overlay**, not generated object states: a warm pane glow drawn over the existing windows at night, the same mechanism as the lamp cones. Removes 20-50.
3. **Pallass lamp = `crystal_lamp` as is**, night via a cold-white glow cone, chain cage indoors, no bronze wall-arm variant. Removes 30-62.
4. **Invrisil alley cluster:** swap the "workbench cluster" stand-in for a cargo-yard cluster (crates, barrel on its side, sack, drain) if no dialogue line names a workbench. Removes 10-18; otherwise c4 stands.
