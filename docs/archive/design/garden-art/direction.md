# Garden of Sanctuary — direction card

Art-director lane, 2026-07-07 (issue #9 pre-work; spec
`docs/superpowers/specs/2026-07-06-portals-garden-design.md` §2 + §5).
Design-only: nothing here is wired — skeleton_scene/biomes/sprites/moods
are untouched by this lane (Magical Door pipeline owns integration).

## The identity claim (one sentence)

**A formal green sanctuary floating alone in bright sky-mist: one axis
from a vine-wreathed door, through a statue-fountain, up to a misted
rise of colorless statues — symmetry instead of walls, light instead of
lamps.**

The Garden is not a city and carries no city verb. Its verb is **REST** —
and the art says "violence is impossible here" before any mechanic does:
no walls, no darkness, no corners. The map's enclosure is a trimmed
hedge, its only door is flowering, and everything grey in it is a memory,
not a threat.

## The user's taste anchor (benchmark, PIL-scanned)

`potential_assets/_benchmarks/benchmark-formal-garden-fountain.png`
(1600×1600, composed entirely from the Garden Environment pack — its
compositional ceiling). Scan findings (100×100 cell classification +
palette extraction):

- **Formal fourfold symmetry** — a north-south stone-path spine, cross
  arms, hedge-framed quadrant parterres, central tiered fountain, and a
  full-width lily-pond band with statues standing in the water.
- **The parterre beds are area fills**, not fixed props: the benchmark's
  large magenta plots (mean rgb (124,3,76)) are the `[16,416]` swatch
  family tiled with edge shading — beds can be any size.
- **The path is the pack's beige sandstone family** (benchmark path mean
  (137,119,94) = flat cells `[144,16]`/`[128,48]`/`[160,48]`, textured
  `[208,96]`, edge/corner block cols 11–18 rows 0–7) — my first-pass
  scan had misread this block as pergola wood; corrected in picks.md.
- **The benchmark's grade is dusk-dark** (luminance median 57, dominant
  quantized color (24,24,0)). ADOPTED: the composition grammar.
  REJECTED: the lighting — the no-darkness card is binding (spec §2);
  the committed mockup proves the same assets read at day-bright.
- **Statue-in-water** is a ready-made grammar and this card adopts it
  for garden DRESSING (mirrored statue-island ponds). It is NOT the
  memorial grammar: canon puts the remembrance statues on the sacred
  hill in mist (Ch. 7.11), and the overnight plinth→statue idiom needs
  dry ground for the visual_states swap + mist marker. Flagged as an
  open question in handoff.md if the user prefers water-borne
  remembrances.
- **Deep pink flowerbeds as signature accent: CONFIRMED** against the
  quarantine — `#8F024F` magenta is nowhere near Liscor amber, Invrisil
  coin-gold, or Pallass forge-bronze; no other region owns a pink.

## Canon (wiki, Book-17 bar — all features enter at/before early Vol 7)

- [Garden of Sanctuary] page: a domed pocket-space with sky above,
  meadow, pond, and a **sacred hill of statues of the dead** — statues
  "so lifelike that but for color they could have turned and greeted
  you" (Ch. 7.11); dome/climates/pond detail Ch. 7.07. Unlocked early
  Volume 7 (Book 17 is named for it) — spoiler-safe.
- The no-violence sanctuary property is canon (weapons/aggression
  restrained) — spec §5.3 makes it a sim guard; the art's job is to
  make that guard feel inevitable, not arbitrary.
- Player-facing naming: it is only ever "the Garden" / Erin's garden.
  (The Skill belongs to ERIN — spec §5.3; the Vol-9 door-Skill name
  never appears anywhere, per `docs/design/spoiler-cutoff.md`.)

## Palette (measured, PIL) + quarantine check

| Swatch | Hex | Source | Role |
|---|---|---|---|
| Sanctuary olive | `#3E4A1B`–`#474F23` | Garden Tiles.png grass block (62,74,27)→(71,80,35) | floor field |
| Topiary hem | `#727A23` (114,122,35) | hedge top-face tile | the enclosure + hill highlight |
| Deep topiary | `#233A0C` family | cypress/hedge objects | verticals |
| Sky-mist | `#CFE8F5` → white glints | owned `sky_mist_final.png` | the impossible sky (skirt) |
| Memorial stone | ramp `#3E362C / #605646 / #827564 / #A89C8A` | stone-ify ramp keyed to pack statues (130,117,100) | ALL remembrance art |
| Petal accent | `#8F024F` + soft `#CB5B96`/`#E28CB4` | pack flowerbed swatch (143,2,79) | petals, blossoms, flowerbeds |
| Basin water | `#457279` (69,114,121) | pack fountain-water tile | fountain + lily pond |

**Quarantine check (bible discipline 2):** Garden accents are petal-pink,
sky-white-blue, and sanctuary greens. No Liscor amber (the garden needs
no lamps — no darkness), no Invrisil coin-gold-on-marble (the stone here
is bone-beige memorial stone, never polished wealth), no Pallass
forge-bronze-on-slate (no metal, no masonry). The vine door's wood brown
is a material read, not an accent hue, and is cooler/pinker than Liscor's
lamplight amber. PASS.

## Landmark reads (2-second test, first entry)

1. **The axis** — door → sandstone path → statue-fountain → misted
   rise, one straight line of meaning (the benchmark's formal spine).
   A first-time player reads the whole map's order in one glance.
2. **The statue-fountain** — a pale octagonal basin with a lone stone
   figure rising from the water, center of the axis.
3. **The misted rise** — an arc of colorless statues standing in a band
   of white mist at the axis head; one plinth always empty.
4. **The door that shouldn't be there** — a freestanding arched door
   wreathed in flowering vines, set in the hedge line, soft light in
   its gap. The only way in or out; nothing else is built.
5. *(meta)* **The map floats** — beyond the hedge hem there is no
   terrain, only bright glinting sky-mist. Every other map sits IN the
   world; this one sits above it.

## Tile-family inventory

- **Floor:** Garden `Assets/Tiles.png` olive-grass variants (picks.md
  §1) + the beige sandstone PATH family (picks.md §1b, benchmark-
  confirmed) for the axis and cross arms + the flowerbed FILL swatches
  (magenta primary) for parterre plots of any size.
- **Walls/structures: NONE.** The Garden deliberately ships no wall
  family. Blocking is the trimmed-hedge hem (the pack's hedge top-face
  as the `blocked` tile) ringing the playable field. Sanctuary is the
  absence of architecture.
- **Skirt:** owned `sky_mist_final.png` (32px, seamless) — the
  impossible sky. This single choice does most of the identity work.
- **Decor (licensed, picks.md §2):** the fountain composite (large
  octagonal basin + Feminine statue centerpiece — composed this pass
  from PIL region scans, resolving the deferral in
  `docs/archive/design/8a-asset-assembly.md` §5), three flowerbed colors,
  two topiary cypresses, wooden bench, small round basin (birdbath),
  lily-pad + water-rock pond accent, pack "Old" statue as a garden
  dressing statue.
- **Decor, conditional (licensed, Fairy Forest 1.7 — user-suggested,
  evaluated picks.md §Fairy-Forest):** "the Old Tree" — ONE giant tree
  in the pack's own olive daylight variant, anchoring a wilder corner
  (canon 7.07 "plants from every part of the world") IF the wired map
  is meaningfully larger than one screen. Everything else in that pack
  is rejected for the Garden (night-lit register vs the no-darkness
  card; "the only grey is memory"; no licensed recolors — reasons per
  item in picks.md).
- **Memorial props (owned, PixelLab + stone-ify):** gnoll / drake /
  goblin / human statues + the waiting plinth (pixellab-batch.md).
- **Ambience/light:** drifting petals = the existing leaf ambience
  preset recolored to the petal family (`#8F024F` source per
  `8a-asset-assembly.md` §5); hill mist = a white-recolored slow
  ground-fog emitter (nearest existing preset: the sewers dust; flag
  for the wiring task). **Zero PointLight2D** — the one map with no
  lights because it has no dark to push against.

## Mood-card DRAFT (values only, NOT wired)

```
"garden": {
  "_comment": "Issue #9: the ONE map with no darkness (spec §2). The only
   card in the game that is BOTH identity-at-every-phase AND vignette 0.0
   -- day-bright at day, dusk, and night, with no edge squeeze at all.
   Every other map either grades with the clock or pins dark; the garden
   pins BRIGHT. The eyes-closed test is the mood system itself: if the
   screen never dims and never vignettes, you are in the garden.",
  "day":   [1.0, 1.0, 1.0],
  "dusk":  [1.0, 1.0, 1.0],
  "night": [1.0, 1.0, 1.0],
  "vignette": 0.0
}
```

No `arena_moods` entry — combat can never start on this map (spec §5.3
sim guard); an arena card existing for the garden would itself be a bug.

## The memorial's visual vocabulary (issue #9: how a remembrance appears)

The memorial is the hill, not a wall — an open arc of statues on the
misted rise (canon: the sacred hill, Ch. 7.11). Committed reference:
`mockup_owned_memorial_vocab.png` (this dir).

1. **Remembrances are statues, and statues are colorless.** Every
   memorial figure ships through the one stone ramp (stone-ify:
   deterministic luminance→ramp recolor, `potential_assets/
   pixellab_2026-07-07_garden/stoneify.py`) keyed to the pack statues'
   beige. Canon-exact: "but for color they could have turned and
   greeted you." A memorial statue NEVER reuses a living NPC's colored
   sprite (guards the repo's known indistinguishable-prop failure mode)
   — but any figure ever made for the game can be stone-ified into a
   remembrance with zero new art. The ramp IS the vocabulary.
2. **The hill always waits.** From its first unlock the arc ends in one
   empty plinth (`plinth_empty_stone`). New remembrances never appear
   in an empty field — the empty plinth is the standing promise that
   the hill grows.
3. **A remembrance appears overnight.** The `visual_states` seam (the
   dirty_table/unlit_lantern machinery) keyed to an accomplishment
   counter swaps plinth→statue at the story beat's sleep. No toast, no
   GDI line, no progress text (OPAQUE-UNTIL-SLEEP discipline): you walk
   in, and someone new is standing on the hill. The heaviest mist sits
   at the NEWEST statue's feet.
4. **Statues answer one question.** Interact/observe on a statue yields
   a single remembrance line (dialogue_line, present tense, no numbers)
   — the memorial is readable but never a menu.
5. **Race-generic roster, beat-specific meaning.** The four owned
   statues (human / gnoll / drake / goblin) are deliberately unnamed
   figures so any qualifying story beat can claim one — remembrance
   text, not the sprite, carries the specific memory. Vol 1–7 scope
   binds what a remembrance line may name; the depicted figures
   themselves stay generic. (Canon note: the wiki says the hill shows
   each viewer their own dead — the game simplifies to the inn's shared
   remembrances; flagged in handoff.md.)

## Self-review vs the bible's disciplines

1. *Verb-first:* the Garden's verb is REST (not a city verb); every
   surface above serves it — no walls, no lights, no commerce. PASS.
2. *Palette quarantine:* checked above, PASS.
3. *Population texture:* designed value = EMPTY. No extras, no vendors;
   the only figures are stone. (Erin herself visits via story beats,
   not as a resident spawn — wiring call.) PASS.
4. *Traversal signature:* one door, ever. The Garden extends Liscor's
   "doors into depth" — the deepest door in the game. PASS.
5. *PC race reads:* n/a (no population) — but the memorial roster spans
   all three playable races + goblins, so every player's story can be
   remembered. PASS in spirit.
6. *Music key:* out of art scope; recommend near-silence + wind/chimes
   (flagged in handoff.md).
7. *wi-art-and-sprites:* props-over-tiles honored (statues, door, bench
   are props); every licensed pick is manifest-only, PIL-measured,
   windowed-verify-before-wiring noted in picks.md; max-fidelity honored
   (real statues, not recolored rectangles); no pack PNG was ever loaded
   into context (PIL numeric scans only; the two mockups were composed
   programmatically and reviewed as MY outputs).

## Mockups (the user's taste-review surface)

- `mockup_licensed_garden_320.png` + `_4x.png` — full-scene composite,
  **licensed content: NOT committed**, lives at
  `potential_assets/pixellab_2026-07-07_garden/mockups/`.
- `mockup_owned_memorial_vocab.png` — owned-only (PixelLab + own
  compositing), committed in this dir: the memorial vocabulary + prop
  roster + sky tile.

## Manifest entries required (licensed picks; controller lands them)

Already present (A1, `8a-asset-assembly.md`): `assets/tiles/garden/Tiles.png`.
New this lane:
- `assets/props/garden/Feminine-Idle-Sheet.png` (Pixel Crawler — Garden
  Environment `Enemies/Feminine/Idle-Sheet.png`) — fountain centerpiece
  crop (frame 0).
- `assets/props/garden/Old-Idle-Sheet.png` (same pack, `Enemies/Old/
  Idle-Sheet.png`) — garden elder-statue dressing prop.

Both: `verdict: "FORBIDDEN"`, `bundle: true`, `fallback: "placeholder"`
(the standard Pixel Crawler shape).
