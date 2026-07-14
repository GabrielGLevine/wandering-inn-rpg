extends CanvasLayer
## Layer 10 -- same reasoning as journal.gd's file doc comment: WIWorldLabels
## is created lazily by world.gd AFTER Main._spawn_ui_layers() adds this
## panel, so an explicit higher layer is required to paint over world-space
## name labels regardless of add order.
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

const PANEL_SIZE := Vector2(860.0, 560.0)
const LIST_WIDTH := 240.0

const ICON_SOURCE_PX := 32
const ICON_SCALE := 2
const ICON_DISPLAY_PX := ICON_SOURCE_PX * ICON_SCALE
const ICON_DIR := "res://assets/icons/items/"
## TRAP: this is a RESERVE, not a clamp -- there is NO runtime guard, so an
## item whose card generates a 4th simultaneous effect line silently GROWS
## the box past the reservation (custom_minimum_size is a floor, and the
## lines VBox renders every line regardless), shoving the layout below it.
const CORNER_BREAKOUT_RESERVED_LINES := 3
const CORNER_BREAKOUT_MARGIN := 10

const SCROLL_BOTTOM_INSET := 30.0

var open := false

var pause_menu_ref: Node = null
var journal_ref: Node = null

var _root: Control
var _title_label: Label
var _gold_label: Label
var _weapon_label: Label
var _armor_label: Label
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
const STATUS_LABEL_RESERVED_LINES := 2
var _scroll: ScrollContainer
var _items_box: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _corner_icon: TextureRect
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

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	stack.add_child(top_row)

	var slots_box := VBoxContainer.new()
	slots_box.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	top_row.add_child(slots_box)

	_gold_label = UIChrome.make_label("")
	slots_box.add_child(_gold_label)

	_weapon_label = UIChrome.make_label("")
	slots_box.add_child(_weapon_label)
	_armor_label = UIChrome.make_label("")
	slots_box.add_child(_armor_label)
	for i in 3:
		var accessory_label := UIChrome.make_label("")
		slots_box.add_child(accessory_label)
		_accessory_labels.append(accessory_label)

	var corner_box := VBoxContainer.new()
	corner_box.add_theme_constant_override("separation", 8)
	corner_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(corner_box)

	_corner_icon = TextureRect.new()
	_corner_icon.custom_minimum_size = Vector2(ICON_DISPLAY_PX, ICON_DISPLAY_PX)
	_corner_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_corner_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_corner_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_corner_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_icon.hide()
	corner_box.add_child(_corner_icon)

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

	_status_label = UIChrome.make_label("")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status_label)
	# Must run AFTER add_child: theme lookups below need the label already
	# inside the themed tree (this panel's `_root` carries `UIChrome.
	_reserve_status_label_height()

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	body.add_child(_scroll)
	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 4)
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_items_box.gui_input.connect(_on_items_gui_input)
	_scroll.add_child(_items_box)

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

	var scroll_bottom_spacer := Control.new()
	scroll_bottom_spacer.custom_minimum_size = Vector2(0.0, SCROLL_BOTTOM_INSET)
	scroll_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(scroll_bottom_spacer)

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
		_emit_shown()
	elif type == WIEvents.ITEM_EQUIPPED or type == WIEvents.ITEM_UNEQUIPPED:
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


func toggle_open() -> bool:
	if not open:
		if not _can_open():
			return false
		_open()
		return true
	_close()
	return true


func _move_cursor(delta: int) -> void:
	if _item_ids.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _item_ids.size())
	_status_label.text = ""
	_rebuild_items()
	_emit_selection()


func _equipped_slot_for(item_id: String, kind: String) -> String:
	if kind == "accessory":
		for slot_name: String in ["accessory_1", "accessory_2", "accessory_3"]:
			if String(Game.sim.equipped.get(slot_name, "")) == item_id:
				return slot_name
		return ""
	if String(Game.sim.equipped.get(kind, "")) == item_id:
		return kind
	return ""


func _row_display_text(i: int) -> String:
	var item_id := String(_item_ids[i])
	var rec: Dictionary = Game.sim.item(item_id)
	var name := String(rec.get("name", item_id))
	var kind := String(rec.get("kind", ""))
	var equipped_here := _equipped_slot_for(item_id, kind) != ""
	var mark := "> " if i == _cursor else "  "
	var tag := ""
	if equipped_here:
		tag = "  [Equipped]"
	elif (rec.get("use_effect", {}) as Dictionary).has("heal") and Game.sim.hotbar_loadout.has("item:%s" % item_id):
		tag = "  [On Hotbar]"
	return "%s%s%s" % [mark, name, tag]


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


func _confirm() -> void:
	if _item_ids.is_empty():
		return
	var item_id := String(_item_ids[_cursor])
	var rec: Dictionary = Game.sim.item(item_id)
	var kind := String(rec.get("kind", ""))
	if kind == "weapon" or kind == "armor" or kind == "accessory":
		var equipped_slot := _equipped_slot_for(item_id, kind)
		var ok: bool = Game.sim.unequip(equipped_slot) if equipped_slot != "" else Game.sim.equip(item_id)
		if not ok:
			return
		_refresh()
		return
	var use_effect: Dictionary = rec.get("use_effect", {})
	if use_effect.has("heal"):
		Game.sim.loadout_toggle("item:%s" % item_id)
		_refresh_row_marks()
		return
	if use_effect.has("next_fight"):
		if Game.sim.use_item(item_id):
			_refresh()
		return
	ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "That isn't something you can equip."})


func _refresh() -> void:
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
		_render_corner()
		return
	var cursor_row: Control = null
	for i in _item_ids.size():
		var name_label := UIChrome.make_label(_row_display_text(i))
		_items_box.add_child(name_label)
		_item_labels.append(name_label)
		if i == _cursor:
			cursor_row = name_label
	_render_detail()
	_render_corner()
	if cursor_row != null:
		if _cursor == 0:
			_scroll.scroll_vertical = 0
		else:
			var row := cursor_row
			(func() -> void: _scroll.ensure_control_visible.call_deferred(row)).call_deferred()


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
	var lore := String(rec.get("lore", ""))
	if lore != "":
		var lore_label := UIChrome.make_label(lore, "Lore")
		lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(lore_label)
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
	for line: String in lines:
		_corner_lines_box.add_child(UIChrome.make_label(line, "Menu"))
	_corner_mech_line = " | ".join(lines)


func item_row_rect(i: int) -> Rect2:
	if not open or i < 0 or i >= _item_labels.size():
		return Rect2()
	var label := _item_labels[i]
	if label == null or not is_instance_valid(label) or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func _icon_texture_for(item_id: String) -> Texture2D:
	var path := _icon_path_for(item_id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


func _icon_path_for(item_id: String) -> String:
	return "%s%s.png" % [ICON_DIR, item_id]
