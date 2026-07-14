extends CanvasLayer

const PANEL_SIZE := Vector2(720.0, 232.0)
const LOCKED_COLOR := Color(0.45, 0.45, 0.45)
const PAGE_CHAR_BUDGET := 200
## A page break landing anywhere in `PAGE_CHAR_BUDGET`
## reads fine mechanically but can visually open a page mid-sentence with no
## signal it's a continuation (e.g. relc_intro's "grip. Sword arm, spear arm
## —" opening a page after "...checks your" was cut off the prior page). Fix:
## `_paginate` prefers a sentence-ending break (`.`/`!`/`?`) when one falls in
## the last SENTENCE_BOUNDARY_WINDOW_FRACTION of the budget (close enough to
## the cap that taking it doesn't waste much page space) -- see
## `_sentence_boundary_cut`. When no such boundary exists, the original word-
## boundary cut still applies, but now appends "…" to the outgoing page and
## prepends "…" to the incoming one, so a mid-sentence break always reads as
## a continuation rather than a period-less non-sequitur. The DIALOGUE_NODE
## event payload is untouched either way (event carries truth, pixels carry
## the budget) -- only `_text_label`'s rendered page text changes, and QA
## (`_is_qa()`) jumps straight to the last page regardless of how many pages
## result, so no script's injected-key count depends on the split point.
const SENTENCE_BOUNDARY_WINDOW_FRACTION := 0.2

var _root: Control
var _stack: VBoxContainer
var _options_box: VBoxContainer
var _speaker_label: Label
var _text_label: Label
var _more_hint: Label
var _option_labels: Array[Label] = []
var _options: Array = []
var _cursor := 0
var _shown := false
## Paged body text for the current node + the page currently shown. A single-
## page node behaves exactly as before (page 0 IS the last page). See
## _render_node / _confirm for the QA-safe paging contract.
var _pages: Array[String] = []
var _page_idx := 0


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
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

	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 6)
	content.add_child(_stack)
	var stack := _stack

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

	# Continuation affordance shown only on a non-final page of a paged node —
	# it occupies the option row's space (options are hidden until the last
	# page), so it never adds a row to the last-page layout that must fit.
	_more_hint = UIChrome.make_label("")
	_more_hint.add_theme_color_override("font_color", LOCKED_COLOR)
	_more_hint.hide()
	stack.add_child(_more_hint)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 1)
	stack.add_child(_options_box)
	_options_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_box.gui_input.connect(_on_options_gui_input)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.INPUT_DEVICE_CHANGED:
			if _shown:
				_render_page()
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
	_options = payload.get("options", [])
	_cursor = 0
	_pages = _paginate(String(payload["text"]))
	# QA (headless/TestDriver) jumps straight to the last page so a single
	# `confirm` still selects an option exactly as before this fix — the paged
	# flow is a windowed human-play affordance and must not change the injected
	# key count the 41-script sweep drives dialogue with (same _is_qa collapse
	# idiom sleep_veil/combat pacing use).
	_page_idx = (_pages.size() - 1) if _is_qa() else 0
	_render_page()


func _paginate(text: String) -> Array[String]:
	var pages: Array[String] = []
	var cur := ""
	for word: String in text.split(" ", false):
		var candidate := word if cur == "" else cur + " " + word
		if candidate.length() > PAGE_CHAR_BUDGET and cur != "":
			var cut := _sentence_boundary_cut(cur)
			if cut != -1:
				var remainder := cur.substr(cut + 1).strip_edges()
				pages.append(cur.substr(0, cut + 1))
				cur = ("%s %s" % [remainder, word]) if remainder != "" else word
			else:
				pages.append(cur + "…")
				cur = "…" + word
		else:
			cur = candidate
	if cur != "":
		pages.append(cur)
	if pages.is_empty():
		pages.append("")
	return pages


func _sentence_boundary_cut(cur: String) -> int:
	var window_start := int(PAGE_CHAR_BUDGET * (1.0 - SENTENCE_BOUNDARY_WINDOW_FRACTION))
	var best := -1
	for i in cur.length():
		var c := cur[i]
		if (c == "." or c == "!" or c == "?") and i >= window_start:
			best = i
	return best


func _render_page() -> void:
	_text_label.text = _pages[_page_idx]
	var on_last := _on_last_page()
	_more_hint.text = "▼  more — press %s" % WIInputHints.label("confirm")
	_more_hint.visible = not on_last
	_options_box.visible = on_last
	if on_last:
		_rebuild_options()
	else:
		for child: Node in _options_box.get_children():
			_options_box.remove_child(child)
			child.queue_free()
		_option_labels.clear()
	_fit_panel_height.call_deferred()


func _on_last_page() -> bool:
	return _page_idx >= _pages.size() - 1


func _fit_panel_height() -> void:
	if not is_instance_valid(_stack):
		return
	var needed := _stack.get_combined_minimum_size().y + 52.0
	var h := maxf(PANEL_SIZE.y, needed)
	_root.custom_minimum_size = Vector2(PANEL_SIZE.x, h)
	_root.size = Vector2(PANEL_SIZE.x, h)
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -h - 18.0, PANEL_SIZE.x * 0.5, -18.0)


func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


func _rebuild_options() -> void:
	for child: Node in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
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
		l.custom_minimum_size = Vector2(0.0, 30.0)
		if locked:
			l.add_theme_color_override("font_color", LOCKED_COLOR)
		_options_box.add_child(l)
		_option_labels.append(l)
		for effect_line: String in opt.get("effect_lines", []):
			var sub := UIChrome.make_label("      %s" % effect_line, "Small")
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if locked:
				sub.add_theme_color_override("font_color", LOCKED_COLOR)
			_options_box.add_child(sub)


## Authored option text sometimes already spells out the requirement inline
## (e.g. "Go on. (Warrior 2)", "...([Basic Cleaning])", or a shop buy's
## "(5 gold)"), which would double up with the auto-generated suffix. Strip
## the "requires "/"costs " lead-in (WIDialogue._requirement_text's only two
## forms) and skip the suffix entirely when what's left is already present in
## the option text. TRAP: the gold case must strip BOTH lead-ins -- matching
## only "requires " leaves a locked buy's authored "(5 gold)" unmatched
## against `_requirement_text`'s "costs 5 gold" core (missing the word
## "costs"), rendering a doubled price ("(5 gold)  (costs 5 gold)"). Every shipped gold-gated option already
## authors its price inline (data/dialogue/krshia_crate.json's 4 buy options,
## the only `requires: {gold: ...}` sites in the game), so this is a strict
## fix, never a regression that would hide a price with nowhere else to show.
func _requirement_suffix(option_text: String, requirement: String) -> String:
	if requirement.is_empty():
		return ""
	var core := requirement.trim_prefix("requires ").trim_prefix("costs ")
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
	if event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()


func _move_cursor(delta: int) -> void:
	if _options.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _options.size())
	_refresh_cursor()


func _confirm() -> void:
	if not _on_last_page():
		_page_idx += 1
		_render_page()
		return
	if _options.is_empty():
		return
	if bool((_options[_cursor] as Dictionary).get("locked", false)):
		return
	Game.sim.dialogue_choose(_cursor)


func _on_options_gui_input(event: InputEvent) -> void:
	if _options.is_empty() or not _on_last_page():
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_option_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _cursor:
			_cursor = idx
			_refresh_cursor()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_option_labels, mb.position)
	if idx >= 0:
		_cursor = idx
		_confirm()


func option_rect(i: int) -> Rect2:
	if i < 0 or i >= _option_labels.size():
		return Rect2()
	var label := _option_labels[i]
	if label == null or not is_instance_valid(label) or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)
