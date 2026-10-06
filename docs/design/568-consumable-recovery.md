# Consumable recovery (#568)

The accepted issue extends food and potion stock without changing equipment,
quest or hotbar item identity. Core stays pure, with JSON catalog data and
versioned JSON saves. The inventory-system skill's Resource/slot rewrite would
break those existing contracts; counts beside the ordered unique-ID array are
the smaller compatible choice. Save-load uses the existing WISave owner and
capacity11 migration, followed by quantity schema12.

## Quantity checkpoint

`stackable: true` plus `consumable_family: food|hp_potion|mp_potion` is explicit.
Current declarations cover actual food, Mending Draught and Remedy Draught.
Preparation-only tools/draughts and quest medicine retain singleton identity.
`item_count(id)` returns owned units. `consumable_counts` has exactly one positive
integer per owned declared stack and no other keys; zero removes both carriers.
The storage ceiling is 2147483647, not a gameplay bag capacity. Finite whole JSON
numbers are accepted and normalized to integers; booleans/fractions are rejected.
Legacy saves receive one unit only after catalog lookup; modern corrupt counts
refuse transactionally. Repeated cooking remains governed by its existing Skill,
ingredient and waking gates; free food gains no sale price or new cooldown.

Grants/removals, shops, crafting, containers and sales preflight item changes.
Multi-step operations buffer their existing events until gold, stock, inputs and
one-shot state agree. Pre-combat checkpoint events remain synchronous and precede
choice effects. No event callback may save a half-completed stock transaction.

## Frozen frontend contract

The shared-use checkpoint implements these APIs:

- `WIItems.preview_use(item, context_snapshot, rules) -> Dictionary` is pure.
- `WIGame.prepare_item_use(item_id, context)` returns a deep-copied offer and
  registers its ephemeral `operation_id`. Context is `world` or `combat`.
- `commit_item_use(operation_id, confirm_risk=false)` returns a frozen result.
  A first harmful dose returns `confirmation_required` until deliberate confirm.
- `cancel_item_use(operation_id)` invalidates that operation with no effects.

Offer/result fields: `operation_id`, `item`, `context`, `source`, `allowed`,
`reason`, `confirmation_required`, `before`, `after`, `preparation_before`,
`preparation`, `count_before`, `count_after`, `ap_before`, `ap_after`, `ap_cost`,
`exposure_before`, `exposure_after`, `dose_number`, `restore_hp`, `restore_mp`,
`poison_hp`, `hp_lost` (actual bounded HP loss). Before/after contain hp/max_hp/mp/max_mp. Result additionally carries
`committed`; canceled/stale results report equal actual before/after values and zero deltas. Every dictionary is captured and deep-copied before publication.
A refusal consumes nothing, so no compensating refund is needed. Confirm compares
all relevant live resources, maxima, stock, preparation, actor/turn and context
with the offer. A stale operation is refused and invalidated, requiring a fresh
preview and deliberate activation. Duplicate or canceled tokens cannot recreate
an operation. Tokens are never saved and are invalidated on load/context change.

UI activation captures the displayed token, latches until result and input
release, and does not create a fresh token inside repeated queued callbacks.
Inventory Use and hotbar slot toggling remain separate reachable actions.
World lethal ingestion refuses; combat lethal ingestion follows normal defeat.
Rules are data-owned: three safe MP doses, four immediate HP loss thereafter,
one AP per combat potion. Healing and poisoning are separately advertised.
Only actual sleep clears exposure. Food stays outside combat.

The core owner publishes operation-linked quantity/use/exposure/poison events
plus compatible `resources_changed` and a settled use event for coherent saving.
Frontend owns inventory/combat controls, effect_text and warning/receipt render
confirmations; root owns authored QA and final window/browser evidence. #569 may
reuse the pure restorative plan and settled commit seam for service later; this
issue does not implement Inn service or new potion crafting.

## Evidence and remaining work

Focused quantities test proves JSON roundtrip/legacy migration, corrupt-load
transactionality, two purchases/one-unit sales, observed settled tuples, stock
exhaustion and container overflow refusal. Existing save, vitals-handoff and
simulation units pass. Logs: `/private/tmp/wi-568-evidence/quantities*`.
Earlier failed logs preserve obsolete schema/singleton expectations and one
corrected event-batch boundary error. Full units/canonicals/balance, actual input
routes, windowed proof and touch evidence remain for composed integration.


## Shared use and reward settlement

The production world/combat item paths use the same pure preview. The standalone
combat policy compatibility adapter also validates through it; its old full-HP
AP-spend expectation now explicitly refuses without cost. Existing HP items keep
`heal` as a compatibility alias beside authoritative `restore_hp` until the
standalone policy/item filtering surfaces are composed. No MP use is inferred
from that alias. Recovery rules are injected from progression.json.

Offer, cancellation, refusal, use result, exposure, poison and settled events
carry frozen operation data. UI constants are `ui_item_use_preview_rendered`,
`ui_item_use_warning_rendered`, `ui_item_use_warning_armed` and
`ui_item_use_rendered`. Event callbacks cannot mint/confirm a nested operation.
World settled uses and claimed rewards autosave only after state is coherent.

Overflow from fixed loot rolls now enters `pending_loot`, an array of bounded
unit records `{item,source,count:1}`. Entries retain each earned drop's source;
modern validation rejects malformed/nonstackable/unknown rewards before load.
JSON count values normalize to integers. Loot events distinguish rolled items,
actual delivered items and pending items; victory retirement completes before
banking events flush, while callbacks still see the finished combat. Existing
singleton duplicate semantics remain unchanged. `claim_pending_loot()` delivers
what fits once, retains the remainder and emits `loot_claimed`; it runs on world
transitions. Inventory should call it before building rows for immediate access.
Delivery accept/arrival/turn-in similarly expose only settled parcel/claim/gold
state, including during nested turn-in attempts.

Focused recovery/reward units pass: first-harm cancel/confirm, captured token
repeats, callback reentrancy, capped combined restoration, JSON/exposure, AP and
actor refusal, armor/shield/difficulty bypass, lethal combat, exact earned boss
loot overflow→reload→consume one→claim once, and nested delivery payout refusal.
Existing save, vitals_handoff, sim_core, combat_sim and combat_policies pass.
Evidence: `/private/tmp/wi-568-evidence/recovery*` and `rewards/` (the latter
preserves the initially failing JSON normalization regression). Numeric tuning
is unchanged from the accepted proposal. The real MP item/vendor and composed
frontend/QA/windows remain outstanding at this checkpoint.
