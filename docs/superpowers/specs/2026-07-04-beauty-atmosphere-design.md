# M-BEAUTY — Atmosphere Systems + Per-Map Art Direction

Status: **APPROVED by user 2026-07-04 (night)** — interactive brainstorm off
the user's reference bar: Hyper Light Drifter (two-hue color story, luminous
accents, particle ambience), Stardew Valley night (global cool grade + warm
point lights), Secret of Mana-family (unified palette, dense intentional
dressing). Ambition locked at **systems + per-map art direction** (no
tileset replacement — the grade/light layer unifies mixed packs without
redrawing sprites). Sequencing: after M7 weapons; pilot runs as LIVE Fable +
godot-ai MCP look-dev with the user judging (this is the exact work class
the MCP was sanctioned for).

## 0. Decisions (locked)

| Decision | Call |
|---|---|
| Depth | Systems pass + per-map art direction (composition/palette per map); NO asset-pack replacement |
| Time-of-day | Sleep-driven phases (day → dusk → night), derived from existing sim counters, reset at sleep; per-map authored base moods modulated by phase |
| Pilot | **Floodplains at dusk** — full stack on the hardest scene first; user verdict gates rollout |
| Sequencing | M7 (tonight) → M-BEAUTY → Onboarding rev → Three Pillars (re-sequence after pilot if needed) |

## 1. Why this works on OUR build

The references' beauty is mostly a LIGHT-AND-COLOR layer, not sprite
quality: one dominant hue per scene + warm accents against cool ambient +
atmosphere particles. Our world renders in a 320×180 SubViewport (M5 R3),
so a single CanvasModulate, a handful of PointLight2Ds, and native-res
GPUParticles2D cost almost nothing and grade EVERY sprite from every pack
into the same palette family — the cheap unifier our mixed packs need.

## 2. The four systems (data-driven, presentation-only)

### 2.1 Grade (mood) layer
- Per-map `mood` data (new `data/moods.json`, keyed by map id):
  `{base: Color, day: Color, dusk: Color, night: Color, vignette: 0..1}` —
  phase colors are the CanvasModulate values (authored absolute, not
  multipliers — simpler to art-direct).
- Applied by a small `src/world/atmosphere.gd` node inside the world
  SubViewport. Interiors and exteriors both graded; UI layers NEVER graded
  (native-res CanvasLayers sit outside the world viewport already).
- Emits `ui_mood_applied {map, phase}` after applying (QA pins it).

### 2.2 Phase system (sleep-driven)
- `phase(): String` on WIGame — a PURE function of existing state: actions
  since last sleep (movement/interactions/fights banked in a lightweight
  `actions_since_sleep` counter; sleep resets it). Thresholds (data, in
  moods.json meta): day < D ≤ dusk < N ≤ night. Deterministic per seed.
- Sim emits `phase_changed {phase}` when a threshold crosses; sleep emits
  it back to day. Opaque-until-sleep is untouched (phase is world light,
  not progress text — no numerals surface).
- Presentation (atmosphere.gd, lights, particles) reacts to the event.

### 2.3 Light layer
- Entity/decor/scatter records may carry
  `light: {color: [r,g,b], energy: float, radius: int, flicker: bool}` —
  world.gd spawns a PointLight2D child (texture: soft radial, shipped as a
  tiny generated PNG). Combat arenas support the same via arena decor.
- Phase gates intensity: lights at ~0 energy in day, full at dusk/night
  (data multiplier per phase in moods.json meta).
- Anchors shipped with the system: inn hearth + lantern (lit state),
  Relc's campfire, gate-district torches/braziers, sewer-grate glow,
  cave = strong darkness in mood + light pools (the cave finally reads
  as a cave).
- Emits `ui_lights_rendered {map, count}`.

### 2.4 Ambience layer (particles + shaders)
- Map data `ambience: [{preset, rect|all, phase: [dusk, night]}]` with
  presets in code: `fireflies`, `dust_motes`, `leaves`, `pond_glints`,
  `embers`. GPUParticles2D at native res, budget ≤ ~64 particles/emitter.
- Shaders (canvas_item, tiny): `foliage_sway` (vertex wiggle on
  scatter/decor tagged `sway: true`), `water_shimmer` (the pond tiles),
  `vignette` (full-viewport, strength from mood data). All inside the
  320×180 viewport.
- Emits `ui_ambience_rendered {map, emitters}`.

## 3. Per-map art direction

Each map gets a DIRECTION CARD (extends the scene-assembly-guide ladder):
focal point (the one thing a screenshot composes around), accent hue
(against the map's graded base), dressing density targets per zone, light
anchors, ambience set. Cards are authored in the rollout tasks and live in
`docs/superpowers/specs/` alongside this spec (one file, all maps).
Direction targets at spec time:
- **Floodplains (pilot):** dusk sky gradient (warm horizon → cool zenith
  feel via grade + a horizon glow decor band), Relc's campfire = warm
  anchor, fireflies + pond glints, grass sway everywhere, Liscor wall as
  the dark horizon mass. HLD's "big quiet space with one warm point".
- **Inn:** Stardew-cozy — warm hearth pool, cool window moonlight at
  night, dust motes, candle flickers.
- **Gate district (night-leaning):** torch pools, dark alleys, sewer
  glow; FOLD IN the logged fixes (roof alignment, freestanding cellar
  door, grate-lookalike scatter).
- **Cave/arenas:** darkness that means it; combat arenas get the biome
  mood so fights sit in the same world.
- **Title screen:** graded + ember drift (first impression).

## 4. Pilot protocol (the taste gate)

Floodplains-dusk built FIRST, full stack + composition pass, via live
godot-ai MCP look-dev (wi-godot-mcp playbook): iterate grade/lights/
particles in-editor, screenshot at 640px, compare against the user's
reference images, repeat. USER verdict on the pilot shots gates rollout —
no other map is touched before the verdict. Pilot deliverable: 3 shots
(wide, campfire close, pond) + the floodplains direction card.

## 5. QA + performance

- QA-first: the three `ui_*` confirmations above + `phase_changed` are
  assertable; a new `atmosphere_check` canonical script pins phase
  progression (walk N actions → dusk event → sleep → day event) and the
  render confirmations per map. Phase determinism keeps every existing
  canonical seed valid (phase derives from counters, consumes NO rng).
- Existing windowed baselines change EVERYWHERE (grades tint everything)
  — rollout's F-task recaptures baselines once, like M4's art landing.
- Web parity is a rollout GATE: lights/particles/shaders must hold frame
  rate in the wasm build (roadmap constraint: wasm perf regressions are
  release blockers). Budgets: ≤8 lights/map, ≤6 emitters/map, shader
  count fixed at 3.
- Zero sim risk: the only sim touch is the `actions_since_sleep` counter +
  `phase()` + one event — unit-tested, save-persisted additively.

## 6. Out of scope

Tileset replacement; commissioned/AI sprite regeneration (separate
standing track); weather; real-time clock; day/night NPC schedules;
combat-mechanical darkness (visibility stays cosmetic).

## 7. Open items (plan time)

- Exact mood colors per map/phase — LOOK-DEV territory, pilot decides the
  floodplains card; rollout cards follow its calibration.
- Phase thresholds D/N (actions counts) — pick at plan time so dusk
  arrives mid-session organically; tune after pilot play.
- Whether combat inherits the field phase or pins per-arena mood
  (recommend: arena mood + field phase passthrough; decide in pilot).
- Firefly/glow texture sourcing: generated radial PNGs vs pack particles
  (Tiny Swords/effects packs have candidates — check asset index first).

## 8. ADDENDUM (user directive, 2026-07-05, post-pilot): label removal + visual affordances

Floating sprite name tags ("You", "Erin", "Dirty Table"…) are REMOVED
entirely for immersion — their placement/readability problems (multiple
VISUAL-LOG entries, combat overlap class) disappear with them. The
compensation contract: **every interactable must read visually without
its label** —
1. Distinct-at-a-glance: an interactable prop must be visibly different
   from lookalike scenery (the Dirty Table must look DIRTY vs the inn's
   other tables — reads before you know it's a task).
2. **State change on interaction:** props whose state changes must SHOW
   it (cleaned table looks clean; emptied chest looks open; lit lantern
   glows). Engine seam: prop `visual_states` data (sprite/region swap
   keyed on the accomplishment/counter the prop banks — presentation
   reads the same counters QA does).
3. Combat: name tags removed; HP bars/damage numbers STAY (product
   constraint — they are readouts, not tags). Dialogue keeps speaker
   names (panel text, not floating).
4. QA: ui_world_labels_rendered asserts retire/replace; controller
   windowed reads identify entities by SPRITE from now on (the point).
Slotted as rollout task R3 (inside M-BEAUTY: one baseline recapture
covers both the grade and the label removal).
