# Itinerary compiler (M3)

Compile an act from the repository root:

```sh
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act1.yaml \
  --out scripts/itinerary/generated/act1.json
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act2.yaml \
  --out scripts/itinerary/generated/act2.json
```

Run the suites with `python3 -m pytest -q scripts/itinerary/tests`.

## The two passes (M3)

A compile is not a translation, it is a loop: plan against projections, play
the plan, then re-plan knowing what happened (§5). Pass 1 is honest about what
it cannot know — a chance-gated drop parts the gold interval, and a
challenge-weighted counter is refused outright and queued as a `pins_pending`
row. Pass 2 pays those off from a recorded run.

```sh
# pass 1: build the HARVEST script (a dump_state after every node) and run it
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act2.yaml \
  --out /tmp/act2.probe.json --probe --run --seed 9 --run-out /tmp/probe_run

# pass 2: re-emit against what that run actually did. THIS is the ship script.
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act2.yaml \
  --out scripts/itinerary/generated/act2.json --refine /tmp/probe_run/events.jsonl
```

The harvest is keyed on **node labels**, not on event ordinals. `dump_state`
(GH#436) emits `qa_state_dump` carrying the whole snapshot, so a probe run's
`events.jsonl` is a sequence of node-labelled readings with the run's ordinary
events between them. Counting occurrences of `gold_changed` and hoping the
count is stable is the alternative, and it goes wrong silently the first time
an unmodelled toast moves the ordinal. A label is not a guess.

Probes are scaffolding. A ship build that still carries one is a compile
error — the same discipline the `dump_checkpoint` grep gate enforces for the
steel thread.

### What pass 2 may and may not do

It may collapse a projection, pin a harvested counter, and fill a `total` that
pass 1 dropped. It may **not** re-decide the plan. The ledger carries two gold
numbers and refine touches exactly one of them:

- `state["gold"]` becomes the harvested truth, so every downstream oracle
  answer is asked under the world the run was really in;
- `gold_interval` stays **projected**, because it is the variable the economy
  planner splices earn-detours on. Collapsing it would let pass 2 drop a
  detour pass 1 inserted — and a pass that removes a node invalidates its own
  evidence, since every rng draw behind that node moves (§2.4).

So an unnecessary detour is **flagged, never removed** (`DETOUR/UNNECESSARY`
in `_refine_notes`). Removing it is an itinerary edit, and an itinerary edit
is re-verified wholesale.

A harvest that is missing nodes is refused rather than partly applied: that is
a stale harvest, and half a refinement is worse than none.

### Fixed point

Pass 2 must be a fixed point (§5): refine, probe the refined plan, harvest
that, refine again, and the output is byte-identical. `--probe` and `--refine`
combine for exactly this proof. It holds because refine only ever ADDS
asserts and tightens pins — it never changes what the run does — so the second
harvest describes the same run as the first.

## When a compiled run reds

Nothing in the emitted JSON is ever hand-patched; that rule is what keeps the
corpus recompilable. So a failure has to be reported somewhere an author can
act on it, which is the NODE:

```sh
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act2.yaml \
  --out /tmp/act2.json --run --seed 9
```

```
ITINERARY FAILURE  step 64/64  action=assert_event_logged type=class_gained
  node       act1.broken.claim   (assert)
  planner    emitter
  written at scripts/itinerary/act1.yaml:26
  spec       {"event": {"payload_contains": {"class": "mage"}, "type": "class_gained"}}
  why        A deliberately false claim -- Act I's sleep banks no class at all.
  driver     expected event was never emitted: class_gained
```

The `_itin` stamp on every step is what makes that possible, and the `why` is
in the report on purpose: half of these reds are the itinerary asking for
something the game stopped offering, and the `why` is what tells you whether
to re-route or drop the beat. A step whose stamp no itinerary declares is
reported as UNMAPPED rather than attributed to the nearest node.

## Golden diffs

```sh
python3 -m scripts.itinerary.goldens <compiled.json> <shipped.json>
```

Byte-identity is the wrong bar (§6.3). Differences sort into three buckets:
**exact** (asserts, presses, event waits and their payload pins, screenshot
names, autoplay policy — fatal), **net** (where a run of cursor/walk moves
arrives — fatal, because the arrival is what the next press acts on), and
**tolerance** (how a walk was split, wait timeouts, settle frames, comment
text, `_itin` stamps — reported, never fatal). Pins may be TIGHTER on the
compiled side and never looser. `press move_down` and `move {down, steps: N}`
are the same cursor idiom and compare equal.

M2 accepts the whole frozen primitive set: `goto`, `talk`, `fight`, `sleep`,
`equip`, `unequip`, `buy`, `sell`, `use_field`, `interact`, `shot`, `assert`,
`detour`, `raw`. Every node needs a stable `id`; every fork (`choose_path`)
needs a `why`. Unknown spec keys are rejected rather than ignored — a typo that
silently no-ops is how a mis-planned fight compiles green and then hangs.

The compiler asks `qa/oracle.gd` for paths, visible dialogue rows, inventory
cursors, the field bar, and progression outcomes, then emits driver steps
stamped with `_itin`. Generated JSON is disposable and must never be
hand-edited.

## What the compiler refuses to do

These are compile-time errors, each bought by a real failure:

- **Leave a conversation open.** A `choose_path` that stops on a node without
  taking a closing row hangs the run: the next `press` is eaten by the panel's
  own cursor. The error names the rows that would close it.
- **Walk into a proximity ambush.** An encounter with `trigger_radius` springs
  after a move lands, mid-walk, and every emitted step behind it is swallowed
  by the combat board. Routes that clip one are refused; plan it instead with
  `fight: {entry: proximity}`, which splits the walk at the radius and makes
  the step in the trigger. (Arriving *inside* a radius by door is safe —
  transitions do not run the check.)
- **Buy what the ledger cannot certainly afford.** See below.
- **Pin a challenge-weighted counter.** `won_combat` deposits fractionally in
  a gray-band fight and at the adversity cap for a low-power one, so it is
  never banked and never pinned; `victories` (integer under both flag states)
  is what a compiled fight asserts. Each skipped bank leaves a `pins_pending`
  row for M3's refine pass.

## Gold is an interval

A chance-gated loot drop parts the ends: a `{gold: 2, chance: 0.5}` table
contributes `[0, 2]`, not `2`. The materialized save follows the LOW end, so
every oracle answer downstream is asked under the poorest world the run could
be in. A purchase is only plannable when the floor covers the price; when it
does not, the economy planner splices in an earn-detour and stamps a
`GOLD/PACING` note into the compiled script's `_pacing_notes`. A pin that
depends on an open interval (a purchase's resulting `total`) is dropped rather
than guessed — M3's refine pass tightens it from a real run.

## Detours (`detours/*.yaml`)

Itinerary fragments in the same node grammar, plus a contract: `entry.map` /
`exit.map` (enforced), `earns` (matched on `min`, never `max` — a detour that
*might* cover the gap leaves the purchase unaffordable in exactly the world
the interval exists to warn about), and `requires`/`forbids` accomplishment
gates. Ties break on the cheapest sufficient earn so a compile is
deterministic. Each detour owes a `why`: it is a choice spliced in without an
author asking for it.

## The ledger replay self-check

After emission the compiler replays the emitted script against the ledger's
own record — positions from the script's `move` steps, map from its
`map_changed` waits, money and gear from its pins — and hard-fails on any
divergence. It also enforces the shapes that hang runs: balanced dialogue and
combat panels, `dialogue_node` waited before `ui_dialogue_shown`,
`combat_autoplay` only inside a live fight, an `_itin` stamp on every step.
Menu cursor moves inside an open panel are excluded from position tracking;
the one tolerated discrepancy is a trailing single-step bump into a blocked
cell, which sets facing without moving.

## RNG

One global stream. Adding or removing a draw-consuming step reshuffles every
later fight, so an itinerary is recompiled and re-verified wholesale; pins are
never patched around a changed epoch. `rng_epoch` counts fights, not loot —
`WIEconomy.roll_loot` seeds a private generator from
`hash("<run_seed>:<entity_id>")` and never touches the world stream.

## Known limits (deliberate, not oversights)

- `sell` is unit-pinned only; no shipped act sells anything, because nothing
  in Act II's inventory is both priced and unworn.
- Resonance capacity is not modelled, so a capacity-blocked accessory equip
  reds its run rather than failing to compile.
- Phase-gated proximity encounters (`present_when`/`encounter_when`) are not
  treated as hazards — the ledger carries no phase, and assuming the worst
  would refuse legitimate daytime routes.
- A `[Wild Affinity]`-style trigger-radius reduction is unmodelled; ignoring it
  keeps hazard detection conservative in the safe direction.

## The acts

`generated/act2.json` is the **pass-2** artifact (§5: the refined script is
the one that ships), which is why it carries `_refine_notes` and two
`accomplishments.won_combat` pins a static compile refuses to write. Rebuild
it with the two-pass recipe above at `--seed 9`; a plain compile is pass 1 and
will differ by exactly those tightenings. `generated/act1.json` has no
projections to pay off, so its two passes are the same file.

`act1.yaml` starts from a new game. `act2.yaml` starts from the shipped
`post_tutorial_street` fixture, on purpose: compiled Act I declines Relc's spar
(M1's ruling — its gate cells sit within Chebyshev 2 of the unavoidable road
ambush), so it ends classless, unarmed, and never reaches Liscor. Act II opens
where that fixture already stands, which is the honest seam rather than a
pretended continuous run.
