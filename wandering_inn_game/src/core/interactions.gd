class_name WIInteractions
extends RefCounted

## Issue #194a seam 1: WIGame.interact()'s kind-dispatch moved here VERBATIM
## behind injected Callables — the emitted event stream must stay
## byte-identical (modulo wall-clock t) to the pre-extraction routing at any
## pinned seed. Owns the door/contains/portal `requires` gate and container
## opening; board/delivery/portal glue, shared effect resolution, and every
## accomplishment/gold/combat side effect stay in WIGame behind their
## Callables. The caller (WIGame.interact) still owns _tick_action + facing
## resolution; state dicts (social_talked/entity_first_use/container_state)
## are passed by reference at dispatch and mutated in place.

var _event_sink: Callable
var _accomplishment_gate_met: Callable
var _record_accomplishment: Callable
var _break_sneak: Callable
var _talk_pool_line: Callable
var _start_dialogue: Callable
var _sleep: Callable
var _interact_board: Callable
var _interact_delivery_board: Callable
var _interact_portal_menu: Callable
var _interact_fence_menu: Callable
var _transition: Callable
var _current_map: Callable
var _resolve_skill_use_effect: Callable
var _holds_weapon_family: Callable
var _has_items: Callable
var _known_skills: Callable
var _apply_gold_effect: Callable
var _use_skill: Callable
var _encounter_gate_met: Callable
var _start_combat: Callable
var _pickup: Callable


func _init(event_sink: Callable, accomplishment_gate_met_cb: Callable, record_accomplishment_cb: Callable, break_sneak_cb: Callable, talk_pool_line_cb: Callable, start_dialogue_cb: Callable, sleep_cb: Callable, interact_board_cb: Callable, interact_delivery_board_cb: Callable, interact_portal_menu_cb: Callable, interact_fence_menu_cb: Callable, transition_cb: Callable, current_map_cb: Callable, resolve_skill_use_effect_cb: Callable, holds_weapon_family_cb: Callable, known_skills_cb: Callable, apply_gold_effect_cb: Callable, use_skill_cb: Callable, encounter_gate_met_cb: Callable, start_combat_cb: Callable, pickup_cb: Callable, has_items_cb: Callable = Callable()) -> void:
	_event_sink = event_sink
	_accomplishment_gate_met = accomplishment_gate_met_cb
	_record_accomplishment = record_accomplishment_cb
	_break_sneak = break_sneak_cb
	_talk_pool_line = talk_pool_line_cb
	_start_dialogue = start_dialogue_cb
	_sleep = sleep_cb
	_interact_board = interact_board_cb
	_interact_delivery_board = interact_delivery_board_cb
	_interact_portal_menu = interact_portal_menu_cb
	_interact_fence_menu = interact_fence_menu_cb
	_transition = transition_cb
	_current_map = current_map_cb
	_resolve_skill_use_effect = resolve_skill_use_effect_cb
	_holds_weapon_family = holds_weapon_family_cb
	_has_items = has_items_cb
	_known_skills = known_skills_cb
	_apply_gold_effect = apply_gold_effect_cb
	_use_skill = use_skill_cb
	_encounter_gate_met = encounter_gate_met_cb
	_start_combat = start_combat_cb
	_pickup = pickup_cb


func dispatch(target: Dictionary, social_talked: Dictionary, entity_first_use: Dictionary, container_state: Dictionary) -> Dictionary:
	if target.is_empty():
		_emit(WIEvents.INTERACT_NOTHING, {})
		return {}
	var is_door_transition := String(target[WIKeys.KIND]) == "door" \
			or (target.has("door_when") and _door_gate_met(target["door_when"] as Dictionary))
	if not is_door_transition:
		_break_sneak.call()
	match String(target[WIKeys.KIND]):
		"npc":
			var npc_id := String(target[WIKeys.ID])
			if target.has("talk_pool") and not (target["talk_pool"] as Array).is_empty() and not bool(social_talked.get(npc_id, false)):
				return _talk_pool_line.call(target)
			if target.has(WIKeys.CONVERSATION):
				if bool(_start_dialogue.call(String(target[WIKeys.CONVERSATION]), String(target[WIKeys.ID]))):
					return {"dialogue": true}
				var line: Dictionary = target["dialogue"][0]
				_emit(WIEvents.DIALOGUE_LINE, line)
				return line
			var line: Dictionary = target["dialogue"][0]
			_emit(WIEvents.DIALOGUE_LINE, line)
			return line
		"prop":
			if bool(target.get("sleep", false)):
				var sleep_toast := String(target.get("sleep_toast", ""))
				if sleep_toast != "":
					_emit(WIEvents.TOAST, {"text": sleep_toast})
				_sleep.call()
				return {"slept": true}
			if bool(target.get("board", false)):
				return _interact_board.call(target)
			if bool(target.get("delivery_board", false)):
				return _interact_delivery_board.call(target)
			if target.has("contains") and (not target.has("contains_when") or _door_gate_met(target["contains_when"] as Dictionary)):
				return _interact_container(target, container_state)
			if target.has("door_when") and _door_gate_met(target["door_when"] as Dictionary):
				var dw: Dictionary = target["door_when"]
				var open_toast := String(dw.get("open_toast", ""))
				if open_toast != "":
					_emit(WIEvents.TOAST, {"text": open_toast})
				_transition.call(String(dw["to_map"]), Vector2i(int(dw["to_cell"][0]), int(dw["to_cell"][1])))
				return {"map": String(_current_map.call())}
			if bool(target.get("portal_menu", false)) and _door_gate_met(target.get("portal_menu_when", {}) as Dictionary):
				return _interact_portal_menu.call()
			# b2 #218: the fence register opens only once trusted; unmet falls
			# through to the plain prop (the eyed_the_stash doorbell).
			if bool(target.get("fence_menu", false)) and _door_gate_met(target.get("fence_menu_when", {}) as Dictionary):
				return _interact_fence_menu.call()
			if target.has("on_interact_accomplishment"):
				var req_family := String(target.get("requires_weapon_family", ""))
				if req_family != "" and not bool(_holds_weapon_family.call(req_family)):
					var hint := String(target.get("item_hint_toast", "Empty hands won't do it. You'd need the right weapon in your pack."))
					_emit(WIEvents.TOAST, {"text": hint})
					return {"item_hint": req_family}
				# b7 #214c: requires_item now gates the PLAIN interact arm too
				# (it was a bench/skill-path key only) — same String|Array
				# all-or-nothing contract, nothing consumed. Absent key = empty
				# list = met, so every shipped prop is byte-identical.
				if _has_items.is_valid() and not bool(_has_items.call(target.get("requires_item", ""))):
					var item_hint := String(target.get("item_hint_toast", "Bare hands won't do it. Something in your pack might."))
					_emit(WIEvents.TOAST, {"text": item_hint})
					return {"item_hint": String(target.get(WIKeys.ID, ""))}
				if bool(target.get("once_per_waking", false)):
					var waking_key := "serve:%s" % String(target[WIKeys.ID])
					if entity_first_use.has(waking_key):
						var spent_toast := String(target.get("once_per_waking_toast", "Nothing more to carry out right now. Come back another day."))
						_emit(WIEvents.TOAST, {"text": spent_toast})
						return {"once_per_waking_spent": true}
					# Bank precedes effect resolution: never combine with a met-gated
					# locked variant, or its flavor read burns the waking use/wage.
					entity_first_use[waking_key] = true
				var resolved: Dictionary = _resolve_skill_use_effect.call({
					"accomplishment": target["on_interact_accomplishment"],
					"toast": target.get("toast", ""),
					"gold": target.get("gold", 0),
					"variants": target.get("variants", []),
				})
				var accomplishment_id := String(resolved["accomplishment"])
				_record_accomplishment.call(accomplishment_id, 1)
				var toast_text := String(resolved.get("toast", ""))
				if toast_text != "":
					_emit(WIEvents.TOAST, {"text": toast_text})
				if int(resolved.get("gold", 0)) != 0:
					var wage := int(resolved["gold"])
					if bool(target.get("once_per_waking", false)) and (_known_skills.call() as Array).has("perfect_hospitality"):
						wage += 1
					_apply_gold_effect.call(wage, String(target[WIKeys.ID]))
				return {"accomplishment": accomplishment_id}
			# Explicit-Skill-use directive (2026-07-10): a KNOWN required skill
			# hints toward the hotbar (interact never auto-casts); an unknown
			# one routes to use_skill for its standard refusal.
			var req_skill := String(target.get("requires_skill", ""))
			if (_known_skills.call() as Array).has(req_skill):
				var hint := String(target.get("skill_hint_toast", ""))
				if hint == "":
					hint = "Bare hands won't do it. Something you know how to do might."
				_emit(WIEvents.TOAST, {"text": hint})
				return {"skill_hint": req_skill}
			return _use_skill.call(req_skill, String(target[WIKeys.ID]))
		"encounter":
			if not bool(_encounter_gate_met.call(target)):
				var gate_toast := String(target.get("gate_closed_toast", ""))
				if gate_toast != "":
					_emit(WIEvents.TOAST, {"text": gate_toast})
				return {}
			if target.has(WIKeys.CONVERSATION):
				if bool(_start_dialogue.call(String(target[WIKeys.CONVERSATION]), String(target[WIKeys.ID]))):
					return {"dialogue": true}
				if bool(_start_combat.call(String(target[WIKeys.ID]))):
					return {"combat": true}
				return {}
			if bool(_start_combat.call(String(target[WIKeys.ID]))):
				return {"combat": true}
			return {}
		"door":
			_transition.call(String(target["to_map"]), Vector2i(int(target["to_cell"][0]), int(target["to_cell"][1])))
			if target.has("on_enter_accomplishment"):
				_record_accomplishment.call(String(target["on_enter_accomplishment"]), 1)
			return {"map": String(_current_map.call())}
		_:
			_emit(WIEvents.INTERACT_UNHANDLED, {"kind": String(target[WIKeys.KIND]), "id": String(target[WIKeys.ID])})
			return {}


func _interact_container(target: Dictionary, container_state: Dictionary) -> Dictionary:
	var id := String(target[WIKeys.ID])
	if bool(container_state.get(id, false)):
		_emit(WIEvents.TOAST, {"text": "Empty."})
		return {"container": id, "empty": true}
	var granted: Array[String] = []
	for raw: Variant in target["contains"]:
		var item_id := String(raw)
		if bool(_pickup.call(item_id, id)):
			granted.append(item_id)
	container_state[id] = true
	if target.has("on_open_accomplishment"):
		_record_accomplishment.call(String(target["on_open_accomplishment"]), 1)
	return {"container": id, "items": granted}


func _door_gate_met(door_when: Dictionary) -> bool:
	return bool(_accomplishment_gate_met.call(door_when.get("requires", {}) as Dictionary))


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
