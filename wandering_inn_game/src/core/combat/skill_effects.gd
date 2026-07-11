class_name WISkillEffects
extends RefCounted
## Registry of active combat skill-effect resolvers, keyed by effect type.
## Pure: operates only on the passed-in WICombat. Passives (hp_bonus,
## hit_bonus) are applied at combatant build inside WICombat; reactions
## (riposte, ap_on_kill, mana_shield) live at WICombat's resolution hooks and
## quick_cast at its cost hooks — their effect types deliberately have no
## resolver here, so resolve_active returns false for them (they cannot be
## actively cast). This registry covers effects a combatant actively spends
## AP/MP on; all spends go through WICombat.spend_skill_costs.

## Cardinal direction tokens accepted by line_damage's target_id (line skills
## target a direction, not a combatant [D]).
const _DIR_TOKENS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}


static func resolve_active(combat: WICombat, actor_id: String, target_id: String, skill: Dictionary) -> bool:
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var a: Dictionary = combat.combatants[actor_id]
	var effect_type := String(effect.get(WIKeys.TYPE, ""))
	if effect_type == "line_damage":
		return _resolve_line_damage(combat, actor_id, a, target_id, skill, effect)
	# move_pool_bonus is a
	# SELF-targeted grant, dispatched early exactly like line_damage above --
	# neither needs the enemy-side gate just below (which would reject a
	# self/no-target cast outright). Gated on `ap_cost > 0` so this ONLY
	# fires for an actively-cast skill (today, only [Stealth]): the two
	# PRE-EXISTING 0-cost move_pool_bonus skills (quick_movement,
	# battlefield_awareness) are labeled passives with no resolver in THIS
	# dispatch table (wi_combat.gd's _start_turn grants their bonus as a real
	# turn-start passive -- see _move_pool_bonus_total).
	# TRAP: generalizing this dispatch to
	# EVERY move_pool_bonus skill regardless of cost would silently turn
	# those two into a free, repeatable-every-turn pool exploit (0 AP, no
	# gate stops a re-press), which nothing asked for. This narrower gate
	# wires only the genuine active cast; the two passives fall through
	# unchanged to the enemy-gated match below, find no case, and keep
	# refusing exactly as `test_sim_core.gd`'s g18 block already pins.
	if effect_type == "move_pool_bonus" and int(skill.get(WIKeys.AP_COST, 0)) > 0:
		return _resolve_move_pool_bonus(combat, actor_id, a, skill, effect)
	# [Invisibility]'s combat read: another SELF-targeted
	# grant, dispatched early exactly like move_pool_bonus above -- a self-cast
	# status has no enemy/adjacency/LoS concept either. See _resolve_invisibility's
	# own doc comment for the untargetable-flag contract.
	if effect_type == "invisibility":
		return _resolve_invisibility(combat, actor_id, a, skill, effect)
	var t: Dictionary = combat.combatants.get(target_id, {})
	if t.is_empty() or not t.get(WIKeys.ALIVE, false):
		return false
	# The same-side gate below is
	# now TYPE-keyed, never skill-name-keyed (the exact drift-seam class
	# effect_text.gd's own DRIFT SEAM comment warns about, applied here to the
	# dispatch gate instead of the card text). Every effect type reaching this
	# point requires a DIFFERENT side (an enemy) except "heal", which requires
	# the SAME side (an ally/self) BY DESIGN -- a future skill that reuses the
	# "heal" type inherits this exemption for free; a future skill reusing any
	# other type stays enemy-gated for free.
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
			if not combat.is_adjacent(actor_id, target_id):
				return false
			combat.spend_skill_costs(a, skill)
			combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": target_id})
			combat._resolve_hit(actor_id, target_id, float(effect[WIKeys.MULT]), true, true)
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
	return false


## The sneak combat read. Spends the skill's cost (1 AP,
## no MP), then adds `effect.amount` (2) straight to the ACTOR's own
## `move_pool` -- the exact field `dash()` mutates, so the pool is spent via
## the same `move_active`/MOVE_COST path afterward, no separate currency. No
## enemy, no adjacency, no LoS -- a self-buff has none of those concepts.
## Emits SKILL_RESOLVED with `target` = the actor's own id (there is no other
## target to report; combat_hud/QA read this the same way a no-target field
## skill's `target: ""` reads elsewhere, just non-empty here since the
## targeting_controller self-target reuse -- see that file's `enter()` --
## always resolves `target_id` to the actor).
static func _resolve_move_pool_bonus(combat: WICombat, actor_id: String, a: Dictionary, skill: Dictionary, effect: Dictionary) -> bool:
	combat.spend_skill_costs(a, skill)
	a[WIKeys.MOVE_POOL] = int(a[WIKeys.MOVE_POOL]) + int(effect.get(WIKeys.AMOUNT, 0))
	combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": actor_id})
	return true


## [Invisibility]'s combat read (controller canon ruling): applies every
## status in `effect.applies` (today just `invisible: {untargetable: true}`)
## onto the ACTOR's OWN statuses, stamping each entry's `expires_after_round`
## from `effect.duration_rounds` -- the icy_floor terrain idiom (`combat.
## round_number + duration_rounds - 1`), reused here per-COMBATANT instead of
## per-cell; `WICombat._purge_expired_statuses` is the generic round-rollover
## consumer (mirrors `_purge_expired_terrain`). `untargetable` is the ONLY key
## any consumer reads: combat_ai.gd's foe-filter and `_act_line`'s enemies_hit
## gate, and wi_combat.gd's break-on-damage in `_resolve_hit` -- none key on
## this skill's id or the `invisible` status name, so a future status reusing
## the flag gets the same AI-exclusion/break-on-damage for free. No enemy, no
## adjacency, no LoS -- a self-buff has none of those concepts (mirrors
## _resolve_move_pool_bonus exactly).
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


## second_wind's real heal resolver. `target_id` has already cleared
## resolve_active's type-keyed same-side gate above (heal requires the SAME
## side), but this is SELF-ONLY tonight -- ally-targeting would need
## targeting_controller.gd to grow an ally-cycling filter arm beyond the
## small self-target addition this task shipped (see that file's `enter()`
## doc comment), so the shipped card is honestly "restore N HP to yourself"
## (effect_text.gd) and the sim enforces exactly that here: a same-side
## target that ISN'T the actor itself (a living ally) still refuses. Widen
## this gate and the card together when ally-targeting lands -- never one
## without the other. Restores `effect.amount` HP capped at max_hp (a
## fully-topped-off actor can still spend the cost for zero net healing,
## same as dash() never refusing for "already fast enough" -- no existing
## skill in this sim gates an active cast on "would this even help").
static func _resolve_heal(combat: WICombat, actor_id: String, a: Dictionary, target_id: String, skill: Dictionary, effect: Dictionary) -> bool:
	if target_id != actor_id:
		return false
	combat.spend_skill_costs(a, skill)
	var missing := int(a[WIKeys.MAX_HP]) - int(a[WIKeys.HP])
	var healed := clampi(int(effect.get(WIKeys.AMOUNT, 0)), 0, missing)
	a[WIKeys.HP] = int(a[WIKeys.HP]) + healed
	combat._emit(WIEvents.SKILL_RESOLVED, {"actor": actor_id, "skill": String(skill[WIKeys.ID]), "target": actor_id, "healed": healed})
	return true


## Flame Jet et al.: target_id is a cardinal direction TOKEN ("up"/"down"/
## "left"/"right" [D]), not a combatant id. LoS gates the CAST — caster's
## cell to the line's first cell must be clear of walls — then the line
## walks all `length` cells regardless of occupancy [per spec: the jet burns
## down the corridor]; walls still clip the walked line itself via
## `line_cells`. Every occupant of the walked cells gets hit regardless of
## side [D: friendly fire is real] with no riposte eligibility (melee=false,
## allow_riposte=false, matching spell_damage's no-riposte contract).
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


## Area terrain resolver. Gates BEFORE spend, mirroring
## spell_damage exactly (range then LoS -- a refused cast costs neither AP
## nor MP): `target_id` must already be a living ENEMY (the same-side gate
## in `resolve_active`, above, enforces that before this is ever reached).
## No damage, no rng consumption anywhere in this path (seed safety) -- the
## area is pure Chebyshev-radius geometry around the TARGET's cell (not the
## caster's), clipped to grid bounds and excluding `blocked` cells (walls
## don't glaze); occupied cells are included, and the caster's OWN cell can
## land in the area when targeting an adjacent foe [D: friendly fire is
## real, deliberate]. Registers every area cell into `combat.terrain`
## (flat refresh on re-cast -- overwriting the same Vector2i key, matching
## `_apply_status_from_effect`'s status idiom), emits SKILL_RESOLVED then
## TERRAIN_ADDED, then applies the effect's `applies` statuses to every
## LIVING occupant of the area regardless of side (reusing
## `_apply_status_from_effect` per occupant, iterated in the same sorted-
## cell order as the emitted payloads for determinism).
static func _resolve_icy_floor(combat: WICombat, actor_id: String, a: Dictionary, target_id: String, skill: Dictionary, effect: Dictionary) -> bool:
	if combat.chebyshev(actor_id, target_id) > int(effect[WIKeys.RANGE]):
		return false
	if not combat.has_los(actor_id, target_id):
		combat._emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "no_los", "target": target_id})
		return false
	combat.spend_skill_costs(a, skill)
	var center: Vector2i = combat.combatants[target_id][WIKeys.CELL]
	var cells := _icy_floor_area(combat, center, int(effect.get(WIKeys.RADIUS, 0)))
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


## The icy_floor blast area: every cell within Chebyshev `radius` of `center`
## (the TARGET's cell), clipped to grid bounds, excluding `blocked` cells.
## Sorted x-then-y for determinism (SKILL_RESOLVED's cells, TERRAIN_ADDED's
## cells, and the terrain dict's iteration order all trace back to this).
static func _icy_floor_area(combat: WICombat, center: Vector2i, radius: int) -> Array[Vector2i]:
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


## Applies a post-hit status from a skill's "applies" dict (e.g. frost_bolt's
## slowed) onto the victim's statuses. Only fires when the hit actually
## landed and the victim is still alive; emits status_applied per status.
static func _apply_status_from_effect(combat: WICombat, target_id: String, effect: Dictionary) -> void:
	var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
	if applies.is_empty():
		return
	var t: Dictionary = combat.combatants.get(target_id, {})
	if t.is_empty() or not bool(t.get(WIKeys.ALIVE, false)):
		return
	for status_id: String in applies:
		# Flat refresh, not a stack: a second application of the same status_id
		# overwrites the dict entry in place, so re-slowing an already-slowed
		# victim still yields exactly one status entry/penalty/expiry.
		(t["statuses"] as Dictionary)[status_id] = (applies[status_id] as Dictionary).duplicate(true)
		combat._emit(WIEvents.STATUS_APPLIED, {"id": target_id, "status": status_id})
