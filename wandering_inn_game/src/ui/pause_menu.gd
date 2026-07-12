extends CanvasLayer
## Pause menu — Resume / Save / Load / Load Autosave / Music / SFX /
## Quit to Title. Toggled by `cancel` (Esc) when the field is idle.
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): pause only toggles/consumes input when
## no dialogue is open and BOTH the journal and the inventory are closed;
## during combat it opens ONLY from the HOTBAR resting mode (see
## `_can_open`/`combat_ref`) with the reduced COMBAT_ROWS set, whose one
## extra verb is Abandon-to-last-autosave — world.gd wires `journal_ref`/
## `inventory_ref` after creating all three components so this check does
## not need a scene-tree lookup; world.gd itself checks `pause_menu.open`
## before handling movement/interact.
##
## Reaching Main: this node is instantiated as a DIRECT CHILD of the
## `Main` node itself (`main.gd`'s `_spawn_ui_layers()` calls
## `add_child(_pause_menu)` on `self`), so `get_parent()` is Main — no
## scene-tree search needed. Main isn't preloaded here (that would create a
## preload cycle: main.gd already preloads this script) so the call is
## duck-typed via `has_method()`, mirroring main.gd's own
## `world.has_method("inject_ui_refs")` pattern for the same reason.

const PANEL_SIZE := Vector2(280.0, 276.0)
## "Music"/"SFX" double as `WIAudio` bus names, so `_row_text()` and
## `_adjust_volume_row()` can use the row key directly as the bus arg.
const ROWS := ["Resume", "Save", "Load", "Load Autosave", "Music", "SFX", "Quit to Title"]
## The reduced row set while a fight is live (combat_ref.is_resting() gates
## opening at all). No Save/Load rows: combat state is never serialized, so a
## mid-fight save would silently drop the fight — Abandon is the honest verb
## (returns to the last autosave, same slot the defeat path loads).
const COMBAT_ROWS := ["Resume", "Abandon to Last Save", "Music", "SFX", "Quit to Title"]
const VOLUME_ROWS := ["Music", "SFX"]

const CONFIRM_PANEL_SIZE := Vector2(340.0, 158.0)
const CONFIRM_TEXT := "Unsaved progress since the\nlast autosave is lost. Quit?"
const ABANDON_CONFIRM_TEXT := "Abandon the fight? You return\nto your last autosave."
## Cursor defaults to "No" (index 0) on entry — both confirmed actions are
## destructive.
const CONFIRM_ROWS := ["No", "Yes"]

## True while the pause panel is visible; world.gd and journal.gd gate on this.
var open := false

## Set by world.gd right after both components are instantiated.
var journal_ref: Node = null
## Set by world.gd/main.gd alongside journal_ref (three-way mutual
## exclusion -- see inventory.gd's file doc comment).
var inventory_ref: Node = null
## Set by main.gd (the combat screen instance). Gates in-combat opening to
## the HOTBAR resting mode (is_resting()) and owns the abandon teardown
## (abandon_combat()) -- the menu never touches combat internals itself.
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

var _root: Control
var _row_labels: Array[Label] = []
var _cursor := 0
var _confirm_label: Label

var _confirm_root: Control
var _confirm_option_labels: Array[Label] = []
var _confirming_quit := false
## Which destructive action the shared No/Yes panel is confirming:
## "quit" (title) or "abandon" (combat -> last autosave).
var _confirm_action := "quit"
var _confirm_cursor := 0


## The live row set: the reduced COMBAT_ROWS while a fight is up, the full
## set otherwise. Everything cursor/refresh/confirm reads goes through this
## so the two sets can never drift from the rendered labels.
func _active_rows() -> Array:
	return COMBAT_ROWS if Game.sim.combat != null else ROWS


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	# STOP (mouse-filter audit, issue #57): see journal.gd's identical fix's
	# doc comment -- swallows a click on the open panel instead of leaking to
	# the world/board underneath. `.hide()`/`.show()` gate visibility.
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
		var row := UIChrome.make_label("", "Menu")
		row.custom_minimum_size = Vector2(220.0, 24.0)
		menu_stack.add_child(row)
		_row_labels.append(row)
	# Issue #84: ONE hover/click handler on the shared row container (mirrors
	# WIHotbar's per-bar-not-per-slot idiom via UIChrome.control_index_at),
	# not one filter per row -- a row Label stays default IGNORE. Hover moves
	# `_cursor` (the SAME field `_refresh()`'s "> " mark already reads, so
	# hover highlight and keyboard selection are ONE state, never a second
	# highlight system); a click sets `_cursor` then calls `_confirm()`, the
	# exact function Enter calls -- one dispatch path either way.
	menu_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_stack.gui_input.connect(_on_menu_gui_input)

	_confirm_root = Control.new()
	UIChrome.apply_theme(_confirm_root)
	_confirm_root.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_root.custom_minimum_size = CONFIRM_PANEL_SIZE
	_confirm_root.size = CONFIRM_PANEL_SIZE
	UIChrome.set_offsets(_confirm_root, -CONFIRM_PANEL_SIZE.x * 0.5, -CONFIRM_PANEL_SIZE.y * 0.5, CONFIRM_PANEL_SIZE.x * 0.5, CONFIRM_PANEL_SIZE.y * 0.5)
	# STOP (mouse-filter audit, issue #57): same fix as `_root` above.
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
		var row := UIChrome.make_label("", "Menu")
		confirm_stack.add_child(row)
		_confirm_option_labels.append(row)
	# Issue #84: same one-handler-on-the-container idiom as `menu_stack` above,
	# for the No/Yes confirm rows (the abandon-combat confirm is explicitly
	# in scope per the issue's constraints).
	confirm_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_stack.gui_input.connect(_on_confirm_gui_input)


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


## The confirm-panel's own "activate the cursored row" dispatch -- factored
## out of `_handle_confirm_input`'s keyboard `confirm` branch (issue #84) so
## `_on_confirm_gui_input`'s mouse click routes through this SAME function,
## never a parallel activation.
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


## Issue #84: hover highlights a main-menu row (sets `_cursor`, same field
## `_refresh()`'s "> " mark reads -- one selection state, not a second
## highlight), a left-click activates it through `_confirm()`, the exact
## function Enter calls. No-op while the confirm sub-panel is up (that has
## its own handler below) or the panel isn't open (menu_stack has no rect to
## hit anyway once hidden, but `_active_rows()` would be meaningless mid-close).
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


## Issue #84: the confirm sub-panel's own hover/click, mirroring
## `_on_menu_gui_input` -- hover sets `_confirm_cursor` (the same field
## `_refresh_confirm()`'s mark reads), click routes through
## `_select_confirm_choice()`, the SAME function Enter calls.
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


## Read-only rect accessor (issue #84, `WIHotbar.slot_rect`'s established
## pattern) -- the on-screen rect of main-menu row `i` as of the last
## `_refresh()`, for QA's `click_pause_row` step. Empty Rect2 when the panel
## is closed, the row is out of range, or the row isn't part of the CURRENT
## active set (`_active_rows()` -- COMBAT_ROWS mid-fight has fewer rows than
## the full label array; a label beyond that count is hidden by `_refresh()`).
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
	# See `world_ref`'s own doc comment -- an armed field-hotbar cursor wants
	# THIS cancel press for itself (disarm), not a pause-menu open.
	if world_ref != null and world_ref.has_method("field_slot_armed") and bool(world_ref.call("field_slot_armed")):
		return false
	return true


func _open() -> void:
	open = true
	_cursor = 0
	_confirming_quit = false
	_confirm_root.hide()
	_refresh()
	_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_PAUSE_SHOWN, {})


func _close() -> void:
	open = false
	_confirming_quit = false
	_root.hide()
	_confirm_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_PAUSE_HIDDEN, {})


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


## Duck-typed reach to Main — see the class doc comment above for why this
## isn't a typed reference. No autosave here by design (spec: explicit
## testing surface) — Main.swap_to_title() only tears down/rebuilds the UI
## and world layers, it never touches save files. Deferred for the same
## reason Main._on_domain_event() defers swap_to_world() on game_loaded/
## game_reset (see the comment in _unhandled_input): this call happens from
## inside this node's own input-handling stack, and swap_to_title() would
## otherwise remove/queue_free this node (and its CanvasLayer siblings)
## before that stack unwinds.
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


## Only Music/SFX rows respond; harmless no-op otherwise.
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
			_close()
			Game.save_manual()
		"Load":
			_close()
			if not Game.load_slot("manual"):
				ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not load save."})
		"Load Autosave":
			_close()
			if not Game.load_slot("auto"):
				ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Could not load save."})
		"Quit to Title":
			_enter_confirm("quit")
