extends CanvasLayer
## Inventory panel -- carried items + the equip slots (weapon/armor/three
## accessories). Toggled by the `inventory` action (`I`).
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): inventory only opens when combat is
## inactive, no dialogue is open, no consolidation offer is pending, and
## BOTH the pause menu and the journal are closed (mirrors journal.gd's
## `_can_open` against pause_menu_ref, extended with a matching check
## against journal_ref). world.gd wires `pause_menu_ref`/`journal_ref` after
## creating all three components, so no scene-tree lookup is needed;
## world.gd itself gates movement/interact on `inventory.open`, and
## journal.gd/pause_menu.gd are each extended with the matching
## `inventory_ref`/`open` check so all three field panels stay mutually
## exclusive.
##
## List grammar: arrows navigate the carried list (dialogue_panel.gd's
## cursor/rebuild-rows pattern -- "> " mark, wrapi wraparound), Enter
## equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped there. Game.sim.equip/unequip do the kind/
## possession validation. A plain carryable item of an unequippable kind
## (e.g. tools) gets its own neutral toast here (Game.sim.equip() would
## silently refuse with no message of its own); every other equip()/
## unequip() false return is either a real, already-self-toasting refusal
## from WIGame (the two accessory refusals: slot-full, over-capacity --
## mirrored into this panel's own `_status_label` too, because the toast
## layer used to draw BEHIND this panel, see below) or prevented entirely
## by `_equipped_slot_for` routing an already-equipped item to unequip()
## instead of a duplicate equip() call.
##
## Layer 10 -- same reasoning as journal.gd's file doc comment: WIWorldLabels
## is created lazily by world.gd AFTER Main._spawn_ui_layers() adds this
## panel, so an explicit higher layer is required to paint over world-space
## name labels regardless of add order.
##
## The carried list is NAME-ONLY per row (plus the "[Equipped]" marker) --
## lore/description live in a SELECTION-DRIVEN detail column beside the list
## (`_detail_box`, built in `_ready()`'s HBox `body`), refreshed by
## `_render_detail()` on every cursor move / rebuild. The MECHANICAL read
## (dice/HP/DR/resonance/worth -- WIEffectText's stat-rule-safe currency,
## which this card used to inline) lives in a SEPARATE selection-driven
## corner at the panel's top right -- previously blank space beside the slot
## rows (`_corner_box`, built alongside them in `_ready()`'s `top_row`),
## refreshed by `_render_corner()` in lockstep with `_render_detail()` from
## the SAME `_rebuild_items` call site off the SAME `_item_ids[_cursor]`, so
## the two columns can never show different items. That corner also carries
## the selected item's icon (`assets/icons/items/<item_id>.png`,
## PATH-BY-CONVENTION -- a missing file degrades to no icon, no error, no
## fallback chip; see `_icon_texture_for`). Lore now reads as flavor purely
## through PLACEMENT (its own row, between the name and the description) and
## STYLING (the `"Lore"` theme type variation, wi_ui_theme.tres -- dimmer/
## desaturated brown at Small's font size, distinct from both the solid dark
## name text and Small's description-prose look). `_rendered_effect_lines()`
## (the `ui_inventory_shown` payload's `item_effect_lines`, one array per
## CARRIED item in list order) is unchanged and independent of where the
## effect lines are drawn on screen; `selected_icon`/`mech_line` are
## additive payload fields for the CURSOR's own selection, carried on BOTH
## `ui_inventory_shown` (opens + gold/equip re-confirms ONLY -- it drives
## the `ui_open` chime, see `_emit_shown`'s AUDIO TRAP note) and the
## per-cursor-move `ui_inventory_selection_rendered` (see
## `_emit_selection`).
##
## `_scroll`'s `mouse_filter` is left at Control's own default (`STOP`, not
## `IGNORE`) so real mouse-wheel/drag scroll input actually reaches the
## ScrollContainer; `ensure_control_visible` on cursor move remains the
## primary keyboard-driven navigation path. Both scroll containers (`_scroll`
## for the list, `_detail_scroll` for the detail column) run
## `vertical_scroll_mode = SCROLL_MODE_SHOW_ALWAYS` so a visible scrollbar
## affordance is always on screen whenever there's more to see.

## Widened so the carried list (name-only rows) and the selection-driven
## detail column both get comfortable width side by side -- see the HBox
## body built in `_ready()`.
const PANEL_SIZE := Vector2(860.0, 560.0)
## Fixed width of the LEFT (carried-list) column; the detail column on the
## right takes whatever's left of the content area.
const LIST_WIDTH := 240.0

## Corner-icon source art is 32px square (assets/icons/items/*.png, PixelLab
## batch); rendered at an INTEGER scale so TEXTURE_FILTER_NEAREST stays crisp
## (no soft/blurry pixel art). 2x (64px) -- not 3x (96px) -- judged against
## the panel's real corner space: the slot-info column beside it
## (`_slots_box`) measures ~150-160px tall (6 label rows at the theme's 14px
## default font + 10px stack separation), and a 64px icon plus the
## breakout box (reserved for up to 3 lines, the real current max across
## data/items.json -- see `CORNER_BREAKOUT_RESERVED_LINES`) comfortably
## shares that band; 96px would push the corner meaningfully taller than the
## slot column it sits beside for no legibility gain at this panel size.
const ICON_SOURCE_PX := 32
const ICON_SCALE := 2
const ICON_DISPLAY_PX := ICON_SOURCE_PX * ICON_SCALE
## Path-by-convention for a carried item's corner icon -- derived from the
## item id, never a data field, so adding an item needs no icon-wiring
## beyond dropping the PNG here. A missing file is a graceful no-icon
## degrade (see `_icon_texture_for`), never an error or a fallback chip.
const ICON_DIR := "res://assets/icons/items/"
## Fixed reservation for the breakout box's height (same "reserve real
## metrics for the true current max, not a guess" idiom as
## `STATUS_LABEL_RESERVED_LINES` below) -- 3 lines covers every shipped item
## today (e.g. traveler_charm's HP + Resonance + Worth lines together).
## TRAP: this is a RESERVE, not a clamp -- there is NO runtime guard, so an
## item whose card generates a 4th simultaneous effect line silently GROWS
## the box past the reservation (custom_minimum_size is a floor, and the
## lines VBox renders every line regardless), shoving the layout below it.
## Adding a 4th line-producing field to any items.json entry (or a new arm
## to WIEffectText.item_effect_lines) means bumping this constant in the
## same change.
const CORNER_BREAKOUT_RESERVED_LINES := 3
## Symmetric content margin inside the breakout box's carved-panel background.
const CORNER_BREAKOUT_MARGIN := 10

## Extra bottom clearance reserved for `_scroll` alone (via a fixed-height
## spacer sibling, see `_ready()`), on top of the panel's uniform 34px
## MarginContainer margin. The panel's PARCHMENT_PANEL art (Banner_Vertical.png,
## 9-sliced via UIChrome.PARCHMENT_REGION) has a decorative bottom curl whose
## onset sits between local y508 and y536 of the 560px-tall panel; the
## previous clip edge (local y526) sat below the curl onset in several
## columns, so a card line rendering at the clip edge drew onto the fold.
## 30px of spacer moves the clip edge to local y496, 12px clear of the
## earliest curl pixel. Same class of fix as message_layer.gd's
## `TOAST_FOLD_DANGER_PX`/combat_hud.gd's readout budget: reserve real
## pixels measured off the art, not a guessed round number.
const SCROLL_BOTTOM_INSET := 30.0

## True while the inventory panel is visible; world.gd/journal.gd/
## pause_menu.gd gate on this.
var open := false

## Set by world.gd right after all three field-panel components are
## instantiated.
var pause_menu_ref: Node = null
var journal_ref: Node = null

var _root: Control
var _title_label: Label
var _gold_label: Label
var _weapon_label: Label
var _armor_label: Label
## One row per accessory slot (index 0/1/2 -> accessory_1/2/3), same
## styling/precedent as the weapon/armor rows above.
var _accessory_labels: Array[Label] = []
## Mirrors the most recent TOAST while this panel is open (see
## `_on_domain_event`). Needed because the toast layer (message_layer.gd)
## used to draw BEHIND this panel's `layer = 10`; a toast fired while the
## panel was open rendered under the opaque parchment. message_layer's toast
## panel now lives on its own CanvasLayer at layer 12 (above this panel's
## 10 -- see message_layer.gd's TOAST_CANVAS_LAYER doc comment), so the
## toast itself is fully visible again even while this panel is open. This
## echo stays anyway (belt-and-braces, single-sourced from the same TOAST
## payload).
var _status_label: Label
## Fixed number of wrapped lines reserved for `_status_label`'s row -- see
## `_reserve_status_label_height()` below for the bug this fixes and why a
## FIXED reservation (not a per-message resize) is the right shape.
const STATUS_LABEL_RESERVED_LINES := 2
## Stored so `_rebuild_items` can scroll the cursor row into view: without
## this, the tail of a long carried list is logically selectable (the
## cursor still moves) but never actually visible via keyboard navigation.
var _scroll: ScrollContainer
var _items_box: VBoxContainer
## The selection-driven detail column beside the list -- see
## `_render_detail()`.
var _detail_scroll: ScrollContainer
var _detail_box: VBoxContainer
## The selection-driven corner beside the slot rows (top right of the panel,
## previously blank) -- the selected item's icon plus a mechanical breakout
## box, kept SEPARATE from `_detail_box`'s lore/description. See
## `_render_corner()`.
var _corner_icon: TextureRect
## Carved-panel-backed breakout box; hidden whenever the selected item has
## no mechanical lines (a plain item's corner then shows only its icon --
## no empty chip floats where the box would have been).
var _corner_breakout: Control
var _corner_lines_box: VBoxContainer
## The selected item's breakout lines joined for the QA payload (`" | "`
## separated, `""` when none) -- cached by `_render_corner` so
## `_emit_shown`'s `mech_line` reads the exact rendered fact instead of
## recomputing it a second time.
var _corner_mech_line := ""
var _item_ids: Array[String] = []
var _cursor := 0
## Parallel to `_item_ids` (same index order) -- populated fresh by every
## `_rebuild_items()` call, issue #84's hover/click rect scan target
## (`UIChrome.control_index_at`, WIHotbar's per-bar-not-per-row idiom: ONE
## `gui_input` handler on `_items_box` itself, ANY manual wheel-scroll
## handling included, rather than a filter per row -- a per-row STOP would
## swallow wheel events before `_scroll` ever saw them).
var _item_labels: Array[Label] = []
## Mouse-wheel scroll step (px) for `_on_items_gui_input`'s manual
## `_scroll.scroll_vertical` adjustment -- roughly 2-3 rows at this panel's
## row pitch, a plain reasonable increment (no QA pins the exact value).
const WHEEL_SCROLL_STEP := 48


func _ready() -> void:
	# See the file doc comment: must outrank WIWorldLabels regardless of
	# scene-tree add order.
	layer = 10
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	# STOP (mouse-filter audit, issue #57): see journal.gd's identical fix's
	# doc comment. `_scroll` (built below) already defaults to STOP on its
	# own (its own doc comment), but the panel's border/padding OUTSIDE the
	# scroll rect was still IGNORE-passthrough until this -- this closes
	# that gap too.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)

	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var content := MarginContainer.new()
	UIChrome.full_rect(content)
	UIChrome.add_margins(content, 34, 36, 34, 34)
	_root.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	content.add_child(stack)

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(220.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_title_label = UIChrome.make_label("", "Header")
	_title_label.text = "Inventory"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_title_label)
	ribbon.add_child(_title_label)

	# Top row: the slot-info column (LEFT) beside the selection-driven corner
	# (RIGHT -- previously blank space, see file doc comment). Same
	# separation as the list/detail body HBox below for a consistent gutter.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	stack.add_child(top_row)

	var slots_box := VBoxContainer.new()
	# Fixed to LIST_WIDTH purely so this column lines up visually with the
	# carried list below it -- no functional coupling to that list.
	slots_box.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	top_row.add_child(slots_box)

	# Diegetic coin line: the panel header, NOT an always-on HUD (Global
	# Constraint: gold shows in toasts + this panel only). Default
	# dark-on-parchment Label, same styling reasoning as the slot rows below.
	# "Gold: N" is literal text (no BBCode), so no `_bb_escape` is needed.
	_gold_label = UIChrome.make_label("")
	slots_box.add_child(_gold_label)

	# Two slot rows, pinned top. Default Label styling (dark brown on
	# parchment -- journal.gd's proven body convention), NOT the "Menu"
	# variation: Menu's light-tan/outlined styling is designed for
	# pause_menu's DARK carved panel and reads nearly background-flat on
	# this parchment, inverting the reading hierarchy.
	_weapon_label = UIChrome.make_label("")
	slots_box.add_child(_weapon_label)
	_armor_label = UIChrome.make_label("")
	slots_box.add_child(_armor_label)
	# Three accessory rows, same default dark-on-parchment styling as
	# weapon/armor above ("Menu" reads background-flat on this panel).
	for i in 3:
		var accessory_label := UIChrome.make_label("")
		slots_box.add_child(accessory_label)
		_accessory_labels.append(accessory_label)

	# RIGHT: the selection-driven corner -- icon on top, mechanical breakout
	# box below it. SIZE_EXPAND_FILL takes whatever width top_row has left
	# past slots_box's fixed column (the panel's real corner space -- see
	# ICON_SCALE's doc comment for the numbers).
	var corner_box := VBoxContainer.new()
	corner_box.add_theme_constant_override("separation", 8)
	corner_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(corner_box)

	_corner_icon = TextureRect.new()
	_corner_icon.custom_minimum_size = Vector2(ICON_DISPLAY_PX, ICON_DISPLAY_PX)
	# Same expand/stretch pair as hotbar.gd's own icon TextureRect precedent
	# (EXPAND_IGNORE_SIZE so the source texture's own size never overrides
	# custom_minimum_size in the container's layout; KEEP_ASPECT_CENTERED --
	# equivalent to a plain scale here since the source is square).
	_corner_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_corner_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Nearest-neighbor, not the engine's default linear filter -- the source
	# is 32px pixel art scaled by an INTEGER factor (ICON_SCALE); linear
	# filtering would soften an integer pixel-art scale into a blur.
	_corner_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corner_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_icon.hide()
	corner_box.add_child(_corner_icon)

	# The breakout box: a CARVED_PANEL background (the same dark-panel
	# chrome pause_menu/title_screen use), SEPARATE art from the parchment
	# card behind it -- the visual cue that this is a distinct mechanical
	# read, not part of the lore/description card. Hidden entirely whenever
	# the selection has no mechanical lines (see `_render_corner`), so a
	# plain item's corner shows only its icon, never an empty chip.
	_corner_breakout = UIChrome.make_texture_panel(UIChrome.CARVED_PANEL)
	var breakout_margin := MarginContainer.new()
	UIChrome.full_rect(breakout_margin)
	UIChrome.add_margins(breakout_margin, CORNER_BREAKOUT_MARGIN, CORNER_BREAKOUT_MARGIN, CORNER_BREAKOUT_MARGIN, CORNER_BREAKOUT_MARGIN)
	_corner_breakout.add_child(breakout_margin)
	_corner_lines_box = VBoxContainer.new()
	_corner_lines_box.add_theme_constant_override("separation", 2)
	breakout_margin.add_child(_corner_lines_box)
	corner_box.add_child(_corner_breakout)
	# Real-metrics fixed reservation (same idiom as
	# `_reserve_status_label_height` below) -- must run after this subtree
	# is parented under the themed `_root`, or the font lookup would resolve
	# against the engine default theme instead of wi_ui_theme.tres.
	_reserve_corner_breakout_height()

	# In-panel refusal echo (see the var's doc comment above). The row always
	# reserves a fixed height regardless of text -- see
	# `_reserve_status_label_height()`'s doc comment.
	_status_label = UIChrome.make_label("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status_label)
	# Must run AFTER add_child: theme lookups below need the label already
	# inside the themed tree (this panel's `_root` carries `UIChrome.
	# apply_theme`), or they'd silently resolve against the engine default
	# theme instead of `wi_ui_theme.tres` and reserve the wrong height.
	_reserve_status_label_height()

	# Carried list (LEFT) + selection-driven detail column (RIGHT), side by
	# side -- see the file doc comment's redesign note.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)

	# LEFT: the carried list, in a ScrollContainer as the overflow safety net
	# for a full catalog with no stacking. Rows are NAME-ONLY (+ "[Equipped]"
	# marker) -- mechanical/lore/description detail lives in `_detail_box` on
	# the right, and `_rebuild_items` scrolls the cursor row into view every
	# rebuild so the safety net stays genuinely reachable by keyboard, not
	# just non-clipping. mouse_filter left at Control's own default (STOP,
	# not IGNORE) so real mouse-wheel/drag scroll input actually reaches the
	# container, and `vertical_scroll_mode` forced SHOW_ALWAYS for a
	# persistent visible scroll affordance.
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	# No horizontal size flag override -- Control's own default (SIZE_FILL,
	# not EXPAND) means the HBox gives this column exactly its
	# custom_minimum_size width and hands all the EXTRA width to the detail
	# column's SIZE_EXPAND_FILL sibling instead.
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	body.add_child(_scroll)
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 4)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Issue #84: ONE hover/click/wheel handler on the row container itself
	# (see `_item_labels`' doc comment) -- individual row Labels stay
	# `UIChrome.make_label`'s default IGNORE.
	_items_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_items_box.gui_input.connect(_on_items_gui_input)
	_scroll.add_child(_items_box)

	# RIGHT: the detail column for whatever item the cursor is currently on
	# -- also scrollable (same mouse_filter/scroll-mode fix as the list) as
	# a safety net for a long description/lore combination at this column's
	# narrower width.
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	body.add_child(_detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(_detail_box)

	# See SCROLL_BOTTOM_INSET's doc comment above: a fixed-height spacer
	# AFTER the body row, same "shrink the EXPAND_FILL sibling" trick
	# `_reserve_status_label_height` uses above it in this same VBox --
	# shrinks the body's own rect without touching the MarginContainer's
	# uniform margin (which also positions the title/gold/slot rows --
	# those read fine; only the scroll columns' OWN clip edge sat inside the
	# parchment's art-safe band).
	var scroll_bottom_spacer := Control.new()
	scroll_bottom_spacer.custom_minimum_size = Vector2(0.0, SCROLL_BOTTOM_INSET)
	scroll_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(scroll_bottom_spacer)

	# Live coin-line refresh: the same domain_event idiom field_hotbar/
	# dialogue_panel use -- if the panel is open when gold changes,
	# re-render the line (and re-confirm) rather than only on open.
	ObservableBus.domain_event.connect(_on_domain_event)


## Reserves a FIXED row height for `_status_label` up front, from real font
## metrics -- never derived from whatever text happens to be showing. A
## `Label` with `AUTOWRAP_WORD_SMART` reports only its SINGLE-LINE height
## from `get_minimum_size()` (word-wrap depends on the final rect width,
## which isn't resolved yet when the container asks for minimum size), so
## VBoxContainer would otherwise reserve exactly ONE line for this row no
## matter how long the text gets -- a 2-line refusal message's 2nd line
## would render outside the reserved row, overlapping the scrolled item
## list's first row beneath it. Fix: reserve STATUS_LABEL_RESERVED_LINES
## (2 -- covers every refusal copy WIGame emits today with zero slack left
## over) of REAL line-pitch height (font height + theme `line_spacing`
## between lines -- `Font.get_multiline_string_size` alone does NOT include
## the spacing, the same trap `_toast_panel_height_for` in message_layer.gd
## already works around) via `custom_minimum_size`, fixed at `_ready()` time
## and NEVER recomputed per message. A fixed reservation -- not a dynamic
## resize keyed to the current text -- means the scroll area's start
## position is identical whether the echo is empty, one line, or its max,
## with no resize/layout-timing race to guard.
func _reserve_status_label_height() -> void:
	var font := _status_label.get_theme_font("font")
	var font_size := _status_label.get_theme_font_size("font_size")
	var line_spacing := float(_status_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	var height := STATUS_LABEL_RESERVED_LINES * pitch - line_spacing
	_status_label.custom_minimum_size = Vector2(0.0, height)


## Same real-metrics-reservation idiom as `_reserve_status_label_height`
## above, applied to the breakout box: a transient probe Label (never
## rendered -- added under `_corner_lines_box` only long enough to resolve
## real font metrics off the live theme, then freed) sizes
## `_corner_breakout` for CORNER_BREAKOUT_RESERVED_LINES up front, so the
## corner's height never jitters as the cursor moves across items with
## different line counts (0 to the reserved max).
func _reserve_corner_breakout_height() -> void:
	var probe := UIChrome.make_label("", "Menu")
	_corner_lines_box.add_child(probe)
	var font := probe.get_theme_font("font")
	var font_size := probe.get_theme_font_size("font_size")
	var line_spacing := float(probe.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	_corner_lines_box.remove_child(probe)
	probe.queue_free()
	var lines_height := CORNER_BREAKOUT_RESERVED_LINES * pitch - line_spacing
	_corner_breakout.custom_minimum_size = Vector2(0.0, lines_height + CORNER_BREAKOUT_MARGIN * 2)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if not open:
		return
	if type == WIEvents.GOLD_CHANGED:
		_refresh_gold()
		# Re-confirm the drawn state (bus convention), carrying the live total.
		_emit_shown()
	elif type == WIEvents.ITEM_EQUIPPED or type == WIEvents.ITEM_UNEQUIPPED:
		# equip/unequip changes the slot rows AND the Resonance header
		# (neither rides on GOLD_CHANGED) -- same re-confirm-on-relevant-
		# domain-event idiom as the gold case above, so a QA script can
		# assert the post-equip resonance total without having to
		# close/reopen the panel.
		_refresh_slots()
		_emit_shown()
	elif type == WIEvents.TOAST:
		# See `_status_label`'s doc comment above -- kept belt-and-braces
		# even though the toast layer itself is fully visible again over
		# this panel. A refusal toast fired while the panel is open (the
		# only toast source reachable while it is, since world input is
		# gated shut) still gets its own visible copy in here,
		# single-sourced from this same payload.
		_status_label.text = String(payload.get("text", ""))


## The `ui_inventory_shown` re-confirm payload, shared by `_open()` and the
## domain-event re-renders above so the two never drift. `cursor_scroll`
## (2026-07-08 hotfix) is `_scroll.scroll_vertical` at emit time -- a real
## RENDERED fact (like every other `ui_*_shown`/`ui_*_rendered` payload
## field), not sim state, so QA can assert the on-open first-row-visible
## fix honestly (gear_loop/00: full pack open must land at scroll 0, or
## row 0's own cursor mark is off-screen with nothing to prove it happened).
## `selected_icon`/`mech_line` (ADDITIVE, inventory-corner design) are the
## same kind of real-rendered-fact field for the CURSOR's own selection
## specifically: `selected_icon` mirrors `_corner_icon.visible` (true only
## when `_icon_texture_for` actually resolved a texture), `mech_line` mirrors
## `_corner_mech_line` (the breakout's lines, `" | "`-joined, `""` when the
## selection has none) -- both read state `_render_corner` already set,
## never recomputed a second time, so the payload can't drift from what's
## drawn. AUDIO TRAP -- this event carries the `ui_open` panel-open chime
## (data/audio.json), so it must fire only on real opens and the sparse
## gold/equip re-confirms above, NEVER per cursor move; per-move corner
## confirmation goes through `_emit_selection()` below instead.
func _emit_shown() -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_SHOWN, {
		"items": _item_ids.size(),
		"gold": Game.sim.gold,
		"item_effect_lines": _rendered_effect_lines(),
		"resonance": {"used": Game.sim.resonance_used(), "capacity": Game.sim.resonance_capacity},
		"cursor_scroll": _scroll.scroll_vertical,
		"selected_icon": _corner_icon.visible,
		"mech_line": _corner_mech_line,
	})


## The per-cursor-move confirmation that the selection corner redrew --
## DISTINCT from `_emit_shown()` (see its AUDIO TRAP note; the
## UI_JOURNAL_LOADOUT_RENDERED idiom) so navigating the list never replays
## the panel-open chime. Same real-rendered-fact contract: `selected_icon`/
## `mech_line` read the state `_render_corner` just set, `cursor`/`item`
## name the selection they describe.
func _emit_selection() -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_SELECTION_RENDERED, {
		"cursor": _cursor,
		"item": "" if _item_ids.is_empty() else String(_item_ids[_cursor]),
		"selected_icon": _corner_icon.visible,
		"mech_line": _corner_mech_line,
	})


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		if not event.is_action_pressed("inventory"):
			return
		if not _can_open():
			return
		_open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("cancel"):
		_close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	if Game.sim.combat != null or Game.sim.dialogue != null:
		return false
	if not Game.sim.pending_consolidation.is_empty():
		return false
	if pause_menu_ref != null and bool(pause_menu_ref.get("open")):
		return false
	if journal_ref != null and bool(journal_ref.get("open")):
		return false
	return true


func _open() -> void:
	open = true
	_cursor = 0
	_refresh()
	_root.show()
	_emit_shown()


func _close() -> void:
	open = false
	_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_HIDDEN, {})


func _move_cursor(delta: int) -> void:
	if _item_ids.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _item_ids.size())
	# A refusal echo belongs to the selection it refused -- clear it on
	# navigation so it never lingers over a different item.
	_status_label.text = ""
	_rebuild_items()
	# Confirm the redrawn corner via the DISTINCT selection event, NEVER
	# `_emit_shown()`: audio.json keys the `ui_open` panel-open chime on
	# ui_inventory_shown, so a shown-per-cursor-move emit replays that chime
	# on every arrow press (18 chimes walking a full pack; WIAudio's 60ms
	# cooldown only suppresses held-key repeats) -- a defect QA can't hear,
	# since event pins are existence-only. The selection event carries the
	# corner's own facts so QA still pins them per move.
	_emit_selection()


## Returns the slot name `item_id` currently occupies ("weapon", "armor",
## or one of the three accessory slots), or "" if it isn't equipped
## anywhere. `Game.sim.equipped` keys accessories by their REAL slot name
## (`accessory_1`/`_2`/`_3`), never the generic "accessory" kind -- a plain
## `equipped.get(kind, "")` lookup (fine for weapon/armor, where kind IS
## the slot name) silently misses every equipped accessory. Without this,
## re-confirming an already-equipped accessory calls `equip()` again
## instead of `unequip()`, which the duplicate-slot guard then silently
## refuses (no toast) -- so the panel's "toggle equip/unequip on confirm"
## grammar never actually works for accessories.
func _equipped_slot_for(item_id: String, kind: String) -> String:
	if kind == "accessory":
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(Game.sim.equipped.get(slot_name, "")) == item_id:
				return slot_name
		return ""
	if String(Game.sim.equipped.get(kind, "")) == item_id:
		return kind
	return ""


## The rendered text for carried-list row `i` -- "> "/"  " cursor mark + name
## + "  [Equipped]" tag -- factored out of `_rebuild_items()`'s creation loop
## (issue #84) so `_refresh_row_marks()` can recompute just the text of an
## already-built Label without tearing it down (a hover shouldn't destroy the
## very node the mouse is currently over).
func _row_display_text(i: int) -> String:
	var item_id := String(_item_ids[i])
	var rec: Dictionary = Game.sim.item(item_id)
	var name := String(rec.get("name", item_id))
	var kind := String(rec.get("kind", ""))
	# Was `String(Game.sim.equipped.get(kind, "")) == item_id`, which only
	# ever matched weapon/armor (kind IS the slot name for those two) -- an
	# equipped ACCESSORY never tagged "[Equipped]" since `equipped` has no
	# "accessory" key at all, only accessory_1/_2/_3. `_equipped_slot_for`
	# checks the real slot set.
	var equipped_here := _equipped_slot_for(item_id, kind) != ""
	var mark := "> " if i == _cursor else "  "
	var tag := "  [Equipped]" if equipped_here else ""
	return "%s%s%s" % [mark, name, tag]


## Rewrites every row Label's text from the CURRENT `_cursor` -- no node is
## freed/recreated (see `_row_display_text`'s doc comment).
func _refresh_row_marks() -> void:
	for i in _item_labels.size():
		_item_labels[i].text = _row_display_text(i)


## Issue #84: moves the cursor to `i` WITHOUT the full `_rebuild_items()`
## teardown -- used by mouse hover (which must not destroy the row Control
## currently under the cursor) and by a click just before it calls
## `_confirm()` (so the corner/detail columns are in sync even on a fresh
## click with no prior hover motion). Mirrors `_move_cursor`'s side effects
## (clear the stale refusal echo, re-render detail/corner, emit the
## selection-rendered event) minus the scroll-into-view call `_move_cursor`
## needs for keyboard's non-local jumps -- a hovered/clicked row is already
## on-screen by construction.
func _hover_cursor(i: int) -> void:
	if _item_ids.is_empty() or i < 0 or i >= _item_ids.size():
		return
	if i == _cursor:
		return
	_cursor = i
	_status_label.text = ""
	_refresh_row_marks()
	_render_detail()
	_render_corner()
	_emit_selection()


## Issue #84: hover highlights a row (`_hover_cursor`, the SAME `_cursor`
## field keyboard Up/Down drives -- one selection state), wheel scrolls the
## list, and a left-click routes through `_confirm()` -- the exact function
## Enter calls. Manual wheel handling (not passthrough to `_scroll`): this
## container is STOP so it can distinguish row clicks from bare list
## scrolling; PASS-ing wheel through to whatever ancestor Control picks it up
## next isn't guaranteed, so `_scroll.scroll_vertical` is adjusted directly.
func _on_items_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover_idx := UIChrome.control_index_at(_item_labels, (event as InputEventMouseMotion).position)
		if hover_idx >= 0:
			_hover_cursor(hover_idx)
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - WHEEL_SCROLL_STEP)
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll.scroll_vertical += WHEEL_SCROLL_STEP
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var idx := UIChrome.control_index_at(_item_labels, mb.position)
	if idx < 0:
		return
	_hover_cursor(idx)
	_cursor = idx
	_confirm()


## Equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped in that slot.
func _confirm() -> void:
	if _item_ids.is_empty():
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var kind := String(rec.get("kind", ""))
	if kind != "weapon" and kind != "armor" and kind != "accessory":
		# Carryable non-equippable kinds (e.g. tools) reach here --
		# Game.sim.equip() would silently refuse (invalid kind, no toast of
		# its own) with no player feedback at all, so the panel owns this
		# one neutral message. Every OTHER equip()/unequip() false return
		# below already carries its own diegetic toast from WIGame, or is
		# prevented entirely by routing an already-equipped item to
		# unequip() instead of a duplicate equip() attempt (the helper
		# above) -- this is the only reachable "no toast yet" case left.
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "That isn't something you can equip."})
		return
	var equipped_slot := _equipped_slot_for(item_id, kind)
	var ok: bool = Game.sim.unequip(equipped_slot) if equipped_slot != "" else Game.sim.equip(item_id)
	if not ok:
		# Defensive only (see above) -- a real refusal already emitted its own
		# diegetic toast (mirrored into `_status_label` by `_on_domain_event`,
		# kept belt-and-braces per that var's doc comment); nothing left to
		# surface here, and emitting a second generic toast on top would
		# double up on the sim's own message.
		return
	_refresh()


func _refresh() -> void:
	# Clear any lingering refusal echo -- a fresh open or a just-succeeded
	# equip/unequip both mean whatever the message was about is no longer
	# the live state.
	_status_label.text = ""
	_refresh_gold()
	_refresh_slots()
	_rebuild_items()


## The effect lines drawn on each carried item's card, one entry per item
## in `_item_ids` order (parallel to the list the panel renders), carried
## on the `ui_inventory_shown` payload so QA can pin the exact generated
## strings the player sees. Same WIEffectText source the card rendering
## uses, so the payload can never drift from the drawn card.
func _rendered_effect_lines() -> Array:
	var out: Array = []
	for item_id: String in _item_ids:
		out.append(WIEffectText.item_effect_lines(Game.sim.item(String(item_id))))
	return out


## The header carries BOTH visible currencies on one line -- "Gold: N" plus
## "Resonance N/M" (the visible-currency tier for the accessory budget).
## Same diegetic-panel-only surface as gold (Global Constraint: no
## always-on HUD); plain text, no BBCode, so no `_bb_escape` is needed here
## either.
func _refresh_gold() -> void:
	_gold_label.text = "Gold: %d     Resonance: %d/%d" % [Game.sim.gold, Game.sim.resonance_used(), Game.sim.resonance_capacity]


func _refresh_slots() -> void:
	_weapon_label.text = "Weapon: %s" % _slot_display("weapon")
	_armor_label.text = "Armor: %s" % _slot_display("armor")
	for i in 3:
		var slot_name := "accessory_%d" % (i + 1)
		_accessory_labels[i].text = "Accessory %d: %s" % [i + 1, _slot_display(slot_name)]


func _slot_display(slot: String) -> String:
	var item_id := String(Game.sim.equipped.get(slot, ""))
	if item_id == "":
		return "—"
	return String(Game.sim.item(item_id).get("name", item_id))


## Rebuilds the carried-item rows from `Game.sim.inventory` fresh every call
## (cheap; no stacking). Each row is NAME-ONLY (+ "[Equipped]" marker) --
## lore/description live in the selection-driven `_detail_box`, the
## mechanical read + icon live in the selection-driven corner (`_corner_box`)
## -- `_render_detail`/`_render_corner` both called at the end of this
## function, off the same cursor, so neither can drift out of sync with the
## highlighted row or with each other. After rebuilding, scrolls the
## cursor's row into view (see `_scroll`'s doc comment).
func _rebuild_items() -> void:
	for child: Node in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	_item_labels.clear()
	_item_ids = Game.sim.inventory.duplicate()
	if _cursor >= _item_ids.size():
		_cursor = max(_item_ids.size() - 1, 0)
	if _item_ids.is_empty():
		_items_box.add_child(UIChrome.make_label("Nothing carried."))
		_render_detail()
		# Empty inventory -> the corner is empty too (no icon, no breakout,
		# no placeholder chip) -- see `_render_corner`'s own empty-list guard.
		_render_corner()
		return
	var cursor_row: Control = null
	for i in _item_ids.size():
		# Default dark-on-parchment Label, same reasoning as the slot rows
		# above ("Menu" is a dark-panel variant). The "> " cursor mark stays
		# legible as dark text on the light parchment.
		var name_label := UIChrome.make_label(_row_display_text(i))
		_items_box.add_child(name_label)
		_item_labels.append(name_label)
		if i == _cursor:
			cursor_row = name_label
	_render_detail()
	_render_corner()
	if cursor_row != null:
		if _cursor == 0:
			# Row 0 is always the correct top-of-list on a fresh `_open()`
			# (`_cursor` resets to 0 there) -- scroll to it DIRECTLY rather
			# than through `ensure_control_visible` below. That helper reads
			# `_items_box`'s row geometry, which is unreliable on the very
			# FIRST rebuild after `_items_box` goes from zero rows to a full
			# batch (playtest evidence: gear_loop/00 -- full-pack open left
			# row 0 scrolled out of view entirely, no ">" cursor mark
			# anywhere on screen). Scroll 0 needs no geometry read at all, so
			# it can't race the container's own layout pass.
			_scroll.scroll_vertical = 0
		else:
			# A FRESH rebuild (every child freed and recreated above) needs the
			# VBoxContainer's own queued sort to actually run before its rows'
			# rects are trustworthy -- a single `call_deferred` hop can still race
			# that queued sort (confirmed empirically: after a full rebuild, one
			# hop left the view scrolled to wherever it was BEFORE the rebuild,
			# not at the cursor's fresh row). Deferring the deferred call gives it
			# a second idle-time hop, past the container's own layout pass.
			var row := cursor_row
			(func() -> void: _scroll.ensure_control_visible.call_deferred(row)).call_deferred()


## Renders the RIGHT-column detail card for whatever item the cursor is
## currently on -- name (+ "[Equipped]" marker, "Header" variation, same
## on-parchment precedent as dialogue_panel.gd's speaker label), the lore
## line (UNLABELED -- no "Lore — " prefix; it reads as flavor purely through
## placement below the name and the "Lore" theme type variation's dimmer
## styling), and the wrapped description prose. LORE/DESCRIPTION ONLY -- the
## mechanical read (previously inline here) now lives in the selection
## corner's breakout box (see `_render_corner`, called in lockstep from
## `_rebuild_items` off the same cursor), so the two can never drift apart
## or double up the same line. Called at the end of every `_rebuild_items`
## (cursor move, open, or a post-equip/unequip refresh) so the detail column
## can never show a different item than the highlighted list row.
func _render_detail() -> void:
	for child: Node in _detail_box.get_children():
		_detail_box.remove_child(child)
		child.queue_free()
	if _item_ids.is_empty():
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var name := String(rec.get("name", item_id))
	var kind := String(rec.get("kind", ""))
	var equipped_here := _equipped_slot_for(item_id, kind) != ""
	var tag := "  [Equipped]" if equipped_here else ""
	var name_label := UIChrome.make_label("%s%s" % [name, tag], "Header")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(name_label)
	# The lore line, UNLABELED (no "Lore — " prefix) -- the mechanical read
	# used to render directly above this (now the selection corner's own
	# breakout box, SEPARATE by user design -- see `_render_corner`), so this
	# card is name -> lore -> description only. The "Lore" theme type
	# variation (wi_ui_theme.tres) is dimmer/desaturated relative to both the
	# solid dark name text and "Small"'s description-prose look below, so it
	# reads as flavor through styling + placement alone.
	var lore := String(rec.get("lore", ""))
	if lore != "":
		var lore_label := UIChrome.make_label(lore, "Lore")
		lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(lore_label)
	# "Small" (12px, default dark color -- proven on parchment by the footer
	# hint strip) keeps the name row visually senior to its prose.
	var desc_label := UIChrome.make_label(String(rec.get("description", "")), "Small")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(desc_label)


## Renders the selection-driven corner (top right of the panel, previously
## blank) for whatever item the cursor is currently on: the item's icon (if
## one exists -- see `_icon_texture_for`'s graceful no-icon degrade) and the
## mechanical breakout box (the SAME `WIEffectText.item_effect_lines` source
## `_rendered_effect_lines`/`_render_detail` used to inline, so this can
## never drift from the QA payload's `item_effect_lines`/`mech_line`
## entries). Both halves hide independently: no icon file -> `_corner_icon`
## stays hidden (no fallback chip); no mechanical lines -> `_corner_breakout`
## stays hidden (no empty box). Called in lockstep with `_render_detail`
## from `_rebuild_items`, off the same cursor.
func _render_corner() -> void:
	for child: Node in _corner_lines_box.get_children():
		_corner_lines_box.remove_child(child)
		child.queue_free()
	if _item_ids.is_empty():
		# Empty inventory -> the corner is empty too, per design (no
		# placeholder chip for either half).
		_corner_icon.hide()
		_corner_icon.texture = null
		_corner_breakout.hide()
		_corner_mech_line = ""
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var icon := _icon_texture_for(item_id)
	_corner_icon.texture = icon
	_corner_icon.visible = icon != null
	var lines: Array[String] = WIEffectText.item_effect_lines(rec)
	_corner_breakout.visible = not lines.is_empty()
	# "Menu" variation (light-tan/outlined) -- the CARVED_PANEL background
	# behind these lines is the same DARK chrome pause_menu/title_screen use,
	# where "Menu" is the proven-legible variation (see slots_box's own
	# comment above for why the default dark-on-parchment Label would go
	# background-flat here instead).
	for line: String in lines:
		_corner_lines_box.add_child(UIChrome.make_label(line, "Menu"))
	_corner_mech_line = " | ".join(lines)


## Read-only rect accessor (issue #84 QA-teeth, `pause_menu.gd`'s `row_rect`/
## `dialogue_panel.gd`'s `option_rect` established pattern) -- the on-screen
## rect of carried-list row `i` as of the last `_rebuild_items()`, for QA's
## `click_inventory_row` step. Empty Rect2 when the panel is closed, the row
## is out of range, or the list is currently empty (`_rebuild_items` swaps in
## a single "Nothing carried." Label not tracked in `_item_labels` for that
## case, so the array is simply empty then -- no special-case needed here).
func item_row_rect(i: int) -> Rect2:
	if not open or i < 0 or i >= _item_labels.size():
		return Rect2()
	var label := _item_labels[i]
	if label == null or not is_instance_valid(label) or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


## The selected item's corner icon texture, or null when the item has none
## carried -- PATH-BY-CONVENTION (`_icon_path_for`), never a data field, so a
## missing file is a graceful degrade: `ResourceLoader.exists` guards the
## load, no error, no placeholder texture returned.
func _icon_texture_for(item_id: String) -> Texture2D:
	var path := _icon_path_for(item_id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


## `assets/icons/items/<item_id>.png` -- the icon path convention `_icon_
## texture_for` resolves against.
func _icon_path_for(item_id: String) -> String:
	return "%s%s.png" % [ICON_DIR, item_id]
