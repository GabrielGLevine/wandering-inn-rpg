class_name WICombatAI
extends RefCounted
## Role-profile AI. Pure static functions over a WICombat; deterministic:
## every choice is sorted (targets: hp asc then id; step directions in the
## fixed order RIGHT, LEFT, UP, DOWN choosing the first that most reduces
## Chebyshev distance).

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


static func take_turn(combat: WICombat) -> void:
	var id := combat.get_active()
	var guard := 0
	while not combat.finished and combat.get_active() == id and guard < 24:
		guard += 1
		if not _act_once(combat, id):
			break
	if not combat.finished and combat.get_active() == id:
		combat.end_turn()


## "inert" (onboarding rev, task O1): a combatant with no reason to act (the
## training dummies -- no block mechanics exist, so standing still is
## correct, not a bug). Returns false on the FIRST call every turn, so
## `take_turn`'s loop immediately falls through to `end_turn()` -- never
## moves, never attacks, never calls `use_skill`/`attack`/`move_active`/
## `dash` at all. Distinct from a "ranged"/"caster" fall-through returning
## false (those still try, then give up); "inert" never tries.
static func _act_once(combat: WICombat, id: String) -> bool:
	var c: Dictionary = combat.combatants[id]
	var profile := String(c.get(WIKeys.AI, ""))
	if profile == "":
		profile = "melee"
	var foes: Array = combat.alive_enemies_of(id)
	if foes.is_empty():
		return false
	match profile:
		"ranged":
			return _act_ranged(combat, id, c, foes)
		"caster":
			return _act_caster(combat, id, c, foes)
		"inert":
			return false
		_:
			return _act_melee(combat, id, c, foes)


## M6 T0 calibration profile: a PC-style caster who leads with spells but does
## NOT stall when mana-dry. `_act_ranged` returns false when no spell is
## castable/approachable this action; the caster then falls through to melee
## (close and stab) so a mana-exhausted mage keeps fighting — which is how a
## human plays the mage kit with a melee weapon, and the only way the balance
## harness measures a caster build's ACTIVE spell contribution (the melee
## profile the harness fielded before never cast, so the mage build's whole
## win-rate edge read as passive [Mana Shield]; spec §2.4 dual-kit confound).
static func _act_caster(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	if _act_ranged(combat, id, c, foes):
		return true
	return _act_melee(combat, id, c, foes)


static func _act_melee(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	for foe: String in foes:
		if combat.is_adjacent(id, foe):
			if (c[WIKeys.SKILLS] as Array).has("power_strike") and int(c[WIKeys.AP]) >= 3:
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


static func _act_ranged(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	# Skill selection skips anything currently unaffordable (AP or MP) [D]:
	# a caster out of mana falls back to cheaper spells or repositioning
	# instead of stalling on a cast that use_skill would refuse.
	var line_id := ""
	var spell_id := ""
	for sk: String in c[WIKeys.SKILLS]:
		var s: Dictionary = combat.skills.get(sk, {})
		if not _can_afford(combat, c, s):
			continue
		var effect_type := String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, ""))
		if effect_type == "line_damage" and line_id == "":
			line_id = sk
		elif effect_type == "spell_damage" and spell_id == "":
			spell_id = sk
	if line_id != "" and _act_line(combat, id, c, line_id):
		return true
	# LoS-filter ranged spell candidates: never pick/cast a target with no LoS.
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


## Affordability for AI skill selection: AP (quick_cast-discounted) and MP.
static func _can_afford(combat: WICombat, c: Dictionary, s: Dictionary) -> bool:
	if int(c[WIKeys.AP]) < combat.effective_ap_cost(c, s):
		return false
	return int(c.get(WIKeys.MP, 0)) >= int(s.get(WIKeys.MP_COST, 0))


## Line-caster variant: only casts a line direction whose walked cells contain
## at least TWO living enemies and ZERO living allies [D: ally-safety; the
## line's steep MP price is only worth paying for a multi-hit — single targets
## fall through to the cheaper single-target spell]. Tries all four cardinal
## directions in DIRS order and casts the first safe, useful one; otherwise
## falls through to let the caller try other actions.
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
			else:
				enemies_hit += 1
		if enemies_hit >= 2 and not hits_ally:
			return combat.use_skill(line_id, String(token_by_dir[dir]))
	return false


## Dash iff, after dashing, the projected pool-funded steps reach the goal
## (adjacency for melee, stop_range for ranged) AND the remaining AP still
## covers the intended action cost. Purely a lookahead — spends nothing.
static func _should_dash(combat: WICombat, c: Dictionary, goal: Vector2i, stop_range: int, action_cost: int) -> bool:
	if int(c[WIKeys.AP]) < WICombat.DASH_COST + action_cost:
		return false
	var projected_pool := int(c[WIKeys.MOVE_POOL]) + WICombat.DASH_GAIN
	var dist := maxi(absi((c[WIKeys.CELL] as Vector2i - goal).x), absi((c[WIKeys.CELL] as Vector2i - goal).y))
	var reachable := _path_len(combat, c[WIKeys.CELL], goal, stop_range)
	if reachable < 0:
		return false
	return reachable <= projected_pool


## Steps one cell toward (or away from) the target; returns false if no step improves.
## Only ever called with toward=false (kiting) now that approach uses _path_step.
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


## Returns the first step of a shortest path from `from` to any free cell
## within `stop_range` (Chebyshev) of `goal`. Deterministic: BFS expands in
## DIRS order. Returns Vector2i.ZERO when already in range or unreachable.
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


## Returns the shortest step count from `from` to any free cell within
## `stop_range` (Chebyshev) of `goal`, or -1 if unreachable. 0 means already
## in range. Used by dash lookahead — never moves anything.
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
