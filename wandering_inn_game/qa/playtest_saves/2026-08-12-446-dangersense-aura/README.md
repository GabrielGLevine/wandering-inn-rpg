# Prepared Playtest State — Dangersense Night Aura (#446 eye-gate)

**Date:** 2026-08-12
**Purpose:** eye-gate for issue #446 (dangersense overlay reworked from HUD
selection box to in-world aura). This save parks a Rogue 4 on the night
floodplains at cell `[11,23]`, one safe cell south of the goblin night patrol's
trigger edge, with exactly one live warning region in view — the darkest field
the aura must stay legible on (#413 constraint).

## How to load

The Title → Playtest States picker only scans `res://qa/fixtures`, so this save
will NOT appear there. Use the manual slot:

1. Quit the game if it is running.
2. Copy the save into the user save directory as the **manual** slot:

   ```sh
   mkdir -p "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves"
   cp wandering_inn_game/qa/playtest_saves/2026-08-12-446-dangersense-aura/dangersense-night-aura.json \
     "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/manual.json"
   ```

   (Do NOT overwrite `auto.json` — use the `manual` slot.)
3. Launch the game (`/usr/local/bin/godot --path wandering_inn_game`) and pick
   **Continue** on the title screen.

## What to judge

Watch at least one full 6.4-second pulse cycle before moving:

- The warning reads as a breathing in-world aura — no rectangle, no corner
  brackets, no blinking.
- The radius edge is locatable: the ochre haze's outer edge IS the trigger
  boundary (step north one cell past it and the patrol wakes).
- Night legibility: the burnt-orange core must read clearly against the dark
  field (worst-case analytical contrast ~3.7:1 vs the ~1.52:1 #413 failure bar;
  derivation in `src/world/dangersense_overlay.gd` next to `CORE_COLOR`).
- The starting cell is safe; avoid stepping north until the read is done.
