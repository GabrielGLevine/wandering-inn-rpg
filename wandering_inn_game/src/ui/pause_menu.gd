extends CanvasLayer

const PANEL_SIZE := Vector2(280.0, 390.0)
const ROWS := ["Resume", "Save", "Load", "Load Autosave", "Music", "SFX", "Quit to Title", "Settings"]
const COMBAT_ROWS := ["Resume", "Abandon to Last Save", "Music", "SFX", "Quit to Title"]
const VOLUME_ROWS := ["Music", "SFX"]

const CONFIRM_PANEL_SIZE := Vector2(340.0, 158.0)
const CONFIRM_TEXT := "Unsaved progress since the\nlast autosave is lost. Quit?"
const ABANDON_CONFIRM_TEXT := "Abandon the fight? You return\nto your last autosave."
const CONFIRM_ROWS := ["No", "Yes"]

const SLOT_PICKER_PANEL_SIZE := Vector2(460.0, 250.0)
const SLOT_ROW_CHAR_BUDGET := 50
const SLOT_PICKER_BACK := "Back"

## GH#377. All three roots below are PRESET_CENTER fixed-size panels, so before
## this the paused world drew at full strength around and behind them -- combat
## HP readouts and the feed sat a few pixels from "Abandon to Last Save" and
## read as part of the menu. ONE full-rect dimmer covers all three (a panel is
## never the thing that dims; the layer is), and it is a plain hide/show, no
## tween: pause is an interruption, not a mood beat.
##
## 0.55 is INVENTED, not matched -- there was no partial-alpha dimmer anywhere
## in the codebase to inherit from. The nearest idiom is sleep_veil.gd's
## full-rect black ColorRect, and what this borrows from it is the click-leak
## contract, not the alpha: MOUSE_FILTER_STOP so a click on the dimmed world
## can never fall through to the board/field underneath while a modal is up.
## The windowed combat_abandon shot is the arbiter for the number.
## 0.70 (was the invented 0.55): the playtest read combat HP text through the
## dim as "showing through the menu" -- white text at 45% is still legible, at
## 30% it recedes. User report outranks the earlier +-0.1 fence.
const SCRIM_COLOR := Color(0.0, 0.0, 0.0, 0.70)
## Playtest fix wave (finding 6): this CanvasLayer shipped at the default
## layer 1, so combat chrome (turn banner, per-combatant HP text) drew ABOVE
## both the scrim and the menu panels -- enemy health read at full strength
## through "Abandon to Last Save". Pause is a modal interruption: it sits
## above toasts (12) and below the sleep veil (30) per message_layer.gd's
## layer map.
const PAUSE_CANVAS_LAYER := 20

var open := false

var journal_ref: Node = null
var inventory_ref: Node = null
var combat_ref: Node = null
## Set by world.gd's `inject_ui_refs` to `self` (a same-file self-ref, not a
## cross-script preload -- world.gd already owns this assignment, no new
## cycle). Lets `_can_open()` refuse to open while the field hotbar's Tab/pad
## cursor is armed (issue #58) -- this node sits LATER in Main's child order
## (see the file doc comment's arbitration note / `_can_open`'s combat
## comment for the general shape of that trap), so an armed Esc/cancel would
## otherwise open the pause menu INSTEAD of ever reaching world.gd's own
## cancel-disarm branch.
var world_ref: Node = null
var settings_ref: Node = null

var _root: Control
var _row_labels: Array[Label] = []
var _cursor := 0
var _confirm_label: Label

var _confirm_root: Control
var _confirm_option_labels: Array[Label] = []
var _confirming_quit := false
var _confirm_action := "quit"
var _confirm_cursor := 0

var _picking_slot := false
var _slot_mode := "save"
var _slot_cursor := 0
var _slot_root: Control
var _slot_title_label: Label
var _slot_labels: Array[Label] = []

var _scrim: ColorRect


func _active_rows() -> Array:
	return COMBAT_ROWS if Game.sim.combat != null else ROWS


func _ready() -> void:
	layer = PAUSE_CANVAS_LAYER
	# FIRST child of this CanvasLayer, before any panel: same-layer siblings
	# draw in tree order, so being first is what puts the dimmer BEHIND all
	# three roots and in front of everything on earlier layers (the combat
	# screen and the world viewport both qualify). Mouse picking runs the
	# reverse of that order, so the panels still take their own clicks and the
	# scrim only catches what misses them.
	_scrim = ColorRect.new()
	_scrim.name = "PauseScrim"
	_scrim.color = SCRIM_COLOR
	UIChrome.full_rect(_scrim)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.hide()
	add_child(_scrim)

	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)
	_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))
	var menu_margin := MarginContainer.new()
	UIChrome.full_rect(menu_margin)
	UIChrome.add_margins(menu_margin, 30, 28, 30, 28)
	_root.add_child(menu_margin)
	var menu_stack := VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 6)
	menu_margin.add_child(menu_stack)
	for i in ROWS.size():
		var row := UIChrome.make_label("", "MenuInk")
		row.custom_minimum_size = Vector2(220.0, 36.0)
		menu_stack.add_child(row)
		_row_labels.append(row)
	menu_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_stack.gui_input.connect(_on_menu_gui_input)

	_confirm_root = Control.new()
	UIChrome.apply_theme(_confirm_root)
	_confirm_root.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_root.custom_minimum_size = CONFIRM_PANEL_SIZE
	_confirm_root.size = CONFIRM_PANEL_SIZE
	UIChrome.set_offsets(_confirm_root, -CONFIRM_PANEL_SIZE.x * 0.5, -CONFIRM_PANEL_SIZE.y * 0.5, CONFIRM_PANEL_SIZE.x * 0.5, CONFIRM_PANEL_SIZE.y * 0.5)
	_confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_root.hide()
	add_child(_confirm_root)
	_confirm_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))
	var confirm_margin := MarginContainer.new()
	UIChrome.full_rect(confirm_margin)
	UIChrome.add_margins(confirm_margin, 28, 26, 28, 24)
	_confirm_root.add_child(confirm_margin)
	var confirm_stack := VBoxContainer.new()
	confirm_stack.add_theme_constant_override("separation", 8)
	confirm_margin.add_child(confirm_stack)
	_confirm_label = UIChrome.make_label()
	_confirm_label.text = CONFIRM_TEXT
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_stack.add_child(_confirm_label)
	for i in CONFIRM_ROWS.size():
		var row := UIChrome.make_label("", "MenuInk")
		confirm_stack.add_child(row)
		_confirm_option_labels.append(row)
	confirm_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_stack.gui_input.connect(_on_confirm_gui_input)

	_slot_root = Control.new()
	UIChrome.apply_theme(_slot_root)
	_slot_root.set_anchors_preset(Control.PRESET_CENTER)
	_slot_root.custom_minimum_size = SLOT_PICKER_PANEL_SIZE
	_slot_root.size = SLOT_PICKER_PANEL_SIZE
	UIChrome.set_offsets(_slot_root, -SLOT_PICKER_PANEL_SIZE.x * 0.5, -SLOT_PICKER_PANEL_SIZE.y * 0.5, SLOT_PICKER_PANEL_SIZE.x * 0.5, SLOT_PICKER_PANEL_SIZE.y * 0.5)
	_slot_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_root.hide()
	add_child(_slot_root)
	_slot_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))
	var slot_margin := MarginContainer.new()
	UIChrome.full_rect(slot_margin)
	UIChrome.add_margins(slot_margin, 24, 20, 24, 20)
	_slot_root.add_child(slot_margin)
	var slot_stack := VBoxContainer.new()
	slot_stack.add_theme_constant_override("separation", 6)
	slot_margin.add_child(slot_stack)
	_slot_title_label = UIChrome.make_label("", "MenuInk")
	slot_stack.add_child(_slot_title_label)
	var slot_spacer := Control.new()
	slot_spacer.custom_minimum_size = Vector2(0.0, 4.0)
	slot_stack.add_child(slot_spacer)
	for i in _slot_rows().size():
		var row := UIChrome.make_label("", "MenuInk")
		row.custom_minimum_size = Vector2(412.0, 32.0)
		slot_stack.add_child(row)
		_slot_labels.append(row)
	slot_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_stack.gui_input.connect(_on_slot_gui_input)

	for root: Control in [_root, _confirm_root, _slot_root]:
		root.visibility_changed.connect(_sync_scrim)
	_sync_scrim()


## GH#377: the scrim's entire lifecycle, derived rather than called. Driving it
## off the three roots' own `visibility_changed` signals (instead of a line at
## each of the eight show/hide sites) means a future fourth show site cannot
## forget it -- and it reads the roots' OWN `visible`, not
## `is_visible_in_tree()`, so hiding the whole layer never feeds back into it.
## "Settings" hides `_root` without showing a sibling, so the scrim correctly
## goes with it: the settings panel is its own surface and owns its own
## backdrop question.
func _sync_scrim() -> void:
	if _scrim == null:
		return
	_scrim.visible = _root.visible or _confirm_root.visible or _slot_root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not open and not (event.is_action_pressed("cancel") and _can_open()):
		return
	# Captured before acting: "Load" in _confirm() can trigger a
	# game_loaded event, which Main._on_domain_event() handles via
	# Main.swap_to_world.call_deferred() (src/world/main.gd) -- deferred, so
	# this node isn't freed inside this callback, but grab the viewport
	# reference up front anyway so the post-action set_input_as_handled()
	# call doesn't depend on this node still being in the tree by the time
	# it runs. Same applies to "Quit to Title" -> Main.swap_to_title().
	var vp := get_viewport()
	if not open:
		_open()
		vp.set_input_as_handled()
		return
	if _confirming_quit:
		_handle_confirm_input(event, vp)
		return
	if _picking_slot:
		_handle_slot_input(event, vp)
		return
	if event.is_action_pressed("cancel"):
		_close()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_cursor = wrapi(_cursor - 1, 0, _active_rows().size())
		_refresh()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_cursor = wrapi(_cursor + 1, 0, _active_rows().size())
		_refresh()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_adjust_volume_row(-1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_adjust_volume_row(1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		vp.set_input_as_handled()


func _handle_confirm_input(event: InputEvent, vp: Viewport) -> void:
	if event.is_action_pressed("cancel"):
		_exit_confirm_quit()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_confirm_cursor = wrapi(_confirm_cursor + 1, 0, CONFIRM_ROWS.size())
		_refresh_confirm()
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select_confirm_choice()
		vp.set_input_as_handled()


func _select_confirm_choice() -> void:
	var choice := String(CONFIRM_ROWS[_confirm_cursor])
	if choice == "Yes":
		var action := _confirm_action
		_close()
		if action == "abandon":
			if combat_ref != null and combat_ref.has_method("abandon_combat"):
				combat_ref.call("abandon_combat")
		else:
			_quit_to_title()
	else:
		_exit_confirm_quit()


func _on_menu_gui_input(event: InputEvent) -> void:
	if not open or _confirming_quit:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_row_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx < _active_rows().size() and idx != _cursor:
			_cursor = idx
			_refresh()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_row_labels, mb.position)
	if idx >= 0 and idx < _active_rows().size():
		_cursor = idx
		_confirm()


func _on_confirm_gui_input(event: InputEvent) -> void:
	if not _confirming_quit:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_confirm_option_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _confirm_cursor:
			_confirm_cursor = idx
			_refresh_confirm()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_confirm_option_labels, mb.position)
	if idx >= 0:
		_confirm_cursor = idx
		_select_confirm_choice()


func row_rect(i: int) -> Rect2:
	if not open or i < 0 or i >= _row_labels.size():
		return Rect2()
	var label := _row_labels[i]
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func _can_open() -> bool:
	if Game.sim.dialogue != null:
		return false
	# Mid-combat opening is allowed ONLY in the HOTBAR resting mode (your
	# turn, no targeting/dash/banner sub-mode in flight) -- combat_ref owns
	# that answer. Combat's own _unhandled_input never consumes `cancel` in
	# HOTBAR mode, and this node sits LATER in Main's child order, so it
	# sees the un-consumed Esc first on the way back.
	if Game.sim.combat != null:
		if combat_ref == null or not combat_ref.has_method("is_resting") or not bool(combat_ref.call("is_resting")):
			return false
	if not Game.sim.pending_consolidation.is_empty():
		return false
	if journal_ref != null and bool(journal_ref.get("open")):
		return false
	if inventory_ref != null and bool(inventory_ref.get("open")):
		return false
	if world_ref != null and world_ref.has_method("field_slot_armed") and bool(world_ref.call("field_slot_armed")):
		return false
	return true


func _open() -> void:
	open = true
	_cursor = 0
	_confirming_quit = false
	_picking_slot = false
	_confirm_root.hide()
	_slot_root.hide()
	_refresh()
	_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_PAUSE_SHOWN, {})


func _close() -> void:
	open = false
	_confirming_quit = false
	_picking_slot = false
	_root.hide()
	_confirm_root.hide()
	_slot_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_PAUSE_HIDDEN, {})


func toggle_open() -> bool:
	if not open:
		if not _can_open():
			return false
		_open()
		return true
	if _confirming_quit:
		_exit_confirm_quit()
		return true
	if _picking_slot:
		_exit_slot_picker()
		return true
	_close()
	return true


func _reopen_after_settings() -> void:
	if open:
		_root.show()


func _enter_confirm(action: String) -> void:
	_confirming_quit = true
	_confirm_action = action
	_confirm_label.text = ABANDON_CONFIRM_TEXT if action == "abandon" else CONFIRM_TEXT
	_confirm_cursor = 0
	_root.hide()
	_confirm_root.show()
	_refresh_confirm()


func _exit_confirm_quit() -> void:
	_confirming_quit = false
	_confirm_root.hide()
	_root.show()
	_refresh()


## Issue #78: opens the Save/Load slot picker. Cursor DEFAULTS TO 0 (slot
## "manual", the pre-existing single-slot id) so every pre-existing "Save"/
## "Load" flow (a fixture_save's default slot, every hand-written
## assert_save_exists) reaches the SAME slot as before this task with
## exactly ONE extra Confirm press to land on the now-explicit row. `mode`
## is "save" or "load" -- purely presentational (the title text + which
## Game.* call `_select_slot` makes), never gates row selectability: an
## empty slot is still pickable in LOAD mode and just fails gracefully with
## the pre-existing "Could not load save." toast, the SAME tolerant-failure
## contract a missing "manual"/"auto" file already had.
func _enter_slot_picker(mode: String) -> void:
	_slot_mode = mode
	_picking_slot = true
	_slot_cursor = 0
	_slot_title_label.text = "Save to which slot?" if mode == "save" else "Load which slot?"
	_root.hide()
	_refresh_slots()
	_slot_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_PICKER_RENDERED, {"mode": mode, "slots": _slot_summaries()})


func _exit_slot_picker() -> void:
	_picking_slot = false
	_slot_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_PICKER_HIDDEN, {})
	_root.show()
	_refresh()


func _handle_slot_input(event: InputEvent, vp: Viewport) -> void:
	if event.is_action_pressed("cancel"):
		_exit_slot_picker()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_slot_cursor = wrapi(_slot_cursor - 1, 0, _slot_rows().size())
		_refresh_slots()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_slot_cursor = wrapi(_slot_cursor + 1, 0, _slot_rows().size())
		_refresh_slots()
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select_slot()
		vp.set_input_as_handled()


## The picker's row list: MANUAL_SLOTS in order, then the trailing "Back"
## row -- the SAME order `_ready()` built `_slot_labels` in, so index i
## always means the same thing everywhere in this file.
func _slot_rows() -> Array[String]:
	var rows: Array[String] = []
	rows.append_array(Game.MANUAL_SLOTS)
	rows.append(SLOT_PICKER_BACK)
	return rows


func _select_slot() -> void:
	var rows := _slot_rows()
	var choice := String(rows[_slot_cursor])
	if choice == SLOT_PICKER_BACK:
		_exit_slot_picker()
		return
	var mode := _slot_mode
	ObservableBus.emit_domain_event(WIEvents.UI_SLOT_PICKER_HIDDEN, {})
	_close()
	if mode == "save":
		Game.save_manual(choice)
	else:
		if not Game.load_slot(choice):
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not load save.", "housekeeping": true})


func _refresh_slots() -> void:
	var rows := _slot_rows()
	for i in rows.size():
		var label := _slot_labels[i] as Label
		var mark := "> " if i == _slot_cursor else "  "
		label.text = mark + _slot_row_text(String(rows[i]), i)


func _slot_row_text(row_id: String, i: int) -> String:
	if row_id == SLOT_PICKER_BACK:
		return SLOT_PICKER_BACK
	var meta := Game.slot_metadata(row_id)
	var summary := "Empty" if meta.is_empty() else _format_slot_summary(meta)
	return _truncate_row("Slot %d — %s" % [i + 1, summary])


## Word-boundary ellipsis truncation (D2-7 #6: "cut words, never widen UI")
## for a player-typed name (up to PC_NAME_MAX=16) plus the longest shipped
## map id could exceed the picker's real row width -- this is the ON-SCREEN
## cut only, mirroring the ambient-bark/dialogue-panel precedent elsewhere
## (message_layer.gd): `UI_SLOT_PICKER_RENDERED`'s own `summary` payload
## (built by `_format_slot_summary` directly, never through this function)
## always carries the FULL untruncated line. Same fallback shape as
## title_screen.gd's `_first_sentence` budget cut, sized for this picker's
## real content width (SLOT_PICKER_PANEL_SIZE minus its own margins).
func _truncate_row(line: String) -> String:
	if line.length() <= SLOT_ROW_CHAR_BUDGET:
		return line
	var budgeted := line.substr(0, SLOT_ROW_CHAR_BUDGET)
	var last_space := budgeted.rfind(" ")
	if last_space > 0:
		budgeted = budgeted.substr(0, last_space)
	return budgeted.strip_edges() + "…"


func _format_slot_summary(meta: Dictionary) -> String:
	var parts: Array[String] = [String(meta.get("pc_name", "Traveler"))]
	var top_class := String(meta.get("top_class", ""))
	if not top_class.is_empty():
		parts.append("%s Lv%d" % [_title_case(top_class), int(meta.get("top_level", 0))])
	var map_id := String(meta.get("map", ""))
	if not map_id.is_empty():
		parts.append(_title_case(map_id))
	return " — ".join(parts)


func _title_case(id: String) -> String:
	var words := id.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


## The picker's slots payload for UI_SLOT_PICKER_RENDERED -- one entry per
## MANUAL_SLOTS id (never includes the "Back" row, which isn't a slot).
func _slot_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: String in Game.MANUAL_SLOTS:
		var meta := Game.slot_metadata(slot)
		out.append({"slot": slot, "exists": not meta.is_empty(), "summary": "Empty" if meta.is_empty() else _format_slot_summary(meta)})
	return out


func _on_slot_gui_input(event: InputEvent) -> void:
	if not _picking_slot:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_slot_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _slot_cursor:
			_slot_cursor = idx
			_refresh_slots()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_slot_labels, mb.position)
	if idx >= 0:
		_slot_cursor = idx
		_select_slot()


func slot_row_rect(i: int) -> Rect2:
	if not _picking_slot or i < 0 or i >= _slot_labels.size():
		return Rect2()
	var label := _slot_labels[i]
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func _quit_to_title() -> void:
	var main := get_parent()
	if main != null and main.has_method("swap_to_title"):
		main.call_deferred("swap_to_title")


func _refresh() -> void:
	var rows := _active_rows()
	for i in _row_labels.size():
		var label := _row_labels[i] as Label
		label.visible = i < rows.size()
		if i < rows.size():
			var mark := "> " if i == _cursor else "  "
			label.text = mark + _row_text(i)


func _row_text(i: int) -> String:
	var key := String(_active_rows()[i])
	if VOLUME_ROWS.has(key):
		return "%s volume: %d" % [key, int(WIAudio.get_bus_volume(key))]
	return key


func _refresh_confirm() -> void:
	for i in CONFIRM_ROWS.size():
		var mark := "> " if i == _confirm_cursor else "  "
		(_confirm_option_labels[i] as Label).text = mark + String(CONFIRM_ROWS[i])


func _adjust_volume_row(delta: int) -> void:
	var key := String(_active_rows()[_cursor])
	if not VOLUME_ROWS.has(key):
		return
	WIAudio.set_bus_volume(key, WIAudio.get_bus_volume(key) + float(delta))
	_refresh()


func _confirm() -> void:
	match String(_active_rows()[_cursor]):
		"Resume":
			_close()
		"Abandon to Last Save":
			_enter_confirm("abandon")
		"Save":
			_enter_slot_picker("save")
		"Load":
			_enter_slot_picker("load")
		"Load Autosave":
			_close()
			if not Game.load_slot("auto"):
				ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not load save.", "housekeeping": true})
		"Quit to Title":
			_enter_confirm("quit")
		"Settings":
			if settings_ref != null:
				_root.hide()
				settings_ref.call("open", Callable(self, "_reopen_after_settings"))
