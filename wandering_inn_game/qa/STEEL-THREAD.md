# Steel-thread playtest

Run from the repository root:

```bash
wandering_inn_game/qa/run_qa.sh steel_thread windowed --seed=9
```

This is a manual, non-sweep instrument and is intentionally absent from
`qa/manifest.json`. Its album lands in
`wandering_inn_game/qa_output/steel_thread/`. Each capture pauses for 240–300
frames (about 4–5 seconds at 60 fps); combat stays visible and resolves through
`combat_autoplay`.

Measured headless wall time at seed 9: **254.40 seconds**. Windowed mode adds
render/settle overhead; the controller will record the actual windowed duration.

## Ordered scene list

1. Title gate and title menu
2. Character picker, name, difficulty, and quest-hint choices
3. First inn view and GDI opener
4. Inn sign and Relc's classless spar tutorial
5. First sleep, `[Warrior]` gain, Relc's spear gift, and equipment panel
6. Gate-road ambush and Liscor gate-district arrival
7. Floodplains pond narrows, `[Snap Freeze]`, guardian arena, and cache
8. Clean `inn_upstairs` floor-seam read with no toast or epilogue overlay
9. Riverfarm village at night, visible wolf-field approach, proximity ambush
10. `witch_hollow` pocket landing zone and Riverfarm longhouse
11. Invrisil boulevard and `mercantile_alleys`
12. Pallass market, forge tier, calibration-rig parley, and forge-hall arena
13. Garden of Sanctuary, Adventurers' Guild, Watch barracks, and ruin surface
14. Sewers fissure, deep tunnels, Raskghar scouts, Relc veto, awakened boss
15. Act V journal, Pisces' descent ask, feeding ward, and seal choice
16. Seal Warden arena, opened vault, anchor, tally, and return
17. Final sleep and GDI epilogue

Fixture loads occur only at act boundaries after the preceding route has been
captured. Tutorial traversal, field-skill crossings, proximity ambushes, forge
hall, both deep-tunnel fights, the Seal Warden, vault, and finale all play live.

## Deliberately out of route

Interiors without their own walkthrough canonical remain out of route:
`inn_player_room`, shops, `rags_camp`, `brothers_parlor`, `runners_guild`,
`pallass_forge_hall` side rooms, and other fixture-only micro-interiors. The
steel thread targets major walkthrough maps, not exhaustive room coverage.

## Known limitation

Two identical seed-9 headless runs have produced different `events_seen`
totals. `combat_autoplay` victory pins are the completability proof, but may
flake under extreme timing variance. If a windowed run reds on a victory pin,
re-run once before triaging.
