# HANDOFF Archive — v2 MVP / v3 Vertical Slice era (frozen 2026-07-01)

Extracted from HANDOFF.md during the 2026-07-02 cleanup. Everything below concerns the FROZEN `wandering_inn_game_v2/` project (Godot 4.6.2 only) and its v3 vertical slice. Historical reference only — the active project is `wandering_inn_game_v4/`.

## v3 "Defend the Inn" — What Was Built

Spec: `docs/superpowers/specs/2026-07-01-wandering-inn-v3-vertical-slice-design.md` (commit `cedd3ab`).
Plan: `docs/superpowers/plans/2026-07-01-wandering-inn-v3-vertical-slice.md` (commit `6a4c2fb`).
Implementation range: `0bd2a42..fb7e730` on `main` (10 task commits + 1 final-review fix commit + 1 cleanup commit).

Flow: Erin frames a goblin threat (with a one-time combat-hint) → Beat 1 reuses the MVP's Shield Spider fight → Beat 2 is a new non-combat "fortify the inn" beat (3 props: door, barrel, patron; first one shows a one-time fortify hint) → Beat 3 is a new `Bed` interactable that checks accomplishments and levels Fighter 1→2 (unlocking Counter Strike) via a toast, since **Wandering Inn lore has characters level up by sleeping, not mid-combat** (explicit user correction — this replaced an earlier mid-combat-level-up design) → Climax is a new `defend_inn_combat_arena` fight (PC + Relc vs. Goblin Raider + Goblin Shaman) → Resolution returns to Erin for a closing dialogue branch.

Key new files:
- `src/rpg/state/wi_player_state.gd` — added `accomplishments`, `seen_hints`, `record_accomplishment()`, `check_for_level_up()`.
- `overworld/maps/house/bed_interaction.gd`, `fortify_interaction.gd` — sleep beat and fortify props (both need `@tool`, see below).
- `overworld/maps/town/shield_spider_victory_trigger.gd`, `goblin_raid_victory_trigger.gd` — per-encounter victory scripts (see Final-Review Fixes below for why these exist instead of the shared `roaming_combat_trigger.gd`).
- `overworld/maps/house/erin_dialogue_router.gd` — picks Erin's intro vs. climax-closing timeline based on accomplishment state.
- `combat/battlers/goblin_raider/`, `combat/battlers/goblin_shaman/` — new enemy `.tres` content, pure data reusing existing `AttackBattlerAction`/`RangedBattlerAction` scripts.
- `overworld/maps/town/battles/defend_inn_combat_arena.tscn`/`.gd` — climax arena, structurally mirrors `liscor_combat_arena.gd`.
- `src/rpg/ui/level_up_toast.tscn`/`.gd` — CanvasLayer-wrapped fade-out toast, shows class/level/skill name only, never raw stats.

### Final-Review Fixes (important — read if touching triggers/leveling)

The final whole-branch review (after all 10 tasks individually passed their own review) caught 3 cross-task integration bugs that no single task's review could see. Fixed in commit `affb067`, cleaned up in `fb7e730`:

1. **Critical:** `won_melee_combat` was never actually recorded during gameplay — the Shield Spider trigger used the shared `roaming_combat_trigger.gd`, whose victory handler is a no-op `queue_free()`. This meant `check_for_level_up()` could never return true, so the *entire* quest chain (leveling, toast, climax-level PC, Erin's closing dialogue) was unreachable in real play, even though every individual task's unit tests passed (they called `record_accomplishment` directly, masking the gap). Fixed by giving Shield Spider and Goblin Raid their own distinct victory-trigger scripts that each record the correct accomplishment (`won_melee_combat` / `defended_inn`).
2. **Important:** `bed_interaction.gd` and `fortify_interaction.gd` were missing `@tool` — every other `Interaction` subclass in this codebase has it (the base class runs editor-time logic; `@tool` does not inherit to GDScript subclasses). Fixed.
3. **Important:** Erin's climax dialogue was gated on `protected_ally_or_inn` + `fighter==2`, both of which become true at the *sleep* beat — before the climax fight actually happens. A player who slept then walked straight to Erin would get "you already won" dialogue prematurely. Fixed by gating on a new `defended_inn` accomplishment, set only by the climax fight's own victory trigger.

**Lesson for future work in this codebase:** a task's own unit test calling `record_accomplishment()` directly does not prove the *real* gameplay trigger (combat victory, prop interaction, etc.) actually calls it. Scene-contract tests should assert the wiring (does the node's script path reference the right accomplishment-recording script?), not just that the underlying state method works in isolation.

## Playtest Round 1 Fixes (v3, commit `4f5ce89`)

User played through character creation → Erin → Shield Spider fight, then got stuck: no indication of what to do next. Root causes found and fixed:

1. `fortify_interaction.gd`'s one-time hint used `print(hint_text)` — console-only, never visible in-game. Fixed to reuse `level_up_toast.tscn`'s `show_message()` (it's a generic toast despite the filename, not level-up-specific).
2. No dialogue after the Shield Spider win told the player to fortify the inn. Fixed: `erin_dialogue_router.gd` now has a 3-way state (`intro_timeline` → `post_spider_timeline` once `won_melee_combat` is set → `climax_timeline` once `defended_inn` is set), with a new `erin_post_spider.dtl` explicitly naming the door/barrel/patron and confirming the interact key is the same as talking to her.
3. `FortifyDoor`/`FortifyBarrel`/`FortifyPatron`/`Bed` all used Relc's exact sprite (`gobot_gfx.tscn`), looking like 4 extra copies of Relc rather than props. Fixed: reassigned to 4 other already-unused character sprites already declared in `main.tscn` (`knight_gfx`, `thief_gfx`, `generic_character_gfx`, `monk_gfx` respectively) — no thematic significance, just visually distinct from Relc and each other.

Confirmed interact key (Space) is the same for NPCs and props — that part was never broken, just undiscoverable given bug #3.

**Lesson for future work:** review passes (task-level and whole-branch) only checked wiring/logic correctness, not what's actually visible/audible to a player. A hint that "works" (state updates correctly) can still be functionally invisible in play. Worth spot-checking anything player-facing (toasts, dialogue triggers, sprites) by asking "would a first-time player see this and know what it means" rather than only "does the code path execute."

## Debugging Notes (v2 MVP post-merge pass — historical, all resolved and confirmed)

- Character creation initially appeared as a small black rectangle in the window corner.
- Root cause: the main scene was a bare `Control`; in this project/window setup it did not fill the viewport reliably.
- Fix applied: `character_creation.tscn` now uses a `CanvasLayer` root with a full-rect `Root` `Control`; `character_creation.gd` adds UI nodes under `Root`.
- User confirmed the character creation screen now fills the full window and is interactive.
- The UI controls were offset toward the bottom-right because the `VBoxContainer` was centered before its children established its size.
- Fix applied: the container is centered after children are added.
- After clicking Begin, the game originally ran the upstream open-rpg opening cutscene.
- Fix applied: `Field.opening_cutscene` in `src/main.tscn` is now cleared.
- Fixed after Begin spawning into the upstream demo town with old sample NPCs.
- Root causes:
  - Player spawn was still at the old Town coordinate.
  - Erin was placed at `Vector2(200, 150)`, outside the actual House/Inn map coordinate island.
  - Old demo Town NPCs/interactions were still present.
  - Relc and Shield Spider were placed far away at arbitrary coordinates.
- Fix applied:
  - Player now starts in the House/Inn area at `Vector2(824, 104)`.
  - Erin is now in the House/Inn coordinate region at `Vector2(872, 120)`.
  - Old demo Town NPCs/interactions were removed from the initial Town/Liscor area.
  - Relc is now near the House-to-Town arrival at `Vector2(152, 168)`.
  - Shield Spider encounter is now nearby at `Vector2(232, 184)`.
  - The House-to-Grove transition was removed so the old demo forest is no longer part of the intended MVP path.
- Headless smoke check passes with only the known shutdown leak warning.
- New bug batch from manual playtest:
  - Erin was still hard to reach at `Vector2(872, 120)`.
  - Shield Spider encounter was an invisible raw trigger.
  - Shield Spider encounter used generic `CombatTrigger`, so victory did not remove it.
  - Combat UI showed the player Battler node name `PC` instead of the chosen character name.
- Fix applied:
  - Player now starts at `Vector2(824, 104)`, near Erin but not on an immediately crowded row.
  - Erin now occupies the original reachable inn interaction cell at `Vector2(840, 120)`.
  - Shield Spider trigger now uses the existing `roaming_combat_trigger.gd`, which queues itself free after victory. **(Superseded by v3's Final-Review Fixes above — Shield Spider now uses its own `shield_spider_victory_trigger.gd` so it can also record `won_melee_combat`.)**
  - Shield Spider trigger now has a visible `SpiderMarker` sprite and a combat emote popup.
  - Liscor combat arena renames the PC Battler from `WIPlayerState.character_name` before combat UI setup.
- Added regression contract test: `tests/test_wi_scene_contracts.gd`.
- Asset clarity pass:
  - Relc source-of-truth check: Wandering Inn Wiki describes him as a male Drake guardsman with light green scales and a spear-focused combat identity.
  - Relc field asset now uses `gobot_gfx.tscn`, which is a better non-human proxy than the previous human woman/thief sprite.
  - Combat PC now uses `combat/battlers/pc/pc_anim.tscn`, a traveler/humanoid proxy based on the generic field sprite.
  - Combat Relc now uses `combat/battlers/relc/relc_anim.tscn`, a green non-human proxy with a spear marker.
  - Combat Shield Spider now uses `combat/battlers/shield_spider/shield_spider_anim.tscn`, an explicit monster/spider proxy based on the bugcat texture.
- Spawn safety pass:
  - The engine snaps positions to 16x16 cells.
  - Erin is at `Vector2(840, 120)`, cell `(52, 7)`.
  - Player now starts at `Vector2(824, 104)`, cell `(51, 6)`, so the PC and Erin cannot register on the same cell.
  - `tests/test_wi_scene_contracts.gd` now asserts the snapped player/Erin cells differ and have at least one movement step of breathing room.
- Return-to-inn and dialogue-tree pass:
  - Root cause for "can't re-enter the inn": the outbound `HouseToTown` area transition still existed, but the Town/Liscor side had no matching return transition after old demo-town cleanup.
  - Fix applied: added `TownToInn` in `Field/Map/Town/Gamepieces` using the existing `door.tscn` transition at `Vector2(120, 168)`.
  - `TownToInn` sends the player to `Vector2(824, 40)`, one safe step below the House/Inn exit trigger, and restores `Insect Factory.mp3` inn music via `ExtResource("34_xbc6u")`.
  - Root cause for "no dialogue trees": Erin and Relc timelines were linear only.
  - Fix applied: `erin_intro.dtl` and `relc_recruit.dtl` now use the existing Dialogic dash-choice syntax with indented branch dialogue.
  - `tests/test_wi_scene_contracts.gd` now asserts the return transition and both dialogue choice trees exist.
- Dialogue choice cleanup pass:
  - Root cause for "dialog selector covers the panel": the `Choices` `VBoxContainer` was inside `UI/DialogueLayout/BoxMargins`, the same 96px bottom panel that contains the dialogue text.
  - Fix applied: `Choices` now lives directly under `UI/DialogueLayout` and is anchored above the dialogue box with fixed button minimum sizes.
  - Root cause for "can't ask another question": timeline branches fell through to `[end_timeline]`.
  - Fix applied: Erin and Relc now have `label ..._questions` hubs; informational branches `jump` back to the hub, while the exit/commit branch ends normally.
  - `tests/test_wi_scene_contracts.gd` now asserts the choice layout and loop-back labels/jumps.
- v3 Task 9 dialogue-choices readability pass:
  - Choices buttons were still centered awkwardly over the dialogue panel and hard to read.
  - Fix applied: added a `ChoicesBackground` `PanelContainer` behind `Choices`, changed `Choices.alignment` to `1`, re-tightened `offset_top`/`offset_bottom` (`-124.0`).

## Expected Manual Playtest Flow (full v2 + v3 loop — NOT YET CONFIRMED BY A HUMAN)

1. Character creation fills the whole window, controls are centered and usable.
2. Click `Begin` — player starts inside The Wandering Inn near Erin.
3. Talk to Erin: dialogue choices render above the panel and are readable; her new threat-framing branch appears with a one-time combat hint.
4. Travel to Liscor, recruit Relc if not already done, fight the Shield Spider.
5. **Check:** after winning, `won_melee_combat` should now actually be recorded (this was the critical bug fixed in the final review — worth explicitly confirming in this playtest).
6. Return to the inn, interact with the 3 fortify props (door, barrel, patron) — first one shows a one-time fortify hint.
7. Interact with the `Bed` — should show a `[Fighter Level 2] — unlocked Counter Strike` toast (only after both the Shield Spider win and all 3 fortify props are done).
8. Walk into the `GoblinRaidEncounter` trigger near Town — climax fight starts, PC should already be level 2 with Counter Strike selectable from turn one, Relc assists.
9. Win the climax fight, return to Erin — should get the closing "you did it" dialogue branch (should NOT appear before this point, even if you talk to Erin right after leveling up — this was the second final-review bug fixed).
10. No console errors throughout.

## Known Harmless Warnings

- Headless shutdown may report ObjectDB/resources still in use due to pre-existing Dialogic shutdown noise (`WARNING: ObjectDB instances leaked at exit`, `ERROR: 26 resources still in use at exit`) — present on every run, not a regression signal.
- Style warnings about unused signal (`dealt_killing_blow`) / unused parameter (`context` in `reactive_skill_battle_momentum.gd`) are pre-existing and harmless.
- `tests/test_player_state.gd` is known to fail under `--script` mode project-wide (a Godot autoload-resolution limitation in script mode, not a real bug) — don't treat it as a regression.

## Latest Verification (as of commit `fb7e730`)

- `godot --headless --path wandering_inn_game_v2 --script res://tests/test_wi_scene_contracts.gd` → PASS (includes all v3 contract assertions + the final-review fix assertions).
- `godot --headless --path wandering_inn_game_v2 --script res://tests/test_wi_player_state_accomplishments.gd` → PASS.
- `godot --headless --path wandering_inn_game_v2 --script res://tests/test_pc_battler_builder.gd` → PASS.
- `godot --headless --path wandering_inn_game_v2 --script res://tests/test_wi_resources.gd` → PASS.
- `godot --headless --path wandering_inn_game_v2 --script res://tests/verify_content.gd` → PASS.
- `godot --headless --path wandering_inn_game_v2 --quit` → exit 0, no `SCRIPT ERROR`/`Parse Error`.
- MCP `run_project`/`get_debug_output`/`stop_project` live boot → clean (only the two pre-existing style warnings above).
- Final whole-branch review (Opus, diff `0bd2a42..fb7e730`) → **READY TO SHIP** after the one fix cycle described above.

## Files Currently Relevant

- `wandering_inn_game_v2/src/rpg/ui/character_creation.tscn` / `.gd`
- `wandering_inn_game_v2/src/main.tscn`
- `wandering_inn_game_v2/src/rpg/state/wi_player_state.gd`
- `wandering_inn_game_v2/overworld/maps/house/erin_intro.dtl`, `bed_interaction.gd`, `fortify_interaction.gd`, `erin_dialogue_router.gd`
- `wandering_inn_game_v2/overworld/maps/town/relc_recruit.dtl`, `shield_spider_victory_trigger.gd`, `goblin_raid_victory_trigger.gd`, `goblin_raid_climax.dtl`
- `wandering_inn_game_v2/overworld/maps/town/battles/liscor_combat_arena.tscn`, `defend_inn_combat_arena.tscn`/`.gd`
- `wandering_inn_game_v2/src/rpg/ui/level_up_toast.tscn`/`.gd`
- `wandering_inn_game_v2/tests/test_wi_scene_contracts.gd` (regression contract test — extend this when adding new wired-up gameplay content)

## Playtest Round 2 (2026-07-01) — Findings and STRATEGIC PIVOT

User resumed the playtest. Smooth through the Shield Spider encounter; **everything after Erin's prepare-the-inn quest is broken** — no quest interactions work. Console errors:

- `SCRIPT ERROR: Parse Error: Identifier "modulate" not declared in the current scope.` at `res://src/rpg/ui/level_up_toast.gd:8` (surfaced via `character_creation.gd:72`)
- `ERROR: Failed to load script "res://src/rpg/ui/level_up_toast.gd" with error "Parse error".`
- `SCRIPT ERROR: Invalid call. Nonexistent function 'show_message' in base 'CanvasLayer'.` at `fortify_interaction.gd:19`

Root cause: `level_up_toast.gd`'s root/base is `CanvasLayer`, which has no `modulate` property. The script fails to parse at load time, the toast node falls back to a plain `CanvasLayer`, so `show_message()` doesn't exist and every caller (fortify hints, bed level-up toast) crashes. The entire post-spider quest chain is dead from this one line.

Why every automated check missed it: no test loads or instantiates `level_up_toast.gd`; the scene-contract tests read `.tscn`/`.gd` as raw text; headless `--quit` does not load scripts outside the autoload/main-scene path. This is the third instance of the same failure class (passes all checks, broken in real play).

**DECISION (user, 2026-07-01): do NOT fix this incrementally.** Instead of continuing to patch the GDQuest-base game, the project pivots to designing a vision-scale architecture that *natively* supports agent-driven QA and development (input injection, screenshot/state observability, headless-simulatable game logic). `wandering_inn_game_v2/` is frozen as a reference implementation — do not invest further work in it beyond reference/mining. Design/brainstorm for the new architecture is in progress; spec will land in `docs/superpowers/specs/` when written.
