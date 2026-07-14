# Mobile-compatible web release — exploration (2026-07-12)

> Status: **IMPLEMENTED** by issues #105 and #106; retained as the exploration
> record. Current controls and QA commands live in `wandering_inn_game/AGENTS.md`.

User direction: explore, do not implement. Grounded in the shipped state
(mouse waves #57/#84/#85, the single-threaded web export, itch html5).

## What already works in our favor

- **Touch → mouse emulation is free.** project.godot carries no override,
  so Godot's default `emulate_mouse_from_touch = true` applies: taps
  already produce the click events every shipped mouse path consumes.
- **Click-to-walk + full menu coverage.** World movement (BFS pathing,
  adjacent-tap interact), dialogue options, hotbar, pause/title/settings,
  pickers, inventory, journal — all tap-operable today via emulation.
- **Single-threaded export = mobile-Safari-safe.** No SharedArrayBuffer
  requirement; the itch embed needs no special headers on mobile.
- **The 16:9 320x180 world** fits phone LANDSCAPE natively;
  canvas_resize_policy=2 adapts.
- **#77's text-scale machinery** is the natural lever for mobile
  readability (budgets re-measure live).

## The real gaps (severity-ordered)

1. **COMBAT IS TOUCH-BLIND for movement/targeting.** The mouse waves
   covered the hotbar slot clicks in combat, but grid movement and
   target/direction selection are keyboard-arrow flows (grep confirms:
   no board-cell click path in combat_screen/targeting_controller —
   world.gd's click-to-walk is field-only). A mobile player can fight
   only via... nothing. This is THE implementation item: tap-a-cell to
   move, tap-a-target to select, tap-confirm — the #75 aim-preview
   primitives already render the legality overlays a tap UI needs.
2. **Text entry (the name step) has no touch path.** #85 documented the
   NAME step's missing clickable commit (Enter-only), and the html
   export ships `virtual_keyboard=false`. Mobile needs: the virtual
   keyboard flag ON + a tappable Begin/commit control. Small.
3. **Hit-target sizes.** At 1280x720 on a ~390-CSS-px phone width,
   dialogue option rows and 16px-derived icons land well under the
   ~44px touch guideline. Options: a mobile UI-scale preset (the #77
   step machinery, plus larger row paddings), not a redesign. Audit
   surface-by-surface; the panels' wrapped-line budgets already
   re-measure, so scaling is mostly safe.
4. **No-hover UX.** Hover-moves-cursor menus degrade fine (tap =
   click), but hover-only affordances (slot-info readouts, hover
   highlights) need tap-once-to-focus/tap-again-to-commit or visible
   alternatives. Inventory/journal rows: verify per-surface.
5. **Orientation.** Portrait is unusable at 16:9; the web can't force
   landscape. Standard remedy: a rotate-your-device overlay (CSS/JS in
   the html shell or an in-game gate).
6. **Payload: 98 MB** (wasm+pck). Tolerable on wifi, hostile on data.
   itch serves compressed; a real size pass (audio bitrates, texture
   audit) is optional-later.
7. **Persistence caveats.** user:// on web = IndexedDB per browser;
   iOS Safari's ITP can evict storage for rarely-visited sites —
   saves/settings may vanish for infrequent players. Disclose on the
   itch page if mobile ships; the shipped-ids/save work doesn't change.
8. **Audio on iOS** needs the first-tap resume (engine-handled) — and
   #105 (the runner's audio blindness) means mobile audio is likewise
   untestable by automation until the real-server smoke lands.
9. **itch gating.** The "mobile friendly" flag on the itch dashboard
   must be ticked before mobile browsers even offer the embed — flip
   only after the above ship (user action, listed last deliberately).

## QA story
Playwright drives touch events natively (hasTouch contexts) — a
`touch_` DSL tier mirroring the click_ actions is straightforward once
#105's real-server runner lands (do them together; the fake-host
interception also breaks worklets for any touch run today).

## Shape + estimate (when scheduled)
- **v1 "playable on a phone in landscape" = M**: combat tap-move/
  tap-target (the one real feature), virtual keyboard + name commit,
  the rotate overlay, a hit-target audit pass with the scale lever,
  the itch flag last.
- **Mobile-first polish (portrait, size diet, PWA) = L, separate,
  probably never for the demo.**

## Recommended slot
After #105 (its runner rework is the QA prerequisite) and after the
class-foundation wave lands; before or with the demo-boundary decision
(mobile web is a demo-reach multiplier — the same seam).
