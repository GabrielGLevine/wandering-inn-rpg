# M-BEAUTY Atmosphere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox syntax. Project skills READ-ONLY for subagents (`wi-godot-mcp` governs any MCP use — controller-only this milestone).

**Goal:** The approved atmosphere systems (spec `docs/superpowers/specs/2026-07-04-beauty-atmosphere-design.md`, §0 decisions LOCKED) + the floodplains-dusk pilot. USER VERDICT on pilot shots gates rollout to other maps — rollout tasks are LISTED but not dispatched until the verdict.

**Architecture:** Presentation-only (the phase sim landed in M7 E2). Mood grade via CanvasModulate in the world SubViewport; lights as data-driven PointLight2Ds; ambience as data-driven GPUParticles2D presets + 3 small canvas shaders. **Ship-neutral-first:** B1-B3 land with NEUTRAL/identity values on every map (zero visible change, full machinery live + QA'd); the pilot (B4) then tunes ONLY floodplains data. This keeps every task behavior-safe and confines look changes to the pilot's controlled window.

## Global Constraints

- Stats hidden; opaque-until-sleep untouched (phase is world light, never progress text).
- UI layers NEVER graded (they live outside the world SubViewport — verify, don't assume).
- QA-first: `ui_mood_applied {map, phase}`, `ui_lights_rendered {map, count}`, `ui_ambience_rendered {map, emitters}` + the existing `phase_changed`. New `atmosphere_check` canonical script.
- Phase thresholds are DATA (moods.json meta) — but changing them post-B1 = canonical-seed re-verify (CLAUDE.md rule from M7 F). B1 ships them matching E2's injected defaults (40/90) so nothing shifts.
- Budgets (spec §5): ≤8 lights/map, ≤6 emitters/map, 3 shaders total. Web parity is a ROLLOUT gate; the pilot only needs native.
- Zero sim changes. Zero data/moods values that alter today's look outside the pilot map.
- NO COMMIT by implementers; alarm-wrap; grep discipline (game_helper exempt).

---

### Task B1: mood grade + phase consumer + atmosphere_check

**Files:** Create `wandering_inn_game_v4/data/moods.json`, `src/world/atmosphere.gd` (+uid), `qa/scripts/atmosphere_check.json`; Modify `src/world/world.gd` (spawn atmosphere node inside the world viewport) or `src/world/main.gd` (whichever owns the SubViewport tree — match the existing spawn idiom), `src/core/wi_events.gd` (3 UI consts), `wandering_inn_game_v4/CLAUDE.md` (row).

**Interfaces — Produces:**
```jsonc
// data/moods.json
{ "meta": { "phase_thresholds": {"dusk": 40, "night": 90},
            "light_energy_by_phase": {"day": 0.0, "dusk": 1.0, "night": 1.0} },
  "moods": { "<map_id>": { "day": [1,1,1], "dusk": [1,1,1], "night": [1,1,1], "vignette": 0.0 } } }
// ALL maps ship IDENTITY values ([1,1,1], vignette 0) — pilot tunes floodplains only.
```
```gdscript
# atmosphere.gd — CanvasModulate child of the world viewport's root
func apply(map_id: String, phase: String) -> void   # sets color from moods.json; emits UI_MOOD_APPLIED {map, phase}
# listens: map_changed + phase_changed on the bus; also applied on world_ready
func phase_now() -> String                           # passthrough Game.sim.phase()
```
- [ ] moods.json identity values for every map key in skeleton_scene (incl. arenas? NO — arenas inherit the field phase via the same CanvasModulate since the combat board renders INSIDE the world viewport [M5 R6] — verify that claim by reading main.gd/world.gd; if the board is a sibling outside the modulate's subtree, note it and scope arena grading to the pilot decision).
- [ ] atmosphere.gd + spawn + events. CanvasModulate must sit so it grades world content but NOT native-res UI CanvasLayers (they're outside the SubViewport — verify with a windowed shot: open the journal at identity grade, confirm unaffected).
- [ ] atmosphere_check.json (seed 9): world_ready → ui_mood_applied{inn, day} → walk ≥40 actions (reuse work_loop-style chore loops or plain paced moves — 40 real moves) → phase_changed{dusk} + ui_mood_applied{*, dusk} → sleep → phase_changed{day}. Deterministic (counter-driven).
- [ ] VERIFY: identity grade = zero visual change (windowed inn shot vs current — controller reads); FULL 30-script sweep (29 + atmosphere_check) at pinned seeds — new ui_mood_applied events enter every stream; cursor waits tolerate unknown events, but confirm no script asserts an exact event-count that breaks (inn_walkthrough's counts are payload-scoped, fine — verify); 13 units; load_gate + smoke. Report per-script.

### Task B2: light layer

**Files:** Create `assets/fx/light_radial.png` (generated soft radial, ~64px, committed) + import sidecar; Modify `src/world/world.gd` (entity/decor `light` data → PointLight2D spawn), `src/world/atmosphere.gd` (phase → light energy multiplier from moods meta), `data/skeleton_scene.json` (light data on: inn hearth decor + unlit_lantern? NO — lantern lights when LIT, skip; Relc's campfire, gate-district braziers/torch decor, sewer grates glow, cave arena? arenas later), `src/core/wi_events.gd` if UI_LIGHTS_RENDERED not already in B1, `wandering_inn_game_v4/CLAUDE.md`.

- [ ] `light: {color:[r,g,b], energy: float, radius: int, flicker: bool}` on entities/decor → world.gd spawns PointLight2D with the radial texture; energy scaled by phase multiplier (day 0.0 ⇒ INVISIBLE at day — today's look preserved without identity hacks); flicker = cheap sine/noise energy wobble.
- [ ] Data: anchors per spec §2.3 with sensible warm values (campfire orange, torch amber, grate green-tinge) — VISIBLE ONLY at dusk/night, which no canonical script reaches except atmosphere_check ⇒ behavior-safe.
- [ ] emits ui_lights_rendered {map, count}; atmosphere_check extends: at dusk assert lights_rendered count>0 on floodplains? (script walks the inn — add a floodplains leg or assert count==0 at inn day; keep it cheap and deterministic — implementer picks, documents).
- [ ] VERIFY: sweep + units + smoke; windowed floodplains shot AT DAY (controller reads: identical to current); budgets enforced in code (clamp + push_warning ⇒ NO, zero-warning rule — clamp + a test_content-style validation in the atmosphere path or a units check).

### Task B3: ambience presets + shaders

**Files:** Create `src/world/ambience.gd` (+uid), `assets/fx/` particle textures (generated dots/motes), 3 shaders under `src/world/shaders/` (foliage_sway.gdshader, water_shimmer.gdshader, vignette.gdshader); Modify `src/world/world.gd` (map `ambience` data → emitters; `sway: true` decor/scatter tag → shader material; pond tiles → shimmer), `src/world/atmosphere.gd` (vignette strength from mood; phase-gates emitters), `data/skeleton_scene.json` (floodplains: fireflies rect over pond + grass sway tags; inn: dust motes — VALUES ONLY WHERE INVISIBLE-BY-DAY or imperceptibly subtle; final tuning is B4), `wandering_inn_game_v4/CLAUDE.md`.

- [ ] Presets: fireflies, dust_motes, leaves, pond_glints, embers (GPUParticles2D, ≤64 particles, native res). Phase-gated (fireflies dusk/night only).
- [ ] Shaders: sway (vertex wobble, amplitude param), shimmer (uv wobble on water tiles), vignette (fullrect, strength param, 0 = off). Wasm-safe constructs only (no unsupported hints).
- [ ] ui_ambience_rendered {map, emitters}; atmosphere_check extends.
- [ ] VERIFY: sweep + units + smoke; windowed day-shot identity check (sway amplitude 0 by default? NO — subtle sway at day is FINE and alive; judgment: ship sway ON subtle [it is the one always-visible change, spec-intended]; controller reads the shot and judges); web export SMOKE (one wasm build + combat_walkthrough — shaders/particles are the wasm risk, catch early rather than at rollout).

### Task B4: THE PILOT — floodplains at dusk (CONTROLLER-EXECUTED, not delegated)

Fable + godot-ai MCP live look-dev per wi-godot-mcp + spec §4: tune floodplains mood colors (dusk warm-horizon grade), campfire/firefly/pond values, composition nudges (skeleton dressing edits allowed on floodplains only), iterating 640px shots against the user's reference images. Deliverables: floodplains direction card (append to the spec dir), 3 pilot shots (wide/campfire/pond) in fp-handoff/pilot-shots/, atmosphere_check extended to pin the floodplains dusk mood event. USER VERDICT GATES ROLLOUT.

### Rollout (verdict received 2026-07-05 — APPROVED): R1 inn/cave/title cards (dispatched); R2 gate-district night card + logged art fixes; **R3 label removal + visual affordances (spec §8 addendum: remove ALL floating name tags; prop `visual_states` engine seam — dirty table visibly dirty + changes when cleaned; combat keeps HP bars, loses name tags; ui_world_labels_rendered asserts retire; per-map affordance audit so every interactable reads without its label)**; RF web-parity gate + baseline recapture ONCE (now covers grade AND labels) + whole-branch opus review.

## Self-review notes
- Spec §2 systems→B1-B3; §3 cards→B4+rollout; §4 pilot protocol→B4; §5 QA/budgets→each task + rollout gate; §7 opens: thresholds ship at E2 defaults (no drift); combat-inherits-phase resolved empirically in B1; firefly texture = generated (asset-index check first per §7 — implementer verifies pack candidates before generating).
- Ship-neutral-first keeps all sweeps green-by-construction; the ONE deliberate always-visible change (subtle sway) is isolated in B3 and controller-read.
- Type consistency: event names/payloads fixed in B1; moods.json schema fixed in B1, consumed B2-B4.
