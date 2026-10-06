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
