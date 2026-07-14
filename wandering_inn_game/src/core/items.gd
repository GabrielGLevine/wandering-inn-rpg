class_name WIItems
extends RefCounted

const FLAT_AP_COST := 1


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
