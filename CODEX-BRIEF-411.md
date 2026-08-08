# Issue #411 — water shoreline treatment (renderer autotile)

You are implementing in the worktree at repo root (branch issue/411-water-shoreline). Read `wandering_inn_game/AGENTS.md` first. Do NOT commit (controller commits). Do NOT edit fixtures or weaken any assertion. Presentation only renders — no sim (`src/core/**`) changes.

## Problem
Water `walls.segments` rows (tagged `water: true`, sheet `res://assets/tiles/free_pack/Water_tiles.png`) render as ONE flat tile per cell (the segment `cap` coord). A pond is a blob of identical blue squares: no banks, no island ring. User capture: `wandering_inn_game/qa_output/probe_roads/pond_island_after.png` in the MAIN tree (read-only reference; may not exist in this worktree).

## The sheet has what you need
`Water_tiles.png` is 400x400, 16px grid. Its top-left region holds classic autotile blob layouts: grass-island-in-water blobs with brown bank edges (4 variants across the top band), plus plain-water variants below. Inspect pixel data yourself to derive the exact edge-tile coordinate map — document the derived map in a comment table.

## Acceptance criteria (numbered; list every one you do NOT meet)
1. The water-segment renderer picks EDGE/CORNER tiles by neighborhood: for each water cell, examine its 8 water/non-water neighbors (union of ALL water segment cells on the map, not per-segment) and select the matching shore tile; interior cells keep a plain-water variant. Handle at minimum: straight edges (4), outer corners (4), inner corners (4), interior. If the sheet's blob set supports finer cases, use them; if a neighborhood has no matching tile, fall back to the current cap tile (NEVER a missing-texture).
2. Works for concave shapes and 1-cell islands-in-water and 1-cell water inlets (the floodplains pond has all three; sewers channels are 1-2 cells wide).
3. Data contract unchanged: no new required map keys. Existing `cap` stays as the interior/fallback pick. (An OPTIONAL per-segment opt-out flag is allowed if some water must stay flat — document it if added.)
4. A UNIT TEST for the edge-picker mapping (pure function: neighborhood bitmask -> tile coord), including the prove-it-can-fail step: the test must fail if the mapping table is corrupted (mutate-in-test or an assert on a known-wrong input).
5. Headless gates green from this worktree: `python3 wandering_inn_game/scripts/data_lint.py` rc=0; full unit suite (every `tests/test_*.gd`) — discipline: `grep -E "SCRIPT ERROR|Parse Error|ERROR: FAIL"` = 0 AND `^PASS` present per suite; `wandering_inn_game/qa/ci_sweep.sh --touching wandering_inn_game/data/maps/floodplains/floodplains.json` all green.
6. You cannot open windows: do NOT claim visual verification. The controller does the windowed read. Your evidence = the unit test + a dump of the picker's tile choices for the floodplains pond neighborhood (print the grid in your report).
7. STOP triggers: needing a sim change, needing a new map data format (beyond the optional flag in 3), or the sheet lacking usable edge tiles → STOP and report NEEDS_CONTEXT; do not improvise around them.

## Report
Files changed, the derived tile-coordinate table, the pond grid dump, gate outputs verbatim, criteria not met.
