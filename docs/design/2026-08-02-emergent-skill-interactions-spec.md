# Emergent Skill/Object Property Interactions (issue #348)

Status: EXPLORATION SPEC (v0.17 L7 deliverable, user directive 2026-08-02).
VERDICT: **BUILD-REDUCED** — generalize the two shipped property arms into
a closed-vocabulary property layer resolved by ONE authored table;
field-only, no propagation, no combat unification, authored per-entity
arms keep precedence forever. A rule engine is a NO-BUILD (§4.1). The
ToTK fantasy is scoped honestly in §3. Nothing here ships in v0.17; this
feeds the post-v0.17 board. Demo matrix in §7; slices in §9; kill
criteria in §10.

---

## 1. The question

Today props and people answer specific Skills through per-entity authored
arms (`requires_skill`/`on_skill_use`/`skill_uses`). The issue asks for a
PROPERTY system: Skills carry properties (burns, freezes, tames,
cleans...), targets carry material/state properties, and interactions
resolve from the intersection — "surprising-but-coherent", ToTK-style.
The governing constraint is stated in the issue itself: the game is
QA-first — every interaction must be assertable.

## 2. What exists (real generalization vs greenfield)

The property system is not greenfield. TWO full property intersections
already ship, in exactly the proposed shape:

- **burns × burnable** — skill flag `burns` (`kindle`, sole carrier) meets
  entity flag `burnable` in `WIFieldSkills.dispatch`
  (src/core/field_skills.gd:91-102): remove entity + `TERRAIN_CHANGED
  {to: "scorched"}` + counter bank + toast. Permanence proven end-to-end
  in tests/test_traversal_seams.gd:87-104 (prop gone, cell walkable,
  survives sleep, quest-prop safety negative at :106-113).
- **freezes × freezable** — skill flag `freezes` (`frost_touch`, sole
  carrier) meets MAP-side cell class `freezable` (authored per-map,
  read by `WIGame._is_freezable`, wi_game.gd:270-271): walkability flip
  via `frozen_cells` (wi_game.gd:64; is_cell_blocked consults `_is_frozen`
  at :262), until-sleep persistence (sleep() clears at wi_game.gd:2127),
  save round-trip (`frozen_cells_json`, wi_game.gd:278-286; proven
  test_traversal_seams.gd:115-142).

So the *mechanism* — skill-side closed flag, target-side closed flag,
resolution at the intersection inside pure sim, fallthrough to
`field_ambient`/refusal (field_skills.gd:141-149) — is shipped and
QA-proven. What does NOT exist is the generalization: each pair is a
hardcoded dispatch arm, and every further behavior flag is a one-off:

- Skill-side flag census (data/skills.json, 119 skills): `burns` 1,
  `freezes` 1, `animates` 1 (`animate_dead`), `tames` 1 (`lesser_bond`),
  `wards` 2, `blinks` 2, `sneaks` 2, `toggles_light` 1, `door_flavor` 1.
  The vocabulary exists — as scattered booleans, each with its own
  dispatch branch (field_skills.gd:51-61,139-140).
- The authored layer: **43 `requires_skill` + 41 `on_skill_use` +
  3 `skill_uses` arms across data/maps/** (counted 2026-08-02) — the
  issue's "~70 hardcoded arms". These route through `WIGame.use_skill`
  (wi_game.gd:425-527), which owns item gates, once_per_waking, variant
  resolution, gold, yields. This layer is NARRATIVE authored content,
  not boilerplate awaiting migration (§6).
- Adjacent but distinct: combat's terrain/status registry
  (`WICombat.terrain`, icy_floor kind; the expires_after_round idiom at
  src/core/combat/skill_effects.gd:244-247) and the `element` field
  (12 skills) are a SEPARATE, already-generalized combat vocabulary.
  Greenfield items in the issue's list — `wet`, `conduct` — have NO
  substrate on either side and are out of v1 (§3, §10-K3).
- Companion verbs already generalized once: `_animate_field`
  (wi_game.gd:719-753) reads the PROP's `companion_source` block
  (GH#156), so "animate a training dummy" — the issue's own example —
  is purchasable TODAY by adding `companion_source` to the dummy prop,
  zero engine work. Honest accounting: some of the fantasy is already
  in stock as per-prop data.

## 3. The honest ToTK gap (issue question f)

ToTK's emergence comes from continuous physics: free objects with
position/velocity, elemental state that propagates in real time, systems
colliding at 60fps without an author in the loop. This game is a
tile-grid, turn-shaped, action-tick sim (`_tick_action`,
wi_game.gd:2335-2340) with props fixed to cells, items as inventory ids,
and zero physics. What a property system here CANNOT deliver:

- **Spatial improvisation** — no dragging, attaching, stacking, throwing.
- **Chain reactions** — no fire-spreads-to-neighbor-then-updraft; any
  propagation would be an authored turn-based cellular system, expensive
  to build and to QA, delivering a pale imitation.
- **Continuous surprise** — no interactions the authors never wrote.
  Every resolution here is a table row someone typed.

What it CAN deliver — the deliverable core this spec scopes to — is
**universality and consistency of discrete verbs**: every material-tagged
thing in the world answers every property-carrying Skill the same
coherent way. The player beat is "I wonder if [Kindle] works on the
thicket... it DOES" — and it working *everywhere* is what makes the world
feel systemic. That beat is real in ToTK too; it is the part a tile-grid
turn game can honestly own. Propagation is an explicit non-goal (revisit
only with a dedicated spec and its own QA cost census).

## 4. Mechanism (issue questions a/b)

### 4.1 Resolution table, not rule engine — ruled

A rule engine (predicates composing at runtime: "fire beats cold beats
water...") produces resolutions nobody authored — which is precisely
what QA-first forbids: the canonical lattice asserts exact event
streams at pinned seeds, and an unauthored resolution is an unasserted
one. The engine also breaks the tune-data-never-sim discipline: tuning
a rule changes N interactions at a distance. NO-BUILD.

The BUILD is one authored resolution table: `data/interactions.json`,
rows of

```json
{"skill_property": "burns", "target_property": "burnable",
 "outcome": "remove_scorch", "persistence": "permanent",
 "counter": "burned_the_debris", "toast_key": "burn_toast",
 "_comment": "the shipped kindle arm, expressed as data"}
```

- `skill_property` / `target_property` come from CLOSED vocabularies
  (§4.2), registered in `scripts/data_lint.py` (whose own charter is
  exactly this tier: structural, engine-free, closed checks —
  data_lint.py:1-40).
- `outcome` comes from a CLOSED verb set, each verb mapping 1:1 onto a
  SHIPPED sim behavior — no new sim verbs in v1:

| outcome verb | shipped behavior it names | persistence classes allowed |
|---|---|---|
| `remove_scorch` | burn shape: remove_entity + TERRAIN_CHANGED + counter (field_skills.gd:91-102) | `permanent` (removed_entities) |
| `freeze_cell` | frozen_cells walkability flip (field_skills.gd:103-114) | `until_sleep` (wi_game.gd:2127) |
| `thaw_cell` | frozen_cells erase (the inverse; trivial new arm over existing state) | immediate |
| `state_flip` | visual_states/counter flip (the unlit_lantern seam) | `until_sleep` or `permanent` via counter |
| `bank_toast` | counter + toast, the observe shape (field_skills.gd:73-81) | n/a |
| `refuse` | authored refusal with its own toast (distinct from ambient fallthrough) | n/a |

- Absent pair = no row = the SHIPPED fallthrough: `field_ambient` toast
  or the "Nothing here calls for that." refusal (field_skills.gd:141-149).
  Null is a first-class, already-shipped answer.

### 4.2 Vocabularies stay where they already live

- **Skill side:** keep the shipped boolean flags AS-IS (`burns`,
  `freezes`, ... — frozen semantics, zero churn); the vocabulary is the
  data_lint-REGISTERED flag list. A new property = a new registered
  flag. No `properties: []` array migration — additive only.
- **Target side:** two shipped placements, both kept: entity boolean
  flags (`burnable` precedent) and map-authored cell classes
  (`freezable` precedent, per-map dicts). New target properties are new
  registered flags (`dirty`, `warded`, `unlit`, `hearth`, `growth`, ...).
- data_lint gains: (1) unregistered property key on any skill/entity =
  FAIL; (2) table rows referencing unregistered vocabulary = FAIL;
  (3) TOTALITY REPORT: the full cross-product of shipped skill-properties
  × shipped target-properties, each cell classified row/null — the
  census that keeps the tripwire surface finite (§5).

### 4.3 Where resolution runs

Inside `WIFieldSkills.dispatch`, replacing the hardcoded burnable/freezes
arms with one table-lookup arm AT THE SAME POSITION in the dispatch
order. Precedence, ruled (this IS the current order, made contract):

1. `sneaks` / `blinks` / `wards` / `animates|tames` special verbs
   (field_skills.gd:51-61 — mobility/companion verbs are not material
   interactions; they stay dedicated arms).
2. AUTHORED per-entity arms — `requires_skill` match, then `skill_uses`
   map (field_skills.gd:62-72) → `WIGame.use_skill`. **Authored always
   beats generic.**
3. Named generic arms: `observe`, `charming_smile`
   (field_skills.gd:73-90).
4. **THE PROPERTY TABLE** (today: the burnable arm :91-102, the freezes
   arm :103-114).
5. `door_flavor` (:121-128), `toggles_light` (:139-140).
6. `field_ambient` → refusal (:141-149).

Byte-identity contract: with a table containing exactly the two shipped
rows and no new tags in data, every canonical's event stream is
byte-identical (slice-1 gate, §9).

### 4.4 Sim purity + determinism (issue question b)

Resolution is a pure Dictionary lookup over injected data — no RNG, no
Node refs, event-emitting through the existing sink (`WIFieldSkills` is
already the pure extracted seam, field_skills.gd:1-33). State outcomes
reuse ONLY the two shipped persistence stores: `frozen_cells`
(until-sleep, save-serialized) and `removed_entities` (permanent,
save-serialized). **v1 adds no new save state → no `WISave.VERSION`
bump** (stays 8, src/core/save.gd:4). Any property that demands new
state (wet, charge, temperature) is out of v1 by construction and gates
on a version-bump decision (K3).

## 5. The QA cost census (issue question b)

The combinatorics fear — N properties × M objects → unbounded QA — is
answered by making the TABLE the QA surface, not the cross-product:

- The tripwire surface = table rows + the totality census. With ~8 skill
  properties × ~15 target properties, the census is ≤ 120 cells, of
  which ~25-35 are rows and the rest are null (the shipped fallthrough,
  itself already covered by canonicals asserting ambient/refusal).
- Per-ROW discipline (test_content arms, mirroring its counter
  cross-ref philosophy): every row must (a) reference registered
  vocabulary, (b) name at least one shipped carrier (a map entity/cell
  actually tagged with the target property) — a carrier-less row is
  dead data, FAIL; (c) every row's counter has the standard
  producer/consumer treatment.
- Per-row CANONICAL discipline: each outcome verb is proven once per
  verb by a dedicated canonical (the test_traversal_seams +
  sewers_walkthrough model), and each ROW is exercised by at least one
  canonical step or fixture assert — surfaces tagging via
  `scripts/derive_qa_surfaces.py` keeps `--touching` re-gates honest.
  Cost is O(rows), authored once per row, NOT O(skills × objects).
- The sim is seed-stable: property resolution adds zero RNG draws, so
  every pinned combat seed and fixture `rng_state` survives untouched
  (the #88-era re-derivation saga is the cautionary precedent this
  design avoids by construction).

## 6. Migration of the ~70 authored arms — DON'T (issue question)

The 43+41+3 authored arms are the narrative layer: they bank specific
counters, hand over items, speak authored lines, gate on carried items
and once_per_waking — machinery the generic table deliberately lacks
(it has no item yields, no gold, no waking caps; that is `use_skill`'s
job, wi_game.gd:447-527). Ruling: **zero migration, ever.** The table is
the substrate UNDER the authored layer (precedence §4.3); authored arms
win on their entities; the table catches everything else. This also
answers the blast-radius question: migration churn on test_content and
the canonical lattice is zero because nothing shipped moves. New tags on
existing entities are additive keys — the repo's established
byte-identical discipline (interactions.gd's additive-key comments are
the precedent trail).

## 7. Demo interaction matrix (~10 shipped skills × ~15 target properties)

Legend: **S** = ships today (authored arm or generic arm — cited),
**G** = generalizes via a v1 table row, **R** = authored refusal row
(distinct toast — refusals are content), **·** = null → ambient/refusal
fallthrough. Skills are all shipped ids (data/skills.json). Target
properties marked * are proposed new registered flags; unmarked ones
exist today (as flags, kinds, or map cell classes).

| skill \ target | burnable | freezable water | frozen ice | dirty* | warded* | unlit* | bone | beast | person (npc) | door | container | hearth* | growth* | dark cell* | (no target) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kindle (burns) | **S** f_s:91 | **R** ("water drinks the flame") | **G** thaw_cell ★ | · | · | **G** state_flip (light it) | · | · | **R** | · | · | **G** state_flip ★ | **G** remove_scorch ★ | · | S ambient |
| frost_touch (freezes) | · | **S** f_s:103 | **R** (already ice) | · | · | · | · | · | **R** ("No. They are a person.") ★ | · | · | **G** state_flip (douse) ★ | · | · | S ambient |
| basic_cleaning (cleans*) | · | · | · | **S** authored arms; **G** for untagged grime | **R** ("this filth is not natural") ★ | · | · | · | · | · | · | · | · | · | S ambient |
| observe (appraises) | **S** generic arm f_s:73 | · | · | S | S | S | S | S | S | S | S | S | S | · | S ambient |
| detect_magic (detects) | · | · | **G** bank_toast ★ | · | **S** authored arms (class-expansion §6) | · | **G** bank_toast | · | · | **G** bank_toast (warded doors) | · | · | · | · | S ambient |
| light (toggles_light) | · | · | · | · | · | **S** per-prop arms; **G** for untagged | · | · | · | · | · | · | · | **G** state_flip ★ | S toggle f_s:139 |
| animate_dead (animates) | · | · | · | · | · | · | **S** companion_source wi_g:719 | · | · | · | · | · | · | · | S refusal |
| lesser_bond (tames) | · | · | · | · | · | · | · | **S** companion_source | **R** (the crab-refusal joke precedent) | · | · | · | · | · | S refusal |
| charming_smile (calms*) | · | · | · | · | · | · | · | **G** bank_toast (soothe line) ★ | **S** generic arm f_s:82 | · | · | · | · | · | S ambient |
| hedge_remedy (brews) | · | · | · | · | · | · | · | **R** ("a draught wants a cauldron") | · | · | · | · | **G** bank_toast (gather) ★ | · | S ambient |

(f_s = field_skills.gd; wi_g = wi_game.gd.) ★ = the "surprise" cells —
each is coherent from the two vocabularies alone, which is the authored-
feeling test: a player who knows [Kindle] burns brush can PREDICT it
thaws ice and lights hearths, and the prediction pays off. Count check:
~24 authored cells (S+G+R) against ~126 nulls — the surface stays small,
and every null is a shipped-fallthrough behavior, not a bug.

Three-pillars gate (issue question c): of the G/R cells above, fewer
than a quarter are combat-adjacent; cleaning/appraising/calming/
brewing/light are social+puzzle pillar verbs. The matrix must keep a
non-combat majority at every slice — this is the [Skills]-usable-
outside-combat north star applied as an acceptance rule.

Explicit-Skill-use doctrine (issue question d): unchanged and load-
bearing. The hotbar is the tool choice; `interact()` NEVER consults the
property table (interact's known-skill hint behavior stays exactly
interactions.gd:156-166). Property resolution fires only from
`use_skill_field` (wi_game.gd:568-577) — a deliberate cast at a faced
cell. No auto-casting, no "smart interact".

## 8. Content cost per property added (issue question e)

One new property costs, invariably: 1 registered flag (data_lint) +
1-3 table rows + at least one map carrier tag per row + one canonical
extension (or a new script if a new outcome verb ships with it) +
`WIEffectText`-consistent toast copy + surfaces regeneration
(`derive_qa_surfaces.py`) + windowed machine-playtest of the new
player-visible resolutions. Estimate: SMALL per property riding existing
outcome verbs; MEDIUM when it introduces an outcome verb (each verb is
a sim arm + a proof canonical, amortized across all its rows). Budget
rule: a property that cannot name three interesting rows at proposal
time is not worth its flag (see K2).

## 9. Costed slices

### Slice 1 — substrate + byte-identity proof (SMALL-MEDIUM; one src lane)
Dispatch-grade: executable from this doc alone.
1. `data/interactions.json` with EXACTLY the two shipped rows
   (burns×burnable→remove_scorch, freezes×freezable→freeze_cell),
   loaded through the existing injected-config path.
2. `WIFieldSkills.dispatch`: replace the two hardcoded arms
   (field_skills.gd:91-114) with the table-lookup arm at the same
   dispatch position (§4.3), same emitted stream.
3. `scripts/data_lint.py`: vocabulary registration + row shape +
   carrier cross-ref + totality report tiers (§4.2, §5).
4. `test_content` arms per §5; `test_traversal_seams` untouched and
   green — it is the byte-identity referee.
5. GATES: headless smoke zero-warnings; test_traversal_seams;
   test_content; data_lint; `qa/ci_sweep.sh --tier smoke` plus
   `--touching` the edited files; the traversal canonicals
   (sewers_walkthrough + the blink/ward loops) byte-identical. ANY
   stream drift = stop (K1).

### Slice 2 — first generalization wave (MEDIUM; data lane + QA lane)
Three properties over existing content, zero new outcome verbs:
- `thaw_cell`: kindle × frozen ice (the cheapest star cell — one new
  trivial arm over frozen_cells, its own canonical leg extending the
  freeze canonical).
- `dirty` tag pass: table row for basic_cleaning × dirty on UNTAGGED
  grime props (authored dirty_table arms keep winning by precedence —
  regression-proof by construction).
- `hearth` + `unlit` tags: kindle-lights / frost-douses / light-lights
  state flips on brazier/hearth/lantern props.
Plus the R-cells' refusal copy (frost×person, kindle×water) — cheap,
high-charm, and they teach the vocabulary. Canonical extensions +
windowed playtest per wi-machine-playtest.

### Slice 3 — discovery content (MEDIUM; content lanes; AFTER #335 items 1-2)
One or two genuinely new verbs with puzzle content (detect_magic
bank_toast rows; charming_smile × beast; growth/gather rows), placed
where multi-solution routes already live (the quest-3-paths DNA).
DEPENDENCY, ruled: discoverability content waits for the #335 feedback
layer's universal action tell + interactable affordance — an emergent
resolution nobody notices is wasted content. Fence (issue question g):
this spec builds ZERO presentation; every table resolution emits only
existing event types (SKILL_USED, TERRAIN_CHANGED, ENTITY_REMOVED,
TOAST, ACCOMPLISHMENT_RECORDED), so #335's tell covers property
resolutions for free the day it lands. Anything presentation-shaped
found missing during implementation is a seam FOR #335, never scope
here.

## 10. Kill criteria

- **K1 (byte-identity):** slice 1 cannot reproduce the shipped streams
  exactly → stop; the generalization is changing semantics, and the
  authored-arms status quo is fine.
- **K2 (abstraction failure):** >20% of table rows end up referencing
  specific entity ids, or a property ships with fewer than three
  interesting rows → the vocabulary is wrong; freeze the table at
  current size and return to authored arms for new content.
- **K3 (state creep):** a property needs new save state, real-time
  propagation, or combat-side semantics → out of scope; dedicated spec
  or decline. Combat unification in particular is NEVER a lane rider —
  the combat vocabulary (element/terrain/status) has its own balance
  authority and its own registry, and gluing the two multiplies the
  harness surface for no proven player value.
- **K4 (lint allowlist):** the totality/carrier arms need an allowlist
  to pass → the closed set is not closed; fix the vocabulary, never
  waive (the VACUOUS_GATE_ALLOWLIST empty-by-design precedent,
  data_lint.py:51-53).
- **K5 (discovery failure):** after #335 lands and slice 2 ships, friend
  playtests never find a star cell unprompted → the discovery fantasy
  is not landing in this presentation; keep the substrate (it costs
  nothing at rest), stop content investment at slice 2.

## 11. Verdict, argued

BUILD-REDUCED. The full ToTK fantasy is not deliverable on a tile-grid
turn sim and this spec declines to pretend otherwise (§3). But the
reduced core — one closed table generalizing two already-shipped,
already-QA-proven property intersections, under the authored layer,
behind the explicit-cast doctrine — is cheap, provably inert at slice 1,
and buys the exact thing the three-pillars mandate keeps asking for:
[Skills] that act on the WORLD, consistently, outside combat. The
no-build alternative leaves every future material interaction a bespoke
dispatch arm in field_skills.gd — the file's own history (burnable, then
freezes, then toggles_light, then door_flavor, each a hand-placed branch
with placement-is-load-bearing comments) is the accumulating cost curve
this table flattens.
