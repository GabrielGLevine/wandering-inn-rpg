# Generation cross-check against existing Pixel Crawler options

Read-only art-direction ruling, 2026-10-09. Every ask in `generation-review.md`
(Tiers 1-3, merged with the open rows of `docs/art-generation-list.md` and
Liscor's ranked needs), plus the recut/recolour asks in `dormant/ALLOC-plants.md`
and `dormant/ALLOC-props.md`, plus the four lamp gaps in
`allocation/ALLOCATION-identity.md`. Judged against the holistic review's
grammar table and region sections, the nine day context shots and the R1 Liscor
captures.

Verdict rule: REMOVE only when the existing option passes a blind read in its
region as-is (data wiring only). PARTIAL when it covers part of the ask or needs
a recut or recolour (the recut/recolour asks from the ALLOC notes are PARTIAL by
that definition; they cost 0 generations). KEEP when nothing in hand is good.

Cell coordinates are 16px cells on the `pc-ext/tiles_*.png` sheets, `(col,row)`
inclusive ranges. Sheet identification note: the sheet holding the Wang blobs
(grass / sand / orange earth / brick patch / white and peach tile) is
`tiles_FreePack_Floors_Tiles.png`; `tiles_FreePack_Wall_Variations.png` is the
rock-cliff variation set (brown, blue-grey, dark) and serves none of these asks.

Exclusivity checks (`pc-ext/INDEX.md` "users"): Floors_Tiles is Liscor's street
sheet (street.json uses the brick patch cells (16-18,1-2)); Library is Liscor's
guild sheet (guild.json uses only parquet cells (21-23,3-4)); Building_Walls is
used by Invrisil (plaster (26,2), glass band (13,35)) AND by Liscor's street
`facade_plaster` (region (18,12)-(23,14)); Building_Roofs is Liscor's `inn_roof`
(teal gable (8,1)-(15,6), tinted in-game). Where a pick takes a non-identity cell
from another region's sheet, the row says so.

Counts: REMOVE 10, PARTIAL 34, KEEP 15 (59 asks after splitting the composite
tier items into the rows the sources list).

## Per ask

`ask | verdict | existing option (sheet + cells or piece id) | bundled? | reason`

### Tier 1: architecture and materials

| # | ask | verdict | existing option | bundled? | reason |
|---|---|---|---|---|---|
| 1 | Liscor brick facade kit: plain, window, door-in-facade, corner (+ Liscor need #1; list row `liscor/facade_wall`) | KEEP | none good. Nearest: Building_Walls plaster-over-brick-foot (30,0)-(35,11) for variant (d) only; Forge Tiles (4,5)-(7,6) is maroon brick, not red-brown/ochre; Furnace Bricks 01-03 are kiln objects | Building_Walls y / Forge n | No Pixel Crawler sheet has a warm fired-brick facade module with window or door cut-outs. Building_Walls is Invrisil's identity sheet and is already what Liscor's cream `facade_plaster` comes from; swapping one plaster for another keeps Liscor cream, not brick. Generate. |
| 2 | Liscor city wall + gate tower, warm sandstone/brick, cap + face + gate arch (Liscor need #2) | PARTIAL (recut) | `tiles_Desert_Ground.png` cap ring (0,7)-(5,11) plain ochre block courses; face courses (4,8)-(7,11) and (0,12)-(5,14) carry blue glyph bands every other row (strip them); sandstone pylons (0,15)-(3,19) as gate-tower posts | n | Ochre sandstone block courses are the warm wall the grey castle wall lacks and read as masonry, not desert, once the blue bands are stripped (pixel edit). No gate arch on the sheet: the dark opening at (8,12)-(11,14) is a cave mouth in brown rock. Remaining generation: gate arch module only. Trade-off: this is the same block silhouette ALLOC-props offered Pallass (wall_module#1 after a beige recolour); tint is not disambiguation, so if Liscor takes Desert Ground, Pallass keeps its existing grey ashlar and the wall_module#1 recolour is dropped. |
| 3a | Invrisil interior floor: pale limestone / cream-grey checker Wang atlas (list row `invrisil/floor_shop`) | REMOVE | `tiles_FreePack_Floors_Tiles.png` white marble Wang blob (0,12)-(4,25); peach sibling (5,12)-(9,25) for the parlor/stationer if one room wants warmth | y | Pale blue-white veined marble, complete Wang blob with edges, lowest internal contrast of any floor in the pool, cold. Reads as a wealthy cold city's shop floor against dark oak props. Floors_Tiles is Liscor's street sheet but these cells are not Liscor's material (Liscor uses the brick patch and dirt). |
| 3b | Invrisil interior wall: pale plaster, oak wainscot, gold cornice (+ ashlar variant for the work room) (list row `invrisil/wall_shop`) | PARTIAL | `tiles_FreePack_Buildings_Walls.png` plaster-over-timber-dado strip (24,12)-(29,14) as the face; existing cap | y (Invrisil's own sheet) | Pale cream plaster over a dark wood base rail is the wainscot read the 1b review wanted and is colder than timberwall_over_plank. Missing: the gold cornice line and the ashlar work-room variant. Generate only the ashlar variant (and add the cornice as a 1px data overlay or a 16x16 cornice tile). |
| 4a | Invrisil facade modules (one window repeated 14 times) (list row `invrisil/facade_panel`) | PARTIAL | Building_Walls storefront variants: big window (0,32)-(5,35), shelf-with-bottles glass (6,32)-(11,35), small-pane glass (18,32)-(23,35), narrow panes (0,36)-(23,39); upper-floor variant plaster-over-brick-foot (30,0)-(35,5) and (30,6)-(35,11) | y | Three unused storefront silhouettes on the sheet Invrisil already owns break the 14x repeat without a new style; the brick-footed plaster gives a second upper module. Nothing remains to generate for windows; the roofline part is 4b. |
| 4b | Invrisil roofline + rooftop mass (list row `invrisil/roofline`) | PARTIAL | `tiles_FreePack_Buildings_Roofs.png` glass conservatory gable (17,6)-(22,12) as one rooftop mass | y | A glass-paned gable is the one roof on any sheet that says cold glass-and-gold; use it on one or two buildings. The teal gable (8,1)-(15,6) is Liscor's `inn_roof` and the plank gables (0,0)-(7,11) are rustic, so the slate/parapet roofline band still needs generation. |
| 5a | Liscor street paving: warm sandstone-sett Wang atlas (list row `liscor/floor_street`) | PARTIAL | `tiles_FreePack_Floors_Tiles.png` orange packed-earth Wang blob (10,0)-(13,11), grey-stone scalloped edges | y (Liscor's sheet; cells unused) | Gives the street a warm ochre lane with connected edges that is visibly not Invrisil marble or Pallass ashlar, at the lowest contrast of the street's layers. It is earth, not setts: the sett atlas for the market square remains, at lower priority. |
| 5b | Liscor need #6: seam-free packed-earth street tile + kerb edge | REMOVE | same blob, (10,0)-(13,11); its stone-rim edge cells are the kerb | y | The blob is exactly the "seamless tile in the sheet" the need was conditional on. |
| 5c | Liscor civic interior wall: (a) plain brick face, (b) brick band under plaster (list row `liscor/wall_civic`) | PARTIAL | (b): Building_Walls (30,0)-(35,5) plaster over brick foot; (a): Forge Tiles plain red-brick band (4,5)-(7,6) only after a hue shift from maroon toward red-brown | (b) y, (a) n | (b) is the Adventurers' Guild face verbatim, but it sits on Invrisil's identity sheet; using it indoors is a rule exception the user must grant. (a) has no honest option: Forge brick is crimson-maroon with lava seams above; a hue-shifted 4x2 band is an audition, not a pick. Generate (a) unless the audition passes. |
| 5d | Liscor civic floors: worn oak boards (Runners') and swept grey flagstone (barracks) (list row `liscor/floor_civic`) | PARTIAL | Runners': `tiles_Library_Tiles.png` straight boards (20,10)-(21,11), 2x2 repeat (avoid the bookcase-shadow notch rows 8-9 and 12); barracks: `tiles_Desert_Ground.png` plain grey flag floor (1,8)-(3,10) | Library y / Desert n | The Library boards are a different pattern from the guild's parquet (21-23,3-4) and from the inn's `inn_floor`, so the Runners' Guild stops borrowing the inn. The Desert grey flag is flat and quiet (which "swept" asks for) but bland; audition against `wall_over_flagstone_v1` before accepting. Verify seamless tiling of both ranges. |
| 6a | Invrisil marble curb tiles (list row `invrisil/curb_marble`) | KEEP | nearest: Sewer Tiles stone channel rim (0,0)-(4,4) | n | The only kerb set on any sheet is a dark slate-green raised channel lip; it reads as a pool rim or pipe edge, not pale stone. Generate. |
| 6b | Invrisil cross-street paving apron / curb edge (list row `invrisil/paving_apron`) | KEEP | none | - | Same gap as 6a; one generation can cover both (edge + corner + apron cells in one tileset call). |

### Tier 2: signature props and lights

| # | ask | verdict | existing option | bundled? | reason |
|---|---|---|---|---|---|
| 7 | Pallass identity lamp: bronze arm, white lamp, day + lit states (allocation gap) | PARTIAL | owned `crystal_lamp` (sprites.json, `assets/sprites/crystal_lamp/Idle-Sheet.png`, 32x64 at 0.5): a bronze post with a white lamp, already placed 10x on the Pallass maps; interior hanging sibling `tiles_Library_Tiles.png` gold chain lamp with cyan crystal (0,15)-(0,18) | crystal_lamp y / Library y | The allocation gap counted only the contested pack candidates; the region's own post lamp is the bronze-and-white fixture the brief describes. The Library chain lamp matches the crystal vocabulary for the lift station and forge hall (its cell is not Liscor's identity). Remaining generation: a lit (night) object state for crystal_lamp and a wall-arm variant. |
| 8a | Dungeon floor brazier for halls and vault approach | REMOVE | owned `dungeon_brazier_owned` (= harvest `set_pieces/dungeon_standing_brazier.png`, iron tripod bowl with flame), already placed in `dungeon_approach.json` and `trapped_halls.json` | y | The uncontested standing brazier the gap told us to check is already wired and in the dungeon; the gap is closed in data. |
| 8b | Ruin dig-camp lantern or brazier with pale highlight | REMOVE | same `dungeon_brazier_owned` / `dungeon_standing_brazier.png` | y | Flame and pale rim separate cleanly from the ruin's dark field (checked against `allocation/context/ruin.png`). Trade-off: shared with the dungeon below it; acceptable because both are the same expedition's kit and the brazier is a prop, not either room's architecture. |
| 8c | Sewers service-channel lit fixture (wall pier lamp / cage lamp with local glow) | REMOVE | `tiles_Hideout_Tiles.png` bracket wall torch (24,0)-(25,1) (three further flame frames at (24,2)-(25,7)); glow from `slices_Hideout_Light.png` slice 2 (cone, `Light__x80_y0_w128_h144`) as a modulated overlay | n | A dark iron bracket torch on a grey pier with a warm cone is the one warm light in a cold channel, which is what [Light]-off reads need. Sewer Tiles itself has no fixture; its copper pipes and grates are the channel dressing, not lamps. |
| 9a | Invrisil wall lantern: bracket, glass, flame + owned public fallback (list row `invrisil/lamp_wall`) | KEEP | nearest: Hideout torch (24,0)-(25,1) | n | A warm open torch is the palette clash the identity ruling just removed from Invrisil (copper lamp #5 moved to Liscor). The owned fallback must be generated regardless. |
| 9b | Invrisil tall formal street lamp (list row `invrisil/lamp_street`) | KEEP | none on any sheet; `street_lamp` (owned streetlamp_v2) stays | - | No post lamp on the Pixel Crawler sheets at all. |
| 10a | Barracks duty set: kit rack, 2-cell bunk row, weapon rack, roster board (Liscor need #3) | PARTIAL | bunk: `tiles_Hideout_Tiles.png` plain wooden cot (17,7)-(20,9), 2 cells wide; board: Hideout wall chart (22,12)-(25,15), 3x3 cells | n | The cot reads as a barracks bed and repeats into a row; the chart reads as a duty map on a board. Kit rack (spears and shields) and weapon rack have no option: Forge Tiles racks (10,17)-(13,19) are maroon forge furniture and read as forge. Generate those two. |
| 10b | Runners' Guild sorting set: pigeonhole/parcel shelf (2-cell) + satchel pile (Liscor need #4) | PARTIAL | satchel: Hideout olive backpack (17,7)-(18,8); sorting furniture: Hideout two-drawer dresser (23,5)-(25,7); stand-in shelf: Library bookshelf top (0,0)-(3,3) | n / Library y | The satchel is a clean one-cell read. A dresser with drawers says "sorting" but not "pigeonholes"; the Library shelf reads as books. Generate the pigeonhole shelf. |
| 10c | Guild board wall: 3-cell request board with handbills + counter back-wall shelf (Liscor need #5) | PARTIAL | back-wall shelf: Library balustrade/shelf (16,0)-(19,1) or bookshelf (0,0)-(3,3); board: Hideout chart (22,12)-(25,15) is a map, not handbills | Library y / Hideout n | The shelf half is covered. The request board is the room's job and handbills are the read; generate it. |
| 10d | Second civic counter set, left/mid/right, pigeonhole back, ledger and bell (list row `liscor/counter`) | PARTIAL | `tiles_Library_Tiles.png` panelled dark-oak counter run (16,1)-(19,2), 4 cells long, cream top edge; pair with the Hideout dresser (23,5)-(25,7) as its back | Library y / Hideout n | A different silhouette from `counter_left/mid/right` (panelled, longer, darker), which is what "reads differently from the Adventurers' Guild" needs. No left/right returns, no pigeonhole back, no bell: generate a single pigeonhole-back piece only if the dresser pairing fails the read. |
| 11a | Invrisil seating: oak side chair, short settee, bar stool (list row `invrisil/seating`) | PARTIAL | side chair: Library teal-cushion chairs (19,14)-(19,16) and (19,16)-(19,18); settee/armchair: Hideout wine armchair (17,3)-(18,6) and tan (19,3)-(20,6); stool: Hideout tan cushion ottoman (18,6)-(19,7) | Library y / Hideout n | The Library chair is a dark-wood side chair with a cold cushion and passes in an Invrisil parlor. The Hideout pieces are chunkier and olive-toned; audition the wine armchair as the settee before generating. If the two styles clash side by side, generate the settee and stool in the Library chair's wood. |
| 11b | Invrisil rugs: axis-aligned, navy/wine field, thin gold key border, two sizes + plain runner (list row `invrisil/rug`, have 2, need 3) | REMOVE | `tiles_Library_Tiles.png` teal rug with gold key border and fringe (23,17)-(26,20), 64x48; optional second: Hideout dark-teal bordered rug (21,3)-(24,6), 64x48 | Library y / Hideout n | The Library rug is the brief almost verbatim (cold teal for navy, thin gold border, axis-aligned) and with `rug_woven_red` and `rug_woven_cream` the role reaches its target of 3. The plain runner is a nicety, not a gap. |
| 11c | Invrisil glass-and-gold display counter (list row `invrisil/display_counter`) | PARTIAL | `tiles_Library_Tiles.png` gold-framed dark-glass display case (20,14)-(22,17), 48x48; teal chest with gold trim (20,17)-(22,20) as a second | y | A gold-trimmed vitrine reads as wealthy display for the enchanter front-of-house. It is a tall case with dark glass, not a pale-pane counter; generate the counter form only if the room needs a service surface rather than a case. |
| 11d | Invrisil workbench set-piece (bench, vice, tools) (list row `invrisil/workbench`) | KEEP | none; lk_tool_a#13 is the Pallass forge bench and is Pallass's | - | Nothing on the sheets groups bench + vice + tools; the Forge racks are forge-red. Generate. |

### Tier 3: stand-ins, recuts, fallbacks

| # | ask | verdict | existing option | bundled? | reason |
|---|---|---|---|---|---|
| 12a | "A Good Vantage" neat two-stack crate stand-in (list row `invrisil/standin_good_vantage`) | PARTIAL (composition) | compose two of dormant container#29 (`Resources__x0_y144_w16_h32`, plain plank crate 15x19, common pool) per stack, one-tile gap, before generating | n | No sheet holds a tidy multi-crate stack (Hideout (13,6)-(17,9) is loose planks; Forge lockers are red). Pool-first says compose the stack in data first; generate only if the composed stack reads as two loose crates. |
| 12b | Shadowed nook: wall-attached dark recess in blue-grey brick, lit edge (list row `invrisil/standin_shadowed_nook`) | REMOVE | `tiles_FreePack_Dungeon_Tiles.png` square recess with pale-blue stone rim (0,3)-(2,4), 48x32; arched alternative (0,10)-(1,11) (verify the row below) | n | Blue-grey stone, deep black interior, a sliver of lit rim: the brief's silhouette in the alley's own palette. It is architecture, nothing lootable in it, so selection/focus stays the only bright element. |
| 12c | Sealed bale with wax seal and tallies (list row `invrisil/standin_sealed_bale`) | KEEP | none; Hideout hay (0,15)-(1,16) is loose hay, lk_container has no bale | - | Generate. |
| 12d | Tray with contents | PARTIAL | dormant other#43 (`Pan__x80_y112`, plate with a meal) on container#42 (`Pan__x0_y128`, wooden platter), both allocated to the inn | n | Sub-cell tableware shared between the inn and one Invrisil tray is not an identity clash. Needs the two pieces paired in data; nothing to generate. |
| 13a | Third shop sign, the Rest's cards-and-hat sign (list row `invrisil/shop_sign`) | KEEP | none | - | Prose-specific imagery; no sheet has it. |
| 13b | Second owned street door (list row `invrisil/door_street`) | KEEP | none can be owned | - | Public-build fallback must be PixelLab-owned; pack art cannot satisfy it. |
| 13c | Third solid shopfront door against glass (list row `invrisil/shop_door`) | PARTIAL (recut) | `tiles_Hideout_Tiles.png` dark plank arched door leaf with brass handle, lift the leaf (about 22x32) from the stone-framed door at (14,0)-(15,2); alternative lk_door#7 arched glass door recut (ALLOC-props) contradicts the #608 "solid" ruling | n | A solid dark door reads as a threshold against the glass band, which is what #608 asked. Recut the leaf without its grey surround so it sits at the 22x32 scale of the other shop doors; no downscaling. |
| 13d | Framed work-room door | PARTIAL (recut) | Hideout stone-framed arched door (14,0)-(15,2) whole, 32x48, trimmed to about 32x40; or Dungeon_Tiles plank door in stone arch (0,7)-(2,9) | n | Both are literally framed doors in cold grey stone. Trim the height so the frame sits inside one wall cap/face row. |
| 14a | Liscor cold hearth recut (reads as a ring now) | KEEP (0-6 gen edit) | none on the sheets; Furnace Bricks 01-03 are all lit kilns | - | This is an edit of the owned `cold_hearth` sprite (hand pixel work or one `edit_image` call), not a Pixel Crawler substitution. |
| 14b | Liscor dirty table recut | KEEP (0-6 gen edit) | none | - | Same: edit of the owned `dirty_table`. |
| 14c | Antinium worker silhouette at gameplay scale | KEEP | none | - | Character work; no pack option. |
| 14d | Official seat family at gameplay scale (stool + chair) (Liscor need #10) | PARTIAL | chair: `tiles_Library_Tiles.png` plain wooden chair (19,19)-(20,21); stool: Hideout tan cushion ottoman (18,6)-(19,7), or dormant seat#2 bench (`Props__x32_y64_w32_h12`) already allocated to Liscor seating | Library y / Hideout n | The Library chair is a plain three-quarter wooden chair on Liscor's own guild sheet and a different silhouette from the teal-cushion chairs Invrisil takes. Generate the stool if the ottoman reads as a cushion. |
| 15a | Public fallback: stool with legs (owned) | KEEP | none can be owned | - | Owned by definition. |
| 15b | Public fallback: smaller pebble | REMOVE | data fix already in place; official build has dormant rock#6-#8 pebbles | y | The row itself says data-fixed; drop from the generation list. |
| 15c | Windows with a night state (#618) | KEEP | none | - | Object state on owned windows; no pack night window exists. |

### Plant recut / recolour asks (`dormant/ALLOC-plants.md` Notes)

| # | ask | verdict | existing option | bundled? | reason |
|---|---|---|---|---|---|
| P1 | b#18 three fused bushes, recut into 3 | PARTIAL (recut) | b#18 `Props__x0_y0_w64_h144` (Fairy Forest) | y | Pure slice, 0 generations. |
| P2 | e#3 2x2 slim pines, recut into 4 | PARTIAL (recut) | e#3 `Model_03_Size_04__x0_y0_w192_h416` (Free Pack) | n | Pure slice, 0 generations. |
| P3 | e#7 2x2 round trees, recut into 4 | PARTIAL (recut) | e#7 `Model_01_Size_03__x0_y0_w96_h192` (Free Pack) | n | Pure slice, 0 generations; audition as the 1x replacement for the downscaled `tree_round`. |
| P4 | Liscor planter container under c#27 (half-barrel or brick tub, 16x12) | REMOVE | dormant container#25 `Tools__x0_y112_w16_h32` (hooped wooden tub, 16x19, common pool) or tool_a#26 `Tools__x16_y96_w16_h16` (small keg) | n | A bush in a hooped tub is the planter read; 16x19 instead of 16x12 is a footprint, not a scale change. Pair in data. |
| P5 | Invrisil urn/planter under c#36 | REMOVE | the existing owned boulevard planter (harvest "planters" already on the boulevard) | y | ALLOC-plants itself names the pairing; no new base needed. |
| P6 | Warm-glow recolour of a#9 (sewers, conditional) | PARTIAL (recolour) | a#9 `Props__x192_y48_w64_h48` (Cave) | y | Only if the sewers go amber; with 8c giving the channel a warm torch, the cold-blue fungus glow becomes the contrast, so the recolour is likely unnecessary. 0 generations either way. |
| P7 | Riverfarm mature crop tile 16x16 (wheat or cabbage head) | KEEP | none; Hideout hay (0,15)-(1,16) is a hay pile, Library planters (22,21)-(25,24) are shrubs | - | ALLOC-plants is right that no sheet has it. |

### Prop recut / recolour asks (`dormant/ALLOC-props.md` Notes)

| # | ask | verdict | existing option | bundled? | reason |
|---|---|---|---|---|---|
| R1 | seat#1 long bench recut (top half, 3-cell) | PARTIAL (recut) | seat#1 `Props__x83_y160_w58_h32` | n | 0 generations. |
| R2 | wall_module#1 Desert tower/block courses to Pallass tier_wall after beige recolour | PARTIAL (recolour), conditional | wall_module#1 `Desert Props__x0_y7_w96_h169` | n | Do it only if Liscor does NOT adopt the Desert Ground courses (ask 2). Same silhouette in two tints across two cities is the shade-variant problem; Pallass's existing grey ashlar is the safer identity. |
| R3 | wall_module#4 picket pen to Riverfarm fence modules | PARTIAL (recut) | wall_module#4 `Props__x6_y176_w68_h80` | n | 0 generations; audition against the current dark post fence. |
| R4 | other#21 four ore carts to singles | PARTIAL (recut) | other#21 `Dungeon_Props__x0_y0_w64_h32` | n | 0 generations. |
| R5 | other#20 chimney stack to pallass/forge_chimney | PARTIAL (recut) | other#20 `Props__x4_y73_w24_h103` | n | 0 generations. |
| R6 | other#4 dug pit without shovel | PARTIAL (recut) | other#4 `Cem Props__x64_y0_w48_h48` | y | 0 generations. |
| R7 | tool_a#3/#4 one grey-head sledgehammer | PARTIAL (recut) | tool_a#3 `Tools__x0_y160_w16_h64` | n | 0 generations. |
| R8 | debris#4-#6 desert horns, cool bone + turf base | PARTIAL (recolour) | debris#4 `Props__x4_y178_w54_h71` | n | Optional floodplains landmark; 0 generations; leave out if the recolour fights the grass. |
| R9 | door#7 arched glass door to Invrisil shop door 2 | PARTIAL (recut) | door#7 `Props__x101_y29_w22_h67` lower half | n | 0 generations, but contradicts the #608 ruling that glazed doors read as windows on the glass band; audition only, and prefer 13c's solid leaf. |
| R10 | window#1 grey stone arch doorway to pallass/door_stone | PARTIAL (recut) | window#1 `Props__x32_y20_w63_h124` | n | 0 generations; fills Pallass's door gap. |
| R11 | door#3 split: lattice gate (dungeon) + green panel door (liscor/door_civic) | PARTIAL (recut) | door#3 `Props__x35_y84_w26_h85` | y | 0 generations. |

### Lamp gaps (`allocation/ALLOCATION-identity.md` "## Gaps")

Pallass = row 7 (PARTIAL), dungeon = 8a (REMOVE), ruin = 8b (REMOVE), sewers = 8c (REMOVE).

## Revised generation list

Ranked by regional identity unlocked. "Firm" items generate regardless; "if audition fails" items generate only when the existing-option audition above does not pass the blind read. Costs use: tileset 3-4, Pro Flash object 5-6, object state 10-25, building kit 10-25, pro character 10-25 + 8 per animation; 2-3 attempts per asset.

| rank | item | kind | generations |
|---|---|---|---|
| 1 | Liscor brick facade kit (plain, window, door-in-facade, corner) + clay-tile roof run | building kit + tileset | 35-85 |
| 2 | Antinium worker rig at gameplay scale (one walk) | pro character + anim | 40-80 |
| 3 | Invrisil wall lantern (bracket, glass, flame), its owned public fallback, tall formal street lamp | 3x Pro Flash object | 30-54 |
| 4 | Pallass crystal_lamp lit state + bronze wall-arm variant | object state + Pro Flash | 30-62 |
| 5 | Windows night state (#618) | object state x2 | 20-50 |
| 6 | Barracks kit rack (spears, shields) + weapon rack | 2x Pro Flash | 20-36 |
| 7 | Official stool + public stool with legs (owned) | 2x Pro Flash | 20-36 |
| 8 | Cold hearth + dirty table edits (owned sprites) | 2x edit_image or hand pixel | 0-24 |
| 9 | Invrisil curb edges/corners + cross-street apron (one tileset call) | tileset x2 | 16-24 |
| 10 | Liscor gate arch / tower cap module | Pro Flash | 12-18 |
| 11 | Invrisil roofline / parapet band | Pro Flash | 12-18 |
| 12 | Guild request board, 3-cell, handbills | Pro Flash | 10-18 |
| 13 | Runners' pigeonhole parcel shelf, 2-cell | Pro Flash | 10-18 |
| 14 | Invrisil workbench set-piece | Pro Flash | 10-18 |
| 15 | Third shop sign (cards and hat) | Pro Flash | 10-18 |
| 16 | Second owned street door | Pro Flash | 10-18 |
| 17 | Sealed factor's bale | Pro Flash | 10-18 |
| 18 | Invrisil wall_shop ashlar variant (+ cornice tile) | tileset | 8-12 |
| 19 | Liscor civic plain-brick face (a) | tileset | 8-12 |
| 20 | Liscor sandstone sett atlas (market square) | tileset | 8-12 |
| 21 | Riverfarm mature crop tile | tileset | 8-12 |
| | **Firm subtotal** | | **327-643** |
| c1 | Invrisil settee + bar stool in the Library chair's wood (if the Hideout armchair/ottoman clash) | 2x Pro Flash | 0-36 |
| c2 | Invrisil display counter in counter form (if the Library case cannot serve) | Pro Flash | 0-18 |
| c3 | Third shop door (if the Hideout leaf recut fails) | Pro Flash | 0-18 |
| c4 | Crate stack (if the container#29 composition fails) | Pro Flash | 0-18 |
| c5 | Framed work-room door (if the Hideout trim fails) | Pro Flash | 0-18 |
| c6 | Counter pigeonhole-back piece (if the dresser pairing fails) | Pro Flash | 0-18 |
| c7 | Barracks grey flagstone (if the Desert flag floor fails) | tileset | 0-12 |
| | **Contingent subtotal** | | **0-138** |
| | **Total** | | **about 330-780; midpoint about 550 firm + contingencies** |

Against the review's 550-750 (about 1,000 worst case) this drops roughly ten assets outright (3a, 5b, 8a, 8b, 8c, 11b, 12b, 15b, P4, P5) and turns another nine into 0-generation recuts or data pairings (4a, 12d, 13c, 13d, 14d, the chair half of 11a, the shelf halves of 10b/10c, 10d). The remaining big tickets are the Liscor facade kit, the Antinium rig and the two object-state asks (Pallass lit lamp, window night state); together they are about half the firm total. One month of Tier 1 (2,000 generations) still covers everything with about 3x headroom.

## Bundle needs

Unbundled sheets the REMOVE/PARTIAL picks depend on (copy into `wandering_inn_game/assets/` and register, sha-identical as `pc-ext/INDEX.md` does for the others):

- `Pixel Crawler - Hideout 1.0/.../Assets/Tiles.png` (`tiles_Hideout_Tiles.png`): sewers torch (8c), barracks cot and chart (10a), satchel and dresser (10b, 10d), wine armchair and ottoman (11a, 14d), shop-door leaf and framed door (13c, 13d).
- `Pixel Crawler - Hideout 1.0/.../Assets/Light.png` (`slices_Hideout_Light.png`): cone glow slice 2 for 8c.
- `Pixel Crawler - Desert/.../Assets/Ground.png` (`tiles_Desert_Ground.png`): Liscor wall courses and pylons (2), barracks flag floor (5d).
- `Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png` (`tiles_FreePack_Dungeon_Tiles.png`): shadowed nook (12b), framed door alternative (13d).
- Conditional: `Pixel Crawler - Forge 1.2/.../Assets/Tiles.png` only if the civic brick face (a) hue-shift audition is run (5c).
- Dormant pieces from unbundled packs: container#25 / tool_a#26 (Free Pack Tools), container#29 (Free Pack Resources), other#43 / container#42 (Free Pack Pan); plus the Free Pack and Desert sources behind the P2, P3, R1-R5, R7-R10 recuts.

Already bundled and used by the picks: Floors_Tiles (3a, 5a, 5b), Library Tiles (5d, 7, 10c, 10d, 11a, 11b, 11c, 14d), Building_Walls (3b, 4a, 5c-b), Building_Roofs (4b), Cave Props (P6), Cemetery Props (R6, R11), owned `crystal_lamp` and `dungeon_brazier_owned` (7, 8a, 8b).

## Liscor verdict

**Partly.** The warm-city envelope can be assembled from existing options; the brick facade itself cannot.

- Facades: **no.** No Pixel Crawler sheet has a warm fired-brick facade module with openings. The only brick-footed module (Building_Walls (30,0)-(35,11)) is cream plaster on Invrisil's identity sheet and is the same family Liscor's `facade_plaster` already comes from; Forge brick is maroon with lava seams; Furnace Bricks are kiln objects. The facade kit (ask 1) stays the single generation that makes Liscor read as brick.
- Roofs: **partly.** The timber sibling the roof row asks for is on Building_Roofs: plank gable (0,0)-(7,5) and the dormer variant (0,6)-(7,11), same sheet as `inn_roof`, same outline weight. The clay-tile run is either the tinted `inn_roof` as now or one tileset generation bundled with the facade kit.
- City wall: **partly.** Desert Ground's ochre sandstone cap ring (0,7)-(5,11) and face courses (4,8)-(7,11), (0,12)-(5,14) with the blue glyph bands stripped, plus the pylons (0,15)-(3,19) as gate-tower posts, replace the grey castle wall in a warm stone that is neither Invrisil's pale marble nor Pallass's grey ashlar. Only the gate arch needs generating. Cost: Pallass must not take the same block silhouette in beige (R2 dropped).
- Street paving: **yes** for a warm lane: Floors_Tiles' orange packed-earth blob (10,0)-(13,11) with its stone-rim edges, on the sheet Liscor's street already uses. The sandstone sett atlas for the market square is the one paving generation left, at lower priority.
- Civic walls: **partly.** The Adventurers' Guild face (brick band under plaster) exists as Building_Walls (30,0)-(35,5) but needs the user to waive the Invrisil-exclusivity rule for an interior use; the plain brick face for the barracks and Runners' Guild has no honest option (Forge (4,5)-(7,6) is a hue-shift audition at best) and is a 8-12 generation tileset.
- Civic floors: **yes.** Library straight boards (20,10)-(21,11) give the Runners' Guild its own oak floor off the inn's `inn_floor`; Desert Ground's plain grey flag (1,8)-(3,10) is a quiet barracks floor to audition against the current `wall_over_flagstone_v1`.
- Civic furniture and lights: Liscor keeps its copper lamp pair; the barracks cot, duty chart, satchel, dresser, panelled counter and plain chair above give the three rooms distinct jobs without generation; kit rack, weapon rack, request board and pigeonhole shelf still generate.
