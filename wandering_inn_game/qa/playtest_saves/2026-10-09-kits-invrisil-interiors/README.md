# Prepared Playtest State -- Invrisil stationer by day (#608 pilot 1b eye-gate)

**Date:** 2026-10-09
**Purpose:** eye-gate the regional kit on the five Invrisil interiors, starting at the stationer.

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

`stationer` at its arrival cell **[6,7]**, one cell north of the door at [6,8], facing north into the shop, by **day** (`actions_since_sleep` 0). The interior grades match across phases, but four interiors add dust motes at dusk and night, so this save covers the day view only.

## What to do

1. Look around the stationer: floor, walls, table, rug, window.
2. Step out through the door at [6,8] to the cross-street, then into the Adventurer's Rest, the enchanter shop (door at [25,1] on the boulevard) and the Brothers' parlor (via the alleys) to compare the interiors.

## What to judge

- Do the interiors read as one shop family (flagstone and timber) rather than the generic Interior_Walls look?
- Do the table, rug and window variants clash within one room?
- Do the flat stand-ins (tray, paper stand) read as props?
- Is every NPC still reachable around the converted tables?

## Verified

`tests/test_fixture_coherence.gd` validates the fixture copy on every unit run.
Keep its `state` identical to this save's.

The save loads and lands where this README claims -- applied through
`WISave.apply` on a real `WIGame` with the shipped 400/900 phase thresholds:

```
PROBE ok=true map=stationer cell=(6, 7) facing=(0, -1) phase=day
```
