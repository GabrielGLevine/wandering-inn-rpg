extends CanvasLayer

## #504 purchase confirmation. One modal for every purchase producer (authored
## shop rows, Ratici's generated fence, room/enchanting services): it renders
## WIGame.pending_purchase and forwards Buy/Cancel to purchase_confirm() /
## purchase_cancel(). It never applies an effect itself.
##
## Accidental-input contract:
##  * the cursor opens on Cancel, never on Buy;
##  * every non-cancel input is swallowed until ARM_SECONDS after the offer
##    rendered (UI_PURCHASE_CONFIRM_ARMED), so the opening tap, a held key,
##    or a rapid double tap cannot land on Buy;
##  * a tap outside the panel dismisses (cancel), the same as Esc/B;
##  * the sim clears the offer BEFORE committing, so a repeated confirm after
##    the modal closes finds nothing to buy.

const PANEL_SIZE := Vector2(520.0, 250.0)  ## width fixed; height is the content-fit floor
const PANEL_MARGINS := Vector2(56.0, 46.0)  ## left+right, top+bottom of the inner MarginContainer
const PATCH_SLACK := 26.0  ## parchment border the nine-patch needs below the last row
const ARM_SECONDS := 0.3
const ROW_CANCEL := 0
const ROW_BUY := 1
const LOCKED_COLOR := Color(0.45, 0.45, 0.45)
const PRICE_TOKEN_RE := "\\s*\\(\\d+ gold\\)\\s*$"

var _root: Control
var _stack: VBoxContainer
var _catcher: Control
var _title_label: Label
var _summary_label: Label
var _price_label: Label
var _after_label: Label
var _hint_label: Label
var _row_labels: Array[Label] = []
var _cursor := ROW_CANCEL
var _shown := false
var _armed := false
var _offer: Dictionary = {}
var _serial := 0
var _price_re := RegEx.new()


func _ready() -> void:
	_price_re.compile(PRICE_TOKEN_RE)
	# Full-viewport catcher: a click anywhere off the panel dismisses the
	# offer and never reaches the dialogue panel's option rows underneath.
	_catcher = Control.new()
	_catcher.name = "Catcher"
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_gui_input)
	_catcher.hide()
	add_child(_catcher)

	_root = Control.new()
	_root.name = "Panel"
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.hide()
	add_child(_root)
	_root.add_child(UIChrome.make_patch(UIChrome.PARCHMENT_PANEL))

	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	UIChrome.add_margins(margin, 28, 24, 28, 22)
	_root.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	_stack = stack

	var ribbon := Control.new()
	ribbon.custom_minimum_size = Vector2(210.0, 42.0)
	ribbon.add_child(UIChrome.make_horizontal_patch(UIChrome.BLUE_RIBBON, UIChrome.RIBBON_PATCH_MARGIN_X, UIChrome.RIBBON_PATCH_MARGIN_Y))
	stack.add_child(ribbon)
	_title_label = UIChrome.make_label("Purchase", "Header")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIChrome.full_rect(_title_label)
	ribbon.add_child(_title_label)

	_summary_label = UIChrome.make_label("", "Menu")
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_summary_label)
	_price_label = UIChrome.make_label("")
	stack.add_child(_price_label)
	_after_label = UIChrome.make_label("")
	stack.add_child(_after_label)

	for i in 2:
		var row := UIChrome.make_label("", "Menu")
		row.custom_minimum_size = Vector2(0.0, 30.0)
		stack.add_child(row)
		_row_labels.append(row)
	_hint_label = UIChrome.make_label("", "Small")
	_hint_label.add_theme_color_override("font_color", LOCKED_COLOR)
	stack.add_child(_hint_label)
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_rows_gui_input)
	ObservableBus.domain_event.connect(_on_domain_event)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	match type:
		WIEvents.PURCHASE_OFFERED:
			_show(payload)
		WIEvents.PURCHASE_CONFIRMED, WIEvents.PURCHASE_CANCELLED, WIEvents.DIALOGUE_ENDED:
			_hide()
		WIEvents.INPUT_DEVICE_CHANGED:
			if _shown:
				_refresh_rows()


func _show(offer: Dictionary) -> void:
	_offer = offer
	_cursor = ROW_CANCEL
	_armed = false
	_serial += 1
	var serial := _serial
	_summary_label.text = _summary_text(offer)
	_price_label.text = "Price: %d gold" % int(offer.get("price", 0))
	_after_label.text = "Gold after: %d" % int(offer.get("gold_after", 0))
	_refresh_rows()
	_catcher.show()
	_root.show()
	_shown = true
	_fit_panel_height()
	ObservableBus.emit_domain_event(WIEvents.UI_PURCHASE_CONFIRM_RENDERED, {
		"conversation": String(offer.get("conversation", "")),
		"item": String(offer.get("item", "")),
		"summary": _summary_label.text,
		"price": int(offer.get("price", 0)),
		"gold_after": int(offer.get("gold_after", 0)),
		"cursor": _cursor,
		"armed": false,
	})
	_arm_later(serial)


func _arm_later(serial: int) -> void:
	await get_tree().create_timer(ARM_SECONDS).timeout
	if not _shown or serial != _serial:
		return
	_armed = true
	ObservableBus.emit_domain_event(WIEvents.UI_PURCHASE_CONFIRM_ARMED, {"conversation": String(_offer.get("conversation", "")), "item": String(_offer.get("item", ""))})


## Height from FONT METRICS at the real inner width (the dialogue panel's
## method): an autowrap Label queried before layout reports its width-0
## wrap height, and a fixed 250px clipped the hint row under the border.
func _fit_panel_height() -> void:
	var inner_w := PANEL_SIZE.x - PANEL_MARGINS.x
	var sep := float(_stack.get_theme_constant("separation"))
	var needed := 0.0
	for child: Node in _stack.get_children():
		var lbl := child as Label
		if lbl == null:
			if child is Control:
				needed += (child as Control).get_combined_minimum_size().y + sep
			continue
		var font := lbl.get_theme_font("font")
		var fsz := lbl.get_theme_font_size("font_size")
		var text_h := font.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, inner_w, fsz).y
		needed += maxf(text_h, lbl.custom_minimum_size.y) + sep
	var h := maxf(PANEL_SIZE.y, needed + PANEL_MARGINS.y + PATCH_SLACK)
	_root.custom_minimum_size = Vector2(PANEL_SIZE.x, h)
	_root.size = Vector2(PANEL_SIZE.x, h)
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -h * 0.5, PANEL_SIZE.x * 0.5, h * 0.5)


func _hide() -> void:
	if not _shown:
		return
	_shown = false
	_armed = false
	_offer = {}
	_root.hide()
	_catcher.hide()
	ObservableBus.emit_domain_event(WIEvents.UI_PURCHASE_CONFIRM_HIDDEN, {})


## The item's catalog name when the row grants one, else the row text with its
## "(N gold)" token stripped (the price has its own line). A trade-in names
## what the player hands over.
func _summary_text(offer: Dictionary) -> String:
	var summary := String(offer.get("item_name", ""))
	if summary.is_empty():
		summary = _price_re.sub(String(offer.get("text", "")), "")
	var consumes: Array = offer.get("consumes", [])
	if not consumes.is_empty():
		summary += "\nHands over: %s" % ", ".join(PackedStringArray(consumes))
	return summary


func _refresh_rows() -> void:
	var labels := ["Cancel", "Buy for %d gold" % int(_offer.get("price", 0))]
	for i in _row_labels.size():
		var mark := "> " if i == _cursor else "  "
		_row_labels[i].text = "%s%s" % [mark, labels[i]]
	_hint_label.text = "%s choose   %s select   %s back" % [WIInputHints.label("move"), WIInputHints.label("confirm"), WIInputHints.label("cancel")]


func _pending() -> bool:
	return Game.sim != null and not Game.sim.pending_purchase.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not _shown or not _pending():
		return
	if event.is_action_pressed("cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if not _armed:
		# Opening tap, held key, or a double tap: swallowed, never routed to
		# the dialogue panel underneath and never a Buy.
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_cursor = ROW_BUY if _cursor == ROW_CANCEL else ROW_CANCEL
		_refresh_rows()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_select(_cursor)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		# Digit keys pick dialogue rows; inside the modal they must not
		# fall through to the panel and pick a second purchase.
		get_viewport().set_input_as_handled()


func _select(row: int) -> void:
	if row == ROW_BUY:
		Game.sim.purchase_confirm()
	else:
		_cancel()


func _cancel() -> void:
	Game.sim.purchase_cancel()


func _on_rows_gui_input(event: InputEvent) -> void:
	if not _shown or not _pending():
		return
	if event is InputEventMouseMotion:
		var idx := UIChrome.control_index_at(_row_labels, (event as InputEventMouseMotion).position)
		if idx >= 0 and idx != _cursor:
			_cursor = idx
			_refresh_rows()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_root.accept_event()
	if not _armed:
		return
	var idx := UIChrome.control_index_at(_row_labels, mb.position)
	if idx >= 0:
		_cursor = idx
		_refresh_rows()
		_select(idx)


func _on_catcher_gui_input(event: InputEvent) -> void:
	if not _shown or not _pending():
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_catcher.accept_event()
	if _armed:
		_cancel()


## QA seams: 0 = Cancel, 1 = Buy.
func row_rect(i: int) -> Rect2:
	if not _shown or i < 0 or i >= _row_labels.size():
		return Rect2()
	var control := _row_labels[i]
	return Rect2(control.global_position, control.size)


func display_state() -> Dictionary:
	return {"shown": _shown, "armed": _armed, "cursor": _cursor, "summary": _summary_label.text, "price": _price_label.text, "after": _after_label.text, "panel_rect": [_root.global_position.x, _root.global_position.y, _root.size.x, _root.size.y]}
