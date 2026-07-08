# Architecture History

This is the detailed, verbatim per-milestone architecture record for
`wandering_inn_game/`. `../CLAUDE.md` keeps only a short, current-state
summary paragraph per live system, each pointing here for the full
mechanism writeup, rollout narrative, and the reasoning behind design
decisions. Read this when you need the "why" behind a system, not just
the "what" — for day-to-day work, `../CLAUDE.md` alone should suffice.

Sections are in roughly chronological (milestone) order. A `[RESOLVED ...]`
or similar bracketed note inside a block means the 2026-07-07 CLAUDE.md
accuracy audit found and fixed a stale claim in that block; the rest of
each block is preserved as originally written, including author framing,
task names, and self-references to "this task"/"this block".

---

## Core systems (M0–M3): sim core, ObservableBus, combat, story spine, character creation


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
  is built in code; content lives in `data/*.json`. No hand-authored .tscn beyond the
  trivial `src/world/main.tscn` root (the actual `run/main_scene` per
  `project.godot` — `src/world/world.tscn` is a byte-identical but
  ORPHANED duplicate nothing references; safe to ignore or delete). **FIELD HELD-KEY MOVEMENT**
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

- **Character creation (M-ARC §5; picker recomposed by issue #42):** New Game →
  `char_creation.gd` (native-res, title-family UIChrome): a single PICK step —
  a 2x3 grid of the six PC sprite variants (`PC_OPTIONS`, row-major: top row
  Male across Human/Drake/Gnoll, bottom row Female), each card an
  idle-animated `AnimatedSprite2D` built from `WISpriteRegistry.frames_for`
  (playing `idle_down`, uniformly scaled to a fixed on-screen portrait height
  regardless of each race's native frame size) inside the same
  `UIChrome.make_chrome_panel`/`BLUE_BUTTON`/`BLUE_BUTTON_PRESSED`
  cursor-highlight idiom the title screen's row menu uses — arrows move the
  cursor across the grid (`move_left/right` change column/race, `move_up/down`
  change row/gender), confirm picks the highlighted card and sets
  `pc_race`+`pc_gender` TOGETHER — then a NAME step (default "Traveler"),
  unchanged. Three COSMETIC sim fields — `pc_name`/`pc_race`/`pc_gender`
  (WIGame, additive save, NO version bump, tolerant sanitizers; NO mechanical
  effect, no sim rule branches on them) — are BYTE-IDENTICAL to the pre-#42
  two-step race→gender menus; this was a presentation-only recomposition, no
  sim payload change. Flow: title New Game → `WIMain.swap_to_char_creation`
  (deferred) → confirm fires `Game.reset({pc_name,pc_race,pc_gender})`,
  threaded ctor→sim; a load restores identity from the save (never sees the
  creation dict). **QA:** `TestDriver` auto-skips creation with the everyman
  defaults (Human/m/"Traveler") — the creation screen is only ever SPAWNED
  when actually wanted (real play, or a QA script that opts in via top-level
  `creation_ui: true` → `TestDriver.wants_creation_ui()`); the default skip is
  byte-identical to the pre-feature New Game. `char_creation` is the one
  canonical driving the real UI (name typed via TestDriver's `type_text`
  unicode step; re-pinned for #42's step shape — `ui_char_creation_rendered`
  now emits `{"step": "pick"}`/`{"step": "name"}`, not the old
  `"race"`/`"gender"`/`"name"` trio). **`pc_name` everywhere:** the combat
  turn-strip/readout name comes from the runtime combatant dict
  (`_build_player_combatant` overrides `display_name` = `pc_name`); field
  name tags were retired (R3) so there is no other player-name render
  surface. **Sprite variant-key indirection (presentation-only, sim purity
  preserved):** the sim builds a pure key `pc_sprite_variant()` =
  `"pc_<race>_<gender>"`; the TWO bind sites resolve it against
  `WISpriteRegistry` — world.gd `_pc_variant_sprite` (field visual) and
  board_renderer `_combatant_sprite_id` (combat chip) — each degrading to the
  data default `body_a` when a variant's art is unregistered. 6 variants
  (human/drake/gnoll × m/f, all in the same earth-tone traveler outfit) via
  the F2 PixelLab v2 pipeline; issue #42's picker is the first UI surface to
  render all six side by side, so it doubles as the live distinct-silhouette
  proof (verified via windowed screenshot, not just data presence). **Opener
  branches by race** (`sleep_veil._opener_lines`): Human keeps the
  otherworlder arrival; Drake/Gnoll get a canon-safe "starting over in
  Liscor" variant (⚑ user taste-review); all 4 lines so the opener-line count
  is race-invariant.

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


---

## Onboarding rev classless-start (Task O1, 2026-07-05)

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
  RE-PATH WINDOW WAS CLOSED BY TASK O5 (2026-07-05):** every canonical QA
  script that asserted a level-1 Warrior kit fielded from fight 1 (no
  spar-first prologue) reddened under this change; O5 re-pathed all of them
  through a fixture/prologue fix — see the O5 block in
  `docs/ARCHITECTURE-HISTORY.md` for the routing model and
  `.superpowers/sdd/fp-handoff/task-o1-report.md` for the original
  red/green disclosure-sweep table. Units are unaffected: every
  `tests/test_sim_core.gd` fixture that intended a classed PC (Task 7's `g`,
  `g4`, and the weapon-gate kit-intersection sub-cases `e2`/`e2b`/`e2c`/`e3`)
  now seeds `.classes = {"warrior": 1}` explicitly right after construction,
  preserving each test's original intent against the new classless default.

---

## Per-milestone architecture blocks (M4 onward)

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
  (ids) + `equipped` {weapon, armor} (+ M-GEAR's `accessory_1`/`_2`/`_3`, see below — 5 keys total as of 2026-07-06, not 2) + `container_state`; field-only
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

- **M-GEAR (resonance gear, 2026-07-06):** G1 added three accessory slots
  (`equipped.accessory_1/_2/_3`, sim-only) and `resonance_capacity` (int,
  default 2, additive-optional save field, no growth mechanism yet) —
  `equip()` refuses a 4th accessory (no free slot) or any equip whose
  resulting total equipped `resonance` (summed across all 5 slots) would
  exceed capacity, each with its own diegetic placeholder toast (grep
  `_CAPACITY_REFUSAL_TOAST`/`_ACCESSORY_SLOTS_FULL_TOAST` in `wi_game.gd` to
  swap final copy). G2 shipped `lore` + real `resonance` values on the full
  19-item catalog (`data/items.json`) plus the Krshia `charms` shop sub-node.
  **G3 (player-facing UI, `src/ui/inventory.gd`):** three accessory slot rows
  alongside Weapon/Armor; the header gained a second visible-currency line
  ("Resonance N/M" beside "Gold: N"); a lore render line per card (between
  the mechanical effect lines and the description, "Lore — " prefix, never
  mixed into `item_effect_lines`); `ui_inventory_shown` gained a
  `resonance:{used,capacity}` sub-dict (byte-compatible add, existing pins
  unaffected — `Game.sim.resonance_used()` is the new public one-liner over
  G1's private `_equipped_resonance_total()`). **Two real pre-G3 bugs found
  and fixed along the way:** (1) the equip/unequip TOGGLE never worked for
  an already-equipped accessory (`equipped.get(kind, "")` only ever matches
  weapon/armor, where kind IS the slot name — an equipped accessory has no
  `equipped["accessory"]` key at all, only `accessory_1/_2/_3` — silently
  refused with no toast; fixed via `_equipped_slot_for(item_id, kind)`);
  (2) the panel's own "Could not equip that." fallback would have DOUBLE-
  toasted on top of G1's own capacity/slot-full refusal toasts the moment an
  accessory-capacity QA path existed — now only fires for a genuinely
  unreachable case (a carryable non-equippable kind, e.g. G2's `tool` items).
  **Refusal surfacing:** traced and confirmed EMPIRICALLY (screenshot) that
  message_layer's toast layer (default `layer` 1) draws BEHIND this panel's
  `layer` 10 — the same overlap class `status_first_encounter` already
  documented for combat_hud/message_layer — so a refusal toast fired while
  the panel is open is genuinely, partially clipped; a new `_status_label`
  mirrors any TOAST into the panel itself while open (safe: no other toast
  source is reachable while the panel intercepts all input). **Full-pack
  scroll fix:** the carried list's `ScrollContainer` has `mouse_filter`
  IGNORE (no wheel wired) and no keyboard-scroll binding, so with the
  catalog now at 19 items the tail was logically selectable (cursor still
  moved) but never actually visible; `_rebuild_items` now calls
  `_scroll.ensure_control_visible` on the cursor's row after every rebuild
  (a double-deferred call — a single `call_deferred` hop can race the
  VBoxContainer's own queued sort after a full rebuild, confirmed
  empirically). QA: `gear_loop` (seed 9, fixture `gear_loop_start`) is the
  canonical proof — see the seed table below for why it's fixture-based
  (a genuine over-capacity refusal needs ~44 gold via the shop, impractical
  to grind naturally in a script).

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
    **SUPERSEDED (M-ARCH Task ARCH-2, 2026-07-07): promoted to
    `UIChrome.bb_escape`** — the three per-file copies consolidated into
    one static (a consultant review flagged the per-file-copy idiom as a
    drift-bomb for a helper this small and hot). A DELIBERATE AMENDMENT
    to the M6.5 idiom, not a reversal: UIChrome was already a
    load-bearing dependency of all three files, so no new dependency
    edge. The idiom still applies AS-IS to per-file copies with no
    natural shared dependency (journal's `_load_combatants_catalog`,
    field_hotbar's wrap/fit helpers). Placeholder technique unchanged,
    byte-identical output; the `[Power Strike]` pin still passes.
  - **(F2/F3) M6.5 final-review cleanup:** deleted 4 truly-dead
    `combat_screen.gd` compat shims (`_drain_playback`/`_beat_delay`/
    `_build_bar_slots`/`_render_bar_slots`) and their matching
    `tests/test_combat_visuals.gd` has_method asserts — `_capture_
    playback_event`/`_feed_line_for_event` are LIVE (real callers in
    `combat_playback.gd`) and were left untouched. Deleted `combat_hud.gd`'s
    dead `_grey()` (and its now-orphaned `LOCKED_COLOR` const, which had no
    other caller).

- **M-LEGIBILITY (L1-L5): `WIEffectText` (`src/core/effect_text.gd`)** is the
  ONE formatter for every player-visible mechanical line — item cards (L2),
  Skill/hotbar cards (L3), the status glossary (L4). Pure/static, VISIBLE-
  CURRENCY only (HP/MP/AP/damage dice+mods/move cells/gold/rounds; raw
  STR/DEX/CON/INT/WIS/CHA and percent-toward are FORBIDDEN in anything it
  emits — `tests/test_effect_text.gd` pins every shipped line,
  `tests/test_content.gd` greps the full catalog). Callers route through
  here rather than hand-composing a mechanical string, so a line can never
  drift from the data it claims to describe.
  **L5 resolved the one known exception to that "never drift" claim:**
  skills.json's `spell_damage.effect.die` field was VESTIGIAL — `wi_combat.gd`
  `_resolve_hit` rolls the CASTER's own `weapon_die` (a fixed per-combatant
  base stat, combatants.json, never touched by equipment) for every hit,
  melee or spell alike, and never read `effect.die` (L1 finding, flagged for
  L5). Fixed at the root: the `die` keys are deleted from skills.json's 7
  spell records, and `_effect_phrase`'s `spell_damage` case now reads the
  honest source via `_caster_weapon_die` (defaults to the "pc" entry in the
  shipped combatants.json — the only caster any shipped UI ever renders a
  Skill card for; a `combatants_catalog` override exists purely for the
  drift-tripwire test, mirroring `status_line`'s existing
  `skills_catalog`-override pattern). Net effect: every player-facing spell
  card now reads "damage 1d6" (the PC's actual weapon_die) regardless of the
  skill — some (ice_shard, flame_scythe, calming_touch) previously showed a
  bigger/smaller die (1d8/1d10/1d3) that the sim never actually rolled.
  **Known residual limitation, disclosed, not fixed further (data-only task
  scope):** `raskghar_maul` (enemy-only, never rendered in any UI) is cast by
  `raskghar_awakened` (weapon_die 9) in the sim, but the formatter has no
  per-caster attribution and defaults to the "pc" catalog entry regardless —
  its `test_effect_text.gd` pin ("damage 1d6") is therefore honest about what
  the FORMATTER does, not what that specific boss actually rolls; real
  caster-threading would need every call site (combat_hud/journal/
  field_hotbar) to pass the ACTIVE combatant's own record through, out of
  this task's data-only/render-only scope.
  **Separately flagged, now SUPPRESSED (fix wave, was NOT fixed at L5 —
  wiring the sim would be a sim-behavior/balance change, out of scope for a
  text-formatter task):** `heal` (second_wind), `icy_floor`, and
  `move_pool_bonus` (quick_movement, battlefield_awareness) have NO consumer
  anywhere in `src/core/combat/` — `WISkillEffects.resolve_active`'s match
  only implements `damage_mult`/`spell_damage`/`line_damage`, and
  `_apply_passives` only implements `hp_bonus`/`hit_bonus` — so these
  Skills' generated cards ("2 AP — restore 8 HP", "+1 move cell", etc.) used
  to promise a mechanic that never fires; all four are reachable in normal
  play (Warrior L3/L4, ice_mage L10, Tactician L1 grants). This was a real,
  user-facing gap (L1's finding #2, re-confirmed by L5); the fix wave closed
  the disclosure hole at the formatter (`effect_text.gd`'s `_effect_phrase`
  now returns `""` for these three effect types, degrading their cards to
  "Name — description", the dangersense idiom — no cost display either,
  since a cost for a non-effect is the worse lie) rather than the sim, so
  the mechanics themselves are STILL not wired — that follow-up (a
  `resolve_active` match arm for `heal`/`icy_floor`, an `_apply_passives` key
  for `move_pool_bonus`) remains queued for the Skills-wave wiring task.
  **Skills Wave Task K2 partially closed the `move_pool_bonus` half of that
  queue — for an ACTIVELY-CAST use only:** `resolve_active` now wires a real
  self-buff resolver for `move_pool_bonus` gated on `ap_cost > 0` (the new
  `[Stealth]` skill's combat read is the first and only consumer), and
  `_effect_phrase`'s `move_pool_bonus` case is un-suppressed for exactly that
  ap_cost>0 shape. `quick_movement`/`battlefield_awareness` are BOTH `ap_cost:
  0` (passive-shaped) and therefore UNCHANGED by this — they still hit
  `resolve_active`'s enemy-gate, find no case, and refuse; their cards stay
  SUPPRESSED. `heal`/`icy_floor` are entirely untouched. See
  `src/core/combat/skill_effects.gd`'s own doc comment for why the gate is
  ap_cost-based rather than a skill-id special case (generalizing to every
  0-cost `move_pool_bonus` skill would have silently turned two previously-
  inert passives into a free, repeatable-every-turn pool exploit).

### THE REQUEST BOARD (M-DEPTH DP2, 2026-07-07)

DP1 shipped the Adventurer's Guild interior with the board/notice-wall
dressed-only (a static toast); DP2 wires the real repeatable-posting
mechanics per the plan's own scope note ("a new data seam... zero new UI").

- **Data**: `data/bounties.json` — a pool of postings (`id`, `pillar`,
  `giver`, `condition`, `gold`, `copy`), assembled verbatim from the writer
  lane's staging doc (`docs/design/board-staging/guild-bounties.json`),
  annotations stripped. 9 of the staging doc's 10 entries shipped live;
  `bounty_crab_cull` stays parked (its condition names a bank,
  `rock_crabs_culled`, that doesn't exist until a future Rock Crab
  encounter lands — the staging doc's own recommendation).
- **Sim (`WIBounties`, `src/core/bounties.gd`)** — pure, no autoload/Node
  refs, following the social.gd/economy.gd extraction pattern:
  - `active_slate(pool, times_slept)` derives the CURRENT 2-3 active
    postings, a window of `min(3, pool.size())` starting at
    `times_slept % pool.size()` — zero rng, the exact talk-pool rotation
    idiom (`chatted_with_<id> % pool.size()`) applied to a pool of RECORDS
    instead of a pool of strings.
  - `condition_met(condition, baseline, accomplishment_count_cb)` — every
    key in a bounty's `condition` dict (the `quests.json` complete_when
    shape) must have advanced by at least its threshold SINCE a baseline
    snapshotted at accept time (DELTA-SINCE-ACCEPT, the staging doc's
    binding semantics call — an absolute read would let a mid-game player
    insta-complete a rotating cull off counters banked before they took the
    posting).
  - `build_picker_graph`/`build_turnin_graph` — construct plain
    `{start, nodes}` `WIDialogue`-shaped Dictionaries FRESH from the
    current slate/accepted state, at runtime, in code (never loaded from
    `data/dialogue/*.json`). `WIDialogue` doesn't know or care where its
    graph came from, so the existing dialogue-panel UI and every QA
    `wait_for_event`(`dialogue_started`/`dialogue_node`/`dialogue_choice`/
    `dialogue_ended`) idiom need no new code path — and because these
    graphs are never registered under `data/dialogue/`, `test_content.gd`'s
    static cross-reference sweep never needs to know they exist.
- **`WIGame` state (all additive save fields, no version bump)**:
  `times_slept` (the rotation clock, incremented unconditionally every
  `sleep()`), `accepted_bounty_id` (one job at a time, v1 simplification),
  `accepted_bounty_baseline` (the delta-since-accept snapshot),
  `board_last_seen_times_slept` (drives the "slate rotated overnight" line,
  shown at most once per rotation). `accept_bounty`/`turn_in_bounty` ride
  EXISTING machinery only, per the plan's scope discipline: a plain
  accomplishment counter (`accepted_bounty_<id>`/`completed_bounty_<id>`)
  and the shared `earn_gold` router (gold_changed + the "Earned N gold."
  toast) — no new event types were added.
- **The two surfaces**:
  - `guild_board` (`board: true`, a `prop`) is BROWSE-ONLY:
    `WIGame._interact_board` assembles the entity's own `toast` (or
    `second_visit_toast` when a posting is outstanding) + the active
    slate's copy + the entity's `observe` footer into a one-option
    (`Step back from the board.`) code-built dialogue. It never mutates
    state.
  - Selys's desk (`selys_delivery.json`) is the transactional surface, per
    board-copy.md sec.2's own framing ("taking a posting means telling
    me"): her hub gained "Take on a posting." (hidden once a posting is
    accepted) and "Turn in my posting." (hidden until one is) — both fire
    a `pending_board_action` signal effect (`open_board_picker`/
    `open_board_turnin`, mirroring `dialogue_choose`'s existing
    `pending_combat` deferred-effect shape) that swaps `dialogue` to a
    fresh `WIBounties`-built graph once the hub conversation ends.
    `accept_bounty` is a THIRD dialogue effect verb, fired from inside the
    picker's own options.
- **`WIDialogue` extension**: `board_accepted` is the SECOND sanctioned
  non-accomplishment `requires`/`hide_when` gate (after `gold`, Economy v1
  D1) — a plain bool read from `WIGame._build_dialogue_ctx`'s ctx (true iff
  `accepted_bounty_id` is non-empty). `_meets`/`_progress_gated` recognize
  it explicitly (hide-until-met, like `accomplishment`, not
  visible-locked like `skill`/`class`); `test_content.gd`'s
  `_validate_requires` recognizes it as a THIRD single-gate-key type so
  authored content using it still passes the "exactly one gate type"
  check.
- **Deliberately NOT a `WIQuests` quest**: no journal entry, no beat text,
  no `quests.json` row — the board is its own data seam, exactly as the
  plan specified, so it never collides with the story-quest machinery.

### The Runner's Guild delivery loop (M-DEPTH DP5, 2026-07-07)

The fourth interior (`runners_guild`, 10x8 off the street's south-east
block — a previously-decorative roof/facade building at x18-21/y15-16
became a real door, `runners_guild_door` (20,17)) and the delivery seam.
The seam RIDES DP2's bounty machinery — extended, never forked:

- **Data**: `data/deliveries.json` — same record family as bounties
  (`id`, `gold`, `condition`, copy) plus the delivery-specific fields
  (`type: "delivery"`, `parcel` {item_id, display_name, flavor},
  `destination` {map, cell, anchor_entity}, `band`, optional `fragile`),
  assembled verbatim from `docs/design/board-staging/runner-deliveries.json`
  (5 of 6 entries; `delivery_hermit_antlers` stays parked until HR-II —
  its staged double-pay hazard vs `hermit_antler_order.json` is resolved
  by shipping NEITHER surface; the reconciliation note travels in the
  data file's own `_comment`). The 5 parcel items are `kind: "parcel"`
  in `items.json`: inert carried flavor, structurally un-equippable
  (equip() only accepts weapon/armor/accessory), no price.
- **The reach condition** (the one genuinely new trace): "reach map/cell
  X with the parcel" can't be an accomplishment threshold directly, so
  `WIGame._check_delivery_arrival` — the smallest honest seam, the
  `_check_trigger_radius` shape reused (Chebyshev distance from a REAL
  `move_player` only; teleport/load can never spuriously complete a
  run) — is the ONE producer of a `delivered_<id>` accomplishment:
  adjacency (Chebyshev ≤ 1) to the destination's anchor entity's LIVE
  cell, parcel-in-pack as the guard. Arrival IS the handoff: the parcel
  leaves the pack (`remove_item`, the sim's first inventory-REMOVAL seam,
  `pickup`'s inverse, emitting the new `item_lost` event) and the
  delivery's `condition: {delivered_<id>: 1}` then rides
  `WIBounties.condition_met` completely unchanged.
- **Mode trace (the DP2 delta/absolute split applied deliberately)**: all
  5 deliveries are DEFAULT-DELTA. Absolute exists for pre-accept-bankable
  one-shots; `delivered_<id>` is structurally un-bankable pre-accept, and
  delta is REQUIRED for re-acceptance honesty (the counter persists after
  a completed run — an absolute read would insta-complete the same
  posting taken again after a rotation; unit-proven in test_sim_core.gd).
- **Within-the-waking stakes / abandon semantics**: `sleep()` with the
  parcel still in the pack FAILS the run — parcel removed (`item_lost` +
  a night-ledger toast, emitted BEFORE the sleep beat's own stream), slip
  cleared, no pay, `delivery_failed` armed (surfaced exactly once as
  Vess's counter bark at the next picker open, then cleared — the Selys
  slate-rotated-line convention). This sleep-fail IS the abandon: no
  "hand it back" option exists by design (contrast the bounty abandon fix
  wave — a bounty could be unfulfillable; every delivery destination is a
  reachable shipped anchor and sleep is always available). A
  delivered-but-unpaid slip SURVIVES sleep (the mark was made
  same-waking; collecting later is just pay).
- **Surfaces**: `runner_board` (`delivery_board: true`, a distinct flag
  from DP2's `board` so the prop dispatch routes correctly) is
  browse-only via `_interact_delivery_board`; Vess's counter
  (`vess_counter.json` + `WIBounties.build_delivery_picker_graph`/
  `build_delivery_turnin_graph`, code-built exactly like Selys's) is the
  transactional surface. Rotation is literally the SAME function
  (`WIBounties.active_slate` on `times_slept`) over the second pool.
  `delivery_accepted` is the FOURTH sanctioned `requires`/`hide_when`
  gate (`board_accepted`'s exact twin) in `WIDialogue` +
  `test_content.gd`. Save: `accepted_delivery_id`/
  `accepted_delivery_baseline`/`delivery_failed`, additive-optional, no
  version bump.

  **GH#27 fix (2026-07-07): the plain rotation signpost was missing.**
  Ship-day DP5 only ever surfaced a rotation to the player as a SIDE
  EFFECT of the one-shot `delivery_failed` bark — a player who turned in
  cleanly, or who simply slept once holding no slip, got a silently
  rotated slate with no bark at all, unlike Selys's board (which
  signposts EVERY rotation via `board_last_seen_times_slept`,
  independent of any failure concept the board doesn't even have).
  Fixed by riding that exact idiom rather than inventing a new one:
  `delivery_last_seen_times_slept` (int, additive-optional save field,
  default 0, `board_last_seen_times_slept`'s twin) tracks the
  `times_slept` value Vess's picker was last opened at.
  `_open_delivery_picker_dialogue` now checks it in an `elif` AFTER the
  `delivery_failed` branch — a sleep that both rotates the slate AND
  fails a run shows only the more specific failure line, never both
  barks back to back — and stamps it to the live `times_slept`
  unconditionally afterward, exactly like the board. Vess's own line
  ("Board turned over while you slept. Grab a slip before somebody
  faster does.") is distinct copy from both Selys's "New paper went up
  this morning..." and Vess's own failure bark, zero em-dashes per the
  em-dash staging doc's barrel-voice call for Vess. `delivery_loop`'s
  step (9) proves it: a second, failure-free sleep, positive (fires once)
  + negative (does not re-fire on a second same-waking talk) pair,
  mirroring step (8)'s convention for the failure bark.

### GH#21: [Ice Floor] area terrain effect (2026-07-07)

`icy_floor` (ice_mage L10 grant) had been a ghost skill since the
M-LEGIBILITY fix wave: castable in data, no `resolve_active` resolver, its
card suppressed to a bare "Name — description" (see the M-LEGIBILITY
section above). GH#21 wires it for real, closing the last item in that
disclosure.

- **Sim state (`WICombat.terrain`, `src/core/combat/wi_combat.gd`)**: a
  `Vector2i cell -> {"kind":"icy_floor", "expires_after_round":int,
  "applies":Dictionary}` map. NOT save-persisted (combat state never is —
  a combat is always mid-encounter). Populated only by the resolver below;
  purged by `_advance_turn`'s round-rollover branch
  (`_purge_expired_terrain`, called right after `round_number` advances
  and `ROUND_STARTED` emits): a cell cast at round N with
  `duration_rounds` D carries `expires_after_round = N+D-1` ("icy through
  end of round N+duration-1"), purged the next time `round_number` moves
  past it. Purged cells are batched into ONE `TERRAIN_EXPIRED` emit per
  kind (today only `icy_floor` exists, so always at most one per
  rollover), mirroring `TERRAIN_ADDED`'s batched-cells-per-cast shape.
  `snapshot()` exposes it as `{"terrain": {kind: [[x,y],...] sorted}}`
  (empty dict when unused).
- **Resolver (`WISkillEffects._resolve_icy_floor`,
  `src/core/combat/skill_effects.gd`)**: reached via a new `"icy_floor"`
  arm in `resolve_active`'s enemy-gated `match` — the target must already
  be a living ENEMY (the existing same-side gate enforces this, exactly
  like `spell_damage`/`damage_mult`), so no NEW cell-targeting UI mode was
  actually needed — the K4 finding that flagged this as "not a clean fit"
  assumed the cast would aim at a bare cell; instead it aims at a
  combatant id, same as every other active skill, and the blast area is
  DERIVED from that target's cell. Gates BEFORE spend, mirroring
  `spell_damage` exactly: Chebyshev range check refuses silently, then a
  LoS check emits `ACTION_REFUSED{reason:"no_los"}` and refuses — a
  refused cast spends neither AP nor MP. On success: the area is every
  cell within Chebyshev `effect.radius` of the TARGET's cell (not the
  caster's), clipped to grid bounds, excluding `blocked` cells (walls
  don't glaze); occupied cells are included, and the CASTER's own cell
  can land in the area when targeting an adjacent foe [D: friendly fire
  is real, deliberate — proven by `test_combat_sim.gd`'s ally-in-the-blast
  case]. Every area cell is registered into `terrain` (a re-cast at the
  same cells flat-refreshes the dict entry in place — the same idiom
  `_apply_status_from_effect` already uses for statuses, not a stack).
  Emits `SKILL_RESOLVED{actor,skill,target,cells}` then
  `TERRAIN_ADDED{kind,cells,rounds}` (cells sorted x-then-y for
  determinism via a shared `WICombat._cell_less_than` comparator), then
  applies `effect.applies` (icy_floor's `slowed`) to every LIVING occupant
  of the area regardless of side, reusing
  `WISkillEffects._apply_status_from_effect` per occupant. No damage, no
  rng consumption anywhere in this path — seed-safe, so
  `sim_combat_batch.gd`'s balance harness is byte-identical before/after
  (no cell fields touch its fixed rosters).
- **Standing/stepping penalty, two call sites**: a new helper,
  `WICombat._apply_terrain_status(c)`, applies the terrain entry's
  `applies` statuses (if any) at `c`'s CURRENT cell — a no-op when the
  cell carries no entry, which is EVERY existing fight's entire duration
  (the zero-behavior-change proof: the full unit suite and canonical QA
  sweep are unchanged byte-for-byte). Called from `move_active` right
  after the cell update (stepping onto ice mid-turn applies the status
  immediately, biting at the NEXT turn start via the existing `slowed`
  machinery) and from `_start_turn`, right after `c["statuses"]` is
  fetched but BEFORE the pre-existing `statuses.has("slowed")`
  consume-block — so a combatant STARTING its turn already standing on
  ice gets the penalty THIS turn: applied then immediately consumed by
  the same machinery, `STATUS_APPLIED` and `STATUS_EXPIRED` both firing
  in the same turn (an accepted design call — the event trail stays
  truthful about what actually happened rather than hiding the
  turn-start reapplication).
- **Presentation**: `board_renderer.gd` gained a persistent per-cell
  overlay (`add_terrain`/`expire_terrain`, one semi-transparent
  `ColorRect` per cell, `ICY_FLOOR_COLOR` — combat_screen's `FROST_FLASH`
  RGB at a lower persistent alpha) — unlike `flash_cells`' one-shot tween,
  these stay on the board until expired. A `COMBATANT_Z` z-index split
  (combatant holders now explicit z_index 1, terrain overlays default 0)
  guarantees terrain renders above the floor/decor but below every
  combatant regardless of scene-tree add order (overlays are added
  dynamically mid-combat, after `build()`'s own children already exist).
  `add_terrain` emits `UI_TERRAIN_RENDERED` (the ui_*_rendered
  confirmation idiom); `expire_terrain` does not (only the add side rides
  it — `TERRAIN_EXPIRED` is the QA-visible signal for the other half).
  `combat_screen.gd`: `TERRAIN_ADDED`/`TERRAIN_EXPIRED` joined
  `AI_PLAYBACK_TYPES` (the TRAP this const's own doc comment warns about —
  `TERRAIN_EXPIRED` fires at round rollover, which can happen MID an AI
  turn) and the live-path dispatch match; `_play_event_visual` routes both
  to the renderer methods. `icy_floor`'s `SKILL_RESOLVED` also flashes its
  `cells` payload in `FROST_FLASH` (`_skill_flash_color` widened to
  recognize the `icy_floor` effect type; `_skill_flash_cells` needed no
  change — the payload already carries `cells`, the exact shape
  `line_damage` already established).
- **Legibility**: `effect_text.gd`'s `icy_floor` arm now generates
  `"glaze a %d×%d patch of ground at range %d for %d rounds"` from
  `effect.{radius,range,duration_rounds}` (patch side = `radius*2+1`) —
  the exact card `"2 AP, 4 MP — glaze a 3×3 patch of ground at range 3
  for 2 rounds. Slows."` The trailing "Slows." rides the existing
  `_status_suffix` machinery unchanged.
- **AI unchanged, deliberately**: `WICombatAI` only ever selects
  `line_damage`/`spell_damage` types, so it never casts `icy_floor`; no
  shipped enemy holds it; the PC's own autoplay profile is melee. The
  feature is player-only today.
- **QA**: `ice_floor_loop` (fixture `near_ice_floor`, classes
  `{ice_mage:10}` — VERIFIED via the `inherits` chain to auto-grant
  `frost_bolt`/`quick_cast`/`light`/`ice_shard`/`icy_floor` with zero
  hand-stuffed `player_skills`) walks the same fixture→Relc→spar→
  training_yard route `status_first_encounter` established: casts
  `icy_floor` on a training dummy (asserting `skill_resolved`,
  `terrain_added`, `status_applied`, `ui_terrain_rendered`, and the exact
  `combat.terrain.icy_floor` cell list), steps the PC onto the blast the
  same turn, ends turn, and pins the NEXT `turn_started{move_pool:1}` (the
  standing-slow proof, live); then idles past expiry to pin
  `terrain_expired` + a subsequent full-pool `turn_started`; then
  `combat_autoplay`s to victory. `tests/test_combat_sim.gd` covers the
  sim rules directly (range/LoS refusal spend nothing, walls/bounds
  exclusion, friendly fire both sides, persistence across the exact
  round window, flat refresh on re-cast, and the empty-terrain no-op).

### The Magical Door: study, awakening, the portal menu (Task D4, issue #8, 2026-07-07)

D1 shipped the ruin map family + `pantry_door`'s `visual_states`; D3 wired
the 3-path mage-consult chain and the recovery-run counter chain
(`door_chain_started` → `door_understood` → `recovered_anchor_stone` +
`bought_catalyst`). D4 closes the chain: Pisces's silent study over N
sleeps, the awakening beat, and the portal menu itself.

- **`WIPortals` (`src/core/portals.gd`)**: a pure, STATIC-ONLY class — no
  instance, no injected-Callable constructor — deliberately following the
  `WIBounties` precedent (`build_picker_graph`) rather than the
  instantiated ARCH-4 sub-sim shape (`WIEconomy`/`WISocial`/
  `WIFieldSkills`): this class owns no live WIGame field to mutate, so a
  constructor + injected setters would be plumbing with nothing to plumb.
  `attuned_destinations(rows, accomplishment_count_cb)` filters
  `data/portals.json` rows by `requires_accomplishment` (>= 1, the
  `door_when`/`contains_when` gate semantics). `build_portal_graph
  (destinations, current_map)` returns a plain `{start, nodes}`
  `WIDialogue`-shaped graph (identical shape to a `data/dialogue/*.json`
  file, built fresh instead of loaded — the `WIBounties` "conversation
  graph fed from data" idiom verbatim) excluding any destination whose
  `map` equals `current_map` (you can't travel to where you stand),
  appending an always-present "Let it be." fallback so the options array
  is never empty. `destination_by_id` is the reverse lookup
  `_travel_to_portal` uses.
- **`data/portals.json` schema (the anchor-stone-per-region contract,
  #10/#12/#16)**: `{id, display_name, map, cell, requires_accomplishment,
  arrival_toast}`. v1 ships the Liscor pair — `pantry_door` (inn, arrival
  `[9,6]`) ↔ `street_anchor_stone` (street, arrival `[29,10]`, a NEW prop
  entity D4 adds) — both keyed on the SAME `door_awakened` (the player's
  home region attunes both ends at once, unlike a future region's row,
  which keys on its OWN new attunement accomplishment). Every future
  region milestone appends a row here with zero code changes.
- **The awakened interact rewire**: `pantry_door`/`street_anchor_stone`
  both carry `portal_menu: true` + `portal_menu_when: {requires:
  {door_awakened: 1}}`. `wi_game.gd`'s `interact()` checks this gate
  (reusing `_door_gate_met` verbatim) BEFORE `on_interact_accomplishment`
  — an unmet gate falls through to the ordinary flavor toast (D1/D3
  byte-identical fallback), a met gate opens
  `WIPortals.build_portal_graph(attuned_destinations(), current_map)` via
  `_begin_code_dialogue` (the SAME code-built-graph mechanism `board_picker`/
  `delivery_picker` use, so the existing dialogue-panel UI and QA
  `wait_for_event` idiom serve it with zero new UI code).
- **The O2 rule (portal travel is `transition()` ONLY)**: choosing a
  destination fires a `{"travel_to": id}` dialogue effect on a
  conversation-ending option; `dialogue_choose` defers it exactly like
  `pending_combat`/`pending_board_action` (applied once dialogue is
  already null), then `_travel_to_portal` resolves it via `transition()`
  directly — never `move_player`, so `_check_trigger_radius` (the
  proximity-ambush check) and every door-arrival helper can never fire on
  a portal arrival. `portal_menu` (the canonical) asserts this
  structurally: the whole script issues zero `move` QA actions, then
  asserts `player_moved`/`player_blocked`/`combat_started` absent for the
  ENTIRE run.
- **The study-sleeps hook (`sleep()`, `wi_game.gd`)**: runs AFTER every
  existing progression resolution (class gains, level-ups, the
  consolidation-offer early return, evolutions, the tremor pointer) —
  additive only, never alters an earlier branch's outcome. With all
  three of D3's beat-3 counters banked (`door_understood`,
  `recovered_anchor_stone`, `bought_catalyst`), each further sleep banks
  `door_study_sleeps` — deliberately a PLAIN accomplishment counter, not
  a dedicated WIGame field: this is the SAME opaque-counter idiom
  `chatted_with_<id>`/`heard_gossip` already use (`social.gd`), so it
  round-trips through the existing `accomplishments` save field with
  ZERO new `save.gd` plumbing (no version bump, nothing to migrate) AND
  Pisces's `talk_pool_stages` (`pisces_magic.json`'s
  `requires_accomplishment` reader) can gate his study-period lines on it
  directly, with no new gate mechanism. Guarded on `door_awakened` not
  yet banked, so it stops incrementing once awake. OPAQUE-UNTIL-SLEEP is
  strict: the two silent study sleeps (N=1, N=2) bank the counter with NO
  toast override — "You sleep soundly." still fires, since nothing
  player-visible happened on those nights; only Pisces's own pool line
  (`pisces_door_study_1`/`pisces_door_study_2`, two new
  `talk_pool_stages` entries, ZERO progress numbers) shifts, discoverable
  only by talking to him. At N=3, `door_awakened` banks (fires
  `accomplishment_recorded`) and this DOES count as "something happened"
  (suppresses the fallback).
- **The GDI's fourth cameo (`sleep_veil.gd`)**: `door_awakened` banks
  SYNCHRONOUSLY inside the same `sleep()` call the veil is already
  buffering (`_running` is true from that sleep's own unconditional
  `phase_changed` emit, which always fires first) — so
  `_on_domain_event`'s `ACCOMPLISHMENT_RECORDED` arm catches the id and
  appends `"[The inn has a Door. The Door has opinions.]"` (spec §1 beat
  4, quoted verbatim) to `_lines`, the EXACT SAME collection idiom
  `CLASS_GAINED`/`CLASS_LEVEL_UP`/etc. already use — not a new mechanism,
  not a new veil mode. The door prop itself never speaks (Global
  Constraint); this is the GDI's own voice, the veil's fourth surface
  after the sleep-beat class/level toasts, the F1 cold-open, and the A4
  epilogue.
- **QA**: `door_awakening` (fixture `door_awakening_start`, a classless
  beat-3-ready PC) drives all 3 sleeps live, pinning
  `ui_sleep_veil_rendered{lines:0}` for the two silent ones and
  `{lines:1}` for the awakening sleep (with `accomplishment_recorded
  {door_awakened}` asserted FIRST — it fires strictly before the veil's
  own deferred coverage event in the same burst, a since-marker ordering
  trap), then proves the interact rewire via `dialogue_started
  {conversation:"portal_menu"}`. `portal_menu` (fixture
  `portal_menu_start`, `door_awakened` pre-banked) drives the full
  round-trip and is the O2 rule's own proof (see above). `tests/
  test_portals.gd` covers `WIPortals` gating/graph-construction purely,
  the study-counter arithmetic (including the counters-banked-mid-waking
  edge — a sleep taken with only 2 of 3 beat-3 counters banked must NOT
  advance the counter), the full interact/travel/return-trip flow against
  a real `WIGame` instance, and a save round-trip of `door_study_sleeps`
  via the ordinary `accomplishments` path.
