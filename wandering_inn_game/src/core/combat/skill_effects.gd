class_name WISkillEffects
extends RefCounted

const _DIR_TOKENS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}


static func resolve_active(combat: WICombat, actor_id: String, target_id: String, skill: Dictionary) -> bool:
	# Passive effects deliberately return false here; callers resolve them outside the active-effect registry.
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var a: Dictionary = combat.combatants[actor_id]
	var effect_type := String(effect.get(WIKeys.TYPE, ""))
	if effect_type == "line_damage":
		return _resolve_line_damage(combat, actor_id, a, target_id, skill, effect)
	# TRAP: AP_COST>0 gate is load-bearing — generalizing to every move_pool_bonus
	# skill turns the two turn-start passives into a free repeatable pool exploit
	# (0 AP, no re-press gate). Passives fall through and refuse; test_sim_core g18 pins.
	if effect_type == "move_pool_bonus" and int(skill.get(WIKeys.AP_COST, 0)) > 0:
		return _resolve_move_pool_bonus(combat, actor_id, a, skill, effect)
	if effect_type == "invisibility":
		return _resolve_invisibility(combat, actor_id, a, skill, effect)
	var t: Dictionary = combat.combatants.get(target_id, {})
	if t.is_empty() or not t.get(WIKeys.ALIVE, false):
		return false
	var same_side := String(t[WIKeys.SIDE]) == String(a[WIKeys.SIDE])
	if effect_type == "heal":
		if not same_side:
			return false
	elif same_side:
		return false
	match effect_type:
		"heal":
			return _resolve_heal(combat, actor_id, a, target_id, skill, effect)
		"damage_mult":
			if not combat.in_weapon_range(actor_id, target_id):
				return false
			combat.spend_skill_costs(a, skill)
			combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id})
			# `applies` rider (GH#165 [Blinding Arrow]): status lands only on a
			# damaging hit, the spell_damage arm's contract. Skills with no
			# `applies` no-op here -- damage_mult stays byte-identical for them.
			var dm_hp_before := int(combat.combatants[target_id][WIKeys.HP])
			combat._resolve_hit(actor_id, target_id, float(effect[WIKeys.MULT]), true, true)
			if int(combat.combatants.get(target_id, {}).get(WIKeys.HP, dm_hp_before)) < dm_hp_before:
				_apply_status_from_effect(combat, target_id, effect)
			return true
		"spell_damage":
			if combat.chebyshev(actor_id, target_id) > int(effect[WIKeys.RANGE]):
				return false
			if not combat.has_los(actor_id, target_id):
				combat._emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "no_los", "target": target_id})
				return false
			combat.spend_skill_costs(a, skill)
			combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id})
			var hp_before := int(combat.combatants[target_id][WIKeys.HP])
			combat._resolve_hit(actor_id, target_id, 1.0, false, false)
			if int(combat.combatants.get(target_id, {}).get(WIKeys.HP, hp_before)) < hp_before:
				_apply_status_from_effect(combat, target_id, effect)
			return true
		"icy_floor":
			return _resolve_icy_floor(combat, actor_id, a, target_id, skill, effect)
		"blast_damage":
			return _resolve_blast_damage(combat, actor_id, a, target_id, skill, effect)
	return false


static func _resolve_move_pool_bonus(combat: WICombat, actor_id: String, a: Dictionary, skill: Dictionary, effect: Dictionary) -> bool:
	combat.spend_skill_costs(a, skill)
	a[WIKeys.MOVE_POOL] = int(a[WIKeys.MOVE_POOL]) + int(effect.get(WIKeys.AMOUNT, 0))
	combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": actor_id})
	return true


static func _resolve_invisibility(combat: WICombat, actor_id: String, a: Dictionary, skill: Dictionary, effect: Dictionary) -> bool:
	combat.spend_skill_costs(a, skill)
	combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": actor_id})
	var expires_after := combat.round_number + int(effect.get(WIKeys.DURATION_ROUNDS, 0)) - 1
	var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
	var statuses: Dictionary = a["statuses"]
	for status_id: String in applies:
		var entry: Dictionary = (applies[status_id] as Dictionary).duplicate(true)
		entry["expires_after_round"] = expires_after
		statuses[status_id] = entry
		combat._emit(WIEvents.STATUS_APPLIED, {"id": actor_id, "status": status_id})
	return true


static func _resolve_heal(combat: WICombat, actor_id: String, a: Dictionary, target_id: String, skill: Dictionary, effect: Dictionary) -> bool:
	if target_id != actor_id and not bool(effect.get("ally_target", false)):
		return false
	var target: Dictionary = combat.combatants[target_id]
	combat.spend_skill_costs(a, skill)
	var missing := int(target[WIKeys.MAX_HP]) - int(target[WIKeys.HP])
	var healed := clampi(int(effect.get(WIKeys.AMOUNT, 0)), 0, missing)
	target[WIKeys.HP] = int(target[WIKeys.HP]) + healed
	combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id, "healed": healed})
	_apply_status_from_effect(combat, target_id, effect)
	return true


static func _resolve_line_damage(combat: WICombat, actor_id: String, a: Dictionary, target_id: String, skill: Dictionary, effect: Dictionary) -> bool:
	if not _DIR_TOKENS.has(target_id):
		return false
	var dir: Vector2i = _DIR_TOKENS[target_id]
	var cast_cell: Vector2i = a[WIKeys.CELL]
	var first_cell := cast_cell + dir
	if first_cell.x < 0 or first_cell.y < 0 or first_cell.x >= combat.grid_size.x or first_cell.y >= combat.grid_size.y or combat.blocked.has(first_cell):
		combat._emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "no_los", "target": target_id})
		return false
	var cells: Array[Vector2i] = combat.line_cells(cast_cell, dir, int(effect.get(WIKeys.LENGTH, 1)))
	combat.spend_skill_costs(a, skill)
	var hit_ids: Array = []
	for id: String in combat.combatants:
		if not bool(combat.combatants[id][WIKeys.ALIVE]):
			continue
		if (combat.combatants[id][WIKeys.CELL] as Vector2i) in cells:
			hit_ids.append(id)
	hit_ids.sort()
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		cells_payload.append([cell.x, cell.y])
	combat._emit(WIEvents.SKILL_RESOLVED, {
		"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id,
		"cells": cells_payload, "hit_ids": hit_ids,
	})
	for id: String in hit_ids:
		if not bool(combat.combatants[id][WIKeys.ALIVE]):
			continue  # an earlier hit in this same line may have already downed them
		combat._resolve_hit(actor_id, id, 1.0, false, false)
		if combat.finished:
			return true
	return true


static func _resolve_icy_floor(combat: WICombat, actor_id: String, a: Dictionary, target_id: String, skill: Dictionary, effect: Dictionary) -> bool:
	if combat.chebyshev(actor_id, target_id) > int(effect[WIKeys.RANGE]):
		return false
	if not combat.has_los(actor_id, target_id):
		combat._emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "no_los", "target": target_id})
		return false
	combat.spend_skill_costs(a, skill)
	var center: Vector2i = combat.combatants[target_id][WIKeys.CELL]
	var cells := _radius_area(combat, center, int(effect.get(WIKeys.RADIUS, 0)))
	var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
	var expires_after := combat.round_number + int(effect.get(WIKeys.DURATION_ROUNDS, 0)) - 1
	var occupant_by_cell: Dictionary = {}
	for id: String in combat.combatants:
		var occ: Dictionary = combat.combatants[id]
		if bool(occ.get(WIKeys.ALIVE, false)):
			occupant_by_cell[occ[WIKeys.CELL]] = id
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		combat.terrain[cell] = {"kind": "icy_floor", "expires_after_round": expires_after, "applies": applies.duplicate(true)}
		cells_payload.append([cell.x, cell.y])
	combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id, "cells": cells_payload})
	combat._emit(WIEvents.TERRAIN_ADDED, {"kind": "icy_floor", "cells": cells_payload, "rounds": int(effect.get(WIKeys.DURATION_ROUNDS, 0))})
	for cell: Vector2i in cells:
		if occupant_by_cell.has(cell):
			_apply_status_from_effect(combat, String(occupant_by_cell[cell]), effect)
	return true


static func _resolve_blast_damage(combat: WICombat, actor_id: String, a: Dictionary, target_id: String, skill: Dictionary, effect: Dictionary) -> bool:
	if combat.chebyshev(actor_id, target_id) > int(effect[WIKeys.RANGE]):
		return false
	if not combat.has_los(actor_id, target_id):
		combat._emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "no_los", "target": target_id})
		return false
	combat.spend_skill_costs(a, skill)
	var center: Vector2i = combat.combatants[target_id][WIKeys.CELL]
	var cells := _radius_area(combat, center, int(effect.get(WIKeys.RADIUS, 0)))
	var hit_ids: Array = []
	for id: String in combat.combatants:
		if not bool(combat.combatants[id][WIKeys.ALIVE]):
			continue
		if (combat.combatants[id][WIKeys.CELL] as Vector2i) in cells:
			hit_ids.append(id)
	hit_ids.sort()
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		cells_payload.append([cell.x, cell.y])
	combat._emit(WIEvents.SKILL_RESOLVED, {
		"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id,
		"cells": cells_payload, "hit_ids": hit_ids,
	})
	for id: String in hit_ids:
		if not bool(combat.combatants[id][WIKeys.ALIVE]):
			continue  # an earlier hit in this same blast may have already downed them
		combat._resolve_hit(actor_id, id, 1.0, false, false)
		if combat.finished:
			return true
	return true


## WALL-SHAPE CONTRACT (icy_floor + blast_damage share this): flat Chebyshev
## radius clip, NOT shadow-casting — blocked cells excluded, cells BEYOND a wall
## get no occlusion check. Indistinguishable at shipped radius 1; any radius>1
## skill must decide occlusion or the two area effects drift silently.
static func _radius_area(combat: WICombat, center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= combat.grid_size.x or cell.y >= combat.grid_size.y:
				continue
			if combat.blocked.has(cell):
				continue
			cells.append(cell)
	cells.sort_custom(WICombat._cell_less_than)
	return cells


static func declare_windup(combat: WICombat, actor_id: String, target_id: String, skill: Dictionary) -> bool:
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var a: Dictionary = combat.combatants[actor_id]
	var t: Dictionary = combat.combatants.get(target_id, {})
	if t.is_empty() or not bool(t.get(WIKeys.ALIVE, false)) or String(t[WIKeys.SIDE]) == String(a[WIKeys.SIDE]):
		return false
	if combat.chebyshev(actor_id, target_id) > int(effect.get(WIKeys.RANGE, 0)):
		return false
	if not combat.has_los(actor_id, target_id):
		combat._emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "no_los", "target": target_id})
		return false
	combat.spend_skill_costs(a, skill)
	var center: Vector2i = combat.combatants[target_id][WIKeys.CELL]
	var cells := _radius_area(combat, center, int(effect.get(WIKeys.RADIUS, 0)))
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		cells_payload.append([cell.x, cell.y])
	combat.windups[actor_id] = {"skill_id": String(skill[WIKeys.ID]), "cells": cells}
	combat._emit(WIEvents.WINDUP_DECLARED, {"id": actor_id, "skill": String(skill[WIKeys.ID]), "cells": cells_payload})
	return true


static func _apply_status_from_effect(combat: WICombat, target_id: String, effect: Dictionary) -> void:
	var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
	if applies.is_empty():
		return
	var t: Dictionary = combat.combatants.get(target_id, {})
	if t.is_empty() or not bool(t.get(WIKeys.ALIVE, false)):
		return
	for status_id: String in applies:
		var entry: Dictionary = (applies[status_id] as Dictionary).duplicate(true)
		if entry.has(WIKeys.DURATION_ROUNDS):
			entry["expires_after_round"] = combat.round_number + int(entry[WIKeys.DURATION_ROUNDS]) - 1
		(t["statuses"] as Dictionary)[status_id] = entry
		combat._emit(WIEvents.STATUS_APPLIED, {"id": target_id, "status": status_id})
