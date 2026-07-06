# Wandering Inn RPG v3 — "Defend the Inn" Vertical Slice Design

## Goal

Turn the v2 MVP (create a character, meet Erin, recruit Relc, fight one enemy) into a small but complete, polished vertical slice that feels like a real Wandering Inn quest: a concrete threat, a few varied beats, real class progression, and a climax that pays off the progression system the MVP built but never exercised through play (no accomplishment tracking existed yet, and the PC never actually leveled up).

This is a continuation of the existing MVP loop, not a replacement — Relc is already recruited and the MVP's Shield Spider fight is reused as this slice's first combat beat.

## Non-Goals

- No generic leveling-curve system. This slice only needs Fighter level 1 → 2 to work; the accomplishment-threshold check is written for that one transition, not as a scalable framework for arbitrary future levels/classes.
- No new tutorial system. Guidance is a few extra lines of dialogue/hint text gated by a one-time-seen flag, not a tutorial framework.
- No branching quest-flag system beyond what's needed for this slice's linear beat order.
- No new combat mechanics or engine changes — the climax fight uses the exact same `PCBattlerBuilder`/`CombatArena` machinery the MVP already built. Leveling happens *before* combat starts (at the sleep beat), specifically to avoid needing any live-Battler mid-combat mutation.
- Full dialogue-UI redesign is out of scope — only the specific choice/text overlap bug (rolled in from v2's known-bug backlog) is fixed.

## Player-Facing Flow

1. **Erin frames the threat.** A new branch on Erin's existing dialogue hub: goblins are massing near Liscor and the inn is at risk. Includes the one-time combat hint (see Tutorial Guidance) since the player is about to be pointed at Beat 1.
2. **Beat 1 (combat) — Shield Spider, near Liscor.** The MVP's existing encounter, reused as-is (same `CombatTrigger`, same arena, same enemy). On victory, records the `won_melee_combat` accomplishment.
3. **Beat 2 (non-combat) — Fortify the Inn.** Back at the inn, the player interacts with 3 static props (barricade a door, move a barrel, warn a patron). The first one interacted with includes the one-time fortify hint, stating there are multiple things to prepare. Once all 3 are done, the `protected_ally_or_inn` accomplishment is set.
4. **Beat 3 (non-combat) — Sleep.** A `Bed` interactable at the inn. Interacting triggers a level-up check: if both `won_melee_combat` and `protected_ally_or_inn` are recorded, the Fighter class advances to level 2 and Counter Strike unlocks, shown via a toast (`[Fighter Level 2] — unlocked Counter Strike`). If the accomplishments aren't there yet, this is a silent no-op and the player can try again later — no gating dialogue needed.
5. **Climax (combat) — the goblins attack.** A new `CombatTrigger` starts `defend_inn_combat_arena.tscn`: PC + Relc vs. 1x Goblin Raider + 1x Goblin Shaman. Because leveling already happened at the sleep beat, the PC simply builds at level 2 from the start of this fight — Counter Strike is available from turn one.
6. **Resolution.** Return to Erin for a closing dialogue beat acknowledging the outcome.

## Architecture

### Leveling and accomplishment tracking (new)

`WIPlayerState` gains a single new field, `accomplishments: Dictionary` (String key → `true`), used as the general-purpose progress-flag store for this entire quest — not just leveling inputs. `won_melee_combat`, `fortify_door`, `fortify_barrel`, `fortify_patron`, and `protected_ally_or_inn` (the umbrella flag set once all 3 `fortify_*` keys are present) all live here as one source of truth, rather than several parallel boolean fields.

Two new methods:
- `record_accomplishment(id: String) -> void` — sets `accomplishments[id] = true`. If `id` starts with `"fortify_"` and all 3 fortify sub-flags (`fortify_door`, `fortify_barrel`, `fortify_patron`) are now present, also sets `protected_ally_or_inn`.
- `check_for_level_up() -> bool` — this slice's leveling rule is written explicitly for the one transition it needs to support (Fighter 1 → 2), not as a generic curve: `if classes.get("fighter", 0) == 1 and accomplishments.has("won_melee_combat") and accomplishments.has("protected_ally_or_inn"): classes["fighter"] = 2; return true`. Returns `false` otherwise.

No other part of the leveling/progression system changes. `PCBattlerBuilder`, `WIClassCatalog`, and the class/skill `.tres` content are all consumed exactly as the MVP built them — this slice only supplies a new *trigger* for reaching level 2 (the sleep beat), not a new mechanism for what level 2 grants.

### Sleep beat (new)

`Bed` — a static `Interaction.tscn` instance placed in the House, following the same pattern as the existing `StrangeTreeInteraction`/`SignInteraction` nodes (a bare `Interaction` instance, not wrapped in a full NPC `Gamepiece`, since it doesn't move). New script `bed_interaction.gd extends Interaction`:
- `_execute()`: `Transition.cover` → `WIPlayerState.check_for_level_up()` → if `true`, show the level-up toast → `Transition.clear`.

### Fortify-the-inn props (new)

Three static `Interaction`-pattern nodes (same structure as `Bed`), one per prop (door, barrel, patron). Each one's script calls `WIPlayerState.record_accomplishment("fortify_<id>")` on interact. The first one encountered (in a fixed order, e.g. the door) also delivers the one-time fortify hint dialogue.

### Climax arena (new)

`defend_inn_combat_arena.tscn` + `defend_inn_combat_arena.gd`, structurally identical to `liscor_combat_arena.tscn`/`.gd` (the MVP's existing arena): `CombatArena` → `Battlers` (`BattlerRoster`) → `PC` (dynamic, built by the unmodified `PCBattlerBuilder`) + `Relc` (static, reused) + `GoblinRaider` (static, new) + `GoblinShaman` (static, new). No new combat-engine code — the arena script is a copy of the existing pattern with different static battlers.

### New enemies: Goblin Raider and Goblin Shaman

Ported from `wandering_inn_game_v1`'s `enemies.json`, following the exact hand-authored `.tres` pattern already used for the Shield Spider (v2 Task 10) — pure data, no new GDScript:
- `goblin_raider_stats.tres` + `goblin_raider_attack.tres` (reuses the existing `AttackBattlerAction` script).
- `goblin_shaman_stats.tres` + `goblin_shaman_stats.tres`'s spell action reuses the existing `RangedBattlerAction` script (the same class Mage's Fire Bolt already uses), themed as a fire spell per v1's `spell_flame_jet` flavor text.

### UI payoff: level-up toast (new)

`CanvasLayer` → `Control` (full-rect, using the now-corrected CanvasLayer-wrapper pattern from the character-creation screen fix) → `Label`, showing class/level/skill-name text only (e.g. `[Fighter Level 2] — unlocked Counter Strike`), auto-fading via a `Tween` after a couple seconds. Never displays raw stat numbers, consistent with the project-wide stats-internal-only rule.

### Tutorial guidance (new, lightweight)

`WIPlayerState.seen_hints: Dictionary` (e.g. `{"combat": false, "fortify": false}`). No new tutorial system — just a couple of extra dialogue/hint lines gated by these flags:
- **Combat hint** — shown once, attached to Erin's threat-framing dialogue (right before pointing the player at Beat 1): explains selecting an action from the combat menu, then a target.
- **Fortify hint** — shown once, in the first fortify prop's dialogue: states there are multiple objects around the inn to prepare, not just this one.

### Dialogue UI polish (known bug, rolled in from v2)

The `Choices` `VBoxContainer` (`src/main.tscn`, under `UI/DialogueLayout`, sibling of `BoxMargins` which holds the dialogue text panel) currently overlaps the text panel it's meant to sit above. Fix its anchor/margin values so it's positioned clearly above `BoxMargins` rather than centered over it. Same category of bug as the character-creation centering issue already diagnosed and fixed in v2 (a Control positioned without accounting for its neighbor's final layout) — expected to be a scene-property correction in `src/main.tscn`, not new logic.

## Data Flow

1. Player talks to Erin → new dialogue branch (added to her existing choice hub) frames the threat, delivers the one-time combat hint.
2. Player travels to Liscor, fights the (reused) Shield Spider. On `CombatEvents.combat_finished(true)`, `WIPlayerState.record_accomplishment("won_melee_combat")`.
3. Player returns to the inn, interacts with the 3 fortify props (first one delivers the one-time fortify hint). Each records its own `fortify_*` key; the 3rd interaction's `record_accomplishment` call also sets `protected_ally_or_inn`.
4. Player interacts with the Bed. `check_for_level_up()` reads both accomplishments, sets `classes["fighter"] = 2`, and the Bed script shows the level-up toast.
5. Player heads back out; the new climax `CombatTrigger` starts `defend_inn_combat_arena.tscn`. `PCBattlerBuilder` reads `classes["fighter"] == 2` and builds the PC with Counter Strike available from the first turn.
6. Victory → return to Erin for the closing dialogue beat.

## Testing

No new test framework — extend the existing `tests/test_wi_scene_contracts.gd` pattern (established during v2's post-merge debugging pass) with:
- Logic assertions: `record_accomplishment`/`check_for_level_up` — `false` with 0 or 1 of the two required accomplishments, `true` with both, and `classes["fighter"]` becomes `2` only in that case.
- Scene-contract assertions: the `Bed` node and all 3 fortify props exist with the expected scripts attached; `defend_inn_combat_arena.tscn` references Goblin Raider, Goblin Shaman, Relc, and PC correctly.

Manual playtest (this project has no input-injection/screenshot tooling available, per the v2 MVP's final review — the same limitation applies here): walk the full flow end to end and confirm the toast appears at the right point, Counter Strike is selectable in the climax fight, and the dialogue choice UI no longer overlaps the text panel.

## Files Touched (expected)

- Modify: `wandering_inn_game_v2/src/rpg/state/wi_player_state.gd` (add `accomplishments`, `seen_hints`, `record_accomplishment`, `check_for_level_up`)
- Modify: `wandering_inn_game_v2/overworld/maps/house/erin_intro.dtl` (new threat-framing branch + combat hint)
- Modify: `wandering_inn_game_v2/src/main.tscn` (add `Bed` + 3 fortify props to House; add new `CombatTrigger` for the climax)
- Create: `wandering_inn_game_v2/overworld/maps/house/bed_interaction.gd`
- Create: `wandering_inn_game_v2/overworld/maps/house/fortify_*.gd` (3 small interaction scripts, or one parameterized script reused 3 times)
- Create: `wandering_inn_game_v2/combat/battlers/goblin_raider/` (stats + attack `.tres`)
- Create: `wandering_inn_game_v2/combat/battlers/goblin_shaman/` (stats + spell `.tres`)
- Create: `wandering_inn_game_v2/overworld/maps/town/battles/defend_inn_combat_arena.tscn` + `.gd`
- Create: `wandering_inn_game_v2/src/rpg/ui/level_up_toast.tscn` + `.gd`
- Modify: `wandering_inn_game_v2/src/main.tscn` (`Choices` `VBoxContainer` anchor/margin fix, under `UI/DialogueLayout`)
- Modify: `wandering_inn_game_v2/tests/test_wi_scene_contracts.gd` (new assertions)
