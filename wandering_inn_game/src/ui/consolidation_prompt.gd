extends CanvasLayer
## Consolidation offer prompt (M6 T8). The sim's sleep beat DEFERS before
## evolutions when a consolidation is available (spec §2.5 REV 2), emitting
## `consolidation_offered` and stashing `pending_consolidation`. This prompt
## renders that choice; the player's answer drives Game.sim.accept_consolidation
## / decline_consolidation, which resume the deferred beat. Modeled on the
## journal panel + the pause menu's two-row confirm (M5 UI style).
##
## Opaque-until-sleep is user-locked: the prompt names the two parent classes
## and the consolidated class, but NEVER the merged level -- a number would leak
## progression math the design keeps hidden (T5 review constraint).
##
## Input arbitration: while an offer is pending (Game.sim.pending_consolidation
## non-empty) world / journal / pause all decline input, so this prompt owns the
## keyboard until the choice is made. Cancel maps to decline (always safe -- the
## offer is re-presented at the next qualifying sleep) and consuming cancel here
## also stops the pause menu opening over the modal.

const PANEL_SIZE := Vector2(600.0, 300.0)
const ROWS := ["Consolidate", "Keep them apart"]

## True while the prompt is visible. Kept for parity with journal/pause; the
## world/journal/pause input gates key off Game.sim.pending_consolidation.
var open := false

var _root: Control
var _title_label: Label
var _body_label: Label
var _row_labels: Array[Label] = []
var _cursor := 0
var _target_display := ""


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = PANEL_SIZE
	_root.size = PANEL_SIZE
	UIChrome.set_offsets(_root, -PANEL_SIZE.x * 0.5, -PANEL_SIZE.y * 0.5, PANEL_SIZE.x * 0.5, PANEL_SIZE.y * 0.5)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	ObservableBus.domain_event.connect(_on_domain_event)

	# A save taken mid-offer restores Game.sim.pending_consolidation but re-emits
	# no consolidation_offered event, so reconstruct the prompt from sim state on
	# spawn (this node is rebuilt fresh on every world swap -- see main.gd).
	var pending := Game.sim.pending_offer_display()
	if not pending.is_empty():
		_show_offer(pending)


func _on_domain_event(type: String, payload: Dictionary) -> void:
	if type == WIEvents.CONSOLIDATION_OFFERED:
		_show_offer(payload)


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
	# Emit the class id (not the display name) so QA matches consolidation_offered's `target`.
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
		_choose(_cursor == 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		_choose(false)
		get_viewport().set_input_as_handled()


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
