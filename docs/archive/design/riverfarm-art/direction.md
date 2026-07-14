# Riverfarm — art direction card (8b pre-work, 2026-07-07)

Region: **Riverfarm village** (~24x16) + **the witch's hollow** (~12x10),
per `docs/superpowers/specs/2026-07-06-riverfarm-design.md`. Art-director
lane deliverable — direction + sourced/generated art only; NO wiring
(skeleton_scene.json / biomes.json / sprites.json / moods.json untouched;
the Magical Door pipeline owns integration).

## The verb (city-identity-bible discipline)

The bible's three cities ask BELONG / DEAL / QUALIFY. Riverfarm is not a
city and must not read as one — it asks the player to **TEND**: everything
in frame is something somebody grew, raised, thatched, or owes. The
village reads HANDMADE next to Liscor's stone — no dressed masonry
anywhere; timber, thatch, loam, and raised earth only. The witch's hollow
is the inverse statement of the same verb: a garden nobody admits is a
garden, where tending is CRAFT and prices are owed. The contrast between
the two maps is the storytelling (spec §1).

## Palette (hex swatches measured from actual picks/gens)

### Riverfarm village — "harvest light"
| Role | Hex | Source (measured) |
|---|---|---|
| Grass base | `#699030` | topdown grass_01 mean (105,144,48) — same tile family as floodplains, continuity with overworld |
| Wheat gold (signature) | `#d8c060` | PixelLab wheat tileset upper terrain |
| Thatch straw | `#f0c048` / `#d8a848` | cottage/longhouse roofs (dominant swatches) |
| Loam / tilled earth | `#603030`→`#4e3018` | wheat tileset lower terrain + Farm.png plots |
| Timber | `#784830` | longhouse/windmill walls |
| Clay daub cream | `#a89078` | cottage walls (canon: "clay deposits around Riverfarm") |
| Crop green | `#5d7822` | Farm.png crop rows (93,115,37) |
| Hearth glow (night only) | `#ff9640` | window PointLight2D vocabulary, sparse |

### The witch's hollow — "green shade"
| Role | Hex | Source |
|---|---|---|
| Underwood grass | `#0c522c` | Fairy Forest Tiles (2,2) flat (12,82,44) |
| Deep-shade canopy | `#1a2a1f` | FF Tree.png y457 row (25,40,30) |
| Forest path | `#46422a` | FF Tiles (9,2) (70,66,41) |
| Moss roof / cottage | `#186048` / `#30a860` | PixelLab witch cottage dominants |
| Fae glow (accent) | `#603d7d`→`#8a5fbf` | FF glow-stones (96,61,125) |
| Firefly | `#d8e65a` | ambience emitter dots |
| THE one warm window | `#ffaa44` | witch cottage — the single warm source in the map |

### Palette-quarantine check (BINDING, bible discipline 2)
- **Liscor amber** = warm lamplight ON grey stone (light role, interior/
  street). Riverfarm's straw-gold is a matte MATERIAL under open daylight
  — texture-heavy thatch/wheat, never a light accent; night windows are
  sparse and the village night grade is deep blue (spec: "deep-blue
  nights"). No role collision.
- **Invrisil coin-gold** = metallic gilt on pale marble. Riverfarm gold is
  desaturated organic straw (`#d8c060` vs metallic `#e8c547` on white) —
  different value context (on green/loam, not marble) and zero specular
  read. No collision.
- **Pallass forge-bronze-on-slate** = industrial bronze + slate + furnace
  orange. Nothing bronze, slate, or engineered in Riverfarm. No collision.
- **Hollow fae-purple** collides with nothing (Pallass crystal lamps are
  pale blue-white; Fairy Forest purple is canopy-dark).

## Landmark reads (what a first-time player recognizes in 2 seconds)

1. **The windmill** (village NE, by the wheat fields) — the tall
   silhouette that says "farming village" from any screen position;
   nothing in Liscor/Invrisil/Pallass shares it. (PixelLab, owned.)
2. **Wheat-field bands** — solid harvest-gold field rectangles with wang
   edges; field LINES over open grass are the region's ground signature.
3. **The longhouse** — one long thatch ridge, twice any cottage's width:
   the communal center (spec §1), quest-giver anchor (headman).
4. **The river + dock** (canon: "farming land fed by a river," wiki
   Riverfarm, ch. 3.00-3.01 E) — Free Pack water blue + plank pier;
   benchmark-anchored (see below).
5. **North-edge earthworks** — raised raw-earth rampart line hinted at the
   map's north boundary: the emperor's works as DRESSING ONLY (Laken
   himself out of v1 scope — flagged in handoff).
6. **Hollow: the ONE warm window** — the witch's cottage light inside a
   cool green-dark frame; the player's eye goes there first, and that IS
   the design (spec: "the contrast IS the storytelling").

## Tile-family inventory

### Village (floor/walls/decor/scatter)
- **Floor**: topdown grass_01/03 (IN-USE family, floodplains continuity);
  dirt lane = topdown dirt_01 (street-biome tile, keeps "unpaved" read);
  wheat field = **PixelLab wang tileset** (owned, 16 tiles, corner bits
  SE=1/SW=2/NE=4/NW=8); tilled plots = wang tile 0 (pure loam) + Farm.png
  crop-row props on top.
- **Structures** (all PixelLab, owned): cottage A (64x64), cottage B
  (64x64), longhouse (112x64), windmill (64x96), well (32x40), earthwork
  rampart (112x32), fence front-face (32x48), fence N-S (32x64), dock
  pier (32x48), rowboat (32x48).
- **Decor/scatter**: haystack + scarecrow (PixelLab); Farm.png crop rows
  (6 crop types x growth stages — licensed picks, see picks.md);
  Vegetation.png trees in GREEN + AUTUMN (orange/red) variants — autumn
  trees are the "harvest light" edge dressing; Admurin Pig/Piggy/Boar for
  livestock pens (catalog: "farmstead dressing", already cast).
- **Water**: Free Pack Water_tiles — flat blue fill (2,7) + animated
  4-frame bank-edge strip (rows 0-4, 6-col frame stride).
- **Ambience/light**: day = golden identity grade; dusk/night = deep blue
  with sparse warm windows (mood draft below). Optional wheat-sway: the
  field is a tileset, so sway ships later as a shader/particle pass —
  logged as a non-blocking juice item for VISUAL-LOG.

### Hollow (floor/walls/decor/scatter)
- **Floor**: Fairy Forest Tiles grass fill (2,2) + textured variants;
  path (9,2); pond block px[112,192,80,80].
- **Walls/enclosure**: Fairy Forest Tree.png — deep-shade y457 row,
  sizes 186x215 / 111x146, ringed as canopy border (blocked cells).
  "Bent trees + sway shader" (spec) — the sway shader is a wiring-time
  item; trees chosen with asymmetric silhouettes.
- **Structure**: PixelLab witch cottage (80x80, owned) — mossy sagging
  roof, warm windows, crooked chimney.
- **Decor/scatter**: FF glow-stones (purple, scaled ~0.55 so they read as
  stones, not blooms — mockup-verified), FF mushroom clusters + stumps,
  Farm.png green crop rows as herb garden, ritual clearing = glow-stone
  ring on open grass (SE quadrant).
- **Ambience/light**: firefly emitter (existing atmosphere-layer
  pattern), ONE warm PointLight2D at the cottage window, fae-purple dim
  glows on the stones.

## Mood-card DRAFT (values only — NOT wired; moods.json untouched)

```
"riverfarm_village": {
  "_draft": "harvest light: golden day, deep-blue night, hearth windows",
  "day":   [1.06, 1.0, 0.88],
  "dusk":  [0.55, 0.45, 0.70],
  "night": [0.26, 0.30, 0.55],
  "vignette": 0.35
},
"witch_hollow": {
  "_draft": "green shade: cool underwood at all phases; dusk is the map's home key; one warm window carries the night",
  "day":   [0.72, 0.92, 0.78],
  "dusk":  [0.40, 0.58, 0.50],
  "night": [0.20, 0.34, 0.30],
  "vignette": 0.50
}
```
Rationale: village day tips warm (only map with a warm day grade — harvest
light); hollow never reaches identity white even at day (canopy). Hollow
vignette 0.50 > sewers' 0.45 — enclosure without underground pin. Values
eyeballed against the graded mockups; wiring pass re-tunes on windowed
screenshots per the standing rule.

## Benchmark verdict (controller input, 2026-07-07)

`potential_assets/_benchmarks/benchmark-farmstead-river-dock.png`
(1600x1600, provenance unstated) — PIL-scanned, never rendered into
context. Vocabulary maps to in-hand Pixel Crawler Free Pack: river blue
`#3080c0/#3090d0` ≈ Water_tiles fill (62,146,209) + its animated banks;
grass `#306000/#307800` ≈ Floors_Tiles/grass family (51,119,4); plank
browns `#904818/#784818` ≈ FP timber; red-roof buildings ≈ FP Buildings
Walls+Roofs. ONE element has no confirmed in-hand source: the chartreuse
gold field fill (`#b0a010`) — covered instead by the owned PixelLab wheat
tileset (warmer `#d8c060`, deliberate). **Verdict: ACHIEVABLE as a
composition ceiling.** Adopted from it: river frontage + working dock as
a village landmark (also canon-true). Deliberate divergence: our roofs
are thatch (handmade identity), not the benchmark's red shingle.

## Mockups (the taste-review surface)

Licensed composites — gitignored, NEVER committed (charter licensing rail):
```
potential_assets/pixellab_2026-07-07_riverfarm/
  mockup_licensed_riverfarm_village_day.png      (320x180 native)
  mockup_licensed_riverfarm_village_day_4x.png   (1280x720)
  mockup_licensed_riverfarm_village_dusk.png     (+ _4x)
  mockup_licensed_riverfarm_hollow_dusk.png      (+ _4x)
```
Composer script: `rf_mockup.py` in the same dir (reproducible).

## Manifest entries required for licensed picks (controller lands these)

| Manifest path | Source pack | Covers |
|---|---|---|
| `assets/props/free_pack/Farm.png` | Pixel Crawler Free Pack 2.1 | crop rows (6 types x stages), plot dressing |
| `assets/props/free_pack/Vegetation.png` | Pixel Crawler Free Pack 2.1 | green + autumn trees, bushes |
| `assets/tiles/free_pack/Water_tiles.png` | Pixel Crawler Free Pack 2.1 | river fill + animated banks |
| `assets/tiles/fairy_forest/Tiles.png` | Pixel Crawler Fairy Forest 1.7 | hollow grass/path/pond |
| `assets/props/fairy_forest/Props.png` | Pixel Crawler Fairy Forest 1.7 | glow-stones, mushrooms, stumps |
| `assets/props/fairy_forest/Tree.png` | Pixel Crawler Fairy Forest 1.7 | hollow canopy trees |
| `assets/props/admurin/` (Canines already?) | Admurin's Freebies | night wolf pack (see handoff) |

(All Pixel Crawler/Admurin entries: `verdict:"FORBIDDEN"`, `bundle:true`,
`fallback:"placeholder"` — same shape as existing entries. PixelLab
outputs are TIER-PUBLIC/committable and need `assets/LICENSES/
pixellab-ai-generated-verdict.md` provenance notes at wiring time, not
manifest entries.)

## Canon references (wiki.wanderinginn.com, checked 2026-07-07)

- **Riverfarm** (wiki /Riverfarm): "a small village of around sixty
  souls" on "an area of farming land fed by a river" (ch. 3.00-3.01 E);
  relocated + grown past a thousand under Laken; "clay deposits around
  Riverfarm" (→ clay-daub walls); witches seek shelter and Laken deals
  with them in Vol 6 (ch. 6.34-6.47 E). All within the Book-17 bar
  (spoiler-cutoff.md item 3 lists "Witch arc/Belavierr: Volume 6 — safe").
- The wiki gives NO building-material canon beyond the clay deposits —
  thatch/timber is a design inference from "village register," flagged
  as such (not canon-contradicting; nothing says stone).
- Spec-directed, not re-verified here: longhouse, north-edge earthworks
  (Laken out of v1 scope — dressing only). Witch NAME selection is
  content-time (handoff flags the register question).

## Self-review vs the bible's disciplines

1. **Verb-first**: TEND named above; every landmark is a worked thing
   (mill, field, dock, rampart, hearth). PASS.
2. **Palette quarantine**: checked per-accent above (straw-material vs
   amber-light vs coin-metal vs forge-bronze). PASS.
3. **Population texture**: village = few, named, busy (headman register);
   NO crowds (that's Invrisil's message). Hollow = exactly one inhabitant.
   Noted for the wiring pass; extras density stays "none." PASS.
4. **Traversal signature**: Riverfarm's is the FIELD LINE — fences/crop
   rows channel walking along lanes (soft, not wall-gated); the hollow's
   is the single winding path. Distinct from doors/alleys/lifts. PASS.
5. **PC race reads**: village humans are Laken's folk — a Drake/Gnoll PC
   gets noticed-but-welcomed pool variance (content-time note). PASS
   (flagged to dialogue, not art).
6. **Music key**: not this lane's surface; queued in handoff (folk/reed
   suggestion). N/A here.
Also checked against wi-art-and-sprites: props-over-tiles respected
(crops/fences/buildings are all props; only floors are tiles); style
families unmixed per layer (PC16 + PIXELLAB at native 16px density in
the world layer — the proven goblin/bat precedent, and PixelLab gens
were prompted to the PC16 kernel; NINJA16/TS-CARTOON excluded from world
art); STR/DEX rule N/A (no UI text shipped).
