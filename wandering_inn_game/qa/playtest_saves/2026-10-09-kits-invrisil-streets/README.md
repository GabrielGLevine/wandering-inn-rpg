# Prepared Playtest State -- Invrisil streets at dusk (#608 pilot 1a eye-gate)

**Date:** 2026-10-09
**Purpose:** eye-gate the regional kit on Invrisil's three street maps (boulevard, cross-street, alleys): identity, repetition and clutter, which metrics cannot judge.

## How to load

The Title -> Playtest States picker only scans `res://qa/fixtures`, so this save
will NOT appear there. Use the manual slot:

1. Quit the game if it is running.
2. Copy the save in as the **manual** slot:

   ```sh
   mkdir -p "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves"
   cp wandering_inn_game/qa/playtest_saves/2026-10-09-kits-invrisil-streets/kits-invrisil-streets-dusk.json \
     "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/manual.json"
   ```

   (Do NOT overwrite `auto.json` -- use the `manual` slot.)
3. Launch (`/usr/local/bin/godot --path wandering_inn_game`) and pick
   **Continue** on the title screen.

## Where it puts you

`invrisil_boulevard` at cell **[14,6]**, facing north at the `plaza_fountain` at [14,5], at **dusk** (`actions_since_sleep` 450). The player is a post-game warrior 10 with no encounter trigger in reach.

## What to do

1. Look at the boulevard from the fountain.
2. Walk boulevard -> cross-street (door at [20,1]) -> alleys (door at [27,2]).
3. Do not sleep: sleeping resets the clock to day.

## What to judge

- Does it read as one Invrisil, distinct from Liscor and the Floodplains (regional identity)?
- Do windows, doors, lamps and cargo repeat visibly (repetition)?
- Is any street too busy or too bare (clutter)?
- Is the dusk grade legible on the marble and ashlar floors?

## Verified

The save loads and lands where this README claims -- applied through
`WISave.apply` on a real `WIGame` with the shipped 400/900 phase thresholds:

```
PROBE ok=true map=invrisil_boulevard cell=(14, 6) facing=(0, -1) phase=dusk
```
