class_name WICombatAI
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


static func _is_untargetable(combat: WICombat, id: String) -> bool:
	var statuses: Dictionary = combat.combatants[id].get("statuses", {})
	for status_id: String in statuses:
		if bool((statuses[status_id] as Dictionary).get("untargetable", false)):
			return true
	return false


static func take_turn(combat: WICombat) -> void:
	var id := combat.get_active()
	var guard := 0
	while not combat.finished and combat.get_active() == id and guard < 24:
		guard += 1
		if not _act_once(combat, id):
			break
	if not combat.finished and combat.get_active() == id:
		combat.end_turn()


static func _act_once(combat: WICombat, id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	var profile := String(c.get(WIKeys.AI, ""))
	if profile == "":
		profile = "melee"
	var foes: Array = combat.alive_enemies_of(id).filter(
		func(foe: String) -> bool: return not _is_untargetable(combat, foe)
	)
	if foes.is_empty():
		return false
	match profile:
		"ranged":
			return _act_ranged(combat, id, c, foes)
		"caster":
			return _act_caster(combat, id, c, foes)
		"inert":
			return false
		"skirmisher":
			return _act_skirmisher(combat, id, c, foes)
		"guard":
			return _act_guard(combat, id, c, foes)
		"coward":
			return _act_coward(combat, id, c, foes)
		_:
			return _act_melee(combat, id, c, foes)


static func _act_caster(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	if _act_ranged(combat, id, c, foes):
		return true
	return _act_melee(combat, id, c, foes)


static func _act_melee(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var windup_id := _windup_skill_id(combat, c)
	if windup_id != "":
		var skill: Dictionary = combat.skills[windup_id]
		var cadence := int(skill.get(WIKeys.WINDUP_CADENCE, 3))
		if cadence > 0 and combat.round_number % cadence == 0 and _can_afford(combat, c, skill):
			for foe: String in foes:
				if combat.is_adjacent(id, foe):
					return combat.use_skill(windup_id, foe)
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if _power_strike_ready(combat, id, c):
				return combat.use_skill("power_strike", foe)
			if int(c[WIKeys.AP]) >= WICombat.ATTACK_COST:
				return combat.attack(foe)
			return false
	var goal: Vector2i = combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := _path_step(combat, c[WIKeys.CELL], goal, 1)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if _should_dash(combat, c, goal, 1, WICombat.ATTACK_COST):
		return combat.dash()
	return false


## GH#337 spec ruling 2: `_act_melee` and `_act_guard` are the two places that
## hardcode power_strike behind a RAW `AP >= 3` test rather than going through
## `_can_afford`, so they need the availability term spliced in explicitly. The
## shape is deliberately a plain `if` and NOT a `return false`: a cooling
## power_strike must FALL THROUGH to the basic attack on the very next line --
## the whole point of doing the AI work before any skill carries a cooldown.
static func _power_strike_ready(combat: WICombat, id: String, c: Dictionary) -> bool:
	return (c[WIKeys.SKILLS] as Array).has("power_strike") \
			and int(c[WIKeys.AP]) >= 3 \
			and combat.skill_available(id, "power_strike")


static func _act_skirmisher(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var can_attack := int(c[WIKeys.AP]) >= WICombat.ATTACK_COST
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if can_attack:
				return combat.attack(foe)
			return _retreat_from_nearest(combat, id, c, foes)
	if not can_attack:
		return _retreat_from_nearest(combat, id, c, foes)
	var goal: Vector2i = combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := _path_step(combat, c[WIKeys.CELL], goal, 1)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if _should_dash(combat, c, goal, 1, WICombat.ATTACK_COST):
		return combat.dash()
	return false


static func _retreat_from_nearest(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	if int(c[WIKeys.MOVE_POOL]) < WICombat.MOVE_COST:
		return false
	return _step(combat, id, _nearest(combat, id, foes), false)


static func _nearest(combat: WICombat, id: String, ids: Array) -> String:
	var best := String(ids[0])
	var best_dist := combat.chebyshev(id, best)
	for other: String in ids:
		var d := combat.chebyshev(id, other)
		if d < best_dist:
			best_dist = d
			best = other
	return best


static func _act_guard(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var support_id := _support_skill(combat, c)
	if support_id != "":
		var support_allies := combat.alive_allies_of(id)
		if not support_allies.is_empty():
			var ward := String(support_allies[0])
			if int(combat.combatants[ward][WIKeys.HP]) < int(combat.combatants[ward][WIKeys.MAX_HP]):
				return combat.use_skill(support_id, ward)
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if _power_strike_ready(combat, id, c):
				return combat.use_skill("power_strike", foe)
			if int(c[WIKeys.AP]) >= WICombat.ATTACK_COST:
				return combat.attack(foe)
			return false
	var allies := combat.alive_allies_of(id)
	var goal: Vector2i = combat.combatants[String(allies[0])][WIKeys.CELL] if not allies.is_empty() \
			else combat.combatants[String(foes[0])][WIKeys.CELL]
	if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
		var dir := _path_step(combat, c[WIKeys.CELL], goal, 1)
		if dir == Vector2i.ZERO:
			return false
		return combat.move_active(dir)
	if _should_dash(combat, c, goal, 1, WICombat.ATTACK_COST):
		return combat.dash()
	return false


const COWARD_FLEE_THRESHOLD := 0.3

static func _act_coward(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var max_hp := maxf(1.0, float(c[WIKeys.MAX_HP]))
	if float(c[WIKeys.HP]) / max_hp >= COWARD_FLEE_THRESHOLD:
		return _act_melee(combat, id, c, foes)
	if _retreat_from_nearest(combat, id, c, foes):
		return true
	if int(c[WIKeys.MOVE_POOL]) < WICombat.MOVE_COST:
		return false
	var allies := combat.alive_allies_of(id)
	if allies.is_empty():
		return false
	var ally := _nearest(combat, id, allies)
	var dir := _path_step(combat, c[WIKeys.CELL], combat.combatants[ally][WIKeys.CELL], 1)
	if dir == Vector2i.ZERO:
		return false
	return combat.move_active(dir)


static func _act_ranged(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	var line_id := ""
	var spell_id := ""
	var area_id := ""
	for sk: String in c[WIKeys.SKILLS]:
		var s: Dictionary = combat.skills.get(sk, {})
		if not _can_afford(combat, c, s):
			continue
		var effect_type := String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, ""))
		if effect_type == "line_damage" and line_id == "":
			line_id = sk
		elif effect_type == "spell_damage" and spell_id == "":
			spell_id = sk
		elif (effect_type == "icy_floor" or effect_type == "blast_damage") and area_id == "":
			area_id = sk
	if line_id != "" and _act_line(combat, id, c, line_id):
		return true
	if area_id != "" and _act_area(combat, id, c, area_id, foes):
		return true
	var los_foes: Array = []
	for foe: String in foes:
		if combat.has_los(id, foe):
			los_foes.append(foe)
	if los_foes.is_empty():
		return false
	var target := String(los_foes[0])
	if spell_id != "":
		var s: Dictionary = combat.skills[spell_id]
		var spell_range := int(s[WIKeys.EFFECT][WIKeys.RANGE])
		var in_range := combat.chebyshev(id, target) <= spell_range
		if in_range and _can_afford(combat, c, s):
			if combat.is_adjacent(id, target) and int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
				if _step(combat, id, target, false):
					return true
			return combat.use_skill(spell_id, target)
		if not in_range:
			var goal: Vector2i = combat.combatants[target][WIKeys.CELL]
			if int(c[WIKeys.MOVE_POOL]) >= WICombat.MOVE_COST:
				var dir := _path_step(combat, c[WIKeys.CELL], goal, spell_range)
				if dir == Vector2i.ZERO:
					return false
				return combat.move_active(dir)
			if _should_dash(combat, c, goal, spell_range, combat.effective_ap_cost(c, s)):
				return combat.dash()
	return false


static func _windup_skill_id(combat: WICombat, c: Dictionary) -> String:
	for sk: String in (c[WIKeys.SKILLS] as Array):
		var s: Dictionary = combat.skills.get(sk, {})
		if int((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.WINDUP_ROUNDS, 0)) > 0:
			return sk
	return ""


static func _support_skill(combat: WICombat, c: Dictionary) -> String:
	for sk: String in (c[WIKeys.SKILLS] as Array):
		var s: Dictionary = combat.skills.get(sk, {})
		if String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, "")) == "heal" and _can_afford(combat, c, s):
			return sk
	return ""


## GH#337 spec ruling 2, and it lands FIRST for a reason proven by probe:
## `take_turn` breaks on the FIRST refused action, so a skill that refuses
## mid-scan costs its holder the WHOLE turn (flagging power_strike unavailable
## cost the goblin chieftain 16 damage and 4 unspent AP). Availability therefore
## has to be part of what "can afford" MEANS, not a separate refusal the AI
## discovers by being told no -- every arm that already filters on this function
## (`_act_ranged`'s line/spell/area scan, `_support_skill`, `_act_melee`'s windup
## cadence) now falls through to its own next option for free.
static func _can_afford(combat: WICombat, c: Dictionary, s: Dictionary) -> bool:
	if int(c[WIKeys.AP]) < combat.effective_ap_cost(c, s):
		return false
	if int(c.get(WIKeys.MP, 0)) < int(s.get(WIKeys.MP_COST, 0)):
		return false
	return combat.skill_available(String(c[WIKeys.ID]), String(s.get(WIKeys.ID, "")))


static func _act_line(combat: WICombat, id: String, c: Dictionary, line_id: String) -> bool:
	var s: Dictionary = combat.skills[line_id]
	if not _can_afford(combat, c, s):
		return false
	var length := int(s[WIKeys.EFFECT][WIKeys.LENGTH])
	var side := String(c[WIKeys.SIDE])
	var token_by_dir := {
		Vector2i.UP: "up", Vector2i.DOWN: "down", Vector2i.LEFT: "left", Vector2i.RIGHT: "right",
	}
	for dir: Vector2i in DIRS:
		var cells: Array[Vector2i] = combat.line_cells(c[WIKeys.CELL], dir, length)
		if cells.is_empty():
			continue
		var enemies_hit := 0
		var hits_ally := false
		for other_id: String in combat.combatants:
			var other: Dictionary = combat.combatants[other_id]
			if not bool(other[WIKeys.ALIVE]) or other_id == id:
				continue
			if not ((other[WIKeys.CELL] as Vector2i) in cells):
				continue
			if String(other[WIKeys.SIDE]) == side:
				hits_ally = true
			elif not _is_untargetable(combat, other_id):
				enemies_hit += 1
		if enemies_hit >= 2 and not hits_ally:
			return combat.use_skill(line_id, String(token_by_dir[dir]))
	return false


static func _act_area(combat: WICombat, id: String, c: Dictionary, area_id: String, foes: Array) -> bool:
	var s: Dictionary = combat.skills[area_id]
	if not _can_afford(combat, c, s):
		return false
	var effect: Dictionary = s.get(WIKeys.EFFECT, {})
	var range_val := int(effect.get(WIKeys.RANGE, 0))
	var side := String(c[WIKeys.SIDE])
	for foe: String in foes:
		if combat.chebyshev(id, foe) > range_val:
			continue
		if not combat.has_los(id, foe):
			continue
		var center: Vector2i = combat.combatants[foe][WIKeys.CELL]
		var cells := WISkillEffects._radius_area(combat, center, int(effect.get(WIKeys.RADIUS, 0)))
		var enemies_hit := 0
		var hits_ally := false
		for other_id: String in combat.combatants:
			if other_id == id:
				continue
			var other: Dictionary = combat.combatants[other_id]
			if not bool(other[WIKeys.ALIVE]):
				continue
			if not ((other[WIKeys.CELL] as Vector2i) in cells):
				continue
			if String(other[WIKeys.SIDE]) == side:
				hits_ally = true
			elif not _is_untargetable(combat, other_id):
				enemies_hit += 1
		if enemies_hit >= 2 and not hits_ally:
			return combat.use_skill(area_id, foe)
	return false


static func _should_dash(combat: WICombat, c: Dictionary, goal: Vector2i, stop_range: int, action_cost: int) -> bool:
	if int(c[WIKeys.AP]) < WICombat.DASH_COST + action_cost:
		return false
	var projected_pool := int(c[WIKeys.MOVE_POOL]) + WICombat.DASH_GAIN
	var dist := maxi(absi((c[WIKeys.CELL] as Vector2i - goal).x), absi((c[WIKeys.CELL] as Vector2i - goal).y))
	var reachable := _path_len(combat, c[WIKeys.CELL], goal, stop_range)
	if reachable < 0:
		return false
	return reachable <= projected_pool


static func _step(combat: WICombat, id: String, target_id: String, toward: bool) -> bool:
	var from: Vector2i = combat.combatants[id][WIKeys.CELL]
	var goal: Vector2i = combat.combatants[target_id][WIKeys.CELL]
	var current := maxi(absi((from - goal).x), absi((from - goal).y))
	var best_dir := Vector2i.ZERO
	var best := current
	for dir: Vector2i in DIRS:
		var cell := from + dir
		if not combat.is_cell_free(cell):
			continue
		var d := maxi(absi((cell - goal).x), absi((cell - goal).y))
		if (toward and d < best) or (not toward and d > best):
			best = d
			best_dir = dir
	if best_dir == Vector2i.ZERO:
		return false
	return combat.move_active(best_dir)


static func _path_step(combat: WICombat, from: Vector2i, goal: Vector2i, stop_range: int) -> Vector2i:
	if maxi(absi((from - goal).x), absi((from - goal).y)) <= stop_range:
		return Vector2i.ZERO
	var queue: Array[Vector2i] = [from]
	var came_from := {from: from}
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir: Vector2i in DIRS:
			var next: Vector2i = cur + dir
			if came_from.has(next) or not combat.is_cell_free(next):
				continue
			came_from[next] = cur
			if maxi(absi((next - goal).x), absi((next - goal).y)) <= stop_range:
				var step: Vector2i = next
				while came_from[step] != from:
					step = came_from[step]
				return step - from
			queue.append(next)
	return Vector2i.ZERO


static func _path_len(combat: WICombat, from: Vector2i, goal: Vector2i, stop_range: int) -> int:
	if maxi(absi((from - goal).x), absi((from - goal).y)) <= stop_range:
		return 0
	var queue: Array[Vector2i] = [from]
	var dist := {from: 0}
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir: Vector2i in DIRS:
			var next: Vector2i = cur + dir
			if dist.has(next) or not combat.is_cell_free(next):
				continue
			dist[next] = int(dist[cur]) + 1
			if maxi(absi((next - goal).x), absi((next - goal).y)) <= stop_range:
				return int(dist[next])
			queue.append(next)
	return -1
