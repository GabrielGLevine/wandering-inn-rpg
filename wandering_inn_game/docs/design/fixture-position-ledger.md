# Fixture position ledger (issue #48, playtest directive item 9)

Authoring source for any future playtest-state fixture. Documents, for each
gate fixture rebuilt in this pass, the story position (what the player has
actually done to be standing here), the honest wealth math, and the
class/level rationale against combat tuning bands. `tests/test_fixture_coherence.gd`
is the validator that enforces the invariants this ledger derives; when
adding a new fixture, derive its numbers here FIRST, then write the fixture,
then run the validator.

## The `post_game` backbone

`post_game` is banked once, by `sleep_veil.gd`, on the first post-epilogue
sleep — it is Act III's own `seal_holds` beat condition (`data/acts.json`).
Structurally, `post_game` can never be true without every one of these also
being true (traced from `data/acts.json`'s act_i/act_ii/act_iii
`advance_when` chain + the climax quest chain that banks `raskghar_sealed`):

- `met_relc`, `sparred_with_relc`, `given_spear_by_relc` (the tutorial —
  `warrior` is `gained_by: sparred_with_relc`, and there is no route to
  Liscor that skips the spar)
- `reached_liscor` (Act I's own advance gate)
- `reached_two_classes` + 3 completed quests (Act II's advance gate —
  `quests_completed: 3` against `the_errand`/`missing_crate`/`cisterns`)
- `watch_runner_pointed`, `heard_the_deep_tremor`, `heard_olesm_briefing`,
  `cleared_the_warren`, `raskghar_sealed` (the climax chain)

Any fixture that carries `post_game` (or any `door_awakened`, since the
whole Magical Door side-arc is itself gated `requires: {post_game: 1}` on
Erin's beat-1 option, `data/dialogue/erin_errand.json`) must carry this full
backbone. The pre-#48 fixtures did not — this is the user's literal
"Riverfarm with zero classes" example, generalized: `door_awakening_start`,
`portal_menu_start`, and `near_riverfarm` were fully classless with none of
the backbone above; `door_chain_talk_start`/`door_chain_scout_start` carried
only the tutorial trio; `door_chain_fight_start` carried warrior5+mage5 but
none of the Act II/III backbone either.

## Honest wealth derivation

Reward amounts pulled directly from `data/dialogue/*.json` /
`data/zevara_intro.json` effect blocks (grepped, not estimated):

| source | amount | producer |
|---|---|---|
| the_errand courier's fee | +4g | `selys_delivery.json` "kept_reward" |
| Zevara bounty: crate | +3g | `zevara_intro.json` claimed_bounty_crate |
| Zevara bounty: cisterns | +4g | `zevara_intro.json` claimed_bounty_cisterns |
| Olesm cisterns report | +6g | `olesm_intro.json` cisterns_reported |
| Zevara bounty: warren | +10g | `zevara_intro.json` claimed_bounty_warren (needs `cleared_the_warren`) |
| wrong_order resolution tip | +3g | `lyonette_tip.json` |
| typical work-loop chores (~3 dirty_table uses) | +6g | `basic_cleaning` gold effect |

**Tier A — post_game, pre-door-chain-spend** (the honest total above,
rounded): **40g floor**. Used by `door_chain_talk_start`,
`door_chain_scout_start`, `door_chain_fight_start` — none of these three
have bought Krshia's `resonant_catalyst` yet (35g, `data/dialogue/
krshia_crate.json`), so the floor must clear that price with headroom.

**Tier B — post_game, post-catalyst-spend**: Tier A's 40g minus the 35g
catalyst = **5g floor**. Used by `door_awakening_start`, `portal_menu_start`,
`near_riverfarm` — all three have `bought_catalyst: 1` already banked.

**Tier 3 — near_garden's own leg set** (Act III reached via
`reached_two_classes` + 3 quests + 2-of-4 ratified legs, but NEVER touches
the Raskghar arc — no `raskghar_sealed`, no warren bounty — and never
touches the door chain — no catalyst spend): the_errand (4g) + crate bounty
(3g) + cisterns bounty (4g) + Olesm report (6g) + wrong_order tip (3g)
+ a couple of chores, rounds to **15g floor**. Used by `near_garden` and
`garden_unlocked` (same tier — the reveal itself costs nothing).

A fixture's exact `gold` value may sit above its tier floor (headroom is
fine, the invariant is a floor, not a pin) but must never sit below it.
`test_fixture_coherence.gd`'s `_gate_gold_floor` encodes these three tiers
exactly; if a future fixture needs a fourth tier, derive it here first.

## Class/level rationale vs. combat tuning bands

`sim_combat_batch.gd`'s `warrior5_mage5` build (10 total held levels,
split-efficiency ~0.78 per `WIProgression.power_multiplier`) is the ONE
tuned band that covers every fight `door_chain_fight_start`'s canonical
resolves to completion: `rift_vermin_leak_w8_relc` (gated 0.55-0.95) and
`ruin_guardian_w8_relc` (gated 0.55-0.8), both ally-fielded (`met_relc`
banked). Since `door_chain_fight_start` was ALREADY correctly built at this
band pre-#48 (only its story backbone was missing), and since the door-chain
septet + `near_riverfarm` narratively describe the SAME PC at different
points along the SAME side-quest arc, every one of them is now built at
`warrior5+mage5` — even the legs that never fight (talk/scout/awakening/
portal_menu/riverfarm), for narrative consistency, not tuning necessity
(their own canonicals route around combat entirely; see each fixture's
`_comment` for the documented leg it takes through the OR-gated
`door_understood` convergence — uniformly the TALK/SKILL leg for this whole
rebuilt family, which is why `rift_vermin_leak`/`ruin_guardian` stay
unfought/live and `removed_entities`/`dormant_encounters` stay empty
throughout).

`near_garden` keeps its own pre-existing, already-correct composition
(`warrior:5, helper:1, tactician:1` — "closest to right already" per the
brief) untouched; only gold/equipment/`times_slept` were topped up.
`garden_unlocked` (new) matches `near_garden` exactly plus the two flags the
reveal itself banks (`cleaned_the_inn`, `garden_door_unlocked`).

## Equipment

Every rebuilt Act-III+ position now equips `relcs_spare_spear` (`dmg_mod:
1`, spear family) instead of the starter `rusty_sword` (`dmg_mod: 0`) —
the spear the PC has carried since the tutorial gift (`given_spear_by_relc`
is in every rebuilt fixture's own backbone). Safe across the whole family:
`warrior`'s own level-1 grants include BOTH `power_strike` (sword-tagged)
and `piercing_strikes` (spear-tagged) — `WICombatBuild.weapon_gated_kit`
filters by weapon family, so switching families only trades one
weapon-tagged skill for its sibling, never drops the class below a fielded
kit. Re-verified live for the one fixture whose canonical actually resolves
combat off this equipment (`door_chain_fight_start` — both `rift_vermin_leak`
and `ruin_guardian` still land victories at the pinned rng_state after the
swap).

## Known, deliberately out-of-scope gaps (flagged for a follow-up, not fixed here)

- `near_act3`, `climax_surface_start`, `climax_sealed_start`,
  `deep_descent_start`, `near_ruin` all carry `gold == 0` at an
  Act-III-or-later position (the SAME gold-floor gap this pass fixed for the
  gate fixtures) — each is the fixture for a long whole-arc canonical
  (`arc_flow`/`climax_chain`/`climax_seal`/`deep_descent`), and none was
  named in issue #48's Part 3 scope. `test_fixture_coherence.gd`'s economy
  check is deliberately scoped to `GATE_FIXTURES` only for this reason.
- `near_invrisil` carries `post_game` without the rest of the Act-III
  backbone (`reached_two_classes`, the raskghar chain) — its own `_comment`
  LOCKS `classes: {warrior: 2}` to the `alley_footpads` combat-tuning
  baseline (measured at "warrior2 SOLO"); adding a second class to earn
  `reached_two_classes` would shift that already-measured win rate off-band.
  A real gap, deliberately not closed here — needs a dedicated
  combat-tuning pass (re-tune the alley_footpads band for a 2-class PC, or
  find another route to `reached_two_classes` that doesn't touch combat
  stats), not a fixture-data edit.
