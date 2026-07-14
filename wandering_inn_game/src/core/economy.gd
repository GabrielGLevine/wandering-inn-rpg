class_name WIEconomy
extends RefCounted

var _event_sink: Callable
var _pickup: Callable
var _set_gold: Callable


func _init(event_sink: Callable, pickup_cb: Callable, set_gold_cb: Callable) -> void:
	_event_sink = event_sink
	_pickup = pickup_cb
	_set_gold = set_gold_cb


func earn(gold: int, amount: int, source: String) -> int:
	if amount <= 0:
		return gold
	var new_gold := gold + amount
	_set_gold.call(new_gold)
	_emit(WIEvents.GOLD_CHANGED, {"delta": amount, "total": new_gold, "source": source})
	_emit(WIEvents.TOAST, {"text": "Earned %d gold." % amount})
	return new_gold


func spend(gold: int, amount: int, source: String) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "gold": gold}
	if gold < amount:
		_emit(WIEvents.TOAST, {"text": "Not enough gold."})
		return {"ok": false, "gold": gold}
	var new_gold := gold - amount
	_set_gold.call(new_gold)
	_emit(WIEvents.GOLD_CHANGED, {"delta": -amount, "total": new_gold, "source": source})
	_emit(WIEvents.TOAST, {"text": "Paid %d gold." % amount})
	return {"ok": true, "gold": new_gold}


func apply_gold_effect(gold: int, amount: int, source: String) -> int:
	if amount > 0:
		return earn(gold, amount, source)
	elif amount < 0:
		var result := spend(gold, -amount, source)
		return int(result["gold"])
	return gold


func roll_loot(gold: int, run_seed: int, entity: Dictionary) -> int:
	# Loot uses its own run-seed/entity-id stream; never consume combat or world RNG.
	var loot_table: Array = entity.get("loot", [])
	if loot_table.is_empty():
		return gold
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = hash("%d:%s" % [run_seed, String(entity.get(WIKeys.ID, ""))])
	var dropped: Array[String] = []
	var gold_dropped := 0
	for drop: Dictionary in loot_table:
		var chance := float(drop.get("chance", 0.0))
		if drop.has("gold"):
			if loot_rng.randf() < chance:
				gold_dropped += int(drop["gold"])
			continue
		var item_id := String(drop["item"])
		if loot_rng.randf() < chance:
			dropped.append(item_id)
	if dropped.is_empty() and gold_dropped <= 0:
		return gold
	var payload: Dictionary = {}
	if not dropped.is_empty():
		payload["items"] = dropped.duplicate()
	if gold_dropped > 0:
		payload["gold"] = gold_dropped
	_emit(WIEvents.LOOT_DROPPED, payload)
	for item_id: String in dropped:
		_pickup.call(item_id, String(entity.get(WIKeys.ID, "")))
	var new_gold := gold
	if gold_dropped > 0:
		new_gold = earn(gold, gold_dropped, String(entity.get(WIKeys.ID, "")))
	return new_gold


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
