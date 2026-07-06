# Consultant brief #2: Liscor gate district (world map) + combat tutorial design

**Date:** 2026-07-03. Two deliverables, priority order below. Same rules as the
Floodplains brief (2026-07-03-floodplains-world-map-brief.md): design + data only,
reply with a document, commit nothing, flag every uncertain atlas pick. Read first:
docs/asset-catalog.md, docs/asset-index.md, docs/scene-assembly-guide.md, and your
own accepted Floodplains deliverable (2026-07-03-floodplains-world-map-design.md —
now integrated; your §5 sketch is the seed for deliverable 1). Integration notes you
should honor: POI-B moved to (13,18); water cap re-picked [1,7]; walls-v2 supports
per-segment sheet overrides (confirmed).

## Deliverable 1 (priority): Liscor gate district — grow the street into a world map

Execute your §5 sketch in full, to the same completeness as the Floodplains
deliverable: ~32x20 world environment; current 10x6 street = the west gate plaza
(street_door position preserved, now the gate back to the Floodplains); eastward:
market row (Library-pack desks/shelving as stalls; Selys relocates here near the
Adventurer's Guild), a Watch post (Castle pack; Royal Crew stand-ins flagged
non-canon-race), Adventurer's Guild doorway as a future interior door target,
wall segments framing the north edge interior-side (player is inside the city).
Existing street encounters (goblin_encounter_1/2, chieftains_raid) MIGRATE OUT to
the Floodplains POI anchors — propose their exact new cells + how the goblin_parley
conversation trigger relocates. Complete map JSON + biome/sprite additions +
transition graph + flag table, exactly like last time.

## Deliverable 2 (if budget remains): combat tutorial design (Relc)

Design the combat tutorial that hangs off the Relc road introduction (see §6 of the
Floodplains design doc — met_relc gating is decided). Constraints: (a) the tutorial
is a REAL WICombat fight vs training dummies or a sparring Relc — no fake UI mode;
propose the encounter/arena data (trivial: true so it banks no counters — that flag
exists); (b) it must teach: arrows move directly (pool), Dash refill, hotbar number
keys, targeting (Tab/Enter), End Turn (E) — the M5 movement-first scheme; (c)
teaching lines delivered via the existing dialogue/toast systems (no new engine
features; propose the exact toast/feed copy per beat); (d) skippable — a player who
declines Relc's offer just doesn't get it; repeatable via re-talking to Relc; (e)
opaque-until-sleep stands — the tutorial NEVER shows progress meters or explains
the leveling system beyond Relc's in-character hints. Deliverable: encounter +
arena JSON, the conversation graph extension (tutorial option replacing the stub),
beat-by-beat script table (player action -> Relc line), QA script outline.
