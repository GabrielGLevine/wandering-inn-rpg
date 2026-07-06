# Wandering Inn RPG M2 — Story Spine Design

## Context

M1 (tactical combat + progression spine, commits `c7515d4..f1c7abd`) is closed: final
whole-branch review clean after one Critical fix, and the loop is human-playtest-confirmed
(2026-07-02). M2 is the north star's other pillar: choice, reactivity, and [Skills] used
outside combat — plus the "real game" foundation (save/load) and the playtest feedback.

Decisions made with the user (2026-07-02, all locked):

1. **M2 focus: story spine** (dialogue with skill checks, quests, save/load, one rich quest)
   after a combat-polish opener. Rejected: combat-depth (another combat-only milestone, no
   narrative pull) and foundations-only sweep. Movement-economy redesign (BG3-style move
   pool + Dash — playtest note 4) deliberately leads M3, since it reshapes the balance
   harness.
2. **Skill checks: possession-gated, visible.** Options gated by skill possession / class
   level / accomplishments; locked options render greyed with the requirement named.
   Matches WI fiction (Skills are capabilities, not dice). Rejected: seeded rolls (less
   WI, doubles authored content), hidden-until-qualified (kills discoverability).
3. **Save model: autosave + one manual slot.** Autosave at beat boundaries; save-anywhere
   single manual slot via a pause menu. Rejected: autosave-only, multi-slot UI.
4. **Content: one rich quest, 3 NPCs** (Erin, Lyonette, Selys — Liscor canon; v1 dialogue
   JSON mineable for voice), across two maps, with a real choice and a non-combat
   skill-checked resolution path. Rejected: minimal proof, full v3-slice parity.
5. **HP numbers are now player-visible (playtest reversal of an M1 styling call).** The
   repo's hard constraint always permitted HP/MP; M1's "no damage numbers" styling proved
   more confusing than immersive in the human playtest. M2 shows HP readouts and damage
   numbers. **Raw STR/DEX/CON/INT/WIS/CHA remain forbidden player-visible — unchanged and
   non-negotiable.**

## Goal

A player can: talk to NPCs in real branching conversations where their [Skills] and class
visibly unlock options, carry a quest across two maps, resolve an obstacle either by
fighting or by a skill-checked non-combat path, make a choice that changes the epilogue,
and save/load anywhere — with every one of those behaviors asserted by headless QA scripts
before any human plays it.

## Part 0 — Combat-polish opener (one task, playtest notes 1–3 + deferrals)

- **AP costs on every action row:** menu renders `Attack ●●`, `[Power Strike] ●●●`,
  `Move ●/step`, `End Turn`.
- **Skill descriptions:** skill-pick mode shows the selected skill's `description` line
  (data already in `skills.json`).
- **HP numbers (decision 5):** each combat square shows `hp/max_hp` text alongside its
  bar; the prose feed includes damage ("Relc strikes Goblin Raider for 7!"); targeting
  shows the target's HP ("Target: Goblin Raider (9/26)"). Sim events already carry the
  numbers — presentation-only change. Update `wandering_inn_game_v4/CLAUDE.md`'s
  constraint wording (HP/damage numbers allowed; raw stats never).
- **Encounter naming:** the two encounters get distinct display names ("Goblin Ambush" /
  "Goblin Warband"); `combat_walkthrough`-style QA gains an `entity_removed` assertion
  for the second encounter (gap found in playtest review).
- Cosmetic deferrals rolled in: toast text wraps instead of clipping at 640px; the field
  world hides while combat is active (spec-drift fix); the `_unhandled_input` guard gets
  parentheses.

## Part 1 — Dialogue system

Pure sim, same discipline as combat:

- **`WIDialogue`** (`src/core/dialogue.gd`, RefCounted, purity rule): runs one
  conversation graph. `_init(graph: Dictionary, ctx: Dictionary, event_sink, )` where
  `ctx` carries the player's known skills, classes, and accomplishments (injected — no
  WIGame reference). API: `current_options() -> Array` (each
  `{text, locked: bool, requirement: String}`), `choose(index) -> bool` (locked refused),
  `finished`, `begin()` (M1 lesson: constructors are silent).
- **Data:** `data/dialogue/<conversation>.json` — node graph:
  `{"start": "n1", "nodes": {"n1": {"speaker": "Erin", "text": "...", "options":
  [{"text": "...", "goto": "n2"}, {"text": "...", "requires": {"skill": "basic_cleaning"},
  "goto": "n3", "effects": [{"accomplishment": "helped_erin"}]}, {"text": "Farewell.",
  "end": true}]}}}`. `requires` supports `skill`, `class: {id: min_level}`, and
  `accomplishment: {id: min_count}`. `effects` supports `accomplishment` (record) and
  `quest` (start). Options without `requires` are always unlocked; a locked option's
  `requirement` string is auto-derived from data display names ("requires [Basic
  Cleaning]").
- **Ownership:** `WIGame.dialogue: WIDialogue` (active-or-null, mirroring `combat`).
  `interact()` on an npc with a `conversation` field starts it (replacing M0's
  single-line `dialogue` array; Erin's line migrates into her graph).
  `WIGame.known_skills()` = innate `player_skills` + `WIProgression.granted_skills`.
- **Events:** `dialogue_started {npc}`, `dialogue_node {speaker, text, options:
  [{text, locked, requirement}]}`, `dialogue_choice {index}`, `dialogue_ended {}` — QA
  asserts lock states straight from the event log.
- **Presentation:** dialogue panel (code-built, message-layer patterns): speaker + text +
  numbered options, up/down + confirm, locked options greyed with requirement text,
  world input gated while active (combat's proven pattern). Emits `ui_dialogue_shown` /
  `ui_dialogue_hidden`.

## Part 2 — Quests (derived, never duplicated)

- **Data:** `data/quests.json` — `{id, title, beats: [{id, description, complete_when:
  {accomplishment_id: min_count}}]}`.
- **`WIQuests`** (pure, static like WIProgression): given quest data + accomplishments,
  derives each started quest's current beat. Quest progress is **a pure function of the
  accomplishment counters** — no parallel progress state (the v2 dead-quest-chain lesson
  made structural). WIGame stores only `started_quests: Array[String]` (set by dialogue
  effects) and re-derives beats after every `record_accomplishment`, emitting
  `quest_started {id}`, `quest_beat_completed {id, beat}`, `quest_completed {id}` (each →
  toast).
- **Journal:** J key on the field toggles a minimal panel listing active quests' current
  beat descriptions. Code-built, ~40 lines.

## Part 3 — Save/load

- **`WISave`** (pure, static): `serialize(game: WIGame) -> Dictionary` /
  `restore(data: Dictionary, ...) -> WIGame` covering: current map, player cell/facing,
  `classes`, `accomplishments`, innate `player_skills`, removed entities, `started_quests`,
  seen-dialogue flags, **world `rng.state`** (determinism survives reload — assert it).
  Versioned envelope (`{"version": 1, "state": {...}}`).
- **Slots:** `user://saves/auto.json` + `user://saves/manual.json`. Autosave after
  `resolve_combat`, `sleep()`, and each `quest_beat_completed`. Manual save/load from a
  pause menu (Esc on the field): Resume / Save / Load / (Load Autosave). `Game` gains
  `save_manual()/load_slot(slot)` orchestration (autoload may touch the filesystem; the
  pure class only builds/consumes Dictionaries).
- Mid-combat and mid-dialogue saving is refused with a toast (M2 simplification; combat
  is short, conversations shorter).

## Part 4 — Maps

- Scene config becomes multi-map: `{"maps": {"inn": {grid, entities}, "street": {...}},
  "start_map": "inn"}`. `WIGame.current_map`; entities/blocking resolve against the
  current map. New entity kind `door: {to_map, to_cell}` — walking into it (blocked cell,
  facing) + interact transitions, emitting `map_changed {map}` (presentation rebuilds;
  autosave triggers).
- Two maps: **The Wandering Inn** (interior: Erin, Lyonette, Bed, table, door out) and
  **Liscor street** (Selys, the goblin obstacle, both goblin encounters move here, door
  back). M0's skeleton content migrates into the inn map; existing QA scripts' routes
  update accordingly (the M0 `skeleton_walkthrough` is superseded by an updated
  inn-scoped walkthrough — keep its beat coverage: move, talk, skill-on-prop, toast).

## Part 5 — Content: "The Errand" (one rich quest)

Canon per the Wandering Inn Wiki; v1 `data/dialogue/*.json` mined for voice, not copied
verbatim. Flow:

1. **Erin (inn):** conversation hub; quest hook — deliver a package to Selys at the
   street. A `[Basic Cleaning]`-gated option (clean the inn's table via dialogue) records
   the existing `cleaned_the_inn` accomplishment — dialogue and world interaction feeding
   the same counter, demonstrably.
2. **Lyonette (inn):** flavor conversation; a class-gated option (`Fighter ≥ 2`) yields a
   tip that unlocks a smoother option with Selys (accomplishment-gated option chaining).
3. **Street obstacle:** goblins block the way to Selys (the renamed "Goblin Warband"
   encounter, which in M2 opens a parley conversation on interact, with "Fight" as one of
   its options). Resolutions: choose the fight option (starts the combat exactly as
   today), **or** a class-gated bypass (`fighter ≥ 1` intimidation line on the parley
   node) — both paths record `street_cleared` and remove the encounter (the bypass via a
   new `remove_entity` dialogue effect emitting the existing `entity_removed`).
4. **Selys (street):** delivery lands; the Lyonette-tip option shortcuts her hesitation.
5. **The choice:** Selys offers a reward — keep it, or send it back to Erin. Two distinct
   accomplishments (`kept_reward` / `gave_reward`), two different epilogue lines at Erin,
   quest completes either way.

New dialogue effect needed by beat 3: `remove_entity: id` (emits the existing
`entity_removed`). Everything else uses existing machinery.

## QA

- `dialogue_walkthrough` — locked option asserted locked (payload), acquire the skill/
  class, re-enter, asserted unlocked, choose it, effect recorded.
- `quest_errand_fight` / `quest_errand_parley` — the full quest via each resolution path;
  both assert `quest_completed`, epilogue-specific accomplishments, and (parley path)
  `entity_removed` without any `combat_started`.
- `save_load_roundtrip` — play to mid-quest, manual save, take divergent actions, load,
  assert exact snapshot equality (incl. rng.state) via `assert_state`; autosave existence
  asserted after a beat completion.
- Combat-polish opener re-verifies `combat_walkthrough`/`level_up_loop` at the canonical
  seed (HP-number changes touch presentation only; if display-name changes alter data,
  re-verify seed 9 still holds and update if not).
- Pure tests: `test_dialogue.gd`, `test_quests.gd`, `test_save.gd` (round-trip on a
  mutated WIGame, version envelope), all `--script`-mode (purity pays again).

## Non-Goals (M2)

- Movement economy redesign (M3 lead), AoE/line/LoS, mage class, new combat mechanics
- Web QA seed threading; respawn systems; multiple save slots; art
- Dialogue portraits/voice/animation; nested subquests; faction/reputation systems

## Files Touched (expected)

- Create: `src/core/dialogue.gd`, `src/core/quests.gd`, `src/core/save.gd`,
  `src/ui/dialogue_panel.gd`, `src/ui/journal.gd`, `src/ui/pause_menu.gd`,
  `data/dialogue/*.json` (erin, lyonette, selys, goblin_parley), `data/quests.json`,
  `tests/test_dialogue.gd`, `test_quests.gd`, `test_save.gd`,
  `qa/scripts/{dialogue_walkthrough, quest_errand_fight, quest_errand_parley,
  save_load_roundtrip}.json`
- Modify: `src/core/wi_game.gd` (dialogue/quests/maps/doors/known_skills/save hooks),
  `src/core/game.gd` (save orchestration), `src/combat/combat_screen.gd` (opener),
  `src/world/world.gd` (map rebuild, journal/pause), `data/skeleton_scene.json` →
  multi-map shape (incl. distinct encounter display names),
  `qa/scripts/*` (route updates), `wandering_inn_game_v4/CLAUDE.md`, `HANDOFF.md`

## Amendment (2026-07-02, overnight delegation — content coherence fix)

Task 8's review found the frozen graphs allowed indefinite reward re-collection (threshold
`requires` never retire options) and a latent deliver-then-exit softlock. Fix: `WIDialogue`
options gain optional `hide_when` (same condition forms as `requires`); hidden options are
omitted from the visible list (`current_options`/`dialogue_node` payload) and `choose()`
indexes the VISIBLE list. Graph patches: Erin's package option hides once `has_package`≥1;
Selys's delivery options hide once `package_delivered`≥1; new Selys hub option "About that
reward." (requires `package_delivered`≥1, hides once `errand_decided`≥1 → goto `delivered`)
restores the decision path on re-entry. Rationale: retiring exhausted options is distinct
from the rejected hidden-until-qualified model — discoverability applies to attainable
options, not spent ones.
