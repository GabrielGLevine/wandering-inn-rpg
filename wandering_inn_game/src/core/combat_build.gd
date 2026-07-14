class_name WICombatBuild
extends RefCounted


static func weapon_gated_kit(kit: Array, weapon_family: String, skills_by_id: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in kit:
		var sk_id := String(raw)
		var rec: Dictionary = skills_by_id.get(sk_id, {})
		if not rec.has(WIKeys.WEAPON) or String(rec[WIKeys.WEAPON]) == weapon_family:
			out.append(sk_id)
	return out


static func equipment_mods(weapon: Dictionary, armor: Dictionary, accessories: Array) -> Dictionary:
	var dmg_mod := int(weapon.get(WIKeys.DAMAGE_MOD, 0))
	var hp_mod := int(armor.get(WIKeys.HP_MOD, 0))
	var dmg_reduction := int(armor.get(WIKeys.DAMAGE_REDUCTION, 0))
	for acc: Dictionary in accessories:
		dmg_mod += int(acc.get(WIKeys.DAMAGE_MOD, 0))
		hp_mod += int(acc.get(WIKeys.HP_MOD, 0))
		dmg_reduction += int(acc.get(WIKeys.DAMAGE_REDUCTION, 0))
	return {WIKeys.DAMAGE_MOD: dmg_mod, WIKeys.HP_MOD: hp_mod, WIKeys.DAMAGE_REDUCTION: dmg_reduction}


static func fold_abilities(kit: Array, accessories: Array) -> Array:
	var out: Array = kit.duplicate()
	for acc: Dictionary in accessories:
		for raw: Variant in (acc.get(WIKeys.ABILITIES, []) as Array):
			var ability_id := String(raw)
			if not out.has(ability_id):
				out.append(ability_id)
	return out
