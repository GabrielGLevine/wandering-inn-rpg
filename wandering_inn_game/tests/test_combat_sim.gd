extends SceneTree
## Pure combat-sim tests: rules, ordering, and determinism.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_combat_sim.gd

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _count(type: String) -> int:
	var n := 0
	for e: Dictionary in _events:
		if e["type"] == type:
			n += 1
	return n


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _cfgs(ids: Array) -> Array:
	var all := _load("res://data/combatants.json")
	var out: Array = []
	for want: String in ids:
		for c: Dictionary in all["combatants"]:
			if String(c[WIKeys.ID]) == want:
				out.append(c.duplicate(true))
	return out


func _make(seed_v: int, sink: Callable) -> WICombat:
	var arena: Dictionary = _load("res://data/arenas.json")["arenas"][0]
	var combat := WICombat.new(arena, _cfgs(["pc", "relc", "goblin_raider", "goblin_shaman"]), _load("res://data/skills.json"), sink, seed_v)
	combat.begin()
	return combat


## Like _make, but lets a test pre-seed a combatant's build-time config (e.g.
## giving pc a spell BEFORE construction) — needed for max_mp, which is only
## computed once at _init from the combatant's starting skill list.
func _make_custom(seed_v: int, sink: Callable, cfg_overrides: Dictionary) -> WICombat:
	var arena: Dictionary = _load("res://data/arenas.json")["arenas"][0]
	var cfgs := _cfgs(["pc", "relc", "goblin_raider", "goblin_shaman"])
	for cfg: Dictionary in cfgs:
		var id := String(cfg[WIKeys.ID])
		if cfg_overrides.has(id):
			for key: String in (cfg_overrides[id] as Dictionary):
				cfg[key] = (cfg_overrides[id] as Dictionary)[key]
	var combat := WICombat.new(arena, cfgs, _load("res://data/skills.json"), sink, seed_v)
	combat.begin()
	return combat


func _init() -> void:
	WITestWatchdog.arm(self)
	var combat := _make(42, _sink)

	# Setup: four combatants at spawn cells, initiative precomputed, round 1 started
	assert(combat.turn_order.size() == 4, "all four in initiative order")
	assert(combat.combatants["pc"][WIKeys.CELL] == Vector2i(2, 3), "pc at first player spawn")
	assert(combat.combatants["goblin_raider"][WIKeys.CELL] == Vector2i(9, 3), "raider at first enemy spawn")
	assert(_count("combat_started") == 1 and _count("round_started") == 1 and _count("turn_started") == 1, "start events")
	assert(combat.combatants[combat.get_active()][WIKeys.AP] == WICombat.MAX_AP, "active has full AP")

	# Movement: costs 1 pool (free of AP), respects bounds/blocked/occupied
	var active: String = combat.get_active()
	var before: Vector2i = combat.combatants[active][WIKeys.CELL]
	assert(combat.move_active(Vector2i.RIGHT) or combat.move_active(Vector2i.LEFT) or combat.move_active(Vector2i.UP) or combat.move_active(Vector2i.DOWN), "some direction is open")
	assert(combat.combatants[active][WIKeys.MOVE_POOL] == WICombat.MOVE_POOL - 1, "move cost 1 pool")
	assert(combat.combatants[active][WIKeys.AP] == WICombat.MAX_AP, "move does not touch AP")
	assert(combat.combatants[active][WIKeys.CELL] != before, "cell changed")

	# Turn/round advance
	combat.end_turn()
	assert(_count("turn_ended") == 1 and _count("turn_started") == 2, "turn advanced")
	combat.end_turn()
	combat.end_turn()
	combat.end_turn()
	assert(_count("round_started") == 2, "wrapping order starts round 2")
	assert(combat.round_number == 2, "round counter")

	# Attack validation: non-adjacent attack refused, no AP spent
	var atk: String = combat.get_active()
	var foes: Array = combat.alive_enemies_of(atk)
	assert(not foes.is_empty(), "has living enemies")
	if not combat.is_adjacent(atk, String(foes[0])):
		assert(not combat.attack(String(foes[0])), "non-adjacent attack refused")
		assert(combat.combatants[atk][WIKeys.AP] == WICombat.MAX_AP, "refused attack costs nothing")

	# Determinism: same seed + same scripted intents → identical event streams
	var stream_a: Array = []
	var stream_b: Array = []
	for stream: Array in [stream_a, stream_b]:
		var ev := func(type: String, payload: Dictionary) -> void:
			stream.append(JSON.stringify({"t": type, "p": payload}))
		var c := _make(99, ev)
		for i in 40:
			if c.finished:
				break
			if not c.move_active(Vector2i.LEFT):
				if not c.move_active(Vector2i.UP):
					c.end_turn()
	assert(stream_a.size() > 10, "scripted run produced events")
	assert(stream_a == stream_b, "same seed + same intents = identical event stream")

	# Forced kill path: down a combatant directly, victory fires when enemies gone
	var c2 := _make(7, _sink)
	_events.clear()
	c2.apply_damage("goblin_raider", 999, "pc", true)
	assert(_count("combatant_downed") == 1, "downed event")
	assert(not c2.finished, "one enemy left, not finished")
	c2.apply_damage("goblin_shaman", 999, "pc", true)
	assert(c2.finished and c2.outcome["victory"] == true, "all enemies down = victory")
	assert(_count("combat_finished") == 1, "combat_finished emitted")

	# Round cap: draw counts as non-victory
	var c3 := _make(7, _sink)
	_events.clear()
	while not c3.finished:
		c3.end_turn()
	assert(c3.outcome["draw"] == true and c3.outcome["victory"] == false, "round cap = draw, non-victory")

	# --- skill effects and reactions ---
	var c4 := _make(11, _sink)
	_events.clear()
	# Teleport pc adjacent to raider for controlled melee tests
	c4.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c4.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	# Force pc active regardless of initiative
	c4.active_index = c4.turn_order.find("pc")
	c4._start_turn()
	c4.combatants["pc"][WIKeys.SKILLS] = ["power_strike", "counter_strike", "battle_momentum"]

	# power_strike: costs 3 AP, resolves as melee hit
	assert(c4.use_skill("power_strike", "goblin_raider"), "power strike usable adjacent with 4 AP")
	assert(c4.combatants["pc"][WIKeys.AP] == 1, "power strike cost 3 AP")
	assert(_count("skill_resolved") == 1 and _count("attack_resolved") >= 1, "skill resolved into a hit roll")

	# piercing_strikes: a reported "only works
	# horizontally adjacent" bug. is_adjacent()/damage_mult's gate both read
	# maxi(absi(dx), absi(dy)) <= 1 -- axis-symmetric by construction, no
	# horizontal-only filter anywhere in src/core/combat/*. Positive proof:
	# a VERTICAL-adjacency (dx==0, dy==1) cast succeeds identically to the
	# horizontal case above.
	var c4v := _make(11, _sink)
	_events.clear()
	c4v.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c4v.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(8, 4)
	c4v.active_index = c4v.turn_order.find("pc")
	c4v._start_turn()
	c4v.combatants["pc"][WIKeys.SKILLS] = ["piercing_strikes"]
	assert(c4v.is_adjacent("pc", "goblin_raider"), "vertical neighbors read as adjacent")
	assert(c4v.use_skill("piercing_strikes", "goblin_raider"), "piercing_strikes usable on a vertically-adjacent enemy")
	assert(c4v.combatants["pc"][WIKeys.AP] == 2, "piercing_strikes cost 2 AP")
	assert(_count("skill_resolved") == 1 and _count("attack_resolved") >= 1, "vertical cast resolved into a hit roll")

	# spell_damage: range-checked, refused out of range, never riposted
	var c5 := _make(11, _sink)
	_events.clear()
	c5.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(9, 3)
	c5.combatants["pc"][WIKeys.CELL] = Vector2i(2, 3)
	c5.combatants["pc"][WIKeys.SKILLS] = ["counter_strike"]
	c5.active_index = c5.turn_order.find("goblin_shaman")
	c5._start_turn()
	assert(not c5.use_skill("flame_bolt", "pc"), "flame bolt refused beyond range 4")
	c5.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(5, 3)
	assert(c5.use_skill("flame_bolt", "pc"), "flame bolt in range")
	assert(_count("reaction_triggered") == 0, "spells never trigger riposte")

	# riposte: melee hit on counter_strike holder answers at 0.8, no chains
	var c6 := _make(3, _sink)
	_events.clear()
	c6.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c6.combatants["pc"][WIKeys.SKILLS] = ["counter_strike"]
	c6.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c6.combatants["goblin_raider"][WIKeys.SKILLS] = ["counter_strike"]
	c6.active_index = c6.turn_order.find("goblin_raider")
	c6._start_turn()
	var hits_before: int = _count("attack_resolved")
	c6.attack("pc")
	var raider_hit: bool = false
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved" and e["payload"]["attacker"] == "goblin_raider":
			raider_hit = bool(e["payload"]["hit"])
	if raider_hit:
		assert(_count("reaction_triggered") == 1, "riposte fired once")
		assert(_count("attack_resolved") == hits_before + 2, "exactly one answer, no chains")
	else:
		assert(_count("reaction_triggered") == 0, "no riposte on a miss")

	# battle_momentum: +1 AP on kill, once per turn
	var c7 := _make(5, _sink)
	_events.clear()
	c7.combatants["pc"][WIKeys.SKILLS] = ["battle_momentum"]
	c7.active_index = c7.turn_order.find("pc")
	c7._start_turn()
	c7.combatants["goblin_raider"][WIKeys.HP] = 1
	c7.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c7.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	var ap_before: int = int(c7.combatants["pc"][WIKeys.AP])
	c7.apply_damage("goblin_raider", 1, "pc", true)
	assert(int(c7.combatants["pc"][WIKeys.AP]) == ap_before + 1, "momentum granted +1 AP on kill")
	c7.combatants["goblin_shaman"][WIKeys.HP] = 1
	c7.apply_damage("goblin_shaman", 1, "pc", true)
	assert(c7.finished, "second kill ended combat")
	assert(_count("reaction_triggered") == 1, "momentum capped once per turn")

	# --- Fix: dead active combatant cannot act; turn auto-advances ---
	var c8 := _make(13, _sink)
	_events.clear()
	var victim: String = c8.get_active()
	var killer := ""
	for id: String in c8.combatants:
		if String(c8.combatants[id][WIKeys.SIDE]) != String(c8.combatants[victim][WIKeys.SIDE]):
			killer = id
			break
	c8.apply_damage(victim, 999, killer, true)
	assert(not c8.combatants[victim][WIKeys.ALIVE], "active downed")
	if not c8.finished:
		assert(c8.get_active() != victim, "turn auto-advanced off the dead active")
		assert(_count("turn_ended") >= 1, "turn_ended emitted for the dead active")
	# Intent guard: manually rewind active_index to the dead combatant and try to act
	var idx: int = c8.turn_order.find(victim)
	if idx != -1 and not c8.finished:
		c8.active_index = idx
		assert(not c8.move_active(Vector2i.RIGHT), "dead active cannot move")
		assert(not c8.attack(killer), "dead active cannot attack")

	# --- movement economy — move pool + Dash; status framework ---
	# Locked-design numbers (M3 plan): everything below asserts RELATIVE to the
	# constants, so pin the constants themselves here or a silent retune passes.
	assert(WICombat.MOVE_POOL == 3, "locked design: 3 free move steps per turn")
	assert(WICombat.DASH_GAIN == 3, "locked design: Dash grants +3 steps")
	assert(WICombat.DASH_COST == 1, "locked design: Dash costs 1 AP")
	var c9 := _make(21, _sink)
	_events.clear()
	var mover: String = c9.get_active()
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL, "pool starts at MOVE_POOL on turn start")
	var mover_ap_before: int = int(c9.combatants[mover][WIKeys.AP])
	# Consume the 3-cell free pool with steps in whichever directions stay on the board.
	var pool_dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	var steps_taken := 0
	for i in 3:
		for dir: Vector2i in pool_dirs:
			if c9.move_active(dir):
				steps_taken += 1
				break
	assert(steps_taken == 3, "three free pool steps succeeded")
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == 0, "pool exhausted after 3 steps")
	assert(int(c9.combatants[mover][WIKeys.AP]) == mover_ap_before, "AP untouched by pool-funded movement")
	# 4th step refused at pool 0, AP still untouched
	var any_fourth := false
	for dir: Vector2i in pool_dirs:
		if c9.move_active(dir):
			any_fourth = true
	assert(not any_fourth, "step refused once pool is 0")
	assert(int(c9.combatants[mover][WIKeys.AP]) == mover_ap_before, "refused step costs nothing")

	# Dash: 1 AP -> +3 pool, repeatable
	var ap_pre_dash: int = int(c9.combatants[mover][WIKeys.AP])
	assert(c9.dash(), "dash succeeds with AP available")
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.DASH_GAIN, "dash grants +3 pool")
	assert(int(c9.combatants[mover][WIKeys.AP]) == ap_pre_dash - WICombat.DASH_COST, "dash costs 1 AP")
	assert(_count("dashed") == 1, "dashed event emitted")
	var found_dash_payload := false
	for e: Dictionary in _events:
		if e["type"] == "dashed" and e["payload"][WIKeys.ID] == mover and int(e["payload"][WIKeys.MOVE_POOL]) == WICombat.DASH_GAIN:
			found_dash_payload = true
	assert(found_dash_payload, "dashed payload carries id + move_pool")
	assert(_count("ap_changed") >= 1, "dash also emits ap_changed")
	# Now 3 more steps possible thanks to the dash
	var post_dash_steps := 0
	for i in 3:
		for dir: Vector2i in pool_dirs:
			if c9.move_active(dir):
				post_dash_steps += 1
				break
	assert(post_dash_steps == 3, "dash enabled 3 more steps")
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == 0, "pool exhausted again")

	# Repeated dash while AP lasts
	var ap_before_second_dash: int = int(c9.combatants[mover][WIKeys.AP])
	if ap_before_second_dash >= WICombat.DASH_COST:
		assert(c9.dash(), "dash is repeatable while AP lasts")
		assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.DASH_GAIN, "second dash also grants +3 pool")

	# Drain AP to 0, then dash refused
	c9.combatants[mover][WIKeys.AP] = 0
	assert(not c9.dash(), "dash refused at 0 AP")
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.DASH_GAIN, "pool unchanged by refused dash")

	# Attack still costs 2 AP and is unaffected by move pool
	var c10 := _make(11, _sink)
	_events.clear()
	c10.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c10.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c10.active_index = c10.turn_order.find("pc")
	c10._start_turn()
	var pc_ap_before_atk: int = int(c10.combatants["pc"][WIKeys.AP])
	var pc_pool_before_atk: int = int(c10.combatants["pc"][WIKeys.MOVE_POOL])
	assert(c10.attack("goblin_raider"), "attack still works adjacent")
	assert(int(c10.combatants["pc"][WIKeys.AP]) == pc_ap_before_atk - WICombat.ATTACK_COST, "attack still costs 2 AP")
	assert(int(c10.combatants["pc"][WIKeys.MOVE_POOL]) == pc_pool_before_atk, "attack does not touch move pool")

	# turn_started payload + snapshot combatants carry move_pool
	var c11 := _make(11, _sink)
	_events.clear()
	c11.end_turn()
	var ts_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "turn_started":
			ts_payload = e["payload"]
	assert(ts_payload.has(WIKeys.MOVE_POOL) and int(ts_payload[WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL, "turn_started payload carries move_pool")
	var snap := c11.snapshot()
	var snap_active: String = String(snap["active"])
	assert((snap["combatants"][snap_active] as Dictionary).has(WIKeys.MOVE_POOL), "snapshot combatants carry move_pool")
	assert(int(snap["combatants"][snap_active][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL, "snapshot move_pool matches turn start")

	# Determinism holds with a dash inserted into the scripted intent stream
	var stream_c: Array = []
	var stream_d: Array = []
	for stream: Array in [stream_c, stream_d]:
		var ev := func(type: String, payload: Dictionary) -> void:
			stream.append(JSON.stringify({"t": type, "p": payload}))
		var c := _make(99, ev)
		for i in 40:
			if c.finished:
				break
			if i == 5:
				c.dash()
				continue
			if not c.move_active(Vector2i.LEFT):
				if not c.move_active(Vector2i.UP):
					c.end_turn()
	assert(stream_c.size() > 10, "scripted run with dash produced events")
	assert(stream_c == stream_d, "same seed + same intents incl. dash = identical event stream")

	# Statuses framework: slowed reduces next turn's pool and expires after applying
	var c12 := _make(11, _sink)
	_events.clear()
	var slowed_id: String = c12.get_active()
	c12.combatants[slowed_id]["statuses"]["slowed"] = {"pool_penalty": 2}
	c12.end_turn()
	# Cycle back to slowed_id's next turn
	var guard := 0
	while c12.get_active() != slowed_id and guard < 8:
		c12.end_turn()
		guard += 1
	assert(c12.get_active() == slowed_id, "cycled back to the slowed combatant's turn")
	assert(int(c12.combatants[slowed_id][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL - 2, "slowed reduces pool by penalty")
	assert(not (c12.combatants[slowed_id]["statuses"] as Dictionary).has("slowed"), "slowed status expired after applying")
	assert(_count("status_expired") == 1, "status_expired emitted once")
	var expired_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_expired":
			expired_payload = e["payload"]
	assert(expired_payload.get(WIKeys.ID, "") == slowed_id and expired_payload.get("status", "") == "slowed", "status_expired payload carries id + status")

	# Slowed pool floor: penalty >= MOVE_POOL still leaves a minimum of 1
	var c13 := _make(11, _sink)
	_events.clear()
	var floor_id: String = c13.get_active()
	c13.combatants[floor_id]["statuses"]["slowed"] = {"pool_penalty": 99}
	c13.end_turn()
	guard = 0
	while c13.get_active() != floor_id and guard < 8:
		c13.end_turn()
		guard += 1
	assert(c13.get_active() == floor_id, "cycled back to the floor-test combatant's turn")
	assert(int(c13.combatants[floor_id][WIKeys.MOVE_POOL]) == 1, "slowed pool floors at 1, never 0 or negative")

	# --- line-of-sight ---
	# Arena fixture: goblin_ambush blocks (5,3),(6,4),(3,5),(8,2).
	var c14 := _make(11, _sink)
	_events.clear()
	# Wall between: pc(4,3) <-> raider(6,3), blocked cell (5,3) sits between them.
	c14.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c14.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	assert(not c14.has_los("pc", "goblin_raider"), "wall between blocks LoS")
	# Adjacent gap: pc(4,3) <-> shaman(4,4), no wall between, and they're adjacent.
	c14.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(4, 4)
	assert(c14.has_los("pc", "goblin_shaman"), "clear adjacent gap has LoS")
	# Symmetry: LoS is the same walked backwards.
	assert(c14.has_los("goblin_shaman", "pc") == c14.has_los("pc", "goblin_shaman"), "LoS is symmetric")
	# Entities do not block LoS: put shaman directly between pc and raider on a clear row.
	c14.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c14.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 1)
	c14.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(2, 1)
	assert(c14.has_los("pc", "goblin_raider"), "occupants do not block LoS, only walls")

	# Ranged spell refused without LoS; melee exempt (adjacency check happens separately).
	var c15 := _make(11, _sink)
	_events.clear()
	c15.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c15.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(6, 3)
	c15.combatants["pc"][WIKeys.SKILLS] = []
	c15.active_index = c15.turn_order.find("goblin_shaman")
	c15._start_turn()
	assert(not c15.use_skill("flame_bolt", "pc"), "spell refused through a wall despite being in range")
	var refusal_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "action_refused":
			refusal_payload = e["payload"]
	assert(refusal_payload.get("reason", "") == "no_los", "no_los action_refused emitted")
	assert(refusal_payload.get("actor", "") == "goblin_shaman" and refusal_payload.get("target", "") == "pc", "refusal payload carries actor+target")
	# Move the shaman off the wall row: now in range and in LoS, spell lands.
	c15.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(4, 1)
	c15.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	assert(c15.use_skill("flame_bolt", "pc"), "spell allowed with clear LoS")
	# Melee attack is exempt from LoS gating (adjacency across a corner is still allowed).
	var c16 := _make(11, _sink)
	_events.clear()
	c16.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c16.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 2)
	c16.active_index = c16.turn_order.find("pc")
	c16._start_turn()
	assert(c16.attack("goblin_raider"), "melee attack is exempt from LoS gating")

	# --- has_los supercover symmetry ---
	# A single Bresenham raster picks one arbitrary path per direction and can
	# disagree on diagonally-adjacent wall pairs; the supercover walk enumerates
	# every cell the ideal segment crosses (a direction-independent geometric
	# fact), so the answer must be identical whichever endpoint you start from.
	var c22 := _make(11, _sink)
	# Exact reproduced asymmetry pair on the goblin_ambush blocked set
	# {(5,3),(6,4),(3,5),(8,2)}.
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 6)
	assert(c22.has_los("pc", "goblin_raider") == c22.has_los("goblin_raider", "pc"), "has_los symmetric on the reproduced asymmetry pair")

	# Property sweep: 8 fixed probe cells, every ordered pair symmetric.
	var probe_cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(11, 7), Vector2i(0, 7), Vector2i(11, 0),
		Vector2i(4, 4), Vector2i(7, 1), Vector2i(2, 6), Vector2i(9, 5),
	]
	for pa: Vector2i in probe_cells:
		for pb: Vector2i in probe_cells:
			if pa == pb:
				continue
			c22.combatants["pc"][WIKeys.CELL] = pa
			c22.combatants["goblin_raider"][WIKeys.CELL] = pb
			var fwd := c22.has_los("pc", "goblin_raider")
			var back := c22.has_los("goblin_raider", "pc")
			assert(fwd == back, "has_los symmetric for probe pair %s <-> %s" % [pa, pb])

	# Sanity: clear corridor has LoS.
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(0, 2)
	assert(c22.has_los("pc", "goblin_raider"), "clear corridor has LoS")
	# Sanity: wall directly between blocks.
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	assert(not c22.has_los("pc", "goblin_raider"), "wall directly between blocks LoS")
	# Sanity: adjacent cells always have LoS (no room for an intermediate cell).
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(5, 5)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 5)
	assert(c22.has_los("pc", "goblin_raider"), "adjacent cells always have LoS")
	# Sanity: diagonal wall pair (5,3)/(6,4) blocks LoS in BOTH directions across
	# the other diagonal of that same 2x2 block (corner rule).
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(5, 4)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	assert(not c22.has_los("pc", "goblin_raider"), "diagonal wall pair blocks LoS forward")
	assert(not c22.has_los("goblin_raider", "pc"), "diagonal wall pair blocks LoS backward")

	# --- line_cells enumeration ---
	var c17 := _make(11, _sink)
	# Clear line, length 4, rightward from (0,0): all 4 cells in bounds and unblocked.
	var cells_clear: Array[Vector2i] = c17.line_cells(Vector2i(0, 0), Vector2i.RIGHT, 4)
	assert(cells_clear == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "clear line enumerates length cells in direction")
	# Bounds clip: rightward from (10,0) in a 12-wide grid only has room for 1 cell (11,0).
	var cells_bound: Array[Vector2i] = c17.line_cells(Vector2i(10, 0), Vector2i.RIGHT, 4)
	assert(cells_bound == [Vector2i(11, 0)], "line clips at grid bounds")
	# Wall clip: rightward from (3,3) hits blocked (5,3); the line stops there (wall blocks fire)
	# and does not continue past it, even though occupants would not have stopped it.
	var cells_wall: Array[Vector2i] = c17.line_cells(Vector2i(3, 3), Vector2i.RIGHT, 4)
	assert(cells_wall == [Vector2i(4, 3), Vector2i(5, 3)], "line stops at first blocked cell (inclusive)")
	# Occupants do not clip the line: put an ally in the path, the line still walks through.
	c17.combatants["relc"][WIKeys.CELL] = Vector2i(1, 0)
	var cells_occupant: Array[Vector2i] = c17.line_cells(Vector2i(0, 0), Vector2i.RIGHT, 4)
	assert(cells_occupant == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "occupants do not clip the line")

	# --- Flame Jet line_damage — friendly fire, cells + hit_ids on skill_resolved ---
	var c18 := _make(11, _sink)
	_events.clear()
	c18.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c18.combatants["relc"][WIKeys.CELL] = Vector2i(2, 0)  # ally in the line: friendly fire
	c18.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 0)  # enemy in the line
	c18.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(7, 7)  # out of the line entirely
	c18.combatants["pc"][WIKeys.SKILLS] = ["flame_jet"]
	c18.combatants["pc"][WIKeys.MP] = 10  # pc built with no spells (mp 0); T4 MP gate needs enough to cast
	c18.active_index = c18.turn_order.find("pc")
	c18._start_turn()
	var relc_hp_before: int = int(c18.combatants["relc"][WIKeys.HP])
	var raider_hp_before: int = int(c18.combatants["goblin_raider"][WIKeys.HP])
	assert(c18.use_skill("flame_jet", "right"), "flame jet resolves with a direction token target")
	assert(_count("skill_resolved") == 1, "flame jet emits exactly one skill_resolved")
	var jet_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			jet_payload = e["payload"]
	assert(jet_payload.has("cells") and (jet_payload["cells"] as Array).size() == 4, "skill_resolved carries the 4 walked cells")
	var jet_hit_ids: Array = jet_payload.get("hit_ids", [])
	assert(jet_hit_ids.has("relc") and jet_hit_ids.has("goblin_raider"), "hit_ids includes both the ally and the enemy in the line")
	assert(not jet_hit_ids.has("goblin_shaman"), "combatant outside the line is not hit")
	# Both victims actually took an attack_resolved roll (melee=false, no riposte possible from a line).
	var jet_targets_seen: Array = []
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			assert(bool(e["payload"]["melee"]) == false, "line hits are non-melee")
			jet_targets_seen.append(String(e["payload"]["target"]))
	assert(jet_targets_seen.has("relc") and jet_targets_seen.has("goblin_raider"), "both ally and enemy got an attack_resolved roll")
	assert(_count("reaction_triggered") == 0, "line hits never trigger riposte")
	assert(int(c18.combatants["relc"][WIKeys.HP]) <= relc_hp_before, "ally in the line can take real damage (friendly fire)")
	assert(int(c18.combatants["goblin_raider"][WIKeys.HP]) <= raider_hp_before, "enemy in the line can take real damage")

	# Non-cardinal / bad direction tokens are refused outright.
	var c19 := _make(11, _sink)
	_events.clear()
	c19.combatants["pc"][WIKeys.SKILLS] = ["flame_jet"]
	c19.active_index = c19.turn_order.find("pc")
	c19._start_turn()
	assert(not c19.use_skill("flame_jet", "diagonal"), "non-cardinal direction token refused")
	assert(_count("skill_resolved") == 0, "refused line does not resolve")

	# --- line_damage refused when its first cell is a wall ---
	var c23 := _make(11, _sink)
	_events.clear()
	c23.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)  # (5,3) is blocked, directly to the right
	c23.combatants["pc"][WIKeys.SKILLS] = ["flame_jet"]
	c23.combatants["pc"][WIKeys.MP] = 10  # pc built with no spells (mp 0); T4 MP gate needs enough to cast
	c23.active_index = c23.turn_order.find("pc")
	c23._start_turn()
	var pc_ap_before_jet: int = int(c23.combatants["pc"][WIKeys.AP])
	assert(not c23.use_skill("flame_jet", "right"), "line_damage refused when its first cell is a wall")
	assert(_count("skill_resolved") == 0, "refused line does not resolve")
	var jet_refusal: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "action_refused":
			jet_refusal = e["payload"]
	assert(jet_refusal.get("reason", "") == "no_los", "wall-blocked line emits no_los action_refused")
	assert(int(c23.combatants["pc"][WIKeys.AP]) == pc_ap_before_jet, "refused line-cast costs no AP")

	# --- frost_bolt applies slowed on hit ---
	var c20 := _make(2, _sink)
	_events.clear()
	c20.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c20.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 1)
	c20.combatants["pc"][WIKeys.SKILLS] = ["frost_bolt"]
	c20.active_index = c20.turn_order.find("pc")
	c20._start_turn()
	var raider_pool_baseline := WICombat.MOVE_POOL
	var found_slowed_seed := false
	for try_seed in range(2, 40):
		var cx := _make(try_seed, _sink)
		_events.clear()
		cx.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
		cx.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 1)
		cx.combatants["pc"][WIKeys.SKILLS] = ["frost_bolt"]
		cx.combatants["pc"][WIKeys.MP] = 10  # pc built with no spells (mp 0); T4 MP gate needs enough to cast
		cx.active_index = cx.turn_order.find("pc")
		cx._start_turn()
		cx.use_skill("frost_bolt", "goblin_raider")
		var hit_landed := false
		for e: Dictionary in _events:
			if e["type"] == "attack_resolved" and e["payload"]["target"] == "goblin_raider" and bool(e["payload"]["hit"]):
				hit_landed = true
		if not hit_landed:
			continue
		found_slowed_seed = true
		assert((cx.combatants["goblin_raider"]["statuses"] as Dictionary).has("slowed"), "frost bolt hit applies slowed to the victim")
		var applied_payload: Dictionary = {}
		for e: Dictionary in _events:
			if e["type"] == "status_applied":
				applied_payload = e["payload"]
		assert(applied_payload.get(WIKeys.ID, "") == "goblin_raider" and applied_payload.get("status", "") == "slowed", "status_applied emitted for the victim")
		# Advance to the raider's next turn: pool should be reduced by the penalty, then status expires.
		var target_id := "goblin_raider"
		var g := 0
		while cx.get_active() != target_id and g < 8:
			cx.end_turn()
			g += 1
		assert(cx.get_active() == target_id, "cycled to the slowed victim's turn")
		assert(int(cx.combatants[target_id][WIKeys.MOVE_POOL]) == raider_pool_baseline - 2, "slowed applied the pool_penalty on the victim's next turn")
		assert(not (cx.combatants[target_id]["statuses"] as Dictionary).has("slowed"), "slowed expired after applying once")
		break
	assert(found_slowed_seed, "found at least one seed where frost bolt hit, to verify slowed application")

	# --- AI never selects a line whose cells include an ally ---
	var c21 := _make(11, _sink)
	_events.clear()
	# Force a fixture: shaman (ranged AI) knows flame_jet; placing an ally goblin_raider
	# directly between the shaman and TWO enemies means the only multi-hit line also
	# hits an ally (two enemies so the T4 >=2-enemy line gate is satisfied — ally-safety
	# is the check actually refusing here).
	c21.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c21.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(1, 0)  # ally, in the only sensible line
	c21.combatants["pc"][WIKeys.CELL] = Vector2i(3, 0)
	c21.combatants["relc"][WIKeys.CELL] = Vector2i(4, 0)  # second enemy in the same line
	c21.combatants["goblin_shaman"][WIKeys.SKILLS] = ["flame_jet"]
	c21.combatants["goblin_shaman"][WIKeys.MP] = 10  # built with no spells (mp 0); give enough so the ally check is the actual gate
	c21.combatants["goblin_shaman"][WIKeys.AI] = "ranged"
	c21.active_index = c21.turn_order.find("goblin_shaman")
	c21._start_turn()
	WICombatAI.take_turn(c21)
	assert(_count("skill_resolved") == 0, "line-capable AI refuses to cast a line that would hit its own ally")

	# --- second slow on an already-slowed victim is a flat refresh ---
	var c24 := _make(11, _sink)
	_events.clear()
	var refresh_id: String = c24.get_active()
	# Simulate two independent slow applications landing on the same victim before
	# their next turn (e.g. two frost bolts) -- the applies-write site is a flat
	# key assignment (never appends/stacks), so this must collapse to one entry.
	c24.combatants[refresh_id]["statuses"]["slowed"] = {"pool_penalty": 2}
	c24.combatants[refresh_id]["statuses"]["slowed"] = {"pool_penalty": 2}
	assert((c24.combatants[refresh_id]["statuses"] as Dictionary).size() == 1, "two slow applications collapse to a single status entry")
	c24.end_turn()
	var guard2 := 0
	while c24.get_active() != refresh_id and guard2 < 8:
		c24.end_turn()
		guard2 += 1
	assert(c24.get_active() == refresh_id, "cycled back to the double-slowed combatant's turn")
	assert(int(c24.combatants[refresh_id][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL - 2, "exactly one penalty applied, not doubled")
	assert(not (c24.combatants[refresh_id]["statuses"] as Dictionary).has("slowed"), "slowed expired exactly once")
	assert(_count("status_expired") == 1, "exactly one status_expired despite two applications")

	# --- MP pool build ---
	var c25 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "quick_cast"]}})
	assert(int(c25.combatants["pc"][WIKeys.MAX_MP]) == 8 + int(8 / 2), "max_mp = 8 + int(INT/2) for a combatant with a spell")
	assert(int(c25.combatants["pc"][WIKeys.MP]) == int(c25.combatants["pc"][WIKeys.MAX_MP]), "mp starts at max_mp")
	assert(int(c25.combatants["goblin_raider"][WIKeys.MAX_MP]) == 0, "non-mage (no mp_cost skills) has max_mp 0")
	assert(int(c25.combatants["goblin_raider"][WIKeys.MP]) == 0, "non-mage mp is 0")
	var snap25 := c25.snapshot()
	assert((snap25["combatants"]["pc"] as Dictionary).has(WIKeys.MP) and (snap25["combatants"]["pc"] as Dictionary).has(WIKeys.MAX_MP), "snapshot combatants carry mp/max_mp")

	# --- spell refused on insufficient MP; refusal costs nothing ---
	var c26 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt"]}})
	_events.clear()
	c26.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c26.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 1)
	c26.active_index = c26.turn_order.find("pc")
	c26._start_turn()
	c26.combatants["pc"][WIKeys.MP] = 1  # frost_bolt costs 2 MP
	var ap_before26: int = int(c26.combatants["pc"][WIKeys.AP])
	assert(not c26.use_skill("frost_bolt", "goblin_raider"), "spell refused when MP is insufficient")
	assert(int(c26.combatants["pc"][WIKeys.AP]) == ap_before26, "MP-refused spell costs no AP")
	assert(int(c26.combatants["pc"][WIKeys.MP]) == 1, "MP-refused spell costs no MP")
	assert(_count("skill_resolved") == 0, "MP-refused spell never resolves")
	c26.combatants["pc"][WIKeys.MP] = 2
	assert(c26.use_skill("frost_bolt", "goblin_raider"), "spell succeeds once MP is sufficient")

	# --- Quick Cast discounts exactly the first spell each turn ---
	var c27 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "flame_jet", "quick_cast"]}})
	_events.clear()
	c27.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c27.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 1)
	c27.active_index = c27.turn_order.find("pc")
	c27._start_turn()
	var ap0: int = int(c27.combatants["pc"][WIKeys.AP])
	assert(c27.use_skill("frost_bolt", "goblin_raider"), "first spell of the turn succeeds")
	assert(int(c27.combatants["pc"][WIKeys.AP]) == ap0, "quick_cast discounts the first spell's AP cost (1 - 1 = 0)")
	assert(int(c27.combatants["pc"][WIKeys.MP]) == int(c27.combatants["pc"][WIKeys.MAX_MP]) - 2, "MP is charged in full even though AP was discounted")
	var ap_before_second: int = int(c27.combatants["pc"][WIKeys.AP])
	assert(c27.use_skill("flame_jet", "right"), "second spell of the turn succeeds")
	assert(int(c27.combatants["pc"][WIKeys.AP]) == ap_before_second - 2, "second spell of the turn costs full AP: the discount is spent")
	c27.end_turn()
	var guard27 := 0
	while c27.get_active() != "pc" and guard27 < 8:
		c27.end_turn()
		guard27 += 1
	assert(c27.get_active() == "pc", "cycled back to pc's next turn")
	var ap1: int = int(c27.combatants["pc"][WIKeys.AP])
	assert(c27.use_skill("frost_bolt", "goblin_raider"), "spell succeeds on the new turn")
	assert(int(c27.combatants["pc"][WIKeys.AP]) == ap1, "quick_cast's discount resets each turn (_start_turn)")

	# --- Mana Shield absorbs damage into MP before HP ---
	var c28 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "mana_shield"]}})
	_events.clear()
	var mp28: int = int(c28.combatants["pc"][WIKeys.MP])
	var hp28: int = int(c28.combatants["pc"][WIKeys.HP])
	c28.apply_damage("pc", 4, "goblin_raider", true)
	assert(int(c28.combatants["pc"][WIKeys.MP]) == mp28 - 4, "mana shield absorbs damage from MP before HP")
	assert(int(c28.combatants["pc"][WIKeys.HP]) == hp28, "HP untouched when MP fully absorbs the hit")
	assert(_count("reaction_triggered") == 1, "mana shield reaction fired")
	assert(_count("mp_changed") == 1, "mp_changed emitted for the absorb")
	var shield_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "reaction_triggered" and e["payload"].get("skill", "") == "mana_shield":
			shield_payload = e["payload"]
	assert(shield_payload.get(WIKeys.ID, "") == "pc" and int(shield_payload.get("absorbed", -1)) == 4, "reaction payload carries id + absorbed amount")

	# Partial absorb: damage exceeds remaining MP, splits between MP and HP.
	_events.clear()
	c28.combatants["pc"][WIKeys.MP] = 4
	var hp_before_partial: int = int(c28.combatants["pc"][WIKeys.HP])
	c28.apply_damage("pc", 6, "goblin_raider", true)
	assert(int(c28.combatants["pc"][WIKeys.MP]) == 0, "partial absorb drains all remaining MP")
	assert(int(c28.combatants["pc"][WIKeys.HP]) == hp_before_partial - 2, "the 2 unabsorbed damage lands on HP")
	var partial_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "reaction_triggered":
			partial_payload = e["payload"]
	assert(int(partial_payload.get("absorbed", -1)) == 4, "partial absorb payload reports only the MP actually spent")

	# Inert at 0 MP: full damage goes to HP, no reaction fires.
	_events.clear()
	var hp_before_inert: int = int(c28.combatants["pc"][WIKeys.HP])
	c28.apply_damage("pc", 5, "goblin_raider", true)
	assert(int(c28.combatants["pc"][WIKeys.HP]) == hp_before_inert - 5, "shield inert at 0 MP: full damage to HP")
	assert(_count("reaction_triggered") == 0, "no reaction fires once MP is empty")

	# --- regression — riposte still never triggers on spell hits ---
	var c29 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt"]}})
	_events.clear()
	c29.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(1, 1)
	c29.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c29.combatants["goblin_raider"][WIKeys.SKILLS] = ["counter_strike"]
	c29.active_index = c29.turn_order.find("pc")
	c29._start_turn()
	assert(c29.use_skill("frost_bolt", "goblin_raider"), "spell cast succeeds against a counter_strike holder")
	assert(_count("reaction_triggered") == 0, "spells never trigger riposte, even against a counter_strike holder with MP wired in")

	# --- determinism holds through a spell-heavy scripted stream ---
	var stream_e: Array = []
	var stream_f: Array = []
	for stream: Array in [stream_e, stream_f]:
		var ev := func(type: String, payload: Dictionary) -> void:
			stream.append(JSON.stringify({"t": type, "p": payload}))
		var c := _make_custom(77, ev, {"pc": {WIKeys.SKILLS: ["frost_bolt", "flame_jet", "quick_cast", "mana_shield"]}})
		for i in 30:
			if c.finished:
				break
			var active_id := c.get_active()
			var ac: Dictionary = c.combatants[active_id]
			if (ac[WIKeys.SKILLS] as Array).has("frost_bolt") and c.use_skill("frost_bolt", "goblin_raider"):
				continue
			if (ac[WIKeys.SKILLS] as Array).has("flame_jet") and c.use_skill("flame_jet", "right"):
				continue
			c.end_turn()
	assert(stream_e.size() > 5, "spell-heavy scripted run produced events")
	assert(stream_e == stream_f, "same seed + same spell-heavy intents = identical event stream")

	# --- AI skips spells it cannot afford (MP) ---
	var c30 := _make(11, _sink)
	_events.clear()
	c30.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(1, 1)
	c30.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c30.combatants["goblin_shaman"][WIKeys.SKILLS] = ["frost_bolt"]
	# Built with flame_bolt (no mp_cost) so mp/max_mp are 0: frost_bolt is unaffordable.
	assert(int(c30.combatants["goblin_shaman"][WIKeys.MP]) == 0, "fixture: shaman has no MP")
	c30.active_index = c30.turn_order.find("goblin_shaman")
	c30._start_turn()
	WICombatAI.take_turn(c30)
	assert(_count("skill_resolved") == 0, "AI never casts a spell it cannot pay MP for")
	assert(_count("mp_changed") == 0, "no MP was spent by the skipped cast")

	# --- AI prefers flame_jet when >=2 enemies share an ally-free line ---
	var c31 := _make(11, _sink)
	_events.clear()
	c31.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c31.combatants["pc"][WIKeys.CELL] = Vector2i(1, 0)
	c31.combatants["relc"][WIKeys.CELL] = Vector2i(3, 0)  # two enemies share the rightward line
	c31.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(7, 7)  # ally well clear of it
	c31.combatants["goblin_shaman"][WIKeys.SKILLS] = ["flame_jet", "frost_bolt"]
	c31.combatants["goblin_shaman"][WIKeys.MP] = 10
	c31.active_index = c31.turn_order.find("goblin_shaman")
	c31._start_turn()
	WICombatAI.take_turn(c31)
	var first_skill31 := ""
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and first_skill31 == "":
			first_skill31 = String(e["payload"]["skill"])
	assert(first_skill31 == "flame_jet", "AI opens with flame_jet when two enemies share an ally-free line")

	# Single enemy in the line: the multi-hit gate fails, AI falls through to the
	# single-target spell instead of burning 4 MP on one victim.
	var c32 := _make(11, _sink)
	_events.clear()
	c32.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c32.combatants["pc"][WIKeys.CELL] = Vector2i(2, 0)
	c32.combatants["relc"][WIKeys.CELL] = Vector2i(7, 6)
	c32.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(7, 7)
	c32.combatants["goblin_shaman"][WIKeys.SKILLS] = ["flame_jet", "frost_bolt"]
	c32.combatants["goblin_shaman"][WIKeys.MP] = 10
	c32.active_index = c32.turn_order.find("goblin_shaman")
	c32._start_turn()
	WICombatAI.take_turn(c32)
	var first_skill32 := ""
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and first_skill32 == "":
			first_skill32 = String(e["payload"]["skill"])
	assert(first_skill32 == "frost_bolt", "AI prefers the single-target spell when only one enemy is in the line")

	# --- "inert" AI profile (training dummies) ---
	# The dummies never act at all (no block mechanics exist, so standing
	# still is correct design, not AI weakness -- onboarding-rev spec §2).
	# Force the dummy adjacent to pc so a REAL melee profile would clearly
	# attack; inert must still refuse to do anything at all.
	var c53 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "training_dummy_a"]), _load("res://data/skills.json"), _sink, 5)
	c53.begin()
	c53.combatants["pc"][WIKeys.CELL] = Vector2i(3, 3)
	c53.combatants["training_dummy_a"][WIKeys.CELL] = Vector2i(4, 3)
	assert(String(c53.combatants["training_dummy_a"][WIKeys.AI]) == "inert", "fixture: training_dummy_a carries the inert AI profile")
	c53.active_index = c53.turn_order.find("training_dummy_a")
	c53._start_turn()
	var dummy_pool_before := int(c53.combatants["training_dummy_a"][WIKeys.MOVE_POOL])
	_events.clear()
	WICombatAI.take_turn(c53)
	assert(_count("attack_resolved") == 0, "inert dummy never attacks even adjacent to a valid target")
	assert(_count("skill_resolved") == 0, "inert dummy never uses a skill")
	assert(c53.combatants["training_dummy_a"][WIKeys.CELL] == Vector2i(4, 3), "inert dummy never moves")
	assert(int(c53.combatants["training_dummy_a"][WIKeys.MOVE_POOL]) == dummy_pool_before, "inert dummy's move_pool is untouched (no dash, no move)")
	assert(_count("turn_ended") == 1, "inert dummy's turn ends immediately -- exactly one turn_ended, no action attempted first")
	assert(c53.get_active() != "training_dummy_a", "turn advanced off the inert dummy")

	# Across a full autoplay fight (same idiom as qa/test_driver.gd's shipped
	# combat_autoplay step: WICombatAI.take_turn(combat) called every turn
	# regardless of side), a dummy must never once appear as an attacker.
	var c54 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "training_dummy_a", "training_dummy_b"]), _load("res://data/skills.json"), _sink, 5)
	c54.begin()
	_events.clear()
	var guard54 := 0
	while not c54.finished and guard54 < 60:
		guard54 += 1
		WICombatAI.take_turn(c54)
	assert(c54.finished, "scripted autoplay fight (pc vs two inert dummies) reaches a resolution")
	assert(bool(c54.outcome.get("victory", false)), "pc wins trivially against zero-offense inert dummies")
	var dummy_attacked := false
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved" and String(e["payload"].get("attacker", "")).begins_with("training_dummy"):
			dummy_attacked = true
	assert(not dummy_attacked, "no attack_resolved ever names a dummy as attacker across the full autoplay fight")

	# --- per-fight action tally (spec §2.1 REV 2) ---
	# Counters accumulate per actor as actions resolve; skill counters come
	# from skills.json weapon/element tags. hit_bonus ±1000 forces guaranteed
	# hits/misses (hit_chance = BASE_HIT + hit_bonus - dex/4), so no seed
	# search is needed and the fight's rng consumption is unchanged.
	var c33 := _make(11, _sink)
	assert(c33.action_tally.is_empty(), "tally starts empty")
	c33.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c33.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c33.combatants["goblin_raider"][WIKeys.HP] = 999
	c33.combatants["pc"]["hit_bonus"] = 1000
	c33.active_index = c33.turn_order.find("pc")
	c33._start_turn()
	assert(c33.attack("goblin_raider"), "guaranteed-hit attack lands")
	assert(int((c33.action_tally.get("pc", {}) as Dictionary).get("melee_hit", 0)) == 1, "melee hit tallied for the attacker")
	assert(c33.attack("goblin_raider"), "second attack lands")
	assert(int((c33.action_tally.get("pc", {}) as Dictionary).get("melee_hit", 0)) == 2, "tally accumulates per hit")
	assert(not c33.action_tally.has("goblin_raider"), "the victim tallies nothing")

	# A guaranteed miss tallies no melee_hit: hits count, swings do not.
	var c34 := _make(11, _sink)
	c34.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c34.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c34.combatants["pc"]["hit_bonus"] = -1000
	c34.active_index = c34.turn_order.find("pc")
	c34._start_turn()
	assert(c34.attack("goblin_raider"), "the attack action itself still resolves")
	assert(int((c34.action_tally.get("pc", {}) as Dictionary).get("melee_hit", 0)) == 0, "missed swing tallies nothing")

	# power_strike is sword-tagged in skills.json: casting tallies
	# sword_skill_used, and its guaranteed hit also tallies melee_hit
	# (a sword-skill hit IS a melee hit).
	var c35 := _make(11, _sink)
	c35.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c35.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c35.combatants["goblin_raider"][WIKeys.HP] = 999
	c35.combatants["pc"][WIKeys.SKILLS] = ["power_strike"]
	c35.combatants["pc"]["hit_bonus"] = 1000
	c35.active_index = c35.turn_order.find("pc")
	c35._start_turn()
	assert(c35.use_skill("power_strike", "goblin_raider"), "power strike lands")
	var t35: Dictionary = c35.action_tally.get("pc", {})
	assert(int(t35.get("sword_skill_used", 0)) == 1, "sword-tagged skill use tallied")
	assert(int(t35.get("melee_hit", 0)) == 1, "sword-skill hit also tallies melee_hit")
	assert(int(t35.get("spell_cast", 0)) == 0, "a melee skill is not a spell cast")

	# A missed power_strike still counts the USE (the deed is swinging the
	# skill) but no melee_hit.
	var c36 := _make(11, _sink)
	c36.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c36.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c36.combatants["pc"][WIKeys.SKILLS] = ["power_strike"]
	c36.combatants["pc"]["hit_bonus"] = -1000
	c36.active_index = c36.turn_order.find("pc")
	c36._start_turn()
	assert(c36.use_skill("power_strike", "goblin_raider"), "missed power strike still casts")
	var t36: Dictionary = c36.action_tally.get("pc", {})
	assert(int(t36.get("sword_skill_used", 0)) == 1, "use tallied on a miss")
	assert(int(t36.get("melee_hit", 0)) == 0, "no melee_hit on a miss")

	# Spell casts tally spell_cast + the element counter from the skills.json
	# element tag, hit or miss; never melee_hit.
	var c37 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "flame_jet"]}})
	c37.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c37.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 1)
	c37.combatants["goblin_raider"][WIKeys.HP] = 999
	c37.active_index = c37.turn_order.find("pc")
	c37._start_turn()
	assert(c37.use_skill("frost_bolt", "goblin_raider"), "frost bolt cast")
	var t37: Dictionary = c37.action_tally.get("pc", {})
	assert(int(t37.get("spell_cast", 0)) == 1, "spell_cast tallied")
	assert(int(t37.get("ice_cast", 0)) == 1, "ice element tallied from the skill tag")
	assert(int(t37.get("fire_cast", 0)) == 0, "no fire counter from an ice spell")
	assert(int(t37.get("melee_hit", 0)) == 0, "spells never tally melee_hit")
	assert(c37.use_skill("flame_jet", "right"), "flame jet cast")
	t37 = c37.action_tally.get("pc", {})
	assert(int(t37.get("spell_cast", 0)) == 2, "second cast accumulates spell_cast")
	assert(int(t37.get("fire_cast", 0)) == 1, "fire element tallied for flame_jet")
	assert(int(t37.get("ice_cast", 0)) == 1, "ice counter untouched by the fire cast")

	# Enemy casts tally under the enemy's own id (per-actor tally).
	var c38 := _make(11, _sink)
	c38.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(1, 1)
	c38.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c38.active_index = c38.turn_order.find("goblin_shaman")
	c38._start_turn()
	assert(c38.use_skill("flame_bolt", "pc"), "shaman flame bolt cast")
	var t38: Dictionary = c38.action_tally.get("goblin_shaman", {})
	assert(int(t38.get("spell_cast", 0)) == 1, "enemy spell_cast tallied under the shaman")
	assert(int(t38.get("fire_cast", 0)) == 1, "flame_bolt carries the fire tag")

	# Refused casts tally nothing (out of range, then insufficient MP): the
	# tally hook sits at the spend site, which refusal paths never reach.
	var c39 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt"]}})
	c39.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c39.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 1)
	c39.active_index = c39.turn_order.find("pc")
	c39._start_turn()
	assert(not c39.use_skill("frost_bolt", "goblin_raider"), "out-of-range cast refused")
	c39.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 1)
	c39.combatants["pc"][WIKeys.MP] = 1
	assert(not c39.use_skill("frost_bolt", "goblin_raider"), "MP-starved cast refused")
	assert(c39.action_tally.is_empty(), "refused casts tally nothing")

	# Riposte hits are the defender's deed: a landed counter_strike answer
	# tallies melee_hit for the riposting defender.
	var c40 := _make(11, _sink)
	c40.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c40.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c40.combatants["goblin_raider"][WIKeys.HP] = 999
	c40.combatants["goblin_raider"][WIKeys.SKILLS] = ["counter_strike"]
	c40.combatants["goblin_raider"]["hit_bonus"] = 1000
	c40.combatants["pc"]["hit_bonus"] = 1000
	c40.active_index = c40.turn_order.find("pc")
	c40._start_turn()
	assert(c40.attack("goblin_raider"), "attack into the riposte holder lands")
	assert(int((c40.action_tally.get("goblin_raider", {}) as Dictionary).get("melee_hit", 0)) == 1, "landed riposte tallies melee_hit for the defender")

	# --- Hotfix WAVE A2 (playtest directive 7, user-confirmed): PC death is an
	# immediate defeat, even with a living ally. Team-wipe still governs every
	# other combatant (relc dying alone does not end the fight, tested below).
	var c41 := _make(11, _sink)
	_events.clear()
	assert(bool(c41.combatants["relc"][WIKeys.ALIVE]), "fixture: relc starts alive")
	c41.apply_damage("pc", 999, "goblin_raider", true)
	assert(not bool(c41.combatants["pc"][WIKeys.ALIVE]), "pc is dead")
	assert(bool(c41.combatants["relc"][WIKeys.ALIVE]), "relc (ally) is still alive")
	assert(c41.finished, "combat ends the instant pc dies, even with a living ally")
	assert(c41.outcome["victory"] == false, "pc death resolves as defeat, not a draw or victory")
	var pc_downed_idx := -1
	var combat_finished_idx := -1
	for i in _events.size():
		var e: Dictionary = _events[i]
		if e["type"] == "combatant_downed" and e["payload"][WIKeys.ID] == "pc" and pc_downed_idx == -1:
			pc_downed_idx = i
		if e["type"] == "combat_finished" and combat_finished_idx == -1:
			combat_finished_idx = i
	assert(pc_downed_idx != -1 and combat_finished_idx != -1, "both combatant_downed{pc} and combat_finished emitted")
	assert(pc_downed_idx < combat_finished_idx, "combatant_downed{pc} precedes combat_finished (sane emit order)")
	assert(_count("combat_finished") == 1, "combat_finished emitted exactly once")
	var finished_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "combat_finished":
			finished_payload = e["payload"]
	assert(finished_payload.get("victory", true) == false, "combat_finished payload carries victory:false, same shape as any other defeat")

	# Ally actions cease: a fresh turn never starts for relc after the pc's
	# death ends the fight -- take_turn is a no-op once finished, and no
	# turn_started for relc exists anywhere in the stream.
	var turns_before := _count("turn_started")
	WICombatAI.take_turn(c41)
	assert(_count("turn_started") == turns_before, "no further turns start once the fight is over")
	for e: Dictionary in _events:
		if e["type"] == "turn_started":
			assert(e["payload"][WIKeys.ID] != "relc", "relc's turn never started after the pc's death ended the fight")

	# Team-wipe still governs every other combatant: relc alone dying (pc and
	# both enemies alive) must NOT end the fight -- only the pc's specific
	# death is special-cased.
	var c42 := _make(11, _sink)
	_events.clear()
	c42.apply_damage("relc", 999, "goblin_raider", true)
	assert(not bool(c42.combatants["relc"][WIKeys.ALIVE]), "relc is dead")
	assert(bool(c42.combatants["pc"][WIKeys.ALIVE]), "pc is still alive")
	assert(not c42.finished, "relc's death alone does not end the fight -- only the pc's does")

	# --- build-time equipment injection (damage_mod/hp_mod/
	# damage_reduction) -- WIGame._build_player_combatant is the only real
	# caller that ever sets these; here we exercise wi_combat.gd's own
	# handling of the fields directly, via _make_custom's cfg override.
	# hp_mod folds into max_hp at build time.
	var c43 := _make_custom(11, _sink, {"pc": {WIKeys.HP_MOD: 4}})
	var c43_base := _make(11, _sink)
	assert(int(c43.combatants["pc"][WIKeys.MAX_HP]) == int(c43_base.combatants["pc"][WIKeys.MAX_HP]) + 4, "hp_mod adds flat to max_hp at build time")
	assert(int(c43.combatants["pc"][WIKeys.HP]) == int(c43.combatants["pc"][WIKeys.MAX_HP]), "starting hp is the boosted max_hp")

	# A combatant with no damage_mod/damage_reduction/hp_mod override defaults
	# to 0 for all three -- byte-identical to the pre-M7 shape.
	assert(int(c43_base.combatants["pc"].get(WIKeys.DAMAGE_MOD, -1)) == 0, "damage_mod defaults to 0")
	assert(int(c43_base.combatants["pc"].get(WIKeys.DAMAGE_REDUCTION, -1)) == 0, "damage_reduction defaults to 0")

	# damage_mod adds flat to MELEE damage (both basic Attack and a
	# damage_mult skill, since both route through _resolve_hit's melee=true
	# branch) -- proven by comparing two otherwise-identical forced hits at
	# the same seed, one with a damage_mod override.
	var c44 := _make(9, _sink)
	c44.combatants["pc"][WIKeys.CELL] = (c44.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i.RIGHT
	c44.combatants["pc"]["hit_bonus"] = 1000
	c44.active_index = c44.turn_order.find("pc")
	c44._start_turn()
	c44.attack("goblin_raider")
	var dmg44 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			dmg44 = int(e["payload"]["damage"])
	var c45 := _make_custom(9, _sink, {"pc": {WIKeys.DAMAGE_MOD: 3}})
	c45.combatants["pc"][WIKeys.CELL] = (c45.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i.RIGHT
	c45.combatants["pc"]["hit_bonus"] = 1000
	c45.active_index = c45.turn_order.find("pc")
	c45._start_turn()
	_events.clear()
	c45.attack("goblin_raider")
	var dmg45 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			dmg45 = int(e["payload"]["damage"])
	assert(dmg45 == dmg44 + 3, "damage_mod +3 adds exactly 3 to an otherwise-identical basic Attack (same seed/roll)")

	# damage_mod also rides a damage_mult skill (power_strike), since it
	# shares the same melee=true _resolve_hit call.
	var c46 := _make_custom(9, _sink, {"pc": {WIKeys.DAMAGE_MOD: 3, WIKeys.SKILLS: ["power_strike"]}})
	c46.combatants["pc"][WIKeys.CELL] = (c46.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i.RIGHT
	c46.combatants["pc"]["hit_bonus"] = 1000
	c46.active_index = c46.turn_order.find("pc")
	c46._start_turn()
	var c47 := _make_custom(9, _sink, {"pc": {WIKeys.SKILLS: ["power_strike"]}})
	c47.combatants["pc"][WIKeys.CELL] = (c47.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i.RIGHT
	c47.combatants["pc"]["hit_bonus"] = 1000
	c47.active_index = c47.turn_order.find("pc")
	c47._start_turn()
	_events.clear()
	c47.use_skill("power_strike", "goblin_raider")
	var dmg47 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			dmg47 = int(e["payload"]["damage"])
	_events.clear()
	c46.use_skill("power_strike", "goblin_raider")
	var dmg46 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			dmg46 = int(e["payload"]["damage"])
	assert(dmg46 == dmg47 + 3, "damage_mod also adds to a damage_mult skill's landed hit (power_strike)")

	# damage_mod must NOT add to ranged spell_damage (int-based, melee=false).
	var c48 := _make_custom(9, _sink, {"pc": {WIKeys.DAMAGE_MOD: 3, WIKeys.SKILLS: ["frost_bolt"]}})
	c48.combatants["pc"][WIKeys.MP] = 10
	c48.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(1, 1)
	c48.combatants["pc"][WIKeys.CELL] = Vector2i(2, 1)
	c48.active_index = c48.turn_order.find("pc")
	c48._start_turn()
	var c49 := _make_custom(9, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt"]}})
	c49.combatants["pc"][WIKeys.MP] = 10
	c49.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(1, 1)
	c49.combatants["pc"][WIKeys.CELL] = Vector2i(2, 1)
	c49.active_index = c49.turn_order.find("pc")
	c49._start_turn()
	_events.clear()
	c49.use_skill("frost_bolt", "goblin_raider")
	var dmg49 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			dmg49 = int(e["payload"]["damage"])
	_events.clear()
	c48.use_skill("frost_bolt", "goblin_raider")
	var dmg48 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			dmg48 = int(e["payload"]["damage"])
	assert(dmg48 == dmg49, "damage_mod does NOT add to a ranged spell_damage cast (melee=false, int-based)")

	# damage_reduction applies in _deduct_hp, floored at >=1 for a positive
	# incoming amount, and BEFORE mana_shield -- proven via apply_damage
	# (bypasses hit-chance rng entirely, isolating the reduction/floor/order
	# math itself).
	var c50 := _make_custom(11, _sink, {"pc": {WIKeys.DAMAGE_REDUCTION: 3}})
	var hp50 := int(c50.combatants["pc"][WIKeys.HP])
	c50.apply_damage("pc", 10, "goblin_raider", true)
	assert(int(c50.combatants["pc"][WIKeys.HP]) == hp50 - 7, "damage_reduction subtracts flatly from incoming damage (10 - 3 = 7)")

	# Floor: reduction >= incoming damage still deals exactly 1, never 0.
	var c51 := _make_custom(11, _sink, {"pc": {WIKeys.DAMAGE_REDUCTION: 5}})
	var hp51 := int(c51.combatants["pc"][WIKeys.HP])
	c51.apply_damage("pc", 2, "goblin_raider", true)
	assert(int(c51.combatants["pc"][WIKeys.HP]) == hp51 - 1, "damage_reduction floors at 1 damage, never 0, for a positive incoming hit")

	# Ordering: reduction applies BEFORE mana_shield, so the shield only ever
	# absorbs what got past armor -- a holder with reduction 3 and ample MP
	# takes the reduction off first, then the shield absorbs the remainder
	# from MP, never touching HP for a hit the shield can fully cover.
	var c52 := _make_custom(11, _sink, {"pc": {WIKeys.DAMAGE_REDUCTION: 3, WIKeys.SKILLS: ["frost_bolt", "mana_shield"]}})
	_events.clear()
	var mp52 := int(c52.combatants["pc"][WIKeys.MP])
	var hp52 := int(c52.combatants["pc"][WIKeys.HP])
	c52.apply_damage("pc", 10, "goblin_raider", true)
	assert(int(c52.combatants["pc"][WIKeys.HP]) == hp52, "HP untouched: reduction (10-3=7) is fully absorbed by mana_shield")
	assert(int(c52.combatants["pc"][WIKeys.MP]) == mp52 - 7, "mana_shield absorbs exactly the POST-reduction amount (7), not the raw 10")
	var reduce_then_shield_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "reaction_triggered" and e["payload"].get("skill", "") == "mana_shield":
			reduce_then_shield_payload = e["payload"]
	assert(int(reduce_then_shield_payload.get("absorbed", -1)) == 7, "mana_shield's own reaction payload also reports the post-reduction amount")

	# --- the sneak combat read ---
	# [Stealth] in combat: 1 AP for +2 move_pool, a genuine self-buff -- no
	# enemy, no adjacency, no LoS. `use_skill("sneak", "pc")` mirrors exactly
	# how the real UI resolves it now (targeting_controller.gd's self-target
	# reuse always resolves target_id to the actor -- see that file's `enter()`
	# doc comment), so this is not a synthetic bypass of the real dispatch.
	var c57 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["sneak"]}})
	c57.active_index = c57.turn_order.find("pc")
	c57._start_turn()
	var pool57_before := int(c57.combatants["pc"][WIKeys.MOVE_POOL])
	var ap57_before := int(c57.combatants["pc"][WIKeys.AP])
	_events.clear()
	assert(c57.use_skill("sneak", "pc"), "sneak resolves as a self-cast (target_id == the actor's own id)")
	assert(int(c57.combatants["pc"][WIKeys.AP]) == ap57_before - 1, "sneak costs exactly 1 AP")
	assert(int(c57.combatants["pc"][WIKeys.MOVE_POOL]) == pool57_before + 2, "sneak grants exactly +2 move_pool")
	assert(_count("ap_changed") == 1, "spend_skill_costs emits ap_changed (no mp_cost, so no mp_changed)")
	assert(_count("mp_changed") == 0, "sneak has no mp_cost -- no mp_changed emitted")
	var sneak_resolved_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			sneak_resolved_payload = e["payload"]
	assert(sneak_resolved_payload.get("actor", "") == "pc" and sneak_resolved_payload.get("target", "") == "pc", "skill_resolved reports the actor as its own target (no other target exists)")
	# The spent pool is real currency afterward -- move_active can spend it via
	# the SAME MOVE_COST path dash()'s grant already uses (no separate ledger).
	# Try all 4 directions per step (the pool-exhaustion test's own idiom
	# above) rather than assuming a hardcoded direction stays on the board.
	var sneak_pool_dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	var moved_after_sneak := 0
	for i in (pool57_before + 2):
		for dir: Vector2i in sneak_pool_dirs:
			if c57.move_active(dir):
				moved_after_sneak += 1
				break
	assert(moved_after_sneak == pool57_before + 2, "every pool cell sneak granted is actually spendable via move_active")

	# Repeatable while AP lasts, same convention as dash().
	var c58 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["sneak"]}})
	c58.active_index = c58.turn_order.find("pc")
	c58._start_turn()
	var ap58_before := int(c58.combatants["pc"][WIKeys.AP])
	assert(ap58_before >= 2, "fixture: at least 2 AP available at turn start")
	assert(c58.use_skill("sneak", "pc"), "first sneak this turn succeeds")
	assert(c58.use_skill("sneak", "pc"), "sneak is repeatable while AP lasts, same as dash")
	assert(int(c58.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 4, "two casts stack (+2 each)")
	# Refused at 0 AP, and a refused cast spends nothing (same contract as
	# frost_bolt's MP-refusal test above and dash's AP-refusal test).
	c58.combatants["pc"][WIKeys.AP] = 0
	var pool58_before_refusal := int(c58.combatants["pc"][WIKeys.MOVE_POOL])
	_events.clear()
	assert(not c58.use_skill("sneak", "pc"), "sneak refused at 0 AP")
	assert(int(c58.combatants["pc"][WIKeys.MOVE_POOL]) == pool58_before_refusal, "refused sneak spends no pool")
	assert(_count("skill_resolved") == 0, "refused sneak never resolves")

	# The two PRE-EXISTING 0-cost move_pool_bonus skills (quick_movement,
	# battlefield_awareness) are UNCHANGED by this wiring -- they still refuse
	# via any target, self or enemy, exactly as test_sim_core.gd's g18 block
	# already pins (this is the OTHER half of that same drift-seam contract,
	# re-pinned here at the combat-sim level too since this file is where the
	# actual resolver dispatch lives).
	var c59 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement"]}})
	c59.active_index = c59.turn_order.find("pc")
	c59._start_turn()
	var pool59_before := int(c59.combatants["pc"][WIKeys.MOVE_POOL])
	assert(not c59.use_skill("quick_movement", "pc"), "the pre-existing 0-cost move_pool_bonus skill still refuses self-target")
	assert(int(c59.combatants["pc"][WIKeys.MOVE_POOL]) == pool59_before, "quick_movement grants nothing as an ACTIVE cast -- still no resolve_active consumer")

	# --- quick_movement/battlefield_awareness are real
	# TURN-START PASSIVES now (wi_combat.gd's `_move_pool_bonus_total`,
	# applied inside `_start_turn`) -- c59 above proves the ACTIVE-cast path
	# is untouched; this proves the PASSIVE path is real. ---
	var c60 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement"]}})
	c60.active_index = c60.turn_order.find("pc")
	_events.clear()
	c60._start_turn()
	assert(int(c60.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 1, "quick_movement grants +1 move_pool at turn start, unconditionally")
	var turn_started_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "turn_started":
			turn_started_payload = e["payload"]
	assert(int(turn_started_payload.get("move_pool", -1)) == WICombat.MOVE_POOL + 1, "turn_started reports the post-passive pool, not the bare base")
	# Stacks with a second 0-cost move_pool_bonus holder (battlefield_awareness).
	var c61 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement", "battlefield_awareness"]}})
	c61.active_index = c61.turn_order.find("pc")
	c61._start_turn()
	assert(int(c61.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 2, "two 0-cost move_pool_bonus skills stack (+1 each)")
	# Applied AFTER the slowed penalty -- a slowed holder still gets the
	# passive bonus on top of the reduced base (wi_combat.gd's `_start_turn`
	# doc comment).
	var c62 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement"]}})
	c62.active_index = c62.turn_order.find("pc")
	c62.combatants["pc"]["statuses"]["slowed"] = {"pool_penalty": 2}
	c62._start_turn()
	assert(int(c62.combatants["pc"][WIKeys.MOVE_POOL]) == maxi(1, WICombat.MOVE_POOL - 2) + 1, "quick_movement's passive still applies on top of a slowed turn")
	# [Stealth]'s ACTIVE cast (ap_cost 1) is a totally separate mechanism --
	# holding it must never ALSO grant a turn-start passive (the ap_cost>0
	# gate lives entirely in skill_effects.gd's resolve_active, never in
	# `_move_pool_bonus_total`, which explicitly skips any ap_cost>0 skill).
	var c63 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["sneak"]}})
	c63.active_index = c63.turn_order.find("pc")
	c63._start_turn()
	assert(int(c63.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL, "[Stealth]'s ACTIVE move_pool_bonus grants no turn-start passive")

	# --- second_wind's self-heal resolver (the
	# ghost-skill escalation's other fix; `_resolve_heal` in skill_effects.gd) ---
	var c64 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["second_wind"]}})
	c64.active_index = c64.turn_order.find("pc")
	c64._start_turn()
	var pc64: Dictionary = c64.combatants["pc"]
	pc64[WIKeys.HP] = int(pc64[WIKeys.MAX_HP]) - 10
	var hp64_before := int(pc64[WIKeys.HP])
	var ap64_before := int(pc64[WIKeys.AP])
	_events.clear()
	assert(c64.use_skill("second_wind", "pc"), "second_wind resolves as a self-cast (target_id == the actor's own id, same plumbing as sneak)")
	assert(int(pc64[WIKeys.HP]) == hp64_before + 8, "second_wind restores exactly effect.amount (8) HP when under the cap")
	assert(int(pc64[WIKeys.AP]) == ap64_before - 2, "second_wind costs exactly 2 AP")
	assert(_count("mp_changed") == 0, "second_wind has no mp_cost -- no mp_changed emitted")
	var heal_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			heal_payload = e["payload"]
	assert(heal_payload.get("actor", "") == "pc" and heal_payload.get("target", "") == "pc", "skill_resolved reports the actor as its own target, same convention as sneak")
	assert(int(heal_payload.get("healed", -1)) == 8, "skill_resolved reports the actual amount healed")

	# Capped at max_hp: healing above the ceiling only restores the missing amount.
	var c65 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["second_wind"]}})
	c65.active_index = c65.turn_order.find("pc")
	c65._start_turn()
	var pc65: Dictionary = c65.combatants["pc"]
	pc65[WIKeys.HP] = int(pc65[WIKeys.MAX_HP]) - 3
	_events.clear()
	assert(c65.use_skill("second_wind", "pc"), "second_wind resolves even when the heal would overshoot max_hp")
	assert(int(pc65[WIKeys.HP]) == int(pc65[WIKeys.MAX_HP]), "HP caps at max_hp, never overshoots")
	var heal_payload_capped: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			heal_payload_capped = e["payload"]
	assert(int(heal_payload_capped.get("healed", -1)) == 3, "the reported healed amount is the CAPPED delta (3), not the raw effect.amount (8)")

	# SELF-ONLY tonight: a living ally (same side, NOT the actor) still refuses
	# -- the type-keyed same-side gate lets it PAST the enemy check, but
	# `_resolve_heal`'s own target_id == actor_id gate stops it there.
	var c66 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["second_wind"]}})
	c66.active_index = c66.turn_order.find("pc")
	c66._start_turn()
	var ap66_before := int(c66.combatants["pc"][WIKeys.AP])
	_events.clear()
	assert(not c66.use_skill("second_wind", "relc"), "second_wind refuses an ally target -- SELF-ONLY tonight (ally-targeting is a follow-up)")
	assert(int(c66.combatants["pc"][WIKeys.AP]) == ap66_before, "refused ally-target heal spends nothing")
	assert(_count("skill_resolved") == 0, "refused ally-target heal never resolves")
	# An enemy target refuses too -- heal requires the SAME side (the
	# type-keyed exemption inverted from every other active effect's
	# different-side requirement), so a DIFFERENT side never even reaches
	# `_resolve_heal`'s self-only gate.
	assert(not c66.use_skill("second_wind", "goblin_raider"), "second_wind refuses an enemy target (fails the type-keyed same-side gate)")

	# --- [Ice Floor]: area terrain effect. Gates BEFORE spend, mirroring
	# spell_damage exactly (range then LoS -- a refused cast costs neither AP
	# nor MP). Arena fixture: goblin_ambush blocks (5,3),(6,4),(3,5),(8,2). ---
	var c67 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["icy_floor"]}})
	_events.clear()
	c67.active_index = c67.turn_order.find("pc")
	c67._start_turn()
	var ap67_before := int(c67.combatants["pc"][WIKeys.AP])
	var mp67_before := int(c67.combatants["pc"][WIKeys.MP])
	assert(not c67.use_skill("icy_floor", "goblin_raider"), "icy_floor refused out of range (default spawn distance 7 > range 3)")
	assert(int(c67.combatants["pc"][WIKeys.AP]) == ap67_before and int(c67.combatants["pc"][WIKeys.MP]) == mp67_before, "refused out-of-range cast spends neither AP nor MP")
	assert(_count("skill_resolved") == 0 and _count("terrain_added") == 0, "refused out-of-range cast never resolves or registers terrain")

	var c68 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["icy_floor"]}})
	_events.clear()
	c68.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c68.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)  # wall (5,3) sits directly between, in range (2)
	c68.active_index = c68.turn_order.find("pc")
	c68._start_turn()
	var ap68_before := int(c68.combatants["pc"][WIKeys.AP])
	var mp68_before := int(c68.combatants["pc"][WIKeys.MP])
	assert(not c68.use_skill("icy_floor", "goblin_raider"), "icy_floor refused without LoS despite being in range")
	var refusal68: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "action_refused":
			refusal68 = e["payload"]
	assert(refusal68.get("reason", "") == "no_los", "no_los action_refused emitted")
	assert(int(c68.combatants["pc"][WIKeys.AP]) == ap68_before and int(c68.combatants["pc"][WIKeys.MP]) == mp68_before, "refused no-LoS cast spends neither AP nor MP")
	assert(_count("skill_resolved") == 0 and _count("terrain_added") == 0, "refused no-LoS cast never resolves or registers terrain")

	# Successful cast: area = Chebyshev radius around the TARGET's cell,
	# clipped to bounds, walls excluded; occupants of every side get slowed
	# (friendly fire); terrain registers exactly through snapshot().
	var c69 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["icy_floor"]}})
	_events.clear()
	c69.combatants["pc"][WIKeys.CELL] = Vector2i(2, 4)
	c69.combatants["relc"][WIKeys.CELL] = Vector2i(4, 4)          # inside the blast -- ally
	c69.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(5, 4)  # cast target, inside the blast
	c69.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(11, 7)  # far outside the blast -- control
	c69.active_index = c69.turn_order.find("pc")
	c69._start_turn()
	var ap69_before := int(c69.combatants["pc"][WIKeys.AP])
	var mp69_before := int(c69.combatants["pc"][WIKeys.MP])
	assert(c69.use_skill("icy_floor", "goblin_raider"), "icy_floor cast succeeds in range with clear LoS")
	assert(int(c69.combatants["pc"][WIKeys.AP]) == ap69_before - 2, "icy_floor costs exactly 2 AP")
	assert(int(c69.combatants["pc"][WIKeys.MP]) == mp69_before - 4, "icy_floor costs exactly 4 MP")
	# Radius-1 blast around (5,4): (4..6, 3..5) minus blocked (5,3) and (6,4).
	var expected_cells69 := [[4, 3], [4, 4], [4, 5], [5, 4], [5, 5], [6, 3], [6, 5]]
	var resolved69: Dictionary = {}
	var terrain_added69: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved69 = e["payload"]
		if e["type"] == "terrain_added":
			terrain_added69 = e["payload"]
	assert(resolved69.get("actor", "") == "pc" and resolved69.get("skill", "") == "icy_floor" and resolved69.get("target", "") == "goblin_raider", "skill_resolved reports actor/skill/target")
	assert((resolved69.get("cells", []) as Array) == expected_cells69, "skill_resolved reports the sorted blast-area cells, walls excluded")
	assert(terrain_added69.get("kind", "") == "icy_floor" and int(terrain_added69.get("rounds", -1)) == 2, "terrain_added reports kind + duration_rounds")
	assert((terrain_added69.get("cells", []) as Array) == expected_cells69, "terrain_added reports the same sorted cell list")
	assert(_count("terrain_added") == 1, "terrain_added fires exactly once per cast, not once per cell")
	assert(c69.terrain.size() == 7, "combat.terrain registers exactly the 7 valid area cells")
	assert(not c69.terrain.has(Vector2i(5, 3)) and not c69.terrain.has(Vector2i(6, 4)), "blocked wall cells never enter the terrain area")
	var snap69 := c69.snapshot()
	assert((snap69["terrain"] as Dictionary).get("icy_floor", []) == expected_cells69, "snapshot().terrain.icy_floor matches the exact sorted cell list")
	assert((c69.combatants["goblin_raider"]["statuses"] as Dictionary).has("slowed"), "the cast target is slowed")
	assert((c69.combatants["relc"]["statuses"] as Dictionary).has("slowed"), "an ALLY standing in the blast is slowed too -- friendly fire is real")
	assert(not (c69.combatants["goblin_shaman"]["statuses"] as Dictionary).has("slowed"), "a combatant outside the blast is untouched (control)")

	# Persistence: icy through the cast round (1) and the next (2, since
	# expires_after_round = round_number(1) + duration_rounds(2) - 1 = 2),
	# purged the next time round_number advances past it (round 3).
	assert(c69.round_number == 1, "cast happened in round 1")
	var members69 := c69.turn_order.size()
	for i in members69:
		c69.end_turn()
	assert(c69.round_number == 2, "one full cycle through turn_order advances exactly one round")
	assert(c69.terrain.size() == 7, "icy_floor persists through round 2")
	assert(_count("terrain_expired") == 0, "not yet purged mid-lifetime")
	for i in members69:
		c69.end_turn()
	assert(c69.round_number == 3, "a second full cycle advances to round 3")
	assert(c69.terrain.is_empty(), "icy_floor is purged once round_number passes its expiry")
	assert(_count("terrain_expired") == 1, "terrain_expired fires exactly once")
	var expired69: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "terrain_expired":
			expired69 = e["payload"]
	assert(expired69.get("kind", "") == "icy_floor" and (expired69.get("cells", []) as Array) == expected_cells69, "terrain_expired reports kind + the exact sorted cell list purged")
	assert((c69.snapshot()["terrain"] as Dictionary).is_empty(), "snapshot().terrain is an empty dict once everything has expired")

	# Turn-start on ice: a combatant STARTING its turn already standing on an
	# icy cell gets the penalty THIS turn via the SAME _start_turn
	# consume-block the slowed status already uses (applied then immediately
	# consumed -- both events fire the same turn).
	var c70 := _make(11, _sink)
	_events.clear()
	var ice_cell70: Vector2i = c70.combatants["pc"][WIKeys.CELL]
	c70.terrain[ice_cell70] = {"kind": "icy_floor", "expires_after_round": c70.round_number + 10, "applies": {"slowed": {"pool_penalty": 2}}}
	c70.active_index = c70.turn_order.find("pc")
	c70._start_turn()
	assert(int(c70.combatants["pc"][WIKeys.MOVE_POOL]) == maxi(1, WICombat.MOVE_POOL - 2), "turn-start already standing on ice applies THIS turn's pool penalty")
	var applied70 := false
	var expired70 := false
	for e: Dictionary in _events:
		if e["type"] == "status_applied" and e["payload"].get("id", "") == "pc" and e["payload"].get("status", "") == "slowed":
			applied70 = true
		if e["type"] == "status_expired" and e["payload"].get("id", "") == "pc" and e["payload"].get("status", "") == "slowed":
			expired70 = true
	assert(applied70 and expired70, "status_applied then status_expired both fire the same turn (applied then immediately consumed)")

	# Move onto ice: stepping onto a terrain cell mid-turn applies the status
	# immediately, but the pool penalty only bites at the combatant's NEXT
	# turn start (this turn's pool is untouched by the step).
	var c71 := _make(11, _sink)
	_events.clear()
	var start_cell71: Vector2i = c71.combatants["pc"][WIKeys.CELL]
	var ice_cell71 := start_cell71 + Vector2i.RIGHT
	c71.terrain[ice_cell71] = {"kind": "icy_floor", "expires_after_round": c71.round_number + 10, "applies": {"slowed": {"pool_penalty": 2}}}
	c71.active_index = c71.turn_order.find("pc")
	c71._start_turn()
	assert(not (c71.combatants["pc"]["statuses"] as Dictionary).has("slowed"), "not slowed before stepping onto the icy cell")
	assert(c71.move_active(Vector2i.RIGHT), "pc moves onto the icy cell")
	assert(c71.combatants["pc"][WIKeys.CELL] == ice_cell71, "pc now stands on the icy cell")
	assert((c71.combatants["pc"]["statuses"] as Dictionary).has("slowed"), "stepping onto ice applies slowed immediately")
	var members71 := c71.turn_order.size()
	for i in members71:
		c71.end_turn()
	assert(c71.get_active() == "pc", "cycled back to pc's own turn")
	assert(int(c71.combatants["pc"][WIKeys.MOVE_POOL]) == maxi(1, WICombat.MOVE_POOL - 2), "the NEXT turn's move_pool reflects the ice penalty from stepping on it last turn")

	# Flat refresh: re-casting the same area registers no duplicate cells and
	# re-applying the status yields exactly one entry, never a stack.
	var c72 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["icy_floor"]}})
	_events.clear()
	c72.combatants["pc"][WIKeys.CELL] = Vector2i(2, 4)
	c72.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 4)
	c72.active_index = c72.turn_order.find("pc")
	c72._start_turn()
	assert(c72.use_skill("icy_floor", "goblin_raider"), "first icy_floor cast succeeds")
	var terrain_size_after_first := c72.terrain.size()
	var raider_statuses72: Dictionary = c72.combatants["goblin_raider"]["statuses"]
	assert(raider_statuses72.has("slowed") and raider_statuses72.size() == 1, "exactly one status entry after the first cast")
	var members72 := c72.turn_order.size()
	for i in members72:
		c72.end_turn()
	assert(c72.get_active() == "pc", "cycled back to pc for the re-cast")
	assert(c72.use_skill("icy_floor", "goblin_raider"), "re-casting the same area succeeds")
	assert(c72.terrain.size() == terrain_size_after_first, "re-casting the same area registers no duplicate cells (flat refresh, keyed by cell)")
	var raider_statuses72b: Dictionary = c72.combatants["goblin_raider"]["statuses"]
	assert(raider_statuses72b.has("slowed") and raider_statuses72b.size() == 1, "re-application still yields exactly one status entry, never a stack")
	assert(int((c72.terrain[Vector2i(3, 4)] as Dictionary).get("expires_after_round", -1)) == c72.round_number + 1, "re-casting refreshes expiry to the NEW cast's value, not stacking onto the old one")

	# Empty-terrain no-op: a fight that never casts icy_floor emits zero
	# terrain events at all -- the "zero behavior change for every
	# pre-existing combat-data payload" proof (also exercises the purge's
	# own early-return across several round rollovers).
	var c73 := _make(11, _sink)
	_events.clear()
	var guard73 := 0
	while not c73.finished and guard73 < c73.turn_order.size() * 3:
		c73.end_turn()
		guard73 += 1
	assert(c73.terrain.is_empty(), "terrain stays empty when icy_floor is never cast")
	assert(_count("terrain_added") == 0 and _count("terrain_expired") == 0, "zero terrain events fire in a fight that never casts icy_floor")
	assert((c73.snapshot()["terrain"] as Dictionary).is_empty(), "snapshot terrain key is an empty dict when unused")

	# --- [Flame Pillar] blast_damage (GH#71): instant AoE damage, no
	# terrain/status writes. Gates BEFORE spend, mirroring icy_floor/
	# spell_damage exactly (range then LoS). Same goblin_ambush arena blocks
	# as icy_floor's own tests: (5,3),(6,4),(3,5),(8,2). ---
	var c90 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["flame_pillar"]}})
	_events.clear()
	c90.active_index = c90.turn_order.find("pc")
	c90._start_turn()
	var ap74_before := int(c90.combatants["pc"][WIKeys.AP])
	var mp74_before := int(c90.combatants["pc"][WIKeys.MP])
	assert(not c90.use_skill("flame_pillar", "goblin_raider"), "flame_pillar refused out of range (default spawn distance 7 > range 3)")
	assert(int(c90.combatants["pc"][WIKeys.AP]) == ap74_before and int(c90.combatants["pc"][WIKeys.MP]) == mp74_before, "refused out-of-range cast spends neither AP nor MP")
	assert(_count("skill_resolved") == 0, "refused out-of-range cast never resolves")

	var c91 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["flame_pillar"]}})
	_events.clear()
	c91.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c91.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)  # wall (5,3) sits directly between, in range (2)
	c91.active_index = c91.turn_order.find("pc")
	c91._start_turn()
	var ap75_before := int(c91.combatants["pc"][WIKeys.AP])
	var mp75_before := int(c91.combatants["pc"][WIKeys.MP])
	assert(not c91.use_skill("flame_pillar", "goblin_raider"), "flame_pillar refused without LoS despite being in range")
	var refusal75: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "action_refused":
			refusal75 = e["payload"]
	assert(refusal75.get("reason", "") == "no_los", "no_los action_refused emitted")
	assert(int(c91.combatants["pc"][WIKeys.AP]) == ap75_before and int(c91.combatants["pc"][WIKeys.MP]) == mp75_before, "refused no-LoS cast spends neither AP nor MP")
	assert(_count("skill_resolved") == 0, "refused no-LoS cast never resolves")

	# Successful cast: an enemy adjacent to a SECOND enemy AND an ally all
	# land in the same blast (friendly fire real, three-way); the wall cell
	# (5,3) sits inside the candidate square and is excluded exactly like
	# icy_floor's own wall exclusion; the actor (pc) stands OUTSIDE the
	# blast this time and is untouched (the "combatant outside the blast"
	# control, mirroring icy_floor's goblin_shaman control in c69 above).
	var c92 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["flame_pillar"]}})
	_events.clear()
	c92.combatants["pc"][WIKeys.CELL] = Vector2i(2, 4)
	c92.combatants["relc"][WIKeys.CELL] = Vector2i(3, 4)           # inside the blast -- ally
	c92.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 3)  # cast target, inside the blast
	c92.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(5, 4)  # second enemy, inside the blast (adjacent to the target)
	c92.active_index = c92.turn_order.find("pc")
	c92._start_turn()
	var ap76_before := int(c92.combatants["pc"][WIKeys.AP])
	var mp76_before := int(c92.combatants["pc"][WIKeys.MP])
	var relc_hp76 := int(c92.combatants["relc"][WIKeys.HP])
	var raider_hp76 := int(c92.combatants["goblin_raider"][WIKeys.HP])
	var shaman_hp76 := int(c92.combatants["goblin_shaman"][WIKeys.HP])
	var pc_hp76 := int(c92.combatants["pc"][WIKeys.HP])
	assert(c92.use_skill("flame_pillar", "goblin_raider"), "flame_pillar cast succeeds in range with clear LoS")
	assert(int(c92.combatants["pc"][WIKeys.AP]) == ap76_before - 3, "flame_pillar costs exactly 3 AP")
	assert(int(c92.combatants["pc"][WIKeys.MP]) == mp76_before - 5, "flame_pillar costs exactly 5 MP")
	# Radius-1 blast around (4,3): (3..5, 2..4) minus blocked (5,3).
	var expected_cells76 := [[3, 2], [3, 3], [3, 4], [4, 2], [4, 3], [4, 4], [5, 2], [5, 4]]
	var resolved76: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved76 = e["payload"]
	assert(resolved76.get("actor", "") == "pc" and resolved76.get("skill", "") == "flame_pillar" and resolved76.get("target", "") == "goblin_raider", "skill_resolved reports actor/skill/target")
	assert((resolved76.get("cells", []) as Array) == expected_cells76, "skill_resolved reports the sorted blast-area cells, the wall cell (5,3) excluded")
	var hit_ids76: Array = resolved76.get("hit_ids", [])
	assert(hit_ids76.has("relc") and hit_ids76.has("goblin_raider") and hit_ids76.has("goblin_shaman"), "hit_ids includes the ally, the cast target, and the second enemy -- friendly fire is real")
	assert(not hit_ids76.has("pc"), "the actor standing outside the blast is not in hit_ids")
	# Each victim actually took an attack_resolved roll (melee=false, no
	# riposte possible from a blast) -- the deterministic proof, since an
	# individual hit-chance roll can still miss (mirrors flame_jet's c18
	# test above, which asserts HP `<=` before for the same reason).
	var blast_targets_seen76: Array = []
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			assert(bool(e["payload"]["melee"]) == false, "blast hits are non-melee")
			blast_targets_seen76.append(String(e["payload"]["target"]))
	assert(blast_targets_seen76.has("relc") and blast_targets_seen76.has("goblin_raider") and blast_targets_seen76.has("goblin_shaman"), "all three struck combatants got an attack_resolved roll")
	assert(not blast_targets_seen76.has("pc"), "the actor outside the blast gets no attack_resolved roll at all")
	assert(int(c92.combatants["relc"][WIKeys.HP]) <= relc_hp76, "the ally in the blast can take real damage (friendly fire)")
	assert(int(c92.combatants["goblin_raider"][WIKeys.HP]) <= raider_hp76, "the cast target can take real damage")
	assert(int(c92.combatants["goblin_shaman"][WIKeys.HP]) <= shaman_hp76, "the second enemy in the blast can take real damage")
	assert(int(c92.combatants["pc"][WIKeys.HP]) == pc_hp76, "the actor outside the blast took no damage")
	assert(c92.terrain.is_empty(), "flame_pillar writes NO terrain (instant damage only, unlike icy_floor)")
	assert(_count("terrain_added") == 0, "flame_pillar never emits terrain_added")
	assert((c92.combatants["relc"]["statuses"] as Dictionary).is_empty(), "flame_pillar applies NO status to the ally")
	assert((c92.combatants["goblin_raider"]["statuses"] as Dictionary).is_empty(), "flame_pillar applies NO status to the cast target either")
	assert(_count("status_applied") == 0, "flame_pillar never emits status_applied")
	assert(_count("reaction_triggered") == 0, "blast hits never trigger riposte (mirrors line_damage's no-riposte contract)")

	# Self-hit: the caster's OWN cell can land in the blast when adjacent to
	# the target -- deliberate, same rule icy_floor documents for its terrain.
	var c93 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["flame_pillar"]}})
	_events.clear()
	c93.combatants["pc"][WIKeys.CELL] = Vector2i(6, 3)
	c93.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(7, 3)
	c93.combatants["relc"][WIKeys.CELL] = Vector2i(11, 6)
	c93.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(11, 7)
	c93.active_index = c93.turn_order.find("pc")
	c93._start_turn()
	var pc_hp77 := int(c93.combatants["pc"][WIKeys.HP])
	assert(c93.use_skill("flame_pillar", "goblin_raider"), "flame_pillar cast succeeds")
	var resolved77: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved77 = e["payload"]
	var hit_ids77: Array = resolved77.get("hit_ids", [])
	assert(hit_ids77.has("pc"), "the caster's own cell landed in the blast, so it's in hit_ids too")
	var self_hit_seen77 := false
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved" and String(e["payload"]["target"]) == "pc":
			self_hit_seen77 = true
	assert(self_hit_seen77, "the caster gets a real attack_resolved roll against its own cell")
	assert(int(c93.combatants["pc"][WIKeys.HP]) <= pc_hp77, "the caster can take real self-inflicted damage (a miss just leaves HP unchanged this roll)")

	# A roster listing the same catalog id twice must field TWO
	# distinct, independently-tracked combatants, never collapse to one via
	# dict-key overwrite. shield_spiders' real shipped roster
	# (["shield_spider", "shield_spider"]) reproduced directly via `_cfgs`
	# (which appends one cfg dict PER occurrence in the requested id list,
	# exactly like `WIGame.start_combat`'s enemy-roster loop).
	var arena_sn: Dictionary = _load("res://data/arenas.json")["arenas"][0]
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		if String(a[WIKeys.ID]) == "sewers_nest":
			arena_sn = a
	var c74 := WICombat.new(arena_sn, _cfgs(["pc", "shield_spider", "shield_spider"]), _load("res://data/skills.json"), _sink, 1)
	c74.begin()
	assert(c74.combatants.size() == 3, "duplicate-id roster fields THREE combatants (pc + both spiders), not two via overwrite")
	assert(c74.turn_order.size() == 3, "initiative order also carries all three -- no combatant silently missing from the fight")
	assert(c74.combatants.has("shield_spider") and c74.combatants.has("shield_spider_2"), "first spider keeps the bare id, second gets a deduped suffix")
	assert(String(c74.combatants["shield_spider"][WIKeys.DISPLAY_NAME]) == String(c74.combatants["shield_spider_2"][WIKeys.DISPLAY_NAME]), "both spiders show the SAME player-facing display name -- the suffix is internal bookkeeping only")
	assert(String(c74.combatants["shield_spider"][WIKeys.TEMPLATE_ID]) == "shield_spider" and String(c74.combatants["shield_spider_2"][WIKeys.TEMPLATE_ID]) == "shield_spider", "both resolve back to the SAME static catalog id (template_id) for presentation lookups (sprite/combat_scale)")
	assert((c74.combatants["shield_spider"][WIKeys.CELL] as Vector2i) != (c74.combatants["shield_spider_2"][WIKeys.CELL] as Vector2i), "the two spiders occupy distinct spawn cells -- real independent combatants, not aliases of one dict")
	# Damaging one must never affect the other -- the strongest proof the
	# pre-fix dict-overwrite aliasing is gone (before the fix there was
	# structurally only ONE dict for both list entries to share).
	c74.apply_damage("shield_spider", 5, "pc", true)
	assert(int(c74.combatants["shield_spider"][WIKeys.HP]) == int(c74.combatants["shield_spider"][WIKeys.MAX_HP]) - 5, "damage lands on the targeted spider")
	assert(int(c74.combatants["shield_spider_2"][WIKeys.HP]) == int(c74.combatants["shield_spider_2"][WIKeys.MAX_HP]), "the OTHER spider is untouched -- no aliasing between the two")

	# Generalizes past a single duplicate pair: three occurrences of the same
	# id (a hypothetical worse case than any shipped roster today) still get
	# three distinct runtime ids via the same re-probed suffix loop.
	var c75 := WICombat.new(arena_sn, _cfgs(["pc", "goblin_raider", "goblin_raider", "goblin_raider"]), _load("res://data/skills.json"), _sink, 1)
	c75.begin()
	assert(c75.combatants.size() == 4, "triple-duplicate roster fields all four combatants")
	assert(c75.combatants.has("goblin_raider") and c75.combatants.has("goblin_raider_2") and c75.combatants.has("goblin_raider_3"), "third occurrence gets _3, not a collision with _2")

	# --- [Invisibility]'s combat read: self-cast untargetable status ---
	var c80 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["invisibility"]}})
	c80.active_index = c80.turn_order.find("pc")
	c80._start_turn()
	var ap80_before := int(c80.combatants["pc"][WIKeys.AP])
	var mp80_before := int(c80.combatants["pc"][WIKeys.MP])
	_events.clear()
	assert(c80.use_skill("invisibility", "pc"), "invisibility resolves as a self-cast")
	assert(int(c80.combatants["pc"][WIKeys.AP]) == ap80_before - 1, "invisibility costs exactly 1 AP")
	assert(int(c80.combatants["pc"][WIKeys.MP]) == mp80_before - 3, "invisibility costs exactly 3 MP")
	var pc_statuses80: Dictionary = c80.combatants["pc"]["statuses"]
	assert(pc_statuses80.has("invisible"), "casting applies the invisible status to the CASTER")
	assert(bool((pc_statuses80["invisible"] as Dictionary).get("untargetable", false)), "the invisible status carries the untargetable flag AI-exclusion keys on")
	assert(int((pc_statuses80["invisible"] as Dictionary).get("expires_after_round", -1)) == c80.round_number + 3 - 1, "expires_after_round stamped from duration_rounds, icy_floor's own idiom")
	var resolved80: Dictionary = {}
	var applied80: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved80 = e["payload"]
		if e["type"] == "status_applied":
			applied80 = e["payload"]
	assert(resolved80.get("actor", "") == "pc" and resolved80.get("skill", "") == "invisibility" and resolved80.get("target", "") == "pc", "skill_resolved reports the actor as its own target, same convention as sneak/second_wind")
	assert(applied80.get("id", "") == "pc" and applied80.get("status", "") == "invisible", "status_applied reports the caster + the invisible status id")

	# --- AI target-selection exclusion + break-on-damage + re-targetable ---
	var cfgs81 := _cfgs(["pc", "goblin_raider"])
	for cfg: Dictionary in cfgs81:
		if String(cfg[WIKeys.ID]) == "pc":
			cfg[WIKeys.SKILLS] = ["invisibility"]
	var c81 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], cfgs81, _load("res://data/skills.json"), _sink, 11)
	c81.begin()
	c81.combatants["pc"][WIKeys.CELL] = Vector2i(3, 3)
	c81.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 3)  # adjacent -- a real melee AI would attack immediately if targetable
	c81.combatants["pc"]["hit_bonus"] = 1000
	c81.combatants["goblin_raider"]["hit_bonus"] = 1000
	c81.active_index = c81.turn_order.find("pc")
	c81._start_turn()
	_events.clear()
	assert(c81.use_skill("invisibility", "pc"), "pc casts invisibility before the raider's turn")
	c81.end_turn()
	var guard81 := 0
	while c81.get_active() != "goblin_raider" and guard81 < 8:
		c81.end_turn()
		guard81 += 1
	assert(c81.get_active() == "goblin_raider", "cycled to the raider's turn")
	_events.clear()
	WICombatAI.take_turn(c81)
	assert(_count("attack_resolved") == 0, "melee AI never attacks its sole foe while that foe is invisible")
	assert(_count("skill_resolved") == 0, "melee AI takes no skill action either -- it has nothing left to do")
	assert(c81.combatants["goblin_raider"][WIKeys.CELL] == Vector2i(4, 3), "melee AI does not even move -- an invisible sole foe leaves it with no living enemy to path toward, exactly like the empty-foes case")
	assert(_count("turn_ended") == 1, "the raider's turn ends immediately, exactly like the inert-profile/no-foe cases")

	# Break on damage: pc attacks (guaranteed hit via hit_bonus 1000), clearing
	# its own invisible status; the raider can then target pc again.
	c81.end_turn()
	var guard81b := 0
	while c81.get_active() != "pc" and guard81b < 8:
		c81.end_turn()
		guard81b += 1
	assert(c81.get_active() == "pc", "cycled back to pc's turn")
	_events.clear()
	assert(c81.attack("goblin_raider"), "pc attacks the raider")
	var expired81: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_expired" and e["payload"].get("id", "") == "pc":
			expired81 = e["payload"]
	assert(expired81.get("status", "") == "invisible", "pc's own attack clears its invisible status (break-on-damage), keyed on the untargetable flag not this skill id")
	assert(not (c81.combatants["pc"]["statuses"] as Dictionary).has("invisible"), "invisible is gone from pc's statuses")

	c81.end_turn()
	var guard81c := 0
	while c81.get_active() != "goblin_raider" and guard81c < 8:
		c81.end_turn()
		guard81c += 1
	assert(c81.get_active() == "goblin_raider", "cycled back to the raider's turn")
	_events.clear()
	WICombatAI.take_turn(c81)
	assert(_count("attack_resolved") >= 1, "once invisibility breaks, the melee AI can target pc again")

	# --- Natural expiry: fades after duration_rounds if never broken ---
	var cfgs82 := _cfgs(["pc", "training_dummy_a"])
	for cfg: Dictionary in cfgs82:
		if String(cfg[WIKeys.ID]) == "pc":
			cfg[WIKeys.SKILLS] = ["invisibility"]
	var c82 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], cfgs82, _load("res://data/skills.json"), _sink, 11)
	c82.begin()
	c82.active_index = c82.turn_order.find("pc")
	c82._start_turn()
	_events.clear()
	assert(c82.use_skill("invisibility", "pc"), "pc casts invisibility (duration_rounds 3)")
	assert(int(c82.round_number) == 1, "cast happened in round 1")
	assert(int((c82.combatants["pc"]["statuses"]["invisible"] as Dictionary).get("expires_after_round", -1)) == 3, "expires_after_round = round(1) + duration(3) - 1 = 3")
	var members82 := c82.turn_order.size()
	for i in members82:
		c82.end_turn()
	assert(int(c82.round_number) == 2, "one full cycle advances exactly one round")
	assert((c82.combatants["pc"]["statuses"] as Dictionary).has("invisible"), "invisible persists through round 2")
	for i in members82:
		c82.end_turn()
	assert(int(c82.round_number) == 3, "a second full cycle advances to round 3")
	assert((c82.combatants["pc"]["statuses"] as Dictionary).has("invisible"), "invisible persists through round 3 -- not yet past its expiry")
	assert(_count("status_expired") == 0, "not yet purged mid-lifetime")
	_events.clear()
	for i in members82:
		c82.end_turn()
	assert(int(c82.round_number) == 4, "a third full cycle advances to round 4")
	assert(not (c82.combatants["pc"]["statuses"] as Dictionary).has("invisible"), "invisible is purged once round_number passes its expiry, never broken by damage")
	assert(_count("status_expired") == 1, "status_expired fires exactly once")
	var expired82: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_expired":
			expired82 = e["payload"]
	assert(expired82.get("id", "") == "pc" and expired82.get("status", "") == "invisible", "status_expired reports the caster + invisible")
	assert(_count("attack_resolved") == 0, "control: nothing ever attacked -- this expiry is purely round-based, not break-on-damage")

	# --- Area effects don't respect invisibility: a line skill still HITS an
	# invisible occupant standing in it. Only the AI's SELECTION heuristic
	# skips COUNTING them toward the >=2-enemies-hit gate (combat_ai.gd's
	# _act_line) -- the resolver itself (_resolve_line_damage) is untouched
	# and hits every occupied cell unconditionally. Being HIT is also not
	# DEALING damage, so this never breaks the invisible occupant's own status. ---
	var c83 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["invisibility"]}, "goblin_shaman": {WIKeys.SKILLS: ["flame_jet"]}})
	c83.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c83.combatants["pc"][WIKeys.CELL] = Vector2i(1, 0)
	c83.combatants["goblin_shaman"]["hit_bonus"] = 1000
	c83.active_index = c83.turn_order.find("pc")
	c83._start_turn()
	assert(c83.use_skill("invisibility", "pc"), "pc casts invisibility")
	assert((c83.combatants["pc"]["statuses"] as Dictionary).has("invisible"), "fixture: pc is invisible")
	c83.end_turn()
	var guard83 := 0
	while c83.get_active() != "goblin_shaman" and guard83 < 8:
		c83.end_turn()
		guard83 += 1
	assert(c83.get_active() == "goblin_shaman", "cycled to goblin_shaman's turn")
	var hp83_before := int(c83.combatants["pc"][WIKeys.HP])
	_events.clear()
	assert(c83.use_skill("flame_jet", "right"), "goblin_shaman casts flame_jet down the line pc occupies")
	assert(int(c83.combatants["pc"][WIKeys.HP]) < hp83_before, "line damage still lands on the invisible occupant standing in the line")
	assert((c83.combatants["pc"]["statuses"] as Dictionary).has("invisible"), "being HIT (not dealing damage) never breaks invisibility -- pc is still invisible after")

	# --- Issue #82's WINDUP SIM SPEC: `slam` (vault_construct, data/skills.json)
	# is the first `windup_rounds` skill. Four blocks below prove the whole
	# contract against the REAL shipped data (no synthetic stand-in skill):
	# declare freezes cells + spends ALL 4 AP; move-out whiffs the target;
	# standing-still eats the hit; downing the caster before its next turn
	# means no posthumous resolution. arenas[0] (goblin_ambush) reused for a
	# plain open 12x8 grid -- the vault arena's own shape is C3's content
	# deliverable, not needed to prove the MECHANISM. ---

	# Block A: declare -> move-out (BOTH occupants relocate) -> whiff. Adjacent
	# cast (slam's own range:1 contract) means the caster's cell is ALWAYS
	# inside its own radius-1 blast at declaration [D: friendly fire, same as
	# blast_damage] -- moving the caster away too (its move_pool is untouched
	# by the declare's AP spend, a real same-turn option) is what makes this a
	# clean TOTAL whiff rather than a caster-self-tag muddying the read.
	var c84 := _cfgs(["pc", "vault_construct"])
	var combat84 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], c84, _load("res://data/skills.json"), _sink, 5)
	combat84.begin()
	combat84.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	combat84.combatants["vault_construct"][WIKeys.CELL] = Vector2i(2, 1)
	combat84.active_index = combat84.turn_order.find("vault_construct")
	combat84._start_turn()
	_events.clear()
	assert(combat84.use_skill("slam", "pc"), "vault_construct declares slam on pc (adjacent, affordable)")
	assert(int(combat84.combatants["vault_construct"][WIKeys.AP]) == 0, "slam's ap_cost (4) fully drains the turn's AP -- the telegraphed AP spike")
	assert(combat84.windups.has("vault_construct"), "declared windup is parked on the caster")
	var frozen84: Array = combat84.windups["vault_construct"]["cells"]
	assert(Vector2i(1, 1) in frozen84, "frozen cells include pc's cell at declaration (radius 1 around the target)")
	assert(_count("windup_declared") == 1, "exactly one windup_declared emitted")
	var declared84: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "windup_declared":
			declared84 = e["payload"]
	assert(declared84.get("id", "") == "vault_construct" and declared84.get("skill", "") == "slam", "windup_declared reports caster + skill")
	assert(_count("skill_resolved") == 0 and _count("attack_resolved") == 0, "a declare resolves NOTHING on cast -- no damage yet")
	# The caster relocates same-turn (move_pool untouched by the AP spend).
	assert(combat84.move_active(Vector2i.RIGHT) and combat84.move_active(Vector2i.RIGHT) and combat84.move_active(Vector2i.RIGHT), "caster steps 3 cells right, clear of its own frozen blast")
	assert(combat84.combatants["vault_construct"][WIKeys.CELL] == Vector2i(5, 1), "caster now well outside the radius-1 box around (1,1)")
	combat84.end_turn()
	assert(combat84.get_active() == "pc", "pc's turn")
	assert(combat84.move_active(Vector2i.DOWN) and combat84.move_active(Vector2i.DOWN) and combat84.move_active(Vector2i.DOWN), "pc steps 3 cells down, clear of the frozen blast")
	assert(combat84.combatants["pc"][WIKeys.CELL] == Vector2i(1, 4), "pc now well outside the radius-1 box around (1,1)")
	var hp84_before := int(combat84.combatants["pc"][WIKeys.HP])
	_events.clear()
	combat84.end_turn()  # wraps back to vault_construct -- _start_turn resolves the windup FIRST
	assert(combat84.get_active() == "vault_construct", "cycled back to the caster's own next turn")
	assert(not combat84.windups.has("vault_construct"), "resolved windup is erased from the pending dict")
	assert(_count("skill_resolved") == 1, "resolution still emits SKILL_RESOLVED even on a total whiff")
	var resolved84: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved84 = e["payload"]
	assert((resolved84.get("hit_ids", []) as Array).is_empty(), "nobody occupies the frozen cells anymore -- zero hits")
	assert(_count("attack_resolved") == 0, "a whiff resolves no hits at all")
	assert(int(combat84.combatants["pc"][WIKeys.HP]) == hp84_before, "pc took no damage -- the counterplay (moving out) worked")

	# Block B: declare -> stand -> hit. Neither occupant moves; the frozen
	# cells still contain pc at resolution, so the windup lands for real.
	var c85 := _cfgs(["pc", "vault_construct"])
	var combat85 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], c85, _load("res://data/skills.json"), _sink, 5)
	combat85.begin()
	combat85.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	combat85.combatants["vault_construct"][WIKeys.CELL] = Vector2i(2, 1)
	combat85.active_index = combat85.turn_order.find("vault_construct")
	combat85._start_turn()
	assert(combat85.use_skill("slam", "pc"), "vault_construct declares slam on pc")
	combat85.end_turn()
	assert(combat85.get_active() == "pc", "pc's turn -- does nothing, stands its ground")
	var hp85_before := int(combat85.combatants["pc"][WIKeys.HP])
	_events.clear()
	combat85.end_turn()  # wraps back to vault_construct -- resolves against the SAME frozen cells
	assert(not combat85.windups.has("vault_construct"), "resolved and cleared")
	var resolved85: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved85 = e["payload"]
	assert((resolved85.get("hit_ids", []) as Array).has("pc"), "pc, still standing in the frozen cell, is among the hits")
	assert(_count("attack_resolved") >= 1, "at least one real hit resolution fired")
	assert(int(combat85.combatants["pc"][WIKeys.HP]) < hp85_before, "pc took real damage from the resolved slam")

	# Block C: declare -> down-the-caster -> no posthumous resolution. A THIRD
	# combatant (a second enemy) is required so downing vault_construct alone
	# doesn't end the whole fight before the "next turn that never comes" can
	# be proven. `apply_damage` is the same public HP-application entry point
	# `_resolve_hit` itself calls internally.
	var c86 := _cfgs(["pc", "vault_construct", "goblin_raider"])
	var combat86 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], c86, _load("res://data/skills.json"), _sink, 5)
	combat86.begin()
	combat86.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	combat86.combatants["vault_construct"][WIKeys.CELL] = Vector2i(2, 1)
	combat86.active_index = combat86.turn_order.find("vault_construct")
	combat86._start_turn()
	assert(combat86.use_skill("slam", "pc"), "vault_construct declares slam on pc")
	assert(combat86.windups.has("vault_construct"), "fixture: windup is pending")
	combat86.apply_damage("vault_construct", 9999, "pc", true)
	assert(not bool(combat86.combatants["vault_construct"][WIKeys.ALIVE]), "vault_construct is downed before its next turn")
	assert(not combat86.finished, "goblin_raider still stands -- the fight continues")
	assert(combat86.windups.has("vault_construct"), "the pending windup is left parked (not eagerly cleared) -- it simply never gets a chance to resolve")
	var hp86_before := int(combat86.combatants["pc"][WIKeys.HP])
	_events.clear()
	var guard86 := 0
	while guard86 < 8 and _count("skill_resolved") == 0:
		combat86.end_turn()
		guard86 += 1
	# A downed combatant's turn is skipped entirely by _advance_turn
	# (`if combatants[get_active()][ALIVE]`) -- _start_turn, and therefore
	# _resolve_windup, is never called for vault_construct again. Cycling
	# several turns (more than one full round) must never produce the
	# resolution event.
	assert(_count("skill_resolved") == 0, "the downed caster's windup never resolves -- no posthumous damage")
	assert(int(combat86.combatants["pc"][WIKeys.HP]) == hp86_before, "pc took no damage from a windup whose caster died first")

	print("PASS: combat sim core rules and determinism hold")
	quit(0)
