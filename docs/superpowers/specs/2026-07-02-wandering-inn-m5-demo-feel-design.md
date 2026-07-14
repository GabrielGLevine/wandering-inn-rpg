# M5 Design — Demo Feel (render rework, shell, hotbar, audio, enemy sprites)

**Status:** REV 2 — user-approved brainstorm, then revised per external-consultant
adversarial review (NEEDS REVISION verdict; all 5 blockers + 4 important findings
accepted — review at `docs/superpowers/consultant/2026-07-02-m5-spec-review.md`,
merged from the consultant's branch). Next: writing-plans.

**Inputs:** M4 playtest findings 1/2/6/7 (fill window, 16px recalibration, main menu,
hotbar), seed doc `2026-07-02-m5-demo-feel-seed.md`, new asset packs (goblin ×3 variants
4-directional, Tiny Swords, Minifantasy SFX+music, xDeviruchi soundtrack, Super Dialogue
Audio Pack, topdown floor tiles), M4 carried Minors (theme/backdrop items), roadmap
constraints (Fable week: this spec + plan land now; execution may finish under Opus).

**Goal:** a stranger launching the game sees a title screen, plays in a window-filling,
smoothly-animated pixel-art world with sound, fights via an icon hotbar, and can save,
quit to title, and continue — no test-harness feel anywhere.

**Non-goals:** mouse input (later milestone; hotbar is keyboard-driven this pass), new
story content, action-driven classes (M6), gear/inventory (post-launch), Relc/Drake
final art (AI-gen exploration is a stretch deliverable, chip fallback stays shippable).

---

## 1. Render core (Lane R — the barrier lane)

- **World renders in a SubViewport at 320×180 logical pixels, 16px grid cell.** A
  `SubViewportContainer` integer-scales it 4× into a **1280×720** window (project
  viewport setting changes from 1024×640). **Scaling mechanism (consultant B5): keep
  `stretch/mode="canvas_items"` and set `stretch/scale_mode="integer"`** — one-line,
  eliminates fractional shimmer at any window size. Consequence accepted and stated:
  the whole canvas (UI included) letterboxes in 1280×720 steps; at 1920×1080 the game
  renders 1× with large bars. Fine for the demo; a hand-rolled resize handler is a
  post-launch nicety.
- **Fill the view (consultant B1 — the original playtest complaint).** Both field maps
  are 10×6 (160×96 logical) — bare, they'd cover 27% of a 320×180 view, WORSE than
  today. Lane R therefore ships **decorative skirt rendering**: `biomes.json` gains
  per-biome `skirt` tile coords (+ optional variation list), and map/arena rendering
  paints skirt tiles from the playable-grid edge to the view bounds (non-walkable,
  pure visual). Exit bar: a windowed screenshot of each map/arena shows environment
  art to every window edge (minus letterbox).
- **CELL becomes 16 logical px everywhere.** Tiles render at native 16px (RE-DERIVE all
  sheet grids: M4 assumed 32px for free-pack sheets — the playtest's "not correctly
  calibrated" symptom; cave was already proven 16px. The plan must verify every sheet's
  native tile size by pixel inspection before wiring, controller-screenshot-verified per
  the M4 lesson).
- **Character/prop sprites keep larger canvases** (Body_A 64px canvas, goblin pack per
  its own frames), anchored feet-to-cell-bottom, with a **Y-sort container** so taller
  sprites overlap the tile above them naturally. Placeholder chips shrink to 16px cells.
- **In-world text strategy (consultant B3):** at 16px cells the current labels/HP text
  are illegible or multi-cell. Split: HP/MP **bars** stay in-viewport as 1–2px-tall
  pixel bars under each unit (legible chunky pixels); ALL **text** (names, HP/MP
  numerals) moves to a native-resolution overlay layer whose labels track world
  positions via the camera+container transform (Lane R ships the world→screen
  projection helper; H consumes it). HP-numeral visibility is a binding product
  constraint — it must survive this move, verified by screenshot.
- **Combat board leaves the CanvasLayer (consultant I6):** CanvasLayers ignore
  Camera2D, so the board (tiles, units, flashes — all current ORIGIN/CELL math) is
  extracted into the world viewport's canvas; `ORIGIN` dies (camera centers the
  board). Lane H inherits a heavily rewritten combat_screen.gd, not today's file.
- **Tweened movement:** field player + combat units interpolate position over
  ~0.12s/step (combat playback beats keep their 0.5s cadence; the tween happens within
  the beat). Blocked-move gets a small bump nudge. Facing/walk anims unchanged.
- **Camera2D** in the world viewport: centers maps smaller than 320×180 (both current
  maps and both arenas fit); follows the player with map-edge clamping on larger maps
  (build it clamped-follow now — M7 maps will exceed the view).
- **UI moves to native-resolution CanvasLayers** over the container (hybrid choice):
  dialogue panel, journal, pause, toasts, hint, combat panels/hotbar all render crisp at
  window res. Existing `ui_*_rendered` confirmations unchanged.
- Combat board (12×8 → 192×128 logical) renders in the same world viewport; board
  centered by the camera during combat.

**QA:** all existing scripts must stay green (event assertions are render-agnostic);
`ui_map_rendered`/`ui_arena_rendered`/`ui_entities_rendered` keep firing; screenshots
recaptured at end of milestone. Windowed screenshot checks are MANDATORY per region/scale
change (M4 lesson, now standing rule).

## 2. Game shell (Lane S)

- **Title screen** (new scene, code-built like all UI): title art text over a tile/mockup
  backdrop, menu New Game / Continue / Quit. Continue enabled iff `user://saves/auto.json`
  or `manual.json` exists; loads the newest. Emits `ui_title_rendered`.
- **Scene management (consultant B2 — this was the spec's biggest hole):** a new root
  `Main` scene owns two child slots: title and world. `world.gd`'s current
  `reload_current_scene()` on `game_loaded`/`game_reset` (world.gd:258) CANNOT survive
  title-first boot (it would reload the title). Lane S ships the manager:
  `Main.swap_to_world()` / `swap_to_title()`; `game_loaded`/`game_reset` now
  re-instantiate the world child via the manager. Every load path (defeat banner →
  auto-load, pause-menu load, title Continue, Quit-to-Title → Continue) routes through
  it and is QA-covered (`defeat_reload` + `save_load_roundtrip` + new `title_flow`).
- **Boot flow:** app starts at title. New Game builds a fresh sim. QA title-skip:
  TestDriver, when active and the script doesn't declare `"starts_at_title": true`,
  auto-advances through New Game before step 1 — existing scripts unchanged except
  this harness behavior. QA greenness is judged **at every lane-merge gate**, not
  mid-lane (11 of 12 scripts open on `world_ready` and are structurally red between
  S's main-scene flip and the title-skip landing — those land in the same task).
- **Pause menu adds "Quit to Title"** with a confirm row ("Unsaved progress since the
  last autosave is lost — quit?"). No autosave-on-quit (explicit user testing surface).
- **Defeat flow unchanged** (banner → reload auto).
- Title music (see Audio). New QA script `title_flow`: boot → title rendered → New Game →
  world_ready → Esc → Quit-to-Title → title rendered → Continue → world_ready with
  restored state.

## 3. Combat hotbar (Lane H — sequenced after Lane R merges)

- **Movement first (consultant B4):** arrows move the active unit DIRECTLY during the
  player turn (spending move pool, then refusing with feedback) — no Move mode, no bar
  arrow-navigation; Mode.MOVE is deleted and Dash simply refills pool (its auto-Move
  behavior from M4.1 becomes moot — dash then walk with arrows). The 3-free-steps
  economy is always one keypress away.
- Bottom-center icon bar (native-res UI layer): slot 1 Attack, slot 2 Dash, slots 3+ =
  combat skills in `skills.json` order. **Number keys 1–9 activate slots** (new input
  actions in project.godot, incl. `end_turn` on E); Esc = cancel as today; Tab/Enter
  targeting unchanged.
- Slot renders: icon, keybind number, AP cost pips, MP cost diamonds, greyed when
  unaffordable (reuses `_menu_row_affordable`/`_skill_affordable` gates), selected-slot
  highlight ring. AP ●, move ○, and MP readouts sit in a strip directly above the bar.
- Targeting/direction-picking UX unchanged this milestone (Tab cycles, Enter confirms) —
  the hotbar replaces the MENU/SKILL_PICK modes' text lists, not targeting.
- Icons: Tiny Swords UI/icon sheet where a fit exists; otherwise 16px authored icons
  (controller-generated or hand-picked pack crops; screenshot-verified). Icon ids live in
  `skills.json` (`"icon": "..."` registry ids) + `sprites.json` entries — data-driven.
- End Turn stays reachable (dedicated key E + a small labeled slot at the bar's right).
- Feed and turn-order strips restyle into the native-res layer (top: turn order; bottom
  above hotbar: feed). Emits `ui_hotbar_rendered {slots: N}`.

## 4. Audio (Lane A)

- **Buses:** Master → Music / SFX / UI / Voice. Default volumes; settings persisted via
  ConfigFile (`user://settings.cfg`). Lane A ships `WIAudio.set_bus_volume(bus, v)` +
  persistence; the settings UI ROWS (Music/SFX 0–10 in pause + title) are Lane S's, so
  pause_menu.gd has exactly one owner (S). Keep the surface minimal.
- **`WIAudio` autoload** (presentation-side, like ObservableBus consumers): listens to
  domain events, plays mapped sounds per **`data/audio.json`**:
  `{event_type[+payload discriminator] → {stream, bus, volume_db, cooldown_ms}}`.
  Minimum map: menu move/confirm, dialogue open/choice, toast, footstep (player_moved,
  cooldown-throttled), attack hit/miss, skill cast (per element), dash, hurt, downed,
  victory/defeat stings, level-up/class-gained sting, quest chime, save chime.
- **Music:** xDeviruchi tracks assigned per context — title, inn, street, combat (+
  victory sting from Minifantasy if it fits); crossfade ~1s on context change
  (map_changed/combat_started/combat_resolved/title). Loop points: use the pack's loop
  versions if provided, else plain loop.
- **Text blips + typewriter: CUT from M5 core (consultant cut-first rec, accepted).**
  Moved to a post-merge stretch task: lowest feel-yield, sole cause of three-lane
  contention on dialogue_panel.gd, and a fresh QA-pacing hazard. If the stretch lands:
  typewriter ~40 chars/s, per-speaker tones (Erin bright / Selys dry / Lyonette
  refined), and it MUST follow the **standing presentation-pacing rule** (new,
  promoted repo-wide): any presentation delay is 0 when `TestDriver.active()` or
  headless — same pattern as AI_BEAT.
- **Web audio policy (consultant I9):** browsers suspend audio until a user gesture and
  itch iframes lack keyboard focus until clicked. The title screen therefore requires a
  "Press any key" beat before starting music (satisfies the gesture), and the itch page
  embed uses click-to-focus. Verified in the web-parity QA run + one manual browser
  check before milestone close.
- Every played sound emits `audio_played {id, bus}` on the bus. QA asserts these ONLY
  via `assert_event_logged` (whole-run audit) — never `wait_for_event` on a
  cooldown-throttled sound (consultant I8: wall-clock `cooldown_ms` can swallow the
  awaited instance in zero-delay runs). Playback failures must not crash headless.
- **Asset curation:** copy used tracks/SFX into `assets/audio/**` via the sync-manifest
  pattern; verify each pack's license file first (xDeviruchi + Minifantasy are known
  CC/permissive families — confirm from the shipped files, record in assets/LICENSES/).
  Mind wasm size: music as OGG (convert MP3s), target < 25MB added for the web build;
  spot-check web QA run still passes and loads.

## 5. Enemy sprites (Lane E)

- **License gate first:** read goblin-pack READMEs (3 sub-packs) + Tiny Swords terms +
  audio pack licenses; record verdicts in `assets/LICENSES/`. Anything unclear → ask user
  before shipping (prototype-use meanwhile).
- Goblin Raider → goblin-pack base; Goblin Shaman → goblin-female (distinct silhouette;
  add a tint if needed); Goblin Chieftain → goblin-sword variant (+slight scale/tint for
  elite read). All 4-directional with per-facing frames — registry already supports
  directional entries.
- **Cave Spider → "Cave Bat"** (data-only: display_name, sprite=Bat_Fur set, same stats/
  AI). Canon note: generic cave fauna, no canon violation. QA scripts referencing
  cave_spider ids: keep the combatant id stable (`cave_spider` id, new display name) to
  avoid churn, or rename id + update scripts — plan decides, disclosure required.
- Orc Crew (Pixel Crawler) stays available as extra raider variants if fights need
  visual variety (user-approved reuse).
- Relc: stays chip unless the AI-gen stretch (below) produces a usable sprite.
- Enemy idle/run/hit/death wiring mirrors the PC's combat-visual hooks (T9 pattern).

## 6. Stretch: AI sprite-generation exploration (controller task, timeboxed)

Generate Drake (Relc) sprite candidates matching the pack aesthetic (16px-scale, 4-
directional idle+walk minimum). Produce: a short doc of method + results + honest quality
assessment, candidate PNGs in a scratch dir (NOT committed to assets/), and a
recommendation (adopt / iterate / drop). User reviews candidates before anything ships.
Failure is an acceptable outcome; Relc-as-chip remains shippable.

## 7. Fable spike (parallel, no repo file conflicts)

TWI wiki research → `docs/superpowers/specs/2026-07-02-m6-canon-class-taxonomy.md`:
curated ~8–12 playable class tree (canon names/evolution lines/consolidation targets),
canon [Skills] mapped to the locked M6 mechanics (action counters, evolution thresholds,
~20–25% split friction, offered-at-sleep consolidation), NPC-flavor-only class list,
citations to wiki pages. Direct M6 spec input.

## 8. Lanes & ownership (parallelism-first)

| Lane | Owns | Depends on |
|---|---|---|
| R render core | project.godot (MERGE OWNER — see below), src/world/world.gd + camera/viewport scaffolding + world→screen projection helper, src/combat/combat_screen.gd board extraction, sprite_registry.gd, data/biomes.json (incl. skirt) + sprites.json scale fields | — (barrier: merges first; Task 1 is the input-forwarding spike) |
| S shell | new src/ui/title_screen.gd + scene wiring, src/core/game.gd boot, src/ui/pause_menu.gd, qa/scripts/title_flow.json | parallel with R (game.gd shared with A — sequence S before A's wiring commit or split files) |
| A audio | new src/audio/wi_audio.gd, data/audio.json, assets/audio/**, settings persistence, dialogue typewriter+blips (src/ui/dialogue_panel.gd) | parallel with R |
| E enemy sprites | data/sprites.json enemy entries, data/combatants.json display/sprite fields, assets/sprites/goblin*/bat*, licenses | parallel with R |
| H hotbar + UI restyle | src/combat/combat_screen.gd UI half, src/ui/* theme/backdrop touch-ups, pixel font for world-adjacent labels | AFTER R (file contention + needs final geometry) |
| Final | layout audit, screenshot recapture, docs, web-size check | all |

Contention rules (consultant I7 fixes): `project.godot` is append-only-by-section with
**R as merge owner** — S (main scene), A (autoload), H (input actions) submit their
one-line registrations, controller applies them at each lane's merge gate. `game.gd` +
`pause_menu.gd`: S sole owner, full stop. `dialogue_panel.gd`: single-owner again now
that blips are cut — H restyles it after R's UI re-parent lands. A's and S's
UI-LAYOUT-touching commits stage after R merges; their logic halves (WIAudio core,
audio.json, title-scene logic) run parallel with R. Standing rules: no controller edits
while any Codex job runs; every region/scale pick is controller-screenshot-verified.
PLAN TASK 1 (mandated): the SubViewport input-forwarding spike — wrapper scene + world
in SubViewport + one CanvasLayer moved out, then load_gate + inn_walkthrough +
combat_walkthrough seed 9 headless; fallback is a root-level `push_input` forwarder.
Also: `world.gd:48` reads pause/journal as siblings — the re-parent must rewire that
lookup. Screenshot convention gains a settle-wait after tweened moves.

## 9. QA & verification strategy

- Existing 12 scripts green **at every lane-merge gate** (see §2 for the title-skip
  window). The `inn_walkthrough` exact-hint-string assertion is brittle under S/H copy
  changes — loosen it to a stable substring when first touched.
- New: `title_flow`; audio assertions (`audio_played` for combat hit, music context
  switch, blip) folded into existing scripts; `ui_hotbar_rendered` in combat scripts.
- Web parity re-verified (audio adds wasm weight; OGG + size budget above).
- Human playtest gate at end: pacing feel (carried), hotbar feel, audio mix, smooth
  movement, title/save/continue loop, goblin/bat sprite read.

## 10. Carried M4 Minors resolved here

Sub-map grey background (world fills window now), dialogue backdrop/theme (Lane H
restyle), unclothed PC (Lane E stretch: check packs for a clothed Body_A variant or
layered outfit; else carry), pixel font for world labels (Lane H).
