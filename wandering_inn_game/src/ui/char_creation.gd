extends CanvasLayer
## M-ARC §5 — character creation at New Game (race / gender / name).
##
## Flow: title NEW GAME -> this screen -> Game.reset({pc_name,pc_race,pc_gender})
## -> the GDI cold open -> inn. Three steps, native-res title-family UI:
##   RACE   -> Human / Drake / Gnoll (arrows move, confirm selects)
##   GENDER -> Male / Female (cosmetic sprite variant only)
##   NAME   -> a text field (default placeholder "Traveler"; type to edit,
##             Enter confirms; empty -> "Traveler")
## Esc backs up one step; Esc on the first step returns to the title. Confirming
## the name fires Game.reset(creation), whose GAME_RESET drives WIMain into the
## world + the GDI opener (race-neutral since the 2026-07-07 copy wave).
##
## QA: this screen is spawned ONLY when it is actually wanted -- real play, or a
## QA script that opts in via top-level `creation_ui: true`. Every OTHER New Game
## (the default TestDriver path) never spawns it: title_screen calls Game.reset()
## straight through, byte-identical to before this feature (see
## title_screen.gd::_confirm). So no auto-skip branch is needed here -- if this
## screen is on screen, it is meant to be driven.
##
## Text entry is captured by THIS node's _unhandled_input (not the LineEdit's own
## editing), so it is deterministic and headless-safe (a LineEdit's GUI-focus
## input path is fragile under the headless server); the LineEdit is the display
## surface only (placeholder + text), driven from `_name`. The char_creation QA
## script types via TestDriver's `type_text` step, which injects unicode key
## events that land here exactly like a real keystroke.

enum Step { RACE, GENDER, NAME }

const NATIVE_SIZE := Vector2(1280.0, 720.0)
const BACKDROP_COLOR := Color(0.08, 0.06, 0.05)
const ENABLED_COLOR := Color(0.95, 0.88, 0.66)
const CURSOR_COLOR := Color(1.0, 0.96, 0.8)
const HINT_COLOR := Color(0.72, 0.68, 0.58)
const NAME_MAX := 16

const RACES: Array[Dictionary] = [
	{"id": "human", "label": "Human"},
	{"id": "drake", "label": "Drake"},
	{"id": "gnoll", "label": "Gnoll"},
]
const GENDERS: Array[Dictionary] = [
	{"id": "m", "label": "Male"},
	{"id": "f", "label": "Female"},
]
const STEP_PROMPT := {
	Step.RACE: "Who are you?",
	Step.GENDER: "Your appearance",
	Step.NAME: "Your name",
}

var _step: int = Step.RACE
var _cursor := 0
var _race := "human"
var _gender := "m"
var _name := ""

var _root: Control
var _prompt_label: Label
var _hint_label: Label
var _option_root: VBoxContainer
var _row_labels: Array[Label] = []
var _name_edit: LineEdit


func _ready() -> void:
	_build_ui()
	_render_step()
	ObservableBus.domain_event.connect(_on_domain_event)


## Controller support fix-wave (issue #18 review, LOW): re-render the current
## step on a device swap so the hint strip's glyphs (composed through
## WIInputHints in `_render_step`) can't go stale mid-screen -- e.g. a player
## who picked up the pad on the NAME step. Re-emits UI_CHAR_CREATION_RENDERED
## (a `_render_step` side effect), which is QA-invisible: the harness only
## injects keys, so the device never changes during a canonical run.
func _on_domain_event(type: String, _payload: Dictionary) -> void:
	if type == WIEvents.INPUT_DEVICE_CHANGED:
		_render_step()


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

	# Same ember drift the title screen uses (WIAmbience "embers" preset), so the
	# creation screen reads as one continuous first-impression beat with it.
	var embers := WIAmbience.make("embers", Rect2(Vector2.ZERO, NATIVE_SIZE))
	embers.emitting = true
	embers.visible = true
	_root.add_child(embers)

	# Prompt ribbon (the title screen's BLUE_RIBBON idiom / asymmetric patch).
	var prompt_panel := UIChrome.make_texture_panel(UIChrome.BLUE_RIBBON)
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt_panel.custom_minimum_size = Vector2(640.0, 92.0)
	prompt_panel.size = Vector2(640.0, 92.0)
	UIChrome.set_offsets(prompt_panel, -320.0, 120.0, 320.0, 212.0)
	_root.add_child(prompt_panel)
	var prompt_margin := MarginContainer.new()
	UIChrome.full_rect(prompt_margin)
	UIChrome.add_margins(prompt_margin, 42, 18, 42, 18)
	prompt_panel.add_child(prompt_margin)
	_prompt_label = UIChrome.make_label("", "Title")
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_margin.add_child(_prompt_label)

	# Option list (race/gender rows) — same panel-row idiom as the title menu.
	var option_anchor := CenterContainer.new()
	option_anchor.set_anchors_preset(Control.PRESET_CENTER)
	option_anchor.custom_minimum_size = Vector2(360.0, 220.0)
	option_anchor.size = Vector2(360.0, 220.0)
	UIChrome.set_offsets(option_anchor, -180.0, -40.0, 180.0, 180.0)
	option_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(option_anchor)
	_option_root = VBoxContainer.new()
	_option_root.add_theme_constant_override("separation", 8)
	_option_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	option_anchor.add_child(_option_root)
	# Build the max number of rows we ever need (RACES is the longest); rows are
	# shown/hidden + relabelled per step so the layout is stable.
	for i in RACES.size():
		var row_panel := UIChrome.make_chrome_panel(UIChrome.BLUE_BUTTON, UIChrome.PATCH_MARGIN)
		row_panel.custom_minimum_size = Vector2(320.0, 48.0)
		_option_root.add_child(row_panel)
		var row_margin := MarginContainer.new()
		UIChrome.full_rect(row_margin)
		UIChrome.add_margins(row_margin, 20, 10, 20, 10)
		row_panel.add_child(row_margin)
		var row := UIChrome.make_label("", "Menu")
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_margin.add_child(row)
		_row_labels.append(row)

	# Name field (used on the NAME step only; a LineEdit as the display surface).
	_name_edit = LineEdit.new()
	UIChrome.apply_theme(_name_edit)
	_name_edit.placeholder_text = "Traveler"
	_name_edit.editable = false  # text is driven from `_name`, not native editing
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.context_menu_enabled = false
	_name_edit.set_anchors_preset(Control.PRESET_CENTER)
	_name_edit.custom_minimum_size = Vector2(360.0, 48.0)
	_name_edit.size = Vector2(360.0, 48.0)
	UIChrome.set_offsets(_name_edit, -180.0, -24.0, 180.0, 24.0)
	_name_edit.hide()
	_root.add_child(_name_edit)

	# Hint strip under the content.
	_hint_label = UIChrome.make_label("", "Small")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	UIChrome.set_offsets(_hint_label, -400.0, -90.0, 400.0, -54.0)
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	_root.add_child(_hint_label)


func _current_options() -> Array:
	return RACES if _step == Step.RACE else GENDERS


func _render_step() -> void:
	_prompt_label.text = String(STEP_PROMPT[_step])
	var is_name := _step == Step.NAME
	_name_edit.visible = is_name
	if is_name:
		for row in _row_labels:
			row.get_parent().get_parent().hide()
		# Controller support (S2, issue #18): `_name` (the source of truth for
		# typing/backspace/`_begin_game`'s fallback) stays untouched at "" --
		# only the DISPLAYED text gets the everyman default ("Traveler", the
		# same fallback `_begin_game` already substitutes for an empty name)
		# so a pad-only player -- who cannot type at all, no on-screen keyboard
		# in v1 -- sees a real name already in the field and can confidently
		# press confirm having accepted the default. Keyboard typing is
		# unaffected: the first keystroke sets `_name` and overwrites this
		# text wholesale (`_handle_name_input` always does `_name_edit.text =
		# _name`, never appends to the displayed string), so nothing needs to
		# be cleared first.
		_name_edit.text = _name if not _name.is_empty() else "Traveler"
		# Controller support (S3, issue #18): composed through WIInputHints so
		# a pad-only player sees A/B instead of Enter/Esc; kb-mode glyphs are
		# byte-identical to the old hardcoded strings (WIInputHints.label's
		# own doc comment), so no QA re-pin is needed here.
		_hint_label.text = "Type a name  •  %s to begin  •  %s to go back" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	else:
		var options := _current_options()
		for i in _row_labels.size():
			var panel := _row_labels[i].get_parent().get_parent() as Control
			if i >= options.size():
				panel.hide()
				continue
			panel.show()
			_refresh_row(i, options)
		_hint_label.text = "Up/Down to choose  •  %s to confirm  •  %s to go back" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	ObservableBus.emit_domain_event(WIEvents.UI_CHAR_CREATION_RENDERED, {"step": _step_name()})


func _refresh_row(i: int, options: Array) -> void:
	var label := _row_labels[i]
	var mark := "> " if i == _cursor else "  "
	label.text = mark + String(options[i]["label"])
	label.add_theme_color_override("font_color", CURSOR_COLOR if i == _cursor else ENABLED_COLOR)
	var panel := label.get_parent().get_parent() as Control
	for child: Node in panel.get_children():
		if child is NinePatchRect:
			# UIWAVE2 title-centering fix: swap through set_patch_texture so
			# the measured art-bbox region follows the texture (the two button
			# arts have different bboxes -- see UIChrome's BLUE_BUTTON_REGION
			# doc comment).
			UIChrome.set_patch_texture(child as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if i == _cursor else UIChrome.BLUE_BUTTON)


func _step_name() -> String:
	match _step:
		Step.RACE: return "race"
		Step.GENDER: return "gender"
		_: return "name"


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.NAME:
		_handle_name_input(event)
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
	elif event.is_action_pressed("cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _handle_name_input(event: InputEvent) -> void:
	# Enter / Esc first (they are also key events, so check the actions before the
	# raw-character path below swallows the keystroke).
	if event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel"):
		_back()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_BACKSPACE:
		if not _name.is_empty():
			_name = _name.substr(0, _name.length() - 1)
			_name_edit.text = _name
		get_viewport().set_input_as_handled()
		return
	var ch := char(key.unicode)
	if _is_name_char(ch) and _name.length() < NAME_MAX:
		_name += ch
		_name_edit.text = _name
		get_viewport().set_input_as_handled()


## Sensible name charset: letters, digits, space, hyphen, apostrophe. Filters out
## control chars / punctuation that would read oddly on a turn strip.
func _is_name_char(ch: String) -> bool:
	if ch == "" or ch.unicode_at(0) < 0x20:
		return false
	if ch == " " or ch == "-" or ch == "'":
		return true
	return ch.to_lower() != ch.to_upper() or ch.is_valid_int()


func _move_cursor(delta: int) -> void:
	var count := _current_options().size()
	_cursor = wrapi(_cursor + delta, 0, count)
	_render_step()


func _confirm() -> void:
	match _step:
		Step.RACE:
			_race = String(RACES[_cursor]["id"])
			_step = Step.GENDER
			_cursor = 0
			_render_step()
		Step.GENDER:
			_gender = String(GENDERS[_cursor]["id"])
			_step = Step.NAME
			_render_step()
		Step.NAME:
			_begin_game()


func _back() -> void:
	match _step:
		Step.RACE:
			# Esc on the first step returns to the title (WIMain owns the swap).
			# Deferred so this input handler finishes before the swap frees this
			# screen out of the tree (else get_viewport() would be null on return).
			if _main() != null:
				_main().swap_to_title.call_deferred()
		Step.GENDER:
			_step = Step.RACE
			_cursor = _race_index()
			_render_step()
		Step.NAME:
			_step = Step.GENDER
			_cursor = _gender_index()
			_render_step()


func _race_index() -> int:
	for i in RACES.size():
		if String(RACES[i]["id"]) == _race:
			return i
	return 0


func _gender_index() -> int:
	for i in GENDERS.size():
		if String(GENDERS[i]["id"]) == _gender:
			return i
	return 0


func _begin_game() -> void:
	var final_name := _name.strip_edges()
	if final_name == "":
		final_name = "Traveler"
	var creation := {"pc_name": final_name, "pc_race": _race, "pc_gender": _gender}
	ObservableBus.emit_domain_event(WIEvents.UI_CHAR_CREATION_CONFIRMED, creation)
	# GAME_RESET drives WIMain into the world + the GDI opener (race-neutral); this
	# screen is torn down with the other UI layers on that swap.
	Game.reset(creation)


func _main() -> WIMain:
	return get_parent() as WIMain
