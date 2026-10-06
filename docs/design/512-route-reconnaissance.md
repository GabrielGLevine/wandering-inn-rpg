# Continuous Rogue and generalist journey reconnaissance

Source reconnaissance for [#512](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/512),
inspected 2026-10-05 at `b1c4b02bee71ba0b0926bf1c466ad7eab65a80e6`.
The issue and [#513](https://github.com/GabrielGLevine/wandering-inn-rpg/issues/513)
were refreshed during inspection. All source references below describe that
snapshot. This is preparation, with no new runtime, balance, visibility, touch,
or completion evidence. Route candidates are not promises that their builds win.

#512 owns earned Rogue/generalist journeys and the cross-route report; #438
retains caster acceptance. #513 consumes their ledgers to investigate demonstrated
economy gaps. Final carried-resource acceptance consumes #566–#570 and the
composed #571 gate. The [resource plan](2026-10-05-persistent-vitals-recovery-plan.md)
does not authorize guessing potion prices, service prices, exposure values or
new scarcity rules. No compiler work is a prerequisite added by this document.

## Starting evidence

The following is a structural inspection of committed scripts and their
[manifest](../../wandering_inn_game/qa/manifest.json), not a rerun:

| Existing route | Fresh creation / no fixture or teleport | Recorded canonical seed | Scope |
| --- | --- | --- | --- |
| `rogue_discovery_cut_route` | Yes | 9 | Cover crossing, sleep acquisition, first real Stealth bypass |
| `rogue_discovery_watch_route` | Yes | 7 | Two cleaning wages, training, road victory, paid Watch recovery, Rogue sleep |
| `rogue_recovery_force` | Yes | 7 | Defeated road and force crate preserved; covered transit recovers acquisition |
| `rogue_recovery_guile` | Yes | 9 | Earned Warrior/Mage, road victory, Light crate, covered transit recovery |
| `steel_thread` | Yes | Manual seed 37, absent from manifest | Historical complete martial route |

Sources: [cut itinerary](../../scripts/itinerary/act_rogue.yaml),
[Watch](../../wandering_inn_game/qa/scripts/rogue_discovery_watch_route.json),
[force](../../wandering_inn_game/qa/scripts/rogue_recovery_force.json),
[guile](../../wandering_inn_game/qa/scripts/rogue_recovery_guile.json),
[steel thread](../../wandering_inn_game/qa/scripts/steel_thread.json).
The opening canonicals stop short of proving continued progression to an ending.

[generalist_loop](../../wandering_inn_game/qa/scripts/generalist_loop.json) tests
Mage balanced evolution with `near_generalist` and teleports; it is not the
social/work-heavy journey requested here. `social_loop`, `work_loop`,
`regional_work_loop`, `cisterns_talk`, `delve_talk` and alternate-ending scripts
are useful local seam references, but their fixture/teleport evidence cannot
establish this journey's acquisition or travel.

## Rogue identity and the growth bottleneck

[classes.json, rogue](../../wandering_inn_game/data/classes.json#L481) accepts
either `recovered_crate_watch >= 1` or `crossed_under_cover >= 1`; acquisition
resolves at sleep. Subsequent levels 2–10 require `sneaked_past_danger` counts
2, 4, 7, 10, 14, 18, 23, 29 and 36. The kit is Stealth at 1, Pick Lock at 2,
Find Trap at 3, Dangersense at 4, Disarm Trap at 5 and Sudden Strike at 7.

The [proximity check](../../wandering_inn_game/src/core/wi_game.gd#L494) requires
an actually present, gate-open, non-dormant, unwarded radius threat. While
sneaking, `danger:<encounter>` permits one growth credit per entity per waking.
Walking outside and back does not rearm it. Sleep clears first-use and dormant
state; ordinary day wrap does not. The separate covered-crossing path requires
this waking's deliberate cover-prop use plus transit; it awards entry credit
even after the road encounter is removed, never live-danger growth credit.

| Authored danger | Map, cell, radius | Availability constraint |
| --- | --- | --- |
| `goblin_encounter_1` | floodplains `(30,23)`, 2 | Removed after defeat; drainage cover alone does not retire it |
| `goblin_night_patrol` | floodplains `(7,21)`, 1 | Night; respawns |
| `road_mothbears` | floodplains `(23,12)`, 1 | Night; respawns |
| `river_wolf_pack` | riverfarm_village `(2,14)`, 1 | Night; removed after victory |
| `alley_footpads_a` / `alley_footpads_b` | mercantile_alleys `(9,9)` / `(14,12)`, 2 | Respawn until Brothers report removes both permanently |
| `boulevard_night_footpads` | invrisil_boulevard `(13,15)`, 1 | Night; respawns |
| `counting_room_guard` | mercantile_alleys `(5,10)`, 1 | Optional pocket; requires `counting_room_open` |
| `seal_warden_alcove` | trapped_halls `(19,6)`, 1 | Requires `read_the_feeding_ward`; bypass buys position, not an ending |

Sources: [floodplains](../../wandering_inn_game/data/maps/floodplains/floodplains.json#L1317),
[Riverfarm](../../wandering_inn_game/data/maps/riverfarm/riverfarm_village.json#L1551),
[alleys](../../wandering_inn_game/data/maps/invrisil/mercantile_alleys.json#L1063),
[boulevard](../../wandering_inn_game/data/maps/invrisil/invrisil_boulevard.json#L1455),
[warden](../../wandering_inn_game/data/maps/dungeon/trapped_halls.json#L654).

[Shipped phase thresholds](../../wandering_inn_game/data/moods.json#L4) are
dusk 400 and night 900 actions; [phase_for](../../wandering_inn_game/src/core/wi_game.gd#L3053)
gives night `[900,1300)` in a cycle of 1800. New routes must record the actual
clock and productive travel, not pad hundreds of no-op actions and label that
discovery. After fight-first acquisition the two early remaining radius threats
are night-only. This is an explicit pacing question, not a proven softlock.

Useful earned-kit opportunities include Pick Lock at the
[enchanter shop](../../wandering_inn_game/data/maps/invrisil/enchanter_shop.json#L222),
Find Trap in the [halls](../../wandering_inn_game/data/maps/dungeon/trapped_halls.json#L294),
and Disarm Trap salvage in the [sewers](../../wandering_inn_game/data/maps/sewers/sewers.json#L432),
[deep tunnels](../../wandering_inn_game/data/maps/sewers/deep_tunnels.json#L385),
[witch hollow](../../wandering_inn_game/data/maps/riverfarm/witch_hollow.json#L741)
and alleys. These uses do not replace the Rogue leveling counter. The warden's
authored `sneak_ambush` grants a concrete combat opening after a stealth approach.
Its fight remains mandatory.

## Candidate continuous routes

**Rogue primary:** preserve the cut opening: approach `(26,24)`, deliberately
use `gate_road_drain_cut` at `(27,24)`, transit to `(31,24)`, walk upstairs,
sleep, and use earned Stealth across the still-live band. Continue ordinary
Liscor errands, gathering real additional classes/gear needed for combat.
Record each distinct danger bypass before each sleep. Later, exercise earned
locks/traps and Invrisil stealth while its producers still exist; report the
Brothers job normally, accepting the loss of both alley producers. Finish with
an actual warden stealth opening and an explicitly selected authored ending.
The prefix is supported; later leveling, readiness, price balance and survival
remain unproven. Do not guarantee Rogue 5 or 7 at an act boundary.

**Rogue historical alternative:** preserve `rogue_recovery_force`'s training,
earned spear, defeated road, force crate and ordinary return. Use the approved
covered transit and sleep for acquisition, then investigate the remaining live
growth opportunities. Never restore the goblins, inject a counter, or silently
replace the history with an unfought road. The guile canonical is a separate
supported opening reference, not a second caster acceptance project.

**Social/work-heavy generalist:** clean the inn's `dirty_table` `(5,4)` using
starting Basic Cleaning, carry `serving_tray` `(10,2)`, then sleep for Helper
and Basic Cooking. Cook at `stew_pot` `(4,1)`, acquire `hot_meal`, and actually
serve available patrons. Use ordinary drainage-covered travel into Liscor.
The ungated `frazzled_drayman` `(19,14)` conversation supplies a free one-shot
`persuaded_someone`; three actual gossip first-talks plus sleep earn Diplomat.
Earned Charming Smile then supports Watch crate recovery and the cistern sweep.
This avoids the Warrior-intimidation assumption in older `social_loop` prose.

Sources: [inn work](../../wandering_inn_game/data/maps/inn/inn.json#L748),
[Helper](../../wandering_inn_game/data/classes.json#L314),
[Diplomat](../../wandering_inn_game/data/classes.json#L440),
[drayman placement](../../wandering_inn_game/data/maps/liscor/street.json#L1861),
[drayman option](../../wandering_inn_game/data/dialogue/drayman_dispute.json#L11),
[Watch crate](../../wandering_inn_game/data/dialogue/watch_crate.json),
[cistern sweep](../../wandering_inn_game/data/dialogue/zevara_intro.json).

Continue with honest serving, gossip, deliveries, regional work and supported
conversation branches, retaining an explicit combat preparation plan for the
deep tunnels, vault and finale. Cook needs five meals, Runner two completed
deliveries, and Trader five deliberate commerce actions before sleep acquisition
([classes](../../wandering_inn_game/data/classes.json#L605)); do not manufacture
those classes with undisclosed repetition. Watch resolution can incidentally
earn Rogue. Report the actual multiclass build rather than calling it pure.

The shared story skeleton comes from [acts.json](../../wandering_inn_game/data/acts.json):
arrival needs a class and Liscor; Act II advancement needs two earned classes
and three completed quests; Act III needs the warren report; Act IV needs the
forge rune, seal report, Riverfarm favor report and Brothers completion. Follow
each actual producer and ordinary door/portal through these gates. All three
final choices require warden victory in
[pisces_seal](../../wandering_inn_game/data/dialogue/pisces_seal.json#L88).
Neither candidate promises a pacifist ending or existing-policy victory.

## Travel and acquisition budget

[portals.json](../../wandering_inn_game/data/portals.json) gates inn↔Liscor on
`door_mounted`, Riverfarm on `door_awakened`, and Invrisil/Pallass/dungeon on
their earned attunements. Actual portal-menu use is earned travel; a QA
`teleport` is not. Before mounting, walk inn → floodplains → street and back.
Record sewer/deep-tunnel, ruin and dungeon travel instead of stitching fixtures.

| Fixed acquisition/fee in the complete regional chain | Gold | Authoritative option |
| --- | ---: | --- |
| Resonant catalyst | 18 | [Krshia charms](../../wandering_inn_game/data/dialogue/krshia_crate.json#L668) |
| Invrisil travel-stone | 18 | [Witch shop](../../wandering_inn_game/data/dialogue/riverfarm_witch.json#L290) |
| Pallass sponsorship | 10 | [Selys](../../wandering_inn_game/data/dialogue/selys_delivery.json#L416) |
| Pallass stone | 18 | [Krshia charms](../../wandering_inn_game/data/dialogue/krshia_crate.json#L690) |
| Pallass entry stamp | 2 | [Market clerk](../../wandering_inn_game/data/dialogue/pallass_market_clerk.json#L55) |
| Forge filing | 5 | [Forge clerk](../../wandering_inn_game/data/dialogue/pallass_forge_clerk.json#L165) |
| Fitness examination | 8 | [Grimalkin](../../wandering_inn_game/data/dialogue/pallass_grimalkin.json#L12) |
| Stamped pass | 3 | [Forge clerk](../../wandering_inn_game/data/dialogue/pallass_forge_clerk.json#L210) |
| Total | 82 | Pallass portion is 46 |

This is a source-derived cost subtotal, not a funded route ledger. Add the
chosen Watch crate fee (2g), cistern donation (3g), Pisces consult (5g), Cups
rumors (1g each), gear, recovery and any ending fee separately. Earned Charming
Smile avoids several fees; an available fight is a different cost/risk fork.
Sources: `watch_crate.hub`, `zevara_intro.sweep_argue`,
[pisces_magic.consult_talk_argue](../../wandering_inn_game/data/dialogue/pisces_magic.json),
[invrisil_fixer](../../wandering_inn_game/data/dialogue/invrisil_fixer.json).

## Imperfect histories and recovery candidates

Freeze baseline inputs, then change one declared choice and preserve it through
the blocker. Pin resources immediately before the blocked purchase, after the
earning/recovery action, and after the purchase succeeds; an eventual reward
somewhere in the run is insufficient for #513.

| Variant | Concrete difference | Required investigation |
| --- | --- | --- |
| Return Selys's reward | `gave_reward` pays 3g; keep pays 4g | Recover the actual 1g deficit, not an invented 4g loss |
| Buy an optional item | Copper luck band costs 4g | Keep the item and show a reachable remaining producer |
| Force crate after road victory | Road and crate fights stay completed | Covered acquisition, then real live-danger growth availability |
| Expose Coyle instead of extort | Forgoes the extortion option's 40g | Finance Pallass without silently changing the chosen outcome |

Sources: [Selys reward](../../wandering_inn_game/data/dialogue/selys_delivery.json#L295),
[luck band](../../wandering_inn_game/data/dialogue/krshia_crate.json#L578),
[approved force recovery](rogue-recovery-proposal.md),
[Coyle](../../wandering_inn_game/data/dialogue/invrisil_merchant_prince.json#L140).

Available content candidates, not guaranteed money already in the purse:

- Inn table wage and serving tray pay 1g each per waking. Repeated cleaning
  does not repeatedly pay; the table has `gold_once_per_waking`.
- [Selys board pick](../../wandering_inn_game/data/dialogue/selys_delivery.json#L269)
  pays 5g once per waking; check its hub gate and `board_pick:selys` first-use.
- [Zevara claims](../../wandering_inn_game/data/dialogue/zevara_intro.json#L210)
  pay 3/4/10g for crate/cistern/warren work, once each; prove the hub and unclaimed flags.
- [Olesm](../../wandering_inn_game/data/dialogue/olesm_intro.json) pays 6g for
  a cistern report, 5g for accepting the post-game survey and 15g on its report.
- [Riverfarm field board](../../wandering_inn_game/data/maps/riverfarm/riverfarm_village.json#L1637)
  at `(3,10)` pays 2g per waking. [Forge fetch slips](../../wandering_inn_game/data/maps/pallass/pallass_forge.json#L809)
  at `(18,4)` pay 2g per waking but cannot solve a gate that prevents reaching the forge.
- [Brothers hat job](../../wandering_inn_game/data/dialogue/invrisil_wilovan.json#L504)
  pays 25g for each supported terminal alternative, once for the job; the
  [stationer setting commission](../../wandering_inn_game/data/dialogue/invrisil_stationer_client.json#L278)
  also pays 25g. Prove continuous access, tasks and claims, not just catalog value.
- [Deliveries](../../wandering_inn_game/data/deliveries.json) pay 1–4g; prove
  posting, acceptance, real travel, parcel integrity and claim. Standing repeats
  must be disclosed as work. `delivery_boulevard_letter` pays 4g and its completed
  delivery enables Selys's free [Runner's Sandals](../../wandering_inn_game/data/dialogue/selys_delivery.json#L192),
  a Second Wind equipment source; it requires earned Invrisil access first.
- [Bounties](../../wandering_inn_game/data/bounties.json) mix delta and absolute
  conditions and rank-dependent payouts. `bounty_second_watch` and
  `bounty_alley_cull` use absolute conditions because producers can be exhausted.
  Inspect actual board availability/baselines before counting any payout.

Small repeatable jobs show a producer exists; they do not establish acceptable
pacing for repeated full-rest loops. The previously chosen job, sold item or
retired encounter may be gone. [Wilovan's report](../../wandering_inn_game/data/dialogue/invrisil_wilovan.json#L87)
permanently removes both alley footpads, including future sneak/loot opportunities.

## Food, potions and actual rest

This snapshot starts battles with full HP/MP
([combat construction](../../wandering_inn_game/src/core/combat/wi_combat.gd#L190)).
[WIItems](../../wandering_inn_game/src/core/items.gd) permits healing only in
active combat at 1 AP and next-fight preparation outside combat. It cannot
establish the future carried-resource survival or poor-player recovery claims.

- `mending_draught`: 8 HP; 10g at the [witch](../../wandering_inn_game/data/dialogue/riverfarm_witch.json#L331)
  or [Xif](../../wandering_inn_game/data/dialogue/xif.json#L14); guaranteed
  [awakened-boss loot](../../wandering_inn_game/data/maps/sewers/deep_tunnels.json#L379).
- `remedy_draught`: 8 HP; guaranteed [ruin-guardian loot](../../wandering_inn_game/data/maps/ruin/ruin_surface.json#L408).
  The inn's [mortar](../../wandering_inn_game/data/maps/inn/inn.json#L1374)
  requires held Hedge Remedy and a yarrow input. Crafting is not universal access.
- `hot_meal` is serving stock. Advanced Cooking at the inn chef counter yields
  `fine_meal`, currently +2 next-fight HP; Signature Dish at the copper pan yields
  `signature_meal`, currently +2 HP/+1 damage. [Items](../../wandering_inn_game/data/items.json)
  and [stations](../../wandering_inn_game/data/maps/inn/inn.json#L1396) distinguish
  acquisition, eating and serving. Preserve the approved repeatable kitchen and
  strongest-per-key #432 preparation caps; new food recovery belongs to #569.
- Free sleep props are [your_bed](../../wandering_inn_game/data/maps/inn/inn_upstairs.json#L202)
  `(9,1)`, [Riverfarm guest cot](../../wandering_inn_game/data/maps/riverfarm/riverfarm_longhouse.json#L284)
  `(8,4)`, and [Brothers guest couch](../../wandering_inn_game/data/maps/invrisil/brothers_parlor.json#L345)
  `(2,7)`. Reaching the couch crosses the alley region; test the chosen live-danger
  history. Player-room and garden beds have separate access conditions.

[Sleep](../../wandering_inn_game/src/core/wi_game.gd#L2807) changes more than
resources: it resets phase, stealth, social/first-use state and dormant encounters,
decrements wards, and returns an undelivered parcel. Log consequences and detours.
[Story sleeps](../../wandering_inn_game/src/core/sleep_beat.gd#L164) also advance
door awakening (three qualifying sleeps), second-door attunement (two) and the
existing capacity beat. Final #570 capacity must be taken from the composed build.

## Required ledgers and remaining acceptance

| Record | Minimum fields |
| --- | --- |
| Run identity | Build/tree, source state, seed, engine, overlay, route, creation choices, input timing, policy, evidence directory |
| Act checkpoint | Actual gate, map/cell, classes/levels, combined level, combat-relevant kit/effective-power basis, gold, equipment, inventory/quantities, sleeps, clock, quests and outcomes |
| Acquisition/spend | Actual input, giver/shop/station/job, item or class, prerequisite, cost/reward, before/after purse, domain event and rendered receipt |
| Each fight | Encounter/ally/companion, worn kit, entry/exit HP/MP, actual skills/casts and spends, potion quantity/exposure, food/preparation, AP costs, outcome, next reachable recovery |
| Sleep/recovery | Location, access route, carried-resource before/after, price, sleep count, expired/reset world state, parcel consequences |
| Imperfect variant | Changed choice, missing/retired producers, exact blocker, remaining recovery producer, detour/actions/sleeps, pinned successful continuation or unresolved finding |
| Player proof | Production input, domain event, matching rendered confirmation, asserted state, retained windowed screenshot and reviewer read; touch/device coverage separately labelled |

All ledger values beyond source-authored prices/gates are **unmeasured here**.
Combined levels are not effective power. Autoplay proves the exercised policy's
outcome, not player comprehension or actual manual use of the entire kit.

Next work is bounded: author Rogue and social prefixes with existing tools,
preserve force-crate and one imperfect-spend/reward history, then execute the
continuous journeys on the settled composed resource build. Use runtime/oracle
state to check actual bypass credit, wards, dormancy and removed producers.
Use the repaired #542 comparator only when claiming structural equivalence.
Keep canonical seed/build evidence and unresolved findings, without relaxing
assertions or retuning enemies to make the policy pass. #513 starts from these
frozen before-change inputs and ledgers, not an assumed funded route.

Historical [STEEL-THREAD.md](../../wandering_inn_game/qa/STEEL-THREAD.md) mixes
older 54g/82g cost summaries and finale results. Its consolidation-offer warning
is superseded by [current sleep processing](../../wandering_inn_game/src/core/sleep_beat.gd#L130),
which applies consolidation and continues the same sleep's story banks. Preserve
that document as historical evidence; derive new claims from current source and
new runs. This reconnaissance changes no source, route script, manifest, driver,
compiler, generated artifact, balance rule, canon choice or issue acceptance.
