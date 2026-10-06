# Holistic art review and harvest direction

Review date: 2026-10-05. Status: **APPROVED for execution**.
The user approved this program on 2026-10-05: “Execute on your recommendation.”
Issue #564 owns execution and its documented regional/layout/UI choices.
The regional identities, canon cutoff and existing gameplay gates remain binding.

## Recommendation

Use the harvest to build **one coherent illustrated pixel world**, with warm,
inhabited interiors and distinct regional architecture. Prioritize composition,
building mass, readable objects, and the amount of world visible on screen.
The most valuable change is a scene that tells its own story before its toast
appears. More detail in each individual sprite will not accomplish that alone.

I recommend substantial scene redesigns, including **one new Invrisil
cross-street**, a reorganized inn common room, a landscaped Garden, and a
visible lower-city backdrop for Pallass. Keep the existing gameplay identities:
Liscor asks you to belong, Invrisil to deal, and Pallass to qualify.

The alternatives are:

| Approach | Benefit | Cost / limitation | Decision |
|---|---|---|---|
| Replace individual sprites within existing compositions | Fastest coverage and public fallback improvement | Preserves empty spaces, weak architecture, visual repetition and framing problems | Retain for clear identity fixes and fallback coverage |
| Recompose regional scenes around a coherent pixel vocabulary | Stronger identity and much better use of the harvest | Requires layout work, grouped comparisons and renewed route evidence | **Recommended** |
| Replace the game with a finer painterly or isometric presentation | Can support richer illustration | Requires new terrain, rigs, occlusion, camera and interaction conventions; much of the harvest would need adaptation | No evidence yet that this serves the game better |

## What was actually reviewed

- Baseline game: `f35270f07561aa3c533c86625b39dc03245fbecf`, native
  `Godot 4.7.stable.official.5b4e0cb0f`, 1280×720. All 185 files named by
  the local asset manifest were present; this is the art-rich overlay view.
- [PR #563](https://github.com/GabrielGLevine/wandering-inn-rpg/pull/563):
  the complete plan-only diff, its fallback design and W0–W6 wave table.
- All 32 current maps: JSON layout/assembly review plus a fresh **62-view
  windowed camera survey**. That survey uses teleports in cold-start state;
  it proves rendering and supplies framing references, not traversal,
  gated-content availability, or a player's route through those maps.
- Ten existing windowed scripts: `atmosphere_check`, `invrisil_walkthrough`,
  `pallass_peek`, `riverfarm_walkthrough`, `garden_walkthrough`,
  `sewers_walkthrough`, `status_first_encounter`, `char_creation`,
  `gear_loop`, and `gate_district_walkthrough`. Together they produced
  **85 screenshots**. Their existing assertions passed, as did `load_gate`.
  Every retained run had exit 0, its PASS marker, passing `result.json`, and
  no error/warning noise. Screenshots were inspected in sequence boards,
  with key findings read at full size. The debug overlay was off.
- All five harvest lane manifests; visual samples of 69 ready props/set
  pieces, 23 new NPCs, directional/animation contact sheets, icon families,
  UI kits, terrain previews and key art. This is not a per-frame acceptance
  review of every candidate.

The manifests contain **1,275 candidate records**: 691 READY, 87
USABLE-WITH-FIX, and 497 ALT. The harvest index reports 1,997 generations;
generation counts, candidate records, and animation frame files are different
measures. A manifest's READY verdict is a candidate assessment, not proof that
the asset has passed in-game composition, anchoring, or animation checks.

Local visual review:
`potential_assets/art_direction_review_2026-10-05/index.html`.
It includes the baseline gallery, all map survey views, harvest samples,
the proposed Invrisil connection diagram and the generated concept board.
This entire directory is ignored and must remain out of the public repository.
Reproduction scripts, complete logs and verdicts are preserved there.

The concept board was generated with the built-in image tool. It is a
**composition and mood reference**, not a screenshot, a canonical building
plan, or production art. Its fine texture and character detail exceed the
current game's pixel scale and should not become the rendering target.
Its inn patrons also do not establish any character casting or race mix.

## Findings that should drive the work

### Architecture carries less identity than the writing

Invrisil's arrival frame is dominated by a repeated paving grid and a marble
rectangle. The shopfront band is outside that frame. Even the later
`06_facade_scale_shock` shot shows a low continuous strip rather than looming
urban buildings. Pallass has a readable lift and forge glow, but isolated wall
panels and a dark border do not yet communicate a vast stacked city.

Evidence: `captures/invrisil_walkthrough/00_scale_shock_arrival.png`,
`06_facade_scale_shock.png`; `captures/pallass_peek/00_pallass_market_arrival_corner.png`,
`13_molten_seam.png`. Paths in this report are relative to the local review
directory unless otherwise stated.

Build facades, thresholds, corners and sightlines as complete structures.
Place their strongest silhouette inside the arrival camera's actual view.
Buildings need enough mass to contain their doors and implied occupants.
Scaling a roof independently of its facade will produce another seam.

### The floor often wins the contrast contest

Invrisil's tight grid, the horizontal grass seams in Riverfarm and Rags's
camp, and the densely speckled floodplains attract attention across the whole
screen. The Garden has the opposite problem: a very plain rectangular lawn
with a fountain and a bed provides little environmental discovery.

Evidence: `captures/_art_review_all_maps/invrisil_boulevard__center.png`,
`riverfarm_village__center.png`, `rags_camp__center.png`,
`floodplains__center.png`, `garden_sanctuary__center.png`.

Use quieter base materials with occasional authored variation. Paths should
describe actual traffic between doors and stations. Terrain edges should
connect materials; outlining every repeated tile creates a tiled carpet.
The harvest's Wang sheets are useful for transitions but still need tiled
scene reads. The grass v2 improves on v1's neon hue; neither preview alone
establishes the best in-game grass. Cave boundaries must not become luminous
outlines around dark floor islands.

### The interface is a large part of the art direction

The current world viewport shrinks to keep help and controls clear. That
repair protects visibility, but long skill lists leave a shallow world view
and a large dark lower band. In the Invrisil arrival capture the world runs
roughly from y=62 to y=438, about 52% of the screen height. Enlarging the map
does not increase how much architecture the player sees at once.

The cream-and-turquoise chrome is consistent, but large parchment textures
and repeated scroll borders compete with the world. Inventory has a large
textured empty middle band; the new icon library can help the item list and
selected-item hierarchy without adding more permanent panels.

Evidence: `captures/invrisil_walkthrough/00_scale_shock_arrival.png`,
`captures/sewers_walkthrough/00b_sewers_lit.png`,
`captures/gear_loop/00_full_pack_top_cursor_rusty_sword.png`.

Recommend a slim walnut frame, quiet ivory reading surfaces, restrained brass
selection and one clearly visible focus state. Use the harvest's parchment,
wood, hotbar and journal pieces as one selected family, not all ten kits.
Keep text on a calm surface and decorative pixels mostly at edges. Keep
text as real text, including labels, numerals and button captions.

Recommend showing field descriptions on selection or explicit request,
instead of retaining the full list during ordinary exploration. Preserve
discoverability and the existing help access. This changes the current
first-sleep/default-help choice and requires a taste decision coordinated
with #507 and the mobile work. It must retain the viewport-clearance repair.
Do not obtain room for the world by shrinking readable text or touch targets.

### Distinct roles still share generic visual vocabulary

Hedault's room, the barracks, stationer, guest rooms and guilds often reuse
the same counters, books, rugs and doors. Rags's camp currently reads as
boulders, greenery and a crate. In the alley combat capture, the footpads
share near-identical silhouettes and the arena is an earthy open board,
which weakens continuity with the paved city outside.

Evidence: `captures/_art_review_all_maps/enchanter_shop__center.png`,
`barracks__center.png`, `stationer__center.png`, `rags_camp__center.png`;
`captures/invrisil_walkthrough/02b_footpads_surround_opens.png`.

The harvest answers this directly: proper shopfront doors, a proof bench,
real market stalls, goblin tents and cooking spits, distinct civic props,
named NPC rigs and enemy-role rigs. Give these a higher priority than purely
decorative extras. A tagged cargo pallet must look different from an ordinary
crate; a different name in a toast does not supply that difference.

### Preserve the atmosphere that already works

The inn's warm hearth pools, the forge's orange-white heat, the witch hollow's
canopy framing, and cool outdoor night grades already establish mood.
Water, light flicker and ambience systems exist. The older strategy document's
diagnosis of a wholly static, flat-lit world is no longer the current baseline.

Evidence: `captures/atmosphere_check/01_dusk.png`,
`captures/pallass_peek/13_molten_seam.png`,
`captures/riverfarm_walkthrough/04_arrived_witch_hollow_day.png`,
`08_village_night.png`.

Improve motion and local lighting selectively. Keep environmental motion
smaller than player, threat and interaction tells. Dark-map outlines and
nearby landmarks need separation from their ground, while [Light] should
still reveal useful detail. Do not flatten all dark scenes into daylight.
These runs do not validate production animation cadence or audio quality.

## Proposed visual grammar

| Layer | Direction |
|---|---|
| World geometry | Keep the 16px logical cell and high three-quarter top-down view; group building/furniture parts into coherent masses |
| Pixel treatment | Crisp clusters and consistent apparent pixel size; measure visible bounds, not canvas dimensions; judge at gameplay scale |
| Ground | Lowest visual contrast; quiet materials, selective wear, connected edges, deliberate paths |
| Structures | Stronger silhouettes and material families; thresholds visually attached to their facades |
| Characters | Consistent feet plane and population scale; distinct heads, clothing and equipment for named identities |
| Landmarks | One clear focal structure per camera composition; secondary props support it |
| Interactions | Readable silhouette plus consistent focus/selection; decorative brightness must not imitate actionable feedback |
| Light | Consistent implied direction within a scene; local material-aware grading and grounded contact shadows |
| UI | Calm ivory paper and dark wood; sparse ornament; readable type; selection distinguishable beyond hue |

Do not indiscriminately remap every sheet to one palette. That could damage
licensed art and erase regional identity. Set a shared neutral/shadow language,
then curate or adapt the assets that visibly clash. Apply the same visual
grammar to official primaries and public fallbacks.

## Regional changes

### The inn: the strongest first pilot

Keep the current 16×10 envelope for the first composition trial. Organize
the north wall into a hearth/kitchen zone and a bar with back shelving. Make
two or three table clusters read as places where people sit. Put Erin at a
service station with a clear approach. Connect entry, bar, stairs and Magical
Door by readable circulation, with clear thresholds and no foreground
furniture obscuring their approach cells.

Harvest candidates: `set_pieces/inn_hearth.png`, `bar_counter_stools.png`,
`back_bar_shelf.png`, `kitchen_prep_counter.png`, `long_tavern_table.png`,
plus the dirty/clean table pair. Treat multi-cell art as a blocking and
occlusion problem as well as a sprite replacement. Re-layout the patrons to
fit the stations; do not overlay a long bar across unchanged interactive cells.

If the correctly scaled furniture cannot preserve circulation, audition an
18×12 common room. That is a conditional blockout decision, not a requirement
to enlarge the map now. Upstairs should read as a landing and guest-room
fronts rather than another open common room; the player's room remains compact
and personal. Inspect both collapsed and expanded help views before choosing
the final room size.

### Liscor: rebuild the market and give civic rooms their jobs

Keep the 32×20 street extent. Anchor the gate area with Watch activity, use
purpose-built bread and Silverfang stalls, and strengthen the route to the
guild. Retain warm stone, timber and worn streets; use named local people,
not an anonymous metropolitan crowd. The barracks needs kit racks, training
order and duty furniture. The guild needs a convincing reception/board wall;
the Runners' Guild needs delivery sorting and a distinct desk arrangement.

Harvest candidates: bread stall, fruit/vegetable stand, fish stall, guard
booth, request board, dray rank, Renn/Vess/Yelra/Watch rigs. Krshia's stall
has a flagged ground-plate issue: fix and compare it before using it.
Avoid adding another outdoor district merely to consume the collection.

### Invrisil: yes, add a useful street

Recompose the existing 28×18 boulevard as a fountain square framed by
two-storey shopfronts, with an arrival view containing both architecture and
the landmark. Break up the hard rectangular marble patch with a designed
curb and paving transitions. Shop doors should have unmistakable thresholds
and signs; leave a clear pedestrian lane beside the carriage and planter
clusters. Preserve scarce coin-gold on pale stone and glass.

Add **one roughly 22×14 commercial cross-street**. Give it actual destinations
by moving the existing stationer and Adventurer's Rest entrances onto it,
while keeping Hedault and the Coyle frontage on the boulevard. Link that
street to both the boulevard and the existing 20×14 alleys, creating a loop:

```text
                  Enchanter → Work room
                      |
Magical Door → Boulevard square ─── Cross-street → Stationer / Rest
                      |                 |
                      └── Alleys ───────┘
                            |
                          Parlor
```

Use front/back contrasts: glass, lamps, signs and formal paving at the front;
service doors, cargo, worn masonry and tighter turns behind it. A second
alley connection needs an explicit gate/topology review so it does not bypass
the footpad/sneak encounter or progression requirements. The loop is a
recommended layout, not yet an approved change to those gates.

Harvest candidates: `invrisil_rooftop_line`, distinct shopfront door/signs,
glazier and teahouse fronts, noble carriage, ornate bench, planters and
streetlamp. The new roofline is supporting architecture; it cannot by itself
turn the low facade strip into a convincing city block.

The cross-street is a game composition proposal, not a claimed canonical map.
The wiki verifies a Cloth District (7.15 R), Satin's Way (7.20), and magical
commerce (3.01 E), all within the cutoff. A later Cloth District-specific
street can use that grounding; no new named shop or post-cutoff landmark is
required for this proposal. [Invrisil wiki](https://wiki.wanderinginn.com/Invrisil),
[7.15 R](https://wiki.wanderinginn.com/Chapter_7.15_R).

### Pallass: show the city under the player

Keep the two existing 26×11 playable terrace maps. Strengthen the continuous
rising structure at the back and render distant lower terraces beyond the
front parapet. Use cold white lamps to separate access routes, bronze for
engineered fixtures, and forge heat locally. Group the lift, queue and permit
desk into a recognizable civic station. Give the forge material storage,
tool walls and a contained molten channel rather than an exposed bright strip.

Harvest candidates: brass steam pipes, forge parapet rail, ingot stack,
tagged cargo/civic props, smith/apprentice/lift-attendant rigs. Generated
concept art is useful for a lower-city backdrop or structural mass absent
from the harvest; flatten and pixel-adapt it before production use.

The wiki's stone construction, stacked floors and elevators support this
spatial emphasis. Preserve beige structural stone as well as the game's
slate/bronze material vocabulary; do not turn every building into black metal.
The ninth-floor smithing quarter is grounded in pre-cutoff material.
[Pallass wiki](https://wiki.wanderinginn.com/Pallass),
[chapter 6.09](https://wanderinginn.com/2019/04/20/6-09/).

### Riverfarm and the witch hollow

Keep the 24×16 village and its river relationship. Replace the striped ground
read, connect the longhouse, mill and well with worn paths, and form working
yards using the harvested well, granary, wheelwright corner, garden patch,
pens, pier and water wheel. The mill should visibly work at the river rather
than rely on its name. Give the longhouse a communal table and domestic
storage, and the mill recognizable work equipment.

The 12×14 witch hollow already has strong canopy and hut framing. Retain
its distinctive green/cool palette and concentrate on visible approach paths,
ritual/work objects and canopy occlusion. Do not replace its successful hero
hut simply because a newer file exists. Witches need their own interior prop
vocabulary rather than a smaller generic inn.

### Garden of Sanctuary

The current 14×12 lawn needs composition most urgently. Build three connected
pockets within that extent first: fountain/rest, planted shelter, and a
quiet memorial rise. Introduce irregular paths, flower masses, hedge breaks
and a readable resting seat. Keep the memorial area restrained and the
Garden's special brightness independent of ordinary outdoor night.

Keep named or story-specific memorial imagery within the current cutoff and
existing content. Use existing garden/foliage art and the fountain candidates
before generating more. If the three pockets require overlap or cramped
approaches at gameplay scale, audition an 18×14 envelope with broader framing;
the choice follows the blockout, not the number of available assets.

### Floodplains, Rags's camp and the ruin

Keep the 40×26 floodplains. Its inn exterior and gate are already useful
anchors; reduce repetitive grass and compose the travel sequence around
landmarks, the pond and clear junctions. Differentiate local ecology with
the new creature rigs instead of adding more unrelated encounters.

Rebuild the 12×9 camp around tents, cooking, supplies and a lookout. The
harvest has hide tents, a cooking spit, weapon rack, palisade and lookout.
Use these as purposeful clusters and preserve Rags's identity. If proper
footprints cannot fit the existing interactions and route, consider 16×12
after a blockout. Avoid changing encounter population or balance as an art
side effect.

The 20×14 ruin surface needs broken architectural masses, an excavation
edge and a legible descent. Currently creatures dominate a largely open dark
field. The harvest's dig tent, survey stakes and dungeon props can support
that composition. Generate a structural landmark only if an in-hand candidate
cannot carry it; preserve existing gate and discovery order.

### Sewers and dungeon rooms

Retain the current map extents and tactical topology. Give the sewer canal
a constructed service-channel identity with wall piers, access ladders,
grates and local maintenance objects. Differentiate deep tunnels, trapped
halls and seal vault by architecture and silhouettes rather than by uniformly
darkening the same props. Use the harvested portcullis, standing brazier,
sarcophagus and chains where semantically appropriate.

Make the vault's seal the dominant landmark. Separate statues, wards,
constructs and rewards at the feet plane. Dark silhouettes need local value
separation, especially before the player activates a light skill. Avoid
decoration on required movement or line-of-sight cells.

## Characters, combat, icons and key art

The male human candidate is especially valuable because its existing-account
rig is documented as a sibling of the female human. Audition the two together
and beside Drake/Gnoll options. Normalize visible height and feet, not frame
size. Named NPCs need distinct identities; the new Watch and regional rigs
can resolve the existing borrowed-character reads.

Most L3a candidate records are USABLE-WITH-FIX. Their mixed animation canvases,
vanishing equipment/tails and facing corrections make a bulk swap unsafe.
Accept whole rigs with south/east/north, walk/idle transitions, hit and death
reads. Use the manifest's replacement clips, then inspect motion at production
timing. Establish separate field and combat size budgets where tall creatures
would cover neighbours or bars. Keep team, active turn and target indicators
clear without tint being the only distinction.

Combat boards should share the surrounding location's material and prop
language while keeping the tactical ground quieter. The Invrisil footpad
board is the first continuity pilot. Rig and art changes must leave roster
and balance untouched unless separately authorized.

For icons, select **families of co-visible actions**, not isolated winners.
Spear, sword and spell variants need distinct shapes at actual slot size.
Use native 16px candidates where those are clearer; a 32px illustration
reduced into the slot is not automatically better. Item icons belong in list
rows and selected-item previews; speculative class emblems should wait for a
useful presentation surface rather than create a new panel to house them.

For title art, `title_backdrop_pro_v1` is the strongest available candidate
for an inn-and-walled-city composition. Audition title/menu overlays and phone
crops before selecting it. The hanging inn-sign emblem is a better primary
identity than a generic martial crest. Act cards need one deliberate visual
family: the collected candidates currently vary in perspective and palette.
Select for story and cutoff fit, remove signatures/baked lettering, and verify
each composition independently. Do not use key art to promise a rendering
style the actual game does not deliver.

## Amend PR #563 before broad execution

Keep its whole-record fallback mechanism, geometry/anchor handling, dual-build
pilot and best-art-wins ruling. Add **scene coherence as an eligibility
condition** for that ruling. The unit of visual approval should be a complete
scene or a co-visible family, with per-asset choices recorded underneath it.

1. Add a direction-and-pilot stage before broad W1–W6 selection: inn, Invrisil
   arrival, Pallass terrace, one dark board and one menu. First decide the
   intended pixel treatment, architecture scale and chrome family.
2. Run W0's reversible fallback infrastructure independently. A crate proves
   resolution; it does not prove the art direction.
3. Deliver the inn pilot with its related props, ground, NPC scale, light and
   HUD framing. Then deliver regional slices. Keep the existing lane issues
   as inventory/dependency records, but compose their outputs by location.
4. Separate geometry-preserving fallback coverage from the new layout program.
   W5 currently promises unchanged blocking/reachability. An extra street,
   larger furniture footprints or a Garden re-layout needs explicit topology
   acceptance, fixture changes and actual door/encounter/return-route evidence.
5. Resolve the player-fallback contract: W1 includes `pc_human_m`, but W0
   forbids every `pc_*` fallback target. Either use a measured outright primary
   replacement for that player rig, or define a player-to-player fallback rule
   that still prevents NPCs from borrowing player skins. Do not quietly escape
   the player-only rule by giving the same rig an anonymous alias.
6. Bring terrain and chrome into the first scene pilots. Deferring both until
   after prop winners are selected makes those decisions dependent on surfaces
   that will soon change. A biome fallback must cover map-local floor layers
   and wall sheets too; resolving only `biomes.json` will leave partial scenes.
7. Close a wave on actual scene evidence and explicit remaining defects,
   not a quota of files wired. READY/ALT counts are not completion criteria.

## Proposed order and review boundaries

| Stage | Concrete result | Review boundary |
|---|---|---|
| Direction | This report, baseline gallery, composition concept and Invrisil loop | User chooses the substantial taste/topology direction |
| Foundation | W0 dual-build fallback pilot; agreed scale/chrome choices | Registry/lint and real public/overlay crate evidence |
| First scene | Inn composition plus compact-help/chrome audition | Actual new-player arrival, chores, conversation, stairs and door; day/dusk; desktop and target phone layouts |
| Cities | Invrisil loop/architecture, Liscor market, Pallass terrace depth | Door pairs, encounter/gate preservation, return routes, crowd separation and regional arrival views |
| Remaining world | Riverfarm, Garden, camp, ruin and underground identities | Region-specific triggers and topology, work-state before/after pairs |
| Roster/polish | Complete accepted rigs/icons, ambient motion and key art | Production animation reads, co-board/co-kit comparisons, title crops |

Before a direction slice is accepted, capture the same gameplay view before
and after, with the primary build and its public fallback. Include the full
HUD, interaction state, day/night where relevant, and an unoccluded landmark
view. Changed interactions need trigger → domain event → rendered confirmation
→ state proof and a windowed read. Changed footprints need blocking tests;
changed paths need actual movement and doors from both sides.

Phone layout, browser touch, physical iPhone Safari/Android Chrome, production
animation timing, and audio remain **unproven by this desktop review**.
Existing mobile work and prior taste rulings must be reconciled before the
relevant changes land. No game files, assets, PRs or issues were published or
merged as part of this review.
