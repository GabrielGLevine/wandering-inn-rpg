# Map Direction Cards (M-BEAUTY §3)

One card per map: focal point, accent hue, dressing density, light
anchors, ambience set, mood values. The floodplains card below is the
PILOT-CALIBRATED reference — rollout cards derive their values from it.

## Floodplains — "the road at blue hour" (PILOT, 2026-07-05)

- **Focal point:** Relc's campfire — the one warm thing in a cooling
  world; every wide shot composes around its pool.
- **Mood values (calibrated over 3 pilot iterations):**
  day identity · dusk `[0.45, 0.50, 0.92]` · night `[0.30, 0.36, 0.72]`
  · vignette `0.4`. The dusk multiply reads blue-grey over green grass
  (a true blue needs darkness — night's values go deeper for it).
- **Light anchors:** campfire (warm orange, flicker) — pilot-verified;
  rollout may add the inn-porch lantern.
- **Ambience:** fireflies + pond_glints over the pond rect (dusk/night);
  grass sway on all foliage (always, subtle).
- **Calibration lessons (apply to every rollout card):**
  1. CanvasModulate MULTIPLIES — it cannot add hue. Blue-hour = darken
     hard + push B; expect green-influenced results over grass; the warm
     lights are what make the grade read as evening.
  2. Vignette below ~0.3 is imperceptible at 320×180; 0.4 = soft frame.
  3. Particle scale: fireflies 0.2–0.4, glints 0.15–0.35 on the 8px dot —
     anything larger reads as blobs at 4× zoom.
  4. Any custom canvas_item shader MUST multiply by COLOR or it drops the
     mood grade (the pond bug, caught frame one).

## Rollout cards (post-verdict, values TBD from the pilot's calibration)

## Inn — "hearth and shadow" (ROLLOUT R1, 2026-07-05, SHIPPED)

- **Focal point:** the hearth [2,1]/grill [3,2] cluster — already lit
  (M-BEAUTY B2) and flickering; the mood grade is tuned to make that
  warmth read as the room's one deliberate light source once dusk hits.
- **Mood values (2 iterations, both staged into the `day` slot + a
  temporary `meta.light_energy_by_phase.day = 1.0` for the peek, per the
  pilot's own throwaway-shot method — see the report for both PNGs):**
  day identity (`[1,1,1]`, unchanged — every canonical script boots at
  inn/day, so this stays a hard zero-behavior-change floor) · dusk
  `[0.85, 0.72, 0.55]` · night `[0.55, 0.50, 0.62]` · vignette `0.4`.
  Iteration 1 (the dusk candidate) read warm and cozy on the first try —
  amber multiply over the already-warm plank/kitchen floor tiles plus the
  lit hearth/grill glow landed close to Stardew-cozy with no further
  adjustment. Iteration 2 (the night candidate) deliberately leans the
  multiplier's B channel ABOVE its R/G (`0.55/0.50/0.62`, B highest) — on
  the warm-toned floor (low native blue) this reads as only mildly
  dimmer/warm, but on the grey stone walls (higher native blue) it pulls
  a genuine cool-blue cast, giving "window-blue night" on the neutral
  surfaces while the floor/hearth pool stay candlelit-warm, per the
  card's own brief — confirmed by the final (non-staged, real dusk-phase)
  `atmosphere_check` screenshot.
- **Light anchors:** hearth + grill (both already shipped B2, warm/
  flicker) — unchanged this task; no new anchors needed, the mood grade
  alone (not new lights) carries the "hearth and shadow" read.
- **Ambience:** dust motes (`rect: "all"`, dusk/night — already shipped
  B3, unchanged this task).
- **Shots:** `.superpowers/sdd/fp-handoff/r1-shots/inn_iter1_00_start_day.png`
  (staged dusk candidate), `inn_iter2_00_start_day.png` (staged night
  candidate), `inn_final_01_dusk.png` (the real pipeline's dusk render,
  `atmosphere_check`'s `01_dusk.png` — hearth/grill glowing, dust motes
  drifting, vignette framing the room).

## Cave/arenas — "dark that means it" (ROLLOUT R1, 2026-07-05, SHIPPED)

- **Arena-inherits-field decision, resolved:** B1 found that a combat
  arena has no CanvasLayer of its own and shares the world SubViewport's
  one CanvasModulate with the field, so it inherits whatever mood is
  CURRENTLY applied for free. That is correct for `goblin_ambush`/
  `training_yard` (open-air arenas — a phase-appropriate outdoor grade is
  the right look for them) but wrong for `cave_mouth`: fighting the
  Chieftain's Raid at midday inherited the FIELD's bright day-identity
  grade, i.e. a "cave" that looked like broad daylight. **Cave NEEDS its
  own pin** — the open question from the plan is resolved in favor of a
  per-arena override, implemented as a small `atmosphere.gd` addition
  (`apply_arena()` + `arena_moods` lookup, gated on `COMBAT_STARTED`'s
  `combat.arena_id`) rather than a field-inheritance workaround. Full
  design/implementation notes live in `atmosphere.gd`'s own Task R1 doc
  comments and the task report.
- **Mood values:** `data/moods.json`'s new `arena_moods.cave_mouth` entry
  — day/dusk/night all identical, `[0.30, 0.32, 0.45]`, vignette `0.45`
  (above the pilot's own 0.4 "soft frame" threshold — pushed slightly
  further since the cave has no actual light-pool anchors yet to carry
  the read on their own). Time-invariant by design: a cave is dark
  regardless of the hour outside it.
- **Light anchors:** NOT shipped this task. `board_renderer.gd`'s arena
  `decor` rendering path (`_build_arena_decor`/`_make_decor_visual`) has
  no `light` dict handling at all — unlike `world.gd`'s field-decor path
  (M-BEAUTY B2), it never calls anything like `_spawn_light`. Wiring that
  in is a `board_renderer.gd` change, outside this task's file scope;
  flagging for a follow-up rather than scope-creeping a combat-rendering
  file into a data/atmosphere task. The dark mood pin alone (no lights)
  already reads as "a cave, genuinely dark" per the verification shot
  below — light pools are a nice-to-have polish pass, not required to
  ship the core "dark that means it" read.
- **Ambience:** none shipped (no ember/dust preset authored for
  cave_mouth's arena `decor` this task, same file-scope reasoning as the
  lights above — `board_renderer.gd` has no `ambience` data path either).
- **Shot:** `.superpowers/sdd/fp-handoff/r1-shots/cave_mouth_chieftains_raid_combat.png`
  — a fresh-boot (day-phase field) run into `chieftains_raid`; the arena
  renders in the new dark/vignetted grade despite the field being at day
  identity, proving the override fires independently of the field's own
  phase.

## Title — "first impression" (ROLLOUT R1, 2026-07-05, SHIPPED)

- **Approach:** `src/ui/title_screen.gd` gained a `_build_embers()` call,
  spawning one `WIAmbience.make("embers", ...)` GPUParticles2D sized to
  the full native 1280×720 window rect, added right after the backdrop
  and before the title ribbon/menu/notice panels so it always draws
  BEHIND them (tree order = draw order within one CanvasLayer). No new
  visual vocabulary invented — reuses the exact preset the in-world
  campfire/hearth embers already use, so the title screen's first
  impression rhymes with the game's own look. Not phase-gated (title has
  no time-of-day) and not registered with `WIAtmosphere` (that registry
  is for the world-viewport's own lights/emitters only) — it just emits
  continuously for as long as the title screen is alive.
- **Mood/grade:** none — the title screen is native-res UI entirely
  outside the world SubViewport (per `atmosphere.gd`'s own B1 finding),
  so no CanvasModulate applies here; "graded" per the original card text
  turned out not to apply structurally, embers alone carry the beat.
- **Shots:** `.superpowers/sdd/fp-handoff/r1-shots/title_01_title_gate_embers.png`,
  `title_02_title_menu_embers.png` — small warm dots drifting slowly
  across the black backdrop, visible but clearly behind/around the
  ribbon and button panels, never overlapping readable text.

## Gate district — "torchlit stone" (ROLLOUT R2, 2026-07-05, SHIPPED)

- **Focal point:** no single hero light — the district reads as a network
  of small torch pools (3 sconces + 2 now-lit campfires + the sewer
  grate's cold green accent) picking out stonework against a dark,
  cool-leaning base, per the "torch pools on cool stone, dark alleys"
  brief. Unlike floodplains (one campfire) or the inn (one hearth
  cluster), the gate district's read is deliberately plural/scattered —
  it's a night market street, not a single room.
- **Mood values (2 iterations, staged into the `day` slot + a temporary
  `meta.light_energy_by_phase.day = 1.0` for the peek, per the pilot's
  own throwaway-shot method — reverted before shipping the real dusk/
  night values; shots in `.superpowers/sdd/fp-handoff/r2-shots/`):**
  day identity (`[1,1,1]`, unchanged) · dusk `[0.35, 0.40, 0.65]` ·
  night `[0.24, 0.28, 0.48]` · vignette `0.44` (above the pilot's 0.4
  floor, per the brief's "night-leaning map" call). Both dusk and night
  are darker/cooler than floodplains' own dusk (`[0.45, 0.50, 0.92]`) —
  night additionally reads darker than floodplains' own NIGHT
  (`[0.30, 0.36, 0.72]`), reinforcing that this map skews dark
  regardless of hour, echoing (at a shallower depth) the cave arena's
  time-invariant-dark treatment from R1. Iteration 1 (`[0.35,0.40,0.65]`,
  vignette 0.42) already read well against the brief on the first try —
  cool stone-blue, torch pools clearly legible; iteration 2
  (`[0.26,0.30,0.52]`, vignette 0.46) pushed darker/cooler for
  comparison and was judged marginally moodier. Final split: iteration
  1's values shipped as `dusk` (the first step down from day), a
  further-darkened value close to iteration 2 shipped as `night`
  (`[0.24,0.28,0.48]`) — mirroring floodplains' own dusk-lighter-than-
  night progression, since `vignette` is a single flat-per-map field
  (not phase-keyed) and can't itself carry that step.
- **Light anchors:** the 3 sconces + sewer grate anchors already existed
  (B2). R2 adds the two street `campfire` decor pieces (`[3,5]` and
  `[13,10]`), previously shipped deliberately unlit (B2's own note: "full
  gate-district night dressing is the rollout task's job") — lighting
  them (`color:[1.0,0.55,0.25], energy:1.0, radius:34, flicker:true`,
  between the sconces' amber and Relc's/hearth's warmer hero-fire values)
  does double duty: it's this card's 2 new torch-pool anchors AND the
  fix for the "reads as a fake sewer grate" bug (see VISUAL-LOG Fixed —
  `campfire` and `sconce` share the same unlit stone-ring-with-embers
  art as `sewer_grate`'s own placeholder rock art; a flickering warm
  glow at dusk/night is unambiguous, the grate's own glow stays green
  and non-flicker so it stays unique).
- **Ambience:** none added this task (no ambience preset judged necessary
  for the street's own read; the existing light network carries "torch
  pools on cool stone" on its own, confirmed by the windowed dusk shots).
- **Fold-in art fixes (the three VISUAL-LOG street entries, see that doc
  for full before/after detail):** (1) roofs — a building had two roof
  pieces but only one misaligned wall tile; added the missing wall pair.
  (2) Dark Cellar door — was freestanding; dressed a wall tile beside it
  (its cell couldn't move without desyncing `crate_light`'s hardcoded
  approach-path step count, so per the brief this dressed AROUND the
  existing cell). (3) scatter/fake-grate discs — root cause traced (via
  a live render-dump, not guesswork) to the two unlit campfires above,
  not the `scatter` pool; `pebble` was cleared of suspicion empirically.
- **Shots:** `.superpowers/sdd/fp-handoff/r2-shots/` — `before_*`/`after_*`
  (day, identity grade, controller-reads the 3 fixes), `mood_iter1_*`/
  `mood_iter2_*` (staged-day-slot peeks for the two mood candidates), and
  the real (non-staged) final pipeline proof via a genuine 40-action
  dusk crossing on the street map: `00_street_day.png` →
  `01_street_dusk_south_square.png` / `02_street_dusk_roof_building.png`
  / `03_street_dusk_cellar_door.png`.
