# CLAUDE.md

Guidance for Claude Code when working in `wandering_inn_game/` — the active
Wandering Inn RPG project (M0: agent-QA foundation + walking skeleton).

## What this is

A fresh Godot 4.7 project built QA-first: every feature must be verifiable
by an agent without a human playtest. See
`docs/superpowers/specs/2026-07-01-wandering-inn-v4-agent-qa-foundation-design.md`
for the architecture rationale and north star (BG3-in-Wandering-Inn, team of 1,
[Skills] usable outside combat).

**Product constraints (repo-wide, non-negotiable):** HP readouts and damage
numbers are player-visible (playtest decision, M2); raw STR/DEX/etc. remain
forbidden. Lore canon comes from the Wandering Inn Wiki, not invention.

## Commands

	# Run the game (windowed)
	/usr/local/bin/godot --path wandering_inn_game

	# Import pass — REQUIRED after creating any new .gd file (class_name registration)
	/usr/local/bin/godot --headless --path wandering_inn_game --import

	# Headless smoke check
	/usr/local/bin/godot --headless --path wandering_inn_game --quit

	# Unit tests (pure classes only — SceneTree scripts, run individually)
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sim_core.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_event_log.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_data.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_sim.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_progression.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_dialogue.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_quests.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_save.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_content.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_sprite_registry.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_visuals.gd
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_audio_data.gd

	# Balance harness — 200 seeded AI-vs-AI fights; THE authority on combat data tuning
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd

	# QA scripts isolate user:// by default via HOME=.godot_home/qa-<script>-<pid>.
	# Use --user-dir DIR after the mode to choose a stable isolated HOME explicitly.
	# Combat QA scripts REQUIRE a fixed seed (fights are deterministic per seed; canonical seed: 9)
	# M-FP Q1 (floodplains re-path): combat_walkthrough/level_up_loop/defeat_reload/line_of_sight_denial/
	# combat_move_input now walk inn->floodplains and meet Relc (12,13, relc_intro) BEFORE their
	# ally_requires-gated fight (goblin_encounter_2 or chieftains_raid) so his combat participation
	# matches the pinned seed below — all five held their PRE-EXISTING seed unchanged after the re-path.
	wandering_inn_game/qa/run_qa.sh combat_walkthrough headless --seed=9
	wandering_inn_game/qa/run_qa.sh level_up_loop headless     # ONBOARDING O5: post_tutorial FIXTURE loop — fixture rng 9 overrides --seed (see the seed table row)
	wandering_inn_game/qa/run_qa.sh mage_unlock_loop headless --seed=9        # scroll -> sleep -> [Mage] gained -> fight with mage kit fielded
	wandering_inn_game/qa/run_qa.sh line_of_sight_denial headless --seed=9    # wall-aware ranged AI (goblin_ambush walls); asserts the positive has_los gate -- no "denial" event fires (see Gotchas; archived note: .superpowers/sdd/archive-m2-m3-task-docs/task-8-report.md)
	wandering_inn_game/qa/run_qa.sh lantern_check headless --seed=9           # scroll -> sleep -> [Mage]/light gained -> unlit_lantern skill_used + lit_the_common_room + toast
	wandering_inn_game/qa/run_qa.sh defeat_reload headless --seed=1           # losing chieftains_raid seed; asserts defeat reloads auto slot instead of reset
	wandering_inn_game/qa/run_qa.sh defeat_ally_alive headless      # ONBOARDING O5: near_defeat FIXTURE (rng 3 overrides --seed) — THE canonical proof of the PC-death defeat rule: PC drops while Relc is ALIVE (hp==40 pinned) => instant defeat + auto-slot reload, no game_reset
	wandering_inn_game/qa/run_qa.sh combat_move_input headless --seed=9       # M5 H2 movement-first: arrows step the unit directly, Dash refills pool; ends mid-combat by design
	# M-FP Q2: relc_spar (training_yard) is PC-vs-dummy-dex-2 -- PC's initiative floor (11) always
	# beats the dummies' ceiling (8), so "PC acts first" and the win itself are seed-independent;
	# seed 9 held on first try, no search needed.
	wandering_inn_game/qa/run_qa.sh relc_tutorial headless --seed=9           # negative decline (no combat_started) -> real spar, real-key beat-by-beat tutor_lines, then opacity/persistence teeth + re-talk second combat_started; ends mid-fight by design (combat_move_input precedent)

	# QA playtest scripts (THE verification tool — prefer this over manual reasoning)
	# Full canonical sweep in one command (what CI runs — .github/workflows/ci.yml):
	wandering_inn_game/qa/ci_sweep.sh                           # all 46 at pinned seeds + grep discipline; --only a,b,c to restrict; list MIRRORS the seed table below — keep in sync
	wandering_inn_game/qa/run_qa.sh load_gate headless          # loads every .gd/.tscn/.tres; catches parse/compile errors. NATIVE-ONLY (see below)
	wandering_inn_game/qa/run_qa.sh inn_walkthrough headless   # full inn journey, no screenshots
	wandering_inn_game/qa/run_qa.sh inn_walkthrough windowed   # same + screenshots (a window opens briefly)
	# Output: qa_output/<script>/result.json, events.jsonl, *.png — read the PNGs to see what a player sees

	# Fully headless web QA (zero windows): exports, serves, drives under headless Chromium
	wandering_inn_game/qa/web/run_web_qa.sh inn_walkthrough              # add --skip-export to reuse last build
	wandering_inn_game/qa/web/run_web_qa.sh combat_walkthrough 9         # seed is threaded through window.__WI_QA__ -> JavaScriptBridge (M3 T8)
	# Output: qa_output/web_<script>/result.json + *.png
	# NOTE: load_gate is native-only — DirAccess cannot enumerate the packed res:// in the
	# web export, and the gate fails loud ("scanned zero resources") rather than false-passing.

This is a fresh project with ZERO known-harmless warnings. Any SCRIPT ERROR,
Parse Error, or WARNING in any run is a regression.

## Architecture

- **Sim core (`src/core/wi_game.gd`)** — `WIGame`, a pure RefCounted simulation.
  PURITY RULE: no autoload, Node, or scene-tree references in sim code, ever.
  Dependencies are injected (config Dictionaries, event-sink Callable, seed).
  This keeps the sim testable headless and mass-simulatable.
- **ObservableBus (autoload)** — the single pipe for every player-visible /
  QA-relevant domain event. `emit_domain_event(type, payload)` logs JSONL and
  emits a signal. NEVER print() anything a player should see; put it on the bus
  and let a UI node render it. UI nodes emit `ui_*_rendered` confirmations back
  onto the bus after actually showing something.
- **Game (autoload)** — owns the `WIGame` instance; wires its event sink to the bus.
- **Presentation (`src/world/world.gd`, `src/ui/message_layer.gd`)** — thin:
  forwards input intents to `Game.sim`, renders state from bus events. All UI
  is built in code; content lives in `data/*.json`. No hand-authored .tscn
  beyond the trivial `src/world/world.tscn` root. **FIELD HELD-KEY MOVEMENT**
  (2026-07-05 playtest directive): on a real move-tween's `finished` signal,
  `_on_move_tween_finished` polls `Input.is_action_pressed` and re-issues
  `Game.sim.move_player` through the identical path a fresh press uses if a
  movement action is still held (re-checking the same `_movement_gated` gate
  `_unhandled_input` uses); combat is untouched (combat_screen.gd never calls
  `_move_player_visual`). QA-safe by two independent facts, not just a
  `TestDriver.active()` guard: `_presentation_delay` already collapses the
  tween duration to 0 under TestDriver/headless (so no tween/no `finished`
  signal exists to repeat from), and `test_driver.gd`'s injected press+release
  pair is synchronous with no frame between them (so `is_action_pressed`
  reads false for injected input well before any real tween could complete
  anyway) — see `.superpowers/sdd/fp-handoff/task-heldmove-report.md`.
- **Field hotbar (Three Pillars P2, `src/ui/field_hotbar.gd`)** — the overworld
  twin of combat's action bar. A native-res `CanvasLayer` spawned by
  `main.gd._spawn_ui_layers` (torn down with the other UI layers on world/title
  swap), field-only: hides on `COMBAT_STARTED`, shows on `UI_COMBAT_HIDDEN`
  (same idiom message_layer uses; combat_screen owns its OWN hotbar, the two
  never coexist). REUSES `WIHotbar` (`src/ui/hotbar.gd`) verbatim for the
  UIChrome 52×52 carved slots. Shows the PC's KNOWN field-tagged skills —
  `Game.sim.known_skills()` (innate + class-granted, the journal's derivation)
  filtered by skills.json `field: true`. Renders on `WORLD_READY` (covers cold
  boot + every load/reset, since main respawns the world on GAME_LOADED/RESET)
  and `CLASS_GAINED`/`CLASS_LEVEL_UP`/`CLASS_EVOLVED`; emits
  `UI_FIELD_HOTBAR_RENDERED {slots:int}`. NOTE: `basic_cleaning` is INNATE
  (`skeleton_scene.json` player.skills) and field-tagged, so a classless cold
  start already shows 1 slot ([Basic Cleaning]) — the "0 slots" empty-bar path
  (renders zero-width chrome, still emits the event) is only hypothetical today.
  Field skills carry no `icon` id yet, so slots use WIHotbar's text-label
  fallback (the long bracketed name is cramped in a 52px slot — a future
  wi-art-and-sprites pass should add `icon` ids for the field skills). INPUT
  ARBITRATION: `world.gd._unhandled_input` routes `hotbar_1..9` number keys →
  `_field_hotbar.skill_for_slot(n)` → `Game.sim.use_skill_field(<skill>)` (P1's
  direct-fire dispatch), gated by the SAME `_movement_gated()` as movement/
  interact, so a number key is inert while any panel/dialogue is open or during
  combat. The hotbar owns the slot→skill list (`_field_skills`); world.gd only
  queries it, keeping the key mapping single-sourced with the rendered bar.
- **TestDriver (autoload, `qa/test_driver.gd`)** — inert unless
  `--qa-script=...` is passed after `--`. Executes declarative JSON playtests:
  injects real keyboard events, waits for bus events (optionally matching a
  `payload_contains` subset), screenshots, asserts on `Game.sim.snapshot()`
  (or the live combat via `combat.`-prefixed paths; array segments index),
  drives fights via `combat_autoplay`, writes result.json, exits 0/1.
- **Combat (M1):** `WICombat` (`src/core/combat/wi_combat.gd`) is a pure
  per-encounter tactical sim — 12x8 grid, 4 AP/turn, precomputed initiative,
  seeded RNG, reaction hooks (riposte, momentum). Construction is silent;
  `begin()` starts the fight (owners assign the instance BEFORE calling it —
  events fire synchronously). `WISkillEffects` = active-effect registry;
  `WICombatAI` = deterministic role AI (BFS approach; profiles `melee`
  [default]/`ranged`/`caster`/`inert` — the latter added by onboarding rev
  Task O1 for training dummies: never acts, ends its turn immediately).
  `WIProgression`
  resolves level-ups from `classes.json` ONLY at the sleep beat (canon).
  Presentation: `src/combat/combat_screen.gd` (hotbar-driven as of M5 H1/H2:
  arrows move the active unit DIRECTLY during the player's turn — no Move
  mode — number keys 1-9 activate slots (1 Attack, 2 Dash, 3+ skills), E
  ends turn, Dash is a pool refill only, Tab/Enter targeting; HP bars + AP
  pips + prose feed — HP readouts and damage numbers are player-visible
  (playtest decision, M2); raw STR/DEX/etc. remain forbidden).

- **Story spine (M2):** `WIDialogue` (`src/core/dialogue.gd`) — pure conversation-graph
  walker; possession-gated visible options (`requires`), retired options (`hide_when` —
  option lists are VISIBLE lists, hidden options shift indices); effects are RETURNED to
  `WIGame.dialogue_choose` which applies them (accomplishment/quest/remove_entity/
  start_combat — the last only on conversation-ending options). ctx refreshes per node
  advance as of M4 (see the M4 block below) — the M2-era "snapshot at start_dialogue"
  staleness no longer applies. `WIQuests`
  (`src/core/quests.gd`) — quest progress is a pure FUNCTION of accomplishment counters,
  stored nowhere. `WISave` (`src/core/save.gd`) — versioned full-state round-trip incl.
  `rng.state` AS A STRING (u64 vs JSON doubles); VERSION 4 (`_migrated` COMPOSES version
  steps: v2→v3 adds dormant_encounters; v3→v4 relocates a "street" save's player_cell to
  [1,3] — the W1 32×20 relayout made old street coords softlock-unsafe, M-FP final-review
  catch; v1 REJECTED by design — E3 relayout makes v1 player_cell softlock-unsafe). file I/O lives
  ONLY in the Game autoload (`user://saves/{auto,manual}.json`; autosave on
  combat_resolved[VICTORY-only]/class_level_up/class_gained/class_evolved/
  consolidation_accepted/quest_beat_completed/map_changed). `Game.load_slot` trial-applies
  onto a throwaway sim and swaps the live `sim` in ONLY on success, so a rejected/old-version
  load is a true no-op (pause_menu surfaces a "Could not load save." notice; the combat
  defeat path checks the return and `Game.reset()`s). QA fixture affordances live in
  `test_driver.gd`: top-level `fixture_save` seeds a slot before a run; the `install_fixture`
  step re-seeds a slot mid-run (used by `save_migration` to force a stale auto slot at defeat
  time). Maps are data (`maps` in
  skeleton_scene.json, `door` entities transition). UI: dialogue panel / journal (J) /
  pause menu (Esc: save/load).

- **Character creation (M-ARC §5):** New Game → `char_creation.gd` (native-res,
  title-family UIChrome): race (Human/Drake/Gnoll) → gender (m/f, cosmetic) →
  name (default "Traveler"). Three COSMETIC sim fields — `pc_name`/`pc_race`/
  `pc_gender` (WIGame, additive save, NO version bump, tolerant sanitizers; NO
  mechanical effect, no sim rule branches on them). Flow: title New Game →
  `WIMain.swap_to_char_creation` (deferred) → confirm fires
  `Game.reset({pc_name,pc_race,pc_gender})`, threaded ctor→sim; a load restores
  identity from the save (never sees the creation dict). **QA:** `TestDriver`
  auto-skips creation with the everyman defaults (Human/m/"Traveler") — the
  creation screen is only ever SPAWNED when actually wanted (real play, or a QA
  script that opts in via top-level `creation_ui: true` → `TestDriver.wants_creation_ui()`);
  the default skip is byte-identical to the pre-feature New Game. `char_creation`
  is the one canonical driving the real UI (name typed via TestDriver's new
  `type_text` unicode step). **`pc_name` everywhere:** the combat turn-strip/
  readout name comes from the runtime combatant dict (`_build_player_combatant`
  overrides `display_name` = `pc_name`); field name tags were retired (R3) so
  there is no other player-name render surface. **Sprite variant-key
  indirection (presentation-only, sim purity preserved):** the sim builds a pure
  key `pc_sprite_variant()` = `"pc_<race>_<gender>"`; the TWO bind sites resolve
  it against `WISpriteRegistry` — world.gd `_pc_variant_sprite` (field visual)
  and board_renderer `_combatant_sprite_id` (combat chip) — each degrading to the
  data default `body_a` when a variant's art is unregistered. 6 variants
  (human/drake/gnoll × m/f, all in the same earth-tone traveler outfit) via the
  F2 PixelLab v2 pipeline. **Opener branches by race** (`sleep_veil._opener_lines`):
  Human keeps the otherworlder arrival; Drake/Gnoll get a canon-safe "starting
  over in Liscor" variant (⚑ user taste-review); all 4 lines so the opener-line
  count is race-invariant.

- **Combat depth (M3):** movement economy — `move_pool` (3 free steps/turn) spends
  before AP; `dash()` costs 1 AP for +3 pool, repeatable. Statuses live in a
  per-combatant dict (`slowed`: `pool_penalty` −2 min 1, expires at that unit's next
  `_start_turn`). LoS is a supercover raycast (`has_los` — symmetric, integer-exact,
  corner rule; walls block). Line skills (`line_cells`) are cardinal-only, clip at
  the first wall (inclusive), and hit EVERYTHING in the line — friendly fire is real
  (AI only fires a line that clips ≥2 enemies and 0 allies). MP: `max_mp = 8 + int/2`,
  granted only when the combatant holds any `mp_cost` skill; spells cost AP+MP via
  unified `spend_skill_costs`; sleep restores MP. [Mage] is an EARNED multiclass:
  `gained_by` (`used_magic ≥ 1`, from the dusty-scroll prop) is checked at the sleep
  beat by `WIProgression.check_class_gains` BEFORE level-ups. Kit: `frost_bolt`
  (1 AP + 2 MP, slows), `flame_jet` (2 AP + 4 MP line), `mana_shield` (1:1 MP absorb
  inside `_deduct_hp`), `quick_cast` (first successful spell each turn −1 AP —
  `effective_ap_cost` is what the UI must display). Balance: `tests/sim_combat_batch.gd`
  runs a 2-composition × 9-build × 100-seed matrix; GATED cells bound win-rate
  0.55–0.95, median rounds 3–12 — tune DATA (`combatants.json`/`arenas.json`),
  never the sim. WAVE A2 (user directive 2026-07-04): `goblin_ambush/warrior2`
  is UN-GATED (measured-only, per-cell via the build's `ungated_comps`) — Relc
  is a canon high-level [Spearmaster] escorting the tutorial fight, so a
  near-1.0 win rate on that ally-carried cell is CORRECT DESIGN; its
  design-relevant gates are now `warrior1_tutorial_solo` (target ~0.4–0.5 win)
  and `relc_downed_rate` (target ≤ ~0.15), both printed per harness run.
  Shipped tune (playtest 8+9): relc con 14→20, goblin_raider str 12→10,
  goblin_shaman int 12→10.

  **M7 Task E6 (loadout axis, 2026-07-05):** the harness builds combatants
  DIRECTLY from `combatants.json`, bypassing `WIGame`/`_build_player_combatant`
  entirely (E2 review finding) — equipment was invisible to it until this
  task. `sim_combat_batch.gd`'s `LOADOUT_CELLS` layers a weapon/armor pair
  (`data/items.json` ids) onto an existing composition+build pairing (looked
  up by name, never redefined) and mirrors the shipped injection semantics
  by hand: a local `_weapon_gated_kit` copy (wi_game.gd's version is a
  private instance method reading `self.skills`, out of this task's file
  scope — kept byte-identical, documented as a manual-sync mirror) plus the
  same `damage_mod`/`hp_mod`/`damage_reduction` fields `wi_combat.gd`'s
  constructor already reads unmodified. All 5 cells are measured-only (new
  design axis, same convention as WAVE A2's tutorial cell); the existing
  gated cells above are untouched in construction (no equipment), which is
  what still pins the pre-M7 canonical seeds. 100 seeds/cell:

  | Cell | Comp | Build | Weapon | Armor | win_rate | median | relc_downed |
  |---|---|---|---|---|---|---|---|
  | `warrior2_sword` (control) | goblin_ambush | warrior2 | rusty_sword | — | 0.99 | 3 | 0.15 |
  | `warrior2_spear` (identity fork) | goblin_ambush | warrior2 | relcs_spare_spear | — | 0.99 | 3 | 0.16 |
  | `warrior2_sword_armored` | goblin_ambush | warrior2 | rusty_sword | leather_jerkin | 1.00 | 3 | 0.15 |
  | `warrior1_tutorial_solo_armored` | goblin_ambush | warrior1_tutorial_solo | rusty_sword | leather_jerkin | 0.51 | 5 | n/a (solo) |
  | `warrior2_mage2_gambeson` | chieftains_raid | warrior2_mage2 | rusty_sword | watch_issue_gambeson | 0.96 | 4 | 0.55 |

  **Verdict: no item numbers moved.** `warrior2_sword` reproduces the plain
  `goblin_ambush/warrior2` cell's win-rate/median/rounds-histogram exactly
  (rusty_sword's mods are 0, as expected) — confirms the mirror is faithful.
  `warrior2_spear` reads as a genuine sidegrade, not a strict win/lose:
  `relcs_spare_spear`'s flat +1 damage_mod (applied to every melee hit,
  basic attack included) lands within noise of the sword kit's periodic
  `power_strike` 2× bursts (0.99 vs 0.99, median unchanged) — the "small
  edge" the spec asked for reads as a wash at this ceiling-saturated
  composition, which is correct: `combat_ai.gd`'s `_act_melee` never calls
  `piercing_strikes` by name (documented in `inventory_loop`'s notes above),
  so this is measuring the flat mod alone; the real identity difference is
  the fielded-skill swap itself (`power_strike` in vs `piercing_strikes` in),
  not a win-rate delta this harness can see. Armor reads as comfort, not
  immunity, exactly per spec: `leather_jerkin` nudges the already-near-1.0
  `goblin_ambush` cell by a single win (0.99→1.00) and nudges the SOLO
  tutorial cell from 0.44→0.51 — still inside the 0.4–0.55 design band, so
  early armor does NOT trivialize the "must survive the opening exchanges"
  bar; `watch_issue_gambeson`'s dr 1 is similarly negligible on the
  already-near-ceiling `chieftains_raid/warrior2_mage2` cell (0.95→0.96). No
  tuning frontier to report — the provisional numbers from the spec already
  hit their design targets. Combat-data seed re-check therefore NOT
  triggered (`data/items.json` unchanged): spot-checked `inventory_loop`
  (seed 9) and `combat_walkthrough` (seed 9) both green post-harness-edit.

	# Story-spine QA scripts (per-script canonical seeds!)
	# M-FP Q1: quest_errand_fight now meets Relc before its fight (draw-steel branch);
	# dialogue_walkthrough/quest_errand_parley/save_load_roundtrip/dialogue_hub_loop re-path
	# through floodplains too but do NOT meet Relc first (their fights/bypasses don't field
	# him either way, so the pre-existing seed's roster is unchanged) -- all five held seed 9.
	wandering_inn_game/qa/run_qa.sh dialogue_walkthrough headless --seed=9
	wandering_inn_game/qa/run_qa.sh dialogue_hub_loop headless --seed=9
	wandering_inn_game/qa/run_qa.sh quest_errand_fight headless --seed=9
	wandering_inn_game/qa/run_qa.sh quest_errand_parley headless --seed=9
	wandering_inn_game/qa/run_qa.sh save_load_roundtrip headless --seed=9
	wandering_inn_game/qa/run_qa.sh combat_walkthrough headless --seed=9
	wandering_inn_game/qa/run_qa.sh level_up_loop headless   # ONBOARDING O5: now a post_tutorial FIXTURE loop (title Continue); fixture rng 9 overrides --seed
	wandering_inn_game/qa/run_qa.sh mage_unlock_loop headless --seed=9
	wandering_inn_game/qa/run_qa.sh line_of_sight_denial headless --seed=9
	# M-FP Q2: new script, no combat_started anywhere in its path (parley bypass only for the
	# floodplains crossing) -- seed held for convention consistency, same as inn_walkthrough/title_flow.
	wandering_inn_game/qa/run_qa.sh gate_district_walkthrough headless --seed=9   # enters street for real from the floodplains liscor_gate; y4 transit lane + krshia_stall/guild_door/sewer_grate (exact toasts) + gate Watch guard (dialogue_line) + Selys (26,4); owns the map_changed{street}->audio_played{music_street} assertion combat_walkthrough dropped
	# Playtest-content slice T3: "The Missing Crate" (street, 3 solution paths -- fight/talk/skill)
	wandering_inn_game/qa/run_qa.sh crate_fight headless --seed=9    # FORCE path: fights the new crate_scavengers encounter (2x goblin_raider, goblin_ambush arena, no ally) via combat_autoplay
	wandering_inn_game/qa/run_qa.sh crate_talk headless --seed=9     # WATCH path: persuades the new watch_sergeant to clear crate_scavengers, no combat_started anywhere
	wandering_inn_game/qa/run_qa.sh crate_light headless --seed=9    # SKILL path: [Light]-studies the new cellar_door prop; proves the hidden-until-met report option is absent before studying
	wandering_inn_game/qa/run_qa.sh journal_skills headless --seed=9  # UI wave item 19: journal skills-by-class panel -- pre-first-use NAME ONLY, post-first-use full description, grouped-by-class payload structure

	# M7 Task E5: inventory/equipment loop
	wandering_inn_game/qa/run_qa.sh inventory_loop headless --seed=9  # ONBOARDING O5: chest pickup -> spar -> re-talk Relc for the GIFT node (spear, O3 moved it off the spar-accept) -> sleep Warrior L1 -> equip the spear via the real UI -> cross the goblin_encounter_1 ambush (30,23) proving the weapon-gated kit (piercing_strikes IN, power_strike OUT) -> journal lists both (knowledge != fieldability)

	# M-BEAUTY Task B1: mood grade + phase-clock consumer
	wandering_inn_game/qa/run_qa.sh atmosphere_check headless --seed=9  # world_ready -> ui_mood_applied{inn,day} -> journal open/close under identity grade (UI-ungraded proof) -> 100 real actions (paced back-and-forth moves; Track P1 dusk_at 40->100) -> phase_changed{dusk} + ui_mood_applied{dusk} -> sleep at bed -> phase_changed{day} + ui_mood_applied{inn,day}

	# ONBOARDING rev O5: the onboarding's own end-to-end proof (classless spar -> sleep Warrior L1 -> gift + I-equip the spear -> proximity ambush -> street)
	wandering_inn_game/qa/run_qa.sh tutorial_flow headless --seed=9

	# THREE PILLARS P5: the field-skill LOOP proof (loads the near_tactician fixture via title Continue)
	wandering_inn_game/qa/run_qa.sh field_skills_loop headless --seed=9  # boot: ui_field_hotbar_rendered{slots:1} (innate [Basic Cleaning]) -> number key on faced dirty_table fires P1 byte-parity stream (skill_used{basic_cleaning,dirty_table}+cleaned_the_inn+same toast) -> number key on empty floor = field_ambient fallback -> sleep grants [Tactician] (pre-banked studied_the_cellar) AND [Helper] (the fresh cleaned_the_inn:1) in ONE sleep -> hotbar re-renders slots:1->3 ([Basic Cleaning],[Basic Cooking],[Observe]) -> [Observe] slot(3) on Erin = her exact observe toast + used_skills journal reveal. Fixture rng overrides --seed; no combat in the path.

	# SOCIAL PILLAR S4: the Social Pillar v1 end-to-end proof (loads post_tutorial_street fixture via title Continue)
	# Content Wave C4: "The Wrong Order" (Lyonette Q2, 3 paths). Split by MAP: the loop is inn-local (Lyonette gives AND reports); TALK/FIGHT resolve on the street.
	wandering_inn_game/qa/run_qa.sh wrong_order_loop headless --seed=9   # PRIMARY inn-local: give -> skill-gate NEGATIVE (short_order pre-Helper) -> earn [Helper] -> cook (stretched_the_order, the cauldron skill-save) -> Lyonette SKILL report (resolved+reported, both beats) -> gratitude -> POOL-GROWTH (talk_pool_post active after resolved_wrong_order). No combat; fixture rng.
	wandering_inn_game/qa/run_qa.sh wrong_order_talk headless --seed=9   # TALK path (street): Krshia smooth-over (heard_wrong_order-gated) -> smoothed_with_krshia + persuaded_someone + resolved_wrong_order, NO combat. give/report pre-proven by the loop.
	wandering_inn_game/qa/run_qa.sh wrong_order_fight headless --seed=9  # FIGHT path (street): clear supplier_scavengers (2x goblin_raider, goblin_ambush) via combat_autoplay -> strongarmed_the_supplier + resolved_wrong_order (beat 1 in combat).
	# ECONOMY v1 D4: the coin arc end-to-end (loads economy_loop_start fixture via title Continue). Gold is inn-only earn while Krshia + loot fights are street-only, so the run walks the mandatory floodplains ambush.
	wandering_inn_game/qa/run_qa.sh economy_loop headless --seed=9  # (1) chore earn: clean dirty_table -> "Earned 1 gold" + gold_changed{total:1}; open I -> ui_inventory_shown{gold:1} (D3 coin-line payload). (2) cross the ambush (Relc-allied) = LOOT FIGHT #1 goblin_encounter_1 -> gold 2 @ seed 9 -> total 3. (3) Krshia stall at 3 gold: EVERY buy greys (charm's own "costs 5 gold" lock = affordability-negative surface). (4) LOOT FIGHT #2 crate_scavengers -> gold 2 @ seed 9 -> total 5 (the earn-to-price; its found_the_crate on_victory adds a hub report option, so the 2nd-visit shop-entry is at index 2 not 1). (5) buy the charm: gold_changed{delta:-5,total:0} (fires BEFORE the "Paid 5 gold" toast) + item_gained{traveler_charm}. (6) open I -> ui_inventory_shown{items:3, gold:0} (spend reached the coin line). Loot isolated by --seed=9; fight outcomes by fixture rng_state=9 (both won straightaway).
	wandering_inn_game/qa/run_qa.sh social_loop headless --seed=9  # PHASE A rotating talk pools + per-waking dedup: gate_guard/Selys/Krshia each play ONE pool dialogue_line on first-talk-per-waking (banking chatted_with_<id> + heard_gossip -> 3), and a SECOND Krshia talk opens her real crate graph with NO re-pool (chatted_with_krshia never reaches 2, assert absent). PHASE B persuade watch_sergeant -> persuaded_someone (identity gate); walk home FIGHTS the fixture-active floodplains ambush (Warrior+Relc); sleep at the inn bed (ONLY bed -> return leg mandatory) resolves diplomat.gained_by{persuaded_someone:1, heard_gossip:3} -> class_gained{diplomat} + grants toast "[Diplomat] class gained! — [Charming Smile], [Calming Touch]". PHASE C field hotbar re-renders slots:1->2 ([Charming Smile] is field-tagged, slot 2); hotbar_2 on faced Erin fires [Charming Smile] -> her friendly_line toast + befriended_moments + used_skills journal reveal. Fixture rng governs --seed.

**Canonical QA seed table (M5 F1 close gate; +3 M6 T7 scripts; +1 lantern_check;
M-FP Q1 floodplains re-path — all 18 held their pre-existing seed; M-FP Q2 adds 2 new
re-derivation; playtest-content slice T2 +1 (`work_loop`); T3 +3 (`crate_fight`/
`crate_talk`/`crate_light`, all held seed 9 straightaway); WAVE A2 +1
(`defeat_ally_alive`, seed 11 pinned from the proven level_up_loop casualty scenario);
UI wave +1 (`journal_skills`, seed 9 held straightaway, no combat in the path);
M7 Task E5 +1 (`inventory_loop`, seed 9 held straightaway); M-BEAUTY Task B1 +1
(`atmosphere_check`, seed 9 held straightaway — phase determinism means it
consumes no rng and needs no search); **ONBOARDING O5 +1 (`tutorial_flow`, the
onboarding's own proof, seed 9)**; **THREE PILLARS P5 +1 (`field_skills_loop`,
fixture-based via `near_tactician`, no combat in the path so the fixture rng
governs and seed 9 held straightaway)**; **SOCIAL PILLAR S4 +1 (`social_loop`,
fixture-based via `post_tutorial_street`, so the fixture rng governs — its one
combat, the fixture-active floodplains ambush, was won at fixture-rng straightaway,
no search)**; **Content Wave C1 +1 (`sewers_walkthrough`, fixture-based via
`near_sewers`, fixture rng 9 won its vermin fight straightaway)**; **Content Wave
C3 +3 (`cisterns_fight`/`cisterns_talk`/`cisterns_scout` — Quest 1 three-path
parity, one script per path per the crate precedent since the SKILL stream
descends the sewers and the TALK stream never does, so they cannot share a run;
all fixture-based, seed 9 held straightaway including `cisterns_fight`'s
warrior-L1-solo nest fight)**; **Content Wave C4 +3
(`wrong_order_loop`/`wrong_order_talk`/`wrong_order_fight` — Quest 2 'The Wrong
Order' three-path parity. The paths split by MAP not just by stream: Lyonette is
BOTH giver and report NPC in the INN, so `wrong_order_loop` runs the whole
give→skill-gate-negative→earn-Helper→cook→report→gratitude→**pool-growth** loop
inn-local (the SKILL path + the first talk_pool_post growth); the cross-map TALK
(Krshia, street) and FIGHT-adjacent (supplier_scavengers, street) resolutions get
their own street-start fixtures with the give+report pre-proven by the loop — so
three scripts, like cisterns, not a shared run. All fixture-based, seed 9 held
straightaway including `wrong_order_fight`'s warrior-L1-solo goblin_raider pair)**;
**Economy v1 D4 +1 (`economy_loop` — the coin arc: chore earn → ambush loot →
Krshia broke → crate loot → buy → I-panel coin line. Fixture-based via
`economy_loop_start` (inn, Warrior L1, 0 gold); its rng_state=9 governs the two
fights and both were won straightaway, while the CLI `--seed=9` governs the
isolated loot gold [both encounters drop gold 2, D2's loot_probe verdict]. Two
peek-only shot scripts excluded from the sweep: `d3_inventory_shot` [coin line]
and `d2_shop_shot`)**),
pinned straightaway (no seed search needed unless noted): run these 46 headless
scripts (M-ARC A3 +2: `climax_chain`/`climax_seal`, the climax chain's
summons/seal streams, fixture-based; the party-veto is a unit roster proof, not
a script; **M-ARC A4 +1: `arc_flow`, THE WHOLE-ARC PROOF, fixture `near_act3`**)
with `qa/run_qa.sh <script> headless --seed=<seed>` unless noted. The peek-only scripts (`title_peek`,
`street_peek`) are screenshot utilities, not canonical gate members;
`floodplains_peek` was retired by Q1 (floodplains is now walkably reachable
via `inn_door`, so a teleport-only peek is redundant — `street_peek` picked up
its teleport-to-region idiom for the new 32×20 gate district instead).

**Social Pillar S1–S4 note (rotating talk pools + [Diplomat]):** an NPC with a
non-empty `talk_pool` (data) plays ONE rotating small-talk `dialogue_line` on the
FIRST talk of a waking — index `chatted_with_<id> % pool.size()` (zero rng) — and
banks `chatted_with_<id>` + `heard_gossip` (both opaque social counters), setting
`social_talked[id]`. Every LATER talk that waking falls through to the NPC's exact
prior behavior (conversation graph, or plain `dialogue[0]`); `sleep()` clears
`social_talked` + `entity_first_use` (the shared per-waking first-use dedup dict
that also gates [Observe]'s `observed_things` and [Charming Smile]'s
`befriended_moments`), re-arming the pool next waking. Both dicts are save-persisted
(additive-optional, **no version bump** — VERSION stays 5), so a mid-waking
save/reload does NOT re-arm a spent pool. **Shipped on a 4-NPC subset:** Krshia,
Selys, Pisces, gate_guard (all street). **Erin + Relc pools are DEFERRED to the
morning queue** (S2 measured them as ~28-of-32-script reds — Erin touches 12, Relc
22 — "unacceptably wide"; the 4-NPC subset proves the pillar while keeping the
onboarding+combat spine byte-clean). Their authored-then-reverted canon copy is
preserved verbatim in `.superpowers/sdd/fp-handoff/task-s2-social-report.md` §"Dropped-but-authored"
for whoever closes them. **The 10 scripts that open a pooled NPC as a first-talk-of-waking
were re-pathed (S4):** `dialogue_hub_loop`, `quest_errand_parley`, `quest_errand_fight`,
`save_load_roundtrip`, `gate_district_walkthrough`, `crate_talk`, `crate_fight`,
`crate_light`, `lantern_check`, `mage_unlock_loop` — each first-talk now absorbs the
pool `dialogue_line` (speaker = the NPC's `display_name`: "Krshia"/"Selys"/"Pisces"/"Watch
Guard") via an added `wait_for_event dialogue_line` + a SECOND `interact` for the real
graph. gate_guard is the tricky one: its pool line AND its `dialogue[0]` both carry
display name "Watch Guard", so the pool absorb pins the exact idx-0 pool text
("Gate's clear...") to disambiguate. `crate_light` sleeps TWICE (re-arming pools), so
it re-paths BOTH its Pisces talk (waking 2) and its Krshia talk (waking 3). **[Diplomat]**
(canon class) is a TWO-gate AND earn: `gained_by {persuaded_someone: 1, heard_gossip: 3}`
— persuasion identity + gossip volume; L1 grants `[charming_smile]` (field, warmer-NPC
reaction, `friendly_line` per NPC) + `[calming_touch]` (combat, re-flavored `slowed`).
`social_loop` is the whole-pillar proof.

**M-FP Q1 topology note:** `inn_door` (inn `[15,3]`) now targets `floodplains`
`(7,6)` (was `street`); `floodplains_inn_door` `(7,5)` returns to inn `[14,3]`;
`street_door` (now the 32×20 Liscor gate district) targets `floodplains`
`(31,24)`; `liscor_gate` `(31,25)` on floodplains targets `street` `[1,3]`.
`goblin_encounter_1` `(21,12)`, `goblin_encounter_2` `(28,18)`, and
`chieftains_raid` `(31,7)` all migrated from `street` onto `floodplains` and
all three now carry `ally_requires: {met_relc: 1}` — Relc (npc, floodplains
`(12,13)`, `relc_intro` conversation) fields as an ally in that fight ONLY
after the player has talked to him and banked the `met_relc` accomplishment;
an unmet fight still starts, just short one ally. Scripts whose fight is
sensitive to that ally slot (reaction triggers, riposte timing, a losing
seed, a LoS-specific arena, or asserted arena/turn-order state) add a
meet-Relc prologue before traveling to the fight; scripts whose fight only
asserts a generic `victory: true` do not (see the two lists above for exactly
which). `relc_spar` `(13,12)` and its `dummies_note` conversation are shipped
(C1); Q2 landed the two new QA scripts that cover the gate district and the
spar (see the table below) — `gate_district_walkthrough` and `relc_tutorial`.

**Onboarding rev Task O2 (proximity trigger, spec §3):** `move_player`
(`wi_game.gd`) gained `_check_trigger_radius()` — after a successful move, any
`encounter` entity on the current map carrying `trigger_radius: N` fires
`start_combat` the instant the player lands within N cells (Chebyshev). It is
a pure alternate call site into `start_combat` (dormant-respawner refusal and
`ally_requires` roster gating are unchanged, both live inside `start_combat`
itself); it fires start_combat DIRECTLY, skipping any `conversation` the
entity might carry — no shipped encounter combines the two, so this is a
documented precedence, not an active regression. Only `door` transitions
(`transition()`/`bind_map_silent()`, i.e. door travel, QA `teleport`, and
save/load restore) never call this — a QA teleport or a load can never
ambush the player. `goblin_encounter_1` RELOCATED from `(21,12)` to
`(30,23)` and gained `trigger_radius: 2`. **The corridor-free property comes
from the MERGED `walls.segments` blocked set, not a lone "y=25 wall" (O5 doc
correction, per O4's BFS over the true blocked geometry):** the floodplains
blocking is `walls.segments` — the SE wall row (which leaves x=31,
`liscor_gate`'s cell, as the only column through the bottom) PLUS the
fishing-pond rect (x7-13, y17-21) — plus the `chieftains_raid`-occupied col 31
above y8; together these make `(31,24)` the sole open cell from which the gate
can be reached, and that cell sits inside the new Chebyshev-2 zone: a BFS over
the true merged blocked set with the zone's cells removed proves `(31,24)`
becomes unreachable from the `(7,6)` entry — no path to `liscor_gate` avoids
the ambush (conclusion unchanged; full proof + BFS-derived return lanes:
`.superpowers/sdd/fp-handoff/task-o2-report.md` and `task-o4-report.md`).
`goblin_encounter_2` (28,18) and `chieftains_raid` (31,7) are unaffected
(interact-only, no `trigger_radius`). **CLOSED by Task O5's re-path window
(2026-07-05):** every canonical script that crossed floodplains → `liscor_gate`
was re-pathed through the real cold-start arc (spar → Warrior → cross the
ambush); the disclosure red set is now fully green (see the O5 block below the
seed table).

**Onboarding rev Task O4 (Pisces + grants-listing toasts, spec §4/§9):**
[Mage] is now EARNED FROM PISCES, not the retired Dusty Scroll.
- **Pisces Jealnv** (Human [Necromancer], canon) is a new npc at the street
  Guild frontage `(30,4)` (east of `guild_door` (28,3), clear of
  `gate_district_walkthrough`'s forecourt approach cells). Sprite: `citizen_f`
  stand-in with a pale cool tint `[0.74,0.82,0.96]` to read as a necromancer
  distinct from Selys's warm green (VISUAL-LOG — a future art pass should give
  him a real portrait/sprite). Conversation `data/dialogue/pisces_magic.json`:
  a short magic tutorial (mana/MP → casting vs swinging → why [Light] is
  first) banking `learned_magic_from_pisces` at the closing option; re-talk
  variants gate on `met_pisces` (banked on first lesson) and
  `learned_magic_from_pisces`. `mage.gained_by` → `{accomplishment:
  {learned_magic_from_pisces: 1}}`.
- **Dusty Scroll RETIRED to flavor:** `dusty_scroll` (inn `(12,7)`) now banks
  `read_dusty_scroll` (a gate-referenced-nowhere flavor accomplishment) and a
  new hint toast; it no longer banks `used_magic` and grants no class.
  `used_magic` is now a dead symbol (its test/fixture uses were repointed to
  `learned_magic_from_pisces` or `read_dusty_scroll`).
- **Grants-listing class_gained toast (spec §4/§9):** `wi_game.gd`'s
  `_class_gained_toast(class_id)` lists the class's level-1 grants —
  `"[Mage] class gained! — [Frost Bolt], [Quick Cast], [Light]"` (display
  names from skills.json, already bracketed; no numbers). Applies to EVERY
  class_gained (Warrior/Helper/Mage). **This is a global toast-format change:**
  every exact-text assertion of the old `"[X] class gained!"` moved to the new
  form — `test_sim_core.gd` (mage), `work_loop.json` (`"[Helper] class gained!
  — [Basic Cooking]"`), and the three O4 scripts. `class_level_up` toasts
  already list grants via `— unlocked …` (unchanged; consistent bracketing
  because display names carry the brackets).
- **The three O4-owned scripts (`mage_unlock_loop`/`lantern_check`/
  `crate_light`) are GREEN again at seed 9** under the current tree (classless
  start + live ambush): they encode the honest new-game flow (meet Relc → spar
  → sleep Warrior → cross the ambush FIGHTING it → Pisces → sleep [Mage]). The
  ambush cross is DELIBERATE and unavoidable (O2's corridor-free gate); all
  ambush/goblin_encounter_2 fights survive+win at seed 9. `crate_light` crosses
  the ambush twice (the mage sleep re-arms it) — both won. Floodplains lanes
  route around the `walls.segments` fishing-pond (x7-13, y17-21) and the
  `chieftains_raid`-occupied col 31; full cell derivation in
  `.superpowers/sdd/fp-handoff/task-o4-report.md`.

**Onboarding rev Task O5 — THE RE-PATH WINDOW (closed 2026-07-05).** The
classless start (O1) + relocated proximity ambush (O2) + gift-node move (O3) +
Pisces/grants toast (O4) reddened 19 canonical scripts; O5 re-pathed all of
them and added `tutorial_flow`. Full sweep (31 scripts) + 13 units + load_gate +
smoke are green, zero SCRIPT ERROR/Parse Error/WARNING. Routing model:
- **ROUTE-W (walk the real cold-start arc)** — most scripts: classless spar vs
  the inert dummies → sleep → Warrior L1 → cross the mandatory floodplains
  proximity ambush (warrior kit + Relc ally) → street. The reusable prologue is
  authored in `combat_walkthrough.json` (part-1 + part-2, seed 9) and reused
  verbatim by the street-crossing scripts (the story/quest/gate scripts prepend
  it; the old `goblin_parley` "Stand aside" bypass is DEAD — the ambush is
  corridor-free). `tutorial_flow` additionally proves the gift node + `I`-equip
  the spear + the part-2 beats.
- **ROUTE-F (fixture start)** — deep-loop / determinism-sensitive combat
  scripts LOAD a fixture via title Continue (fixture `apply()` sets
  `rng.state = int(rng_state)`, OVERRIDING `--seed` for all post-load draws, so
  their combat determinism flows from the fixture rng_state, not the CLI seed —
  same contract as `near_*`). **New fixtures:** `post_tutorial` (v5; warrior L1,
  met/sparred/given_spear, rusty_sword equipped + spear in pack, floodplains
  (7,6), rng 9) — consumed by `level_up_loop` (its outcome-defining consumer,
  rng tuned for the fight-2 riposte) and `combat_move_input` (rng-agnostic after
  its re-route); `post_tutorial_street` (same, at street (1,3), rng 9) —
  consumed by `crate_talk`/`crate_fight` (skips the ambush so `crate_talk` stays
  genuinely combat-free); `near_defeat` (warrior L1, floodplains, rng **3**) —
  `defeat_ally_alive`, tuned so the level_up_loop-style route's fight-2 drops
  the PC while Relc survives. **KEY determinism fact:** a straight-to-fight
  fixture is rng-INSENSITIVE (no pre-fight combat advances the rng, and the
  chieftains fight structurally protects the back-line PC — Relc tanks and
  dies); the fight only varies with the fixture rng once a *prior* combat has
  advanced the stream (why `defeat_ally_alive` keeps fight1+sleep before
  fight2).
- **Pin-only fixes** (classless-safe, no re-path): `journal_skills` (boot
  payload `["Innate"]`/1, was `["Innate","Warrior"]`/5), `save_migration` +
  `consolidation_reload` (fresh-boot `classes == {}`), `line_of_sight_denial` +
  `defeat_reload` (hotbar `slots: 3`, was 4 — their subject is orthogonal to the
  PC kit; the classless PC + Relc still wins/loses those fights).
- `relc_tutorial` REWRITE: O3's new meet-node gift option shifted the post-spar
  indices, so its old "second spar" re-talk now walks the **gift node** instead
  (spear + `given_spear_by_relc` + the "press I" teaching); the skippable
  negative + full part-1 beats + opacity teeth are unchanged.

| script | seed | notes |
|---|---|---|
| `load_gate` | none | native-only resource compile/load gate; no seed needed |
| `tutorial_flow` | 9 | **ONBOARDING O5 (new canonical, the onboarding's own proof).** Boot CLASSLESS (hotbar 3 slots at the spar) → meet Relc → accept spar → part-1 beats by real keys against the shipped `training_yard` tutor_lines (opening/first_step/pool_empty/dash/aim/first_blood/watch/wrap — wrap's NEW O3 line) → `item_gained` ABSENT until the gift → sleep → `class_gained{warrior}` + the O4 grants toast → re-talk Relc for the GIFT node (spear + given_spear_by_relc + "press I" teaching) → press I + equip the spear (`item_equipped`) → walk the road, the O2 proximity ambush fires with NO interact (`real_ones` beat) → warrior+spear kit (4 slots) + Relc win it (`road_clear`) → gate onto the street. Part-2 skill beats (skill_aim/skill_hit) are UI-manual-only (autoplay with a spear never fires a skill, per `inventory_loop`'s finding) — the identical part-1 `aim` beat covers the targeting UI. Seed 9, held straightaway. |
| `inn_walkthrough` | 9 | full inn journey, no screenshots in headless. M-FP Q1: unaffected — never exits the inn, verified green as-is. **M-BEAUTY R3:** the `ui_world_labels_rendered` count assert (retired event) removed; `ui_entities_rendered` count assert (sprites:12) untouched and still passes (entity count itself didn't change) |
| `dialogue_walkthrough` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** Erin/Selys story path. M-FP Q1: re-paths inn→floodplains→liscor_gate→street; fights `goblin_encounter_2` WITHOUT meeting Relc first (asserts only generic `victory: true`, roster-neutral either way) |
| `dialogue_hub_loop` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** conversation hub loop-backs and decision-invalidation hide_when sweep. M-FP Q1: re-paths inn→floodplains→liscor_gate→street; takes the parley bypass (no combat), no Relc prologue needed |
| `quest_errand_fight` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** errand path with goblin fight. M-FP Q1: re-paths inn→floodplains (meet Relc at (12,13) before `goblin_encounter_2`)→liscor_gate→street→Selys, then back via the same doors to the inn epilogue |
| `quest_errand_parley` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** errand path through parley. M-FP Q1: re-paths inn→floodplains→liscor_gate→street→Selys and back; parley bypass, no Relc prologue needed |
| `save_load_roundtrip` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** save/load persistence path. M-FP Q1: re-paths inn→floodplains→liscor_gate→street→Selys (parley bypass, stays on street through the save/load beats — no Relc prologue needed) |
| `combat_walkthrough` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** unchanged from M2 — still holds post-rebalance. M-FP Q1: now ALSO exercises the `ally_requires` roster gate end-to-end — opens with a roster NEGATIVE fight (fresh boot straight to `goblin_encounter_1` (21,12), `met_relc` unset, asserts 3 combatants/no `relc` `turn_started`), then meets Relc (12,13, `relc_intro`), then the original `goblin_encounter_2` fight as a roster POSITIVE (asserts `combat.combatants.relc.side == "player"` + a `relc` `turn_started`); `accomplishments.won_combat` is now 2 (both fights), not 1. Dropped the `music_street` audio assertion — the walkthrough no longer visits `street` (fight is on floodplains); Q2's `gate_district_walkthrough` picked that assertion up (see its row below) when it visits street for real. **M-BEAUTY R3:** both `ui_world_labels_rendered` count asserts (retired event) removed; the `assert_world_labels_in_view`{context:combat} geometry probe KEPT (still valid — the surviving HP/MP stats panel still needs to project on-screen correctly, unrelated mechanism from the retired count event) |
| `level_up_loop` | 9 (fixture) | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** **Now a `post_tutorial` FIXTURE loop** (title Continue). Fixture rng (9) overrides --seed. fight 2 swapped from `goblin_encounter_1` to `chieftains_raid` — see Gotchas. M-FP Q1: re-paths inn→floodplains, meets Relc (12,13) before fight 1 (`goblin_encounter_2`) since fight 2 (`chieftains_raid`) also gates on him; returns to inn to sleep/level, then back to floodplains for fight 2 — met_relc persists, no second meet needed. WAVE A2 §7: re-derived from seed 11 to 12 — the post-D4 "pc death = immediate defeat" change turned seed 11's fight 2 from a win (pc goes down mid-fight, relc alive, relc mops up the last enemy under the old team-wipe rule) into a defeat under the new pc-death rule; seed 12 wins fight 2 outright (pc survives) and still fires `reaction_triggered{counter_strike}` (step 67's assert), so it holds both roles the seed needs |
| `mage_unlock_loop` | 9 | **Onboarding rev O4 (full rewrite):** [Mage] now comes from PISCES, not the retired Dusty Scroll — so this walks the real cold-start arc: meet Relc→spar→sleep (Warrior L1)→cross the floodplains proximity ambush (`goblin_encounter_1`, warrior kit + Relc ally, fight 1)→Liscor gate→street→Pisces (`pisces_magic`, banks `learned_magic_from_pisces`)→back to the inn→sleep ([Mage] gained, O4 grants-listing toast `"[Mage] class gained! — [Frost Bolt], [Quick Cast], [Light]"`)→`goblin_encounter_2` with the mage kit fielded (asserts `combat.combatants.pc.skills` **contains** `[frost_bolt, quick_cast, light]` — replaces the old mage-only `slots==5`/`max_mp==12` pins, which no longer hold now the honest route also carries Warrior). Also pins the O4 Warrior gain toast. Seed 9 survives+wins BOTH fights. Pond (`walls.segments` x7-13 y17-21), SE wall (y=25) and `chieftains_raid`-occupied col 31 shape the floodplains return lane — see task-o4-report.md for the BFS-derived cells |
| `line_of_sight_denial` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** see Gotchas for the arena substitution. M-FP Q1: re-paths inn→floodplains, meets Relc (12,13) before `goblin_encounter_2` (the `flame_bolt`/no-`no_los` assertions are arena-internal and unaffected by the extra ally) |
| `defeat_reload` | 1 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M4 T4 losing `chieftains_raid` seed; verifies defeat loads `auto` and does not emit `game_reset`. M-FP Q1: re-paths inn→floodplains, meets Relc (12,13) before the fight (chieftains_raid moved street→floodplains); final `current_map` assertion is now `floodplains`, not `street`. Note: in this seed Relc dies BEFORE the PC, so it proves the reload flow, not the pc-death-with-living-ally rule — that's `defeat_ally_alive`'s job |
| `defeat_ally_alive` | 3 (fixture) | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** **Now the `near_defeat` FIXTURE** (warrior L1 -> fight1 gob2 -> sleep -> W2 -> fight2 chieftains LOST with the PC dropping while Relc survives at full 40 HP; fixture rng 3 overrides --seed; relc.hp==40 re-pinned). WAVE A2 (directive 7) — **THE canonical proof of the PC-death defeat rule** through the real input/AI/UI path. Route is `level_up_loop.json` verbatim through fight 2's `combat_autoplay` (seed 11 = level_up_loop's OLD seed, whose fight 2 is the proven scenario: chieftains_raid downs the PC at round 3 while Relc stands at 24/40 HP and the chieftain at 4 HP — a WIN under the pre-A2 team-wipe rule, Relc's turn was next). Asserts `combat_finished`{victory:false, draw:false}, snapshot `combat.combatants.pc.alive == false` + `relc.alive == true` + `relc.hp == 24` (exact pin — deterministic per seed; the tooth is hp > 0 at defeat) BEFORE confirming the banner, then the defeat_reload idiom: confirm → `ui_combat_hidden` → `game_loaded` → `current_map == floodplains` → `assert_event_absent game_reset`. If a combat-data change moves this seed, re-derive by searching for a fight-2 seed where the PC drops while Relc lives (the WAVE A2 report documents the method) |
| `title_flow` | 9 | M5 S3; no combat in the path, seed held for convention consistency. M-FP Q1: `inn_door` now targets `floodplains` — the mid-script `map_changed` wait and the final `current_map` assertion both changed from `street` to `floodplains` (this one WAS affected by the door retarget, despite reading as topology-agnostic; confirmed red-then-green, not assumed) |
| `combat_move_input` | 9 (fixture) | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** **Now a `post_tutorial` FIXTURE** (warrior+sword so the [Power Strike] slot-info fires); rng-agnostic manual moves re-routed NW around Relc's (2,4) spawn. M5 H2; drives movement-first arrows + Dash refill with real key injection, then ENDS MID-COMBAT (injected moves diverge from the canonical autoplay trajectory, so it never asserts an outcome). M-FP Q1: route is now inn→floodplains only (meets Relc at (12,13) first, then `goblin_encounter_2`, no separate street leg); in-arena cells/assertions are unchanged. UI wave item 15 (Dash confirm gate): pressing `hotbar_2` now only ARMS the gate — added an explicit confirm-gate proof (`assert_event_absent dashed` + AP/pool unchanged + a `01b_dash_confirm_gate` screenshot) between the press and the pre-existing `dashed` wait, which now follows a `confirm` press instead of the `hotbar_2` press directly |
| `class_evolution_loop` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M6 T7; `near_evolution` fixture → organic respawn-encounter grind → sleep → `class_evolved` + evolved kit fielded. M-FP Q1: fight1 (`goblin_encounter_2`)/fight2+fight3 (`goblin_encounter_1`, repeatable) are all on floodplains now; meets Relc (12,13) once before fight1, banked for all three fights across the sleep/evolve beat |
| `consolidation_flow` | 9 | M6 T7/T8; `near_consolidation` fixture → offer → decline → re-offer → accept → `consolidation_accepted`, [Spellsword] at merged level, merged kit fielded. Accept/decline driven through the real UI prompt (T8): cancel = decline, confirm on the default row = accept; asserts `ui_consolidation_prompt_rendered`/`_hidden`. M-FP Q1: post-accept kit-check fight (`goblin_encounter_2`) is on floodplains; meets Relc (12,13) first |
| `save_migration` | 1 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M6 T7; v2→v3 `_migrated` proof + v1 pause-load rejection (safe no-op + "Could not load save." notice) + ⟦I12⟧ defeat-reload with a stale v1 `auto` slot → `Game.reset()`. Seed 1 is defeat_reload's proven losing chieftains_raid seed (navigation mirrored); `install_fixture` re-seeds v1 into `auto` after the pre-fight autosave. M-FP Q1: the `install_fixture` still lands right after the floodplains-arrival autosave; meeting Relc (12,13) in between fires no autosave of its own, so the v1 overwrite survives intact to defeat time |
| `consolidation_reload` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M6 T8; pause-Loads the `pending_offer` fixture (a save taken mid-offer) and asserts the consolidation prompt RECONSTRUCTS on load (`ui_consolidation_prompt_rendered`) then answers it → [Spellsword]. Guards the persisted `pending_consolidation` field against a future autosave-while-pending change (softlock otherwise). M-FP Q1: unaffected — never leaves the inn, verified green as-is |
| `generalist_loop` | 9 | M6 F1 (whole-branch-review fix); `near_generalist` fixture (mage 10, 7/7 ice/fire split) → sleep fires the Generalist path (`skill_unlocked` ice_shard/flare_burst + balanced-mastery toast, `generalist_classes` gains mage) → a chieftains_raid fight asserts the PC combat kit CONTAINS both balanced grants (granted_skills folds a generalist class's `evolution.balanced_grants`; combat snapshot exposes `skills`). M-FP Q1: fight is on floodplains now; meets Relc (12,13) first |
| `lantern_check` | 9 | **Onboarding rev O4 (full rewrite):** was a two-move scroll→sleep prologue; NOW inherits mage_unlock_loop's honest Pisces arc verbatim (meet Relc→spar→sleep Warrior→cross ambush fight 1→Pisces→sleep [Mage]/[Light]) because [Light] is folded into the mage L1 grant and mage is Pisces-earned. THEN the ORIGINAL payoff, unchanged: `unlit_lantern` interact asserts `skill_used`{skill:light,target:unlit_lantern} + `accomplishment_recorded`{id:lit_the_common_room} + exact `toast` "[Light] — A steady white orb…" + `ui_toast_rendered`. Ends in the inn (no floodplains re-cross). One combat now (the ambush), seed 9 |
| `gate_district_walkthrough` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M-FP Q2 (D1-4, new script). No combat in the path (the floodplains-crossing leg takes the `goblin_parley` "Stand aside" bypass, verbatim from `quest_errand_parley.json`'s proven route) — seed held for convention consistency. Enters `street` for real via `liscor_gate` (not a teleport); asserts `ui_map_rendered`{map:street, floor_cells:640, blocked_cells:106} — `blocked_cells` is the SIM's runtime blocked set, the static 32×20 `blocked` list (56) UNION the wall `segments` expansion (32+2+16=50), not just the static list; asserts `map_changed`{street}→`audio_played`{music_street} (the carried-minor `combat_walkthrough` dropped when its route left street for the floodplains — this script now owns that evidence). Walks the y4 transit lane (with the north/south detours the market stalls and the Guild forecourt force) and interacts `krshia_stall`/`sewer_grate`/`guild_door` (each: `accomplishment_recorded` + exact `toast` text + `ui_toast_rendered`), the gate `gate_guard` (a plain npc with no conversation graph — interact fires `dialogue_line` + `ui_dialogue_rendered` directly, no `dialogue_started`/`ui_dialogue_shown`), and Selys at (26,4) (`dialogue_started`{selys_delivery} + `ui_dialogue_shown`) |
| `relc_tutorial` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M-FP Q2 (D2-8, new script). No seed search needed: PC dex 10 (+d6, floor 11) always outranks both training-dummy dex 2 (+d6, ceiling 8), so "PC acts first" is seed-independent, and 21 HP dummies vs the PC's real kit make the win itself seed-robust too. Covers all nine D2-8 elements: the skippable NEGATIVE first (`meet`→`banter`→`spar_offer`, decline via "Another time." — asserts `combat_started` absent + `met_relc` banked), then a real re-talk into the actual spar; drives the beat-id `ui_tutor_line_rendered` sequence with real keys against the SHIPPED `training_yard` `tutor_lines` (order: opening→first_step→pool_empty→dash→aim→first_blood→watch→wrap, confirmed by trace); **the opacity + persistence teeth**: `accomplishments.sparred_with_relc == 1`, `accomplishment_recorded`{won_combat}/{melee_hit} both absent (belt-and-braces `trivial:true` on the entity AND the arena skips `_bank_action_tally` entirely), no `class_level_up`/`class_gained`, no `entity_removed`{relc_spar} (persistent:true); re-talk after victory fires a SECOND `combat_started` — ends mid-fight there by design (`combat_move_input` precedent: manual/injected beats diverge from a canonical autoplay trajectory). Windowed pass flagged a real issue — see the Gotchas entry below (D2-7 #6). UI wave item 15: the `hotbar_2` press (dash beat) needed one added `confirm` press before the `dashed` wait, same confirm-gate change as `combat_move_input` |
| `work_loop` | 9 | Playtest-content slice T2 (new script). Inn work-loop, Helper leg: dirty_table clean ×2 (`cleaned_the_inn` 1,2) → new `serving_tray` prop interact ×1 (`delivered_item` 1) → new `hungry_patron` npc (`patron_serving` conversation, hub+loop-back) serve ×2 across two conversation visits (`served_customer` 1,2) → sleep at `bed` → `class_gained`{helper} (fires at `cleaned_the_inn`≥1) + exact toast `"[Helper] class gained!"` → snapshot `classes.helper==1` → new `stew_pot` prop interact BEFORE `basic_cooking` is known → `skill_unknown` negative → second chore burst (clean ×2 more, serve ×1 more — `cleaned_the_inn` reaches 4, crossing the L2 `requires_any` threshold of 3) → sleep → `class_level_up`{helper,2} batched toast `"[Helper Level 2]"`. **Harness gotcha (new this script):** the very FIRST autosave's `"Autosaved. (Esc — save/load anytime)"` toast is a NESTED emission (`Game`'s `class_gained` listener calls `save_auto()` synchronously, which re-enters `emit_domain_event` for its own toast) that lands in `test_driver`'s `_events_seen` BEFORE the outer `class_gained` event that triggered it — a cursor-gated `wait_for_event` for that exact text will never match forward of the `class_gained` match and hangs to timeout; use `assert_event_logged` (whole-run scan) for that one assertion instead, same as any other autosave-adjacent toast text check. Inn now carries 10 entities (11 sprites incl. player) — **`inn_walkthrough`'s `ui_entities_rendered`/`ui_world_labels_rendered` count assertions (sprites/count: 8) are a known, unavoidable regression from this addition** (entity COUNT, not cell placement — no path broke) still needing a controller-side count-only edit to that canonical script (T2 report flags it; T2's file scope did not include `qa/scripts/inn_walkthrough.json`). **M7 Task E5 addition:** an `inn_chest` pickup beat (`item_gained`/toast/`ui_toast_rendered` for `leather_jerkin`) is inserted at the very start, before Beat 0 — the detour ([2,3]→down3→left1→down1→[1,7]→interact) round-trips back to the exact spawn cell (2,3) via the reverse moves, so every existing beat below is untouched; seed 9 re-verified green, no re-derivation needed (pickup doesn't autosave, so no toast-queue race like `inventory_loop`'s Relc-gift beat). **M-BEAUTY R3 fix (new toast-queue race, this script's first pickup is also the game's FIRST-EVER `item_gained`):** `message_layer.gd`'s new one-time "Press I — your pack." hint (onboarding spec §9 interim) queues right behind this script's `inn_chest` pickup toast — an UNQUALIFIED `wait_for_event ui_toast_rendered` right after (previously used for the `00b_chest_pickup` screenshot's wait) would consume the WRONG toast for every later unqualified wait in the script (confirmed: `00b_stew_pot_locked_toast`/`01_clean_toast` screenshots showed the hint/stew-pot text respectively, one slot late, before the fix). Fixed by qualifying that first wait (`payload_contains` "Got: Leather Jerkin") and adding one more qualified wait (`payload_contains` the hint's exact text) right after it, so the since-marker cursor clears both toasts before any later unqualified wait runs — every downstream screenshot verified correct after the fix. |
| `crate_fight` | 9 (fixture) | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** **Now the `post_tutorial_street` FIXTURE** (starts past the ambush at street (1,3), so crate_talk stays combat-free). Playtest-content slice T3 (new script). "The Missing Crate" FORCE path: copies the proven inn→floodplains→liscor_gate leg from `gate_district_walkthrough.json` verbatim, accepts `missing_crate` from the new `krshia` npc (street `(13,2)`, beside her shipped `krshia_stall`), fights the new `crate_scavengers` encounter (street `(12,16)`, 2×`goblin_raider` in the shipped `goblin_ambush` arena, no ally — a fresh roster/arena pairing not covered by any existing script) via `combat_autoplay`, then reports back for the win. Seed 9 held on the first try — no search needed (see the task report's search log). Asserts `entity_removed`{crate_scavengers}, `accomplishment_recorded`{recovered_crate_force}/{found_the_crate}, both `quest_beat_completed` beats (1 then 2) + `quest_completed`{missing_crate}, and a `ui_journal_shown`/`_hidden` confirmation. **Since-marker gotcha (new this script):** the fight's `on_victory` array banks `found_the_crate` (firing `quest_beat_completed`{beat:1}) BEFORE `remove_entity` fires `entity_removed` for the encounter — a `wait_for_event` sequence that waits for `entity_removed` before `quest_beat_completed` hangs, because the since-marker cursor has already passed the (earlier-in-log) quest event. Order waits to match true emission order, not narrative order; the same trap applies to `crate_talk`'s persuade option below. |
| `crate_talk` | 9 (fixture) | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** **Now the `post_tutorial_street` FIXTURE** (starts past the ambush at street (1,3), so crate_talk stays combat-free). Playtest-content slice T3 (new script). "The Missing Crate" WATCH (talk) path: no `combat_started` anywhere in the path. Pitching Krshia banks `asked_about_crate` alongside starting `missing_crate`; the new `watch_sergeant` npc (street `(17,12)`) then offers a persuade option (visible only once `asked_about_crate` is banked, hidden again once `found_the_crate` lands) that removes `crate_scavengers` directly (`remove_entity`, the `goblin_parley` warrior-bypass pattern) and banks `recovered_crate_watch`/`found_the_crate` — asserts `entity_removed`{crate_scavengers} + `assert_event_absent combat_started`. Same since-marker ordering gotcha as `crate_fight`: the persuade option's accomplishment effects (and the `quest_beat_completed` they fire) land BEFORE its `remove_entity` effect in the log. |
| `crate_light` | 9 | Playtest-content slice T3. "The Missing Crate" SKILL (guile) path. **Onboarding rev O4 (prologue rewrite):** now inherits mage_unlock_loop's Pisces arc for [Light], THEN does the street crate quest. Because the mage-granting sleep RE-ARMS `goblin_encounter_1` and the cellar is on the street, this path crosses the floodplains ambush **TWICE** (fight 1 pre-mage as Warrior; fight 2 post-mage as Warrior/Mage) — both won at seed 9. Crate-quest tail UNCHANGED from the pre-O4 script: accepts from Krshia, proves the hidden-until-met discipline (`dialogue_node` `options` exact-length array = only "Just visiting." before studying — the guile report line is genuinely absent), studies `cellar_door` (street `(10,17)`, `requires_skill: light`) to bank `studied_the_cellar`, reports via the now-visible guile option (`recovered_crate_guile`/`found_the_crate`/`crate_returned` in one `dialogue_choose`, so the two `quest_beat_completed` waits fire back-to-back). |
| `journal_skills` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** UI wave (item 19, new script). No combat in the path — seed held for convention consistency. Opens the journal at fresh boot: asserts `ui_journal_shown`'s extended payload (`skill_groups: ["Innate", "Warrior"]`, `skill_count: 5`, `revealed_skills: []` — the pre-first-use NAME-ONLY state, proven structurally rather than by screenshot/OCR). Closes, uses the Innate `[Basic Cleaning]` skill via the `dirty_table` prop (same cells `test_sim_core.gd`'s unit test drives: right×3 to (5,3), a blocked down-step faces the table without moving), asserts `used_skills` (now in `Game.sim.snapshot()`) contains `basic_cleaning`, then re-opens the journal and asserts `revealed_skills` now contains it — the first-use reveal, end-to-end through the real UI, not just the sim. `combat_move_input`/`relc_tutorial` (existing scripts) both needed a one-line edit for the SAME wave's Dash confirm-gate change (item 15) — see their own rows/notes below for what changed. |
| `inventory_loop` | 9 | **⟦ONBOARDING O5 re-pathed — see the O5 block above.⟧** M7 Task E5 (new script), THE canonical inventory/equipment loop. Route: `inn_chest` pickup (`leather_jerkin`, `items:2` pinned on the first `I` open) → floodplains → meets Relc fresh (first-ever talk, no decline detour — `relc_tutorial` already covers that) → wins the trivial spar (accept no longer grants the spear — O3 moved it) → re-talks Relc for the GIFT node (`You said you had something for me?` → `relcs_spare_spear` + `given_spear_by_relc`) → sleeps for Warrior L1 → equips the spear via the real UI (`items:3`, gift at index 2) → crosses the `goblin_encounter_1` PROXIMITY ambush at `(30,23)` with `met_relc` banked (Relc allied) → victory. **The kit proof:** `combat.combatants.pc.skills` exact-array-asserted to `["basic_swordwork", "tough_body", "piercing_strikes"]` — `power_strike` (weapon:sword) is gated OUT, `piercing_strikes` (weapon:spear) stays IN; `ui_hotbar_rendered`'s payload is `{slots: N}` ONLY (no slot ids/composition — checked `combat_hud.gd`), and the count (4) is IDENTICAL to the sword-equipped baseline (exactly one weapon-tagged skill has `ap_cost>0` in either family at level 1), so the count alone does NOT distinguish the kits — the exact-array assert is the real proof. **The autoplay-tagged-skill finding (d):** `WICombatAI._act_melee` (`src/core/combat/combat_ai.gd`) checks `(c["skills"] as Array).has("power_strike")` BY LITERAL NAME and never inspects any other weapon-tagged skill generically; `_tally_skill_use` only fires from `use_skill()`, never from a plain `attack()`. Net effect: `sword_skill_used` CAN accrue under autoplay (power_strike is the one skill the AI ever calls by name) but `spear_skill_used` structurally CANNOT — with a spear equipped the AI just falls through to plain `attack()` every adjacent turn, never once calling `use_skill("piercing_strikes", ...)`. This script asserts BOTH counters absent (whole-run `assert_event_absent`) as the true, code-confirmed outcome, not a limitation papered over. **The loot-roll determination (e):** `goblin_encounter_1`'s `loot: [{item: crude_blade, chance: 0.25}]` rolls from a run-seed+encounter-id-derived RNG (never the live sim stream); at seed 9 this roll does NOT drop — verified empirically via `events.jsonl` (no `loot_dropped` anywhere after `combat_resolved`) — so the script asserts `assert_event_absent loot_dropped` and documents it; a future items.json/loot-table change that flips the roll needs this assert (and comment) flipped together. **Toast-queue race gotcha (new this script, distinct from work_loop's nested-autosave one):** `message_layer.gd`'s toast queue drains ONE AT A TIME with a real (QA-collapsed to 0.4s) wall-clock hold per toast (`_drain_toasts`/`_hold_seconds`); the Relc-gift toast is queued right behind the floodplains-entry autosave's toast, so its RENDER lags the domain event by a real-time amount that varies run-to-run (observed anywhere from immediately to ~1.2s later) — an unqualified `wait_for_event ui_toast_rendered` matched the WRONG (Autosaved) render and desynced the since-marker past `combat_started` (timed it out); a qualified `assert_event_logged` (instant, no poll) was ALSO flaky when a fast run hadn't drained the queue yet. Fixed: a qualified (`payload_contains` the exact text) `wait_for_event` with a generous timeout (10s), placed right after `ui_combat_shown` — nothing else needs to run for the queue's own timer to tick, so it just polls until the specific render appears regardless of how fast the surrounding fight resolves. Also proves the reveal-interplay (plan E5 bullet 2): the journal (`ui_journal_shown`) still lists BOTH `[Power Strike]` (revealed — used during the spar) and `[Piercing Strikes]` (name-only — never `use_skill`'d, per the finding above) under Warrior regardless of which weapon is currently equipped — knowledge ≠ fieldability, confirmed by a windowed screenshot read (`.superpowers/sdd/fp-handoff/e5-shots/07_journal_knowledge_not_fieldability.png`). |
| `atmosphere_check` | 9 | M-BEAUTY Task B1 (new script), THE canonical mood-grade/phase-clock proof. No combat, no rng — phase is a pure function of `actions_since_sleep` counters, so seed 9 held straightaway. Route: `world_ready` → `ui_mood_applied`{inn,day} → opens/closes the journal under the identity day grade (UI-ungraded proof; screenshot `00b_journal_open_identity_grade` — the parchment panel and its border are exactly as bright as the field behind it, confirming the journal's native-res CanvasLayer sits outside the world SubViewport's CanvasModulate) → 100 real actions via pure back-and-forth moves along inn row y=3 (`(2,3)`→right10→`(12,3)`→left10→`(2,3)`, FIVE round trips — Track P1 re-sized 40→100 in lockstep with the dusk_at retune; the row is clear of every entity/blocked cell from x=1–14, only `inn_door` at x=15 is excluded; all 100 succeed, net displacement zero, exactly crossing `dusk_at`=100) → `phase_changed`{dusk} + `ui_mood_applied`{dusk} → walks to the bed (`(2,3)`→down3→`(2,6)`, bed itself at `(2,7)` blocks the last step same as `work_loop`/`inventory_loop`'s chest routes) → sleep → `phase_changed`{day} + `ui_mood_applied`{inn,day}. Windowed day/dusk shots were visually IDENTICAL at B1 (ship-neutral-first: every `moods.json` entry is `[1,1,1]`/vignette 0) — see `task-b1-report.md` for that side-by-side. **M-BEAUTY Task B2 update:** now also `assert_event_logged`s `ui_lights_rendered`{map:inn, count:2} (whole-run scan, not `wait_for_event` — see the light-layer architecture block's QA note for why) right after the day `ui_mood_applied` wait. The day/dusk visual-identity claim is DAY-ONLY as of B2: the inn's hearth+grill lights are invisible at day (unchanged) but genuinely glow at dusk now — `01_dusk.png` legitimately differs from `00_start_day.png` from this task onward; see `task-b2-report.md`. **M-BEAUTY Task B3 update:** now also `assert_event_logged`s `ui_ambience_rendered`{map:inn, emitters:1} (same whole-run-scan idiom, right below the B2 lights tooth) — the inn's one `dust_motes` entry is always spawned regardless of phase (emitter existence vs `.emitting`/`.visible` on/off is the phase-gated part, same design as lights' energy). The inn route itself never crosses the sway/water-shimmer/vignette surfaces (no floodplains foliage or pond on this script's path, vignette strength is still identity 0.0 everywhere) — those are proven by a separate THROWAWAY floodplains script instead (day sway + dusk pond fireflies/glints + dusk campfire, three shots; see `task-b3-report.md`), same idiom as B2's THROWAWAY campfire proof. |
| `sewers_walkthrough` | 9 (fixture) | **Content Wave C1 (new canonical, +1 → 34).** THE Liscor sewers proof. Loads the `near_sewers` FIXTURE (post_tutorial_street shape + `heard_about_cisterns` pre-banked — C3 banks that from Olesm for real) via title Continue, positioned two north of the grate approach (street `(15,9)`). ENTERS via the REAL `sewer_grate` interact — the **grate-gate seam** (`door_when` on the street grate prop; gate MET → `open_toast` + transition to sewers `(2,2)`, gate UNMET → byte-identical to the pre-quest `heard_the_sewers`+toast, so `gate_district_walkthrough`/`crate_*`/`social_loop` stay green; unit-covered in `test_sim_core.gd`). Then the sewers atmosphere teeth (`assert_event_logged`, whole-run scan): `ui_mood_applied`{sewers,day} (dark pin), `ui_map_rendered`{sewers}, `ui_ambience_rendered`{sewers, emitters:3} (2 always-on `pond_glints` on the water channels + `dust_motes`), `ui_lights_rendered`{sewers, count:2} (phosphor + grate-shaft — day-gated OFF at day, but registered). Reads two flavor props (`phosphor_moss`/`drainage_marker`, exact toasts), clears the new `sewer_vermin` trash pack (2×`sewer_vermin`, arena `sewers_nest`, no ally — `combat_autoplay`, fixture rng 9 wins straightaway), then climbs the `sewer_exit` ladder back to street `(15,11)`. Shots: `00_sewers_landing` (mood), `01_vermin_encounter` (dark combat), `02_back_on_street`. The `shield_spiders` nest is placed but NOT fought here (Quest 1 / C3; interact-only, off-path). Grate-gate verdict: **thin sim seam** (`door_when` on props + `_door_gate_met` in `interact()`), not data-only — doors transition unconditionally, so a gated transition needed the smallest presentation/sim seam per spec §4. |
| `cisterns_fight` | 9 (fixture) | **Content Wave C3 Quest 1 FIGHT path (new canonical, +1 → 35).** Loads `cisterns_fight_start` (warrior L1 beside Olesm at the Guild frontage `(29,4)`) via title Continue. Full three-path-parity loop: GIVE (Olesm `olesm_intro` cisterns node banks `heard_about_cisterns` → opens the C1 grate `door_when` + starts the `cisterns` quest; `cisterns_brief` is the what/where/how explaining beat) → descend the now-open `sewer_grate` → clear the `shield_spiders` nest (`on_victory` banks `cleared_the_nest` + `resolved_the_cisterns`, firing quest beat 1) → ascend the ladder → REPORT (Olesm banks `cisterns_reported` → beat 2 + `quest_completed`). Fixture rng governs the warrior-L1-solo fight (~0.74 harness win; rng 9 won straightaway). Shot `01_olesm_give`. |
| `cisterns_talk` | 9 (fixture) | **Content Wave C3 Quest 1 TALK path (new canonical, +1 → 36).** Loads `cisterns_talk_start` (warrior L1 at `(29,4)`). NO combat anywhere (its whole point; `assert_event_absent combat_started`). GIVE (Olesm) → cross to Watch Captain Zevara at the gate `(2,6)` and PERSUADE her via the `zevara_intro` sweep chain (`sweep_pitch`→`sweep_argue`, banks `persuaded_someone` + `watch_swept_cisterns` + `resolved_the_cisterns` [beat 1] + `remove_entity shield_spiders`) → REPORT to Olesm via the Watch option (`cisterns_reported` → beat 2 + completion). FIRST canonical coverage of `zevara_intro` (C2's probe was deleted; no prior asserts). Shot `02_zevara_persuade`. |
| `cisterns_scout` | 9 (fixture) | **Content Wave C3 Quest 1 SKILL path (new canonical, +1 → 37).** Loads `cisterns_scout_start` (warrior L1 + `[Tactician]`/`[Observe]` at `(29,4)`). NO combat. GIVE (Olesm) → descend the grate → `[Observe]` the new `nest_ledge` prop `(17,10)` overlooking the nest — banks `scouted_the_nest` via the `requires_skill:observe`+`on_skill_use` seam (interact E routes through the SAME `use_skill('observe',…)` the field `[Observe]` hotbar uses — crate_light/cellar_door precedent) → ascend → REPORT the INTELLIGENCE to Olesm (`cisterns_intel`: his "a map is as good as a corpse" `[Tactician]` beat banks `resolved_the_cisterns` THEN `cisterns_reported`, firing BOTH beats + completion at once — crate guile precedent). **Third script by judgment (34→37, not the planner's estimate of 36):** the SKILL stream descends the sewers while the TALK stream never does, so they cannot share a run (a quest resolves exactly once). Shot `03_nest_observe`. |
| `char_creation` | none | **M-ARC §5 (new canonical, +1 → 42).** THE character-creation proof — the ONLY script that drives the real creation UI (`starts_at_title` + top-level `creation_ui: true`; every OTHER New Game is the default TestDriver skip → `Game.reset()` straight through, byte-identical to before this feature, so the whole suite is untouched). Title gate → New Game → `swap_to_char_creation` → picks **Drake / Female / "Sella"** (arrows + `type_text` unicode into the name field, captured by `char_creation.gd::_unhandled_input`, NOT LineEdit GUI focus — headless-safe) → confirm fires `Game.reset({pc_name,pc_race,pc_gender})`. Asserts: `ui_char_creation_confirmed`{Sella,drake,f}; the **Drake-branched** GDI opener (`ui_gdi_opener_rendered`{lines:4, race:drake} — the "starting over in Liscor" copy, canon-safe: only Humans are Earth otherworlders); the snapshot identity fields + the pure variant key `pc_sprite == "pc_drake_f"` (art-independent); and the RENDERED field binding `ui_entities_rendered`{pc_sprite:"pc_drake_f"} (world.gd + board_renderer resolve the variant at the two presentation bind sites, degrading to `body_a` if a variant's art is missing). No combat/rng → no seed. |
| `deep_descent` | 9 | **M-ARC A2, EXTENDED A3 (JOIN path, +0 — same canonical).** THE Raskghar descent proof — fixture-based via `deep_descent_start` (sewers, warrior L5, `heard_the_deep_tremor` pre-banked, facing the `deep_fissure` at (8,12); fixture `rng_state` governs BOTH fights, overrides `--seed`). Interact the fissure → **descend** to `deep_tunnels` → read Cold Hearth → clear the interact-only `raskghar_scouts` route-fight (solo) → read Gnawed Bones → reach `warren_mouth` (threshold toast + `reached_the_warren`, UNCHANGED) → **A3: interact the `awakened_boss` encounter (12,7) → the `relc_descent` join/veto dialogue → [Go together.] banks `relc_joined_descent` (satisfies `awakened_boss.ally_requires`) → WIN the Awakened + 2 scout adds in the `deep_warren` arena with Relc fielded (roster proof `combat.combatants.relc.side==player`) → on_victory banks `cleared_the_warren`**. `heard_the_deep_tremor` gate key: A3's tremor beat (Zevara summons) is its real producer (climax_chain), the fixture stands in. Boss WON at fixture `rng_state=9` straightaway (warrior L5 + Relc; no seed search). **The party VETO/solo path is DESCOPED to a unit roster proof** (user directive) — `test_combat_data._check_boss_veto_roster` builds a real WIGame and asserts DECLINE (`went_alone`, no `relc_joined_descent`) fields NO Relc while JOIN fields him; the 0.04 solo cell (sim_combat_batch BOSS_CELLS) documents the difficulty. No dedicated veto script. |
| `climax_chain` | 9 (fixture) | **M-ARC A3 (new canonical, +1 → 44) — the tremor beat + surface briefings (PRE-descent arc).** Loads `climax_surface_start` (inn bed, Act II COMPLETE: 2 classes + 3 quests). Proves: **(1) THE TREMOR BEAT** — sleeping with Act II complete fires the one-shot pointer toast "A Watch runner is looking for you." + banks `watch_runner_pointed` (`_maybe_fire_tremor_pointer` in `sleep()`); **(2) ZEVARA SUMMONS** — her summons option (gated on `watch_runner_pointed`) banks `heard_the_deep_tremor` (opens the deep_fissure FOR REAL); **(3) OLESM BRIEFING** — gated on the tremor, banks `heard_olesm_briefing`. Teleport-driven between NPCs. No combat. NOTE: inside `sleep()`, `accomplishment_recorded{watch_runner_pointed}` fires BEFORE the pointer toast — wait for the accomplishment first (the wait cursor advances in emission order). |
| `climax_seal` | 9 (fixture) | **M-ARC A3 (new canonical, +1 → 45) — the seal beat (POST-victory arc).** Loads `climax_sealed_start` (street, Act II done + `cleared_the_warren` banked, `raskghar_sealed` NOT). Proves: **(1) ZEVARA SEAL** (gated on `cleared_the_warren`) banks `raskghar_sealed` — the **Act III advance key** (acts.json); victory != sealed, the seal is a separate surface beat AFTER the return (acts-data trace); **(2) journal advances to ACT III** (`ui_journal_shown{act_id:act_iii}`); **(3) OLESM RESOLUTION** (gated on `cleared_the_warren`) banks `heard_olesm_resolution`. Separate stream (distinct post-victory game state). No combat. |
| `arc_flow` | 9 (fixture) | **M-ARC A4 (new canonical, +1 → 46) — THE WHOLE-ARC PROOF.** Loads `near_act3` (inn bed, Act II complete: Warrior 5 + Diplomat 1, 3 quests, no Act III keys). Drives the ENTIRE Act III arc live: **(1)** tremor sleep pointer; **(2)** Zevara summons → `heard_the_deep_tremor`; **(3)** Olesm briefing; **(4)** THE DESCENT — teleports to the `deep_tunnels` landing and replays `deep_descent`'s winning nav (Cold Hearth → `raskghar_scouts` fight → Gnawed Bones → Warren Mouth → the Relc JOIN veto → boss VICTORY, Relc fielded) → `cleared_the_warren`. **The surface arc (sleep + dialogues + teleports) consumes ZERO rng, so the fights sit at the SAME deterministic rng `deep_descent` wins at** — no seed search (proven: `deep_descent` still passes with warrior5+diplomat1); **(5)** Zevara seal → `raskghar_sealed`; **(6) THE GDI EPILOGUE EVENT** — `ui_gdi_epilogue_rendered{lines:7}` fired by the seal `dialogue_ended` (armed by `raskghar_sealed`, played on dialogue-end — NOT a sleep) → banks `post_game`; **(7)** journal Act III completed beat (`seal_holds`, gated on `post_game`); **(8)** the post-game Zevara greeting variant (`dialogue_node`, last-match `raskghar_sealed` text_variant; also proves no epilogue re-fire on re-entry); **(9)** free-play sanity (move + plain sleep `ui_sleep_veil_rendered{lines:0}` + `assert_event_count ui_gdi_epilogue_rendered == 1`). Fixture-based, no seed search. |

- **Playtest fixes + art (M4):** Dialogue gating SPLIT — options with
  accomplishment-keyed `requires` are HIDDEN until met (progress must not leak);
  skill/class gates stay visible-locked (deliberate tease). NEVER mix an
  accomplishment key with skill/class keys in one `requires` dict (`_meets`
  evaluates only the first key). Dialogue ctx REFRESHES per node advance
  (`WIDialogue.choose` returns `{effects, ended, next}` without advancing;
  `WIGame.dialogue_choose` applies effects → `set_ctx` → `advance`), so
  mid-conversation effects re-gate the same conversation — hubs loop via
  `goto` back-references. Every node with any vanishing option (hide_when OR
  accomplishment-requires) must keep one FULLY UNGATED exit option
  (`test_content.gd` enforces). `cleaned_the_inn` comes only from the
  dirty_table prop. Defeat loads the `auto` slot (QA: `defeat_reload`, seed 1).
- **Art pipeline (M4):** viewport 1024×640; field + combat cells both 64px.
  *(SUPERSEDED by M5 R3 — the render pipeline is now a 320×180 world SubViewport
  scaled 4× in a 1280×720 window, world `CELL := 16`; see the "Demo feel + render
  pipeline (M5)" block below. The M4 registry/sprite mechanics still apply.)*
  `WISpriteRegistry` (src/world/, presentation-only) builds SpriteFrames from
  `data/sprites.json` (directional entries → `idle_down/walk_side/...`;
  optional `region` crops shared sheets; optional `render_scale`) and TileSets
  via `tile_set_for(sheet, tile_px)`. Maps/arenas carry `biome` tags resolved
  through `data/biomes.json` (NOTE: cave sheet is a 16px grid; free-pack sheets
  32px). Rendering emits `ui_map_rendered`/`ui_arena_rendered`/
  `ui_entities_rendered` confirmations that QA asserts. Committed curated
  extracts live in `assets/` (licenses alongside in `assets/LICENSES/`);
  `potential_assets/` stays gitignored. **Any tile/sprite region pick MUST be
  verified by a windowed screenshot read by the controller** — text-guessed
  coords were wrong repeatedly in M4. Browse assets via `docs/asset-index.md`
  (repo root), never by loading PNGs into context.
- **Paced AI playback (M4 T10):** sim resolves AI turns synchronously; the
  combat screen queues WAIT_AI visual events and replays them at
  `AI_BEAT_SECONDS` (0.5s) per beat, skippable via confirm/cancel. Queue
  entries capture ALL render state (cells, flip, flash cells, post-event
  hp/mp) at ENQUEUE time — never read live combat state on a dequeue path
  (the live snapshot is already at end-of-turn). `_refresh_combatants` is
  gated off while `_playing`; one full `_refresh` fires at drain end. Delay
  is 0 whenever `TestDriver.active()` or headless — so QA (windowed included)
  can never observe real pacing; cadence feel is human-playtest-only.

- **Demo feel + render pipeline (M5):** The project window is 1280×720 with
  `window/stretch/mode="canvas_items"` and no integer `scale_mode`; Main owns a
  320×180 world SubViewport scaled 4× and centered in the full window. This is
  the playtest-approved fill-window fractional stretch direction — do not
  restore integer stretch without a new playtest decision. `WIMain.world_to_screen`
  is the single projection path for native-resolution labels.

- **Environment schema (M5 E3):** `data/skeleton_scene.json` maps use
  `floor_layers`, `walls.segments`, `decor`, and `scatter` as presentation data.
  Wall segments are walls-v2 `{from, to, cap, face}` records; `WIGame.segment_cells`
  is the single source for inclusive segment cell expansion used by sim blocking
  and tests. Decor/scatter sprites are non-blocking presentation entries; sprite
  records in `data/sprites.json` may carry `region`, `render_scale`, `anchor`,
  and `shadow`, while map entities may carry `facing` (`up/down/left/right`) so
  world.gd can choose idle rows and side flips.

- **E3 inn layout lock:** inn grid is 16×10. Erin is stationed on the bar line
  at cell `[7, 2]` facing down; the inn door is `[15, 3]`. The street return
  door `street_door` sends the player to inn cell `[14, 3]`. Keep those coords
  stable unless updating every walkthrough and the scene-assembly docs.

- **UI chrome (M5 H1/H3):** `UIChrome` is the helper for parchment/ribbon/
  button NinePatch panels and labels. The Tiny Swords parchment/banner art
  floats inside transparent canvases, so `region_rect` must use the measured
  art bbox (`PARCHMENT_REGION`, `BANNER_H_REGION`) or panels stretch empty
  transparent margins and appear collapsed. Hotbar slots use fixed 52×52 carved
  frames; slot icon ids come from `data/skills.json`/`data/sprites.json`.

- **Music loops (M5 A2):** curated xDeviruchi music comes from the pack's
  Loopable OGG variants or repo-local loopable edits. Loopable tracks loop from
  0; do not add `loop_offset_sec` to a Loopable-variant track. If a future
  non-loopable source needs a musical offset, document why in the asset verdict
  and tests before adding data support back.

- **Combat controls (M5 H1/H2; Dash confirm gate, UI wave item 15):** the
  combat turn resting state is `Mode.HOTBAR`. Arrow/WASD inputs move the
  active unit directly using move pool before AP. Number keys activate
  hotbar slots (`1` Attack, `2` Dash, `3+` skills). Dash refills move pool
  and costs AP; it is NOT a movement mode, but as of the UI wave it is no
  longer instant either — selecting it (like Attack/skills) shows its
  cost/effect in the readout and arms `Mode.DASH_CONFIRM`, a confirm gate
  (Enter executes via `combat.dash()`, Esc cancels back to HOTBAR with no
  spend) handled directly by `combat_screen.gd`'s own `_input_dash_confirm`
  — deliberately NOT folded into `_targeting` (Dash has no target to
  cycle/aim). Tab cycles targets while aiming (ATTACK/SKILL_TARGET only),
  Enter confirms, Esc cancels, and E ends turn.

- **Action-driven classes (M6):** progression is driven by ACCOMPLISHMENT
  COUNTERS — doing `[X]` things levels `[X]` (never BG3-style chosen) — resolved
  ONLY at the sleep beat (canon). `WIProgression` (`src/core/progression.gd`) is
  the pure reader; `WIGame.sleep()` (`src/core/wi_game.gd`) applies the beat in
  order: class gains → level-ups → **consolidation offer** → evolutions.
  - **Leveling:** `check_level_ups` walks a class's `levels` cumulatively; each
    level's `requires` (counter thresholds; `requires_any` for spellsword = met
    when EITHER parent's counter reaches its threshold). ONE sleep resolves ALL
    earned levels (multi-level), batched into ONE toast per class. `check_class_gains`
    grants earned multiclasses (`mage` via `used_magic`) BEFORE level-ups.
  - **Evolution (`check_evolutions`):** at `evolution.at_level` (10), the
    dominant accomplishment axis (`dominance_share` 0.6, `min_uses` 12) picks a
    Replacement (warrior→swordsman/spearmaster, mage→ice_mage/fire_mage), carrying
    level; below dominance with volume + `balanced_grants` → Generalist grant
    (persisted in `generalist_classes`); below with none → Waiting (re-checked
    each sleep). Catalog-order, cycle-safe. `granted_skills` resolves `inherits`
    chains (swordsman inherits warrior; spellsword inherits BOTH parents).
  - **Non-linear scaling (T4/T4b):** `effective_power` (k-norm, `power_k` 1.55)
    + `power_multiplier` (=effective/Σlevels, ≤1.0, EXACTLY 1.0 for a focused
    single class) apply a SPLIT PENALTY to derived stats only (never magnitude);
    `apply_stat_bonuses` adds per-effective-level `stat_growth` via ONE shared
    path (`wi_game` + `sim_combat_batch` both call it). Split-friction target
    20–25% — tune DATA (`power_k`, `stat_growth`), validated by the harness,
    NEVER the sim.
  - **Consolidation (§2.5):** at sleep, if two parent lines both ≥
    `min_parent_level` (6) and sum ≥ `min_combined_level` (13), the beat DEFERS
    (emits `consolidation_offered`, stores `pending_consolidation`) BEFORE
    evolutions — the merge is offered before an evolution can lock a class's
    identity. Accept → parents consumed into `[Spellsword]` at
    `max(ceil(2·sum/3), max parent)`; decline → that sleep's evolutions proceed.
    Offer round-trips in saves, re-offered each qualifying sleep, refusable
    forever. UI: `src/ui/consolidation_prompt.gd` (modal; world/journal/pause
    decline input while `Game.sim.pending_consolidation` is non-empty; RECONSTRUCTS
    from `Game.sim.pending_offer_display()` on load since the offer event only
    fires live at the sleep beat).
  - **Class tree (data/classes.json):** `warrior` (base, 12 levels, evolution)
    + `mage` (earned) → evolutions → `[Spellsword]` consolidation. `fighter` was
    the legacy 2-level base — DELETED (T9); `warrior` is the canonical base and
    old saves remap `fighter`→`warrior` in `save.gd._migrated` (no version bump).
  - **OPAQUE-UNTIL-SLEEP is USER-LOCKED:** never render progress-toward text
    anywhere — no "3/12 sword uses", no percentages, no level numbers in the
    consolidation prompt. Toasts / journal / prompts show RESULTS only. (Raw
    STR/DEX/etc. remain forbidden repo-wide; HP/MP/damage stay visible.) QA:
    `class_evolution_loop` / `consolidation_flow` / `consolidation_reload` /
    `save_migration` (seed table above).

- **Equipment (M7, 2026-07-05):** pure sim state — `WIGame.inventory`
  (ids) + `equipped` {weapon, armor} + `container_state`; field-only
  `pickup/equip/unequip` (equipped ⊆ inventory invariant). Combat reads
  equipment ONCE at `start_combat` build: kit = class kit filtered by the
  equipped weapon's family vs skills' `"weapon"` tags (untagged always
  fields — spells are never tagged, test_items enforces), weapon
  `damage_mod` melee-only, armor `hp_mod` at build, `damage_reduction`
  in `_deduct_hp` BEFORE mana_shield, floor ≥1. **Loot RNG isolation:**
  victory rolls use a `hash(run_seed, encounter_id)`-derived generator —
  NEVER the live sim stream (a main-stream draw would shift every
  multi-fight canonical seed). Containers: `contains` props grant once,
  persist emptied via `container_state`. Save VERSION 5 (composing
  v2→v3→v4→v5; migration equips the rusty sword so old saves keep their
  fight shape; also carries `actions_since_sleep`). Sleep-phase (M-BEAUTY
  fold): `phase()` = pure function of `actions_since_sleep` (dusk ≥100,
  night ≥225 since Track P1 retune — code fallback is still 40/90, but
  the LIVE injected values are moods.json's; config-injected), `phase_changed` on crossings + sleep
  reset, zero rng; NOTE it can emit mid-combat (PC turns tick the
  counter) — presentation consumers must tolerate that. CHANGING the
  phase thresholds (`data/moods.json`'s `meta.phase_thresholds`, LIVE as of
  the M-BEAUTY final-review fix wave — see the Atmosphere block above)
  shifts where phase_changed lands in event streams — treat it like combat
  data: full canonical-seed re-verify required. Inventory UI:
  `src/ui/inventory.gd` (I key, journal grammar, three-way arbitration
  with journal/pause). QA: `inventory_loop` (seed 9) is the canonical
  proof; the melee AI cannot use spear-tagged skills (literal
  power_strike check) so spear tallies never accrue under autoplay —
  kit asserts carry that proof instead.

- **Atmosphere / mood grade (M-BEAUTY Task B1, 2026-07-05):** presentation-only,
  ship-neutral-first. `data/moods.json` (`meta.phase_thresholds` {dusk:100,
  night:225} since Track P1 (2026-07-06), retuned from 40/90 — LIVE as of the
  M-BEAUTY final-review fix wave (Fix 3,
  2026-07-05): `game.gd`'s `_build_sim` now reads this dict and passes
  `{dusk_at, night_at}` into `WIGame`'s `phase_config` ctor arg (the ctor
  already accepted it, unused, since the M7 M-BEAUTY fold — `wi_game.gd`
  itself was untouched by the fix). **Track P1 sizing:** the honest inn→Liscor
  onboarding route (post-Warrior-sleep) hits `actions_since_sleep==62` at
  arrival (measured N~60; `gate_district_walkthrough` events.jsonl), so with the
  old dusk_at=40 the player arrived already at dusk — the playtest complaint.
  dusk_at 100 (~1.6×N) lands arrival in LATE DAY with dusk ~38 actions later;
  night_at 225 = 2.25×dusk_at. These NO LONGER match
  `wi_game.gd`'s own hardcoded `_phase_config` fallback (40/90) — the injection
  is what makes moods.json's values the live ones; changing it for real now genuinely
  moves `phase_changed` in every event stream, see the phase-threshold
  reverify rule in the Equipment/M-BEAUTY Gotchas block below (now actually
  reachable, not theoretical) —
  `meta.light_energy_by_phase` is data staged for Task B2, READ as of that
  task — see the light-layer block below) +
  per-map `moods.<map_id>.<phase>` RGB triples + `vignette`, one entry per
  `skeleton_scene.json` map key (`inn`/`street`/`floodplains` — arenas are
  separate, `data/arenas.json`, out of scope until a rollout task). EVERY
  entry ships identity (`[1,1,1]`, vignette 0) this task — zero visible
  change, full machinery live. `src/world/atmosphere.gd` (`WIAtmosphere`,
  `extends CanvasModulate`) is spawned as a direct child of `WIWorld` in
  `world.gd`'s `_ready()` (added, and its own `_ready()` connected to the
  bus, BEFORE `WORLD_READY` emits — the same-frame ordering is what lets it
  catch its own spawn event). Listens to `world_ready`/`map_changed`/
  `phase_changed`; `apply(map_id, phase)` sets `color` from moods.json and
  emits `ui_mood_applied {map, phase}`; `phase_now()` passes through
  `Game.sim.phase()`. **Combat-board-inherits-the-grade finding (empirical,
  answers the plan's open question):** CanvasModulate tints the ENTIRE
  default canvas layer of the viewport it lives in, not just its own node
  subtree (Godot semantics: one CanvasModulate per canvas). No CanvasLayer
  wraps `WIWorld.combat_board_root()` (a plain Node2D sibling of
  `_field_root` under the same World node, M5 R6) — it shares the world
  SubViewport's default canvas with `atmosphere.gd`, so arenas inherit
  whatever mood is currently applied FOR FREE, no extra wiring. UI
  CanvasLayers (`message_layer`/`combat_screen`/`journal`/`pause_menu`/
  `inventory`/`consolidation_prompt`, all children of `WIMain` directly, per
  `main.gd`'s `_spawn_ui_layers`) sit OUTSIDE the world SubViewport entirely
  and are structurally ungraded — confirmed by a windowed screenshot of the
  journal open at the identity grade (`atmosphere_check`'s
  `00b_journal_open_identity_grade` shot). QA: `atmosphere_check` (seed 9,
  table above) is the canonical proof — walks the phase clock through a full
  day→dusk→day cycle via 100 real actions + a sleep (re-sized from 40 in
  lockstep with the Track P1 dusk_at retune 40→100), asserting both
  `phase_changed` and `ui_mood_applied` at each crossing. New consts
  `UI_MOOD_APPLIED` (emitted this task), `UI_LIGHTS_RENDERED`/
  `UI_AMBIENCE_RENDERED` (declared now per the plan, B2/B3 emit them) live
  in `wi_events.gd`.

- **Light layer (M-BEAUTY Task B2, 2026-07-05):** presentation-only, still
  ship-neutral-first for DAY specifically (dusk/night now genuinely change —
  see the visual-identity note below). Entity/decor records in
  `skeleton_scene.json` may carry `light: {color:[r,g,b], energy: float,
  radius: int, flicker: bool}`; `world.gd`'s `_make_entity_visual` spawns a
  `PointLight2D` child (`_spawn_light`) whenever a `light` dict is present,
  textured with the generated `assets/fx/light_radial.png` (64px soft radial
  white gradient — a small PIL script, not a purchased/sourced asset;
  provenance + the script verbatim live in `task-b2-report.md`),
  `texture_scale = (radius*2)/64` so the data-authored `radius` sets the
  glow's on-screen size, centered on the cell. `_rebuild_field` resets a
  per-pass `_light_count` and calls `_atmosphere.clear_lights()` BEFORE
  rebuilding (old holders are only `queue_free()`d, not synchronously freed,
  so the registry must be cleared explicitly rather than trusting
  `is_instance_valid()` to catch up); after the pass it asserts
  `_light_count <= 8` (spec §5 budget — assert, not push_error, same
  zero-warning reasoning as below) and emits `ui_lights_rendered {map,
  count}`. **Phase gating lives entirely in `atmosphere.gd`, not world.gd:**
  `register_light(node, base_energy, flicker)` immediately sets the new
  node's `.energy = base_energy * light_multiplier(phase_now())` (so a light
  spawned mid-dusk via a map change is never dark-until-next-event), and
  `apply()` (already the map/phase color entrypoint) now also calls
  `_refresh_lights()` so a `phase_changed`/`map_changed` pass updates the
  grade color and every live light's energy together. `light_multiplier`
  reads `moods.json`'s `meta.light_energy_by_phase` (`day: 0.0` — this is
  THE mechanism that keeps every light invisible at day, no per-anchor
  identity hack needed). **Flicker** (`_process` in `atmosphere.gd`) is a
  small sine wobble on the subset of registered lights with `flicker: true`,
  and is skipped ENTIRELY (no per-light work at all) whenever there are no
  flicker lights OR the current phase's multiplier is 0 — i.e. truly zero
  per-frame cost at day, per the plan's requirement. **rgb/color
  bounds-check (B1 review carry, resolved):** malformed `moods.json` rgb or
  `light.color` data (wrong array length) is treated as a data-authoring bug
  and asserted loudly at the point of use (`atmosphere.gd`'s `apply()`,
  `world.gd`'s `_spawn_light`) — NOT a silent identity/skip fallback with a
  `push_error` (would print on every touching run and violate the
  zero-warning rule) and NOT a fully silent fallback (would let a data typo
  ship invisibly). This matches `WISpriteRegistry`'s own idiom for malformed
  catalog data (`sprite_registry.gd`'s `assert(_catalog.has(sprite_id), ...)`
  et al.) — the codebase's one existing convention for bad content data,
  reused rather than a second one invented. **2D lighting pipeline: NO
  project or viewport setting was required** — `PointLight2D`'s defaults
  (additive blend, range/cull masks matching every `CanvasItem`'s own
  defaults) work as-is inside the 320×180 world `SubViewport`; verified
  empirically via a windowed screenshot pair (day: campfire dark, identical
  to the pre-B2 baseline; dusk: same frame, campfire glowing warm-orange —
  see `task-b2-report.md`). **Shipped anchors** (all warm except the sewer
  grate; ≤8/map budget: inn 2, street 4, floodplains 1): inn `hearth`
  [2,1]/`grill` [3,2] (cluster); floodplains `campfire` [10,7] (Relc's,
  decor); street `sconce` ×3 [14,7]/[15,12]/[14,17] (gate-district
  brazier/torch anchors — the street-decor `sconce` entries ARE the
  "brazier" the plan named; there is no separate `brazier` sprite id) +
  `sewer_grate` entity [16,11] (subtle green, no flicker — an eerie steady
  glow, not a fire). Street's own two `campfire` decor entries ([3,5] and
  [13,10]) were DELIBERATELY left unlit this task — not in the plan's named
  anchor list; full gate-district night dressing was the ROLLOUT task's
  job. **Superseded by M-BEAUTY Task R2 (2026-07-05):** both street
  campfires are now lit (see the rollout R2 block below) — street carries
  6 lights today (3 sconces + sewer_grate + 2 campfires), still inside
  the ≤8/map budget.
  **Visual-identity note (supersedes part of the B1 entry above):** B1's
  `atmosphere_check` day/dusk screenshot pair was pixel-identical because
  B1 shipped zero lights; as of B2 that is DAY-ONLY — `01_dusk.png` now
  legitimately differs from `00_start_day.png` (the inn's hearth/grill
  visibly glow at dusk) by design, while the day shot stays pixel-identical
  to every prior baseline (confirmed by direct comparison against B1's own
  `00_start_day.png`). QA: `atmosphere_check` extends with an
  `assert_event_logged` (NOT `wait_for_event` — `ui_lights_rendered` fires
  inside `_rebuild_field`, BEFORE `world_ready`, the same ordering class as
  `work_loop`'s nested-autosave gotcha above, so a forward-only wait here
  would hang to timeout) for `ui_lights_rendered {map: inn, count: 2}` right
  after the day `ui_mood_applied` wait. Light ENERGY itself (0 at day, >0 at
  dusk) has no honest sim-observable event to assert on — it's presentation
  state `atmosphere.gd` owns directly — so the headless tooth stays scoped
  to event-presence + count, with a windowed screenshot (a THROWAWAY script,
  content preserved in `task-b2-report.md`) as the real proof a light reads
  as lit at dusk.

- **Ambience layer + shaders (M-BEAUTY Task B3, 2026-07-05):** presentation-
  only, extends the B1/B2 registry pattern to particles + 3 tiny canvas
  shaders. `src/world/ambience.gd` (`WIAmbience`, static factory, no state)
  builds a `GPUParticles2D` per preset — `fireflies`, `dust_motes`, `leaves`,
  `pond_glints`, `embers` (≤64 particles each, native 320×180-px space) —
  from `assets/fx/particle_dot.png` (fireflies/dust_motes/pond_glints/embers,
  differentiated by color/motion/scale, not shape) and
  `assets/fx/particle_leaf.png` (leaves only), both generated (PIL, white RGB
  + alpha shape, same idiom as B2's `light_radial.png`; docs/asset-index.md
  was checked first per spec §7 — the only particle-adjacent pack art is
  multi-frame one-shot VFX strips, not a small repeatable dot/leaf sprite;
  generation script verbatim in `task-b3-report.md`). Map data `ambience:
  [{preset, rect|"all", phase:[...]}]` (M5 R4-style passthrough field, same
  idiom as `decor`/`scatter`) → `world.gd`'s `_build_ambience` spawns one
  emitter per entry (added to `_field_root`, drawing in front of every
  sprite — intended, ambience reads in front of trees/the player) and
  registers it with `_atmosphere` (`register_emitter`/`clear_emitters`/
  `_refresh_emitters` — same registry lifecycle as lights: cleared at the
  top of every `_rebuild_field`, re-applied from `apply()`). **Emitter phase
  gating is a hard on/off, not a continuous multiplier like lights**: a
  `phase_changed`/`map_changed` pass sets BOTH `.emitting` (stops new
  particle spawn) AND `.visible` (hard-cuts any still-alive particles
  instantly) together — `.emitting` alone would let stragglers fade out
  naturally over their remaining lifetime, which is nicer during real play
  but makes a windowed day-phase screenshot non-deterministic (a shot taken
  a few frames after crossing back to day could still show a straggler);
  the hard cut keeps every day-phase QA shot deterministic, matching B1/B2's
  ship-neutral-first day-identity contract. `_ambience_count` backs
  `AMBIENCE_BUDGET` (≤6/map, spec §5, same assert-not-push_error convention
  as `LIGHT_BUDGET`) and the `ui_ambience_rendered {map, emitters}` emission
  (right after `ui_lights_rendered` in `_rebuild_field`, same "before
  `world_ready`" ordering class — QA must use `assert_event_logged`, not
  `wait_for_event`, same reasoning as `ui_lights_rendered`).
  **Shipped data:** floodplains `ambience` has `fireflies` + `pond_glints`
  sharing one rect (`[6,16,8,6]`, a bounding box over the pond's
  wall-segment cells with a one-cell margin), both `phase: [dusk, night]`;
  inn has `dust_motes` (`rect: "all"`, `phase: [dusk, night]` — DAY is the
  one ambience case explicitly deferred to a pilot/rollout judgment call per
  the plan, not shipped this task).
  **Sway shader** (`src/world/shaders/foliage_sway.gdshader`, canvas_item
  vertex): a subtle (0.6px default amplitude) horizontal wobble, scaled by
  `(1 - UV.y)` so a sprite's top sways and its bottom (the "root") stays
  anchored — classic grass/foliage motion, not a rigid shift. ONE shared
  `ShaderMaterial` (`world.gd`'s `_sway_material`, created once in
  `_ready()`) drives every swaying sprite; per-sprite phase variance comes
  from the shader reading each sprite's own world position
  (`MODEL_MATRIX[3].xy`, a canvas_item vertex-shader built-in), not a
  per-instance uniform, so sharing one material is both correct and free.
  Tagged via a NEW `sway: true` field on `decor` entries (per-record) and
  `scatter` specs (per-pool — `world.gd`'s `_build_scatter` threads one
  `sway` value from the whole spec to every sprite it produces; the
  floodplains spec whose pool mixes `grass_tuft`/`pebble`/`flower_tiny` is
  tagged as a WHOLE rather than split by sprite id, to avoid re-seeding the
  scatter presence hash — which would move WHICH cells host which prop and
  break "all else identical" in the day-shot check; at 0.6px amplitude the
  effect on the mixed pool's non-foliage `pebble` instances is imperceptible
  in practice). Shipped: all 19 foliage `decor` entries on floodplains
  (`tree_big` ×7, `tree_round` ×4, `bush_green` ×8) + both floodplains
  `scatter` specs (`grass_tuft`/`pebble`/`flower_tiny` and `flower_purple`).
  This is THE ONE deliberate always-visible change this task ships (sway is
  NOT phase-gated — it plays at every phase, including day) — per the plan,
  a subtle motion layer reads as "alive" without being a look change a
  controller would flag; the windowed day shot is the judgment gate (see
  Task B3 report).
  **Water shimmer** (`src/world/shaders/water_shimmer.gdshader`, canvas_item
  fragment, uv wobble): applied via an OVERLAY `TileMapLayer`, NOT a
  material on the pond's own tiles. The floodplains pond is painted by
  `walls.segments` entries on the `free_pack/Water_tiles.png` sheet (cap-only
  cells, no `face`) inside `tile_board_builder.gd`'s `build_walls` (a file
  shared with `combat_screen.gd`, out of this task's scope, and one that
  returns only the covered-CELL set, not the layer node itself — there is no
  node this task could reach in to attach a material to the ACTUAL painted
  tiles without editing that shared file). `world.gd`'s
  `_build_water_shimmer` (called right after `_build_floor` in
  `_rebuild_field`) re-derives the identical cells from the identical source
  data (segments matched by `sheet == WATER_SHEET`, via the SAME public
  `WIGame.segment_cells`/`WITileBoardBuilder.make_tile_layer` calls
  `build_walls` itself uses) and paints the identical cap tile into a FRESH
  `TileMapLayer` added as a later `_field_root` sibling — drawn on top of,
  and fully covering, the flat one underneath — with the shimmer
  `ShaderMaterial` applied only to this overlay. No-op (frees the unused
  layer) on any map without a `Water_tiles.png` segment (every map except
  floodplains, today).
  **Vignette** (`src/world/shaders/vignette.gdshader`, canvas_item fragment,
  fullrect): a `ColorRect` (`world.gd`'s `_vignette`) created ONCE in
  `_ready()` as a child of the field `Camera2D` (NOT of `WIWorld` directly)
  so its rect (`position = -VIEW_SIZE/2`, `size = VIEW_SIZE`) always tracks
  the camera's centered/clamped view regardless of map size; `z_index =
  4096` forces it to draw above world content regardless of sibling-order
  timing (`combat_board_root` is added lazily, sometimes after the camera).
  `atmosphere.gd`'s `apply()` writes moods.json's per-map `vignette` field
  (already in the schema since B1, a flat 0..1 float, not phase-keyed) into
  the ColorRect's `strength` shader uniform every mood application
  (`_apply_vignette`); COLOR is fully overridden in `fragment()` so
  `strength: 0.0` (every map, today) means alpha is 0 EVERYWHERE — provably
  invisible, not just faint. No `moods.json` edit was needed this task (the
  `vignette` field already existed, identity 0.0, since B1).
  **WASM-SAFE constructs only**, verified by an actual web export + web QA
  run (`combat_walkthrough`, seed 9) — the first web smoke in this arc,
  since B1/B2 shipped zero shaders/particles and had nothing wasm-specific
  to risk: PASS, 375 events, 3 clean screenshots, no failures. Particle
  presets use only `ParticleProcessMaterial`'s plain simulation properties
  (emission box, direction/spread/velocity/gravity/scale/color/color_ramp/
  orbit_velocity) — no sub_emitters, collision, attractors, trails, or noise
  textures, all of which the compatibility/web renderer path does not
  support. QA: `atmosphere_check` extends with a second
  `assert_event_logged` tooth, `ui_ambience_rendered {map: inn, emitters:
  1}` (same whole-run-scan idiom as the B2 lights tooth, right below it —
  the inn's one `dust_motes` entry is always spawned regardless of phase,
  same "emitter always exists, on/off toggled by phase" design as lights).

- **Atmosphere rollout R1: inn + cave arena + title embers (M-BEAUTY Task
  R1, 2026-07-05):** first rollout task post-pilot-verdict (see
  `docs/superpowers/specs/2026-07-05-map-direction-cards.md`), tuning
  `data/moods.json`'s `inn` entry for real (dusk `[0.85, 0.72, 0.55]`,
  night `[0.55, 0.50, 0.62]`, vignette `0.4` — `day` stays identity
  `[1,1,1]`, unchanged) plus a new per-arena mood mechanism for
  `cave_mouth`. Iterated the inn values the same way the pilot did:
  staged each candidate into the `inn.day` slot + a temporary
  `meta.light_energy_by_phase.day = 1.0` (so hearth/grill light up during
  the peek too), shot `atmosphere_check windowed`'s `00_start_day.png`,
  judged it, then reverted BOTH back to identity/0.0 before writing the
  real dusk/night values — day-phase behavior for every canonical script
  never actually changed at any point this task, only the throwaway
  local screenshots did. **Arena mood pin (resolves the B1 plan's open
  question):** B1 found a combat arena has no CanvasLayer of its own, so
  it shares the world SubViewport's one CanvasModulate with the field and
  inherits whatever mood is currently applied for free — correct for
  `goblin_ambush`/`training_yard` (open-air) but wrong for `cave_mouth`
  (a cave fight at midday inherited the field's bright day grade).
  `data/moods.json` gained a new top-level `arena_moods` dict (parallel
  to `moods`, keyed by ARENA id, same day/dusk/night/vignette shape);
  `cave_mouth`'s entry is time-invariant (`[0.30, 0.32, 0.45]` on all
  three phases, vignette `0.45` — a cave is dark regardless of the hour
  outside it). `atmosphere.gd` gained `apply_arena()` (same job as
  `apply()`, reads `arena_moods` instead of `moods`) plus
  `_in_arena_override`/`_active_arena_id` state: `COMBAT_STARTED` checks
  `Game.sim.combat.arena_id` against `arena_moods` and only switches to
  the pinned color when an entry exists — an arena without one (every
  arena except `cave_mouth`, today) is untouched, so `goblin_ambush`/
  `training_yard` keep inheriting the field's grade exactly as before
  this task. `PHASE_CHANGED` mid-combat re-applies whichever source
  (pin vs. field) is currently active instead of a phase crossing
  clobbering an active pin back to the field's color; `UI_COMBAT_HIDDEN`
  restores the field's own mood if a pin was active. **No light anchors
  were added to `cave_mouth`'s arena decor** — `board_renderer.gd`'s
  arena-decor rendering path (`_build_arena_decor`/`_make_decor_visual`)
  has no `light` dict handling at all (unlike `world.gd`'s field-decor
  path from B2), and wiring that in is a `board_renderer.gd` change,
  outside this task's file scope; the dark mood pin alone already reads
  as "genuinely dark" (verified by a windowed `chieftains_raid` shot —
  see the task report) — light pools in the cave are flagged as follow-up
  polish, not required to ship the core look. **Title ember drift:**
  `src/ui/title_screen.gd`'s `_build_ui()` now calls `_build_embers()`,
  which spawns one `WIAmbience.make("embers", ...)` GPUParticles2D sized
  to the full native 1280×720 window rect (title is native-res UI
  entirely outside the world SubViewport, per `atmosphere.gd`'s B1
  finding — no CanvasModulate applies here, so this is the one
  atmosphere touch with no mood grade behind it). Added right after the
  backdrop and before the ribbon/menu/notice panels so it always draws
  BEHIND them (tree order = draw order within one CanvasLayer); not
  phase-gated (title has no time-of-day) and not registered with
  `WIAtmosphere` (that registry is for the world viewport's own lights/
  emitters only) — it just emits continuously. QA: full 30-script sweep
  (pinned seeds) + 13 units + `load_gate`/smoke all green, zero
  `SCRIPT ERROR`/warning lines; `title_flow` unaffected (embers are
  presentation-only, assert nothing). Windowed proof shots (inn dusk,
  title embers, `cave_mouth` combat under the new dark grade) live in
  `.superpowers/sdd/fp-handoff/r1-shots/`.

- **Atmosphere rollout R2: gate district "torchlit stone" + 3 art fixes
  (M-BEAUTY Task R2, 2026-07-05):** tunes `data/moods.json`'s `street`
  entry for real (`day` stays identity `[1,1,1]`; `dusk`
  `[0.35, 0.40, 0.65]`; `night` `[0.24, 0.28, 0.48]`; `vignette 0.44`,
  above the pilot's 0.4 floor per the card's "night-leaning map" call).
  Both phases are darker/cooler than floodplains' own dusk
  (`[0.45, 0.50, 0.92]`); `night` is additionally darker than
  floodplains' own `night` (`[0.30, 0.36, 0.72]`) — the district reads
  dark regardless of hour, same spirit as R1's `cave_mouth` pin at a
  shallower depth. Iterated 2 candidates the same staged-day-slot way
  as the pilot/R1 (temporary `meta.light_energy_by_phase.day = 1.0`,
  reverted before shipping); shipped `dusk`/`night` mirror floodplains'
  own dusk-lighter-than-night progression. **Light anchors:** the 3
  street sconces + `sewer_grate` already existed (B2); R2 lights the
  two street `campfire` decor entries (`[3,5]`/`[13,10]`) that B2
  deliberately shipped unlit (`color: [1.0, 0.55, 0.25], energy: 1.0,
  radius: 34, flicker: true`) — see the light-layer block above for the
  now-superseded "deliberately unlit" note. Street now carries 6 lights
  (3 sconces + grate + 2 campfires), inside the ≤8/map budget. **Fold-in
  art fixes (the three street VISUAL-LOG entries; full before/after in
  the doc's Fixed section):**
  1. **Roofs misaligned:** the street building at `(18-21,15-16)` had
     two `inn_roof` decor pieces (`(19,15)`/`(21,15)`) but only one
     `facade_plaster` wall, at an unaligned `x=20` under neither roof.
     Realigned to the Adventurer's Guild building's own precedent (two
     roof/facade pairs at MATCHING x): moved the facade to `(19,16)`,
     added a second at `(21,16)`.
  2. **Dark Cellar door freestanding:** `cellar_door` (street entity,
     `10,17`) is a quest interactable whose `crate_light` approach path
     is a hardcoded step sequence ending at that exact cell — moving it
     would desync that script, so per the task's own brief this dressed
     AROUND the cell instead: one `facade_plaster` tile at `(11,17)`
     (east of the door, on a row/column the approach path never
     crosses). `crate_light` re-verified green untouched.
  3. **Scatter "fake grate" discs:** root cause was NOT the `scatter`
     pool (`pebble`, the nearest-by-name suspect, was cleared by both a
     live render-dump and an empirical pool-removal test — the
     discs persisted with `pebble` removed and even with `scatter`
     emptied entirely). The actual cause: `campfire` and `sconce` share
     the exact same source art (a stone ring with red embers,
     `Bonfire_01-Sheet.png`) — unlit, that reads identically to
     `sewer_grate`'s own placeholder rock art. Lighting the two street
     campfires (fix above) doubles as the fix: a flickering warm glow
     at dusk/night is unambiguous fire, while the grate keeps its own
     distinct steady green glow. The DAY-time passive resemblance
     (light energy 0 by the ship-neutral-first convention) is
     unchanged — that residual traces to the separately-logged,
     still-open "`sewer_grate` is placeholder rock art" VISUAL-LOG item,
     out of this task's 3 assigned fixes.
  QA: full 30-script sweep (pinned seeds) + 13 units + `load_gate`/smoke
  all green, zero `SCRIPT ERROR`/warning lines; `crate_light` specifically
  re-verified (the only fix touching a quest-interactable's neighborhood).
  Windowed proof (day fixes + 2 staged mood iterations + a REAL,
  non-staged 40-action dusk crossing on the street map) live in
  `.superpowers/sdd/fp-handoff/r2-shots/`.

- **Label removal + visual affordances + first-pickup hint (M-BEAUTY R3,
  2026-07-05, spec §8 addendum + onboarding spec §9 interim):**
  - **Field name tags GONE.** `world.gd` no longer touches `WIWorldLabels`
    at all — `_rebuild_field_labels`/`_label_entry`/`_world_labels()`/
    `_set_world_label_context` are deleted, the `label_id`/`label_name`/
    `label_offset` metadata on entity holders is gone, and
    `_make_entity_visual`'s signature dropped its `label_text`/
    `show_label` params entirely. `ui_world_labels_rendered` RETIRED as an
    event (both emitters gone, the `WIEvents` const removed, both QA
    count-asserts removed from `inn_walkthrough.json`/
    `combat_walkthrough.json`).
  - **Combat name tags GONE, HP/MP readout STAYS.** `board_renderer.gd`'s
    `_rebuild_combat_labels` publishes `id`/`anchor`/`offset` only (no
    `name`) — HP bars (`_hp_bars`/`_mp_bars`, plain in-board ColorRects,
    never part of WIWorldLabels) are completely untouched, and the HP/MP
    NUMERAL readout ("57/80  MP 12/20") still rides `WIWorldLabels`'
    `stats` line via `apply_stats`/`set_stats` — name and stats were
    ALREADY two separate sub-labels pre-R3 (`_make_panel`'s `Name`/`Stats`
    Label children), so no "split a composed label" work was needed, just
    delete the name half. `combat_hud.gd`'s turn-order strip (top banner,
    "Turn: Relc | > Traveler | Goblin Shaman...") is the sanctioned name
    surface the spec calls out — unaffected, already text-based, not a
    floating tag. Dialogue keeps speaker names (panel text) unchanged.
  - **`WIWorldLabels` survives, COMBAT-ONLY, STATS-ONLY** (`src/ui/
    world_labels.gd`): the `Name` sub-label and `NAME_HEIGHT` const are
    deleted from `_make_panel`/`rebuild_context`; `PANEL_SIZE` shrank to a
    single stats row. The journal's `CanvasLayer.layer = 10` fix (M6.5 UI
    wave item 11, guards against `WIWorldLabels` bleeding over the
    journal's opaque parchment) is UNCHANGED and still load-bearing — the
    combat stats overlay is still a `WIWorldLabels` CanvasLayer at the
    default layer otherwise, and `WIMain.world_labels()` still lazily
    creates it the same way (now first invoked from `board_renderer.gd`'s
    `build()` instead of `world.gd`'s field rebuild). The exact field-side
    bleed-through this fix originally targeted can no longer occur at all
    (field labels don't exist to bleed) — see `docs/VISUAL-LOG.md`'s Fixed
    section.
  - **`visual_states` seam** (presentation-only, `world.gd`): a `prop`/
    `npc` entity record may carry `visual_states: [{when: {...}, sprite?,
    tint?, light?}]`. `_resolve_entity_render(ent)` evaluates every entry
    against `_visual_state_active` and folds in the LAST satisfied
    entry's fields over the base `sprite`/`tint`/`light` (ascending-
    threshold authoring convention, same idiom as `classes.json` level
    tables — a later, higher threshold overrides an earlier one, an
    unmet entry never masks the base look). Two `when` shapes shipped:
    `{"counter": id, "at": n}` (true once `Game.sim.accomplishment_count
    (id) >= n`) and `{"container_opened": true}` (true once
    `Game.sim.container_state.get(entity_id, false)`). Used by BOTH the
    initial `_build_entities()` build (a loaded save already past
    threshold renders the post-state immediately, never the pre-state)
    and `_refresh_entity_visual(id)` (re-renders ONE entity's holder in
    place — `queue_free` the old, `_make_entity_visual` a new one at the
    same cell — never a full `_rebuild_field()`). Two bus listeners drive
    the live re-render in `_on_domain_event`: `ACCOMPLISHMENT_RECORDED`
    (synchronous with the sim — `record_accomplishment` sets the counter
    THEN emits, so no deferral needed; `_refresh_entities_watching_counter`
    scans `_entity_visuals` for any prop whose `visual_states` names that
    counter) and `ITEM_GAINED` (the container case — `source` is the
    container's own entity id, but `WIGame._interact_container` sets
    `container_state[id] = true` AFTER every contained item's `pickup()`
    call returns, i.e. AFTER this event fires for the earlier items in a
    multi-item chest — `call_deferred("_refresh_entity_visual", source_id)`
    re-checks on the next idle frame, by which point the whole synchronous
    `interact()` call has completed). No sim-visible event/counter was
    missing — presentation reads existing counters/events exactly as
    briefed; `wi_game.gd` was NOT touched.
  - **Shipped visual_states data** (`data/skeleton_scene.json`, inn):
    `dirty_table` — base `tint: [0.62,0.56,0.46]` (dirty, vs `table_brown`'s
    untinted look — the same region/scale, distinct only by tint, per
    spec §8 pt.1's "tint is a valid distinct-at-a-glance method"); on
    `cleaned_the_inn >= 1` swaps to `sprite: "table_brown"` + identity
    tint `[1,1,1]` — i.e. becomes visually IDENTICAL to the inn's other
    (already-clean) tables, which is exactly correct thematically. Windowed-
    verified distinct at 3x zoom, subtle at 1x (VISUAL-LOG follow-up
    logged for a stronger dirty-region pick). `unlit_lantern` — on
    `lit_the_common_room >= 1`, brightens tint (`[1.4,1.25,0.75]`) AND
    spawns a small warm `light` (`color:[1,0.85,0.5], energy:0.55,
    radius:14, flicker:true`) via the SAME `_spawn_light` B2 already built
    — reads as a strong, unmistakable glow (windowed-verified: tiny grey
    unlit sprite -> a bright warm-green-yellow orb). `inn_chest` — on
    `container_opened` (i.e. emptied), tints cool-grey (`[0.5,0.52,0.58]`,
    iterated up from an initial too-subtle `[0.72,0.68,0.62]` after a
    windowed read showed no visible difference — see VISUAL-LOG for the
    open-lid-sprite follow-up this tint substitutes for). `inn_chest` ALSO
    got a `render_scale` bump 0.5 -> 0.75 (unrelated to visual_states,
    a plain affordance fix from the audit below — at 0.5 the chest was a
    near-invisible dark smudge against the alcove floor, confirmed by a
    windowed crop; 0.75 reads as a proper chest at a glance).
  - **First-pickup I-hint** (onboarding spec §9 interim, `message_layer.gd`):
    a one-time "Press I — your pack." toast on the FIRST `ITEM_GAINED`,
    presentation-side-only, never in save data. **The trigger surface,
    honestly (R3 review fix): once per SESSION-SCOPED STATIC, re-armed on
    GAME_RESET only.** `_first_pickup_hint_shown` is a `static var`
    (statics live on the script resource, preloaded for the whole process
    by main.gd's `MESSAGE_LAYER_SCRIPT` const), so it survives every
    MessageLayer teardown/respawn — GAME_LOADED (defeat-reload, pause
    Load, title Continue) does NOT re-show the hint in the same sitting
    (the pre-fix instance var was wiped by the defeat-reload respawn and
    re-showed it). GAME_RESET (title New Game; defeat with no autosave)
    RE-ARMS it via a SCRIPT-BOUND bus connection (`Callable(get_script(),
    ...)`, hooked once per process): traced necessity — pause-menu "Quit
    to Title" frees every UI layer with no reset event, then title "New
    Game" fires GAME_RESET while NO MessageLayer instance exists, so an
    instance-bound listener would miss that re-arm. Verified end-to-end
    by a throwaway windowed script (3 pickups across load + quit-to-title
    + New Game → exactly 2 hint renders, events.jsonl-grepped; shots
    `inn_06`/`inn_07` in r3-shots/). The hint itself bridges `ITEM_GAINED`
    -> the very next `TOAST` (pickup() ALWAYS emits `TOAST` unconditionally
    right after `ITEM_GAINED`, same synchronous call, the only
    `ITEM_GAINED` emission site in the sim) via the instance-var
    `_first_pickup_hint_pending`, so the hint enqueues immediately behind
    the "Got: X" toast in `_toast_queue`, never before it.
    **QA fallout (found by this task, not this task's bug to leave
    unfixed):** the hint is one EXTRA toast in the FIFO queue — any script
    with an UNQUALIFIED `wait_for_event ui_toast_rendered` after the
    game's first pickup now matches the HINT's render instead of the
    NEXT real toast's (confirmed: `work_loop.json`'s `00b_stew_pot_
    locked_toast`/`01_clean_toast` screenshots showed the WRONG toast
    text before the fix). Fixed by qualifying the wait (`payload_contains`
    the hint's exact text) right after the chest-pickup toast wait in
    `work_loop.json` — `inventory_loop.json` was ALREADY immune (its own
    waits were already qualified, the established repo pattern for
    exactly this toast-race class, see its own doc comment on the
    Relc-gift toast).
  - **Affordance audit** (spec §8's per-map pass, windowed, controller-read
    — inn/street/floodplains): every interactable checked reads via
    sprite/color alone with labels off — NPCs (Erin, Krshia, gate_guard,
    watch_sergeant, Selys, Relc) via distinct sprite/tint/silhouette,
    names discoverable through dialogue panel text (by design, spec §8
    pt.3); goblins read as small green humanoids (genre-convention
    color-coding); props (tables, chest, lantern, stew pot, campfires,
    sconces, sewer_grate) all carry pre-existing R1/R2 fixes or this
    task's visual_states. No NEW blocking affordance gaps found beyond
    the two already-open VISUAL-LOG items this task's audit reconfirmed
    (`stew_pot` reusing the `grill` look; the outfit-layer PC). Two
    obsoleted VISUAL-LOG items closed by this task's root-cause removal:
    the journal-bleed-through label item and the "enemy labels overlap
    the hotbar" item (both were about labels that no longer exist).
  - QA: full 30-script sweep (pinned seeds) + 13 units + `load_gate`/smoke
    all green, zero `SCRIPT ERROR`/warning lines. Windowed proof (inn
    dirty/clean table + patron scene + lantern unlit/lit + chest opened +
    first-pickup hint toast; combat with/without labels; 4 street vantage
    points; 5 floodplains vantage points) lives in `.superpowers/sdd/
    fp-handoff/r3-shots/`.

- **Combat presentation components (M6.5 decomposition, 2026-07-04):**
  `combat_screen.gd` (681 lines, was 2062) is ONLY the mode FSM +
  `_unhandled_input` dispatch + `_on_domain_event` bus hub + lifecycle +
  composition root — the single place the 4 combat commands
  (attack/use_skill/dash/end_turn) + `Game.sim.resolve_combat()` are
  called. Components, each constructed via loose-typed `load().new()`
  (bare class_name refs break `test_combat_visuals`'s --script-mode
  stub compile). Autoload-free discipline applies ONLY to the components
  the test lazily load()s through compat shims — `combat_playback.gd` +
  `combat_hud.gd` (+ `targeting_controller.gd` as future-proofing), whose
  autoload touches route through one-line screen wrappers.
  `board_renderer.gd` references ObservableBus/TestDriver DIRECTLY (it is
  only ever built by the real _ready() path, never under the test stub) —
  do not "fix" it to be lazy-loadable, and never lazy-load it from a shim:
  `combat_view.gd` (WICombatView — the ONLY sanctioned UI→sim read
  surface; thin verbatim getters), `board_renderer.gd` (arena board via
  `WITileBoardBuilder` [shared with world.gd — src/world/
  tile_board_builder.gd], combatant visuals/anims/bars/labels),
  `combat_playback.gd` (the M4 T10 paced AI queue — capture-at-enqueue
  / no-live-reads-on-dequeue invariants live HERE now),
  `combat_hud.gd` (panels/hotbar render/readout/feed [wrapped-line
  budgeting]/tutor [count/render split]/banners; slot DATA stays on the
  screen, HUD renders from passed state), `targeting_controller.gd`
  (aim filters/cycle/confirm — fresh per combat, returns actions, never
  executes them). New presentation code goes IN the matching component,
  never back into combat_screen.

- **UI wave (2026-07-04, playtest directives 15/11/19 + M6.5 final-review
  cleanup F2/F3):**
  - **(15) Dash confirm gate** — see the "Combat controls" block above.
  - **(19) Journal skills-by-class panel:** `WIGame.used_skills` is a SET
    (`Array[String]`, additive save field, tolerant default `[]` — see
    save.gd) recording every skill id the PC has ever actually used/cast,
    fed from BOTH the exploration `use_skill` path AND combat (`WICombat.
    used_skills_tally`, populated in `spend_skill_costs` alongside
    `action_tally`, merged into `used_skills` by `WIGame.resolve_combat`
    UNCONDITIONALLY — i.e. NOT gated by the same `trivial` flag that
    suppresses `_bank_action_tally`'s accomplishment bank, so a trivial
    spar still reveals a skill's description after its first real use).
    `WIGame.skills_journal()` builds the grouped-by-class display data
    ("Innate" from `player_skills`, then one group per held class in
    classes.json catalog order, each carrying its own + any
    `inherits`-chain ancestor's grants — a local duplicate of
    `WIProgression`'s own/inherited-grants walk, since progression.gd
    wasn't in that task's edit scope); pre-first-use a skill's `text` is
    NAME ONLY, post-first-use "NAME — description" (opacity: static text
    only, never a number). `journal.gd` renders it via a scrollable
    BBCode `RichTextLabel` and extends `ui_journal_shown`'s payload
    (`skill_groups`, `skill_count`, `revealed_skills`, `quest_lines`) so
    QA can assert the panel's structure/reveal state without OCR. QA:
    `journal_skills` (seed table above).
  - **(11) Journal layout:** `journal.gd`'s `CanvasLayer.layer` is now
    explicitly `10` — `WIWorldLabels` (at the time, world-space name labels)
    was created lazily by `world.gd` AFTER `Main._spawn_ui_layers()` adds the
    journal, so with both left at the default layer (1) the labels painted
    OVER the journal's opaque parchment; an explicit higher layer wins
    regardless of add order. **M-BEAUTY R3 update (2026-07-05):** field name
    labels are RETIRED (spec §8 addendum — see the Architecture entry below),
    so the exact bleed-through this fixed can no longer occur on the field
    side; `WIWorldLabels` itself survives combat-only (HP/MP stat readout,
    `WIMain.world_labels()` is still lazily created the same way from
    `board_renderer.gd`'s first `build()` call), so `layer=10` is UNCHANGED
    and still load-bearing — do not revert it. Panel grew 560×430 → 640×560
    for the new skills section.
    **`_bb_escape` self-collision bug (found while building the journal,
    ALL THREE copies fixed by the wave's review pass):** the naive
    `s.replace("[", "[lb]").replace("]", "[rb]")` chain garbles every
    bracketed name — the first replace's own output (`"[lb]"`) contains a
    `]` the second replace re-matches (e.g. `"[Power Strike]"` →
    `"[lb[rb]Power Strike[rb]"`; was user-visible on the combat slot-info
    line). Fixed with a placeholder-char technique in `journal.gd`,
    `combat_hud.gd`, AND `targeting_controller.gd` — kept as three
    per-file copies with cross-referencing doc comments (the M6.5
    zero-cross-dependency idiom; a shared UIChrome home was considered
    but per-file copies preserve each component's documented load()
    story). Any NEW `_bb_escape` copy must use the placeholder form —
    never the naive chain. `combat_move_input` pins the escaped slot-info
    payload text for `[Power Strike]` as the regression tooth.
  - **(F2/F3) M6.5 final-review cleanup:** deleted 4 truly-dead
    `combat_screen.gd` compat shims (`_drain_playback`/`_beat_delay`/
    `_build_bar_slots`/`_render_bar_slots`) and their matching
    `tests/test_combat_visuals.gd` has_method asserts — `_capture_
    playback_event`/`_feed_line_for_event` are LIVE (real callers in
    `combat_playback.gd`) and were left untouched. Deleted `combat_hud.gd`'s
    dead `_grey()` (and its now-orphaned `LOCKED_COLOR` const, which had no
    other caller).

## Working conventions

- When you add ANY player-visible feature, extend a QA script (or add a new one
  in `qa/scripts/`) that walks it and asserts both the domain event AND the
  `ui_*_rendered` confirmation, then run it before claiming the feature works.
- Content is data + code: new entities/skills go in `data/*.json`; new
  behavior goes in the sim; presentation only renders.
- Tests are plain SceneTree scripts under `tests/` (no GUT/gdUnit). Pure
  classes only — anything needing autoloads is QA-script territory instead.
- Balance changes are `combatants.json`/`skills.json` edits validated by
  `sim_combat_batch.gd` (GATED cells win-rate 0.55-0.95, median rounds 3-12;
  `goblin_ambush/warrior2` is measured-only by user directive — see the M3
  block above) — never tune by feel. Changing combat data or rules can
  invalidate the canonical QA seed: re-verify
  `combat_walkthrough`/`level_up_loop` and update the seed here and in this
  file's Commands section if needed.
- GDQuest GDScript style: tabs, static typing, `class_name` + `##` doc comments.

## Gotchas

- `CanvasLayer` has no `modulate` — tint/fade child Controls instead (this
  exact bug shipped a dead quest chain in v2).
- **Godot 4.7 `ResourceLoader.load()` returns a NON-NULL but uncompilable
  script resource when a .gd has a parse/compile error** — null-checking load()
  is not enough; the load gate also checks `Script.can_instantiate()`.
- `--script`-mode runs don't resolve autoloads as bare identifiers — that's why
  the purity rule exists; don't reference autoloads from `src/core/wi_game.gd`,
  `event_log.gd`, `qa_paths.gd`, or `tests/`.
- Commit generated `*.uid` sidecars alongside new `.gd` files.
- **Sprite frames with transparent padding below the figure need a measured
  `anchor`** (data/sprites.json). Feet-anchoring uses the FRAME bottom, so
  Body_A/Citizen_F's 16px under-feet padding (figure y 18–47 of 64) drew every
  character exactly ONE CELL above its logical cell — the player aligning with
  a door/prop visual was physically a row off, and interact hit nothing. Fixed
  with `anchor: [0.5, 0.75]`. When adding any new character/prop sheet, measure
  the figure's bbox (PIL alpha scan) and set the anchor from the FEET PLANE,
  not the frame edge; verify with a windowed adjacency screenshot.
- Web QA seeding (M3 T8): `run_web_qa.sh <script> <seed>` threads the seed
  through `run_web_qa.mjs` -> `window.__WI_QA__ = {script, seed}` ->
  `game.gd._build_sim` reads it via `JavaScriptBridge.eval(...)` only when
  `OS.has_feature("web")` AND no `--seed=` user arg was given natively. Only
  `game.gd` reads the *seed* off the bridge (`qa/test_driver.gd` already uses
  `JavaScriptBridge.eval` for script-name/screenshot/result plumbing) — the
  sim core in `src/core/**` never touches the bridge, so sim purity is
  unaffected.
  Combat QA scripts are now web-runnable (parity with native); `load_gate`
  remains native-only (see above).
- `WICombatAI.take_turn`'s `_act_once` defaults an empty `"ai"` field (the
  PC's own combatant config) to the **melee** profile, which never inspects
  ranged/spell skills. This means `combat_autoplay` will NEVER cast a spell
  for the player character, no matter the seed or which classes it holds —
  `mage_unlock_loop` verifies the mage kit via `combat.combatants.pc.max_mp`
  (only nonzero when a known skill carries `mp_cost`) instead of an
  actually-observed cast. Similarly, `action_refused {reason: "no_los"}` is
  unreachable under AI-only play: `_act_ranged` pre-filters targets with an
  explicit `has_los` check, while `_act_line` filters *indirectly* —
  `line_cells` truncates at the first blocked cell, blocked cells can't hold
  combatants, so a wall-obstructed direction can never satisfy its
  ≥2-enemies-hit gate. It's a dead-code safety net under AI play, not a
  reachable QA event. (Player path: single-target spells are also
  pre-filtered — `combat_screen.gd` drops non-LoS targets before selection —
  so the refusal is live only via the player's line-skill direction picker,
  which has no such filter.) `line_of_sight_denial`
  instead proves the has_los gate positively: `flame_bolt` (a wall-aware
  ranged cast) resolves successfully and `action_refused/no_los` never
  fires, using the `goblin_ambush` arena (the only arena with a ranged
  enemy) rather than the walled-but-all-melee `chieftains_raid` roster.
  `level_up_loop`'s fight 2 was swapped from `goblin_encounter_1` to
  `chieftains_raid` for the same structural reason: in `goblin_encounter_1`,
  `relc` (ally) is always the lowest-HP/nearest target and the lone melee
  enemy dies before ever reaching the PC, so `counter_strike` (riposte) can
  never trigger there regardless of seed; `chieftains_raid`'s 3 melee
  enemies give the PC a real chance of being hit (win rate 0.61 per the
  balance harness — hence needing an explicit seed search rather than a
  first-seed-tried pick).
- **PC death is an immediate DEFEAT, even with a living ally (WAVE A2 §7,
  post-D4 user-confirmed directive).** `_check_end` in `wi_combat.gd` checks
  `combatants["pc"]["alive"]` FIRST, before the team-wipe scan — previously
  a fight only ended in defeat when BOTH the pc and every ally were down, so
  a fight where the pc dies mid-round but an ally (`relc`) survives used to
  CONTINUE and could still resolve as a win (the ally mops up the rest).
  That is exactly what broke `level_up_loop`'s old seed 11: fight 2
  (`chieftains_raid`) had the pc go down at round 3 with `relc` alive and
  `goblin_chieftain` at 4 HP, previously won when `relc`'s next turn finished
  the chieftain off — now an instant defeat. Re-derived to seed 12 (wins fight
  2 outright, still fires `reaction_triggered{counter_strike}`). **Any future
  combat-data or sim change must be re-checked for this same failure mode**:
  a canonical seed that used to win via "pc goes down, ally carries the
  win" no longer can — search for a replacement where the pc actually
  survives, don't assume the old win margin still applies. `sim_combat_batch.gd`
  is unaffected structurally (`combat.outcome["victory"]` already reflects
  whichever branch `_finish` took), but gated-cell win rates can shift because
  losses no longer require every ally down too — re-run the harness after any
  defeat-condition change, not just after data changes. The rule's canonical
  QA proof is `defeat_ally_alive` (seed 11, table above) — it re-verifies
  "PC dies while Relc lives = instant defeat" through the real
  input/AI/UI path on every sweep.
- **Message panels budget WRAPPED LINES, not entries (M-FP F fix — keep it
  that way).** The combat feed (`combat_screen.gd`) and the world
  `dialogue_line` panel (`message_layer.gd`) both fit text by measuring
  wrapped visual lines at panel width (`Font.get_multiline_string_size`;
  line pitch = font height + theme `line_spacing` — the string-size call
  does NOT include line_spacing, a real trap) and then EVICT the oldest
  feed entries / TRUNCATE with ellipsis until the total fits the panel's
  art-safe capacity (the parchment's bottom fold bleeds above the naive
  margin — feed effective text height is 90px, not 106). Design rule
  D2-7 #6 is binding: cut words, never widen the UI. The dialogue panel
  truncates only the ON-SCREEN string — `ui_dialogue_rendered` still
  carries the full text (QA asserts it exactly). Any future panel or
  `tutor_lines` copy change: re-verify with windowed `relc_tutorial` +
  `gate_district_walkthrough` runs, read by eyes.
- **Onboarding rev Task O1 (2026-07-05): classless start.** `data/skeleton_scene.json`'s
  `player.classes` is now `{}` (was `{"warrior": 1}`) — the PC starts with NO
  class and NO combat skills; the combat hotbar (`combat_hud.gd`'s
  `rebuild_slots`, which just iterates `c["skills"]`) degrades gracefully to
  Attack/Dash/End Turn only, and the journal's skills panel
  (`WIGame.skills_journal`) shows only the "Innate" group, no crash either
  way (traced, not assumed — both loops are empty-safe by construction).
  `warrior` is now EARNED via `gained_by: {accomplishment: {sparred_with_relc: 1}}`
  (mage's `used_magic` precedent shape) — `sparred_with_relc` is banked by
  the shipped `relc_spar`/`training_yard` encounter's `on_victory`, so the
  first post-spar sleep grants Warrior 1 (the full 4-skill kit) with zero new
  machinery, same as mage's `check_class_gains` path. The player still spawns
  with `rusty_sword` equipped (the M7 equipment default, untouched by this
  task) — classless + sword-equipped is a real reachable state: the kit stays
  empty regardless of what's equipped (`_weapon_gated_kit` filters an EMPTY
  input kit to an empty output), so the sword sits inert until Warrior is
  earned. Training dummies (`training_dummy_a`/`_b` in `data/combatants.json`)
  now carry `"ai": "inert"` (new `combat_ai.gd` profile, `_act_once` returns
  `false` on its first call every turn — never moves/attacks/uses a skill,
  turn ends immediately) plus `weapon_die: 0` as belt-and-braces documentation
  — **note the actual damage floor**: `wi_combat.gd`'s melee resolution does
  `damage = maxi(1, base_damage)`, so a hit landing ALWAYS deals >=1; "zero
  damage" is only real because inert dummies structurally never call
  `attack()` at all, not because `weapon_die: 0` forces a zero roll. **THE
  RE-PATH WINDOW IS NOT YET CLOSED (Task O5, next):** every canonical QA
  script that asserted a level-1 Warrior kit fielded from fight 1 (no
  spar-first prologue) reds under this change until O5 lands a fixture/prologue
  fix — see `.superpowers/sdd/fp-handoff/task-o1-report.md` for the exact
  red/green table from the disclosure sweep. Units are unaffected: every
  `tests/test_sim_core.gd` fixture that intended a classed PC (Task 7's `g`,
  `g4`, and the weapon-gate kit-intersection sub-cases `e2`/`e2b`/`e2c`/`e3`)
  now seeds `.classes = {"warrior": 1}` explicitly right after construction,
  preserving each test's original intent against the new classless default.

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before
implementing any game system, you MUST check for a matching `godot-prompter:*`
skill and invoke it. This applies to all agents, subagents, and sessions
working in this repository.

Key skills: `gdscript-patterns`, `scene-organization`, `component-system`,
`resource-pattern`, `event-bus`, `godot-ui`, `state-machine`, `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.
