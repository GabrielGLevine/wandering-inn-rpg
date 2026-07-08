# CLAUDE.md

Guidance for Claude Code in `wandering_inn_game/` — active Wandering Inn RPG project (M0: agent-QA foundation + walking skeleton).

## What this is

Fresh Godot 4.7 project, QA-first: every feature must be agent-verifiable, no human playtest. See
`docs/superpowers/specs/2026-07-01-wandering-inn-v4-agent-qa-foundation-design.md`
for architecture rationale + north star (BG3-in-Wandering-Inn, team of 1, [Skills] usable outside combat).

**Product constraints (repo-wide, non-negotiable):** HP readouts + damage numbers player-visible (playtest decision, M2); raw STR/DEX/etc. stay forbidden. Lore canon from Wandering Inn Wiki, never invented.

## Commands

**Run discipline (bites every session):** failed `assert` HANGS headless run forever — alarm-wrap long invocations
(`perl -e 'alarm 45; exec @ARGV' /usr/local/bin/godot ...`; macOS has no `timeout`). Grep every run output for
`SCRIPT ERROR|Parse Error|WARNING` — unit suite can print `PASS` yet hide swallowed SCRIPT ERROR. Full gate discipline:
`wi-verifying-changes` skill.

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
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_effect_text.gd  # M-LEGIBILITY L1: WIEffectText exact lines + drift tripwires + forbidden-vocab
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_acts.gd          # M-ARC A1: act-derivation
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_items.gd         # M7 E1: items/equipment validation
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_traversal_seams.gd  # Skills Wave K1: freeze/burn seams
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_input_hints.gd      # Issue #18 S3: WIInputHints label table + device classification
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_portals.gd          # Magical Door plan Task D4 (issue #8): WIPortals catalog filter + graph derivation

	# Balance harness — 200 seeded AI-vs-AI fights; THE authority on combat data tuning
	/usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd

	# QA scripts isolate user:// by default via HOME=.godot_home/qa-<script>-<pid>.
	# Use --user-dir DIR after the mode to choose a stable isolated HOME explicitly.
	# Combat QA scripts REQUIRE a fixed seed (fights are deterministic per seed).
	# Per-script seed + one-line purpose: the canonical seed table below.
	# Per-script full rationale (why this route/seed/assertion): docs/QA-SCRIPT-NOTES.md.
	wandering_inn_game/qa/run_qa.sh <script> headless --seed=<seed>

	# QA playtest scripts (THE verification tool — prefer this over manual reasoning)
	# Full canonical sweep in one command (what CI runs — .github/workflows/ci.yml):
	wandering_inn_game/qa/ci_sweep.sh                           # all 49 at pinned seeds + grep discipline; --only a,b,c to restrict; list MIRRORS the seed table below — keep in sync
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

Fresh project, ZERO known-harmless warnings. Any SCRIPT ERROR, Parse Error, or WARNING in any run = regression.

## Architecture

Full mechanism detail, rollout narrative, design rationale for every system: `docs/ARCHITECTURE-HISTORY.md`. This section current-state-only, one short paragraph per live system.

- **Sim core (`src/core/wi_game.gd`)** — `WIGame`, pure `RefCounted` sim. PURITY RULE: no autoload/Node/scene-tree refs in sim code, ever; dependencies injected (config dicts, event-sink `Callable`, seed). Keeps sim headless-testable, mass-simulatable.
- **ObservableBus (autoload)** — single pipe for every player-visible / QA-relevant domain event (`emit_domain_event`, JSONL log + signal). Never `print()` anything player should see; UI nodes render from bus events, emit `ui_*_rendered` confirmations back onto bus.
- **Game (autoload)** — owns `WIGame` instance, wires event sink to bus, owns save/load file I/O.
- **Presentation (`src/world/world.gd`, `src/ui/message_layer.gd`, `src/world/main.tscn`)**
  — thin: forwards input to `Game.sim`, renders state from bus events. All UI built in code; content in `data/*.json`. `main.tscn` = only hand-authored root scene (`project.godot`'s `run/main_scene`) — `src/world/world.tscn` orphaned byte-identical duplicate, nothing references it. Render pipeline (M5): 1280×720 window, 320×180 world `SubViewport` scaled 4×, centered (fractional `canvas_items` stretch, not integer). Environment schema (M5 E3): maps use `floor_layers`, `walls.segments` (walls-v2 records; `WIGame.segment_cells` = single cell-expansion source shared by sim blocking + tests), `decor`, `scatter`. Field held-key movement (2026-07-05): held keys re-issue `move_player` on each move-tween `finished` signal, gated same as fresh press; collapses to 0 duration under QA/headless — unobservable to tests. Full detail: "Presentation" + "Demo feel + render pipeline (M5)" + "Environment schema (M5 E3)" blocks in `docs/ARCHITECTURE-HISTORY.md`.
- **Field hotbar (`src/ui/field_hotbar.gd`, Three Pillars P2)** — overworld twin of combat action bar; shows PC's known field-tagged skills (`Game.sim.known_skills()` filtered by `skills.json`'s `field: true`), hides during combat, reuses `WIHotbar` for render. Number keys route through `world.gd` existing movement/interact gate.
- **TestDriver (autoload, `qa/test_driver.gd`)** — inert unless `--qa-script=...` passed. Executes declarative JSON playtests: injects real input, waits for bus events (`payload_contains` subset match), screenshots, asserts on `Game.sim.snapshot()`, drives fights via `combat_autoplay`, writes `result.json`. Per-script routing/rationale: `docs/QA-SCRIPT-NOTES.md`; script list: canonical seed table below.
- **Combat (`WICombat`, `src/core/combat/wi_combat.gd`)** — pure per-encounter tactical sim: 12×8 grid, 4 AP/turn, precomputed initiative, seeded RNG, reaction hooks (riposte, momentum). Movement economy: `move_pool` (3 free steps/turn) spends before AP; `dash()` costs 1 AP for +3 pool. LoS = supercover raycast (symmetric, corner rule); line skills clip at first wall, hit everything in line (friendly fire real). MP: `max_mp = 8 + int/2`, granted only when combatant holds any `mp_cost` skill. **PC death = immediate defeat**, even with living ally (`_check_end` checks `pc.alive` first) — any future combat-data/sim change must re-check this failure mode; `defeat_ally_alive` = canonical proof. `WISkillEffects` = active-effect registry; `WICombatAI` = deterministic role AI (`melee`/`ranged`/`caster`/`inert` profiles — PC's own combatant config defaults to `melee`, so `combat_autoplay` never casts spell or fires line-skill refusal for player; see Gotchas). Presentation decomposed into components (M6.5): `combat_screen.gd` = only mode FSM + input dispatch; `board_renderer.gd`/`combat_view.gd`/`combat_playback.gd`/`combat_hud.gd`/
  `targeting_controller.gd` each own one concern — new presentation code goes in matching component, never back into `combat_screen`. Combat controls: arrows move active unit directly (move pool before AP), number keys = hotbar slots, Dash arms confirm gate (Enter/Esc), never fires instantly. Full detail: "Combat (M1)" / "Combat depth (M3)" / "Combat controls" / "Combat presentation components (M6.5)" blocks in `docs/ARCHITECTURE-HISTORY.md`.
  **Area terrain (GH#21, [Ice Floor]):** `WICombat.terrain` = `Vector2i cell -> {kind, expires_after_round, applies}` map, populated only by `WISkillEffects.resolve_active`'s `icy_floor` arm (Chebyshev-radius blast around TARGET's cell, walls/out-of-bounds excluded), purged in `_advance_turn` round-rollover branch. Standing on or stepping onto terrain cell applies its `applies` statuses via `_apply_terrain_status` (two call sites: `move_active`, `_start_turn`) — every existing fight leaves `terrain` empty whole duration, guaranteed no-op elsewhere (`sim_combat_batch.gd` byte-identical before/after). AI never selects it (`WICombatAI` only picks `line_damage`/`spell_damage`) — player-only today. `ice_floor_loop` = canonical proof.
- **Progression (`src/core/progression.gd`)** — ACCOMPLISHMENT-COUNTER driven (doing `[X]` things levels `[X]`, never chosen), resolved only at sleep beat, order: class gains → level-ups → consolidation offer → evolutions. Evolution at level 10 picks Replacement (dominant axis), Generalist grant (balanced, below dominance), or defers (Waiting). Consolidation offers `[Spellsword]` when two parent lines both qualify; refusable forever, round-trips in saves. **OPAQUE-UNTIL-SLEEP user-locked**: never render progress-toward text (no "3/12 uses", no percentages) — toasts/journal/prompts show RESULTS only. Full detail: "Action-driven classes (M6)" block in `docs/ARCHITECTURE-HISTORY.md`.
- **Story spine** — `WIDialogue` (`src/core/dialogue.gd`) = pure conversation-graph walker; possession-gated visible options (`requires`, hidden) vs retired options (`hide_when`, shown-but-inert); effects returned to `WIGame.dialogue_choose`, which applies them + re-gates ctx per node advance. `WIQuests` (`src/core/quests.gd`) — quest progress = pure function of accomplishment counters. `WISave` (`src/core/save.gd`) — versioned full-state round-trip (current `VERSION := 5`; `_migrated` composes each version step); file I/O only in Game autoload. Maps/doors = data (`skeleton_scene.json`). Full detail: "Story spine (M2)" block in `docs/ARCHITECTURE-HISTORY.md`.
- **THE REQUEST BOARD (`WIBounties`, `src/core/bounties.gd`, M-DEPTH DP2)** —
  rotating bounty pool (`data/bounties.json`), deliberately NOT `WIQuests` quest (no journal entry, no beat text): `board_bounties()` derives active 2-3 postings from `times_slept % pool.size()` (zero rng, talk-pool rotation idiom at pool-window granularity). `accept_bounty`/`turn_in_bounty` (`wi_game.gd`) ride existing machinery only — plain accomplishment counter (`accepted_bounty_<id>`/`completed_bounty_<id>`) + shared `earn_gold` router; bounty condition (the `quests.json` complete_when dict shape) evaluates DELTA-SINCE-ACCEPT (current counter minus baseline snapshotted at accept), never absolute read. Board prop (`guild_board`, `board: true`) browse-only; accept/turn-in at Selys's desk (`selys_delivery.json` "Take on a posting."/"Turn in my posting." hub options) via TWO code-built `WIDialogue` graphs (`WIBounties.build_picker_graph`/`build_turnin_graph`) — real conversations, built at runtime from current slate, not static file, so existing dialogue-panel UI + QA `wait_for_event` idiom need no new code path. `WIGame._build_dialogue_ctx`'s `board_accepted` bool = SECOND sanctioned non-accomplishment `requires`/`hide_when` gate (after `gold`, Economy v1 D1) — `WIDialogue._meets`/`_progress_gated` recognize it explicitly. Full detail: "THE REQUEST BOARD (M-DEPTH DP2)" block in `docs/ARCHITECTURE-HISTORY.md`.
  **THE DELIVERY BOARD (M-DEPTH DP5)** rides same machinery over second pool (`data/deliveries.json`, Runner's Guild): same `active_slate` rotation, same `condition_met` (all-delta; `delivered_<id>` counter produced ONLY by `WIGame._check_delivery_arrival` — Chebyshev-1 adjacency to destination anchor from real `move_player`, parcel-in-pack guard; arrival removes parcel via `remove_item`/`item_lost`, sim's one inventory-removal seam). Sleeping on undelivered parcel FAILS run (parcel returns, no pay — this IS the abandon; no hand-back option by design). Vess's counter (`vess_counter.json` + `delivery_accepted`, FOURTH sanctioned gate) transacts; `runner_board` (`delivery_board: true`) browses. Full detail: "The Runner's Guild delivery loop (M-DEPTH DP5)" block in `docs/ARCHITECTURE-HISTORY.md`.
- **The Magical Door / portal menu (`WIPortals`, `src/core/portals.gd`,
  Magical Door plan Task D4, issue #8)** — pure STATIC-ONLY derivation + code-built `WIDialogue` graph (`WIBounties.build_picker_graph` precedent, not instantiated ARCH-4 sub-sim shape — class owns no WIGame field to mutate). `data/portals.json` rows (`{id, display_name, map, cell, requires_accomplishment, arrival_toast}`) = anchor-stone-per-region seam every future region milestone (#10/#12/#16) appends row to, zero code. `WIGame.attuned_destinations()` filters catalog by accomplishment gate; prop carrying `portal_menu: true` (`pantry_door` in inn, `street_anchor_stone` in street) opens `WIPortals.build_portal_graph()` once its `portal_menu_when` gate met (the `door_when`/`contains_when` idiom) — menu excludes anchor's OWN map, each anchor only offers somewhere else. Choosing destination fires `travel_to` dialogue effect, resolved by `WIGame._travel_to_portal` via `transition()` ONLY (O2 rule: `move_player`/`_check_trigger_radius` never touched, arrival can never trigger proximity fight — `portal_menu` = canonical proof). Awakening beat = sleep()-beat hook: with D3's three beat-3 counters banked, every further sleep banks PLAIN accomplishment counter `door_study_sleeps` (opaque-until-sleep — zero progress text, only Pisces's own `talk_pool_stages` lines shift, `pisces_magic.json`); at N=3 `door_awakened` banks, `sleep_veil.gd` catches (veil's fourth cameo, after class/level toasts, F1 opener, A4 epilogue) to queue GDI's own line under same black veil — door prop never speaks. Full detail: "The Magical Door / portal menu (Task D4)" block in `docs/ARCHITECTURE-HISTORY.md`.
- **Character creation (`char_creation.gd`, M-ARC §5, picker recomposed issue
  #42)** — New Game → one-step 2x3 sprite-picker grid (six idle-animated AnimatedSprite2D PC variants via `WISpriteRegistry`: Human/Drake/Gnoll × Male/Female) → name. Picking card sets `pc_race`+`pc_gender` together. Three cosmetic sim fields (`pc_name`/`pc_race`/`pc_gender`), additive save, no mechanical effect. QA auto-skips creation with everyman defaults unless script opts in. Full detail: "Character creation (M-ARC §5)" block in `docs/ARCHITECTURE-HISTORY.md`.
- **Equipment & Gear** — pure sim state, `WIGame.inventory` (ids) + `equipped` (5 keys: `weapon`, `armor`, `accessory_1/_2/_3`, per M-GEAR G1 2026-07-06) + `container_state`. Combat reads equipment once at `start_combat` build (weapon-family-gated kit, `damage_mod`/`hp_mod`/`damage_reduction`). Loot RNG isolated from live sim stream (`hash(run_seed, encounter_id)`-derived) — never shifts combat seed. `resonance_capacity` (default 2) caps total accessory resonance; refused equips get diegetic placeholder toast. Inventory UI: `src/ui/inventory.gd`. Full detail: "Equipment (M7)" + "M-GEAR (resonance gear)" blocks in `docs/ARCHITECTURE-HISTORY.md`.
- **Atmosphere / lighting / ambience (`src/world/atmosphere.gd`,
  `src/world/ambience.gd`, presentation-only)** — per-map/per-phase mood color grade (`data/moods.json`, ship-neutral-first: identity `[1,1,1]` everywhere except tuned rollouts) via single `CanvasModulate`; per-arena overrides for arenas that shouldn't inherit field grade (e.g. `cave_mouth`, always dark). Lights (`PointLight2D`, phase-gated energy, ≤8/map budget) + ambience emitters (`GPUParticles2D` presets, hard on/off per phase, ≤6/map) register with `atmosphere.gd` — single `apply()` refreshes color + every light + every emitter together. Three small canvas shaders: foliage sway (always-on), water shimmer (floodplains pond overlay), vignette (identity 0.0 everywhere today). Field name tags RETIRED (R3) — combat name tags gone too, HP/MP numeral readout stays; `WIWorldLabels` survives combat-stats-only. `visual_states` seam lets prop/npc swap sprite/tint/light on accomplishment counter or container-opened flag (e.g. `dirty_table` cleaning up, `unlit_lantern` lighting). Full detail: "Atmosphere / mood grade (B1)" / "Light layer (B2)" / "Ambience layer + shaders (B3)" / "Atmosphere rollout R1/R2" / "Label removal + visual affordances (R3)" blocks in `docs/ARCHITECTURE-HISTORY.md`.
- **Legibility formatter (`WIEffectText`, `src/core/effect_text.gd`,
  M-LEGIBILITY)** — the ONE formatter for every player-visible mechanical line (item cards, skill/hotbar cards, status glossary). Pure/static, VISIBLE-CURRENCY only (HP/MP/AP/dice/cells/gold/rounds; raw stats + percent-toward forbidden in anything it emits) — rendered line can never drift from data it describes. Skills Wave Task K4 wired real sim consumers for `heal` (second_wind self-only heal, capped at max_hp) and `move_pool_bonus` at 0 AP cost (quick_movement/battlefield_awareness, real turn-start passive) — both cards un-suppressed now. GH#21 wired last ghost skill, `icy_floor`: "new cell-targeting mode" K4 worried about turned out unnecessary (cast still targets combatant id, same as every other active skill — area derived FROM that target's cell, not aimed at bare cell), card now generates "N AP, N MP — glaze an RxR patch of ground at range R for N rounds. Slows." from `effect.{range,radius,duration_rounds,applies}`. Full detail: "M-LEGIBILITY (L1-L5)" and "GH#21 [Ice Floor] area terrain effect" blocks in `docs/ARCHITECTURE-HISTORY.md`.
- **Art pipeline (`WISpriteRegistry`, `src/world/`, M4)** — builds SpriteFrames/TileSets from `data/sprites.json`/`data/biomes.json`. Committed curated extracts in `assets/` (licenses in `assets/LICENSES/`); browse via `docs/asset-index.md`, never by loading PNGs into context. Any tile/sprite region pick must be verified by windowed screenshot. Full detail: "Art pipeline (M4)" block (layout specifics superseded by M5 render pipeline above, mechanics still apply) in `docs/ARCHITECTURE-HISTORY.md`.

**Canonical QA seed table** (source of truth: `qa/manifest.json` — `ci_sweep.sh` verifies this table against it). Run any script: `qa/run_qa.sh <script> headless --seed=<seed>` (fixture-based scripts load save via title Continue whose own `rng_state` OVERRIDES `--seed`; seed shown below = pinned/held either way). Full sweep: `qa/ci_sweep.sh` (parses `qa/manifest.json`; hard-fails if this table drifts from it — keep both in sync when adding script). Two screenshot-only utilities (`title_peek`, `street_peek`) excluded, not canonical. Full per-script rationale (route, seed, assertions, gotchas): `docs/QA-SCRIPT-NOTES.md`.

| script | seed | purpose |
|---|---|---|
| `load_gate` | none | native-only resource compile/load gate |
| `inn_walkthrough` | 9 | full inn journey, no screenshots in headless; issue #40's canonical diagonal leg (move_diag out-and-back, net zero) opens it |
| `dialogue_walkthrough` | 9 | Erin/Selys story path (meets Relc, then `goblin_encounter_2`) |
| `dialogue_hub_loop` | 9 | conversation hub loop-backs + `hide_when` sweep |
| `quest_errand_fight` | 9 | errand path with a goblin fight |
| `quest_errand_parley` | 9 | errand path through parley |
| `save_load_roundtrip` | 9 | save/load persistence path |
| `combat_walkthrough` | 9 | core combat proof; `ally_requires` roster gate negative-then-positive |
| `tutorial_flow` | 9 | the onboarding's own end-to-end proof (spar → gift → ambush → street) |
| `level_up_loop` | 9 (fixture `post_tutorial`) | level-up loop; fight 2 tests riposte |
| `mage_unlock_loop` | 9 | [Mage] earned from Pisces; full cold-start arc + mage kit fielded |
| `line_of_sight_denial` | 9 | wall-aware ranged AI proof (positive `has_los` gate) |
| `defeat_reload` | 1 | losing seed; defeat loads `auto` slot, no `game_reset` |
| `defeat_ally_alive` | 3 (fixture `near_defeat`) | THE canonical proof of the PC-death-is-instant-defeat rule |
| `title_flow` | 9 | title screen flow; no combat |
| `playtest_boot` | none | Issue #43: debug-only title 'Playtest States' picker -- boots `near_garden` via the real fixture-copy-then-Continue path |
| `combat_move_input` | 9 (fixture `post_tutorial`) | movement-first arrows + Dash refill via real input |
| `class_evolution_loop` | 9 (fixture `near_evolution`) | grind → sleep → `class_evolved` + evolved kit |
| `consolidation_flow` | 9 (fixture `near_consolidation`) | offer/decline/re-offer/accept → [Spellsword] |
| `save_migration` | 1 | v2→v3 migration + v1 pause-load rejection + stale-slot defeat-reload |
| `consolidation_reload` | 9 | pause-load reconstructs the consolidation prompt mid-offer |
| `generalist_loop` | 9 (fixture `near_generalist`) | Generalist evolution path + balanced-mastery grants |
| `lantern_check` | 9 | [Light] `lit_the_common_room` payoff, after the Pisces mage arc |
| `gate_district_walkthrough` | 9 | enters street for real via `liscor_gate`; gate NPCs + Selys |
| `relc_tutorial` | 9 | full `relc_spar` tutor_lines beats + opacity/persistence teeth |
| `work_loop` | 9 | inn work-loop, Helper leg (chores → `class_gained` → level 2) |
| `crate_fight` | 9 (fixture `post_tutorial_street`) | "Missing Crate" FORCE path |
| `crate_talk` | 9 (fixture `post_tutorial_street`) | "Missing Crate" WATCH path (no combat) |
| `crate_light` | 9 | "Missing Crate" SKILL path ([Light]-studies `cellar_door`) |
| `journal_skills` | 9 | journal skills-by-class panel; pre/post-first-use reveal |
| `inventory_loop` | 9 | THE inventory/equipment loop; weapon-gated kit proof |
| `atmosphere_check` | 9 | mood-grade/phase-clock proof; day→dusk→day cycle |
| `field_skills_loop` | 9 (fixture `near_tactician`) | field-skill hotbar loop (Basic Cleaning → Observe); K2b loadout assign/unassign + remapped-slot proof |
| `social_loop` | 9 (fixture `post_tutorial_street`) | Social Pillar v1 proof; rotating talk pools → [Diplomat] |
| `sewers_walkthrough` | 9 (fixture `near_sewers`) | Liscor sewers proof; grate-gate seam + vermin fight |
| `cisterns_fight` | 9 (fixture `cisterns_fight_start`) | Quest 1 FIGHT path (clear `shield_spiders` nest) |
| `cisterns_talk` | 9 (fixture `cisterns_talk_start`) | Quest 1 TALK path (persuade Zevara, no combat) |
| `cisterns_scout` | 9 (fixture `cisterns_scout_start`) | Quest 1 SKILL path ([Appraise Foe] the `nest_ledge`) |
| `wrong_order_loop` | 9 (fixture) | "The Wrong Order" inn-local give→cook→report loop |
| `wrong_order_talk` | 9 (fixture) | "The Wrong Order" TALK path (Krshia smooth-over, no combat) |
| `wrong_order_fight` | 9 (fixture) | "The Wrong Order" FIGHT path (clear `supplier_scavengers`) |
| `economy_loop` | 9 (fixture `economy_loop_start`) | the coin arc: chore earn → loot → shop → spend |
| `char_creation` | none | THE character-creation UI proof (sprite-pick (2x3 idle grid, #42) + name) |
| `deep_descent` | 9 (fixture `deep_descent_start`) | the Raskghar descent + JOIN-Relc boss victory |
| `climax_chain` | 9 (fixture `climax_surface_start`) | the tremor beat + Zevara summons + Olesm briefing |
| `climax_seal` | 9 (fixture `climax_sealed_start`) | the seal beat + journal Act III advance |
| `arc_flow` | 9 (fixture `near_act3`) | THE WHOLE ACT III ARC PROOF, tremor through epilogue |
| `status_first_encounter` | 9 (fixture `near_mage_cast`) | status glossary + first-encounter combat-feed surface |
| `ice_floor_loop` | 9 (fixture `near_ice_floor`) | GH#21: [Ice Floor] area terrain effect -- cast/friendly-fire/standing-slow/expiry, live |
| `gear_loop` | 9 (fixture `gear_loop_start`) | resonance-gear UI proof (accessory rows, capacity refusal) |
| `stealth_loop` | 9 (fixture `near_ambush_sneak`) | the [Stealth] seam: skip an ambush, break it, positive control |
| `rogue_earn_loop` | 9 (fixture `near_rogue`) | K3 [Rogue] earn: `recovered_crate_watch` -> sleep -> `class_gained` -> [Stealth] fielded |
| `stages_loop` | 9 (fixture `krshia_stage3_pre`) | Social Pillar II: `talk_pool_stages` base->final (Krshia), unlocked hub topic + shop discount perk surface |
| `guild_interior_walkthrough` | 9 (fixture `near_guild`) | M-DEPTH DP1: guild_door real-door round-trip, Selys-behind-the-desk (pool + graph incl. desk-context node), board/notice-wall dressed props, Renn/Ilvo/Yelra walk-on pool lines |
| `board_loop` | 9 (fixture `board_loop_start`) | M-DEPTH DP2: THE REQUEST BOARD goes live -- browse/accept/fulfill/turn-in at Selys's desk (delta-since-accept, gold payout), slate rotation across a sleep + the "slate rotated overnight" line |
| `upstairs_walkthrough` | 9 | M-DEPTH DP3: the inn's upstairs -- stairs door pair, Lyonette's locked door (observe+locked_toast), sleep-beat parity proven live at the PC's own bed (same events, one extra flavor toast) |
| `barracks_walkthrough` | 9 (fixture `near_barracks`) | M-DEPTH DP4: the Watch barracks + market-depth stalls -- `bread_stall` (flavor/observe) + the `peddler`'s mini-buy (`watch_issue_gambeson`, 20g), `barracks_door` real-door round-trip (the relocated `watch_guard`, zero prior QA touches), Duty Sergeant Dresk Ashgrave's talk_pool, Zevara's desk (she stays at the gate), THE CELL (locked_toast, empty-v1 dressed) |
| `delivery_loop` | 9 (fixture `near_runners_guild`) | M-DEPTH DP5: the Runner's Guild delivery loop -- `runners_guild_door` round-trip, Vess's counter (talk_pool bark + `vess_counter` graph), THE DELIVERY BOARD browse, take a slip -> a real walked carry -> Chebyshev-1 arrival handoff at `krshia_stall` -> turn-in pay (1g exact total), the sleep-fail negative (parcel returns on the night ledger, no pay, `delivery_failed` armed) + slate rotation across the sleep + the one-shot failed-run bark; GH#27: a second, failure-free sleep proves Vess's OWN plain-rotation bark (distinct from both Selys's board line and Vess's failure line) fires once per rotation, not twice in the same waking |
| `stage3_perks_loop` | 9 (fixture `stage3_perks_pre`) | Issue #23: the `once_per_waking` dialogue seam's own proof -- Erin's daily meal (`well_fed` + hp_mod) and Relc's spar wager (+1g), both live: eat/win -> option gone same waking -> sleep clears `well_fed` + the bank -> both options back |
| `ruin_walkthrough` | 9 (fixture `near_ruin`) | Magical Door plan Task D1 (issue #8): enter the gated ruin via a fixture with `door_chain_started`, real `ruin_door` door_when transition, walk the new `ruin_surface` map's bounds, read the pedestal-locked toast (`anchor_stone_pedestal`), round-trip exit via `ruin_exit` -- routes AROUND both new dormant encounters (`rift_vermin_leak`/`ruin_guardian` have no combat data yet, D2's job) |
| `door_chain_fight` | 9 (fixture `door_chain_fight_start`) | Magical Door plan Task D3 (issue #8): the FIGHT leg + full end-to-end chain -- Erin's beat-1 flicker line live, Pisces sends the player to clear `rift_vermin_leak` (inn), the ruin recovery run (`ruin_guardian` fight + `anchor_stone_pedestal` opens), Krshia's `resonant_catalyst` purchase -- both quest beats complete |
| `door_chain_talk` | 9 (fixture `door_chain_talk_start`) | Magical Door plan Task D3 (issue #8): the TALK leg -- persuades Pisces (zero combat), banks the SAME `door_understood` as the FIGHT leg, then opens `anchor_stone_pedestal` WITHOUT ever fighting `ruin_guardian` (the pedestal's `contains_when` OR-gate proof from a non-FIGHT producer) |
| `door_chain_scout` | 9 (fixture `door_chain_scout_start`) | Magical Door plan Task D3 (issue #8): the SKILL leg -- `[Observe]`s `pantry_door_runes`, reports to Pisces (banks the SAME `door_understood`), then buys Krshia's `resonant_catalyst` (`bought_catalyst`) |
| `door_awakening` | 9 (fixture `door_awakening_start`) | Magical Door plan Task D4 (issue #8): the full awakening chain from a beat-3-ready fixture through 3 real sleeps -- 2 silent study beats then `door_awakened` banks + the GDI line queues under the sleep veil -- to the awakened `pantry_door`'s interact rewire (opens the portal menu, not the flavor toast) |
| `portal_menu` | 9 (fixture `portal_menu_start`) | Magical Door plan Task D4 (issue #8, the O2 rule): fast-travel round-trip -- menu at the inn anchor -> street arrival -> menu at the street anchor -> return to the inn -- pins the `map_changed` pair in order and asserts no `combat_started`/`player_moved`/`player_blocked` fires anywhere in the run (portal travel is `transition()` only) |
| `garden_walkthrough` | 9 (fixture `near_garden`) | Issue #9 Task G1 (spec §5 RATIFIED): the Garden of Sanctuary unlock-to-rest loop -- the qualifying sleep silently banks `garden_door_unlocked` (act >= III AND K=2 of 4 ratified legs), Erin's `talk_pool_stages` acknowledgment, `garden_door` opens for real at the inn, day-bright identity + fountain + misted-rise clearing live on `garden_sanctuary`, rest-bed sleep parity at `garden_bed`, round-trip exit -- plus a whole-run no-violence sim-guard cross-check (`combat_started` never fires) |
| `riverfarm_walkthrough` | 9 (fixture `near_riverfarm`) | 8b Task R1 (issue #10): door arrival via the portal contract's first exercise (locked shape 1) -- village walk (headman talk_pool + the charmed villager's `echo_of` tell, locked shape 3) -- the night wolf gate NEGATIVE at day (`encounter_when`, locked shape 2, canonical-pinned) -- the hollow round-trip -- the witch's two-form read across a REAL live mid-waking phase crossing (no sleep, locked shape 4) -- routes around `briar_collectors`/`briar_collectors_deep` (live encounters post-R2 merge; interact-only, never faced -- `combat_started` absent whole-run) |
| `riverfarm_fight` | 9 (fixture `riverfarm_fight_start`) | 8b Task R3 (issue #11) 'The Price of a Favor' FIGHT path -- give, clear `briar_collectors` then `briar_collectors_deep` (the escalation R2 tuned; the deep victory banks the shared `blight_lifted` convergence), report, completion; plus the night-wolf POSITIVE leg (a real actions-since-sleep burst to night, `river_wolf_pack`'s `trigger_radius` fires and is won) |
| `riverfarm_talk` | 9 (fixture `riverfarm_talk_start`) | 8b Task R3 (issue #11) 'The Price of a Favor' TALK path -- no combat: give, the witch's [Diplomat]-gated mediation (a renegotiated year of hearth-tending banks `blight_lifted`), report, completion, plus the shared post-conditions every path converges on (village visual_states BRIGHTEN, the charmed villager's echo RETIRES via `talk_pool_stages`, the witch-cottage VENDOR unlocks) |
| `riverfarm_skill` | 9 (fixture `riverfarm_skill_start`) | 8b Task R3 (issue #11) 'The Price of a Favor' SKILL path -- no combat: give, the gauntlet in sequence (`basic_cooking` the offering -> [Light] the threshold candles -> [Observe] the true knot, existing field-skill seams) -- the last step banks `blight_lifted` directly -- report, completion |

## Working conventions

- Add ANY player-visible feature → extend QA script (or add new one in `qa/scripts/`) that walks it, asserts both domain event AND `ui_*_rendered` confirmation; run before claiming feature works.
- Content = data + code: new entities/skills in `data/*.json`; new behavior in sim; presentation only renders.
- Tests = plain SceneTree scripts under `tests/` (no GUT/gdUnit). Pure classes only — anything needing autoloads = QA-script territory.
- Balance changes = `combatants.json`/`skills.json` edits validated by `sim_combat_batch.gd` (GATED cells win-rate 0.55-0.95, median rounds 3-12; `goblin_ambush/warrior2` measured-only by user directive — see "Combat depth (M3)" block in `docs/ARCHITECTURE-HISTORY.md`) — never tune by feel. Combat data/rule change can invalidate canonical QA seed: re-verify `combat_walkthrough`/`level_up_loop`, update seed in this file's canonical seed table (and `qa/ci_sweep.sh`'s `CANON` array) if needed.
- GDQuest GDScript style: tabs, static typing, `class_name` + `##` doc comments.
- **Comment style (user directive 2026-07-07, binds all new code + _comment fields):** comments state FUNCTION, CONSTRAINTS, TRAPS — never provenance. No task/wave/review-finding narratives, no issue citations (exception: forward-promise to OPEN issue may cite it until issue closes). History lives in git blame, ledger, docs/ARCHITECTURE-HISTORY.md. Trap/contract comments (drift seams, order constraints, payload shapes) = the valuable kind — keep writing those. Legacy corpus thinned by GH#44 at 8a→8b boundary.

## Gotchas

- `CanvasLayer` has no `modulate` — tint/fade child Controls instead (exact bug shipped dead quest chain in v2).
- **Godot 4.7 `ResourceLoader.load()` returns NON-NULL but uncompilable script resource when .gd has parse/compile error** — null-checking load() not enough; load gate also checks `Script.can_instantiate()`.
- `--script`-mode runs don't resolve autoloads as bare identifiers — why purity rule exists; no autoload refs from `src/core/wi_game.gd`, `event_log.gd`, `qa_paths.gd`, or `tests/`.
- Commit generated `*.uid` sidecars alongside new `.gd` files.
- **Sprite frames with transparent padding below figure need measured `anchor`** (data/sprites.json). Feet-anchoring uses FRAME bottom — Body_A/Citizen_F's 16px under-feet padding (figure y 18–47 of 64) drew every character exactly ONE CELL above logical cell; player visually aligned with door/prop was physically row off, interact hit nothing. Fixed with `anchor: [0.5, 0.75]`. New character/prop sheet: measure figure bbox (PIL alpha scan), set anchor from FEET PLANE, not frame edge; verify with windowed adjacency screenshot.
- Web QA seeding (M3 T8): `run_web_qa.sh <script> <seed>` threads seed through `run_web_qa.mjs` -> `window.__WI_QA__ = {script, seed}` -> `game.gd._build_sim` reads via `JavaScriptBridge.eval(...)` only when `OS.has_feature("web")` AND no `--seed=` user arg given natively. Only `game.gd` reads *seed* off bridge (`qa/test_driver.gd` already uses `JavaScriptBridge.eval` for script-name/screenshot/result plumbing) — sim core in `src/core/**` never touches bridge, sim purity unaffected.
  Combat QA scripts now web-runnable (parity with native); `load_gate` stays native-only (see above).
- `WICombatAI.take_turn`'s `_act_once` defaults empty `"ai"` field (PC's own combatant config) to **melee** profile, which never inspects ranged/spell skills. So `combat_autoplay` NEVER casts spell for player character, any seed, any classes — `mage_unlock_loop` verifies mage kit via `combat.combatants.pc.max_mp` (nonzero only when known skill carries `mp_cost`), not observed cast. Similarly `action_refused {reason: "no_los"}` unreachable under AI-only play: `_act_ranged` pre-filters targets with explicit `has_los` check; `_act_line` filters *indirectly* — `line_cells` truncates at first blocked cell, blocked cells can't hold combatants, so wall-obstructed direction can never satisfy ≥2-enemies-hit gate. Dead-code safety net under AI play, not reachable QA event. (Player path: single-target spells also pre-filtered — `combat_screen.gd` drops non-LoS targets before selection — refusal live only via player's line-skill direction picker, which has no filter.) `line_of_sight_denial` proves has_los gate positively: `flame_bolt` (wall-aware ranged cast) resolves successfully, `action_refused/no_los` never fires, uses `goblin_ambush` arena (only arena with ranged enemy), not walled-but-all-melee `chieftains_raid` roster. `level_up_loop` fight 2 swapped from `goblin_encounter_1` to `chieftains_raid` for same structural reason: in `goblin_encounter_1`, `relc` (ally) always lowest-HP/nearest target, lone melee enemy dies before reaching PC — `counter_strike` (riposte) can never trigger there, any seed; `chieftains_raid`'s 3 melee enemies give PC real chance of being hit (win rate 0.61 per balance harness — hence explicit seed search, not first-seed-tried pick).
- **PC death = immediate DEFEAT, even with living ally (WAVE A2 §7, post-D4 user-confirmed directive).** `_check_end` in `wi_combat.gd` checks `combatants["pc"]["alive"]` FIRST, before team-wipe scan — previously fight only ended in defeat when BOTH pc and every ally down; fight where pc dies mid-round with ally (`relc`) alive used to CONTINUE, could still resolve as win (ally mops up rest). Exactly what broke `level_up_loop` old seed 11: fight 2 (`chieftains_raid`) — pc down round 3, `relc` alive, `goblin_chieftain` at 4 HP, previously won when `relc`'s next turn finished chieftain — now instant defeat. Re-derived to seed 12 (wins fight 2 outright, still fires `reaction_triggered{counter_strike}`). **Any future combat-data or sim change: re-check this same failure mode** — canonical seed that won via "pc goes down, ally carries the win" no longer can; search replacement where pc actually survives, don't assume old win margin still applies. `sim_combat_batch.gd` structurally unaffected (`combat.outcome["victory"]` already reflects whichever branch `_finish` took), but gated-cell win rates can shift (losses no longer require every ally down too) — re-run harness after any defeat-condition change, not just data changes. Rule's canonical QA proof: `defeat_ally_alive` (seed 11, table above) — re-verifies "PC dies while Relc lives = instant defeat" through real input/AI/UI path every sweep.
- **Message panels budget WRAPPED LINES, not entries (M-FP F fix — keep it that way).** Combat feed (`combat_screen.gd`) + world `dialogue_line` panel (`message_layer.gd`) both fit text by measuring wrapped visual lines at panel width (`Font.get_multiline_string_size`; line pitch = font height + theme `line_spacing` — string-size call does NOT include line_spacing, real trap), then EVICT oldest feed entries / TRUNCATE with ellipsis until total fits panel art-safe capacity (parchment bottom fold bleeds above naive margin — feed effective text height 90px, not 106). Design rule D2-7 #6 binding: cut words, never widen UI. Dialogue panel truncates only ON-SCREEN string — `ui_dialogue_rendered` still carries full text (QA asserts exactly). Any future panel or `tutor_lines` copy change: re-verify with windowed `relc_tutorial` + `gate_district_walkthrough` runs, read by eyes.
  **M-LEGIBILITY L5 extended this to THIRD panel:** `combat_hud.gd` readout (`_readout_label`, a `RichTextLabel`, not `Label` — see `_rtl_wrapped_line_count`/`_rtl_line_capacity`/`_rtl_fit_to_lines`, distinct from feed's `Label`-typed helpers because RichTextLabel real theme properties = `normal_font`/`normal_font_size`/`line_separation`, not Label's `font`/`font_size`/`line_spacing`) had NO budget at all until this fix — L4 windowed shot (`.superpowers/sdd/fp-handoff/l4-shots/01_first_encounter_feed.png`) caught frost_bolt full 3-segment slot-info line wrapping to 2nd line (head + hint + 2 info lines = 4 total), 4th line rode parchment bottom fold exactly like pre-fix feed/dialogue panels. Fixed via `_compose_readout`: fits ONLY variable-length slot-info segment to capacity remaining after `head`+`hint` (capacity 3 lines total, calibrated to RichTextLabel real font pitch — see READOUT_TEXT_WIDTH/HEIGHT doc comment in `combat_hud.gd`). Same truncate-render-only contract: `ui_slot_info_rendered` still carries FULL escaped line (`combat_move_input.json` pins exactly for `[Power Strike]`) — only `_readout_label.text` gets fitted version. Windowed-reverified via `status_first_encounter` (frost_bolt line now truncates cleanly to 3 lines, no fold bleed).
- **Onboarding rev classless start (Task O1, 2026-07-05):** `player.classes` starts `{}` (no class, no combat skills); `warrior` now EARNED via `sparred_with_relc` (banked by shipped `relc_spar` tutorial fight), granted at next sleep. UI/hotbar/journal degrade gracefully with zero classes. Full narrative (incl. re-path window Task O5 later closed): `docs/ARCHITECTURE-HISTORY.md` "Onboarding rev classless-start" section.

## GodotPrompter

Godot project, GodotPrompter skills available. Before implementing any game system, MUST check for matching `godot-prompter:*` skill and invoke it. Binds all agents, subagents, sessions in this repo.

Key skills: `gdscript-patterns`, `scene-organization`, `component-system`, `resource-pattern`, `event-bus`, `godot-ui`, `state-machine`, `godot-testing`.

Full skill list: invoke `godot-prompter:using-godot-prompter`.