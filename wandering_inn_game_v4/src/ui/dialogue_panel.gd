extends CanvasLayer
## Conversation UI for branching dialogue graphs (WIDialogue). Renders the
## current node's speaker/text and numbered options, and forwards confirmed
## choices to the sim. Distinct from message_layer.gd's `dialogue_line`
## (the M0 one-off NPC line) — this panel only reacts to
## `dialogue_started`/`dialogue_node`/`dialogue_ended`.
##
## Input arbitration (repo-wide precedence: combat > dialogue > pause >
## journal > world): this panel only consumes input while a conversation is
## open (`Game.sim.dialogue != null`), which sits below combat_screen (combat
## always ends any dialogue first) and above pause_menu/journal/world — those
## three gate on dialogue being closed.
##
## GOTCHA: CanvasLayer has no `modulate`; only child Controls are styled.

## 232px tall: 3 option rows + ribbon + 2-line text clear the parchment
## margins without clipping (controller windowed pass at E3/H3 merge).
const PANEL_SIZE := Vector2(720.0, 232.0)
const LOCKED_COLOR := Color(0.45, 0.45, 0.45)

var _root: Control
var _options_box: VBoxContainer
var _speaker_label: Label
var _text_label: Label
var _option_labels: Array[Label] = []
var _options: Array = []
var _cursor := 0
var _shown := false


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y - 18.0, PANEL_SIZE.x * 0.5, -18.0)
	_root.hide()
	add_child(_root)

	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var content := MarginContainer.new()
	UIChrome.full_rect(content)
	UIChrome.add_margins(content, 28, 28, 28, 24)
	_root.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	content.add_child(stack)

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(210.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_speaker_label = UIChrome.make_label("", "Header")
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_speaker_label)
	ribbon.add_child(_speaker_label)

	_text_label = UIChrome.make_label()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(PANEL_SIZE.x - 56.0, 46.0)
	stack.add_child(_text_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 1)
	stack.add_child(_options_box)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.DIALOGUE_STARTED:
			_shown = false
		WIEvents.DIALOGUE_NODE:
			_render_node(payload)
			if not _shown:
				_shown = true
				_root.show()
				ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_SHOWN, {})
		WIEvents.DIALOGUE_ENDED:
			_hide()


func _render_node(payload: Dictionary) -> void:
	_speaker_label.text = String(payload["speaker"])
	_text_label.text = String(payload["text"])
	_options = payload.get("options", [])
	_cursor = 0
	_rebuild_options()


func _rebuild_options() -> void:
	for l: Label in _option_labels:
		l.queue_free()
	_option_labels.clear()
	for i in _options.size():
		var opt: Dictionary = _options[i]
		var locked := bool(opt.get("locked", false))
		var mark := "> " if i == _cursor else "  "
		var text: String
		if locked:
			var opt_text := String(opt["text"])
			var suffix := _requirement_suffix(opt_text, String(opt.get("requirement", "")))
			text = "%s%d. %s%s" % [mark, i + 1, opt_text, suffix]
		else:
			text = "%s%d. %s" % [mark, i + 1, String(opt["text"])]
		var l := UIChrome.make_label()
		l.text = text
		if locked:
			l.add_theme_color_override("font_color", LOCKED_COLOR)
		_options_box.add_child(l)
		_option_labels.append(l)


## Authored option text sometimes already spells out the requirement inline
## (e.g. "Go on. (Warrior 2)" or "...([Basic Cleaning])"), which would double
## up with the auto-generated "(requires X)" suffix. Strip the "requires "
## lead-in and skip the suffix entirely when what's left is already present
## in the option text.
func _requirement_suffix(option_text: String, requirement: String) -> String:
	if requirement.is_empty():
		return ""
	var core := requirement.trim_prefix("requires ")
	if option_text.contains(core):
		return ""
	return "  (%s)" % requirement


func _refresh_cursor() -> void:
	for i in _options.size():
		var opt: Dictionary = _options[i]
		var mark := "> " if i == _cursor else "  "
		if bool(opt.get("locked", false)):
			var opt_text := String(opt["text"])
			var suffix := _requirement_suffix(opt_text, String(opt.get("requirement", "")))
			(_option_labels[i] as Label).text = "%s%d. %s%s" % [mark, i + 1, opt_text, suffix]
		else:
			(_option_labels[i] as Label).text = "%s%d. %s" % [mark, i + 1, String(opt["text"])]


func _hide() -> void:
	_shown = false
	_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_HIDDEN, {})


func _unhandled_input(event: InputEvent) -> void:
	if Game.sim.dialogue == null:
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


func _move_cursor(delta: int) -> void:
	if _options.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _options.size())
	_refresh_cursor()


func _confirm() -> void:
	if _options.is_empty():
		return
	if bool((_options[_cursor] as Dictionary).get("locked", false)):
		return
	Game.sim.dialogue_choose(_cursor)
