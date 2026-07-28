class_name WISocial
extends RefCounted

var _event_sink: Callable
var _accomplishment_count: Callable
var _record_accomplishment: Callable
var _find_entity: Callable


func _init(event_sink: Callable, accomplishment_count_cb: Callable, record_accomplishment_cb: Callable, find_entity_cb: Callable) -> void:
	_event_sink = event_sink
	_accomplishment_count = accomplishment_count_cb
	_record_accomplishment = record_accomplishment_cb
	_find_entity = find_entity_cb


## `repeat` = the pool is already spent this waking and the NPC has no authored
## `dialogue` fallback: re-serve the SAME current line and bank NOTHING (a
## second bank would rotate the pool mid-waking and inflate heard_gossip).
func talk_pool_line(target: Dictionary, social_talked: Dictionary, repeat: bool = false) -> Dictionary:
	var id := String(target[WIKeys.ID])
	var pool: Array = target["talk_pool"]
	for stage: Dictionary in target.get("talk_pool_stages", []):
		if _accomplishment_gate_met(stage.get("requires_accomplishment", {})):
			pool = stage["lines"]
	var counter_key := "chatted_with_%s" % id
	var idx := int(_accomplishment_count.call(counter_key)) % pool.size()
	if repeat:
		# Step BACK one, wrapping: the first talk already banked, so `idx` points
		# at the NEXT line. A bare `idx - 1` re-served index 0 on every size-th
		# chat (idx == 0 wraps to size - 1, not to itself).
		idx = (idx + pool.size() - 1) % pool.size()
	var speaker := String(target.get(WIKeys.DISPLAY_NAME, id))
	_emit(WIEvents.DIALOGUE_LINE, {"speaker": speaker, "text": _resolve_pool_line(pool[idx])})
	if repeat:
		return {"talked": id, "index": idx, "repeat": true}
	_record_accomplishment.call(counter_key, 1)
	_record_accomplishment.call("heard_gossip", 1)
	social_talked[id] = true
	return {"talked": id, "index": idx}


func _resolve_pool_line(raw: Variant) -> String:
	if not (raw is Dictionary):
		return String(raw)
	var echo_id := String((raw as Dictionary)["echo_of"])
	var echo_target: Dictionary = _find_entity.call(echo_id)
	if echo_target.is_empty() or not echo_target.has("talk_pool"):
		return ""
	var echo_pool: Array = echo_target["talk_pool"]
	for stage: Dictionary in echo_target.get("talk_pool_stages", []):
		if _accomplishment_gate_met(stage.get("requires_accomplishment", {})):
			echo_pool = stage["lines"]
	var echo_idx := int(_accomplishment_count.call("chatted_with_%s" % echo_id)) % echo_pool.size()
	return String(echo_pool[echo_idx])


func _accomplishment_gate_met(req: Dictionary) -> bool:
	for key: String in req:
		if int(_accomplishment_count.call(key)) < int(req[key]):
			return false
	return true


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
