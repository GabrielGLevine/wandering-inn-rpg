# Itinerary Compiler — engine design (#434)

Fable-authored 2026-08-12, on user directive to frontload the full design
before implementation. Companion to the #434 issue body (which carries the
sim-rule inventory with file refs) and to `wi-writing-qa-scripts`'s two
lesson sections (the rule corpus this engine encodes). The shipped
2569-step `steel_thread.json` is the golden corpus; the balance program
(#437–#442) built the instruments this engine composes.

## 0. The one architectural ruling that matters

**The compiler never reimplements sim semantics.** Every question about
what the game would do — visible dialogue rows, walkability, portal rows,
field bar, gold — is answered by the GAME, through `qa/oracle.gd`, against
a save the compiler materializes. The compiler's own ledger tracks only
what it needs to SEQUENCE decisions (what's banked, who was talked to this
waking, what's carried); whenever a decision needs ground truth, it
serializes the ledger to a WISave fixture and asks the oracle. Python
plans; GDScript answers. The moment someone ports `_visible_options` math
into Python, this engine starts rotting — refuse that patch.

Corollary: the compiler is **not a pure static translator**. It is a
compile → run → refine loop (§5). Combat outcomes, loot rolls, and level
timing are runtime facts; the engine's job is to plan around them and then
harvest them.

## 1. Module decomposition

```
itinerary/                      (repo-root scripts/itinerary/)
  schema.py      — YAML itinerary parser + validation (§3)
  ledger.py      — world-state ledger (§2)
  bridge.py      — WISave materializer + oracle/driver shell-outs
  planners/
    route.py     — goto: oracle path queries + door/portal/travel-prop legs
    dialogue.py  — talk/choose: graph walk via oracle visible_options
    combat.py    — fight: entry mode, policy, victory pins, tape harvest
    economy.py   — gold interval arithmetic + earn-detour insertion (§2.3)
    sleep.py     — sleep: level/consolidation/attunement projections
  emit.py        — primitive → step-JSON idiom table (§4); provenance stamps
  refine.py      — pass-2 pin tightening from a recorded run (§5)
  goldens.py     — corpus recompile + structural diff (§6)
```

Two binaries: `compile_itinerary.py <itin.yaml> [--refine <events.jsonl>]`
and `diff_itinerary.py` (variant overlay tooling, §3.3).

## 2. The ledger

A plain dict mirroring WISave `state` keys the compiler must order
decisions by: `accomplishments` (counts), `classes` (+ a PROJECTED flag,
§2.2), `player_skills`, `equipped`, `inventory` (ordered — picker cursors
derive from insertion order), `gold` (an INTERVAL, §2.3), `current_map/
cell/facing`, `sleeps`, `talked_this_waking` (per-NPC), `removed_entities`,
`started_quests`, `dormant_encounters`, plus compiler-only bookkeeping:
`rng_epoch` (§2.4) and `pins_pending` (facts deferred to pass 2).

Ledger updates come from three sources, in trust order:
1. **Data-derived** (dialogue effects arrays, quest complete_when, door
   gates) — applied at compile time, exact.
2. **Projected** (combat victory, level-ups at sleep, loot) — applied as
   assumptions, each emitting a `pins_pending` entry for pass-2
   confirmation.
3. **Harvested** (pass-2 events.jsonl) — replaces projections with actuals.

### 2.1 The waking state machine
`sleep` clears `talked_this_waking` (engine truth: `social_talked` clears
only in `sleep()`); `talk` against a pool-carrying NPC not yet talked this
waking emits the pool-line idiom; `dialogue`-carrying NPCs (from the map
entity, not hardcoded lists) skip it. Panel-teardown settle frames are the
emitter's job (§4), not the planner's.

### 2.2 Class/level projection
Levels bank only at sleep; thresholds are cumulative lifetime counters the
ledger already tracks (melee_hit etc. are PROJECTED from fight tapes in
pass 2 — pass 1 uses sim_progression_pace-style estimates and marks the
sleep's `class_gained/level` pins as pending). Consolidation offers and
evolution fire at sleep: the sleep planner must consult
`WIProgression`-derived data (via a small oracle query addition,
`progression_preview` — the one oracle extension this engine needs) and
either script the modal or assert its absence. An unplanned
`pending_consolidation` modal eats all input — the #1 hang risk.

### 2.3 Economy planning
`gold` is an interval [min, max]: loot rolls (e.g. 50% drops) widen it;
purchases require `min >= price` — when violated, the planner inserts an
earn-detour from a registered detour library (board bounties, buybacks,
standing bounties) and logs a GOLD/PACING provenance note. Pass 2
collapses intervals to actuals and can REMOVE detours that proved
unnecessary (flagged, not silent). The interval discipline exists because
the reauthor lane measured exactly this: a fenced draught pair and a 50%
supplier roll are the difference between a funded and unfunded finale.

### 2.4 RNG doctrine
Every rng draw (combat construction, loot, some AI) advances one global
stream. **Any inserted or removed draw reshuffles every fight after it**
(measured: one optional detour moved the warden's ending HP from 6 to 58).
The ledger tracks `rng_epoch` = ordinal count of draw-consuming steps; any
edit before epoch N invalidates all pins with epoch > N. `refine.py` uses
this to know which pass-2 harvests are stale after an itinerary edit —
recompile+rerun is expected and cheap (~60s headless), so the engine
never attempts draw-preserving surgery. Document this in the user-facing
README: itineraries are re-verified wholesale, not patched.

### 2.5 What the ledger deliberately does NOT model
Combat resolution, AI decisions, toast queues/coalescing, veil line
counts, arena geometry. These are pass-2 harvest domains or
never-pin domains (the skill doc's traps list is normative).

**Amendment (2026-08-13, M2 audit finding):** loot does NOT consume the
global RNG stream — `economy.gd` seeds a private generator from
`hash(run_seed:entity_id)` — so `rng_epoch` counts fights only. The §2
prose listing loot as a global draw is superseded by this note.

**Amendment (2026-08-13, M3): pass 2 refines PINS, not the PLAN.** The refine
loop collapses `state["gold"]` to the harvested actual (so downstream oracle
answers are asked under the world the run was really in) but deliberately
leaves `gold_interval` projected, because that interval is what the economy
planner splices earn-detours on. Letting the harvest move it would let pass 2
drop a detour pass 1 inserted — and a pass that removes a node invalidates its
own evidence, since every draw behind that node moves. So §2.3's "can REMOVE
detours that proved unnecessary (flagged, not silent)" resolves to FLAG only:
the removal is an itinerary edit, re-verified wholesale per §2.4. This is also
what makes §5's fixed point hold rather than merely be hoped for — refine only
ever adds asserts and tightens pins, so the refined script plays the same run
the probe did.

**Amendment (2026-08-13, M3): `won_combat` has a second depositor.** §2.2
treats challenge-weighted counters as a combat-resolution concern, and the
ledger queues its `pins_pending` rows from `apply_victory` alone. Measured in
Act II: `won_combat` reaches 1 at `act2.krshia.report`, a `talk` node with no
fight in it — a quest resolution-path grant (`WICombatBanking.grant`, GH#211
§5) deposits weighted counters too. Pass 2 therefore pins from the HARVEST
(any weighted counter that moved during a node) rather than from the queue,
and reports an unqueued move as the modelling gap it is. Teaching the dialogue
planner to project resolution grants is open work.

## 3. The itinerary language

### 3.1 Shape
YAML list of ACTS → labeled NODES. Every node has a stable `id` (the
anchor for variants, provenance, and diffing). Example:

```yaml
- act: ii
  nodes:
    - id: nest.prep.klbkch
      talk: {npc: klbkch, at: street}          # ally gate, pool-line aware
    - id: nest.fight
      fight: {encounter: shield_spiders, entry: interact, policy: competent,
              expect: victory, shots: [mid_fight]}
    - id: nest.report
      talk: {npc: olesm, choose_path: [worried, report], pin: quest_completed/cisterns}
    - id: act2.sleep
      sleep: {expect_levels: true, shot: after}
```

### 3.2 Primitive set (frozen for M1–M3; extensions need a design note)
`goto` (map or map+cell; router picks doors/travel-props/portals from the
gate state in the ledger), `talk` (with `choose_path`: a list of NODE
LABELS or option-text anchors — never indices; the dialogue planner
resolves cursor moves via oracle at the ledger state), `fight`, `sleep`,
`equip`/`unequip`, `buy`/`sell` (vendor + option-text anchor), `use_field`
(skill), `interact` (labeled prop), `shot` (album beat: name + hold),
`assert` (ledger expectation → emitted as assert_state/event pins),
`detour` (named block from the detour library, insertable by planners),
`raw` (escape hatch: literal steps, provenance-stamped, budgeted — a
compiled script with >2% raw steps fails validation; raw is where corpus
knowledge goes to hide).

### 3.3 Variants (the Mage run)
A variant file = base reference + patch list keyed on node ids:
`replace / insert_after / insert_before / remove`, plus scalar overrides
(`creation.class_route: mage`). No conditionals inside itineraries —
branching lives in the variant layer, keeping every itinerary a straight
line (what a playthrough IS). The variant compiles to a complete
itinerary before planning; diffs are reviewable as patch files.

### 3.4 Choice provenance
Every fork choice (`choose_path`, resolution paths, ending picks) requires
an inline `why:` string. The compiler emits these into step `_comment`s —
CHOICE-LOG discipline enforced at the language level.

**Amendment (2026-08-13, pre-M4 design note — Fable).** Two rulings:

1. **§3.2 vocabulary amendment (narrow unfreeze).** The M3 golden measured
   exactly two missing idioms in 2569 corpus steps; the vocabulary gains
   exactly those two and re-freezes:
   - `fight: {mode: driven, turns: [...]}` — an explicit turn list
     (move/hotbar_N/cycle/end_turn presses + tutor-beat event waits),
     shaped from the shipped spar (steel_thread 84-106). Autoplay remains
     the default mode; `driven` exists for fights whose CHOREOGRAPHY is
     the content. Turn lists are exact-class in goldens.
   - `journal` — open, optional named capture, close (the shipped
     press-journal idiom, steel_thread 562-566 / 2318-2323). Exact-class.
   Both require emitter acceptance-table rows (the set-equality pin
   forces this mechanically).
2. **Pass-2 planning fence (structural, before M4).** Refine must never
   re-plan. Enforcement is a plan-spine equality gate: pass 2 hard-fails
   (CompileError) if node list, routes, or inserted detours differ from
   pass 1 — pins/asserts/probe-removal excluded from the comparison. This
   fences the audited latent path (refine's harvested ledger values
   feeding route/ally/preview planning) for every future itinerary,
   including M4's Mage variant, the first corpus artifact that sleeps
   after fights. A weighted-counter lint on planner-readable requires is
   OPTIONAL advisory on top; the spine gate is the binding rule.

**Amendment (2026-08-13, M3.6 ruling — Fable).** The golden's measured
blocker table + the M3.5 audit findings resolve to one final pre-M4
scope; the vocabulary re-freezes after these:

1. **`fight.entry: dialogue`** — third FIGHT_ENTRIES member: the fight
   is entered by a dialogue option carrying `start_combat` (the spar's
   shape). The planner walks the conversation to that option; the
   emitter omits the map-encounter approach/press and expects
   combat_started off the dialogue confirm.
2. **Effect-derived event waits (planner pass, no vocabulary):** after
   a chosen dialogue option, the planner derives event waits from the
   option's own `effects` array AND its quests.json joins
   (accomplishment/quest_started/beat/completed/item_gained shapes).
   The M3.5 "141" figure is REFUTED as miscounted — re-measure first
   (audit: ~115 in-window, ≥26 non-derivable or already reproduced;
   the pass targets the derivable subset and the golden differ decides
   the rest row by row).
3. **Emitter frame flexibilities (spec keys, not primitives):**
   `turn_wait: false` (6 of 12 shipped fights carry no turn_started
   wait), tutor-beat waits inside autoplay (`beats:` on the autoplay
   fight), post-dismiss banking waits (`expect_banks_after_dismiss`),
   payload-tight `combat_started` pins (`arena:` passthrough),
   `goto.via: <door-id>` (the GH#375 west-door class), and the two
   missing event kinds (`ui_map_rendered`, `ui_gdi_epilogue_rendered`)
   as wait-shapes.
4. **Sneak-lifetime modeling (#440)** in the ledger/route planner —
   the last planner gap on the thread's tail.
5. **Hardening (audit items):** node-level unknown-key rejection (a
   typo'd second primitive currently no-ops silently — pre-existing);
   fence arrival tracking (ledger end-position per node joins the
   spine comparison, closing the state-dependent-destination hole
   before M4's portal-heavy variant).

Exit: the steel-thread golden passes the tolerance differ end-to-end;
STEEL-THREAD.md's "regenerate via compiler" line lands. M4 (the Mage
variant, the #438 acceptance milestone) dispatches only after this.

**M3.6 landed 2026-08-13, exit NOT met.** All five items are built,
pinned from a node SPEC through to emitted steps, and mutation-proved
(`scripts/itinerary/tests/`, contract + `pipeline.py` harness). The golden
carries the whole of Act I: 21 nodes over shipped steps 0-217, green
headless at seed 37 (232/232), byte-identical across two compiles.

Item 2's "141" is REFUTED and re-measured **from the emitter's own
placement rule** rather than from a standalone scanner: **105 rows at 60
sites** are derivable (96 announced immediately on a continuing row, 9
after the teardown on a closing row), and 36 belong to other idioms (26
prop-interact, 8 post-dismiss, 2 sleep). A first pass reported 94/55/47
and was wrong in both directions -- it missed a conversation that opens
without a `dialogue_started` wait, and it did not model the closing-row
placement at all.

Differ, against shipped 0-217: pre-lane `50 exact / 11 net`, M3.6
`50 exact / 9 net`. The lane ships exactly ONE `goldens.py` change and it
is pure accounting: gaps of unmatched spine steps are carried forward,
with a two-sided COVERAGE invariant proving nothing is dropped from
comparison, so it cannot mask a difference. A second change — putting the
pinned value in the alignment key — was tried and REVERTED: it fixes a
real mis-pairing weakness but also moves a legitimate subsuming tightening
into exact-class fatal, which is a change to which class is fatal. Policy,
not accounting, and not a lane's to make inside the milestone it gates.

**The open ruling, stated without overselling it.** Does §6.3's "pins
may be TIGHTER and never looser" extend from `assert_*` actions to a
compiled-only `wait_for_event`? Inside the authored 0-217 window a YES
reclassifies **12 of 50** exact rows — measured, and typed in
`qa/STEEL-THREAD.md`: 3 `dialogue_node`, 2 `ui_dialogue_rendered`, 2
`map_changed`, and one each of `class_gained`, `entity_removed`,
`phase_changed`, `ui_inventory_selection_rendered`,
`ui_sleep_veil_rendered`. Only 5 of the 12 are in the dialogue idioms the
residual table names; the ruling covers all 12 because it is about the
ACTION, not the idiom.

The corpus-wide figure of ~134 rows (60 conversation opens, 50
destination nodes, 24 pool lines) is an ESTIMATE and must be read as one:
it projects the emitter's idioms onto an itinerary that does not exist,
since only 0-217 is authored. The observed sample is the 12.

A YES is necessary and nowhere near sufficient — it leaves 38 exact and
all 9 net rows in the authored window alone. The rest is emitter idiom
variance (the 330-row `assert_state player_cell` class, the sleep idiom,
the inventory `items` pin, the in-autoplay assert slot) and two differ
accounting weaknesses. The lane declined to answer the question because
widening a gate to pass its own milestone is the wrong shape of work.

**M4 STAYS BLOCKED.** The golden does not pass the tolerance differ, so
§7's M3.6 exit is NOT met and the M4 dispatch condition is unchanged.

## 4. Emitter contract

One idiom table, tested in isolation (unit: primitive + ledger state →
exact step list). All step-JSON knowledge lives HERE and nowhere else:
pool-line pattern, settle frames after panel closes, bump-move facing,
door-transition vs interact, `dialogue_started → dialogue_node →
ui_dialogue_shown` wait chains, destination pins (never indices, never
full option lists), `victories`-not-`won_combat`, combat dismiss ordering,
screenshot+hold pairs, portal menu row derivation, `policy: competent` on
every fight (the 2026-08-12 ruling — dumb is available per-node for
instrument-comparison runs only).

Every emitted step carries `"_itin": "<node-id>"`. The driver ignores it;
`refine.py` and humans map failures back to nodes with it. Two build
modes: `--authoring` (inserts `dump_checkpoint` at act boundaries +
`--fail-fast` guidance) and ship mode (pure; grep gate for teleport/
install_fixture AND for leftover `dump_checkpoint`).

## 5. Two-pass compilation

Pass 1 (static): plan + emit with projections; risky pins loosened
(victory pins present, but level counts, gold totals, veil lines, toast
texts pinned only where data-derived). Run headless once.
Pass 2 (`--refine events.jsonl`): harvest actuals — level timings, gold
totals, inventory cursor rows, fight tapes (rounds, resources — fed to
the pacing report), unnecessary detours — and re-emit with tight pins.
Re-run to green. The pass-2 output is the SHIPPED script; the pass-1
script is scaffolding. Convergence contract: pass 2 must be a fixed point
(a third compile from the same events changes nothing) — tested in CI on
the corpus.

Failure loop: red run → failure's `_itin` node → planner category
(route/dialogue/combat/economy/sleep) → either a knowledge-base gap
(fix emitter/planner, benefits every itinerary) or an itinerary error
(fix the YAML). Nothing gets hand-patched in the emitted JSON — that
rule is what keeps the corpus recompilable.

## 6. Verification stack

1. Emitter unit table (fast, pure).
2. Ledger replay self-check: every emitted wait must be derivable from
   the ledger transition that emitted it (catches planner/emitter drift).
3. **Golden corpus**: recompile the shipped steel-thread itinerary
   (M3 deliverable: `steel_thread.yaml`, hand-derived once from the
   2569-step script) → structural diff against the shipped JSON.
   Tolerance rules: step order within a node may differ; pin subsets may
   be TIGHTER but never looser; walk routes may differ if both
   oracle-valid; shot names/holds exact. Diff tool reports per-node.
4. Compiled-run gates: headless ×2 (events_seen recorded), grep gates,
   preflight untouched.
5. Calibration cross-check: fight tapes from the compiled run vs
   sim_spine_viability's rows for the same builds (win expectation
   within the row's band) — the run and the table must not drift apart.

## 7. Implementation phasing (lane-sized, sequential)

- **M1 — spine**: schema, ledger, bridge (+ oracle `progression_preview`),
  route+talk+sleep planners, emitter core. Exit: compile Act I from a
  hand-written `act1.yaml`, green headless, zero raw steps.
- **M2 — full primitives**: combat/economy planners, detour library,
  shots, asserts. Exit: Acts I–II compile green; emitter unit table
  complete; ledger replay self-check on.
- **M3 — corpus + refine**: two-pass refine, provenance failure loop,
  `steel_thread.yaml` golden, fixed-point test. Exit: golden recompile
  passes tolerance diff; docs (STEEL-THREAD.md gains "regenerate via
  compiler" as the canonical path).
  **Landed 2026-08-13 except the golden.** Refine, the provenance loop, the
  tolerance differ and the fixed-point proof all ship and are gated; the
  `steel_thread.yaml` golden is BLOCKED on two language gaps measured against
  the shipped 2569-step script — the Relc spar is driven turn by turn for its
  tutor beats (steps 84–106) and two journal reads are album beats with no
  world effect (steps 562–566, 2318–2323). Neither is expressible as a pass,
  and §3.2 freezes the primitive set through M3, so both are reported instead
  of being hidden inside `raw`. Character creation (steps 18–31) is NOT a gap
  — §8 already rules it a `creation:`-keyed emitter prelude, merely unbuilt.
  The gap table lives in `qa/STEEL-THREAD.md`. A design note unfreezing the
  vocabulary for hand-driven combat turns and panel-reading beats is the
  prerequisite for the golden, and belongs ahead of M4.
- **M3.5 — the amendment, landed 2026-08-13.** Both §3.2 primitives are BUILT
  and reproduce their corpus rows exactly (spar 75–114, journal 561–566 and
  2317–2322), §8's `creation:` prelude is BUILT and reproduces steps 0–40, and
  the pass-2 plan-spine fence is enforced with a mutation red. The golden is
  NOT done: `steel_thread.yaml` carries steps 0–61 and passes the tolerance
  differ with zero exact-class rows, then stops at the Relc meeting. What stops
  it is a beat the amendment did not reach — the spar is entered by a dialogue
  option's `start_combat` effect and `FIGHT_ENTRIES` has no `entry: dialogue`
  — plus the effect-derived event waits the dialogue planner drops (M3.5
  recorded these as "141"; that was a whole-script census of those event
  types, and the figure the planner actually owes is **105 rows at 60 sites**
  — see M3.6 below) and six fight-shape variances. Measured table in
  `qa/STEEL-THREAD.md`. **These are
  the M4 prerequisite the way the two closed primitives were M3.5's**; the
  vocabulary stays frozen until a note rules on `entry: dialogue`.
- **M3.6 — the second amendment, landed 2026-08-13.** `fight.entry:
  dialogue`, effect-derived event waits, the five emitter frame keys,
  sneak lifetime and the two hardening items all BUILT. The golden reaches
  shipped step 217 and runs green; it does not pass the differ end to end,
  and the residual is the tightening-class ruling above rather than
  vocabulary. See the §3.2 amendment's own note.
- **M4 — variants**: overlay layer + the Mage-run variant (the #438
  acceptance milestone). Exit: Mage run green in single-digit full runs,
  pacing report auto-generated from pass-2 harvests.

Each milestone is one delegable lane with the usual gates; M1's oracle
extension is the only src/qa-side change and stays additive.

## 8. Open questions, with recommendations (decide at lane time, not now)

- **Oracle process cost**: one godot boot per query (~1-2s) × hundreds of
  queries per compile. Recommendation: batch mode (`--queries <file>` →
  answers array) added to oracle.gd in M1; do NOT build a long-running
  daemon (state-leak risk between queries beats the latency win).
- **Where creation-UI choreography lives**: as a fixed emitter prelude
  keyed by `creation:` scalars (race/gender/difficulty/hints) — it's
  UI-cursor knowledge, not world knowledge. Revisit only if creation UI
  changes.
- **Detour library home**: `itinerary/detours/*.yaml` with the same node
  schema — they're just itinerary fragments with entry/exit map
  contracts. Economy planner inserts by contract match.
- **Sim-table coupling**: pass-2 could auto-append the run's build rows
  to the viability roster. Nice, not M-scoped; file when someone wants it.

## 9. What this engine is NOT

Not a general game bot (it compiles KNOWN routes, it doesn't search);
not a balance instrument (that's the sim table — §6.5 only cross-checks);
not a replacement for hand-written micro-canonicals (fixture-first policy
stands — this engine exists for ROUTE-subject scripts: walkthroughs,
steel threads, variants).
