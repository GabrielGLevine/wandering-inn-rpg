class_name WICombatAI
extends RefCounted
## Role-profile AI. Pure static functions over a WICombat; deterministic:
## every choice is sorted (targets: hp asc then id; step directions in the
## fixed order RIGHT, LEFT, UP, DOWN choosing the first that most reduces
## Chebyshev distance).

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


## Data-driven AI-targeting exclusion: true iff `id` currently holds ANY
## status carrying `untargetable: true` -- never a skill-id or status-name
## check, so any future status reusing the flag (not just invisibility's
## `invisible`) is excluded for free with zero new AI code.
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
	# [Invisibility]'s AI-exclusion contract: a foe holding an
	# `untargetable`-flagged status (today only invisibility's `invisible`,
	# see skill_effects.gd's `_resolve_invisibility`) can never be PICKED as a
	# target by any single-target act path below. Filtered here, once, before
	# profile dispatch -- an invisible sole foe makes `foes` empty, which
	# already falls through to `return false` exactly like "no living enemy
	# at all" (this turn does nothing, same as today's empty-foes case).
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


## Calibration profile: a PC-style caster who leads with spells but does
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


## Issue #82's WINDUP SIM SPEC: the melee profile's ONE new arm -- if the
## combatant holds a `windup_rounds`-carrying skill, this is a cadence round
## for it (`combat.round_number % windup_cadence == 0`), it's ADJACENT to a
## foe (every shipped windup skill has `effect.range == 1`, so this reuses the
## exact same adjacency check the plain-attack loop below already makes,
## rather than a separate range/LoS lookahead), and it can afford the cost:
## DECLARE, taking priority over the plain attack/power_strike branch below.
## No re-declare guard is needed: `_start_turn` always resolves (and erases)
## any pending windup before the AI ever gets a turn, and every shipped
## windup skill's `ap_cost` fully drains the turn's AP in one declare, so a
## second `_act_once` pass this same turn fails the affordability check here
## and falls through to the plain-attack branch (which then also fails on 0
## AP) -- the existing AP economy is what "ends the action" for free.
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


## Issue #83 gap-analysis: "skirmisher" -- a hit-and-run melee fighter. Attacks
## exactly like the melee profile (same adjacency/afford checks, same target
## priority -- foes is already hp-asc/id sorted) for as long as it still has
## AP for another swing, then spends any leftover move_pool RETREATING from
## the nearest foe instead of standing in melee range, which is what the
## plain melee profile does by omission today. STATELESS "already attacked"
## signal: `can_attack` (AP >= ATTACK_COST) is recomputed fresh every
## `_act_once` call from CURRENT ap alone, no new combatant field -- a fresh
## turn (AP == MAX_AP) always tries to close and swing first, and only falls
## into retreat once genuinely out of attacks for the turn (0 or 1 AP left).
## No power_strike branch: kept to the literal "attack" verb the spec names,
## so a skirmisher never burns its whole turn on one 3-AP skill and skips the
## retreat leg entirely.
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


## Spends one MOVE_COST step directly away from the nearest living foe (ties
## resolved by `_nearest`'s own deterministic rule). Shared by the skirmisher
## profile's post-attack disengage and (indirectly, via its own extra rally
## fallback) the coward profile's flee branch below. Returns false with no
## side effect when the pool is empty or no step increases distance
## (cornered/already maximally far) -- `take_turn`'s guard-bounded loop then
## ends the turn, same as every other "nothing useful left to do" case here.
static func _retreat_from_nearest(combat: WICombat, id: String, c: Dictionary, foes: Array) -> bool:
	if int(c[WIKeys.MOVE_POOL]) < WICombat.MOVE_COST:
		return false
	return _step(combat, id, _nearest(combat, id, foes), false)


## Nearest of `ids` (a list of living combatant ids, never empty when called)
## to `id`, by Chebyshev distance. Ties keep whichever appears EARLIEST in
## `ids` -- every caller passes an already hp-asc/id-sorted list
## (`alive_enemies_of`/`alive_allies_of`'s own convention), so a tie resolves
## the same deterministic way every other target-priority pick in this file
## already does, never a fresh comparator of its own.
static func _nearest(combat: WICombat, id: String, ids: Array) -> String:
	var best := String(ids[0])
	var best_dist := combat.chebyshev(id, best)
	for other: String in ids:
		var d := combat.chebyshev(id, other)
		if d < best_dist:
			best_dist = d
			best = other
	return best


## Issue #83 gap-analysis: "guard" -- protects its lowest-HP living ally by
## body-blocking adjacency. When no FOE is adjacent to it, its
## movement GOAL is its ward's cell (`alive_allies_of`'s own hp-asc sort picks
## the ward) rather than the nearest/weakest ENEMY the melee profile chases --
## it plants itself beside whoever on its side is hurt worst instead of
## rushing the fight. Once a foe IS adjacent (drawn in by its positioning, or
## closing on its own), it fights exactly like melee (same power_strike/
## attack branch, verbatim). No windup arm -- today's only windup holder
## (vault_construct) stays plain melee; a future guard-profile windup holder
## would need this arm ported over explicitly, not inherited for free.
## Degrades to melee's own goal (chase foes[0]) when it has no living ally to
## guard -- a solo guard is just a fighter.
## Issue #90 support_skill arm: BEFORE the melee logic below, a guard
## holding a known, affordable heal-type skill checks its ward (`alive_
## allies_of`'s own hp-asc sort, the SAME "whoever's hurt worst" pick the
## movement goal below already uses) -- if that ward is missing HP, cast on
## them instead of fighting this action. Priority over engaging a foe: a
## guard's whole identity is protecting its side, so covering support comes
## first when it's available and useful, the same precedence "guard the
## ward" already has over "chase the nearest enemy" in the movement branch
## below. `mana_shield` is deliberately NOT part of this arm -- it has no
## resolver (skill_effects.gd's own header comment: reactions can't be
## actively cast), so a support-profile holder that knows it already
## benefits passively, no selection needed.
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
			if (c[WIKeys.SKILLS] as Array).has("power_strike") and int(c[WIKeys.AP]) >= 3:
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


## Issue #83 gap-analysis: "coward" -- flees once wounded rather than fighting
## to the death. At or above COWARD_FLEE_THRESHOLD of max_hp, behaves EXACTLY
## like the melee profile (reused verbatim, including its windup arm --
## "coward" is melee with one extra low-HP branch, not a separate fighter).
## Below the threshold it NEVER attacks: first it spends its move retreating
## from the nearest foe (`_retreat_from_nearest`, the skirmisher's own helper
## -- same "step directly away" rule); once that stops improving distance
## (cornered, or already maximally far) it rallies toward its nearest living
## ally instead of standing frozen, "regroup with the group" rather than
## "guard's" hp-need-based ward pick -- the two profiles deliberately use
## DIFFERENT ally-selection heuristics (proximity here, need there).
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
	# Skill selection skips anything currently unaffordable (AP or MP) [D]:
	# a caster out of mana falls back to cheaper spells or repositioning
	# instead of stalling on a cast that use_skill would refuse.
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
		# Issue #90 area_skill arm: icy_floor/blast_damage, tracked in its own
		# slot (never competes with spell_id -- a caster holding both a
		# single-target spell and an area skill can genuinely use either,
		# unlike line_id/spell_id which are mutually exclusive per skill).
		elif (effect_type == "icy_floor" or effect_type == "blast_damage") and area_id == "":
			area_id = sk
	if line_id != "" and _act_line(combat, id, c, line_id):
		return true
	if area_id != "" and _act_area(combat, id, c, area_id, foes):
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


## The first known skill carrying `effect.windup_rounds > 0`, or "" if `c`
## holds none. Every OTHER profile (ranged/caster/inert) ignores this --
## windup is a melee-profile-only arm today (the one shipped holder,
## `vault_construct`, is melee).
static func _windup_skill_id(combat: WICombat, c: Dictionary) -> String:
	for sk: String in (c[WIKeys.SKILLS] as Array):
		var s: Dictionary = combat.skills.get(sk, {})
		if int((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.WINDUP_ROUNDS, 0)) > 0:
			return sk
	return ""


## Issue #90: the first known, affordable heal-type skill, or "" if `c`
## holds none -- `_windup_skill_id`'s own "first known skill of a shape"
## pattern, reused verbatim. Guard-profile-only today (`_act_guard`'s new
## support_skill arm); every other profile ignores this.
static func _support_skill(combat: WICombat, c: Dictionary) -> String:
	for sk: String in (c[WIKeys.SKILLS] as Array):
		var s: Dictionary = combat.skills.get(sk, {})
		if String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, "")) == "heal" and _can_afford(combat, c, s):
			return sk
	return ""


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
			elif not _is_untargetable(combat, other_id):
				# An untargetable (invisible) occupant does not COUNT toward
				# the multi-hit gate -- canon ruling: area effects don't
				# respect invisibility, so if the line is cast anyway (via
				# other qualifying occupants) `WISkillEffects._resolve_line_
				# damage` still hits every occupied cell unconditionally,
				# invisible or not. This branch only affects whether the AI
				# CHOOSES to cast, never what the resolver actually hits.
				enemies_hit += 1
		if enemies_hit >= 2 and not hits_ally:
			return combat.use_skill(line_id, String(token_by_dir[dir]))
	return false


## Issue #90 area_skill arm: the icy_floor/blast_damage twin of `_act_line`
## above -- same >=2-living-enemies-hit-and-zero-allies-hit gate, same
## untargetable-exclusion-from-the-COUNT contract (an invisible occupant
## never counts toward the threshold, but the resolver still hits it
## unconditionally if the cast goes through via other qualifying
## occupants), reused VERBATIM rather than a parallel rule. The one real
## difference from `_act_line`: area skills target a CANDIDATE ENEMY id
## (the existing icy_floor/flame_pillar targeting mode -- no new UI/target
## concept), not a cardinal direction, so this walks `foes` (already
## hp-asc/id sorted, already untargetable-filtered by `_act_once`) instead
## of DIRS, deriving the blast off each candidate's own cell via
## `WISkillEffects._radius_area` -- the SAME area-derivation icy_floor/
## blast_damage/windup declare all already share, called verbatim, never
## re-implemented here.
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
