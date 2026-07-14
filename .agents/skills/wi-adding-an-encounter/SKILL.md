---
name: wi-adding-an-encounter
description: Use when adding a new enemy/combatant, arena, or encounter entity, or changing any combat-balance data (stats, weapon_die, skills, arena layout) that could shift fight outcomes.
---

# Adding an Encounter

Combat data lives in `data/combatants.json` (roster), `data/arenas.json`
(battlefields), and an `encounter` entity on a map
(`data/maps/<region>/<map>.json`, issue #100 split) that ties a roster subset to an arena. Tune
these DATA files — never the sim (`src/core/combat/*`) — to change balance.

## Combatant record (`data/combatants.json`)
| Field | Meaning |
|---|---|
| `id` | referenced by encounter `enemies`/`allies` and combatant lookups |
| `display_name`, `sprite` | presentation |
| `side` | `"player"` or `"enemy"` |
| `stats` | `str/dex/con/int/wis/cha` — **never shown to players anywhere**, drives derived combat stats only |
| `weapon_die` | base damage die (`pc`/`relc`/goblins use 4-6) |
| `ai` | `""` (player-controlled — the PC's own entry), `"melee"`, `"ranged"`, or `"caster"` (profile `WICombatAI.take_turn` picks) |
| `skills` | Array of skill ids this combatant knows (e.g. `["basic_swordwork"]`, `["flame_bolt"]`) |

## Arena record (`data/arenas.json`)
| Field | Meaning |
|---|---|
| `id` | referenced by an encounter's `arena` |
| `biome` | key into `data/biomes.json` for default tile art |
| `grid` | `{width, height}` — both current arenas are 12×8 |
| `blocked` | `[[x,y], ...]` blocked cells inside the grid |
| `player_spawns` / `enemy_spawns` | Arrays of `[x,y]` candidate spawn cells for each side |
| `floor_layers`, `decor` | presentation-only; decor is deliberately placed OUTSIDE the playable grid (x<0 or x>=width) so it never competes with tactical readability |

## Encounter entity (on a map, `kind: "encounter"`)
`arena` (arena id), `enemies: [combatant id, ...]`, `allies: [combatant id,
...]` (added alongside the PC), `conversation?` (a parley option before the
fight starts), `on_victory?` (String or Array of accomplishment ids granted
on win, default `"won_combat"`), `respawns?` (bool — `true` means victory
leaves the entity on the map but DORMANT (`start_combat` refuses it, tracked
in the save's `dormant_encounters`) until the next sleep beat re-arms it;
default/absent means the entity is removed for good on victory). Full field
table and blocking/reachability rules: `wi-adding-a-scene`.

## Balance workflow — the harness is the only authority
Run after ANY roster/stat/skill/arena change:
```
/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd
```
16 cells (2 compositions × 8 builds, 100 seeds each). GATED cells must land
win-rate 0.55–0.95, median rounds 3–12; some are `gated: false`
(recorded/measured only — split-class, caster-profile, and
`warrior1_tutorial`). `warrior1_tutorial` is the **tutorial-difficulty
watchdog**: the player's real first fight (`goblin_encounter_2` →
`goblin_ambush`) is fought at warrior level 1, no `counter_strike`/
`battle_momentum` yet — watch its win-rate even though it isn't bounds-gated;
an unwinnable first fight is a real regression regardless of other cells.

## The autoplay gotcha (never forget this one)
`WICombatAI.take_turn`'s `_act_once` defaults an empty `"ai"` field (the PC's
own entry) to the **melee** profile, so `combat_autoplay` will NEVER cast a
spell for the player, no matter the seed or classes held — a QA script cannot
observe a player-side cast. Assert the kit via state instead:
```json
{"action": "assert_state", "path": "combat.combatants.pc.max_mp", "equals": 16}
```
or `combat.combatants.pc.skills` with `"contains"` a spell id
(`mage_unlock_loop`/`consolidation_flow`'s pattern). Only the harness's
`"ai": "caster"` build profile ever exercises a casting PC — a measurement
axis, not something reachable through real play.

## After any combat-data change: re-verify every combat QA script
Fights are deterministic per seed, but stat/skill/roster/arena changes can
flip a canonical outcome. Re-run every combat-touching script at its pinned
seed (`AGENTS.md` table). A failure is a real seed-search task, not a
one-value edit — `level_up_loop`'s fight 2 moved from `goblin_encounter_1` to
`chieftains_raid` (repinned to seed 11) because the old composition
structurally could never trigger `counter_strike`.

## New encounters need a QA script + seed-table row
Per `wi-writing-qa-scripts`: walk it, assert `combat_started`/
`combat_finished` and `ui_combat_shown`/`ui_combat_hidden`, pin a seed, add
the `AGENTS.md` row.

## Common mistakes
- Tuning a stat/skill "by feel" and skipping the harness — the harness is the
  numbers authority, not intuition.
- Writing a QA assertion that expects the PC to cast a spell under
  `combat_autoplay` — it structurally cannot happen (melee-profile default).
- Changing combat data and not re-running the pinned-seed combat scripts —
  a green harness does not guarantee a canonical script's outcome is
  unchanged.
- Treating `warrior1_tutorial`'s `gated: false` as "doesn't matter" — it's
  measured specifically because it's the player's real first fight.
- Forgetting `respawns: true` vs. permanent removal when copying an existing
  encounter entity as a template.

Verify per `wi-verifying-changes` (balance harness + full QA sweep + seed
check is the required gate set for any combat-data change).
