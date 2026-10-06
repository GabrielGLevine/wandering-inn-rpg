# Meal recovery (#569)

The existing JSON dialogue walker and purchase confirmation own service flow.
`WIItems.preview_service` reuses the pure item restoration preview; no Resource
inventory, new dialogue framework, or saved field is added. A service projects
its optional well-fed maximum before restoration, but preserves the true prior
resources/preparation for receipts. This keeps waking +2 max HP distinct from
one-fight meal preparation and room bonuses.

## Authored recovery matrix

| Path | Restore HP / MP | Retained preparation / cost |
| --- | --- | --- |
| Hot Meal | 6 / 0 | No preparation; no resale price |
| Fine Meal | 8 / 4 | +2 max HP next fight; no resale price |
| Signature Meal | 10 / 6 | +2 max HP, +1 damage next fight; no resale price |
| Seared Venison | 6 / 0 | +2 max HP next fight; one-shot carcass |
| Early Inn meal | 6 / 4 | 3 gold; repeatable confirmed service |
| Existing late Erin meal | 6 / 4 | Existing once-per-waking gate; well-fed +2 max HP until sleep |
| Free Inn bed | Full resulting pools | Real sleep, progression and exposure reset |

Numbers are initial game tuning, not canon or economy validation. Flarepepper
Powder and synthesis/oil/cudgel preparation receive no inferred restoration.
Existing unlimited held cooking/station access, recipe ingredients, one-shot
outputs, strongest-per-key preparation and no food resale remain intact.

## Service and receipt contract

An ungated final Erin hub option, `Could I get something to eat?`, leads to
`meal_service`; old row indices remain stable, exact option arrays gain a row.
The service hub offers paid recovery, free-bed directions and an exit before
or after either errand reward. It requires neither a class nor cooking Skill.
The poor branch names the south-wall stairs and far-end upstairs bed. The
late seat retains its original relationship/story and `meal:erin` waking gates.

An effect `recovery: {restore_hp, restore_mp, well_fed?}` is restricted by lint
to one service per option with only gold/gate effects. Preflight rejects no
benefit before charges or gate banking. Paid offers capture their recovery
projection; confirmation revalidates it and the price/purse before committing.
Cancellation, stale confirmation and full-pool refusal change no resources,
stock or gates. Recovery charges never bank commerce/class accomplishments.
Synchronous purchase/resource/settled callbacks cannot reenter a choice.

`resources_changed` and `service_recovery_settled` carry frozen
`service: inn_meal`, `source: erin_errand`, `reason: dialogue`, `before`, `after`,
`preparation_before`, `preparation`, `restore_hp`, `restore_mp`, `gold_before`,
and `gold_after`. All gold/resources/waking state settle before callbacks.
The latter event fires after dialogue advances and triggers Game autosave.
Inventory eating continues to use #568's operation-linked item event contract.

## Checkpoint evidence and remaining acceptance

`test_meal_recovery` passes in `/private/tmp/wi-569-evidence/service-green`:
zero-gold non-cook service directions and real bed interaction, paid cancel,
settled callback/reentrant-confirm refusal, no-benefit revalidation, partial
restoration, waking meal gate/refusal/reset, held Basic Cooking at pot/kettle,
Advanced Cooking/Signature Dish at their actual station seam, capped repeated
food/preparation, missing Skill/station, no resale and JSON reload→eat.
Setup supplies held Skills/class/gold in unit cases; this is contract proof,
not earned acquisition or production-input/window proof. The first run caught
an incorrect unit assertion reading vitals outside WISave's state envelope;
its noisy log remains under `first`, and is not passing evidence.

Data lint and import pass. Affected dialogue, consumable recovery/counts,
simulation, content, shipped-ID, vitals-handoff, save, reachability and copy-fit
units pass under `compat`, `compat-fixed` and `content-extra`. The first content
run rejected the new effect until its explicit verb/schema validation was
registered; that failed log remains in `compat`. Expanded meal cases also prove
both errand reward poor branches, overflow without cooking-counter gain, and
authored no-output cookware. Authored UI routes, full units/canonicals/balance
and windows remain for composed integration.
Root owns QA and frontend composition; physical-phone/human evidence remains
separate. Unlimited kitchen recovery must be measured in #513/#453, not capped
silently to preserve a former full-rest baseline.

## Production-input QA scope

The canonical routes `meal_service_loop`, `meal_earned_cooking` and
`meal_station_loop` use production message timing and actual player controls.
The first uses disclosed pre-errand Mage1/depletion/6-gold setup: cancellation,
two paid meals (7 HP/0 MP → 13/4 → 19/8, gold 6 → 3 → 0), frozen receipts
rendered after dialogue closes, a poor purchase refusal, and the real stairs,
hall and free bed (32 HP/12 MP). QA dialogue deliberately jumps to its final
page; the full bed directions are domain-asserted, but the initial directions
page is not certified visible by this route.

The fresh route creates a character, cleans for one gold, walks to the bed,
earns Helper/Basic Cooking, opens the upstairs chest and equips its armor.
That creates headroom without healing (33/33 → 33/37), rather than simulating
combat injury. Held cooking at the stew pot and alternate kettle produces two
Hot Meals. Missing Skill, missing station and the authored no-output short
order add no food. Inventory eating restores exactly four HP and leaves one
meal; a second full-pool use keeps that unit. Only character creation resets
the game. This establishes real acquisition and consumption, not class-band
combat balance or an economy based on repeated wage farming.

The station fixture explicitly supplies Chef10/Mage1, held cooking Skills,
depletion and a legal station position; its class history is not earned.
Two actual Advanced Cooking casts produce two Fine Meals, both eaten for
8 HP/4 MP without stacking the +2 next-fight maximum-HP preparation. A walked
Signature Dish cast produces a meal whose use restores 10 HP and the remaining
4 MP, preserves +2 maximum HP and adds +1 damage preparation, with no potion
exposure. Actual manual save/load retains 33 HP/12 MP, preparation and empty
food stock. No merchant-resale trigger or combat consequence is claimed by
these routes; no-resale refusal and additional negative combinations remain
covered by `test_meal_recovery`.

Native headless input/render events establish the exercised wiring and timing,
not placement or touch-device acceptance. Controller-owned window/browser
reads, independent review and composed integration gates remain separate.
Rejected route drafts are preserved alongside final evidence, including the
headless CSS probe, last-page text, event-order/new-game reset, complete nested
receipt payload, and blocked kitchen traversal corrections. None changed
runtime behavior or relaxed a refusal.
