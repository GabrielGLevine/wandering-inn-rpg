# Prepared Playtest State — PC death-cast colour (#460 eye-gate)

**Date:** 2026-08-14
**Purpose:** eye-gate the [Bone Dart] / [Deathbolt] recolour shipped in #460.
`combat_screen._skill_flash_color` picked `FLAME_FLASH` for every non-frost
`spell_damage`, so both shipped [Necromancer] casts threw an **orange fire**
projectile and flashed orange on the target. They now key on the authored
`element: death` and read **grave-green** (`GRAVE_FLASH`, the same colour the
summon's arrival cell flashes).

**Why this needs your eyes and not a headless run:** `WICombatAI` defaults the
PC's empty `ai` to the melee profile, so **autoplay structurally cannot cast**.
No canonical fields a PC death-cast, and the only frames in hand are the Lich's
own bolts — the enemy side of the same colour. This is a player-visible change
to two *already-shipped* player spells, which is exactly the label-vs-art class
`VISUAL-LOG.md` exists for.

## How to load

The Title → Playtest States picker only scans `res://qa/fixtures`, so this save
will NOT appear there. Use the manual slot:

1. Quit the game if it is running.
2. Copy the save in as the **manual** slot:

   ```sh
   mkdir -p "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves"
   cp wandering_inn_game/qa/playtest_saves/2026-08-14-460-death-cast-colour/death-cast-colour.json \
     "$HOME/Library/Application Support/Godot/app_userdata/Wandering Inn RPG/saves/manual.json"
   ```

   (Do NOT overwrite `auto.json` — use the `manual` slot.)
3. Launch (`/usr/local/bin/godot --path wandering_inn_game`) and pick
   **Continue** on the title screen.

## Where it puts you

`ruin_surface` at cell **[16,11]**, facing east — one cell west of
`crypt_lich_mouth` at [17,11]. The encounter is **interact-only** (no trigger
radius), so nothing happens until you press interact. You are a **warrior 11 /
necromancer 10** carrying both recoloured spells hotbarred, a `leather_jerkin`,
two `mending_draught`s, and the new `graveflame_wand` equipped.

## What to do

1. Press **interact** facing the Lich to start the fight.
2. Cast **[Bone Dart]** and **[Deathbolt]** from the hotbar, at least once each.
3. Let the **Lich cast back** — it fields the same two spells, so you can judge
   the PC-cast and enemy-cast colour in the same fight, on the same background.

## What to judge

- Does grave-green **read as death magic** rather than as a generic green
  (the [Ice Wall]/frost blue and the nature-green glyph family are the
  neighbours it must not be confused with)?
- Does the projectile stay legible **against the cave floor** of `ruin_court`?
  The VISUAL-LOG row flags this as the specific risk: green-on-stone may read
  weakly where orange did not.
- Do PC-cast and enemy-cast read as **the same spell**? They should — one
  colour, two casters.
- If the hue is wrong, say which direction (darker / more desaturated / more
  blue-shifted); the constant is a one-line change.

## Do not sleep in this state

`warrior 11 + necromancer 10` is the **cheapest legal [Deathknight]
consolidation pair**, and consolidation now fires automatically in the sleep
beat (#482). Sleeping would retire both parents mid-read and take the spells
with them. Fight, judge, quit.

## Verified

The save loads and lands where this README claims — checked by applying it
through `WISave.apply` on a real `WIGame`:

```
PROBE map=ruin_surface cell=(16, 11) facing=(1, 0)
PROBE classes={ "warrior": 11.0, "necromancer": 10.0 }
PROBE bone_dart=true deathbolt=true
PROBE equipped={ "weapon": "rusty_sword", "armor": "leather_jerkin", "accessory_1": "graveflame_wand", ... }
PROBE_OK
```
