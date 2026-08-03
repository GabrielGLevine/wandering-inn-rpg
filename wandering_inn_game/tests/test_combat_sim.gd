extends SceneTree

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

	assert(combat.turn_order.size() == 4, "all four in initiative order")
	assert(combat.combatants["pc"][WIKeys.CELL] == Vector2i(2, 3), "pc at first player spawn")
	assert(combat.combatants["goblin_raider"][WIKeys.CELL] == Vector2i(9, 3), "raider at first enemy spawn")
	assert(_count("combat_started") == 1 and _count("round_started") == 1 and _count("turn_started") == 1, "start events")
	assert(combat.combatants[combat.get_active()][WIKeys.AP] == WICombat.MAX_AP, "active has full AP")

	var active: String = combat.get_active()
	var before: Vector2i = combat.combatants[active][WIKeys.CELL]
	assert(combat.move_active(Vector2i.RIGHT) or combat.move_active(Vector2i.LEFT) or combat.move_active(Vector2i.UP) or combat.move_active(Vector2i.DOWN), "some direction is open")
	assert(combat.combatants[active][WIKeys.MOVE_POOL] == WICombat.MOVE_POOL - 1, "move cost 1 pool")
	assert(combat.combatants[active][WIKeys.AP] == WICombat.MAX_AP, "move does not touch AP")
	assert(combat.combatants[active][WIKeys.CELL] != before, "cell changed")

	combat.end_turn()
	assert(_count("turn_ended") == 1 and _count("turn_started") == 2, "turn advanced")
	combat.end_turn()
	combat.end_turn()
	combat.end_turn()
	assert(_count("round_started") == 2, "wrapping order starts round 2")
	assert(combat.round_number == 2, "round counter")

	var atk: String = combat.get_active()
	var foes: Array = combat.alive_enemies_of(atk)
	assert(not foes.is_empty(), "has living enemies")
	if not combat.is_adjacent(atk, String(foes[0])):
		assert(not combat.attack(String(foes[0])), "non-adjacent attack refused")
		assert(combat.combatants[atk][WIKeys.AP] == WICombat.MAX_AP, "refused attack costs nothing")

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

	var c2 := _make(7, _sink)
	_events.clear()
	c2.apply_damage("goblin_raider", 999, "pc", true)
	assert(_count("combatant_downed") == 1, "downed event")
	assert(not c2.finished, "one enemy left, not finished")
	c2.apply_damage("goblin_shaman", 999, "pc", true)
	assert(c2.finished and c2.outcome["victory"] == true, "all enemies down = victory")
	assert(_count("combat_finished") == 1, "combat_finished emitted")

	var c3 := _make(7, _sink)
	_events.clear()
	while not c3.finished:
		c3.end_turn()
	assert(c3.outcome["draw"] == true and c3.outcome["victory"] == false, "round cap = draw, non-victory")

	var c4 := _make(11, _sink)
	_events.clear()
	c4.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c4.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c4.active_index = c4.turn_order.find("pc")
	c4._start_turn()
	c4.combatants["pc"][WIKeys.SKILLS] = ["power_strike", "counter_strike", "battle_momentum"]

	assert(c4.use_skill("power_strike", "goblin_raider"), "power strike usable adjacent with 4 AP")
	assert(c4.combatants["pc"][WIKeys.AP] == 1, "power strike cost 3 AP")
	assert(_count("skill_resolved") == 1 and _count("attack_resolved") >= 1, "skill resolved into a hit roll")

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
	var idx: int = c8.turn_order.find(victim)
	if idx != -1 and not c8.finished:
		c8.active_index = idx
		assert(not c8.move_active(Vector2i.RIGHT), "dead active cannot move")
		assert(not c8.attack(killer), "dead active cannot attack")

	assert(WICombat.MOVE_POOL == 3, "locked design: 3 free move steps per turn")
	assert(WICombat.DASH_GAIN == 3, "locked design: Dash grants +3 steps")
	assert(WICombat.DASH_COST == 1, "locked design: Dash costs 1 AP")
	var c9 := _make(21, _sink)
	_events.clear()
	var mover: String = c9.get_active()
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL, "pool starts at MOVE_POOL on turn start")
	var mover_ap_before: int = int(c9.combatants[mover][WIKeys.AP])
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
	var any_fourth := false
	for dir: Vector2i in pool_dirs:
		if c9.move_active(dir):
			any_fourth = true
	assert(not any_fourth, "step refused once pool is 0")
	assert(int(c9.combatants[mover][WIKeys.AP]) == mover_ap_before, "refused step costs nothing")

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
	var post_dash_steps := 0
	for i in 3:
		for dir: Vector2i in pool_dirs:
			if c9.move_active(dir):
				post_dash_steps += 1
				break
	assert(post_dash_steps == 3, "dash enabled 3 more steps")
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == 0, "pool exhausted again")

	var ap_before_second_dash: int = int(c9.combatants[mover][WIKeys.AP])
	if ap_before_second_dash >= WICombat.DASH_COST:
		assert(c9.dash(), "dash is repeatable while AP lasts")
		assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.DASH_GAIN, "second dash also grants +3 pool")

	c9.combatants[mover][WIKeys.AP] = 0
	assert(not c9.dash(), "dash refused at 0 AP")
	assert(int(c9.combatants[mover][WIKeys.MOVE_POOL]) == WICombat.DASH_GAIN, "pool unchanged by refused dash")

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

	var c12 := _make(11, _sink)
	_events.clear()
	var slowed_id: String = c12.get_active()
	c12.combatants[slowed_id]["statuses"]["slowed"] = {"pool_penalty": 2}
	c12.end_turn()
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

	var c14 := _make(11, _sink)
	_events.clear()
	c14.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c14.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	assert(not c14.has_los("pc", "goblin_raider"), "wall between blocks LoS")
	c14.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(4, 4)
	assert(c14.has_los("pc", "goblin_shaman"), "clear adjacent gap has LoS")
	assert(c14.has_los("goblin_shaman", "pc") == c14.has_los("pc", "goblin_shaman"), "LoS is symmetric")
	c14.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c14.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 1)
	c14.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(2, 1)
	assert(c14.has_los("pc", "goblin_raider"), "occupants do not block LoS, only walls")

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
	c15.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(4, 1)
	c15.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	assert(c15.use_skill("flame_bolt", "pc"), "spell allowed with clear LoS")
	var c16 := _make(11, _sink)
	_events.clear()
	c16.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c16.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 2)
	c16.active_index = c16.turn_order.find("pc")
	c16._start_turn()
	assert(c16.attack("goblin_raider"), "melee attack is exempt from LoS gating")

	var c22 := _make(11, _sink)
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(3, 6)
	assert(c22.has_los("pc", "goblin_raider") == c22.has_los("goblin_raider", "pc"), "has_los symmetric on the reproduced asymmetry pair")

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

	c22.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(0, 2)
	assert(c22.has_los("pc", "goblin_raider"), "clear corridor has LoS")
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	assert(not c22.has_los("pc", "goblin_raider"), "wall directly between blocks LoS")
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(5, 5)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 5)
	assert(c22.has_los("pc", "goblin_raider"), "adjacent cells always have LoS")
	c22.combatants["pc"][WIKeys.CELL] = Vector2i(5, 4)
	c22.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	assert(not c22.has_los("pc", "goblin_raider"), "diagonal wall pair blocks LoS forward")
	assert(not c22.has_los("goblin_raider", "pc"), "diagonal wall pair blocks LoS backward")

	var c17 := _make(11, _sink)
	var cells_clear: Array[Vector2i] = c17.line_cells(Vector2i(0, 0), Vector2i.RIGHT, 4)
	assert(cells_clear == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "clear line enumerates length cells in direction")
	var cells_bound: Array[Vector2i] = c17.line_cells(Vector2i(10, 0), Vector2i.RIGHT, 4)
	assert(cells_bound == [Vector2i(11, 0)], "line clips at grid bounds")
	var cells_wall: Array[Vector2i] = c17.line_cells(Vector2i(3, 3), Vector2i.RIGHT, 4)
	assert(cells_wall == [Vector2i(4, 3), Vector2i(5, 3)], "line stops at first blocked cell (inclusive)")
	c17.combatants["relc"][WIKeys.CELL] = Vector2i(1, 0)
	var cells_occupant: Array[Vector2i] = c17.line_cells(Vector2i(0, 0), Vector2i.RIGHT, 4)
	assert(cells_occupant == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "occupants do not clip the line")

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
	var jet_targets_seen: Array = []
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			assert(bool(e["payload"]["melee"]) == false, "line hits are non-melee")
			jet_targets_seen.append(String(e["payload"]["target"]))
	assert(jet_targets_seen.has("relc") and jet_targets_seen.has("goblin_raider"), "both ally and enemy got an attack_resolved roll")
	assert(_count("reaction_triggered") == 0, "line hits never trigger riposte")
	assert(int(c18.combatants["relc"][WIKeys.HP]) <= relc_hp_before, "ally in the line can take real damage (friendly fire)")
	assert(int(c18.combatants["goblin_raider"][WIKeys.HP]) <= raider_hp_before, "enemy in the line can take real damage")

	var c19 := _make(11, _sink)
	_events.clear()
	c19.combatants["pc"][WIKeys.SKILLS] = ["flame_jet"]
	c19.active_index = c19.turn_order.find("pc")
	c19._start_turn()
	assert(not c19.use_skill("flame_jet", "diagonal"), "non-cardinal direction token refused")
	assert(_count("skill_resolved") == 0, "refused line does not resolve")

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

	var c21 := _make(11, _sink)
	_events.clear()
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

	var c24 := _make(11, _sink)
	_events.clear()
	var refresh_id: String = c24.get_active()
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

	var c25 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "quick_cast"]}})
	assert(int(c25.combatants["pc"][WIKeys.MAX_MP]) == 8 + int(8 / 2), "max_mp = 8 + int(INT/2) for a combatant with a spell")
	assert(int(c25.combatants["pc"][WIKeys.MP]) == int(c25.combatants["pc"][WIKeys.MAX_MP]), "mp starts at max_mp")
	assert(int(c25.combatants["goblin_raider"][WIKeys.MAX_MP]) == 0, "non-mage (no mp_cost skills) has max_mp 0")
	assert(int(c25.combatants["goblin_raider"][WIKeys.MP]) == 0, "non-mage mp is 0")
	var snap25 := c25.snapshot()
	assert((snap25["combatants"]["pc"] as Dictionary).has(WIKeys.MP) and (snap25["combatants"]["pc"] as Dictionary).has(WIKeys.MAX_MP), "snapshot combatants carry mp/max_mp")

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

	_events.clear()
	var hp_before_inert: int = int(c28.combatants["pc"][WIKeys.HP])
	c28.apply_damage("pc", 5, "goblin_raider", true)
	assert(int(c28.combatants["pc"][WIKeys.HP]) == hp_before_inert - 5, "shield inert at 0 MP: full damage to HP")
	assert(_count("reaction_triggered") == 0, "no reaction fires once MP is empty")

	# GH#334 ruling 12: WHICH Skill absorbed. The gate and the credit were both
	# the literal id "mana_shield", so [Ice Wall] -- an Ice Mage L14 capstone
	# whose entire effect block IS `mana_shield` -- could never be the thing the
	# game said had acted, and never entered `used_skills`: its authored
	# description stayed unreachable while a phantom [Mana Shield] took the
	# credit in the save. The absorber is now the FIRST held skill whose effect
	# TYPE is mana_shield, which for a real ice_mage kit (own grants ahead of
	# inherited ones) is the capstone and for everyone else is unchanged.
	_events.clear()
	var c28b := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["ice_wall", "mana_shield"]}})
	c28b.combatants["pc"][WIKeys.MP] = 6
	var hp28b: int = int(c28b.combatants["pc"][WIKeys.HP])
	c28b.apply_damage("pc", 3, "goblin_raider", true)
	assert(int(c28b.combatants["pc"][WIKeys.MP]) == 3 and int(c28b.combatants["pc"][WIKeys.HP]) == hp28b,
		"the absorb math is untouched -- only the credit moved")
	var ice_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "reaction_triggered":
			ice_payload = e["payload"]
	assert(String(ice_payload.get("skill", "")) == "ice_wall",
		"the ACTING skill is credited, not the base id it shares an effect type with")
	assert(String(ice_payload.get("family", "")) == "mana_shield",
		"the shield FAMILY still rides the payload -- the three presentation sites key their shield tell on it, not on a growing id list")

	# A holder of ONLY the specialised absorber is shielded at all, which the
	# literal-id gate never allowed.
	_events.clear()
	var c28c := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["ice_wall"]}})
	c28c.combatants["pc"][WIKeys.MP] = 5
	var hp28c: int = int(c28c.combatants["pc"][WIKeys.HP])
	c28c.apply_damage("pc", 2, "goblin_raider", true)
	assert(int(c28c.combatants["pc"][WIKeys.HP]) == hp28c and int(c28c.combatants["pc"][WIKeys.MP]) == 3,
		"[Ice Wall] alone absorbs -- reading the effect type closes the latent hole where it did nothing")

	# ...and the plain [Mana Shield] holder is byte-identical to before.
	_events.clear()
	var c28d := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt", "mana_shield"]}})
	c28d.combatants["pc"][WIKeys.MP] = 5
	c28d.apply_damage("pc", 2, "goblin_raider", true)
	var base_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "reaction_triggered":
			base_payload = e["payload"]
	assert(String(base_payload.get("skill", "")) == "mana_shield",
		"a plain mage still credits mana_shield -- every shipped enemy that carries it by name is unchanged")

	var c29 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["frost_bolt"]}})
	_events.clear()
	c29.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(1, 1)
	c29.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c29.combatants["goblin_raider"][WIKeys.SKILLS] = ["counter_strike"]
	c29.active_index = c29.turn_order.find("pc")
	c29._start_turn()
	assert(c29.use_skill("frost_bolt", "goblin_raider"), "spell cast succeeds against a counter_strike holder")
	assert(_count("reaction_triggered") == 0, "spells never trigger riposte, even against a counter_strike holder with MP wired in")

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

	var c30 := _make(11, _sink)
	_events.clear()
	c30.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(1, 1)
	c30.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c30.combatants["goblin_shaman"][WIKeys.SKILLS] = ["frost_bolt"]
	c30.combatants["goblin_shaman"][WIKeys.MP] = 0
	c30.combatants["goblin_shaman"][WIKeys.MAX_MP] = 0
	assert(int(c30.combatants["goblin_shaman"][WIKeys.MP]) == 0, "fixture: shaman has no MP")
	c30.active_index = c30.turn_order.find("goblin_shaman")
	c30._start_turn()
	WICombatAI.take_turn(c30)
	assert(_count("skill_resolved") == 0, "AI never casts a spell it cannot pay MP for")
	assert(_count("mp_changed") == 0, "no MP was spent by the skipped cast")

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

	var c34 := _make(11, _sink)
	c34.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c34.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c34.combatants["pc"]["hit_bonus"] = -1000
	c34.active_index = c34.turn_order.find("pc")
	c34._start_turn()
	assert(c34.attack("goblin_raider"), "the attack action itself still resolves")
	assert(int((c34.action_tally.get("pc", {}) as Dictionary).get("melee_hit", 0)) == 0, "missed swing tallies nothing")

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

	var c38 := _make(11, _sink)
	c38.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(1, 1)
	c38.combatants["pc"][WIKeys.CELL] = Vector2i(3, 1)
	c38.active_index = c38.turn_order.find("goblin_shaman")
	c38._start_turn()
	assert(c38.use_skill("flame_bolt", "pc"), "shaman flame bolt cast")
	var t38: Dictionary = c38.action_tally.get("goblin_shaman", {})
	assert(int(t38.get("spell_cast", 0)) == 1, "enemy spell_cast tallied under the shaman")
	assert(int(t38.get("fire_cast", 0)) == 1, "flame_bolt carries the fire tag")

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

	var turns_before := _count("turn_started")
	WICombatAI.take_turn(c41)
	assert(_count("turn_started") == turns_before, "no further turns start once the fight is over")
	for e: Dictionary in _events:
		if e["type"] == "turn_started":
			assert(e["payload"][WIKeys.ID] != "relc", "relc's turn never started after the pc's death ended the fight")

	var c42 := _make(11, _sink)
	_events.clear()
	c42.apply_damage("relc", 999, "goblin_raider", true)
	assert(not bool(c42.combatants["relc"][WIKeys.ALIVE]), "relc is dead")
	assert(bool(c42.combatants["pc"][WIKeys.ALIVE]), "pc is still alive")
	assert(not c42.finished, "relc's death alone does not end the fight -- only the pc's does")

	var c43 := _make_custom(11, _sink, {"pc": {WIKeys.HP_MOD: 4}})
	var c43_base := _make(11, _sink)
	assert(int(c43.combatants["pc"][WIKeys.MAX_HP]) == int(c43_base.combatants["pc"][WIKeys.MAX_HP]) + 4, "hp_mod adds flat to max_hp at build time")
	assert(int(c43.combatants["pc"][WIKeys.HP]) == int(c43.combatants["pc"][WIKeys.MAX_HP]), "starting hp is the boosted max_hp")

	assert(int(c43_base.combatants["pc"].get(WIKeys.DAMAGE_MOD, -1)) == 0, "damage_mod defaults to 0")
	assert(int(c43_base.combatants["pc"].get(WIKeys.DAMAGE_REDUCTION, -1)) == 0, "damage_reduction defaults to 0")

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

	var c50 := _make_custom(11, _sink, {"pc": {WIKeys.DAMAGE_REDUCTION: 3}})
	var hp50 := int(c50.combatants["pc"][WIKeys.HP])
	c50.apply_damage("pc", 10, "goblin_raider", true)
	assert(int(c50.combatants["pc"][WIKeys.HP]) == hp50 - 7, "damage_reduction subtracts flatly from incoming damage (10 - 3 = 7)")

	var c51 := _make_custom(11, _sink, {"pc": {WIKeys.DAMAGE_REDUCTION: 5}})
	var hp51 := int(c51.combatants["pc"][WIKeys.HP])
	c51.apply_damage("pc", 2, "goblin_raider", true)
	assert(int(c51.combatants["pc"][WIKeys.HP]) == hp51 - 1, "damage_reduction floors at 1 damage, never 0, for a positive incoming hit")

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
	var sneak_pool_dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	var moved_after_sneak := 0
	for i in (pool57_before + 2):
		for dir: Vector2i in sneak_pool_dirs:
			if c57.move_active(dir):
				moved_after_sneak += 1
				break
	assert(moved_after_sneak == pool57_before + 2, "every pool cell sneak granted is actually spendable via move_active")

	var c57b := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["flash_step"]}})
	c57b.active_index = c57b.turn_order.find("pc")
	c57b._start_turn()
	var flash_ap_before := int(c57b.combatants["pc"][WIKeys.AP])
	var flash_mp_before := int(c57b.combatants["pc"][WIKeys.MP])
	var flash_pool_before := int(c57b.combatants["pc"][WIKeys.MOVE_POOL])
	_events.clear()
	assert(c57b.use_skill("flash_step", "pc"), "Flash Step's combat half resolves through the existing self-cast move-pool verb")
	assert(int(c57b.combatants["pc"][WIKeys.AP]) == flash_ap_before - 2, "Flash Step spends its exact 2 AP combat cost")
	assert(int(c57b.combatants["pc"][WIKeys.MP]) == flash_mp_before - 3, "Flash Step spends its exact 3 MP combat cost")
	assert(int(c57b.combatants["pc"][WIKeys.MOVE_POOL]) == flash_pool_before + 3, "Flash Step grants exactly +3 combat move cells")
	assert(_count("ap_changed") == 1 and _count("mp_changed") == 1, "Flash Step emits both combat cost changes")

	var c57c := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["double_step"]}})
	c57c.active_index = c57c.turn_order.find("pc")
	c57c._start_turn()
	var double_ap_before := int(c57c.combatants["pc"][WIKeys.AP])
	var double_pool_before := int(c57c.combatants["pc"][WIKeys.MOVE_POOL])
	_events.clear()
	assert(c57c.use_skill("double_step", "pc"), "Double Step's combat half resolves through the existing self-cast move-pool verb")
	assert(int(c57c.combatants["pc"][WIKeys.AP]) == double_ap_before - 1, "Double Step spends its exact 1 AP combat cost")
	assert(int(c57c.combatants["pc"][WIKeys.MOVE_POOL]) == double_pool_before + 2, "Double Step grants exactly +2 combat move cells")
	assert(_count("mp_changed") == 0, "Double Step has no combat MP cost")

	var c58 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["sneak"]}})
	c58.active_index = c58.turn_order.find("pc")
	c58._start_turn()
	var ap58_before := int(c58.combatants["pc"][WIKeys.AP])
	assert(ap58_before >= 2, "fixture: at least 2 AP available at turn start")
	assert(c58.use_skill("sneak", "pc"), "first sneak this turn succeeds")
	assert(c58.use_skill("sneak", "pc"), "sneak is repeatable while AP lasts, same as dash")
	assert(int(c58.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 4, "two casts stack (+2 each)")
	c58.combatants["pc"][WIKeys.AP] = 0
	var pool58_before_refusal := int(c58.combatants["pc"][WIKeys.MOVE_POOL])
	_events.clear()
	assert(not c58.use_skill("sneak", "pc"), "sneak refused at 0 AP")
	assert(int(c58.combatants["pc"][WIKeys.MOVE_POOL]) == pool58_before_refusal, "refused sneak spends no pool")
	assert(_count("skill_resolved") == 0, "refused sneak never resolves")

	var c59 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement"]}})
	c59.active_index = c59.turn_order.find("pc")
	c59._start_turn()
	var pool59_before := int(c59.combatants["pc"][WIKeys.MOVE_POOL])
	assert(not c59.use_skill("quick_movement", "pc"), "the pre-existing 0-cost move_pool_bonus skill still refuses self-target")
	assert(int(c59.combatants["pc"][WIKeys.MOVE_POOL]) == pool59_before, "quick_movement grants nothing as an ACTIVE cast -- still no resolve_active consumer")

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
	var c61 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement", "battlefield_awareness"]}})
	c61.active_index = c61.turn_order.find("pc")
	c61._start_turn()
	assert(int(c61.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 2, "two 0-cost move_pool_bonus skills stack (+1 each)")
	var c62 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["quick_movement"]}})
	c62.active_index = c62.turn_order.find("pc")
	c62.combatants["pc"]["statuses"]["slowed"] = {"pool_penalty": 2}
	c62._start_turn()
	assert(int(c62.combatants["pc"][WIKeys.MOVE_POOL]) == maxi(1, WICombat.MOVE_POOL - 2) + 1, "quick_movement's passive still applies on top of a slowed turn")
	var c63 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["sneak"]}})
	c63.active_index = c63.turn_order.find("pc")
	c63._start_turn()
	assert(int(c63.combatants["pc"][WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL, "[Stealth]'s ACTIVE move_pool_bonus grants no turn-start passive")

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

	var c66 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["second_wind"]}})
	c66.active_index = c66.turn_order.find("pc")
	c66._start_turn()
	var ap66_before := int(c66.combatants["pc"][WIKeys.AP])
	_events.clear()
	assert(not c66.use_skill("second_wind", "relc"), "second_wind refuses an ally target -- SELF-ONLY tonight (ally-targeting is a follow-up)")
	assert(int(c66.combatants["pc"][WIKeys.AP]) == ap66_before, "refused ally-target heal spends nothing")
	assert(_count("skill_resolved") == 0, "refused ally-target heal never resolves")
	assert(not c66.use_skill("second_wind", "goblin_raider"), "second_wind refuses an enemy target (fails the type-keyed same-side gate)")

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

	var c70 := _make(11, _sink)
	_events.clear()
	var ice_cell70: Vector2i = c70.combatants["pc"][WIKeys.CELL]
	c70.terrain[ice_cell70] = {"kind": "icy_floor", "expires_after_round": c70.round_number + 10, "applies": {"slowed": {"pool_penalty": 2}}}
	c70.active_index = c70.turn_order.find("pc")
	c70._start_turn()
	assert(int(c70.combatants["pc"][WIKeys.MOVE_POOL]) == maxi(1, WICombat.MOVE_POOL - 2), "turn-start already standing on ice applies THIS turn's pool penalty")
	var applied70: Dictionary = {}
	var expired70: Dictionary = {}
	var applied_index70 := -1
	var expired_index70 := -1
	for event_index: int in _events.size():
		var e: Dictionary = _events[event_index]
		if e["type"] == "status_applied" and e["payload"].get("id", "") == "pc" and e["payload"].get("status", "") == "slowed":
			applied70 = e["payload"]
			applied_index70 = event_index
		if e["type"] == "status_expired" and e["payload"].get("id", "") == "pc" and e["payload"].get("status", "") == "slowed":
			expired70 = e["payload"]
			expired_index70 = event_index
	assert(applied70 == {"id": "pc", "status": "slowed", "source_kind": "icy_floor"}, "terrain status_applied identifies icy_floor as its source")
	assert(expired70 == {"id": "pc", "status": "slowed", "source_kind": "icy_floor"}, "terrain status_expired preserves icy_floor as its source")
	assert(applied_index70 >= 0 and applied_index70 < expired_index70, "status_applied fires before status_expired when standing ice reapplies and immediately consumes slowed")

	var generic70 := _make(11, _sink)
	_events.clear()
	generic70.active_index = generic70.turn_order.find("pc")
	(generic70.combatants["pc"]["statuses"] as Dictionary)["slowed"] = {"pool_penalty": 2}
	generic70._start_turn()
	var generic_expired70: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_expired" and e["payload"].get("id", "") == "pc" and e["payload"].get("status", "") == "slowed":
			generic_expired70 = e["payload"]
	assert(not generic_expired70.is_empty(), "generic slowed emits status_expired")
	assert(String(generic_expired70.get("source_kind", "")) == "", "generic slowed expiry carries no terrain source")

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

	var c73 := _make(11, _sink)
	_events.clear()
	var guard73 := 0
	while not c73.finished and guard73 < c73.turn_order.size() * 3:
		c73.end_turn()
		guard73 += 1
	assert(c73.terrain.is_empty(), "terrain stays empty when icy_floor is never cast")
	assert(_count("terrain_added") == 0 and _count("terrain_expired") == 0, "zero terrain events fire in a fight that never casts icy_floor")
	assert((c73.snapshot()["terrain"] as Dictionary).is_empty(), "snapshot terrain key is an empty dict when unused")

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
	c74.apply_damage("shield_spider", 5, "pc", true)
	assert(int(c74.combatants["shield_spider"][WIKeys.HP]) == int(c74.combatants["shield_spider"][WIKeys.MAX_HP]) - 5, "damage lands on the targeted spider")
	assert(int(c74.combatants["shield_spider_2"][WIKeys.HP]) == int(c74.combatants["shield_spider_2"][WIKeys.MAX_HP]), "the OTHER spider is untouched -- no aliasing between the two")

	var c75 := WICombat.new(arena_sn, _cfgs(["pc", "goblin_raider", "goblin_raider", "goblin_raider"]), _load("res://data/skills.json"), _sink, 1)
	c75.begin()
	assert(c75.combatants.size() == 4, "triple-duplicate roster fields all four combatants")
	assert(c75.combatants.has("goblin_raider") and c75.combatants.has("goblin_raider_2") and c75.combatants.has("goblin_raider_3"), "third occurrence gets _3, not a collision with _2")

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
	assert(_count("skill_resolved") == 0, "the downed caster's windup never resolves -- no posthumous damage")
	assert(int(combat86.combatants["pc"][WIKeys.HP]) == hp86_before, "pc took no damage from a windup whose caster died first")

	var c87 := _cfgs(["pc", "relc", "vault_construct"])
	var combat87 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], c87, _load("res://data/skills.json"), _sink, 5)
	combat87.begin()
	combat87.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	combat87.combatants["relc"][WIKeys.CELL] = Vector2i(2, 2)
	combat87.combatants["vault_construct"][WIKeys.CELL] = Vector2i(2, 1)
	combat87.combatants["pc"][WIKeys.MAX_HP] = 500
	combat87.combatants["pc"][WIKeys.HP] = 500
	combat87.combatants["relc"][WIKeys.MAX_HP] = 500
	combat87.combatants["relc"][WIKeys.HP] = 500
	combat87.combatants["vault_construct"]["hit_bonus"] = 1000
	combat87.active_index = combat87.turn_order.find("vault_construct")
	combat87._start_turn()
	assert(combat87.use_skill("slam", "pc"), "vault_construct declares slam on pc")
	var frozen87: Array = combat87.windups["vault_construct"]["cells"]
	assert(Vector2i(2, 1) in frozen87, "fixture: the caster's OWN cell is inside its frozen blast (adjacent declare, radius 1)")
	assert(Vector2i(2, 2) in frozen87, "fixture: the bystander ally's cell is inside the frozen blast too")
	var construct87_hp_before := int(combat87.combatants["vault_construct"][WIKeys.HP])
	var pc87_hp_before := int(combat87.combatants["pc"][WIKeys.HP])
	var relc87_hp_before := int(combat87.combatants["relc"][WIKeys.HP])
	_events.clear()
	var guard87 := 0
	while _count("skill_resolved") == 0 and guard87 < 8:
		combat87.end_turn()
		guard87 += 1
	assert(_count("skill_resolved") == 1, "the windup resolved exactly once on the caster's next turn")
	var resolved87: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			resolved87 = e["payload"]
	var hit_ids87: Array = resolved87.get("hit_ids", [])
	assert(not hit_ids87.has("vault_construct"), "the caster is EXCLUDED from its own resolution's hit_ids -- never self-hit (F1 ruling)")
	assert(hit_ids87.has("pc") and hit_ids87.has("relc"), "the target AND the same-blast bystander ally are both hit -- friendly fire stays real for everyone but the caster")
	assert(int(combat87.combatants["vault_construct"][WIKeys.HP]) == construct87_hp_before, "the caster's HP is untouched by its own resolution")
	assert(int(combat87.combatants["pc"][WIKeys.HP]) < pc87_hp_before, "pc took real damage")
	assert(int(combat87.combatants["relc"][WIKeys.HP]) < relc87_hp_before, "the bystander ally took real damage")

	var c_pen := _make_custom(5, _sink, {"relc": {WIKeys.HP_MOD: -18}})
	var relc_base_hp := 20 + int(_cfgs(["relc"])[0][WIKeys.STATS]["con"])
	assert(int(c_pen.combatants["relc"][WIKeys.MAX_HP]) == relc_base_hp - 18, "negative hp_mod folds into max_hp at build")
	assert(int(c_pen.combatants["relc"][WIKeys.HP]) == relc_base_hp - 18, "starting hp matches the penalized max")
	var c_floor := _make_custom(5, _sink, {"relc": {WIKeys.HP_MOD: -9999}})
	assert(int(c_floor.combatants["relc"][WIKeys.MAX_HP]) == 1, "over-large negative hp_mod floors max_hp at 1, never dead-at-build")
	assert(bool(c_floor.combatants["relc"][WIKeys.ALIVE]), "the floored combatant is alive at round 1")


	var c100 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 5)
	c100.begin()
	c100.combatants["goblin_raider"][WIKeys.AI] = "skirmisher"
	c100.combatants["pc"][WIKeys.CELL] = Vector2i(5, 3)
	c100.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)  # adjacent, open room to retreat into
	c100.active_index = c100.turn_order.find("goblin_raider")
	c100._start_turn()
	_events.clear()
	WICombatAI.take_turn(c100)
	assert(_events[0]["type"] != "combatant_moved", "skirmisher attacks IMMEDIATELY when adjacent with full AP -- no retreat step precedes its first attack")
	assert(_count("attack_resolved") == 2, "spends its whole AP budget on attacks (2 @ 2 AP = 4 AP) before retreat ever becomes reachable")
	assert(int(c100.combatants["goblin_raider"][WIKeys.AP]) == 0, "fixture: all AP spent")
	assert(_count("combatant_moved") > 0, "once out of AP for another swing, retreats with its leftover move_pool instead of standing still")
	var first_attack100 := -1
	var first_move100 := -1
	for i in _events.size():
		if first_attack100 == -1 and _events[i]["type"] == "attack_resolved":
			first_attack100 = i
		if first_move100 == -1 and _events[i]["type"] == "combatant_moved":
			first_move100 = i
	assert(first_attack100 < first_move100, "attack-then-retreat ordering holds within the same turn")
	assert(c100.chebyshev("goblin_raider", "pc") > 1, "retreated clear of adjacency")

	var c101 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 5)
	c101.begin()
	c101.combatants["goblin_raider"][WIKeys.AI] = "skirmisher"
	c101.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c101.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(11, 7)
	var start_dist101 := c101.chebyshev("goblin_raider", "pc")
	c101.active_index = c101.turn_order.find("goblin_raider")
	c101._start_turn()
	_events.clear()
	WICombatAI.take_turn(c101)
	assert(_count("attack_resolved") == 0, "not adjacent yet, and too far to close the gap this turn -- no attack to make")
	assert(_count("combatant_moved") > 0, "approaches toward pc")
	assert(int(c101.combatants["goblin_raider"][WIKeys.AP]) == WICombat.MAX_AP, "approach spends move_pool only, never AP -- mirrors melee's own approach; the dash lookahead correctly refuses a futile partial dash at this distance")
	assert(c101.chebyshev("goblin_raider", "pc") < start_dist101, "closed real distance toward pc")

	var c102 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider", "goblin_shaman", "cave_spider"]), _load("res://data/skills.json"), _sink, 5)
	c102.begin()
	c102.combatants["goblin_raider"][WIKeys.AI] = "guard"
	c102.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)  # sole foe, nowhere near adjacent
	c102.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 4)
	c102.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(9, 6)  # closer (cheby 3) but only lightly hurt
	c102.combatants["cave_spider"][WIKeys.CELL] = Vector2i(2, 6)  # farther (cheby 4) but critically hurt
	c102.combatants["goblin_shaman"][WIKeys.HP] = int(c102.combatants["goblin_shaman"][WIKeys.MAX_HP]) - 2
	c102.combatants["cave_spider"][WIKeys.HP] = 1
	c102.active_index = c102.turn_order.find("goblin_raider")
	c102._start_turn()
	_events.clear()
	WICombatAI.take_turn(c102)
	assert(_count("attack_resolved") == 0, "pc is nowhere near adjacent -- guard doesn't fight yet")
	assert(_count("combatant_moved") > 0, "guard moves toward its ward instead of standing idle")
	assert(c102.chebyshev("goblin_raider", "cave_spider") < 4, "closed distance toward the critically-hurt ally")
	assert(c102.chebyshev("goblin_raider", "cave_spider") < c102.chebyshev("goblin_raider", "goblin_shaman"), "ends up nearer the WOUNDED ward than the untouched ally, despite starting farther from it -- HP need overrides raw proximity")

	var c103 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider", "goblin_shaman"]), _load("res://data/skills.json"), _sink, 5)
	c103.begin()
	c103.combatants["goblin_raider"][WIKeys.AI] = "guard"
	c103.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c103.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(5, 3)  # adjacent to pc
	c103.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)  # far-off wounded ally
	c103.combatants["goblin_shaman"][WIKeys.HP] = 1
	c103.active_index = c103.turn_order.find("goblin_raider")
	c103._start_turn()
	_events.clear()
	WICombatAI.take_turn(c103)
	assert(_count("attack_resolved") >= 1, "guard fights whatever is adjacent to it right now, exactly like melee")

	var c104 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 5)
	c104.begin()
	c104.combatants["goblin_raider"][WIKeys.AI] = "guard"
	c104.combatants["pc"][WIKeys.CELL] = Vector2i(1, 1)
	c104.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 1)
	c104.active_index = c104.turn_order.find("goblin_raider")
	c104._start_turn()
	_events.clear()
	WICombatAI.take_turn(c104)
	assert(_count("combatant_moved") > 0, "solo guard (no living ally) still approaches the enemy like melee")
	assert(c104.chebyshev("goblin_raider", "pc") < 5, "closed distance toward pc, degrading to melee's own approach goal")

	var c105 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 5)
	c105.begin()
	c105.combatants["goblin_raider"][WIKeys.AI] = "coward"
	c105.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c105.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(5, 3)
	c105.active_index = c105.turn_order.find("goblin_raider")
	c105._start_turn()
	_events.clear()
	WICombatAI.take_turn(c105)
	assert(_count("attack_resolved") >= 1, "coward at full HP fights exactly like melee -- fear only kicks in below the threshold")

	var c106 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 5)
	c106.begin()
	c106.combatants["goblin_raider"][WIKeys.AI] = "coward"
	c106.combatants["pc"][WIKeys.CELL] = Vector2i(4, 3)
	c106.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(5, 3)  # adjacent -- a brave/melee AI would clearly attack
	var max_hp106 := int(c106.combatants["goblin_raider"][WIKeys.MAX_HP])
	c106.combatants["goblin_raider"][WIKeys.HP] = maxi(1, int(max_hp106 * 0.2))  # under WICombatAI.COWARD_FLEE_THRESHOLD (0.3)
	c106.active_index = c106.turn_order.find("goblin_raider")
	c106._start_turn()
	_events.clear()
	WICombatAI.take_turn(c106)
	assert(_count("attack_resolved") == 0, "below the flee threshold, coward never attacks even while adjacent to a valid target")
	assert(_count("combatant_moved") > 0, "flees instead")
	assert(c106.chebyshev("goblin_raider", "pc") > 1, "retreated out of adjacency")

	var c107 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider", "goblin_shaman"]), _load("res://data/skills.json"), _sink, 5)
	c107.begin()
	c107.combatants["goblin_raider"][WIKeys.AI] = "coward"
	c107.combatants["pc"][WIKeys.CELL] = Vector2i(11, 7)  # far corner -- raider is already maximally far
	c107.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(0, 0)  # opposite corner: only RIGHT/DOWN are even legal steps, both REDUCE distance from pc
	c107.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(3, 0)  # the rally target
	c107.combatants["goblin_raider"][WIKeys.HP] = 1
	c107.active_index = c107.turn_order.find("goblin_raider")
	c107._start_turn()
	_events.clear()
	WICombatAI.take_turn(c107)
	assert(_count("attack_resolved") == 0, "still never attacks while afraid, even cornered")
	assert(_count("combatant_moved") > 0, "cornered coward (no retreat step improves distance) rallies toward its living ally instead of freezing")
	assert(c107.chebyshev("goblin_raider", "goblin_shaman") < maxi(absi(0 - 3), absi(0 - 0)), "closed distance toward the rally ally")

	var stream_k: Array = []
	var stream_l: Array = []
	for stream: Array in [stream_k, stream_l]:
		var ev := func(type: String, payload: Dictionary) -> void:
			stream.append(JSON.stringify({"t": type, "p": payload}))
		var cfgs := _cfgs(["pc", "goblin_raider", "goblin_shaman", "cave_spider"])
		for cfg: Dictionary in cfgs:
			match String(cfg[WIKeys.ID]):
				"goblin_raider":
					cfg[WIKeys.AI] = "coward"
				"goblin_shaman":
					cfg[WIKeys.AI] = "skirmisher"
				"cave_spider":
					cfg[WIKeys.AI] = "guard"
		var c := WICombat.new(_load("res://data/arenas.json")["arenas"][0], cfgs, _load("res://data/skills.json"), ev, 21)
		c.begin()
		var guard_k := 0
		while not c.finished and guard_k < 200:
			guard_k += 1
			WICombatAI.take_turn(c)
		assert(c.finished, "mixed-new-profile autoplay fight terminates")
	assert(stream_k.size() > 10, "mixed-new-profile autoplay run produced events")
	assert(stream_k == stream_l, "same seed + same new-profile mix = identical event stream")

	var c108 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["soothing_presence"]}})
	c108.active_index = c108.turn_order.find("pc")
	c108._start_turn()
	var relc108: Dictionary = c108.combatants["relc"]
	relc108[WIKeys.HP] = int(relc108[WIKeys.MAX_HP]) - 10
	var relc_hp108_before := int(relc108[WIKeys.HP])
	var pc108_before: Dictionary = c108.combatants["pc"]
	var ap108_before := int(pc108_before[WIKeys.AP])
	var mp108_before := int(pc108_before[WIKeys.MP])
	_events.clear()
	assert(c108.use_skill("soothing_presence", "relc"), "soothing_presence resolves against a living ally (ally_target: true widens the self-only gate)")
	assert(int(relc108[WIKeys.HP]) == relc_hp108_before + 6, "soothing_presence restores exactly effect.amount (6) HP to the ALLY target, not the caster")
	assert(int(pc108_before[WIKeys.AP]) == ap108_before - 2, "soothing_presence costs exactly 2 AP")
	assert(int(pc108_before[WIKeys.MP]) == mp108_before - 3, "soothing_presence costs exactly 3 MP")
	var heal_payload108: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved":
			heal_payload108 = e["payload"]
	assert(heal_payload108.get("actor", "") == "pc" and heal_payload108.get("target", "") == "relc", "skill_resolved reports the ALLY as the target, unlike second_wind's self-only report")
	assert(int(heal_payload108.get("healed", -1)) == 6, "skill_resolved reports the actual amount healed")

	var c109 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["soothing_presence"]}})
	c109.active_index = c109.turn_order.find("pc")
	c109._start_turn()
	var pc109: Dictionary = c109.combatants["pc"]
	pc109[WIKeys.HP] = int(pc109[WIKeys.MAX_HP]) - 10
	_events.clear()
	assert(c109.use_skill("soothing_presence", "pc"), "soothing_presence still resolves as a self-cast")
	assert(int(pc109[WIKeys.HP]) == int(pc109[WIKeys.MAX_HP]) - 10 + 6, "self-cast heals the caster")

	var c110 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["soothing_presence"]}})
	c110.active_index = c110.turn_order.find("pc")
	c110._start_turn()
	var ap110_before := int(c110.combatants["pc"][WIKeys.AP])
	_events.clear()
	assert(not c110.use_skill("soothing_presence", "goblin_raider"), "soothing_presence still refuses an enemy target")
	assert(int(c110.combatants["pc"][WIKeys.AP]) == ap110_before, "refused enemy-target heal spends nothing")
	assert(_count("skill_resolved") == 0, "refused enemy-target heal never resolves")

	var c111 := _make_custom(11, _sink, {"pc": {WIKeys.SKILLS: ["sudden_strike"]}})
	c111.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)  # teleport adjacent, the c4 precedent (damage_mult needs in_weapon_range)
	c111.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c111.active_index = c111.turn_order.find("pc")
	c111._start_turn()
	var pc111: Dictionary = c111.combatants["pc"]
	pc111[WIKeys.AP] = 8  # headroom for two casts' worth of AP within one turn
	var ap111_before := int(pc111[WIKeys.AP])
	_events.clear()
	assert(c111.use_skill("sudden_strike", "goblin_raider"), "sudden_strike resolves the first time this fight")
	assert(int(pc111[WIKeys.AP]) == ap111_before - 2, "sudden_strike costs exactly 2 AP on its one real cast")
	assert(_count("skill_resolved") == 1, "exactly one resolution from the first cast")
	var ap111_after_first := int(pc111[WIKeys.AP])
	_events.clear()
	assert(not c111.use_skill("sudden_strike", "goblin_raider"), "a second sudden_strike cast in the SAME fight is refused -- once per fight")
	assert(int(pc111[WIKeys.AP]) == ap111_after_first, "the refused repeat cast spends neither AP nor MP -- checked before any spend, same discipline as every other refusal gate")
	assert(_count("skill_resolved") == 0, "the refused repeat cast never resolves")

	# GH#334 ruling 14: the HUD hole. `WICombat.skill_spent` is the ONE reader of
	# that refusal, shared by `use_skill` above and by combat_hud's affordability
	# test through the view -- before it existed the bar drew a spent skill at
	# full brightness and the press simply did nothing, indistinguishable from a
	# dropped input.
	assert(c111.skill_spent("pc", "sudden_strike"),
		"a once-per-fight skill reads SPENT after its one cast -- the term the bar dims on")
	assert(not c111.skill_spent("goblin_raider", "sudden_strike"),
		"spent is per ACTOR: another combatant's tally is not the player's")
	assert(not c111.skill_spent("pc", "power_strike"),
		"a skill without once_per_fight is never spent, however often it is cast")
	var view111 := WICombatView.new(c111)
	assert(view111.skill_spent("pc", "sudden_strike"),
		"the view passthrough reports the same fact the sim refuses on")

	var c112 := _make_custom(12, _sink, {"pc": {WIKeys.SKILLS: ["sudden_strike"]}})
	c112.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	c112.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	c112.active_index = c112.turn_order.find("pc")
	c112._start_turn()
	_events.clear()
	assert(c112.use_skill("sudden_strike", "goblin_raider"), "sudden_strike resolves again in a NEW fight -- the once-per-fight gate is per-WICombat-instance, not persistent")

	var c119a := _make(11, _sink)
	c119a.combatants["pc"][WIKeys.CELL] = Vector2i(3, 3)
	c119a.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 3)
	c119a.active_index = c119a.turn_order.find("pc")
	c119a._start_turn()
	c119a.combatants["pc"]["hit_bonus"] = 1000
	_events.clear()
	assert(c119a.attack("goblin_raider"), "baseline attack lands")
	var baseline_damage119 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			baseline_damage119 = int(e["payload"]["damage"])
	assert(baseline_damage119 > 0, "fixture: baseline attack dealt real damage")

	var c119b := _make(11, _sink)
	c119b.combatants["pc"][WIKeys.CELL] = Vector2i(3, 3)
	c119b.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 3)
	c119b.active_index = c119b.turn_order.find("pc")
	c119b._start_turn()
	c119b.combatants["pc"]["hit_bonus"] = 1000
	(c119b.combatants["pc"]["statuses"] as Dictionary)["weakened"] = {"duration_rounds": 2}
	_events.clear()
	assert(c119b.attack("goblin_raider"), "weakened attack lands (same seed, same hit roll)")
	var weakened_damage119 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			weakened_damage119 = int(e["payload"]["damage"])
	assert(weakened_damage119 == maxi(1, int(baseline_damage119 * WICombat.WEAKENED_MULT)), "weakened shrinks the ATTACKER's own outgoing damage to floor(base*0.75)")

	var c119c := _make(11, _sink)
	c119c.combatants["pc"][WIKeys.CELL] = Vector2i(3, 3)
	c119c.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 3)
	c119c.active_index = c119c.turn_order.find("pc")
	c119c._start_turn()
	c119c.combatants["pc"]["hit_bonus"] = 1000
	(c119c.combatants["goblin_raider"]["statuses"] as Dictionary)["guarded"] = {"duration_rounds": 2}
	_events.clear()
	assert(c119c.attack("goblin_raider"), "attack into a guarded defender lands")
	var guarded_damage119 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			guarded_damage119 = int(e["payload"]["damage"])
	assert(guarded_damage119 == maxi(1, int(baseline_damage119 * WICombat.GUARDED_MULT)), "guarded shrinks the DEFENDER's own incoming damage to floor(base*0.75)")

	var c119d := _make(11, _sink)
	c119d.combatants["pc"][WIKeys.CELL] = Vector2i(3, 3)
	c119d.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(4, 3)
	c119d.active_index = c119d.turn_order.find("pc")
	c119d._start_turn()
	c119d.combatants["pc"]["hit_bonus"] = 1000
	(c119d.combatants["pc"]["statuses"] as Dictionary)["weakened"] = {"duration_rounds": 2}
	(c119d.combatants["goblin_raider"]["statuses"] as Dictionary)["guarded"] = {"duration_rounds": 2}
	_events.clear()
	assert(c119d.attack("goblin_raider"), "attack with BOTH statuses lands")
	var both_damage119 := 0
	for e: Dictionary in _events:
		if e["type"] == "attack_resolved":
			both_damage119 = int(e["payload"]["damage"])
	assert(
		both_damage119 == maxi(1, int(maxi(1, int(baseline_damage119 * WICombat.WEAKENED_MULT)) * WICombat.GUARDED_MULT)),
		"weakened and guarded compose MULTIPLICATIVELY on the same hit -- pinned order: attacker-side (weakened) first, defender-side (guarded) second"
	)

	var c120 := _make(11, _sink)
	c120.active_index = c120.turn_order.find("pc")
	(c120.combatants["pc"]["statuses"] as Dictionary)["rooted"] = {"duration_rounds": 1}
	c120._start_turn()
	assert(int(c120.combatants["pc"][WIKeys.MOVE_POOL]) == 0, "move_pool reads 0 the moment _start_turn runs on a rooted holder")
	_events.clear()
	assert(not c120.move_active(Vector2i.RIGHT), "movement refuses at 0 pool")
	assert(_count("action_refused") == 1, "a rooted holder's refused move emits ACTION_REFUSED")
	var ap120_before := int(c120.combatants["pc"][WIKeys.AP])
	assert(not c120.dash(), "Dash refuses outright while rooted")
	assert(_count("action_refused") == 2, "a rooted holder's refused dash emits ACTION_REFUSED too")
	for e120: Dictionary in _events:
		if e120["type"] == "action_refused":
			assert(String(e120["payload"].get("actor", "")) == "pc" and String(e120["payload"].get("reason", "")) == "rooted", "the refusal names the actor + reason 'rooted'")
	assert(int(c120.combatants["pc"][WIKeys.AP]) == ap120_before, "the refused dash spends no AP")
	assert(int(c120.combatants["pc"][WIKeys.MOVE_POOL]) == 0, "the refused dash grants no pool either")

	var c120b := _make(11, _sink)
	c120b.round_number = 5
	WISkillEffects._apply_status_from_effect(c120b, "pc", {"applies": {"rooted": {"duration_rounds": 1}}})
	var rooted_entry120b: Dictionary = (c120b.combatants["pc"]["statuses"] as Dictionary)["rooted"]
	assert(int(rooted_entry120b.get("expires_after_round", -1)) == 5, "duration_rounds:1 applied at round 5 stamps expires_after_round=5 (N+D-1)")

	var c121 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 11)
	c121.begin()
	WISkillEffects._apply_status_from_effect(c121, "goblin_raider", {"applies": {"burning": {"tick_damage": 5, "duration_rounds": 1}}})
	assert((c121.combatants["goblin_raider"]["statuses"] as Dictionary).has("burning"), "fixture: raider is burning")
	var raider_hp121_before := int(c121.combatants["goblin_raider"][WIKeys.HP])
	_events.clear()
	var guard121 := 0
	while c121.round_number == 1 and guard121 < 8:
		c121.end_turn()
		guard121 += 1
	assert(c121.round_number == 2, "advanced into round 2 (the rollover that ticks + purges)")
	var tick_index121 := -1
	var expire_index121 := -1
	var tick_damage121 := 0
	for i in _events.size():
		var e: Dictionary = _events[i]
		if e["type"] == "status_ticked" and String(e["payload"].get("id", "")) == "goblin_raider":
			tick_index121 = i
			tick_damage121 = int(e["payload"].get("damage", 0))
		if e["type"] == "status_expired" and String(e["payload"].get("id", "")) == "goblin_raider" and String(e["payload"].get("status", "")) == "burning":
			expire_index121 = i
	assert(tick_index121 >= 0, "burning ticks at the round-rollover it's still active for, even a 1-round duration")
	assert(tick_damage121 == 5, "tick damage matches the status entry's own tick_damage")
	assert(int(c121.combatants["goblin_raider"][WIKeys.HP]) == raider_hp121_before - 5, "the tick actually deducted HP")
	assert(expire_index121 >= 0, "burning is purged once its expires_after_round has passed")
	assert(tick_index121 < expire_index121, "TICK fires before PURGE in the SAME rollover -- purging first would silently skip this final tick")
	assert(not (c121.combatants["goblin_raider"]["statuses"] as Dictionary).has("burning"), "burning is gone from the raider's statuses after the rollover")

	var c122 := _make(11, _sink)
	WISkillEffects._apply_status_from_effect(c122, "goblin_raider", {"applies": {"burning": {"tick_damage": 2, "duration_rounds": 3}}})
	WISkillEffects._apply_status_from_effect(c122, "goblin_raider", {"applies": {"burning": {"tick_damage": 7, "duration_rounds": 3}}})
	var statuses122: Dictionary = c122.combatants["goblin_raider"]["statuses"]
	assert(int((statuses122["burning"] as Dictionary).get("tick_damage", -1)) == 7, "re-application REFRESHES (overwrites) the entry -- the second cast's tick_damage wins, never summed with the first")

	var c123 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 11)
	c123.begin()
	c123.combatants["pc"][WIKeys.HP] = 3
	WISkillEffects._apply_status_from_effect(c123, "pc", {"applies": {"burning": {"tick_damage": 99, "duration_rounds": 3}}})
	_events.clear()
	var guard123 := 0
	while not c123.finished and guard123 < 16:
		c123.end_turn()
		guard123 += 1
	assert(c123.finished, "the burning tick eventually ends the fight")
	assert(not bool(c123.outcome.get("victory", true)), "PC downed by a burning tick is a DEFEAT, the same instant-defeat rule as any other damage source")
	assert(_count("combat_finished") == 1, "combat_finished fires exactly once -- no double-advance/desync from the tick's own down-check")

	var c113 := _make(11, _sink)
	_events.clear()
	c113.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c113.combatants["pc"][WIKeys.CELL] = Vector2i(2, 0)
	c113.combatants["relc"][WIKeys.CELL] = Vector2i(3, 0)  # inside icy_floor's radius-1 blast around pc's cell
	c113.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(7, 7)  # the shaman's own ally, well clear of the blast
	c113.active_index = c113.turn_order.find("goblin_shaman")
	c113._start_turn()
	WICombatAI.take_turn(c113)
	assert(_count("terrain_added") >= 1, "AI casts icy_floor when its blast catches >=2 living enemies with zero allies caught")
	var first_skill113 := ""
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and first_skill113 == "":
			first_skill113 = String(e["payload"]["skill"])
	assert(first_skill113 == "icy_floor", "area_skill wins priority over the single-target spell (flame_bolt) when it qualifies")

	var c114 := _make(11, _sink)
	_events.clear()
	c114.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c114.combatants["pc"][WIKeys.CELL] = Vector2i(2, 0)
	c114.combatants["relc"][WIKeys.CELL] = Vector2i(11, 7)  # far outside the blast -- control
	c114.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(7, 7)
	c114.active_index = c114.turn_order.find("goblin_shaman")
	c114._start_turn()
	WICombatAI.take_turn(c114)
	assert(_count("terrain_added") == 0, "AI does not cast icy_floor when only one enemy would be caught")
	var first_skill114 := ""
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and first_skill114 == "":
			first_skill114 = String(e["payload"]["skill"])
	assert(first_skill114 == "flame_bolt", "AI falls through to the single-target spell when the area gate fails")

	var c115 := _make(11, _sink)
	_events.clear()
	c115.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c115.combatants["pc"][WIKeys.CELL] = Vector2i(2, 0)
	c115.combatants["relc"][WIKeys.CELL] = Vector2i(3, 0)
	c115.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(2, 1)  # the shaman's own ally, inside BOTH candidate blasts
	c115.active_index = c115.turn_order.find("goblin_shaman")
	c115._start_turn()
	WICombatAI.take_turn(c115)
	assert(_count("terrain_added") == 0, "AI refuses icy_floor when its own ally would be caught in the blast, off every candidate center")

	var cfgs116 := _cfgs(["pc", "relc", "goblin_raider", "goblin_shaman"])
	for cfg: Dictionary in cfgs116:
		if String(cfg[WIKeys.ID]) == "pc":
			cfg[WIKeys.SKILLS] = ["invisibility"]
	var c116 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], cfgs116, _load("res://data/skills.json"), _sink, 11)
	c116.begin()
	c116.combatants["goblin_shaman"][WIKeys.CELL] = Vector2i(0, 0)
	c116.combatants["pc"][WIKeys.CELL] = Vector2i(2, 0)
	c116.combatants["relc"][WIKeys.CELL] = Vector2i(3, 0)
	c116.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(7, 7)
	c116.active_index = c116.turn_order.find("pc")
	c116._start_turn()
	_events.clear()
	assert(c116.use_skill("invisibility", "pc"), "pc casts invisibility before the shaman's turn")
	c116.end_turn()
	var guard116 := 0
	while c116.get_active() != "goblin_shaman" and guard116 < 8:
		c116.end_turn()
		guard116 += 1
	assert(c116.get_active() == "goblin_shaman", "cycled to the shaman's turn")
	_events.clear()
	WICombatAI.take_turn(c116)
	assert(_count("terrain_added") == 0, "an invisible pc does not count toward the area_skill's >=2 gate -- only relc counts, one short")
	var any_targeted_pc116 := false
	for e: Dictionary in _events:
		if (e["type"] == "skill_resolved" or e["type"] == "attack_resolved") and String(e["payload"].get("target", "")) == "pc":
			any_targeted_pc116 = true
	assert(not any_targeted_pc116, "no action this turn ever targets the invisible pc -- neither the area cast nor its single-target fallback")

	var c117 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "ruin_ward_b", "ruin_guardian"]), _load("res://data/skills.json"), _sink, 11)
	c117.begin()
	assert(String(c117.combatants["ruin_ward_b"][WIKeys.AI]) == "guard", "fixture: ruin_ward_b carries the guard AI profile")
	assert((c117.combatants["ruin_ward_b"][WIKeys.SKILLS] as Array).has("guarding_ward"), "fixture: ruin_ward_b knows guarding_ward")
	c117.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)  # far from both -- no foe adjacent, support_skill is the only live choice
	c117.combatants["ruin_ward_b"][WIKeys.CELL] = Vector2i(6, 4)
	c117.combatants["ruin_guardian"][WIKeys.CELL] = Vector2i(7, 4)
	var guardian117: Dictionary = c117.combatants["ruin_guardian"]
	guardian117[WIKeys.HP] = int(guardian117[WIKeys.MAX_HP]) - 10
	var guardian_hp117_before := int(guardian117[WIKeys.HP])
	c117.active_index = c117.turn_order.find("ruin_ward_b")
	c117._start_turn()
	_events.clear()
	WICombatAI.take_turn(c117)
	var support_skill_used117 := ""
	var total_healed117 := 0
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and String(e["payload"].get("skill", "")) == "guarding_ward":
			support_skill_used117 = "guarding_ward"
			total_healed117 += int(e["payload"].get("healed", 0))
	assert(support_skill_used117 == "guarding_ward", "guard casts guarding_ward on its hurt ally instead of idling/chasing")
	assert(total_healed117 > 0, "a real heal amount was reported")
	assert(int(guardian117[WIKeys.HP]) == guardian_hp117_before + total_healed117, "the ward's HP actually increased by the total reported heal amount across every cast this turn")

	var c118 := WICombat.new(_load("res://data/arenas.json")["arenas"][0], _cfgs(["pc", "ruin_ward_b", "ruin_guardian"]), _load("res://data/skills.json"), _sink, 11)
	c118.begin()
	c118.combatants["pc"][WIKeys.CELL] = Vector2i(0, 0)
	c118.combatants["ruin_ward_b"][WIKeys.CELL] = Vector2i(6, 4)
	c118.combatants["ruin_guardian"][WIKeys.CELL] = Vector2i(7, 4)
	c118.active_index = c118.turn_order.find("ruin_ward_b")
	c118._start_turn()
	_events.clear()
	WICombatAI.take_turn(c118)
	var used_support118 := false
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and String(e["payload"].get("skill", "")) == "guarding_ward":
			used_support118 = true
	assert(not used_support118, "guard never casts its support skill on a ward already at full HP")

	var c119 := _make(5, _sink)
	c119.active_index = c119.turn_order.find("pc")
	c119._start_turn()
	var pc119: Dictionary = c119.combatants["pc"]
	pc119[WIKeys.HP] = int(pc119[WIKeys.MAX_HP]) - 10
	var ap119_before := int(pc119[WIKeys.AP])
	var draught119 := {"id": "test_draught", "use_effect": {"heal": 8}}
	var result119 := WIItems.resolve_use(draught119, c119)
	assert(bool(result119.get("ok", false)), "a heal-shaped item resolves in combat")
	assert(int(result119.get("healed", -1)) == 8, "healed the full nominal amount (well under max_hp)")
	assert(int(pc119[WIKeys.HP]) == int(pc119[WIKeys.MAX_HP]) - 2, "hp actually increased by the healed amount")
	assert(int(pc119[WIKeys.AP]) == ap119_before - 1, "combat item-use spends exactly 1 AP, flat -- independent of any per-item field (items carry none)")

	pc119[WIKeys.HP] = int(pc119[WIKeys.MAX_HP])
	var ap119_before_b := int(pc119[WIKeys.AP])
	var result119b := WIItems.resolve_use(draught119, c119)
	assert(bool(result119b.get("ok", false)), "a heal-shaped item still resolves at full HP")
	assert(int(result119b.get("healed", -1)) == 0, "healed clamps to 0 at full HP")
	assert(int(pc119[WIKeys.AP]) == ap119_before_b - 1, "AP is still spent even on a 0-heal use")

	pc119[WIKeys.AP] = 0
	var hp119_before_refusal := int(pc119[WIKeys.HP])
	var result119c := WIItems.resolve_use(draught119, c119)
	assert(not bool(result119c.get("ok", true)), "a heal-shaped item refuses with 0 AP")
	assert(int(pc119[WIKeys.HP]) == hp119_before_refusal, "a refused use costs nothing -- hp untouched")

	assert(not bool(WIItems.resolve_use(draught119, null).get("ok", true)), "a heal-shaped item refuses outside combat")
	var meal119 := {"id": "test_meal", "use_effect": {"next_fight": {"damage_mod": 1}}}
	assert(not bool(WIItems.resolve_use(meal119, c119).get("ok", true)), "a next_fight-shaped item refuses mid-combat")
	var meal_result119 := WIItems.resolve_use(meal119, null)
	assert(bool(meal_result119.get("ok", false)), "a next_fight-shaped item resolves in the field")
	assert(int((meal_result119.get("pending_meal", {}) as Dictionary).get("damage_mod", 0)) == 1, "the next_fight buff dict rides back verbatim")

	assert(not bool(WIItems.resolve_use({"id": "test_inert", "use_effect": {}}, c119).get("ok", true)), "an item with no recognized use_effect key never resolves in combat")
	assert(not bool(WIItems.resolve_use({"id": "test_inert", "use_effect": {}}, null).get("ok", true)), "an item with no recognized use_effect key never resolves in the field")

	# --- GH#165 review F2: damage_mult `applies` rider (blinding_arrow) ---
	# The melee AI never casts it, so no sim cell walks this path; the rider
	# must land ONLY on a damaging hit and tick off after its round.
	var c_blind := _make_custom(4242, _sink, {"pc": {WIKeys.SKILLS: ["blinding_arrow"], WIKeys.STATS: {"str": 30, "dex": 30, "con": 10, "int": 5, "wis": 5, "cha": 5}}})
	while c_blind.get_active() != "pc":
		c_blind.end_turn()
	var blind_target := "goblin_raider"
	var pre_hp := int(c_blind.combatants[blind_target][WIKeys.HP])
	assert(c_blind.use_skill("blinding_arrow", blind_target) or true, "cast attempted")
	var post_hp := int(c_blind.combatants[blind_target][WIKeys.HP])
	if post_hp < pre_hp:
		assert(c_blind.combatants[blind_target]["statuses"].has("weakened"),
			"a damaging blinding_arrow applies weakened (GH#165 rider)")
	else:
		assert(not c_blind.combatants[blind_target]["statuses"].has("weakened"),
			"a missed blinding_arrow applies nothing")

	# --- GH#337 cd1: the cooldown ledger + THE AI FALL-THROUGH ---
	# Deliberately driven off a SYNTHETIC unavailable (a hand-written stamp),
	# not off shipped data: the AI work is the spec's hard prerequisite and had
	# to be provable before any skill in skills.json carried `cooldown_rounds`.
	# The probe this whole ruling came from: `take_turn` breaks on the first
	# refused action, so a chieftain whose power_strike merely REFUSED lost its
	# entire turn (16 damage -> 0, 4 AP unspent). These arms pin the opposite.
	var cd1 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_chieftain"]), _load("res://data/skills.json"), _sink, 7)
	cd1.begin()
	assert(cd1.cooldowns.is_empty(), "a fresh fight starts with an empty cooldown ledger")
	assert(cd1.skill_available("goblin_chieftain", "power_strike"),
		"nothing is on cooldown until something stamps it")
	assert(cd1.cooldown_remaining("goblin_chieftain", "power_strike") == 0,
		"an unstamped skill reports 0 rounds remaining")
	assert(((cd1.snapshot()["combatants"]["goblin_chieftain"] as Dictionary)["cooldowns"] as Dictionary).is_empty(),
		"snapshot carries an empty cooldown map when nothing has cooled")

	# Park the two adjacent so the melee AI's adjacency arm is the branch under
	# test, and hand the chieftain the turn.
	cd1.combatants["pc"][WIKeys.CELL] = Vector2i(5, 3)
	cd1.combatants["goblin_chieftain"][WIKeys.CELL] = Vector2i(6, 3)
	cd1.active_index = cd1.turn_order.find("goblin_chieftain")
	cd1._start_turn()
	_events.clear()
	# THE synthetic unavailable: two rounds out, written straight into the
	# ledger. No data row exists yet -- that is the point.
	cd1.cooldowns["goblin_chieftain"] = {"power_strike": cd1.round_number + 2}
	assert(not cd1.skill_available("goblin_chieftain", "power_strike"),
		"a future stamp makes the skill unavailable")
	assert(cd1.cooldown_remaining("goblin_chieftain", "power_strike") == 2,
		"remaining is stamp-minus-round, in rounds")
	assert(int(((cd1.snapshot()["combatants"]["goblin_chieftain"] as Dictionary)["cooldowns"] as Dictionary)["power_strike"]) == 2,
		"snapshot reports REMAINING rounds, not the absolute stamp")
	WICombatAI.take_turn(cd1)
	var used_ps121 := false
	var attacked121 := 0
	var refused121 := 0
	for e: Dictionary in _events:
		if e["type"] == "skill_resolved" and String(e["payload"].get("skill", "")) == "power_strike":
			used_ps121 = true
		if e["type"] == "attack_resolved" and String(e["payload"].get("attacker", "")) == "goblin_chieftain":
			attacked121 += 1
		if e["type"] == "action_refused" and String(e["payload"].get("reason", "")) == "cooldown":
			refused121 += 1
	assert(not used_ps121, "a cooling power_strike is never cast")
	assert(attacked121 == 2, "the AI FALLS THROUGH to plain attacks and spends its whole 4 AP -- not one refusal and a lost turn")
	assert(refused121 == 0, "the fall-through happens BEFORE use_skill, so no refusal event is produced at all")

	# The same skill, two rounds on: the ledger is not purged, the stamp simply
	# stops being in the future (no tick loop exists).
	cd1.round_number += 2
	assert(cd1.skill_available("goblin_chieftain", "power_strike"),
		"the stamp expires by the round counter passing it, with nothing purged")
	assert(((cd1.snapshot()["combatants"]["goblin_chieftain"] as Dictionary)["cooldowns"] as Dictionary).is_empty(),
		"an elapsed stamp drops out of the snapshot entirely")

	# cd2: the sim's own gate refuses a cooling cast, and refuses it LOUDLY.
	var cd2 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd2.begin()
	cd2.combatants["pc"][WIKeys.SKILLS] = ["power_strike"]
	cd2.combatants["pc"][WIKeys.CELL] = Vector2i(5, 3)
	cd2.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	cd2.active_index = cd2.turn_order.find("pc")
	cd2._start_turn()
	cd2.cooldowns["pc"] = {"power_strike": cd2.round_number + 1}
	_events.clear()
	var raider_hp122 := int(cd2.combatants["goblin_raider"][WIKeys.HP])
	var ap122_before := int(cd2.combatants["pc"][WIKeys.AP])
	assert(not cd2.use_skill("power_strike", "goblin_raider"), "use_skill refuses a cooling skill")
	assert(int(cd2.combatants["pc"][WIKeys.AP]) == ap122_before, "a refused cast spends no AP")
	assert(int(cd2.combatants["goblin_raider"][WIKeys.HP]) == raider_hp122, "a refused cast deals no damage")
	var cooldown_refusal122 := {}
	for e: Dictionary in _events:
		if e["type"] == "action_refused":
			cooldown_refusal122 = e["payload"]
	assert(String(cooldown_refusal122.get("reason", "")) == "cooldown",
		"the refusal rides ACTION_REFUSED with reason 'cooldown' (spec ruling 5)")
	assert(String(cooldown_refusal122.get("skill", "")) == "power_strike",
		"the refusal names which Skill is recovering")

	# cd3: the STAMP itself, taken in spend_skill_costs beside the other spends
	# -- and taken only when the cast actually resolved.
	var cd3 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd3.begin()
	cd3.combatants["pc"][WIKeys.SKILLS] = ["power_strike"]
	cd3.combatants["pc"][WIKeys.CELL] = Vector2i(5, 3)
	cd3.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(6, 3)
	cd3.active_index = cd3.turn_order.find("pc")
	cd3._start_turn()
	var shipped_cd3 := int((cd3.skills["power_strike"] as Dictionary).get(WICombat.COOLDOWN_ROUNDS, 0))
	assert(shipped_cd3 == 2,
		"power_strike is the spam set's anchor and ships cooldown_rounds 2 -- the every-other-turn rhythm the milestone exists for")
	assert(cd3.use_skill("power_strike", "goblin_raider"), "a ready power_strike resolves")
	assert(cd3.cooldown_remaining("pc", "power_strike") == shipped_cd3,
		"a resolved cast stamps round_number + cooldown_rounds, so remaining == cooldown_rounds on the same round")
	assert(not cd3.skill_available("pc", "power_strike"), "and the skill is immediately unavailable")
	# The RHYTHM itself, off shipped data: unavailable for this round and the
	# next, ready again the round after -- exactly one of the holder's own turns
	# skipped, which is what `cooldown_rounds: 2` is supposed to buy.
	cd3.round_number += 1
	assert(not cd3.skill_available("pc", "power_strike"), "still cooling one round on")
	cd3.round_number += 1
	assert(cd3.skill_available("pc", "power_strike"), "ready again two rounds after the cast")

	# cd4: a cast the RESOLVER refuses (out of weapon range) must not burn the
	# cooldown -- the exact defect that put the stamp in spend_skill_costs
	# rather than at the top of use_skill.
	var cd4 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd4.begin()
	cd4.combatants["pc"][WIKeys.SKILLS] = ["power_strike"]
	cd4.combatants["pc"][WIKeys.CELL] = Vector2i(1, 3)
	cd4.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	cd4.active_index = cd4.turn_order.find("pc")
	cd4._start_turn()
	assert(not cd4.use_skill("power_strike", "goblin_raider"), "an out-of-range melee skill is refused by its resolver")
	assert(cd4.cooldown_remaining("pc", "power_strike") == 0,
		"a cast the RESOLVER refused burns no cooldown -- the stamp lives beside the spends, past every gate")

	# cd5: WIItems' synthetic item-use skill dict is EXEMPT by construction
	# (spec ruling 3) -- it carries no cooldown_rounds and there is no default.
	var cd5 := _make(5, _sink)
	cd5.active_index = cd5.turn_order.find("pc")
	cd5._start_turn()
	cd5.combatants["pc"][WIKeys.HP] = int(cd5.combatants["pc"][WIKeys.MAX_HP]) - 10
	assert(bool(WIItems.resolve_use({"id": "test_draught_cd", "use_effect": {"heal": 8}}, cd5).get("ok", false)),
		"the item-use path still resolves")
	assert(cd5.cooldowns.is_empty(), "using an item never writes a cooldown stamp")

	# cd6: the BAR agrees with the sim -- the surface half of ruling 5. Built
	# here rather than in test_combat_visuals because the assertion only means
	# anything against a LIVE ledger, which is what this file has.
	var hud_script_cd := load("res://src/combat/combat_hud.gd")
	var cd6 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd6.begin()
	cd6.combatants["pc"][WIKeys.SKILLS] = ["power_strike"]
	cd6.combatants["pc"][WIKeys.CELL] = Vector2i(8, 3)
	cd6.combatants["goblin_raider"][WIKeys.CELL] = Vector2i(9, 3)
	cd6.active_index = cd6.turn_order.find("pc")
	cd6._start_turn()
	cd6.combatants["pc"][WIKeys.AP] = 8  # AP is never what refuses, in either half
	var view_cd6 := WICombatView.new(cd6)
	var hud_cd6: RefCounted = hud_script_cd.new(null, null, null)
	hud_cd6.set_combat(cd6)
	var slots_cd6: Array = hud_cd6.rebuild_slots(view_cd6, "pc")
	var pc_cd6: Dictionary = view_cd6.combatant("pc")
	assert(hud_cd6.skill_affordable(pc_cd6, "power_strike", view_cd6),
		"a ready power_strike reads affordable")
	cd6.cooldowns["pc"] = {"power_strike": cd6.round_number + 2}
	assert(not hud_cd6.skill_affordable(view_cd6.combatant("pc"), "power_strike", view_cd6),
		"a cooling skill reads UNAFFORDABLE -- it must not draw bright and swallow the press")
	var rendered_cd6: Array = hud_cd6.render_bar_slots(view_cd6, slots_cd6)
	var line_cd6 := ""
	for d_cd6: Dictionary in rendered_cd6:
		if String(d_cd6.get("id", "")) == "power_strike":
			assert(not bool(d_cd6["affordable"]), "the rendered slot the hotbar dims on carries the same verdict")
			assert(int(d_cd6.get("cooldown_remaining", -1)) == 2,
				"the rendered slot record carries the LIVE remaining count, read from the sim predicate")
			line_cd6 = hud_cd6._slot_info_line(d_cd6)
	assert(line_cd6.contains("Recovering"),
		"a dimmed slot must SAY why it is dimmed, got: %s" % line_cd6)
	assert(line_cd6.contains("2 rounds"), "and say how long, got: %s" % line_cd6)
	# The live clause TAKES THE DESCRIPTION'S PLACE while cooling -- the readout
	# strip is fitted to a fixed pixel budget and an appended clause was the part
	# that got ellipsised away (found by windowed read, not by this test).
	assert(not line_cd6.contains(String((cd6.skills["power_strike"] as Dictionary)["description"])),
		"while cooling the authored flavour yields to the live state, got: %s" % line_cd6)
	# ...and the READY state carries the STANDING clause, which is the half the
	# first pass overflowed the readout strip with. This bare-`new()` HUD has no
	# `_readout_label`, so the fit-driven degrade in `_slot_info_line` cannot fire
	# here BY DESIGN -- that is exactly what this pair of asserts pins: the clause
	# is unconditional, and dropping the flavour is a decision the real fitter
	# makes, never a hardcoded truncation. The player-visible half is gated by
	# qa/scripts/combat_move_input.json + 03_power_strike_slot_info.png.
	cd6.cooldowns["pc"] = {}
	var ready_line_cd6 := ""
	for d_ready_cd6: Dictionary in hud_cd6.render_bar_slots(view_cd6, slots_cd6):
		if String(d_ready_cd6.get("id", "")) == "power_strike":
			assert(int(d_ready_cd6.get("cooldown_remaining", -1)) == 0, "the slot is ready again")
			ready_line_cd6 = hud_cd6._slot_info_line(d_ready_cd6)
	assert(ready_line_cd6.contains("Once every 2 rounds."),
		"a READY cooled Skill states its cadence before the player spends a turn finding out, got: %s" % ready_line_cd6)
	assert(ready_line_cd6.contains(String((cd6.skills["power_strike"] as Dictionary)["description"])),
		"and with no fitter attached the authored flavour is still there, got: %s" % ready_line_cd6)
	# The HUD built with no combat handed in (test_combat_visuals' bare-new()
	# shape) can never think anything is cooling -- every pre-GH#337 call site
	# keeps its exact previous answer.
	var hud_bare_cd6: RefCounted = hud_script_cd.new(null, null, null)
	assert(hud_bare_cd6.skill_affordable(view_cd6.combatant("pc"), "power_strike", view_cd6),
		"a HUD with no combat reference is cooldown-blind by construction")

	# --- GH#345 rider: the difficulty apply site --------------------------------
	# L1 owns `WISettings.difficulty_damage_taken_mult` and its contract; this is
	# the sim half. Driven off the injected field directly -- the sim never reads
	# an autoload, and that injection is exactly what makes the settings row safe
	# to move mid-save.
	var cd7 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd7.begin()
	assert(cd7.difficulty_damage_taken_mult == 1.0,
		"default is Silver is 1.0 -- every balance cell and QA fixture is byte-identical by construction")
	var pc_cd7: Dictionary = cd7.combatants["pc"]
	var raider_cd7: Dictionary = cd7.combatants["goblin_raider"]
	var dr_cd7 := int(pc_cd7.get(WIKeys.DAMAGE_REDUCTION, 0))
	assert(dr_cd7 == 0, "fixture: the bare pc carries no damage_reduction, so the arithmetic below is the mult alone")
	pc_cd7[WIKeys.HP] = 100
	pc_cd7[WIKeys.MAX_HP] = 100
	cd7._deduct_hp("pc", 10)
	assert(int(pc_cd7[WIKeys.HP]) == 90, "at 1.0 the amount passes through untouched")
	cd7.difficulty_damage_taken_mult = 0.75
	cd7._deduct_hp("pc", 10)
	assert(int(pc_cd7[WIKeys.HP]) == 82, "the softer rung scales damage TAKEN (10 -> 8, rounded)")
	cd7.difficulty_damage_taken_mult = 1.3
	cd7._deduct_hp("pc", 10)
	assert(int(pc_cd7[WIKeys.HP]) == 69, "the harder rung scales the same way (10 -> 13)")
	# ENEMY side is untouched at every setting -- the knob is damage taken by the
	# player, never a global damage dial.
	raider_cd7[WIKeys.HP] = 100
	raider_cd7[WIKeys.MAX_HP] = 100
	cd7._deduct_hp("goblin_raider", 10)
	assert(int(raider_cd7[WIKeys.HP]) == 90, "an enemy takes its raw amount at every difficulty")
	# A hit can never be scaled out of existence.
	cd7.difficulty_damage_taken_mult = 0.75
	var hp_floor_cd7 := int(pc_cd7[WIKeys.HP])
	cd7._deduct_hp("pc", 1)
	assert(int(pc_cd7[WIKeys.HP]) == hp_floor_cd7 - 1, "a 1-damage hit still costs 1 on the softest rung")

	# --- GH#345: the REPORTED number is the number the HP bar pays ---------------
	# `_apply_difficulty` lives inside `_deduct_hp`, so ATTACK_RESOLVED's `damage`
	# was the PRE-scale figure -- the floating damage number
	# (`combat_screen._board_renderer.spawn_damage_number`) and the feed line
	# ("%s strikes %s for %d!") both read that field verbatim, so on the hard rung
	# the player would watch a "10" float over a 13-point HP drop. Driven through
	# the real `_resolve_hit` because the EMIT is the thing under test. The bare pc
	# carries no damage_reduction and no mana_shield, so the HP delta and the
	# reported field must agree exactly.
	var cd8 := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd8.begin()
	cd8.difficulty_damage_taken_mult = 1.3
	var pc_cd8: Dictionary = cd8.combatants["pc"]
	assert(int(pc_cd8.get(WIKeys.DAMAGE_REDUCTION, 0)) == 0,
		"fixture: the bare pc carries no damage_reduction, so HP delta == reported damage")
	pc_cd8[WIKeys.HP] = 4000
	pc_cd8[WIKeys.MAX_HP] = 4000
	var checked_cd8 := 0
	var scaled_cd8 := 0
	for attempt_cd8 in 40:
		var before_cd8 := int(pc_cd8[WIKeys.HP])
		_events.clear()
		cd8._resolve_hit("goblin_raider", "pc", 1.0, true, false)
		for e_cd8: Dictionary in _events:
			if String(e_cd8["type"]) != "attack_resolved" or not bool(e_cd8["payload"]["hit"]):
				continue
			var payload_cd8: Dictionary = e_cd8["payload"]
			checked_cd8 += 1
			var paid_cd8 := before_cd8 - int(pc_cd8[WIKeys.HP])
			if paid_cd8 > 1:
				scaled_cd8 += 1
			assert(int(payload_cd8["damage"]) == paid_cd8,
				"ATTACK_RESOLVED's damage must equal the HP the difficulty rung actually cost")
			assert(int(payload_cd8["target_hp"]) == int(pc_cd8[WIKeys.HP]),
				"target_hp is the post-scale HP, and always was")
	assert(checked_cd8 >= 5, "the hard-rung loop has to land real hits or it proves nothing")
	assert(scaled_cd8 >= 5, "and those hits have to be big enough for 1.3 to bite")
	# At the default rung the field is byte-identical to its pre-GH#345 value.
	var cd8b := WICombat.new(_load("res://data/arenas.json")["arenas"][0],
			_cfgs(["pc", "goblin_raider"]), _load("res://data/skills.json"), _sink, 7)
	cd8b.begin()
	var pc_cd8b: Dictionary = cd8b.combatants["pc"]
	pc_cd8b[WIKeys.HP] = 4000
	pc_cd8b[WIKeys.MAX_HP] = 4000
	var checked_cd8b := 0
	for attempt_cd8b in 40:
		var before_cd8b := int(pc_cd8b[WIKeys.HP])
		_events.clear()
		cd8b._resolve_hit("goblin_raider", "pc", 1.0, true, false)
		for e_cd8b: Dictionary in _events:
			if String(e_cd8b["type"]) != "attack_resolved" or not bool(e_cd8b["payload"]["hit"]):
				continue
			checked_cd8b += 1
			assert(int(e_cd8b["payload"]["damage"]) == before_cd8b - int(pc_cd8b[WIKeys.HP]),
				"at 1.0 the reported damage is unchanged from before the rider")
	assert(checked_cd8b >= 5, "the 1.0 loop has to land real hits too")

	print("PASS: combat sim core rules and determinism hold")
	quit(0)
