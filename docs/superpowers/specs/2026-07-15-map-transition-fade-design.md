# Map Transition Fade Design

> Status: **ACTIVE**

## Goal

Replace the field map hard cut with a 0.25-second black transition while
leaving simulation state, map-change events, and headless QA streams unchanged.

## Decisions

1. `WIMain` owns one persistent native-resolution `CanvasLayer` veil above the
   world and UI. It survives ordinary UI teardown and is hidden at boot/title.
2. `WIWorld` routes `MAP_CHANGED` rebuilds through
   `WIMain.transition_map(rebuild)`. The old field remains visible for a
   0.125-second fade to black; the callable rebuilds only at full cover; the
   new field then fades in for 0.125 seconds.
3. Main consumes all input while the transition is active. World also includes
   the transition in `_movement_gated()` so held movement and click paths
   cannot act against the already-changed sim while the old field is visible.
4. Headless and ordinary TestDriver runs collapse both waits and call the
   rebuild synchronously. No new domain event is emitted, so existing QA event
   logs and assertions remain unchanged.
5. A `--map-transition-visual` user argument opts a windowed TestDriver run
   into real pacing for screenshot evidence only. It changes timing, never
   state or event payloads.

## Visual and input contract

- The veil is solid black at the rebuild boundary and covers the full native
  viewport, including the field HUD; it never persists on title/character
  creation screens.
- Map interaction, field skills, journal/inventory/pause input, click-walking,
  and held movement cannot advance during the transition.
- Repeated transitions cannot overlap; the input gate makes a second player
  transition unreachable until the first completes.

## QA contract

- Source/unit contracts pin persistent-layer ownership, half-duration math,
  rebuild-at-black ordering, collapse rules, and input gating.
- Existing crossing canonicals retain their exact headless behavior.
- A focused `map_transition_fade` canonical crosses inn to street and captures
  a partially covered new-map frame plus a fully revealed frame when run
  windowed with `--map-transition-visual`.
- The final visual read checks full-screen cover, no old/new geometry mix,
  unchanged HUD placement after reveal, and no stuck black veil.

## Non-goals

- No sim, collision, path, door, save, audio, or map-data changes.
- No fades for title, combat-board appearance, dialogue, sleep, or defeat.
- No new transition setting or duration selector.

## Failure modes guarded

- Rebuilding before black recreates the hard cut beneath a cosmetic overlay.
- Leaving the veil inside ordinary UI teardown frees it during title/world
  swaps or places later UI above it.
- TestDriver pacing without an explicit opt-in slows the full canonical suite.
- Blocking only mouse input still permits keyboard/gamepad movement or menus.

## Exit

The focused and crossing gates are green, the opt-in windowed frames are read,
and #87's only remaining map-fade scope is complete.
