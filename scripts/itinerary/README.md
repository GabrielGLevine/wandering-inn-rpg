# Itinerary compiler (M2)

Compile an act from the repository root:

```sh
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act1.yaml \
  --out scripts/itinerary/generated/act1.json
python3 scripts/itinerary/compile_itinerary.py scripts/itinerary/act2.yaml \
  --out scripts/itinerary/generated/act2.json
```

Run the suites with `python3 -m pytest -q scripts/itinerary/tests`.

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

`act1.yaml` starts from a new game. `act2.yaml` starts from the shipped
`post_tutorial_street` fixture, on purpose: compiled Act I declines Relc's spar
(M1's ruling — its gate cells sit within Chebyshev 2 of the unavoidable road
ambush), so it ends classless, unarmed, and never reaches Liscor. Act II opens
where that fixture already stands, which is the honest seam rather than a
pretended continuous run.
