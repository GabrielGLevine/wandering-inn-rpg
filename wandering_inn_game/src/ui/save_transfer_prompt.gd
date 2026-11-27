extends CanvasLayer
## Old-site save hand-off prompt, shown over the title menu. It renders
## Game.pending_transfer() and forwards the player's answer to
## Game.apply_transfer / decline_transfer; it never writes a save itself.
## The offer comes from a link anyone can craft, so the cursor always opens
## on the choice that changes nothing and input is swallowed until armed.

const PANEL_SIZE := Vector2(720.0, 420.0)
const BUTTON_SIZE := Vector2(250.0, 44.0)
const ARM_SECONDS := 0.3
const REFUSED_TEXT := "That link's save data can't be read. Nothing was changed."

var _catcher: Control
var _panel: Control
var _title: Label
var _body: Label
var _button_row: HBoxContainer
var _buttons: Array[Label] = []
var _button_ids: Array[String] = []
var _cursor := 0
var _shown := false
var _armed := false
var _serial := 0
var _page := ""
var _conflicts: Array[Dictionary] = []
var _conflict_index := 0
var _replace: Array[String] = []
var _layout_key: Array = []
var _menu_live := false


func _ready() -> void:
	layer = 20
	_catcher = Control.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.hide()
	add_child(_catcher)
	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.hide()
	add_child(_panel)
	_panel.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))
	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 30, 24, 30, 24)
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	_title = UIChrome.make_label("", "MenuInk")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_title)
	_body = UIChrome.make_label("", "MenuInk")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_text = false
	stack.add_child(_body)
	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 24)
	_button_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_button_row.gui_input.connect(_on_buttons_gui_input)
	stack.add_child(_button_row)
	for i in 2:
		var button := UIChrome.make_label("", "MenuInk")
		button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.86, 0.76, 0.56)
		frame.border_color = Color(0.18, 0.105, 0.045)
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(6)
		frame.set_content_margin_all(8)
		button.add_theme_stylebox_override("normal", frame)
		_button_row.add_child(button)
		_buttons.append(button)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	# A boot-time offer waits for the title menu; a later one opens at once.
	if type == WIEvents.UI_TITLE_RENDERED:
		_menu_live = true
	if _menu_live and not _shown and type in [WIEvents.UI_TITLE_RENDERED, WIEvents.SAVE_TRANSFER_OFFERED, WIEvents.SAVE_TRANSFER_REFUSED]:
		_open.call_deferred()


func _open() -> void:
	var pending: Dictionary = Game.pending_transfer()
	if pending.is_empty() or _shown:
		return
	_replace = []
	_conflicts = []
	if pending.has("refused"):
		_render("refused", "Old-site saves", REFUSED_TEXT, ["ok"])
		return
	for row: Dictionary in pending.rows:
		if row.status == "conflict":
			_conflicts.append(row)
	var lines: Array[String] = []
	var importable := 0
	for row: Dictionary in pending.rows:
		match String(row.status):
			"new":
				importable += 1
				lines.append("%s: %s. Will be added." % [row.label, row.summary])
			"conflict":
				importable += 1
				lines.append("%s: %s. You already have a save here, so you choose." % [row.label, row.summary])
			"unreadable":
				lines.append("%s: can't be read, so it is skipped." % row.label)
	if importable == 0:
		_render("unreadable", "Old-site saves", "\n".join(lines) + "\nNothing was changed.", ["ok"])
		return
	lines.append("Nothing you have here is replaced unless you choose it.")
	_render("offer", "Saves from the old site were found. Import them?", "\n".join(lines), ["later", "import"])


func _render(page: String, title: String, body: String, ids: Array) -> void:
	_page = page
	_title.text = title
	_body.text = body
	_button_ids.assign(ids)
	var labels := {"ok": "OK", "later": "Not now", "import": "Import", "keep": "Keep what's here", "use_old": "Use old-site save"}
	for i in _buttons.size():
		_buttons[i].visible = i < ids.size()
		_buttons[i].set_meta("text", String(labels[ids[i]]) if i < ids.size() else "")
	_cursor = 0
	_armed = false
	_serial += 1
	_catcher.show()
	_panel.show()
	_shown = true
	_layout()
	_refresh_buttons()
	_emit_rendered.call_deferred(_serial)
	_arm_later(_serial)


func _emit_rendered(serial: int) -> void:
	await get_tree().process_frame
	if not _shown or serial != _serial:
		return
	ObservableBus.emit_domain_event(WIEvents.UI_SAVE_TRANSFER_RENDERED, display_state())


func _arm_later(serial: int) -> void:
	await get_tree().create_timer(ARM_SECONDS).timeout
	if _shown and serial == _serial:
		_armed = true


func _layout_signature() -> Array:
	return [get_viewport().get_visible_rect().size, WISettings.text_scale_step(), WIResponsiveLayout.uses_touch_layout()]


func _process(_delta: float) -> void:
	if _shown and _layout_key != _layout_signature():
		_layout()


func _layout() -> void:
	var viewport := get_viewport()
	var text_scale: float = WISettings.TEXT_SCALE_STEPS[WISettings.text_scale_step()]
	WIResponsiveLayout.apply_readable_theme(_panel, viewport, text_scale)
	var rect := WIResponsiveLayout.modal_rect(viewport, PANEL_SIZE)
	if WIResponsiveLayout.uses_touch_layout():
		# The shared touch modal leaves room for a Back chip this prompt has none of.
		var safe := WIResponsiveLayout.safe_rect(viewport)
		rect = Rect2(safe.position + Vector2(24.0, 16.0), safe.size - Vector2(48.0, 32.0))
	WIResponsiveLayout.place_panel(_panel, rect)
	for button: Label in _buttons:
		button.custom_minimum_size = WIResponsiveLayout.touch_size(viewport, BUTTON_SIZE)
	_layout_key = _layout_signature()


func _refresh_buttons() -> void:
	for i in _buttons.size():
		_buttons[i].text = ("> %s <" if i == _cursor else "%s") % String(_buttons[i].get_meta("text", ""))


func _close() -> void:
	_shown = false
	_armed = false
	_panel.hide()
	_catcher.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_SAVE_TRANSFER_HIDDEN, {"page": _page})


func _choose(id: String) -> void:
	match id:
		"later":
			_close()
			Game.decline_transfer()
		"import":
			_next_conflict()
		"keep":
			_conflict_index += 1
			_next_conflict()
		"use_old":
			_replace.append(String(_conflicts[_conflict_index].slot))
			_conflict_index += 1
			_next_conflict()
		"ok":
			_close()
			if _page == "refused":
				Game.decline_transfer()
			elif _page == "unreadable":
				Game.apply_transfer([])


func _next_conflict() -> void:
	if _page == "offer":
		_conflict_index = 0
	if _conflict_index < _conflicts.size():
		var row := _conflicts[_conflict_index]
		_render("conflict", "Two saves for %s" % row.label, "Here now: %s (last played %s)\nOld site: %s (last played %s)\nPick one to keep. The other is discarded." % [
			row.current, _date(int(row.current_t)), row.summary, _date(int(row.t))], ["keep", "use_old"])
		return
	var result: Dictionary = Game.apply_transfer(_replace)
	_apply_settings(result.get("settings", {}))
	var added: int = (result.get("imported", []) as Array).size() + (result.get("replaced", []) as Array).size()
	var text := "Nothing was changed." if added == 0 else "%d save%s imported. Choose Continue to play." % [added, "" if added == 1 else "s"]
	if not (result.get("failed", []) as Array).is_empty():
		text += "\nSome saves could not be written. Free up browser storage and open the old link again."
	_render("done", "Old-site saves", text, ["ok"])


## Allowlisted scalars only (WISaveTransfer.parse_settings), each through the
## setter that clamps it.
func _apply_settings(values: Dictionary) -> void:
	for key: String in values:
		var value: Variant = values[key]
		match key:
			"accessibility/text_scale_step":
				WISettings.set_text_scale_step(int(value))
			"accessibility/reduce_motion":
				WISettings.set_reduce_motion(bool(value))
			"combat/speed_step":
				WISettings.set_combat_speed_step(int(value))
			"combat/difficulty_step":
				WISettings.set_difficulty_step(int(value))
			"field_hud/show_quest_thread":
				WISettings.set_show_quest_thread(bool(value))
			"journal/quest_hints":
				WISettings.set_show_quest_hints(bool(value))
			_:
				WIAudio.set_bus_volume(key.get_slice("/", 1), float(value))


func _date(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix) if unix > 0 else "unknown"


func _unhandled_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
	if not _armed:
		return
	if event.is_action_pressed("cancel"):
		_choose(_button_ids[0])
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_cursor = wrapi(_cursor + 1, 0, _button_ids.size())
		_refresh_buttons()
	elif event.is_action_pressed("confirm"):
		_choose(_button_ids[_cursor])


func _on_buttons_gui_input(event: InputEvent) -> void:
	if not _shown or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_button_row.accept_event()
	if not _armed:
		return
	for i in _button_ids.size():
		if Rect2(_buttons[i].position, _buttons[i].size).has_point(mb.position):
			_cursor = i
			_choose(_button_ids[i])
			return


## QA seams.
func button_rect(id: String) -> Rect2:
	var i := _button_ids.find(id)
	if not _shown or i < 0:
		return Rect2()
	return Rect2(_buttons[i].global_position, _buttons[i].size)


func display_state() -> Dictionary:
	var viewport := get_viewport()
	var buttons := {}
	for id: String in _button_ids:
		var css := WIResponsiveLayout.css_rect(viewport, button_rect(id))
		buttons[id] = [css.position.x, css.position.y, css.size.x, css.size.y]
	var font := _body.get_theme_font("font")
	var font_size := _body.get_theme_font_size("font_size")
	var text_height := font.get_multiline_string_size(_body.text, HORIZONTAL_ALIGNMENT_LEFT, _body.size.x, font_size).y
	return {
		"page": _page, "title": _title.text, "body": _body.text, "buttons": _button_ids.duplicate(), "cursor": _button_ids[_cursor] if _shown else "",
		"touch": WIResponsiveLayout.uses_touch_layout(), "button_css": buttons,
		"font_css": font_size * WIResponsiveLayout.css_scale(viewport),
		"body_fits": text_height <= _body.size.y + 1.0,
		"panel_in_view": viewport.get_visible_rect().encloses(Rect2(_panel.global_position, _panel.size)),
	}
