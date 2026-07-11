class_name WICombat
extends RefCounted
## Pure tactical combat simulation for one encounter.
##
## PURITY RULE: no autoload, Node, or scene-tree references. Dependencies are
## injected (arena/combatant/skill configs, event-sink Callable, RNG seed).
## All randomness flows through `rng`; initiative is precomputed then sorted —
## never roll inside a comparator.

const MAX_AP := 4
const MOVE_COST := 1
const ATTACK_COST := 2
const BASE_HIT := 85
const ROUND_CAP := 30
const MOVE_POOL := 3
const DASH_COST := 1
const DASH_GAIN := 3

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
## Per-fight deed tally, actor id -> {counter: count} (M6 §2.1 REV 2).
## Counters: melee_hit on landed melee hits (ripostes included — the deed is
## the defender's); sword_skill_used/spear_skill_used from the skills.json
## `weapon` tag and spell_cast + ice_cast/fire_cast from its `element` tag,
## both tallied at the spend site (refused actions never reach it).
## WIGame.resolve_combat banks the PC's tally into accomplishments on
## victory; the tally itself emits nothing and consumes no rng.
var action_tally: Dictionary = {}
## Per-fight SET of skill ids actually cast, actor id -> {skill_id: true}
## Recorded at the SAME spend site as action_tally
## (spend_skill_costs, below) — a refused cast never reaches it, same
## convention — but this is a bare presence set, never gated by any
## `trivial` flag: that gate lives entirely on WIGame's `_bank_action_tally`
## (the ACCOMPLISHMENT-counter bank), a separate concern from "has this skill
## ever been cast" for the journal's first-use reveal, which
## `WIGame.resolve_combat` merges in unconditionally.
var used_skills_tally: Dictionary = {}
## `Vector2i` cell -> `{"kind":
## "icy_floor", "expires_after_round": int, "applies": Dictionary}`. NOT
## save-persisted (combat state never is, per data/skills.json/wi_combat.gd
## convention -- a combat is always mid-encounter, never resumed across a
## save load). Populated only by WISkillEffects.resolve_active's icy_floor
## arm; purged by `_advance_turn`'s round-rollover branch
## (`_purge_expired_terrain`). Every existing fight leaves this empty for
## its whole duration -- the two consumers (`_apply_terrain_status`'s call
## sites in `move_active`/`_start_turn`, and the purge above) are no-ops on
## an empty dict, which is the zero-behavior-change proof for every
## pre-existing combat-data payload.
var terrain: Dictionary = {}

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
		# Same-catalog-id roster collapse fix: a roster listing the
		# same combatant id twice (e.g. shield_spiders' ["shield_spider",
		# "shield_spider"]) used to key `combatants` by the plain id, so the
		# second entry silently overwrote the first -- the roster fielded one
		# fewer combatant than it listed. Every cfg now gets a UNIQUE runtime
		# id (first occurrence keeps the bare id; each further collision gets
		# "_2", "_3", ... -- re-probed against `combatants` so it can never
		# collide with a genuinely distinct id that happens to already carry
		# a numeric suffix). Display name is untouched (`DISPLAY_NAME` below
		# still reads straight off `cfg`) -- players see "Shield Spider"
		# twice, the suffix is internal bookkeeping only. `TEMPLATE_ID` keeps
		# the ORIGINAL catalog id so presentation can still resolve the
		# static combatants.json record (sprite, combat_scale) by the id that
		# actually exists there -- see board_renderer.gd's two read sites.
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
			# M7 §2 combat build injection (WIGame._build_player_combatant is
			# the only caller that ever sets these on a real cfg today; every
			# other combatant defaults to 0, unaffected): armor's hp_mod folds
			# into max_hp here at build time. damage_mod/damage_reduction ride
			# along on the combatant dict for the two runtime sites that use
			# them (_resolve_hit's melee damage, _deduct_hp's incoming-damage
			# floor) -- see those functions' own doc comments.
			WIKeys.MAX_HP: 20 + int(cfg[WIKeys.STATS]["con"]) + int(cfg.get(WIKeys.HP_MOD, 0)),
			WIKeys.DAMAGE_MOD: int(cfg.get(WIKeys.DAMAGE_MOD, 0)),
			WIKeys.DAMAGE_REDUCTION: int(cfg.get(WIKeys.DAMAGE_REDUCTION, 0)),
			WIKeys.AP: 0,
			WIKeys.MOVE_POOL: 0,
			"statuses": {},
			WIKeys.ALIVE: true,
		}
		for sk: Variant in cfg.get(WIKeys.SKILLS, []):
			c[WIKeys.SKILLS].append(String(sk))
		_apply_passives(c)
		c[WIKeys.HP] = c[WIKeys.MAX_HP]
		# MP pool exists only for casters: any known skill carrying an mp_cost.
		# Non-casters get max_mp 0 (no MP bar player-side).
		c[WIKeys.MAX_MP] = 0
		for sk: String in c[WIKeys.SKILLS]:
			if (skills.get(sk, {}) as Dictionary).has(WIKeys.MP_COST):
				c[WIKeys.MAX_MP] = 8 + int(int(c[WIKeys.STATS]["int"]) / 2)
				break
		c[WIKeys.MP] = c[WIKeys.MAX_MP]
		combatants[c[WIKeys.ID]] = c
	_roll_initiative()


## Kicks off the fight: emits combat_started and starts round 1 / first turn.
## Separated from _init so the owner can finish wiring (e.g. assigning this
## instance somewhere listeners can reach) before any event fires.
func begin() -> void:
	# `arena` is additive (every QA pin uses payload_contains subset match):
	# it keys per-arena music variants in data/audio.json (first-match-wins,
	# specific-before-generic ordering there) and any future arena-keyed
	# presentation.
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


## Supercover cell walk from a's cell to b's cell. Blocked (wall) cells refuse
## LoS; other combatants never block LoS [D per spec]. The endpoints
## themselves are never treated as obstructing (a combatant always has LoS
## out of/into its own occupied cell).
##
## SYMMETRY GUARANTEE: `_supercover` enumerates every cell the ideal
## center-to-center segment crosses, which is a pure geometric property of
## the segment — the same set of cells regardless of which endpoint is
## "from" and which is "to" (see `_supercover`'s doc comment for the corner
## rule that makes this true even on diagonally-adjacent wall pairs). A
## single-raster Bresenham walk instead commits to one arbitrary path per
## direction and can therefore disagree with itself when reversed; this is
## the asymmetry bug this construction guards against: has_los((0,0),(3,6)) vs the reverse
## disagreeing on the blocked set {(5,3),(6,4),(3,5),(8,2)}.
func has_los(a_id: String, b_id: String) -> bool:
	var from: Vector2i = combatants[a_id][WIKeys.CELL]
	var to: Vector2i = combatants[b_id][WIKeys.CELL]
	for cell: Vector2i in _supercover(from, to):
		if cell == from or cell == to:
			continue
		if blocked.has(cell):
			return false
	return true


## Supercover line: every cell the ideal segment from `from` to `to` crosses,
## inclusive of both endpoints. Deterministic, no rng — pure integer geometry.
##
## Algorithm: with nx=|dx|, ny=|dy| grid-line crossings remaining to make in
## x and y respectively, the i-th (1-indexed) x-crossing occurs at parametric
## t=(2i-1)/(2*nx) along the segment and the j-th y-crossing at
## t=(2j-1)/(2*ny). Comparing two such fractions cross-multiplied,
## (2i-1)*ny vs (2j-1)*nx, is exact integer arithmetic — no floats, no
## rounding, so the result cannot depend on direction of travel. When the two
## are exactly equal the segment passes through a grid CORNER: per the
## adjudicated corner rule, BOTH cells diagonally adjacent to that corner
## (the two "off-diagonal" cells, not just the forward diagonal cell) are
## included — this is what restores symmetry on diagonally-touching wall
## pairs, since without it a corner-grazing line could be said to pass
## through either of two different single cells depending on which way you
## look at it.
##
## LOOP BOUND (provable): each iteration retires at least one of the nx+ny
## required crossings (a corner tie retires both x and y at once), so the
## loop runs at most nx+ny times — i.e. at most |dx|+|dy| iterations, well
## under the 2*(|dx|+|dy|)+4 ceiling asserted below. Exceeding that ceiling
## is a geometry bug, not a valid outcome, hence the loud assert instead of a
## silent break (this replaces an earlier, discarded supercover attempt that
## walked without a bound and hung the test suite).
func _supercover(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
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
				# Exact corner crossing: include both off-diagonal cells, then
				# step into the diagonal cell itself.
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


## Cardinal-only line enumeration: walks `length` cells from `from` in
## `toward_dir` (must be a unit cardinal direction), clipped at grid bounds.
## Stops at (and includes) the first blocked cell — walls stop fire — but
## does NOT stop for occupants; every cell in the returned array gets hit
## regardless of who stands there [D: friendly fire is real, per spec].
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
		return false
	var target: Vector2i = (c[WIKeys.CELL] as Vector2i) + dir
	if absi(dir.x) + absi(dir.y) != 1 or not is_cell_free(target):
		return false
	c[WIKeys.CELL] = target
	c[WIKeys.MOVE_POOL] = int(c[WIKeys.MOVE_POOL]) - MOVE_COST
	_emit(WIEvents.COMBATANT_MOVED, {"id": c[WIKeys.ID], "cell": [target.x, target.y]})
	_apply_terrain_status(c)
	return true


## Spends 1 AP for +DASH_GAIN move pool. Repeatable while AP lasts.
func dash() -> bool:
	if finished:
		return false
	if not bool(combatants[get_active()][WIKeys.ALIVE]):
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
	if finished:
		return false
	if not bool(combatants[get_active()][WIKeys.ALIVE]):
		return false
	var attacker_id := get_active()
	var a: Dictionary = combatants[attacker_id]
	var t: Dictionary = combatants.get(target_id, {})
	if t.is_empty() or not t[WIKeys.ALIVE] or String(t[WIKeys.SIDE]) == String(a[WIKeys.SIDE]):
		return false
	if int(a[WIKeys.AP]) < ATTACK_COST or not is_adjacent(attacker_id, target_id):
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
	# Both gates run BEFORE any spend: a refused cast costs neither MP nor AP.
	if int(a.get(WIKeys.MP, 0)) < int(skill.get(WIKeys.MP_COST, 0)):
		return false
	if int(a[WIKeys.AP]) < effective_ap_cost(a, skill):
		return false
	return WISkillEffects.resolve_active(self, actor_id, target_id, skill)


## The AP a cast will actually cost `c`: quick_cast discounts the first
## successful spell (a skill carrying an mp_cost) each turn by 1 (min 0).
func effective_ap_cost(c: Dictionary, skill: Dictionary) -> int:
	var cost := int(skill.get(WIKeys.AP_COST, 0))
	if _quick_cast_applies(c, skill):
		cost = maxi(0, cost - 1)
	return cost


func _quick_cast_applies(c: Dictionary, skill: Dictionary) -> bool:
	return skill.has(WIKeys.MP_COST) and (c[WIKeys.SKILLS] as Array).has("quick_cast") \
			and not _quick_cast_spent.get(String(c[WIKeys.ID]), false)


## Charges a successful cast's AP + MP. The single spend site for skill
## resolvers — refusal paths must return before reaching this. Consumes the
## quick_cast first-spell-of-the-turn discount when it applied.
func spend_skill_costs(c: Dictionary, skill: Dictionary) -> void:
	_tally_skill_use(String(c[WIKeys.ID]), skill)
	_mark_skill_used(String(c[WIKeys.ID]), String(skill.get(WIKeys.ID, "")))
	var ap_cost := effective_ap_cost(c, skill)
	if _quick_cast_applies(c, skill):
		_quick_cast_spent[String(c[WIKeys.ID])] = true
	c[WIKeys.AP] = int(c[WIKeys.AP]) - ap_cost
	_emit(WIEvents.AP_CHANGED, {"id": String(c[WIKeys.ID]), "ap": c[WIKeys.AP]})
	var mp_cost := int(skill.get(WIKeys.MP_COST, 0))
	if mp_cost > 0:
		c[WIKeys.MP] = int(c[WIKeys.MP]) - mp_cost
		_emit(WIEvents.MP_CHANGED, {"id": String(c[WIKeys.ID]), "mp": c[WIKeys.MP]})


## Applies damage directly (used by hit resolution and tests).
func apply_damage(target_id: String, amount: int, source_id: String, melee: bool) -> void:
	_deduct_hp(target_id, amount)
	_post_damage(target_id, source_id)


## Deducts HP and returns the new value. The single source of truth for HP
## math — mana_shield absorption happens here, inside the damage application,
## so it always precedes the down-check regardless of the damage source.
func _deduct_hp(target_id: String, amount: int) -> int:
	var t: Dictionary = combatants[target_id]
	if not t[WIKeys.ALIVE]:
		return int(t[WIKeys.HP])
	amount = _apply_damage_reduction(t, amount)
	amount = _absorb_with_mana_shield(t, amount)
	t[WIKeys.HP] = maxi(0, int(t[WIKeys.HP]) - amount)
	return int(t[WIKeys.HP])


## Armor's flat damage_reduction, applied BEFORE mana_shield so the
## shield only ever absorbs what actually got past armor. A landed hit
## always deals >=1 regardless of how much reduction stacks against it (the
## floor only engages for a positive incoming amount -- _resolve_hit never
## calls this with a non-positive amount today, but a future 0/negative-
## amount caller stays unfloored rather than being pushed up to 1 out of
## nowhere).
func _apply_damage_reduction(t: Dictionary, amount: int) -> int:
	var reduction := int(t.get(WIKeys.DAMAGE_REDUCTION, 0))
	if reduction <= 0 or amount <= 0:
		return amount
	return maxi(1, amount - reduction)


## Mana Shield reaction: while the holder knows it and mp > 0, incoming damage
## drains MP 1:1 before touching HP. Partial absorbs split (the shield takes
## what MP remains; the rest lands on HP). Returns the unabsorbed remainder.
func _absorb_with_mana_shield(t: Dictionary, amount: int) -> int:
	if amount <= 0 or not (t[WIKeys.SKILLS] as Array).has("mana_shield"):
		return amount
	var absorbed := mini(int(t.get(WIKeys.MP, 0)), amount)
	if absorbed <= 0:
		return amount
	t[WIKeys.MP] = int(t[WIKeys.MP]) - absorbed
	_emit(WIEvents.REACTION_TRIGGERED, {"id": String(t[WIKeys.ID]), "skill": "mana_shield", "absorbed": absorbed})
	_emit(WIEvents.MP_CHANGED, {"id": String(t[WIKeys.ID]), "mp": t[WIKeys.MP]})
	return amount - absorbed


## Post-damage bookkeeping: down/kill/end checks. Emits combatant_downed.
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
		# The weapon's flat damage_mod adds to melee damage only
		# (basic Attack AND weapon-family skills like power_strike/
		# piercing_strikes, since both route through this same melee=true
		# call) -- never to a ranged spell_damage cast (melee=false, int-
		# based). Defaults to 0 for every combatant without build-time
		# injection, so this is byte-identical to the pre-M7 formula
		# whenever damage_mod is 0 (rusty_sword's provisional value).
		if melee:
			base_damage += int(a.get(WIKeys.DAMAGE_MOD, 0))
		damage = maxi(1, base_damage)
		target_hp = _deduct_hp(target_id, damage)
		if melee:
			_tally(attacker_id, "melee_hit")
	_emit(WIEvents.ATTACK_RESOLVED, {
		"attacker": attacker_id, "target": target_id, "hit": hit,
		"damage": damage, "target_hp": target_hp, "melee": melee,
	})
	if not hit:
		return
	# [Invisibility]'s break-on-damage rule: dealing damage (any attack or
	# damaging skill -- every one of them routes through this single
	# `_resolve_hit` choke point, melee or spell or line alike) clears the
	# ATTACKER's own untargetable status. Keyed on the flag, not this
	# combatant's held skills, so it fires identically for a riposte
	# counter-attack (the recursive `_resolve_hit` call below, attacker_id
	# swapped to the riposter) as for a normal turn action.
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


## Clears any status on `id` carrying `untargetable: true` (today only
## invisibility's `invisible` entry) and emits STATUS_EXPIRED per cleared
## entry -- the break-on-damage half of the untargetable contract (the
## natural-expiry half lives in `_purge_expired_statuses` below). DATA-DRIVEN:
## reads the flag off whatever is in `statuses`, never checks a skill id or
## the status name "invisible" specifically, so any future status reusing
## this flag breaks on damage for free.
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
	c[WIKeys.AP] = MAX_AP
	_momentum_used.erase(c[WIKeys.ID])
	_quick_cast_spent.erase(c[WIKeys.ID])
	var pool := MOVE_POOL
	var statuses: Dictionary = c["statuses"]
	# A combatant STARTING its turn already standing on icy_floor gets
	# the penalty THIS turn, through the SAME consume-block below (applied
	# here -> immediately consumed a few lines down) -- applied before the
	# `slowed` check so this turn's TURN_STARTED move_pool reflects the
	# reduced pool, not a stale one that only kicks in next turn.
	_apply_terrain_status(c)
	if statuses.has("slowed"):
		var penalty := int((statuses["slowed"] as Dictionary).get("pool_penalty", 0))
		pool = maxi(1, MOVE_POOL - penalty)
		statuses.erase("slowed")
		_emit(WIEvents.STATUS_EXPIRED, {"id": c[WIKeys.ID], "status": "slowed"})
	pool += _move_pool_bonus_total(c)
	c[WIKeys.MOVE_POOL] = pool
	_emit(WIEvents.TURN_STARTED, {"id": c[WIKeys.ID], "ap": MAX_AP, "move_pool": pool})


## The two PRE-EXISTING 0-cost move_pool_bonus skills
## (quick_movement, battlefield_awareness) are genuine PASSIVES -- a holder
## gets +amount move_pool at the START of every turn, unconditionally: no
## cast, no cost, no refusal path. This is deliberately separate from
## [Stealth]'s ACTIVE cast (ap_cost 1, gated in skill_effects.gd's
## resolve_active on ap_cost > 0), which this function never touches.
## Applied AFTER the slowed penalty above -- same "per-turn pool math lives
## here" site the penalty already established -- so a slowed holder of one
## of these still gets its passive bonus on top of the reduced base (a
## flat add, same as dash() stacking on top of whatever pool state already
## exists; there is no design reason the passive would selectively skip a
## slowed turn).
func _move_pool_bonus_total(c: Dictionary) -> int:
	var total := 0
	for sk: String in (c[WIKeys.SKILLS] as Array):
		var s: Dictionary = skills.get(sk, {})
		if int(s.get(WIKeys.AP_COST, 0)) > 0:
			continue
		var effect: Dictionary = s.get(WIKeys.EFFECT, {})
		if String(effect.get(WIKeys.TYPE, "")) == "move_pool_bonus":
			total += int(effect.get(WIKeys.AMOUNT, 0))
	return total


## Applies the terrain entry (if
## any) registered at `c`'s CURRENT cell onto `c` -- the STANDING-terrain
## counterpart of `WISkillEffects._apply_status_from_effect` (that one fires
## on a HIT; this one fires on OCCUPYING a terrain cell). No-op when
## `terrain` holds no entry for the cell -- every existing fight never
## populates `terrain` at all, so this is a guaranteed no-op there (the
## "zero behavior change for every pre-existing fight" proof). Two call
## sites, per the design: `move_active` (stepping onto a terrain cell mid-
## turn) and `_start_turn` (starting a turn already standing on one, applied
## before the `slowed` consume-block so the SAME machinery handles both —
## applied then immediately consumed the same turn, both events firing).
func _apply_terrain_status(c: Dictionary) -> void:
	var cell: Vector2i = c[WIKeys.CELL]
	if not terrain.has(cell):
		return
	var entry: Dictionary = terrain[cell]
	var applies: Dictionary = entry.get(WIKeys.APPLIES, {})
	for status_id: String in applies:
		(c["statuses"] as Dictionary)[status_id] = (applies[status_id] as Dictionary).duplicate(true)
		_emit(WIEvents.STATUS_APPLIED, {"id": String(c[WIKeys.ID]), "status": status_id})


## Called from `_advance_turn`'s round-rollover branch, after
## `round_number` has already advanced and ROUND_STARTED has already
## emitted. Removes every terrain cell whose `expires_after_round` has
## passed (a cell cast at round N with `duration_rounds` D carries
## `expires_after_round = N+D-1`, so it survives the rollover check through
## round N+D-1 and is purged the next time round_number moves past it --
## "icy through end of round N+duration-1"). Batches every purged cell into
## ONE terrain_expired emit PER KIND (today only "icy_floor" ever exists in
## `terrain`, so this is always at most one emit per rollover) rather than
## one per cell, mirroring TERRAIN_ADDED's batched-cells-per-cast shape.
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


## The per-COMBATANT counterpart of `_purge_expired_terrain` above, called
## from the SAME round-rollover site: removes any status entry carrying an
## `expires_after_round` that has passed. This is a GENERIC, opt-in mechanism
## -- only a status entry that itself stamps `expires_after_round` (today,
## invisibility's `invisible`, set by WISkillEffects._resolve_invisibility)
## is ever touched here. Every pre-existing per-unit status (`slowed`, from
## frost_bolt/icy_floor's hit-applied `applies` dict) carries NO such key, so
## this purge is a guaranteed no-op for every fight that never casts
## invisibility -- `slowed` keeps expiring exactly as before, via
## `_start_turn`'s own dedicated consume-block, untouched by this function.
## Iterates combatant ids in sorted order for deterministic event ordering.
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


## Deterministic cell ordering (x then y) shared by every terrain payload
## that must sort for determinism (TERRAIN_ADDED's cells, TERRAIN_EXPIRED's
## cells, snapshot()'s terrain lists) -- one canonical comparator so the
## sort order can never drift arm-to-arm.
static func _cell_less_than(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


## PC death is an immediate defeat, regardless of living allies (post-D4
## playtest directive 7, user-confirmed): the team-wipe rule below still
## governs every other combatant, but "pc" specifically ends the fight the
## instant it goes down. Checked BEFORE the team-wipe scan so a PC death that
## happens to coincide with the last enemy dying (e.g. a friendly-fire line
## skill) resolves as DEFEAT, never a simultaneous victory.
func _check_end() -> void:
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
		}
	return {
		"round": round_number, "active": get_active() if not turn_order.is_empty() else "",
		"finished": finished, "victory": outcome.get("victory", false),
		"order": turn_order.duplicate(), "combatants": cs,
		"terrain": _terrain_snapshot(),
	}


## `{kind: [[x,y],...] sorted}` -- empty dict when `terrain` is empty
## (every pre-existing fight). QA asserts through this exact shape
## (`assert_state combat.terrain.icy_floor`).
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


## Increments one deed counter for one actor in the per-fight tally.
func _tally(actor_id: String, counter: String) -> void:
	var counters: Dictionary = action_tally.get(actor_id, {})
	counters[counter] = int(counters.get(counter, 0)) + 1
	action_tally[actor_id] = counters


## Tallies a successful skill spend from its skills.json tags: a `weapon` tag
## counts <weapon>_skill_used; an `element` tag counts spell_cast plus
## <element>_cast. Untagged skills tally nothing here.
func _tally_skill_use(actor_id: String, skill: Dictionary) -> void:
	if skill.has(WIKeys.WEAPON):
		_tally(actor_id, "%s_skill_used" % String(skill[WIKeys.WEAPON]))
	if skill.has("element"):
		_tally(actor_id, "spell_cast")
		_tally(actor_id, "%s_cast" % String(skill["element"]))


## Records `skill_id` into `used_skills_tally` for `actor_id` (the
## per-fight half — see that var's own doc comment). A no-op for an
## empty id (skill dicts always carry one from data/skills.json in real
## play; the guard is pure hygiene against a hand-built test dict).
func _mark_skill_used(actor_id: String, skill_id: String) -> void:
	if skill_id == "":
		return
	var used: Dictionary = used_skills_tally.get(actor_id, {})
	used[skill_id] = true
	used_skills_tally[actor_id] = used


func _emit(type: String, payload: Dictionary) -> void:
	if _event_sink.is_valid():
		_event_sink.call(type, payload)
