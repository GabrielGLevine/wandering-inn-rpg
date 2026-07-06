# Floodplains World Map — Design Document

**Consultant deliverable, 2026-07-03.** Per brief
`docs/superpowers/specs/2026-07-03-floodplains-world-map-brief.md`. Design + data
only; nothing committed to game data by the consultant. All atlas coordinates are
starting picks pending controller screenshot verification (flags in §4).

**Grid: 40×26 at CELL=16** (640×416 px vs the 320×180 view → the camera
clamp-follows on both axes; this is a *world environment* per the new
fixed-vs-world principle). Coordinate frame: x 0–39 west→east, y 0–25
north→south.

---

## 1. Composition overview

**Zone A — Inn Hill (NW, roughly x2–13, y1–9).** The map's P2 XL anchor: the
Wandering Inn seen from outside, canon-correct on its hill outside Liscor's
walls. The hill reads as a lighter grass plateau (`grass_02` patch) rather than
literal elevation tiles — PC16 has no cliff/elevation kit, so tone shift + a
boulder at the plateau lip + the building's mass do the work. The building is a
composite: roof slab decor (y2–4), plaster facade strip (y5), door entity at
(7,5), blocked footprint underneath so the sim matches the visual. A campfire
(the existing animated `sconce` bonfire loop, re-registered as `campfire`)
burns beside the door — P8's "one animated flame reads alive" for a daylight
exterior where P6 lights are skipped. A short dirt apron spills from the door
into the road (P4: materials meet with a transition, not a butt joint).

**Zone B — The road (spine, inn → gate).** A 2-wide `dirt_01` road descending
from the hill, running east across the midline, then bending south-east to the
gate. Built from seven staggered rects, each offset 1 cell from the last — the
stagger IS the P4 wobble; no straight run longer than ~8 tiles. It's the same
dirt the street map's whole floor uses, so walking through the gate into the
street reads as continuous material (P1 across maps). Mid-road at
(21,12)–(22,13) is POI-A, "trouble on the road" — a widened shoulder with a
lone boulder and crate for future goblin-ambush staging.

**Zone C — Wet lowland + flood pond (SW, x5–15, y15–23).** The canon
spring-flood story told in ground materials (P1): a `transition_01` mud sheet
spreads across the lowland, wobble-edged with list-mode cells, and a water pond
sits in its middle as a blocked blob (5 wobbled rows — P4's "banks wobble 1–2
tiles"). The pond is the map's P7 blue accent (~4% of frame). Bushes and
reed-height grass tufts cluster at the waterline (P3: scatter clusters, not
noise). Pond-edge cell (12,18) is POI-B, the future fishing/flood-pond
interaction anchor. Two smaller mud smears south-west continue the "this valley
floods" motif so the pond doesn't read as a lone decal.

**Zone D — Ruin stones outcrop (NE, x28–35, y3–7).** POI-C: a blocked rock
blob rendered with the biome blocked tile, dressed with `boulder` sprites on
top and pebble-heavy scatter around it. Canon hook: the Ruins of Liscor stand
in the Floodplains — this outcrop is the surface tease for that future content.
It also gives the empty NE quadrant its P2 medium anchor.

**Zone E — Liscor wall + gate (S edge, x20–39, y25).** Castle-sheet wall
segments (walls-v2, blocking) run the south-east margin of the bottom row with
a single-cell gap at x=31 holding the "To Liscor" door. Wall dressing at the
map margin, exactly as the brief specifies — the city is a facade, not a place,
yet. Crates and a barrel cluster at the gate approach (P8: traffic implies
people). The wall deliberately does NOT span the whole south edge: west of x20
the grassland runs open to the map bound, preserving the "open valley" reading.

**Fill — meadow.** Everything between zones gets grass-variant patches
(`grass_02`/`grass_03` rects breaking the base `grass_01` monotony — P1's
"floor alone has 3–4 materials"), tree clusters (two PC16 tree models, some
placed in the out-of-grid skirt margin like the street map already does), and
two seeded scatter passes (base tufts/pebbles/tiny-flowers at 0.06 +
purple-flower accent at 0.015, cluster 0.7–0.9) so no walkable region is empty
>4 tiles (P3). Palette lands on P7: ~60% green grass, ~30% dirt/mud/foliage,
~10% accents (pond blue, purple flowers, red roof).

**Ladder position:** this JSON specifies L0–L3 in one authored pass (blockout +
ground story + anchors + scatter/life). L4 (CanvasModulate day tone)
intentionally omitted — day exterior per P6 wants near-white ambient, which is
the default.

---

## 2. Data

### 2.1 `biomes.json` — new entry

```json
"floodplains": {
 "sheet": "res://assets/tiles/floor_tiles_12/grass_01.png",
 "tile_px": 540,
 "floor": [0, 0],
 "blocked_sheet": "res://assets/tiles/free_pack/Wall_Tiles.png",
 "blocked": [14, 4],
 "blocked_tile_px": 16,
 "_comment_skirt": "Open grassland runs past every edge -- skirt is the same whole-image grass so the world visually continues beyond the camera clamp.",
 "skirt_sheet": "res://assets/tiles/floor_tiles_12/grass_01.png",
 "skirt_tile_px": 540,
 "skirt": [0, 0]
}
```

Rationale: whole-image single-tile picks from `topdown_floor_tiles_12` are the
zero-coordinate-risk path (street precedent), and grass/dirt/transition from
the *same pack* are designed to sit together — this sidesteps the catalog's
warning about mixing two grass styles, because PC16 grass is never used as
ground here (PC16 supplies props only). Blocked tile `[14,4]` reuses the street
biome's pick for consistency (used only under the Zone-D outcrop, always with
boulder sprites on top).

### 2.2 `sprites.json` — new entries

```json
"inn_roof": {
 "render_scale": 0.5,
 "animations": {
  "idle": {
   "sheet": "res://assets/props/free_pack/Building_Roofs.png",
   "region": [0, 0, 96, 64],
   "frame_size": [96, 64],
   "fps": 1
  }
 },
 "shadow": true
},
"tree_round": {
 "render_scale": 0.2,
 "animations": {
  "idle": {
   "sheet": "res://assets/props/free_pack/Tree_M1_S4.png",
   "region": [0, 0, 368, 256],
   "frame_size": [368, 256],
   "fps": 1
  }
 },
 "shadow": true
},
"campfire": {
 "render_scale": 0.75,
 "animations": {
  "idle": {
   "sheet": "res://assets/props/free_pack/Bonfire_01-Sheet.png",
   "region": [0, 0, 128, 32],
   "frame_size": [32, 32],
   "fps": 6
  }
 }
}
```

Notes: `tree_round` is a whole-image crop of the already-synced
`Tree_M1_S4.png` (index says Model_01/Size_04 is 368×256 — if the synced file
differs, use its actual dimensions; whole-image either way). `campfire`
duplicates the proven `sconce` recipe at outdoor scale. `inn_roof` region is a
guess — see §4.

### 2.3 Asset sync additions (`tools/sync_assets.py` manifest)

| dest | source |
|---|---|
| `assets/tiles/free_pack/Water_tiles.png` | `Pixel Crawler - Free Pack 2.1/.../Environment/Tilesets/Water_tiles.png` (400×400) |
| `assets/tiles/floor_tiles_12/grass_02.png` | `topdown_floor_tiles_12/grass/grass_02.png` (540×540) |
| `assets/tiles/floor_tiles_12/grass_03.png` | `topdown_floor_tiles_12/grass/grass_03.png` (540×540) |

Everything else the map uses is already synced (`grass_01`, `dirt_01`,
`transition_01`, `Building_Roofs`, `Building_Walls`, `Tree_M1_S4`, `Tree_M2_S4`,
`Vegetation`, `Rocks`, `Bonfire_01-Sheet`, castle `Tiles.png`, `Wall_Tiles`).

### 2.4 `skeleton_scene.json` → `maps.floodplains` — the complete map block

```json
"floodplains": {
 "biome": "floodplains",
 "grid": { "width": 40, "height": 26 },
 "_comment": "World environment (consultant design 2026-07-03): 40x26 > 20x11 view, camera clamp-follows per axis. Zones: inn hill NW, road spine, flood pond SW, ruin-stones outcrop NE, Liscor wall+gate S edge. POI anchor cells (content wired later): road-trouble (21,12)-(22,13), fishing-pond (12,18), ruin-stones (31,5).",
 "blocked": [
  [5, 4], [6, 4], [7, 4], [8, 4], [9, 4],
  [5, 5], [6, 5], [8, 5], [9, 5],
  [30, 4], [31, 4], [32, 4],
  [30, 5], [31, 5], [32, 5],
  [31, 6],
  [17, 7],
  [24, 19]
 ],
 "floor_layers": [
  {
   "_pick": "Hill plateau: lighter grass variant, whole-image tile (zero coord risk, look unverified)",
   "sheet": "res://assets/tiles/floor_tiles_12/grass_02.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [3, 2, 9, 7] }
  },
  {
   "_pick": "NE meadow tone patch",
   "sheet": "res://assets/tiles/floor_tiles_12/grass_02.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [17, 2, 9, 6] }
  },
  {
   "_pick": "SE meadow tone patch",
   "sheet": "res://assets/tiles/floor_tiles_12/grass_02.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [21, 17, 7, 5] }
  },
  {
   "_pick": "West meadow tone patch, third grass variant",
   "sheet": "res://assets/tiles/floor_tiles_12/grass_03.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [2, 11, 5, 4] }
  },
  {
   "_pick": "East meadow tone patch",
   "sheet": "res://assets/tiles/floor_tiles_12/grass_03.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [33, 9, 6, 6] }
  },
  {
   "_pick": "Wet lowland mud sheet around the flood pond (P1 flood story)",
   "sheet": "res://assets/tiles/floor_tiles_12/transition_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [5, 15, 11, 9] }
  },
  {
   "_pick": "Mud sheet wobble edge, NE shoulder (P4: no straight seams)",
   "sheet": "res://assets/tiles/floor_tiles_12/transition_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "list": [[16, 16], [16, 17], [17, 17], [15, 14], [14, 14], [6, 14], [7, 14], [4, 17], [4, 18], [3, 19]] }
  },
  {
   "_pick": "Secondary mud smear east of pond",
   "sheet": "res://assets/tiles/floor_tiles_12/transition_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [16, 19, 4, 3] }
  },
  {
   "_pick": "Secondary mud smear SW corner",
   "sheet": "res://assets/tiles/floor_tiles_12/transition_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [2, 21, 3, 3] }
  },
  {
   "_pick": "Road seg 1: down the hill from the inn door apron",
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [6, 6, 3, 2] }
  },
  {
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [6, 7, 2, 6] }
  },
  {
   "_pick": "Road seg 2: east across the midline (staggered rects = wobble)",
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [7, 13, 10, 2] }
  },
  {
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [16, 14, 8, 2] }
  },
  {
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [23, 15, 6, 2] }
  },
  {
   "_pick": "Road seg 3: bend south-east to the gate",
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [28, 16, 2, 5] }
  },
  {
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [29, 20, 2, 3] }
  },
  {
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "rect": [30, 22, 2, 4] }
  },
  {
   "_pick": "Road-trouble POI shoulder widening at (21,12)-(22,13)",
   "sheet": "res://assets/tiles/floor_tiles_12/dirt_01.png",
   "tile_px": 540,
   "coords": [0, 0],
   "cells": { "list": [[21, 12], [22, 12], [20, 12], [22, 13]] }
  }
 ],
 "_comment_walls": "Two systems here. (1) Liscor wall: castle-sheet blocking segments along the SE bottom row, single-cell gate gap at x=31. Cap/face reuse the street band's unverified castle picks. (2) Flood pond: water rows as blocking segments with a PER-SEGMENT sheet override (brief schema lists sheet/tile_px per segment) -- cap tile IS the water fill, no face. Both block via the walls-v2 sim merge, which is what makes the pond impassable without painting the biome's rock blocked-tile over it.",
 "walls": {
  "sheet": "res://assets/tiles/castle/Tiles.png",
  "tile_px": 16,
  "segments": [
   { "from": [20, 25], "to": [30, 25], "cap": [2, 11], "face": [2, 13] },
   { "from": [32, 25], "to": [39, 25], "cap": [2, 11], "face": [2, 13] },
   { "from": [9, 17], "to": [11, 17], "cap": [3, 3], "sheet": "res://assets/tiles/free_pack/Water_tiles.png", "tile_px": 16 },
   { "from": [8, 18], "to": [12, 18], "cap": [3, 3], "sheet": "res://assets/tiles/free_pack/Water_tiles.png", "tile_px": 16 },
   { "from": [7, 19], "to": [13, 19], "cap": [3, 3], "sheet": "res://assets/tiles/free_pack/Water_tiles.png", "tile_px": 16 },
   { "from": [8, 20], "to": [12, 20], "cap": [3, 3], "sheet": "res://assets/tiles/free_pack/Water_tiles.png", "tile_px": 16 },
   { "from": [9, 21], "to": [11, 21], "cap": [3, 3], "sheet": "res://assets/tiles/free_pack/Water_tiles.png", "tile_px": 16 }
  ]
 },
 "decor": [
  { "sprite": "inn_roof", "cell": [7, 3] },
  { "sprite": "facade_plaster", "cell": [7, 5] },
  { "sprite": "campfire", "cell": [10, 7] },
  { "sprite": "boulder", "cell": [3, 8] },
  { "sprite": "tree_big", "cell": [1, 10] },
  { "sprite": "tree_big", "cell": [16, 4] },
  { "sprite": "tree_big", "cell": [25, 3] },
  { "sprite": "tree_big", "cell": [36, 10] },
  { "sprite": "tree_big", "cell": [3, 15] },
  { "sprite": "tree_round", "cell": [12, 10] },
  { "sprite": "tree_round", "cell": [22, 18] },
  { "sprite": "tree_round", "cell": [35, 15] },
  { "sprite": "tree_big", "cell": [-2, 5] },
  { "sprite": "tree_big", "cell": [18, -2] },
  { "sprite": "tree_round", "cell": [41, 7] },
  { "sprite": "boulder", "cell": [30, 4] },
  { "sprite": "boulder", "cell": [32, 5] },
  { "sprite": "boulder", "cell": [31, 5] },
  { "sprite": "boulder", "cell": [17, 7] },
  { "sprite": "boulder", "cell": [24, 19] },
  { "sprite": "crate", "cell": [21, 12] },
  { "sprite": "bush_green", "cell": [8, 15] },
  { "sprite": "bush_green", "cell": [9, 16] },
  { "sprite": "bush_green", "cell": [6, 18] },
  { "sprite": "bush_green", "cell": [13, 17] },
  { "sprite": "bush_green", "cell": [14, 20] },
  { "sprite": "bush_green", "cell": [27, 8] },
  { "sprite": "bush_green", "cell": [28, 7] },
  { "sprite": "bush_green", "cell": [34, 21] },
  { "sprite": "crate", "cell": [29, 24] },
  { "sprite": "barrel", "cell": [33, 24] },
  { "sprite": "crate", "cell": [34, 23] }
 ],
 "scatter": [
  {
   "pool": ["grass_tuft", "pebble", "flower_tiny"],
   "density": 0.06,
   "cluster": 0.7,
   "seed": 21
  },
  {
   "pool": ["flower_purple"],
   "density": 0.015,
   "cluster": 0.9,
   "seed": 22
  }
 ],
 "entities": [
  {
   "id": "floodplains_inn_door",
   "kind": "door",
   "cell": [7, 5],
   "display_name": "The Wandering Inn",
   "sprite": "door",
   "to_map": "inn",
   "to_cell": [14, 3]
  },
  {
   "id": "liscor_gate",
   "kind": "door",
   "cell": [31, 25],
   "display_name": "To Liscor",
   "sprite": "door",
   "to_map": "street",
   "to_cell": [1, 3]
  }
 ]
}
```

Consistency check against the sim: blocked list + wall-segment cells never
coincide with a door, POI, or decor-walkway cell; scatter auto-skips
blocked/entity/player cells per `world.gd`; the road is continuously walkable
inn-door → gate (verified cell-by-cell against the rects:
(7,6)→(6..7,7–12)→(7..16,13)→(16..23,14)→(23..28,15–16)→(28..29,16–20)→
(29..30,20–22)→(30..31,22–25)→gate (31,25)).

### 2.5 Edits to existing maps (same file)

```jsonc
// maps.inn.entities -> inn_door: retarget from street to floodplains
{
 "id": "inn_door", "kind": "door", "cell": [15, 3],
 "display_name": "To the Floodplains", "sprite": "door",
 "to_map": "floodplains", "to_cell": [7, 6]
}

// maps.street.entities -> street_door: the street is now Liscor-gate-adjacent
{
 "id": "street_door", "kind": "door", "cell": [0, 3],
 "display_name": "To the Floodplains", "sprite": "door",
 "to_map": "floodplains", "to_cell": [31, 24]
}
```

---

## 3. Transition graph + placements

```
inn (15,3) ──> floodplains (7,6)     [arrive just below the inn's front door]
floodplains (7,5) ──> inn (14,3)     [existing inn arrival cell, unchanged]
floodplains (31,25) ──> street (1,3) [existing street arrival cell, unchanged]
street (0,3) ──> floodplains (31,24) [arrive just north of the gate]
```

Every arrival cell is adjacent to (never on) the return door, matching the
existing anti-retrigger convention. `start_map` and the player block are
untouched.

**POI anchors (cells reserved, content wired by the project later):**

- **POI-A road trouble** — (21,12)–(22,13): widened dirt shoulder + crate +
  boulder at (17,7) as approach cover. Future goblin encounter entity goes at
  (21,12); `goblin_ambush` arena biome (`street`, dirt) is already tonally
  right.
- **POI-B fishing/flood pond** — (12,18): walkable mud cell on the pond's east
  bank. Future `prop` entity (fishing interaction / flood-lore toast).
- **POI-C ruin stones** — (31,5) is blocked; the interaction cell is (31,7)
  south of the blob. Future Ruins-of-Liscor tease (canon: the Ruins stand in
  the Floodplains).

**QA re-pathing heads-up (project-side per the brief):** every script that
walks inn→street (`dialogue_walkthrough`, `quest_errand_*`,
`save_load_roundtrip`, `defeat_reload`, `inn_walkthrough`, and any
combat-adjacent path that transits the street) now crosses the floodplains;
`map_changed` autosave beats double up (inn→floodplains→street). Also
`test_content.gd`-style content checks may need the new map id registered.
Combat data untouched — canonical seeds should hold, but the seed table's own
rule says re-verify after any map graph change.

---

## 4. Uncertain picks — flag table

| # | Pick | Risk | Notes / fallback |
|---|---|---|---|
| 1 | `Water_tiles.png` cap `[3,3]` (pond fill) | **HIGH — pure guess.** Sheet never opened; 400×400@16 = 25×25 tiles; `[3,3]` assumes a still-water blob interior near top-left. | Screenshot the sheet grid first. Fallback if no clean fill tile: drop the water segments, keep the pond as mud (`transition_01`) with a plain `blocked` ring rendered under boulder decor. |
| 2 | Per-segment `sheet`/`tile_px` override on walls-v2 segments | **MEDIUM — schema-asserted, engine-unverified by consultant.** Brief's schema lists `sheet` per segment; confirm `world.gd::_build_walls` actually reads it per-segment, not only top-level. | If top-level only: split `walls` won't work — render pond via a dedicated blocked-cell approach instead (add pond cells to `blocked`, accept rock tile, cover with mud layer + heavy bush/boulder dressing), or extend the renderer. |
| 3 | `inn_roof` region `[0,0,96,64]` on `Building_Roofs.png` | **HIGH — guess.** 400×400 sheet, never inspected; assuming a roof slab at origin. | Iterate region + `render_scale` on screenshot; the whole building composite (roof at (7,3) + facade at (7,5) + door overlay) is expected to take 2–3 windowed iterations. |
| 4 | `facade_plaster` region `[288,192,96,48]` | **MEDIUM.** Existing sprite, but its street usage was itself flagged unverified in M5 R4 comments. | Same iteration pass as #3. |
| 5 | Castle `Tiles.png` cap `[2,11]` / face `[2,13]` | **MEDIUM.** Street band's picks, marked unverified there. Also: face orientation on a *south-edge* wall (face may paint into the y=26 skirt margin) needs a look. | If face renders wrong, drop `face` and run cap-only like the inn's side walls. |
| 6 | `Wall_Tiles.png` blocked `[14,4]` on grass | **LOW-MED.** Street's blocked pick; never seen against a grass base. Only visible at the Zone-D outcrop under boulder sprites. | Any rocky tile works; iterate. |
| 7 | `grass_01/02/03`, `dirt_01`, `transition_01` whole-image | **LOW.** Zero coordinate risk (whole-image, street-proven pattern), but `grass_01`'s actual look and the grass_02/03-on-grass_01 patch seams have never been screenshotted; `transition_01`'s grass↔dirt orientation is unknown (it may read directional). | Expect one L1 screenshot pass on seams; patches are same-pack so worst case is swapping which variant is base. |
| 8 | `Tree_M1_S4.png` whole-image + `render_scale` 0.2 | **LOW.** Zero coord risk; only scale/anchor needs eyeballing against `tree_big`'s proven 0.3. | Adjust scale on screenshot. |

Recommended verification order: #1/#2 first — they gate the pond design.

---

## 5. Optional: how the 10×6 street grows into a Liscor gate district

Later pass, sketch only. Keep the current street JSON as the seed and grow it
to ~32×20 (world environment): the existing 10×6 becomes the *gate plaza* at
the map's west end — the current `street_door` position stays the gate back
into the Floodplains, preserving the transition graph. Extend east with: a
market row (Library-pack desks/shelving as stalls per the catalog's
Selys-counter note, `Shop` track from xDeviruchi), a Watch post (Castle pack
facade + Royal Crew stand-ins, flagged non-canon race), and an Adventurer's
Guild doorway as the next interior `door` target. The castle wall band flips
role: instead of dressing the margin, wall segments frame the north edge
interior-side, since the player is now *inside* Liscor. Existing street
encounters (`goblin_encounter_*`, `chieftains_raid`) should migrate OUT to the
Floodplains POI anchors at that point — goblins inside the walls never made
canon sense; the street rework is the natural moment to fix it.

---

*End of deliverable. All edits above are proposals for the controller session
to apply, screenshot-verify (§4 order: #1/#2 first — they gate the pond
design), and QA re-path.*

---

## 6. Project addendum (2026-07-03, user direction): Relc introduction

Relc must be MET before he fights beside you. Placement: the Floodplains road,
shortly after first leaving the inn — a Watch guardsman intercepting a stranger
walking toward his city is canon-natural (Relc: Drake, Senior Guardsman,
[Spearmaster] per the taxonomy doc).

- **Entity:** `relc` npc on/near the road east of the inn hill (suggest ~(12,13),
  first road stretch — before POI-A so the meeting precedes any road trouble).
  Conversation: short intro graph (who are you / heading to Liscor / watch
  yourself out here), records accomplishment `met_relc`.
- **Gating:** combat encounters field Relc as ally ONLY once `met_relc` >= 1.
  Today `combatants.json`/encounter rosters add him unconditionally — the
  integration wires the roster through the accomplishment (data + small sim
  check; same pattern as class gains' `gained_by`).
- **Tutorial hook (future):** this interaction is the designated entry point for
  the combat tutorial when tutorial-building lands (Relc walks you through a
  practice bout — his [Spearmaster] teaching posture is canon-friendly). Design
  the conversation graph with a dangling `tutorial` option stub (hidden until
  the tutorial milestone) rather than retrofitting later.
- **Sprite reality:** Drakes are the tree's hardest gap (catalog §6). Stand-in:
  Cemetery `A_Hunter` (the only other fully-directional character; grim armed
  figure) tinted, display name carries him until Drake art exists — same
  flagged-placeholder convention as the Watch/Royal Crew note.
- **QA:** extend the floodplains walkthrough script to meet Relc, assert
  `met_relc` + the dialogue events; combat scripts assert Relc present ONLY
  after the meeting (and a negative: first-ever fight without meeting him, if
  any path still allows one, fields no Relc).
