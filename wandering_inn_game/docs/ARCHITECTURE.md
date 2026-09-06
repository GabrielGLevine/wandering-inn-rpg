# ARCHITECTURE — wandering_inn_game (machine-oriented map)

> Purpose: bootstrap a fresh agent session on repo structure, data flow, seams,
> and traps. Structural facts only. Rationale/history: `ARCHITECTURE-HISTORY.md`.
> Operating contracts, commands, verification routing: `../AGENTS.md`.
> Volatile values (seeds, counts, save VERSION, ceilings) live in their code
> authorities — never copy them here.

## 0. Identity

```
engine:        Godot 4.7 (/usr/local/bin/godot); run from repo root
project:       wandering_inn_game/  (only active project)
main_scene:    src/world/main.tscn  (WIMain, src/world/main.gd — boot/injection root)
code:          GDScript; all UI built in code (no authored .tscn beyond main.tscn)
content:       JSON under data/ (content=data, behavior=sim, rendering=presentation)
determinism:   seeded RNG injected into sim; QA seeds pinned in qa/manifest.json
render:        1280x720 window, canvas_items stretch; world = 320x180 SubViewport scaled 4x; field cell=16px
```

## 1. Layer model (dependency rules)

| layer | path | rule |
|---|---|---|
| sim core | `src/core/**` | pure RefCounted. NEVER references autoloads, `Node`, scene tree. Deps injected: config Dictionaries, event-sink Callable, seed |
| combat sim | `src/core/combat/**` | same purity; per-encounter instance owned by `WIGame` |
| autoloads | see §2 | own file I/O, event pipe, process-level services |
| presentation | `src/world/**`, `src/combat/**`, `src/ui/**`, `src/audio/**` | thin: forward input to `Game.sim.*`, render state + bus events. Never `print()` player-visible text |
| data | `data/*.json`, `data/maps/<region>/*.json`, `data/dialogue/*.json` | all gameplay content; validated by `scripts/data_lint.py` + unit suites |
| QA | `qa/` | `test_driver.gd` autoload, inert without `--qa-script=`; declarative JSON playtests |

Canonical loop:
```
input → presentation _unhandled_input → Game.sim.<command>()
  → sim mutates + emits domain events (injected sink)
  → ObservableBus (signal + JSONL log)
  → presentation renders → emits ui_*_rendered confirmation
  → QA asserts BOTH domain event and rendered confirmation
```
Every player-visible feature ships: domain event + `ui_*_rendered` + QA assertion.

## 2. Autoloads (project.godot order)

| autoload | file | role |
|---|---|---|
| `ObservableBus` | `src/core/observable_bus.gd` | single domain-event pipe: `emit_domain_event(type, payload)` → signal + JSONL |
| `Game` | `src/core/game.gd` | owns the `WIGame` instance; ALL save-file I/O (`user://saves/`); `load_slot` trial-applies to a throwaway sim, swaps only on success; builds sim config from data (incl. `moods.json` phase thresholds) |
| `TestDriver` | `qa/test_driver.gd` | QA executor; inert in normal play; auto-skips char creation unless script opts in |
| `WIAudio` | `src/audio/wi_audio.gd` | data-driven audio router over `data/audio.json` (event subset-match SFX, first-match music, ducking, Voice bus) |
| `WIInputHints` | `src/ui/input_hints.gd` | observes input device (kbd/gamepad) without consuming; source for control labels |
| `WISettings` | `src/ui/wi_settings.gd` | fullscreen/text-scale/reduce-motion in `user://settings.cfg` (shared file with WIAudio volumes; each writer reloads before save). Autoload-free internally by design |
| `WIDebugOverlay` | `src/ui/debug_overlay.gd` | dev-only read-only sim inspector; root-level so UI teardown never frees it |

## 3. Module registry

### 3.1 Sim core (`src/core/`)
`WIGame` (`wi_game.gd`) is the facade: owns player state, world state, command
API (`move_player`, `interact`, `sleep`, `start_combat`, `resolve_combat`,
`dialogue_choose`, `pickup/equip/unequip`, `use_skill_field`, `transition`, …),
`snapshot()` for QA. Extracted seams (all pure, injected-Callable, event streams
byte-identical at extraction):

| file | class | owns |
|---|---|---|
| `interactions.gd` | WIInteractions | `interact()` kind-dispatch routing |
| `sleep_beat.gd` | WISleepBeat | sleep-beat orchestration + toast stream |
| `combat_banking.gd` | WICombatBanking | post-fight accomplishment/loot banking |
| `combat_build.gd` | WICombatBuild | combatant-build math SHARED with `tests/sim_combat_batch.gd` (never fork — harness must measure the shipped game) |
| `progression.gd` | WIProgression | class gains / level-ups / evolutions / consolidation, resolved ONLY at sleep |
| `dialogue.gd` | WIDialogue | pure conversation-graph walker; effects RETURNED to `WIGame.dialogue_choose`, ctx refreshed per node |
| `dialogue_banks.gd` | WIDialogueBanks | shared line banks deduping repeated lines/option verbs across graphs |
| `quests.gd` | WIQuests | quest progress = pure function of accomplishment counters (stored nowhere) |
| `acts.gd` | WIActs | act = derived (highest act whose gates pass), never saved |
| `save.gd` | WISave | versioned serializer/migrator; `VERSION`, `DEPRECATED_IDS` live here; `rng.state` saved as STRING |
| `save_migration.gd` | WISaveMigration | legacy-project-dir → fresh `user://` copy at boot |
| `economy.gd` / `shop.gd` / `fence.gd` | WIEconomy/WIShop/WIFence | gold, shops; fence = code-built rotating stock (`fence_stock.json`) |
| `social.gd` | WISocial | talk pools, `chatted_with_<id>` rotation, gossip |
| `bounties.gd` | WIBounties | board/delivery slates (`active_slate` on `times_slept`), delta-since-accept `condition_met`, code-built picker/turn-in graphs |
| `bounty_scaling.gd` | WIBountyScaling | rank-scaled repeatable cull encounters (shared with harness) |
| `portals.gd` | WIPortals | static; attuned destinations + code-built portal menu; portal travel is `transition()` ONLY, never `move_player` |
| `field_skills.gd` | WIFieldSkills | overworld skill dispatch; property-table interactions (`data/interactions.json`, first-match-wins row order) |
| `items.gd` / `keys.gd` | WIItems/WIKeys | item catalog helpers; key/lock gating |
| `inn_guests.gd` | WIInnGuests | deterministic guest rotation (roster order + times_slept, zero rng) |
| `effect_text.gd` | WIEffectText | THE one formatter for every player-visible mechanical line; visible-currency only (raw STR/DEX/… forbidden — `test_effect_text.gd` pins) |
| `address.gd` | WIAddress | `{addr}`/`{Addr}` PC-address substitution at emit time |
| `event_log.gd` | WIEventLog | chronicle/event-log records |
| `scene_catalog.gd` | WISceneCatalog | composes `data/scene_root.json` + `data/maps/<region>/*.json` into scene_config; `segment_cells` = single wall-segment expansion authority |
| `system_bestowal.gd` | WISystemBestowal | #347 prototype, debug-flag only, zero player surface |
| `wi_events.gd` | WIEvents | event-name consts. Names are PERSISTED QA/API contracts — rename only with all producers/consumers/fixtures migrated |
| `qa_paths.gd` | QAPaths | QA path constants |

### 3.2 Combat sim (`src/core/combat/`)

| file | class | owns |
|---|---|---|
| `wi_combat.gd` | WICombat | per-encounter tactical sim: 12x8 grid, 4 AP/turn, `move_pool` (3 free steps, dash refills), precomputed initiative, seeded rng, statuses, `terrain` (round-expiring), windups, supercover LoS, `in_weapon_range` (data `weapon_range`; melee=adjacency), reactions (riposte, momentum). Construction silent; owner assigns instance BEFORE `begin()` (events fire synchronously). Combat state NEVER serialized |
| `skill_effects.gd` | WISkillEffects | active-effect resolvers (`damage_mult`/`spell_damage`/`line_damage`/`blast_damage`/`icy_floor`/heal/`move_pool_bonus`…), `_radius_area` shared Chebyshev derivation, statuses, passives |
| `combat_ai.gd` | WICombatAI | deterministic profiles: `melee`(default)/`ranged`/`caster`/`inert`/`skirmisher`/`guard`/`coward`; composes the same public verbs. PC autoplay = melee → autoplay never proves player-spell paths |

### 3.3 Combat presentation (`src/combat/`)
`combat_screen.gd` (CanvasLayer) = mode FSM + input dispatch + bus hub +
composition root; the ONLY caller of the 4 combat commands + `resolve_combat`.
Components (new presentation code goes IN a component, never back into screen):

| file | class | owns |
|---|---|---|
| `combat_view.gd` | WICombatView | the ONLY sanctioned UI→sim read surface (thin getters) |
| `board_renderer.gd` | WICombatBoardRenderer | arena board, combatant visuals/bars, terrain + dangersense overlays. References autoloads directly — never lazy-load it via a shim |
| `combat_playback.gd` | WICombatPlayback | paced AI replay queue. INVARIANT: capture ALL render state at ENQUEUE; never read live combat on dequeue. Delay 0 under TestDriver/headless |
| `combat_hud.gd` | WICombatHud | panels/hotbar/readout/feed (measured wrapped-line eviction)/tutor/banners |
| `targeting_controller.gd` | WICombatTargeting | aim filter/cycle/confirm; returns actions, never executes |

### 3.4 World presentation (`src/world/`)

| file | class | owns |
|---|---|---|
| `main.gd` | WIMain | boot order + injection root; spawns/tears down world and UI layers; title↔world swaps; `world_to_screen` projection |
| `world.gd` | WIWorld | field render + input intents; `visual_states` seam (counter/container-driven per-entity looks); presence reconciliation on `PHASE_CHANGED`/`ACCOMPLISHMENT_RECORDED`; held-key movement repeat |
| `entity_visual_factory.gd` | WIEntityVisualFactory | pure builder for entity visuals + blocked-prop sets |
| `camera_controller.gd` | WICameraController | camera clamp/pan math |
| `sprite_registry.gd` | WISpriteRegistry | SpriteFrames/TileSets from `data/sprites.json` (region crops, render_scale, anchors); asserts loudly on malformed catalog data |
| `tile_board_builder.gd` | WITileBoardBuilder | tile layers for BOTH field and arena (shared file — edits affect both) |
| `atmosphere.gd` | WIAtmosphere | CanvasModulate mood grade per map/phase (`data/moods.json`, `arena_moods` pins), light/emitter registries, vignette |
| `ambience.gd` | WIAmbience | GPUParticles2D preset factory (WASM-safe properties only) |
| `dangersense_overlay.gd` | WIDangersenseOverlay | windup danger overlay (PC `dangersense` holders only) |
| `data_registry.gd` | WIDataRegistry | data file loading/caching |

### 3.5 UI (`src/ui/`)
All CanvasLayers, spawned by `main.gd._spawn_ui_layers`, native-res, outside the
world SubViewport (never mood-graded). Opaque panels set `layer = 10`.

| file | role |
|---|---|
| `message_layer.gd` | toast FIFO + one-time hints; static toast history for journal Recent Messages |
| `dialogue_panel.gd` | renders WIDialogue nodes/options (data graphs AND code-built graphs identically) |
| `purchase_confirm.gd` | #504 modal over the dialogue panel for `WIGame.pending_purchase`: cursor opens on Cancel, input swallowed until `ui_purchase_confirm_armed`, outside tap = cancel; forwards to `purchase_confirm()`/`purchase_cancel()` |
| `journal.gd` | J: quests/leads/skills-by-class (BBCode); reveal state from sim |
| `inventory.gd` | I: equip/unequip, resonance header, lore lines |
| `pause_menu.gd` | Esc: save/load slots, settings, quit-to-title |
| `title_screen.gd` | New Game/Continue; must not call `swap_to_world` itself |
| `char_creation.gd` | pick (race×gender grid) + name; cosmetic sim fields only |
| `sleep_veil.gd` | sleep interstitial + defeat interstitial; pure renderer, consumes nothing |
| `consolidation_prompt.gd` | modal class-merge offer; reconstructs from sim on load |
| `field_hotbar.gd` / `field_hotbar_layout.gd` / `field_chips.gd` | overworld hotbar of known `field:true` skills; number keys direct-fire, Tab selection cursor |
| `hotbar.gd` | shared 52x52 slot bar (combat + field) |
| `settings_panel.gd` | shared title/pause settings; derived rect (no magic heights); credits/help from data |
| `ui_chrome.gd` | UIChrome: NinePatch parchment/button chrome, `bb_escape` (placeholder technique — never naive replace chain), runtime-load fallback art |
| `picker_presenter.gd` | numbered-row picker derivation (lockstep with sim payload; derive, never rewrite) |
| `world_labels.gd` | COMBAT-ONLY HP/MP stat readout (name tags retired everywhere) |
| `input_hints.gd` / `wi_settings.gd` / `debug_overlay.gd` | autoloads, see §2 |

## 4. Event architecture

- `WIEvents` consts = the registry. Domain events describe sim facts;
  `ui_*_rendered` events confirm a player actually got the render.
- Bus logs JSONL per run → `qa_output/<script>/events.jsonl`.
- Emission-order trap: events emitted during `_rebuild_field`
  (`ui_lights_rendered`, `ui_ambience_rendered`) fire BEFORE `world_ready` —
  QA must use `assert_event_logged`, not `wait_for_event`.
- Sim emits synchronously inside command calls; presentation must tolerate
  mid-combat `phase_changed` (PC turns tick the action counter).
- Deferred dialogue effects (`pending_combat`, `pending_board_action`,
  `travel_to`) apply only after the conversation ends.
- Purchase rows (#504: `requires.gold` N + `gold: -N` effect, no narrative
  `spend` tag) do not commit on `dialogue_choose`: the offer parks on
  `WIGame.pending_purchase` (`purchase_offered`) and `purchase_confirm()`
  revalidates then runs the ordinary commit path once; `purchase_cancel()`
  returns to the same node. QA buy idiom: confirm → `purchase_offered` →
  `ui_purchase_confirm_armed` → down + confirm → `purchase_confirmed` → gold/item.

## 5. Data catalog (`data/`)

| file | drives | notes |
|---|---|---|
| `scene_root.json` | start map + player seed (cell, innate skills, classes `{}` = classless start, inventory/equipped) | maps themselves live in `maps/` |
| `maps/<region>/<map>.json` | rooms: floor_layers, walls.segments `{from,to,cap,face}`, decor, scatter, entities (npc/prop/door), lights, ambience, `visual_states`, `present_when`, facing | composed by WISceneCatalog; region dirs are the lane-disjointness unit |
| `maps/_shared_talk.json` | shared talk pools | |
| `dialogue/*.json` | conversation graphs: nodes, options with `requires`/`hide_when`, effects | ONE gate type per requires dict; sanctioned gate keys: accomplishment (hidden-until-met), `skill`/`class` (visible-locked), `gold`, `board_accepted`, `delivery_accepted`, `phase` |
| `classes.json` | class tree: levels (cumulative `requires` counters, `requires_any`), `gained_by`, `granted_skills`, `inherits` chains, `evolution`, stat_growth | resolved only at sleep |
| `skills.json` | skill records: `field`, `contexts`, `ap_cost`/`mp_cost`, `effect` (typed), `weapon` tags, `icon` | untagged skills always field; effect types must have a resolver or their card is suppressed |
| `combatants.json` | combatant stats: hp/weapon_die/`weapon_range`/skills/`ai` profile | |
| `arenas.json` | combat arenas: grid, walls, biome, decor | |
| `items.json` | catalog: kind (weapon/armor/accessory/tool/parcel), damage_mod/hp_mod/damage_reduction, resonance, lore, price | |
| `quests.json` | quest defs: `complete_when` counter thresholds | |
| `interactions.json` | #348 field-skill property table (burnable/freezable/…); ROW ORDER IS CONTRACT (first match wins) | |
| `bounties.json` / `deliveries.json` | board/delivery posting pools | rotate on `times_slept`, no rng |
| `portals.json` | door network rows `{id, map, cell, requires_accomplishment, arrival_toast}` | new region = new row, zero code |
| `fence_stock.json` | Ratici fence pool | |
| `moods.json` | per-map phase color grades + vignette, `arena_moods` pins, `meta.phase_thresholds` (LIVE injected values), `meta.light_energy_by_phase` | threshold changes shift `phase_changed` in every stream → full canonical re-verify |
| `biomes.json` | per-biome tile sheets/coords, footstep family, blocked props | sheet grids differ (16px vs 32px) |
| `sprites.json` | sprite catalog: sheets, directional rows, `region`, `render_scale`, `anchor` (feet plane), `shadow` | anchors from measured alpha bounds |
| `audio.json` | event→SFX subset-match rows, music first-match rows, round-robin variants | |
| `acts.json` / `leads.json` | derived act ladder; derived journal leads (must mirror target option gates exactly) | |
| `progression.json` | challenge-weighted leveling knobs | |
| `help_content.json` / `credits.json` | settings-panel content; copy-fit capped | |
| `shipped_ids.json` | GENERATED freeze list — shipped ids are permanent API; deprecate via `WISave.DEPRECATED_IDS`, never rename | `scripts/generate_shipped_ids.py` |
| `system_bestowals.json` | #347 prototype table, debug-only | |

Edit discipline: surgical edits only; append via
`wandering_inn_game/scripts/splice_json.py`; never reserialize a mixed-format
shipped file. Any `data/*.json` change → `scripts/data_lint.py` first.

## 6. Persistence

- `WISave` (pure): full-state round-trip; `VERSION` + composed migrations +
  `DEPRECATED_IDS` in `src/core/save.gd`. Prefer additive-optional fields with
  tolerant defaults over version bumps.
- Slots (`user://saves/`): 3 manual + `auto` (checkpoint) + `auto_prev`
  (rotated on New Game) + `auto_pre_combat` (pre-fight boundary; the defeat
  rewind target). Dialogue-committed fights snapshot on `PRE_COMBAT_CHOICE`
  (before effects + rng draw) and suppress that fight's `COMBAT_STARTED`
  snapshot.
- Autosave triggers: victory/class events/quest beats/map change/`PHASE_CHANGED`.
- `Game.load_slot` = trial-apply on throwaway sim, swap only on success →
  rejected load is a true no-op.
- Fixture saves carry `rng_state`, which OVERRIDES a command-line seed after
  load.
- Settings/audio live in `user://settings.cfg` — configuration, not save data.

## 7. Progression pipeline (sleep beat)

`WIGame.sleep()` order: class gains (`gained_by`) → level-ups (batched,
multi-level, one toast per class) → consolidation offer (DEFERS the rest;
accept merges parents, decline resumes) → evolutions (dominant-axis at
`at_level`, else generalist/waiting) → post hooks (door study, tremors, delivery
fail, guest rotation). Everything keys off accomplishment counters — the
universal currency (`record_accomplishment`); quests, acts, leads, bounties,
dialogue gates, visual_states all derive from them. OPAQUE-UNTIL-SLEEP:
never render progress-toward (no counts/percentages); results only.

## 8. QA harness

- `qa/run_qa.sh <script> headless|windowed [--seed=N]` executes
  `qa/scripts/<name>.json` via TestDriver: injected real input, event waits
  (`wait_for_event` + `payload_contains`), whole-run `assert_event_logged`,
  `snapshot()`/`combat.`-path assertions, `combat_autoplay`, screenshots,
  fixture installs → `qa_output/<script>/{result.json,events.jsonl,logs,shots}`
  (rerun replaces the dir).
- `qa/manifest.json` = ONE source of truth for script names/seeds/fixtures/
  tiers/notes. After manifest/script/fixture edits:
  `scripts/derive_qa_surfaces.py` then `python3 scripts/render_qa_notes.py
  --write` (repo root). `qa/ci_sweep.sh [--tier smoke|--touching <path>]`
  selects canonicals.
- Missing `result.json` = failure even on exit 0. Zero-noise: any
  `SCRIPT ERROR`/`Parse Error`/`WARNING` is a regression despite PASS.
- Unit/contract suites: `tests/test_*.gd` (SceneTree, discovered by
  `scripts/preflight.sh --full`); anything needing real autoload/UI wiring
  belongs in declarative QA instead.
- Balance authority: `tests/sim_combat_batch.gd` (gated win-rate/median cells).
  Tune DATA, never sim rules. Combat-data changes → re-run harness + affected
  combat canonicals (incl. defeat/ally canonicals — PC death ends combat even
  if allies live).
- Web QA: `qa/web/run_web_qa.sh` (real HTTP server, console/worklet checks).
- Windowed screenshots are the only proof of "reads correctly" — humans gate
  FEEL; sprite/tile region picks must be verified by an actual screenshot read.

## 9. Extension recipes (task → primary seams → gate)

| task | touch | proof | skill |
|---|---|---|---|
| new class/skill | `classes.json`/`skills.json` (+ resolver in `skill_effects.gd` if new effect type) | data_lint, balance harness, combat canonicals | wi-adding-a-class-or-skill |
| new map/room | `data/maps/<region>/`, `biomes.json`, `moods.json` entry | `ci_sweep --touching`, reachability tests, windowed read | wi-adding-a-scene |
| new encounter/enemy | `combatants.json`/`arenas.json` (+ AI profile if novel) | balance harness + combat canonicals | wi-adding-an-encounter |
| dialogue/quest | `data/dialogue/`, `quests.json` (gates per §5 rules) | test_content/test_dialogue, dialogue QA script | wi-adding-dialogue-and-quests |
| sprite/prop | `sprites.json` + `assets/` | sprite-registry unit + windowed before/after | wi-art-and-sprites |
| repeatable posting | `bounties.json`/`deliveries.json`/`fence_stock.json` | data_lint + board canonicals | — |
| new region portal | `portals.json` row | portal canonicals | — |
| player-visible anything | + bus event + `ui_*_rendered` + QA assertion | wi-verifying-changes routing | — |

## 10. Hard invariants (violation = architecture bug)

1. Sim purity (§1). New sim modules: pure RefCounted, injected deps, unit-testable via bare `--script` (which does NOT load autoloads).
2. Event names + shipped content ids are frozen API (deprecate-and-map, never rename).
3. Content in data; tune data, never sim rules; canon from the Wandering Inn Wiki.
4. Opaque-until-sleep; visible stat grammar (`test_effect_text` tripwires).
5. One dialogue-gate type per `requires` dict; every node with vanishing options keeps one ungated exit (`test_content`).
6. Loot/derived rng draws use isolated generators (`hash(run_seed, encounter_id)`) — a main-stream draw shifts every multi-fight canonical seed.
7. Code-built dialogue graphs (boards/fence/portals) reuse the WIDialogue shape — never a parallel UI path.
8. Shared helpers stay shared (`combat_build.gd`, `segment_cells`, `_radius_area`, `bb_escape`) — hand-copies drift.
9. Presentation reads sim via sanctioned surfaces (`WICombatView`, `snapshot()`, bus) — no reach-ins.
10. Durable Godot/QA traps: see `../AGENTS.md` "Durable Godot and QA gotchas" (mandatory reading; not duplicated here).
