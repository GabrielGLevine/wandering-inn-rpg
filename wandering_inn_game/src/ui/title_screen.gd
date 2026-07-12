extends CanvasLayer
## Title screen. Boots as the game's first screen (Main.swap_to_title()).
##
## Two beats, per spec I9 (browser audio-gesture / iframe-focus requirement):
## 1. GESTURE — "Press any key" placeholder; any keypress or click advances to
##    the menu. This doubles as the web AudioContext unlock gesture and the
##    iframe focus-grabber, so title/game audio is never silently dead on a
##    fresh itch.io page load.
## 2. MENU — New Game / Continue / Playtest States (debug builds only) / Quit,
##    arrows to move, Enter to confirm. Continue is enabled iff a save exists
##    (auto or manual, newest wins) and is skipped over (not selectable) while
##    disabled.
##
## New Game calls Game.reset() and Continue calls Game.load_slot(...) only --
## both already emit "game_reset" / "game_loaded", which Main._on_domain_event()
## already handles by re-instantiating the world (swap_to_world.call_deferred()).
## This screen must NOT call Main.swap_to_world() itself or the world would be
## built twice.
##
## "Playtest States" is a THIRD top-level state (PLAYTEST_LIST) hung off
## MENU, gated at build time by `OS.is_debug_build()` (see `_row_visible`)
## so it can never render in a release export (itch/Steam ship
## `--export-release`, which the engine itself flips `is_debug_build()`
## false for -- see qa/web/export_web.sh, the same command release.yml
## runs). It lists `qa/fixtures/*.json` (name + a `_comment`-derived
## one-line summary), story-position-ordered by `PLAYTEST_FIXTURE_ORDER`
## with any unlisted fixture appended via raw dirlist fallback. Confirming
## a row copies that fixture into a DEDICATED "playtest" save slot
## (`Game.install_fixture_save`, the same byte-for-byte copy
## qa/test_driver.gd's `_install_fixture_saves` performs -- never "manual",
## so the user's own save is never clobbered) and loads it via the same
## slot-generic `Game.load_slot` Continue uses -- zero new sim machinery.

enum State { GESTURE, MENU, PLAYTEST_LIST }

## "Settings" is APPENDED at the end (issue #77) -- never inserted earlier --
## so every existing index-based/count-based QA reference (mouse_loop.json's
## `click_title_row row:2` = Continue, title_flow.json's "move down 1" to
## reach Continue) keeps the exact same target row. title_flow.json's
## `selectable_rows` counts DO bump by 1 (a real new always-selectable row),
## re-pinned there.
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
	"near_evolution", "near_consolidation", "pending_offer", "near_generalist",
	"near_mage_cast", "near_ice_floor", "near_defeat", "door_chain_talk_start",
	"door_chain_scout_start", "door_chain_fight_start", "door_awakening_start",
	"portal_menu_start", "near_ruin", "near_garden", "garden_unlocked", "deep_descent_start",
	"climax_surface_start", "climax_sealed_start", "near_act3",
]
const PLAYTEST_PAGE_SIZE := 10
const PLAYTEST_CAUTION := "QA states — counters may be odd. Loads its own slot; your saves are safe."
## Sane truncation budget for a fixture's `_comment` first-sentence summary.
const PLAYTEST_SUMMARY_CHAR_BUDGET := 70
const ENABLED_COLOR := Color(0.95, 0.88, 0.66)
const DISABLED_COLOR := Color(0.5, 0.47, 0.4)
const GESTURE_COLOR := Color(0.85, 0.8, 0.68)
const BACKDROP_COLOR := Color(0.08, 0.06, 0.05)
## Native window size (project.godot's window/size/viewport_* -- this screen
## lives entirely outside the 320x180 world SubViewport, per the header doc,
## so it uses the real window's own pixel space, not the world's).
const NATIVE_SIZE := Vector2(1280.0, 720.0)

## Injected by WIMain._spawn_title so New Game can open character creation.
## The injection idiom (not a tree scan) matches combat_screen.
var main_ref: WIMain
## Set by main.gd alongside main_ref (issue #77) -- the shared
## settings_panel.gd instance, opened by the new "Settings" row.
var settings_ref: Node = null

var _state: int = State.GESTURE
var _cursor := 0
var _continue_enabled := false
var _continue_slot := ""

var _root: Control
var _gesture_label: Label
var _notice_label: Label
var _menu_root: VBoxContainer
var _row_labels: Array[Label] = []
## Parallel to `_row_labels` (same index order) -- the chrome panel Control
## per row (issue #84's click/hover target: the WHOLE pill, not just its
## inner label, matching `_refresh_rows()`'s own texture-swap "selected"
## render).
var _row_panels: Array[Control] = []

## Playtest-state picker. `_fixture_entries` is lazily built on first open
## (`{name:String, summary:String}`, story-position ordered) and cached for
## the rest of the process -- `qa/fixtures/*.json` never changes mid-run.
## `_playtest_cursor` is a GLOBAL index into `_fixture_entries` (not a
## per-page index); the displayed page is derived from it
## (`_playtest_cursor / PLAYTEST_PAGE_SIZE`), so Up/Down auto-paginates.
var _playtest_root: Control
var _playtest_row_labels: Array[Label] = []
var _playtest_page_label: Label
var _fixture_entries: Array[Dictionary] = []
var _playtest_cursor := 0


func _ready() -> void:
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GESTURE:
		if _is_gesture_event(event):
			_enter_menu()
			get_viewport().set_input_as_handled()
		return
	if _state == State.PLAYTEST_LIST:
		_handle_playtest_input(event)
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
	# A pad-only player never touches a key/mouse, so without this the
	# GESTURE beat is an unbeatable wall for them. InputEventJoypadButton
	# only -- InputEventJoypadMotion is deliberately EXCLUDED, or stick
	# drift past the deadzone (a pad resting in a player's lap, no
	# deliberate press) would silently skip the beat, defeating its whole
	# purpose (the web AudioContext-unlock / iframe-focus gesture, per the
	# file header doc).
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
	# the same helper path dialogue_panel.gd/journal.gd use (a symmetric 36
	# stretched the ribbon's short top/bottom border).
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
	# Issue #84: STOP (was IGNORE) + ONE hover/click handler over the whole
	# row list (`UIChrome.control_index_at` against `_row_panels`, WIHotbar's
	# per-bar-not-per-row idiom) -- a row's own chrome panel stays default
	# IGNORE, same as every other UIChrome-built Control.
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


## Builds the (hidden-until-opened) playtest-state picker panel -- a
## title, the fixed caution line, PLAYTEST_PAGE_SIZE row labels (blanked
## when a page has fewer entries than the page size), and a page-position
## label. Same chrome idiom as `_menu_root`'s rows, minus the per-row
## NinePatch (a plain Label list, matching pause_menu.gd's simpler picker
## style -- this panel is denser than the 3/4-row title menu).
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

	# Issue #84: same one-handler-on-the-container idiom as `_menu_root`
	# above, over `_playtest_row_labels` -- `_playtest_global_index` maps the
	# local (on-page) row index the rect scan returns to the GLOBAL fixture
	# index `_playtest_cursor`/`_confirm_playtest_row` use.
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_playtest_gui_input)


func _enter_menu() -> void:
	_state = State.MENU
	_refresh_continue_state()
	_cursor = 0 if _row_selectable(0) else _first_selectable_row()
	_gesture_label.hide()
	_menu_root.show()
	_refresh_rows()
	# `selectable_rows` is the "device-of-truth" row count -- read live off
	# `_row_selectable` (which itself reads `OS.is_debug_build()` for the
	# Playtest States row and `_continue_enabled` for Continue) rather than
	# a hardcoded literal, so this payload always reflects what THIS binary
	# actually rendered, on whatever platform/build it's running as.
	ObservableBus.emit_domain_event(WIEvents.UI_TITLE_RENDERED, {"continue_enabled": _continue_enabled, "selectable_rows": _selectable_row_count()})


## settings_panel.gd's `on_close` callback (issue #77) -- re-shows the
## top-level menu once Settings closes back out, matching pause_menu.gd's
## `_reopen_after_settings` precedent (a resume, not a fresh `_enter_menu()`
## -- no cursor reset, no re-fired ui_title_rendered).
func _reopen_after_settings() -> void:
	if _state == State.MENU:
		_menu_root.show()


func _first_selectable_row() -> int:
	for i in ROWS.size():
		if _row_selectable(i):
			return i
	return 0


## Web builds have no OS process for Quit to close -- there is nothing for it
## to do in a browser tab, so it's hidden outright rather than shown-disabled
## (cleanest: no dead row a player can highlight and wonder about).
##
## "Playtest States" is hidden outright (not shown-disabled) unless
## `OS.is_debug_build()` -- the same engine call every Godot release export
## template bakes to `false` at compile time (a debug export template /
## editor-run / bare `--headless` run all bake it `true`). itch/Steam ship
## via `--export-release` (qa/web/export_web.sh, the exact command
## release.yml's export job runs) which uses the RELEASE template, so this
## row is provably absent from every shipped build -- see this file's
## header doc for the full mechanism note.
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


## How many top-level menu rows are actually reachable by the cursor right
## now, on THIS binary -- title_flow's canonical "device-of-truth" proof
## that the debug gate (and Continue's own enabled/disabled state) is
## live, not assumed.
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
				# Swap through set_patch_texture so the measured art-bbox region
				# follows the texture (the two button arts have different bboxes
				# -- see UIChrome's BLUE_BUTTON_REGION doc comment).
				UIChrome.set_patch_texture(child as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if i == _cursor else UIChrome.BLUE_BUTTON)


## Issue #84: hover highlights a top-level menu row (sets `_cursor`, the SAME
## field `_refresh_rows()`'s mark/color/pill-texture-swap all read -- one
## selection state), a left-click routes through `_confirm()`, the exact
## function Enter calls. Skips (both hover and click) a row that's hidden or
## disabled -- `_row_selectable`, the SAME gate `_move_cursor` already skips
## past for keyboard.
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


## Read-only rect accessor (issue #84, `WIHotbar.slot_rect`'s established
## pattern) -- the on-screen rect of top-level menu row `i` (its WHOLE chrome
## pill, matching the click/hover target above), for QA's `click_title_row`
## step. Empty Rect2 when out of range, the row is hidden, or the state isn't
## MENU (the picker/gesture beats have no such rows on screen).
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
			# Real play (and a QA script opting in via `creation_ui`) routes
			# through the character-creation screen; every OTHER New Game path
			# -- the default TestDriver skip -- calls Game.reset() straight
			# through, byte-identical to before this feature (the creation
			# screen is never even spawned), so every existing canonical is
			# untouched.
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
			_load_slot_or_notice(_continue_slot)
		"Playtest States":
			_enter_playtest_list()
		"Quit":
			get_tree().quit()
		"Settings":
			# Hides the top-level menu (state stays MENU throughout -- see
			# `_reopen_after_settings`) and hands settings_panel.gd a callback
			# to re-show it on Back/Cancel.
			if settings_ref != null:
				_menu_root.hide()
				settings_ref.call("open", Callable(self, "_reopen_after_settings"))


## `load_slot` returns false on a corrupt or older-version save (WISave.
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


# --- Playtest-state picker -------------------------------------------------

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
	_refresh_rows()


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
## `_newest_save_slot` scans only auto/manual, so Continue never offers it;
## pause_menu's Load rows hardcode manual/auto; combat_screen's defeat path
## hardcodes auto; nothing in src/ enumerates the saves dir. The first
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


## Issue #84: hover/click over the playtest picker's rows, mirroring
## `_on_menu_gui_input` -- hover moves `_playtest_cursor` (the SAME field
## `_refresh_playtest()`'s mark/color reads), a click routes through
## `_confirm_playtest_row()`, the exact function Enter calls.
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


## Maps a rect-scanned on-page row index (0..PLAYTEST_PAGE_SIZE-1) to the
## GLOBAL `_fixture_entries` index `_playtest_cursor`/`_confirm_playtest_row`
## use -- the same `page`/`start` derivation `_refresh_playtest()` uses to lay
## the current page out. -1 for no local match or a blank row past the last
## real entry on a partial final page.
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
	_playtest_page_label.text = "Page %d / %d" % [page + 1, _playtest_page_count()]


## Underscore-separated fixture basename -> "Title Case With Spaces" for
## display (e.g. "post_tutorial_street" -> "Post Tutorial Street").
func _display_fixture_name(fixture: String) -> String:
	var words := fixture.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


## Scans `qa/fixtures/*.json` for every fixture, ordered per
## PLAYTEST_FIXTURE_ORDER with unlisted fixtures appended alphabetically
## (raw dirlist fallback), each paired with a `_comment`-derived summary.
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


## First-sentence (or char-budget-truncated) summary of a fixture's
## `_comment` field, "" if the fixture has none (several hand-authored
## fixtures predate the `_comment` convention -- the row falls back to
## the display name alone, still fully usable via `_display_fixture_name`).
func _fixture_summary(fixture: String) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://qa/fixtures/%s.json" % fixture))
	if not (parsed is Dictionary):
		return ""
	return _first_sentence(String((parsed as Dictionary).get("_comment", "")))


## Sane truncation: prefer the first sentence break ("able to."/"?"/"!"
## followed by a space or end of string); fall back to a hard char budget
## with an ellipsis when no early sentence break exists (some `_comment`s
## run long before their first period, e.g. abbreviations like "M-ARC A3").
## The fallback cuts at the last WORD boundary at-or-before the budget, not
## a raw char index (VISUAL-LOG: "...the ambus…" mid-word truncation) --
## only a single unbroken run longer than the whole budget (no space
## anywhere in the first PLAYTEST_SUMMARY_CHAR_BUDGET chars) falls back to
## the raw char cut, so short real words are never split.
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
