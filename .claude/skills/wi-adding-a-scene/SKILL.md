---
name: wi-adding-a-scene
description: Use when adding a new map/room to data/skeleton_scene.json, adding doors/furniture/props to an existing map, or reviewing a map edit for blocking/reachability correctness.
---

# Adding a Scene (map)

Maps are data (`data/skeleton_scene.json`, keyed under `maps`); `world.gd`
renders them, `WIGame` (`src/core/wi_game.gd`) only reads `grid`, `blocked`,
`walls.segments`, and `entities` for sim purposes — `floor_layers`, `decor`,
and `scatter` are presentation-only passthrough the sim never touches.

## Map record anatomy
| Field | Shape | Meaning |
|---|---|---|
| `biome` | String | key into `data/biomes.json` (`inn`/`street`/`cave`/`floodplains`) — supplies default sheet/tile_px/floor/blocked/skirt tiles |
| `grid` | `{width, height}` | playable grid size |
| `blocked` | `[[x,y], ...]` | non-walkable cells, joined into `blocked_cells` at load |
| `walls` | `{sheet, tile_px, segments: [...]}` or `{top_coords, base_coords, band_rows}` | see Walls below |
| `floor_layers` | `[{sheet, tile_px, variants\|coords, cells}]` | `cells` is `"all"`, `{"rect": [x,y,w,h]}`, or `{"list": [[x,y], ...]}` |
| `decor` | `[{sprite, cell}]` | **non-blocking** presentation sprites |
| `scatter` | `[{pool: [sprite,...], density, cluster, seed}]` | scattered decoration, seeded |
| `entities` | `[{...}]` | see Entity kinds below |

### Walls
`walls.segments`: `{from: [x,y], to: [x,y], cap: [atlas_x,atlas_y], face:
[atlas_x,atlas_y]}`. `WIGame.segment_cells` expands `from`/`to` into the
INCLUSIVE rect spanned (both axes) — the single source of truth shared by the
sim (joined into `blocked_cells`) and the renderer (paints wall art on
exactly those cells); never double-list a wall's cells in `blocked` too.
`cap`/`face` are ATLAS TILE COORDS, not gameplay cells: with `face` given, it
paints every covered cell and `cap` paints one cell above each (skipped where
already covered); with no `face`, `cap` alone paints every covered cell
(solid/vertical run). The alternate `{top_coords, base_coords, band_rows}`
form (`street`) paints a non-blocking decorative skirt above row 0 only.

## Entity kinds
Every entity has `id`, `kind`, `cell: [x,y]`, `display_name`, `sprite`, plus
optional `facing` (`up/down/left/right` — idle row / side flip) and `tint`
(`[r,g,b]`).

| kind | extra fields |
|---|---|
| `npc` | `conversation?` (starts dialogue via `start_dialogue`), `dialogue: [{speaker, text}]` (fallback line) |
| `prop` | `sleep?` (interact calls `Game.sim.sleep()`), `on_interact_accomplishment?` + `toast?` (fires directly on interact), `requires_skill?` + `on_skill_use: {accomplishment, toast}` (gated on knowing the skill) |
| `door` | `to_map` (must be a key under `maps`), `to_cell: [x,y]` (must be unblocked and unoccupied — `is_cell_blocked` checks both) |
| `encounter` | `arena` (key into `data/arenas.json`), `enemies`/`allies: [id,...]` (into `data/combatants.json`), `conversation?` (parley first), `on_victory?` (String\|Array, default `"won_combat"`), `respawns?` (true = dormant-until-sleep; default = removed permanently) |

Doors are interact-activated only. No runtime code validates `to_map`/
`to_cell` — a bad door silently crashes (bad map) or strands the player
inside furniture (blocked/occupied landing cell) until someone walks it, so
check both by hand or QA walkthrough whenever you add or move one.

## THE BLOCKING CONTRACT
`decor` is non-blocking presentation ONLY. Anything that visually reads solid
— a table, barricade, market stall, grill — must ALSO be in `blocked` or
placed as an `entity` (blocks its own cell). A decor-only "solid" object is a
real bug: the player walks through it. Don't double-list a wall segment's
cells in `blocked` too — `segment_cells` already joins them in.

## Props-over-tiles (2026-07-04 user directive)
Represent objects with real furniture/prop sprites (`data/sprites.json`/
`decor`/`entities`) — never by recoloring an environment/floor tile to stand
in for an object; a recolored tile reads as terrain variation, not a thing.

## Reachability and the inn lock
Every new map needs a door chain from the `inn` (`start_map`), or an explicit
unreachable-by-design note (see `floodplains`'s `_comment`: gated on a
door-retarget task, verified only via the `floodplains_peek` teleport
script). Inn grid is 16×10, Erin at `[7,2]` facing down, inn door `[15,3]`,
street door returns to `[14,3]` — keep stable or update every walkthrough +
the scene-assembly docs together.

## After any map edit
1. Re-run every path-walking QA script crossing the map (arrow sequences are
   absolute cell counts — a new blocked cell can strand a script mid-walk).
2. Update any `ui_map_rendered` `floor_cells`/`blocked_cells` count assertion,
   e.g. `inn_walkthrough.json`: `{"action": "assert_event_logged", "type":
   "ui_map_rendered", "payload_contains": {"map": "inn", "floor_cells": 160,
   "blocked_cells": 55}}` (paired with a `ui_entities_rendered` sprite-count
   check) — the standard render-confirmation idiom to reuse.
3. Verify any new/moved door's landing cell by hand.
4. Score the scene: `godot --headless --path wandering_inn_game --script
   res://tools/scene_dynamism.gd` (issue #73). New scenes target composite
   >=50; the component breakdown says WHAT to add — low c1 (internal variety)
   means pull decor from more than one asset-pack family, not more of the
   same; low c3 (composition) means an off-center focal light/prop + dress
   the border band; low c2 (distinctiveness) means the biome/sprite picks
   either read like a different region or share too little language with the
   region's siblings. <30 prints a loud advisory — near-certain brown box,
   fix before spending a windowed shot. The score is advisory, NOT a gate,
   and it is blind to palette clash inside a family (see the report's
   'What this metric cannot see') — the windowed read stays final authority.
5. Windowed screenshot, read by you — per `wi-verifying-changes`.

## Editor-driven design iteration
The godot-ai MCP is RETIRED (2026-07-06, see wi-running-the-machine).
Visual layout iteration = the dynamism tool for structure + windowed QA
screenshots read by the controller for taste. Maps are still DATA: the
deliverable is `skeleton_scene.json`, never a hand-edited `.tscn`.

## Save-compat forward hazard (M7 final-review lesson)
A NEW blocking entity (container, prop, NPC) placed on a cell that was
WALKABLE in any shipped save version can trap a prior-version save that
loads standing there. Every such placement needs either a guaranteed-open
neighbor (compute all four — the M7 chest/ruin cells passed this) or a
migration player_cell guard (the v3→v4 street precedent). A cul-de-sac
placement without a guard is the M-FP softlock class again.

## Common mistakes
- Solid-looking decor with no matching `blocked` cell/entity (walk-through-
  the-table bug).
- Recoloring a floor/wall tile as furniture instead of a prop sprite.
- A door targeting a blocked or occupied cell.
- Editing a map without re-running/updating the QA scripts that walk it.
- Skipping the reachability note on an intentionally unwired map.

New encounters placed on a map need combat data + a QA script per
`wi-adding-an-encounter`. Verify per `wi-verifying-changes`.
