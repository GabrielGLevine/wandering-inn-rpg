class_name WIEconomy
extends RefCounted
## Gold state transitions + loot rolls, extracted from wi_game.gd.
## PURITY RULE: no autoload/Node/scene-tree references. `gold` itself stays
## owned by WIGame (save.gd reads/writes `game.gold` directly and is banned
## from this task's diff) -- every method here takes the CURRENT gold as a
## parameter and returns the new value; WIGame's thin wrappers reassign its
## own field. Cross-cutting calls (inventory's `pickup`) are constructor-
## injected Callables, the same idiom as the event-sink injection below.

var _event_sink: Callable
## Callable(item_id: String, source_id: String) -> bool, forwards to
## WIGame.pickup -- inventory ownership is out of this task's scope.
var _pickup: Callable
## Callable(new_gold: int) -> void, forwards to WIGame's field BEFORE the
## synchronous GOLD_CHANGED emit (field-first, required: the emit's
## consumers read Game.sim.gold directly in the same frame -- inventory.gd's
## _refresh_gold -- so the field must already hold the new total when the
## event fires; the _set_light_active precedent, same contract).
var _set_gold: Callable


func _init(event_sink: Callable, pickup_cb: Callable, set_gold_cb: Callable) -> void:
	_event_sink = event_sink
	_pickup = pickup_cb
	_set_gold = set_gold_cb


## Adds `amount` coins and emits `gold_changed {delta, total, source}` + the
## diegetic "Earned N gold." toast. A non-positive amount is a silent no-op
## (returns `gold` unchanged, emits nothing).
func earn(gold: int, amount: int, source: String) -> int:
	if amount <= 0:
		return gold
	var new_gold := gold + amount
	_set_gold.call(new_gold)
	_emit(WIEvents.GOLD_CHANGED, {"delta": amount, "total": new_gold, "source": source})
	_emit(WIEvents.TOAST, {"text": "Earned %d gold." % amount})
	return new_gold


## Removes `amount` coins IF the purse can cover it, emitting `gold_changed
## {delta:-amount, total, source}` + the "Paid N gold." toast. REFUSES when
## short (no debt): emits "Not enough gold.", no `gold_changed`. A
## non-positive amount is a silent refusal. Returns `{ok: bool, gold: int}`.
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


## The single `gold: +/-N` effect-verb router shared by dialogue effects and
## chore/serve prop effects: positive earns, negative spends (refusal-safe),
## zero is a no-op. Returns the new gold value.
func apply_gold_effect(gold: int, amount: int, source: String) -> int:
	if amount > 0:
		return earn(gold, amount, source)
	elif amount < 0:
		var result := spend(gold, -amount, source)
		return int(result["gold"])
	return gold


## Rolls an encounter's `loot: [{item, chance}]` / `{gold, chance}` table on
## victory. Uses a BRAND NEW RandomNumberGenerator seeded from
## hash(run_seed, encounter_id) -- NEVER the live sim/combat stream -- so a
## post-victory loot draw can never shift any other fight's trajectory, and a
## canonical multi-fight seed stays byte-identical whether or not a drop
## rolls. Deterministic per (run seed, encounter id) pair. A no-op for an
## entity with no `loot` field or an empty table. Emits `loot_dropped {items,
## gold}` once for the whole table (if anything dropped) BEFORE granting
## items (their own "Got: <name>" toasts) and earning coin (its own "Earned
## N gold." toast) -- `combat_screen.gd` times this after the victory
## banner's confirm press, so any toast queues to render only once the
## banner is already gone. Returns the new gold value.
func roll_loot(gold: int, run_seed: int, entity: Dictionary) -> int:
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
