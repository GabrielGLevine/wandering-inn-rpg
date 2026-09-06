# Encounter schema

Combatants carry ID/name, HP, movement/AP, accuracy/evasion/armor, derived power
inputs, weapon die, AI profile, skills, and optional combat visual adjustments.
The parser and combat-data tests own the exact keys and ranges.

Arenas carry ID, biome, grid, blocked cells, player/enemy spawn candidates, and
presentation floor/decor. Validate every spawn and reachable combat space
against the real blocker model.

Map entities of kind `encounter` reference an arena and combatant IDs, optional
allies/conversation, victory accomplishment string or array, and optional
respawn. Respawning victories record dormancy until sleep; ordinary victories
remove the entity. Follow `wi-adding-a-scene` for map blocking and doors.

Registration includes combat/content validation, sprite frames and scale,
produced/shipped accomplishment IDs, map reachability, a manifest QA route, and
all affected deterministic combat canonicals. Inspect sibling records/tests for
current registration rather than maintaining a hardcoded matrix here.
