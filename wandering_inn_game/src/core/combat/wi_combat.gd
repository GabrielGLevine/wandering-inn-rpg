class_name WICombat
extends RefCounted

const MAX_AP := 4
const MOVE_COST := 1
const ATTACK_COST := 2
const BASE_HIT := 85
const ROUND_CAP := 30
const MOVE_POOL := 3
const DASH_COST := 1
const DASH_GAIN := 3
const WEAKENED_MULT := 0.75
const GUARDED_MULT := 0.75

## GH#337 skill cooldowns. The skills.json field name lives HERE rather than in
## `WIKeys` because it is a combat-only knob with exactly three readers (this
## file, `combat_hud.gd`'s slot record, `WIEffectText`'s clause) -- the same
## call every other combat-local key already makes ("statuses", "hit_bonus",
## "expires_after_round").
##
## SEMANTICS, and they are the whole design: a stamp is ABSOLUTE
## (`round_number + cooldown_rounds`, the terrain/status expiry idiom -- no tick
## loop exists and none is wanted), so `cooldown_rounds: N` means "unavailable
## for N rounds COUNTING the round it was used in". N=1 therefore only forbids a
## second cast inside the SAME turn (meaningful for a cheap skill a 4-AP turn
## could fire twice); N=2 is the real alternation knob -- used on round R, ready
## again on R+2, i.e. exactly one of your own turns skipped. Nothing shipped
## carries N>2.
const COOLDOWN_ROUNDS := "cooldown_rounds"

var grid_size: Vector2i
var blocked: Dictionary = {}
var combatants: Dictionary = {}
var turn_order: Array = []
var active_index: int = 0
var round_number: int = 0
var finished := false
var outcome: Dictionary = {}
var skills: Dictionary = {}
var rng := RandomNumberGenerator.new()
var arena_config: Dictionary = {}
var arena_id := ""
var action_tally: Dictionary = {}
var used_skills_tally: Dictionary = {}
var terrain: Dictionary = {}

## GH#337: actor id -> {skill id -> the round number it becomes usable again}.
## Written ONLY by `spend_skill_costs` (and `_resolve_windup` for the two-beat
## skills, which stamp at RESOLUTION, not declaration) and read ONLY through
## `skill_available`/`cooldown_remaining`. Never purged: an absolute stamp
## simply stops being in the future, so there is nothing to expire. Never
## save-serialized -- `WISave.serialize` carries no `combat` field at all, and a
## fresh `WICombat` per encounter clears the ledger by construction.
var cooldowns: Dictionary = {}

## GH#345 rider (v0.17). L1 owns the settings getter and its semantics
## (`WISettings.difficulty_damage_taken_mult`, whose own doc comment is the
## contract this implements); this lane owns the apply site, and the apply site
## has to live in the sim because the sim is where damage is dealt.
##
## INJECTED, never read: the PURITY RULE forbids this class from touching an
## autoload, so the composition root sets this field once, right after the
## `WICombat` is built and exactly where equipment mods are read. That is also
## the whole "safe mid-save" answer L1's contract asks for -- a player may move
## the row at any time, and because nothing re-reads it mid-fight the change
## lands on the NEXT fight rather than halfway through a live one.
##
## Default 1.0 IS Silver IS the shipped balance, so every balance cell, every
## QA fixture and every test that constructs a WICombat directly stays
## byte-identical by construction.
var difficulty_damage_taken_mult := 1.0

var windups: Dictionary = {}

var _event_sink: Callable
var _momentum_used: Dictionary = {}
var _quick_cast_spent: Dictionary = {}


func _init(arena_cfg: Dictionary, combatant_cfgs: Array, skills_cfg: Dictionary, event_sink: Callable, rng_seed: int) -> void:
	_event_sink = event_sink
	rng.seed = rng_seed
	arena_config = arena_cfg.duplicate(true)
	arena_id = String(arena_cfg.get(WIKeys.ID, ""))
	grid_size = Vector2i(int(arena_cfg["grid"]["width"]), int(arena_cfg["grid"]["height"]))
	for cell: Array in arena_cfg.get("blocked", []):
		blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
	for s: Dictionary in skills_cfg.get(WIKeys.SKILLS, []):
		skills[String(s[WIKeys.ID])] = s
	var spawn_i := {"player": 0, "enemy": 0}
	for cfg: Dictionary in combatant_cfgs:
		var side := String(cfg[WIKeys.SIDE])
		var spawns: Array = arena_cfg["player_spawns"] if side == "player" else arena_cfg["enemy_spawns"]
		var spawn: Array = spawns[spawn_i[side]]
		spawn_i[side] += 1
		var base_id := String(cfg[WIKeys.ID])
		var runtime_id := base_id
		var suffix := 2
		while combatants.has(runtime_id):
			runtime_id = "%s_%d" % [base_id, suffix]
			suffix += 1
		var c := {
			WIKeys.ID: runtime_id,
			WIKeys.TEMPLATE_ID: base_id,
			WIKeys.DISPLAY_NAME: String(cfg[WIKeys.DISPLAY_NAME]),
			WIKeys.SIDE: side,
			WIKeys.CELL: Vector2i(int(spawn[0]), int(spawn[1])),
			WIKeys.STATS: (cfg[WIKeys.STATS] as Dictionary).duplicate(true),
			WIKeys.WEAPON_DIE: int(cfg[WIKeys.WEAPON_DIE]),
			WIKeys.AI: String(cfg.get(WIKeys.AI, "")),
			WIKeys.SKILLS: [],
			"hit_bonus": 0,
			WIKeys.MAX_HP: maxi(20 + int(cfg[WIKeys.STATS]["con"]) + int(cfg.get(WIKeys.HP_MOD, 0)), 1),
			WIKeys.DAMAGE_MOD: int(cfg.get(WIKeys.DAMAGE_MOD, 0)),
			WIKeys.DAMAGE_REDUCTION: int(cfg.get(WIKeys.DAMAGE_REDUCTION, 0)),
			WIKeys.WEAPON_RANGE: int(cfg.get(WIKeys.WEAPON_RANGE, 1)),
			WIKeys.AP: 0,
			WIKeys.MOVE_POOL: 0,
			"statuses": {},
			WIKeys.ALIVE: true,
		}
		for sk: Variant in cfg.get(WIKeys.SKILLS, []):
			c[WIKeys.SKILLS].append(String(sk))
		_apply_passives(c)
		c[WIKeys.HP] = c[WIKeys.MAX_HP]
		c[WIKeys.MAX_MP] = 0
		for sk: String in c[WIKeys.SKILLS]:
			if (skills.get(sk, {}) as Dictionary).has(WIKeys.MP_COST):
				c[WIKeys.MAX_MP] = 8 + int(int(c[WIKeys.STATS]["int"]) / 2)
				break
		c[WIKeys.MP] = c[WIKeys.MAX_MP]
		combatants[c[WIKeys.ID]] = c
	_roll_initiative()


func begin() -> void:
	_emit(WIEvents.COMBAT_STARTED, {"order": turn_order.duplicate(), "arena": arena_id})
	_start_round()
	_start_turn()


func _apply_passives(c: Dictionary) -> void:
	for sk: String in c[WIKeys.SKILLS]:
		var effect: Dictionary = skills.get(sk, {}).get(WIKeys.EFFECT, {})
		match String(effect.get(WIKeys.TYPE, "")):
			"hp_bonus":
				c[WIKeys.MAX_HP] += int(effect[WIKeys.AMOUNT])
			"hit_bonus":
				c["hit_bonus"] += int(effect[WIKeys.AMOUNT])


func _roll_initiative() -> void:
	var entries: Array = []
	var ids := combatants.keys()
	ids.sort()
	for id: String in ids:
		entries.append({"id": id, "init": int(combatants[id][WIKeys.STATS]["dex"]) + rng.randi_range(1, 6)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["init"] != b["init"]:
			return a["init"] > b["init"]
		return String(a[WIKeys.ID]) < String(b[WIKeys.ID]))
	turn_order = entries.map(func(e: Dictionary) -> String: return String(e[WIKeys.ID]))


func get_active() -> String:
	return String(turn_order[active_index])


func is_adjacent(a_id: String, b_id: String) -> bool:
	var d: Vector2i = (combatants[a_id][WIKeys.CELL] as Vector2i) - (combatants[b_id][WIKeys.CELL] as Vector2i)
	return maxi(absi(d.x), absi(d.y)) <= 1


func chebyshev(a_id: String, b_id: String) -> int:
	var d: Vector2i = (combatants[a_id][WIKeys.CELL] as Vector2i) - (combatants[b_id][WIKeys.CELL] as Vector2i)
	return maxi(absi(d.x), absi(d.y))


func in_weapon_range(attacker_id: String, target_id: String) -> bool:
	var weapon_range := int(combatants[attacker_id].get(WIKeys.WEAPON_RANGE, 1))
	if weapon_range <= 1:
		return is_adjacent(attacker_id, target_id)
	return chebyshev(attacker_id, target_id) <= weapon_range and has_los(attacker_id, target_id)


func has_los(a_id: String, b_id: String) -> bool:
	var from: Vector2i = combatants[a_id][WIKeys.CELL]
	var to: Vector2i = combatants[b_id][WIKeys.CELL]
	for cell: Vector2i in _supercover(from, to):
		if cell == from or cell == to:
			continue
		if blocked.has(cell):
			return false
	return true


func _supercover(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	# Integer supercover and tie handling must stay direction-symmetric.
	var cells: Array[Vector2i] = [from]
	var dx := to.x - from.x
	var dy := to.y - from.y
	var nx := absi(dx)
	var ny := absi(dy)
	var sign_x := 1 if dx > 0 else -1
	var sign_y := 1 if dy > 0 else -1
	var x := from.x
	var y := from.y
	var i := 0
	var j := 0
	var max_iters := 2 * (nx + ny) + 4
	var iters := 0
	while i < nx or j < ny:
		iters += 1
		assert(iters <= max_iters, "supercover loop exceeded provable bound (%d) — geometry bug, not valid output" % max_iters)
		var step_x := i < nx
		var step_y := j < ny
		if step_x and step_y:
			var lhs := (2 * i + 1) * ny
			var rhs := (2 * j + 1) * nx
			if lhs == rhs:
				cells.append(Vector2i(x + sign_x, y))
				cells.append(Vector2i(x, y + sign_y))
				x += sign_x
				y += sign_y
				i += 1
				j += 1
				cells.append(Vector2i(x, y))
				continue
			step_x = lhs < rhs
			step_y = not step_x
		if step_x:
			x += sign_x
			i += 1
		else:
			y += sign_y
			j += 1
		cells.append(Vector2i(x, y))
	return cells


func line_cells(from: Vector2i, toward_dir: Vector2i, length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var cur := from
	for i in length:
		cur += toward_dir
		if cur.x < 0 or cur.y < 0 or cur.x >= grid_size.x or cur.y >= grid_size.y:
			break
		cells.append(cur)
		if blocked.has(cur):
			break
	return cells


func alive_enemies_of(id: String) -> Array:
	var side := String(combatants[id][WIKeys.SIDE])
	var out: Array = []
	for other_id: String in combatants:
		var o: Dictionary = combatants[other_id]
		if o[WIKeys.ALIVE] and String(o[WIKeys.SIDE]) != side:
			out.append(other_id)
	out.sort_custom(func(a: String, b: String) -> bool:
		if combatants[a][WIKeys.HP] != combatants[b][WIKeys.HP]:
			return int(combatants[a][WIKeys.HP]) < int(combatants[b][WIKeys.HP])
		return a < b)
	return out


func alive_allies_of(id: String) -> Array:
	var side := String(combatants[id][WIKeys.SIDE])
	var out: Array = []
	for other_id: String in combatants:
		var o: Dictionary = combatants[other_id]
		if other_id != id and o[WIKeys.ALIVE] and String(o[WIKeys.SIDE]) == side:
			out.append(other_id)
	out.sort_custom(func(a: String, b: String) -> bool:
		if combatants[a][WIKeys.HP] != combatants[b][WIKeys.HP]:
			return int(combatants[a][WIKeys.HP]) < int(combatants[b][WIKeys.HP])
		return a < b)
	return out


func is_cell_free(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return false
	if blocked.has(cell):
		return false
	for c: Dictionary in combatants.values():
		if c[WIKeys.ALIVE] and c[WIKeys.CELL] == cell:
			return false
	return true


func move_active(dir: Vector2i) -> bool:
	if finished:
		return false
	if not bool(combatants[get_active()][WIKeys.ALIVE]):
		return false
	var c: Dictionary = combatants[get_active()]
	if int(c[WIKeys.MOVE_POOL]) < MOVE_COST:
		if _is_rooted(get_active()):
			_emit_rooted_refusal(get_active())
		return false
	var target: Vector2i = (c[WIKeys.CELL] as Vector2i) + dir
	if absi(dir.x) + absi(dir.y) != 1 or not is_cell_free(target):
		return false
	c[WIKeys.CELL] = target
	c[WIKeys.MOVE_POOL] = int(c[WIKeys.MOVE_POOL]) - MOVE_COST
	_emit(WIEvents.COMBATANT_MOVED, {"id": c[WIKeys.ID], "cell": [target.x, target.y]})
	_apply_terrain_status(c)
	return true


func _is_rooted(id: String) -> bool:
	return (combatants[id]["statuses"] as Dictionary).has("rooted")


func _emit_rooted_refusal(id: String) -> void:
	_emit(WIEvents.ACTION_REFUSED, {"actor": id, "reason": "rooted"})


func dash() -> bool:
	if finished:
		return false
	if not bool(combatants[get_active()][WIKeys.ALIVE]):
		return false
	if _is_rooted(get_active()):
		_emit_rooted_refusal(get_active())
		return false
	var c: Dictionary = combatants[get_active()]
	if int(c[WIKeys.AP]) < DASH_COST:
		return false
	c[WIKeys.AP] = int(c[WIKeys.AP]) - DASH_COST
	c[WIKeys.MOVE_POOL] = int(c[WIKeys.MOVE_POOL]) + DASH_GAIN
	_emit(WIEvents.DASHED, {"id": c[WIKeys.ID], "move_pool": c[WIKeys.MOVE_POOL]})
	_emit(WIEvents.AP_CHANGED, {"id": c[WIKeys.ID], "ap": c[WIKeys.AP]})
	return true


func attack(target_id: String) -> bool:
	# Spend and emit AP before resolving hit events; playback depends on this order.
	if finished:
		return false
	if not bool(combatants[get_active()][WIKeys.ALIVE]):
		return false
	var attacker_id := get_active()
	var a: Dictionary = combatants[attacker_id]
	var t: Dictionary = combatants.get(target_id, {})
	if t.is_empty() or not t[WIKeys.ALIVE] or String(t[WIKeys.SIDE]) == String(a[WIKeys.SIDE]):
		return false
	if int(a[WIKeys.AP]) < ATTACK_COST or not in_weapon_range(attacker_id, target_id):
		return false
	a[WIKeys.AP] = int(a[WIKeys.AP]) - ATTACK_COST
	_emit(WIEvents.AP_CHANGED, {"id": attacker_id, "ap": a[WIKeys.AP]})
	_resolve_hit(attacker_id, target_id, 1.0, true, true)
	return true


func use_skill(skill_id: String, target_id: String) -> bool:
	if finished:
		return false
	if not bool(combatants[get_active()][WIKeys.ALIVE]):
		return false
	var actor_id := get_active()
	var a: Dictionary = combatants[actor_id]
	if not (a[WIKeys.SKILLS] as Array).has(skill_id):
		return false
	var skill: Dictionary = skills.get(skill_id, {})
	if not (skill.get(WIKeys.CONTEXTS, []) as Array).has("combat"):
		return false
	if skill_spent(actor_id, skill_id):
		return false
	if not skill_available(actor_id, skill_id):
		# Defensive, not a live path: the bar dims a cooling slot
		# (`combat_hud.skill_affordable`) so it can't be pressed, and every AI
		# arm tests `skill_available` before it commits. The refusal rides the
		# shipped ACTION_REFUSED render arm so that IF the gate is ever reached
		# it speaks, rather than silently no-oping -- the exact defect GH#334
		# ruling 14 closed for `once_per_fight`.
		_emit(WIEvents.ACTION_REFUSED, {"actor": actor_id, "reason": "cooldown", "skill": skill_id})
		return false
	if int(a.get(WIKeys.MP, 0)) < int(skill.get(WIKeys.MP_COST, 0)):
		return false
	if int(a[WIKeys.AP]) < effective_ap_cost(a, skill):
		return false
	if int((skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.WINDUP_ROUNDS, 0)) > 0:
		return WISkillEffects.declare_windup(self, actor_id, target_id, skill)
	return WISkillEffects.resolve_active(self, actor_id, target_id, skill)


## GH#334 ruling 14: THE ONE reader of the once-per-fight refusal, shared by the
## sim's own `use_skill` gate above and by the HUD's affordability test through
## `WICombatView.skill_spent`. It used to exist only inside `use_skill`, so the
## bar drew a spent skill exactly as bright as an affordable one and the press
## simply did nothing -- indistinguishable, from the player's seat, from an
## input that had been dropped.
func skill_spent(actor_id: String, skill_id: String) -> bool:
	if not bool((skills.get(skill_id, {}) as Dictionary).get(WIKeys.ONCE_PER_FIGHT, false)):
		return false
	return (used_skills_tally.get(actor_id, {}) as Dictionary).has(skill_id)


## GH#337: THE cooldown predicate, and the only one. `use_skill`'s own gate,
## `WICombatAI._can_afford` (plus the two hardcoded power_strike arms), and the
## HUD's `skill_affordable` all route through it, so the bar, the enemy AI and
## the rules can never disagree about what is still recovering -- the
## `skill_spent` contract, applied to the second refusal reason.
func skill_available(actor_id: String, skill_id: String) -> bool:
	return cooldown_remaining(actor_id, skill_id) <= 0


## Rounds still to wait before `skill_id` is usable again, 0 when it is ready.
## Combat-visible state of the same class as AP and MP (spec ruling 5): the
## opaque-until-sleep lock governs PROGRESSION text, not combat resources, so
## the HUD is free to render this number.
func cooldown_remaining(actor_id: String, skill_id: String) -> int:
	var ready_on := int((cooldowns.get(actor_id, {}) as Dictionary).get(skill_id, 0))
	return maxi(0, ready_on - round_number)


func effective_ap_cost(c: Dictionary, skill: Dictionary) -> int:
	var cost := int(skill.get(WIKeys.AP_COST, 0))
	if _quick_cast_applies(c, skill):
		cost = maxi(0, cost - 1)
	return cost


func _quick_cast_applies(c: Dictionary, skill: Dictionary) -> bool:
	return skill.has(WIKeys.MP_COST) and (c[WIKeys.SKILLS] as Array).has("quick_cast") \
			and not _quick_cast_spent.get(String(c[WIKeys.ID]), false)


func spend_skill_costs(c: Dictionary, skill: Dictionary) -> void:
	_tally_skill_use(String(c[WIKeys.ID]), skill)
	_mark_skill_used(String(c[WIKeys.ID]), String(skill.get(WIKeys.ID, "")))
	# GH#337 spec ruling 3: the stamp belongs HERE, beside the other spends, and
	# never in `use_skill` -- the resolvers validate range/LoS/target side AFTER
	# the gate chain, so a stamp taken at the gate would burn the cooldown on a
	# cast the sim then refuses. Every resolver that reaches a real effect has
	# already called through this function.
	# A windup skill is the ONE exception (spec ruling 3): it stamps at
	# RESOLUTION, in `_resolve_windup`, so the two-beat declare doesn't start the
	# clock a round early.
	if int((skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.WINDUP_ROUNDS, 0)) <= 0:
		_stamp_cooldown(String(c[WIKeys.ID]), skill)
	var ap_cost := effective_ap_cost(c, skill)
	if _quick_cast_applies(c, skill):
		_quick_cast_spent[String(c[WIKeys.ID])] = true
	c[WIKeys.AP] = int(c[WIKeys.AP]) - ap_cost
	_emit(WIEvents.AP_CHANGED, {"id": String(c[WIKeys.ID]), "ap": c[WIKeys.AP]})
	var mp_cost := int(skill.get(WIKeys.MP_COST, 0))
	if mp_cost > 0:
		c[WIKeys.MP] = int(c[WIKeys.MP]) - mp_cost
		_emit(WIEvents.MP_CHANGED, {"id": String(c[WIKeys.ID]), "mp": c[WIKeys.MP]})


## GH#337. Data-driven ONLY -- a skill with no `cooldown_rounds` writes nothing,
## which is also what makes `WIItems`' synthetic item-use skill dict EXEMPT by
## construction (spec ruling 3): it carries no such field and there is no default
## to fall back on, so drinking a potion can never start a clock.
func _stamp_cooldown(actor_id: String, skill: Dictionary) -> void:
	var rounds := int(skill.get(COOLDOWN_ROUNDS, 0))
	var skill_id := String(skill.get(WIKeys.ID, ""))
	if rounds <= 0 or skill_id == "":
		return
	var ledger: Dictionary = cooldowns.get(actor_id, {})
	ledger[skill_id] = round_number + rounds
	cooldowns[actor_id] = ledger


func apply_damage(target_id: String, amount: int, source_id: String, melee: bool) -> void:
	_deduct_hp(target_id, amount)
	_post_damage(target_id, source_id)


func _deduct_hp(target_id: String, amount: int) -> int:
	var t: Dictionary = combatants[target_id]
	if not t[WIKeys.ALIVE]:
		return int(t[WIKeys.HP])
	amount = _apply_difficulty(t, amount)
	amount = _apply_damage_reduction(t, amount)
	amount = _absorb_with_mana_shield(t, amount)
	t[WIKeys.HP] = maxi(0, int(t[WIKeys.HP]) - amount)
	return int(t[WIKeys.HP])


## GH#345 rider. THE one-field read, and it is one field: damage dealt TO a
## player-side combatant, scaled. Nothing else -- not enemy HP, not AP, not
## accuracy, and above all not any RNG draw, so a seeded fight has the IDENTICAL
## shape (initiative, AI decisions, every roll) at every setting and only the
## cost of a hit moves.
##
## Placed on the RAW incoming amount, AHEAD of `damage_reduction`, deliberately:
## DR is a flat subtraction, so scaling after it would quietly make a point of
## armour worth more on the easy rung and less on the hard one. The knob is
## meant to say how hard the world hits, not to re-weight gear.
##
## `_deduct_hp` is the choke point every source already funnels through --
## attacks, ripostes, line/blast multi-hits, windup resolutions and burning
## ticks -- so there is exactly one site, not one per damage type.
func _apply_difficulty(t: Dictionary, amount: int) -> int:
	if amount <= 0 or difficulty_damage_taken_mult == 1.0:
		return amount
	if String(t.get(WIKeys.SIDE, "")) != "player":
		return amount
	return maxi(1, int(round(amount * difficulty_damage_taken_mult)))


func _apply_damage_reduction(t: Dictionary, amount: int) -> int:
	var reduction := int(t.get(WIKeys.DAMAGE_REDUCTION, 0))
	if reduction <= 0 or amount <= 0:
		return amount
	return maxi(1, amount - reduction)


## GH#334 ruling 12: WHICH Skill absorbed. The gate and the credit used to be
## the literal id "mana_shield", so [Ice Wall] -- an Ice Mage L14 capstone whose
## whole effect block IS `mana_shield` -- could never be the thing the game said
## had acted, and never entered `used_skills`: its authored description stayed
## unreachable while a phantom [Mana Shield] took the credit in the save.
##
## FIRST match in kit order, deliberately: `WIProgression.granted_skills` lists a
## class's OWN grants ahead of its inherited ones, so an ice_mage (who holds both,
## mana_shield by inheritance from [Mage] L2) credits the capstone, while a plain
## mage -- and every enemy that carries the base skill by name -- credits
## mana_shield exactly as before. Reading the effect TYPE rather than the id also
## closes the latent hole where a future absorber-only holder got no shield at
## all. "" = no absorber held; the absorb math itself is untouched.
func _absorber_skill_id(t: Dictionary) -> String:
	for raw: Variant in (t[WIKeys.SKILLS] as Array):
		var sid := String(raw)
		if String(((skills.get(sid, {}) as Dictionary).get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, "")) == "mana_shield":
			return sid
	return ""


func _absorb_with_mana_shield(t: Dictionary, amount: int) -> int:
	if amount <= 0:
		return amount
	var absorber := _absorber_skill_id(t)
	if absorber == "":
		return amount
	var absorbed := mini(int(t.get(WIKeys.MP, 0)), amount)
	if absorbed <= 0:
		return amount
	t[WIKeys.MP] = int(t[WIKeys.MP]) - absorbed
	# `family` names the MECHANISM the presentation layer keys its shield tell on
	# (combat_hud's feed line, combat_screen's flash, combat_playback's beat), so
	# those three stay one string comparison instead of a growing id list as more
	# absorbers ship -- while `skill` stays the id, which is what the credit,
	# the save, and the journal reveal need.
	_emit(WIEvents.REACTION_TRIGGERED, {"id": String(t[WIKeys.ID]), "skill": absorber, "family": "mana_shield", "absorbed": absorbed})
	_emit(WIEvents.MP_CHANGED, {"id": String(t[WIKeys.ID]), "mp": t[WIKeys.MP]})
	return amount - absorbed


func _post_damage(target_id: String, source_id: String) -> void:
	var t: Dictionary = combatants[target_id]
	if t[WIKeys.ALIVE] and int(t[WIKeys.HP]) == 0:
		t[WIKeys.ALIVE] = false
		_emit(WIEvents.COMBATANT_DOWNED, {"id": target_id})
		_on_kill(source_id)
		_check_end()
		if not finished and get_active() == target_id:
			_emit(WIEvents.TURN_ENDED, {"id": target_id})
			_advance_turn()


func _resolve_hit(attacker_id: String, target_id: String, mult: float, melee: bool, allow_riposte: bool) -> void:
	var a: Dictionary = combatants[attacker_id]
	var t: Dictionary = combatants[target_id]
	var hit_chance: int = BASE_HIT + int(a["hit_bonus"]) - int(t[WIKeys.STATS]["dex"]) / 4
	var hit := rng.randi_range(1, 100) <= hit_chance
	var damage := 0
	var target_hp := int(t[WIKeys.HP])
	if hit:
		var stat: int = int(a[WIKeys.STATS]["str"]) if melee else int(a[WIKeys.STATS]["int"])
		var base_damage := int((stat / 2 + rng.randi_range(1, int(a[WIKeys.WEAPON_DIE]))) * mult)
		if melee:
			base_damage += int(a.get(WIKeys.DAMAGE_MOD, 0))
		damage = maxi(1, base_damage)
		damage = _apply_status_damage_mods(a, t, damage)
		target_hp = _deduct_hp(target_id, damage)
		# GH#345, THE REPORTED number. `_deduct_hp` scales by the difficulty
		# multiplier internally, so emitting the pre-scale `damage` would float a
		# "10" over a 13-point HP drop and print "strikes you for 10!" in the feed
		# -- HP readouts + damage numbers are a stated product constraint
		# (AGENTS.md), and the burning tick three functions down already reports the
		# honest `hp_before - hp_after`. `_apply_difficulty` is PURE (it reads only
		# the target's side and the injected multiplier, and mutates nothing), so
		# re-evaluating it on the same raw `damage` reports exactly the number
		# `_deduct_hp` used without applying the scale twice.
		#
		# Deliberately NOT switched to a raw HP delta: `damage_reduction` and the
		# mana-shield absorb also sit inside `_deduct_hp`, and both already have
		# their own player-facing tells (the armour readout; REACTION_TRIGGERED's
		# `absorbed`). An HP delta would silently fold them into the attack number
		# and re-pin every DR/shield assertion in the suite. The one thing this
		# fixes is the scalar the player just chose on the settings row.
		damage = _apply_difficulty(t, damage)
		if melee and int(a.get(WIKeys.WEAPON_RANGE, 1)) <= 1:
			_tally(attacker_id, "melee_hit")
		if int(a.get(WIKeys.WEAPON_RANGE, 1)) > 1:
			_tally(attacker_id, "ranged_hit")
	_emit(WIEvents.ATTACK_RESOLVED, {
		"attacker": attacker_id, "target": target_id, "hit": hit,
		"damage": damage, "target_hp": target_hp, "melee": melee,
	})
	if not hit:
		return
	_break_untargetable_statuses(attacker_id)
	_post_damage(target_id, attacker_id)
	if finished:
		return
	var target_now: Dictionary = combatants[target_id]
	if allow_riposte and melee and target_now[WIKeys.ALIVE] \
			and (target_now[WIKeys.SKILLS] as Array).has("counter_strike") \
			and is_adjacent(target_id, attacker_id):
		var riposte_mult := float(skills["counter_strike"][WIKeys.EFFECT][WIKeys.MULT])
		_emit(WIEvents.REACTION_TRIGGERED, {"id": target_id, "skill": "counter_strike"})
		_resolve_hit(target_id, attacker_id, riposte_mult, true, false)


func _apply_status_damage_mods(attacker: Dictionary, defender: Dictionary, amount: int) -> int:
	if (attacker["statuses"] as Dictionary).has("weakened"):
		amount = maxi(1, int(amount * WEAKENED_MULT))
	if (defender["statuses"] as Dictionary).has("guarded"):
		amount = maxi(1, int(amount * GUARDED_MULT))
	return amount


func _break_untargetable_statuses(id: String) -> void:
	var statuses: Dictionary = combatants[id]["statuses"]
	for status_id: String in statuses.keys():
		if bool((statuses[status_id] as Dictionary).get("untargetable", false)):
			statuses.erase(status_id)
			_emit(WIEvents.STATUS_EXPIRED, {"id": id, "status": status_id})


func _on_kill(killer_id: String) -> void:
	var k: Dictionary = combatants.get(killer_id, {})
	if k.is_empty() or not k.get(WIKeys.ALIVE, false):
		return
	if (k[WIKeys.SKILLS] as Array).has("battle_momentum") and not _momentum_used.get(killer_id, false):
		_momentum_used[killer_id] = true
		k[WIKeys.AP] = int(k[WIKeys.AP]) + int(skills["battle_momentum"][WIKeys.EFFECT][WIKeys.AMOUNT])
		_emit(WIEvents.REACTION_TRIGGERED, {"id": killer_id, "skill": "battle_momentum"})
		_emit(WIEvents.AP_CHANGED, {"id": killer_id, "ap": k[WIKeys.AP]})


func end_turn() -> void:
	if finished:
		return
	_emit(WIEvents.TURN_ENDED, {"id": get_active()})
	_advance_turn()


func _tick_burning_statuses() -> void:
	var ids := combatants.keys()
	ids.sort()
	for id: String in ids:
		var c: Dictionary = combatants[id]
		if not bool(c[WIKeys.ALIVE]):
			continue
		var statuses: Dictionary = c["statuses"]
		if not statuses.has("burning"):
			continue
		var tick_damage := int((statuses["burning"] as Dictionary).get("tick_damage", 2))
		var hp_before := int(c[WIKeys.HP])
		var hp_after := _deduct_hp(id, tick_damage)
		_emit(WIEvents.STATUS_TICKED, {"id": id, "status": "burning", "damage": hp_before - hp_after, "hp": hp_after})
		if hp_after == 0:
			c[WIKeys.ALIVE] = false
			_emit(WIEvents.COMBATANT_DOWNED, {"id": id})
			_check_end()
			if finished:
				return


func _advance_turn() -> void:
	var tries := 0
	while tries < turn_order.size() + 1:
		tries += 1
		active_index += 1
		if active_index >= turn_order.size():
			active_index = 0
			round_number += 1
			if round_number > ROUND_CAP:
				_finish(false, true)
				return
			_emit(WIEvents.ROUND_STARTED, {"round": round_number})
			_tick_burning_statuses()
			if finished:
				return
			_purge_expired_terrain()
			_purge_expired_statuses()
		if combatants[get_active()][WIKeys.ALIVE]:
			_start_turn()
			return


func _start_round() -> void:
	round_number = 1
	_emit(WIEvents.ROUND_STARTED, {"round": 1})


func _start_turn() -> void:
	var c: Dictionary = combatants[get_active()]
	_resolve_windup(c)
	if finished or not bool(c[WIKeys.ALIVE]):
		return
	c[WIKeys.AP] = MAX_AP
	_momentum_used.erase(c[WIKeys.ID])
	_quick_cast_spent.erase(c[WIKeys.ID])
	var pool := MOVE_POOL
	var statuses: Dictionary = c["statuses"]
	_apply_terrain_status(c)
	if statuses.has("slowed"):
		var slowed: Dictionary = statuses["slowed"]
		var penalty := int(slowed.get("pool_penalty", 0))
		pool = maxi(1, MOVE_POOL - penalty)
		statuses.erase("slowed")
		_emit(WIEvents.STATUS_EXPIRED, {
			"id": c[WIKeys.ID],
			"status": "slowed",
			"source_kind": String(slowed.get("source_kind", "")),
		})
	pool += _move_pool_bonus_total(c)
	if statuses.has("rooted"):
		pool = 0
	c[WIKeys.MOVE_POOL] = pool
	_emit(WIEvents.TURN_STARTED, {"id": c[WIKeys.ID], "ap": MAX_AP, "move_pool": pool})


func _resolve_windup(c: Dictionary) -> void:
	var actor_id := String(c[WIKeys.ID])
	if not windups.has(actor_id):
		return
	var w: Dictionary = windups[actor_id]
	windups.erase(actor_id)
	var skill_id := String(w["skill_id"])
	# GH#337 spec ruling 3: a windup's cooldown starts when the blow LANDS, not
	# when it was telegraphed -- `spend_skill_costs` deliberately skipped it at
	# declare time. Nothing shipped pairs `windup_rounds` with `cooldown_rounds`
	# today (slam's `windup_cadence` already paces the only holders), so this arm
	# is the mechanism being correct ahead of a data row, not a live path.
	_stamp_cooldown(actor_id, skills.get(skill_id, {}))
	var effect: Dictionary = (skills.get(skill_id, {}) as Dictionary).get(WIKeys.EFFECT, {})
	var cells: Array = w["cells"]
	var hit_ids: Array = []
	for id: String in combatants:
		if id == actor_id:
			continue  # caster excluded by id (see doc comment) -- never by cell
		if not bool(combatants[id][WIKeys.ALIVE]):
			continue
		if (combatants[id][WIKeys.CELL] as Vector2i) in cells:
			hit_ids.append(id)
	hit_ids.sort()
	var cells_payload: Array = []
	for cell: Vector2i in cells:
		cells_payload.append([cell.x, cell.y])
	_emit(WIEvents.SKILL_RESOLVED, {
		"actor": actor_id, "skill": skill_id, "cells": cells_payload, "hit_ids": hit_ids,
	})
	for id: String in hit_ids:
		if not bool(combatants[id][WIKeys.ALIVE]):
			continue  # an earlier hit in this same resolution may have already downed them
		var hp_before := int(combatants[id][WIKeys.HP])
		_resolve_hit(actor_id, id, 1.0, true, false)
		if finished:
			return
		if int(combatants.get(id, {}).get(WIKeys.HP, hp_before)) < hp_before:
			WISkillEffects._apply_status_from_effect(self, id, effect)


func _move_pool_bonus_total(c: Dictionary) -> int:
	var total := 0
	for sk: String in (c[WIKeys.SKILLS] as Array):
		var s: Dictionary = skills.get(sk, {})
		if int(s.get(WIKeys.AP_COST, 0)) > 0:
			continue
		var effect: Dictionary = s.get(WIKeys.EFFECT, {})
		if String(effect.get(WIKeys.TYPE, "")) == "move_pool_bonus":
			total += int(effect.get(WIKeys.AMOUNT, 0))
			_emit(WIEvents.PASSIVE_APPLIED, {"id": String(c[WIKeys.ID]), "skill": sk})
	return total


func _apply_terrain_status(c: Dictionary) -> void:
	var cell: Vector2i = c[WIKeys.CELL]
	if not terrain.has(cell):
		return
	var entry: Dictionary = terrain[cell]
	var applies: Dictionary = entry.get(WIKeys.APPLIES, {})
	for status_id: String in applies:
		var status_data := (applies[status_id] as Dictionary).duplicate(true)
		var source_kind := String(entry.get("kind", ""))
		status_data["source_kind"] = source_kind
		(c["statuses"] as Dictionary)[status_id] = status_data
		_emit(WIEvents.STATUS_APPLIED, {
			"id": String(c[WIKeys.ID]),
			"status": status_id,
			"source_kind": source_kind,
		})


func _purge_expired_terrain() -> void:
	if terrain.is_empty():
		return
	var purged_by_kind: Dictionary = {}
	for cell: Vector2i in terrain.keys():
		var entry: Dictionary = terrain[cell]
		if int(entry.get("expires_after_round", -1)) < round_number:
			var kind := String(entry.get("kind", ""))
			var cells: Array = purged_by_kind.get(kind, [])
			cells.append(cell)
			purged_by_kind[kind] = cells
			terrain.erase(cell)
	for kind: String in purged_by_kind:
		var cells: Array = purged_by_kind[kind]
		cells.sort_custom(_cell_less_than)
		var cells_payload: Array = []
		for cell: Vector2i in cells:
			cells_payload.append([cell.x, cell.y])
		_emit(WIEvents.TERRAIN_EXPIRED, {"kind": kind, "cells": cells_payload})


func _purge_expired_statuses() -> void:
	var ids := combatants.keys()
	ids.sort()
	for id: String in ids:
		var statuses: Dictionary = combatants[id]["statuses"]
		for status_id: String in statuses.keys():
			var entry: Dictionary = statuses[status_id]
			if entry.has("expires_after_round") and int(entry["expires_after_round"]) < round_number:
				statuses.erase(status_id)
				_emit(WIEvents.STATUS_EXPIRED, {"id": id, "status": status_id})


static func _cell_less_than(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


func _check_end() -> void:
	# PC death is immediate defeat even while another player-side combatant lives.
	if combatants.has("pc") and not bool(combatants["pc"][WIKeys.ALIVE]):
		_finish(false, false)
		return
	var sides_alive := {"player": false, "enemy": false}
	for c: Dictionary in combatants.values():
		if c[WIKeys.ALIVE]:
			sides_alive[String(c[WIKeys.SIDE])] = true
	if not sides_alive["enemy"]:
		_finish(true, false)
	elif not sides_alive["player"]:
		_finish(false, false)


func _finish(victory: bool, draw: bool) -> void:
	if finished:
		return
	finished = true
	var survivors: Array = []
	for id: String in combatants:
		if combatants[id][WIKeys.ALIVE]:
			survivors.append(id)
	survivors.sort()
	outcome = {"victory": victory, "rounds": round_number, "survivors": survivors, "draw": draw}
	_emit(WIEvents.COMBAT_FINISHED, {"victory": victory, "rounds": round_number, "draw": draw})


func snapshot() -> Dictionary:
	var cs := {}
	for id: String in combatants:
		var c: Dictionary = combatants[id]
		cs[id] = {
			"cell": [(c[WIKeys.CELL] as Vector2i).x, (c[WIKeys.CELL] as Vector2i).y],
			"hp": c[WIKeys.HP], "max_hp": c[WIKeys.MAX_HP], "ap": c[WIKeys.AP],
			"mp": c[WIKeys.MP], "max_mp": c[WIKeys.MAX_MP],
			"move_pool": c[WIKeys.MOVE_POOL],
			"alive": c[WIKeys.ALIVE], "side": c[WIKeys.SIDE],
			"skills": (c[WIKeys.SKILLS] as Array).duplicate(),
			"weapon_range": int(c.get(WIKeys.WEAPON_RANGE, 1)),
			"cooldowns": _cooldown_snapshot(id),
		}
	return {
		"round": round_number, "active": get_active() if not turn_order.is_empty() else "",
		"finished": finished, "victory": outcome.get("victory", false),
		"order": turn_order.duplicate(), "combatants": cs,
		"terrain": _terrain_snapshot(),
	}


## GH#337. REMAINING rounds, not the absolute stamp: a snapshot consumer wants
## "how long until I can use this", and a relative number is also the only form
## that stays stable across a replay from a different round. Ready skills are
## omitted entirely, so a fight where nothing has cooled reads `{}` for every
## combatant. Skill ids are SORTED -- the `_terrain_snapshot` determinism
## discipline, since Dictionary key order is insertion order.
func _cooldown_snapshot(actor_id: String) -> Dictionary:
	var ledger: Dictionary = cooldowns.get(actor_id, {})
	if ledger.is_empty():
		return {}
	var skill_ids := ledger.keys()
	skill_ids.sort()
	var out := {}
	for skill_id: String in skill_ids:
		var remaining := maxi(0, int(ledger[skill_id]) - round_number)
		if remaining > 0:
			out[skill_id] = remaining
	return out


func _terrain_snapshot() -> Dictionary:
	var out := {}
	for cell: Vector2i in terrain:
		var kind := String((terrain[cell] as Dictionary).get("kind", ""))
		var list: Array = out.get(kind, [])
		list.append(cell)
		out[kind] = list
	for kind: String in out:
		var cells: Array = out[kind]
		cells.sort_custom(_cell_less_than)
		var cells_payload: Array = []
		for cell: Vector2i in cells:
			cells_payload.append([cell.x, cell.y])
		out[kind] = cells_payload
	return out


func _tally(actor_id: String, counter: String) -> void:
	var counters: Dictionary = action_tally.get(actor_id, {})
	counters[counter] = int(counters.get(counter, 0)) + 1
	action_tally[actor_id] = counters


func _tally_skill_use(actor_id: String, skill: Dictionary) -> void:
	if skill.has(WIKeys.WEAPON):
		_tally(actor_id, "%s_skill_used" % String(skill[WIKeys.WEAPON]))
	if skill.has("element"):
		_tally(actor_id, "spell_cast")
		_tally(actor_id, "%s_cast" % String(skill["element"]))


func _mark_skill_used(actor_id: String, skill_id: String) -> void:
	if skill_id == "":
		return
	var used: Dictionary = used_skills_tally.get(actor_id, {})
	used[skill_id] = true
	used_skills_tally[actor_id] = used


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
