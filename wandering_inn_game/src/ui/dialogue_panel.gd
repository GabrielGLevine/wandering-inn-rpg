extends CanvasLayer

const PANEL_SIZE := Vector2(720.0, 232.0)
const LOCKED_COLOR := Color(0.45, 0.45, 0.45)
const PAGE_CHAR_BUDGET := 200
const PICKER_CONVERSATIONS := [&"board_picker", &"delivery_picker"]
const PICKER_MAX_HEIGHT := 684.0
const PICKER_CARD_BG := Color(0.93, 0.86, 0.70, 0.72)
const PICKER_CARD_SELECTED_BG := Color(0.12, 0.25, 0.38, 0.96)
const PICKER_CARD_BORDER := Color(0.36, 0.29, 0.20, 0.72)
const PICKER_CARD_SELECTED_BORDER := Color(0.94, 0.73, 0.27, 1.0)
const PICKER_SELECTED_TEXT := Color(1.0, 0.97, 0.88)
const PICKER_REWARD_TEXT := Color(0.98, 0.77, 0.28)
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
var _option_controls: Array[Control] = []
var _options: Array = []
var _cursor := 0
var _shown := false
var _conversation_id := ""
var _picker_active := false
var _picker_rows: Array = []
var _picker_cards: Array[PanelContainer] = []
var _picker_title_labels: Array[Label] = []
var _picker_reward_labels: Array[Label] = []
var _picker_detail_labels: Array[Label] = []
var _picker_needed_height := 0.0
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
			_conversation_id = String(payload.get("conversation", ""))
			_picker_active = false
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
	_picker_active = PICKER_CONVERSATIONS.has(StringName(_conversation_id)) \
		and WIPickerPresenter.is_picker_payload(String(payload["text"]), _options)
	if _picker_active:
		var picker := WIPickerPresenter.derive(String(payload["text"]), _options)
		_picker_rows = picker["rows"]
		_pages = [String(picker["prompt"])]
	else:
		_picker_rows.clear()
		_pages = _paginate(String(payload["text"]))
	# QA (headless/TestDriver) jumps straight to the last page so a single
	# `confirm` still selects an option exactly as before this fix — the paged
	# flow is a windowed human-play affordance and must not change the injected
	# key count the 41-script sweep drives dialogue with (same _is_qa collapse
	# idiom sleep_veil/combat pacing use).
	# CONTRACT: picker entry is one shared page for humans + QA; ordinary prose keeps QA's collapsed paging.
	_page_idx = 0 if _picker_active else ((_pages.size() - 1) if _is_qa() else 0)
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
	if _picker_active:
		_text_label.custom_minimum_size = Vector2(PANEL_SIZE.x - 56.0, 24.0)
		_more_hint.hide()
		_options_box.show()
		_rebuild_options()
		_fit_panel_height.call_deferred()
		return
	_text_label.custom_minimum_size = Vector2(PANEL_SIZE.x - 56.0, 46.0)
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
		_option_controls.clear()
	_fit_panel_height.call_deferred()


func _on_last_page() -> bool:
	return _page_idx >= _pages.size() - 1


func _fit_panel_height() -> void:
	if not is_instance_valid(_stack):
		return
	var needed := _stack.get_combined_minimum_size().y + 52.0
	_picker_needed_height = needed
	var h := minf(maxf(PANEL_SIZE.y, needed), PICKER_MAX_HEIGHT) if _picker_active else maxf(PANEL_SIZE.y, needed)
	_root.custom_minimum_size = Vector2(PANEL_SIZE.x, h)
	_root.size = Vector2(PANEL_SIZE.x, h)
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -h - 18.0, PANEL_SIZE.x * 0.5, -18.0)
	if _picker_active:
		_emit_picker_rendered.call_deferred()


func _is_qa() -> bool:
	return (TestDriver != null and TestDriver.active()) or DisplayServer.get_name() == "headless"


func _rebuild_options() -> void:
	for child: Node in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	_option_labels.clear()
	_option_controls.clear()
	_picker_cards.clear()
	_picker_title_labels.clear()
	_picker_reward_labels.clear()
	_picker_detail_labels.clear()
	_options_box.add_theme_constant_override("separation", 6 if _picker_active else 1)
	if _picker_active:
		_rebuild_picker_options()
		return
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
		_option_controls.append(l)
		for effect_line: String in opt.get("effect_lines", []):
			var sub := UIChrome.make_label("      %s" % effect_line, "Small")
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if locked:
				sub.add_theme_color_override("font_color", LOCKED_COLOR)
			_options_box.add_child(sub)


func _rebuild_picker_options() -> void:
	for i in _picker_rows.size():
		var row: Dictionary = _picker_rows[i]
		var card := PanelContainer.new()
		card.focus_mode = Control.FOCUS_ALL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_entered.connect(_on_picker_focus.bind(i))
		_options_box.add_child(card)

		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIChrome.add_margins(margin, 10, 5, 10, 5)
		card.add_child(margin)
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 2)
		margin.add_child(stack)

		var title_bar := HBoxContainer.new()
		title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_bar.add_theme_constant_override("separation", 12)
		stack.add_child(title_bar)
		var title := UIChrome.make_label("", "Menu")
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_bar.add_child(title)
		var reward := UIChrome.make_label(String(row["reward"]), "Header")
		reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		reward.add_theme_color_override("font_color", PICKER_REWARD_TEXT)
		title_bar.add_child(reward)
		var detail := UIChrome.make_label(String(row["detail"]), "Small")
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.visible = not String(row["detail"]).is_empty()
		stack.add_child(detail)

		_picker_cards.append(card)
		_picker_title_labels.append(title)
		_picker_reward_labels.append(reward)
		_picker_detail_labels.append(detail)
		_option_controls.append(card)
	_refresh_picker_cards(false)


func _picker_card_style(selected: bool, locked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PICKER_CARD_SELECTED_BG if selected else PICKER_CARD_BG
	if locked and not selected:
		style.bg_color = Color(0.60, 0.58, 0.53, 0.58)
	style.border_color = PICKER_CARD_SELECTED_BORDER if selected else PICKER_CARD_BORDER
	var border_width := 2 if selected else 1
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	return style


func _refresh_picker_cards(emit_event: bool = true) -> void:
	for i in _picker_cards.size():
		var selected := i == _cursor
		var row: Dictionary = _picker_rows[i]
		_picker_cards[i].add_theme_stylebox_override("panel", _picker_card_style(selected, bool(row["locked"])))
		_picker_title_labels[i].text = ("▶  " if selected else "     ") + String(row["title"])
		var text_color := PICKER_SELECTED_TEXT if selected else LOCKED_COLOR if bool(row["locked"]) else Color(0.18, 0.15, 0.12)
		_picker_title_labels[i].add_theme_color_override("font_color", text_color)
		_picker_detail_labels[i].add_theme_color_override("font_color", text_color)
	if _cursor >= 0 and _cursor < _picker_cards.size() and _picker_cards[_cursor].is_inside_tree() and not _picker_cards[_cursor].has_focus():
		_picker_cards[_cursor].grab_focus()
	if emit_event:
		_emit_picker_rendered()


func _on_picker_focus(index: int) -> void:
	if not _picker_active or index == _cursor:
		return
	_cursor = index
	_refresh_picker_cards()


func _emit_picker_rendered() -> void:
	if not _picker_active or _picker_rows.is_empty() or _cursor < 0 or _cursor >= _picker_rows.size():
		return
	var selected: Dictionary = _picker_rows[_cursor]
	ObservableBus.emit_domain_event(WIEvents.UI_PICKER_RENDERED, {
		"conversation": _conversation_id,
		"row_count": _picker_rows.size(),
		"visible_rows": _option_controls.size(),
		"cursor": _cursor,
		"selected_title": String(selected["title"]),
		"selected_reward": String(selected["reward"]),
		"selected_detail": String(selected["detail"]),
		"page_count": 1,
		"fits_viewport": _picker_needed_height <= PICKER_MAX_HEIGHT,
		"panel_height": _root.size.y,
	})


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
	if _picker_active:
		_refresh_picker_cards()
		return
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
	_picker_active = false
	_conversation_id = ""
	ObservableBus.emit_domain_event(WIEvents.UI_DIALOGUE_HIDDEN, {})


func _unhandled_input(event: InputEvent) -> void:
	if Game.sim.dialogue == null:
		return
	if event.is_action_pressed("confirm"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif _picker_active and event.is_action_pressed("cancel"):
		_cancel_picker()
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event.is_action_pressed("move_up"):
		_move_cursor(-1)
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event.is_action_pressed("move_down"):
		_move_cursor(1)
		get_viewport().set_input_as_handled()
	elif _on_last_page() and event is InputEventKey and event.pressed and not event.echo:
		# GH#171: options render as "1. ...", so number keys should pick them
		# (friend-playtest expectation). Reuses the hotbar_N actions' physical
		# keys via unicode -- 1-9 map to visible option rows; locked rows
		# refuse exactly like a cursor confirm would.
		var digit := int(event.unicode) - int("1".unicode_at(0))
		if digit >= 0 and digit <= 8 and digit < _options.size():
			if not bool((_options[digit] as Dictionary).get("locked", false)):
				_cursor = digit
				_refresh_cursor()
				Game.sim.dialogue_choose(digit)
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


func _cancel_picker() -> void:
	if _picker_rows.is_empty():
		return
	var cancel_index := _picker_rows.size() - 1
	if not bool((_picker_rows[cancel_index] as Dictionary).get("cancel", false)):
		return
	_cursor = cancel_index
	_refresh_cursor()
	_confirm()


func _on_options_gui_input(event: InputEvent) -> void:
	if _options.is_empty() or not _on_last_page():
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_option_controls, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _cursor:
			_cursor = idx
			_refresh_cursor()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := UIChrome.control_index_at(_option_controls, mb.position)
	if idx >= 0:
		_cursor = idx
		_refresh_cursor()
		_confirm()


func option_rect(i: int) -> Rect2:
	if i < 0 or i >= _option_controls.size():
		return Rect2()
	var control := _option_controls[i]
	if control == null or not is_instance_valid(control) or not control.visible:
		return Rect2()
	return Rect2(control.global_position, control.size)
