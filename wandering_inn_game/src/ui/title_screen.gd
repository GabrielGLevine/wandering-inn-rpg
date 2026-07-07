extends CanvasLayer
## Title screen. Boots as the game's first screen (Main.swap_to_title()).
##
## Two beats, per spec I9 (browser audio-gesture / iframe-focus requirement):
## 1. GESTURE — "Press any key" placeholder; any keypress or click advances to
##    the menu. This doubles as the web AudioContext unlock gesture and the
##    iframe focus-grabber, so title/game audio is never silently dead on a
##    fresh itch.io page load.
## 2. MENU — New Game / Continue / Quit, arrows to move, Enter to confirm.
##    Continue is enabled iff a save exists (auto or manual, newest wins) and
##    is skipped over (not selectable) while disabled.
##
## New Game calls Game.reset() and Continue calls Game.load_slot(...) only --
## both already emit "game_reset" / "game_loaded", which Main._on_domain_event()
## already handles by re-instantiating the world (swap_to_world.call_deferred()).
## This screen must NOT call Main.swap_to_world() itself or the world would be
## built twice.

enum State { GESTURE, MENU }

const ROWS: Array[String] = ["New Game", "Continue", "Quit"]
const ENABLED_COLOR := Color(0.95, 0.88, 0.66)
const DISABLED_COLOR := Color(0.5, 0.47, 0.4)
const GESTURE_COLOR := Color(0.85, 0.8, 0.68)
const BACKDROP_COLOR := Color(0.08, 0.06, 0.05)
## Native window size (project.godot's window/size/viewport_* -- this screen
## lives entirely outside the 320x180 world SubViewport, per the header doc,
## so it uses the real window's own pixel space, not the world's).
const NATIVE_SIZE := Vector2(1280.0, 720.0)

## Injected by WIMain._spawn_title so New Game can open character creation
## (M-ARC §5). The injection idiom (not a tree scan) matches combat_screen.
var main_ref: WIMain

var _state: int = State.GESTURE
var _cursor := 0
var _continue_enabled := false
var _continue_slot := ""

var _root: Control
var _gesture_label: Label
var _notice_label: Label
var _menu_root: VBoxContainer
var _row_labels: Array[Label] = []


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GESTURE:
		if _is_gesture_event(event):
			_enter_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()


func _is_gesture_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	# Controller support (S2, issue #18): a pad-only player never touches a
	# key/mouse, so without this the GESTURE beat is an unbeatable wall for
	# them. InputEventJoypadButton only -- InputEventJoypadMotion is
	# deliberately EXCLUDED, or stick drift past the deadzone (a pad resting
	# in a player's lap, no deliberate press) would silently skip the beat,
	# defeating its whole purpose (the web AudioContext-unlock / iframe-focus
	# gesture, per the file header doc).
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _build_ui() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	_build_embers()

	# make_texture_panel gives the ribbon its asymmetric X/Y patch margins —
	# the same helper path dialogue_panel.gd/journal.gd use (H3 review
	# Important 3; a symmetric 36 stretched the ribbon's short top/bottom border).
	var title_panel := UIChrome.make_texture_panel(UIChrome.BLUE_RIBBON)
	title_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_panel.custom_minimum_size = Vector2(640.0, 92.0)
	title_panel.size = Vector2(640.0, 92.0)
	UIChrome.set_offsets(title_panel, -320.0, 180.0, 320.0, 272.0)
	_root.add_child(title_panel)

	var title_margin := MarginContainer.new()
	UIChrome.full_rect(title_margin)
	UIChrome.add_margins(title_margin, 42, 18, 42, 18)
	title_panel.add_child(title_margin)

	var title_label := UIChrome.make_label("THE WANDERING INN", "Title")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_margin.add_child(title_label)

	_gesture_label = UIChrome.make_label("Press any key", "Menu")
	_gesture_label.set_anchors_preset(Control.PRESET_CENTER)
	_gesture_label.custom_minimum_size = Vector2(400.0, 36.0)
	_gesture_label.size = Vector2(400.0, 36.0)
	UIChrome.set_offsets(_gesture_label, -200.0, 34.0, 200.0, 70.0)
	_gesture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gesture_label.add_theme_color_override("font_color", GESTURE_COLOR)
	_root.add_child(_gesture_label)

	var menu_anchor := CenterContainer.new()
	menu_anchor.set_anchors_preset(Control.PRESET_CENTER)
	menu_anchor.custom_minimum_size = Vector2(320.0, 170.0)
	menu_anchor.size = Vector2(320.0, 170.0)
	UIChrome.set_offsets(menu_anchor, -160.0, 34.0, 160.0, 204.0)
	menu_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(menu_anchor)

	_menu_root = VBoxContainer.new()
	_menu_root.add_theme_constant_override("separation", 8)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.hide()
	menu_anchor.add_child(_menu_root)
	for i in ROWS.size():
		var row_panel := UIChrome.make_chrome_panel(UIChrome.BLUE_BUTTON, UIChrome.PATCH_MARGIN)
		row_panel.custom_minimum_size = Vector2(300.0, 44.0)
		_menu_root.add_child(row_panel)
		var row_margin := MarginContainer.new()
		UIChrome.full_rect(row_margin)
		UIChrome.add_margins(row_margin, 20, 8, 20, 8)
		row_panel.add_child(row_margin)
		var row := UIChrome.make_label("", "Menu")
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_margin.add_child(row)
		_row_labels.append(row)

	# End of the gate beat's render (backdrop + title + "press any key" +
	# the menu skeleton, still hidden pending the gesture). Zero-payload --
	# QA scripts that need to drive the gate deterministically (title_flow,
	# S3) wait on this instead of a frame-count guess; title_peek retrofit
	# per the S1 review (progress.md item 1).
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_GATE_RENDERED, {})


## M-BEAUTY Task R1: subtle ember drift over the title screen -- the map
## direction cards' "first impression" beat, and the one atmosphere touch
## that lives entirely outside the world SubViewport (title is native-res UI,
## per this file's header doc). `WIAmbience` is a pure static factory class
## (no autoload, no state -- see ambience.gd's header doc), reachable from
## any UI context the same way hotbar.gd reaches `WISpriteRegistry` directly;
## reusing its "embers" preset here keeps the look consistent with the
## in-world campfire/hearth ember language instead of inventing a new visual
## vocabulary for the title screen alone. Spans the full native-res rect
## (`NATIVE_SIZE`) so a handful of embers drift somewhere on screen at any
## moment; added right after the backdrop and before every other child (the
## ribbon, menu rows, notice label) so it always draws BEHIND them -- tree
## order is draw order within one CanvasLayer -- and never obscures readable
## text. Not phase-gated (the title screen has no time-of-day) and not
## registered with `WIAtmosphere` (that registry exists for the world
## viewport's own lights/emitters only): it just emits continuously,
## unconditionally, for as long as the title screen is alive.
func _build_embers() -> void:
	var embers := WIAmbience.make("embers", Rect2(Vector2.ZERO, NATIVE_SIZE))
	embers.emitting = true
	embers.visible = true
	_root.add_child(embers)


func _enter_menu() -> void:
	_state = State.MENU
	_refresh_continue_state()
	_cursor = 0 if _row_selectable(0) else _first_selectable_row()
	_gesture_label.hide()
	_menu_root.show()
	_refresh_rows()
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_RENDERED, {"continue_enabled": _continue_enabled})


func _first_selectable_row() -> int:
	for i in ROWS.size():
		if _row_selectable(i):
			return i
	return 0


## Web builds have no OS process for Quit to close -- there is nothing for it
## to do in a browser tab, so it's hidden outright rather than shown-disabled
## (cleanest: no dead row a player can highlight and wonder about).
func _row_visible(i: int) -> bool:
	return not (ROWS[i] == "Quit" and OS.has_feature("web"))


func _row_enabled(i: int) -> bool:
	return _continue_enabled if ROWS[i] == "Continue" else true


func _row_selectable(i: int) -> bool:
	return _row_visible(i) and _row_enabled(i)


func _move_cursor(delta: int) -> void:
	var idx := _cursor
	for i in ROWS.size():
		idx = wrapi(idx + delta, 0, ROWS.size())
		if _row_selectable(idx):
			_cursor = idx
			break
	_refresh_rows()


func _refresh_rows() -> void:
	for i in ROWS.size():
		var label: Label = _row_labels[i]
		if not _row_visible(i):
			label.get_parent().get_parent().hide()
			continue
		label.get_parent().get_parent().show()
		var mark := "> " if i == _cursor else "  "
		label.text = mark + ROWS[i]
		label.add_theme_color_override("font_color", ENABLED_COLOR if _row_enabled(i) else DISABLED_COLOR)
		var panel := label.get_parent().get_parent() as Control
		for child: Node in panel.get_children():
			if child is NinePatchRect:
				# UIWAVE2 title-centering fix: swap through set_patch_texture
				# so the measured art-bbox region follows the texture (the two
				# button arts have different bboxes -- see UIChrome's
				# BLUE_BUTTON_REGION doc comment).
				UIChrome.set_patch_texture(child as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if i == _cursor else UIChrome.BLUE_BUTTON)


func _confirm() -> void:
	if not _row_selectable(_cursor):
		return
	match ROWS[_cursor]:
		"New Game":
			# M-ARC §5: real play (and a QA script opting in via `creation_ui`)
			# routes through the character-creation screen; every OTHER New Game
			# path -- the default TestDriver skip -- calls Game.reset() straight
			# through, byte-identical to before this feature (the creation screen
			# is never even spawned), so every existing canonical is untouched.
			if _skip_creation():
				Game.reset()
			elif main_ref != null:
				# Deferred so this input handler (and its trailing
				# set_input_as_handled) finishes before the swap frees this title
				# out of the tree -- same reason Game.reset()'s swap is deferred.
				main_ref.swap_to_char_creation.call_deferred()
			else:
				Game.reset()
		"Continue":
			# M5 final review: load_slot returns false on a corrupt or
			# older-version save (WISave.apply rejects mismatched VERSION).
			# Without feedback the title screen silently does nothing --
			# surface it and grey the row so New Game is the obvious path.
			if not Game.load_slot(_continue_slot):
				_continue_slot = ""
				_refresh_continue_state()
				_show_notice("Save is from an older version. Start a New Game")
		"Quit":
			get_tree().quit()


## True when a QA run is driving and has NOT opted into the real creation UI --
## the default TestDriver New Game skips creation and resets with the everyman
## defaults, keeping every existing canonical byte-unchanged. A char_creation QA
## script sets top-level `creation_ui: true` to take the real path instead.
func _skip_creation() -> bool:
	return TestDriver != null and TestDriver.active() and not TestDriver.wants_creation_ui()


func _refresh_continue_state() -> void:
	_continue_slot = _newest_save_slot()
	_continue_enabled = not _continue_slot.is_empty()


## Returns "auto" or "manual" (whichever save file was modified most recently),
## or "" if neither exists.
func _newest_save_slot() -> String:
	var best_slot := ""
	var best_time := -1
	for slot in ["auto", "manual"]:
		var path := "user://saves/%s.json" % slot
		if FileAccess.file_exists(path):
			var modified_time: int = FileAccess.get_modified_time(path)
			if modified_time > best_time:
				best_time = modified_time
				best_slot = slot
	return best_slot

## One-line feedback strip under the menu (e.g. incompatible-save notice).
func _show_notice(text: String) -> void:
	if _notice_label == null:
		_notice_label = UIChrome.make_label("", "Small")
		_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		UIChrome.set_offsets(_notice_label, -300.0, -60.0, 300.0, -36.0)
		(_menu_root.get_parent() as Control).add_child(_notice_label)
	_notice_label.text = text
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_NOTICE_RENDERED, {"text": text})
