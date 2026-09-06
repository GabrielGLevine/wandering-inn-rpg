# Map schema

A map record contains biome, grid, optional blocked cells, walls, floor layers,
decor, scatter, and entities. Read `scene_catalog.gd`, `world.gd`, and nearby
records for exact current shapes.

Wall segments expand the inclusive rectangle between `from` and `to`; the same
expanded cells drive sim blocking and wall rendering. Atlas `cap`/`face`
coordinates are art coordinates, not gameplay cells. Decorative skirts are
nonblocking.

Every entity has ID, kind, cell, display name, and sprite, with optional facing
and tint. NPCs may start a conversation or provide fallback dialogue. Props may
sleep, bank an interaction accomplishment, or invoke a known field skill. Doors
name destination map/cell. Encounters name arena, enemy/allied rosters, optional
conversation/victory accomplishments, and respawn behavior.

Inspect interaction precedence when combining fields. A gated door transition
may short-circuit a generic interaction accomplishment; QA must pin the
open/blocked feedback and map transition produced by the real resolver, not an
effect that never runs. Arrival transitions can bypass ordinary blocking, so
verify the destination and a safe step-away/re-entry route.

Presence variants and visual states are ordered/gated data. Inspect all existing
arms and current resolver semantics before appending: later matching variants
may shadow earlier text/art, and presence changes during dialogue may be
deferred. Shipped map/entity/counter IDs obey the freeze list. Append with the
repository splice helper and validate exact placement.

A new blocking entity on a cell that was walkable in a shipped save can load a
player inside solid geometry. Prove an open neighbor using the real blocker
model or add a save migration that moves the player to a safe cell. Treat
cul-de-sac placements as save-compatibility changes, not only layout changes.
