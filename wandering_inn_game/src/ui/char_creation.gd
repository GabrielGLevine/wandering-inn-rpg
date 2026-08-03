extends CanvasLayer
## Flow: title NEW GAME -> this screen -> Game.reset({pc_name,pc_race,pc_gender})
## -> the GDI cold open -> inn. Two steps, native-res title-family UI:
##   PICK -> a 2x3 grid of the six PC sprite variants (pc_human_m/f,
##           pc_drake_m/f, pc_gnoll_m/f), each an idle-animated AnimatedSprite2D
##           via WISpriteRegistry -- arrows move the cursor across the grid,
##           confirm picks the highlighted card and sets pc_race + pc_gender
##           TOGETHER (one visual pick, not a two-step race-then-gender text
##           menu; the sim payload keys are unchanged, this is a
##           presentation-only recomposition).

## Issue #346: two SETUP prompts after the name. They write the SAME
## `WISettings` keys the Settings panel owns -- creation is a convenience
## surface, not a second source of truth, so there is no parallel state to keep
## in sync and nothing new to serialize into the save. Each opens on the
## player's CURRENT value, so a returning player is shown what they already
## chose rather than a reset.
enum Step { PICK, NAME, DIFFICULTY, HINTS }

const NATIVE_SIZE := Vector2(1280.0, 720.0)
const BACKDROP_COLOR := Color(0.08, 0.06, 0.05)
const HINT_COLOR := Color(0.72, 0.68, 0.58)
const NAME_MAX := 16
const BEGIN_BUTTON_SIZE := Vector2(200.0, 48.0)

## The six PC sprite variants, in GridContainer fill order (row-major: top
## row is Male across the three races, bottom row is Female) so a plain
## for-loop over this array lays the grid out correctly with GRID_COLS
## columns. Picking a card sets pc_race + pc_gender together. CONSTRAINT: no
## race/gender text anywhere in this dict on purpose (playtest hotfix #3 --
## identity reads from the art alone; stats are never shown either, same
## rule) -- do not add a label field back without re-checking that rule.
const PC_OPTIONS: Array[Dictionary] = [
	{"race": "human", "gender": "m", "sprite": "pc_human_m"},
	{"race": "drake", "gender": "m", "sprite": "pc_drake_m"},
	{"race": "gnoll", "gender": "m", "sprite": "pc_gnoll_m"},
	{"race": "human", "gender": "f", "sprite": "pc_human_f"},
	{"race": "drake", "gender": "f", "sprite": "pc_drake_f"},
	{"race": "gnoll", "gender": "f", "sprite": "pc_gnoll_f"},
]
const GRID_COLS := 3
const GRID_ROWS := 2
## Playtest hotfix #3: cards carry NO race/gender label any more (identity
## must be evident from the art alone -- see `_refresh_card`'s doc comment)
## and the reclaimed label space folds into the portrait, which also grows
## a further increment on top of that -- CARD_SIZE.y 196->236 (+40),
## PORTRAIT_HEIGHT 128->200 (+56%). The prompt ribbon (shrunk + raised) and
## hint strip (lowered) below make room; see their own offsets.
const CARD_SIZE := Vector2(300.0, 236.0)
const CARD_GAP := Vector2(18.0, 14.0)
const GRID_SIZE := Vector2(936.0, 486.0)  # GRID_COLS*CARD_SIZE.x + gaps, GRID_ROWS*CARD_SIZE.y + gap
const PORTRAIT_HEIGHT := 200.0
const PORTRAIT_CENTER_Y := 118.0  # CARD_SIZE.y * 0.5 -- centered, no label row below it any more

const STEP_PROMPT := {
	Step.PICK: "Who are you?",
	Step.NAME: "Your name",
	Step.DIFFICULTY: "How hard a road?",
	# Short on purpose: the prompt ribbon is a fixed 640-wide texture panel at
	# Title size, and the longer draft ran out past both of its ends (peek frame
	# cc4c). Kept to the width of the PICK/NAME prompts it sits beside.
	Step.HINTS: "Should the journal point?",
}

## The two setup steps' copy. Diegetic, and deliberately NOT a mechanics
## readout: the difficulty rungs take their names from Liscor Hunted's own
## challenge ranks (canon), and no multiplier is quoted to the player here or
## anywhere else. Both are changeable later from Settings, which the hint strip
## says out loud so a player never feels locked in by a menu they met once.
## WIDTH IS A WINDOWED CATCH, not a guess: at 420 the hints rows' copy ran out
## past both ends of the panel (peek frame cc4c). 620 is the width the longest
## row measures inside with margin to spare, and the blurbs were cut down in
## the same pass rather than only widening the furniture.
const CHOICE_ROW_SIZE := Vector2(620.0, 44.0)
const CHOICE_ROW_GAP := 10
const DIFFICULTY_BLURBS := {
	"Bronze": "a gentler road",
	"Silver": "the road as it was cut",
	"Gold": "no allowances",
}
const HINT_CHOICES := [
	{"value": true, "label": "Yes — name the next step", "blurb": "the journal points the way"},
	{"value": false, "label": "No — let me find it", "blurb": "quests read as written"},
]

var _step: int = Step.PICK
var _cursor := 0
var _race := "human"
var _gender := "m"
var _name := ""

var _root: Control
var _prompt_label: Label
var _hint_label: Label
var _grid_anchor: Control
var _cards: Array[Control] = []
var _portraits: Array[AnimatedSprite2D] = []
var _name_edit: LineEdit
var _begin_button: Control

## Issue #346: the shared setup-choice list, reused by BOTH new steps (one
## widget, two datasets -- a second bespoke picker would be two things to keep
## tappable, and the credits-modal lesson a4 #216 is exactly that a
## keyboard-only surface strands a touch player).
var _choice_anchor: Control
var _choice_rows: Array[Control] = []
var _choice_labels: Array[Label] = []
var _choice_cursor := 0
var _difficulty_step := 0
var _quest_hints := true


func _ready() -> void:
	# Issue #346: open on the player's CURRENT settings, not on hardcoded
	# defaults -- the Settings panel is the source of truth and this screen is
	# a shortcut into it, so it has to show what is actually set right now.
	_difficulty_step = WISettings.difficulty_step()
	_quest_hints = WISettings.show_quest_hints()
	_build_ui()
	_render_step()
	ObservableBus.domain_event.connect(_on_domain_event)


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

	var embers := WIAmbience.make("embers", Rect2(Vector2.ZERO, NATIVE_SIZE))
	embers.emitting = true
	embers.visible = true
	_root.add_child(embers)

	var prompt_panel := UIChrome.make_texture_panel(UIChrome.BLUE_RIBBON)
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt_panel.custom_minimum_size = Vector2(640.0, 76.0)
	prompt_panel.size = Vector2(640.0, 76.0)
	UIChrome.set_offsets(prompt_panel, -320.0, 104.0, 320.0, 180.0)
	_root.add_child(prompt_panel)
	var prompt_margin := MarginContainer.new()
	UIChrome.full_rect(prompt_margin)
	UIChrome.add_margins(prompt_margin, 42, 14, 42, 14)
	prompt_panel.add_child(prompt_margin)
	_prompt_label = UIChrome.make_label("", "Title")
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_margin.add_child(_prompt_label)

	_build_picker_grid()
	_build_choice_list()

	_name_edit = LineEdit.new()
	UIChrome.apply_theme(_name_edit)
	_name_edit.placeholder_text = "Traveler"
	_name_edit.editable = true
	_name_edit.max_length = NAME_MAX
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.context_menu_enabled = false
	_name_edit.set_anchors_preset(Control.PRESET_CENTER)
	_name_edit.custom_minimum_size = Vector2(360.0, 48.0)
	_name_edit.size = Vector2(360.0, 48.0)
	UIChrome.set_offsets(_name_edit, -180.0, -24.0, 180.0, 24.0)
	_name_edit.hide()
	_name_edit.text_changed.connect(_on_name_edit_text_changed)
	_name_edit.text_submitted.connect(_on_name_edit_text_submitted)
	_name_edit.focus_entered.connect(_on_name_edit_focus_entered)
	_root.add_child(_name_edit)

	_begin_button = UIChrome.make_chrome_panel(UIChrome.BLUE_BUTTON, UIChrome.PATCH_MARGIN)
	_begin_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_begin_button.set_anchors_preset(Control.PRESET_CENTER)
	_begin_button.custom_minimum_size = BEGIN_BUTTON_SIZE
	_begin_button.size = BEGIN_BUTTON_SIZE
	UIChrome.set_offsets(_begin_button, -BEGIN_BUTTON_SIZE.x * 0.5, 40.0, BEGIN_BUTTON_SIZE.x * 0.5, 40.0 + BEGIN_BUTTON_SIZE.y)
	_begin_button.gui_input.connect(_on_begin_button_gui_input)
	_begin_button.hide()
	# Issue #346: the NAME step no longer commits -- two setup prompts follow it
	# -- so the control that leaves it says so. The commit moved onto the LAST
	# setup row, where confirming a choice and starting the run are one act.
	var begin_label := UIChrome.make_label("Continue", "")
	begin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	begin_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_begin_button.add_child(begin_label)
	_root.add_child(_begin_button)

	_hint_label = UIChrome.make_label("", "Small")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	UIChrome.set_offsets(_hint_label, -400.0, -34.0, 400.0, -4.0)
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	_root.add_child(_hint_label)


## The six-sprite picker grid (2 rows x 3 cols, PC_OPTIONS' own row-major
## order). Cards are built once at _ready and stay in the tree for the
## screen's whole lifetime; only the NAME step hides the whole
## `_grid_anchor` (see _render_step), same show/hide-the-whole-thing idiom
## the old per-step row visibility used, just one container instead of per-row.
func _build_picker_grid() -> void:
	_grid_anchor = CenterContainer.new()
	_grid_anchor.set_anchors_preset(Control.PRESET_CENTER)
	_grid_anchor.custom_minimum_size = GRID_SIZE
	_grid_anchor.size = GRID_SIZE
	UIChrome.set_offsets(_grid_anchor, -GRID_SIZE.x * 0.5, -170.0, GRID_SIZE.x * 0.5, 316.0)
	_grid_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_grid_anchor)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", int(CARD_GAP.x))
	grid.add_theme_constant_override("v_separation", int(CARD_GAP.y))
	# ONE hover/click handler on the grid itself (title_screen.gd's
	# `_menu_root` idiom: the IGNORE ancestors above -- `_root`, `_grid_anchor`
	# -- don't block a STOP descendant from being hit-tested; only THIS
	# container needs to flip). A card's own chrome panel stays default
	# IGNORE.
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	grid.gui_input.connect(_on_grid_gui_input)
	_grid_anchor.add_child(grid)

	for opt: Dictionary in PC_OPTIONS:
		var card := UIChrome.make_chrome_panel(UIChrome.BLUE_BUTTON, UIChrome.PATCH_MARGIN)
		card.custom_minimum_size = CARD_SIZE
		card.size = CARD_SIZE
		grid.add_child(card)

		var sprite_id := String(opt["sprite"])
		var portrait := AnimatedSprite2D.new()
		portrait.sprite_frames = WISpriteRegistry.frames_for(sprite_id)
		portrait.centered = true
		var frame_tex := portrait.sprite_frames.get_frame_texture("idle_down", 0)
		var frame_h := frame_tex.get_size().y if frame_tex != null else PORTRAIT_HEIGHT
		var s := PORTRAIT_HEIGHT / frame_h
		portrait.scale = Vector2(s, s)
		portrait.position = Vector2(CARD_SIZE.x * 0.5, PORTRAIT_CENTER_Y)
		portrait.play("idle_down")
		card.add_child(portrait)
		_portraits.append(portrait)
		_cards.append(card)


## Issue #346: three rows is the widest either setup step needs (difficulty has
## three rungs, hints has two), so the list is built ONCE at the maximum and
## surplus rows hide -- no per-step teardown, and `choice_row_rect` can hand a
## driver a live rect without worrying about which step built it.
const CHOICE_ROW_MAX := 3


func _build_choice_list() -> void:
	_choice_anchor = CenterContainer.new()
	_choice_anchor.set_anchors_preset(Control.PRESET_CENTER)
	UIChrome.set_offsets(_choice_anchor, -CHOICE_ROW_SIZE.x * 0.5, -110.0, CHOICE_ROW_SIZE.x * 0.5, 110.0)
	_choice_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_anchor.hide()
	_root.add_child(_choice_anchor)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", CHOICE_ROW_GAP)
	# ONE hover/click handler on the container, the picker grid's own idiom.
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_choice_gui_input)
	_choice_anchor.add_child(stack)

	for _i in CHOICE_ROW_MAX:
		var row := UIChrome.make_chrome_panel(UIChrome.BLUE_BUTTON, UIChrome.PATCH_MARGIN)
		row.custom_minimum_size = CHOICE_ROW_SIZE
		row.size = CHOICE_ROW_SIZE
		stack.add_child(row)
		var label := UIChrome.make_label("", "")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_child(label)
		_choice_rows.append(row)
		_choice_labels.append(label)


## `[{label, blurb}]` for the ACTIVE setup step, empty off those steps. One
## place derives both the rendered rows and the `options` payload key, so QA
## reads the strings the screen actually drew.
func _choice_options() -> Array:
	var out: Array = []
	match _step:
		Step.DIFFICULTY:
			for name: String in WISettings.DIFFICULTY_LABELS:
				out.append({"label": name, "blurb": String(DIFFICULTY_BLURBS.get(name, ""))})
		Step.HINTS:
			for choice: Dictionary in HINT_CHOICES:
				out.append({"label": String(choice["label"]), "blurb": String(choice["blurb"])})
	return out


func _render_step() -> void:
	_prompt_label.text = String(STEP_PROMPT[_step])
	var is_name := _step == Step.NAME
	var options := _choice_options()
	var is_choice := not options.is_empty()
	_name_edit.visible = is_name
	_begin_button.visible = is_name
	_grid_anchor.visible = _step == Step.PICK
	_choice_anchor.visible = is_choice
	var option_labels: Array[String] = []
	for raw: Variant in options:
		option_labels.append(String((raw as Dictionary)["label"]))
	if is_choice:
		for i in _choice_rows.size():
			var live := i < options.size()
			_choice_rows[i].visible = live
			if not live:
				continue
			var option := options[i] as Dictionary
			_choice_labels[i].text = "%s — %s" % [String(option["label"]), String(option["blurb"])]
			UIChrome.set_patch_texture(_choice_rows[i].get_child(0) as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if i == _choice_cursor else UIChrome.BLUE_BUTTON)
		# Issue #346: say it is not a one-way door. A setup prompt a player
		# meets once and cannot find again is worse than no prompt.
		_hint_label.text = "Arrows to choose  •  %s to confirm  •  %s to go back  •  change it any time in Settings" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	elif is_name:
		_name_edit.text = _name if not _name.is_empty() else "Traveler"
		_hint_label.text = "Type a name  •  %s to continue  •  %s to go back" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	else:
		for i in PC_OPTIONS.size():
			_refresh_card(i)
		_hint_label.text = "Arrows to choose  •  %s to confirm  •  %s to go back" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	ObservableBus.emit_domain_event(WIEvents.UI_CHAR_CREATION_RENDERED, {
		"step": _step_name(),
		"options": option_labels,
		"cursor": _choice_cursor if is_choice else -1,
	})


func _refresh_card(i: int) -> void:
	var selected := i == _cursor
	var card := _cards[i]
	for child: Node in card.get_children():
		if child is NinePatchRect:
			UIChrome.set_patch_texture(child as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if selected else UIChrome.BLUE_BUTTON)


func _step_name() -> String:
	match _step:
		Step.PICK: return "pick"
		Step.DIFFICULTY: return "difficulty"
		Step.HINTS: return "hints"
		_: return "name"


## Issue #346: the live on-screen rect of setup-choice row `i`, the exact
## `card_rect`/`begin_button_rect` contract (empty Rect2 when that row is not
## visible on the current step) -- so the tap path is drivable and a touch
## player is never stranded on a new prompt.
func choice_row_rect(i: int) -> Rect2:
	if i < 0 or i >= _choice_rows.size():
		return Rect2()
	var row := _choice_rows[i]
	if row == null or not row.visible or not _choice_anchor.visible:
		return Rect2()
	return Rect2(row.global_position, row.size)


func click_choice_row(i: int) -> void:
	if _choice_options().is_empty() or i < 0 or i >= _choice_options().size():
		return
	_choice_cursor = i
	_confirm()


func _on_choice_gui_input(event: InputEvent) -> void:
	var options := _choice_options()
	if options.is_empty():
		return
	var live_rows: Array[Control] = []
	for i in options.size():
		live_rows.append(_choice_rows[i])
	if event is InputEventMouseMotion:
		var hover := UIChrome.control_index_at(live_rows, (event as InputEventMouseMotion).position)
		if hover >= 0 and hover != _choice_cursor:
			_choice_cursor = hover
			_render_step()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(live_rows, mb.position)
	if idx >= 0:
		click_choice_row(idx)


func _move_choice(delta: int) -> void:
	var options := _choice_options()
	if options.is_empty():
		return
	_choice_cursor = wrapi(_choice_cursor + delta, 0, options.size())
	_render_step()


func _on_grid_gui_input(event: InputEvent) -> void:
	if _step != Step.PICK:
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_cards, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _cursor:
			_cursor = idx
			_render_step()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_cards, mb.position)
	if idx >= 0:
		_cursor = idx
		_confirm()


func card_rect(i: int) -> Rect2:
	if _step != Step.PICK or i < 0 or i >= _cards.size():
		return Rect2()
	var card := _cards[i]
	if card == null or not card.visible:
		return Rect2()
	return Rect2(card.global_position, card.size)


## Issue #106: the Begin button's real on-screen rect, for
## `qa/test_driver.gd`'s `click_char_creation_begin` step -- empty Rect2 off
## the NAME step, same not-visible contract as `card_rect` above.
func begin_button_rect() -> Rect2:
	if _step != Step.NAME or _begin_button == null or not _begin_button.visible:
		return Rect2()
	return Rect2(_begin_button.global_position, _begin_button.size)


func _on_begin_button_gui_input(event: InputEvent) -> void:
	if _step != Step.NAME:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_confirm()


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.NAME:
		_handle_name_input(event)
		return
	if not _choice_options().is_empty():
		_handle_choice_input(event)
		return
	if event.is_action_pressed("move_left"):
		_move_col(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_move_col(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move_row(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_row(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_back()
		get_viewport().set_input_as_handled()


## A one-axis list: up/down (and left/right, so a stick or a d-pad flick reads
## the same either way) move, confirm accepts, cancel steps back.
func _handle_choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		_move_choice(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		_move_choice(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _handle_name_input(event: InputEvent) -> void:
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


func _on_name_edit_text_changed(new_text: String) -> void:
	var filtered := ""
	for i in new_text.length():
		if _is_name_char(new_text[i]):
			filtered += new_text[i]
	filtered = filtered.left(NAME_MAX)
	_name = filtered
	if filtered != new_text:
		_name_edit.text = filtered
		_name_edit.caret_column = filtered.length()


func _on_name_edit_focus_entered() -> void:
	if _name.is_empty() and _name_edit.text != "":
		_name_edit.text = ""


func _on_name_edit_text_submitted(_new_text: String) -> void:
	_confirm()


func _is_name_char(ch: String) -> bool:
	if ch == "" or ch.unicode_at(0) < 0x20:
		return false
	if ch == " " or ch == "-" or ch == "'":
		return true
	return ch.to_lower() != ch.to_upper() or ch.is_valid_int()


func _move_col(delta: int) -> void:
	var col := _cursor % GRID_COLS
	var row := _cursor / GRID_COLS
	col = wrapi(col + delta, 0, GRID_COLS)
	_cursor = row * GRID_COLS + col
	_render_step()


func _move_row(delta: int) -> void:
	var col := _cursor % GRID_COLS
	var row := _cursor / GRID_COLS
	row = wrapi(row + delta, 0, GRID_ROWS)
	_cursor = row * GRID_COLS + col
	_render_step()


func _confirm() -> void:
	match _step:
		Step.PICK:
			var opt: Dictionary = PC_OPTIONS[_cursor]
			_race = String(opt["race"])
			_gender = String(opt["gender"])
			_step = Step.NAME
			_render_step()
		Step.NAME:
			_step = Step.DIFFICULTY
			_choice_cursor = _difficulty_step
			_render_step()
		Step.DIFFICULTY:
			_difficulty_step = _choice_cursor
			_step = Step.HINTS
			_choice_cursor = 0 if _quest_hints else 1
			_render_step()
		Step.HINTS:
			_quest_hints = bool((HINT_CHOICES[_choice_cursor] as Dictionary)["value"])
			_begin_game()


func _back() -> void:
	match _step:
		Step.PICK:
			if _main() != null:
				_main().swap_to_title.call_deferred()
		Step.NAME:
			_step = Step.PICK
			_cursor = _option_index()
			_render_step()
		Step.DIFFICULTY:
			_step = Step.NAME
			_render_step()
		Step.HINTS:
			_step = Step.DIFFICULTY
			_choice_cursor = _difficulty_step
			_render_step()


func _option_index() -> int:
	for i in PC_OPTIONS.size():
		var opt: Dictionary = PC_OPTIONS[i]
		if String(opt["race"]) == _race and String(opt["gender"]) == _gender:
			return i
	return 0


func _begin_game() -> void:
	var final_name := _name.strip_edges()
	if final_name == "":
		final_name = "Traveler"
	# Issue #346: the two setup prompts write the SETTINGS, not the save.
	# `WISettings` is config-file-backed and never touched by WISave/Game.reset,
	# so writing BEFORE reset is safe by construction -- and because these are
	# the same keys the Settings panel owns, the player can move either of them
	# again five minutes later with no second source of truth to reconcile.
	WISettings.set_difficulty_step(_difficulty_step)
	WISettings.set_show_quest_hints(_quest_hints)
	var creation := {"pc_name": final_name, "pc_race": _race, "pc_gender": _gender}
	# The chosen setup values ride the confirmation payload (they are NOT part
	# of `creation`, which is the sim's own cosmetic-identity dict and must stay
	# exactly the three keys Game.reset consumes).
	var confirmed := creation.duplicate()
	confirmed["difficulty_step"] = _difficulty_step
	confirmed["quest_hints"] = _quest_hints
	ObservableBus.emit_domain_event(WIEvents.UI_CHAR_CREATION_CONFIRMED, confirmed)
	Game.reset(creation)


func _main() -> WIMain:
	return get_parent() as WIMain
