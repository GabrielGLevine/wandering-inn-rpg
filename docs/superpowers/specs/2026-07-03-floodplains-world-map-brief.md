# Consultant brief: Floodplains world map (+ the fixed-vs-world environment principle)

**Date:** 2026-07-03. **Requested by:** project lead (Fable), commissioned by the user.
**Your deliverable is DESIGN + DATA, not engine code.** Everything you produce must be
buildable by the existing renderer from JSON alone.

## 1. New standing design principle (user, 2026-07-03)

The game has TWO environment kinds:

- **Fixed environments** — interiors and combat arenas (the Wandering Inn common room,
  Adventurer's Guild, arena boards). The whole space fits the 320x180 viewport; the
  camera does not move. Grid <= 20x11 cells at CELL=16.
- **World environments** — outdoor traversal spaces (the Floodplains, Liscor's streets).
  LARGER than the viewport; the camera centers on the PC and clamps at map edges, so
  new terrain emerges as you walk. Grid > 20 wide and/or > 11 tall.

The engine already implements this split — `world.gd::_camera_axis` centers when
content <= view and clamp-follows when content > view, PER AXIS. The distinction is
purely a property of `grid.width/height` in map data. Your job is to exploit it.

## 2. The task: design the FLOODPLAINS map

Canon (source: wiki.wanderinginn.com mirror — Fandom 402s bots): Erin's inn stands on
a hill in the Floodplains OUTSIDE Liscor's walls — the inn does not sit in the city.
The Floodplains are open grassland valleys/hills that flood in the spring rains.

Design a world map (suggested 36x24 to 48x30 cells) where:
- The inn sits on its hill (the inn door transitions here; this map replaces the inn's
  current direct exit onto "street" — the street becomes Liscor-gate-adjacent and
  connects from this map's south/east edge).
- Liscor's walls/gate read in the distance at one edge (facade/wall dressing at the
  map margin — a "to Liscor" door entity at the road's end).
- Terrain tells the canon story: grass hills, wet lowland patches, a worn road from
  inn to gate, scatter density per the assembly guide (P3/P4: clustered, wobbled
  edges, nothing empty for >4 tiles).
- 2-3 encounter/POI anchor sites for future content (goblin trouble on the road, a
  fishing/flood pond, a rock outcrop) — mark cells, we wire content later.

## 3. Binding constraints

- **Read these repo docs first** (they are the design system): `docs/asset-catalog.md`
  (what art exists; PC16 family only for world art — NO Tiny Swords terrain),
  `docs/asset-index.md` (exact sheets/dims), `docs/scene-assembly-guide.md`
  (8 principles + L0-L4 ladder — your composition must be expressed in its terms).
- **Schema (all in `wandering_inn_game_v4/data/`):** a map entry =
  `{"biome": id, "grid": {"width","height"}, "blocked": [[x,y],...],
  "walls": {"segments": [{"from","to","cap","face","sheet","tile_px"}], band keys...},
  "floor_layers": [{"sheet","tile_px","variants"|[coords],"cells":"all"|{"rect"}|{"list"}}],
  "decor": [{"sprite": id, "cell": [x,y]}],
  "scatter": [{"pool":[ids],"density":0..1,"cluster":0..1,"seed":int}],
  "entities": [{"kind","id","cell","sprite","display_name",...}]}`.
  Biomes live in `biomes.json` (sheet/floor/blocked/skirt picks). Sprites in
  `sprites.json` (region crops + render_scale + anchor + optional shadow:true).
  walls-v2 segments BLOCK (sim merges their cells); decor/scatter are visual only.
- Atlas coordinates you propose are STARTING PICKS — the controller screenshot-verifies
  and iterates every pick (standing M4 rule). Flag any pick you're unsure of.
- Door entities: `{"kind":"door","to_map","to_cell"}`. Propose the full transition
  graph (inn <-> floodplains <-> street) but note: WE do the QA re-pathing.

## 4. Deliverable format (commit nothing — reply with a document)

1. Composition overview (one paragraph per zone, referencing guide principles).
2. The complete map JSON block (+ any new biomes.json / sprites.json entries needed).
3. Transition graph + suggested entity placements.
4. Uncertain picks flagged. 5. Optional: a second, smaller pass sketching how the
   current 10x6 "street" grows into a Liscor gate-district world map later.
