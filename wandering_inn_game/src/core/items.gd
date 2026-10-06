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
	if combat == null or not combat.combatants.has("pc"):
		return {"ok": false}
	var pc: Dictionary = combat.combatants["pc"]
	var recovery_item := item.duplicate(true)
	recovery_item.usable_in_combat = true
	recovery_item.use_effect.restore_hp = int(effect.get("restore_hp", effect.get("heal", 0)))
	var plan := preview_use(recovery_item, {"context": "combat", "context_valid": true,
		"count": 1, "exposure": 0, "ap": pc[WIKeys.AP], "alive": pc[WIKeys.ALIVE],
		"finished": combat.finished, "player_turn": combat.get_active() == "pc",
		"preparation": {"armed": {}}, "resources": {"hp": pc[WIKeys.HP], "mp": pc[WIKeys.MP],
			"max_hp": pc[WIKeys.MAX_HP], "max_mp": pc[WIKeys.MAX_MP]}}, {})
	if not bool(plan.allowed):
		return {"ok": false}
	var synthetic_skill := {WIKeys.ID: String(item.get(WIKeys.ID, "")), WIKeys.AP_COST: plan.ap_cost,
		WIKeys.MP_COST: 0, WIKeys.EFFECT: {WIKeys.TYPE: "heal", WIKeys.AMOUNT: plan.restore_hp}}
	if not WISkillEffects.resolve_active(combat, "pc", "pc", synthetic_skill):
		return {"ok": false}
	return {"ok": true, "healed": plan.restore_hp}


static func _resolve_meal_use(combat: WICombat, effect: Dictionary) -> Dictionary:
	if combat != null:
		return {"ok": false}
	return {"ok": true, "pending_meal": (effect["next_fight"] as Dictionary).duplicate(true)}


static func preview_use(item: Dictionary, context: Dictionary, rules: Dictionary) -> Dictionary:
	var before: Dictionary = context.get("resources", {}).duplicate(true)
	var preparation: Dictionary = context.get("preparation", {}).duplicate(true)
	var in_combat := String(context.get("context", "")) == "combat"
	var count := int(context.get("count", 0))
	var exposure := int(context.get("exposure", 0))
	var ap := int(context.get("ap", 0))
	var plan := {"item": String(item.get("id", "")), "context": context.get("context", "world"),
		"source": String(item.get("id", "")), "allowed": false, "reason": "", "confirmation_required": false,
		"before": before, "after": before.duplicate(true), "preparation_before": preparation.duplicate(true),
		"preparation": preparation, "count_before": count, "count_after": count,
		"ap_before": ap, "ap_after": ap, "ap_cost": 0, "exposure_before": exposure, "exposure_after": exposure,
		"dose_number": 0, "restore_hp": 0, "restore_mp": 0, "poison_hp": 0, "hp_lost": 0}
	if item.is_empty() or count <= 0:
		return _refused(plan, "missing_stock")
	if not bool(context.get("context_valid", false)):
		return _refused(plan, "wrong_context")
	if not bool(context.get("alive", true)) or int(before.get("hp", 0)) <= 0:
		return _refused(plan, "not_alive")
	if in_combat:
		if bool(context.get("finished", false)):
			return _refused(plan, "finished_combat")
		if not bool(context.get("player_turn", false)):
			return _refused(plan, "wrong_actor")
		if not bool(item.get("usable_in_combat", false)) or String(item.get("consumable_family", "")) == "food":
			return _refused(plan, "not_combat_usable")
		plan.ap_cost = int(rules.get("combat_ap_cost", 1))
		if ap < int(plan.ap_cost):
			return _refused(plan, "insufficient_ap")
	var effect: Dictionary = item.get("use_effect", {})
	plan.restore_hp = mini(maxi(0, int(effect.get("restore_hp", 0))), maxi(0, int(before.get("max_hp", 0)) - int(before.get("hp", 0))))
	plan.restore_mp = mini(maxi(0, int(effect.get("restore_mp", 0))), maxi(0, int(before.get("max_mp", 0)) - int(before.get("mp", 0))))
	var armed: Dictionary = preparation.get("armed", {}).duplicate(true)
	if not in_combat:
		for key: String in effect.get("next_fight", {}):
			armed[key] = maxi(int(armed.get(key, 0)), int(effect.next_fight[key]))
	var prep_benefit: bool = armed != preparation.get("armed", {})
	if int(plan.restore_hp) == 0 and int(plan.restore_mp) == 0 and not prep_benefit:
		return _refused(plan, "no_benefit")
	plan.preparation.armed = armed
	plan.after.hp = int(before.hp) + int(plan.restore_hp)
	plan.after.mp = int(before.mp) + int(plan.restore_mp)
	if String(item.get("consumable_family", "")) == "mp_potion":
		if exposure >= MAX_COUNT:
			return _refused(plan, "exposure_limit")
		plan.dose_number = exposure + 1
		plan.exposure_after = exposure + 1
		var safe := int(rules.get("safe_mp_doses", 3))
		if exposure >= safe:
			plan.poison_hp = int(rules.get("poison_hp", 4))
			plan.hp_lost = mini(int(plan.after.hp), int(plan.poison_hp))
			plan.confirmation_required = exposure == safe
			if not in_combat and int(plan.after.hp) <= int(plan.poison_hp):
				return _refused(plan, "lethal_world_poison")
			plan.after.hp = maxi(0, int(plan.after.hp) - int(plan.poison_hp))
	plan.after.mp_potion_doses = plan.exposure_after
	plan.ap_after = ap - int(plan.ap_cost)
	plan.count_after = count - 1
	plan.allowed = true
	return plan


static func preview_service(effect: Dictionary, resources: Dictionary, preparation: Dictionary, rules: Dictionary) -> Dictionary:
	var projected := resources.duplicate(true)
	var prepared := preparation.duplicate(true)
	if bool(effect.get("well_fed", false)) and not bool(prepared.get("well_fed", false)):
		projected.max_hp = int(projected.max_hp) + 2
		prepared.well_fed = true
	var plan := preview_use({"id": "inn_meal", "use_effect": effect}, {
		"context": "world", "context_valid": true, "count": 1,
		"resources": projected, "preparation": prepared,
		"exposure": resources.get("mp_potion_doses", 0)}, rules)
	plan.before = resources.duplicate(true)
	plan.preparation_before = preparation.duplicate(true)
	return plan


static func _refused(plan: Dictionary, reason: String) -> Dictionary:
	plan.allowed = false
	plan.reason = reason
	return plan


static func valid_pending_loot(entries: Variant, catalog: Dictionary) -> bool:
	if not (entries is Array):
		return false
	for entry: Variant in entries:
		if not (entry is Dictionary) or not (entry.get("item") is String) or not (entry.get("source") is String):
			return false
		if not stackable(catalog.get(entry.item, {})) or not valid_count(entry.get("count")) or int(entry.count) != 1:
			return false
	return true
