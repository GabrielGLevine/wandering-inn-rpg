extends CanvasLayer
## Pause menu — Resume / Save / Load / Load Autosave / Music / SFX /
## Quit to Title. Toggled by `cancel` (Esc) when the field is idle.
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > inventory > world): pause only toggles/consumes input when
## combat is inactive, no dialogue is open, and BOTH the journal and the
## inventory (M7 E4) are closed — world.gd wires `journal_ref`/
## `inventory_ref` after creating all three components so this check does
## not need a scene-tree lookup; world.gd itself checks `pause_menu.open`
## before handling movement/interact.
##
## Reaching Main (M5 S2): this node is instantiated as a DIRECT CHILD of the
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
const VOLUME_ROWS := ["Music", "SFX"]

const CONFIRM_PANEL_SIZE := Vector2(340.0, 158.0)
const CONFIRM_TEXT := "Unsaved progress since the\nlast autosave is lost — quit?"
## Cursor defaults to "No" (index 0) on entry — quitting is destructive.
const CONFIRM_ROWS := ["No", "Yes"]

## True while the pause panel is visible; world.gd and journal.gd gate on this.
var open := false

## Set by world.gd right after both components are instantiated.
var journal_ref: Node = null
## Set by world.gd/main.gd alongside journal_ref (M7 E4 three-way mutual
## exclusion -- see inventory.gd's file doc comment).
var inventory_ref: Node = null

var _root: Control
var _row_labels: Array[Label] = []
var _cursor := 0

var _confirm_root: Control
var _confirm_option_labels: Array[Label] = []
var _confirming_quit := false
var _confirm_cursor := 0


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	_confirm_root = Control.new()
	UIChrome.apply_theme(_confirm_root)
	_confirm_root.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_root.custom_minimum_size = CONFIRM_PANEL_SIZE
	_confirm_root.size = CONFIRM_PANEL_SIZE
	UIChrome.set_offsets(_confirm_root, -CONFIRM_PANEL_SIZE.x * 0.5, -CONFIRM_PANEL_SIZE.y * 0.5, CONFIRM_PANEL_SIZE.x * 0.5, CONFIRM_PANEL_SIZE.y * 0.5)
	_confirm_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var confirm_label := UIChrome.make_label()
	confirm_label.text = CONFIRM_TEXT
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_stack.add_child(confirm_label)
	for i in CONFIRM_ROWS.size():
		var row := UIChrome.make_label("", "Menu")
		confirm_stack.add_child(row)
		_confirm_option_labels.append(row)


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
		_cursor = wrapi(_cursor - 1, 0, ROWS.size())
		_refresh()
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_cursor = wrapi(_cursor + 1, 0, ROWS.size())
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
		var choice := String(CONFIRM_ROWS[_confirm_cursor])
		if choice == "Yes":
			_close()
			_quit_to_title()
		else:
			_exit_confirm_quit()
		vp.set_input_as_handled()


func _can_open() -> bool:
	if Game.sim.combat != null or Game.sim.dialogue != null:
		return false
	if not Game.sim.pending_consolidation.is_empty():
		return false
	if journal_ref != null and bool(journal_ref.get("open")):
		return false
	if inventory_ref != null and bool(inventory_ref.get("open")):
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


func _enter_confirm_quit() -> void:
	_confirming_quit = true
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
	for i in ROWS.size():
		var mark := "> " if i == _cursor else "  "
		(_row_labels[i] as Label).text = mark + _row_text(i)


func _row_text(i: int) -> String:
	var key := String(ROWS[i])
	if VOLUME_ROWS.has(key):
		return "%s volume: %d" % [key, int(WIAudio.get_bus_volume(key))]
	return key


func _refresh_confirm() -> void:
	for i in CONFIRM_ROWS.size():
		var mark := "> " if i == _confirm_cursor else "  "
		(_confirm_option_labels[i] as Label).text = mark + String(CONFIRM_ROWS[i])


## Only Music/SFX rows respond; harmless no-op otherwise.
func _adjust_volume_row(delta: int) -> void:
	var key := String(ROWS[_cursor])
	if not VOLUME_ROWS.has(key):
		return
	WIAudio.set_bus_volume(key, WIAudio.get_bus_volume(key) + float(delta))
	_refresh()


func _confirm() -> void:
	match String(ROWS[_cursor]):
		"Resume":
			_close()
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
			_enter_confirm_quit()
