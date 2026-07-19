# Scene Assembly Guide — benchmark-quality maps from potential_assets

**What this is:** instructions for an AI session building world/arena scenes
in `wandering_inn_game` to the quality bar of the Pixel Crawler showcase
mockups (the user-designated benchmarks). The benchmark images themselves
live in `potential_assets/_benchmarks/` (gitignored, local-only):
`benchmark-farmstead-river-dock`, `benchmark-tavern-interior-multiroom`,
`benchmark-forest-clearing-lightshafts`, `benchmark-formal-garden-fountain`,
`benchmark-sewer-canal`, `benchmark-forge-lava-interior`. Load one for a
side-by-side ONLY at ladder rung L4 (sec. 3) — everything else you need
from them is already encoded below. Written 2026-07-03. Companions: `docs/asset-catalog.md` (which pack/sheet to use —
**and sec. 3c/3d there for PixelLab-generated props that already exist or are
already wired; check it before generating a prop**), `docs/asset-index.md`
(exact paths/dimensions), `data/biomes.json` + `src/world/sprite_registry.gd`
(the existing pipeline you extend).

**Non-negotiable repo constraints this guide works inside:**
- Content is data + codegen. No hand-authored `.tscn`. Scenes are described
  in `data/*.json` and rendered by `world.gd`/`combat_screen.gd` through
  `WISpriteRegistry`. A map must be regenerable from its JSON.
- World `CELL := 16`; `biomes.json` slices PC16 sheets at 16px.
- Every tile/sprite region pick MUST be verified by a windowed QA screenshot
  read by the controller. Text-guessed atlas coords were wrong repeatedly in
  M4. Whole-image single-tile picks (like the street's `dirt_01`) are the
  zero-risk alternative when a sheet is one motif.
- Every player-visible change extends a QA script asserting the domain event
  AND the `ui_*_rendered` confirmation.

---

## 1. Why the benchmarks look good — eight principles

Decompiled from the five benchmark scenes. Each principle maps to a
concrete mechanism in section 2.

**P1 — Layered ground, never a flat fill.** Farmstead: grass base → dirt
path worn through it → river with organic banks → dock planks OVER water.
Tavern: stone kitchen floor vs wood hall floor vs plank bedroom floor, one
material per functional zone, rug accents on top. A scene reads rich when
the *floor alone* has 3-4 materials meeting at credible seams.

**P2 — One XL anchor per screen, then descending prop sizes.** Farmstead =
the cottage; forest = the giant vine-covered tree; garden = the fountain;
sewer = the green canal. The eye needs one big thing; everything else
supports it. Ratio in the benchmarks is roughly: 1 XL anchor, 2-4 medium
anchors (dock, crop plot, statue pond), 10-20 small props, then scatter.

**P3 — Scatter fills the silence, in clusters.** No walkable region in any
benchmark is empty for more than ~3-4 tiles without a micro-detail: grass
tufts, flowers, pebbles, twigs, mushrooms, cracks, blood/wine stains,
puddles. Crucially it *clusters* (5 flowers near the pond, mushroom rings
at tree bases, debris along walls) rather than uniform noise.

**P4 — Edges are never straight.** River banks wobble 1-2 tiles; the
forest clearing is an organic blob framed by canopy; even the tavern's
interior walls stagger to create room pockets. Where two materials meet
there is always a transition: autotile lip, skirt tile, or a scatter line
(reeds at the waterline, dirt spill at path edges).

**P5 — Everything standing casts a contact shadow.** Trees, fences,
furniture, characters, the dock's posts. PC16 packs ship `Shadows.png`
sheets for structures/props; where absent, a ~40%-alpha black ellipse under
the sprite base sells groundedness. Shadow presence is the single cheapest
"amateur vs pro" tell.

**P6 — Light is the mood layer.** Tavern: warm sconces/candles against a
dim interior, black void outside the walls. Forest: dark ambient + diagonal
light shafts + saturated glow accents (purple flowers, cyan sparks).
Castle/Hideout mockups: same recipe (orange fire glow vs cool dark).
Exterior daylight scenes (farmstead, garden) skip lights but keep a
muted global tone rather than full brightness.

**P7 — 60/30/10 palette discipline.** ~60% biome base (green grass / brown
wood / grey stone), ~30% secondary (dirt, foliage variation, furniture),
~10% saturated accents that carry the theme: teal roof + blue water
(farmstead), red tablecloths + food (tavern), purple/cyan glow (forest),
pink flowerbeds (garden), toxic green canal (sewer). Accents are what a
screenshot gets remembered by; budget them, don't splash them.

**P8 — Signs of life.** Animated fire/water/smoke loops; NPCs placed AT
work stations (cook by the stove, barmaid behind the bar) facing their
task; surfaces dressed (food on tables, bottles on shelves, tools on
benches). A static scene with one animated flame reads alive.

---

## 2. The Godot mechanism for each principle

Target node structure `world.gd` builds per map (all code-generated,
z-order bottom→top):

```
World (Node2D)
├── GroundBase      TileMapLayer   # P1: biome floor fill
├── GroundDetail    TileMapLayer   # P1/P3: paths, material patches, decals
├── WaterAnim       TileMapLayer   # P1: animated water cells (if any)
├── Shadows         Node2D         # P5: prop/structure shadow sprites
├── Walls           TileMapLayer   # blocked cells, wall variation tiles
├── YSorted         Node2D (y_sort_enabled)   # P2: props + entities mixed
│     ├── prop sprites (Sprite2D/AnimatedSprite2D, offset so base = sort line)
│     └── entity sprites (existing registry path)
├── Canopy/Overhang CanvasLayer or high-z TileMapLayer  # tree crowns, roof lips
├── LightShafts     Node2D         # P6: additive polygons (exterior forest only)
└── Lights          Node2D         # P6: PointLight2D at fire/sconce props
    + CanvasModulate on the map root  # P6: ambient tone per biome
```

- **P1 layers:** extend `biomes.json` per-biome with `detail` entries
  (tile picks for path/patch materials) and let map JSON paint them (2.1).
  The existing floor/blocked/skirt trio already proves the pattern.
- **P2/P8 props:** `skeleton_scene.json` `entities` already carries `prop`
  kind + `sprite` id → registry. Multi-cell anchors (huts, dock, bed rows)
  need a `footprint` (w×h cells) so blocked-cell data stays truthful.
- **P3 scatter:** do NOT hand-list 200 pebbles in JSON. Add a per-map
  `scatter` spec — `[{sprite_pool, density, cluster, seed}]` — and generate
  placements deterministically (`hash(map_id, cell)` or seeded RNG) at
  render time. Same JSON in = same scene out, QA-stable, zero authoring
  cost per pebble. Keep scatter off blocked/entity/path cells.
- **P4 edges:** cheapest first — the proven skirt approach (M5 R4) plus
  1-2-tile jitter on region boundaries in the generator; full 47-blob
  autotile wiring of `Floors_Tiles.png` is the high-effort upgrade, do it
  only when a seam is actually ugly in a screenshot.
- **P5 shadows:** registry gains `shadow` variants (from pack Shadows
  sheets) or a generated ellipse texture; emit under every prop whose
  sprite is taller than 1 cell.
- **P6 lights:** `CanvasModulate` color per biome tag (inn: warm dim
  `#b8a68f`-ish; cave/forest: cool dark; day exterior: near-white). One
  `PointLight2D` (warm orange, gentle energy flicker via Tween) per
  fire-family prop (sconce, bonfire, candle, forge). Light shafts:
  2-3 long semi-transparent white polygons rotated ~30°, additive blend —
  forest/cave only. All presentation-side; sim untouched.
- **P7 palette:** enforced by *pack choice*, not code — one biome kit per
  map (catalog sec. 2), accents from that pack's own accent items.
- **P8 anim:** registry already builds SpriteFrames; register the pack
  animated props (Bonfire `Fire_01/02` + `Smoke`, water tiles, Tiny Swords
  sheep if pastoral) and mark NPC field entities with a `facing` in map
  JSON so they look at their station.

### 2.1 Data schema sketch (extend, don't replace)

```jsonc
// skeleton_scene.json -> maps.<id>
{
  "biome": "inn",                    // existing
  "zones": [                          // NEW (P1/P3): rectangular material regions
    {"rect": [0,0,10,6], "floor": "kitchen_stone", "ambient": "warm_dim"}
  ],
  "paint": [                          // NEW (P1): explicit detail cells
    {"cells": [[4,5],[4,6]], "tile": "rug_red"}
  ],
  "scatter": [                        // NEW (P3)
    {"pool": ["grass_tuft","pebble","flower_white"], "density": 0.06,
     "cluster": 0.7, "seed": 3}
  ],
  "entities": [                       // existing; props gain footprint/facing
    {"kind":"prop","id":"long_table","sprite":"free_pack/table_banquet",
     "cell":[7,4],"footprint":[3,1]},
    {"kind":"npc","id":"erin","cell":[5,3],"facing":"up"}
  ]
}
```

Zone/paint/scatter names resolve through `biomes.json`/`sprites.json`
entries so atlas coordinates live in ONE place and every pick gets its
screenshot verification exactly once.

---

## 3. Assembly ladder — build in verified rungs

Never attempt a benchmark scene in one pass. Each rung ends with
`run_qa.sh <script> windowed` + controller reads the PNG. Stop at any rung
if it already reads well — later rungs are polish, not requirements.

- **L0 — Blockout.** Floor fill + walls + skirt + door/entity positions
  (this is roughly where the game is today). Verify: layout legible,
  nothing overlapping.
- **L1 — Ground story.** Zones/materials, paths, edge transitions, decals
  (stains, cracks). Verify: floor alone tells you what each area is for.
- **L2 — Anchors + props.** XL anchor, furniture clusters per zone,
  wall-mounted rhythm (sconce every 4-6 wall tiles, trophy/banner between),
  surface dressing. Verify: each zone passes "what happens here?" at a
  glance; no floating props (shadows on).
- **L3 — Scatter + life.** Seeded scatter clusters, animated fire/water,
  NPCs at stations with facing. Verify: no dead 4-tile-empty regions;
  something moves on screen.
- **L4 — Light + mood.** CanvasModulate, point lights, canopy/overhang,
  light shafts where fitting. Verify: screenshot reads as *the benchmark's
  cousin*; accents ≤ ~10% of frame.

QA note: rungs L0-L3 change `ui_map_rendered` payloads/screenshots only —
existing event assertions stay valid. L4's lights can subtly shift every
pixel; re-capture windowed baselines once, per the M-Art precedent.

---

## 4. Benchmark → kit mapping (what to reach for)

| Benchmark element | Source (see catalog for detail) |
|---|---|
| Inn floors/walls/rooms | Free Pack Floors/Wall_Tiles + Interior sheets (in use) |
| Inn furniture + food/clutter | Free Pack `Furniture.png` (~100 items) + Interior_Props + stations |
| Bar bottles/potion shelves | Free Pack Esoteric + Hideout potion racks |
| Wall trophies/weapons rhythm | Castle Assets (shields, banners) + weapons sheets as decor |
| River/pond + banks | Free Pack Water(_tiles); reeds/rocks from Fairy Forest/Cave props |
| Dock/planks over water | Free Pack building planks + Sewer plank-bridge pieces |
| Crop plot / farm corner | Free Pack farm props (verify via asset-index); fence from Garden tiles |
| Forest clearing frame | Fairy Forest trees (7 color variants) + canopy overhang + glow flora |
| Glow accents (forest/cave) | Fairy Forest rune stones/flowers, Cave purple mushrooms |
| Formal garden | Garden pack (near-literal Garden of Sanctuary) |
| Sewer canal scene | Sewer pack tiles/props (canon Liscor sewers) |
| Goblin camp dressing | goblin-huts + watchtower (CUSTOM-HD, render_scale + footprints) |
| Ambient fire/smoke anim | Free Pack Bonfire `Fire_01/02`, `Smoke` |
| Dust/splash accents | Tiny Swords Particle FX (style-agnostic, scale down) |
| Interior mood light | CanvasModulate + PointLight2D recipe (sec. 2 P6) |

Composition reference: the pack mockups themselves are in-tree floor plans —
trace their room proportions and prop placement logic (not their pixels)
when laying out the inn or any biome scene. Paths: catalog sec. 2 → exact
files in `docs/asset-index.md`.

---

## 5. Pitfalls (all previously hit or scan-confirmed)

- Atlas coords from memory/arithmetic — always screenshot-verify a pick
  once before using it widely (M4 lesson, repeated).
- Style-family mixing on the same layer: no Tiny Swords units/terrain
  beside PC16 world art; CUSTOM-HD (goblins/huts) only via render_scale
  and only as already proven in-game.
- Free Pack ≠ Free Pack 2.1 paths — they're identical content; sync from
  `2.1` like the manifest already does.
- PC16 enemy sprites are single-facing (mirror-only) — position conveys
  facing on the grid; don't promise 4-dir walk for them.
- Cave sheet is 16px-grid; some prop sheets are irregular — `region` crops
  in `sprites.json` handle non-grid sheets, `tile_set_for(sheet, tile_px)`
  only fits true grids.
- Scatter must respect `blocked` and entity cells, and must be seeded —
  unseeded randomness breaks QA screenshot comparability between runs.
- `CanvasLayer` has no `modulate` (repo gotcha) — put `CanvasModulate` as
  a child node of the world, tint child Controls for UI fades.
- Keep sim purity: everything in this guide is presentation. If a change
  needs the sim to know about it (new blocked cells from a footprint), it
  goes in the JSON data the sim already reads, never a scene-side hack.
