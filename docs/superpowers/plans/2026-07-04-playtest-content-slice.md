# Playtest-Content Slice Implementation Plan

> Status: **DONE** — executed; retained as a design record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Every implementer routes work through the project skills (`.claude/skills/wi-*`) — READ-ONLY.

**Goal:** Make leveling variety humanly playtestable NOW: a repeatable inn work-loop that gains and levels [Helper], plus one gate-district quest with three solution paths (fight/talk/skill) banking different counters — all on existing engine seams.

**Architecture:** Content-only. Data (`classes.json`/`skills.json`/`skeleton_scene.json`/`quests.json`), dialogue graphs, QA scripts. **ZERO sim/engine changes** — spec §4/§6 contract. If any task discovers an engine change is required, STOP that task and report; do not improvise sim edits.

**Tech Stack:** Godot 4.7 data-driven content; declarative QA (`qa/run_qa.sh`).

**Authority:** `docs/superpowers/specs/2026-07-04-three-pillars-world-skills-design.md` §2 + §4 (user-approved 2026-07-04). Plan-time decisions recorded here override open items in spec §7.

## Global Constraints

- Canon from the Wandering Inn Wiki. Names baked in below are canon-attested or flagged `CANON-FLAG` — a flagged name the implementer cannot attest on the wiki mirror is ESCALATED in the task report, never silently invented/swapped.
- Stats (STR/DEX/etc.) never player-visible; opaque-until-sleep (no progress-toward text anywhere — toasts/dialogue show RESULTS only).
- Dialogue `requires` dicts: ONE key each (`_meets` evaluates only the first key). Accomplishment-requires HIDE until met; skill-requires stay visible-locked. Every node with any vanishing option keeps one fully ungated exit (`test_content` enforces).
- Class-level `requires` = AND over keys; `requires_any` = OR (spellsword precedent). `gained_by.accomplishment` = AND.
- Single-owner files per task. All Godot runs alarm-wrapped (`perl -e 'alarm 180; exec @ARGV' ...`); grep every output for `SCRIPT ERROR|Parse Error|WARNING` (`[godot_ai game_helper]` line exempt). NO COMMIT by implementers — controller commits per task.
- Verified seams this plan builds on (do not re-derive): prop `on_interact_accomplishment` and `requires_skill`+`on_skill_use` fire on EVERY interact (repeatable; counters monotonic); dialogue option `effects` is an ARRAY (can bank multiple accomplishments); `on_victory` accepts an Array of ids; `basic_cleaning` is INNATE (skeleton `player.skills`) — never grant it from a class (known_skills dedups, but the grant would be dead weight).

## Plan-time decisions (spec §7 resolutions)

1. **Helper entry chore = cleaning.** `gained_by: {cleaned_the_inn: 1}` — Erin's inn funnels every player to the dirty table (M2 content); `gained_by` has AND semantics and no `requires_any`, so one canonical entry counter it is.
2. **Chore counters:** `cleaned_the_inn` (existing, prop), `served_customer` (new, dialogue), `delivered_item` (new, prop), `cooked_meal` (new, skill-gated prop). Levels use `requires_any` across them.
3. **Tactician seam:** the quest's skill path banks `studied_the_cellar` — the `studied_*` accomplishment the Three Pillars milestone will key Tactician's `gained_by` to. Nothing else Tactician ships now.
4. **No new combatants/arenas/art.** The fight path reuses `goblin_raider` (goblins-in-the-sewers is canon-plausible for Liscor) and the arena `goblin_encounter_2` already uses; NPCs reuse `citizen_f` sprite with new tints (max-fidelity rule: real sprites, distinct tints).

---

### Task T1: [Helper] class line + service skills (data)

**Files:**
- Modify: `wandering_inn_game_v4/data/skills.json` (add 3 entries)
- Modify: `wandering_inn_game_v4/data/classes.json` (add 3 classes)

**Interfaces:**
- Produces: class id `helper` (gained_by `cleaned_the_inn`); counters consumed: `cleaned_the_inn`/`served_customer`/`delivered_item`/`cooked_meal` (T2 banks them); skill id `basic_cooking` (T2's stew pot gates on it).

- [ ] **Step 1:** add to `skills.json` `skills` array (shape matches `basic_cleaning`/`light` exactly):

```json
{"id": "lesser_stamina", "display_name": "[Lesser Stamina]", "contexts": ["exploration"], "description": "Chores that would tire another barely slow you."},
{"id": "basic_cooking", "display_name": "[Basic Cooking]", "contexts": ["exploration"], "description": "Simple meals come out right, every time."},
{"id": "lesser_strength", "display_name": "[Lesser Strength]", "contexts": ["exploration"], "description": "Trays, kegs, and crates feel lighter than they should."}
```
All three are canon-attested skill names (TWI: [Lesser Stamina]/[Lesser Strength] stat-skills; [Basic Cooking] Erin-adjacent). Skill NAMES are player-visible and allowed; raw stats are not.

- [ ] **Step 2:** add to `classes.json` `classes` array:

```json
{
 "id": "helper",
 "display_name": "Helper",
 "stat_growth": {"con": 1},
 "evolution": {
  "at_level": 10, "dominance_share": 0.6, "min_uses": 12,
  "targets": {"served_customer": "barmaid", "delivered_item": "server"}
 },
 "levels": [
  {"level": 1, "requires": {}, "grants": ["lesser_stamina"]},
  {"level": 2, "requires_any": {"cleaned_the_inn": 3, "served_customer": 3, "delivered_item": 3}, "grants": []},
  {"level": 3, "requires_any": {"cleaned_the_inn": 6, "served_customer": 6, "delivered_item": 6}, "grants": ["basic_cooking"]},
  {"level": 4, "requires_any": {"cleaned_the_inn": 10, "served_customer": 10, "delivered_item": 10, "cooked_meal": 6}, "grants": []},
  {"level": 5, "requires_any": {"cleaned_the_inn": 15, "served_customer": 15, "delivered_item": 15, "cooked_meal": 10}, "grants": ["quick_movement"]},
  {"level": 6, "requires_any": {"cleaned_the_inn": 21, "served_customer": 21, "delivered_item": 21, "cooked_meal": 15}, "grants": []},
  {"level": 7, "requires_any": {"cleaned_the_inn": 28, "served_customer": 28, "delivered_item": 28, "cooked_meal": 21}, "grants": []},
  {"level": 8, "requires_any": {"cleaned_the_inn": 36, "served_customer": 36, "delivered_item": 36, "cooked_meal": 28}, "grants": []},
  {"level": 9, "requires_any": {"cleaned_the_inn": 45, "served_customer": 45, "delivered_item": 45, "cooked_meal": 36}, "grants": []},
  {"level": 10, "requires_any": {"cleaned_the_inn": 55, "served_customer": 55, "delivered_item": 55, "cooked_meal": 45}, "grants": []}
 ],
 "gained_by": {"accomplishment": {"cleaned_the_inn": 1}}
}
```

Thresholds are triangular-ish (~2-4 chores per early level, mirroring warrior's fight cadence at ~3 melee_hit/fight); ABSOLUTE tuning is an F-task call if the work_loop QA shows the cadence off. Volume note: L2 at 3 chores ≈ one focused inn visit.

```json
{
 "id": "barmaid",
 "display_name": "Barmaid",
 "stat_growth": {"con": 1, "dex": 1},
 "levels": [
  {"level": 11, "requires_any": {"served_customer": 66}, "grants": ["lesser_strength"]},
  {"level": 12, "requires_any": {"served_customer": 78}, "grants": []}
 ]
},
{
 "id": "server",
 "display_name": "Server",
 "stat_growth": {"con": 1, "dex": 1},
 "levels": [
  {"level": 11, "requires_any": {"delivered_item": 66}, "grants": ["lesser_strength"]},
  {"level": 12, "requires_any": {"delivered_item": 78}, "grants": []}
 ]
}
```
Evolution replacement classes carry level (warrior→swordsman precedent: check swordsman's record and MATCH its structural conventions exactly — `inherits` key if swordsman carries one, level numbering style, etc.). [Barmaid] canon (Lyonette); [Server] canon (Ishkr). Both kits grant [Lesser Strength] (Lyonette-attested). `CANON-FLAG`: verify [Helper] on the wiki mirror; attested fallback if it misses: rename id+display to `assistant`/"Assistant" (also flagged — escalate in the report if BOTH miss, do not invent a third).

- [ ] **Step 3:** verify vs the real machinery — run `tests/test_content.gd`, `tests/test_progression.gd`, `tests/test_sim_core.gd` (grants resolve, DAG sane, no cross-ref breaks). Expected: PASS ×3, zero warnings.
- [ ] **Step 4:** regression: `class_evolution_loop` (9), `consolidation_flow` (9), `generalist_loop` (9), `save_migration` (1) headless — catalog additions must not flip the class-machinery scripts. `load_gate` + smoke.
- [ ] **Step 5:** report (payload diffs, canon attestation notes, gate results). Controller commits `slice T1: [Helper] line + service skills`.

---

### Task T2: inn work-loop content (skeleton + patron graph + work_loop QA)

**Files:**
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json` (`maps.inn.entities` additions ONLY — do not touch other maps)
- Create: `wandering_inn_game_v4/data/dialogue/patron_serving.json`
- Create: `wandering_inn_game_v4/qa/scripts/work_loop.json`
- Modify: `wandering_inn_game_v4/CLAUDE.md` (seed row for `work_loop`)

**Interfaces:**
- Consumes: T1's `helper` class + `basic_cooking` skill id; counters from plan decision 2.
- Produces: QA script `work_loop` (seed 9) — the slice's Helper-leg acceptance evidence.

- [ ] **Step 1:** add inn entities (cells MUST be validated against the inn's merged blocked set — blocked ∪ wall `segment_cells` ∪ entity cells, per wi-adding-a-scene; the cells below are candidates near the dining zone — adjust to the first free cell if occupied, and report final cells):

```json
{"id": "hungry_patron", "kind": "npc", "cell": [5, 6], "display_name": "Hungry Patron", "sprite": "citizen_f", "tint": [1.0, 0.85, 0.6], "facing": "left", "conversation": "patron_serving", "dialogue": [{"speaker": "Hungry Patron", "text": "Innkeeper! Anyone?"}]},
{"id": "serving_tray", "kind": "prop", "cell": [6, 2], "display_name": "Laden Tray", "sprite": "table_brown", "render_scale": 0.5, "on_interact_accomplishment": "delivered_item", "toast": "You carry the laden tray out to the tables."},
{"id": "stew_pot", "kind": "prop", "cell": [3, 1], "display_name": "Stew Pot", "sprite": "grill", "requires_skill": "basic_cooking", "on_skill_use": {"accomplishment": "cooked_meal", "toast": "[Basic Cooking] — The stew comes out rich and hot."}}
```
Sprite ids `table_brown`/`grill`/`citizen_f` must be verified present in `data/sprites.json` (they shipped pre-M-FP; if `grill` is named differently, use the actual kitchen-grill sprite id from the inn's existing entities and report it). Max-fidelity rule: real sprites, no recolored tiles. `stew_pot` sits in the kitchen zone; `serving_tray` at the bar; patron at a dining table, `blocked`-audit clean.

- [ ] **Step 2:** `data/dialogue/patron_serving.json` — mirror the structural shape of `data/dialogue/lyonette_tip.json` (hub + loop-back + ungated exit). Content:

```json
{
 "id": "patron_serving",
 "start": "greet",
 "nodes": {
  "greet": {
   "speaker": "Hungry Patron",
   "text": "There you are! Stew, bread, anything — I've been sitting here an age.",
   "options": [
    {"label": "Bring him a bowl from the kitchen. (Serve)", "effects": [{"accomplishment": "served_customer"}], "goto": "served"},
    {"label": "\"Someone will be right with you.\"", "end": true}
   ]
  },
  "served": {
   "speaker": "Hungry Patron",
   "text": "Ahh. Now THAT'S service. I'll want another before long, mind.",
   "options": [
    {"label": "\"Wave me down when you do.\"", "end": true}
   ]
  }
 }
}
```
ADAPT the key names to the real graph schema (read `lyonette_tip.json` first — option/effect/goto/end key names in this repo's dialogue format are authoritative; the CONTENT above is what's fixed). Re-talk restarts at `greet`, so serving is repeatable — that's the loop.

- [ ] **Step 3:** `qa/scripts/work_loop.json` (seed 9), modeled on `inn_walkthrough`'s structure. Beats, in order, each with the domain event AND `ui_*_rendered` confirmation:
  1. Walk to dirty_table, `use_skill`-interact ×2 → two `accomplishment_recorded{cleaned_the_inn}` (counts 1,2) + exact toast + `ui_toast_rendered`.
  2. Walk to serving_tray, interact ×1 → `accomplishment_recorded{delivered_item}`.
  3. Walk to hungry_patron, converse: choose the Serve option, exit; re-talk, Serve again, exit → `served_customer` count 2 + `ui_dialogue_shown`/`ui_dialogue_hidden`.
  4. Walk to the bed, sleep → `class_gained{helper}` (cleaned_the_inn ≥1 fires `gained_by`) + `toast` containing "Helper" + `ui_toast_rendered`. Assert `assert_event_absent` for any toast text containing "/" progress fragments (opacity teeth: grep-style payload check on the class toast text asserting the EXACT string, which itself contains no numbers).
  5. Post-sleep: `snapshot` assert `classes.helper` present at level ≥1; interact stew_pot BEFORE Helper 3 → `skill_unknown` (basic_cooking not yet known) — the gated-chore negative.
  6. Second chore burst (clean ×2, serve ×1 — crosses the L2 `requires_any` threshold of 3 on cleaned_the_inn) → sleep → `class_level_up{helper}` batched toast.
- [ ] **Step 4:** run `work_loop` headless seed 9 → PASS zero warnings; windowed once, LIST PNG paths (controller reads: patron/tray/pot visible + distinct, toasts legible).
- [ ] **Step 5:** regression: `inn_walkthrough` (9), `dialogue_hub_loop` (9), `lantern_check` (9) — the inn additions must not strand existing walk paths (new entities can block cells scripts walk through — if one goes red, MOVE YOUR ENTITY, never edit the canonical script). `load_gate` + smoke + `tests/test_content.gd` + `tests/test_dialogue.gd`.
- [ ] **Step 6:** CLAUDE.md seed row. Report. Controller commits `slice T2: inn work-loop (Helper leg)`.

---

### Task T3: "The Missing Crate" — 3-path gate-district quest

**Files:**
- Modify: `wandering_inn_game_v4/data/skeleton_scene.json` (`maps.street.entities` additions ONLY)
- Modify: `wandering_inn_game_v4/data/quests.json` (one quest)
- Create: `wandering_inn_game_v4/data/dialogue/krshia_crate.json`, `wandering_inn_game_v4/data/dialogue/watch_crate.json`
- Create: `wandering_inn_game_v4/qa/scripts/crate_fight.json`, `crate_talk.json`, `crate_light.json`
- Modify: `wandering_inn_game_v4/CLAUDE.md` (3 seed rows)

**Interfaces:**
- Consumes: gate-district street map (32×20, W1) — `krshia_stall` prop at its shipped cell; existing combatant `goblin_raider`; existing arena = whatever `goblin_encounter_2` references in `data/skeleton_scene.json` (read it).
- Produces: counters `found_the_crate`, `crate_returned`, `studied_the_cellar` (Tactician seam), `recovered_crate_force`/`_watch`/`_guile` (path telemetry for the F-task pillar audit).

- [ ] **Step 1:** quest record appended to `quests.json` `quests` array (shape = `the_errand`):

```json
{
 "id": "missing_crate",
 "title": "The Missing Crate",
 "beats": [
  {"id": "find", "description": "Find out what happened to Krshia's missing crate near the south-square sewers.", "complete_when": {"found_the_crate": 1}},
  {"id": "report", "description": "Tell Krshia what became of her crate.", "complete_when": {"crate_returned": 1}}
 ]
}
```

- [ ] **Step 2:** street entities (cells validated against the street's merged blocked set; candidates given — adjust to free cells near the named zones and report):

```json
{"id": "krshia", "kind": "npc", "cell": [8, 2], "display_name": "Krshia", "sprite": "citizen_f", "tint": [0.75, 0.6, 0.45], "facing": "down", "conversation": "krshia_crate", "dialogue": [{"speaker": "Krshia", "text": "Hrr. Busy, yes? Come back when you can talk."}]},
{"id": "crate_scavengers", "kind": "encounter", "cell": [12, 16], "display_name": "Crate Scavengers", "sprite": "goblin_raider", "arena": "SAME-AS-goblin_encounter_2", "enemies": ["goblin_raider", "goblin_raider"], "allies": [], "on_victory": ["recovered_crate_force", "found_the_crate"]},
{"id": "cellar_door", "kind": "prop", "cell": [10, 17], "display_name": "Dark Cellar", "sprite": "door", "requires_skill": "light", "on_skill_use": {"accomplishment": "studied_the_cellar", "toast": "[Light] — The orb drifts down the stairs. There: Krshia's crate, dragged behind a broken shelf."}}
```
Krshia stands BESIDE her shipped stall prop (canon: Krshia Silverfang, Gnoll shopkeeper — tint reads brown/tan vs Selys's green and the magenta citizens). `arena`: copy the exact arena id `goblin_encounter_2` carries in floodplains. The scavengers + cellar sit in the south square near the sewer grates (design-consistent: sewers are where goblins slip in).

- [ ] **Step 3:** `krshia_crate.json` — hub graph (goblin_parley + lyonette_tip conventions; ADAPT key names to the real schema):
  - `hub` (Krshia): quest pitch. Options: start quest ("I'll look into it." → effects `[{"quest": "missing_crate"}]`, `hide_when` after quest started) · report option A gated `requires {studied_the_cellar: 1}` (HIDDEN until met): "The crate's in the old cellar — scavengers dragged it down." → effects `[{"accomplishment": "recovered_crate_guile"}, {"accomplishment": "found_the_crate"}, {"accomplishment": "crate_returned"}]` → thanks node · report option B gated `requires {found_the_crate: 1}` (covers fight/watch paths): "Your crate's accounted for." → effects `[{"accomplishment": "crate_returned"}]` → thanks node · ungated exit.
  - NOTE the guile path banks `found_the_crate` at REPORT time (prop `on_skill_use` banks only one id — the study itself banks `studied_the_cellar`; discovery completes when told to Krshia). Beat `find` therefore completes at different moments per path — that is fine and asserted per-script.
  - `hide_when` on the pitch after `missing_crate` is started; both report options `hide_when {crate_returned: 1}` so the hub retires cleanly. One key per requires dict.
- [ ] **Step 4:** `watch_crate.json` — give the SOUTH-square Watch guard (the one Q2 asserts `dialogue_line` for stays UNTOUCHED — add a NEW `watch_sergeant` npc next to the sewer grates instead, `citizen_f` sprite, tint `[0.6, 0.7, 1.0]`): persuade option gated `requires {missing_crate_started...}` — quests don't bank counters; gate on the quest-start effect instead: give the pitch option a second effect `{"accomplishment": "asked_about_crate"}` and gate the sergeant's option `requires {asked_about_crate: 1}` — "Scavengers by the grates. Clear them out for the Silverfang, will you?" → option "Point them at the scavengers. (Persuade)" → effects `[{"accomplishment": "recovered_crate_watch"}, {"accomplishment": "found_the_crate"}, {"remove_entity": "crate_scavengers"}]` (goblin_parley's remove pattern) + ungated exit + `hide_when {found_the_crate: 1}`.
- [ ] **Step 5:** three QA scripts, all starting with the proven inn→floodplains→liscor_gate route (copy the leg from `gate_district_walkthrough.json`):
  - `crate_fight.json`: pitch from Krshia → walk to scavengers → fight via `combat_autoplay` → `combat_finished{victory:true}` → `accomplishment_recorded{found_the_crate}` → report B → `quest_beat_completed` ×2 + journal `ui_journal_rendered` assert. **Seed: derive** (new roster/arena pairing — search from 9 upward per wi-adding-an-encounter; document the search).
  - `crate_talk.json` (seed 9, no combat): pitch (banks `asked_about_crate`) → sergeant persuade → `entity_removed{crate_scavengers}` + `assert_event_absent combat_started` → report B → beats complete.
  - `crate_light.json` (seed 9): lantern_check's proven prologue (scroll → sleep → [Mage]/[Light]) → travel → `use_skill` on cellar_door → `accomplishment_recorded{studied_the_cellar}` + exact toast → report A (hidden-until-met option — assert the option list BEFORE studying omits it: cursor-index discipline) → beats complete.
  - All three: opacity spot-assert (quest/journal text contains no counter numerals) + `ui_toast_rendered` confirmations.
- [ ] **Step 6:** full verify: 3 new scripts green; regression `gate_district_walkthrough` (9), `relc_tutorial` (9), `street_peek` windowed (new entities visible, controller reads); `tests/test_content.gd` + `test_dialogue.gd` + `test_quests.gd`; `load_gate` + smoke.
- [ ] **Step 7:** CLAUDE.md rows. Report (incl. final cells, seed-search log, canon notes — Krshia text tone vs wiki voice). Controller commits `slice T3: The Missing Crate (3-path quest)`.

---

### Task T4: slice F — full gate, pillar audit, docs, review

**Files:**
- Modify: `HANDOFF.md`, `wandering_inn_game_v4/CLAUDE.md` (script-count prose), `docs/VISUAL-LOG.md` (triage anything new)

- [ ] **Step 1:** full canonical sweep (now 26 scripts) at pinned seeds + 12 units + smoke + balance harness (classes.json changed: harness gates must hold — Helper isn't in any harness composition, verify output unchanged cell-for-cell) + web parity spot (`combat_walkthrough` wasm).
- [ ] **Step 2:** pillar audit (spec §5): counter-banking opportunities per pillar — Combat (spar loop + 3 encounters + crate fight), Social (patron serve, Krshia/sergeant talk paths), Exploration/Puzzles (cellar [Light] study, scroll, lantern) — table in the report; flag any pillar at zero repeatable sources.
- [ ] **Step 3:** windowed set for HANDOFF (work-loop props, Krshia + sergeant + cellar, one crate-path mid-beat) — controller-read; VISUAL-LOG per fidelity directive.
- [ ] **Step 4:** whole-branch review (opus) over the slice range with method hints: requires_any level-walk semantics vs cumulative thresholds (the L4/L5 `cooked_meal` keys join later — trace `check_level_ups`'s cumulative walk against a cook-only player), monotonic-counter loop edge (re-serving after `crate_returned`), the three-path convergence (can a player bank `found_the_crate` twice? — fight then talk — and does beat completion tolerate it), save round-trip of new counters, opacity across all new text. Fix wave per findings.
- [ ] **Step 5:** HANDOFF: slice acceptance checklist for the human playtest (spec §4 bar: one session levels warrior via spar AND Helper via chores, feels the split penalty, resolves the quest three ways on three runs). Ledger. Controller commits `slice F: gate + docs`.

## Self-review notes

- Spec §4 coverage: work-loop→T2, spar leg→already live (W2), 3-path quest→T3, Helper data→T1, acceptance bar→T4 step 5. §2.1 Helper/Barmaid/Server→T1. §2.2 Tactician: only the `studied_*` seam ships (T3) — full Tactician is the Three Pillars milestone, per spec §4.4.
- No-sim-change audit: every mechanism used (gained_by, requires_any, effects arrays, on_victory arrays, prop chains, remove_entity, quest counters) verified present in shipped code at plan time (file:line traced in the planning session).
- Type consistency: counter ids match across T1 (requires_any keys) / T2 (banking) / T3 (quest + telemetry); `basic_cooking` id consistent T1→T2.
- Known risk: dialogue-graph key-name drift (this plan writes content, the repo schema names win — both graph tasks instruct ADAPT-to-schema); encounter-cell/entity-cell collisions (both tasks carry the merged-blocked-set audit).
