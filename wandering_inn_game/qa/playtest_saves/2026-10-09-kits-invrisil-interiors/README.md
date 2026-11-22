# Prepared Playtest State -- Invrisil stationer by day (#608 pilot 1b; re-aimed at the #632 rebuild)

**Date:** 2026-10-09
**Purpose:** eye-gate the #632 Invrisil rebuild on the five interiors, starting at the stationer. The save is the #608 pilot's, unchanged; what to look at below is #632's.

## How to load

The same state ships as the fixture `qa/fixtures/kits_invrisil_stationer_day_start.json`, so the
picker lists it:

1. Launch (`/usr/local/bin/godot --path wandering_inn_game`).
2. Pick **Playtest States** on the title screen, then
   **Kits Invrisil Stationer Day Start** (listed after the curated
   entries).

Or load this file through the manual slot:

1. Quit the game if it is running.
2. Copy the save in as the **manual** slot:

   ```sh
   mkdir -p "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves"
   cp wandering_inn_game/qa/playtest_saves/2026-10-09-kits-invrisil-interiors/kits-invrisil-stationer-day.json \
     "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/manual.json"
   ```

   (Do NOT overwrite `auto.json` -- use the `manual` slot.)
3. Launch (`/usr/local/bin/godot --path wandering_inn_game`) and pick
   **Continue** on the title screen.

## Where it puts you

`stationer` at its arrival cell **[6,7]**, one cell north of the door at [6,8], facing north into the shop, by **day** (`actions_since_sleep` 0). The interior grades match across phases and the four pilot interiors no longer add dust motes at dusk and night (dropped in the #608 1b night read), so night differs only by the authored lights.

## What to do

1. Look around the stationer: marble floor, plaster north wall with the gold cornice line, the counter and tables with their tabletop pieces, the iron stove.
2. Step out through the door at [6,8] to the cross-street, then into the Adventurer's Rest, the enchanter shop (door at [25,1] on the boulevard) and the Brothers' parlor (via the alleys) to compare the interiors.

## What to judge

- Stationer and enchanter shop: does the pale marble floor with the plaster wall and gold cornice read as a good shop, without going near-white?
- Tabletop pieces sit ON their surface, not in front of or behind it: inkpot and quill on the stationer counter at [5,1], scroll on the desk at [9,3], book on the table at [4,5]; the glass on the parlor counter; the test-tube rack and bell jar on the work-room sideboard at [5,1]-[6,1] (the work room needs the commission settled or [Pick Lock]).
- Stationer: the iron stove, the oak chairs and the planter. Enchanter shop: the lamp at [2,1] beside the glass case and the potted plant.
- Parlor: the settee for the guest couch. Adventurer's Rest: the one long bench and the helmeted bust beside the rack.
- Is every NPC still reachable around the furniture?

In a public checkout (no asset overlay) each tabletop piece draws its own owned stand-in (inkpot, quill, book, glass, rack, bell jar); check that none floats off its surface.

## Verified

`tests/test_fixture_coherence.gd` validates the fixture copy on every unit run.
Keep its `state` identical to this save's.

The save loads and lands where this README claims -- applied through
`WISave.apply` on a real `WIGame` with the shipped 400/900 phase thresholds:

```
PROBE ok=true map=stationer cell=(6, 7) facing=(0, -1) phase=day
```
