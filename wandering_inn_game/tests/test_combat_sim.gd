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

	# --- Task 4: skill effects and reactions ---
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

	# --- Task 2: movement economy — move pool + Dash; status framework ---
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

	# --- Task 3: line-of-sight ---
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

	# --- M3 T3 review fix #1: has_los supercover symmetry ---
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

	# --- Task 3: line_cells enumeration ---
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

	# --- Task 3: Flame Jet line_damage — friendly fire, cells + hit_ids on skill_resolved ---
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

	# --- M3 T3 review fix #2: line_damage refused when its first cell is a wall ---
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

	# --- Task 3: frost_bolt applies slowed on hit ---
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

	# --- Task 3: AI never selects a line whose cells include an ally ---
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

	# --- M3 T3 review fix #3: second slow on an already-slowed victim is a flat refresh ---
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

	# --- Task 4: MP pool build ---
	var c25 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "quick_cast"]}})
	assert(int(c25.combatants["pc"][WIKeys.MAX_MP]) == 8 + int(8 / 2), "max_mp = 8 + int(INT/2) for a combatant with a spell")
	assert(int(c25.combatants["pc"][WIKeys.MP]) == int(c25.combatants["pc"][WIKeys.MAX_MP]), "mp starts at max_mp")
	assert(int(c25.combatants["goblin_raider"][WIKeys.MAX_MP]) == 0, "non-mage (no mp_cost skills) has max_mp 0")
	assert(int(c25.combatants["goblin_raider"][WIKeys.MP]) == 0, "non-mage mp is 0")
	var snap25 := c25.snapshot()
	assert((snap25["combatants"]["pc"] as Dictionary).has(WIKeys.MP) and (snap25["combatants"]["pc"] as Dictionary).has(WIKeys.MAX_MP), "snapshot combatants carry mp/max_mp")

	# --- Task 4: spell refused on insufficient MP; refusal costs nothing ---
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

	# --- Task 4: Quick Cast discounts exactly the first spell each turn ---
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

	# --- Task 4: Mana Shield absorbs damage into MP before HP ---
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

	# --- Task 4: regression — riposte still never triggers on spell hits ---
	var c29 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt"]}})
	_events.clear()
	c29.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(1, 1)
	c29.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c29.combatants["goblin_raider"][WIKeys.SKILLS] = ["counter_strike"]
	c29.active_index = c29.turn_order.find("pc")
	c29._start_turn()
	assert(c29.use_skill("frost_bolt", "goblin_raider"), "spell cast succeeds against a counter_strike holder")
	assert(_count("reaction_triggered") == 0, "spells never trigger riposte, even against a counter_strike holder with MP wired in")

	# --- Task 4: determinism holds through a spell-heavy scripted stream ---
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

	# --- Task 4: AI skips spells it cannot afford (MP) ---
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

	# --- Task 4: AI prefers flame_jet when >=2 enemies share an ally-free line ---
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

	# --- Onboarding rev Task O1: "inert" AI profile (training dummies) ---
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

	# --- M6 T1: per-fight action tally (spec §2.1 REV 2) ---
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

	# --- M7 Task E2: build-time equipment injection (damage_mod/hp_mod/
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

	# --- Skills Wave Task K2: the sneak combat read ---
	# [Sneak] in combat: 1 AP for +2 move_pool, a genuine self-buff -- no
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
	assert(int(c59.combatants["pc"][WIKeys.MOVE_POOL]) == pool59_before, "quick_movement grants nothing -- still no consumer")

	print("PASS: combat sim core rules and determinism hold")
	quit(0)
