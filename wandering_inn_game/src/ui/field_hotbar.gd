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

var _hotbar: WIHotbar
var _selection_label: Label
## Parchment-strip chrome panel drawn directly behind `_selection_label`
## (added to the tree BEFORE it, so it draws underneath -- Control siblings
## paint in child order). Sized/positioned in lockstep with the label by
## `_position_selection_label`; visibility mirrors the label's own in
## `_update_selection_label`.
var _selection_label_backing: Control
var _field_skills: Array = []
var _last_slots: Array = []
var _combat_hidden := false
var _dialogue_open := false


func _ready() -> void:
	var root := Control.new()
	UIChrome.apply_theme(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_hotbar = HOTBAR_SCRIPT.new()
	_hotbar.name = "FieldHotbarBar"
	root.add_child(_hotbar)
	_selection_label_backing = UIChrome.make_chrome_panel(UIChrome.PARCHMENT_STRIP, UIChrome.STRIP_PATCH_MARGIN)
	_selection_label_backing.name = "SelectionLabelBacking"
	_selection_label_backing.visible = false
	root.add_child(_selection_label_backing)
	_selection_label = UIChrome.make_label("")
	_selection_label.name = "SelectionLabel"
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.visible = false
	root.add_child(_selection_label)
	_hotbar.slot_clicked.connect(func(index: int) -> void: slot_activate_requested.emit(index + 1))
	ObservableBus.domain_event.connect(_on_domain_event)


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
	_update_selection_label(index)


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
	var viewport_width := get_viewport().get_visible_rect().size.x
	var backing_x := clampf(slot_center_x - backing_size.x * 0.5, 0.0, maxf(0.0, viewport_width - backing_size.x))
	var backing_top := rect.position.y - backing_size.y - SELECTION_LABEL_GAP
	_selection_label_backing.custom_minimum_size = backing_size
	_selection_label_backing.size = backing_size
	_selection_label_backing.position = Vector2(backing_x, backing_top)
	_selection_label.position = Vector2(backing_x, backing_top) + padding


func _on_domain_event(type: String, _payload: Dictionary) -> void:
	match type:
		WIEvents.WORLD_READY:
			_combat_hidden = false
			_dialogue_open = false
			_apply_visibility()
			_render()
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


func _apply_visibility() -> void:
	visible = not (_combat_hidden or _dialogue_open)


func _render() -> void:
	_field_skills = _collect_field_skills()
	var slots: Array = []
	var readout_lines: Array = []
	var number := 1
	var combatants_catalog := _load_combatants_catalog()
	for id: String in _field_skills:
		var sk: Dictionary = Game.sim.skills.get(id, {})
		slots.append({
			"type": "skill",
			"id": id,
			"label": String(sk.get("display_name", id)),
			"icon": String(sk.get("icon", "")),
			"key_hint": str(number),
		})
		readout_lines.append("%d  %s" % [number, _readout_line(sk, id, combatants_catalog)])
		number += 1
	_last_slots = slots
	_hotbar.render(slots, -1)
	ObservableBus.emit_domain_event(WIEvents.UI_FIELD_HOTBAR_RENDERED, {"slots": _field_skills.size(), "readout_lines": readout_lines})


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
