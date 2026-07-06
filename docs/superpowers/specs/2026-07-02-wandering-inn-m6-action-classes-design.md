# M6 Design — Action-Driven Classes (the identity system) — REV 2

**Status:** REV 2 — execution-ready for autonomous execution. REV 1 was adversarially
reviewed by the external consultant (NEEDS REVISION, 6 blockers + 6 importants —
`docs/superpowers/consultant/2026-07-02-m6-spec-review.md`); ALL findings are integrated
below (marked ⟦Bn⟧/⟦In⟧ where load-bearing). The user approved the [D] register
(2026-07-02) and is unavailable during execution — this document plus the plan are the
complete authority. Where this REV 2 conflicts with the taxonomy doc's numbers, REV 2 wins.

**Authorities, in order:** (1) user-locked decisions in
`2026-07-02-progression-vision-action-driven-classes.md` §RESOLVED; (2) this spec; (3) the
canon taxonomy `2026-07-02-m6-canon-class-taxonomy.md` for names/tree/canon rules (its
Confidence Notes list FORBIDDEN names). Canon source: `wiki.wanderinginn.com`.

**Goal:** progression by deed — melee levels [Warrior], casting levels [Mage], focus
evolves at the 10-cap, split builds pay 20–25%, [Spellsword] consolidation is OFFERED at
sleep and genuinely reachable by the split archetype. All opaque-until-sleep.

**Non-goals:** unchanged from REV 1 (gear, studied-spell duality, self-creation,
de-consolidation, comma classes, progress meters).

## 1. Ship set

Unchanged from REV 1: [Warrior] (fighter rename — [D]1), [Swordsman], [Spearmaster],
[Mage], [Ice Mage], [Fire Mage], [Spellsword] ([D]2), NPC-flavor classes as data,
aspiration stubs. ⟦I11⟧ **Base [Warrior]'s kit includes ONE spear-tagged skill** —
[Piercing Strikes] (canon, Ksmvr) — so the sword/spear behavioral choice is REAL and
[Spearmaster] is reachable. (REV 1 shipped it unreachable: spear skills only existed
post-evolution.)

## 2. Mechanics (sim core — pure, harness-tunable)

### 2.1 Action counters ⟦I9⟧
Per-fight tally in `WICombat`, banked to accomplishments in `WIGame.resolve_combat` on
VICTORY (defeat banks nothing — defeat already reloads the autosave, so lost tallies are
consistent with the reload; document this in the class-system docs). Skill tags in
`skills.json`: `weapon: "sword"|"spear"`, `element: "ice"|"fire"`. Counters: `melee_hit`,
`sword_skill_used`, `spear_skill_used`, `spell_cast`, `ice_cast`, `fire_cast`.
**Liveness is a DATA flag, not a heuristic:** encounters/arenas may set `"trivial": true`
→ no counter bank (silent). No round-count clause, no damage-dealt clause (REV 1's
"3 rounds OR enemy damage>0" both under- and over-blocked — a flawless 2-round win of a
real fight MUST bank). Shipped demo content marks nothing trivial today; the flag exists
for the repeatable encounter below and future content.

### 2.2 Leveling ⟦B2⟧
- `classes.json` thresholds become counter-driven (schema: per-level cumulative counter
  requirements; T2 defines the schema, CONTENT authors values ⟦I10⟧).
- **Multi-level sleeps:** `check_level_ups` loops until no further threshold is met — one
  sleep can grant several levels (announced as one batched toast per class: "[Warrior
  Level 9 → 12]" style). REV 1's +1-per-sleep inheritance is REMOVED (it made level 10–12
  arithmetically unreachable in the demo's sleep count).
- **Repeatable encounter (data-only):** the street gains one respawning skirmish
  (`"respawns": true` on a new encounter entity — engine support: `resolve_combat` skips
  `remove_entity` for respawning encounters; the entity re-arms after the next sleep).
  This is the demo's counter volume valve AND the organic path for QA/evolution.
  Balance-harness content rules apply; it may NOT be marked trivial.
- **Honest band restatement:** demo arc (errand + fixed fights + a few repeatable runs +
  chores) targets **Warrior 8–11 focused** / **Mage 7–9 focused** / **~6–7 each split**.
  Thresholds tuned to land those bands with the tally volumes MEASURED from real QA runs
  (T2 records measured volumes in the ledger before tuning; REV 1's guessed volumes were
  ~3× too optimistic per the consultant's analysis).

### 2.3 Evolution ⟦I7⟧⟦I8⟧
- **Sleep ordering (REVISED): gains → level-ups → evolutions → consolidation offer.**
  (REV 1's evolutions-before-level-ups delayed every evolution one sleep.)
- At each sleep, a class at level ≥10 with its 10-cap unconsumed: dominant weapon/element
  share ≥60% AND total tagged uses ≥ a minimum volume (data, default 12) → evolve
  (replace id, carry level, kit per §2.6 inherits). Otherwise the class **WAITS —
  symmetric for Warrior AND Mage** (REV 1 consumed the Mage cap immediately; a ±1-cast
  coin flip permanently locked out [Ice Mage] — removed).
- **Balanced-Mage generalist path ([D]3):** granted only when share <60% AND total casts
  ≥ the minimum volume at cap-check time (demonstrated identity, not noise). Consumes the
  cap. Warrior has no generalist branch (waits indefinitely; sword/spear only).
- **At-cap-no-evolution feedback:** the sleep where a class is ≥10 but neither evolves
  nor takes the generalist path emits ONE qualitative state toast ("Your focus wavers
  between frost and flame." / "Your hands haven't chosen sword or spear yet.") — state
  description, not progress-toward; the opacity rule survives, and the player learns the
  system is alive. Emitted at most once per class per sleep, only at the cap.
- Off-interval evolution (past 10) keeps the canon "substandard" flavor line ONLY when it
  fires at 12+ (not at 10/11 — the normal path must not read as substandard ⟦I7⟧).

### 2.4 Non-linear scaling ⟦B4⟧
- **Formula pinned (one reading):** `effective_power(classes) = (Σ_i L_i^k)^(1/k)` — the
  k-norm of held class levels. Pure 10 → 10.0; 5/5 at k=1.35 → 8.36 (power ratio 0.836);
  monotonic in every L_i; k=1 degrades to the plain sum. `k` lives in classes.json meta.
- **Primary gate is CLOSED-FORM:** tune k so the 5/5-vs-pure-10 power ratio lands in
  [0.75, 0.80] (the locked 20–25% band); k ∈ [1.32, 1.42] per the consultant's algebra —
  a unit test pins the ratio, no harness needed for the gate itself.
- Power applies as a scalar on the combat-relevant derived stats in
  `_build_player_combatant` (stats stay sim-internal, never UI).
- **Secondary (informative, not blocking): harness matrix with a CASTER-PROFILE PC** —
  T4 adds a `"caster"` AI profile to `WICombatAI` (prefers affordable spells over melee;
  the vision explicitly requires playstyle-scripted profiles and the melee-only autoplay
  gotcha is documented). Matrix axes: pure-warrior-10 / pure-mage-10(caster) / 5-5(both
  profiles) / consolidated. Record win rates in the ledger; bounds stay 0.55–0.95 for
  shipped fights; the split-vs-pure win-rate GAP is reported, not gated (dual-kit
  advantage confounds it — the closed-form gate is the design authority ⟦B4⟧).

- **REVISION (2026-07-03, user veto of the split-penalty-only reading):** "Power applies as
  a scalar" is corrected to **additive level→class-stat growth, scaled by split-efficiency** —
  canon: leveling a class boosts THAT class's relevant stats (magnitude), while SKILLS remain
  the primary progression driver. Two halves, one formula family:
  1. **Magnitude (new):** each class declares `stat_growth` in classes.json — a map of
     combat-stat → increment-per-effective-level. Canon mapping: `fighter`/`warrior` →
     `{str,con}`; `swordsman`/`spearmaster` → `{str,dex}`; `mage`/`ice_mage`/`fire_mage` →
     `{int}`; `spellsword` → `{str,int}`. Increments start uniform (+1) and are DATA-tunable
     (F1/playtest), never a hard commit.
  2. **Split-efficiency (kept from the shipped T4):** `efficiency = power_multiplier =
     effective_power(classes)/Σlevels` (1.0 focused, ≈0.78 for a 5/5 split at k=1.55).
  3. **Application:** `stat_bonus[S] = round(Σ_class growth_c[S] · L_c · efficiency)`, ADDED to
     the base template stat (not multiplied). Focused level-10 → full class bonus; 5/5 split →
     ≈78% of each class's bonus, spread across two stat domains → weaker in any single domain.
     Magnitude AND the locked 20–25% split friction fall out together.
  - The closed-form `effective_power` ratio gate [0.75,0.80] STANDS as the efficiency measure
    (k=1.55, shipped). What changes is that stats now grow with level for FOCUSED builds too,
    so the balance baseline moves — F1's seed re-derivation expands to every canonical combat
    seed, not only split-PC paths. The shipped T4 (commit 3447869: `effective_power`,
    `power_multiplier`, harness axes) is the substrate; the revision adds `stat_growth` data +
    `derived_stat_bonuses` + rewires `_build_player_combatant` from multiply to add-bonus.

### 2.5 Consolidation ⟦B1⟧⟦B3⟧⟦I7⟧
- **Trigger (REVISED): both parents ≥6 AND sum ≥13** (data, tunable) — fires for the
  demo's real split archetype (~6–7/6–7). REV 1's (≥8, sum≥18) could never fire outside
  fixtures — the user-locked choice beat was dead content.
- **Math (REVISED): merged = max(ceil(2·(L_a+L_b)/3), max(L_a, L_b))** — integer
  arithmetic (never 0.67 float: ceil(0.67×21)=15 but the vision example needs
  ceil(2·21/3)=14 — REV 1's pinned test was arithmetically false); the max() clamp stops
  the merge dropping below the higher parent (20+8 would otherwise yield 19). Pinned
  tests: (9,12)→14 (the vision example), (6,7)→9, (10,10)→14, (20,8)→20 (clamp).
- **Precedence at the same sleep: the consolidation OFFER is presented BEFORE evolutions
  resolve** (it's the user-locked choice beat; evolution is automatic). Decline → that
  sleep's evolutions proceed normally. Accept → parents are consumed into [Spellsword];
  no evolution that sleep. **Evolved classes remain valid parents** ([Swordsman]+[Ice
  Mage] still offer [Spellsword], same target) ⟦I7⟧.
- Offer state + accept/decline round-trip in saves; re-offered each qualifying sleep;
  refusable forever. Events: `consolidation_offered/accepted/declined`.
- Consolidated class levels from EITHER parent line's counters (canon rule, unchanged).

### 2.6 Kits + skill inheritance ⟦B5⟧
- Combat kits are RECOMPUTED from held classes every fight (existing architecture) — so
  evolution/consolidation would silently strip granted skills. **New classes.json field:
  `"inherits": "<class_id>"`** — `WIProgression.granted_skills` resolves the inheritance
  chain (child grants = own grants ∪ inherited grants, cycle-guarded). [Swordsman]
  inherits warrior; [Spellsword] inherits BOTH parents via `"inherits": ["warrior",
  "mage"]` (list form) + its signature skill ([Keener Edge], canon).
- Kits per taxonomy §5 + §1's spear addition; canon names only; new effect types are
  SIM-lane work with tests (as REV 1).
- [Light] out-of-combat utility unchanged.

### 2.7 Save schema ⟦B5⟧
**ONE coordinated version bump (1→2)** covering ALL M6 schema additions (per-fight-tally
nothing — sim-transient; cap-consumed set, consolidation offer state, evolved/renamed
class ids) PLUS the fighter→warrior mapping, in a single migration function. v1 saves
(including stale autosaves hit via DEFEAT-RELOAD — that path must be migration-tested,
else `_close_banner`'s reset fallback wipes runs ⟦I12⟧) migrate transparently. The T7
fixture save is authored in v1 format once, committed, never regenerated.

## 3. QA / verification ⟦B6⟧

- **New harness affordance (spec'd here, not improvised): `"fixture_save"` key in a QA
  script header** — TestDriver copies `res://qa/fixtures/<name>.json` into
  `user://saves/manual.json` before the run (~20 lines in test_driver.gd). Committed
  fixtures: `near_evolution.json` (Warrior 9, sword counters at threshold-1),
  `near_consolidation.json` (6/6 dual), `v1_format.json` (migration).
- Scripts: `class_evolution_loop` (fixture start + repeatable-encounter organic finish —
  the organic last level is the assertion that matters), `consolidation_flow` (decline →
  re-offer → accept), `save_migration` (v1 fixture via pause-load AND via defeat-reload).
- Unit: tally/banking + trivial flag; multi-level sleep loop; evolution dominance +
  min-volume + wait symmetry + state-toast once-guard; k-norm pins (ratio band test);
  consolidation math pins ((9,12)→14, (6,7)→9, (10,10)→14, (20,8)→20); inherits chain
  resolution (incl. cycle guard); migration.
- Harness: caster profile + matrix axes per §2.4; bounds 0.55–0.95 on shipped fights.
- Dialogue/content sweep per §4/T9.

## 4. Migration hit list (T9 — explicit, from the consultant's sweep ⟦I12⟧)

`data/skeleton_scene.json` PC starting `classes` (new games, not just saves);
`data/dialogue/goblin_parley.json` fighter gate + "(Fighter)" copy; the M4.1 Lyonette
content (already conversation-gated — verify no fighter remnants);
`qa/scripts/level_up_loop.json` `classes.fighter` assert;
`qa/scripts/dialogue_walkthrough.json` `class_level_up {class: fighter}` payload;
`tests/sim_combat_batch.gd` BUILDS constants + header comment;
`tests/test_sim_core.gd` / `test_save.gd` / `test_progression.gd` / `test_dialogue.gd`
(expected literals incl. "requires Fighter 2"); v4 `CLAUDE.md` seed-table notes ("Fighter-2");
defeat-reload of v1 autosave (see §2.7). Repo-wide `grep -ri fighter` is the closing check.

## 5. Execution notes

- **T0 (NEW, before T4 dispatch): half-day calibration spike** ⟦consultant de-risk⟧ —
  caster AI profile + k-sweep {1.0, 1.35, 1.7} through the matrix; confirm the k-norm
  power ratio is the stable gate and record whether win-rate gaps track it. If they
  don't, the closed-form gate STILL governs (already primary) — the spike just documents
  the divergence for the playtest checklist.
- Lane ownership ⟦I10⟧: T2 defines threshold SCHEMA + reader; CONTENT (T6a) authors ALL
  classes.json values (tree skeleton + thresholds) BEFORE T2's verification runs; T6b
  (kits) parallel after T6a. SIM never writes classes.json values.
- Ordering, harness authority, Opus final review, playtest-checklist accumulation
  (user absent): unchanged from REV 1.
- Playtest checklist additions: opaque-until-sleep verbatim reactions; the at-cap state
  toast (does it read as guidance or noise); repeatable-encounter pacing; split-vs-pure
  feel vs the 20–25% number.
