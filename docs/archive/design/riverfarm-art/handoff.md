# Riverfarm — wiring handoff (post-Door integration task)

What the future 8b wiring task needs from this art lane. Nothing here is
wired: skeleton_scene.json / biomes.json / sprites.json / moods.json were
NOT touched (charter). Mockups (taste surface) + raw art:
`potential_assets/pixellab_2026-07-07_riverfarm/`.

## Staged biome fragments (DRAFT — not a data file)

```json
{
  "riverfarm_village": {
    "sheet": "res://assets/tiles/floor_tiles_12/grass_01.png",
    "tile_px": 540,
    "floor": [0, 0],
    "blocked_sheet": "res://assets/tiles/free_pack/Wall_Tiles.png",
    "blocked": [14, 4],
    "blocked_tile_px": 16,
    "skirt_sheet": "res://assets/tiles/floor_tiles_12/grass_01.png",
    "skirt_tile_px": 540,
    "skirt": [0, 0],
    "_comment": "floodplains family on purpose (open countryside continuity); the village identity comes from PROPS (thatch structures, wheat-field wang tiles, crop rows, river band), not a new floor. Wheat field + loam plots + river need either a floor_layers mechanism or decor-tile placement -- see open questions."
  },
  "witch_hollow": {
    "sheet": "res://assets/tiles/fairy_forest/Tiles.png",
    "tile_px": 16,
    "floor": [2, 2],
    "blocked_sheet": "res://assets/props/fairy_forest/Tree.png",
    "blocked": null,
    "_comment": "floor = flat underwood green [2,2] rgb(12,82,44); enclosure should be TREE PROPS on blocked cells (Tree.png y457 deep-shade row, scale ~0.35-0.4), not a wall tile -- a forest pocket, not a room. Path tile [9,2]; pond = 5x5 composite px[112,192,80,80]."
  }
}
```

Mood-card drafts (values in `direction.md`, "Mood-card DRAFT" section):
`riverfarm_village` (warm day / deep-blue night) + `witch_hollow`
(never-white day, dusk home key, vignette 0.50).

## Sprite-entry notes (PixelLab keepers, all native 16px density)

All are single-frame props → `sprites.json` static entries,
`render_scale: 1.0`, default anchor `[0.5,1.0]` EXCEPT where noted;
every one still needs the windowed adjacency screenshot (anchor rule).

| id suggestion | file | cells (WxH world) | notes |
|---|---|---|---|
| `cottage_thatch_a` | prop_cottage_thatch_a.png | 4x4 (block ~4x2 at base) | shadow: true |
| `cottage_thatch_b` | prop_cottage_thatch_b.png | 4x4 | shadow: true |
| `longhouse` | prop_longhouse_thatch.png | 7x4 (block ~7x2) | shadow: true; door centered — align a door entity to it |
| `windmill` | prop_windmill.png | 4x6 (block ~3x2 at base) | shadow: true; sails overhang — anchor.y from base masonry, NOT frame bottom (alpha-scan feet plane) |
| `village_well` | prop_village_well.png | 2x2.5 | interactable — marker per "interactables must read" rule |
| `haystack` | prop_haystack.png | 2x2 | scatter |
| `scarecrow` | prop_scarecrow.png | 2x3 | scatter/decor |
| `earthwork_rampart` | prop_earthwork_rampart.png | 7x2 | north-edge dressing row, blocked cells |
| `fence_ew` | prop_fence_v.png | 2x3 (visual), blocks 1 row | tile in runs |
| `fence_ns` | prop_fence_ns.png | 2x4 | verify ladder-read at windowed check |
| `dock_pier` | prop_dock_pier2.png | 2x4 | feet ON bank row, extends over water |
| `rowboat` | prop_rowboat.png | 2x3 | water decor |
| `witch_cottage` | prop_witch_cottage.png | 5x5 (block ~5x3) | shadow: true; pair with ONE warm PointLight2D (phase-gated, unlit_lantern precedent) |
| `wheat_field` (tiles) | tileset_wheat_over_loam.png | 16px wang sheet | corner bits SE=1/SW=2/NE=4/NW=8; tile 0 = loam plot base, tile 15 = wheat fill |

Licensed picks (crops, trees, water, Fairy Forest, wolves): region tables
in `picks.md`; manifest entries listed in `direction.md` — **manifest +
ignore-block regen + bundle release come FIRST** (wi-shipping) before any
extraction.

## Open questions for the wiring pass

1. **Field-as-floor vs field-as-decor**: the wang wheat field wants
   biome-level tile placement (like cave floor), but current biomes are
   single-floor + blocked. Options: (a) extend biomes.json with a
   decor-tile layer, (b) place field cells as flat "prop" quads (the
   mockup composer proves the look either way). Same mechanism serves the
   river band. This is the one real schema question this region raises.
2. **River edge animation**: Water_tiles rows 0-4 hold 4 animation frames
   (6-col stride) of the bank block — is an animated-tile seam worth it
   in v1, or ship the static bank row?
3. **Blight visual_states** (spec §3: "the map itself is the reward
   readout"): recommend authoring the village mood/props in the LIFTED
   state (this lane's art) and adding a `blighted` visual_state at
   content time: grey-tinted crop rows (tint [0.7,0.65,0.6]), dimmed
   windows, vignette +0.1 — cheap, reversible, no extra art.
4. **Night-gated wolf encounter** (spec §5): Admurin Canine frame math
   unverified (192x64 Run sheets — 6@32x64 or 3@64x64?); needs a
   sheet-scan + windowed pass when the combatant is added. ADMURIN
   style family: keep wolves in their own encounter.
5. **Witch's two-phase idle** (elderly-by-day/young-by-dusk): art NOT
   generated (profile-gated, see pixellab-batch.md queue). visual_states
   swap is the cheap mechanism per spec.

## Canon flags

- **Laken out of v1 scope** (spec §1): earthworks are north-edge DRESSING
  only; no [Emperor] content, no throne, no Laken sprite. Flagged.
- **Witch name**: content-time wiki check against Vol-6 Riverfarm witches
  (Eloise/Hedag/Mavika/Agratha registers exist in canon — the spec's
  barter-speak + "Tea first" line is CLOSE to Eloise's tea-witch register;
  either borrow-with-verify or invent + canon-register per spec §2).
  Belavierr explicitly out (spec non-goal). All witch-arc material is
  Vol 6 = inside the Book-17 bar (spoiler-cutoff.md §3).
- **Headman**: canon Riverfarm has Mister Prost ([Steward]) — content
  lane should wiki-verify before naming; the art register (harried
  working man, no livery) holds either way.
- Wiki page used: wiki.wanderinginn.com/Riverfarm (village size, river,
  clay deposits, witch arrival — cited in direction.md). Building
  materials are design inference, not canon-sourced (page silent).

## Taste-queue for the user (via controller)

- 4x mockups: village day / village dusk / hollow dusk (paths in
  direction.md). The claim to judge: **"golden handmade village on a
  river + one warm light in a dark green wood."**
- Thatch-vs-shingle: we committed to thatch (PixelLab) over the in-hand
  Free Pack red/green shingle roofs — flag per the fidelity directive
  (this is an upgrade, not a downgrade, but it's a LOOK decision).
