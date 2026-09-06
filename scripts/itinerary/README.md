# Itinerary compiler (M3.6)

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

Since the 2026-08-14 ruling the tightening allowance covers a compiled-only
`wait_for_event` as well as `assert_*`: a wait the shipped script does not make
is the stricter claim, and it cannot hide — if the event never fires the run
does not finish. It runs ONE WAY. A compiled-only step of any other action is
extra behaviour and fatal; a SHIPPED-only step of any action is a claim the
compiler dropped and fatal; a compiled wait whose payload pin is a subset of
the shipped one is a loosening and fatal. Every reclassified row is printed
individually in its own report block, which the `--limit` truncation does not
apply to.

M2 accepts the whole frozen primitive set: `goto`, `talk`, `fight`, `sleep`,
`equip`, `unequip`, `buy`, `sell`, `use_field`, `interact`, `journal`, `shot`,
`assert`, `detour`, `raw`. Every node needs a stable `id`; every fork
(`choose_path`) needs a `why`. Unknown keys are rejected rather than ignored —
at the SPEC level (`fight: {encouter: x}`) and, since M3.6, at the NODE level
too. The node-level check is what catches a misspelled second primitive: a
`figth:` beside a valid `goto:` is not in the primitive set, so the
exactly-one-primitive count never saw it and the beat silently did not happen.

## The M3.6 frame keys (2026-08-13 amendment)

None of these is a new primitive. Each says which of an idiom's OPTIONAL rows
this particular beat has, which is a property of the world and not a
preference:

| Key | On | What it says |
|---|---|---|
| `entry: dialogue` + `npc` + `choose_path` | `fight` | The board opens on a conversation's own confirm, from a row whose effects carry `start_combat`. The fight node owns the walk; the emitter emits neither an approach press nor a panel teardown. |
| `turn_wait: false` | `fight` | This board carries no `turn_started {id: pc}` wait (6 of the corpus's 12 fights). |
| `beats: {before_turn: [...], after_combat: [...]}` | autoplay `fight` | Tutor-line beats around the policy handover. A driven fight places beats with `beat:` turn entries instead. |
| `expect_banks_after_dismiss: true` | `fight` | `resolve_combat()` runs on the banner dismiss, so the encounter's `on_victory` deposits are waited on BETWEEN that confirm and `ui_combat_hidden`. |
| `arena: <id>` | `fight` | Tightens the `combat_started` pin to the arena that opened. |
| `via: <door-id>` | `goto` | Which door the LAST leg takes. Two doors between the same pair of maps are both oracle-valid and arrive on different cells; the arrival is what the next press acts on (GH#375's west inn door). |
| `expect_render: true` | `goto` | Asserts `ui_map_rendered` for the destination — the presentation half of an arrival. |
| `expect_epilogue: true` | `sleep` | The run's last claim: `ui_sleep_veil_finished` then `ui_gdi_epilogue_rendered`. |

## Effect-derived event waits

A chosen dialogue option's `effects` array already moved the ledger; since M3.6
it also says what the game will ANNOUNCE while it does. The derivation mirrors
`WIGame.dialogue_choose`'s loop and its elif chain, and joins `quests.json`
through `scripts/itinerary/quests.py` so a counter that closes a beat drags
`quest_beat_completed`/`quest_completed` behind it. Placement is the engine's
order, not a preference: on a CLOSING row the announcements land after
`dialogue_ended`/`ui_dialogue_hidden` (because `choose()` emits the teardown
before returning the effects), and on a continuing row they land before the
destination `dialogue_node`. Get that backwards and every wait sails past the
forward-only since-cursor.

Toasts are deliberately not derived. The amendment enumerates the derivable
shapes as accomplishment / quest_started / beat / completed / item_gained, and
a toast is a presentation echo of an event already pinned; the purchase, sale
and prop idioms pin the toasts whose authored COPY is the claim.

## Sneak lifetime (#440)

`WISave` does not serialize `sneaking` — it is runtime-only, cleared by
`sleep()` — so the oracle can never be asked about a live stance and the
ledger carries the lifetime itself. A `use_field` on a `sneaks: true` Skill
toggles it (and the two directions announce different things); a fight, a
non-door interact and a sleep all drop it. While it is live the route planner
stops refusing walks that cross a proximity radius, because the engine's own
proximity pass `continue`s instead of springing.

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

## Band crossings that do not fight (#508)

`route._walk` refuses any path inside a proximity encounter's trigger radius
-- unless the engine would let it through. Two arms, mirrored from
`wi_game.gd`'s proximity pass: a live sneak (`use_field` on a `sneaks:true`
Skill) credits `sneaked_past_danger` and walks on; a served `cover_prop`
(`interact` on a `once_per_waking` prop banks `serve:<prop>` in the ledger's
`entity_first_use`, cleared at sleep like the sim) credits
`crossed_under_cover`. The walk then carries a `bypass_bank` op whose waits
the emitter pins right after the moves (the bypass toast rides the sneak
arm). `act_rogue.yaml` -> `qa/scripts/rogue_discovery_cut_route.json` is the
canonical: creation to [Rogue] to the first sneak with no fixture at all.

## Compiled canonicals are regenerated with the emitter

A shipped `qa/scripts/*.json` that is COMPILED from an act (today:
`act_rogue.yaml` -> `rogue_discovery_cut_route.json`) is an emitter output,
not hand-authored. Any change to `emit.py`, the planners or the ledger owes
a recompile of each one (`compile_itinerary.py <act> --out qa/scripts/<name>.json`)
and a real run of the result in the same PR -- otherwise the shipped script
silently drifts from the source itinerary (review finding, #434).

## Act I is at golden equivalence (2026-09-06)

`goldens.py` on a fresh `steel_thread.yaml` compile vs `qa/scripts/steel_thread.json`
reports NET 0 and EXACT == the shipped-only steps past the Act I seam (1,563):
nothing the itinerary authors is claimed differently from the corpus. The
vocabulary that closed the last rows: `talk.shots` (anchor -> screenshot taken
on the node that anchor opens), `equip.shot` (taken with the inventory open),
`sleep.expect_veil_lines` (donor-backed veil line count; not derivable), and
`ui_inventory_shown.items` derived from the inventory oracle. One Act I row
is still shipped-only: the ambush's `ui_hotbar_rendered {slots: 4}` logged
assert (an autoplay fight has no slot for it yet).

## Act II is at golden equivalence (2026-09-06)

Shipped steps 218-558 are authored in `steel_thread.yaml`; a slice diff of
that range reports 0 exact / 0 net, and the compiled Act I-II script runs
green headless at seed 37. What it took, and what a differ PASS does not buy:

- **A golden PASS is not a runtime PASS.** Compiled-only claims are
  "tighter" by policy, so a WRONG compiled-only claim never reds the diff.
  The first headless run of the PASSing slice timed out at the warrior
  sleep: the class-gained render was pinned BEFORE the veil and the veil
  fires first. Every emitter change ends with a headless run of the compile
  at the corpus seed (`--seed=37`; an empty `--seed=` is a different seed
  and the cistern nest LOSES at it).
- **Plain sleeps pin per gained class, never the whole dict.** A warrior
  that fought twice sleeps to level 3 on combat counters the ledger does
  not model; the corpus pins `classes.mage` alone. Only a merge pins the
  dict.
- **Alignment is a weighted LCS** (`goldens._align`), not difflib's
  longest-block matcher, which re-paired Selys' delivery with Olesm's brief
  when one arrival pin was inserted between them. Named shots, valued
  arrival pins, and map/combat/dialogue starts weigh more than presses.
- **Merged facing bumps** (`right 2` = one cell plus the bump into the
  encounter) are discounted only when the discount reconciles the two
  nets; `from_start` is ignored (delivery vs order, v0.15 lesson).
- Vocabulary: `fight.shots {approach: [...], turn: [...]}` (approach lands
  after the facing bump, before the entry press); a `goto` that names a
  walkable cell pins its arrival (the corpus's waypoints); dialogue grants
  claim the `Got: <name>` toast; the equip slot pin follows the panel
  close; the GH#167 tremor pointer is derived from the oracle preview
  (`reached_two_classes`, `tremor_pointer`) and emitted in
  `sleep_beat.gd` order (bank, quest start, sticky toast) before the veil.
- Slice diffs while later acts are unauthored: filter the compile by
  `_itin` prefix and the corpus by step range (Act I = `itinerary.start,
  act1.` over 0-218; Act II = `act2.` over 218-559). A `--slices` option on
  `goldens.py` is the open follow-up.

