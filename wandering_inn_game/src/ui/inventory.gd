extends CanvasLayer
## Inventory panel — carried items + the two equip slots (weapon/armor),
## M7 Task E4. Toggled by the `inventory` action (`I`).
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): inventory only opens when combat is
## inactive, no dialogue is open, no consolidation offer is pending, and
## BOTH the pause menu and the journal are closed (mirrors journal.gd's
## `_can_open` against pause_menu_ref, extended with a matching check
## against journal_ref). world.gd wires `pause_menu_ref`/`journal_ref` after
## creating all three components, same as the existing journal<->pause
## pair, so no scene-tree lookup is needed; world.gd itself gates
## movement/interact on `inventory.open`, and journal.gd/pause_menu.gd are
## each extended with the matching `inventory_ref`/`open` check so all three
## field panels stay mutually exclusive.
##
## List grammar: arrows navigate the carried list (dialogue_panel.gd's
## cursor/rebuild-rows pattern -- "> " mark, wrapi wraparound), Enter
## equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped there. Game.sim.equip/unequip do the kind/
## possession validation. **M-GEAR Task G3 update:** a plain carryable item
## of an unequippable kind (tools: field_whetstone/fishers_handline) gets its
## own neutral toast here (Game.sim.equip() would silently refuse with no
## message of its own); every other equip()/unequip() false return is either
## a real, already-self-toasting refusal from WIGame (G1's two accessory
## refusals: slot-full, over-capacity -- mirrored into this panel's own
## `_status_label` too, originally because the toast layer drew BEHIND this
## panel, see below) or prevented entirely by `_equipped_slot_for` routing an
## already-equipped item to unequip() instead of a duplicate equip() call.
##
## Layer 10 -- same reasoning as journal.gd's file doc comment: WIWorldLabels
## is created lazily by world.gd AFTER Main._spawn_ui_layers() adds this
## panel, so an explicit higher layer is required to paint over world-space
## name labels regardless of add order.
##
## UIWAVE2 item 3 (user-ratified side-panel redesign): the carried list is now
## NAME-ONLY per row (plus the "[Equipped]" marker) -- every mechanical detail
## (effect lines, lore, description) moved to a SELECTION-DRIVEN detail column
## beside the list (`_detail_box`, built in `_ready()`'s HBox `body`), refreshed
## by `_render_detail()` on every cursor move / rebuild. The literal "Lore — "
## text prefix is gone; lore now reads as flavor purely through PLACEMENT
## (its own row, between the effect lines and the description) and STYLING
## (the new `"Lore"` theme type variation, wi_ui_theme.tres -- dimmer/
## desaturated brown at Small's font size, distinct from both the solid dark
## body color and Small's description-prose look). `_rendered_effect_lines()`
## (the `ui_inventory_shown` payload's `item_effect_lines`, one array per
## CARRIED item in list order) is UNCHANGED -- it was already independent of
## how/where the effect lines are drawn on screen, so no QA re-pin was needed
## for it.
##
## UIWAVE2 item 4 (overflow scroll fix): `_scroll`'s `mouse_filter` used to be
## `IGNORE` (inherited from the old full-rect Control convention this file's
## other panels use for non-interactive chrome) -- but that also silently
## swallowed real mouse-wheel scroll input aimed at the ScrollContainer,
## which is exactly what the user reported ("couldn't scroll"). Left at its
## Control default (`STOP`) so wheel/drag scrolling actually reaches the
## container; `ensure_control_visible` on cursor move is UNCHANGED (still the
## primary keyboard-driven navigation path) and both scroll containers
## (`_scroll` for the list, `_detail_scroll` for the detail column) now run
## `vertical_scroll_mode = SCROLL_MODE_SHOW_ALWAYS` so a visible scrollbar
## affordance is always on screen whenever there's more to see, not just
## discoverable by accident.

## UIWAVE2 item 3 (side-panel redesign): widened 640 -> 860 so the carried
## list (name-only rows now) and the new selection-driven detail column both
## get comfortable width side by side -- see the HBox body built in `_ready()`.
const PANEL_SIZE := Vector2(860.0, 560.0)
## Fixed width of the LEFT (carried-list) column; the detail column on the
## right takes whatever's left of the content area.
const LIST_WIDTH := 240.0

## Fix wave 2 (VISUAL-LOG "item card's last lore line rides the panel's
## bottom fold"): extra bottom clearance reserved for `_scroll` alone (via a
## fixed-height spacer sibling, see `_ready()`), on top of the panel's
## uniform 34px MarginContainer margin. MEASURED (evidence:
## .superpowers/sdd/fp-handoff/s2close-playtest-shots/tutorial_flow/
## 03_spear_equipped.png, `Relc's Spare Spear` card's last lore line, panel
## at y80..640 in the 720p shot): a per-column scan for the fold's tan curl
## color across the panel's text width (this panel's PARCHMENT_PANEL art,
## Banner_Vertical.png, 9-sliced via UIChrome.PARCHMENT_REGION) puts the
## decorative bottom curl's onset between LOCAL y508 and y536 of the
## 560px-tall panel -- the curl is WAVY art, so the EARLIEST column (y508)
## is the binding edge; the dark border line below it (local y538) is NOT
## where the danger starts. The previous clip edge (560 - 34 margin =
## local y526) sat BELOW the curl onset in several columns, so a card line
## rendering at the clip edge drew straight onto the fold (the illegible
## line in the evidence shot). 30px of spacer moves the clip edge to local
## y496, 12px clear of the earliest curl pixel. Same class of fix as
## message_layer.gd's `TOAST_FOLD_DANGER_PX`/combat_hud.gd's readout
## budget: reserve real pixels measured off the art, not a guessed round
## number.
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
## M-GEAR Task G3: one row per accessory slot (index 0/1/2 -> accessory_1/2/3),
## same styling/precedent as the weapon/armor rows above.
var _accessory_labels: Array[Label] = []
## M-GEAR Task G3 refusal surfacing: mirrors the most recent TOAST while this
## panel is open (see `_on_domain_event`). Originally needed because the
## toast layer (message_layer.gd, then a default CanvasLayer `layer` 1) drew
## BEHIND this panel's `layer = 10` -- a toast fired while the panel was open
## rendered under the opaque parchment (traced empirically, see the G3
## report). KF fix wave (2026-07-07): message_layer's toast panel now lives
## on its own CanvasLayer at layer 12 (above this panel's 10 -- see
## message_layer.gd's TOAST_CANVAS_LAYER doc comment), so the toast itself is
## fully visible again even while this panel is open. This echo STAYS
## anyway (belt-and-braces, single-sourced from the same TOAST payload --
## controller decision) rather than being removed.
var _status_label: Label
## KF fix wave (2026-07-07): fixed number of wrapped lines reserved for
## `_status_label`'s row -- see `_reserve_status_label_height()` below for
## the bug this fixes and why a FIXED reservation (not a per-message resize)
## is the right shape.
const STATUS_LABEL_RESERVED_LINES := 2
## M-GEAR Task G3: stored so `_rebuild_items` can scroll the cursor row into
## view -- the ScrollContainer's own `mouse_filter` is IGNORE (no wheel input
## wired) and there is no keyboard-scroll binding either, so without this the
## tail of a long carried list (up to 19 items today) is logically selectable
## (the cursor still moves) but never actually visible.
var _scroll: ScrollContainer
var _items_box: VBoxContainer
## UIWAVE2 item 3: the selection-driven detail column beside the list --
## see `_render_detail()`.
var _detail_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _item_ids: Array[String] = []
var _cursor := 0


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
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# Diegetic coin line (Economy v1 D3): the panel header, NOT an always-on
	# HUD (Global Constraint: gold shows in toasts + this panel only). Default
	# dark-on-parchment Label, same styling reasoning as the slot rows below.
	# "Gold: N" is literal text (no BBCode), so no `_bb_escape` is needed.
	_gold_label = UIChrome.make_label("")
	stack.add_child(_gold_label)

	# Two slot rows, pinned top (spec §3). Default Label styling (dark brown
	# on parchment -- journal.gd's proven body convention), NOT the "Menu"
	# variation: Menu's light-tan/outlined styling is designed for
	# pause_menu's DARK carved panel and reads nearly background-flat on
	# this parchment, inverting the reading hierarchy (E4 review finding).
	_weapon_label = UIChrome.make_label("")
	stack.add_child(_weapon_label)
	_armor_label = UIChrome.make_label("")
	stack.add_child(_armor_label)
	# M-GEAR Task G3: three accessory rows, same default dark-on-parchment
	# styling as weapon/armor above (E4 review finding still applies -- "Menu"
	# reads background-flat on this panel).
	for i in 3:
		var accessory_label := UIChrome.make_label("")
		stack.add_child(accessory_label)
		_accessory_labels.append(accessory_label)

	# M-GEAR Task G3: in-panel refusal echo (see the var's doc comment above).
	# KF fix wave (2026-07-07): NO LONGER "empty by default -- adds no visible
	# gap" -- see `_reserve_status_label_height()`'s doc comment; the row now
	# always reserves a fixed height regardless of text.
	_status_label = UIChrome.make_label("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status_label)
	# Must run AFTER add_child: theme lookups below need the label already
	# inside the themed tree (this panel's `_root` carries `UIChrome.
	# apply_theme`), or they'd silently resolve against the engine default
	# theme instead of `wi_ui_theme.tres` and reserve the wrong height.
	_reserve_status_label_height()

	# UIWAVE2 item 3: carried list (LEFT) + selection-driven detail column
	# (RIGHT), side by side -- see the file doc comment's redesign note.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)

	# LEFT: the carried list, in a ScrollContainer as the overflow safety net
	# -- item count started at the spec's 8-item catalog (no stacking) and
	# has since grown to a 19-item full catalog (M-GEAR G2). Rows are now
	# NAME-ONLY (+ "[Equipped]" marker) -- the mechanical/lore/description
	# detail moved to `_detail_box` on the right (UIWAVE2 item 3), and
	# `_rebuild_items` still scrolls the cursor row into view every rebuild
	# so the safety net stays genuinely reachable by keyboard, not just
	# non-clipping. UIWAVE2 item 4: mouse_filter left at Control's own
	# default (STOP, not IGNORE) so real mouse-wheel/drag scroll input
	# actually reaches the container (see the file doc comment), and
	# `vertical_scroll_mode` forced SHOW_ALWAYS for a persistent visible
	# scroll affordance.
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
	_scroll.add_child(_items_box)

	# RIGHT: the detail column for whatever item the cursor is currently on
	# (UIWAVE2 item 3) -- also scrollable (same mouse_filter/scroll-mode fix
	# as the list) as a safety net for a long description/lore combination
	# at this column's narrower width.
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

	# Live coin-line refresh (Economy v1 D3): the same domain_event idiom
	# field_hotbar/dialogue_panel use -- if the panel is open when gold
	# changes, re-render the line (and re-confirm) rather than only on open.
	ObservableBus.domain_event.connect(_on_domain_event)


## KF fix wave (2026-07-07): reserves a FIXED row height for `_status_label`
## up front, from real font metrics -- never derived from whatever text
## happens to be showing. PLAYTEST FINDING (gear_loop
## `03_capacity_refusal_in_panel_echo.png`): the L3-era review believed this
## was a proper VBox row (it IS a `stack.add_child` sibling, positioned
## correctly above `_scroll`) but never accounted for a real Godot gotcha,
## the SAME class of bug this repo's CLAUDE.md already documents for the
## toast/dialogue/feed/readout panels ("message panels budget WRAPPED
## LINES, not entries"): a `Label` with `AUTOWRAP_WORD_SMART` reports only
## its SINGLE-LINE height from `get_minimum_size()` (word-wrap depends on
## the final rect width, which isn't resolved yet when the container asks
## for minimum size) -- so VBoxContainer reserved exactly ONE line for this
## row no matter how long the text got. `_CAPACITY_REFUSAL_TOAST` ("It
## buzzes once against the others, like a wasp against glass, and will not
## settle.") wraps to 2 lines at this panel's real content width (measured
## when this fix landed: 572px = the then-640 PANEL_SIZE.x minus the content
## MarginContainer's 34px+34px margins; PANEL_SIZE later widened to 860 for
## UIWAVE2 item 3's side panel, which only gives this row MORE width to work
## with) -- its 2nd line rendered OUTSIDE the reserved row, overlapping
## the scrolled item list's first row directly beneath (the visible
## "double-exposure" in the evidence shot). Fix: reserve
## STATUS_LABEL_RESERVED_LINES (2 -- covers every refusal copy WIGame emits
## today, `_CAPACITY_REFUSAL_TOAST` included, with zero slack left over) of
## REAL line-pitch height (font height + theme `line_spacing` between lines
## -- `Font.get_multiline_string_size` alone does NOT include the spacing,
## the same trap `_toast_panel_height_for` in message_layer.gd already
## works around) via `custom_minimum_size`, fixed at `_ready()` time and
## NEVER recomputed per message. A fixed reservation -- not a dynamic
## resize keyed to the current text -- means the scroll area's start
## position is IDENTICAL whether the echo is empty, one line, or its max,
## "in every scroll position" per the fix decision, with no resize/layout-
## timing race to guard (the panel's own `_rebuild_items` doc comment
## already flags a real one-hop container-sort race elsewhere in this
## file -- a fixed reservation sidesteps that class of bug entirely here).
func _reserve_status_label_height() -> void:
	var font := _status_label.get_theme_font("font")
	var font_size := _status_label.get_theme_font_size("font_size")
	var line_spacing := float(_status_label.get_theme_constant("line_spacing"))
	var pitch := font.get_height(font_size) + line_spacing
	var height := STATUS_LABEL_RESERVED_LINES * pitch - line_spacing
	_status_label.custom_minimum_size = Vector2(0.0, height)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if not open:
		return
	if type == WIEvents.GOLD_CHANGED:
		_refresh_gold()
		# Re-confirm the drawn state (bus convention), carrying the live total.
		_emit_shown()
	elif type == WIEvents.ITEM_EQUIPPED or type == WIEvents.ITEM_UNEQUIPPED:
		# M-GEAR Task G3: equip/unequip changes the slot rows AND the
		# Resonance header (neither rides on GOLD_CHANGED) -- same
		# re-confirm-on-relevant-domain-event idiom as the gold case above,
		# so a QA script can assert the post-equip resonance total without
		# having to close/reopen the panel.
		_refresh_slots()
		_emit_shown()
	elif type == WIEvents.TOAST:
		# M-GEAR Task G3 refusal surfacing: see `_status_label`'s doc comment
		# above -- kept belt-and-braces even after the KF fix wave made the
		# toast layer itself fully visible again over this panel. A refusal
		# toast fired while the panel is open (the only toast source
		# reachable while it is, since world input is gated shut) still gets
		# its own visible copy in here, single-sourced from this same payload.
		_status_label.text = String(payload.get("text", ""))


## M-GEAR Task G3: the `ui_inventory_shown` re-confirm payload, shared by
## `_open()` and the domain-event re-renders above so the two never drift.
func _emit_shown() -> void:
	ObservableBus.emit_domain_event(WIEvents.UI_INVENTORY_SHOWN, {
		"items": _item_ids.size(),
		"gold": Game.sim.gold,
		"item_effect_lines": _rendered_effect_lines(),
		"resonance": {"used": Game.sim.resonance_used(), "capacity": Game.sim.resonance_capacity},
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
	# GF Minor 1: a refusal echo belongs to the selection it refused --
	# clear it on navigation so it never lingers over a different item.
	_status_label.text = ""
	_rebuild_items()


## M-GEAR Task G3: returns the slot name `item_id` currently occupies
## ("weapon", "armor", or one of the three accessory slots), or "" if it
## isn't equipped anywhere. `Game.sim.equipped` keys accessories by their
## REAL slot name (`accessory_1`/`_2`/`_3`), never the generic "accessory"
## kind -- a plain `equipped.get(kind, "")` lookup (fine for weapon/armor,
## where kind IS the slot name) silently misses every equipped accessory.
## This was a real pre-G3 bug: re-confirming an already-equipped accessory
## called `equip()` again instead of `unequip()`, which G1's own duplicate-
## slot guard then silently refused (no toast) -- so the panel's "toggle
## equip/unequip on confirm" grammar (spec §3) never actually worked for
## accessories until this fix.
func _equipped_slot_for(item_id: String, kind: String) -> String:
	if kind == "accessory":
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(Game.sim.equipped.get(slot_name, "")) == item_id:
				return slot_name
		return ""
	if String(Game.sim.equipped.get(kind, "")) == item_id:
		return kind
	return ""


## Equips the selected item into its own kind's slot, or unequips it if it
## IS the item already equipped in that slot (spec §3 journal grammar).
func _confirm() -> void:
	if _item_ids.is_empty():
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var kind := String(rec.get("kind", ""))
	if kind != "weapon" and kind != "armor" and kind != "accessory":
		# Carryable non-equippable kinds (M-GEAR G2's tools: field_whetstone,
		# fishers_handline) reach here -- Game.sim.equip() would silently
		# refuse (invalid kind, no toast of its own) with no player feedback
		# at all, so the panel owns this one neutral message. Every OTHER
		# equip()/unequip() false return below already carries its own
		# diegetic toast from WIGame (G1's two accessory refusals), or is
		# prevented entirely by routing an already-equipped item to unequip()
		# instead of a duplicate equip() attempt (the helper above) -- this is
		# the only reachable "no toast yet" case left.
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
	# M-GEAR Task G3: clear any lingering refusal echo -- a fresh open or a
	# just-succeeded equip/unequip both mean whatever the message was about
	# is no longer the live state.
	_status_label.text = ""
	_refresh_gold()
	_refresh_slots()
	_rebuild_items()


## M-LEGIBILITY L2: the effect lines drawn on each carried item's card, one
## entry per item in `_item_ids` order (parallel to the list the panel renders),
## carried on the `ui_inventory_shown` payload so QA can pin the exact generated
## strings the player sees. Same WIEffectText source the card rendering uses, so
## the payload can never drift from the drawn card.
func _rendered_effect_lines() -> Array:
	var out: Array = []
	for item_id: String in _item_ids:
		out.append(WIEffectText.item_effect_lines(Game.sim.item(String(item_id))))
	return out


## M-GEAR Task G3: the header now carries BOTH visible currencies on one
## line -- "Gold: N" (Economy v1 D3, unchanged) plus "Resonance N/M" (spec's
## visible-currency tier for the accessory budget). Same diegetic-panel-only
## surface as gold (Global Constraint: no always-on HUD); plain text, no
## BBCode, so no `_bb_escape` is needed here either.
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
## (cheap; the catalog has grown to 19 items (M-GEAR G2), no stacking).
## UIWAVE2 item 3: each row is now NAME-ONLY (+ "[Equipped]" marker) -- the
## mechanical effect lines / lore / description that used to render inline
## under every row now live in the selection-driven `_detail_box` (see
## `_render_detail`, called at the end of this function so the two columns
## can never drift out of sync). After rebuilding, scrolls the cursor's row
## into view (see `_scroll`'s doc comment).
func _rebuild_items() -> void:
	for child: Node in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	_item_ids = Game.sim.inventory.duplicate()
	if _cursor >= _item_ids.size():
		_cursor = max(_item_ids.size() - 1, 0)
	if _item_ids.is_empty():
		_items_box.add_child(UIChrome.make_label("Nothing carried."))
		_render_detail()
		return
	var cursor_row: Control = null
	for i in _item_ids.size():
		var item_id := String(_item_ids[i])
		var rec: Dictionary = Game.sim.item(item_id)
		var name := String(rec.get("name", item_id))
		var kind := String(rec.get("kind", ""))
		# M-GEAR Task G3: was `String(Game.sim.equipped.get(kind, "")) ==
		# item_id`, which only ever matched weapon/armor (kind IS the slot
		# name for those two) -- an equipped ACCESSORY never tagged
		# "[Equipped]" since `equipped` has no "accessory" key at all, only
		# accessory_1/_2/_3. `_equipped_slot_for` checks the real slot set.
		var equipped_here := _equipped_slot_for(item_id, kind) != ""
		var mark := "> " if i == _cursor else "  "
		var tag := "  [Equipped]" if equipped_here else ""
		# Default dark-on-parchment Label, same reasoning as the slot rows
		# above (E4 review finding: "Menu" is a dark-panel variant). The
		# "> " cursor mark stays legible as dark text on the light parchment.
		var name_label := UIChrome.make_label("%s%s%s" % [mark, name, tag])
		_items_box.add_child(name_label)
		if i == _cursor:
			cursor_row = name_label
	_render_detail()
	if cursor_row != null:
		# A FRESH rebuild (every child freed and recreated above) needs the
		# VBoxContainer's own queued sort to actually run before its rows'
		# rects are trustworthy -- a single `call_deferred` hop can still race
		# that queued sort (confirmed empirically: after a full rebuild, one
		# hop left the view scrolled to wherever it was BEFORE the rebuild,
		# not at the cursor's fresh row). Deferring the deferred call gives it
		# a second idle-time hop, past the container's own layout pass.
		var row := cursor_row
		(func() -> void: _scroll.ensure_control_visible.call_deferred(row)).call_deferred()


## UIWAVE2 item 3: renders the RIGHT-column detail card for whatever item the
## cursor is currently on -- name (+ "[Equipped]" marker, "Header" variation,
## same on-parchment precedent as dialogue_panel.gd's speaker label), the
## mechanical effect lines (GENERATED via WIEffectText.item_effect_lines,
## never hand-composed -- same source `_rendered_effect_lines` uses for the
## QA payload, so the two can never drift), the lore line (UNLABELED -- no
## "Lore — " prefix; it reads as flavor purely through placement below the
## effect lines and the new "Lore" theme type variation's dimmer styling),
## and the wrapped description prose. Called at the end of every
## `_rebuild_items` (cursor move, open, or a post-equip/unequip refresh) so
## the detail column can never show a different item than the highlighted
## list row.
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
	# M-LEGIBILITY L2: the mechanical effect lines, GENERATED from the item's
	# data via the shared WIEffectText formatter (never hand-composed here --
	# that drift is the defect this milestone kills). item_effect_lines already
	# ends with the "Worth N gold" value where the item is priced. A plain
	# item (no mods, no price) yields an empty array -> no effect rows.
	for effect_line: String in WIEffectText.item_effect_lines(rec):
		_detail_box.add_child(UIChrome.make_label(effect_line))
	# UIWAVE2 item 3: the lore line, UNLABELED (no "Lore — " prefix) -- the
	# "Lore" theme type variation (wi_ui_theme.tres) is dimmer/desaturated
	# relative to both the solid dark effect-line text above and "Small"'s
	# description-prose look below, so it reads as flavor through styling +
	# placement alone.
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
