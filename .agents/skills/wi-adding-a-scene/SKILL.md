---
name: wi-adding-a-scene
description: Add or edit a map, room, door, wall, furniture, prop, or reachability route.
---

# Add a scene

Maps are JSON at `data/maps/<region>/<map>.json`, composed by
`WISceneCatalog`; `data/scene_root.json` owns start-map/player data. Put a new
map in its narrative region. Different region directories may be separate
lanes; edits in one region or shared catalogs serialize.

Keep sim and presentation meanings distinct. The sim reads grid, blocked cells,
wall segments, and entities. Floors, decor, and scatter render only. Anything
drawn as solid must also block through an entity, wall, or blocked cell; every
blocked cell should have a visible reason. Do not double-list cells already
blocked by wall segments. Furniture and obstacles use real prop art rather than
recolored floor tiles.

Doors need a valid destination map and a landing cell that is in bounds,
walkable, and unoccupied. Prove reachability from the start map unless the map
is deliberately inaccessible and documented. Measure reachability with the
loader’s actual blocking model; an asserted coordinate or teleport is not
proof. Moving an entity also requires checking scripts whose route relied on
bumping its old cell.

After editing, run data lint and `ci_sweep.sh --touching <path>`, then the
path-walking scripts that cross the map. Update rendered map/entity assertions
only from observed counts/events. Run the scene dynamism tool as an advisory and
fix obvious composition/affordance gaps rather than optimizing its score.

Create an unregistered `probe_<map>` route when needed to capture the full map.
Read it windowed with the real overlay, compare drawn solids against blocking,
check doors from both sides, and capture distinct times to detect static NPCs.
For any interaction, prove physical adjacency, the real interact trigger,
domain state/event, and rendered feedback. Ask the user only for a genuine
layout/taste choice, with a prepared state and concrete alternatives.

Read [references/map-schema.md](references/map-schema.md) before adding a map,
entity kind, wall, portal, or presence/visual-state rule. Use
`wi-art-and-sprites` for registry/anchor work and `wi-verifying-changes` for the
final evidence set.
