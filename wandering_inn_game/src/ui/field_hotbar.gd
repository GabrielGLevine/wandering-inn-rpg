class_name WIFieldHotbar
extends CanvasLayer
## DIALOGUE gate: this layer is added to the tree AFTER `DialoguePanel`
## (main.gd's `_spawn_ui_layers` order) and neither sets an explicit
## CanvasLayer `layer`, so at the shared default it drew ON TOP of the
## conversation panel's bottom-anchored option rows. RULING: dialogue always
## wins -- HIDE (never reposition/shift; a moving hotbar reads as jitter)
## while a conversation is open. Gated on `_dialogue_open`, tracked from the
## SAME DIALOGUE_STARTED/DIALOGUE_ENDED pair message_layer.gd's own
## `_conversation_open` already keys off (the dialogue-open state the UI
## already tracks) -- combined with `_combat_hidden` via `_apply_visibility`
## since combat and a real conversation never overlap (combat_screen ends
## any open dialogue first) but both independently want this layer hidden.
const HOTBAR_SCRIPT := preload("res://src/ui/hotbar.gd")

signal slot_activate_requested(slot: int)

const SELECTION_LABEL_GAP := 4.0
const SELECTION_LABEL_PADDING_X := 10.0
const SELECTION_LABEL_PADDING_Y := 4.0
const TOGGLE_SIZE := Vector2(144.0, 52.0)
const TOGGLE_GAP := 8.0
const READOUT_MAX_WIDTH := 720.0
const READOUT_SCROLLBAR_RESERVE := 14.0
const CONTROLS_BOTTOM_MARGIN := 10.0
const READOUT_GAP := 8.0
const READOUT_SELECTION_CLEARANCE := 34.0

var _hotbar: WIHotbar
var _root: Control
var _readout_panel: PanelContainer
var _readout_scroll: ScrollContainer
var _readout_label: Label
var _toggle: Control
var _toggle_label: Label
var _selection_label: Label
## Parchment-strip chrome panel drawn directly behind `_selection_label`
## (added to the tree BEFORE it, so it draws underneath -- Control siblings
## paint in child order). Sized/positioned in lockstep with the label by
## `_position_selection_label`; visibility mirrors the label's own in
## `_update_selection_label`.
var _selection_label_backing: Control
var _field_skills: Array = []
var _last_slots: Array = []
var _readout_lines: Array = []
var _slot_numbers: Array = []
var _fallback_labels: Array = []
var _expanded := true
var _combat_hidden := false
var _dialogue_open := false
var _panel_open := false


func _ready() -> void:
	_root = Control.new()
	UIChrome.apply_theme(_root)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hotbar = HOTBAR_SCRIPT.new()
	_hotbar.name = "FieldHotbarBar"
	_root.add_child(_hotbar)
	_build_readout()
	_build_toggle()
	_selection_label_backing = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_selection_label_backing.name = "SelectionLabelBacking"
	_selection_label_backing.visible = false
	_root.add_child(_selection_label_backing)
	_selection_label = UIChrome.make_label("")
	_selection_label.name = "SelectionLabel"
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.visible = false
	_root.add_child(_selection_label)
	_hotbar.slot_clicked.connect(func(index: int) -> void: slot_activate_requested.emit(index + 1))
	ObservableBus.domain_event.connect(_on_domain_event)
	WIInputHints.device_changed.connect(_on_device_changed)
	get_viewport().size_changed.connect(_layout_controls)
	_expanded = WISettings.field_readout_expanded()


func _build_readout() -> void:
	_readout_panel = UIChrome.make_chrome_panel_container(UIChrome.PARCHMENT_PANEL, UIChrome.PATCH_MARGIN)
	_readout_panel.name = "FieldReadout"
	_readout_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_readout_panel)
	_readout_scroll = ScrollContainer.new()
	_readout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_readout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_readout_scroll.clip_contents = true
	_readout_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_readout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_readout_panel.add_child(_readout_scroll)
	_readout_label = UIChrome.make_label("", "Small")
	_readout_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_readout_scroll.add_child(_readout_label)


func _build_toggle() -> void:
	_toggle = UIChrome.make_texture_panel(UIChrome.BLUE_BUTTON)
	_toggle.name = "FieldReadoutToggle"
	_toggle.custom_minimum_size = TOGGLE_SIZE
	_toggle.size = TOGGLE_SIZE
	_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle.gui_input.connect(_on_toggle_gui_input)
	_root.add_child(_toggle)
	_toggle_label = UIChrome.make_label("", "Small")
	_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toggle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toggle.add_child(_toggle_label)


func hotbar_node() -> WIHotbar:
	return _hotbar


func skill_for_slot(n: int) -> String:
	var idx := n - 1
	if idx < 0 or idx >= _field_skills.size():
		return ""
	return String(_field_skills[idx])


func slot_count() -> int:
	return _field_skills.size()


func set_selected(index: int) -> void:
	_hotbar.render(_last_slots, index)
	_layout_controls()
	_update_selection_label(index)


func toggle_rect() -> Rect2:
	if not visible or _toggle == null or not _toggle.visible:
		return Rect2()
	return Rect2(_toggle.global_position, _toggle.size)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("field_readout"):
		_set_expanded(not _expanded, true, "player")
		get_viewport().set_input_as_handled()


func _on_toggle_gui_input(event: InputEvent) -> void:
	# CONTRACT: Godot's default touch->mouse emulation shares this click path.
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		_set_expanded(not _expanded, true, "player")
		_toggle.accept_event()


func _on_device_changed(_device: String) -> void:
	_update_toggle_label()
	_emit_rendered("device")


## Shows/positions/hides the floating skill-name label for the given
## selection index and emits UI_FIELD_HOTBAR_SELECTION_RENDERED -- the ONE
## place both halves happen together, so the event always describes exactly
## what's on screen. `index < 0` (or out of range -- defensive only, callers
## never pass an invalid non-negative index today) is the disarmed case:
## label hidden, payload all-empty per that event's own doc comment.
func _update_selection_label(index: int) -> void:
	var skill_id := ""
	var label_text := ""
	if index >= 0 and index < _field_skills.size():
		skill_id = String(_field_skills[index])
		var sk: Dictionary = Game.sim.skills.get(skill_id, {})
		# `display_name` is ALREADY bracket-formatted ("[Basic Cleaning]") --
		# see this file's own doc comment; do not re-wrap it.
		label_text = String(sk.get("display_name", skill_id))
	if label_text == "":
		_selection_label.visible = false
		_selection_label_backing.visible = false
	else:
		_selection_label.text = label_text
		_position_selection_label(index)
		_selection_label.visible = true
		_selection_label_backing.visible = true
	ObservableBus.emit_domain_event(WIEvents.UI_FIELD_HOTBAR_SELECTION_RENDERED, {
		"index": index if label_text != "" else -1,
		"skill": skill_id if label_text != "" else "",
		"label": label_text,
	})


func _position_selection_label(index: int) -> void:
	var rect := _hotbar.slot_rect(index)
	if rect.size == Vector2.ZERO:
		_selection_label.visible = false
		_selection_label_backing.visible = false
		return
	var label_size := _selection_label.get_minimum_size()
	_selection_label.size = label_size
	var padding := Vector2(SELECTION_LABEL_PADDING_X, SELECTION_LABEL_PADDING_Y)
	var backing_size := label_size + padding * 2.0
	var slot_center_x := rect.position.x + rect.size.x * 0.5
	var safe := _current_safe_rect()
	var backing_x := clampf(slot_center_x - backing_size.x * 0.5, safe.position.x, maxf(safe.position.x, safe.end.x - backing_size.x))
	var backing_top := maxf(safe.position.y, rect.position.y - backing_size.y - SELECTION_LABEL_GAP)
	_selection_label_backing.custom_minimum_size = backing_size
	_selection_label_backing.size = backing_size
	_selection_label_backing.position = Vector2(backing_x, backing_top)
	_selection_label.position = Vector2(backing_x, backing_top) + padding


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	match type:
		WIEvents.WORLD_READY:
			_combat_hidden = false
			_dialogue_open = false
			_panel_open = false
			_expanded = WISettings.field_readout_expanded()
			var reason := "world_ready"
			if not WISettings.has_field_readout_choice() and Game.sim.times_slept > 0:
				WISettings.set_field_readout_expanded(false)
				_expanded = false
				reason = "prior_waking"
			_apply_visibility()
			_render(reason)
		WIEvents.CLASS_GAINED, WIEvents.CLASS_LEVEL_UP, WIEvents.CLASS_EVOLVED, WIEvents.LOADOUT_CHANGED:
			_render()
		WIEvents.COMBAT_STARTED:
			_combat_hidden = true
			_apply_visibility()
		WIEvents.UI_COMBAT_HIDDEN:
			_combat_hidden = false
			_apply_visibility()
		WIEvents.DIALOGUE_STARTED:
			_dialogue_open = true
			_apply_visibility()
		WIEvents.DIALOGUE_ENDED:
			_dialogue_open = false
			_apply_visibility()
		WIEvents.UI_PAUSE_SHOWN, WIEvents.UI_JOURNAL_SHOWN, WIEvents.UI_INVENTORY_SHOWN:
			_panel_open = true
			_apply_visibility()
		WIEvents.UI_PAUSE_HIDDEN, WIEvents.UI_JOURNAL_HIDDEN, WIEvents.UI_INVENTORY_HIDDEN:
			_panel_open = false
			_apply_visibility()
		WIEvents.UI_SLEEP_VEIL_FINISHED:
			if not WISettings.has_field_readout_choice() and Game.sim.times_slept >= 1:
				_set_expanded(false, true, "first_waking")
		WIEvents.UI_SETTINGS_RENDERED:
			_layout_controls()


func _apply_visibility() -> void:
	visible = not (_combat_hidden or _dialogue_open or _panel_open)


func _render(reason: String = "skills") -> void:
	_field_skills = _collect_field_skills()
	var slots: Array = []
	_readout_lines = []
	_slot_numbers = []
	_fallback_labels = []
	var number := 1
	var combatants_catalog := _load_combatants_catalog()
	for id: String in _field_skills:
		var sk: Dictionary = Game.sim.skills.get(id, {})
		var display := String(sk.get("display_name", id))
		var fallback := WIFieldHotbarLayout.fallback_label(display, id)
		slots.append({
			"type": "skill",
			"id": id,
			"label": display,
			"fallback_label": fallback,
			"icon": String(sk.get("icon", "")),
			"key_hint": str(number),
		})
		_slot_numbers.append(str(number))
		_fallback_labels.append(fallback)
		_readout_lines.append("%d  %s" % [number, _readout_line(sk, id, combatants_catalog)])
		number += 1
	_last_slots = slots
	_hotbar.render(slots, -1)
	_update_readout()
	_update_toggle_label()
	_layout_controls()
	_emit_rendered(reason)


func _set_expanded(value: bool, persist: bool, reason: String) -> void:
	if persist:
		WISettings.set_field_readout_expanded(value)
	_expanded = value
	_update_readout()
	_update_toggle_label()
	_layout_controls()
	_emit_rendered(reason)


func _update_readout() -> void:
	if _readout_panel == null:
		return
	_readout_label.text = "\n".join(_readout_lines)
	_readout_panel.visible = _expanded and not _readout_lines.is_empty()


func _update_toggle_label() -> void:
	if _toggle == null:
		return
	_toggle.visible = not _last_slots.is_empty()
	var verb := "Hide" if _expanded else "Show"
	_toggle_label.text = "%s details [%s]" % [verb, WIInputHints.label("field_readout")]


## CONTRACT: payload mirrors visible mode, order, numbering, and fallbacks.
func _emit_rendered(reason: String) -> void:
	if _hotbar == null:
		return
	ObservableBus.emit_domain_event(WIEvents.UI_FIELD_HOTBAR_RENDERED, {
		"slots": _field_skills.size(),
		"expanded": _expanded,
		"reason": reason,
		"toggle_label": _toggle_label.text if _toggle_label != null else "",
		"slot_numbers": _slot_numbers.duplicate(),
		"fallback_labels": _fallback_labels.duplicate(),
		"readout_lines": _readout_lines.duplicate(),
	})


func _layout_controls() -> void:
	if _hotbar == null or _root == null:
		return
	var viewport := get_viewport()
	# TRAP: swapped-out layers can receive bus events before queued deletion.
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	var safe := _current_safe_rect()
	var group_width := _hotbar.size.x
	if _toggle.visible:
		group_width += TOGGLE_GAP + TOGGLE_SIZE.x
	var group_left := safe.position.x + (safe.size.x - group_width) * 0.5
	var hotbar_center := group_left + _hotbar.size.x * 0.5
	var center_shift := hotbar_center - viewport_size.x * 0.5
	var safe_bottom := maxf(0.0, viewport_size.y - safe.end.y)
	_hotbar.offset_left = -_hotbar.size.x * 0.5 + center_shift
	_hotbar.offset_right = _hotbar.size.x * 0.5 + center_shift
	_hotbar.offset_top = -_hotbar.size.y - CONTROLS_BOTTOM_MARGIN - safe_bottom
	_hotbar.offset_bottom = -CONTROLS_BOTTOM_MARGIN - safe_bottom
	if _toggle.visible:
		_toggle.position = Vector2(group_left + _hotbar.size.x + TOGGLE_GAP, safe.end.y - CONTROLS_BOTTOM_MARGIN - TOGGLE_SIZE.y)
	var style := _readout_panel.get_theme_stylebox("panel")
	var frame_size := WIFieldHotbarLayout.style_frame_size(style)
	var panel_width := minf(READOUT_MAX_WIDTH, maxf(1.0, safe.size.x - WIFieldHotbarLayout.OUTER_MARGIN * 2.0))
	var text_width := panel_width - frame_size.x - READOUT_SCROLLBAR_RESERVE
	var content_height := _readout_content_height(text_width)
	var desired_height := content_height + frame_size.y
	var reserved_bottom := maxf(_hotbar.size.y, TOGGLE_SIZE.y) + CONTROLS_BOTTOM_MARGIN + READOUT_GAP + READOUT_SELECTION_CLEARANCE
	var rect := WIFieldHotbarLayout.readout_rect(safe, READOUT_MAX_WIDTH, desired_height, reserved_bottom)
	_readout_panel.position = rect.position
	_readout_panel.size = rect.size
	_readout_panel.custom_minimum_size = rect.size
	var content_rect := WIFieldHotbarLayout.style_content_rect(Rect2(Vector2.ZERO, rect.size), style)
	_readout_label.custom_minimum_size = Vector2(maxf(1.0, content_rect.size.x - READOUT_SCROLLBAR_RESERVE), content_height)
	_readout_label.size = _readout_label.custom_minimum_size


func _current_safe_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	return WIFieldHotbarLayout.viewport_safe_rect(
		viewport.get_visible_rect().size,
		DisplayServer.get_display_safe_area(),
		DisplayServer.screen_get_size(),
	)


func _readout_content_height(width: float) -> float:
	if _readout_lines.is_empty() or width <= 0.0:
		return 1.0
	var text := "\n".join(_readout_lines)
	var font := _readout_label.get_theme_font("font")
	var font_size := _readout_label.get_theme_font_size("font_size")
	var measured := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var line_height := font.get_height(font_size)
	var line_spacing := float(_readout_label.get_theme_constant("line_spacing"))
	var lines := maxi(1, int(round(measured.y / maxf(line_height, 1.0))))
	return measured.y + float(maxi(0, lines - 1)) * line_spacing


func _readout_line(sk: Dictionary, id: String, combatants_catalog: Array = []) -> String:
	var display := String(sk.get("display_name", id))
	var desc := String(sk.get("description", ""))
	var effect_lines := WIEffectText.skill_effect_lines(sk, combatants_catalog)
	if effect_lines.is_empty():
		return "%s — %s" % [display, desc] if desc != "" else display
	if desc == "":
		return "%s — %s" % [display, effect_lines[0]]
	return "%s — %s — %s" % [display, effect_lines[0], desc]


func _load_combatants_catalog() -> Array:
	const COMBATANTS_PATH := "res://data/combatants.json"
	if not FileAccess.file_exists(COMBATANTS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has("combatants"):
		return (parsed as Dictionary)["combatants"]
	return []


## The field hotbar's slot list now comes straight from
## the sim's own `field_hotbar_loadout()` (moved there so the FILTER lives on
## the sim, per the plan's "sim owns state + filters" rule -- this file used
## to duplicate the known_skills()-filtered-by-field derivation inline; it now
## only asks for the already-filtered result). AUTO (loadout empty) is
## byte-identical to the pre-K2b order: innate skills first, then kit order.
func _collect_field_skills() -> Array:
	var loadout: Array = Game.sim.field_hotbar_loadout()
	# Defensive filter: a skill id no longer in `Game.sim.skills` at all (a
	# rename or data edit the sim's own field:true filter wouldn't catch,
	# since it only checks the TAG, not that the catalog entry still exists)
	# must never produce a broken/blank slot that reads as part of the bar
	# having vanished. CONSTRAINT: `_render()` builds `slots` AND
	# `skill_for_slot`'s mapping straight off this list, so filter HERE (not
	# inside `_render()`'s per-skill loop) to keep both in lockstep -- a
	# skipped id is skipped everywhere, not just in the visual row.
	return loadout.filter(func(id: Variant) -> bool: return Game.sim.skills.has(String(id)))
