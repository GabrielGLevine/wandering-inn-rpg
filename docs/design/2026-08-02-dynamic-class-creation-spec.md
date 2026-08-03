# Dynamic Class Creation — bestowed unique classes (issue #347)

Status: EXPLORATION SPEC (v0.17 L7 deliverable, user directive 2026-08-02).
VERDICT: **BUILD-REDUCED** — authored class records selected by derived
portfolio predicates ("authored uniques, derived triggers"). Generative
class assembly is a NO-BUILD, argued in §2. Nothing here ships in v0.17;
this feeds the post-v0.17 board. Slices in §8; kill criteria in §9.

INTERNAL-LORE NOTE: this doc discusses deep-volume System lore the way
`docs/design/spoiler-cutoff.md` itself does (internal planning precedent).
Player-facing rules are in §5 — the System's name never reaches the player.

---

## 1. The question

The [Grand Design of Isthekenous] — canon's leveling intelligence — is
famous for bestowing UNIQUE classes that fit what a person actually DID,
not what a table offered. The issue asks whether this game can deliver
that: a class the player feels was invented for them. The tension: the
game is deterministic, tune-data-never-sim, QA-first — every feature must
be agent-verifiable, every combat number harness-gated, every shipped id
frozen forever. "A class that did not exist at authoring time" appears to
contradict all four disciplines at once.

The resolution this spec argues: **"unique" is a player-experience
property, not a data-generation property.** Canon supports this exactly —
the Grand Design is an ACCOUNTANT, not a poet: it tallies deeds and
recognizes when a tallied life matches a class-shape. The game's
accomplishment-counter machinery is already a faithful miniature of that.
What the player must feel is *"the System saw ME"*; what the mechanism
must do is *recognize a rare portfolio shape*. Recognition is cheap,
deterministic, and authorable. Invention is none of those.

## 2. Mechanism adjudication (issue question a)

Three candidates were named. Rulings:

### 2.1 Generative (name grammar + skill-pool draft) — NO-BUILD

Rejected on four independent grounds, any one of which is fatal:

1. **Frozen-id discipline.** A class id reachable in a shipped save is
   permanent API (`data/shipped_ids.json`, `_comment`: generated at each
   release, currently freezing 35 classes / 119 skills / 529
   accomplishment ids at release 0.16.2; enforced by
   `tests/test_shipped_ids.gd` + `WISave.DEPRECATED_IDS`,
   `src/core/save.gd:7`). A generated id has no catalog record:
   `WIProgression.granted_skills` iterates `class_catalog.get("classes")`
   (src/core/progression.gd:102-118), `check_level_ups` reads the
   record's `levels` table (progression.gd:158-172), display names come
   from the record. A class absent from the catalog grants nothing,
   levels nowhere, and renders as its raw id. The only fix is
   serializing class DEFINITIONS into saves — a new save-format surface,
   a permanent migration burden, and a class the freeze validator cannot
   see. That is the hard line; see kill criterion K5.
2. **Balance authority.** `tests/sim_combat_batch.gd` is "Balance
   authority: gated cells enforce bands" (sim_combat_batch.gd:2) — cells
   are authored, finite, seeded. A runtime-assembled kit cannot be a
   cell. A combat-relevant class with no gated cell violates the
   project's own definition of tuned.
3. **QA-first.** The verification lattice is example-based: canonical
   scripts, pinned fixtures, exact-event assertions. A combinatorial
   generator is only property-testable, and nothing in the lattice does
   property testing. "Every interaction must be assertable" (repo-wide).
4. **It undercuts the fantasy.** Name-grammar output ([Blade Cook of the
   Sewer]) reads as procedural the moment a player sees two of them.
   Canon's unique classes read as AUTHORED — because in-story they are:
   the Grand Design fits a class from precedent and meaning, not from a
   random draw. Curated copy beats grammar copy at the exact thing this
   feature is for.

### 2.2 Pure derivation from tracked state — NO-BUILD *as new machinery*

`WIProgression.check_class_gains` (progression.gd:138-155) IS derivation
from tracked state: flat counter thresholds over `accomplishments`,
resolved at sleep. Building a second derivation engine would duplicate
shipped machinery. What the shipped gate CANNOT express is portfolio
SHAPE — ratios, breadth, absence — and that delta is real but small: it
is a predicate-vocabulary extension, not a new system (§3).

### 2.3 Authored-combination table keyed on portfolio shape — BUILD (reduced)

The chosen mechanism. "Unique" lives in the TRIGGER — a predicate over
frozen-id counters rare enough that most runs never satisfy it — while
the class RECORD is authored, frozen-id, balance-gated, and QA-covered
like every other class. The player's particular history selects the
class; the class itself was always waiting in the catalog. This is also
exactly how the shipped game already produces its rarest moments: the
consolidation offer ([Spellsword]) and the evolution fork are authored
records behind derived gates, and playtesters report them as personal.

## 3. Mechanism spec

### 3.1 Data shape

Bestowed classes are ordinary records in `data/classes.json`'s `classes`
array (so `granted_skills`/display-name/journal/save consumers work with
ZERO changes), carrying a `bestowed_by` block instead of `gained_by`.
The two are mutually exclusive (new `test_content.gd` arm). Records
without `gained_by` are ALREADY skipped by the shipped gain path
(progression.gd:143: `not cls.has("gained_by")` → continue), so adding a
bestowal record is inert to every shipped code path by construction —
the data addition is zero-risk before the new check exists.

`bestowed_by` is a CLOSED five-arm predicate vocabulary (data_lint shape
check, semantics pinned in `test_progression`; the closed-set discipline
is `scripts/data_lint.py`'s own: structural pre-checks, no rule engine):

| arm | shape | semantics | precedent |
|---|---|---|---|
| `requires` | `{counter: min}` | every counter ≥ min | `_level_met`, progression.gd:182-186 |
| `requires_any` | `{counter: min}` | any counter ≥ min | progression.gd:176-181 |
| `dominance` | `{"counter": id, "pool": [ids], "share": f}` | counter/sum(pool) ≥ share, no tie | evolution dominance, progression.gd:201-226 |
| `breadth` | `{"counters": [ids], "min_each": n}` | every listed counter ≥ n | new (the cross-pillar shape) |
| `absence` | `{counter: max}` | every counter ≤ max | new (the "never did X" shape) |

Plus one non-counter arm: `excludes_classes: [ids]` (held-class veto,
reads the `classes` dict; use sparingly). All arms present must pass
(AND). The vocabulary is CAPPED at these six arms — a bestowal that
needs a seventh is declined, not accommodated (kill criterion K1).

`absence` is the one genuinely new semantic: it breaks the monotonicity
`check_class_gains` enjoys (counters only grow, so met-once = met
forever). Consequence, documented not fixed: a player can close a
bestowal by acting (canon-true — paths close). Evaluation happens only
at the sleep beat, so non-monotonicity can only ever close a FUTURE
bestowal, never revoke a granted one.

### 3.2 Resolution: sleep placement + the retroactive level chain

New pure static `WIProgression.check_bestowals(classes, accomplishments,
class_catalog) -> String` returning at most ONE class id: first
catalog-order match wins, then stop (catalog array order is the
deterministic tie-break, same iteration discipline as check_class_gains).

Placement in `WISleepBeat.run` (src/core/sleep_beat.gd:48-61): **between
the class-gains block (sleep_beat.gd:53-58) and the level-ups block
(sleep_beat.gd:59)**, gated on the one-per-run counter (§3.3). Order
becomes: gains → **bestowal** → level-ups → consolidation offer →
evolutions.

Why before level-ups, not last: the bestowed class enters at level 1 with
its `levels` table authored against the SAME counters its predicate read
— so the shipped `check_level_ups` while-loop (progression.gd:167-171
chains every already-met level in one pass, and sleep_beat.run calls it
on the post-gain `classes` dict) carries the fresh class to level 4-6
THE SAME NIGHT. "[X] class gained! [X] Level 5!" in one sleep is the
whole fantasy — *you were already this thing; the System just said so* —
and it costs ZERO new sim: it is existing behavior of the level engine.
A bestowal step placed after evolutions would defer the chain to the
next sleep and undercut the moment.

MIRROR CONTRACT: `tests/sim_class_paths.gd` reproduces sleep()'s
progression order exactly and says so (sim_class_paths.gd:6-13); the
bestowal step lands in `_sleep_resolve` in the same commit as the
sleep_beat change, or the harness measures a different game.

### 3.3 One-per-run cap

At most one bestowed class per run (v1). Mechanism: bank a plain
accomplishment `class_bestowed` via `record_accomplishment`
(wi_game.gd:835-837) when a bestowal fires; `check_bestowals` is skipped
while it is ≥ 1. Counters already save-serialize, so the cap round-trips
with no save-format change (`WISave.VERSION` stays 8, save.gd:4).
Rationale: uniqueness is the product; two bestowals in one run reads as
a content system, not a recognition; and the cap bounds the balance
surface (§6) to one extra class per build.

### 3.4 Interplay with evolution/consolidation (issue question b)

- A bestowed record may carry its own `evolution` block, `aspiration`,
  or a sparse continuation table — all shipped machinery
  ([Courier]/[Witch] sparse-table precedent, GH#54;
  docs/design/class-expansion-spec.md §2). v1 roster ships
  evolution-less with `aspiration` text carrying the fantasy (the
  [Necromancer] precedent, class-expansion-spec.md:165).
- Retirement: `_retired_class_ids` (progression.gd:121-135) already
  handles evolution targets and consolidation parents; bestowed classes
  participate identically. No bestowed class appears in any
  `parent_lines`/`targets` in v1.
- Power math: a bestowed class is a normal entry in the `classes` dict,
  so `power_multiplier`'s split penalty (progression.gd:44-50, power_k
  1.55) applies automatically. The retroactive chain (§3.2) means it
  arrives at a real level, not a diluting L1 — deliberate.
- Predicates read counters, not held classes (except `excludes_classes`),
  so evolved/consolidated players still qualify: [Spellsword] does not
  orphan a bestowal earned by the road taken to it.

## 4. What "unique" honestly means here (expectation-setting)

The System cannot invent; it can only recognize. The honest gap vs the
canon fantasy: a second player with the same weird life gets the same
class. Mitigations that are IN scope: predicates rare enough that the
path-diversity harness proves most archetypes never see one (§6), copy
written in second person about the deeds ("You fed strangers before you
fed yourself"), and the one-per-run cap. Mitigation OUT of scope:
per-player name variation (that is the generative no-build). This is the
#348 ToTK-gap discipline applied to progression: scope to the
deliverable core — recognition, rarity, and a bespoke-feeling moment —
and say plainly what is not deliverable.

## 5. Canon + spoiler surface (issue question c)

- The Grand Design of Isthekenous is named DEEP past the advertised bar
  (the naming interlude is Volume 9; the advertised scope is through
  Volume 7 — docs/design/spoiler-cutoff.md). Rule 1 of that doc binds:
  the name — and "Isthekenous", and "Grand Design" — never appears in
  player-facing text, art, mechanics, or public planning surfaces. This
  is the [Door of Portals]→"Magical Door" precedent (spoiler-cutoff.md
  rule 2) applied to the System itself.
- The game ALREADY has the player-visible fiction, shipped and
  user-ratified: the System speaks in gold-on-black bracket lines under
  the sleep veil, unnamed — "[Class: none.] … This world watches what
  you do." (`src/ui/sleep_veil.gd:73-79`, the GDI opener); the
  consolidation offer is likewise "delivered by the Grand Design during
  sleep" internally while the player just hears the voice
  (sleep_veil.gd:288-289). **The bestowal moment extends this exact
  register** (§7). No new fiction is invented; the internal name stays
  in comments and docs, per shipped precedent.
- Unique classes are canon well inside the bar — the System visibly
  tailors classes to unprecedented deeds (Pawn's [Priest], the first
  Antinium to earn it, Vol 2; Numbtongue's [Soulbard], Vol 6; wiki-check
  both cites at implementation time per convention). Bestowed class
  NAMES in our roster are ⚑ ORIGINAL noun phrases (ruling 9,
  class-expansion-spec.md §9) unless an attested pre-Book-17 name fits;
  every name gets the standard wiki-check + cutoff-check at authoring
  (spoiler-cutoff.md rule 4), with rule 5's treat-ambiguous-as-past-
  cutoff default.
- SEAM (controller/user, not this lane): issue #347's public title
  carries the "GDI" initialism; spoiler-cutoff rule 1 covers issue
  titles. Recommend future public-surface phrasing avoid even the
  initialism ("system-bestowed").

## 6. Balance + harness membership (issue questions a/e)

- **Combat-granting bestowals** add BUILDS rows to `sim_combat_batch.gd`
  (build = bestowed class at its post-chain level, crossed against the
  region-tier compositions its predicate makes reachable), GATED
  0.55-0.95 — the necromancer-rows precedent
  (class-expansion-spec.md §8). Non-combat bestowals add no cells
  (helper precedent). Grants reuse SHIPPED effect types only — a
  bestowal is never the vehicle for a new sim verb (STOP-trigger
  discipline; kill criterion K6).
- **Rarity and reachability are gated, not vibes**, using shipped
  machinery: `sim_class_paths.gd` (200 seeded runs/archetype, horizons
  12/25/50, existing entropy ≥ 2.0 / funnel ≤ 0.45 gates,
  sim_class_paths.gd:20-23). Additions per bestowal: one TARGETED
  archetype whose waking battery matches the predicate, plus rarity
  measurement across the existing battery. Proposed gates (tune at
  implementation, mechanism is what's ruled): targeted archetype reaches
  the bestowal in ≥ 50% of runs at horizon 50; pooled non-targeted
  archetypes reach it in ≤ 5%. Bestowals add terminal states, so the
  existing entropy gate benefits for free.
- Pacing: bestowal never gates story content in v1 (no `requires` on any
  quest/door reads a bestowed counter), so `sim_progression_pace.gd`
  bands are unaffected; re-run as report-only confirmation.

## 7. The bestowal moment (issue question d: opaque-until-sleep)

- The predicate is NEVER surfaced. No progress text, no "something
  watches you approvingly", no journal hints. Opaque-until-sleep is
  user-locked repo-wide (AGENTS.md: results only) and the surprise IS
  this feature's product. The one sanctioned foreshadow: `aspiration`
  text on the bestowed record renders only AFTER gain, like every class.
- Sim emits a new `WIEvents.CLASS_BESTOWED {class, level}` (fired after
  the level chain resolves, carrying the post-chain level) alongside the
  standard CLASS_GAINED/CLASS_LEVEL_UP stream — QA asserts on it, and
  `sleep_veil.gd` catches it for a dedicated veil beat (the veil's
  established catch-a-domain-event pattern: class/level toasts, F1
  opener, consolidation announce, defeat). Toast fallback preserved for
  completeness (`_class_gained_toast` shape, sleep_beat.gd:225-238).
- Veil copy (draft, 3 lines, OPENER register, measured under the 880px
  veil column per `test_copy_fit._check_veil_lines`):
  - `[Some classes are offered. This one was owed.]`
  - `[<Class Name> — Level <N>.]`
  - `[It watched you earn it.]`
  Copy lane owns final lines; stat grammar + no-progress-language rules
  apply; the voice stays unnamed (§5).
- Under QA/headless the veil collapses to an instant coverage emit, the
  shipped `_is_qa()` contract for every veil mode.

## 8. Costed slices (issue question f) — the v0.18+ milestone shape

### Slice 0 — machinery (SMALL; one src lane + one test lane)
Dispatch-grade: executable from this doc alone.
1. `WIProgression.check_bestowals` + the six predicate arms (§3.1),
   pure statics beside check_class_gains.
2. `WIEvents.CLASS_BESTOWED` const + doc comment (src/core/wi_events.gd).
3. `WISleepBeat.run` bestowal step between gains and level-ups
   (§3.2) + `class_bestowed` cap counter (§3.3).
4. `sim_class_paths.gd` `_sleep_resolve` mirror step (same commit).
5. Tests: `test_progression` truth table per arm (met/unmet/tie/absence
   non-monotonicity/excludes_classes/catalog-order tie-break/cap);
   `test_content` arm: `bestowed_by` XOR `gained_by`, arms from the
   closed set only, every referenced counter has a producer;
   `data_lint.py` shape tier for the block.
6. Gates: headless smoke zero-warnings; test_progression; test_content;
   `qa/ci_sweep.sh --tier smoke`. With no bestowal records in data the
   sweep must be BYTE-IDENTICAL — slice 0 is provably inert.

### Slice 1 — the first bestowal (MEDIUM; data lane + QA lane + veil lane)
ONE record, end-to-end. Chosen shape: **the pacifist** — the strongest
three-pillars statement (non-combat play recognized as first-class), and
every counter it needs ships today (talk/skill quest-path counters,
`persuaded_someone`, quests-completed, low `won_combat` via `absence`).
Sketch: `breadth` over ≥3 peaceful-resolution counters + `requires`
quests-completed-shaped volume + `absence {won_combat: 2}` +
`excludes_classes` on the pure-combat consolidations. Name: ⚑ ORIGINAL
noun phrase, wiki-checked at authoring; candidates to check, in order:
[Peacebinder], [Gentle Hand], [Quiet Diplomat] — with the standard
nearest-canon-substitute fallback rule. Grants: field/social skills from
the shipped catalog only. Deliverables: the record; veil beat + copy-fit;
`near_bestowal_pacifist` fixture (counters banked just under the
predicate, fixture-coherence rules apply) + `bestowal_pacifist_loop`
canonical (sleep → CLASS_BESTOWED + chained CLASS_LEVEL_UP + journal
render + veil coverage event; model: `class_evolution_loop`);
sim_class_paths targeted archetype + rarity gates (§6); seed-table +
manifest + QA-notes regeneration per convention.

### Slice 2 — the roster (MEDIUM-LARGE; one content lane per record)
2-4 more bestowals covering the remaining pillar shapes (a breadth
"did-everything" recognition; a stealth/mobility `dominance` shape over
sneak/blink/ward counters; at most ONE combat-granting record, which
buys the full §6 harness bill). Each is a self-contained lane: record +
fixture + canonical + harness rows. classes.json appends go under a
per-lane anchor comment; splice discipline per COMMON.

## 9. Kill criteria

- **K1 (vocabulary creep):** a proposed bestowal needs an arm outside
  §3.1's six → decline the bestowal. Two such declines in one wave →
  stop roster growth and re-evaluate the whole feature.
- **K2 (rarity failure):** any bestowal reached by >5% of pooled
  non-targeted archetype runs after two predicate retunes → cut that
  record (it is not unique, it is a class).
- **K3 (reachability failure):** targeted archetype under 50% at
  horizon 50 after two retunes → the predicate is precious; re-cut or
  kill the record.
- **K4 (felt-sameness):** user/friend windowed playtest reads the
  bestowal as a normal class gain → presentation rework gates any
  further roster work (slice 2 blocked on it).
- **K5 (the hard line):** any implementation pressure toward
  serializing class definitions into saves, runtime name assembly, or
  non-catalog class ids → hard stop; that is the §2.1 no-build
  resurfacing.
- **K6 (balance blast):** a combat-granting bestowal cannot land its
  gated band without breaking sibling cells after two retunes → demote
  its grants to field-only, or kill the record. A bestowal never ships
  a new effect type.

## 10. Why not no-build outright

The reduced build is cheap (slice 0 is a few pure functions on shipped
machinery; the level chain and the veil are free), risk-fenced (inert
until data exists, byte-identity provable), and aimed at the game's
stated identity: the progression system IS the product ("the game
balances around Class + Skill progression", full-game-architecture §4),
and this is the progression system's single most famous canon beat. The
no-build option forfeits the one moment the license is uniquely
positioned to deliver, to avoid machinery this codebase has already
proven five times over (gains/evolution/consolidation/aspiration/
sparse-tables). Build-reduced, as specified.
