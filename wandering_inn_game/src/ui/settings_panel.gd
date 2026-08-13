extends CanvasLayer

# GH#386: THE MAGIC-CONSTANT ERA IS OVER. Every prior row add answered with
# another +36 on a hardcoded height, and the panel reached 716 of the 720px
# window -- a scroll bleeding off both screen edges with no room for its own
# ornament. The rect is DERIVED now (`_measure_rows_panel_size`, live font
# metrics, the hint-ribbon fix's own idiom) and clamped into the band below, and
# anything that still does not fit SCROLLS instead of growing. So a future row
# costs nothing here, and neither does a Text Scale step, which is the case the
# fixed rect could never answer at all.
const ROWS_PANEL_MIN := Vector2(320.0, 260.0)
## Width ceiling leaves the descriptor tails room at 130%. Height ceiling is
## NOT the target -- the derived height lands near the journal's own framing
## band (y=82..635) at 100% and near 560 at 130%; the ceiling is only the point
## past which the list starts scrolling instead of growing, and no shipped text
## scale reaches it. Set it BELOW the 130% derivation and Back goes off-page --
## which is exactly what a first pass at 553 did, silently, to the mouse path.
const ROWS_PANEL_MAX := Vector2(560.0, 620.0)
const ROWS_MARGIN_X := 30.0
const ROWS_MARGIN_Y := 22.0
const ROWS_SCROLLBAR_RESERVE := 14.0
## Row pitch is ROW_MIN_HEIGHT + ROW_SEPARATION, and it is the number that
## decides whether 17 rows fit a framed panel. Tuned so the derived height
## sits inside the journal band at 100% with the 12px "Small" glyphs still
## clear of both edges.
const ROW_MIN_HEIGHT := 22.0
const ROW_SEPARATION := 3
const GROUP_GAP := 8.0
const CONTROLS_PANEL_SIZE := Vector2(620.0, 380.0)
## GH#386/#379 grew the Help page from 6 sections to 8; 530 no longer carried
## the "> Back" row. 680 is the height `CREDITS_PANEL_SIZE` already proves fits
## the 720px window with its ornament intact. MIRRORED by hand in
## tests/test_copy_fit.gd -- that suite asserts this literal.
const HELP_PANEL_SIZE := Vector2(620.0, 680.0)
## a4 #216: credits content (5 sections) overflowed the 530-tall help panel —
## the Back label (now a functional TAP target) rendered below the parchment.
## Its own taller panel keeps every row, and Back, on the visible page.
const CREDITS_PANEL_SIZE := Vector2(620.0, 680.0)
const HELP_TEXT_WIDTH := HELP_PANEL_SIZE.x - 52.0
const HELP_CONTENT_PATH := "res://data/help_content.json"
const CREDITS_CONTENT_PATH := "res://data/credits.json"

## Row list, REGROUPED (GH#386). The old order was pure append history: every
## new knob landed immediately before "Back" to protect QA pin indices, so by
## v0.18 the two GAMEPLAY settings sat under file management and the two
## near-identical labels ("Quest Thread" / "Quest Hints") were four unrelated
## rows apart. The index contract is a QA-pin concern, not a player concern:
## the order is grouped by what a player came here to change, and
## qa/scripts/settings_loop.json is re-pinned in the same commit.
## "Back" is still the LAST row and still index 16 -- the group sizes happen to
## preserve it, which is worth stating so nobody reads that as coincidence they
## may break. Group boundaries are drawn as SPACERS, not header rows: a header
## would be an unfocusable entry in a list every navigation leg counts through.
const ROWS := [
	"Difficulty", "Combat Speed", "Quest Hints", "Quest Thread",
	"Master volume", "Music volume", "SFX volume",
	"Fullscreen", "Text Scale", "Reduce Motion",
	"Controls...", "Help...", "Credits...", "Replay Hints",
	"Export Save", "Import Save...",
	"Back",
]
## Row indices a group gap is drawn ABOVE. Data, so the grouping cannot drift
## from ROWS by an off-by-one nobody notices until a windowed shot.
const GROUP_GAP_BEFORE := [4, 7, 10, 14, 16]
const AUDIO_ROWS := {"Master volume": "Master", "Music volume": "Music", "SFX volume": "SFX"}
## GH#447: the descriptor tails these two rows used to carry are GONE. They were
## char_creation.gd's blurbs VERBATIM ("one voice for one knob, whichever door
## the player came through"), so when a playtest report cut the blurbs off the
## creation screen as overexplaining, this door had to lose them in the same
## pass or the one voice becomes two. The rows read bare state now
## ("Difficulty: Silver Rank", "Quest Hints: On"); the durable explanation the
## v0.17-close P2 actually wanted is the Help page's own "Difficulty & Quest
## Hints" section, which shipped alongside these tails and stays.
## The rank word in that first row is NOT typed here: it rides inside
## WISettings.DIFFICULTY_LABELS (user ruling 2026-08-13), so this door and the
## creation door say it because they read the same const, not because two
## format strings happen to agree.

const MOUSE_LABELS := {
	"move": "Click ground to walk",
	"interact": "Click adjacent target",
	"confirm": "Click a row / option",
	"hotbar": "Click a hotbar slot",
	"field_readout": "Click Details",
}

enum State { ROWS, CONTROLS, HELP, CREDITS }

## True while this panel is visible -- world.gd/pause_menu.gd/title_screen.gd
## don't currently gate on this (see file doc comment: the caller hides its
## own root instead), but exposed for parity with every other panel's `open`
## field (pause_menu.gd/journal.gd/inventory.gd all expose one the same way).
var is_open := false

var _state: int = State.ROWS
var _cursor := 0
var _on_close := Callable()

var _root: Control
var _rows_scroll: ScrollContainer
var _rows_title: Label
var _row_labels: Array[Label] = []

var _controls_root: Control
var _controls_back_label: Label

var _help_root: Control
var _credits_root: Control
var _credits_section_count := 0
## key (numkey string) -> url, rebuilt on every credits-panel build.
var _credits_links: Dictionary = {}
## a4 #216: per-link-row labels (label -> numkey) + the Back label, so the
## credits modal is fully tap-reachable on mobile (it was keyboard-only:
## open it on touch and you were stuck).
var _credits_link_labels: Array = []
## Parallel to _credits_link_labels (NOT _credits_links.keys(), which would
## de-dupe a reused key and desync the rect lookup) — review hardening.
var _credits_link_keys: Array = []
var _credits_back_label: Control = null
var _help_back_label: Label
var _help_sections: Array = []


func _ready() -> void:
	# Above the default-layer (1) UI stack every other panel here uses (see
	# file doc comment) -- explicit, not relying on same-layer tree-order
	# tie-break.
	layer = 2
	_build_rows_panel()
	_build_controls_panel()
	_build_help_panel()
	_build_credits_panel()


func _build_rows_panel() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)
	_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, int(ROWS_MARGIN_X), int(ROWS_MARGIN_Y), int(ROWS_MARGIN_X), int(ROWS_MARGIN_Y))
	_root.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)

	_rows_title = UIChrome.make_label("Settings", "Menu")
	_rows_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_rows_title)

	# The overflow answer settings_panel.gd's own comment asked for since a9
	# #246. It is inert at every shipped text scale on a 720px window -- the
	# derived rect fits -- and it is what keeps a future row (or a 130% step, or
	# a longer descriptor tail) from bleeding off the parchment again.
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_rows_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_rows_scroll)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", ROW_SEPARATION)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_scroll.add_child(stack)

	for i in ROWS.size():
		if GROUP_GAP_BEFORE.has(i):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0.0, GROUP_GAP)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(gap)
		var row := UIChrome.make_label("", "Small")
		row.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(row)
		_row_labels.append(row)

	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_rows_gui_input)


## The whole rect, from live font metrics (the hint-ribbon fix's idiom): the
## widest rendered row decides the width, the row count and group gaps decide
## the height, and ROWS_PANEL_MIN/MAX bound both. Re-run on every `_refresh()`
## because a Text Scale step is itself a row in this list -- the one case the
## old fixed rect could not answer at all.
func _measure_rows_panel_size() -> Vector2:
	var probe := _row_labels[0] if not _row_labels.is_empty() else null
	if probe == null:
		return ROWS_PANEL_MIN
	var font := probe.get_theme_font("font")
	var font_size := probe.get_theme_font_size("font_size")
	var widest := 0.0
	for i in ROWS.size():
		widest = maxf(widest, font.get_string_size("> " + _row_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var row_h := maxf(ROW_MIN_HEIGHT, float(font.get_height(font_size)))
	var content_h := float(ROWS.size()) * row_h \
			+ float(ROWS.size() - 1) * float(ROW_SEPARATION) \
			+ float(GROUP_GAP_BEFORE.size()) * (GROUP_GAP + float(ROW_SEPARATION))
	# Title row ("Settings" at Menu weight) plus the outer stack's own 6px gap
	# under it -- from the label's OWN minimum size, so a Text Scale step moves
	# it without this function knowing which type variation the title wears.
	var title_h := (_rows_title.get_minimum_size().y if _rows_title != null else 24.0) + 6.0
	return Vector2(
		clampf(widest + ROWS_MARGIN_X * 2.0 + ROWS_SCROLLBAR_RESERVE, ROWS_PANEL_MIN.x, ROWS_PANEL_MAX.x),
		clampf(content_h + title_h + ROWS_MARGIN_Y * 2.0 + 6.0, ROWS_PANEL_MIN.y, ROWS_PANEL_MAX.y))


func _apply_rows_panel_size() -> void:
	var wanted := _measure_rows_panel_size()
	_root.custom_minimum_size = wanted
	_root.size = wanted
	UIChrome.set_offsets(_root, -wanted.x * 0.5, -wanted.y * 0.5, wanted.x * 0.5, wanted.y * 0.5)


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


func _format_action_name(action: String) -> String:
	var words := action.split("_")
	for i in words.size():
		var w: String = words[i]
		if not w.is_empty():
			words[i] = w[0].to_upper() + w.substr(1)
	return " ".join(words)


func _build_help_panel() -> void:
	_help_root = Control.new()
	UIChrome.apply_theme(_help_root)
	_help_root.set_anchors_preset(Control.PRESET_CENTER)
	_help_root.custom_minimum_size = HELP_PANEL_SIZE
	_help_root.size = HELP_PANEL_SIZE
	UIChrome.set_offsets(_help_root, -HELP_PANEL_SIZE.x * 0.5, -HELP_PANEL_SIZE.y * 0.5, HELP_PANEL_SIZE.x * 0.5, HELP_PANEL_SIZE.y * 0.5)
	_help_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_root.hide()
	add_child(_help_root)
	_help_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 26, 20, 26, 20)
	_help_root.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var title := UIChrome.make_label("Help", "Menu")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# The sections scroll; the TITLE and the BACK ROW do not. Back rode off the
	# bottom of the parchment the moment this page went from 6 sections to 8
	# (windowed catch, GH#386) -- the same failure a4 #216 already fixed once by
	# growing the panel, which is a fix with an expiry date. Outside the scroll,
	# Back is reachable at any section count and any text scale.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)

	_help_sections = _load_help_sections()
	for section: Dictionary in _help_sections:
		var body := UIChrome.make_label(_help_line(section))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(HELP_TEXT_WIDTH, 0.0)
		stack.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	outer.add_child(spacer)

	_help_back_label = UIChrome.make_label("> Back", "Menu")
	outer.add_child(_help_back_label)
	_help_back_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_back_label.gui_input.connect(_on_help_back_gui_input)


## `data/help_content.json` -- content is DATA, this file only renders (CLAUDE.md
## convention). `{"sections": [{"heading":String, "body":String}, ...]}`;
## malformed/missing file degrades to an empty panel rather than a load-time
## crash (same graceful-degrade contract UIChrome.chrome_texture uses for a
## missing asset).
func _load_help_sections() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HELP_CONTENT_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("sections") is Array:
		return (parsed as Dictionary)["sections"]
	return []


func _help_line(section: Dictionary) -> String:
	return "%s — %s" % [String(section.get("heading", "")), String(section.get("body", ""))]


func _help_line_by_heading(heading: String) -> String:
	for section: Dictionary in _help_sections:
		if String(section.get("heading", "")) == heading:
			return _help_line(section)
	return ""


func open(on_close: Callable = Callable()) -> void:
	is_open = true
	_on_close = on_close
	_state = State.ROWS
	_cursor = 0
	_controls_root.hide()
	_help_root.hide()
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
	_help_root.hide()
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
	if _state == State.CREDITS:
		if event.is_action_pressed("cancel") or event.is_action_pressed("confirm"):
			_exit_credits()
			vp.set_input_as_handled()
			return
		# GH#186-adjacent (user directive 2026-07-18): numkey link rows --
		# the About section's external links open in the OS browser (web
		# builds open a tab). Event first so QA can assert without a browser.
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var keycode := (event as InputEventKey).keycode
			if keycode >= KEY_1 and keycode <= KEY_9:
				var key_name := str(keycode - KEY_1 + 1)
				if _credits_links.has(key_name):
					var url := String(_credits_links[key_name])
					ObservableBus.emit_domain_event(WIEvents.UI_CREDITS_LINK_OPENED, {"key": key_name, "url": url})
					if not _suppress_shell_open():
						OS.shell_open(url)
					vp.set_input_as_handled()
		return
	if _state == State.HELP:
		if event.is_action_pressed("cancel") or event.is_action_pressed("confirm"):
			_exit_help()
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
		# a4 #216: on a volume/scale/speed row (the +/- adjust rows), a tap on
		# the LEFT half decrements and the RIGHT half increments — touch had
		# no way to turn a value DOWN (tap always activated = +1).
		var key := String(ROWS[idx])
		if AUDIO_ROWS.has(key) or key == "Text Scale" or key == "Combat Speed" or key == "Difficulty":
			var row_ctl := _row_labels[idx] as Control
			var left_half := mb.position.x < row_ctl.position.x + row_ctl.size.x * 0.5
			_adjust_row(-1 if left_half else 1)
			return
		_activate_row()


func _on_controls_back_gui_input(event: InputEvent) -> void:
	if _state != State.CONTROLS:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_exit_controls()


func _on_help_back_gui_input(event: InputEvent) -> void:
	if _state != State.HELP:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_exit_help()


## a4 #216: QA rect hooks for the credits modal's tap surfaces + the
## volume half-row split. Mirror row_rect's null/visibility contract.
func credits_link_rect(key: String) -> Rect2:
	if _state != State.CREDITS:
		return Rect2()
	var idx := _credits_link_keys.find(key)
	if idx < 0 or idx >= _credits_link_labels.size():
		return Rect2()
	var label := _credits_link_labels[idx] as Control
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func credits_back_rect() -> Rect2:
	if _state != State.CREDITS or _credits_back_label == null or not _credits_back_label.visible:
		return Rect2()
	return Rect2(_credits_back_label.global_position, _credits_back_label.size)


func row_rect(i: int) -> Rect2:
	if not is_open or _state != State.ROWS or i < 0 or i >= _row_labels.size():
		return Rect2()
	var label := _row_labels[i]
	if label == null or not label.visible:
		return Rect2()
	# A row scrolled out of the viewport is NOT clickable, and a rect handed out
	# for one produces a click that lands on nothing and reports nothing. Return
	# the null rect so a caller fails loud instead (GH#386: the first pass at
	# this rework clipped "Back" off the page at 115% and every downstream step
	# timed out five seconds at a time with no cause named).
	if _rows_scroll != null:
		var view := Rect2(_rows_scroll.global_position, _rows_scroll.size)
		if not view.encloses(Rect2(label.global_position, label.size)):
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


## Payload sample pins field-readout help copy; Controls owns live glyphs.
func _enter_help() -> void:
	_state = State.HELP
	_root.hide()
	_help_root.show()
	var sample := _help_line_by_heading("Skills & the Hotbar")
	ObservableBus.emit_domain_event(WIEvents.UI_HELP_RENDERED, {"sections": _help_sections.size(), "sample": sample})


func _exit_help() -> void:
	_state = State.ROWS
	_help_root.hide()
	_root.show()
	_refresh()


## GH#147: attribution surface (user ruling 2026-07-18 -- the Settings
## section satisfies pack attribution requirements; Ove Melaa's line is
## verbatim). Content is DATA (data/credits.json); this only renders.
func _build_credits_panel() -> void:
	_credits_root = Control.new()
	UIChrome.apply_theme(_credits_root)
	_credits_root.set_anchors_preset(Control.PRESET_CENTER)
	_credits_root.custom_minimum_size = CREDITS_PANEL_SIZE
	_credits_root.size = CREDITS_PANEL_SIZE
	UIChrome.set_offsets(_credits_root, -CREDITS_PANEL_SIZE.x * 0.5, -CREDITS_PANEL_SIZE.y * 0.5, CREDITS_PANEL_SIZE.x * 0.5, CREDITS_PANEL_SIZE.y * 0.5)
	_credits_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits_root.hide()
	add_child(_credits_root)
	_credits_root.add_child(UIChrome.make_patch(UIChrome.CARVED_PANEL))
	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 26, 12, 26, 10)
	_credits_root.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	var title := UIChrome.make_label("Credits", "Menu")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var payload: Variant = null
	if FileAccess.file_exists(CREDITS_CONTENT_PATH):
		payload = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_CONTENT_PATH))
	var sections: Array = (payload.get("sections", []) if payload is Dictionary else [])
	_credits_section_count = sections.size()
	_credits_links.clear()
	_credits_link_labels.clear()
	_credits_link_keys.clear()
	for section: Variant in sections:
		var head := UIChrome.make_label(String((section as Dictionary).get("heading", "")), "Menu")
		stack.add_child(head)
		for line: Variant in (section as Dictionary).get("lines", []):
			var body := UIChrome.make_label(String(line), "Small")
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size = Vector2(HELP_TEXT_WIDTH, 0.0)
			stack.add_child(body)
		for link: Variant in (section as Dictionary).get("links", []):
			var link_row: Dictionary = link
			_credits_links[String(link_row.get("key", ""))] = String(link_row.get("url", ""))
			_credits_link_keys.append(String(link_row.get("key", "")))
			var row := UIChrome.make_label("%s — %s" % [String(link_row.get("key", "")), String(link_row.get("label", ""))], "Small")
			var link_key := String(link_row.get("key", ""))
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.gui_input.connect(_on_credits_link_gui_input.bind(link_key))
			_credits_link_labels.append(row)
			stack.add_child(row)
	var back := UIChrome.make_label("Back — Esc / tap here", "Menu")
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(_on_credits_back_gui_input)
	_credits_back_label = back
	stack.add_child(back)
	# The panel itself takes a tap anywhere OUTSIDE a link row as escape —
	# no dead modal on touch. Link rows and the back label STOP the event
	# first, so their own handlers win.
	_credits_root.gui_input.connect(_on_credits_panel_gui_input)


## a4 #216 review: a QA/headless run must never actually launch a browser —
## settings_loop taps a link every run (smoke + full tier). The event is
## emitted regardless (QA asserts on it); only the real OS.shell_open is
## gated, matching this file's headless-side-effect discipline.
func _suppress_shell_open() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


func _open_credits_link(key: String) -> void:
	if not _credits_links.has(key):
		return
	var url := String(_credits_links[key])
	ObservableBus.emit_domain_event(WIEvents.UI_CREDITS_LINK_OPENED, {"key": key, "url": url})
	if not _suppress_shell_open():
		OS.shell_open(url)


func _on_credits_link_gui_input(event: InputEvent, key: String) -> void:
	if _state != State.CREDITS:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_open_credits_link(key)
		get_viewport().set_input_as_handled()


func _on_credits_back_gui_input(event: InputEvent) -> void:
	if _state != State.CREDITS:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_exit_credits()
		get_viewport().set_input_as_handled()


func _on_credits_panel_gui_input(event: InputEvent) -> void:
	if _state != State.CREDITS:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_exit_credits()
		get_viewport().set_input_as_handled()


func _enter_credits() -> void:
	_state = State.CREDITS
	_root.hide()
	_credits_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_CREDITS_RENDERED, {"sections": _credits_section_count, "links": _credits_links.size()})


func _exit_credits() -> void:
	_state = State.ROWS
	_credits_root.hide()
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
		"Combat Speed":
			return "Combat Speed: %s" % WISettings.combat_speed_label()
		"Quest Thread":
			return "Quest Thread: %s" % ("On" if WISettings.show_quest_thread() else "Off")
		# GH#338. Named apart from "Quest Thread" on purpose: that one is the
		# opt-in FIELD-HUD strip (default OFF), this one is the journal's own
		# next-step sub-row (default ON), and they switch independently.
		"Quest Hints":
			return "Quest Hints: %s" % ("On" if WISettings.show_quest_hints() else "Off")
		# Issue #345. Cycles like Text Scale / Combat Speed rather than
		# toggling, because it has three positions; the names are Liscor
		# Hunted's own challenge ranks (canon, wiki-verified).
		"Difficulty":
			return "Difficulty: %s" % String(WISettings.difficulty_label())
		_:
			return key


func _refresh() -> void:
	for i in ROWS.size():
		var label := _row_labels[i] as Label
		var mark := "> " if i == _cursor else "  "
		label.text = mark + _row_text(i)
	_apply_rows_panel_size()
	# Keyboard navigation must not walk off the visible page once the list
	# scrolls (only reachable at a large Text Scale today, but that is exactly
	# the state the fixed rect used to lose rows in).
	if _rows_scroll != null and _cursor >= 0 and _cursor < _row_labels.size():
		_rows_scroll.ensure_control_visible(_row_labels[_cursor])
	ObservableBus.emit_domain_event(WIEvents.UI_SETTINGS_RENDERED, {
		"master": int(WIAudio.get_bus_volume("Master")),
		"music": int(WIAudio.get_bus_volume("Music")),
		"sfx": int(WIAudio.get_bus_volume("SFX")),
		"fullscreen": WISettings.is_fullscreen(),
		"text_scale_step": WISettings.text_scale_step(),
		"reduce_motion": WISettings.reduce_motion(),
		"combat_speed_step": WISettings.combat_speed_step(),
		"show_quest_thread": WISettings.show_quest_thread(),
		"show_quest_hints": WISettings.show_quest_hints(),
		"difficulty_step": WISettings.difficulty_step(),
	})


func _adjust_row(delta: int) -> void:
	var key := String(ROWS[_cursor])
	if AUDIO_ROWS.has(key):
		var bus := String(AUDIO_ROWS[key])
		WIAudio.set_bus_volume(bus, WIAudio.get_bus_volume(bus) + float(delta))
		_refresh()
	elif key == "Text Scale":
		WISettings.set_text_scale_step(wrapi(WISettings.text_scale_step() + delta, 0, WISettings.TEXT_SCALE_STEPS.size()))
		_refresh()
	elif key == "Combat Speed":
		WISettings.set_combat_speed_step(wrapi(WISettings.combat_speed_step() + delta, 0, WISettings.COMBAT_SPEED_STEPS.size()))
		_refresh()
	elif key == "Difficulty":
		WISettings.set_difficulty_step(wrapi(WISettings.difficulty_step() + delta, 0, WISettings.DIFFICULTY_LABELS.size()))
		Game.sim.difficulty_damage_taken_mult = WISettings.difficulty_damage_taken_mult()
		_refresh()


## a9 #246: Export dumps the Continue-grade save text (Game.export_save_text,
## save_manual's own blocked-state guard); Import routes caller text through
## Game.import_save_text (trial-sim validated, non-destructive on refusal).
## Three platform arms each: web = JavaScriptBridge blob download / file
## input; desktop = native dialogs; headless (QA) = user://exports files so
## canonicals can assert the whole path without a dialog.
const EXPORT_DIR := "user://exports"
const IMPORT_REFUSED_TOAST := "That file isn't a Wandering Inn save this build can read. Nothing was changed."
var _web_import_cb: JavaScriptObject = null


func _export_save() -> void:
	var text: String = Game.export_save_text()
	if text == "":
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Cannot export right now.", "housekeeping": true})
		return
	var fname := "wandering-inn-save-%d.json" % int(Game.sim.times_slept)
	if OS.has_feature("web"):
		var js := """
var blob = new Blob([%s], {type: 'application/json'});
var a = document.createElement('a');
a.href = URL.createObjectURL(blob);
a.download = %s;
a.click();
URL.revokeObjectURL(a.href);
""" % [JSON.stringify(text), JSON.stringify(fname)]
		JavaScriptBridge.eval(js, true)
		_finish_export(fname)
		return
	if DisplayServer.get_name() == "headless":
		DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
		var f := FileAccess.open("%s/%s" % [EXPORT_DIR, fname], FileAccess.WRITE)
		if f == null:
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Couldn't write the export. Save not exported.", "housekeeping": true})
			return
		f.store_string(text)
		f.close()
		_finish_export(fname)
		return
	var on_picked := func(status: bool, paths: PackedStringArray, _idx: int) -> void:
		if not is_instance_valid(self) or not status or paths.is_empty():
			return
		var out := FileAccess.open(paths[0], FileAccess.WRITE)
		if out == null:
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Couldn't write there. Save not exported.", "housekeeping": true})
			return
		out.store_string(text)
		out.close()
		_finish_export(paths[0].get_file())
	var err := DisplayServer.file_dialog_show("Export Save", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), fname, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json"]), on_picked)
	if err != OK:
		DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
		var f2 := FileAccess.open("%s/%s" % [EXPORT_DIR, fname], FileAccess.WRITE)
		if f2 == null:
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Couldn't write the export. Save not exported.", "housekeeping": true})
			return
		f2.store_string(text)
		f2.close()
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "No file dialog here — exported to %s" % ProjectSettings.globalize_path("%s/%s" % [EXPORT_DIR, fname]), "housekeeping": true})
		ObservableBus.emit_domain_event(WIEvents.SAVE_EXPORTED, {"file": fname, "fallback": true})


func _finish_export(fname: String) -> void:
	ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Save exported: %s" % fname, "housekeeping": true})
	ObservableBus.emit_domain_event(WIEvents.SAVE_EXPORTED, {"file": fname})


func _import_save() -> void:
	if OS.has_feature("web"):
		_web_import_cb = JavaScriptBridge.create_callback(_on_web_import_text)
		JavaScriptBridge.get_interface("window").__wi_import_cb = _web_import_cb
		JavaScriptBridge.eval("""
var inp = document.createElement('input');
inp.type = 'file';
inp.accept = '.json,application/json';
inp.onchange = function() {
	if (!inp.files.length) return;
	var r = new FileReader();
	r.onload = function() { window.__wi_import_cb(r.result); };
	r.readAsText(inp.files[0]);
};
inp.click();
""", true)
		return
	if DisplayServer.get_name() == "headless":
		# QA probe order: an explicit import.json, else the NEWEST export —
		# so a canonical can round-trip Export -> Import in one leg.
		var probe := "%s/import.json" % EXPORT_DIR
		if not FileAccess.file_exists(probe):
			var newest := ""
			var newest_key: Array = [0, 0, ""]
			if DirAccess.dir_exists_absolute(EXPORT_DIR):
				for f in DirAccess.get_files_at(EXPORT_DIR):
					if String(f).ends_with(".json"):
						var ts := FileAccess.get_modified_time("%s/%s" % [EXPORT_DIR, f])
						# strict newest; same-second ties break by length-then-lex
						# (natural order: -10 beats -9; review F8)
						var key: Array = [ts, String(f).length(), String(f)]
						if key > newest_key:
							newest_key = key
							newest = "%s/%s" % [EXPORT_DIR, f]
			probe = newest
		if probe != "" and FileAccess.file_exists(probe):
			_apply_import_text(FileAccess.get_file_as_string(probe))
		else:
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": IMPORT_REFUSED_TOAST, "housekeeping": true})
		return
	var on_picked := func(status: bool, paths: PackedStringArray, _idx: int) -> void:
		if not is_instance_valid(self) or not status or paths.is_empty():
			return
		_apply_import_text(FileAccess.get_file_as_string(paths[0]))
	var err := DisplayServer.file_dialog_show("Import Save", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.json"]), on_picked)
	if err != OK:
		# review F2: no dialog on this platform — the fallback must actually
		# WORK, so this arm reads the same import.json probe the headless arm
		# uses, and names a real OS path.
		var probe2 := "%s/import.json" % EXPORT_DIR
		if FileAccess.file_exists(probe2):
			_apply_import_text(FileAccess.get_file_as_string(probe2))
		else:
			DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "No file dialog here — drop the file at %s and use Import again." % ProjectSettings.globalize_path(probe2), "housekeeping": true})


func _on_web_import_text(args: Array) -> void:
	if args.is_empty():
		return
	_apply_import_text(String(args[0]))


func _apply_import_text(text: String) -> void:
	if Game.import_save_text(text):
		ObservableBus.emit_domain_event(WIEvents.SAVE_IMPORTED, {})
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Save imported. Welcome back.", "housekeeping": true})
		_close()
	else:
		ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": IMPORT_REFUSED_TOAST, "housekeeping": true})


func _activate_row() -> void:
	var key := String(ROWS[_cursor])
	if AUDIO_ROWS.has(key) or key == "Text Scale" or key == "Combat Speed" or key == "Difficulty":
		_adjust_row(1)
		return
	match key:
		"Fullscreen":
			WISettings.toggle_fullscreen()
			_refresh()
		"Reduce Motion":
			WISettings.toggle_reduce_motion()
			_refresh()
		"Quest Thread":
			WISettings.toggle_show_quest_thread()
			_refresh()
		"Quest Hints":
			WISettings.toggle_show_quest_hints()
			_refresh()
		"Controls...":
			_enter_controls()
		"Replay Hints":
			WISettings.replay_hints()
			ObservableBus.emit_domain_event(WIEvents.UI_HINTS_REPLAYED, {})
			ObservableBus.emit_domain_event(WIEvents.TOAST, {"text": "Tutorial hints will show again.", "housekeeping": true})
		"Help...":
			_enter_help()
		"Credits...":
			_enter_credits()
		"Export Save":
			_export_save()
		"Import Save...":
			_import_save()
		"Back":
			_close()
