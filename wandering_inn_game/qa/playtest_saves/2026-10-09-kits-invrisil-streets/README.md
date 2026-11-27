# Prepared Playtest State -- Invrisil streets at dusk (#608 pilot 1a; re-aimed at the #632 rebuild)

**Date:** 2026-10-09
**Purpose:** eye-gate the #632 Invrisil rebuild on the three street maps (boulevard, cross-street, alleys). The save is the #608 pilot's, unchanged; what to look at below is #632's.

## How to load

The same state ships as the fixture `qa/fixtures/kits_invrisil_streets_dusk_start.json`, so the
picker lists it:

1. Launch (`/usr/local/bin/godot --path wandering_inn_game`).
2. Pick **Playtest States** on the title screen, then
   **Kits Invrisil Streets Dusk Start** (listed after the curated
   entries).

Or load this file through the manual slot:

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

1. Look at the boulevard from the fountain. It is dusk, so the nine upper windows should be lit.
2. Walk boulevard -> cross-street (door at [20,1]) -> alleys (door at [27,2]).
3. Keep walking until night falls (`actions_since_sleep` 900, about 450 steps) to see the windows and lanterns at night. Do not sleep: sleeping resets the clock to day.

## What to judge

- Window night state: do the upper windows on the boulevard (nine) and the cross-street (seven) glow warm at dusk and night, sit on their panes, and stay dark by day?
- Boulevard: the purple banners flanking the cross-street door, the pale urn on the west square at [3,8], and the townhouse door on the alleys portal.
- Cross-street: the Adventurer's Rest sign at [13,1] (three cards and a hat) and the pale urn at [18,5].
- Alleys: the cargo-yard cluster (kegs, crates, sacks, the sealed bale) on the wall-foot cells, and the steel wall lanterns with warm light, on the building wall at [11,9] and [16,10].
- Does it still read as one Invrisil, distinct from Liscor, and is the dusk grade legible on the paving?

In a public checkout (no asset overlay) the same walk shows the owned fallbacks: the cold steel lantern, the owned urn and the owned townhouse door.

## Verified

`tests/test_fixture_coherence.gd` validates the fixture copy on every unit run.
Keep its `state` identical to this save's.

The save loads and lands where this README claims -- applied through
`WISave.apply` on a real `WIGame` with the shipped 400/900 phase thresholds:

```
PROBE ok=true map=invrisil_boulevard cell=(14, 6) facing=(0, -1) phase=dusk
```
