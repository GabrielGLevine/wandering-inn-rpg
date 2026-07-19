# Prepared Playtest State — Raskghar Handoff (#148 thread legibility)

**Date:** 2026-07-17
**Purpose:** eye-gate for issue #148 (thread legibility, v0.10.0 headline). This
save is parked at the **Raskghar handoff** — you have come back up from the
warren (`cleared_the_warren`) but have **not yet reported to Zevara**
(`raskghar_sealed` still pending). That is the exact window where the new rumor
lattice is armed and most visible.

Build: Warrior 5 + Diplomat 1, Act II complete (The Errand / The Missing Crate /
Something in the Cisterns all done), 40 gold, standing in the inn facing Erin.

## How to load

1. Quit the game if it is running.
2. Copy `raskghar-handoff.json` into the game's user save directory as the
   **manual** slot:

   - macOS: `~/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/manual.json`
     ```sh
     mkdir -p "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves"
     cp wandering_inn_game/qa/playtest_saves/2026-07-17-raskghar-handoff/raskghar-handoff.json \
       "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/manual.json"
     ```
   (Paths are repo-root-relative, matching the sibling `2026-07-09-user-stage6`
   archive convention under `wandering_inn_game/qa/playtest_saves/`.)
   (Do NOT overwrite `auto.json` — use the `manual` slot.)
3. Launch the game (`/usr/local/bin/godot --path wandering_inn_game`), pick
   **Continue** on the title screen (the second row).

## What to look at (the #148 surfaces)

- **The rumor lattice (Tier 2).** Talk to **Erin** (she is right in front of you).
  Her first line is the armed relay: *"You came back up. TELL Zevara you came
  back up — she counts."* Walk out to the street and the other hub carriers
  (Krshia, Zevara, Olesm, Pisces) each carry their own thread-appropriate lines.
  After you actually report to Zevara at the gate (banking `raskghar_sealed`),
  Erin's relay **retires** back to neutral chitchat — the thread goes quiet once
  it is resolved.
- **The opt-in Quest Thread line (Tier 4).** Open **Settings** and toggle
  **Quest Thread** on (it ships **OFF** by default). A single quest-thread line
  now appears at the bottom of the field hotbar readout — the first active
  quest's *Title (Region) — beat text*. Toggle it back off and the readout is
  byte-for-byte what it was.
- **Sharper journal beats (Tier 1).** Open the **journal**. Every beat now names
  its place (and its person where a person is the contact) — e.g. the cistern
  and crate beats now say where to go and who to tell.
- **Arrival re-orientation (Tier 3).** Two maps re-orient you on arrival: the
  ruin surface (once you understand the door) and the dungeon approach (once the
  Watch points you at the fissure). At this save's state the dungeon-approach
  toast is already retired (you cleared the warren); the ruin toast arms later,
  once `door_understood` banks in the door chain.

## Notes

- Product locks held: no attribute words in player copy, no progress numerals,
  canon voice, opaque-until-sleep. The lattice relays say WHO/WHERE, never WHAT
  TO DO.
- This save is a real, coherence-valid story position (mirrors the
  `thread_lattice_loop_start` QA fixture's state with a realistic build).
