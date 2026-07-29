# GH#330 — Beast Tamer dynamism + the no-treadmill cures (2026-07-29, Fable)

> Status: **ACTIVE** — executes now per user word (was v0.17 pool).
Authority: issue #330 + the no-treadmill principle (wi-adding-a-class-or-skill
:163, LAW). Recon: workflow wf_64c65766-734 (beast-system map + audit; facts
cited below are verified there with file:line).

## Design rulings (controller)

**R1 — The soothe becomes a real tend.** `corusdeer_range`'s existing
soothe option (requires [Animals: Basic Command], banks `soothed_a_beast`
+ `corusdeer_calmed`, makes the encounter dormant for the day) ALSO banks
`tended_beasts`. Calming a panicked animal is tending; the second function
(non-violent encounter resolution + forgoing the cull bounty) already
exists. Same pattern added to the razorbeak nest surface (one new soothe
option on its confront shape, same skill gate, banks the same pair).
Soothing vs culling stays a genuine economy choice — the cull bounties are
untouched.

**R2 — The hunter's lambs are the second class door.** New prop
`hunters_lamb_pen` at the hunter's post (riverfarm_village, cell chosen
against the walked-route union), present_when `{requires:
{thicket_answered: 1}}` — the R2 aftermath fiction made literal ("Two
lambs I lost this spring"; herd wintering at the north bend). Base
interact banks `soothed_a_beast` (a class entry OUTSIDE the floodplains —
today the wounded deer is the only door); variant (soothed >= 1) banks
`tended_beasts`; `beasts_mending` skill arm mirrors the deer's shape.
`once_per_waking`. Function beyond the counter: each tend yields a
`wool_tuft` item (new id, sells ~1g — item-yield is the economy-safe
shape per recon §7; the hunter's reactive pool gains one stage keyed on
10+ tends). No gold on the prop — the wage floor does not move.

**R3 — The deer's payoff arc.** At `tended_beasts >= 10` (the same
threshold that grants [Beast's Mending] — you learn to heal by healing
it), the wounded corusdeer's next tend banks `corusdeer_healed` (new
counter) with the arc's closing toast; thereafter the prop is ABSENT
(`{absent: {corusdeer_healed: 1}}` on present_when) and two things
replace it: (a) `worn_grass_patch` observe at [33,9] — the memory beat +
a ONE-TIME `shed_antler` pickup (new item, the canon antler-heat curio,
warm to hold; contains_when frozen_cache pattern); (b) `corusdeer_range`
gains a variant: with `corusdeer_healed >= 1` the soothe option's skill
requirement DROPS (the herd knows your scent — the healed deer vouches).
Permanent mechanical payoff, no numbers touched. Art: register the
existing `corusdeer_doe` walk-capable rig from
potential_assets/pixellab_2026-07-06/expansion_batch/ as the healed
stand-up frame at the final tend (windowed proof required).

**R4 — Companion overworld utility (the one engine seam).**
`_present_gate_met` gains a `companion` key: `{"companion": "<id>"}` —
entity present only while that companion rides (String match on
`WIGame.companion`; validator whitelist + test_content arm extended; the
closed-vocabulary discipline is WHY this is a spec'd seam and not a data
hack). Data on top:
- Wolf: `wolf_scent_cache` x2 (floodplains, riverfarm_village) — "the
  wolf noses at the turf" → digs up a small find (2-3g item or a
  lead-grade hint toast); variant-zeroed after first find
  (frozen_cache pattern, per-cache `found_*` counters, data-derived).
- Razorbeak: `razorbeak_vantage` x2 (floodplains, pallass_market) — it
  wheels up and marks what it sees: an information observe (real hint
  copy: where a cache/encounter/lead sits) + banks `observed_things`.
No skeleton utility (necromancy parked at Wave A). No combat changes,
no new boons — the kit and every gated cell stay untouched.

**R5 — Audit cures shipping in this wave.**
- `archery_butt` (TREADMILL, and an undecayed `ranged_hit` spigot): gains
  `once_per_waking` + each practice yields one `loose_arrow` (new cheap
  item, ammo-flavor consumable-to-sell); counter unchanged.
- The 7 produce-benches (4 cook + 3 alchemy, THIN "banks on repeat with
  no payload"): the v0.16.1 brew-arm contract generalized — the counter
  banks ONLY when the output pickup succeeds. No counter on a dup-refusal.
- Accepted-THIN, no change (logged): dirty_table/serving_tray (real inn
  chores, wage + serve chain), [Charming Smile] befriended arm (the
  friendly_line IS social texture).
- TREADMILL cure for the deer itself is R2+R3 (it stops being the sole
  producer AND stops being eternal).

**R6 — Deferred, filed as follow-ups, NOT built here:** the companion
dead-end (both tame props one-shot + death permanent = a save can
exhaust all bonds forever; fix sketch: bank `companion_lost` on the
downed-clear, spring litters gated on it — needs its own issue since it
adds a bare code literal + new dens); pond/stable surfaces; any
[Beast's Mending] combat context.

## Constraints (binding on the implementer)
- Ladder thresholds UNTOUCHED — no-treadmill means richer paths, not
  faster levels. Pace harness + sim_class_paths re-run; deltas recorded
  in the PR body (the harness already models 2-3 tends/waking vs the
  world's 1, so alignment should move p50s little or not at all — if
  helper/warrior/caster p50s move, STOP and report).
- beast_tamer_loop/tamer_bond_loop pin toasts verbatim — the deer's
  EXISTING arms keep their strings; the arc lands via NEW variants
  (later-satisfied-wins) and the absent gate.
- corusdeer_calmed stays exactly as shipped (frozen, zero consumers —
  R1 does not re-semanticize it, it just keeps banking).
- New counters (`corusdeer_healed`, `found_*` per cache) and items
  (`wool_tuft`, `shed_antler`, `loose_arrow`) are data-derived /
  catalog entries — zero STRUCTURAL_LITERALS churn. Freeze names at
  first write.
- Economy: zero new gold-bearing once_per_waking props (wage floor 9g
  stands); item yields priced so no craft-guard trips; census budget
  ~120 chars per _comment.
- Every new player-facing surface gets canonical coverage (the R4 gate
  needs a companion-present/absent pair leg); windowed shots for the
  healed deer, the lamb pen, both cache/vantage finds.
- The R4 seam extends: sim + validator whitelist + test_content arm +
  a can-fail unit proof, one commit.
