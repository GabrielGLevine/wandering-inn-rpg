# M5 — Demo Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** title-screen-to-demo experience — window-filling 16px pixel world with smooth movement, sound, icon hotbar combat, and a save/continue loop.

**Architecture:** per spec REV 2 (`docs/superpowers/specs/2026-07-02-wandering-inn-m5-demo-feel-design.md` — READ IT FIRST, it is the authority; this plan sequences it). Sim core untouched. World moves into a 320×180 SubViewport (16px cells) under a new root `Main` scene; UI stays native-res. Five lanes: R (render, barrier), S (shell), A (audio), E (enemy sprites), H (hotbar), then final polish.

**Tech stack:** Godot 4.7, GDScript, existing QA harness. Consultant review findings (B1–B5, I6–I9) are binding — each is cited at the task that discharges it.

## Global Constraints

- Everything in the M4 plan's Global Constraints carries over verbatim (purity, zero warnings, canonical seeds, GDQuest style, no raw stats player-facing, potential_assets gitignored, controller screenshot-verifies every region/scale pick, no controller edits during live Codex jobs).
- **QA green at every lane-MERGE GATE** (not mid-lane); full 13-script sweep + web parity before milestone close.
- **Standing presentation-pacing rule (NEW, repo-wide):** any presentation delay/reveal is 0 when `TestDriver.active()` or headless.
- `audio_played` assertions use `assert_event_logged` only — never `wait_for_event`.
- `project.godot` is append-only-by-section; R is merge owner — S/A/H registrations are applied by the controller at merge gates.
- License gate before any new-pack asset ships (goblin packs, Tiny Swords, audio packs): read the shipped license/README, record verdict in `assets/LICENSES/`, unclear → ask user.

## Lane / task map

```
Lane R (barrier):    R1 spike → R2 Main+viewport scaffold → R3 16px recalibration → R4 camera+skirt → R5 tween+overlay-labels → R6 combat board extraction
Lane S (parallel):   S1 title scene+scene-manager (+R2 handshake) → S2 quit-to-title+settings rows → S3 title_flow QA
Lane A (parallel):   A1 WIAudio+audio.json+SFX map → A2 music contexts → A3 asset curation+licenses+web budget
Lane E (parallel):   E1 goblin/bat licenses+extraction → E2 registry entries+combatant wiring
Lane H (after R):    H1 hotbar → H2 UI restyle (theme/font/backdrops) → H3 movement-first input (B4)
Final:               F1 integration audit + screenshot recapture + docs → F2 stretch (typewriter+blips, AI-gen Drake) → Opus final review
```

Dispatch order: R1 first and alone (day-1 spike, consultant I6). Then R2+S1 coordinate (one interface: `Main` scene contract). R3–R6 sequential in lane R; S2–S3, A1–A3, E1–E2 parallel to R. H after R merges. F after all.

---

### Task R1: SubViewport input/screenshot spike (consultant I6 — MANDATED FIRST)

**Files:** Create `wandering_inn_game_v4/src/world/main.tscn` + `src/world/main.gd` (skeleton only); modify nothing else. Throwaway branch of world wiring INSIDE the new scene.

Build the minimal wrapper: `Main` (Control, full-rect) → `SubViewportContainer` (stretch=false, scale 4×, centered) → `SubViewport` (320×180, `handle_input_locally` default) → instance today's world scene content; move ONE CanvasLayer (message_layer) out beside the container. Set `stretch/scale_mode="integer"` in project.godot (B5).

- [ ] Wire it so the game boots into Main with the world inside the SubViewport (temporary main-scene flip).
- [ ] Run `load_gate`, `inn_walkthrough --seed=9`, `combat_walkthrough --seed=9` headless. PASS = injected keys reach `world._unhandled_input` through the container. FAIL = implement the fallback: a root-level forwarder calling `SubViewport.push_input(event)` for unhandled root input; re-run.
- [ ] Windowed screenshot: world renders 4×-scaled, message layer crisp at native res.
- [ ] Verify `world.gd:48`-style sibling lookups (`_pause_menu`/`_journal`) still resolve — if the re-parent broke them, note the required rewiring for R2 (do not fix beyond the spike's needs).
- [ ] Report the verdict (forwarding works natively / fallback required) — R2..R6 and S1 briefs depend on it. Commit as a WIP scaffold (main scene flip NOT yet committed if scripts would break — keep old main scene until S1; the spike commit must leave all QA green via the old boot path).

### Task R2: Main scene + viewport scaffold (landed for real)

**Files:** `src/world/main.gd/.tscn`, `src/world/world.gd` (re-parent + sibling lookups), `project.godot` (viewport 1280×720, integer scale_mode; main scene STAYS world-boot until S1 flips it), every `src/ui/*.gd` CanvasLayer moved to native-res layer parented under Main.

**Interfaces:** `Main` exposes `world_root()` (the SubViewport's content node) and `ui_root()`; S1's title work plugs into `Main.swap_to_title()/swap_to_world()` (S owns those methods' bodies; R2 stubs them). Produces the world→screen projection helper: `Main.world_to_screen(world_pos: Vector2) -> Vector2` (camera+container transform) — H and R5 consume it.

- [ ] Land the R1 structure permanently, all UI layers re-parented, sibling lookups rewired (world.gd gets explicit NodePath/exports instead of sibling assumptions).
- [ ] Full 13-script QA sweep green (this is a merge gate). Windowed screenshots of field + combat + dialogue.
- [ ] Commit.

### Task R3: 16px recalibration

**Files:** `src/world/world.gd`, `src/combat/combat_screen.gd` (CELL only), `src/world/sprite_registry.gd`, `data/biomes.json`, `data/sprites.json`.

- [ ] FIRST: verify every committed sheet's native tile/frame grid by pixel inspection (report actual numbers; M4 wrongly assumed 32px for free-pack floors/walls — spec §1). Controller screenshot-verifies every corrected pick.
- [ ] CELL := 16 in field + combat; tile layers at native tile size scale CELL/tile_px; character sprites anchored feet-to-cell-bottom in a Y-sort container; chips at 16px; HP/MP bars as 1–2px in-viewport pixel bars (B3 split — text comes off-board in R5).
- [ ] QA sweep + windowed screenshots (movement no longer jumpy is the human gate; correctness gate = all green, sprites/tiles aligned in screenshots).
- [ ] Commit.

### Task R4: camera + skirt fill (B1)

> **AMENDED by the immersion design spike (user mandate 2026-07-02):** R4 implements
> `docs/superpowers/specs/2026-07-02-environment-ui-immersion-design.md` §1–§4 — floor_layers/
> walls/decor schema + inn/street compositions + dressed arena skirts — not bare skirt tiles.
> H1/H3 implement its §5 UI chrome (Tiny Swords parchment/carved kit). Exit bar per its §6.

**Files:** `src/world/world.gd`, `src/combat/combat_screen.gd`, `data/biomes.json` (+`skirt` coords per biome).

- [ ] Camera2D: center maps/arenas smaller than the view; clamped-follow for larger.
- [ ] Skirt rendering: paint per-biome skirt tiles from grid edge to view bounds (non-walkable, visual only). Exit bar: windowed screenshot of BOTH maps + BOTH arenas shows art to every edge.
- [ ] `ui_map_rendered`/`ui_arena_rendered` payloads unchanged. QA sweep. Commit.

### Task R5: tweened movement + native-res world-anchored text (B3)

**Files:** `src/world/world.gd`, `src/combat/combat_screen.gd`, new `src/ui/world_labels.gd` (native-res overlay layer: name labels + HP/MP numerals tracking units via `Main.world_to_screen`).

- [ ] Field + combat step tween ~0.12s (within combat playback beats); blocked-move bump nudge. Screenshot settle-wait convention added to TestDriver (I6 note): `screenshot` waits 0.15s when not headless.
- [ ] All unit name/HP text moves to the overlay (binding: HP numerals stay player-visible); in-board Labels deleted.
- [ ] QA sweep + windowed. Commit. **LANE R MERGE GATE.**

### Task R6: combat board extraction (I6)

**Files:** `src/combat/combat_screen.gd` (board out of CanvasLayer into world viewport canvas; ORIGIN dies; flashes/holders move with it; panels stay UI-layer pending H).

- [ ] Extract; camera centers board on combat_started, returns to player on ui_combat_hidden.
- [ ] Combat QA (walkthrough 9, lul 11, mage 9, los 9, defeat 1) + windowed. Commit.

### Task S1: title scene + scene manager (B2)

**Files:** `src/ui/title_screen.gd`, `src/world/main.gd` (swap_to_* bodies), `game.gd` (new-game/continue entry), `qa/test_driver.gd` (title auto-skip unless `"starts_at_title": true`), `project.godot` main-scene flip (via controller at merge).

- [ ] Title: "Press any key" beat (I9 web gesture) → menu New Game / Continue / Quit; Continue iff a save exists (loads newest); emits `ui_title_rendered`.
- [ ] `game_loaded`/`game_reset` re-instantiate the world child via Main (replaces `reload_current_scene` — B2). Defeat + pause-load + Continue + Quit-to-Title all route through it.
- [ ] Title auto-skip in TestDriver; ALL 13 scripts green at this merge gate (same task as the flip — spec §2).
- [ ] Commit.

### Task S2: quit-to-title + settings rows

**Files:** `src/ui/pause_menu.gd` (Quit-to-Title + confirm row; Music/SFX 0–10 rows calling `WIAudio.set_bus_volume`), title settings mirror.

- [ ] Implement; hint-string assertion in inn_walkthrough loosened to stable substring when touched (I6 note). QA sweep. Commit.

### Task S3: title_flow QA script

- [ ] New script per spec §2 (boot→title→New Game→world_ready→Esc→Quit-to-Title→title→Continue→world_ready restored); `"starts_at_title": true`. Seed 9. Add to CLAUDE.md table. Commit.

### Task A1: WIAudio + audio.json + SFX map

**Files:** `src/audio/wi_audio.gd` (new autoload — registration via controller at merge), `data/audio.json`, `assets/audio/**` (curated), `tests/test_audio_data.gd` (validates audio.json ids/paths).

- [ ] Bus layout; event→sound map per spec §4 list; `audio_played {id, bus}` emission; cooldown_ms throttling; headless-safe (no crash without audio device).
- [ ] QA: `assert_event_logged audio_played` for attack-hit folded into combat_walkthrough; sweep. Commit.

### Task A2: music contexts

- [ ] Title/inn/street/combat tracks, ~1s crossfade on context events; victory sting. OGG only. Commit.

### Task A3: audio curation + licenses + web budget

- [ ] License verdicts recorded (xDeviruchi, Minifantasy, Super Dialogue for stretch); MP3→OGG conversion; committed audio < 25MB; `run_web_qa.sh combat_walkthrough 9` passes and load time noted. Commit.

### Task E1: enemy sprite licenses + extraction

- [ ] Read goblin-pack×3 READMEs + Tiny Swords terms; record in assets/LICENSES/ (unclear → surface to user, prototype-only meanwhile); extend tools/sync_assets.py manifest; extract goblin base/female/sword + Bat_Fur sheets. Commit.

### Task E2: enemy sprites wired

**Files:** `data/sprites.json`, `data/combatants.json`, `data/skeleton_scene.json` (encounter markers if sprite-able).

- [ ] Raider=base, Shaman=female(+tint if needed), Chieftain=sword variant(+elite tint/scale); cave_spider id keeps, display "Cave Bat" + Bat_Fur sprite (disclosure in report); idle/run/hit/death wired via T9 hooks; 4-directional facings.
- [ ] Combat QA sweep + windowed screenshot of both arenas (controller verifies silhouettes read). Commit.

### Task H1: hotbar

**Files:** `src/combat/combat_screen.gd` (UI half), new `src/ui/hotbar.gd`, `data/skills.json` (+`icon` ids), `data/sprites.json` (icon entries), `project.godot` input actions (1–9, E — via controller at merge).

- [ ] Bar per spec §3: slots Attack/Dash/skills, number-key activation, cost pips/diamonds, greyed via existing affordability gates, selected highlight; End Turn slot + E; `ui_hotbar_rendered {slots}` asserted in combat scripts. MENU/SKILL_PICK text lists die.
- [ ] Icons: Tiny Swords fits else 16px crops — every icon screenshot-verified by controller. QA sweep + windowed. Commit.

### Task H2: movement-first input (B4)

- [ ] Arrows move the active unit directly during player turn (pool spend, refusal feedback); Mode.MOVE deleted; Dash refills pool only. Targeting (Tab/Enter) unchanged. Update CLAUDE.md combat-controls docs.
- [ ] Combat QA sweep (autoplay unaffected — regression only) + windowed. Human-playtest item logged. Commit.

### Task H3: UI restyle

- [ ] Theme resource + pixel-adjacent font for headers/labels (body text stays readable-size), dialogue/journal/pause backdrops unified, toast/hint restyle. Screenshot audit of every screen. Commit.

### Task F1: integration audit + recapture + docs

- [ ] Full 13-script sweep + web parity + all unit tests; screenshot recapture; CLAUDE.md M5 block (render architecture, pacing rule, audio map, hotbar controls, new seeds); HANDOFF status + next-playtest checklist (pacing cadence, hotbar feel, audio mix, movement smoothness, title/save loop, goblin/bat read). Commit.

### Task F2 (stretch, only if schedule allows): typewriter+blips (per spec cut note, MUST follow pacing rule); AI-gen Drake exploration (controller, per spec §6).

### Final gate: mandatory Opus whole-branch review + fix wave (M2–M4 precedent).

## Self-review notes
- Consultant blockers discharged at: B1→R4, B2→S1, B3→R3+R5, B4→H2, B5→R1/R2; I6→R1+R5+R6, I7→lane map + controller merge rule, I8→Global Constraints, I9→S1+A3.
- The plan intentionally carries less inline code than M4's: R-lane geometry depends on the R1 spike verdict and per-sheet pixel audits; briefs get exact values at dispatch time from the spec + spike report. Task-level exactness lives in the spec's REV 2 sections, which are unusually precise.
