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
