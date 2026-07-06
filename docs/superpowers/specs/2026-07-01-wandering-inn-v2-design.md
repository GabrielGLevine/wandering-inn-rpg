# Wandering Inn RPG v2 — Design

## Goal

Build `wandering_inn_game_v2`: a Godot game set in the world of The Wandering Inn, using `godot-open-rpg`'s field/combat engine as the structural foundation instead of building from scratch (as `wandering_inn_game_v1` did).

`wandering_inn_game_v1` proved out lore-accurate content (classes, races, skills, enemies, dialogue as JSON) but built its own field movement, dialogue, and tactical-grid combat systems from the ground up. `godot-open-rpg` is a GDQuest teaching demo with a more robust, already-working engine (gameboard/pathfinding, gamepiece movement, cutscene/trigger system, Dialogic-based dialogue, readiness-bar turn-based combat) but only placeholder generic-fantasy content (bear/wolf/squirrel battlers, unnamed knight/wizard/thief sprites) and no RPG progression system (no classes, races, skills, or leveling at all).

v2 combines them: open-rpg's engine, reskinned and extended with v1's Wandering Inn content and a new class/race/skill/leveling layer that open-rpg doesn't have.

**Lore source of truth:** [The Wandering Inn Wiki](https://wiki.wanderinginn.com/The_Wandering_Inn_Wiki) — check here for canon accuracy on characters (e.g. Relc's personality/abilities), skills/classes, and locations (Liscor, the Inn) whenever content is authored or reviewed.

## MVP Scope

First playable milestone only — not full conversion of all Wandering Inn lore in one pass:

- **Player character:** solo custom-built PC (player chooses race + background + name at game start, tabletop-style), can hold multiple classes and levels like v1's model
- **Classes:** Fighter and Mage only (of v1's 12 total)
- **Companion:** Relc Grasstongue (Drake, tanky melee), recruitable — party is PC + 1 companion, using open-rpg's native multi-Battler `BattlerRoster`
- **Combat:** open-rpg's existing readiness-bar/ATB turn system, unmodified — no tactical grid
- **Enemy:** one enemy from v1's `enemies.json`, for one combat encounter
- **Maps:** The Wandering Inn (interior, start hub) and Liscor (town exterior, recruit Relc + combat encounter) — 2 of open-rpg's 3 placeholder maps reskinned; forest map unused for now
- **Dialogue:** Erin (Inn) and Relc (Liscor), converted from v1's JSON to Dialogic timelines
- **Items/Quests:** only what's needed to support the above (a couple items, one "recruit Relc" quest flag)

Everything else — the other 10 classes and ~65 skills, the other 9 enemies, the forest map, the rest of v1's items/quests catalog, other NPCs' dialogue (Selys, Mrsha, Klbkch) — is deferred to future milestones, each following the same pattern established here.

## Non-Goals (for this milestone)

- Full skill catalog port (67 of v1's 78 skills have near-unique, often grid/positional effects built for v1's abandoned tactical-grid combat; porting them requires bespoke engine work per skill and is out of scope until the MVP pattern is proven)
- Multiple companions or full party management UI
- General-purpose data-driven item/quest systems (open-rpg's enum-based `Inventory` and a simple flags dict are sufficient at MVP content scale)
- New custom art — reuse open-rpg's placeholder sprites/tilesets as-is

## Architecture

### Project setup

- New folder `wandering_inn_game_v2/`, created as a fresh clone of `godot-open-rpg` (copy the files; do not nest `godot-open-rpg`'s own `.git` history — v2 gets a clean start inside this repo)
- Engine: Godot **4.6.2** (matches `godot-open-rpg`'s `project.godot` pin; confirmed installed at `/usr/local/bin/godot`)
- `godot-open-rpg/` itself stays untouched, excluded from this repo (`.gitignore`), used only as the clone source and as a reference to diff against when merging upstream fixes later
- Every new `.gd` file needs a headless import pass before `class_name` registration works: `/usr/local/bin/godot --headless --path <path-to-v2> --import`

### Data layer

v1's JSON files (`classes.json`, `races.json`, `skills.json`, `enemies.json`) are the source-of-truth reference content, ported as native Godot `Resource` (`.tres`) files rather than runtime-loaded JSON — matching how `godot-open-rpg` already authors battlers and actions as `.tres` instances of shared GDScript classes.

New Resource types (none of these exist in open-rpg today):
- **`WIClassData`** — id, display name, `gained_by` condition text (e.g. "Win 5 melee combats"), stat priority, and `level_skills: Dictionary[int, Array[Resource]]` mapping level thresholds to the actions/passives unlocked at that level
- **`WIRaceData`** — stat bonuses and display info, ported near-verbatim from `races.json` (cheap: pure data, no reinterpretation needed)
- **Active skills** → subclass `BattlerAction` (open-rpg's existing interface: `battler_action_attack.gd`, `battler_action_heal.gd`, `battler_action_modify_stats.gd` are the existing examples to follow)
- **Passive skills** → new `PassiveEffect` Resource, applied via `BattlerStats.add_modifier` / `add_multiplier` when the granting class reaches the required level

### Player character system (new)

`godot-open-rpg`'s `Player` autoload currently only tracks the field gamepiece reference — no stats, classes, or inventory. Extend it (or add a new `WIPlayerState` autoload alongside it) to hold: race, background, `classes: Dictionary[String, int]`, tracked accomplishments, and inventory state.

Unlike companions and enemies (hand-authored static `Battler` scenes, matching open-rpg's existing demo pattern), the PC's `Battler` + `BattlerStats` are **constructed dynamically at runtime** from `WIPlayerState`, since the PC's race/class/level combination varies per playthrough.

### Stats are internal only

The Wandering Inn's source material has no explicit STR/DEX/CON/INT/WIS/CHA stat sheet visible to the reader. v1's `stats: {STR, DEX, CON, INT, WIS, CHA}` dictionary (used internally to derive `BattlerStats.attack`/`defense`/`max_health`/etc. per race/class bonuses) is kept as an internal calculation only. No UI surfaces raw stat numbers or letter/number ratings to the player. Character creation and any character-sheet screen show only: race, class(es) and level(s), known skills (with flavor descriptions), and derived combat values that make narrative sense to show (HP, MP/mana, equipped gear) — not the underlying STR/DEX/etc. inputs.

### Leveling (new — open-rpg has no leveling/XP system at all)

Port v1's accomplishment-based model: there is no XP. Classes are gained by meeting a condition (`gained_by`, e.g. "Cast 5 spells successfully") and leveled by tracked accomplishments. Reaching a level threshold in `WIClassData.level_skills` automatically grants the listed skill(s).

### Combat

Unmodified `godot-open-rpg` engine: `Combat` (turn director), `Battler`/`BattlerStats`/`BattlerAction`, `BattlerRoster`. No tactical grid, no AP system — action selection and speed-ordered execution as open-rpg already implements it.

### MVP skill mapping (Fighter + Mage, ~13 skills)

Ports directly onto the architecture above:
`basic_swordwork`, `tough_body`, `counter_strike`, `power_strike`, `tier1_unlock`, `tier2_unlock`, `quick_cast`, `mana_conservation`, `spell_evolution`

Reinterpreted (originally grid-positional or purely informational, no non-grid combat equivalent):
- `battle_momentum` (was "+1 AP on kill") → bonus readiness / extra turn on kill
- `guard_formation` (party-formation defense buff) → dropped for MVP; a formation mechanic doesn't apply to a 1-companion, non-grid party
- `mana_sense`, `arcane_sight` (magic detection/informational) → flavor/narrative only, no mechanical combat effect

### Companions

Relc Grasstongue: hand-authored static `Battler` scene (Drake, tanky melee), recruited via a field `Interaction`/cutscene placed in the Liscor map, then added to the party's `BattlerRoster` entry — no new companion-recruitment framework needed beyond open-rpg's existing `Interaction`/`Cutscene` templates.

### Dialogue

Use open-rpg's bundled Dialogic plugin (already registered in `project.godot`) instead of v1's custom JSON dialogue-node engine. v1's `erin.json` and `relc.json` dialogue content is converted to Dialogic `.dtl` timeline files — a content-conversion task, not new engine code. Other NPCs' dialogue JSON (`selys.json`, `mrsha.json`, `klbkch.json`) is left unconverted until those characters are in scope.

### Inventory / Quests

open-rpg's `Inventory` (`src/common/inventory.gd`) is a small hardcoded `ItemTypes` enum with icon lookup — sufficient at MVP content scale. Extend the enum with the handful of WI items actually needed rather than building a general-purpose data-driven item catalog. No dedicated quest system: a flags dictionary on `WIPlayerState` covers the single "recruit Relc" quest state needed for MVP.

### Maps

- `overworld/maps/house/` (map + tileset) → **The Wandering Inn** interior: starting location, Erin dialogue hub, character creation happens here or immediately before entering
- `overworld/maps/town/` (map + tileset) → **Liscor**: guard post to recruit Relc, one combat encounter trigger using the MVP enemy
- `overworld/maps/forest/` — unused for MVP, reskinned in a later milestone

## Testing

Godot has no unit test framework configured in `godot-open-rpg` (no GUT/gdUnit) and none should be introduced solely for this — verification is manual + headless parse checks:
- `godot --headless --path wandering_inn_game_v2 --quit` after each work session to surface script/autoload parse errors
- Manual playtest of the full MVP slice: create character → start at the Inn → talk to Erin → travel to Liscor → recruit Relc → trigger the combat encounter → win/lose combat resolves correctly

## Risks / Open Items

- **Godot version:** confirmed no conflict — installed engine is 4.6.2, matching `godot-open-rpg`'s pin exactly (v1's CLAUDE.md references a stale `/opt/homebrew/bin/godot` 4.7 path that no longer exists on this machine; v2's CLAUDE.md will use `/usr/local/bin/godot` 4.6.2)
- **Skill effect reinterpretation is subjective:** the 4 reinterpreted/dropped MVP skills (`battle_momentum`, `guard_formation`, `mana_sense`, `arcane_sight`) are judgment calls made without a tactical grid to design against — acceptable for MVP flavor, may need revisiting once more classes are ported and patterns emerge
- **Dynamic PC Battler construction** is new territory relative to open-rpg's all-static-Battler-scenes demo pattern — worth prototyping early in implementation to confirm `BattlerStats`/`BattlerAction` assembly at runtime works cleanly before building the rest of the character-creation flow on top of it
