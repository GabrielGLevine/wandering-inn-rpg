extends CanvasLayer
## This screen must NOT call Main.swap_to_world() itself or the world would be
## built twice.

enum State { GESTURE, MENU, PLAYTEST_LIST, NEW_GAME_CONFIRM }

const ROWS: Array[String] = ["New Game", "Continue", "Playtest States", "Quit", "Settings"]
## Story-position ordering for the playtest-state picker. Any
## `qa/fixtures/*.json` NOT listed here (save-format-migration test fixtures
## like v1_format/v2_format, narrow verification-only fixtures like
## dp2_fixwave_absolute_start, or a future fixture nobody's curated yet)
## falls back to raw alphabetical dirlist order, appended after every
## curated entry (see `_load_fixture_entries`).
const PLAYTEST_FIXTURE_ORDER: Array[String] = [
	"post_tutorial", "post_tutorial_street", "near_sewers", "near_tactician",
	"near_ambush_sneak", "near_rogue", "near_guild", "near_barracks",
	"near_runners_guild", "board_loop_start", "economy_loop_start",
	"gear_loop_start", "cisterns_talk_start", "cisterns_scout_start",
	"cisterns_fight_start", "wrong_order_talk_start", "wrong_order_fight_start",
	"wrong_order_loop_start", "krshia_stage3_pre", "stage3_perks_pre",
	"near_evolution", "near_consolidation", "near_generalist",
	"near_mage_cast", "near_ice_floor", "near_defeat", "door_chain_talk_start",
	"door_chain_scout_start", "door_chain_fight_start", "door_awakening_start",
	"portal_menu_start", "near_ruin", "near_garden", "garden_unlocked", "deep_descent_start",
	"climax_surface_start", "climax_sealed_start", "near_act3",
	"near_mixer",
	# v0.19 close. `martial_field_armed` is the wave's MARQUEE read: the five
	# martial verbs plus [Ice Floor] in one hand, on the floodplains, where the
	# unsteady chute and the carcass both are. `sewers_property_seams` is the
	# mage half of the same sentence -- freeze, cross, thaw, kindle, clean.
	"martial_field_armed", "martial_field_start", "sewers_property_seams",
	# #396 close. APPENDED at the tail deliberately: playtest_boot pins curated
	# indices 30 and 32 (#472 retired `pending_offer` from index 22, shifting the
	# target from 33 to 32), and appending moves nothing before them. Story order --
	# meet the shepherd, stand his watch with him fielded, finish Eloise's quest.
	"winter_teeth_start", "winter_watch_agreed_night", "makings_mid_tend",
]
const PLAYTEST_PAGE_SIZE := 10
const NEW_GAME_CONFIRM_ROWS := ["No", "Yes"]
## GH#186: FIXED size, sized for the longest slot summary + both option
## rows. The v0.11.0 dynamic content-fit measured the autowrap label
## pre-layout and exploded to viewport height; QA auto-collapses this
## confirm (_is_qa), so ONLY a windowed human pass sees this panel --
## keep it deterministic.
const NEW_GAME_CONFIRM_PANEL_SIZE := Vector2(400.0, 225.0)
const PLAYTEST_CAUTION := "QA states — counters may be odd. Loads its own slot; your saves are safe."
const PLAYTEST_SUMMARY_CHAR_BUDGET := 70
const ENABLED_COLOR := Color(0.95, 0.88, 0.66)
const DISABLED_COLOR := Color(0.5, 0.47, 0.4)
const GESTURE_COLOR := Color(0.85, 0.8, 0.68)
const BACKDROP_COLOR := Color(0.08, 0.06, 0.05)
const NATIVE_SIZE := Vector2(1280.0, 720.0)

var main_ref: WIMain
var settings_ref: Node = null

var _state: int = State.GESTURE
var _cursor := 0
var _continue_enabled := false
var _continue_slot := ""

var _root: Control
var _gesture_label: Label
var _gesture_catcher: Control
var _notice_label: Label
var _continue_caption_label: Label
var _menu_root: VBoxContainer
var _chronicle_root: Control
var _row_labels: Array[Label] = []
## Parallel to `_row_labels` (same index order) -- the chrome panel Control
## per row (issue #84's click/hover target: the WHOLE pill, not just its
## inner label, matching `_refresh_rows()`'s own texture-swap "selected"
## render).
var _row_panels: Array[Control] = []

var _playtest_root: Control
var _playtest_row_labels: Array[Label] = []
var _playtest_page_label: Label
## a4 #216 slice 3: touch paging/exit for the playtest picker (row-select tap
## already shipped; paging + exit were keyboard-only).
var _playtest_back_label: Label
var _fixture_entries: Array[Dictionary] = []
var _playtest_cursor := 0

var _new_game_confirm_root: Control
var _new_game_confirm_label: Label
var _new_game_confirm_option_labels: Array[Label] = []
var _new_game_confirm_cursor := 0


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GESTURE:
		if _is_gesture_event(event):
			# GESTURE is functional: it unlocks the browser AudioContext and
			# gives an embedded iframe keyboard focus before menu input begins.
			_enter_menu()
			get_viewport().set_input_as_handled()
		return
	if _state == State.PLAYTEST_LIST:
		_handle_playtest_input(event)
		return
	if _state == State.NEW_GAME_CONFIRM:
		_handle_new_game_confirm_input(event)
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


func _on_gesture_catcher_input(event: InputEvent) -> void:
	if _state != State.GESTURE:
		return
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		# accept BEFORE _enter_menu(): entering the menu frees this very
		# catcher, and accepting through the freed node is a null deref
		# (the sweep's zero-SCRIPT-ERROR bar caught exactly this).
		_gesture_catcher.accept_event()
		_enter_menu()


func _is_gesture_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
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

	# GH#197 (mobile): the title art consumed clicks before _unhandled_input's
	# gesture check, so taps ON the title never satisfied "Press any key".
	# A full-rect catcher above the chrome owns pointer input during GESTURE
	# and is freed on menu entry; keyboard/pad still route via _unhandled_input.
	_gesture_catcher = Control.new()
	_gesture_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gesture_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_gesture_catcher.gui_input.connect(_on_gesture_catcher_input)
	_root.add_child(_gesture_catcher)

	var menu_anchor := CenterContainer.new()
	menu_anchor.set_anchors_preset(Control.PRESET_CENTER)
	menu_anchor.custom_minimum_size = Vector2(320.0, 170.0)
	menu_anchor.size = Vector2(320.0, 170.0)
	UIChrome.set_offsets(menu_anchor, -160.0, 34.0, 160.0, 204.0)
	menu_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(menu_anchor)

	_menu_root = VBoxContainer.new()
	_menu_root.add_theme_constant_override("separation", 8)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_root.gui_input.connect(_on_menu_gui_input)
	_menu_root.hide()
	menu_anchor.add_child(_menu_root)
	for i in ROWS.size():
		var row_panel := UIChrome.make_chrome_panel(UIChrome.BLUE_BUTTON, UIChrome.PATCH_MARGIN)
		row_panel.custom_minimum_size = Vector2(300.0, 44.0)
		_menu_root.add_child(row_panel)
		_row_panels.append(row_panel)
		var row_margin := MarginContainer.new()
		UIChrome.full_rect(row_margin)
		UIChrome.add_margins(row_margin, 20, 8, 20, 8)
		row_panel.add_child(row_margin)
		var row := UIChrome.make_label("", "Menu")
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_margin.add_child(row)
		_row_labels.append(row)

	_build_playtest_panel()
	_build_new_game_confirm_panel()

	# End of the gate beat's render (backdrop + title + "press any key" +
	# the menu skeleton, still hidden pending the gesture). Zero-payload --
	# QA scripts that need to drive the gate deterministically (title_flow)
	# wait on this instead of a frame-count guess.
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_GATE_RENDERED, {})


## Subtle ember drift over the title screen -- the map direction cards'
## "first impression" beat, and the one atmosphere touch that lives
## entirely outside the world SubViewport (title is native-res UI, per
## this file's header doc). `WIAmbience` is a pure static factory class
## (no autoload, no state -- see ambience.gd's header doc), reachable from
## any UI context the same way hotbar.gd reaches `WISpriteRegistry`
## directly; reusing its "embers" preset here keeps the look consistent
## with the in-world campfire/hearth ember language instead of inventing a
## new visual vocabulary for the title screen alone. Spans the full
## native-res rect (`NATIVE_SIZE`) so a handful of embers drift somewhere
## on screen at any moment; added right after the backdrop and before
## every other child (the ribbon, menu rows, notice label) so it always
## draws BEHIND them -- tree order is draw order within one CanvasLayer --
## and never obscures readable text. Not phase-gated (the title screen has
## no time-of-day) and not registered with `WIAtmosphere` (that registry
## exists for the world viewport's own lights/emitters only): it just
## emits continuously, unconditionally, for as long as the title screen is
## alive.
func _build_embers() -> void:
	var embers := WIAmbience.make("embers", Rect2(Vector2.ZERO, NATIVE_SIZE))
	embers.emitting = true
	embers.visible = true
	_root.add_child(embers)


func _build_playtest_panel() -> void:
	_playtest_root = Control.new()
	UIChrome.apply_theme(_playtest_root)
	_playtest_root.set_anchors_preset(Control.PRESET_CENTER)
	var panel_size := Vector2(680.0, 400.0)
	_playtest_root.custom_minimum_size = panel_size
	_playtest_root.size = panel_size
	UIChrome.set_offsets(_playtest_root, -panel_size.x * 0.5, -panel_size.y * 0.5, panel_size.x * 0.5, panel_size.y * 0.5)
	_playtest_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playtest_root.hide()
	_root.add_child(_playtest_root)
	_playtest_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 28, 20, 28, 16)
	_playtest_root.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var title := UIChrome.make_label("Playtest States", "Menu")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)

	var caution := UIChrome.make_label(PLAYTEST_CAUTION, "Small")
	caution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(caution)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	stack.add_child(spacer)

	for i in PLAYTEST_PAGE_SIZE:
		var row := UIChrome.make_label("", "Small")
		row.clip_text = true
		stack.add_child(row)
		_playtest_row_labels.append(row)

	_playtest_page_label = UIChrome.make_label("", "Small")
	_playtest_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_playtest_page_label)

	_playtest_back_label = UIChrome.make_label("‹ Back  (Esc)", "Small")
	_playtest_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_playtest_back_label)

	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_playtest_gui_input)


func _build_new_game_confirm_panel() -> void:
	_new_game_confirm_root = Control.new()
	UIChrome.apply_theme(_new_game_confirm_root)
	_new_game_confirm_root.set_anchors_preset(Control.PRESET_CENTER)
	_new_game_confirm_root.custom_minimum_size = NEW_GAME_CONFIRM_PANEL_SIZE
	_new_game_confirm_root.size = NEW_GAME_CONFIRM_PANEL_SIZE
	UIChrome.set_offsets(_new_game_confirm_root, -NEW_GAME_CONFIRM_PANEL_SIZE.x * 0.5, -NEW_GAME_CONFIRM_PANEL_SIZE.y * 0.5, NEW_GAME_CONFIRM_PANEL_SIZE.x * 0.5, NEW_GAME_CONFIRM_PANEL_SIZE.y * 0.5)
	_new_game_confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_game_confirm_root.hide()
	_root.add_child(_new_game_confirm_root)
	_new_game_confirm_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))
	var confirm_margin := MarginContainer.new()
	UIChrome.full_rect(confirm_margin)
	UIChrome.add_margins(confirm_margin, 28, 26, 28, 24)
	_new_game_confirm_root.add_child(confirm_margin)
	var confirm_stack := VBoxContainer.new()
	confirm_stack.add_theme_constant_override("separation", 8)
	confirm_margin.add_child(confirm_stack)
	_new_game_confirm_label = UIChrome.make_label()
	_new_game_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_stack.add_child(_new_game_confirm_label)
	for i in NEW_GAME_CONFIRM_ROWS.size():
		var row := UIChrome.make_label("", "Menu")
		confirm_stack.add_child(row)
		_new_game_confirm_option_labels.append(row)
	confirm_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_stack.gui_input.connect(_on_new_game_confirm_gui_input)


func _enter_menu() -> void:
	_state = State.MENU
	_refresh_continue_state()
	_cursor = 0 if _row_selectable(0) else _first_selectable_row()
	_gesture_label.hide()
	if _gesture_catcher != null:
		_gesture_catcher.queue_free()
		_gesture_catcher = null
	_menu_root.show()
	_refresh_rows()
	# `selectable_rows` is the "device-of-truth" row count -- read live off
	# `_row_selectable` (which itself reads `OS.is_debug_build()` for the
	# Playtest States row and `_continue_enabled` for Continue) rather than
	# a hardcoded literal, so this payload always reflects what THIS binary
	# actually rendered, on whatever platform/build it's running as.
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_RENDERED, {"continue_enabled": _continue_enabled, "selectable_rows": _selectable_row_count()})
	_show_chronicle_card()


func _show_chronicle_card() -> void:
	var facts: Dictionary = WISettings.latest_chronicle()
	if facts.is_empty():
		return
	_chronicle_root = Control.new()
	_chronicle_root.name = "ChronicleCard"
	UIChrome.apply_theme(_chronicle_root)
	_chronicle_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_chronicle_root.custom_minimum_size = Vector2(420.0, 150.0)
	_chronicle_root.size = Vector2(420.0, 150.0)
	UIChrome.set_offsets(_chronicle_root, 24.0, -174.0, 444.0, -24.0)
	_chronicle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chronicle_root)
	_chronicle_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 18, 10, 18, 10)
	_chronicle_root.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)

	var heading := UIChrome.make_label("Chronicle", "Header")
	stack.add_child(heading)
	var identity_line := UIChrome.make_label(_chronicle_identity_line(facts), "Small")
	identity_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(identity_line)
	var ending_line := UIChrome.make_label(String(facts.get("ending", "")), "Small")
	ending_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(ending_line)
	stack.add_child(UIChrome.make_label("%d quests  •  %d victories  •  %d sleeps" % [int(facts.get("quests_completed", 0)), int(facts.get("victories", 0)), int(facts.get("sleeps", 0))], "Small"))
	ObservableBus.emit_domain_event(WIEvents.UI_CHRONICLE_RENDERED, {
		"surface": "title",
		"facts": facts,
	})


func _chronicle_identity_line(facts: Dictionary) -> String:
	var parts: Array[String] = [String(facts.get("name", "Traveler")), String(facts.get("race", ""))]
	for raw_class: Variant in facts.get("classes", []):
		var class_facts := raw_class as Dictionary
		parts.append("%s Lv%d" % [String(class_facts.get("name", "")), int(class_facts.get("level", 0))])
	return " • ".join(parts)


func _reopen_after_settings() -> void:
	if _state == State.MENU:
		_menu_root.show()


func _first_selectable_row() -> int:
	for i in ROWS.size():
		if _row_selectable(i):
			return i
	return 0


func _row_visible(i: int) -> bool:
	if ROWS[i] == "Quit" and OS.has_feature("web"):
		return false
	if ROWS[i] == "Playtest States" and not OS.is_debug_build():
		return false
	return true


func _row_enabled(i: int) -> bool:
	return _continue_enabled if ROWS[i] == "Continue" else true


func _row_selectable(i: int) -> bool:
	return _row_visible(i) and _row_enabled(i)


func _selectable_row_count() -> int:
	var n := 0
	for i in ROWS.size():
		if _row_selectable(i):
			n += 1
	return n


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
				UIChrome.set_patch_texture(child as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if i == _cursor else UIChrome.BLUE_BUTTON)


func _on_menu_gui_input(event: InputEvent) -> void:
	if _state != State.MENU:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_row_panels, (event as InputEventMouseMotion).position)
		if idx >= 0 and _row_selectable(idx) and idx != _cursor:
			_cursor = idx
			_refresh_rows()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_row_panels, mb.position)
	if idx >= 0 and _row_selectable(idx):
		_cursor = idx
		_confirm()


## a4 #216 slice 3: QA rects/state for the playtest touch nav.
func playtest_page_rect() -> Rect2:
	if _state != State.PLAYTEST_LIST or _playtest_page_label == null or not _playtest_page_label.visible:
		return Rect2()
	return Rect2(_playtest_page_label.global_position, _playtest_page_label.size)


func playtest_back_rect() -> Rect2:
	if _state != State.PLAYTEST_LIST or _playtest_back_label == null or not _playtest_back_label.visible:
		return Rect2()
	return Rect2(_playtest_back_label.global_position, _playtest_back_label.size)


func playtest_cursor_page() -> int:
	return _playtest_cursor / PLAYTEST_PAGE_SIZE


func row_rect(i: int) -> Rect2:
	if _state != State.MENU or i < 0 or i >= _row_panels.size():
		return Rect2()
	var panel := _row_panels[i]
	if panel == null or not panel.visible:
		return Rect2()
	return Rect2(panel.global_position, panel.size)


func _confirm() -> void:
	if not _row_selectable(_cursor):
		return
	match ROWS[_cursor]:
		"New Game":
			_handle_new_game_row()
		"Continue":
			_load_slot_or_notice(_continue_slot)
		"Playtest States":
			_enter_playtest_list()
		"Quit":
			get_tree().quit()
		"Settings":
			if settings_ref != null:
				_menu_root.hide()
				settings_ref.call("open", Callable(self, "_reopen_after_settings"))


func _handle_new_game_row() -> void:
	if _newest_save_slot().is_empty():
		_start_new_game()
		return
	_enter_new_game_confirm()


func _start_new_game() -> void:
	if _skip_creation():
		Game.reset()
	elif main_ref != null:
		# Deferred so this input handler (and its trailing
		# set_input_as_handled) finishes before the swap frees this title
		# out of the tree -- same reason Game.reset()'s swap is deferred.
		main_ref.swap_to_char_creation.call_deferred()
	else:
		Game.reset()


func _enter_new_game_confirm() -> void:
	_state = State.NEW_GAME_CONFIRM
	_new_game_confirm_cursor = 0
	var summary := _format_slot_summary(Game.slot_metadata(_newest_save_slot()))
	_new_game_confirm_label.text = "Starting a New Game will overwrite:\n%s\n\nThis cannot be undone." % summary
	_menu_root.hide()
	_new_game_confirm_root.show()
	_refresh_new_game_confirm()
	ObservableBus.emit_domain_event(WIEvents.UI_NEW_GAME_CONFIRM_RENDERED, {"summary": summary})
	if _is_qa():
		# Same collapse contract as sleep_veil.gd's `_is_qa()` (opener/
		# epilogue/defeat): every existing canonical's New Game must keep
		# working unconditionally -- the coverage event above still fires
		# (title_flow.json pins its exact summary), but the interactive
		# Yes/No hold is skipped, auto-resolving to "Yes" the same beat. A
		# human windowed playtest is what actually exercises Confirm/Cancel,
		# same precedent as every other veil mode's own doc comment.
		_exit_new_game_confirm()
		_start_new_game()


func _exit_new_game_confirm() -> void:
	_state = State.MENU
	_new_game_confirm_root.hide()
	_menu_root.show()
	_refresh_rows()


func _handle_new_game_confirm_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		_exit_new_game_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_new_game_confirm_cursor = wrapi(_new_game_confirm_cursor + 1, 0, NEW_GAME_CONFIRM_ROWS.size())
		_refresh_new_game_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select_new_game_confirm_choice()
		get_viewport().set_input_as_handled()


func _select_new_game_confirm_choice() -> void:
	var choice := String(NEW_GAME_CONFIRM_ROWS[_new_game_confirm_cursor])
	_exit_new_game_confirm()
	if choice == "Yes":
		_start_new_game()


func _refresh_new_game_confirm() -> void:
	for i in NEW_GAME_CONFIRM_ROWS.size():
		var mark := "> " if i == _new_game_confirm_cursor else "  "
		_new_game_confirm_option_labels[i].text = mark + String(NEW_GAME_CONFIRM_ROWS[i])


func _on_new_game_confirm_gui_input(event: InputEvent) -> void:
	if _state != State.NEW_GAME_CONFIRM:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_new_game_confirm_option_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _new_game_confirm_cursor:
			_new_game_confirm_cursor = idx
			_refresh_new_game_confirm()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_new_game_confirm_option_labels, mb.position)
	if idx >= 0:
		_new_game_confirm_cursor = idx
		_select_new_game_confirm_choice()


## apply rejects mismatched VERSION). Without feedback the title screen
## silently does nothing -- surface it and grey the Continue row so New
## Game is the obvious path. (Continue-only: the playtest picker loads its
## own "playtest" slot directly and shows its own failure notice -- see
## `_confirm_playtest_row` -- because this helper's failure branch resets
## Continue-slot state, which the picker must not touch.)
func _load_slot_or_notice(slot: String) -> void:
	if not Game.load_slot(slot):
		_continue_slot = ""
		_refresh_continue_state()
		_show_notice("Save is from an older version. Start a New Game")


func _skip_creation() -> bool:
	return TestDriver != null and TestDriver.active() and not TestDriver.wants_creation_ui()


## Issue #88 (gap-2): sleep_veil.gd's `_is_qa()` idiom, independent copy per
## this codebase's per-file component convention (`_format_slot_summary`/
## `_display_fixture_name`'s own precedent) -- gates the New-Game
## overwrite-confirm's interactive Yes/No hold, same contract as every veil
## mode (opener/epilogue/defeat): collapse under ANY QA run (native or web,
## headless or windowed) or a bare headless boot, never under real play.
func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


func _refresh_continue_state() -> void:
	_continue_slot = _newest_save_slot()
	_continue_enabled = not _continue_slot.is_empty()
	_refresh_continue_caption()


func _newest_save_slot() -> String:
	var best_slot := ""
	var best_time := -1
	var candidates: Array[String] = ["auto"]
	candidates.append_array(Game.MANUAL_SLOTS)
	for slot: String in candidates:
		var path := "user://saves/%s.json" % slot
		if FileAccess.file_exists(path):
			var modified_time: int = FileAccess.get_modified_time(path)
			if modified_time > best_time:
				best_time = modified_time
				best_slot = slot
	return best_slot


func _refresh_continue_caption() -> void:
	if _continue_caption_label == null:
		_continue_caption_label = UIChrome.make_label("", "Small")
		_continue_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_continue_caption_label.set_anchors_preset(Control.PRESET_CENTER)
		UIChrome.set_offsets(_continue_caption_label, -160.0, 294.0, 160.0, 328.0)
		_continue_caption_label.add_theme_color_override("font_color", GESTURE_COLOR)
		_root.add_child(_continue_caption_label)
	if not _continue_enabled:
		_continue_caption_label.hide()
		return
	var meta := Game.slot_metadata(_continue_slot)
	if meta.is_empty():
		_continue_caption_label.hide()
		return
	_continue_caption_label.text = _first_sentence(_format_slot_summary(meta))
	_continue_caption_label.show()


func _format_slot_summary(meta: Dictionary) -> String:
	var parts: Array[String] = [String(meta.get("pc_name", "Traveler"))]
	var top_class := String(meta.get("top_class", ""))
	if not top_class.is_empty():
		parts.append("%s Lv%d" % [_display_fixture_name(top_class), int(meta.get("top_level", 0))])
	var map_id := String(meta.get("map", ""))
	if not map_id.is_empty():
		parts.append(_display_fixture_name(map_id))
	return " — ".join(parts)


func _show_notice(text: String) -> void:
	if _notice_label == null:
		_notice_label = UIChrome.make_label("", "Small")
		_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		UIChrome.set_offsets(_notice_label, -300.0, -60.0, 300.0, -36.0)
		(_menu_root.get_parent() as Control).add_child(_notice_label)
	_notice_label.text = text
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_NOTICE_RENDERED, {"text": text})



func _handle_playtest_input(event: InputEvent) -> void:
	var vp := get_viewport()
	if event.is_action_pressed("move_up"):
		_move_playtest_cursor(-1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_playtest_cursor(1)
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_move_playtest_cursor(-PLAYTEST_PAGE_SIZE)
		vp.set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_move_playtest_cursor(PLAYTEST_PAGE_SIZE)
		vp.set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm_playtest_row()
		vp.set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_exit_playtest_list()
		vp.set_input_as_handled()


func _enter_playtest_list() -> void:
	if _fixture_entries.is_empty():
		_fixture_entries = _load_fixture_entries()
	_state = State.PLAYTEST_LIST
	_playtest_cursor = 0
	_menu_root.hide()
	_playtest_root.show()
	_refresh_playtest()
	ObservableBus.emit_domain_event(WIEvents.UI_PLAYTEST_LIST_RENDERED, {"count": _fixture_entries.size(), "pages": _playtest_page_count()})


func _exit_playtest_list() -> void:
	_state = State.MENU
	_playtest_root.hide()
	_menu_root.show()
	# a4 #216 slice 3 review: land the cursor on the FIRST selectable row and
	# emit the menu render (Back used to be silent — QA had no signal and the
	# stale cursor at "Playtest States" made any follow-on nav overshoot).
	_cursor = 0 if _row_selectable(0) else _first_selectable_row()
	_refresh_rows()
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_RENDERED, {"continue_enabled": _continue_enabled, "selectable_rows": _selectable_row_count()})


func _move_playtest_cursor(delta: int) -> void:
	if _fixture_entries.is_empty():
		return
	_playtest_cursor = clampi(_playtest_cursor + delta, 0, _fixture_entries.size() - 1)
	_refresh_playtest()


## Copies the cursored fixture into the DEDICATED "playtest" save slot
## (`Game.install_fixture_save`, the qa/test_driver.gd fixture_save copy) and
## loads that slot directly via the same slot-generic `Game.load_slot`
## Continue uses -- still zero new sim machinery. The slot is "playtest",
## NEVER "manual" -- installing over the manual slot would silently CLOBBER
## the user's own save, and the user is this feature's whole audience. The
## extra slot file is benign everywhere else (traced, not assumed):
## `_newest_save_slot` scans only "auto" + `Game.MANUAL_SLOTS` (issue #78:
## widened from a hardcoded auto/manual pair, but "playtest" was never a
## member of either list, so it's STILL never offered); pause_menu's slot
## picker iterates the SAME `Game.MANUAL_SLOTS` list; combat_screen's defeat
## path hardcodes auto; nothing in src/ enumerates the saves dir. The first
## in-game autosave after booting a state writes "auto" as usual, which
## Continue then picks up. Failure (a bad hand-authored fixture rejected by
## WISave.apply) surfaces its own notice rather than riding
## `_load_slot_or_notice` -- that helper's failure branch resets
## Continue-slot state, which this path must leave untouched.
func _confirm_playtest_row() -> void:
	if _fixture_entries.is_empty():
		return
	var fixture := String(_fixture_entries[_playtest_cursor]["name"])
	if not Game.install_fixture_save(fixture, "playtest") or not Game.load_slot("playtest"):
		_show_notice("Could not load fixture: " + fixture)


func _on_playtest_gui_input(event: InputEvent) -> void:
	if _state != State.PLAYTEST_LIST:
		return
	if event is InputEventMouseMotion:
		var local_idx := UIChrome.control_index_at(_playtest_row_labels, (event as InputEventMouseMotion).position)
		var idx := _playtest_global_index(local_idx)
		if idx >= 0 and idx != _playtest_cursor:
			_playtest_cursor = idx
			_refresh_playtest()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var local_idx := UIChrome.control_index_at(_playtest_row_labels, mb.position)
	var idx := _playtest_global_index(local_idx)
	if idx >= 0:
		_playtest_cursor = idx
		_confirm_playtest_row()
		return
	# a4 #216 slice 3: tap the Back label to exit, or the page label to turn
	# the page (wrap) — the multi-page picker was stuck on page 1 for touch.
	if _playtest_back_label != null and Rect2(_playtest_back_label.position, _playtest_back_label.size).has_point(mb.position):
		_exit_playtest_list()
		return
	if _playtest_page_count() > 1 and _playtest_page_label != null and Rect2(_playtest_page_label.position, _playtest_page_label.size).has_point(mb.position):
		# WRAP to page 0 from the last page (touch has no backward page tap, so
		# a clamp would strand the user on the final page). Land on that page's
		# row 0, clamped to the real list end.
		var next_page := (_playtest_cursor / PLAYTEST_PAGE_SIZE + 1) % _playtest_page_count()
		_playtest_cursor = mini(next_page * PLAYTEST_PAGE_SIZE, _fixture_entries.size() - 1)
		_refresh_playtest()


func _playtest_global_index(local_i: int) -> int:
	if local_i < 0:
		return -1
	var page := _playtest_cursor / PLAYTEST_PAGE_SIZE
	var start := page * PLAYTEST_PAGE_SIZE
	var idx := start + local_i
	if idx < 0 or idx >= _fixture_entries.size():
		return -1
	return idx


func _playtest_page_count() -> int:
	return maxi(1, int(ceil(float(_fixture_entries.size()) / float(PLAYTEST_PAGE_SIZE))))


func _refresh_playtest() -> void:
	var page := _playtest_cursor / PLAYTEST_PAGE_SIZE
	var start := page * PLAYTEST_PAGE_SIZE
	for i in PLAYTEST_PAGE_SIZE:
		var idx := start + i
		var label: Label = _playtest_row_labels[i]
		if idx >= _fixture_entries.size():
			label.text = ""
			continue
		var entry: Dictionary = _fixture_entries[idx]
		var mark := "> " if idx == _playtest_cursor else "  "
		var line := _display_fixture_name(String(entry["name"]))
		var summary := String(entry["summary"])
		if not summary.is_empty():
			line += " — " + summary
		label.text = mark + line
		label.add_theme_color_override("font_color", ENABLED_COLOR if idx == _playtest_cursor else DISABLED_COLOR)
	_playtest_page_label.text = ("Page %d / %d  (tap to turn)" % [page + 1, _playtest_page_count()]) if _playtest_page_count() > 1 else "Page %d / %d" % [page + 1, _playtest_page_count()]


func _display_fixture_name(fixture: String) -> String:
	var words := fixture.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


func _load_fixture_entries() -> Array[Dictionary]:
	var names: Array[String] = []
	var dir := DirAccess.open("res://qa/fixtures")
	if dir != null:
		for f: String in dir.get_files():
			if f.ends_with(".json"):
				names.append(f.get_basename())
	names.sort()
	var ordered: Array[String] = []
	for n: String in PLAYTEST_FIXTURE_ORDER:
		if names.has(n):
			ordered.append(n)
	for n: String in names:
		if not ordered.has(n):
			ordered.append(n)
	var entries: Array[Dictionary] = []
	for n: String in ordered:
		entries.append({"name": n, "summary": _fixture_summary(n)})
	return entries


func _fixture_summary(fixture: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://qa/fixtures/%s.json" % fixture))
	if not (parsed is Dictionary):
		return ""
	return _first_sentence(String((parsed as Dictionary).get("_comment", "")))


func _first_sentence(text: String) -> String:
	if text.is_empty():
		return ""
	for terminator in [". ", "! ", "? "]:
		var at := text.find(terminator)
		if at != -1 and at < PLAYTEST_SUMMARY_CHAR_BUDGET:
			return text.substr(0, at + 1)
	if text.length() <= PLAYTEST_SUMMARY_CHAR_BUDGET:
		return text
	var budgeted := text.substr(0, PLAYTEST_SUMMARY_CHAR_BUDGET)
	var last_space := budgeted.rfind(" ")
	if last_space > 0:
		budgeted = budgeted.substr(0, last_space)
	return budgeted.strip_edges() + "…"
