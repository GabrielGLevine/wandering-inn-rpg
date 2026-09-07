class_name WICombatMobileHud
extends RefCounted

signal action_requested(action: String)

var _host: Control
var _root: Control
var _rail: Control
var _active: Label
var _context: Label
var _page_label: Label
var _buttons: Dictionary = {}
var _drawer: Control
var _drawer_text: Label
var _drawer_page_label: Label
var _tutor: Control
var _tutor_label: Label
var _hotbar: WIHotbar
var _regions: Dictionary = {}
var _font_size := 26
var _page := 0
var _page_count := 1
var _last_info_index := -1
var _drawer_page := 0
var _drawer_pages: Array[String] = []
var _drawer_tab := "battle"
var _drawer_texts: Dictionary = {}
var _details_open := false
var _tutor_text := ""
var _tutor_page := 0
var _tutor_pages: Array[String] = []
var _view: RefCounted
var _inspected_id := ""
var _last_actor := ""
var _target_id := ""
var _is_targeting := false
var _bar_active := false
var _confirm_armed := false
var _latest_feed := ""
var _text_scale := 1.0


func _init(host: Control, hotbar: WIHotbar) -> void:
	_host = host
	_hotbar = hotbar
	_root = Control.new()
	_root.name = "MobileCombatHud"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIChrome.full_rect(_root)
	_host.add_child(_root)
	_rail = _panel(_root)
	_active = _label(_rail)
	_context = _label(_rail)
	_page_label = _label(_rail, true)
	for record: Array in [["details", "Details"], ["page_previous", "‹"], ["page_next", "›"], ["previous", "‹"], ["next", "›"], ["back", "Back"], ["confirm", "Confirm"]]:
		_button(_root, record[0], record[1])
	_tutor = _panel(_root)
	_tutor_label = _label(_tutor)
	_button(_root, "note_close", "Close")
	_button(_root, "note_next", "More")
	_drawer = _panel(_root)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer_text = _label(_drawer)
	_drawer_page_label = _label(_drawer, true)
	for record: Array in [["drawer_close", "Close"], ["battle", "Battle"], ["actions", "Actions"], ["log", "Log"], ["drawer_previous", "Previous"], ["drawer_next", "Next"]]:
		_button(_drawer, record[0], record[1])
	_host.move_child(_hotbar, -1)
	_root.hide()


func _panel(parent: Control) -> Control:
	var panel := UIChrome.make_texture_panel(UIChrome.PARCHMENT_STRIP)
	parent.add_child(panel)
	return panel


func _label(parent: Control, centered := false) -> Label:
	var label := UIChrome.make_label("", "MenuInk")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("line_spacing", 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(label)
	return label


func _button(parent: Control, id: String, text: String) -> void:
	var button := UIChrome.make_texture_panel(UIChrome.BLUE_BUTTON)
	button.name = id
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := UIChrome.make_label(text, "MenuInk")
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIChrome.full_rect(label)
	button.add_child(label)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			button.accept_event()
			action_requested.emit(id)
	)
	parent.add_child(button)
	_buttons[id] = button


func refresh(view: RefCounted, rendered_slots: Array, selected_index: int, info_index: int,
		targeting: Dictionary, bar_active: bool, confirm_armed: bool, dash_confirm: bool,
		in_targeting: bool, feed: Array, action_lines: Array[String], text_scale: float) -> void:
	_view = view
	_text_scale = text_scale
	_bar_active = bar_active
	_confirm_armed = confirm_armed
	_is_targeting = in_targeting
	_latest_feed = String(feed.back()) if not feed.is_empty() else ""
	_root.show()
	_buttons["details"].show()
	var actor := String(view.active_id())
	if actor != _last_actor:
		_inspected_id = ""
		_page = 0
		_last_actor = actor
	if info_index != _last_info_index:
		_page = maxi(0, info_index) / WICombatMobileLayout.PAGE_SIZE
		_last_info_index = info_index
	_page_count = WIHotbar.page_count(rendered_slots.size(), WICombatMobileLayout.PAGE_SIZE)
	_page = clampi(_page, 0, _page_count - 1)
	var viewport := _host.get_viewport()
	_font_size = WIResponsiveLayout.readable_font_size(viewport, 18, text_scale)
	for label: Label in [_active, _context, _page_label, _drawer_text, _drawer_page_label, _tutor_label]:
		label.add_theme_font_size_override("font_size", _font_size)
	for button: Control in _buttons.values():
		(button.get_node("Text") as Label).add_theme_font_size_override("font_size", _font_size)
	var safe := WIResponsiveLayout.safe_rect(viewport)
	var scale := WIResponsiveLayout.css_scale(viewport)
	var font := _active.get_theme_font("font")
	var line_height := font.get_height(_font_size)
	var preliminary := WICombatMobileLayout.regions(safe, scale, line_height, _page_count)
	var tutor_height := 0.0
	if not _tutor_text.is_empty():
		var width: float = preliminary["board"].size.x - 100.0 / scale
		var wrapped := WICombatMobileLayout.pages(_tutor_text, font, _font_size, width, 10000.0)[0]
		tutor_height = maxf(50.0 / scale, ceilf(float(wrapped.count("\n") + 1) * line_height + 40.0 / scale) + 2.0)
	_regions = WICombatMobileLayout.regions(safe, scale, line_height, _page_count, tutor_height)
	_place(_rail, _regions["rail"])
	_active.text = ""
	_context.text = ""
	for id: String in ["details", "page_previous", "page_next", "previous", "next", "back", "confirm"]:
		_place(_buttons[id], _regions[id])
	_place_child(_active, _regions["active"], _rail)
	_place_child(_context, _regions["context"], _rail)
	_place_child(_page_label, _regions["page_label"], _rail)
	_page_label.text = "Actions %d / %d" % [_page + 1, _page_count]
	var show_pages := _page_count > 1 and bar_active
	_page_label.visible = show_pages
	_buttons["page_previous"].visible = show_pages
	_buttons["page_next"].visible = show_pages
	_hotbar.render_page(rendered_slots, selected_index, _regions["slot_size"], _page, WICombatMobileLayout.PAGE_SIZE, _font_size)
	var hotbar_rect: Rect2 = _regions["hotbar"]
	hotbar_rect.position.x += (hotbar_rect.size.x - _hotbar.rendered_width()) * 0.5
	hotbar_rect.size.x = _hotbar.rendered_width()
	_place(_hotbar, hotbar_rect)
	_hotbar.visible = bar_active and not _details_open
	_target_id = ""
	var targets: Array = targeting.get("targets", [])
	if in_targeting and not targets.is_empty():
		_target_id = String(targets[int(targeting.get("index", 0))])
	_active.text = _active_text(view, actor)
	var action := ""
	if not rendered_slots.is_empty():
		var slot: Dictionary = rendered_slots[clampi(info_index, 0, rendered_slots.size() - 1)]
		action = String(slot.get("label", "")).replace("\n", " ")
		if slot.has("ap_cost"):
			action += " · %d AP" % int(slot["ap_cost"])
		if int(slot.get("mp_cost", 0)) > 0:
			action += " · %d MP" % int(slot["mp_cost"])
	var context := action
	if in_targeting:
		if bool(targeting.get("line_mode", false)):
			context += "\nAim %s · arrows turn the line" % ["up", "down", "left", "right"][int(targeting.get("line_dir", 0))]
		elif not _target_id.is_empty():
			context = "Target: " + _unit_summary(view, _target_id) + "\n" + action
		else:
			context += "\nNo target in reach. Back to move."
	elif dash_confirm:
		context += "\nConfirm to refill your steps."
	elif not _inspected_id.is_empty() and view.ids().has(_inspected_id):
		context = "Inspect: " + _unit_summary(view, _inspected_id) + "\n" + action
	elif not bar_active:
		context = "Tap the board to skip.\n" + _latest_feed
	else:
		context += "\nTap a neighboring square to move.\n‹ › inspect fighters."
	_context.text = WICombatMobileLayout.pages(context, font, _font_size, _context.size.x, _context.size.y)[0]
	_buttons["confirm"].visible = bar_active and confirm_armed
	_buttons["back"].visible = bar_active and (in_targeting or dash_confirm or not _inspected_id.is_empty())
	_buttons["previous"].visible = bar_active and (not in_targeting or confirm_armed)
	_buttons["next"].visible = _buttons["previous"].visible
	_drawer_texts = {
		"battle": _battle_text(view),
		"actions": "Action details\n\n" + "\n\n".join(action_lines),
		"log": "Recent combat events\n\n" + "\n\n".join(feed),
	}
	_layout_tutor(scale, font)
	_layout_drawer(safe, scale, font)
	if _details_open:
		for id: String in ["details", "page_previous", "page_next", "previous", "next", "back", "confirm"]:
			_buttons[id].hide()


func _active_text(view: RefCounted, id: String, compact := true) -> String:
	var c: Dictionary = view.combatant(id)
	var name := String(view.display_name(id))
	var font := _active.get_theme_font("font")
	if compact and font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x > _active.size.x:
		while not name.is_empty() and font.get_string_size(name + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x > _active.size.x:
			name = name.left(-1)
		name += "…"
	var line := "%s\nHP %d/%d" % [name, int(c["hp"]), int(c["max_hp"])]
	if int(c.get("max_mp", 0)) > 0:
		line += " · MP %d/%d" % [int(c.get("mp", 0)), int(c["max_mp"])]
	line += "\nAP %d · Move %d" % [int(c["ap"]), int(c["move_pool"])]
	return line


func _unit_summary(view: RefCounted, id: String) -> String:
	var c: Dictionary = view.combatant(id)
	return "%s\nHP %d/%d · %s" % [view.display_name(id), int(c["hp"]), int(c["max_hp"]), _statuses(c)]


static func _statuses(combatant: Dictionary) -> String:
	var names: Array[String] = []
	for id: String in combatant.get("statuses", {}):
		names.append(id.replace("_", " ").capitalize())
	return ", ".join(names) if not names.is_empty() else "No status"


func _battle_text(view: RefCounted) -> String:
	var lines: Array[String] = ["Turn order"]
	var order: Array[String] = []
	for id: String in view.order():
		if view.alive(id):
			order.append(("▶ " if id == view.active_id() else "") + view.display_name(id))
	lines.append(" → ".join(order))
	for id: String in view.ids():
		var c: Dictionary = view.combatant(id)
		lines.append("")
		lines.append(_active_text(view, id, false) + (" · Down" if not view.alive(id) else ""))
		lines.append("Status: " + _statuses(c))
		var skills: Array[String] = []
		for skill: String in c.get("skills", []):
			skills.append(String(view.skill(skill).get("display_name", skill)))
		if not skills.is_empty():
			lines.append("Skills: " + ", ".join(skills))
	return "\n".join(lines)


func _place(control: Control, rect: Rect2) -> void:
	WIResponsiveLayout.place_panel(control, rect)


func _place_child(control: Control, rect: Rect2, parent: Control) -> void:
	_place(control, Rect2(rect.position - parent.global_position, rect.size))


func _layout_tutor(scale: float, font: Font) -> void:
	_tutor.visible = not _tutor_text.is_empty() and not _details_open
	_buttons["note_close"].visible = _tutor.visible
	_buttons["note_next"].hide()
	if not _tutor.visible:
		return
	var rect: Rect2 = _regions["tutor"]
	_place(_tutor, rect)
	var inset := 10.0 / scale
	_tutor_label.text = ""
	_place(_tutor_label, Rect2(Vector2(inset, inset), Vector2(rect.size.x - 100.0 / scale, rect.size.y - 40.0 / scale)))
	_tutor_pages = WICombatMobileLayout.pages(_tutor_text, font, _font_size, _tutor_label.size.x, _tutor_label.size.y)
	_tutor_page = clampi(_tutor_page, 0, _tutor_pages.size() - 1)
	_tutor_label.text = _tutor_pages[_tutor_page]
	_place(_buttons["note_close"], Rect2(Vector2(rect.end.x - 80.0 / scale, rect.position.y + 6.0 / scale), Vector2(74.0, 44.0) / scale))
	if _tutor_pages.size() > 1:
		_buttons["note_next"].show()
		(_buttons["note_next"].get_node("Text") as Label).text = "More" if _tutor_page < _tutor_pages.size() - 1 else "Again"
		_place(_buttons["note_next"], Rect2(Vector2(rect.end.x - 80.0 / scale, rect.position.y + 54.0 / scale), Vector2(74.0, 44.0) / scale))


func _layout_drawer(safe: Rect2, scale: float, font: Font) -> void:
	_drawer.visible = _details_open
	if not _details_open:
		return
	var rect := WIResponsiveLayout.modal_rect(_host.get_viewport(), Vector2(1100, 600)).intersection(safe)
	_place(_drawer, rect)
	var gap := 6.0 / scale
	var row := 44.0 / scale
	var top := gap
	for i in 3:
		_place(_buttons[["battle", "actions", "log"][i]], Rect2(Vector2(gap + i * (110.0 / scale + gap), top), Vector2(110.0 / scale, row)))
	_place(_buttons["drawer_close"], Rect2(Vector2(rect.size.x - 96.0 / scale - gap, top), Vector2(96.0 / scale, row)))
	var bottom := rect.size.y - row - gap
	_place(_buttons["drawer_previous"], Rect2(Vector2(gap, bottom), Vector2(110.0 / scale, row)))
	_place(_buttons["drawer_next"], Rect2(Vector2(rect.size.x - 110.0 / scale - gap, bottom), Vector2(110.0 / scale, row)))
	_place(_drawer_page_label, Rect2(Vector2(354.0 / scale, top), Vector2(rect.size.x - 462.0 / scale, row)))
	_drawer_text.text = ""
	_place(_drawer_text, Rect2(Vector2(20.0 / scale, top + row + gap), Vector2(rect.size.x - 40.0 / scale, bottom - top - row - gap * 2.0)))
	_drawer_pages = WICombatMobileLayout.pages(String(_drawer_texts.get(_drawer_tab, "")), font, _font_size, _drawer_text.size.x, _drawer_text.size.y)
	_drawer_page = clampi(_drawer_page, 0, _drawer_pages.size() - 1)
	_drawer_text.text = _drawer_pages[_drawer_page]
	_drawer_page_label.text = "%s · %d / %d" % [_drawer_tab.capitalize(), _drawer_page + 1, _drawer_pages.size()]


func handle_action(id: String) -> bool:
	match id:
		"details":
			_details_open = true
			_drawer_page = 0
		"drawer_close":
			_details_open = false
		"battle", "actions", "log":
			_drawer_tab = id
			_drawer_page = 0
		"drawer_previous":
			_drawer_page = maxi(0, _drawer_page - 1)
		"drawer_next":
			_drawer_page = mini(_drawer_pages.size() - 1, _drawer_page + 1)
		"page_previous":
			_page = wrapi(_page - 1, 0, _page_count)
		"page_next":
			_page = wrapi(_page + 1, 0, _page_count)
		"note_close":
			_tutor_text = ""
		"note_next":
			_tutor_page = wrapi(_tutor_page + 1, 0, _tutor_pages.size())
		_:
			return false
	return true


func inspect(delta: int) -> void:
	var ids: Array = _view.ids()
	var from := _inspected_id if not _inspected_id.is_empty() else String(_view.active_id())
	var index := ids.find(from)
	_inspected_id = String(ids[wrapi(index + delta, 0, ids.size())])


func clear_inspection() -> void:
	_inspected_id = ""


func focused_id() -> String:
	return _target_id if not _target_id.is_empty() else _inspected_id


func show_tutor(text: String) -> void:
	_tutor_text = text
	_tutor_page = 0


func reset() -> void:
	_details_open = false
	_tutor_text = ""
	_tutor_page = 0
	_tutor_pages.clear()
	_inspected_id = ""
	_last_actor = ""
	_page = 0


func details_open() -> bool:
	return _details_open


func board_rect() -> Rect2:
	return _regions.get("board", Rect2())


func control_rect(id: String) -> Rect2:
	var control := _buttons.get(id) as Control
	return control.get_global_rect() if control != null and control.is_visible_in_tree() else Rect2()


func snapshot() -> Dictionary:
	var viewport := _host.get_viewport()
	var controls: Dictionary = {}
	var texts: Dictionary = {}
	var labels := {"active": _active, "context": _context, "drawer": _drawer_text, "tutor": _tutor_label, "page": _page_label, "drawer_page": _drawer_page_label}
	for id: String in labels:
		var label: Label = labels[id]
		if label.is_visible_in_tree() and (not _details_open or label == _drawer_text or label == _drawer_page_label):
			texts[id] = _rect_data(WIResponsiveLayout.css_rect(viewport, label.get_global_rect()))
	for id: String in _buttons:
		var rect := control_rect(id)
		if rect.has_area():
			controls[id] = _rect_data(WIResponsiveLayout.css_rect(viewport, rect))
	if _hotbar.is_visible_in_tree():
		for node: Control in _hotbar.get_children():
			controls["slot_%d" % int(node.get_meta("slot_index", -1))] = _rect_data(WIResponsiveLayout.css_rect(viewport, node.get_global_rect()))
	return {
		"mobile": true, "text_scale": _text_scale, "font_css": _font_size * WIResponsiveLayout.css_scale(viewport),
		"controls": controls, "board_css": _rect_data(WIResponsiveLayout.css_rect(viewport, board_rect())),
		"text_rects": texts,
		"details_open": _details_open, "details_text": _drawer_text.text if _details_open else "",
		"details_tab": _drawer_tab, "details_page": _drawer_page, "details_pages": _drawer_pages.size(),
		"active_text": _active.text, "context_text": _context.text, "tutor_text": _tutor_label.text if _tutor.visible else "",
		"action_page": _page, "action_pages": _page_count,
		"focused_id": focused_id(),
		"tutor_page": _tutor_page, "tutor_pages": _tutor_pages.size(),
	}


static func _rect_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}
