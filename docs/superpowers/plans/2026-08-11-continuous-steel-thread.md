# Continuous Steel Thread Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `qa/scripts/steel_thread.json` as ONE continuous playthrough — single PC, title screen → epilogue, every state reached by an in-game event from the previous state (no `install_fixture`, no `teleport`).

**Architecture:** One append-only JSON script grown act by act. Each segment is verified by running the FULL prefix headless before the next segment starts (the script must stay green at every extension). Inter-region travel uses the game's own Magical Door chain (`horns_dig` → `door_mounted` → `door_awakened` → `invrisil_attuned`/`pallass_attuned`/`dungeon_attuned`, `data/portals.json`). Existing per-region walkthrough scripts are choreography donors, but every dialogue selection is re-derived against the continuous PC's state (visible-option lists differ from donor fixture states).

**Tech Stack:** QA driver (`qa/test_driver.gd`) declarative JSON, `qa/run_qa.sh steel_thread headless|windowed --seed=N`, Godot 4.7 headless.

## Why this rewrite (user directive, 2026-08-11)

The shipped steel thread stitched 6 fixture loads + 17 teleports across
incompatible PC iterations (warrior 5 → warrior 10 → warrior 2 →
spellsword 14) and played regions in a FALSE order (Riverfarm/Invrisil/
Pallass before the warren; real act structure is warren = Act III, door
chain + regions = Act IV, seal descent = Act V per `data/acts.json`).
User's purpose: judge narrative pacing, leveling progress, reachability
reasonableness, and progression of the game from a single realistic
playthrough. That requires continuity, not coverage.

## Global Constraints

- **No `install_fixture` steps, no `teleport` steps, no `fixture_save` root key.** `starts_at_title: true`, `creation_ui: true`. The negative proof is mechanical: `grep -c '"teleport"\|"install_fixture"' qa/scripts/steel_thread.json` must be 0 (comment keys excluded — keep those words out of comments too).
- **One PC:** drake_f, same creation choices as the current script (cursor choreography already in the prefix). One continuous class trajectory; whatever the route spec derives (expected: warrior early, mage via frost line, spellsword consolidation before Act IV heavy fights).
- **Seed 9 first.** A seed change invalidates every downstream combat — if a segment forces a re-seed, the WHOLE prefix re-verifies before continuing. Record the final seed in STEEL-THREAD.md.
- **Album duty:** keep a screenshot at every narrative beat the old album covered *that lies on or beside the spine*; name shots in run order (`NN_...`). Off-spine teleport-only "tolerant legs" are dropped and the drops logged in STEEL-THREAD.md.
- **Windowed pacing:** captures hold 240–300 frames as before; combat visible via `combat_autoplay`.
- Manual instrument: stays OUT of `qa/manifest.json` (no sweep row, no surfaces regen needed).
- All `wi-writing-qa-scripts` traps apply (since-marker, dialogue event order `dialogue_started → dialogue_node → ui_dialogue_shown`, destination pins never bare indices, `victories` not `won_combat` for gray-band fights, bump-move facing idiom, unqualified-toast trap).
- Segment commits land on branch `steel-thread-continuous`; merge to main only after Task 7's full green.

## File Structure

- Rewrite: `wandering_inn_game/qa/scripts/steel_thread.json` (the only code file; grown append-only across Tasks 1–5)
- Create: `wandering_inn_game/docs/design/steel-thread-route-spec.md` (Task 0 deliverable; the derived spine)
- Rewrite: `wandering_inn_game/qa/STEEL-THREAD.md` (Task 6)
- Append: `docs/CHOICE-LOG.md` (Task 6)

Donor scripts (choreography reference only, never copied blind):
`gate_district_walkthrough`, `dialogue_walkthrough`, `sewers_walkthrough`,
`riverfarm_walkthrough`, `longhouse_walkthrough`, `invrisil_walkthrough`,
`pallass_walkthrough`, `ruin_walkthrough`, `thread_lattice_loop`, and the
old steel_thread (git show HEAD — its live combat/tutorial segments are
the best donors for Acts I and V).

---

### Task 0: Route spec (the spine, derived from data)

**Files:**
- Create: `wandering_inn_game/docs/design/steel-thread-route-spec.md`

**Interfaces:**
- Produces: ordered table of beats: `act | beat | map | trigger (NPC/prop/dialogue node/skill) | banks (accomplishment/quest step) | combat? | sleep?`. Tasks 1–5 implement rows verbatim.

- [ ] **Step 1:** Read `data/acts.json`, `data/quests.json`, `data/portals.json`, and every dialogue graph a spine quest references. Derive the minimal accomplishment chain from creation to `seal_resolved` + epilogue, including: Act II's 3 quests + second class mechanism, `raskghar_sealed` route, the full door chain (`horns_dig` start conditions — note it gates on `seal_kept_reported`-adjacent counters; verify actual start gate from data, not memory), region arcs (`price_of_a_favor_reported`, `brothers_job_done`, `elevator_pass_stamped`, `lattice_forge_rune`), Act V descent chain (`seal_descent_agreed` → `read_the_feeding_ward` → `seal_resolved`).
- [ ] **Step 2:** For each beat, name the exact banking site (map, entity id, dialogue node id) by grepping data — no "somewhere in Riverfarm" rows.
- [ ] **Step 3:** Mark every combat on the spine with its arena/encounter id (these are the seed-risk points) and every required sleep (class gains, `door_awakened` attunement sleeps).
- [ ] **Step 4:** Sanity-probe the two riskiest unknowns headless before committing the spec: (a) second-class acquisition route, (b) `horns_dig` start gate. One throwaway script each under `qa/scripts/tmp_probe_*.json`, deleted after reading.
- [ ] **Step 5:** Commit spec (`docs(steel-thread): derive continuous route spec`).

### Task 1: Act I segment — Arrival

**Files:**
- Modify: `wandering_inn_game/qa/scripts/steel_thread.json` (replace wholesale with new prefix)

**Interfaces:**
- Produces: green prefix ending with `assert_event_logged accomplishment_recorded {id: reached_liscor}` and `assert_state classes` showing class 1; PC standing in `street`.

- [ ] **Step 1:** Author: title gate → title → creation (keep existing drake_f choreography) → inn opener → inn sign → Relc spar → sleep ([Warrior]) → spear gift → equipment panel. Replace the three old Act-I teleports with walked routes (`stairs_up` door at inn (1,8) → `inn_upstairs` bed; walk back down for the gift node).
- [ ] **Step 2:** Continue: inn door → floodplains → east route → gate-road ambush (live, `combat_autoplay`) → street arrival; pin `reached_liscor`.
- [ ] **Step 3:** Run `wandering_inn_game/qa/run_qa.sh steel_thread headless --seed=9`. Expected: PASS, `failures: []`.
- [ ] **Step 4:** Commit (`feat(steel-thread): continuous Act I segment`).

### Task 2: Act II segment — Make a Place for Yourself

**Files:**
- Modify: `wandering_inn_game/qa/scripts/steel_thread.json` (append)

**Interfaces:**
- Consumes: Task 1 end state (warrior, street).
- Produces: green prefix with `quests_completed >= 3`, `reached_two_classes` banked, second class present in `assert_state classes`.

- [ ] **Step 1:** Author the three Act-II quests per route spec (expected: `the_errand` package delivery, `missing_crate` Krshia arc, `cisterns` Watch arc — exact from Task 0), each quest's full dialogue choreography with destination pins.
- [ ] **Step 2:** Author the second-class route (expected frost/mage line; includes any scroll/prop skill grant + sleep beat). Pin the `class_gained` toast by exact text.
- [ ] **Step 3:** Full prefix headless, seed 9. PASS required.
- [ ] **Step 4:** Commit (`feat(steel-thread): continuous Act II segment`).

### Task 3: Act III segment — What Stirs Beneath

**Files:**
- Modify: `wandering_inn_game/qa/scripts/steel_thread.json` (append)

**Interfaces:**
- Consumes: Task 2 end state.
- Produces: green prefix with `raskghar_sealed` banked; album shots for fissure, deep tunnels, scouts, warren mouth, Relc veto, boss, warren cleared.

- [ ] **Step 1:** Author: `something_beneath` start → sewers fissure entry (walked; sewers entry is NOT a street door — use the fissure entity route from route spec) → deep tunnels → scout fight (live) → warren mouth → Relc beat → awakened boss (live) → `cleared_the_warren` + `raskghar_sealed` pins.
- [ ] **Step 2:** Full prefix headless, seed 9. PASS. If the boss reds on seed 9 with the continuous build, seed-search (document candidates tried) and re-verify Tasks 1–2 prefix under the new seed BEFORE continuing.
- [ ] **Step 3:** Commit (`feat(steel-thread): continuous Act III segment`).

### Task 4: Act IV segment — What the Door Opened

**Files:**
- Modify: `wandering_inn_game/qa/scripts/steel_thread.json` (append)

**Interfaces:**
- Consumes: Task 3 end state (post-seal Liscor).
- Produces: green prefix with `door_mounted`, `door_awakened`, `price_of_a_favor_reported`, `brothers_job_done`, `elevator_pass_stamped`, `lattice_forge_rune`, `seal_kept_reported` all banked.

- [ ] **Step 1:** Door chain: Horns intro at inn → `horns_dig` (dig site route + haul) → `door_mounted`; Krshia catalyst errand → Pisces delivery → attunement sleeps → `door_awakened`. Pin the portal hub dialogue (`The Magical Door` speaker) on first use.
- [ ] **Step 2:** Riverfarm arc via Door: village night watch (live wolf fight), witch hollow, longhouse; bank `price_of_a_favor_reported`. Keep the old album's Riverfarm beats.
- [ ] **Step 3:** Invrisil arc: attune → boulevard → mercantile alleys → Brothers parlor → `brothers_job_done`. Include enchanter shop only if on-spine per route spec; else log as dropped coverage.
- [ ] **Step 4:** Pallass arc: papers/permit chain → forge tier → calibration-rig parley → forge-hall fight (live) → `elevator_pass_stamped`; then `lattice_forge_rune` + `seal_kept_reported` closers per route spec.
- [ ] **Step 5:** Full prefix headless after EACH sub-arc (2–4 runs total, they get long — budget for it). PASS each time before appending the next arc.
- [ ] **Step 6:** Commit per sub-arc (`feat(steel-thread): continuous Act IV — <arc>`).

### Task 5: Act V segment — What the Seal Was Feeding

**Files:**
- Modify: `wandering_inn_game/qa/scripts/steel_thread.json` (append)

**Interfaces:**
- Consumes: Task 4 end state.
- Produces: green FULL script: `seal_descent_agreed` → `read_the_feeding_ward` → seal choice → Seal Warden (live) → vault → anchor → tally → return → final sleep → `ui_epilogue_rendered` (or the epilogue's actual event per route spec).

- [ ] **Step 1:** Author: Pisces descent ask at inn → Door to `dungeon_approach` (`dungeon_attuned` — verify it banks on the spine by this point; if not, the sleep-beat second-door pair from route spec) → walked `trapped_halls` route (replaces the old teleport at old-step 631) → feeding ward → choice → Warden fight (live) → vault → anchor → tally → walked return → final sleep → epilogue.
- [ ] **Step 2:** Full headless, seed 9 (or Task-3 seed). PASS.
- [ ] **Step 3:** Grep-gate: `grep -c '"teleport"\|"install_fixture"' qa/scripts/steel_thread.json` → 0.
- [ ] **Step 4:** Commit (`feat(steel-thread): continuous Act V + finale`).

### Task 6: Docs

**Files:**
- Rewrite: `wandering_inn_game/qa/STEEL-THREAD.md`
- Append: `docs/CHOICE-LOG.md`

- [ ] **Step 1:** STEEL-THREAD.md: new ordered scene list (true act order), continuity contract (no fixtures/teleports — and the grep gate), final seed, measured headless wall time, dropped-coverage list, windowed instructions.
- [ ] **Step 2:** CHOICE-LOG: rewrite-in-place decision (old stitched album superseded by user directive 2026-08-11; git history retains it), dropped legs, build trajectory chosen.
- [ ] **Step 3:** Commit (`docs(steel-thread): continuous-run contract`).

### Task 7: Verification + observation run

- [ ] **Step 1:** Two consecutive full headless runs at the final seed. Both PASS; note wall time and any `events_seen` variance in STEEL-THREAD.md (known limitation carries over).
- [ ] **Step 2:** Merge `steel-thread-continuous` → main (gated: full unit bar + the grep gate).
- [ ] **Step 3:** Launch `wandering_inn_game/qa/run_qa.sh steel_thread windowed --seed=<final>` for the user to observe. Report expected duration up front.

## Self-Review notes

- Spec coverage: continuity constraint (Tasks 1–5 + grep gate), true act order (route spec + segments in act order), observation deliverable (Task 7). Leveling-progress judgment is the USER's read of the run; the script's job is one honest trajectory.
- Empirical honesty: exact step JSON cannot be pre-written for a sim-derived route; each task pins its GATES (exact accomplishments/events) instead. That is the falsifiable deliverable per segment.
- Risk register: (1) `horns_dig` start gate may demand counters the spine doesn't naturally bank — Task 0 Step 4 probes it first. (2) Single-seed all-fights — Task 3 Step 2 defines the re-seed protocol. (3) Act IV length may push full-prefix verify runs past 10 min — acceptable; headless timeout per run set generously.
