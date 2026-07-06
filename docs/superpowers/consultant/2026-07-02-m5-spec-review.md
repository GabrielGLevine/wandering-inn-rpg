# M5 spec — external consultant adversarial review

**Reviewed:** `docs/superpowers/specs/2026-07-02-wandering-inn-m5-demo-feel-design.md`
**Against:** `wandering_inn_game_v4/` source on `main` (world.gd, combat_screen.gd, test_driver.gd,
game.gd, pause_menu.gd, project.godot, data/*.json, qa/scripts/*), `CLAUDE.md`, `ROADMAP.md`, `HANDOFF.md`.
**Reviewer stance:** external, no project history assumed; claims below are checked against the
actual files, with `file:line` references.

---

## Verdict: NEEDS REVISION

The lane structure, QA posture, and asset/license gating are genuinely good. But the spec's
flagship claim — "world fills the window" — is geometrically false for the maps that exist, and
two of its "unchanged" claims (defeat flow, QA scripts green throughout) are contradicted by code
paths the spec never mentions. Blocking list:

1. **B1 — Fill-the-window doesn't survive arithmetic** (§1 + §10 contradiction).
2. **B2 — The boot change breaks every load/reset path** via `reload_current_scene()` (§2/§9 contradiction).
3. **B3 — In-world text and HP overlays at 16px are unowned** and collide with the HP-visible product constraint.
4. **B4 — Move is unreachable from the hotbar as specified** (§3 internal incoherence).
5. **B5 — The integer-scaling mechanism is unspecified**, and the current project stretch setting would reintroduce the exact shimmer §1 exists to kill.

None of these are fatal to the design direction. All of them are fatal to handing this spec to a
planning pass as-is, because each one silently reassigns work between lanes R/S/H.

---

## Findings (by severity)

### B1. "World fills the window" is false for every map in the game — §1, §10

**Problem.** §1 fixes the world view at 320×180 logical / 16px cells (20×11 visible cells) with the
camera centering smaller maps. Both field maps are **10×6 cells** (`data/skeleton_scene.json:13,81`)
— 160×96 logical. That's **27% of the view area**, centered in void. The combat board (12×8 →
192×128) is ~43%. Today, at 64px cells in 1024×640, the same 10×6 map covers ~37% of the window.
**The design as written makes relative world coverage *worse* than the M4 playtest state it was
commissioned to fix** (playtest finding #1: "game must FILL the window"). §10 then claims the
sub-map grey background Minor is "resolved (world fills window now)" — it is not; the grey void
just moved inside the SubViewport and got integer-scaled.

**Failure/cost.** The first human playtest after the milestone reproduces complaint #1 verbatim,
after the most expensive lane in the milestone shipped.

**Fix.** Pick one explicitly in the spec, because each lands on a different lane:
- **Decorative skirt** (recommended): each biome renders beyond the playable grid to the view
  edges — void cells filled with non-walkable variant tiles / darkened border art. Cheap, data-driven
  (extend `biomes.json` with a `skirt`/`void` tile), owned by R, works for arenas too.
- Camera zoom per map (fills window but reintroduces non-native scaling — contradicts §1's own
  premise; reject).
- Bigger maps (content work, explicitly out of M5 scope; reject).

### B2. The title-boot change breaks defeat-reload, save/load, and quit-to-title — §2, §9

**Problem.** §2 changes the project main scene to the title screen and says "Defeat flow unchanged
(banner → reload auto)". §9 says "title-skip handling is the one structural change." Both false:
`world.gd:258` handles `game_reset`/`game_loaded` with `get_tree().reload_current_scene()`, and
`pause_menu.gd` documents the same dependency (`pause_menu.gd:57`). Once the main scene is the
title — or the world is instanced under a SubViewport wrapper scene — `reload_current_scene()`
either reloads the *title* or reloads a wrapper whose re-instantiation path nobody has defined.
That mechanism is load-bearing for: `defeat_reload` (banner → `Game.load_slot("auto")` →
`game_loaded`, `combat_screen.gd:1033-1043`), `save_load_roundtrip`, pause-menu Load/Load-Autosave,
and §2's own new Quit-to-Title → Continue flow.

**Failure/cost.** Two QA scripts red for structural reasons mid-milestone; worse, the failure mode
is "load dumps you at the title with a live sim behind it" — exactly the class of
harness-passes-player-broken bug this repo's CLAUDE.md warns about. Also a lane-ownership hole:
`world.gd` is R's, boot flow is S's, and this path spans both — the table in §8 assigns it to
nobody.

**Fix.** Spec must name the new world-rebuild mechanism (e.g. a `game_root.gd` that owns
instancing/freeing the world scene inside the SubViewport, with `game_loaded`/`game_reset`
handled there, not via `reload_current_scene`) and assign it to one lane (R, since it owns the
scene scaffolding), with S consuming it for New Game/Continue/Quit-to-Title.

### B3. Per-combatant HP/name overlays and field labels have no 16px story — §1, §3

**Problem.** The spec restyles the feed and turn-order strips (§3) but never mentions the
per-entity text that currently renders **in board/world space**: field entity name labels
(`world.gd:182-189`, default ~16px font on what will be a 16px cell — one label spans 4-6 cells),
combat name labels, HP text (`font_size 10` at `combat_screen.gd:264` — 10 *logical* px in a 16px
world view, i.e. nearest-neighbor-scaled ×4 into chunky blocks), and HP/MP bars sized in 64px-cell
units (`CELL - 6` wide, 4px tall → 1 logical px at 16px cells). Every one of these constants in
`combat_screen.gd` (ORIGIN at :10, label offsets at :239/:247/:263) is 64px-tuned. And **HP
readouts are a binding product constraint** (player-visible per M2 playtest decision, v4
CLAUDE.md) — they can't just be dropped when they stop fitting.

**Failure/cost.** Either illegible pixel-mush text inside the world viewport, or an unplanned
mid-milestone invention of a floating-label system — in `combat_screen.gd`, the file with the
strictest R-then-H sequencing, i.e. schedule contagion in the known contention hotspot.

**Fix.** Decide in the spec: in-world overlays move to a native-res overlay layer that tracks
board positions through the container transform (screen_pos = container_offset + cell × 16 × scale),
or in-viewport pixel-font labels (accepting the aesthetic). Assign it: the *mechanism* is R
(it's viewport-transform plumbing), the *styling* is H. Note the world-field labels
(`world.gd:182`) need the same decision.

### B4. The hotbar has no Move, and arrows are double-booked — §3

**Problem.** §3 enumerates slots: "slot 1 Attack, slot 2 Dash, slots 3+ = combat skills." The
current MENU the hotbar replaces is `["Move", "Attack", "Dash", "Skill", "End Turn"]`
(`combat_screen.gd:879`). **Move — the 3-free-steps-per-turn movement economy, the M3 headline
mechanic — has no slot and no key.** Meanwhile §3 keeps "arrow/Enter menu navigation ... over the
bar," so arrows can't simultaneously move the unit. As written, a player can attack but never
walk. Related: Dash currently chains into Move mode on success (`combat_screen.gd:1064-1065`, and
M4.1 hotfix item 5 makes that chaining *stronger*) — dash-to-nowhere if Move mode is orphaned.

**Failure/cost.** Not implementable as written; the planner will invent the answer, which is
exactly how spec-vs-plan drift starts.

**Fix (pick one, spec it).** Keyboard-first coherent option: **arrows move the unit directly**
when no slot is armed (move pool spends, bump feedback when empty — this *is* the default mode),
numbers arm/fire slots, Tab/Enter unchanged inside targeting, E ends turn — and drop bar
arrow-navigation entirely (numbers + highlight-on-press replace it). Alternative: keep bar
navigation and give Move slot 1 (Attack shifts right). The first matches "no test-harness feel"
better; the second is closer to today's code. Also specify: number keys pressed *during*
targeting are ignored (or cancel-and-rearm) — don't leave it to chance. Minor: E is already bound
to `interact` (`project.godot:55-59`) — mode-split is safe (world ignores input in combat,
`world.gd:46`), but call it a deliberate reuse, not a "dedicated key," and note TestDriver's
`interact` injection doubles as End Turn in combat scripts.

### B5. Integer scaling on window resize is asserted, not designed — §1

**Problem.** The project currently ships `window/stretch/mode="canvas_items"` at 1024×640
(`project.godot:25-27`). Keep that (at 1280×720) and any non-1280-wide window fractionally scales
the *entire* canvas — including the SubViewportContainer's 4× world — reinstating the blur/shimmer
§1 exists to eliminate. The spec never names the mechanism. The three real options have very
different costs: (a) `stretch/scale_mode="integer"` — one project.godot line, but letterboxes the
whole UI in 1280×720 jumps (at 1920×1080 you get 1× and ~33% of the screen as bars); (b) stretch
`disabled` + hand-rolled resize handler that integer-scales the container and re-anchors native-res
UI — the only way to get "crisp UI at any window size + integer world," but it's real code R must
own; (c) SubViewportContainer `stretch=true`, which sizes the viewport *from* the container —
wrong direction, listed only so the plan doesn't stumble into it.

**Failure/cost.** Option ambiguity here silently changes whether §1's "UI renders crisp at window
res" is even true; discovered during R, the barrier lane everything queues behind.

**Fix.** Spec picks (a) or (b) explicitly. Given "accept plain letterbox this milestone," (a) is
defensible and cheap — but then say out loud that UI letterboxes too and 1920×1080 is heavily
barred, or pick (b) and budget it.

### I6. Input routing through the SubViewport is plausible but unproven — spike it first — §1

**Assessment (per the review brief's specific questions):**
- **Screenshots: survive.** TestDriver is an autoload; `get_viewport()` at `test_driver.gd:188` is
  the **root** viewport, and the root capture composites the SubViewportContainer's drawn output
  *and* the native-res CanvasLayers. No pipeline change needed. (New minor: field tweens mean a
  screenshot right after a `move` step can catch mid-tween positions — irrelevant to event
  assertions, mildly annoying for screenshot review; add a settle-wait convention.)
- **Input: mostly survives, semantics shift.** `Input.parse_input_event` (`test_driver.gd:119`)
  feeds the root; `SubViewportContainer` does forward keyboard events into its child viewport, and
  a contained SubViewport's `handle_input_locally` is forced off, so
  `set_input_as_handled()` inside it still kills the event tree-wide. **But** the container
  forwards during its own early input stage, so nodes *inside* the viewport can now see keys
  before root-level UI `_unhandled_input` — the current precedence chain (combat > dialogue >
  pause > journal > world, `world.gd:42-48`) survives only because it's state-guard-based, not
  order-based. Two concrete lands mines: `world.gd:48` reads `_pause_menu`/`_journal` as direct
  siblings (they won't be siblings after the UI re-parent), and the whole thing depends on
  Godot 4.7 forwarding behavior nobody in this repo has exercised.
- **Fix.** Make the plan's Task 1 an explicit spike: bare wrapper scene + world in SubViewport +
  one CanvasLayer moved out, then `load_gate` + `inn_walkthrough` + `combat_walkthrough --seed=9`
  headless. If injected keys don't reach `world._unhandled_input`, the fallback (route input via a
  root-level forwarder that calls `push_input` on the SubViewport) is cheap — but only if
  discovered on day 1, not under H's deadline.
- **ORIGIN/CELL:** `ORIGIN` (32,24) and `CELL`=64 are constants in `combat_screen.gd:9-10` and
  `world.gd:9`; with camera centering, ORIGIN should die, not be rescaled — but note the combat
  board currently lives **inside a CanvasLayer** (`combat_screen.gd:1`), and CanvasLayers ignore
  Camera2D. "Board centered by the camera" therefore requires extracting the board into the world
  viewport's canvas — that's the real content of R's "combat_screen.gd board half," and it drags
  `_refresh_combatants`, `_apply_combatant_moved`, `_flash_cells` (all ORIGIN+CELL math) with it.
  The R/H "halves" share `_squares`, `_refresh`, and the playback pipeline — the split is
  sequenced, fine, but H should expect to inherit a heavily rewritten file, not today's.
- **"All existing QA event assertions survive unchanged":** directionally true (events are
  sim-side and the counts asserted are render-agnostic), with three exceptions the spec should
  name: (1) the B2 reload path above; (2) 11 of 12 scripts open with `wait_for_event world_ready`
  — red until title-skip lands, so "stay green **throughout**" (§9) is unachievable during Lane S
  by definition; phrase it as "green at every merge gate" instead; (3) `inn_walkthrough` asserts
  the *exact* hint string ("Esc — menu (save/load)...") — any S/H copy change breaks it; that's a
  brittle assertion to fix opportunistically.

### I7. §8's ownership table contradicts itself — §8

- `project.godot`: table says Lane R owns it; §8's own text has A registering the WIAudio autoload
  in it; H needs it too (input actions for keys 1–9 and End Turn — none exist today,
  `project.godot:29-80`). Three writers for the file the table gives one owner.
- `game.gd`: table row S says "game.gd shared with A — sequence S before A's wiring commit";
  §8 text says "S is the sole owner" and A touches project.godot **only**. Both can't be true.
- `dialogue_panel.gd`: A owns it "parallel with R" — but R's UI re-parenting (§1 "UI moves to
  native-res CanvasLayers") re-homes and re-sizes that exact node (`world.gd:31` instantiates it
  as a world child). A builds the typewriter against a layout R is concurrently invalidating.
  Same applies to S's pause_menu work.

**Fix.** Declare project.godot append-only-by-section with R as merge owner; delete the
"game.gd shared with A" note (the autoload design makes it unnecessary — correct call, just
finish it); and stage A/S's *UI-layout-touching* commits after R's re-parent lands (their
non-layout halves — WIAudio core, audio.json, title scene logic — stay parallel). This is the
predecessor-flagged self-contradiction class; it's here, in the section written to prevent it.

### I8. Typewriter reveal has no QA zero-delay rule — §4, §9

**Problem.** The repo already learned this lesson with AI playback: `_beat_delay()` returns 0 when
`TestDriver.active()` or headless (`combat_screen.gd:904-907`), because QA must never wait on
presentation pacing. §4's typewriter (~40 chars/s) and per-N-chars blips have no such clause.
Dialogue scripts inject choice keys immediately after `ui_dialogue_shown`; whether that races the
reveal depends on implementation choices the spec doesn't constrain. Related flake risk:
`audio.json` `cooldown_ms` is wall-clock — in zero-delay headless runs, back-to-back events
(footsteps especially) can swallow the exact `audio_played` instance a script asserts.

**Fix.** One spec line: "typewriter/blips follow the AI_BEAT pattern — instant reveal, no blips,
when `TestDriver.active()` or headless; promote this to a standing rule for all presentation
pacing." And: fold `audio_played` assertions in as `assert_event_logged` (whole-run audit), never
`wait_for_event` on a cooldown-throttled sound.

### I9. Browser audio autoplay and iframe focus are unhandled — §4, missing

**Problem.** The launch target is an itch.io **web** demo. Browsers suspend the AudioContext until
a user gesture, and an itch iframe doesn't have keyboard focus until clicked — for a keyboard-only
game this means: stranger opens the page, title music doesn't play, keys do nothing, first
impression is "broken." §4 budgets wasm *size* but not wasm *audio policy*.

**Fix.** Title screen requires one interaction before music starts anyway — make that explicit:
"Press any key / click to begin" pre-title beat (doubles as the focus-grabber and the audio
gesture), and verify in the web QA run that `audio_played` for title music fires only post-gesture
rather than silently failing. This is a one-evening feature that saves the first thirty seconds of
every stranger's demo.

### M10. Minor notes

- **§5 Cave Bat**: sound. Keep the `cave_spider` id (registry-swap cost is zero, script churn
  isn't); the disclosure requirement is the right call.
- **§5 goblin variants**: "distinct silhouette; add a tint if needed" — the M4 NPC-tint lesson
  says verify distinctness by screenshot, not intention; fold into the standing windowed-check rule.
- **§1 tween + rapid input**: field QA injects moves every 2 frames; 0.12s tweens must be
  kill-and-restart (or retarget), else positions lag the sim. Visual-only, but worth one spec word
  ("interruptible").
- **§2 Continue = newest of auto/manual**: fine; note manual saves are blocked mid-combat/dialogue
  (`game.gd:36`) so "newest" can't resurrect a modal state — good property, keep it true.
- **Fullscreen toggle** (F11 / borderless): strangers expect it in a "feels like a game"
  milestone; trivially cheap alongside B5's resize work. Spec omits it.
- **First-run defaults**: name the numbers (e.g. Music 7/10, SFX 8/10) so the human playtest gates
  a real mix, not whatever the implementer left in.

---

## The one thing I'd cut first: the typewriter + per-speaker blips (§4's dialogue half)

Rationale: it's the only §4 item with *negative* schedule synergy — it adds a QA-pacing hazard
(I8), it's the piece of Lane A that collides with R's UI re-parent and H's dialogue restyle
(dialogue_panel.gd is the only file with three lanes near it), and its demo-feel yield is the
lowest in the spec: a stranger notices missing SFX and missing music immediately; nobody notices
missing per-speaker text blips. Cut it and Lane A becomes almost purely additive (autoload + JSON
+ assets), which is the safest shape for the week you have. Keep a single "dialogue opened" sound
so dialogue isn't silent.

Second and third cuts, for the record: H's restyle breadth (feed/turn-strip/theme/pixel-font —
ship the bare hotbar over today's visuals), then E's variant differentiation (one goblin base +
tints for all three enemy types). I would not cut the title/continue shell — it's the only thing
standing between you and another "save/load still human-untested" playtest line, which has now
appeared in two consecutive handoffs.

## What I'd add that the spec missed

1. **A void-fill treatment** (B1) — without it the milestone's stated goal fails on its own maps.
2. **A named owner + mechanism for world re-instantiation on load/reset** (B2).
3. **An in-world-text/HP-overlay strategy at 16px** (B3) — it's a product-constraint collision,
   not a polish item.
4. **A day-1 input/screenshot spike task in Lane R** (I6) with pass/fail QA gates, before S/A/H
   build on the new tree.
5. **The integer-scaling mechanism decision** (B5), stated in terms of which project setting or
   code owns resize.
6. **A "press any key" web-gesture beat + autoplay/focus handling** (I9).
7. **A standing zero-delay rule for all presentation pacing** (I8), written into v4 CLAUDE.md, not
   just this spec.

---

*Overall: the spec is two or three honest paragraphs away from being executable. Its instincts —
lanes, license gates, QA-first, data-driven icons — are right. Its failures are all of one kind:
asserting that existing structures survive a change without checking the three files where they
don't. The fixes above are spec-text fixes, not design pivots; the hybrid render direction itself
is sound and worth the week.*
