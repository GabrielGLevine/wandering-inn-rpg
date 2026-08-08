# Playtest round-3 fix plan (user findings, 2026-08-08) — VERIFIED, mid-execution

All four findings reproduced with data + windowed captures
(qa_output/probe_{boulevard,hollow,village}/*.png; probe scripts are
UNREGISTERED temporaries in qa/scripts/probe_*.json — delete or
register at close). Weekly usage CAUTION: inline fixes only, no lanes.

## Verified findings + decided fixes

1. **Eloise "second house" (witch_hollow)** — CONFIRMED by capture:
   codex_hut ("The Old Hut", door to witch_hut map, entity[23] at
   (1,7), rs 0.4 = ~2 cells) renders jammed into witch_cottage_prop
   (green thatch, entity[9] at (3,7), 80px). They are DISTINCT
   buildings by design (Old Hut = derelict interior map; cottage =
   Eloise's). Fix: MOVE witch_hut_door south-west, e.g. (1,10)-ish —
   keeps l3's re-authored prose fact "west edge" TRUE (hollow[23]
   .observe pins west-edge + smaller-house facts). Blocked cells (1,5)
   (2,5)(1,6)(2,6)... belong to the cottage+hut band — recompute both
   footprints and re-lay blocked to match art. QA routes: makings_loop,
   witch_brew_loop, witch_cottage_reachability walk the hollow —
   re-derive routes/pins from runs after the move.
2. **Longhouse blocked-vs-art (riverfarm_village)** — CONFIRMED
   mechanically: blocked x8..14 y6..7; art (112x64 @1.0, anchor
   .522/.813 at (11,7)) covers x9.67..13.17, y to 8.37. Fix: blocked
   -> x10..13 y6..7 (remove (8,6)(8,7)(9,6)(9,7)(14,6)(14,7));
   re-derive village blocked_cells count pins (105 -> 99) from runs.
3. **Boulevard alley door free-floats** — CONFIRMED by capture: drawn
   alley mouth = tan brick at top-right (~x26+, y0..2); functional
   door boulevard_to_alleys at (26,8) mid-east-edge, unattached. ~10
   scripts route boulevard->mercantile; moving the door = route
   re-authoring across them. DECISION: too heavy for CAUTION inline —
   file as scoped issue with the capture attached.
4. **Static NPCs** — census: 13 NPC sprites have NO idle animation
   entry (wilovan, ratici, hedault, master_coyle, drake_patron,
   gnoll_ranger, gnoll_traveler, hired_blade, human_laborer,
   invrisil_lady_client, citizen_f, city_scribe + one more) — file art
   issue (PixelLab idle sheets, established pipeline).
5. **Spriteless boulevard props** (glazier (6,1), teahouse (7,1),
   cordwainer (15,1), carriage_wake (11,1)) — capture shows real
   facade art behind them; they read as building features, NOT
   free-floating. Fix: add explicit `"invisible": true` marker +
   justifying _comment to each; new data_lint HARD arm: interactable
   entity with no sprite must carry invisible:true.
6. **Magic Door sprite unification (user side-note)** — cities show a
   green stone arch sprite (visible in both captures). My grep did NOT
   find the inn's magical-door entity or the city portal ids — search
   display_name "Magical Door"/kind door to_map across maps, then set
   the inn's to the same arch sprite id.

## Systematic arms owed (the "machine playtests should have caught" answer)
a) data_lint HARD: spriteless interactable entities need invisible:true.
b) data_lint ADVISORY: blocked cell with no visual owner — footprint-
   aware (expand entity/decor cells by frame_size*render_scale around
   anchor; segments count as dressed).
c) data_lint ADVISORY: atlas-region alpha coverage (PIL scan) — catches
   the invisible-sprite class (#398 bar_counter precedent).
d) wi-machine-playtest fold: capture set for any new/changed map MUST
   include debug-overlay-ON shots (blocked cells vs art) + walk-the-
   edges instruction; static-NPC check (two consecutive captures
   differ on NPC cells).

## Sequence
Longhouse fix -> hollow move -> invisible markers + arm (a) -> arms
(b)(c) -> magic-door swap -> pins/routes re-derived from runs ->
--touching sweeps green -> VISUAL-LOG + commit -> file alley-door issue
+ idle-anim art issue -> skill fold (d) -> delete/register probe_*.
