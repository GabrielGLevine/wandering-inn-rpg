extends CanvasLayer

const PANEL_SIZE := Vector2(600.0, 300.0)
const ROWS := ["Consolidate", "Keep them apart"]

var open := false

var sleep_veil_ref: Node = null

var _root: Control
var _title_label: Label
var _body_label: Label
var _row_labels: Array[Label] = []
var _cursor := 0
var _target_display := ""
## The offer payload held back while the sleep veil's sequence runs (see the
## VEIL GATE doc comment above). Non-empty only between consolidation_offered
## and the veil's UI_SLEEP_VEIL_FINISHED.
var _held_offer: Dictionary = {}


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)

	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var content := MarginContainer.new()
	UIChrome.full_rect(content)
	UIChrome.add_margins(content, 34, 30, 34, 30)
	_root.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	content.add_child(stack)

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(240.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_title_label = UIChrome.make_label("", "Header")
	_title_label.text = "A Path Converges"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_title_label)
	ribbon.add_child(_title_label)

	_body_label = UIChrome.make_label()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_body_label)

	for _i in ROWS.size():
		var row := UIChrome.make_label()
		_row_labels.append(row)
		stack.add_child(row)

	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_row_gui_input)

	ObservableBus.domain_event.connect(_on_domain_event)

	# RELOAD-MID-OFFER CONTRACT (the documented choice for the veil-gate edge):
	# a load re-emits no phase_changed, so no sleep veil ever runs on this
	# path -- the offer surfaces IMMEDIATELY on load, unheld. This is the
	# no-veil branch of the VEIL GATE doc comment above; consolidation_reload
	# pins it (prompt rendered straight after game_loaded/world_ready, with
	# zero ui_sleep_veil_* events anywhere in the run).
	var pending := Game.sim.pending_offer_display()
	if not pending.is_empty():
		_show_offer(pending)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.CONSOLIDATION_OFFERED:
		if sleep_veil_ref != null and bool(sleep_veil_ref.call("sleep_sequence_active")):
			_held_offer = payload
		else:
			_show_offer(payload)
	elif type == WIEvents.UI_SLEEP_VEIL_FINISHED:
		if not _held_offer.is_empty():
			var offer := _held_offer
			_held_offer = {}
			_show_offer(offer)


func _show_offer(offer: Dictionary) -> void:
	var parents: Array = offer.get("parents_display", [])
	_target_display = String(offer.get("target_display", ""))
	var a := String(parents[0]) if parents.size() > 0 else "one path"
	var b := String(parents[1]) if parents.size() > 1 else "another"
	_body_label.text = "You dream of two roads becoming one. [%s] and [%s] could consolidate into [%s], or hold to their own shapes." % [a, b, _target_display]
	_cursor = 0
	_refresh()
	open = true
	_root.show()
	ObservableBus.emit_domain_event(WIEvents.UI_CONSOLIDATION_PROMPT_RENDERED, {"target": String(offer.get("target", ""))})


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("move_up"):
		_cursor = wrapi(_cursor - 1, 0, ROWS.size())
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_cursor = wrapi(_cursor + 1, 0, ROWS.size())
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_choose(false)
		get_viewport().set_input_as_handled()


func _select_current() -> void:
	_choose(_cursor == 0)


func _on_row_gui_input(event: InputEvent) -> void:
	if not open:
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
		_select_current()


func row_rect(i: int) -> Rect2:
	if not open or i < 0 or i >= _row_labels.size():
		return Rect2()
	var label := _row_labels[i]
	if label == null or not label.visible:
		return Rect2()
	return Rect2(label.global_position, label.size)


func _choose(accepted: bool) -> void:
	open = false
	_root.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_CONSOLIDATION_PROMPT_HIDDEN, {})
	if accepted:
		Game.sim.accept_consolidation()
	else:
		Game.sim.decline_consolidation()


func _refresh() -> void:
	for i in ROWS.size():
		var mark := "> " if i == _cursor else "  "
		var text := String(ROWS[i])
		if i == 0 and _target_display != "":
			text = "Consolidate into [%s]" % _target_display
		_row_labels[i].text = mark + text
