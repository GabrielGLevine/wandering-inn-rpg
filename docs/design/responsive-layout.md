# Responsive layout

Issue #505. Physical browser observations remain open under #511.

## Shared rules

`WIResponsiveLayout` converts viewport rectangles through the live screen
transform. A texture's source size and a native window screenshot do not
establish its size in the browser.

- Coarse-pointer web contexts and native mobile use controls of at least
  44 × 44 CSS pixels. Important text starts at 14 CSS pixels, multiplied by
  the selected 100%, 115%, or 130% text scale. The minimum is applied after
  canvas scaling. Existing desktop type sizes and chrome remain the defaults.
- Layout reads the current viewport on resize. It resizes existing item rows,
  tabs, hotbar slots and selection labels, including while their panel is open.
- Web safe bounds intersect the canvas with browser `safe-area-inset-*`
  values. Native mobile/fullscreen uses the display safe area. A desktop
  window's position on its monitor is not a notch inset.
- Phone portrait entry uses the existing rotation prompt and resumes in
  landscape. This change does not introduce portrait gameplay.

## Field and panels

Field navigation occupies the top band; skills and the Details control occupy
the bottom band. The world viewport ends before those bands. The player camera
uses the remaining height, including in small interiors. Phone field details
start collapsed unless the player has saved a preference. Expanded details
scroll within a capped region and have a visible Hide details control.

Phone inventory and journal use the available width beneath navigation. Their
navigation chip reads Close while open. Inventory equipment replaces the item
list within its scrolling column; Hide equipment returns to carried items.
The selected item's icon, mechanics and description remain in the detail
column. Journal tabs retain separate touch regions. Scrolling inventory does
not equip or unequip an item.

Conversation text uses the available phone width and readable type. Long nodes
retain paging; options retain scrolling when needed. A conversation ends
through its authored choices, since choices may carry effects or commit a
fight. The continuation cue says to tap. Transient message strips use readable
phone type and fit above field controls and expanded details. Quest notices
reserve space above conversation panels so the speaker ribbon stays clear.

## Combat

Phone combat reserves a side panel for the active fighter, selected action,
action pages and explicit confirmation. Action pages retain the original slot
indices. No saved action or field skill is dropped to fit the screen. Field
slots stay compact; combat slots also show AP/MP costs.

The board keeps cells at least 44 CSS pixels across. Its camera follows the
active and inspected/target fighter when both fit, and prioritizes the inspected
or target fighter when their separation exceeds the available view. The arrows
cycle the roster or current targets; Back leaves inspection or targeting.
This deliberately shows part of a large arena instead of shrinking every cell.

Details provides paged Battle, Actions and Log views and a 44 CSS-pixel Close
control. Battle includes the full roster, turn order, HP/MP/AP, movement,
statuses and skills. A long name may be abbreviated in the compact active
summary; Battle retains its full text. Long tutorial notes provide More and
Close controls. Their full copy is also retained in the combat log.

Text fitting clears the previous label content before resizing its rectangle,
then paginates against the new area. Otherwise Godot's previous minimum height
can keep old text flowing over controls after a smaller viewport or larger
font. Geometry checks include text-versus-text and text-versus-control overlap.

The active-turn triangle uses a canvas primitive. In the local Godot 4.7.2
build (`ed1daf0bf`), [Polygon2D redraw](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/2d/polygon_2d.cpp#L387-L395)
reaches an [index-buffer update using the vertex-buffer target](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/storage/mesh_storage.cpp#L532-L543).
Showing details and resizing triggered WebGL binding errors on that path.
The primitive retains the triangle's points, color and lifecycle and avoids
the invalid update. The browser warning gate remains unchanged.

## Evidence boundaries

The browser registry exercises Chromium at 844 × 390 and 915 × 412 CSS pixels,
including a live shrink to 740 × 360 and restoration. Its iPhone and Android
profiles emulate viewport, user agent and touch capability; they are not
Safari/WebKit or physical-device tests. Existing portrait-entry checks run
before landscape play.

Geometry checks read live rectangles. Browser contacts must produce trusted
DOM touch events. A drag requires one continuous start, movement and end;
ordinary taps must have matching starts and ends. Each registry run requires
all expected script steps, no aborted result or failures, and its required
contact proofs. Screenshots provide the separate visual read.

Physical safe-area behavior, browser chrome changes, iOS Safari, actual Android
hardware and touch feel remain unproven until the shared #511 session. A
passing emulated profile does not close those acceptance clauses.
