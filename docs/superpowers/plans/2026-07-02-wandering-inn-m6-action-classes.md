# M6 — Action-Driven Classes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** progression by deed — action counters level classes, focus evolves them at 10, split builds pay ~20–25%, [Spellsword] consolidation offered at sleep; all opaque-until-sleep.

**REV 2 (consultant-integrated):** the spec's REV 2 supersedes REV 1 numbers/mechanisms everywhere — consolidation math ceil(2·sum/3) w/ max-parent clamp (pinned: (9,12)->14, (6,7)->9, (10,10)->14, (20,8)->20); trigger both>=6 sum>=13; multi-level sleeps; repeatable street encounter; sleep order gains->level-ups->evolutions->consolidation-OFFER-first-at-collision; Mage waits like Warrior + min-volume + state toast; k-norm formula with CLOSED-FORM power-ratio gate [0.75,0.80] (harness win-rate informative only, caster profile added); inherits field for kit survival; ONE save bump v1->2; fixture_save harness affordance; liveness = data flag only; base Warrior gets [Piercing Strikes] so spear path is real.

**NEW Task T0 (before T4): half-day calibration spike** — caster AI profile + k-sweep {1.0,1.35,1.7}; document win-rate-vs-power-ratio tracking; closed-form gate governs regardless.

**Architecture:** the spec is the authority — `docs/superpowers/specs/2026-07-02-wandering-inn-m6-action-classes-design.md`, with the canon taxonomy `2026-07-02-m6-canon-class-taxonomy.md` as its content source (canon-verified names ONLY; its Confidence Notes list forbidden names). Sim-pure mechanics in `WICombat` tally / `WIGame` banking / `WIProgression` resolution; presentation renders toasts/hints/offer.

**Tech stack:** Godot 4.7, GDScript, existing harness. Written for post-Fable execution: every task names its authority section; the balance harness settles every number.

## Global Constraints

- M4/M5 plan Global Constraints carry over verbatim (purity, zero warnings, GDQuest style, no raw stats, QA green at merge gates, presentation-pacing rule, controller merge-owns project.godot, no controller edits during live Codex jobs).
- **No progress meters or progress-toward text anywhere** (opaque-until-sleep is user-locked). Journal hints are retrospective only.
- **Combat data changes WILL move canonical seeds** — every task that touches combatants/skills/classes data re-verifies the seed table and re-derives where needed (budgeted in F1).
- The vision example is a pinned test: Warrior 9 + Mage 12 → [Spellsword] 14 via **ceil(2·21/3)** — integer math ONLY (0.67 float gives 15 and is WRONG; see spec §2.5 REV 2).
- M6 starts only after M5's final review closes (M5 rewrote the presentation layer M6's UI lane touches).

## Lanes

```
Lane SIM (sequential, TDD-heavy, strongest implementer):
  T1 counters+tags → T2 counter-driven leveling → T3 evolution → T4 L^k scaling → T5 consolidation
Lane CONTENT (parallel from T1): T6 classes.json tree + kits + aspiration stubs
Lane QA (parallel from T2):     T7 QA scripts + save-migration fixture
Lane UI (after SIM + M5-H):     T8 toasts/journal hints/consolidation prompt (hotbar syncs new kits)
Final:                          T9 fighter→warrior migration sweep → F1 harness calibration + seed re-derivation + docs → Opus final review
```

Ownership: SIM owns `src/core/**` + `tests/test_*`; CONTENT owns `data/classes.json` + `data/skills.json` (SIM may add tag READING, never data); QA owns `qa/scripts/**` + fixture saves; UI owns `src/ui/**` + `src/combat/` UI half. T9 crosses data+scripts+dialogue — runs alone.

---

### Task T1: combat action tally + skill tags (spec §2.1 REV 2 — liveness is the `trivial` data flag, NO round/damage heuristic; defeat banks nothing)

**Files:** `src/core/combat/wi_combat.gd` (per-fight tally dict, populated where attack/skill resolution already emits events), `src/core/wi_game.gd` (`resolve_combat` banks tally → accomplishments via existing `record_accomplishment`, gated by the liveness rule), `data/skills.json` (weapon/element tags — coordinate: CONTENT lane owns the file; T1 ships the reader + the tags for the four existing spells/skills in ONE disclosed edit), `tests/test_combat_sim.gd` + `tests/test_sim_core.gd` additions.

- [ ] TDD: failing tests — tally counts melee hits per actor; spell casts tagged by element; tally banks to accomplishments on victory resolution; `trivial: true` encounters bank NOTHING (data flag — no round/damage heuristic exists); defeat banks nothing.
- [ ] Implement; all units + combat QA at canonical seeds (no data/rules changed yet → seeds hold); smoke. Commit.

### Task T2: counter-driven leveling (spec §2.2)

**Files:** `src/core/progression.gd`, `tests/test_progression.gd`. ⟦I10⟧ T2 defines the threshold SCHEMA + reader ONLY — `data/classes.json` VALUES are authored by CONTENT T6a, which must land before T2's verification; T2 also implements MULTI-LEVEL sleep loops (spec §2.2 REV 2) and the repeatable-encounter engine support (`respawns` flag in resolve_combat).

- [ ] TDD: warrior levels from melee counters; mage from cast counters; MULTI-LEVEL single sleep (loop-until-no-gain, one batched toast per class); placeholder `won_combat>=3` mage rule DELETED (test asserts absence); respawning encounter re-arms after sleep.
- [ ] MEASURE real tally volumes from QA runs FIRST (record in ledger), then CONTENT tunes thresholds to the REV 2 bands (Warrior 8–11 / Mage 7–9 focused, ~6–7/6–7 split). Units + QA sweep (seeds re-checked). Commit.

### Task T3: evolution machinery (spec §2.3)

**Files:** `src/core/progression.gd` (`check_evolutions(classes, accomplishments, config) -> Array` — replacement semantics), `src/core/wi_game.gd` sleep() ordering (gains → level-ups → evolutions → consolidation offer, spec §2.3 REV 2), `tests/test_progression.gd`.

- [ ] TDD per spec §2.3 REV 2: sleep order gains→level-ups→EVOLUTIONS (fixed ⟦I7⟧); dominance ≥60% AND min tagged volume; WAIT symmetric for Warrior+Mage (no immediate Mage cap burn ⟦I8⟧); balanced-Mage generalist only at share<60% AND min volume; at-cap state toast (once per class per sleep, qualitative, no numbers); off-interval flavor only at 12+; kit survival via `inherits` resolution in granted_skills (⟦B5⟧, incl. cycle guard); `class_evolved {from,to,level}`.
- [ ] Units + QA. Commit.

### Task T4: non-linear scaling (spec §2.4)

**Files:** `src/core/progression.gd` (`effective_power(classes, config) -> float` = k-NORM `(Σ L_i^k)^(1/k)`, spec §2.4 REV 2 — formula reading is PINNED), `src/core/wi_game.gd` `_build_player_combatant` (derived stat application — DESIGN NOTE: stats stay sim-internal, never UI), `tests/test_progression.gd`, `tests/sim_combat_batch.gd` (new build axis: pure-10 / 5-5 / consolidated-14).

- [ ] TDD: monotonicity; PINNED closed-form gate — 5/5-vs-pure-10 power ratio in [0.75,0.80] at shipped k (unit test IS the gate); k from classes.json meta.
- [ ] Harness: caster AI profile (T0 spike delivers it) + matrix axes pure-w10/pure-m10(caster)/5-5(both)/consolidated; win rates RECORDED not gated (dual-kit confound — spec §2.4). Units + QA + seed re-check. Commit.

### Task T4b: additive stat_growth (spec §2.4 REVISION 2026-07-03 — user veto of split-penalty-only reading; SIM lane, before T5)

**Files:** `src/core/progression.gd` (new `derived_stat_bonuses(classes, class_catalog) -> Dictionary`; extract the shared apply helper the T4 review flagged as duplicated), `src/core/wi_game.gd` `_build_player_combatant` (multiply → add-bonus rewire), `data/classes.json` (`stat_growth` per class — disclosed single CONTENT-lane edit, T1 precedent), `tests/test_progression.gd`, `tests/sim_combat_batch.gd` (dedupe via the shared helper).

- [ ] TDD: `stat_bonus[S] = round(Σ_class growth_c[S]·L_c · efficiency)` with `efficiency = power_multiplier` (round once per stat, efficiency outside the sum — pinned reading); focused builds get the full bonus exactly (mult 1.0); 5/5 split ≈78% per domain; empty classes → no bonuses; closed-form [0.75,0.80] gate test UNCHANGED (k=1.55 stays).
- [ ] Harness re-run (win rates recorded, not gated); canonical-seed sweep RECORDED — re-derivation stays F1's (baseline moves for focused builds too). No save schema change (bonuses derived at build time). Commit.

### Task T5: consolidation (spec §2.5)

**Files:** `src/core/progression.gd` + `src/core/wi_game.gd` (offer at sleep, accept/decline API, `consolidation_offered/accepted/declined` events), `src/core/save.gd` (offer state round-trip), `tests/test_progression.gd` + `tests/test_save.gd`.

- [ ] TDD per spec §2.5 REV 2: trigger both≥6 sum≥13; merged = max(ceil(2·sum/3), max(parents)) — pinned (9,12)→14, (6,7)→9, (10,10)→14, (20,8)→20; OFFER precedes evolutions at collision; evolved classes valid parents; skills fold via inherits; either-parent leveling; decline→re-offer; offer state save round-trip. SAVE: this task implements the ONE coordinated v1→2 bump + migration fn covering ALL M6 schema (spec §2.7) — T9 extends the SAME migration with the rename, no second bump.
- [ ] Units + QA. Commit.

### Task T6: content — class tree + kits (taxonomy §2/§5; CONTENT lane, parallel from T1)

**Files:** `data/classes.json`, `data/skills.json` (+icons per M5 H1 pattern), `data/sprites.json` (icon entries).

- [ ] Author: warrior/swordsman/spearmaster/mage/ice_mage/fire_mage/spellsword + aspiration stubs; kits ONLY from taxonomy §5 canon-verified names ([Lunge] and the ruled-out names are FORBIDDEN); new effect types (e.g. [Second Wind] heal, [Icy Floor] terrain) need SIM-lane coordination — prefer existing effect types, disclose any new ones as a SIM sub-task.
- [ ] [Light] as out-of-combat utility (M2 prop-skill pattern) with one content use.
- [ ] test_combat_data + test_content green; balance harness run (interim); icons screenshot-verified by controller. Commit.

### Task T7: QA scripts + migration fixture (spec §3; QA lane, parallel from T2)

- [ ] FIRST: implement the `fixture_save` harness affordance in test_driver.gd (spec §3 ⟦B6⟧, ~20 lines: copy res://qa/fixtures/<name>.json → user://saves/manual.json pre-run). Commit fixtures: near_evolution (v2), near_consolidation (v2), v1_format (v1, hand-authored ONCE). Scripts: class_evolution_loop (fixture start + repeatable-encounter ORGANIC finish), consolidation_flow (decline→re-offer→accept), save_migration (v1 via pause-load AND via DEFEAT-RELOAD ⟦I12⟧).
- [ ] Seeds pinned per script; CLAUDE.md table updated. Commit.

### Task T8: UI — toasts, journal hints, consolidation prompt (UI lane, after SIM + M5 final)

**Files:** `src/ui/**`, `src/combat/` UI half (hotbar picks up new kits automatically via skills.json order — verify), journal retrospective hint lines.

- [ ] Evolution/consolidation toasts (canon voice); consolidation yes/no prompt beat at sleep (keyboard, matches M5 UI style); journal hints AFTER events only (no progress-toward — constraint test: grep new strings for numbers/percentages).
- [ ] Windowed screenshots controller-verified; QA sweep. Commit.

### Task T9: fighter→warrior migration ([D]1; runs ALONE — crosses all ownership)

**Files:** `data/*.json` (ids), `src/core/save.gd` (version bump + mapping), every `qa/scripts/*.json` + `data/dialogue/*.json` with `fighter` references, `tests/**` references.

- [ ] Extend T5's migration fn with fighter→warrior (NO new version bump); execute the EXPLICIT hit list in spec §4 (skeleton_scene starting classes, goblin_parley gate+copy, level_up_loop + dialogue_walkthrough asserts, sim_combat_batch BUILDS+header, test literals incl. "requires Fighter 2", CLAUDE.md "Fighter-2" notes); closing check `grep -ri fighter` repo-wide; defeat-reload of a stale v1 autosave proven by T7's save_migration script.
- [ ] FULL QA sweep + all units. Commit.

### Task F1: harness calibration + seed re-derivation + docs

- [ ] Tune k + thresholds until: split gate 20–25%, all win-rate cells 0.55–0.95, medians 3–12; record matrix in ledger.
- [ ] Re-derive any moved canonical seeds (search protocol per M3/M4 precedent); update CLAUDE.md (M6 block: counters/evolution/consolidation semantics, new seeds, forbidden-names note) + HANDOFF (playtest checklist: focused-vs-split feel, opaque-until-sleep verbatim reactions, evolution moment delight, consolidation prompt clarity).
- [ ] Full sweep: units, 15+ QA scripts, web parity. Commit.

### Final gate: mandatory Opus whole-branch review + fix wave.

## Self-review notes
- Spec §2 numbers (60% dominance, thresholds, k) are all data — F1 owns final values; tasks encode them as config, never literals in sim code.
- T1's skills.json tag edit crosses CONTENT ownership — single disclosed edit, CONTENT rebases on it (sequence T1 before T6 dispatch).
- If M5's H-lane changed combat input/UI structure beyond spec (check its reports), T8's brief must carry the delta — post-Fable planner: read M5 ledger entries before dispatching T8.
