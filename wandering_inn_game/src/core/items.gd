class_name WIItems
extends RefCounted

const FLAT_AP_COST := 1
const MAX_COUNT := 2147483647


static func stackable(item: Dictionary) -> bool:
	return item.get("stackable", false) == true


static func valid_count(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= 1 and number <= MAX_COUNT


static func legacy_counts(inventory: Array, catalog: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for id: Variant in inventory:
		if stackable(catalog.get(String(id), {})):
			counts[String(id)] = 1
	return counts


static func valid_counts(inventory: Array, counts: Variant, catalog: Dictionary) -> bool:
	if not (counts is Dictionary):
		return false
	var seen: Dictionary = {}
	for id: Variant in inventory:
		if not (id is String) or seen.has(id):
			return false
		seen[id] = true
		if stackable(catalog.get(id, {})) and not valid_count(counts.get(id)):
			return false
	for id: Variant in counts:
		if not (id is String) or not seen.has(id) or not stackable(catalog.get(id, {})) or not valid_count(counts[id]):
			return false
	return true


static func resolve_use(item: Dictionary, combat: WICombat) -> Dictionary:
	var effect: Dictionary = item.get(WIKeys.USE_EFFECT, {})
	if effect.has("heal"):
		return _resolve_heal_use(item, combat, effect)
	if effect.has("next_fight"):
		return _resolve_meal_use(combat, effect)
	return {"ok": false}


static func _resolve_heal_use(item: Dictionary, combat: WICombat, effect: Dictionary) -> Dictionary:
	if combat == null or combat.finished:
		return {"ok": false}
	var actor_id := combat.get_active()
	if not bool(combat.combatants.get(actor_id, {}).get(WIKeys.ALIVE, false)):
		return {"ok": false}
	var a: Dictionary = combat.combatants[actor_id]
	if int(a.get(WIKeys.AP, 0)) < FLAT_AP_COST:
		return {"ok": false}
	var synthetic_skill := {
		WIKeys.ID: String(item.get(WIKeys.ID, "")),
		WIKeys.AP_COST: FLAT_AP_COST,
		WIKeys.MP_COST: 0,
		WIKeys.EFFECT: {WIKeys.TYPE: "heal", WIKeys.AMOUNT: int(effect["heal"])},
	}
	var before := int(a[WIKeys.HP])
	if not WISkillEffects.resolve_active(combat, actor_id, actor_id, synthetic_skill):
		return {"ok": false}
	var healed := int(combat.combatants[actor_id][WIKeys.HP]) - before
	return {"ok": true, "healed": healed}


static func _resolve_meal_use(combat: WICombat, effect: Dictionary) -> Dictionary:
	if combat != null:
		return {"ok": false}
	return {"ok": true, "pending_meal": (effect["next_fight"] as Dictionary).duplicate(true)}
