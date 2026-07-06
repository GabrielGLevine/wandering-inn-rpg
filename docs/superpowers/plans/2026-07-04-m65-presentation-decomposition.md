# M6.5 Presentation Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Project skills (`.claude/skills/wi-*`) are READ-ONLY and govern verification.

**Goal:** Split the `combat_screen.gd` god-file (2062 lines, 6 tangled regions) into four focused components + a shared tile builder, with ZERO behavior change — every canonical QA script stays green at its pinned seed after every task.

**Architecture:** Behavior-preserving extraction. The full canonical sweep is the refactor's correctness oracle: identical events at identical seeds = identical behavior. New components are plain scripts composed by `combat_screen.gd` (which shrinks to mode-FSM + input dispatch + bus hub + composition root). A thin `WICombatView` read facade bounds UI→sim reads (consultant finding: UI reads sim internals); the command surface stays the existing 4 combat calls (attack/use_skill/dash/end_turn) — already clean, no redesign.

**Authority:** ROADMAP "M6.5" amendments (2026-07-03 consultant architecture review, user-confirmed). Structure map with file:line inventory: the investigator table in the planning session (2026-07-04) — regenerate with the same region prompt if needed.

## Global Constraints

- **ZERO behavior change.** No data files touched, no sim files touched (see wi_game.gd verdict, Task D5), no event payload/order changes, no visual-layout changes. If a task cannot preserve behavior without a semantic decision, STOP and report.
- **Gate per task:** FULL canonical sweep (26 scripts, pinned seeds — table in v4 CLAUDE.md) + 12 units + smoke, zero warnings (`[godot_ai game_helper]` line exempt). The sweep script pattern lives at the controller; implementers run scripts individually or ask the controller. Additionally per task: one windowed compare named in the task.
- M4 T10 playback invariants are LOAD-BEARING and must survive verbatim: state captured at ENQUEUE, never live reads on a dequeue path, `_refresh_combatants` gated while playing, zero-delay under `TestDriver.active()`/headless.
- **events.jsonl diff oracle: EXCLUDE `audio_played` lines** (D1 reviewer finding: `wi_audio.gd`'s `cooldown_ms` de-dup keys off wall-clock `Time.get_ticks_msec()` — any frame-timing shift reorders/drops SFX entries; pre-existing, deterministic-per-build, QA-green either way). Compare the event stream with `grep -v '"audio_played"'` on both sides; a diff in any OTHER event type is a real behavior change.
- New `.gd` files: `--headless --import` once, commit `*.uid` sidecars. GDQuest style: tabs, static typing, `class_name`, `##` docs.
- Single implementer at a time (same file family). NO COMMIT by implementers.
- **Parallel-playtest safety:** the user may be playtesting on `main`. Keep dirty windows short; the controller commits only at full-green boundaries; HANDOFF tells the user to relaunch only at green commits.

## File Structure (end state)

```
src/world/tile_board_builder.gd   WITileBoardBuilder — shared static tile/board painters
src/combat/combat_view.gd         WICombatView — read facade over a WICombat
src/combat/board_renderer.gd      WICombatBoardRenderer — arena board + combatant visuals/anims
src/combat/combat_playback.gd     WICombatPlayback — AI beat queue (capture/drain/skip)
src/combat/targeting_controller.gd WICombatTargeting — aim modes/filters/cycling
src/combat/combat_hud.gd          WICombatHud — panels/hotbar/readout/feed/tutor/banner
src/combat/combat_screen.gd       slimmed: mode FSM + input dispatch + bus hub + composition (<500 lines)
src/world/world.gd                consumes WITileBoardBuilder; loses its duplicate painters
```

---

### Task D1: WITileBoardBuilder (shared tile painters)

**Files:**
- Create: `wandering_inn_game_v4/src/world/tile_board_builder.gd`
- Modify: `wandering_inn_game_v4/src/world/world.gd`, `wandering_inn_game_v4/src/combat/combat_screen.gd`

**Interfaces — Produces (all static, no scene refs; every param explicit):**
```gdscript
class_name WITileBoardBuilder
static func resolve_layer_cells(spec: Variant, grid: Vector2i) -> Array          # from world.gd:259 / combat_screen.gd:505 (EXACT dupes)
static func make_tile_layer(parent: Node2D, sheet: String, tile_px: int, registry) -> TileMapLayer   # from world.gd:414 / combat_screen.gd:723
static func build_floor_layers(parent: Node2D, layers_cfg: Array, grid: Vector2i, biome_cfg: Dictionary, registry) -> void  # from world.gd:224 / combat_screen.gd:472
static func build_skirt(parent: Node2D, grid: Vector2i, margin: int, biome_cfg: Dictionary, registry) -> void  # from world.gd:204 / combat_screen.gd:453 (margin parameterizes the one difference)
static func build_walls(parent: Node2D, walls_cfg: Dictionary, grid: Vector2i, biome_cfg: Dictionary, registry) -> Dictionary  # SUPERSET: world.gd:298's band+segments form; returns covered-cells dict (world's blocked-painter optimization). Arena configs carry no `segments`, so combat's band-only behavior falls out of the same code path unchanged.
```

- [ ] **Step 1:** create the file; MOVE (not copy) the five function bodies from world.gd, adapting only signatures (explicit params replace member access). Keep each body's logic byte-equivalent; where world/combat variants differed only by a constant (skirt margin), parameterize.
- [ ] **Step 2:** rewire `world.gd` call sites to the builder; DELETE its five originals. Rewire `combat_screen.gd`'s `_resolve_layer_cells`/`_make_tile_layer`/`_build_arena_floor_layers`/`_build_arena_skirt`/`_build_arena_walls` to the builder; DELETE the four duplicates (`_build_arena_walls` becomes a thin call passing the arena's band-form walls config — verify an arena config's walls shape against the builder's superset parser and report the mapping).
- [ ] **Step 3:** `--headless --import` (new class_name); FULL sweep + units + smoke.
- [ ] **Step 4:** windowed compare: `street_peek` + `combat_walkthrough` windowed — controller reads (field tiles and arena tiles pixel-identical to pre-task shots; capture BEFORE starting via `git stash` if needed, or rely on the M-FP-era shots in fp-handoff).
- [ ] **Step 5:** report → controller commits `M6.5 D1: shared WITileBoardBuilder (dupes deleted)`.

### Task D2: WICombatView + WICombatBoardRenderer

**Files:**
- Create: `src/combat/combat_view.gd`, `src/combat/board_renderer.gd`
- Modify: `src/combat/combat_screen.gd`

**Interfaces — Produces:**
```gdscript
class_name WICombatView            # RefCounted; constructed per combat: WICombatView.new(combat)
func stats(id: String) -> Dictionary       # {hp, max_hp, mp, max_mp} from combat.combatants[id]
func cell(id: String) -> Vector2i
func alive(id: String) -> bool
func ids() -> Array
func order() -> Array                       # from combat.snapshot()
func active_id() -> String
func skill(skill_id: String) -> Dictionary
func effective_ap_cost(id: String, skill_id: String) -> int
func line_cells(origin: Vector2i, dir: Vector2i, length: int) -> Array
func alive_enemies_of(id: String) -> Array
func is_adjacent(a: String, b: String) -> bool
func chebyshev(a: String, b: String) -> int
func has_los(a: String, b: String) -> bool
func grid_size() -> Vector2i
func arena_config() -> Dictionary

class_name WICombatBoardRenderer   # Node2D-owning helper constructed by the screen
func build(view: WICombatView, main_ref: Node) -> void   # board+skirt+floor+walls (via WITileBoardBuilder)+blocked-cover+decor+combatant visuals+labels; emits UI_ARENA_RENDERED + UI_WORLD_LABELS_RENDERED with byte-identical payloads
func clear() -> void
func move_visual(id: String, cell: Vector2i, tween: bool) -> void
func bump(id: String, dir: Vector2i) -> void
func play_anim(id: String, anim: String, token: int) -> void
func queue_idle(id: String, token: int) -> void
func flash_cells(cells: Array, color: Color) -> void
func apply_stats(id: String, stats: Dictionary) -> void   # bar widths + label text (the shared refresh/dequeue path)
func mark_death_visible(id: String) -> void
func fade_chip(id: String) -> void
func set_flip(id: String, toward: Vector2i) -> void
```

- [ ] **Step 1:** create WICombatView; move NOTHING yet — it wraps the live combat with the getters above (each body = the existing direct read, verbatim).
- [ ] **Step 2:** create board_renderer.gd; MOVE the board/sprite region functions (structure map list: `_build_board` through `_flash_cells`, incl. `_make_combatant_visual`, label funcs, tween/anim/fade/flash funcs) and their owned vars (`_board,_squares,_hp_bars,_mp_bars,_combat_tweens,_combat_anim_tokens`). All sim reads inside go through the view.
- [ ] **Step 3:** combat_screen delegates (`_show_combat` calls renderer.build; playback/refresh call renderer methods). Bus emissions moved with their functions keep payloads byte-identical — diff `events.jsonl` of a `combat_walkthrough` run against a pre-task run to prove it (same seed → files should differ ONLY in timestamps if any).
- [ ] **Step 4:** import pass; FULL sweep + units + smoke; windowed `relc_tutorial` compare (tutor feed + dummies render identical).
- [ ] **Step 5:** report → commit `M6.5 D2: WICombatView facade + board renderer extracted`.

### Task D3: WICombatPlayback

**Files:**
- Create: `src/combat/combat_playback.gd`
- Modify: `src/combat/combat_screen.gd`

**Interfaces — Produces:**
```gdscript
class_name WICombatPlayback        # RefCounted; new(renderer: WICombatBoardRenderer, screen: Node)
func capture(type: String, payload: Dictionary, view: WICombatView) -> void  # enqueue-time snapshot (moves _capture_playback_event/_capture_event_ui/_capture_combatant_stats + payload serializers verbatim)
func drain() -> void               # the beat loop; per-beat calls renderer.* + screen.render_feed_line(entry)/screen.render_tutor(dict) callbacks; emits UI_AI_PLAYBACK_DONE
func is_playing() -> bool
func request_skip() -> void
func beat_delay() -> float         # zero under TestDriver.active()/headless — idiom unchanged
```

- [ ] **Step 1:** MOVE the playback region (map list `_capture_playback_event`..`_highlight_actor`, `_run_ai_turn`, `_drain_playback`, `_apply_playback_event`, `_apply_captured_stats`, `_apply_combatant_moved`, `_wait_for_skip`) + vars (`_playback,_playing,_skip_requested,_ai_turn_active`). **The M4 T10 invariants move as a block — every enqueue-time capture and the no-live-reads-on-dequeue discipline must survive verbatim; the reviewer will hand-trace one full AI turn.**
- [ ] **Step 2:** screen keeps `_apply_turn_started` (mode FSM) but delegates AI execution + queue state to playback; `_refresh_combatants` gating reads `playback.is_playing()`.
- [ ] **Step 3:** import; FULL sweep + units + smoke; `events.jsonl` diff on `combat_walkthrough`(9) + `level_up_loop`(11) vs pre-task (payload identity).
- [ ] **Step 4:** report → commit `M6.5 D3: playback queue extracted (T10 invariants intact)`.

### Task D4: WICombatTargeting + WICombatHud + slim screen

**Files:**
- Create: `src/combat/targeting_controller.gd`, `src/combat/combat_hud.gd`
- Modify: `src/combat/combat_screen.gd`

**Interfaces — Produces:**
```gdscript
class_name WICombatTargeting       # RefCounted; new(view: WICombatView)
func enter(mode: int, skill_id: String, actor: String) -> Dictionary  # filters targets (adjacency/range/LoS) or line dirs; returns {targets, los_blocked, out_of_range, line_mode} — emits UI_TARGETING_SHOWN byte-identical
func cycle(delta: int) -> void
func confirm() -> Dictionary       # returns the chosen action {kind, target_id | direction} — the SCREEN executes it on combat (commands stay at the composition root)
func cancel() -> void
func state() -> Dictionary         # {targets, index, line_mode, line_dir, skill_id, flags} — HUD renders from this

class_name WICombatHud             # Control-owning; new(root, main_ref)
func build() -> void               # panels/hotbar/labels (from _ready's UI block + _make_panel*)
func refresh(view, mode, targeting_state, bar_slots, bar_index) -> void  # order strip/readout/slot info/hotbar render
func rebuild_slots(view, actor) -> Array
func feed_push(text) / feed_line_for_event(...) / reset_tutor(...) / match_tutor(...) / render_tutor(...)  # feed+tutor block moves whole, incl. wrapped-line budgeting (M-FP F contract)
func show_banner(text) / hide_all()
```

- [ ] **Step 1:** MOVE targeting region + vars; MOVE HUD region + vars (map lists). `_mode` STAYS on the screen (FSM owner); `_bar_index`/`_bar_slots` ownership: slots data lives on the screen (input activates them), HUD renders from passed state — no component reaches back into the screen.
- [ ] **Step 2:** screen slims to: mode FSM, `_unhandled_input` dispatch (delegating to targeting/playback/HUD), `_on_domain_event` hub, lifecycle (`_show_combat`/`_apply_combat_finished`/`_close_banner`/`_apply_turn_started`), composition wiring. Target <500 lines — report the final count; >600 = report why.
- [ ] **Step 3:** ALL remaining direct `combat.`/`Game.sim.combat` reads in the four components + screen route through WICombatView except the four command calls + `Game.sim.resolve_combat()` (screen-only). Grep-prove it: `grep -n "Game.sim\|combat\." src/combat/*.gd` output in the report, each hit classified view/command/lifecycle.
- [ ] **Step 4:** import; FULL sweep + units + smoke; windowed `relc_tutorial` + `combat_move_input` compare (hotbar/readout/tutor/targeting visuals identical — controller reads).
- [ ] **Step 5:** report → commit `M6.5 D4: targeting + HUD extracted; combat_screen is FSM + composition`.

### Task D5: F — gate, wi_game verdict, docs, review

- [ ] **Step 1:** FULL gate: 26 scripts + 12 units + harness + smoke + web parity (`combat_walkthrough` wasm).
- [ ] **Step 2:** wi_game.gd assessment memo (controller-authored, in the ledger + CLAUDE.md note): 732 lines, pure, fully green, next milestone (M7 weapons) touches equip/data paths not presentation — RECOMMEND DEFER any split until M7's plan shows a concrete seam; assessment is a deliverable, not a license to refactor.
- [ ] **Step 3:** CLAUDE.md architecture section: replace the combat_screen monolith description with the component map + view/command contract; note the T10 invariants' new home.
- [ ] **Step 4:** whole-branch review (opus) over the M6.5 range: method hints — events.jsonl byte-compare on 3 seeds vs pre-range, T10 invariant hand-trace, view-facade completeness grep, no orphaned members in the slimmed screen, windowed set reads.
- [ ] **Step 5:** fix wave; HANDOFF + ledger; commit `M6.5 F: gate + docs`.

## Self-review notes

- Consultant findings coverage: god-file split → D2-D4; builder duplication → D1; snapshot/command surfaces → WICombatView (reads) + explicit 4-command root (D4 step 3); wi_game.gd → D5 assessment.
- Behavior-preservation oracle: full-sweep-per-task + events.jsonl seed-diffs (D2/D3) + windowed compares (D1/D2/D4) + the opus byte-compare (D5).
- Type consistency: WICombatView signatures fixed here; D2 creates, D3/D4 consume identically.
- Known risk: `_build_arena_walls` → superset builder (D1) is the one place two code paths merge — the mapping report + arena-tile windowed compare gates it; if any arena walls config resists the superset parser, D1 STOPS and reports (constraint 1).
