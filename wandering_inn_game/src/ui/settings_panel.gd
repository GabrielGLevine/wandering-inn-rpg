extends CanvasLayer
## Settings + accessibility surface (issue #77) -- Audio (Master/Music/SFX),
## Video (fullscreen), Text Scale, Reduce Motion, a Controls reference
## sub-page, and a "Replay Hints" action. Reachable from BOTH pause_menu.gd
## and title_screen.gd (each spawns/owns its OWN instance -- see main.gd's
## `_spawn_title`/`_spawn_ui_layers`, mirroring how every other UI layer is
## rebuilt fresh on every title/world swap). Same shared-panel idiom as
## pause_menu.gd: one VBox row list, ONE hover/click handler over the whole
## container (`UIChrome.control_index_at`), row activation routes keyboard
## Confirm and mouse click through the SAME function (issue #84 standard).
##
## Persistence lives in WISettings (video/text-scale/accessibility) and
## WIAudio (Master/Music/SFX volume) -- this file only reads/writes through
## those two autoloads, never owns state itself, so it can be freely
## torn down and rebuilt (title/world swap) with zero state loss.
##
## Layer 2 -- above the default-layer (1) UI stack (pause_menu/journal/
## inventory/message_layer/title_screen all use the CanvasLayer default) so
## it draws on top of whichever menu opened it, though `open()`'s caller
## also hides its own root while settings is up (belt-and-braces, not
## load-bearing for visibility).

## Issue #106: grown 340->420 (+80) for ROWS' widened 30px row height (was
## 22px, see `_build_rows_panel`'s row loop) -- same 9-slice-tolerates-resize
## reasoning as pause_menu.gd's identical PANEL_SIZE fix.
const PANEL_SIZE := Vector2(320.0, 420.0)
const CONTROLS_PANEL_SIZE := Vector2(620.0, 380.0)

## Row list. "Settings" is reached from a LATER-appended row on both
## pause_menu.gd's ROWS and title_screen.gd's ROWS (never inserted earlier --
## preserves every existing hardcoded row index in qa/scripts/*.json).
const ROWS := [
	"Master volume", "Music volume", "SFX volume",
	"Fullscreen", "Text Scale", "Reduce Motion",
	"Controls...", "Replay Hints", "Back",
]
## Row key -> WIAudio bus name, for the three volume rows (left/right or
## confirm/click nudges by 1, matching pause_menu.gd's own `_adjust_volume_row`
## semantics, extended to Master).
const AUDIO_ROWS := {"Master volume": "Master", "Music volume": "Music", "SFX volume": "SFX"}

## Controls reference: the mouse column has no InputMap-action analog (mouse
## folds into WIInputHints' "kb" device classification), so it's a small
## local reference table instead of a WIInputHints lookup. Keyed by the SAME
## action names WIInputHints.LABELS carries -- an action with no mouse
## affordance in this game (journal/inventory/cycle/end_turn) renders "--".
const MOUSE_LABELS := {
	"move": "Click ground to walk",
	"interact": "Click adjacent target",
	"confirm": "Click a row / option",
	"hotbar": "Click a hotbar slot",
}

enum State { ROWS, CONTROLS }

## True while this panel is visible -- world.gd/pause_menu.gd/title_screen.gd
## don't currently gate on this (see file doc comment: the caller hides its
## own root instead), but exposed for parity with every other panel's `open`
## field (pause_menu.gd/journal.gd/inventory.gd all expose one the same way).
## Named `is_open` (not bare `open`) because `open` is this panel's own
## PUBLIC entry-point function name (pause_menu.gd/title_screen.gd call
## `settings_ref.call("open", ...)` from outside, unlike every other panel's
## private `_open()`) -- GDScript refuses a function and a var sharing one
## name.
var is_open := false

var _state: int = State.ROWS
var _cursor := 0
var _on_close := Callable()

var _root: Control
var _row_labels: Array[Label] = []

var _controls_root: Control
var _controls_back_label: Label


func _ready() -> void:
	# Above the default-layer (1) UI stack every other panel here uses (see
	# file doc comment) -- explicit, not relying on same-layer tree-order
	# tie-break.
	layer = 2
	_build_rows_panel()
	_build_controls_panel()


func _build_rows_panel() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	# STOP (mouse-filter audit, issue #57/#84 discipline): swallows a click on
	# the open panel instead of leaking to whatever's underneath.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)
	_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 30, 24, 30, 24)
	_root.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var title := UIChrome.make_label("Settings", "Menu")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)

	for i in ROWS.size():
		var row := UIChrome.make_label("", "Small")
		# Issue #106 hit-target audit: 22px design height, one of the worst-
		# measured surfaces (tied with pause_menu.gd's slot-picker rows).
		# Widened to 30 (INPUT region only -- width/text untouched); PANEL_SIZE
		# grown above to match.
		row.custom_minimum_size = Vector2(260.0, 30.0)
		stack.add_child(row)
		_row_labels.append(row)

	# Issue #84: ONE hover/click handler over the shared row container --
	# pause_menu.gd's/title_screen.gd's exact idiom.
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_rows_gui_input)


func _build_controls_panel() -> void:
	_controls_root = Control.new()
	UIChrome.apply_theme(_controls_root)
	_controls_root.set_anchors_preset(Control.PRESET_CENTER)
	_controls_root.custom_minimum_size = CONTROLS_PANEL_SIZE
	_controls_root.size = CONTROLS_PANEL_SIZE
	UIChrome.set_offsets(_controls_root, -CONTROLS_PANEL_SIZE.x * 0.5, -CONTROLS_PANEL_SIZE.y * 0.5, CONTROLS_PANEL_SIZE.x * 0.5, CONTROLS_PANEL_SIZE.y * 0.5)
	_controls_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_root.hide()
	add_child(_controls_root)
	_controls_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 26, 20, 26, 20)
	_controls_root.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	var title := UIChrome.make_label("Controls", "Menu")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)

	# Data-driven from WIInputHints.LABELS -- can never drift from the real
	# glyph table test_input_hints.gd pins (never a hand-copied action list).
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	stack.add_child(grid)
	for header_text: String in ["Action", "Keyboard", "Gamepad", "Mouse"]:
		grid.add_child(UIChrome.make_label(header_text, "Small"))
	var kb_labels: Dictionary = WIInputHints.LABELS["kb"]
	var pad_labels: Dictionary = WIInputHints.LABELS["pad"]
	for action: String in kb_labels:
		grid.add_child(UIChrome.make_label(_format_action_name(action), "Small"))
		grid.add_child(UIChrome.make_label(String(kb_labels[action]), "Small"))
		grid.add_child(UIChrome.make_label(String(pad_labels.get(action, "--")), "Small"))
		grid.add_child(UIChrome.make_label(String(MOUSE_LABELS.get(action, "--")), "Small"))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	stack.add_child(spacer)

	_controls_back_label = UIChrome.make_label("> Back", "Menu")
	stack.add_child(_controls_back_label)
	_controls_back_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_back_label.gui_input.connect(_on_controls_back_gui_input)


## Underscore-separated action id -> "Title Case With Spaces" (mirrors
## title_screen.gd's `_display_fixture_name`).
func _format_action_name(action: String) -> String:
	var words := action.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


## `on_close` fires once, when this panel closes back out (Back/Cancel from
## the ROWS state) -- the caller (pause_menu.gd/title_screen.gd) passes a
## Callable that re-shows its OWN hidden root. Re-entrant safe: calling
## `open()` again while already open just resets the cursor/state, same as
## every other panel's `_open()`.
func open(on_close: Callable = Callable()) -> void:
	is_open = true
	_on_close = on_close
	_state = State.ROWS
	_cursor = 0
	_controls_root.hide()
	_root.show()
	# SHOWN before the first RENDERED (unlike pause_menu.gd's `_open()`,
	# whose own `_refresh()` is silent -- this one's own `_refresh()` emits
	# UI_SETTINGS_RENDERED, so the emission order here is what actually
	# determines the two events' relative order on the bus).
	ObservableBus.emit_domain_event(WIEvents.UI_SETTINGS_SHOWN, {})
	_refresh()


func _close() -> void:
	is_open = false
	_root.hide()
	_controls_root.hide()
	_state = State.ROWS
	ObservableBus.emit_domain_event(WIEvents.UI_SETTINGS_HIDDEN, {})
	if _on_close.is_valid():
		_on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var vp := get_viewport()
	if _state == State.CONTROLS:
		if event.is_action_pressed("cancel") or event.is_action_pressed("confirm"):
			_exit_controls()
			vp.set_input_as_handled()
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
		_adjust_row(-1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_adjust_row(1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_activate_row()
		vp.set_input_as_handled()


## Issue #84: hover highlights a row (sets `_cursor`, the SAME field
## `_refresh()`'s "> " mark reads), a left-click activates it through
## `_activate_row()`, the exact function Confirm calls -- one dispatch path
## either way, pause_menu.gd's/title_screen.gd's exact idiom.
func _on_rows_gui_input(event: InputEvent) -> void:
	if not is_open or _state != State.ROWS:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_row_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _cursor:
			_cursor = idx
			_refresh()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_row_labels, mb.position)
	if idx >= 0:
		_cursor = idx
		_activate_row()


func _on_controls_back_gui_input(event: InputEvent) -> void:
	if _state != State.CONTROLS:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_exit_controls()


## Read-only rect accessor (WIHotbar.slot_rect/pause_menu.row_rect's
## established pattern) for QA's `click_settings_row` step.
func row_rect(i: int) -> Rect2:
	if not is_open or _state != State.ROWS or i < 0 or i >= _row_labels.size():
		return Rect2()
	var label := _row_labels[i]
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func _enter_controls() -> void:
	_state = State.CONTROLS
	_root.hide()
	_controls_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_CONTROLS_RENDERED, {"rows": (WIInputHints.LABELS["kb"] as Dictionary).size()})


func _exit_controls() -> void:
	_state = State.ROWS
	_controls_root.hide()
	_root.show()
	_refresh()


func _row_text(i: int) -> String:
	var key := String(ROWS[i])
	if AUDIO_ROWS.has(key):
		return "%s: %d" % [key, int(WIAudio.get_bus_volume(String(AUDIO_ROWS[key])))]
	match key:
		"Fullscreen":
			return "Fullscreen: %s" % ("On" if WISettings.is_fullscreen() else "Off")
		"Text Scale":
			return "Text Scale: %s" % WISettings.text_scale_label()
		"Reduce Motion":
			return "Reduce Motion: %s" % ("On" if WISettings.reduce_motion() else "Off")
		_:
			return key


func _refresh() -> void:
	for i in ROWS.size():
		var label := _row_labels[i] as Label
		var mark := "> " if i == _cursor else "  "
		label.text = mark + _row_text(i)
	ObservableBus.emit_domain_event(WIEvents.UI_SETTINGS_RENDERED, {
		"master": int(WIAudio.get_bus_volume("Master")),
		"music": int(WIAudio.get_bus_volume("Music")),
		"sfx": int(WIAudio.get_bus_volume("SFX")),
		"fullscreen": WISettings.is_fullscreen(),
		"text_scale_step": WISettings.text_scale_step(),
		"reduce_motion": WISettings.reduce_motion(),
	})


## Left/right fine-adjust for the volume rows (extends pause_menu.gd's
## `_adjust_volume_row` to Master) and the Text Scale step (wraps).
## Harmless no-op on every other row.
func _adjust_row(delta: int) -> void:
	var key := String(ROWS[_cursor])
	if AUDIO_ROWS.has(key):
		var bus := String(AUDIO_ROWS[key])
		WIAudio.set_bus_volume(bus, WIAudio.get_bus_volume(bus) + float(delta))
		_refresh()
	elif key == "Text Scale":
		WISettings.set_text_scale_step(wrapi(WISettings.text_scale_step() + delta, 0, WISettings.TEXT_SCALE_STEPS.size()))
		_refresh()


## Confirm/click dispatch. Volume rows and Text Scale step forward by ONE
## (same as a single Right press) -- gives mouse-only play a working lever
## without a drag-slider widget; Left/Right stay the fine per-step control.
func _activate_row() -> void:
	var key := String(ROWS[_cursor])
	if AUDIO_ROWS.has(key) or key == "Text Scale":
		_adjust_row(1)
		return
	match key:
		"Fullscreen":
			WISettings.toggle_fullscreen()
			_refresh()
		"Reduce Motion":
			WISettings.toggle_reduce_motion()
			_refresh()
		"Controls...":
			_enter_controls()
		"Replay Hints":
			WISettings.replay_hints()
			ObservableBus.emit_domain_event(WIEvents.UI_HINTS_REPLAYED, {})
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Tutorial hints will show again."})
		"Back":
			_close()
