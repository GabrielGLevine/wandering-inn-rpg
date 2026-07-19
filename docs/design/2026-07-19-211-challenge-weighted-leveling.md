# #211 Challenge-weighted leveling — design (2026-07-19, Fable)

Design authority for the wave's largest sim package. User directives live
VERBATIM in #211's two comments (2026-07-18) — adversity-not-repetition,
and resolution-path-exclusive quest experience. This doc turns them into
mechanism. Implementation follows the #194a seam-3 banking extraction and
lands INSIDE that module; wi_game.gd is not re-touched.

## 1. Where the weight applies (the one deposit path)

Seam 3 extracts `resolve_combat`'s victory block + `_bank_action_tally` +
`_roll_loot` into a banking module. ALL combat-sourced counter deposits
already flow through `_bank_action_tally` (post-fight, from
`combat.action_tally["pc"]`) plus the `on_victory` records. The weight
multiplies THESE deposits only:

- weighted: every action-tally counter (`melee_hit`, `spell_cast`,
  `*_skill_used`, `ranged_hit`, …) and the LITERAL `won_combat` counter.
  REFINED AT IMPLEMENTATION (2026-07-19): `victories` (chronicle tally)
  and specific `on_victory` quest ids ALWAYS bank integer-unconditional —
  a fractional `cleared_the_nest` would break its quest gate; zero
  shipped quests key on `won_combat` (verified), so the XP lever loses
  nothing.
- raw (v1, per directive): non-combat pillars — Helper chores, social,
  craft, exploration, delivery, quest-path accomplishment banks. Canon
  adversity for those is an OPEN design question, deliberately out.

The existing binary precedent (`trivial` fights bank ZERO — kept, it
becomes weight 0) generalizes to a continuous factor:

```
deposit = base_amount * challenge_weight * repetition_decay
```

## 2. Challenge weight (enemy power vs player power)

Player power: `WIProgression.effective_power(classes, catalog)` — the
existing L^k-norm (power_k 1.55) that already backs bounty rank.

Enemy party power: **new explicit data field** `power_level` per
combatant record (class-level-equivalent scalar; party power =
effective_power over the enemy roster's power_levels using the same
norm). REJECTED deriving power from statlines (hp/str/weapon_die):
brittle proxy, silently shifts with every balance retune, and violates
tune-data-never-sim. Authoring pass covers ~50 combatants from the
region-tier table (#66 T1-T5); a `test_combat_data` tripwire requires
`power_level` on every roster member of every encounter.

Weight curve (all knobs in `data/progression.json`, new file, owned by
the classes catalog loader):

```
ratio = enemy_party_power / max(player_power, 1.0)
weight = clampf(pow(ratio, weight_gamma), weight_floor, weight_cap)
       with weight_gamma 1.6, weight_floor 0.0, weight_cap 2.0 (initial)
below-band (ratio ≤ gray_ratio 0.55): weight *= gray_scale (0.15)  # gray-out, not zero
par (ratio ≈ 1): ≈ 1.0    above-band: up to 2.0 (cap)
trivial flag (data): weight = 0 exactly (unchanged contract)
```

Initial constants are SIM-DERIVED at implementation (harness sweep, §6),
not hand-picked; the doc's numbers are starting points.

## 3. Repetition decay (per-encounter-id)

Kill count source: the encounter's first `on_victory` counter (already
banked once per win, per-encounter-id by construction — no new state).

```
decay = 1.0 / (1.0 + decay_rate * ln(1 + prior_wins))   decay_rate 0.9
```

Squirrel #100 at par: ln(101)*0.9 ≈ 4.15 → decay ≈ 0.19 → with a
below-band weight ≈ 0.15 the deposit rounds to ~0.03 of base — "a
hundred squirrels won't move the needle." A first Raskghar at ratio
1.4: weight ≈ 1.7, decay 1.0 → the needle moves. Both knobs data.

## 4. Fractional banking + save migration

Deposits become floats; accomplishments stay ints (everything reads
them: gates, quests, requires). New WIGame field
`fractional_bank: Dictionary` (counter → float accumulator in [0,1)):

```
acc = fractional_bank.get(counter, 0.0) + deposit
record_accomplishment(counter, floori(acc))   # only when ≥ 1
fractional_bank[counter] = acc - floori(acc)
```

Save `VERSION 6 → 7`; `_migrated` step: absent `fractional_bank` → `{}`
(old saves resume with empty accumulators — no retroactive reweighting).
Opaque-until-sleep holds: accumulators are NEVER rendered; toasts and
journal keep showing results only.

## 5. Resolution-path-exclusive quest experience

Directive: a significant quest resolved Diplomatically vs through Combat
feeds ONLY the resolving class line. Mechanism: quests with
`resolution_paths` gain per-path `resolution_grant` records:

```json
"resolution_grant": {"path": "talk", "deposits": {"parley_resolved": 6, "heard_gossip": 4}}
```

- Deposits route through the SAME weighted seam as one large "adversity
  deposit" at quest close, at a quest-authored `grant_weight` (par 1.0
  default; big arc closes may author higher) — repetition decay does NOT
  apply (quests are once-by-construction).
- Counters chosen per path feed that path's class line only (combat
  closes → combat counters, diplomatic closes → social counters, skill
  closes → the skill line's counters). The chunk is HEFTY: sized by the
  sim harness so a major quest ≈ several par fights of the same act.
- Pairs with b3's parley talk-downs: every converted encounter becomes a
  real build decision.

## 6. Acceptance harness (before any data tuning ships)

`tests/sim_progression_pace.gd` — scripted Act I→III traces through the
REAL banking seam + `WIProgression` sleep sequence (mirror-contract with
`WIGame.sleep()` order, `sim_class_paths` precedent):

- Archetype traces (combat-lane, social-lane, mixed) × acts, each a
  sequence of encounter wins (with real rosters' power_levels), chores,
  quest closes, sleeps.
- GATES: level bands at act boundaries (Act I end: PC total levels in
  [a1_lo, a1_hi]; likewise II/III — bands ratified against current
  shipped pacing before the weight lands, then re-derived); the #160
  funnel gates stay green (entropy ≥ 2.0, spellsword share ≤ 0.45);
  `sim_combat_batch` 0.55–0.95 bars untouched (weights don't change
  fight outcomes, only banking).
- Regression leg: weight=1/decay=1/grants-off config must reproduce
  today's counters EXACTLY (byte-identical accomplishments over a
  scripted trace) — proves the seam is a pure generalization.

## 7. Execution order (post seam-3)

1. Harness first (traces + bands at CURRENT behavior, weight off).
2. Weight + decay + fractional bank behind config (regression leg green).
3. `power_level` authoring pass + tripwire.
4. Sim-derive constants; tune to bands; CHOICE-LOG the chosen curve.
5. Quest `resolution_grant` authoring for the significant quests
   (cisterns, wrong_order, door chain, invrisil disagreement, delve,
   crate — the multi-path set); harness re-run.
6. Save VERSION bump + migration + `save_migration` QA leg.
7. Full bar + canonical seed re-checks (leveling cadence shifts CAN move
   canonical scripts that sleep-level mid-route — expect seed/pin
   re-derivations; budget for them).

## 8. CHOICE-LOG adjudications this doc makes (flag to user, reversible)

- Enemy power = authored `power_level` field, not statline-derived.
- Below-band gray-out is a scale (0.15), not hard zero — a level-2
  player still inches forward on easy fights; hard zero only via
  `trivial`.
- Old saves migrate with empty accumulators (no retroactive credit).
- Non-combat pillars stay raw-counted in v1 (directive-explicit).
- Quest grants skip repetition decay (once-by-construction).
