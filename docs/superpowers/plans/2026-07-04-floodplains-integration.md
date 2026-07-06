# Floodplains Integration (Gate District + Relc Tutorial) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Every implementer MUST route work through the project skills (`.claude/skills/wi-*`) — wi-adding-a-scene, wi-adding-an-encounter, wi-adding-dialogue-and-quests, wi-art-and-sprites, wi-writing-qa-scripts, wi-verifying-changes. Skills are READ-ONLY.

**Goal:** Make the Floodplains the live overworld between inn and Liscor: inn→floodplains→gate-district topology, street grown to the 32×20 Liscor gate district, all goblin encounters migrated onto the road, Relc introduced (met_relc ally gating) with his repeatable combat tutorial.

**Architecture:** Pure data for maps/encounters/dialogue (skeleton_scene/combatants/arenas/dialogue JSON); two surgical engine changes (a `persistent` encounter flag + `ally_requires` roster gate in the sim; a declarative `tutor_lines` feed handler in the combat screen). One door-retarget "quiet window" flips the topology and re-paths all affected QA in a single pass.

**Authority:** `docs/superpowers/specs/2026-07-03-floodplains-world-map-design.md` (§2.5 door retargets, §6 Relc addendum) and `docs/superpowers/specs/2026-07-03-liscor-gate-district-and-tutorial-design.md` (D1 + D2 **including the Controller adjudication at the end — its notes OVERRIDE the design body where they differ**). Where this plan says "copy §X", the JSON in that spec section is the payload, verbatim, with only the deltas this plan states.

## Global Constraints

- Sim purity: no autoload/Node refs in `src/core/**`. Tune data, never sim.
- Stats hidden; opaque-until-sleep (tutorial lines carry NO XP/level/counter text — D2-5's opacity audit is a contract).
- Canon: Relc = Drake, Senior Guardsman, [Spearmaster]; A_Hunter tinted `[0.6,1.0,0.6]` is the flagged non-canon stand-in. Krshia/Watch text per design (already canon-checked).
- Every region/scale pick: windowed screenshot READ by the controller before done (design flag tables D1-5/D2-7 name the HIGH-risk picks).
- Zero warnings anywhere; failed asserts hang (alarm-wrap; see wi-verifying-changes).
- Single-implementer per file. `data/skeleton_scene.json` is owned by Lane W ONLY. `data/sprites.json` is owned by Lane A ONLY.
- All work on `main`; commit per task after green.

## Current baseline (verified 2026-07-04 — do not re-do)

- `maps.floodplains` (40×26) is FULLY LANDED incl. pond walls (Water_tiles cap `[1,7]`, cap-only), grass_02/03 + Water_tiles synced, campfire/tree_round/inn_roof sprites live, POI-B row clear at (13,18). L0 was da89286 + composite iterations.
- Doors are NOT flipped: `inn_door`→street, `street_door`→inn. Street is still 10×6 with all 3 encounters.
- Missing assets: `assets/tiles/library/Tiles.png`, `assets/sprites/royal_soldier/`, `assets/props/sewer/`, `assets/sprites/a_hunter/`. Missing sprites.json entries: `library_desk`, `library_shelf`, `royal_soldier`, `sewer_grate`, `a_hunter`, `training_dummy`.
- 19 canonical QA scripts (18 + `lantern_check`); seed table in v4 CLAUDE.md.

## Lanes and sequencing

```
S1 (sim) ─┐
P1 (ui)  ─┤ parallel        A2 (windowed art) ── W1 (street block) ── W2 (THE FLIP) ── Q1 (re-path) ─┐
A1 (art) ─┤──────────────────┘                                                        Q2 (new QA)  ─┤── F (gate+docs+review)
C1,C2 (content) ─┘  (C1/C2 parallel with A*; W2 needs S1+C1+C2+W1)
```

---

### Task S1: sim — `persistent` flag + `ally_requires` roster gate (Lane S)

**Files:**
- Modify: `wandering_inn_game_v4/src/core/wi_game.gd` (resolve_combat victory branch; start_combat ally assembly)
- Test: `wandering_inn_game_v4/tests/test_sim_core.gd`

**Interfaces:**
- Produces: encounter entity keys `persistent: bool` (victory does not remove the entity; immediately re-fightable) and `ally_requires: {"<accomplishment>": <min_count>}` (allies list fielded only when every counter is met). Consumed by W2's entities and Q1/Q2 assertions.

- [ ] **Step 1: failing tests.** In `test_sim_core.gd`, beside the existing trivial-flag tests add: (g-persist-1) a `persistent: true` encounter, after a won fight: `find/entity still present`, `removed_entities` untouched, NO `entity_removed` emitted, and `start_combat` on it succeeds again immediately; (g-persist-2) a non-persistent encounter unchanged (removed as today); (g-ally-1) an encounter with `allies:["relc"], ally_requires:{"met_relc":1}` and `accomplishments.met_relc` unset starts combat WITHOUT relc in the combatant set; (g-ally-2) same with `met_relc`=1 fields relc. Run: alarm-wrapped `--script res://tests/test_sim_core.gd` → expect FAIL/hang on the new asserts.
- [ ] **Step 2: implement.** Victory branch of `resolve_combat` — the adjudicated three-case shape (adjudication note 1, verbatim):

```gdscript
if bool(entity.get("respawns", false)):
    if not dormant_encounters.has(_pending_encounter):
        dormant_encounters.append(_pending_encounter)
elif not bool(entity.get("persistent", false)):
    remove_entity(_pending_encounter)
# persistent && !respawns -> stays live, immediately re-fightable (the spar)
```

Ally gate in `start_combat` where `entity.get("allies", [])` is read:

```gdscript
var allies: Array = entity.get("allies", [])
var ally_req: Dictionary = entity.get("ally_requires", {})
for key: String in ally_req:
    if accomplishment_count(key) < int(ally_req[key]):
        allies = []
        break
```

(Wholesale gate — every current ally IS Relc; do not build per-ally machinery, YAGNI.)
- [ ] **Step 3: green.** test_sim_core PASSES; then 12/12 units; smoke zero-warn; `combat_walkthrough` seed 9 still green (no data uses the new keys yet — byte-identical fights expected).
- [ ] **Step 4: commit** `M-FP S1: persistent encounters + ally_requires roster gate`.

---

### Task P1: combat screen — declarative `tutor_lines` feed handler (Lane P)

**Files:**
- Modify: `wandering_inn_game_v4/src/combat/combat_screen.gd`
- Modify: `wandering_inn_game_v4/src/core/wi_events.gd` (add `const UI_TUTOR_LINE_RENDERED := &"ui_tutor_line_rendered"`)

**Interfaces:**
- Consumes: `arena_config["tutor_lines"]`: Array of `{id: String, on: {event: String, payload_contains: Dictionary, nth: int=1}, line: String}` (inert data passthrough — already survives `arena_config.duplicate(true)`).
- Produces: each entry fires AT MOST ONCE when its matching bus event count reaches `nth`; the line goes into the existing prose feed; emits `ui_tutor_line_rendered {beat: id}`. Q2 asserts these.

- [ ] **Step 1:** read the feed-push path and the paced-playback queue rules in combat_screen.gd (M4 T10 header comment). CONSTRAINT (design flag D2-7 #5): tutor lines triggered by AI-TURN events must ride the playback queue (capture-at-enqueue), not fire live; player-turn events fire immediately. Hook the same code path(s) that push feed lines today.
- [ ] **Step 2:** implement (~30 lines): on each domain event the screen already receives, scan un-fired `tutor_lines`, match `event` + `payload_contains` subset (reuse/duplicate the TestDriver subset-match semantics), count matches per entry, fire at `nth`. Mark fired per combat instance (reset on combat start).
- [ ] **Step 3: verify inert.** No arena carries `tutor_lines` yet: full combat QA set (`combat_walkthrough` 9, `combat_move_input` 9, `defeat_reload` 1, `line_of_sight_denial` 9) green + smoke zero-warn — proves the handler is a no-op without data.
- [ ] **Step 4: commit** `M-FP P1: tutor_lines declarative feed handler (inert until an arena carries data)`.

---

### Task A1: asset sync + sprite entries (Lane A)

**Files:**
- Modify: `wandering_inn_game_v4/tools/sync_assets.py` (manifest), `wandering_inn_game_v4/data/sprites.json`
- Create: `wandering_inn_game_v4/assets/tiles/library/Tiles.png`, `assets/sprites/royal_soldier/Idle-Sheet.png`, `assets/props/sewer/Props.png`, `assets/sprites/a_hunter/{Idle,Run}_{Down,Side,Up}-Sheet.png` (+ LICENSES sidecars per pack convention)

- [ ] **Step 1:** add the 5 manifest rows from design D1-2.2 (exact source paths there); run the sync; verify dims match the design's parentheticals.
- [ ] **Step 2:** add sprites.json entries verbatim from design D1-2.1 (`library_desk`, `library_shelf`, `royal_soldier`, `sewer_grate`) and D2-2 (`a_hunter`, `training_dummy`). **ANCHOR RULE (wi-art-and-sprites):** a_hunter and royal_soldier are 64px character frames — measure the figure bbox (PIL alpha scan) and set `anchor` from the feet plane (body_a/citizen_f needed `[0.5,0.75]`; measure, don't assume).
- [ ] **Step 3: green.** `load_gate` + smoke zero-warn (regions may be visually wrong — that's A2 — but must parse/load).
- [ ] **Step 4: commit** `M-FP A1: library/royal-soldier/sewer/a_hunter/training_dummy assets + sprite entries`.

### Task A2: windowed region iteration (Lane A; after A1; before W1 uses the sprites)

- [ ] **Step 1:** build a throwaway peek QA script (screenshot-only, teleport allowed) that renders each new sprite on a test cell; run windowed; CONTROLLER READS the frames. Iterate the HIGH/MED flags: library desk `[96,272,48,32]` + shelf `[208,144,32,48]` (fallback: `table_brown`/`shelf_bottles`), sewer grate `[64,192,32,32]` (fallback boulder), training_dummy armor stand `[640,448,32,48]` (fallback crate), royal_soldier-as-stationary-NPC + `facing` mirror behavior, a_hunter tint `[0.6,1.0,0.6]` readability.
- [ ] **Step 2:** delete the throwaway script; commit `M-FP A2: region/scale verdicts (screenshot-read)` with the verified coords + a one-line verdict per flag in the message.

---

### Task C1: combat data — dummies + training_yard (Lane C)

**Files:**
- Modify: `wandering_inn_game_v4/data/combatants.json`, `wandering_inn_game_v4/data/arenas.json`

- [ ] **Step 1:** BEFORE writing `tutor_lines`, grep the `_emit` sites in `src/core/combat/wi_combat.gd` for `attack_resolved` and `combat_finished` payload key names; the design's trigger filters (D2-4) must match emitted keys byte-for-byte — fix the tutor_lines JSON to match source, never the reverse.
- [ ] **Step 2:** add `training_dummy_a`/`_b` combatants verbatim (design D2-2) and the `training_yard` arena (D2-2: `trivial: true`, 12×8, empty blocked, spawns as listed, floor patch, off-grid dressing) with the full 8-beat `tutor_lines` block from D2-4 (key names corrected per Step 1).
- [ ] **Step 3: green.** `test_combat_data` (cross-reference suite) + `load_gate` + smoke. The balance harness is NOT extended: `trivial` fights are exempt from win-rate gating by design intent (D2-7 #3) — state this in the commit message.
- [ ] **Step 4: commit** `M-FP C1: training dummies + training_yard arena (tutor_lines data)`.

### Task C2: dialogue — relc_intro + dummies_note + parley tweak (Lane C)

**Files:**
- Create: `wandering_inn_game_v4/data/dialogue/relc_intro.json`, `data/dialogue/dummies_note.json`
- Modify: `wandering_inn_game_v4/data/dialogue/goblin_parley.json` (one word: hub "across the street" → "across the road")

- [ ] **Step 1:** copy both graphs verbatim from design D2-3 (they already honor the M4 gating rules: hidden-until-met accomplishment gates, ungated exits, start_combat only on ending options; see wi-adding-dialogue-and-quests).
- [ ] **Step 2: green.** `test_content` + `test_dialogue` (test_content validates gate ids/goto/exits; `met_relc`/`sparred_with_relc` must be accepted as produced counters — if test_content rejects consumed-nowhere accomplishments, wire them per its actual contract, do not weaken the test).
- [ ] **Step 3: commit** `M-FP C2: relc_intro + dummies_note graphs; parley street->road`.

---

### Task W1: street → 32×20 Liscor gate district (Lane W; after A1/A2)

**Files:**
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json` (`maps.street` complete replacement)

- [ ] **Step 1:** replace `maps.street` with the design D1-2.3 block verbatim, with these deltas: (a) any region coords corrected by A2; (b) keep the existing `selys` tint if it differs (grep the current inn/street entities for her tint before replacing); (c) leave the 3 encounter entities OUT of the new block (they migrate in W2 — the street ships encounter-free per D1-1 Zone note).
- [ ] **Step 2: blocking contract check (wi-adding-a-scene):** run the map through a blocked-vs-decor audit — every stall/building footprint cell in `blocked`, row y4 walkable x0→31, side street walkable y5→19, no blocked cell under a door/NPC/prop entity.
- [ ] **Step 3: green + windowed.** `load_gate`; a temporary teleport peek (or the Q2 walkthrough if sequencing allows) windowed; CONTROLLER READS: plaza, market row, Guild frontage, south square (design D1-4's four shots). NOTE: `dialogue_walkthrough`/`quest_errand_*`/etc. WILL FAIL from this task until Q1 re-paths — expected-red is confined to the W1→Q1 window; do not "fix" them here.
- [ ] **Step 4: commit** `M-FP W1: Liscor gate district (street 10x6 -> 32x20)`.

### Task W2: THE FLIP — doors, encounter migration, Relc entities (Lane W; after S1+C1+C2+W1)

**Files:**
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json`

- [ ] **Step 1:** retarget doors per design §2.5 verbatim: `inn_door` → `floodplains (7,6)`, display "To the Floodplains"; `street_door` → `floodplains (31,24)`, display "To the Floodplains".
- [ ] **Step 2:** migrate the 3 encounters into `maps.floodplains.entities` per the D1-3 table — `goblin_encounter_1`→(21,12) (move the crate decor (21,12)→(20,12)), `goblin_encounter_2`→(28,18) (conversation field migrates unchanged), `chieftains_raid`→(31,7). Records otherwise byte-identical. Add `"ally_requires": {"met_relc": 1}` to ALL THREE (they all field relc).
- [ ] **Step 3:** add the `relc` npc and `relc_spar` encounter entities verbatim from design §D2-2 (relc at (12,13), a_hunter sprite, tint, `conversation: "relc_intro"`; relc_spar at (13,12) with `trivial: true`, `persistent: true`, `on_victory: ["sparred_with_relc"]` — **the §D2-2 list, NOT §D2-1's `[]`**, per adjudication note 2 — `conversation: "dummies_note"`, `allies: []`).
- [ ] **Step 4: green (sim-level).** `load_gate` + smoke + `test_content`. Full QA is RED until Q1 — commit anyway (the quiet window is open): `M-FP W2: topology flip + encounter migration + Relc (QA re-path follows in Q1)`.

---

### Task Q1: the QA re-path window (Lane Q; immediately after W2 — same session)

**Files:**
- Modify: `wandering_inn_game_v4/qa/scripts/*.json` (the design D1-4 table is the worklist), `wandering_inn_game_v4/CLAUDE.md` (both script lists)

- [ ] **Step 1: enumerate.** `grep -l "street" qa/scripts/*.json` + the D1-4 table + `lantern_check` (inn-only — verify unaffected). For each script: new route inn→floodplains→gate; Selys now at street (26,4) via the y4 lane; extra `map_changed` autosave beats double up — re-derive every step-path with the dialogue-cursor rule in mind (wi-writing-qa-scripts).
- [ ] **Step 2: THE ROSTER RULE (biggest cost — do not shortcut).** Every script whose fight fields relc must now MEET RELC FIRST (walk to (12,13), run the intro to the `met_relc` effect, exit) or the roster—and therefore the entire fight trajectory—changes and the canonical seed breaks. Scripts: `combat_walkthrough`, `level_up_loop`, `defeat_reload`, `line_of_sight_denial`, `quest_errand_fight`, `combat_move_input`, `class_evolution_loop`, `consolidation_flow`, `generalist_loop`, `save_migration`. After adding the meet-Relc prologue, re-verify each at its pinned seed; a still-red script = real seed re-derivation (search protocol; document the new seed).
- [ ] **Step 3:** extend the floodplains walkthrough (or the successor of `inn_walkthrough`'s exterior leg) with: `met_relc` assertion, roster POSITIVE (fight after meeting fields relc — assert via `combat.` snapshot combatant set), and the NEGATIVE (a first fight without meeting him fields NO relc — use a fresh-boot script variant that goes straight to (21,12)).
- [ ] **Step 4:** `street_peek` reframed for 32×20; RETIRE `floodplains_peek` (delete + remove from lists) — the map is now walkably covered.
- [ ] **Step 5:** update BOTH CLAUDE.md script lists + the seed table (new rows: re-pathed seeds, `gate_district_walkthrough`, `relc_tutorial` placeholder pending Q2). Full 19-script sweep green + 12 units + smoke.
- [ ] **Step 6: commit** `M-FP Q1: QA re-path for the floodplains topology (meet-Relc prologues; seed re-verification)`.

### Task Q2: new QA — gate_district_walkthrough + relc_tutorial (Lane Q; after Q1)

**Files:**
- Create: `wandering_inn_game_v4/qa/scripts/gate_district_walkthrough.json`, `qa/scripts/relc_tutorial.json`
- Modify: `wandering_inn_game_v4/CLAUDE.md` (seed rows)

- [ ] **Step 1:** `gate_district_walkthrough` per design D1-4: enter from the floodplains gate, assert `ui_map_rendered` (32×20 payload — compute `blocked_cells` from the shipped block), walk y4 end-to-end, interact krshia_stall + guild_door + sewer_grate (assert all three accomplishments + EXACT toast texts — the unqualified-toast trap), Watch-guard `dialogue_line`, Selys `ui_dialogue_shown` at (26,4). Windowed variant screenshots: plaza/market/Guild/south square.
- [ ] **Step 2:** `relc_tutorial` per design D2-8, all nine numbered elements — including the skippable NEGATIVE first ("Another time." → `assert_event_absent combat_started` scoped by exact-payload discipline), the beat-id `ui_tutor_line_rendered` sequence driven by real keys, and **the opacity teeth**: `sparred_with_relc == 1`, `won_combat` absent/0, `melee_hit` absent/0 (tally suppressed by trivial), no `class_level_up`/`class_gained` logged, `relc_spar` still present (persistent) + second `combat_started` on re-talk. Seed 9 candidate; verify, else search + pin.
- [ ] **Step 3:** both green headless; windowed run of relc_tutorial CONTROLLER-READ (feed line wrap check — design flag D2-7 #6: cut words, never widen UI). Seed-table rows added.
- [ ] **Step 4: commit** `M-FP Q2: gate district + Relc tutorial QA (opacity + persistence teeth)`.

---

### Task F: full gate, docs, review (after Q1+Q2)

- [ ] **Step 1:** full sweep: every canonical script at its pinned seed, 12/12 units, balance harness (16 cells — data untouched by this plan except the migrated encounters' `ally_requires`; harness builds field relc unconditionally via composition config — verify the harness is unaffected, it constructs fights directly, not via entities), smoke, web parity spot (`combat_walkthrough` wasm).
- [ ] **Step 2:** windowed screenshot set for HANDOFF (floodplains road with Relc, gate district four shots, tutorial mid-beat) — controller-read.
- [ ] **Step 3:** docs: v4 CLAUDE.md architecture note (floodplains topology, persistent/ally_requires keys, tutor_lines contract), HANDOFF state + playtest checklist additions (tutorial feel, gate district readability, road pacing), ledger.
- [ ] **Step 4:** dispatch the whole-branch review (this plan's full range) with method hints per wi-running-the-machine; fix wave; commit `M-FP F: gate + docs`.

## Self-review notes (writing-plans checklist applied)

- **Spec coverage:** D1 zones→W1; D1-3 migration→W2; D1-4 re-path table→Q1; gate_district QA→Q2; D2 dummies/arena/tutor_lines→C1+P1; D2-3 graphs→C2; D2-6 persistent→S1 (adjudicated elif); §6 met_relc gating→S1+W2+Q1; D2-8→Q2; flag tables→A2/C1-step1/Q2-step3. Music (D1-2.4) deliberately DROPPED (optional per design; audio.json per-map support unverified — YAGNI).
- **Known risks:** Q1 roster rule is the schedule risk (10 scripts × possible seed searches) — budget it; W1→Q1 expected-red window must stay within one working session; harness/entity independence (F step 1) verified at F, flagged here.
- **Type consistency:** `ally_requires` counts via `accomplishment_count` (existing sim accessor — S1 implementer: verify exact name in wi_game.gd and match it); `UI_TUTOR_LINE_RENDERED` string `ui_tutor_line_rendered` used by P1+C1+Q2 identically.
