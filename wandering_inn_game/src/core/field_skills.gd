class_name WIFieldSkills
extends RefCounted

var _event_sink: Callable
var _skills: Dictionary
var _door_openable: Callable
var _break_sneak: Callable
var _toggle_sneak: Callable
var _mark_skill_used: Callable
var _record_accomplishment: Callable
var _remove_entity: Callable
var _use_skill: Callable
var _toggle_light: Callable
var _blink: Callable
var _ward: Callable
var _animate: Callable


func _init(event_sink: Callable, skills: Dictionary, break_sneak_cb: Callable, toggle_sneak_cb: Callable, mark_skill_used_cb: Callable, record_accomplishment_cb: Callable, remove_entity_cb: Callable, use_skill_cb: Callable, toggle_light_cb: Callable, blink_cb: Callable, ward_cb: Callable, animate_cb: Callable, door_openable_cb: Callable = Callable()) -> void:
	_event_sink = event_sink
	_skills = skills
	_door_openable = door_openable_cb
	_break_sneak = break_sneak_cb
	_toggle_sneak = toggle_sneak_cb
	_mark_skill_used = mark_skill_used_cb
	_record_accomplishment = record_accomplishment_cb
	_remove_entity = remove_entity_cb
	_use_skill = use_skill_cb
	_toggle_light = toggle_light_cb
	_blink = blink_cb
	_ward = ward_cb
	_animate = animate_cb


## CONTRACT (plan P1): faced entity with requires_skill==skill_id + on_skill_use
## routes via use_skill(skill_id, prop_id) — SAME seam interact() uses; emitted
## event stream BYTE-IDENTICAL to interact-with-requires_skill. Fallthrough:
## no qualifying entity -> skill's field_ambient toast; none authored -> refusal
## idiom. Unknown-skill and non-field guards are the CALLER's job
## (wi_game.use_skill_field) — never re-guard here.
func dispatch(skill_id: String, known: bool, target: Dictionary, faced_cell: Vector2i, current_map: String, frozen_cells: Dictionary, entity_first_use: Dictionary, is_freezable: bool) -> Dictionary:
	# Required-skill props route through WIGame.use_skill so field and generic interaction share one effect seam.
	if not known:
		_emit(WIEvents.SKILL_UNKNOWN, {"skill": skill_id})
		_emit(WIEvents.TOAST, {"text": "You don't know how to do that yet."})
		return {}
	if not bool(_skills.get(skill_id, {}).get(WIKeys.FIELD, false)):
		_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
		_emit(WIEvents.TOAST, {"text": "That's not something you can do out here."})
		return {}
	if bool(_skills.get(skill_id, {}).get("sneaks", false)):
		return _toggle_sneak.call(skill_id)
	var skill: Dictionary = _skills.get(skill_id, {})
	if bool(skill.get("blinks", false)):
		return _blink.call(skill_id, skill)
	if bool(skill.get("wards", false)):
		_break_sneak.call()
		return _ward.call(skill_id, skill, faced_cell)
	if bool(skill.get("animates", false)) or bool(skill.get("tames", false)):
		_break_sneak.call()
		return _animate.call(skill_id, skill, target)
	if not target.is_empty() and String(target.get("requires_skill", "")) == skill_id and target.has("on_skill_use"):
		_break_sneak.call()
		return _use_skill.call(skill_id, String(target[WIKeys.ID]))
	# Pantry-door consolidation (user FEEL verdict 2026-07-19): `skill_uses`
	# = a per-skill map of on_skill_use arms, so ONE entity can answer
	# multiple Skills differently (the door: observe reads the runes,
	# detect_magic reads the wardwork) instead of clustering sibling props.
	# Routed BEFORE the generic observe arm so a mapped observe wins.
	if not target.is_empty() and (target.get("skill_uses", {}) as Dictionary).has(skill_id):
		_break_sneak.call()
		return _use_skill.call(skill_id, String(target[WIKeys.ID]))
	if skill_id == "observe" and not target.is_empty():
		_break_sneak.call()
		var observe_line := String(target.get("observe", "You watch. Details surface."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		if _bank_first_use(entity_first_use, "observe", String(target[WIKeys.ID])):
			_record_accomplishment.call("observed_things", 1)
		_emit(WIEvents.TOAST, {"text": observe_line})
		return {"observed": String(target[WIKeys.ID])}
	if skill_id == "charming_smile" and not target.is_empty():
		_break_sneak.call()
		var friendly_line := String(target.get("friendly_line", "You offer a warm, disarming smile. It costs nothing, and it is not unwelcome."))
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		if _bank_first_use(entity_first_use, "friendly", String(target[WIKeys.ID])):
			_record_accomplishment.call("befriended_moments", 1)
		_emit(WIEvents.TOAST, {"text": friendly_line})
		return {"befriended": String(target[WIKeys.ID])}
	if not target.is_empty() and bool(target.get("burnable", false)) and bool(_skills.get(skill_id, {}).get("burns", false)):
		_break_sneak.call()
		var burned_id := String(target[WIKeys.ID])
		var burned_cell: Vector2i = target[WIKeys.CELL]
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": burned_id})
		_mark_skill_used.call(skill_id)
		_record_accomplishment.call("burned_the_debris", 1)
		var burn_toast := String(target.get("burn_toast", "Flame takes the debris. It crackles, collapses to ash, and the way is clear."))
		_remove_entity.call(burned_id)
		_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [burned_cell.x, burned_cell.y], "to": "scorched"})
		_emit(WIEvents.TOAST, {"text": burn_toast})
		return {"burned": burned_id}
	var is_frozen := (frozen_cells.get(current_map, {}) as Dictionary).has(faced_cell)
	if bool(_skills.get(skill_id, {}).get("freezes", false)) and is_freezable and not is_frozen:
		_break_sneak.call()
		if not frozen_cells.has(current_map):
			frozen_cells[current_map] = {}
		(frozen_cells[current_map] as Dictionary)[faced_cell] = true
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TERRAIN_CHANGED, {"map": current_map, "cell": [faced_cell.x, faced_cell.y], "to": "ice"})
		var freeze_toast := String(_skills.get(skill_id, {}).get("freeze_toast", "Frost races across the water and locks it solid. You can cross now. Until it thaws."))
		_emit(WIEvents.TOAST, {"text": freeze_toast})
		return {"frozen": [faced_cell.x, faced_cell.y]}
	# b7 #214b: skill-authored door flavor — a data key, not an effect block
	# (test_effect_text's empty-effect-lines pin for open_doors stays
	# honest). Fires only on an OPENABLE door (review M1): a sealed
	# door_when/portal gate must not read "was not locked", and the hidden
	# garden door must not leak via toast — unmet doors fall through to
	# field_ambient like any non-door.
	var door_flavor := String(_skills.get(skill_id, {}).get("door_flavor", ""))
	if door_flavor != "" and not target.is_empty() \
			and _door_openable.is_valid() and bool(_door_openable.call(target)):
		_break_sneak.call()
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": String(target[WIKeys.ID])})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TOAST, {"text": door_flavor})
		return {"door_flavored": String(target[WIKeys.ID])}
	# [Light]'s toggle, the `sneaks` idiom for the orb (v0.16.1 finding 5). This
	# replaced a hardcoded `if skill_id == "light"` inside the field_ambient arm
	# that only ever SET the flag, so a second cast was a no-op and only sleep()
	# put the orb out.
	# PLACEMENT IS LOAD-BEARING: this must stay BELOW the requires_skill and
	# skill_uses arms above. Lighting a light-requiring prop (the witch hollow's
	# threshold candles) faces an entity whose on_skill_use answers "light" --
	# route the toggle first and lighting the candles would snuff your own orb as
	# a side effect. Facing such a prop, the prop wins; facing anything else, the
	# orb toggles.
	if bool(_skills.get(skill_id, {}).get("toggles_light", false)):
		return _toggle_light.call(skill_id)
	var field_ambient := String(_skills.get(skill_id, {}).get("field_ambient", ""))
	if field_ambient != "":
		_emit(WIEvents.SKILL_USED, {"skill": skill_id, "context": "exploration", "target": ""})
		_mark_skill_used.call(skill_id)
		_emit(WIEvents.TOAST, {"text": field_ambient})
		return {"ambient": skill_id}
	_emit(WIEvents.SKILL_NO_EFFECT, {"skill": skill_id, "target": ""})
	_emit(WIEvents.TOAST, {"text": "Nothing here calls for that."})
	return {}


func _bank_first_use(entity_first_use: Dictionary, verb: String, entity_id: String) -> bool:
	var key := "%s:%s" % [verb, entity_id]
	if entity_first_use.has(key):
		return false
	entity_first_use[key] = true
	return true


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
