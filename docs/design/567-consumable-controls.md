# Consumable controls (#567)

The frontend preserves JSON item IDs and the ordered inventory list. Declared
stacks show a count in inventory rows, selected detail and combat item slots.
These quantities come from the simulation and refresh on item change events.
The first checkpoint stages this readout; runtime validation and shared-use
controls await the validated #568 API checkpoint.

Use and combat-bar membership will be separate reachable controls. Activation
captures the displayed item, operation and render generation. It cannot create
a fresh operation inside queued callbacks. The shared warning starts on Cancel
and waits for opening-input release before explicit confirm. A visible captured
inventory receipt or combat-feed receipt releases the operation latch without
waiting for an occluded global toast; the same operation is not later repeated
as another world receipt. Existing equipment queues are unchanged.

Godot UI/HUD/responsive patterns use existing themed Containers and layout
helpers. The inventory skill's Resource/grid rewrite is unnecessary here;
existing item, quest, hotbar and save identity stays intact. New frontend proof
will cover actual controls, stale/duplicate input, cancel/confirm and frozen
receipt fields before root-owned windowed/browser and composed QA acceptance.


The frontend now binds Use to the prepared item, operation and render generation.
Bar placement is a separate control. The shared message-layer presenter keeps the
operation latched until a captured in-panel/feed receipt has rendered and input is
released. First-harm confirmation defaults to Cancel and waits for input release
and a 300ms reading guard. In-panel receipts do not enter the world toast queue.
The phone status is inside the detail scroller, and the resource summary uses a
single compact line; this removes fixed blank status space from the content budget.

Focused production-control regression passes (Godot 4.7): two units consume once
per action, retired callbacks cannot consume the next row, bar placement does not
heal, cancellation preserves the full saved tuple, confirmed fourth mana dose
records HP/MP/exposure/count, and receipt text remains captured after live state
changes. Import is clean. This is native logical evidence; current browser layout,
actual pointer routes, combat rendered fit and physical touch remain unproven.


The composed checkpoint includes core/catalog206f36ac: pure previews do not replace
pending use tokens, and real Mana Potions appear in combat slots. Focused checks
also cover held confirm through receipt, core-driven AP refusal, MP recovery copy,
quantity labels and preservation of a selected token while inspecting another item.
Existing effect-text, resource-HUD and combat-visual units pass without engine noise.
The load gate passes with its result artifact. The controller owns the actual smoke
and full integration tiers plus new input QA; an attempted standalone `smoke` route
was rejected before gameplay because no such route exists.

Selectors for authored input are inventory `item_use_rect()`/`item_bar_rect()` and
message-layer `item_warning_cancel_rect()`/`item_warning_confirm_rect()`; the latter
is discoverable in group `wi_item_use_presenter`. Render events preserve frozen
core fields plus `text`/`surface`; previews add `generation`. Warning arming emits
`UI_ITEM_USE_WARNING_ARMED` only after release and the reading guard. These native
control tests do not establish the final combat feed fit or responsive touch path.


Review corrections retain the current operation for 300ms after its first actual
receipt render and until input is released. The live-button regression taps again
within 30ms plus three frames with three MP doses, checks one consumption, then
checks a deliberate later press. Keyboard Use on a refused no-benefit offer leaves
bar placement enabled. Both regressions exercise current control bindings.

Combat receipt proof now requires visible complete text after HUD refresh. A hidden
mobile desktop feed, or a clipped receipt, cannot suppress the shared visible
receipt panel; its actual Close button is exposed by `item_receipt_close_rect()`.
A production CombatScreen/HUD unit forces the touch-layout branch and checks the
visible fallback, captured text, close and rearm. The mobile rail uses item-specific
HP/MP recovery, AP, dose and poisoning copy instead of the Dash instruction. Native
injected-layout checks do not replace the controller's browser/touch proof.

Food/service core91bdac25 is composed. Item cards omit zero restoration fields and
reserve mana-poisoning warnings for declared MP potions. Exact hot/fine/signature/
seared-food lines and potion warnings pass the exhaustive effect-text contract.
The four affected focused units pass without noise on the composed corrections.
