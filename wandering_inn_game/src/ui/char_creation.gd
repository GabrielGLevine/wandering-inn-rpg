extends CanvasLayer
## Character creation at New Game (sprite picker / name).
##
## Flow: title NEW GAME -> this screen -> Game.reset({pc_name,pc_race,pc_gender})
## -> the GDI cold open -> inn. Two steps, native-res title-family UI:
##   PICK -> a 2x3 grid of the six PC sprite variants (pc_human_m/f,
##           pc_drake_m/f, pc_gnoll_m/f), each an idle-animated AnimatedSprite2D
##           via WISpriteRegistry -- arrows move the cursor across the grid,
##           confirm picks the highlighted card and sets pc_race + pc_gender
##           TOGETHER (one visual pick, not a two-step race-then-gender text
##           menu; the sim payload keys are unchanged, this is a
##           presentation-only recomposition).
##   NAME   -> a text field (default placeholder "Traveler"; type to edit,
##             Enter confirms; empty -> "Traveler")
## Esc backs up one step; Esc on the first step returns to the title. Confirming
## the name fires Game.reset(creation), whose GAME_RESET drives WIMain into the
## world + the GDI opener (race-neutral).
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

enum Step { PICK, NAME }

const NATIVE_SIZE := Vector2(1280.0, 720.0)
const BACKDROP_COLOR := Color(0.08, 0.06, 0.05)
const HINT_COLOR := Color(0.72, 0.68, 0.58)
const NAME_MAX := 16

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
## Uniform on-screen portrait height regardless of source frame size (human
## 104px/drake 124px/gnoll 108px square frames all catalog at different native
## sizes) -- keeps every card's silhouette the same scale for a fair compare.
const PORTRAIT_HEIGHT := 200.0
const PORTRAIT_CENTER_Y := 118.0  # CARD_SIZE.y * 0.5 -- centered, no label row below it any more

const STEP_PROMPT := {
	Step.PICK: "Who are you?",
	Step.NAME: "Your name",
}

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


func _ready() -> void:
	_build_ui()
	_render_step()
	ObservableBus.domain_event.connect(_on_domain_event)


## Re-render the current step on a device swap so the hint strip's glyphs
## (composed through WIInputHints in `_render_step`) can't go stale
## mid-screen -- e.g. a player who picked up the pad on the NAME step.
## Re-emits UI_CHAR_CREATION_RENDERED (a `_render_step` side effect), which
## is QA-invisible: the harness only injects keys, so the device never
## changes during a canonical run.
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
	# Shrunk + raised from the original 92-tall/y120-212 (playtest hotfix #3):
	# reclaims room below for the larger picker grid.
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

	# Hint strip under the content. Lowered from the original y-90/-54
	# (playtest hotfix #3): reclaims room above for the larger picker grid.
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
	# top/bottom widened to fit the taller GRID_SIZE (playtest hotfix #3) --
	# 10px clear of the shrunk prompt ribbon above (bottom edge y180) and the
	# lowered hint strip below (top edge y686) at every screen height this
	# NATIVE_SIZE-scaled layout renders at.
	UIChrome.set_offsets(_grid_anchor, -GRID_SIZE.x * 0.5, -170.0, GRID_SIZE.x * 0.5, 316.0)
	_grid_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_grid_anchor)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", int(CARD_GAP.x))
	grid.add_theme_constant_override("v_separation", int(CARD_GAP.y))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _render_step() -> void:
	_prompt_label.text = String(STEP_PROMPT[_step])
	var is_name := _step == Step.NAME
	_name_edit.visible = is_name
	_grid_anchor.visible = not is_name
	if is_name:
		# `_name` (the source of truth for typing/backspace/`_begin_game`'s
		# fallback) stays untouched at "" -- only the DISPLAYED text gets the
		# everyman default ("Traveler", the same fallback `_begin_game`
		# already substitutes for an empty name) so a pad-only player -- who
		# cannot type at all, no on-screen keyboard in v1 -- sees a real name
		# already in the field and can confidently press confirm having
		# accepted the default. Keyboard typing is unaffected: the first
		# keystroke sets `_name` and overwrites this text wholesale
		# (`_handle_name_input` always does `_name_edit.text = _name`, never
		# appends to the displayed string), so nothing needs to be cleared
		# first.
		_name_edit.text = _name if not _name.is_empty() else "Traveler"
		# Composed through WIInputHints so a pad-only player sees A/B instead
		# of Enter/Esc; kb-mode glyphs are byte-identical to the old
		# hardcoded strings (WIInputHints.label's own doc comment), so no QA
		# re-pin is needed here.
		_hint_label.text = "Type a name  •  %s to begin  •  %s to go back" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	else:
		for i in PC_OPTIONS.size():
			_refresh_card(i)
		_hint_label.text = "Arrows to choose  •  %s to confirm  •  %s to go back" % [WIInputHints.label("confirm"), WIInputHints.label("cancel")]
	ObservableBus.emit_domain_event(WIEvents.UI_CHAR_CREATION_RENDERED, {"step": _step_name()})


## The selection cue is the card's OWN chrome texture (BLUE_BUTTON_PRESSED
## vs BLUE_BUTTON below) -- no text label. CONSTRAINT: never add a
## race/gender text row back here (see PC_OPTIONS's doc comment).
func _refresh_card(i: int) -> void:
	var selected := i == _cursor
	var card := _cards[i]
	for child: Node in card.get_children():
		if child is NinePatchRect:
			# Swap through set_patch_texture so the measured art-bbox region
			# follows the texture (the two button arts have different bboxes
			# -- see UIChrome's BLUE_BUTTON_REGION doc comment).
			UIChrome.set_patch_texture(child as NinePatchRect, UIChrome.BLUE_BUTTON_PRESSED if selected else UIChrome.BLUE_BUTTON)


func _step_name() -> String:
	match _step:
		Step.PICK: return "pick"
		_: return "name"


func _unhandled_input(event: InputEvent) -> void:
	if _step == Step.NAME:
		_handle_name_input(event)
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
			_begin_game()


func _back() -> void:
	match _step:
		Step.PICK:
			# Esc on the first step returns to the title (WIMain owns the swap).
			# Deferred so this input handler finishes before the swap frees this
			# screen out of the tree (else get_viewport() would be null on return).
			if _main() != null:
				_main().swap_to_title.call_deferred()
		Step.NAME:
			_step = Step.PICK
			_cursor = _option_index()
			_render_step()


## Index of the PC_OPTIONS entry matching the current pc_race/pc_gender, so
## backing out of NAME re-highlights the card the player actually picked.
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
	var creation := {"pc_name": final_name, "pc_race": _race, "pc_gender": _gender}
	ObservableBus.emit_domain_event(WIEvents.UI_CHAR_CREATION_CONFIRMED, creation)
	# GAME_RESET drives WIMain into the world + the GDI opener (race-neutral); this
	# screen is torn down with the other UI layers on that swap.
	Game.reset(creation)


func _main() -> WIMain:
	return get_parent() as WIMain
