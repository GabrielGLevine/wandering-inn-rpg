# M6 spec + plan — external consultant adversarial review (pre-autonomy gate)

**Reviewed:** `docs/superpowers/specs/2026-07-02-wandering-inn-m6-action-classes-design.md` +
`docs/superpowers/plans/2026-07-02-wandering-inn-m6-action-classes.md`
**Against:** the vision doc (authority), the canon taxonomy, v4 `CLAUDE.md`, and the code on
`main` (`progression.gd`, `wi_game.gd`, `wi_combat.gd`, `save.gd`, `classes.json`,
`combatants.json`, `skills.json`, `sim_combat_batch.gd`, `test_driver.gd`, `qa/run_qa.sh`).
Godot is not installed in this review environment, so the counter-volume sanity check was done
analytically from combat data (stat formulas verified against `wi_combat.gd`), not by running a
fight. All arithmetic below is checkable by hand.

---

## Verdict: NEEDS REVISION

The design direction is faithful to the vision and the taxonomy is genuinely good research. But
this milestone runs **autonomously**, and the spec currently contains one pinned test case that
is arithmetically false, a demo-band target the codebase cannot reach, a consolidation trigger
its own numbers make unreachable, a calibration gate its own harness cannot measure, and two QA
scripts that cannot be written against the existing harness. A human executor would catch these
and improvise; an autonomous one will either fail loudly mid-milestone or "fix" them silently
and wrongly. Blocking list:

1. **B1 — The pinned consolidation example is false as written:** ceil(0.67×21) = **15**, not 14.
2. **B2 — Warrior 10–12 is unreachable:** one-level-per-sleep code + ~12–20 total PC melee hits in the demo arc.
3. **B3 — The consolidation trigger (both ≥8, sum ≥18) is unreachable by the 7/7 split build it exists for.**
4. **B4 — The 20–25% win-rate gate cannot be measured:** the harness PC is melee-AI-only and the split build's kit is an advantage k must first cancel.
5. **B5 — "Granted skills kept" contradicts how skills are actually derived** (recomputed from held classes every fight), and cap-consumed/offer state has no save story.
6. **B6 — Three of the four new QA scripts are unimplementable:** the harness has no fixture-save mechanism and no way to reach the required game states.

Every one of these is fixable with spec text and small numbers changes — no architecture pivot
needed. Details, then the de-risk recommendation.

---

## Findings by severity

### B1. ceil(0.67×21) = 15. The pinned test case contradicts its own formula — spec §2.5, plan Global Constraints, taxonomy §4

**Problem.** The vision example is Warrior 9 + Mage 12 → 14. The taxonomy writes "21 × 0.67 →
14.07 → 14, ceil edge checked in tests" — but ceil(14.07) is **15**. The number 14 comes from
**2/3**, not 0.67: 21 × 2⁄3 = 14 exactly, and ceil(14) = 14. The two constants diverge at every
sum divisible by 3 (sum 18: 0.67 → ceil 13, 2/3 → 12; sum 21: 15 vs 14) — i.e. at a third of
all possible triggers, including the pinned one.

**Failure scenario (autonomous).** The executor implements `ceil(0.67 * sum)` per spec, writes
the pinned test asserting 14, watches it fail, and "fixes" it by switching to `floor` or
`round` — silently changing every other consolidation level in the game (floor(10.72)=10 vs
ceil=11 at 8+8), with no user available to notice.

**Fix.** Define the formula in integer arithmetic: `merged = ceili(2 * (La + Lb) / 3.0)` or
equivalently `(2 * sum + 2) / 3` integer-divided. Never write 0.67 anywhere. Re-derive the
secondary pins: 8+8 → 11, 10+8 → 12, 12+12 → 16, 9+12 → 14. Also add the clamp
`merged = max(merged, max(La, Lb))`: the formula first drops below the higher parent at
20+8 → 19 — outside the demo band, but the sim shouldn't have a silent regression waiting in
M7+ (canon supports merged < *sum*, which is always true here; below *max* is your design
call — make it explicitly, one line).

### B2. The demo band (Warrior 10–12) is unreachable — spec §2.2 vs `progression.gd:51` and the combat data

Two independent walls, either of which alone blocks it:

**Wall 1 — one level per sleep.** `check_level_ups` evaluates exactly `held + 1`
(`progression.gd:51`); `sleep()` applies the result once. Warrior 1 → 12 requires **11
sleeps**. The demo arc has perhaps 2–4 natural sleep beats; a player *could* trudge to the bed
11 times, but that is the opposite of an identity-system showcase. The spec's own
"announcements batched exactly as today" (§2.2) entrenches this ceiling. Canon explicitly
supports gaining multiple levels in one sleep — the spec must say `check_level_ups` loops until
fixpoint (and the toast batches multi-level gains), or the band is fiction.

**Wall 2 — counter volume.** From the combat data: PC damage per landed hit = str/2 + d6 =
9.5 avg (`wi_combat.gd:422-423`); enemy pools are 26–33 HP; Relc (str 14, avg 10.5) takes
roughly half of every fight's kills. A two-enemy fight yields the PC ~3 landed hits; the
chieftain fight ~5. The full demo arc (3–4 one-shot fights — every encounter is
`remove_entity`-on-victory, nothing repeats) produces **~12–20 `melee_hit` events total**, plus
~3–8 `sword_skill_used` (Power Strike is AP-capped at ~1–2 uses/fight). Ten-plus levels on
~15 events means ~1.5 hits per level, flat — there is no room for the vision's "leveling slows
with level; early levels fast" curve, and evolution min-uses thresholds become single-digit
coin flips.

**Failure scenario.** T2's own test ("errand-arc counter volume reaches Warrior ≥10") gets
written against a hand-fed accomplishments dict and passes, while the actual game caps at
~W4–6. The milestone whose goal is "progression is determined by what you DO" ships with its
evolution and consolidation mechanics **never firing in real play** — verified only by
fixtures, invisible to the demo player. Under autonomous execution nobody notices until the
post-milestone human playtest, the one gate the user can't attend.

**Fix (all three, they compose).** (a) Multi-level sleeps (Wall 1). (b) Add **one repeatable
encounter** to the world data — a respawning street/cave patrol (canon-safe framing: real
enemies, genuine challenge) — this is a data-only addition, ~20 lines of JSON, and it also
gives `class_evolution_loop` a real path (see B6) and gives the liveness rule a reason to exist
(see I9). (c) Re-state the band honestly against the tuned volumes — if the answer after (a)+(b)
is W8–10/M6–8, change §2.2, §2.5's trigger, and the evolution cap story together, not
piecemeal.

### B3. The consolidation trigger is unreachable by the archetype it exists for — spec §2.5 vs §2.2

**Problem.** §2.2's own pacing targets: focused ≈ W10–12 *or* M8–10; split ≈ **7/7**. The
trigger is both ≥8, sum ≥18. The split build — the only archetype consolidation is *for*, per
the vision's locked decision 3 ("consolidation later effectively refunds the penalty — the
payoff arc") — maxes at 7/7 = sum 14. **Never triggers.** The focused build triggers only if
its off-class also reaches 8, which under B2's counter starvation is fantasy. Net: the ONE
player-facing choice in the whole system (user-locked) is dead content in the demo;
`consolidation_flow` QA will exercise it via fixture and green-wash it.

**Fix.** Lower the trigger to match the band you actually ship: both ≥6, sum ≥13 (7/7 → sum 14
triggers; merged = ceil(2×14/3) = 10 — a pure-10 equivalent, which *is* the penalty refund,
working exactly as the vision promises). Keep 9+12→14 as a pure math pin. If B2's fix moves the
band up, move this with it — the invariant to preserve is **"the split archetype the demo can
actually produce must qualify at least once before the demo ends."** Write that sentence into
§2.5; it's the testable form.

### B4. The 20–25% split-friction gate cannot be measured by the harness as it stands — spec §2.4, plan T4/F1

Three compounding problems, in order of severity:

**(a) The instrument can't play the build.** The batch harness PC runs `ai = "melee"`
(`sim_combat_batch.gd:48`), and the melee profile never casts — this is a *documented* gotcha
(v4 CLAUDE.md: "combat_autoplay will NEVER cast a spell for the player character"; M3's own
balance caveat: the mage build's +0.26 win rate was "entirely Mana Shield passive"). A
"pure-Mage-10" or "5/5 actually casting" cell is unmeasurable. The vision doc explicitly
anticipated this: "batch matrix over **playstyle-scripted AI profiles**" — the spec and plan
dropped the profiles. That is a spec-vs-vision contradiction, not just a gap.

**(b) k must first cancel a kit *advantage*.** The split build holds BOTH class kits — including
mana_shield and quick_cast, passives worth +0.26 win rate in M3's measurements. Win-rate-wise,
5/5 starts *ahead* of pure-10-warrior before stats enter. Since class levels currently grant
**skills only** (`_build_player_combatant` injects `granted_skills`, nothing else —
`wi_game.gd:366-369`), the stat channel k tunes **does not exist yet**, and to open a 20–25%
win-rate gap it must first overpower the kit advantage — pushing k (or the per-level stat gain)
to values that will distort the four existing 0.55–0.95 cells §3 promises to preserve.

**(c) The math k *can* do, it does trivially — on the wrong metric.** On a power scalar
P = Σ Lᵢᵏ, the split ratio is closed-form: r(k) = 2·5ᵏ/10ᵏ = 2¹⁻ᵏ, so the 20–25% band is
exactly k ∈ [1.32, 1.42] — no tuning loop needed, k≈1.35 was already right. The hard, maybe
impossible, part is only the *win-rate* restatement the spec chose.

**Also: the formula itself is ambiguous.** "per-class weight w(L)=L^k normalized across held
classes" has at least two readings — power = Σ Lᵢᵏ (my math above), or per-class stat
contributions scaled by normalized weights wᵢ = Lᵢᵏ/ΣLⱼᵏ (under which a 5/5 split gets *50%*
of each class's contribution — nowhere near the 20–25% band). An executor will pick one. And
nothing anywhere defines **what a class level grants stat-wise** (str? int? both? how much per
level?) — the entire level→stat mapping is unspecified, in a codebase where damage = stat/2 +
die, HP = 20 + con, and hit chance doesn't read attacker stats at all (`wi_combat.gd:417`).

**Fix.** Spec must state: (1) the exact equation (recommend P_i per class with effective
levels ℓᵢ = Lᵢ · (Lᵢᵏ / Σ Lⱼᵏ), or the closed-form Σ Lᵢᵏ — pick ONE and write it); (2) the
stat mapping (e.g. +1 str per effective warrior level, +1 int per effective mage level, +0.5
con per any effective level — numbers for F1 to tune); (3) **the gate metric**: primary gate on
the effective-power ratio (closed-form, deterministic), with win rate demoted to a sanity band
(split within [pure − 0.35, pure − 0.05] in the calibration cells); (4) a **caster AI profile
for the PC** added to the harness so split/mage cells actually cast — without it every mage
cell in the new matrix axis is fiction. Name the calibration arena; "the calibration arena"
(§2.4) currently refers to nothing.

### B5. "Granted skills kept" contradicts the skill-derivation architecture; evolution state has no save story — spec §2.3/§2.5, plan T3/T5

**Problem 1 — skill folding.** Combat kits are **recomputed from held classes every fight**:
`_build_player_combatant` calls `granted_skills(classes, catalog)` (`wi_game.gd:368`), which
walks the level tables of classes you currently hold. Evolution *replaces* the class id;
consolidation *removes* both parents. The moment `warrior` becomes `swordsman`, every skill
granted by warrior's table vanishes from the next fight's kit — unless the executor invents a
mechanism the spec never names. Two clean options: (a) evolved/merged classes carry an
`"inherits": ["warrior"]` field that `granted_skills` follows (small, data-driven — recommend);
(b) evolved class level tables duplicate parent grant rows (pure data, but T6 must author 10
levels × N classes of duplication and keep them in sync). The spec says "granted skills kept,"
the plan tests "keep skills" — neither says HOW, and the two options have different owners
(SIM vs CONTENT).

**Problem 2 — leveling the merged/evolved class.** §2.2 says "[Warrior] levels from
melee_hit+won_combat **weighted sums**"; §2.5 says [Spellsword] "counters from EITHER parent
line level it." The existing `requires` semantics are per-counter AND thresholds
(`progression.gd:56-59`) — there is no weighted-sum and no OR. This is a silent schema + sim
extension that plan T2 never mentions; T2's executor will discover mid-task that the data
format in classes.json can't express the spec.

**Problem 3 — persistence.** Save state must now carry: 10-cap-consumed flags (else a
balanced Mage save/loads and re-rolls into Ice Mage), the consolidation offer/declined state
(T5 mentions this one), and the evolved-class identity survives via `classes` (fine). WISave
uses **strict version equality** (`save.gd:26`) and a strict required-key list — every schema
addition invalidates all saves. T3 and T5 each add fields; T9 bumps the version for the rename.
Uncoordinated, that's two or three version bumps in one milestone with fixtures pinned to the
wrong ones. **Fix:** one coordinated bump (VERSION 1 → 2) covering ALL M6 additions + the
fighter→warrior mapping in a single migration function; T3/T5 write to the new schema behind
that migration; the T7 fixture is authored in v1 format once and never regenerated.

### B6. Three of the four new QA scripts cannot be written against the existing harness — spec §3, plan T7

**Problem.** `class_evolution_loop` ("fight sword-tagged fights to 10") needs ~10 levels of
counters: the demo has 3–4 **one-shot** encounters (removed on victory) and TestDriver has no
step that writes state (`assert_state` reads; there is no grant/set step). `consolidation_flow`
needs both classes ≥8 — even further out of reach. The migration script must "load a committed
v1-format fixture save" — but TestDriver can only load `user://saves/{auto,manual}.json` via
the pause menu, and **nothing copies a committed fixture into `user://saves/`**: not
`run_qa.sh` (read it — it only wires output dirs), not TestDriver. As written, T7 is
unimplementable; an autonomous executor will bolt an ad-hoc mechanism onto the harness without
design review — on the milestone where the harness is the design authority.

**Fix.** Spec the affordance once, properly: a `"fixture_save": "res://qa/fixtures/<name>.json"`
key in the QA script header that TestDriver copies into `user://saves/manual.json` (or a
dedicated slot) before the run, + a leading load step. Commit fixtures for: near-evolution
counters, near-consolidation dual-class, v1-format migration. This is ~20 lines in
test_driver.gd and makes all three scripts trivial. (The repeatable encounter from B2's fix
lets `class_evolution_loop` also exercise the *real* counter path for the last level or two —
both fixture-start AND organic-finish, which is the assertion that actually matters.)

---

### I7. Sleep-beat ordering: evolutions-before-level-ups delays every evolution by one sleep; consolidation precedence undefined — plan T3, spec §2.3/§2.5

Plan T3 specifies "gains → evolutions → level-ups." Trace it: Warrior 9 with the level-10
counters banked → this sleep, the evolution check sees level 9 (no-op), THEN the level-up makes
10. Evolution fires **next** sleep at the earliest — every evolution lands one sleep late,
and with sleeps scarce (B2) possibly never before the demo ends. Worse, the off-interval
"substandard" flavor (§2.3) keys on evolving past 10 — under this ordering the *normal* path
brushes against it. **Fix: gains → level-ups → evolutions → consolidation offer.**

Separately: if Warrior 10 (sword-dominant) and the consolidation predicate are BOTH true at one
sleep, which fires? If evolution consumes `warrior` first, do (Swordsman, Mage) still qualify
as Spellsword parents? Canon defines the merge as Warrior+Mage. The spec is silent, and under
its own demo band (W10+/M8+) this collision is the *common* case, not an edge. Decide:
consolidation offer takes precedence at the same sleep (recommend — it's the user-locked choice
beat and evolution is automatic), and state whether evolved classes remain valid parents
(recommend yes, same target).

### I8. Mage cap-consumption is asymmetric and coarse; the at-cap-no-evolution state is silent — spec §2.3

A Mage at 10 with dominance <60% is immediately routed to the generalist path, **cap consumed,
Ice/Fire Mage locked out forever** — while a Warrior in the same position "waits" and may
evolve later. Nothing in the vision or taxonomy justifies the asymmetry. At demo counter
volumes (12–20 casts, B2) the 60% share is decided by ±1 cast: a 7/13-ice player (54%) is
"balanced" and permanently locked out, invisibly, under a locked no-feedback rule. **Fix:**
make Mage wait like Warrior unless BOTH balanced (share <60%) AND a minimum total-cast volume
is met (so "balanced" is a demonstrated identity, not noise); grant the generalist bonus at
the first sleep where that holds. And give the at-cap-no-evolution sleep ONE qualitative toast
("Your focus wavers between frost and flame." — state description, not progress-toward, so it
doesn't violate opacity). Otherwise the player hits the milestone's flagship moment — level
10 — and sees nothing, and assumes the game is broken. That toast is also what makes target-4's
"can the player understand why they didn't evolve" answerable at all.

### I9. The liveness rule solves a non-problem and creates a real one — spec §2.1 vs taxonomy §1

Every demo encounter is one-shot (removed on victory) — **farming is impossible in the shipped
content**, so the rule protects nothing today. Meanwhile its concrete form ("enemy damage > 0
OR ≥3 rounds") both *under*-blocks (deliberately stall 3 rounds vs a trivial enemy → bank) and
*over*-blocks (a skilled 2-round flawless win of a REAL fight banks **nothing, silently** —
punishing exactly the play the system should reward; the taxonomy's own phrasing was "enemies
COULD deal damage," i.e. capability, which the spec quietly narrowed to "dealt"). If B2's
repeatable encounter lands, the rule becomes necessary — implement it as a **data flag**
(`"trivial": true` on the encounter/arena, no bank) or an encounter-power-vs-player-level
check, not a behavioral heuristic. Delete the 3-round clause entirely; it's the gameable half.

### I10. Plan ownership contradicts its own task file lists — plan Lanes vs T2/T6

The ownership table: "CONTENT owns `data/classes.json` + `data/skills.json` (SIM may add tag
READING, never data)." T2 — a SIM-lane task — lists `data/classes.json` (thresholds) in its
files, while T6 (CONTENT) authors the class tree in the same file **in parallel from T1**. Two
lanes, one file, concurrent — the exact contention class M5's lane table was revised to
prevent, and this time there's no user to adjudicate the merge. **Fix:** T2 defines the
threshold *schema* and reads it; CONTENT authors all classes.json values, sequenced: T6a
(tree skeleton + thresholds, blocks T2 verification) → T6b (kits, parallel). Or T2 lands
before T6 dispatches, same as the T1 disclosure. Either way, write it down.

### I11. Warrior dominance is vacuous in the demo — Spearmaster is unreachable — spec §2.3/§1, taxonomy §3/§5

No spear-tagged skill is obtainable: the Warrior band kit (taxonomy §5) is sword/neutral, spear
skills exist only inside the [Spearmaster] post-evolution kit, and there is no gear system.
Sword share is therefore 100% for every player, always — the ≥60% dominance predicate for
warriors is dead code, the sword/spear "behavioral choice" the vision showcases does not exist,
and [Spearmaster] ships as unreachable content. Acceptable (Relc flavor, data-complete for
M7+) — but the spec must SAY it's unreachable-by-design, or an autonomous QA author will burn
a day scripting an impossible `spearmaster` path. If you want the choice to be real, base
Warrior needs one spear-tagged skill in its kit (taxonomy note: Relc's page has the canon
names) — one data row.

### I12. T9 migration — what the sweep must explicitly hit (plan lists categories; these are the instances that bite)

The plan's category list (data ids, save mapping, QA scripts, dialogue, tests) is right; for a
judgment-free executor, name the specifics:

- `data/skeleton_scene.json:8` — the PC's **starting** `classes: {"fighter": 1}` (new games,
  not just saves; miss it and every new game holds a class id that no longer exists in
  classes.json — likely a boot crash or silent skill loss).
- `data/dialogue/goblin_parley.json:6` — `requires {class: {fighter: 1}}` AND the player-visible
  option copy "(Fighter)".
- `qa/scripts/level_up_loop.json:36` (`assert_state classes.fighter`) and
  `qa/scripts/dialogue_walkthrough.json:78` (`class_level_up {class: fighter}` payload).
- `tests/sim_combat_batch.gd:18-19` — the BUILDS constants (the balance harness itself).
- `tests/test_sim_core.gd`, `test_save.gd:39`, `test_progression.gd` (throughout),
  `test_dialogue.gd` (including the rendered copy assertion "requires Fighter 2" — the string
  is generated from the names map, so it updates when display_name does, but the test's
  *expected* literal must be edited by hand).
- **Defeat-reload of a stale autosave:** post-migration, a v1 `auto.json` must load through the
  migration path — if `apply` rejects it, `_close_banner`'s fallback is `Game.reset()`
  (`combat_screen.gd`), i.e. defeat after updating wipes the run. The migration test must cover
  the *defeat-reload* route, not just pause-menu load.
- Docs: v4 CLAUDE.md's seed-table notes and `sim_combat_batch.gd`'s header comment say
  "Fighter-2" — stale docs are how the next session re-introduces the old id.

One structural note: T9 "runs ALONE" is right, but it depends on T7's v1-format fixture being
committed **before** T9 changes the format — the plan implies this by lane order; make it an
explicit dependency arrow, since autonomous schedulers only respect what's written.

### M13. Minor

- §2.2's band notation "~Warrior 10–12 / Mage 8–10 focused" is ambiguous between "either,
  depending on focus" and "both at once." B3's analysis shows the reading changes whether
  consolidation is reachable. Write "warrior-focused reaches W10–12 (M ≤3); mage-focused
  M8–10 (W ≤4); split ~7/7" — whatever the real intent is.
- Sim currently emits toast copy directly (`wi_game.gd:421,435`) — plan says UI lane owns
  toasts. The SIM-lane executor will pattern-match the existing code and put evolution toast
  strings in `wi_game.gd`, colliding with T8. Decide: sim emits typed events only
  (`class_evolved {from,to,level,off_interval}`), UI renders copy — one line in T3's brief.
- [D]3's "BOTH element ladders' tier-1" vs canon spell Tiers (Ice Shard is spell-Tier 2 but
  ladder-tier 1) — the word "tier" is doing two jobs; rename one ("ladder step 1") before an
  executor grants the wrong skills.
- Aspiration stubs: safe as data (`check_class_gains` skips entries without
  `gained_by.accomplishment` — verified), but say stubs must NOT carry `gained_by`, or someone
  authors one and [Cryomancer] becomes gainable at level 1.

---

## The single highest-risk assumption

**"The balance harness settles every number"** (plan, Tech stack; spec §2.4/§4). It's the
load-bearing claim of the whole autonomous setup — and for this milestone the harness *cannot
currently measure the central number*: its PC never casts (melee AI), so every mage/split cell
in the new matrix is a fiction of Mana Shield passives; the split build's kit advantage means
the k-dial must cancel an effect the gate metric conflates with the one it's tuning; and the
win-rate restatement of "20–25% weaker" may have **no solution in k at all**.

**Cheap de-risk (half a day, before T4 is dispatched):** add a `caster` AI profile for the PC
to `WICombatAI` (cast-when-affordable-else-melee is enough), hand-wire the stat mapping from
B4's fix with placeholder numbers, and run the pure-10 / 5-5 grid at k ∈ {1.0, 1.35, 1.7}. If
the win-rate gap moves monotonically with k and can pass through the band, the spec's gate
stands. If not (my prediction), switch the primary gate to the closed-form effective-power
ratio (k = 1 − log₂(target) — deterministic, no tuning loop) with win rate as a sanity band.
Either way you've spent hours, not the milestone, and F1 stops being a prayer.

## What autonomous execution still needs that neither document provides

1. **The fixture-save harness affordance** (B6) — specced, not improvised.
2. **The exact effective-power equation + level→stat mapping** (B4) — currently two ambiguous
   readings and zero stat model.
3. **The sleep-beat pipeline order** as a single normative list: class gains → level-ups
   (looped to fixpoint) → evolutions → consolidation offer → autosave (I7; and note the
   existing autosave hook fires on `class_level_up`/`class_gained` — T1's tally banking must
   happen before `combat_resolved` is emitted, or the victory autosave misses the new counters:
   `resolve_combat` currently records accomplishments *then* emits, `wi_game.gd:377-382` —
   keep that order for the tally, say so in T1).
4. **One coordinated save-version bump** covering all M6 schema changes + the rename (B5).
5. **The repeatable-encounter decision** (B2) — it's the keystone that makes counter volumes,
   the liveness rule, and `class_evolution_loop` all coherent; it's data-only, but adding
   content in a systems milestone needs an explicit scope blessing in the spec, or the executor
   will (correctly) refuse to invent it.
6. **A "did the demo player actually see it" gate:** add to F1 a scripted end-to-end run of the
   real demo content (no fixtures) asserting that at least one evolution and one consolidation
   offer fire before the last sleep. That single assertion operationalizes "the identity system
   shipped" — everything else in §3 can pass with the system invisible.

---

*Overall: the design is the right game. The taxonomy is the best document in the repo. But the
spec's numbers were written before anyone multiplied them against the demo's actual content
volume or the code's actual leveling loop, and its calibration promise was written against a
harness that can't hold it. Fix the arithmetic (B1–B3), name the mechanisms (B4–B6), and this
is safely executable by an agent without design judgment — which is the standard this review
was asked to apply.*
