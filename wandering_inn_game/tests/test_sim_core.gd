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


func _last_dialogue_text() -> String:
	var text := ""
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			text = String(e["payload"]["text"])
	return text


func _last_dialogue_speaker() -> String:
	var speaker := ""
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			speaker = String(e["payload"]["speaker"])
	return speaker


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _int_cell(value: Variant) -> Array:
	var arr := value as Array
	if arr == null or arr.size() != 2:
		return []
	return [int(arr[0]), int(arr[1])]


func _entity_by_id(records: Array, id: String) -> Dictionary:
	for record: Dictionary in records:
		if String(record.get("id", "")) == id:
			return record
	return {}


func _incoming_door_landings(scene_config: Dictionary, target_map: String) -> Array:
	var out: Array = []
	for map_cfg: Dictionary in (scene_config["maps"] as Dictionary).values():
		for entity: Dictionary in map_cfg.get("entities", []):
			var transitions: Array = []
			if String(entity.get("kind", "")) == "door":
				transitions.append(entity)
			var door_when: Variant = entity.get("door_when", null)
			if door_when is Dictionary:
				transitions.append(door_when)
			for transition: Dictionary in transitions:
				if String(transition.get("to_map", "")) != target_map:
					continue
				var landing := _int_cell(transition.get("to_cell", []))
				if not landing.is_empty() and not out.has(landing):
					out.append(landing)
	return out


func _direction_cell(direction: String) -> Array:
	match direction:
		"up":
			return [0, -1]
		"down":
			return [0, 1]
		"left":
			return [-1, 0]
		"right":
			return [1, 0]
	return []


func _map_static_blockers(map_cfg: Dictionary, excluded_entity_id: String = "") -> Array:
	var out: Array = []
	for raw: Variant in map_cfg.get("blocked", []):
		var cell := _int_cell(raw)
		if not cell.is_empty() and not out.has(cell):
			out.append(cell)
	for raw_segment: Variant in (map_cfg.get("walls", {}) as Dictionary).get("segments", []):
		if not raw_segment is Dictionary:
			continue
		for segment_cell: Vector2i in WIGame.segment_cells(raw_segment as Dictionary):
			var cell := [segment_cell.x, segment_cell.y]
			if not out.has(cell):
				out.append(cell)
	# TRAP (#119): a silent non-matching exclusion shipped an inert mutation
	# guard once (#113, typo'd id) — an exclusion that resolves to no entity
	# on the map is a test bug, never a pass.
	var excluded_found := excluded_entity_id == ""
	for entity: Dictionary in map_cfg.get("entities", []):
		if String(entity.get("id", "")) == excluded_entity_id:
			excluded_found = true
			continue
		var cell := _int_cell(entity.get("cell", []))
		if not cell.is_empty() and not out.has(cell):
			out.append(cell)
	assert(excluded_found,
		"excluded_entity_id '%s' matches no entity on the map -- inert exclusion (typo?)" % excluded_entity_id)
	return out


func _canonical_route_cells(path: String, map_id: String, map_cfg: Dictionary, excluded_entity_id: String = "") -> Array:
	var route: Array = []
	var current: Array = []
	var facing: Array = []
	var active := false
	var blockers := _map_static_blockers(map_cfg, excluded_entity_id)
	for step: Dictionary in _load_json(path).get("steps", []):
		var action := String(step.get("action", ""))
		if action == "assert_state" and String(step.get("path", "")) == "current_map":
			if String(step.get("equals", "")) == map_id:
				active = true
			else:
				active = false
			continue
		if not active:
			continue
		if action == "wait_for_event" and String(step.get("type", "")) == "map_changed":
			if String((step.get("payload_contains", {}) as Dictionary).get("map", "")) != map_id:
				break
		if action == "assert_state" and String(step.get("path", "")) == "player_cell":
			current = _int_cell(step.get("equals", []))
			if not current.is_empty() and not route.has(current):
				route.append(current.duplicate())
			continue
		if action == "move" and not current.is_empty():
			facing = _direction_cell(String(step.get("direction", "")))
			for _i: int in int(step.get("steps", 1)):
				var next := [int(current[0]) + int(facing[0]), int(current[1]) + int(facing[1])]
				if blockers.has(next):
					continue
				current = next
				if not route.has(current):
					route.append(current.duplicate())
		elif action == "press" and String(step.get("name", "")) == "interact" and not current.is_empty() and not facing.is_empty():
			var target := [int(current[0]) + int(facing[0]), int(current[1]) + int(facing[1])]
			if not route.has(target):
				route.append(target)
	return route


func _toast_texts() -> Array:
	var out: Array = []
	for e: Dictionary in _events:
		if e["type"] == "toast":
			out.append(String(e["payload"].get("text", "")))
	return out


func _land_pc_hit(g: WIGame) -> void:
	var cb: WICombat = g.combat
	cb.combatants["pc"][WIKeys.CELL] = (cb.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i.RIGHT
	cb.combatants["goblin_raider"][WIKeys.HP] = 999
	cb.combatants["pc"]["hit_bonus"] = 1000
	cb.active_index = cb.turn_order.find("pc")
	cb._start_turn()
	assert(cb.attack("goblin_raider"), "guaranteed melee hit lands")


func _init() -> void:
	WITestWatchdog.arm(self)
	var scene_config := WISceneCatalog.compose()
	var skill_config := _load_json("res://data/skills.json")
	var game := WIGame.new(scene_config, skill_config, _sink, 12345)
	_check_chronicle_facts(scene_config, skill_config)

	var witch_map: Dictionary = scene_config["maps"]["witch_hollow"]
	var witch := _entity_by_id(witch_map["entities"], "riverfarm_witch")
	assert(_int_cell(witch.get("cell", [])) == [5, 8] and String(witch.get("facing", "")) == "down",
		"Eloise must stand two cells clear of the cottage and face the approach")
	assert(not (witch_map["decor"] as Array).any(func(d: Dictionary) -> bool: return _int_cell(d.get("cell", [])) == _int_cell(witch.get("cell", []))),
		"Eloise's cell must be decor-free")
	for neighbor: Array in [[4, 8], [6, 8], [5, 7], [5, 9]]:
		assert(not (witch_map["blocked"] as Array).any(func(b: Variant) -> bool: return _int_cell(b) == neighbor),
			"Eloise needs four statically open cardinal neighbors: %s" % [neighbor])

	var deep_map: Dictionary = scene_config["maps"]["deep_tunnels"]
	var cameo := _entity_by_id(deep_map["entities"], "relc_descent_cameo")
	var cameo_cell := _int_cell(cameo.get("cell", []))
	var boss := _entity_by_id(deep_map["entities"], "awakened_boss")
	var warren_mouth := _entity_by_id(deep_map["entities"], "warren_mouth")
	var warren_cell := _int_cell(warren_mouth.get("cell", []))
	assert(String(cameo.get("sprite", "")) == "relc" and maxi(absi(int(cameo_cell[0]) - int(warren_cell[0])), absi(int(cameo_cell[1]) - int(warren_cell[1]))) == 1,
		"Relc's descent cameo must remain visible beside the warren mouth")
	var deep_landings := _incoming_door_landings(scene_config, "deep_tunnels")
	assert(not deep_landings.is_empty(), "deep_tunnels needs at least one graph-derived incoming door landing")
	assert(not deep_landings.has(cameo_cell), "Relc's descent cameo must not occupy an incoming door landing")
	var deep_route := _canonical_route_cells("res://qa/scripts/deep_descent.json", "deep_tunnels", deep_map, "relc_descent_cameo")
	assert(not deep_route.is_empty() and not deep_route.has(cameo_cell),
		"Relc's descent cameo must not block the canonical descent route")
	var deep_blockers := _map_static_blockers(deep_map, "relc_descent_cameo")
	assert(not deep_blockers.has(cameo_cell) and not (deep_map["decor"] as Array).any(func(d: Dictionary) -> bool: return _int_cell(d.get("cell", [])) == cameo_cell),
		"Relc's descent cameo needs an otherwise unoccupied cell")
	assert(cameo.get("present_when", {}).get("requires", {}).get("reached_the_warren", 0) == 1,
		"Relc's cameo must be gated by reaching the warren")
	assert(cameo.get("conversation", null) == null and cameo.get("arena", null) == null,
		"Relc's field cameo must not replace the boss conversation or combat wiring")
	assert(_int_cell(cameo.get("cell", [])) != _int_cell(boss.get("cell", [])), "Relc's cameo and awakened boss must remain separate entities")
	var presence_game := WIGame.new(scene_config, skill_config, func(_type: String, _payload: Dictionary) -> void: pass, 77)
	presence_game.transition("deep_tunnels", Vector2i(11, 5))
	var live_cameo := presence_game.entities["relc_descent_cameo"] as Dictionary
	assert(not presence_game.entity_present(live_cameo), "Relc's cameo must be absent before reached_the_warren")
	presence_game.record_accomplishment("reached_the_warren")
	assert(presence_game.entity_present(live_cameo), "Relc's cameo must appear after reached_the_warren")

	# GH#199 `absent` present_when arm (the Rags conduct gate's negative leg):
	# count < threshold = present; reaching the threshold hides; ANDs with a
	# requires leg in the same when-dict.
	var absent_ent := {"id": "absent_probe", "present_when": {"absent": {"probe_kills": 1}}}
	assert(presence_game.entity_present(absent_ent), "absent-gated entity present while the counter is zero")
	presence_game.record_accomplishment("probe_kills")
	assert(not presence_game.entity_present(absent_ent), "absent-gated entity hides once the counter reaches threshold")
	var combo_ent := {"id": "combo_probe", "present_when": {"requires": {"reached_the_warren": 1}, "absent": {"probe_kills": 1}}}
	assert(not presence_game.entity_present(combo_ent), "requires+absent ANDs: absent leg fails despite met requires")
	var combo_ok := {"id": "combo_ok", "present_when": {"requires": {"reached_the_warren": 1}, "absent": {"other_counter": 1}}}
	assert(presence_game.entity_present(combo_ok), "requires+absent ANDs: both legs met = present")

	var street_map: Dictionary = scene_config["maps"]["street"]
	var upstairs_map: Dictionary = scene_config["maps"]["inn_upstairs"]
	assert(float(_entity_by_id(street_map["entities"], "bread_stall").get("field_y_sort_bias_px", 0.0)) == 20.0,
		"bread_stall needs its entity-scoped sort override")
	assert(float(_entity_by_id(upstairs_map["entities"], "lyonette_door").get("field_y_sort_bias_px", 0.0)) == 20.0,
		"lyonette_door needs its entity-scoped sort override")
	assert((upstairs_map["decor"] as Array).any(func(d: Dictionary) -> bool: return d.get("sprite", "") == "rug_tan" and _int_cell(d.get("cell", [])) == [6, 2]),
		"Lyonette's threshold needs the bounded rug zoning cue")

	var ruin_map: Dictionary = scene_config["maps"]["ruin_surface"]
	var statue := _entity_by_id(ruin_map["entities"], "ruin_court_statue")
	assert(_int_cell(statue.get("cell", [])) == [14, 4] and String(statue.get("sprite", "")) == "dungeon_statue",
		"the canonical ruin route needs a solid interactive statue at [14,4]")
	assert((ruin_map["decor"] as Array).any(func(d: Dictionary) -> bool: return d.get("sprite", "") == "dungeon_rubble" and _int_cell(d.get("cell", [])) == [10, 4]),
		"the canonical ruin route needs low rubble at [10,4]")
	var ruin_forbidden := _incoming_door_landings(scene_config, "ruin_surface")
	var ruin_encounters: Array = []
	for entity: Dictionary in ruin_map["entities"]:
		if String(entity.get("kind", "")) == "encounter":
			ruin_encounters.append(_int_cell(entity.get("cell", [])))
	for cell: Array in ruin_encounters + _canonical_route_cells("res://qa/scripts/ruin_walkthrough.json", "ruin_surface", ruin_map, "ruin_court_statue"):
		if not ruin_forbidden.has(cell):
			ruin_forbidden.append(cell)
	assert(not ruin_forbidden.is_empty() and not ruin_encounters.is_empty(),
		"ruin forbidden cells must derive from live doors, encounters, and canonical route data")
	for staging_cell: Array in [_int_cell(statue.get("cell", [])), [10, 4]]:
		assert(not ruin_forbidden.has(staging_cell),
			"new ruin staging must avoid graph-derived door landings, encounters, and route cells")

	assert(game.grid_size == Vector2i(16, 10), "grid size from config")
	assert(game.player_cell == Vector2i(2, 3), "player start cell from config")
	assert(_count("sim_initialized") == 1, "sim_initialized emitted once")

	assert(game.pc_name == "Traveler" and game.pc_race == "human" and game.pc_gender == "m", "default identity is Human/male/Traveler")
	assert(game.pc_sprite_variant() == "pc_human_m", "default variant key")
	var id_snap := game.snapshot()
	assert(id_snap["pc_name"] == "Traveler" and id_snap["pc_race"] == "human" and id_snap["pc_gender"] == "m", "identity exposed in snapshot")
	assert(id_snap["pc_sprite"] == "pc_human_m", "variant key exposed in snapshot")
	var made := WIGame.new(scene_config, skill_config, _sink, 1, {}, {}, {"pc_name": "Sella", "pc_race": "drake", "pc_gender": "f"})
	assert(made.pc_name == "Sella" and made.pc_race == "drake" and made.pc_gender == "f", "creation_config sets identity")
	assert(made.pc_sprite_variant() == "pc_drake_f", "chosen variant key")
	var dirty := WIGame.new(scene_config, skill_config, _sink, 1, {}, {}, {"pc_name": "  Trimmed  Overlong Name Here  ", "pc_race": "elf", "pc_gender": "x"})
	assert(dirty.pc_race == "human" and dirty.pc_gender == "m", "unknown race/gender sanitized to defaults")
	assert(dirty.pc_name.length() <= WIGame.PC_NAME_MAX and dirty.pc_name.strip_edges() == dirty.pc_name, "name trimmed + length-capped")
	var blank := WIGame.new(scene_config, skill_config, _sink, 1, {}, {}, {"pc_name": "   "})
	assert(blank.pc_name == "Traveler", "blank name falls back to Traveler")

	assert(game.move_player(Vector2i.UP), "open-cell move succeeds")
	assert(game.player_cell == Vector2i(2, 2), "player moved up")
	for i in 10:
		game.move_player(Vector2i.LEFT)
	assert(game.player_cell.x == 1, "west wall segment at x=0 blocks movement")
	assert(_count("player_blocked") >= 1, "blocked moves emit player_blocked")

	game.move_player(Vector2i.DOWN)  # (1,3)
	while game.player_cell.x < 7:
		assert(game.move_player(Vector2i.RIGHT), "row y=3 is open up to x=7")
	assert(not game.move_player(Vector2i.UP), "npc cell blocks movement")
	assert(game.player_facing == Vector2i.UP, "blocked move still sets facing")

	var line := game.interact()
	assert(line.get("talked", "") == "erin", "npc interact returns the pool-talked shape (Phase C)")
	assert(_last_dialogue_speaker() == "Erin", "dialogue_line emitted with Erin's speaker")
	assert(_count("dialogue_line") == 1, "dialogue_line emitted")

	game.move_player(Vector2i.DOWN)  # (7,4)
	game.move_player(Vector2i.LEFT)  # (6,4)
	game.move_player(Vector2i.LEFT)  # blocked by table, faces it
	assert(game.player_cell == Vector2i(6, 4), "player stands right of table")

	var hint_effect := game.interact()
	assert(hint_effect.get("skill_hint", "") == "basic_cleaning", "prop interact returns the hint shape, not the cast")
	assert(_count("skill_used") == 0, "interact never casts the required skill")
	assert(_count("toast") == 1, "one nudge toast")
	assert(String(_events[-1]["payload"]["text"]).contains("wipe-down"), "the nudge is the prop's authored NARRATIVE line, never a skill name")
	assert(game.accomplishment_count("cleaned_the_inn") == 0, "no accomplishment from the hint")
	assert(not game.used_skills.has("basic_cleaning"), "no used_skills entry from the hint")

	var effect := game.use_skill_field("basic_cleaning")
	assert(effect.get("accomplishment", "") == "cleaned_the_inn", "hotbar cast on the faced prop returns effect")
	assert(_count("skill_used") == 1, "skill_used emitted")
	assert(_count("accomplishment_recorded") == 3, "accomplishment_recorded emitted")
	assert(_count("toast") == 3, "hint toast + cleaning toast + D2 wage toast all emitted")
	assert(_count("gold_changed") == 1, "cleaning wage emits one gold_changed")
	assert(game.gold == 1, "cleaning the table pays the D2 wage of 1 gold")
	assert(game.accomplishment_count("cleaned_the_inn") == 1, "accomplishment stored")
	assert(game.used_skills.has("basic_cleaning"), "exploration use_skill records into used_skills")

	game.use_skill_field("basic_cleaning")
	assert(_count("skill_used") == 2, "second use still emits skill_used")
	assert(_count("accomplishment_recorded") == 4, "counter records each increment")
	assert(game.accomplishment_count("cleaned_the_inn") == 2, "count is 2 after two uses")
	# GH#202-adjacent (infinite-gold report): the chore REPEATS (Helper curve
	# rides the counter) but the tip is daily -- gold_once_per_waking on
	# dirty_table means the second same-waking clean pays nothing, and a
	# sleep re-arms exactly one more payout.
	assert(_count("gold_changed") == 1, "second same-waking clean pays no second tip")
	assert(game.gold == 1, "gold capped at the daily chore wage")
	# Re-arm across a waking is covered by entity_first_use.clear() in
	# sleep() + work_loop's Beat 6a second-day earn pins -- mutating this
	# shared flow with a sleep here would shift every downstream count.
	assert(game.accomplishment_count("never_done") == 0, "absent id counts 0")

	var none := game.use_skill("fireball", "dirty_table")
	assert(none.is_empty(), "unknown skill returns empty")
	assert(_count("skill_unknown") == 1, "skill_unknown emitted")

	var stray := game.use_skill("basic_cleaning", "erin")
	assert(stray.is_empty(), "skill on target without on_skill_use returns empty")
	assert(_count("skill_no_effect") == 1, "skill_no_effect emitted for inert target")

	var snap := game.snapshot()
	assert(snap["player_cell"] == [6, 4], "snapshot player_cell")
	assert(snap["current_map"] == "inn", "snapshot current_map")
	assert(snap["accomplishments"]["cleaned_the_inn"] == 2, "snapshot carries counts")
	assert(snap["removed_entities"].is_empty(), "snapshot carries removed_entities")

	var combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"items": _load_json("res://data/items.json"),
	}
	_events.clear()
	var g := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g.classes = {"warrior": 1}
	assert(g.classes.get("warrior", 0) == 1, "fixture: warrior 1 seeded explicitly (scene config no longer starts classed)")

	g.sleep()
	assert(_count("class_level_up") == 0, "no level without accomplishments")
	assert(_count("toast") == 1, "sleep always toasts")

	g.record_accomplishment("met_relc")

	g.transition("floodplains", Vector2i(27, 18))
	assert(g.start_combat("goblin_encounter_2"), "combat starts")
	assert(g.combat != null and g.combat.combatants.has("pc") and g.combat.combatants.has("relc"), "pc + relc fielded")
	assert((g.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("power_strike"), "pc skills from class grants")
	assert(not (g.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("counter_strike"), "no L2 skills at L1")

	g.combat.apply_damage("goblin_raider", 999, "pc", true)
	g.combat.apply_damage("goblin_shaman", 999, "pc", true)
	assert(g.combat.finished and g.combat.outcome["victory"], "forced victory")
	g.resolve_combat()
	assert(g.combat == null, "combat cleared")
	assert(g.accomplishment_count("won_combat") == 1, "victory recorded")
	assert(g.accomplishment_count("street_cleared") == 1, "street clear recorded")
	assert(not g.entities.has("goblin_encounter_2"), "encounter removed")
	assert(_count("entity_removed") == 1, "entity_removed emitted")
	assert((g.removed_entities as Array[String]).has("goblin_encounter_2"), "removed_entities tracks encounter")

	_events.clear()
	g.sleep()
	assert(g.classes["warrior"] == 2, "warrior leveled at sleep")
	assert(_count("class_level_up") == 1 and _count("skill_unlocked") == 2, "level + two skill unlocks")

	assert(g.start_combat("goblin_encounter_1"), "second combat starts")
	assert((g.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("counter_strike"), "L2 grant fielded")

	g.combat.apply_damage("pc", 999, "goblin_raider", true)
	g.combat.apply_damage("relc", 999, "goblin_raider", true)
	assert(g.combat.finished and not g.combat.outcome["victory"], "forced defeat")
	_events.clear()
	g.resolve_combat()
	assert(_count("game_over") == 1, "game_over on defeat")
	assert(g.entities.has("goblin_encounter_1"), "encounter persists after defeat")

	var goblin_parley_graph := _load_json("res://data/dialogue/goblin_parley.json")
	var cc_parley: Dictionary = combat_config.duplicate(true)
	cc_parley["dialogue"] = {"goblin_parley": goblin_parley_graph}

	var gsp1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_parley)
	gsp1.classes = {"warrior": 1}
	gsp1.transition("floodplains", Vector2i(27, 18))
	assert(gsp1.start_dialogue("goblin_parley", "goblin_encounter_2"), "parley starts")
	assert(gsp1.dialogue_choose(1), "Stand aside chosen (warrior gate met)")
	assert(gsp1.accomplishment_count("goblins_spared") == 1, "Stand aside banks goblins_spared")
	assert(gsp1.accomplishment_count("street_cleared") == 1 and gsp1.accomplishment_count("persuaded_someone") == 1, "Stand aside still banks its existing pair")
	assert(gsp1.combat == null, "no fight on the bypass")
	assert(not gsp1.entities.has("goblin_encounter_2"), "encounter removed by the bypass")

	var gsp2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_parley)
	gsp2.classes = {"warrior": 1}
	gsp2.transition("floodplains", Vector2i(27, 18))
	assert(gsp2.start_dialogue("goblin_parley", "goblin_encounter_2"), "parley starts")
	assert(gsp2.dialogue_choose(0), "Draw steel chosen")
	assert(gsp2.combat != null, "fight starts")
	gsp2.combat.apply_damage("goblin_raider", 999, "pc", true)
	gsp2.combat.apply_damage("goblin_shaman", 999, "pc", true)
	assert(gsp2.combat.finished and gsp2.combat.outcome["victory"], "forced victory")
	gsp2.resolve_combat()
	assert(gsp2.accomplishment_count("won_combat") == 1 and gsp2.accomplishment_count("street_cleared") == 1, "fight path still banks its own pair")
	assert(gsp2.accomplishment_count("goblins_spared") == 0, "a won fight never banks goblins_spared")

	var gsp3 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_parley)
	gsp3.classes = {"warrior": 1}
	gsp3.transition("floodplains", Vector2i(27, 18))
	assert(gsp3.start_dialogue("goblin_parley", "goblin_encounter_2"), "parley starts")
	assert(gsp3.dialogue_choose(2), "Back away slowly chosen")
	assert(gsp3.dialogue == null, "decline ends the conversation")
	# GH#199 outcome-based-mercy ruling (CHOICE-LOG 2026-07-19): backing away
	# IS mercy — it banks goblins_spared + goblin_left_in_peace, but never the
	# clear/persuade counters, and leaves the encounter standing.
	assert(gsp3.accomplishment_count("goblins_spared") == 1, "backing away banks goblins_spared (outcome-based mercy)")
	assert(gsp3.accomplishment_count("goblin_left_in_peace") == 1, "backing away banks the fine-grained conduct counter")
	assert(gsp3.accomplishment_count("street_cleared") == 0 and gsp3.accomplishment_count("persuaded_someone") == 0, "backing away never banks the clear/persuade counters")
	assert(gsp3.entities.has("goblin_encounter_2"), "backing away leaves the encounter in place")

	var g2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(g2.current_map == "inn", "starts on start_map")
	assert(g2.entities.has("erin") and not g2.entities.has("selys"), "entities are per-map")
	g2.player_cell = Vector2i(14, 3)
	g2.player_facing = Vector2i.RIGHT
	_events.clear()
	g2.interact()
	assert(g2.current_map == "floodplains", "door transitions map")
	assert(g2.player_cell == Vector2i(7, 6), "arrives at to_cell")
	assert(_count("map_changed") == 1, "map_changed emitted")
	assert(g2.entities.has("relc") and not g2.entities.has("erin"), "entity view rebound")
	assert(g2.is_cell_blocked(Vector2i(7, 4)), "floodplains wall blocks")
	assert(g2.is_cell_blocked(Vector2i(7, 3)), "inn footprint blocks its upper floor")
	assert(not g2.is_cell_blocked(Vector2i(7, 6)), "inn arrival apron stays clear")
	assert(g2.find_entity("erin").size() > 0 and g2.find_entity("nobody").is_empty(), "find_entity searches all maps")
	g2.player_cell = Vector2i(27, 18)
	g2.player_facing = Vector2i.RIGHT
	g2.interact()
	assert(g2.combat != null, "warband starts combat (no conversation yet)")
	g2.combat.apply_damage("goblin_raider", 999, "pc", true)
	g2.combat.apply_damage("goblin_shaman", 999, "pc", true)
	g2.resolve_combat()
	assert(g2.accomplishment_count("won_combat") == 1 and g2.accomplishment_count("street_cleared") == 1, "array on_victory records all")

	var dlg_graph := {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Erin", "text": "Hello!", "options": [
			{"text": "Fight me.", "effects": [{"start_combat": "goblin_encounter_1"}], "end": true},
			{"text": "Clear the road.", "effects": [{"remove_entity": "goblin_encounter_2"}, {"accomplishment": "street_cleared"}], "goto": "n2"},
			{"text": "Bye.", "end": true}]},
		"n2": {"speaker": "Erin", "text": "Done.", "options": [{"text": "Bye.", "end": true}]}},
	}
	var cc2: Dictionary = combat_config.duplicate(true)
	cc2["dialogue"] = {"test_conv": dlg_graph}
	var g4 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc2)
	g4.classes = {"warrior": 1}
	assert(g4.known_skills().has("basic_cleaning") and g4.known_skills().has("power_strike"), "known = innate + grants")
	_events.clear()
	assert(g4.start_dialogue("test_conv", "erin"), "dialogue starts")
	assert(g4.dialogue != null and _count("dialogue_started") == 1 and _count("dialogue_node") == 1, "started + node")
	assert(not g4.move_player(Vector2i.RIGHT), "movement refused during dialogue")
	assert(not g4.start_dialogue("test_conv", "erin"), "no dialogue during dialogue")
	assert(g4.dialogue_choose(1), "choose applies effects")
	assert(g4.find_entity("goblin_encounter_2").is_empty(), "entity removed cross-map via effect")
	assert(g4.accomplishment_count("street_cleared") == 1, "accomplishment effect recorded")
	assert(g4.dialogue != null, "goto continues dialogue")
	assert(g4.dialogue_choose(0), "end option")
	assert(g4.dialogue == null and _count("dialogue_ended") == 1, "dialogue cleared on end")
	assert(g4.start_dialogue("test_conv", "erin"), "restart")
	assert(g4.dialogue_choose(0), "fight option")
	assert(g4.dialogue == null and g4.combat != null, "dialogue ended then combat started")
	g4.combat.apply_damage("goblin_raider", 999, "pc", true)
	g4.combat.apply_damage("goblin_shaman", 999, "pc", true)
	_events.clear()
	g4.resolve_combat()
	assert(_count("combat_resolved") == 1, "combat_resolved emitted on victory")

	var quest_catalog := {"quests": [{WIKeys.ID: "the_errand", "title": "The Errand", "beats": [
		{WIKeys.ID: "deliver", "description": "Deliver the package.", "complete_when": {"package_delivered": 1}},
		{WIKeys.ID: "decide", "description": "Decide about the reward.", "complete_when": {"errand_decided": 1}},
	]}]}
	var cc4: Dictionary = cc2.duplicate(true)
	cc4["quests"] = quest_catalog
	var g6 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc4)
	_events.clear()
	g6.start_quest("the_errand")
	assert(_count("quest_started") == 1 and _count("toast") == 1, "start_quest emits event + toast")
	g6.record_accomplishment("package_delivered")
	g6.record_accomplishment("errand_decided")
	assert(_count("quest_beat_completed") == 2, "both quest beats emitted exactly once")
	assert(_count("quest_completed") == 1, "quest_completed emitted exactly once")

	var edge_graph := {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Erin", "text": "Take this.", "options": [
			{"text": "Done.", "effects": [{"accomplishment": "package_delivered"}, {"quest": "the_errand"}], "end": true},
		]}},
	}
	var cc5: Dictionary = combat_config.duplicate(true)
	cc5["dialogue"] = {"edge_conv": edge_graph}
	cc5["quests"] = quest_catalog
	var g7 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc5)
	assert(g7.start_dialogue("edge_conv", "erin"), "edge dialogue starts")
	_events.clear()
	assert(g7.dialogue_choose(0), "accomplishment before quest effect is accepted")
	assert(_count("quest_beat_completed") == 0 and _count("quest_completed") == 0, "unstarted quest does not emit beat events")
	g7.record_accomplishment("errand_decided")
	assert(_count("quest_beat_completed") == 1 and _count("quest_completed") == 1, "edge quest completes from cached started progress")

	var dlg_graph2 := {"start": "n1", "nodes": {"n1": {"speaker": "X", "text": "t", "options": [
		{"text": "fight mid-convo", "effects": [{"start_combat": "goblin_encounter_1"}], "goto": "n2"}]},
		"n2": {"speaker": "X", "text": "t2", "options": [{"text": "bye", "end": true}]}}}
	var cc3: Dictionary = combat_config.duplicate(true)
	cc3["dialogue"] = {"conv2": dlg_graph2}
	var g5 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc3)
	g5.start_dialogue("conv2", "erin")
	_events.clear()
	assert(g5.dialogue_choose(0), "choice itself succeeds")
	assert(g5.combat == null, "combat not started mid-dialogue")
	assert(_count("dialogue_effect_failed") == 1, "failure surfaced as event")
	assert(_count("pre_combat_choice") == 1, "pre_combat_choice fires even for a later-refused start_combat (the disarm case)")

	var dlg_graph3 := {"start": "n1", "nodes": {"n1": {"speaker": "X", "text": "t", "options": [
		{"text": "commit", "effects": [{"accomplishment": "relc_joined_descent"}, {"start_combat": "goblin_encounter_1"}], "end": true}]}}}
	var cc_pcc: Dictionary = combat_config.duplicate(true)
	cc_pcc["dialogue"] = {"conv3": dlg_graph3}
	var g5b := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_pcc)
	g5b.start_dialogue("conv3", "erin")
	_events.clear()
	assert(g5b.dialogue_choose(0), "committing choice succeeds")
	assert(g5b.combat != null, "ending start_combat effect starts the fight")
	var pcc_idx := -1
	var acc_idx := -1
	for ei: int in _events.size():
		var ev: Dictionary = _events[ei]
		if ev["type"] == "pre_combat_choice" and pcc_idx == -1:
			pcc_idx = ei
			assert(String((ev["payload"] as Dictionary).get("encounter", "")) == "goblin_encounter_1", "pre_combat_choice carries the start_combat target id")
		if ev["type"] == "accomplishment_recorded" and String((ev["payload"] as Dictionary).get("id", "")) == "relc_joined_descent" and acc_idx == -1:
			acc_idx = ei
	assert(pcc_idx >= 0 and acc_idx >= 0, "both pre_combat_choice and the choice's accomplishment emitted")
	assert(pcc_idx < acc_idx, "pre_combat_choice fires BEFORE the committing option's own accomplishment (the pre-effects snapshot contract)")

	_events.clear()
	var g8 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g8.player_cell = Vector2i(12, 6)
	g8.player_facing = Vector2i.DOWN
	g8.interact()
	assert(g8.accomplishment_count("read_dusty_scroll") == 1, "scroll records its flavor accomplishment")
	assert(g8.accomplishment_count("used_magic") == 0, "scroll no longer banks used_magic (O4 retirement)")
	assert(_count("accomplishment_recorded") == 1, "accomplishment_recorded emitted")
	assert(_count("toast") == 1, "scroll toasts")
	g8.interact()
	assert(g8.accomplishment_count("read_dusty_scroll") == 2, "scroll is repeatable")

	_events.clear()
	g8.sleep()
	assert(g8.classes.get("mage", 0) == 0, "retired scroll no longer grants [Mage]")

	g8.record_accomplishment("learned_magic_from_pisces")
	_events.clear()
	g8.sleep()
	assert(g8.classes.get("mage", 0) == 1, "mage class gained at sleep")
	assert(_count("class_gained") == 1, "class_gained emitted")
	assert(_count("class_level_up") == 0, "no mage level without won_combat 3")
	var gain_toast: Dictionary = _events[_events.size() - 1]
	assert(gain_toast["type"] == "toast" and gain_toast["payload"]["text"] == "[Mage] class gained! — [Frost Bolt], [Quick Cast], [Light]", "O4 grants-listing gain toast text")

	var g9 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	for i in 3:
		g9.record_accomplishment("won_combat")
	g9.record_accomplishment("learned_magic_from_pisces")
	_events.clear()
	g9.sleep()
	assert(g9.classes.get("mage", 0) == 2, "mage gains then immediately levels to 2 in the same sleep")
	assert(_count("class_gained") == 1, "gain event fires once")
	var mage_level_ups := 0
	for e: Dictionary in _events:
		if e["type"] == "class_level_up" and String(e["payload"]["class"]) == "mage":
			mage_level_ups += 1
	assert(mage_level_ups == 1, "mage level event also fires this sleep (warrior incidentally levels too on won_combat 3)")

	g9.transition("street", Vector2i(4, 3))
	assert(g9.start_combat("goblin_encounter_2"), "combat starts with mage-build pc")
	var pc_skills: Array = g9.combat.combatants["pc"][WIKeys.SKILLS]
	assert(pc_skills.has("frost_bolt") and pc_skills.has("quick_cast") and pc_skills.has("flame_jet") and pc_skills.has("mana_shield"), "pc fields full mage kit")
	assert(int(g9.combat.combatants["pc"][WIKeys.MAX_MP]) > 0, "pc has an mp pool once a caster")

	var seg_h: Array[Vector2i] = WIGame.segment_cells({"from": [2, 5], "to": [5, 5]})
	var expected_h: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]
	assert(seg_h == expected_h, "horizontal segment covers the inclusive run")
	var seg_v: Array[Vector2i] = WIGame.segment_cells({"from": [7, 4], "to": [7, 2]})
	assert(seg_v.size() == 3 and seg_v.has(Vector2i(7, 2)) and seg_v.has(Vector2i(7, 4)), "vertical segment covers the run regardless of from/to order")
	assert(WIGame.segment_cells({"from": [3, 3]}).size() == 1, "to defaults to from (single-cell segment)")
	assert(WIGame.segment_cells({}).is_empty(), "malformed segment resolves to no cells")
	var seg_config := {
		"start_map": "room",
		"player": {WIKeys.CELL: [0, 0], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"room": {
			"grid": {"width": 6, "height": 6},
			"blocked": [[4, 4]],
			"walls": {"segments": [{"from": [1, 2], "to": [3, 2], "cap": [0, 0], "face": [0, 1]}]},
			"entities": [],
		}},
	}
	var g10 := WIGame.new(seg_config, skill_config, _sink, 1)
	assert(g10.blocked_cells.size() == 4, "segment cells join listed blocked cells")
	assert(g10.is_cell_blocked(Vector2i(2, 2)), "segment interior cell blocks movement")
	assert(g10.is_cell_blocked(Vector2i(4, 4)), "listed blocked cell still blocks")
	assert(not g10.is_cell_blocked(Vector2i(2, 1)), "cap row above a face segment stays walkable")

	var diag_config := {
		"start_map": "room",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"room": {
			"grid": {"width": 6, "height": 6},
			"blocked": [],
			"entities": [],
		}},
	}

	var gDiagOpen := WIGame.new(diag_config, skill_config, _sink, 1)
	assert(gDiagOpen.move_player(Vector2i(1, 1)), "open diagonal (down-right) succeeds")
	assert(gDiagOpen.player_cell == Vector2i(2, 2), "lands on the diagonal target cell")
	assert(gDiagOpen.player_facing == Vector2i.RIGHT, "diagonal facing collapses to the horizontal cardinal")
	assert(gDiagOpen.move_player(Vector2i(-1, -1)), "open diagonal (up-left) succeeds")
	assert(gDiagOpen.player_cell == Vector2i(1, 1), "lands back on the diagonal target cell")
	assert(gDiagOpen.player_facing == Vector2i.LEFT, "up-left also collapses to a horizontal cardinal (LEFT, not UP)")
	assert(gDiagOpen.move_player(Vector2i.UP), "cardinal move still works")
	assert(gDiagOpen.player_facing == Vector2i.UP, "cardinal facing is untouched by the collapse")

	var corner_x_config := diag_config.duplicate(true)
	corner_x_config["maps"]["room"]["blocked"] = [[2, 1]]
	var gCornerX := WIGame.new(corner_x_config, skill_config, _sink, 1)
	assert(not gCornerX.is_cell_blocked(Vector2i(2, 2)), "sanity: the diagonal target itself is open")
	assert(not gCornerX.move_player(Vector2i(1, 1)), "corner rule refuses the diagonal when the x-orthogonal is blocked")
	assert(gCornerX.player_cell == Vector2i(1, 1), "player did not slide through the x-orthogonal corner")
	assert(_count("player_blocked") >= 1, "the refusal emits player_blocked like any other blocked move")

	var corner_y_config := diag_config.duplicate(true)
	corner_y_config["maps"]["room"]["blocked"] = [[1, 2]]
	var gCornerY := WIGame.new(corner_y_config, skill_config, _sink, 1)
	assert(not gCornerY.is_cell_blocked(Vector2i(2, 2)), "sanity: the diagonal target itself is open")
	assert(not gCornerY.move_player(Vector2i(1, 1)), "corner rule refuses the diagonal when the y-orthogonal is blocked")
	assert(gCornerY.player_cell == Vector2i(1, 1), "player did not slide through the y-orthogonal corner")

	var corner_target_config := diag_config.duplicate(true)
	corner_target_config["maps"]["room"]["blocked"] = [[2, 2]]
	var gCornerTarget := WIGame.new(corner_target_config, skill_config, _sink, 1)
	assert(not gCornerTarget.is_cell_blocked(Vector2i(2, 1)) and not gCornerTarget.is_cell_blocked(Vector2i(1, 2)), "sanity: both orthogonals are open")
	assert(not gCornerTarget.move_player(Vector2i(1, 1)), "a blocked diagonal target still refuses even with open orthogonals")

	var corner_both_config := diag_config.duplicate(true)
	corner_both_config["maps"]["room"]["blocked"] = [[2, 1], [1, 2]]
	var gCornerBoth := WIGame.new(corner_both_config, skill_config, _sink, 1)
	assert(not gCornerBoth.is_cell_blocked(Vector2i(2, 2)), "sanity: the diagonal target itself is open")
	assert(not gCornerBoth.move_player(Vector2i(1, 1)), "corner rule refuses when BOTH orthogonals are blocked")
	assert(gCornerBoth.player_cell == Vector2i(1, 1), "no slide through a fully pinched corner")

	var g11 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g11.transition("street", Vector2i(4, 3))
	assert(g11.start_combat("goblin_encounter_2"), "tally-bank combat starts")
	var cb11 := g11.combat
	_land_pc_hit(g11)
	(cb11.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	cb11.combatants["pc"][WIKeys.MP] = 10
	_events.clear()
	assert(cb11.use_skill("frost_bolt", "goblin_raider"), "pc casts an ice spell")
	assert(g11.seen_statuses.has("slowed"), "first-ever slowed application banks into seen_statuses")
	var status_applied_11: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			status_applied_11 = e["payload"]
	assert(bool(status_applied_11.get("first_seen", false)), "first application of a status carries first_seen:true")
	assert(String(status_applied_11.get("status_text", "")) == WIEffectText.status_line("slowed"), "status_applied carries the L1-generated glossary sentence on first encounter")
	cb11.end_turn()
	var guard11 := 0
	while cb11.get_active() != "pc" and guard11 < 8:
		cb11.end_turn()
		guard11 += 1
	assert(cb11.get_active() == "pc", "cycled back to pc's turn")
	assert(cb11.attack("goblin_raider"), "pc lands a second melee hit")
	cb11.apply_damage("goblin_raider", 9999, "pc", true)
	cb11.apply_damage("goblin_shaman", 9999, "pc", true)
	assert(cb11.finished and cb11.outcome["victory"], "forced victory")
	_events.clear()
	g11.resolve_combat()
	assert(g11.accomplishment_count("melee_hit") == 2, "melee hits banked on victory")
	assert(g11.accomplishment_count("spell_cast") == 1, "spell cast banked on victory")
	assert(g11.accomplishment_count("ice_cast") == 1, "element counter banked on victory")
	assert(g11.accomplishment_count("won_combat") == 1, "on_victory records still fire")
	assert(g11.used_skills.has("frost_bolt"), "combat use_skill records into used_skills")
	var melee_events := 0
	for e: Dictionary in _events:
		if e["type"] == "accomplishment_recorded" and String(e["payload"][WIKeys.ID]) == "melee_hit":
			melee_events += 1
			assert(int(e["payload"]["count"]) == 2, "banked counter lands in one increment")
	assert(melee_events == 1, "one accomplishment_recorded per banked counter")

	var gStatus := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	gStatus.record_accomplishment("met_relc")
	gStatus.transition("floodplains", Vector2i(27, 18))
	assert(gStatus.start_combat("goblin_encounter_2"), "status test: fight 1 starts")
	var cbS := gStatus.combat
	_land_pc_hit(gStatus)
	(cbS.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	cbS.combatants["pc"][WIKeys.MP] = 20
	_events.clear()
	assert(cbS.use_skill("frost_bolt", "goblin_raider"), "status test: cast 1 lands")
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "seen_statuses banks exactly one entry after the first-ever application")
	var applied1: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			applied1 = e["payload"]
	assert(bool(applied1.get("first_seen", false)) and String(applied1.get("status_text", "")) != "", "cast 1's status_applied is first_seen with glossary text")
	var guardS := 0
	while cbS.get_active() != "pc" and guardS < 8:
		cbS.end_turn()
		guardS += 1
	assert(cbS.get_active() == "pc", "status test: cycled back to pc for cast 2")
	_events.clear()
	assert(cbS.use_skill("frost_bolt", "goblin_raider"), "status test: cast 2 lands (same target, still alive at 999 hp)")
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "a second application of an already-seen status does not duplicate the entry")
	var applied2: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			applied2 = e["payload"]
	assert(not bool(applied2.get("first_seen", false)), "cast 2's status_applied is NOT first_seen (once-only property: no second toast)")
	assert(String(applied2.get("status_text", "")) == "", "a repeat application carries no glossary text (nothing new to formatting-cost)")
	cbS.apply_damage("goblin_raider", 9999, "pc", true)
	cbS.apply_damage("goblin_shaman", 9999, "pc", true)
	assert(cbS.finished and cbS.outcome["victory"], "status test: fight 1 forced victory")
	gStatus.resolve_combat()
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "resolve_combat does not re-merge or duplicate seen_statuses")
	assert(gStatus.start_combat("goblin_encounter_1"), "status test: fight 2 starts")
	var cbS2 := gStatus.combat
	_land_pc_hit(gStatus)
	cbS2.combatants["goblin_raider"][WIKeys.HP] = 999
	(cbS2.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	cbS2.combatants["pc"][WIKeys.MP] = 20
	_events.clear()
	assert(cbS2.use_skill("frost_bolt", "goblin_raider"), "status test: fight 2 cast lands")
	var applied3: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "status_applied":
			applied3 = e["payload"]
	assert(not bool(applied3.get("first_seen", false)), "a status seen in a PRIOR fight is not first_seen in a later one")
	assert(gStatus.seen_statuses == (["slowed"] as Array[String]), "cross-fight: still exactly one seen_statuses entry")

	var g12 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g12.find_entity("goblin_encounter_2")["trivial"] = true
	g12.transition("floodplains", Vector2i(27, 18))
	assert(g12.start_combat("goblin_encounter_2"), "trivial combat starts")
	_land_pc_hit(g12)
	(g12.combat.combatants["pc"][WIKeys.SKILLS] as Array).append("frost_bolt")
	g12.combat.combatants["pc"][WIKeys.MP] = 10
	assert(g12.combat.use_skill("frost_bolt", "goblin_raider"), "pc casts an ice spell in the trivial fight")
	g12.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g12.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	g12.resolve_combat()
	assert(g12.accomplishment_count("melee_hit") == 0, "trivial encounter banks no counters")
	assert(g12.accomplishment_count("spell_cast") == 0, "trivial encounter banks no spell_cast counter either")
	assert(g12.used_skills.has("frost_bolt"), "used_skills records the cast DESPITE the trivial encounter suppressing its accomplishment tally")
	assert(g12.accomplishment_count("won_combat") == 1, "on_victory accomplishments still record")
	assert(not g12.entities.has("goblin_encounter_2"), "trivial fight still removes the encounter")

	var g13 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g13.transition("street", Vector2i(4, 3))
	assert(g13.start_combat("goblin_encounter_2"), "arena-trivial combat starts")
	g13.combat.arena_config["trivial"] = true
	_land_pc_hit(g13)
	g13.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g13.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	g13.resolve_combat()
	assert(g13.accomplishment_count("melee_hit") == 0, "trivial arena banks no counters")
	assert(g13.accomplishment_count("won_combat") == 1, "on_victory records unaffected by arena flag")

	var g14 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g14.record_accomplishment("met_relc")
	g14.transition("street", Vector2i(4, 3))
	assert(g14.start_combat("goblin_encounter_2"), "defeat-path combat starts")
	_land_pc_hit(g14)
	g14.combat.apply_damage("pc", 9999, "goblin_raider", true)
	g14.combat.apply_damage("relc", 9999, "goblin_raider", true)
	assert(g14.combat.finished and not g14.combat.outcome["victory"], "forced defeat")
	_events.clear()
	g14.resolve_combat()
	assert(_count("game_over") == 1, "game_over on defeat")
	assert(g14.accomplishment_count("melee_hit") == 0, "defeat banks nothing")

	var g15 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	_events.clear()
	assert(g15.use_skill("light", "unlit_lantern").is_empty(), "ungranted class skill is still unknown")
	assert(_count("skill_unknown") == 1, "unknown-skill event fires pre-grant")
	g15.record_accomplishment("learned_magic_from_pisces")
	g15.sleep()
	assert(g15.classes.get("mage", 0) == 1, "mage gained at the sleep beat")
	assert(not g15.player_skills.has("light"), "light stays class-granted, never innate")
	assert(g15.known_skills().has("light"), "light is in the known set once mage is held")
	_events.clear()
	var lit := g15.use_skill("light", "unlit_lantern")
	assert(lit.get("accomplishment", "") == "lit_the_common_room", "class-granted skill fires the prop")
	assert(g15.accomplishment_count("lit_the_common_room") == 1, "prop accomplishment recorded")
	assert(_count("skill_used") == 1 and _count("toast") == 1, "skill_used + toast emitted")

	var g16 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g16.classes["warrior"] = 2
	g16.classes["mage"] = 1
	g16.record_accomplishment("melee_hit", 18)
	_events.clear()
	g16.sleep()
	assert(g16.classes["warrior"] == 5, "one sleep resolves ALL earned levels (2 -> 5)")
	assert(g16.classes["mage"] == 1, "second class untouched (its won_combat gate unmet)")
	var warrior_levels: Array = []
	var warrior_toasts: Array = []
	for e: Dictionary in _events:
		if e["type"] == "class_level_up" and String(e["payload"]["class"]) == "warrior":
			warrior_levels.append(int(e["payload"]["level"]))
		if e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Warrior"):
			warrior_toasts.append(String(e["payload"]["text"]))
	assert(warrior_levels == [3, 4, 5], "a class_level_up event per earned level, ascending")
	assert(warrior_toasts.size() == 1, "ONE batched toast per class")
	assert(warrior_toasts[0] == "[Warrior Level 2 → 5] — unlocked [Quick Movement], [Second Wind], [Dangersense] (+2 Max HP, +1 damage)", "batched toast announces span + all unlocks + felt growth")
	assert(_count("skill_unlocked") == 3, "per-level grants all unlock")
	g16.record_accomplishment("melee_hit", 30)
	_events.clear()
	g16.sleep()
	assert(g16.classes["warrior"] == 9, "second sleep walks 5 -> 9 on melee_hit 48")
	var span_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Warrior"):
			span_toast = String(e["payload"]["text"])
	assert(span_toast == "[Warrior Level 5 → 9] (+4 Max HP, +2 damage)", "grant-less batch toasts the span's own felt growth, not silence")
	g16.record_accomplishment("won_combat", 3)
	_events.clear()
	g16.sleep()
	var mage_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Mage"):
			mage_toast = String(e["payload"]["text"])
	assert(mage_toast == "[Mage Level 2] — unlocked [Flame Jet], [Mana Shield], [Flame Dart] (+1 Max MP)", "single level keeps the plain shape + felt growth")

	var g17 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g17.find_entity("goblin_encounter_2")["respawns"] = true
	g17.transition("floodplains", Vector2i(27, 18))
	assert(g17.start_combat("goblin_encounter_2"), "respawning combat starts")
	_land_pc_hit(g17)
	g17.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g17.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	_events.clear()
	g17.resolve_combat()
	assert(g17.entities.has("goblin_encounter_2"), "respawning encounter stays on the map")
	assert(_count("entity_removed") == 0, "no removal event for a respawner")
	assert(_count("combat_resolved") == 1, "victory still resolves normally")
	assert(Array(g17.dormant_encounters) == ["goblin_encounter_2"], "beaten respawner is dormant")
	assert(g17.snapshot()["dormant_encounters"] == ["goblin_encounter_2"], "snapshot exposes dormancy for QA")
	assert(g17.accomplishment_count("melee_hit") == 1, "respawner victories bank counters")
	assert(not g17.start_combat("goblin_encounter_2"), "dormant encounter refuses to re-fight before sleep")
	g17.sleep()
	assert(g17.dormant_encounters.is_empty(), "sleep re-arms respawners")
	assert(g17.start_combat("goblin_encounter_2"), "re-armed encounter fights again")
	_land_pc_hit(g17)
	g17.combat.apply_damage("goblin_raider", 9999, "pc", true)
	g17.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	g17.resolve_combat()
	assert(g17.accomplishment_count("won_combat") == 2, "second win records again")
	assert(g17.accomplishment_count("melee_hit") == 2, "second win banks counters again")

	var gp1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gp1.find_entity("goblin_encounter_2")["persistent"] = true
	gp1.transition("floodplains", Vector2i(27, 18))
	assert(gp1.start_combat("goblin_encounter_2"), "persistent combat starts")
	_land_pc_hit(gp1)
	gp1.combat.apply_damage("goblin_raider", 9999, "pc", true)
	gp1.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	_events.clear()
	gp1.resolve_combat()
	assert(gp1.entities.has("goblin_encounter_2"), "persistent encounter stays on the map")
	assert(gp1.find_entity("goblin_encounter_2").size() > 0, "persistent encounter still findable")
	assert((gp1.removed_entities as Array[String]).is_empty(), "removed_entities untouched by a persistent win")
	assert(_count("entity_removed") == 0, "no entity_removed for a persistent win")
	assert(gp1.dormant_encounters.is_empty(), "persistent (non-respawning) win never goes dormant")
	assert(gp1.start_combat("goblin_encounter_2"), "persistent encounter is immediately re-fightable")

	var gp2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gp2.transition("floodplains", Vector2i(27, 18))
	assert(gp2.start_combat("goblin_encounter_2"), "non-persistent combat starts")
	_land_pc_hit(gp2)
	gp2.combat.apply_damage("goblin_raider", 9999, "pc", true)
	gp2.combat.apply_damage("goblin_shaman", 9999, "pc", true)
	_events.clear()
	gp2.resolve_combat()
	assert(not gp2.entities.has("goblin_encounter_2"), "non-persistent encounter removed as today")
	assert((gp2.removed_entities as Array[String]).has("goblin_encounter_2"), "removed_entities tracks it")
	assert(_count("entity_removed") == 1, "entity_removed emitted as today")

	var ga1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	ga1.find_entity("goblin_encounter_2")["ally_requires"] = {"met_relc": 1}
	ga1.transition("street", Vector2i(4, 3))
	assert(ga1.start_combat("goblin_encounter_2"), "combat starts without the ally requirement met")
	assert(not ga1.combat.combatants.has("relc"), "ungated allies stay off the roster when the requirement isn't met")

	var ga2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	ga2.find_entity("goblin_encounter_2")["ally_requires"] = {"met_relc": 1}
	ga2.record_accomplishment("met_relc")
	ga2.transition("street", Vector2i(4, 3))
	assert(ga2.start_combat("goblin_encounter_2"), "combat starts with the ally requirement met")
	assert(ga2.combat.combatants.has("relc"), "ally fielded once the requirement is met")

	var g18 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g18.classes["warrior"] = 5
	g18.transition("street", Vector2i(4, 3))
	assert(g18.start_combat("goblin_encounter_2"), "combat builds with a mixed wired/unresolved-effect kit")
	var cb18 := g18.combat
	var pc18: Dictionary = cb18.combatants["pc"]
	assert((pc18[WIKeys.SKILLS] as Array).has("second_wind") and (pc18[WIKeys.SKILLS] as Array).has("quick_movement") and (pc18[WIKeys.SKILLS] as Array).has("dangersense"), "new-type skills fielded")
	cb18.active_index = cb18.turn_order.find("pc")
	cb18._start_turn()
	assert(int(pc18[WIKeys.MOVE_POOL]) == WICombat.MOVE_POOL + 1, "quick_movement's passive grants +1 move_pool every turn start")
	pc18[WIKeys.HP] = int(pc18[WIKeys.MAX_HP]) - 5
	var hp_before := int(pc18[WIKeys.HP])
	var ap_before := int(pc18[WIKeys.AP])
	assert(cb18.use_skill("second_wind", "pc"), "second_wind now resolves as a self-heal")
	assert(int(pc18[WIKeys.HP]) == mini(hp_before + 8, int(pc18[WIKeys.MAX_HP])), "second_wind restores effect.amount HP, capped at max_hp")
	assert(int(pc18[WIKeys.AP]) == ap_before - 2, "second_wind costs 2 AP")
	var ap_before2 := int(pc18[WIKeys.AP])
	assert(not cb18.use_skill("second_wind", "goblin_raider"), "second_wind still refuses an enemy target (the type-keyed same-side gate)")
	assert(not cb18.use_skill("dangersense", "goblin_raider"), "unresolved passive-shaped active still refuses")
	assert(int(pc18[WIKeys.AP]) == ap_before2, "refused casts spend nothing")
	_land_pc_hit(g18)

	var g19 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g19.classes = {"warrior": 11, "mage": 10}
	g19.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	_events.clear()
	g19.sleep()
	assert(_count("consolidation_offered") == 1, "qualifying sleep emits consolidation_offered")
	var offered_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "consolidation_offered":
			offered_payload = e["payload"]
	assert((offered_payload["parents"] as Array) == ["warrior", "mage"], "offer payload carries parents")
	assert(offered_payload["target"] == "spellsword", "offer payload carries target")
	assert(int(offered_payload["level"]) == 14, "offer payload carries merged level (11,10) -> 14")
	assert(_count("class_evolved") == 0, "evolutions are DEFERRED, not resolved, on the offering sleep")
	assert(not _events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "You sleep soundly."), "the soundly-sleep fallback never fires on an offering sleep")
	assert(g19.classes.has("warrior") and g19.classes.has("mage"), "parents are untouched until the offer resolves")
	assert(g19.pending_consolidation.get("target", "") == "spellsword", "pending offer stored on the game")

	_events.clear()
	g19.accept_consolidation()
	assert(_count("consolidation_accepted") == 1, "accept emits consolidation_accepted")
	assert(not g19.classes.has("warrior") and not g19.classes.has("mage"), "both parent classes are erased")
	assert(int(g19.classes.get("spellsword", 0)) == 14, "target class set at the merged level")
	assert(_count("class_evolved") == 0, "accept never runs the evolution stage")
	assert(g19.pending_consolidation.is_empty(), "pending offer cleared after accept")
	var post_accept_skills := g19.known_skills()
	assert(post_accept_skills.has("basic_swordwork") and post_accept_skills.has("frost_bolt"), "spellsword's inherits chain still resolves both parents' kits")
	assert(post_accept_skills.has("keener_edge"), "spellsword's own signature grant is present")

	_events.clear()
	g19.accept_consolidation()
	assert(_events.is_empty(), "accept with no pending offer emits nothing")

	var g20 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g20.classes = {"warrior": 11, "mage": 10}
	g20.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	_events.clear()
	g20.sleep()
	assert(g20.pending_consolidation.get("target", "") == "spellsword", "same setup defers with a pending offer")
	_events.clear()
	g20.decline_consolidation()
	assert(_count("consolidation_declined") == 1, "decline emits consolidation_declined")
	assert(g20.pending_consolidation.is_empty(), "pending offer cleared after decline")
	assert(_count("class_evolved") == 2, "decline resolves BOTH classes' evolutions (warrior->swordsman, mage->ice_mage)")
	assert(g20.classes.has("swordsman") and not g20.classes.has("warrior"), "warrior evolves to swordsman on decline")
	assert(g20.classes.has("ice_mage") and not g20.classes.has("mage"), "mage evolves to ice_mage on decline")

	_events.clear()
	g20.decline_consolidation()
	assert(_events.is_empty(), "decline with no pending offer emits nothing")

	var g20b := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g20b.classes = {"warrior": 6, "mage": 7}
	_events.clear()
	g20b.sleep()
	assert(g20b.pending_consolidation.is_empty(), "warrior 6 / mage 7 (sum 13, both below min_parent_level 10) no longer triggers an offer -- the retune's own invariant")
	assert(_count("class_evolved") == 0, "neither class is at its evolution at_level yet -- no outcome at all")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "You sleep soundly."), "a sleep with no offer and no evolution outcome still falls through to the soundly-sleep fallback")

	var g21 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g21.classes = {"warrior": 11, "mage": 10}
	g21.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	g21.sleep()
	_events.clear()
	g21.decline_consolidation()
	g21.classes = {"warrior": 11, "mage": 10}
	_events.clear()
	g21.sleep()
	assert(_count("consolidation_offered") == 1, "decline does not suppress future offers -- re-offered at the next qualifying sleep")

	var g22 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g22.classes = {"warrior": 11, "mage": 10}
	g22.accomplishments = {"sword_skill_used": 12, "spear_skill_used": 2, "ice_cast": 13, "fire_cast": 1}
	g22.sleep()
	assert(g22.pending_consolidation.get("target", "") == "spellsword", "offer pending")
	g22.accomplishments["spear_skill_used"] = 20
	_events.clear()
	g22.decline_consolidation()
	assert(g22.classes.has("spearmaster"), "decline recomputes evolutions from CURRENT (post-offer-mutation) counters, not stale ones")
	assert(not g22.classes.has("swordsman"), "the stale sword-dominant outcome from offer time is NOT applied")

	var g23 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	_events.clear()
	g23.accept_consolidation()
	g23.decline_consolidation()
	assert(_events.is_empty(), "accept/decline on a game with no offer ever emits nothing")

	var cc_arc := combat_config.duplicate(true)
	cc_arc["acts"] = _load_json("res://data/acts.json")
	cc_arc["quests"] = {"quests": [
		{WIKeys.ID: "q_a", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qa_done": 1}}]},
		{WIKeys.ID: "q_b", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qb_done": 1}}]},
		{WIKeys.ID: "q_c", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qc_done": 1}}]},
	]}
	var arc := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_arc)
	arc.classes = {"warrior": 11, "mage": 10}
	arc.started_quests.assign(["q_a", "q_b", "q_c"])
	arc.accomplishments = {"reached_liscor": 1, "qa_done": 1, "qb_done": 1, "qc_done": 1}
	arc.reprime_quests()
	assert(arc.act_summary()[WIKeys.ID] == "act_ii", "AF I1 baseline: pre-flag act line sits at Act II (gate reads reached_two_classes, not classes.size())")

	_events.clear()
	arc.sleep()
	assert(arc.accomplishment_count("reached_two_classes") == 1, "AF I1: the qualifying sleep banks reached_two_classes")
	assert(arc.pending_consolidation.get("target", "") == "spellsword", "AF I1: that sleep defers with a [Spellsword] offer")
	assert(arc.accomplishment_count("watch_runner_pointed") == 0, "AF I1: the offer sleep defers the tremor pointer (one-sleep delay)")
	assert(arc.act_summary()[WIKeys.ID] == "act_iii", "AF I1: flag banked -> act line advances to Act III")

	arc.accept_consolidation()
	assert(arc.classes.size() == 1 and arc.classes.has("spellsword"), "AF I1: accepted merge leaves a single [Spellsword] class")
	assert(arc.accomplishment_count("reached_two_classes") == 1, "AF I1: reached_two_classes survives the merge (monotonic, never un-banked)")
	assert(arc.act_summary()[WIKeys.ID] == "act_iii", "AF I1: post-consolidation act line stays Act III, never walks back to Act II")

	_events.clear()
	arc.sleep()
	assert(arc.accomplishment_count("watch_runner_pointed") == 1, "AF I1: post-consolidation sleep fires the tremor pointer (gate reads the flag, not the live count)")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "A Watch runner is looking for you."), "AF I1: the Watch-runner pointer toast renders after consolidation")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "A Watch runner is looking for you." and bool(e["payload"].get("sticky", false))), "GH#273: the pointer toast carries sticky=true -- it queues LAST at a busy wake beat and must survive message_layer's transition queue-wipe")

	var cc_garden := combat_config.duplicate(true)
	cc_garden["acts"] = _load_json("res://data/acts.json")
	cc_garden["quests"] = {"quests": [
		{WIKeys.ID: "q_a", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qa_done": 1}}]},
		{WIKeys.ID: "q_b", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qb_done": 1}}]},
		{WIKeys.ID: "q_c", "beats": [{WIKeys.ID: "b", "description": "", "complete_when": {"qc_done": 1}}]},
	]}
	var gg := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_garden)
	gg.classes = {"warrior": 1}
	gg.started_quests.assign(["q_a", "q_b", "q_c"])
	gg.accomplishments = {"reached_liscor": 1, "qa_done": 1, "qb_done": 1, "qc_done": 1}
	gg.reprime_quests()
	assert(gg.act_summary()[WIKeys.ID] == "act_ii", "garden gate baseline: 1 class, quests done, but reached_two_classes unbanked -> still Act II")

	_events.clear()
	gg.sleep()
	assert(gg.accomplishment_count("garden_door_unlocked") == 0, "garden gate: act < III refuses regardless of legs")

	gg.classes["helper"] = 1
	gg.accomplishments["cleaned_the_inn"] = 1
	_events.clear()
	gg.sleep()
	assert(gg.act_summary()[WIKeys.ID] == "act_iii", "garden gate: 2nd class + 3 quests => Act III this sleep")
	assert(gg.accomplishment_count("garden_door_unlocked") == 0, "garden gate: Act III reached but only 1 of 4 legs banked -- K=2 still unmet")

	gg.accomplishments["resolved_wrong_order"] = 1
	_events.clear()
	gg.sleep()
	assert(gg.accomplishment_count("garden_door_unlocked") == 1, "garden gate: K=2 of 4 (cleaned_the_inn + resolved_wrong_order) + Act III unlocks the garden")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "accomplishment_recorded" and String(e["payload"]["id"]) == "garden_door_unlocked"), "garden gate: the unlock fires accomplishment_recorded")

	_events.clear()
	gg.sleep()
	assert(gg.accomplishment_count("garden_door_unlocked") == 1, "garden gate: idempotent past the first qualifying sleep")
	assert(not _events.any(func(e: Dictionary) -> bool: return e["type"] == "accomplishment_recorded" and String(e["payload"]["id"]) == "garden_door_unlocked"), "garden gate: no re-bank on a later sleep")

	gg.record_accomplishment("sign_defended")
	_events.clear()
	gg.sleep()
	assert(gg.accomplishment_count("garden_door_unlocked") == 1, "garden gate: banking a 3rd leg post-qualification stays at 1, never bumps")
	assert(not _events.any(func(e: Dictionary) -> bool: return e["type"] == "accomplishment_recorded" and String(e["payload"]["id"]) == "garden_door_unlocked"), "garden gate: banking sign_defended after qualification does not re-fire the unlock event")

	var gGuard := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gGuard.bind_map_silent("garden_sanctuary", Vector2i(1, 1))
	assert(not gGuard.start_combat("goblin_encounter_2"), "garden sim guard: start_combat refuses on the garden map")
	assert(gGuard.combat == null, "garden sim guard: no combat instance is ever built")
	gGuard.bind_map_silent("floodplains", Vector2i(1, 1))
	assert(gGuard.start_combat("goblin_encounter_2"), "garden sim guard control: start_combat still works normally off the garden map")

	var gMem := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345)
	gMem.player_skills.append("observe")
	assert(gMem.known_skills().has("observe"), "memorial observe test: [Appraise Foe] known")
	gMem.bind_map_silent("garden_sanctuary", Vector2i(6, 2))
	gMem.player_facing = Vector2i.UP  # faces memorial_plot_warren at (6,1)
	_events.clear()
	var before_res := gMem.use_skill_field("observe")
	assert(before_res.get("observed", "") == "memorial_plot_warren", "memorial observe: pre-claim appraise targets the plot")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "A stone plinth, swept clean, facing the axis like the others. Whatever belongs here hasn't been carried up from below yet."), "memorial observe: pre-claim reads the WAITING plinth line, not the remembrance")
	assert(gMem.accomplishment_count("cleared_the_warren") == 0, "memorial observe: appraising the plinth never itself banks the story beat")

	gMem.accomplishments["cleared_the_warren"] = 1
	_events.clear()
	var after_res := gMem.use_skill_field("observe")
	assert(after_res.get("observed", "") == "memorial_plot_warren", "memorial observe: post-claim appraise still targets the same plot")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]).begins_with("A gnoll carved in stone")), "memorial observe: post-claim reads the gnoll's remembrance line")

	gMem.bind_map_silent("garden_sanctuary", Vector2i(10, 2))
	gMem.player_facing = Vector2i.UP  # faces memorial_plot_wrong_order at (10,1)
	_events.clear()
	gMem.use_skill_field("observe")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "A stone plinth at the far end of the row, otherwise unremarkable, waiting on whatever the inn hasn't settled yet."), "memorial observe: a sibling plot's own counter being unbanked reads ITS waiting line, unaffected by cleared_the_warren above")

	var gReg := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345)
	gReg.player_skills.append("observe")
	gReg.player_cell = Vector2i(6, 4)
	gReg.player_facing = Vector2i.LEFT  # faces dirty_table at (5,4)
	_events.clear()
	gReg.use_skill_field("observe")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "You watch. Details surface."), "memorial observe regression guard: a visual_states prop with no observe override (dirty_table) keeps the generic [Appraise Foe] fallback")

	var e1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(e1.inventory.has("rusty_sword"), "PC starts carrying the starter sword")
	assert(String(e1.equipped.get(WIKeys.WEAPON, "")) == "rusty_sword", "PC starts with the starter sword equipped")
	assert(String(e1.equipped.get("armor", "")) == "", "PC starts with no armor equipped")
	assert(String(e1.equipped.get("accessory_1", "?")) == "", "PC starts with no accessory_1 equipped")
	assert(String(e1.equipped.get("accessory_2", "?")) == "", "PC starts with no accessory_2 equipped")
	assert(String(e1.equipped.get("accessory_3", "?")) == "", "PC starts with no accessory_3 equipped")
	assert(e1.resonance_capacity == 2, "PC starts with the default resonance_capacity of 2")
	assert(e1.item("rusty_sword").get(WIKeys.KIND, "") == "weapon", "item() resolves the starter sword's catalog record")
	assert(e1.item("nonexistent_item").is_empty(), "item() returns {} for an unknown id")

	_events.clear()
	assert(e1.pickup("leather_jerkin", "inn_chest"), "pickup adds a new item")
	assert(e1.inventory.has("leather_jerkin"), "picked-up item joins inventory")
	assert(_count("item_gained") == 1, "item_gained emitted once")
	var gained_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_gained":
			gained_payload = e["payload"]
	assert(gained_payload.get("item", "") == "leather_jerkin" and gained_payload.get("source", "") == "inn_chest", "item_gained payload carries item + source")
	_events.clear()
	assert(not e1.pickup("leather_jerkin", "inn_chest"), "repeat pickup of an already-carried item is a no-op")
	assert(_events.is_empty(), "repeat pickup emits nothing")

	_events.clear()
	assert(not e1.equip("chipped_spear"), "cannot equip an item not in inventory")
	assert(_events.is_empty(), "unpossessed equip attempt emits nothing")
	assert(not e1.equip("nonexistent_item"), "cannot equip an unknown item id")
	assert(e1.equip("leather_jerkin"), "equip succeeds once possessed")
	assert(String(e1.equipped.get("armor", "")) == "leather_jerkin", "armor slot holds the equipped item")
	assert(_count("item_equipped") == 1, "item_equipped emitted once")
	var equipped_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_equipped":
			equipped_payload = e["payload"]
	assert(equipped_payload.get("item", "") == "leather_jerkin" and equipped_payload.get("slot", "") == "armor", "item_equipped payload carries item + slot")
	for slot: String in e1.equipped:
		var eq_id := String(e1.equipped[slot])
		assert(eq_id == "" or e1.inventory.has(eq_id), "invariant: every non-empty equipped slot is also in inventory")

	_events.clear()
	assert(e1.unequip("armor"), "unequip clears a filled slot")
	assert(String(e1.equipped.get("armor", "")) == "", "armor slot is empty after unequip")
	assert(_count("item_unequipped") == 1, "item_unequipped emitted once")
	assert(not e1.unequip("armor"), "unequip on an already-empty slot is a no-op")
	assert(not e1.unequip("bogus_slot"), "unequip on an unknown slot name is a no-op")

	var eSell := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(eSell.sell_price(24) == 12, "sell_price halves worth (leather_jerkin's 24 -> 12, trade_bonus 0)")
	assert(eSell.sell_price(5) == 2, "sell_price rounds DOWN on an odd worth (traveler_charm's 5 -> floor(2.5) = 2)")
	assert(eSell.sell_price(1) == 0, "sell_price rounds a worth of 1 down to 0 (floor(0.5) = 0)")
	assert(eSell.sell_price(0) == 0, "sell_price of a zero worth is 0")

	eSell.pickup("leather_jerkin", "test")
	assert(eSell.sellable_items() == ["leather_jerkin"], "sellable_items lists the priced item carried, in inventory order")
	assert(not eSell.sellable_items().has("rusty_sword"), "sellable_items excludes the starter sword (no price field -- never established worth)")

	assert(eSell.equip("leather_jerkin"), "fixture: equip the jerkin to prove the equipped exclusion")
	assert(not eSell.sellable_items().has("leather_jerkin"), "sellable_items excludes a currently-equipped item")
	_events.clear()
	assert(not eSell.sell_item("leather_jerkin"), "sell_item refuses an equipped item (remove_item's own equipped guard, defense-in-depth)")
	assert(_events.is_empty(), "refused equipped-item sell emits nothing")
	assert(eSell.unequip("armor"), "fixture: unequip the jerkin back before the real sale")
	assert(eSell.sellable_items() == ["leather_jerkin"], "sellable_items lists it again once unequipped")

	eSell._dialogue_conversation_id = "krshia_sell"
	_events.clear()
	assert(eSell.sell_item("leather_jerkin"), "sell_item succeeds on a sellable, carried, unequipped item")
	assert(not eSell.inventory.has("leather_jerkin"), "sold item leaves the inventory")
	assert(eSell.gold == 12, "sell_item pays sell_price(24) = 12 gold")
	assert(_count("item_lost") == 1, "item_lost emitted once")
	assert(_count("gold_changed") == 1, "gold_changed emitted once")
	var sold_gold_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "gold_changed":
			sold_gold_payload = e["payload"]
	assert(sold_gold_payload.get("delta", 0) == 12 and sold_gold_payload.get("total", 0) == 12 and sold_gold_payload.get("source", "") == "krshia_sell", "gold_changed payload carries delta/total/source for the sale")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "Earned 12 gold."), "the standard earn toast fires for a sale like any other reward")

	_events.clear()
	assert(not eSell.sell_item("leather_jerkin"), "selling an item no longer carried is a no-op")
	assert(_events.is_empty(), "no-op resale emits nothing")

	assert(eSell.unequip("weapon"), "fixture: unequip the starter sword")
	_events.clear()
	assert(not eSell.sell_item("rusty_sword"), "sell_item refuses an item with no price field")
	assert(_events.is_empty(), "refused unpriced-item sell emits nothing")

	eSell.pickup("resonant_catalyst", "test")
	assert(not eSell.sellable_items().has("resonant_catalyst"), "sellable_items excludes an unsellable-flagged item despite its price")
	_events.clear()
	assert(not eSell.sell_item("resonant_catalyst"), "sell_item refuses an unsellable-flagged item")
	assert(eSell.inventory.has("resonant_catalyst"), "the refused item stays carried")
	assert(_events.is_empty(), "refused unsellable-flagged sell emits nothing")

	var eBonus := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(eBonus.sell_price(24) == 12, "fixture baseline: no trade_bonus known yet")
	eBonus.skills["test_trader_instinct"] = {"id": "test_trader_instinct", "trade_bonus": 0.1}
	eBonus.player_skills.append("test_trader_instinct")
	assert(eBonus.sell_price(24) == 13, "a known skill's trade_bonus scales the rate: floor(24 * 0.5 * 1.1) = floor(13.2) = 13")

	e1.transition("floodplains", Vector2i(27, 18))
	e1.record_accomplishment("met_relc")
	assert(e1.start_combat("goblin_encounter_2"), "combat starts for the field-only guard check")
	_events.clear()
	assert(not e1.equip("leather_jerkin"), "equip refuses mid-combat (field-only action)")
	assert(not e1.unequip("weapon"), "unequip refuses mid-combat (field-only action)")
	assert(_events.is_empty(), "mid-combat equip/unequip attempts emit nothing")
	e1.combat.apply_damage("goblin_raider", 999, "pc", true)
	e1.combat.apply_damage("goblin_shaman", 999, "pc", true)
	e1.resolve_combat()

	var cc_g1: Dictionary = combat_config.duplicate(true)
	var g1_items: Array = ((cc_g1["items"] as Dictionary)["items"] as Array).duplicate(true)
	g1_items.append_array([
		{WIKeys.ID: "test_charm_hp", WIKeys.KIND: "accessory", WIKeys.HP_MOD: 3, WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_charm_dmg", WIKeys.KIND: "accessory", WIKeys.DAMAGE_MOD: 2, WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_charm_reduc", WIKeys.KIND: "accessory", WIKeys.DAMAGE_REDUCTION: 4, WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_charm_over", WIKeys.KIND: "accessory", WIKeys.RESONANCE: 3},
		{WIKeys.ID: "test_charm_extra", WIKeys.KIND: "accessory", WIKeys.RESONANCE: 0},
		{WIKeys.ID: "test_ring_res1", WIKeys.KIND: "accessory", WIKeys.RESONANCE: 1},
		{WIKeys.ID: "test_blade_res1", WIKeys.KIND: "weapon", "weapon_family": "sword", WIKeys.RESONANCE: 1},
		{WIKeys.ID: "test_blade_res1b", WIKeys.KIND: "weapon", "weapon_family": "sword", WIKeys.RESONANCE: 1},
	])
	cc_g1["items"] = {"items": g1_items}
	var gAcc := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_g1)
	for fixture_id: String in ["test_charm_hp", "test_charm_dmg", "test_charm_reduc", "test_charm_over", "test_charm_extra", "test_ring_res1", "test_blade_res1", "test_blade_res1b"]:
		gAcc.pickup(fixture_id, "test_fixture")

	_events.clear()
	assert(gAcc.equip("test_charm_hp"), "equip an accessory into the first empty slot")
	assert(String(gAcc.equipped.get("accessory_1", "")) == "test_charm_hp", "first accessory equip lands in accessory_1")
	var acc_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_equipped":
			acc_payload = e["payload"]
	assert(acc_payload.get("item", "") == "test_charm_hp" and acc_payload.get("slot", "") == "accessory_1", "item_equipped payload carries item + the actual accessory slot")
	assert(gAcc.equip("test_charm_dmg"), "equip a second accessory")
	assert(String(gAcc.equipped.get("accessory_2", "")) == "test_charm_dmg", "second accessory equip lands in accessory_2 (first still occupied)")

	_events.clear()
	assert(not gAcc.equip("test_charm_hp"), "re-equipping an already-worn accessory is refused")
	assert(String(gAcc.equipped.get("accessory_3", "?")) == "", "the duplicate never lands in accessory_3")
	assert(_count("item_equipped") == 0 and _count("toast") == 0, "duplicate-equip refusal is silent (guard idiom), no event")

	_events.clear()
	assert(not gAcc.equip("test_charm_over"), "over-capacity equip is refused")
	assert(String(gAcc.equipped.get("accessory_3", "?")) == "", "refused equip leaves accessory_3 empty")
	assert(_count("item_equipped") == 0, "refused equip emits no item_equipped")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "It buzzes once against the others, like a wasp against glass, and will not settle.", "over-capacity equip emits the capacity refusal toast idiom")
	assert(gAcc.inventory.has("test_charm_over"), "the refused item is still carried (never equipped, never dropped)")

	assert(gAcc.equip("test_charm_reduc"), "equip the third (zero-resonance) accessory, filling all three slots")
	_events.clear()
	assert(not gAcc.equip("test_charm_extra"), "a 4th accessory is refused: no free slot")
	assert(_count("item_equipped") == 0, "refused equip emits no item_equipped")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "There's nowhere left on you for it to rest. It waits in your palm, patient as stone.", "slot-full equip emits the DISTINCT slot-full refusal toast, not the capacity one")

	for slot: String in gAcc.equipped:
		var eq_id := String(gAcc.equipped[slot])
		assert(eq_id == "" or gAcc.inventory.has(eq_id), "invariant holds across all 5 slots: every non-empty equipped slot is also in inventory")

	assert(gAcc.unequip("accessory_1") and gAcc.unequip("accessory_2") and gAcc.unequip("accessory_3"), "unequip clears all three accessory slots")
	_events.clear()
	assert(not gAcc.equip("test_charm_over"), "test_charm_over (resonance 3) alone still exceeds capacity 2 even with every slot free")
	assert(String(_events[-1]["payload"]["text"]) == "It buzzes once against the others, like a wasp against glass, and will not settle.", "same capacity refusal, now with all slots free -- proves it's a resonance gate, not a slot-count gate")

	assert(gAcc.equip("test_ring_res1"), "resonance-1 ring equips into the freed accessory slot")
	assert(gAcc.equip("test_blade_res1"), "resonance-1 weapon swap onto rusty_sword (0->1) fits: total exactly 2")
	_events.clear()
	assert(gAcc.equip("test_blade_res1b"), "swap-at-capacity succeeds: displaced resonance-1 weapon is subtracted before the incoming resonance-1 weapon is added")
	assert(String(gAcc.equipped.get(WIKeys.WEAPON, "")) == "test_blade_res1b", "the swap actually landed")
	assert(not gAcc.equip("test_charm_over"), "and a resonance-3 item at the same full state still refuses")
	assert(gAcc.unequip("accessory_1"), "swap-test cleanup: free the ring's slot")
	assert(gAcc.equip("rusty_sword"), "swap-test cleanup: swap the weapon back (resonance 1 -> 0)")

	var gAccBase := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_g1)
	gAccBase.transition("floodplains", Vector2i(27, 18))
	gAccBase.record_accomplishment("met_relc")
	assert(gAccBase.start_combat("goblin_encounter_2"), "baseline (no accessories) combat starts")
	var acc_base_max_hp := int(gAccBase.combat.combatants["pc"][WIKeys.MAX_HP])

	assert(gAcc.equip("test_charm_hp") and gAcc.equip("test_charm_dmg") and gAcc.equip("test_charm_reduc"), "re-equip all three (zero-resonance) accessories")
	gAcc.transition("floodplains", Vector2i(27, 18))
	gAcc.record_accomplishment("met_relc")
	assert(gAcc.start_combat("goblin_encounter_2"), "accessory-equipped combat starts")
	assert(int(gAcc.combat.combatants["pc"][WIKeys.MAX_HP]) == acc_base_max_hp + 3, "accessory hp_mod (3) folds into max_hp at build time, exactly like armor's hp_mod (weapon/armor both contribute 0 here)")
	assert(int(gAcc.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 2, "accessory damage_mod (2) folds into the combat build (rusty_sword contributes 0)")
	assert(int(gAcc.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 4, "accessory damage_reduction (4) folds into the combat build (no armor equipped)")

	var e2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e2.classes = {"warrior": 1}
	e2.transition("floodplains", Vector2i(27, 18))
	e2.record_accomplishment("met_relc")
	assert(e2.start_combat("goblin_encounter_2"), "sword-build combat starts")
	var sword_kit: Array = e2.combat.combatants["pc"][WIKeys.SKILLS]
	assert(sword_kit.has("power_strike"), "sword-equipped warrior fields the sword-tagged grant")
	assert(not sword_kit.has("piercing_strikes"), "sword-equipped warrior does NOT field the spear-tagged grant")
	assert(sword_kit.has("basic_swordwork") and sword_kit.has("tough_body"), "untagged passives always field regardless of weapon")
	assert(int(e2.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 0, "rusty_sword's damage_mod (0) rides the combat build")
	assert(int(e2.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 0, "no armor equipped -> damage_reduction 0")

	var e2b := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e2b.classes = {"warrior": 1}
	e2b.transition("floodplains", Vector2i(27, 18))
	e2b.record_accomplishment("met_relc")
	e2b.pickup("chipped_spear", "test")
	assert(e2b.equip("chipped_spear"), "equip the spear")
	assert(e2b.start_combat("goblin_encounter_2"), "spear-build combat starts")
	var spear_kit: Array = e2b.combat.combatants["pc"][WIKeys.SKILLS]
	assert(spear_kit.has("piercing_strikes"), "spear-equipped warrior fields the spear-tagged grant")
	assert(not spear_kit.has("power_strike"), "spear-equipped warrior does NOT field the sword-tagged grant")

	var e2c := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e2c.classes = {"warrior": 1}
	e2c.transition("floodplains", Vector2i(27, 18))
	e2c.record_accomplishment("met_relc")
	assert(e2c.unequip("weapon"), "deliberately go unarmed")
	assert(e2c.start_combat("goblin_encounter_2"), "unarmed combat starts")
	var unarmed_kit: Array = e2c.combat.combatants["pc"][WIKeys.SKILLS]
	assert(not unarmed_kit.has("power_strike") and not unarmed_kit.has("piercing_strikes"), "unarmed fields neither weapon-tagged grant")
	assert(unarmed_kit.has("basic_swordwork") and unarmed_kit.has("tough_body"), "unarmed still fields untagged skills (base attack + untagged)")
	assert(int(e2c.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 0, "unarmed carries no weapon damage_mod")

	var e3 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e3.classes = {"warrior": 1}
	for i in 3:
		e3.record_accomplishment("won_combat")
	e3.record_accomplishment("learned_magic_from_pisces")
	e3.sleep()
	assert(e3.classes.get("mage", 0) == 2, "mage build fixture: gained + leveled")
	e3.pickup("chipped_spear", "test")
	assert(e3.equip("chipped_spear"), "equip a spear on the mage/warrior split build")
	e3.transition("street", Vector2i(4, 3))
	assert(e3.start_combat("goblin_encounter_2"), "spear-equipped mage-build combat starts")
	var mage_spear_kit: Array = e3.combat.combatants["pc"][WIKeys.SKILLS]
	assert(mage_spear_kit.has("frost_bolt") and mage_spear_kit.has("quick_cast") and mage_spear_kit.has("flame_jet") and mage_spear_kit.has("mana_shield"), "mage spells field regardless of the equipped weapon (untagged)")
	assert(mage_spear_kit.has("piercing_strikes") and not mage_spear_kit.has("power_strike"), "the warrior half of the kit still gates on the equipped weapon")

	var e4 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e4.transition("street", Vector2i(4, 3))
	assert(e4.start_combat("goblin_encounter_2"), "baseline (no armor) combat starts")
	var base_max_hp := int(e4.combat.combatants["pc"][WIKeys.MAX_HP])
	var base_damage_mod := int(e4.combat.combatants["pc"][WIKeys.DAMAGE_MOD])

	var e4b := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e4b.transition("street", Vector2i(4, 3))
	e4b.pickup("leather_jerkin", "test")
	assert(e4b.equip("leather_jerkin"), "equip the jerkin")
	assert(e4b.start_combat("goblin_encounter_2"), "armored combat starts")
	assert(int(e4b.combat.combatants["pc"][WIKeys.MAX_HP]) == base_max_hp + 4, "leather_jerkin's hp_mod (+4) rides the combat build")
	assert(int(e4b.combat.combatants["pc"][WIKeys.HP]) == int(e4b.combat.combatants["pc"][WIKeys.MAX_HP]), "starting hp is the boosted max_hp")
	assert(int(e4b.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 0, "leather_jerkin carries no damage_reduction")

	var e4c := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e4c.transition("street", Vector2i(4, 3))
	e4c.pickup("watch_issue_gambeson", "test")
	assert(e4c.equip("watch_issue_gambeson"), "equip the gambeson")
	assert(e4c.start_combat("goblin_encounter_2"), "damage_reduction armor combat starts")
	assert(int(e4c.combat.combatants["pc"][WIKeys.DAMAGE_REDUCTION]) == 1, "watch_issue_gambeson's damage_reduction (1) rides the combat build")
	assert(int(e4c.combat.combatants["pc"][WIKeys.MAX_HP]) == base_max_hp, "watch_issue_gambeson carries no hp_mod")

	var e5 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	e5.pickup("relcs_spare_spear", "relc_intro")
	assert(e5.equip("relcs_spare_spear"), "equip Relc's spare spear")
	e5.transition("street", Vector2i(4, 3))
	assert(e5.start_combat("goblin_encounter_2"), "spear-with-damage-mod combat starts")
	assert(int(e5.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == 1, "relcs_spare_spear's damage_mod (+1) rides the combat build")

	var wf6 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	wf6.transition("street", Vector2i(4, 3))
	wf6.well_fed = true
	assert(wf6.start_combat("goblin_encounter_2"), "well_fed combat starts")
	assert(int(wf6.combat.combatants["pc"][WIKeys.MAX_HP]) == base_max_hp + 2, "well_fed's +2 hp_mod rides the combat build")
	assert(int(wf6.combat.combatants["pc"][WIKeys.HP]) == int(wf6.combat.combatants["pc"][WIKeys.MAX_HP]), "starting hp is the boosted max_hp")

	var wf6b := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	wf6b.transition("street", Vector2i(4, 3))
	wf6b.well_fed = true
	wf6b.pickup("leather_jerkin", "test")
	assert(wf6b.equip("leather_jerkin"), "equip the jerkin alongside well_fed")
	assert(wf6b.start_combat("goblin_encounter_2"), "well_fed + armored combat starts")
	assert(int(wf6b.combat.combatants["pc"][WIKeys.MAX_HP]) == base_max_hp + 4 + 2, "well_fed's +2 SUMS with leather_jerkin's +4 hp_mod, not overrides it")

	var cc_use: Dictionary = combat_config.duplicate(true)
	var use_items: Array = (_load_json("res://data/items.json")["items"] as Array).duplicate(true)
	use_items.append({"id": "test_draught", "name": "Test Draught", "kind": "tool", "weapon_family": "none", "damage_mod": 0, "hp_mod": 0, "damage_reduction": 0, "resonance": 0, "tier": "mundane", "abilities": [], "description": "d", "lore": "l", "use_effect": {"heal": 8}})
	use_items.append({"id": "test_meal", "name": "Test Meal", "kind": "tool", "weapon_family": "none", "damage_mod": 0, "hp_mod": 0, "damage_reduction": 0, "resonance": 0, "tier": "mundane", "abilities": [], "description": "d", "lore": "l", "use_effect": {"next_fight": {"damage_mod": 1}}})
	cc_use["items"] = {"items": use_items}

	var iu1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_use)
	iu1.transition("street", Vector2i(4, 3))
	iu1.pickup("test_meal", "test")
	_events.clear()
	assert(iu1.use_item("test_meal"), "use_item resolves a next_fight-shaped item in the field")
	assert(not iu1.inventory.has("test_meal"), "consumption = inventory.erase -- the meal is gone")
	assert(_count("item_used") == 1, "item_used emitted on a successful field use")
	assert(_count("toast") >= 1, "a visible toast card accompanies the use")
	assert(int(iu1.pending_meal.get("damage_mod", 0)) == 1, "the next_fight buff banked onto pending_meal")

	iu1.transition("street", Vector2i(4, 3))
	assert(iu1.start_combat("goblin_encounter_2"), "combat starts with a pending meal banked")
	assert(int(iu1.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == base_damage_mod + 1, "the meal's +1 damage_mod rode this fight's build")
	assert(iu1.pending_meal.is_empty(), "pending_meal is cleared the instant it's read -- one-shot")
	iu1.combat = null
	iu1.transition("street", Vector2i(4, 3))
	assert(iu1.start_combat("goblin_encounter_2"), "a second combat starts with no meal pending")
	assert(int(iu1.combat.combatants["pc"][WIKeys.DAMAGE_MOD]) == base_damage_mod, "the SECOND fight's build carries no meal bonus -- it was truly one-shot, not re-applied")

	var iu2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_use)
	iu2.transition("street", Vector2i(4, 3))
	iu2.pickup("test_draught", "test")
	assert(not iu2.use_item("test_draught"), "use_item refuses a heal-shaped item in the field")
	assert(iu2.inventory.has("test_draught"), "a refused use consumes nothing")

	var iu3 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_use)
	iu3.transition("street", Vector2i(4, 3))
	iu3.pickup("test_draught", "test")
	assert(not iu3.combat_use_item("test_draught"), "combat_use_item refuses outside combat")
	assert(iu3.start_combat("goblin_encounter_2"), "combat starts for the combat_use_item proof")
	iu3.combat.active_index = iu3.combat.turn_order.find("pc")
	iu3.combat._start_turn()
	iu3.combat.combatants["pc"][WIKeys.HP] = int(iu3.combat.combatants["pc"][WIKeys.MAX_HP]) - 10
	_events.clear()
	assert(iu3.combat_use_item("test_draught"), "combat_use_item resolves the heal-shaped item mid-fight")
	assert(not iu3.inventory.has("test_draught"), "consumption = inventory.erase -- the draught is gone")
	assert(_count("item_used") == 1, "item_used emitted on a successful combat use")
	assert(int(iu3.combat.combatants["pc"][WIKeys.HP]) == int(iu3.combat.combatants["pc"][WIKeys.MAX_HP]) - 2, "hp actually increased by the healed amount")

	assert(iu3.pickup("test_draught", "test"), "a fresh pickup after consumption succeeds -- nothing left to no-op against")

	var cc_ability: Dictionary = combat_config.duplicate(true)
	var ability_items: Array = (_load_json("res://data/items.json")["items"] as Array).duplicate(true)
	ability_items.append({"id": "test_relic", "name": "Test Relic", "kind": "accessory", "weapon_family": "none", "damage_mod": 0, "hp_mod": 0, "damage_reduction": 0, "resonance": 0, "tier": "mundane", "abilities": ["invisibility"], "description": "d", "lore": "l"})
	cc_ability["items"] = {"items": ability_items}

	var ab1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_ability)
	ab1.transition("street", Vector2i(4, 3))
	ab1.pickup("test_relic", "test")
	assert(ab1.equip("test_relic"), "equip the synthetic relic")
	assert(not ab1.known_skills().has("invisibility"), "abilities never leak into known_skills() before combat")
	assert(ab1.start_combat("goblin_encounter_2"), "combat starts with the relic equipped")
	assert((ab1.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("invisibility"), "the relic's ability folds into the PC's combat kit at start_combat")
	assert(not ab1.known_skills().has("invisibility"), "abilities still absent from known_skills() -- combat-only, not a real class/skill grant")
	assert(not ab1.player_skills.has("invisibility"), "abilities never touch player_skills -- no persistence leak")
	assert(int(ab1.combat.combatants["pc"][WIKeys.MAX_MP]) > 0, "the granted invisibility's mp_cost composes max_mp for free (WICombat._init's any-mp_cost-skill scan)")

	var ab_save_data: Dictionary = WISave.serialize(ab1)
	assert(not (ab_save_data["state"] as Dictionary).has("combat"), "combat state is never save-serialized -- an in-fight ability fold has nothing to leak into")
	assert(not ((ab_save_data["state"] as Dictionary)["player_skills"] as Array).has("invisibility"), "the saved player_skills carries no ability leak")
	var ab_restored := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_ability)
	assert(WISave.apply(ab_restored, ab_save_data), "the relic-equipped save round-trips")
	assert(ab_restored.equipped.get("accessory_1", "") == "test_relic", "the relic itself round-trips as plain equipped state (unaffected by R3)")
	assert(not ab_restored.known_skills().has("invisibility"), "a freshly-loaded game still shows no ability leak in known_skills()")

	var item_graph := {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Relc", "text": "Here, take this.", "options": [
			{"text": "Thanks.", "effects": [{"item": "relcs_spare_spear"}], "end": true},
		]}},
	}
	var cc6: Dictionary = combat_config.duplicate(true)
	cc6["dialogue"] = {"gift_conv": item_graph}
	var e6 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc6)
	assert(e6.start_dialogue("gift_conv", "relc"), "gift dialogue starts")
	assert(not e6.inventory.has("relcs_spare_spear"), "spare spear not carried before the gift is accepted")
	_events.clear()
	assert(e6.dialogue_choose(0), "accept the gift option")
	assert(e6.inventory.has("relcs_spare_spear"), "dialogue {\"item\": id} effect grants the item via pickup")
	assert(_count("item_gained") == 1, "item_gained emitted for the dialogue-granted item")
	var dlg_item_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "item_gained":
			dlg_item_payload = e["payload"]
	assert(dlg_item_payload.get("item", "") == "relcs_spare_spear" and dlg_item_payload.get("source", "") == "gift_conv", "dialogue item-gift's pickup source is the conversation id")

	var e7 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(e7.actions_since_sleep == 0, "fresh game starts with a zeroed action clock")
	assert(e7.phase() == "day", "fresh game starts in phase day")
	var rng_before_ticks := e7.rng.state
	for i in 39:
		var dir := Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT
		assert(e7.move_player(dir), "move %d succeeds (open cell)" % i)
	assert(e7.actions_since_sleep == 39, "39 successful moves tick the clock 39 times")
	assert(e7.phase() == "day", "39 actions stays under the dusk threshold (40)")
	_events.clear()
	assert(e7.move_player(Vector2i.RIGHT), "the 40th move crosses the dusk threshold")
	assert(e7.actions_since_sleep == 40, "clock reads 40 after the 40th action")
	assert(e7.phase() == "dusk", "40 actions crosses into dusk")
	assert(_count("phase_changed") == 1, "phase_changed emitted exactly once on the crossing")
	var dusk_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "phase_changed":
			dusk_payload = e["payload"]
	assert(dusk_payload.get("phase", "") == "dusk", "phase_changed payload carries the new phase")
	_events.clear()
	e7.player_facing = Vector2i.UP
	e7.interact()
	assert(e7.actions_since_sleep == 41, "interact() ticks the clock too, regardless of outcome")
	assert(_count("phase_changed") == 0, "no further crossing yet (still dusk)")
	for i in 48:
		var dir2 := Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT
		e7.move_player(dir2)
	assert(e7.actions_since_sleep == 89, "clock reads 89 just before the night threshold")
	assert(e7.phase() == "dusk", "89 actions stays in dusk")
	_events.clear()
	e7.move_player(Vector2i.RIGHT)
	assert(e7.actions_since_sleep == 90, "clock reads 90 at the night threshold")
	assert(e7.phase() == "night", "90 actions crosses into night")
	assert(_count("phase_changed") == 1, "phase_changed emitted exactly once on the night crossing")
	e7.player_cell = Vector2i(0, 3)
	e7.player_facing = Vector2i.LEFT
	var stuck_count := e7.actions_since_sleep
	assert(not e7.move_player(Vector2i.LEFT), "west wall segment blocks this move")
	assert(e7.actions_since_sleep == stuck_count, "a blocked move does not tick the clock")
	_events.clear()
	e7.sleep()
	assert(e7.actions_since_sleep == 0, "sleep() resets the action clock to 0")
	assert(e7.phase() == "day", "reset clock reads phase day")
	assert(_count("phase_changed") == 1, "sleep() emits phase_changed exactly once")
	var sleep_phase_payload: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "phase_changed":
			sleep_phase_payload = e["payload"]
	assert(sleep_phase_payload.get("phase", "") == "day", "sleep()'s phase_changed payload reads day")
	_events.clear()
	e7.sleep()
	assert(_count("phase_changed") == 1, "sleep() emits phase_changed even on a same-phase (day->day) reset")
	assert(e7.rng.state == rng_before_ticks, "actions_since_sleep/phase bookkeeping consumes no rng")

	var e8 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(e8.actions_since_sleep == 0, "fresh game, zeroed clock")
	e8.transition("street", Vector2i(4, 3))
	assert(e8.start_combat("goblin_encounter_2"), "combat starts")
	var clock_before_pc_turn := e8.actions_since_sleep
	e8.combat.active_index = e8.combat.turn_order.find("pc")
	e8.combat._start_turn()
	assert(e8.actions_since_sleep == clock_before_pc_turn + 1, "forcing the PC's own turn_started ticks the clock exactly once, via _combat_event_relay")

	var L1a := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L1a.record_accomplishment("met_relc")
	L1a.transition("floodplains", Vector2i(20, 12))
	assert(L1a.start_combat("goblin_encounter_1"), "loot determinism: instance A starts encounter_1")
	L1a.combat.apply_damage("goblin_raider", 999, "pc", true)
	L1a.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L1a.resolve_combat()
	var l1a_dropped := L1a.inventory.has("crude_blade")

	var L1b := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L1b.record_accomplishment("met_relc")
	L1b.transition("floodplains", Vector2i(20, 12))
	assert(L1b.start_combat("goblin_encounter_1"), "loot determinism: instance B starts encounter_1")
	L1b.combat.apply_damage("goblin_raider", 999, "pc", true)
	L1b.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L1b.resolve_combat()
	var l1b_dropped := L1b.inventory.has("crude_blade")
	assert(l1a_dropped == l1b_dropped, "same run seed + same encounter id -> identical loot roll outcome across independent instances")

	var L2both := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L2both.record_accomplishment("met_relc")
	L2both.transition("floodplains", Vector2i(20, 12))
	assert(L2both.start_combat("goblin_encounter_1"), "loot independence: both-fights instance starts encounter_1")
	L2both.combat.apply_damage("goblin_raider", 999, "pc", true)
	L2both.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L2both.resolve_combat()
	L2both.transition("floodplains", Vector2i(27, 18))
	assert(L2both.start_combat("goblin_encounter_2"), "loot independence: both-fights instance starts encounter_2 after encounter_1")
	L2both.combat.apply_damage("goblin_raider", 999, "pc", true)
	L2both.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L2both.resolve_combat()
	var both_e2_dropped := L2both.inventory.has("chipped_spear")

	var L2solo := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L2solo.record_accomplishment("met_relc")
	L2solo.transition("floodplains", Vector2i(27, 18))
	assert(L2solo.start_combat("goblin_encounter_2"), "loot independence: solo instance starts encounter_2 directly")
	L2solo.combat.apply_damage("goblin_raider", 999, "pc", true)
	L2solo.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L2solo.resolve_combat()
	var solo_e2_dropped := L2solo.inventory.has("chipped_spear")
	assert(both_e2_dropped == solo_e2_dropped, "encounter_2's loot roll is independent of whether encounter_1 already rolled -- different encounter ids draw from separate streams")

	var L3 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 777, combat_config)
	L3.record_accomplishment("met_relc")
	L3.transition("floodplains", Vector2i(20, 12))
	assert(L3.start_combat("goblin_encounter_1"), "loot rng isolation: instance starts combat")
	var rng_state_after_start := L3.rng.state
	L3.combat.apply_damage("goblin_raider", 999, "pc", true)
	L3.combat.apply_damage("goblin_shaman", 999, "pc", true)
	L3.resolve_combat()
	assert(L3.rng.state == rng_state_after_start, "a loot roll consumes ZERO draws from the live sim rng stream")

	var gC := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(not gC.inventory.has("leather_jerkin"), "inn_chest's contents not carried before opening")
	gC.transition("inn_upstairs", Vector2i(9, 2))
	for i in 2:
		assert(gC.move_player(Vector2i.DOWN), "the your-room column is clear down to the chest")
	assert(gC.player_cell == Vector2i(9, 4), "player stands one cell north of inn_chest, facing down")
	_events.clear()
	var chest_result := gC.interact()
	assert(chest_result.get("container", "") == "inn_chest", "container interact returns its own id")
	assert((chest_result.get("items", []) as Array).has("leather_jerkin"), "container interact returns the granted item ids")
	assert(gC.inventory.has("leather_jerkin"), "opening the chest grants its contents")
	assert(_count("item_gained") == 1, "one item_gained for the chest's single item")
	assert(bool(gC.container_state.get("inn_chest", false)), "container_state marks the chest emptied")
	var chest_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast":
			chest_toast = String(e["payload"].get("text", ""))
	assert(chest_toast == "Got: Leather Jerkin", "pickup's toast reads 'Got: <name>'")

	_events.clear()
	var chest_again := gC.interact()
	assert(bool(chest_again.get("empty", false)), "re-interacting an emptied container returns the empty marker")
	assert(_count("item_gained") == 0, "re-interact grants nothing")
	assert(_count("toast") == 1, "re-interact emits exactly one toast")
	var empty_toast := ""
	for e: Dictionary in _events:
		if e["type"] == "toast":
			empty_toast = String(e["payload"].get("text", ""))
	assert(empty_toast == "Empty.", "re-interact toasts exactly 'Empty.'")

	var gC2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gC2.container_state["inn_chest"] = true
	gC2.transition("inn_upstairs", Vector2i(9, 2))
	for i in 2:
		gC2.move_player(Vector2i.DOWN)
	_events.clear()
	var restored_result := gC2.interact()
	assert(bool(restored_result.get("empty", false)), "a pre-marked-emptied container_state (the post-load shape) is respected on its first LIVE interact")
	assert(not gC2.inventory.has("leather_jerkin"), "a pre-marked-emptied container grants nothing")
	assert(_count("item_gained") == 0, "a pre-marked-emptied container emits no item_gained on interact")


	var gT1 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gT1.transition("floodplains", Vector2i(30, 20))
	assert(gT1.combat == null, "fixture: starts outside the trigger zone (dist 3)")
	_events.clear()
	assert(gT1.move_player(Vector2i.DOWN), "step succeeds (open cell)")
	assert(gT1.player_cell == Vector2i(30, 21), "player lands at dist 2 from the encounter")
	assert(gT1.combat != null, "entering the zone starts combat with no interact call")
	assert(_count("combat_started") == 1, "one combat_started fired from the move alone")
	assert(gT1.combat.combatants.has("goblin_raider"), "the real goblin_encounter_1 roster fielded")

	var gT2 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gT2.transition("floodplains", Vector2i(30, 19))
	assert(gT2.move_player(Vector2i.DOWN), "step succeeds (open cell)")
	assert(gT2.player_cell == Vector2i(30, 20), "player lands at dist 3 -- adjacent-outside the zone")
	assert(gT2.combat == null, "adjacent-outside the radius does not trigger")

	var gT3 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gT3.dormant_encounters.append("goblin_encounter_1")
	gT3.transition("floodplains", Vector2i(30, 20))
	gT3.move_player(Vector2i.DOWN)  # (30,21), dist 2
	_events.clear()
	assert(gT3.move_player(Vector2i.DOWN), "step succeeds (open cell)")
	assert(gT3.player_cell == Vector2i(30, 22), "player lands at dist 1, deep inside the zone")
	assert(gT3.combat == null, "a dormant encounter's zone does not trigger a fight")
	assert(_count("combat_started") == 0, "no combat_started while dormant")

	gT3.sleep()
	assert(gT3.dormant_encounters.is_empty(), "sleep re-arms the respawner")
	_events.clear()
	assert(gT3.move_player(Vector2i.RIGHT), "step succeeds (open cell)")
	assert(gT3.player_cell == Vector2i(31, 22), "player lands at dist 1, still inside the zone")
	assert(gT3.combat != null, "re-armed encounter fights again on re-entry")
	assert(_count("combat_started") == 1, "one fresh combat_started on the re-trigger")

	var gT4 := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	_events.clear()
	gT4.transition("floodplains", Vector2i(30, 22))  # dist 1, well inside the zone
	assert(gT4.combat == null, "transition (teleport/door/load-restore) never triggers the ambush")
	assert(_count("combat_started") == 0, "no combat_started from a bare transition")


	var tag_skills_raw: Dictionary = _load_json("res://data/skills.json")
	var tagged_skill_list: Array = (tag_skills_raw[WIKeys.SKILLS] as Array).duplicate(true)
	tagged_skill_list.append({WIKeys.ID: "stealth_ritual", WIKeys.DISPLAY_NAME: "[Stealth Ritual]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "sneaks": true})
	var gTagK2 := WIGame.new(WISceneCatalog.compose(), {WIKeys.SKILLS: tagged_skill_list}, _sink, 12345, combat_config)
	gTagK2.player_skills.append("stealth_ritual")
	assert(not gTagK2.sneaking, "fixture: not sneaking at start")
	_events.clear()
	gTagK2.use_skill_field("stealth_ritual")
	assert(gTagK2.sneaking, "a DIFFERENT skill id carrying sneaks:true still toggles sneaking on (tag-keyed, not id-keyed)")
	assert(_count("sneak_started") == 1, "sneak_started fires on a tag toggle")
	assert(_toast_texts() == ["You soften your step."], "the on-toast fires exactly once, tag-toggle case")
	_events.clear()
	gTagK2.use_skill_field("stealth_ritual")
	assert(not gTagK2.sneaking, "the SAME tagged skill toggles back off")
	assert(_count("sneak_ended") == 1, "sneak_ended fires on the off-toggle")
	assert(_toast_texts() == ["You straighten up."], "the off-toast fires exactly once")

	var gTwoVerbs := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gTwoVerbs.player_skills.append("sneak")
	gTwoVerbs.player_skills.append("invisibility")
	assert(not gTwoVerbs.sneaking, "fixture: not sneaking at start")
	_events.clear()
	gTwoVerbs.use_skill_field("invisibility")
	assert(gTwoVerbs.sneaking, "[Invisibility] toggles the shared flag on")
	assert(_count("sneak_started") == 1, "sneak_started fires once")
	_events.clear()
	gTwoVerbs.use_skill_field("sneak")
	assert(not gTwoVerbs.sneaking, "a DIFFERENT sneaks-tagged skill ([Stealth]) toggles the SAME flag back off -- one stance, two keys")
	assert(_count("sneak_ended") == 1, "sneak_ended fires once, from the [Stealth] press")
	assert(_count("sneak_started") == 0, "no fresh sneak_started from the cross-skill press")

	var wave_b_skills: Array = (_load_json("res://data/skills.json")[WIKeys.SKILLS] as Array).duplicate(true)
	wave_b_skills.append({WIKeys.ID: "test_blink", WIKeys.DISPLAY_NAME: "[Test Blink]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "blinks": true, "blink_range": 3})
	wave_b_skills.append({WIKeys.ID: "test_short_blink", WIKeys.DISPLAY_NAME: "[Test Short Blink]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "blinks": true, "blink_range": 2})
	wave_b_skills.append({WIKeys.ID: "test_ward", WIKeys.DISPLAY_NAME: "[Test Ward]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "wards": true})
	wave_b_skills.append({WIKeys.ID: "test_greater_ward", WIKeys.DISPLAY_NAME: "[Test Greater Ward]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "wards": true, "ward_sleeps": 2})
	wave_b_skills.append({WIKeys.ID: "test_animate", WIKeys.DISPLAY_NAME: "[Test Animate]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "animates": true})
	var wave_b_skill_config := {WIKeys.SKILLS: wave_b_skills}

	var gBlinkWater := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gBlinkWater.player_skills.append("test_blink")
	gBlinkWater.transition("sewers", Vector2i(3, 4))
	gBlinkWater.player_facing = Vector2i.DOWN
	_events.clear()
	var water_blink := gBlinkWater.use_skill_field("test_blink")
	assert(gBlinkWater.player_cell == Vector2i(3, 7), "blink scans through freezable water and lands on the farthest non-freezable open cell")
	assert(water_blink.get("teleported", []) == [3, 7], "blink result reports the landing cell")
	assert(_count("player_teleported") == 1, "blink emits one player_teleported event")
	assert(_count("skill_used") == 1, "successful blink emits one exploration skill_used")

	var shoreline_scene := WISceneCatalog.compose()
	(shoreline_scene["maps"]["sewers"]["entities"] as Array).append({
		WIKeys.ID: "shoreline_danger",
		WIKeys.KIND: "encounter",
		WIKeys.CELL: [3, 10],
		WIKeys.DISPLAY_NAME: "Shoreline Danger",
		"arena": "goblin_ambush",
		"enemies": ["goblin_raider"],
		"allies": [],
		"trigger_radius": 1,
	})
	var gBlinkShoreline := WIGame.new(shoreline_scene, wave_b_skill_config, _sink, 12345, combat_config)
	gBlinkShoreline.player_skills.append("test_short_blink")
	gBlinkShoreline.transition("sewers", Vector2i(3, 7))
	gBlinkShoreline.player_facing = Vector2i.DOWN
	_events.clear()
	gBlinkShoreline.use_skill_field("test_short_blink")
	assert(gBlinkShoreline.player_cell == Vector2i(3, 8), "shoreline blink lands before the unreached freezable cell")
	assert(gBlinkShoreline.accomplishment_count("blinked_past_danger") == 0, "danger touching only unreached water earns no blink bypass credit")
	assert(not gBlinkShoreline.entity_first_use.has("danger:shoreline_danger"), "unreached water does not consume the shared danger dedup")
	gBlinkShoreline.transition("sewers", Vector2i(1, 10))
	_events.clear()
	assert(gBlinkShoreline.move_player(Vector2i.RIGHT), "later real move reaches the still-armed shoreline radius")
	assert(gBlinkShoreline.combat != null and _count("combat_started") == 1, "unreached shoreline danger was not suppressed by the blink")

	var gBlinkWall := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gBlinkWall.player_skills.append("test_short_blink")
	gBlinkWall.transition("floodplains", Vector2i(19, 25))
	gBlinkWall.player_facing = Vector2i.RIGHT
	_events.clear()
	assert(gBlinkWall.use_skill_field("test_short_blink").is_empty(), "blink refuses when a non-freezable wall blocks range 1")
	assert(gBlinkWall.player_cell == Vector2i(19, 25), "refused blink does not move the player")
	assert(_toast_texts() == ["No clear landing lies ahead."], "blocked blink uses the exact refusal toast")

	var gBlinkPast := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gBlinkPast.player_skills.append("test_short_blink")
	gBlinkPast.transition("floodplains", Vector2i(30, 21))
	gBlinkPast.player_facing = Vector2i.UP
	_events.clear()
	gBlinkPast.use_skill_field("test_short_blink")
	assert(gBlinkPast.player_cell == Vector2i(30, 19), "short blink crosses from inside the road ambush radius to outside")
	assert(gBlinkPast.combat == null and _count("combat_started") == 0, "crossing outward banks bypass credit and does not fire the encounter")
	assert(gBlinkPast.accomplishment_count("blinked_past_danger") == 1, "blink crossing banks blinked_past_danger once")
	assert(gBlinkPast.entity_first_use.has("danger:goblin_encounter_1"), "blink crossing shares sneak's danger:<id> dedup seam")

	var gBlinkInto := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gBlinkInto.player_skills.append("test_short_blink")
	gBlinkInto.transition("floodplains", Vector2i(30, 19))
	gBlinkInto.player_facing = Vector2i.DOWN
	_events.clear()
	gBlinkInto.use_skill_field("test_short_blink")
	assert(gBlinkInto.player_cell == Vector2i(30, 21), "blink landing reaches the armed road ambush radius")
	assert(gBlinkInto.combat != null and _count("combat_started") == 1, "landing inside a radius fires normally")

	var gWard := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gWard.player_skills.append("test_ward")
	gWard.transition("floodplains", Vector2i(30, 20))
	gWard.player_facing = Vector2i.DOWN
	_events.clear()
	var ward_result := gWard.use_skill_field("test_ward")
	assert(String(ward_result.get("warded", "")) == "goblin_encounter_1", "ward selects the armed radius containing the faced cell")
	assert(gWard.warded_encounters.has("goblin_encounter_1"), "warded encounter state is retained on the sim")
	assert(gWard.accomplishment_count("warded_danger") == 1 and gWard.accomplishment_count("witch_craft_used") == 1, "ward banks both counters")
	assert(_count("ward_placed") == 1, "ward emits a placed-charm event")
	_events.clear()
	assert(gWard.use_skill_field("test_ward").is_empty(), "ward refuses an encounter already holding its charm")
	assert(_toast_texts() == ["The charm already holds here."], "re-ward refusal has its own honest line")
	_events.clear()
	assert(gWard.move_player(Vector2i.DOWN), "warded player can step into the radius")
	assert(gWard.combat == null and _count("combat_started") == 0, "warded trigger_radius encounter is suppressed")
	gWard.sleep()
	assert(not gWard.warded_encounters.has("goblin_encounter_1"), "one-sleep ward clears on sleep")

	var gWardRefusal := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gWardRefusal.player_skills.append("test_ward")
	gWardRefusal.transition("inn", Vector2i(2, 3))
	gWardRefusal.player_facing = Vector2i.RIGHT
	_events.clear()
	assert(gWardRefusal.use_skill_field("test_ward").is_empty(), "ward refuses when no armed radius contains the faced cell")
	assert(_toast_texts() == ["No hidden danger answers the charm."], "ward refusal uses the exact toast")

	var gGreaterWard := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gGreaterWard.player_skills.append("test_greater_ward")
	gGreaterWard.transition("floodplains", Vector2i(30, 20))
	gGreaterWard.player_facing = Vector2i.DOWN
	gGreaterWard.use_skill_field("test_greater_ward")
	gGreaterWard.sleep()
	assert(int((gGreaterWard.warded_encounters["goblin_encounter_1"] as Dictionary).get("sleeps", 0)) == 1, "greater ward decrements to one remaining sleep")
	gGreaterWard.sleep()
	assert(not gGreaterWard.warded_encounters.has("goblin_encounter_1"), "greater ward clears after its second sleep")

	var gAnimateCrowded := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gAnimateCrowded.player_skills.append("test_animate")
	gAnimateCrowded.accomplishments["horns_party_formed"] = 1
	gAnimateCrowded.transition("trapped_halls", Vector2i(17, 11))
	gAnimateCrowded.player_facing = Vector2i.RIGHT
	assert(String(gAnimateCrowded.use_skill_field("test_animate").get("animated", "")) == "bone_pile_halls", "vault regression animates the nearby halls bone pile")
	_events.clear()
	assert(gAnimateCrowded.start_combat("vault_boss_slot"), "full Horns vault combat starts while a companion is held")
	assert(gAnimateCrowded.combat != null and _count("combat_started") == 1, "vault combat remains live with no constructor error cascade")
	var crowded_player_ids: Array[String] = []
	for combatant_id: String in gAnimateCrowded.combat.combatants:
		if String(gAnimateCrowded.combat.combatants[combatant_id][WIKeys.SIDE]) == "player":
			crowded_player_ids.append(combatant_id)
	crowded_player_ids.sort()
	assert(crowded_player_ids == ["ceria", "ksmvr", "pc", "yvlon"], "vault fields exactly the PC and three Horns in its four player spawns")
	assert(gAnimateCrowded.companion == "skeleton_ally", "capacity skip preserves the held companion for a later fight")
	assert(_toast_texts().has("A crowded field. Your companion hangs back at its edge."), "capacity skip explains why the bones stay off-field")

	var gAnimate := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gAnimate.player_skills.append("test_animate")
	gAnimate.transition("ruin_surface", Vector2i(14, 10))
	gAnimate.player_facing = Vector2i.RIGHT
	_events.clear()
	var animate_result := gAnimate.use_skill_field("test_animate")
	assert(String(animate_result.get("animated", "")) == "bone_pile_ruin", "animate targets the faced Wave-A bone pile")
	assert(gAnimate.companion == "skeleton_ally", "animate sets the persisted skeleton companion id")
	assert(gAnimate.removed_entities.has("bone_pile_ruin"), "animate consumes the bone-pile prop through remove_entity")
	assert(_count("terrain_changed") == 0 and _count("entity_removed") == 1 and _count("companion_changed") == 1,
		"animate uses entity removal for the vanished pile and emits no unrendered terrain change")
	gAnimate.transition("floodplains", Vector2i(27, 18))
	assert(gAnimate.start_combat("goblin_encounter_2"), "animated companion carries into the next fight")
	assert(gAnimate.combat.combatants.has("skeleton_ally"), "start_combat appends skeleton_ally to the ally roster")
	gAnimate.combat.combatants["skeleton_ally"][WIKeys.HP] = 0
	gAnimate.combat._post_damage("skeleton_ally", "goblin_raider")
	assert(gAnimate.companion == "", "companion downed in combat clears the field state immediately")

	var gAnimateSleep := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gAnimateSleep.companion = "skeleton_ally"
	gAnimateSleep.sleep()
	assert(gAnimateSleep.companion == "", "sleep clears an active companion")

	# --- GH#156: companion_source generalization + [Lesser Bond] taming ---
	var gTameMismatch := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gTameMismatch.player_skills.append("test_animate")
	gTameMismatch.transition("floodplains", Vector2i(10, 22))
	gTameMismatch.player_facing = Vector2i.RIGHT
	_events.clear()
	assert(gTameMismatch.use_skill_field("test_animate").is_empty(), "an animates skill refuses a tamed-kind source (kind gate)")
	assert(_toast_texts() == ["No bones here will answer."], "kind mismatch uses the animate refusal toast")

	var gTame := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gTame.player_skills.append("lesser_bond")
	gTame.transition("floodplains", Vector2i(10, 22))
	gTame.player_facing = Vector2i.RIGHT
	_events.clear()
	var tame_result := gTame.use_skill_field("lesser_bond")
	assert(String(tame_result.get("companion", "")) == "wolf_companion", "lesser_bond bonds the wolf-den pup")
	assert(String(tame_result.get("source", "")) == "tamed", "tame reports its source kind")
	assert(gTame.companion == "wolf_companion" and gTame.companion_source == "tamed", "tamed companion state is source-keyed")
	assert(gTame.removed_entities.has("wolf_den"), "taming consumes the den prop through remove_entity")
	assert(gTame.accomplishment_count("tended_beasts") == 1, "a tame banks one tended_beasts")
	gTame.sleep()
	assert(gTame.companion == "wolf_companion", "tamed companions PERSIST sleep (the bond holds; only animated workings fade)")
	gTame.player_facing = Vector2i.RIGHT
	gTame.transition("floodplains", Vector2i(7, 23))
	_events.clear()
	var rebond_result := gTame.use_skill_field("lesser_bond")
	assert(String(rebond_result.get("companion", "")) == "razorbeak_companion", "a new bond takes the razorbeak chick")
	assert(_toast_texts().has("Your old companion slips away; one bond at a time is all anyone holds."), "single-slot: the old bond is released with its toast")
	assert(gTame.companion == "razorbeak_companion", "companion slot swaps to the new bond")

	var gTameJoke := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gTameJoke.player_skills.append("lesser_bond")
	gTameJoke.transition("floodplains", Vector2i(20, 16))
	gTameJoke.player_facing = Vector2i.RIGHT
	_events.clear()
	assert(gTameJoke.use_skill_field("lesser_bond").is_empty(), "rock crabs refuse taming")
	assert(_toast_texts() == ["The crab regards you with all the tameable warmth of a boulder."], "the crab refusal joke plays verbatim")

	var gBoons := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gBoons.player_skills.append("animals_basic_command")
	gBoons.player_skills.append("pack_bond")
	gBoons.companion = "wolf_companion"
	gBoons.companion_source = "tamed"
	gBoons.transition("floodplains", Vector2i(27, 18))
	assert(gBoons.start_combat("goblin_encounter_2"), "tamed wolf fields into the goblin fight")
	var wolf_combatant: Dictionary = gBoons.combat.combatants.get("wolf_companion", {})
	assert(not wolf_combatant.is_empty(), "start_combat appends the wolf companion to the roster")
	assert((wolf_combatant[WIKeys.SKILLS] as Array).has("basic_command_boon") and (wolf_combatant[WIKeys.SKILLS] as Array).has("pack_bond_boon"),
		"companion boons ride the COMPANION combatant, not the PC")
	assert(int(wolf_combatant["hit_bonus"]) == 8, "basic_command_boon folds +8 hit on the wolf")
	assert(int(wolf_combatant[WIKeys.MAX_HP]) == 34, "pack_bond_boon folds +4 max hp on the wolf (20 + 10 con + 4)")
	assert(not (gBoons.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("basic_command_boon"), "the PC kit never carries the boon ids")

	# --- GH#165: PC-side [Sworn Fang: Ride Together] boon (companion fielded -> boon on the PC) ---
	var gSworn := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gSworn.player_skills.append("sworn_fang_ride_together")
	gSworn.companion = "wolf_companion"
	gSworn.companion_source = "tamed"
	gSworn.transition("floodplains", Vector2i(27, 18))
	assert(gSworn.start_combat("goblin_encounter_2"), "sworn-fang fight fields the wolf")
	var sworn_pc: Dictionary = gSworn.combat.combatants["pc"]
	assert((sworn_pc[WIKeys.SKILLS] as Array).has("sworn_fang_boon"), "the PC kit carries sworn_fang_boon while a companion rides")
	assert(int(sworn_pc["hit_bonus"]) >= 8, "sworn_fang_boon folds at least +8 hit onto the PC")
	assert(not (gSworn.combat.combatants["wolf_companion"][WIKeys.SKILLS] as Array).has("sworn_fang_boon"), "the PC-side boon rides the PC, never the companion")
	# absent without a companion
	var gSwornSolo := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gSwornSolo.player_skills.append("sworn_fang_ride_together")
	gSwornSolo.transition("floodplains", Vector2i(27, 18))
	assert(gSwornSolo.start_combat("goblin_encounter_2"), "solo sworn-fang fight starts")
	assert(not (gSwornSolo.combat.combatants["pc"][WIKeys.SKILLS] as Array).has("sworn_fang_boon"), "no companion -> no PC-side boon")
	# the hidden carrier is never a class data grant (only the passive grant is)
	var _sworn_granted := false
	var _passive_granted := false
	for _cls: Dictionary in (combat_config["classes"]["classes"] as Array):
		for _lv: Dictionary in (_cls["levels"] as Array):
			if (_lv["grants"] as Array).has("sworn_fang_boon"): _sworn_granted = true
			if (_lv["grants"] as Array).has("sworn_fang_ride_together"): _passive_granted = true
	assert(not _sworn_granted, "sworn_fang_boon (hidden carrier) is NEVER a class data grant")
	assert(_passive_granted, "sworn_fang_ride_together IS granted in data (beast_master L14)")

	# --- GH#92 D3: room-tier max-HP bonus (persistent via accomplishment counters) ---
	var gRoomBase := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gRoomBase.transition("floodplains", Vector2i(27, 18))
	assert(gRoomBase.start_combat("goblin_encounter_2"), "control fight starts")
	var base_hp := int(gRoomBase.combat.combatants["pc"][WIKeys.MAX_HP])
	var gRoomTiers := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gRoomTiers.accomplishments["room_tier_1"] = 1
	gRoomTiers.accomplishments["room_tier_2"] = 1
	gRoomTiers.transition("floodplains", Vector2i(27, 18))
	assert(gRoomTiers.start_combat("goblin_encounter_2"), "tiered fight starts")
	assert(int(gRoomTiers.combat.combatants["pc"][WIKeys.MAX_HP]) == base_hp + 2,
		"two held room tiers add +2 max HP at the combat build (GH#92 D3)")

	var gBoonsPartial := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gBoonsPartial.player_skills.append("animals_basic_command")
	gBoonsPartial.companion = "wolf_companion"
	gBoonsPartial.companion_source = "tamed"
	gBoonsPartial.transition("floodplains", Vector2i(27, 18))
	assert(gBoonsPartial.start_combat("goblin_encounter_2"), "partial-kit wolf fields into the goblin fight")
	var partial_wolf: Dictionary = gBoonsPartial.combat.combatants.get("wolf_companion", {})
	assert((partial_wolf[WIKeys.SKILLS] as Array).has("basic_command_boon"), "L2+ kit injects the command boon")
	assert(not (partial_wolf[WIKeys.SKILLS] as Array).has("pack_bond_boon"), "pre-[Pack Bond] kit injects NO hp boon (review N1)")

	# --- GH#156 review M2: wounded-corusdeer soothe/mend paths + variant flip ---
	var gMend := WIGame.new(WISceneCatalog.compose(), wave_b_skill_config, _sink, 12345, combat_config)
	gMend.player_skills.append("beasts_mending")
	gMend.transition("floodplains", Vector2i(32, 9))
	gMend.player_facing = Vector2i.RIGHT
	_events.clear()
	gMend.interact()
	assert(gMend.accomplishment_count("soothed_a_beast") == 1, "first corusdeer interact banks soothed_a_beast")
	assert(gMend.accomplishment_count("tended_beasts") == 0, "the variant gate resolves BEFORE the bank -- first visit is the soothe, not a tend")
	gMend.interact()
	assert(gMend.accomplishment_count("soothed_a_beast") == 1 and gMend.accomplishment_count("tended_beasts") == 0,
		"second same-waking interact is once_per_waking-spent")
	assert(gMend.use_skill_field("beasts_mending").get("once_per_waking_spent", false) == true,
		"the mend cast shares interact's serve: key -- one careful visit per waking TOTAL (review M1)")
	assert(gMend.accomplishment_count("tended_beasts") == 0, "spent-waking mend banks nothing")
	gMend.sleep()
	_events.clear()
	gMend.interact()
	assert(gMend.accomplishment_count("tended_beasts") == 1 and gMend.accomplishment_count("soothed_a_beast") == 1,
		"post-sleep interact flips to the tended_beasts variant")
	gMend.sleep()
	var mend_gold := gMend.gold
	var mend_result := gMend.use_skill_field("beasts_mending")
	assert(String(mend_result.get("accomplishment", "")) == "tended_beasts", "fresh-waking mend cast resolves the on_skill_use payload")
	assert(gMend.accomplishment_count("tended_beasts") == 2, "the mend cast banks tended_beasts")
	assert(gMend.gold == mend_gold + 2, "the mend cast pays its small care wage")
	assert(gMend.use_skill_field("beasts_mending").get("once_per_waking_spent", false) == true,
		"a second same-waking mend is spent -- the curve cannot be ground at one prop between sleeps")

	var affinity_scene := WISceneCatalog.compose()
	(affinity_scene["maps"]["floodplains"]["entities"] as Array).append({
		WIKeys.ID: "test_beast_ambush",
		WIKeys.KIND: "encounter",
		WIKeys.CELL: [33, 23],
		WIKeys.DISPLAY_NAME: "Test Beast",
		"beast": true,
		"arena": "goblin_ambush",
		"enemies": ["goblin_raider"],
		"trigger_radius": 2,
	})
	var gAffinityOff := WIGame.new(affinity_scene, wave_b_skill_config, _sink, 12345, combat_config)
	gAffinityOff.transition("floodplains", Vector2i(33, 20))
	assert(gAffinityOff.move_player(Vector2i.DOWN), "control walks to dist 2")
	assert(gAffinityOff.combat != null, "without [Wild Affinity] the beast ambush triggers at its authored radius")
	var gAffinityOn := WIGame.new(affinity_scene, wave_b_skill_config, _sink, 12345, combat_config)
	gAffinityOn.player_skills.append("wild_affinity")
	gAffinityOn.transition("floodplains", Vector2i(33, 20))
	assert(gAffinityOn.move_player(Vector2i.DOWN), "affinity walks to dist 2")
	assert(gAffinityOn.combat == null, "[Wild Affinity] shrinks the beast ambush radius by 1")
	assert(gAffinityOn.move_player(Vector2i.DOWN), "affinity walks to dist 1")
	assert(gAffinityOn.combat != null, "[Wild Affinity] still triggers inside the reduced radius")
	var gPeace := WIGame.new(affinity_scene, wave_b_skill_config, _sink, 12345, combat_config)
	gPeace.player_skills.append("wild_affinity")
	gPeace.player_skills.append("peace_of_the_wild")
	gPeace.transition("floodplains", Vector2i(33, 20))
	assert(gPeace.move_player(Vector2i.DOWN), "peace walks to dist 2")
	assert(gPeace.move_player(Vector2i.DOWN), "peace walks to dist 1")
	assert(gPeace.combat == null, "[Peace of the Wild] supersedes at -2: no ambush even at dist 1")

	var gSneak := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gSneak.player_skills.append("sneak")
	_events.clear()
	var sneak_on := gSneak.use_skill_field("sneak")
	assert(sneak_on.get("sneaking", false) == true, "use_skill_field returns the new sneaking state")
	assert(gSneak.sneaking, "sneaking flips true")
	assert(gSneak.snapshot()["sneaking"] == true, "snapshot carries sneaking")
	assert(gSneak.used_skills.has("sneak"), "sneak is marked used (journal reveal)")
	assert(_count("skill_used") == 1, "the toggle emits exactly one skill_used")

	gSneak.transition("floodplains", Vector2i(30, 20))
	_events.clear()
	assert(gSneak.move_player(Vector2i.DOWN), "step to dist 2 succeeds")
	assert(gSneak.combat == null, "sneaking skips the trigger entirely at dist 2")
	assert(gSneak.move_player(Vector2i.DOWN), "step to dist 1 succeeds")
	assert(gSneak.combat == null, "sneaking skips the trigger entirely at dist 1 too")
	assert(_count("combat_started") == 0, "no combat_started anywhere in the sneaking approach")
	gSneak.use_skill_field("sneak")
	assert(not gSneak.sneaking, "the re-press straightens up")
	_events.clear()
	assert(gSneak.move_player(Vector2i.RIGHT), "step succeeds (open cell), still dist 1")
	assert(gSneak.combat != null, "NOT sneaking: the same zone now fires the ambush for real")
	assert(_count("combat_started") == 1, "one combat_started on the not-sneaking step")

	var gBreakProp := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakProp.player_skills.append("sneak")
	gBreakProp.use_skill_field("sneak")
	assert(gBreakProp.sneaking, "fixture: sneaking before the interact")
	gBreakProp.player_cell = Vector2i(6, 4)
	gBreakProp.player_facing = Vector2i.LEFT  # faces dirty_table at (5,4)
	_events.clear()
	gBreakProp.interact()
	assert(not gBreakProp.sneaking, "interact() reaching a prop response breaks sneaking")
	assert(_toast_texts()[0] == "You straighten up.", "the off-toast is emitted BEFORE the prop's own toast")
	assert(_count("sneak_ended") == 1, "sneak_ended fires from the interact break")

	var gBreakDoor := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakDoor.player_skills.append("sneak")
	gBreakDoor.use_skill_field("sneak")
	gBreakDoor.player_cell = Vector2i(14, 3)
	gBreakDoor.player_facing = Vector2i.RIGHT  # faces inn_door at (15,3)
	_events.clear()
	gBreakDoor.interact()
	assert(gBreakDoor.sneaking, "a door transition KEEPS sneaking")
	assert(_count("sneak_ended") == 0, "no sneak_ended from a door crossing")
	assert(gBreakDoor.current_map == "floodplains", "fixture: the door actually transitioned")

	var gBreakNothing := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakNothing.player_skills.append("sneak")
	gBreakNothing.use_skill_field("sneak")
	gBreakNothing.player_cell = Vector2i(2, 3)
	gBreakNothing.player_facing = Vector2i.DOWN  # open floor, nothing faced
	gBreakNothing.interact()
	assert(gBreakNothing.sneaking, "interact() reaching nothing does not break sneaking")

	var gBreakFieldTarget := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakFieldTarget.player_skills.append("sneak")
	gBreakFieldTarget.use_skill_field("sneak")
	gBreakFieldTarget.player_cell = Vector2i(6, 4)
	gBreakFieldTarget.player_facing = Vector2i.LEFT  # faces dirty_table
	gBreakFieldTarget.use_skill_field("basic_cleaning")
	assert(not gBreakFieldTarget.sneaking, "a field-skill use that resolves on a real target breaks sneaking")

	var gBreakAmbient := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakAmbient.player_skills.append("sneak")
	gBreakAmbient.use_skill_field("sneak")
	gBreakAmbient.player_cell = Vector2i(2, 3)
	gBreakAmbient.player_facing = Vector2i.DOWN  # open floor, no entity faced
	gBreakAmbient.use_skill_field("basic_cleaning")  # falls through to field_ambient
	assert(gBreakAmbient.sneaking, "a field_ambient no-op flourish does NOT break sneaking")

	var gBreakCombat := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gBreakCombat.player_skills.append("sneak")
	gBreakCombat.record_accomplishment("met_relc")
	gBreakCombat.transition("floodplains", Vector2i(27, 18))
	gBreakCombat.use_skill_field("sneak")
	gBreakCombat.dormant_encounters.append("goblin_encounter_2")
	assert(not gBreakCombat.start_combat("goblin_encounter_2"), "fixture: the dormant encounter refuses to start")
	assert(gBreakCombat.sneaking, "a REFUSED start_combat does not break sneaking")
	gBreakCombat.dormant_encounters.clear()
	assert(gBreakCombat.start_combat("goblin_encounter_2"), "a real start_combat succeeds once un-dormant")
	assert(not gBreakCombat.sneaking, "start_combat succeeding breaks sneaking for ANY cause")

	var gSleepClear := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gSleepClear.player_skills.append("sneak")
	gSleepClear.use_skill_field("sneak")
	assert(gSleepClear.sneaking, "fixture: sneaking before sleep")
	_events.clear()
	gSleepClear.sleep()
	assert(not gSleepClear.sneaking, "sleep clears sneaking")
	assert(_count("sneak_ended") == 0, "sleep's clear is silent -- no sneak_ended (matches light_active/frozen_cells)")

	var scene_p1 := WISceneCatalog.compose()
	var skills_p1 := _load_json("res://data/skills.json")

	var g_interact := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_interact.player_cell = Vector2i(6, 4)
	g_interact.player_facing = Vector2i.LEFT  # faces dirty_table at [5,4]
	_events.clear()
	var hint_fx := g_interact.interact()
	assert(hint_fx.get("skill_hint", "") == "basic_cleaning", "interact on a known-skill prop returns the hint shape")
	assert(_events.size() == 1 and _events[0]["type"] == "toast", "hint path emits exactly one toast, nothing else")
	assert(not String(_events[0]["payload"]["text"]).contains("[") and String(_events[0]["payload"]["text"]).contains("wipe-down"), "the nudge is narrative -- no bracketed skill name anywhere in it")
	assert(g_interact.accomplishment_count("cleaned_the_inn") == 0, "interact never casts")

	var g_field := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_field.player_cell = Vector2i(6, 4)
	g_field.player_facing = Vector2i.LEFT
	_events.clear()
	var fx := g_field.use_skill_field("basic_cleaning")
	assert(fx.get("accomplishment", "") == "cleaned_the_inn", "field use of a faced prop returns the prop's effect")
	assert(_count("skill_used") == 1, "the hotbar path is the caster")
	assert(g_field.accomplishment_count("cleaned_the_inn") == 1, "faced-prop field use fires the accomplishment")
	assert(g_field.used_skills.has("basic_cleaning"), "faced-prop field use records used_skills (journal reveal)")

	var g_amb := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_amb.player_cell = Vector2i(2, 3)
	g_amb.player_facing = Vector2i.DOWN  # open cell, no entity faced
	assert(g_amb.entity_at(g_amb.player_cell + g_amb.player_facing).is_empty(), "faced cell is empty for the ambient case")
	_events.clear()
	var amb := g_amb.use_skill_field("basic_cleaning")
	assert(amb.get("ambient", "") == "basic_cleaning", "no faced prop -> ambient result")
	assert(_count("skill_used") == 1, "ambient still emits skill_used")
	assert(_count("toast") == 1, "ambient emits its flavor toast")
	assert(_count("accomplishment_recorded") == 0, "ambient banks no accomplishment")
	assert(g_amb.used_skills.has("basic_cleaning"), "ambient use reveals the skill in the journal")

	var g_glow := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_glow.player_skills.append("light")
	assert(g_glow.known_skills().has("light"), "light is known for the glow case")
	g_glow.player_cell = Vector2i(2, 3)
	g_glow.player_facing = Vector2i.DOWN  # proven-empty faced cell (the ambient case above)
	assert(not g_glow.light_active, "light_active defaults false")
	_events.clear()
	var glow_res := g_glow.use_skill_field("light")
	assert(glow_res.get("ambient", "") == "light", "ambient [Light] cast returns {ambient:light}")
	assert(g_glow.light_active, "ambient [Light] cast flips light_active true")
	assert(_count("ui_pc_light_rendered") == 0, "the SIM emits no ui_pc_light_rendered (that is the presentation's confirmation)")
	g_glow.use_skill_field("light")
	assert(g_glow.light_active, "re-casting [Light] while lit leaves light_active true")
	var g_noglow := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_noglow.player_cell = Vector2i(2, 3)
	g_noglow.player_facing = Vector2i.DOWN
	g_noglow.use_skill_field("basic_cleaning")
	assert(not g_noglow.light_active, "a non-[Light] ambient cast leaves light_active false")
	g_glow.sleep()
	assert(not g_glow.light_active, "sleep() clears light_active (the orb winks out)")

	var g_fed := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	assert(not g_fed.well_fed, "well_fed defaults false")
	g_fed.well_fed = true
	g_fed.sleep()
	assert(not g_fed.well_fed, "sleep() clears well_fed (the meal doesn't carry past a rest)")

	_events.clear()
	var unk := g_amb.use_skill_field("frost_bolt")  # not known by a classless PC
	assert(unk.is_empty(), "unknown field skill returns empty")
	assert(_count("skill_unknown") == 1, "unknown field skill emits skill_unknown")
	assert(_count("toast") == 1, "unknown field skill toasts the generic refusal")
	assert(_count("skill_used") == 0, "unknown field skill does nothing")

	var g_nf := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_nf.player_skills.append("power_strike")  # combat skill, no `field` tag
	assert(g_nf.known_skills().has("power_strike"), "power_strike is known for this case")
	_events.clear()
	var nf := g_nf.use_skill_field("power_strike")
	assert(nf.is_empty(), "non-field skill is refused in the field")
	assert(_count("skill_no_effect") == 1, "non-field field-use emits skill_no_effect")
	assert(_count("toast") == 1, "non-field field-use toasts a refusal")
	assert(_count("skill_used") == 0, "non-field field-use fires nothing")

	var g_na := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_na.skills["synthetic_field"] = {WIKeys.ID: "synthetic_field", WIKeys.DISPLAY_NAME: "[Synthetic]", WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true}
	g_na.player_skills.append("synthetic_field")
	g_na.player_cell = Vector2i(2, 3)
	g_na.player_facing = Vector2i.DOWN
	_events.clear()
	var na := g_na.use_skill_field("synthetic_field")
	assert(na.is_empty(), "field skill with no ambient and no target is refused")
	assert(_count("skill_no_effect") == 1, "no-ambient field-use emits skill_no_effect")
	assert(_count("toast") == 1, "no-ambient field-use toasts the established refusal")
	assert(_count("skill_used") == 0, "no-ambient field-use fires nothing")

	var g_obs := WIGame.new(scene_p1, skills_p1, _sink, 12345)
	g_obs.player_skills.append("observe")
	assert(g_obs.known_skills().has("observe"), "observe is known for this case")
	g_obs.player_cell = Vector2i(7, 3)
	g_obs.player_facing = Vector2i.UP  # faces erin at [7,2]
	_events.clear()
	var ob := g_obs.use_skill_field("observe")
	assert(ob.get("observed", "") == "erin", "observe on a faced entity returns {observed:id}")
	assert(_count("skill_used") == 1, "observe emits skill_used")
	assert(g_obs.accomplishment_count("observed_things") == 1, "observe banks observed_things +1 (opaque tactician feed)")
	assert(g_obs.used_skills.has("observe"), "observe reveals itself in the journal on first use")
	var ob_toast: Dictionary = _events[_events.size() - 1]
	assert(ob_toast["type"] == "toast" and String(ob_toast["payload"]["text"]).begins_with("A young human"), "observe emits the entity's own observe string as the toast")

	g_obs.player_cell = Vector2i(6, 4)
	g_obs.player_facing = Vector2i.LEFT  # faces the dirty_table prop (no `observe` string)
	_events.clear()
	var ob2 := g_obs.use_skill_field("observe")
	assert(not ob2.is_empty() and ob2.has("observed"), "observe on an unlabelled entity still resolves")
	var ob2_toast: Dictionary = _events[_events.size() - 1]
	assert(ob2_toast["payload"]["text"] == "You watch. Details surface.", "generic observe fallback string")
	assert(g_obs.accomplishment_count("observed_things") == 2, "generic-fallback observe still banks observed_things")

	g_obs.player_cell = Vector2i(2, 3)
	g_obs.player_facing = Vector2i.DOWN
	assert(g_obs.entity_at(g_obs.player_cell + g_obs.player_facing).is_empty(), "faced cell empty for observe ambient")
	_events.clear()
	var oba := g_obs.use_skill_field("observe")
	assert(oba.get("ambient", "") == "observe", "empty-cell observe -> ambient result")
	assert(_count("accomplishment_recorded") == 0, "empty-cell observe banks no accomplishment")
	assert(g_obs.accomplishment_count("observed_things") == 2, "observed_things unchanged by an ambient (empty-cell) observe")

	var social_scene := {
		"start_map": "plaza",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: ["observe"]},
		"maps": {"plaza": {
			"grid": {"width": 6, "height": 6},
			"blocked": [],
			"entities": [
				{WIKeys.ID: "gossip_npc", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "Krshia",
				 "talk_pool": ["Gossip one.", "Gossip two.", "Gossip three."],
				 WIKeys.CONVERSATION: "krshia_convo",
				 "observe": "She weighs you like a sack of produce.",
				 "friendly_line": "Hrr. For you, a fair price - and I mean it."},
			],
		}},
	}
	var social_cc: Dictionary = combat_config.duplicate(true)
	social_cc["dialogue"] = {"krshia_convo": {
		"start": "n1",
		"nodes": {"n1": {"speaker": "Krshia", "text": "Real conversation.", "options": [{"text": "Bye.", "end": true}]}},
	}}
	var gS := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	assert(gS.player_facing == Vector2i.RIGHT and gS.entity_at(Vector2i(2, 1)).get(WIKeys.ID, "") == "gossip_npc", "fixture: player faces the gossip NPC")

	_events.clear()
	var t0 := gS.interact()
	assert(t0.get("talked", "") == "gossip_npc" and int(t0.get("index", -1)) == 0, "first talk plays pool line index 0")
	assert(gS.dialogue == null, "the pool line does NOT open the real conversation")
	assert(_count("dialogue_line") == 1 and _count("dialogue_started") == 0, "pool line rides the plain DIALOGUE_LINE surface (gate_guard idiom), not a graph")
	var pool_line0: Dictionary = {}
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			pool_line0 = e["payload"]
	assert(pool_line0.get("speaker", "") == "Krshia" and pool_line0.get("text", "") == "Gossip one.", "pool line carries {speaker=display_name, text=pool[0]}")
	assert(gS.accomplishment_count("chatted_with_gossip_npc") == 1, "first talk banks chatted_with_<id>")
	assert(gS.accomplishment_count("heard_gossip") == 1, "first talk banks heard_gossip")
	assert(bool(gS.social_talked.get("gossip_npc", false)), "first talk sets the social_talked flag")

	_events.clear()
	var t1 := gS.interact()
	assert(t1.get("dialogue", false) == true, "second talk this waking starts the real conversation")
	assert(gS.dialogue != null and _count("dialogue_started") == 1, "the flagged path is today's exact conversation behavior")
	assert(_count("dialogue_line") == 0, "no pool line on the fallthrough talk")
	assert(gS.accomplishment_count("chatted_with_gossip_npc") == 1, "fallthrough talk does not re-bank the counter")
	assert(gS.dialogue_choose(0), "close the real conversation")
	assert(gS.dialogue == null, "conversation closed")

	gS.sleep()
	assert(not bool(gS.social_talked.get("gossip_npc", false)), "sleep clears social_talked (re-arms the pool)")
	_events.clear()
	var t2 := gS.interact()
	assert(int(t2.get("index", -1)) == 1, "next waking rotates to pool line index 1")
	var pool_line1 := ""
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			pool_line1 = String(e["payload"]["text"])
	assert(pool_line1 == "Gossip two.", "index 1 is the second pool line")
	assert(gS.accomplishment_count("chatted_with_gossip_npc") == 2, "second waking's talk banks the counter to 2")

	gS.sleep()
	var t3 := gS.interact()
	assert(int(t3.get("index", -1)) == 2, "third waking rotates to pool line index 2")
	gS.sleep()
	_events.clear()
	var t4 := gS.interact()
	assert(int(t4.get("index", -1)) == 0, "fourth waking WRAPS the rotation back to index 0 (3 %% 3)")
	var pool_line_wrap := ""
	for e: Dictionary in _events:
		if e["type"] == "dialogue_line":
			pool_line_wrap = String(e["payload"]["text"])
	assert(pool_line_wrap == "Gossip one.", "wraparound replays the first pool line")

	var plain_scene := {
		"start_map": "plaza",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"plaza": {
			"grid": {"width": 6, "height": 6}, "blocked": [],
			"entities": [{WIKeys.ID: "guard", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "Guard",
				"dialogue": [{"speaker": "Guard", "text": "Move along."}]}],
		}},
	}
	var gPlain := WIGame.new(plain_scene, skill_config, _sink, 7)
	_events.clear()
	var pl := gPlain.interact()
	assert(pl.get("speaker", "") == "Guard" and pl.get("text", "") == "Move along.", "a no-talk_pool NPC returns its plain dialogue line unchanged")
	assert(_count("dialogue_line") == 1, "plain NPC still emits exactly one dialogue_line")
	assert(gPlain.accomplishment_count("heard_gossip") == 0, "a no-talk_pool NPC banks no social counters")

	var staged_scene := {
		"start_map": "plaza",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"plaza": {
			"grid": {"width": 6, "height": 6},
			"blocked": [],
			"entities": [
				{WIKeys.ID: "staged_npc", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "Staged",
				 "talk_pool": ["Base one.", "Base two."],
				 "talk_pool_stages": [
					{"id": "stage_two", "requires_accomplishment": {"leg_a": 1}, "lines": ["Stage two one.", "Stage two two."]},
					{"id": "stage_three", "requires_accomplishment": {"leg_a": 1, "leg_b": 1}, "lines": ["Stage three one.", "Stage three two."]},
				 ]},
			],
		}},
	}
	var base_pool: Array = ["Base one.", "Base two."]
	var stage2_pool: Array = ["Stage two one.", "Stage two two."]
	var stage3_pool: Array = ["Stage three one.", "Stage three two."]
	var gStg := WIGame.new(staged_scene, skill_config, _sink, 7)
	_events.clear()
	gStg.interact()
	assert(base_pool.has(_last_dialogue_text()), "unmet stage gates: first talk plays the BASE pool")
	gStg.sleep()
	gStg.record_accomplishment("leg_a")
	_events.clear()
	gStg.interact()
	var at_stage2 := _last_dialogue_text()
	assert(stage2_pool.has(at_stage2) and not base_pool.has(at_stage2), "leg_a alone met: stage 2's pool wins")
	gStg.sleep()
	gStg.record_accomplishment("leg_b")
	_events.clear()
	gStg.interact()
	var at_stage3 := _last_dialogue_text()
	assert(stage3_pool.has(at_stage3) and not stage2_pool.has(at_stage3), "both legs met: stage 3 (the LAST met entry) wins, not stage 2")

	var gObs := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	assert(gObs.known_skills().has("observe"), "observe is known for the dedup case")
	_events.clear()
	var ob_a := gObs.use_skill_field("observe")
	assert(ob_a.get("observed", "") == "gossip_npc", "first observe resolves on the faced entity")
	assert(gObs.accomplishment_count("observed_things") == 1, "first observe banks observed_things")
	assert(_count("skill_used") == 1, "first observe emits skill_used")
	_events.clear()
	var ob_b := gObs.use_skill_field("observe")
	assert(ob_b.get("observed", "") == "gossip_npc", "repeat observe still resolves (flavor + reveal fire)")
	assert(_count("skill_used") == 1, "repeat observe still emits skill_used (only the bank is deduped)")
	assert(_count("toast") == 1, "repeat observe still shows the flavor toast")
	assert(gObs.accomplishment_count("observed_things") == 1, "repeat observe of the same entity banks NOTHING (farm resolved)")
	assert(_count("accomplishment_recorded") == 0, "no accomplishment_recorded on the deduped repeat observe")
	gObs.sleep()
	assert(gObs.entity_first_use.is_empty(), "sleep clears entity_first_use (re-arms first-use banks)")
	var ob_c := gObs.use_skill_field("observe")
	assert(ob_c.get("observed", "") == "gossip_npc", "post-sleep observe resolves again")
	assert(gObs.accomplishment_count("observed_things") == 2, "post-sleep observe of the same entity banks again (re-armed)")

	var gCharm := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	gCharm.player_skills.append("charming_smile")
	assert(gCharm.known_skills().has("charming_smile"), "charming_smile is known for this case")
	_events.clear()
	var ch_a := gCharm.use_skill_field("charming_smile")
	assert(ch_a.get("befriended", "") == "gossip_npc", "charm on a faced entity returns {befriended:id}")
	assert(gCharm.accomplishment_count("befriended_moments") == 1, "first charm banks befriended_moments +1 (opaque diplomat feed)")
	assert(_count("skill_used") == 1, "charm emits skill_used")
	assert(gCharm.used_skills.has("charming_smile"), "charm reveals itself in the journal on first use")
	var ch_toast: Dictionary = _events[_events.size() - 1]
	assert(ch_toast["type"] == "toast" and ch_toast["payload"]["text"] == "Hrr. For you, a fair price - and I mean it.", "charm emits the entity's own friendly_line as the toast")
	_events.clear()
	var ch_b := gCharm.use_skill_field("charming_smile")
	assert(ch_b.get("befriended", "") == "gossip_npc", "repeat charm still resolves (flavor + reveal fire)")
	assert(_count("skill_used") == 1, "repeat charm still emits skill_used (only the bank is deduped)")
	assert(_count("toast") == 1, "repeat charm still shows the friendly toast")
	assert(gCharm.accomplishment_count("befriended_moments") == 1, "repeat charm of the same entity banks NOTHING (farm resolved, mirrors observe)")
	gCharm.player_skills.append("observe")
	var ch_ob := gCharm.use_skill_field("observe")
	assert(ch_ob.get("observed", "") == "gossip_npc", "observe on the already-charmed entity resolves")
	assert(gCharm.accomplishment_count("observed_things") == 1, "observe banks independently of charm on the SAME entity (composite dedup key)")
	assert(gCharm.accomplishment_count("befriended_moments") == 1, "the independent observe did NOT touch befriended_moments")
	gCharm.sleep()
	assert(gCharm.entity_first_use.is_empty(), "sleep clears the shared first-use dict (re-arms the friendly bank too)")
	var ch_c := gCharm.use_skill_field("charming_smile")
	assert(ch_c.get("befriended", "") == "gossip_npc", "post-sleep charm resolves again")
	assert(gCharm.accomplishment_count("befriended_moments") == 2, "post-sleep charm of the same entity banks again (re-armed)")
	var charm_scene2: Dictionary = social_scene.duplicate(true)
	(charm_scene2["maps"]["plaza"]["entities"] as Array)[0].erase("friendly_line")
	var gCharm2 := WIGame.new(charm_scene2, skill_config, _sink, 7, social_cc)
	gCharm2.player_skills.append("charming_smile")
	_events.clear()
	var ch2 := gCharm2.use_skill_field("charming_smile")
	assert(not ch2.is_empty() and ch2.has("befriended"), "charm on a friendly_line-less entity still resolves")
	var ch2_toast: Dictionary = _events[_events.size() - 1]
	assert(String(ch2_toast["payload"]["text"]).begins_with("You offer a warm"), "generic friendly fallback string")
	assert(gCharm2.accomplishment_count("befriended_moments") == 1, "generic-fallback charm still banks befriended_moments")
	gCharm2.player_cell = Vector2i(4, 4)
	gCharm2.player_facing = Vector2i.DOWN
	assert(gCharm2.entity_at(gCharm2.player_cell + gCharm2.player_facing).is_empty(), "faced cell empty for charm ambient")
	_events.clear()
	var chamb := gCharm2.use_skill_field("charming_smile")
	assert(chamb.get("ambient", "") == "charming_smile", "empty-cell charm -> ambient result")
	assert(_count("accomplishment_recorded") == 0, "empty-cell charm banks no accomplishment")

	var gSaveA := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	gSaveA.interact()  # bank a talk-pool line -> populates social_talked + counters
	gSaveA.use_skill_field("observe")  # populate entity_first_use
	assert(bool(gSaveA.social_talked.get("gossip_npc", false)), "round-trip fixture: social_talked populated")
	assert(not gSaveA.entity_first_use.is_empty(), "round-trip fixture: entity_first_use populated")
	var s1_data := WISave.serialize(gSaveA)
	var gSaveB := WIGame.new(social_scene, skill_config, _sink, 7, social_cc)
	assert(WISave.apply(gSaveB, s1_data), "S1 save applies")
	assert(gSaveB.social_talked == gSaveA.social_talked, "social_talked round-trips")
	assert(gSaveB.entity_first_use == gSaveA.entity_first_use, "entity_first_use round-trips")

	var gGrate := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gGrate.transition("street", Vector2i(15, 11))
	gGrate.player_facing = Vector2i.RIGHT  # faces the sewer_grate at (16,11)
	assert(gGrate.entity_at(Vector2i(16, 11)).get(WIKeys.ID, "") == "sewer_grate", "grate is at (16,11) facing cell")
	_events.clear()
	var pre := gGrate.interact()
	assert(pre.get("accomplishment", "") == "heard_the_sewers", "unmet grate banks heard_the_sewers (unchanged pre-quest behavior)")
	assert(gGrate.current_map == "street", "unmet grate does NOT transition")
	assert(_count("map_changed") == 0, "unmet grate emits no map_changed")
	assert(_count("toast") == 1 and String(_events[-1]["payload"].get("text", "")).begins_with("A heavy iron grate"), "unmet grate fires the exact pre-quest toast")
	assert(gGrate.accomplishment_count("heard_the_sewers") == 1, "heard_the_sewers banked once")
	gGrate.record_accomplishment("heard_about_cisterns")
	gGrate.player_cell = Vector2i(15, 11)
	gGrate.player_facing = Vector2i.RIGHT
	_events.clear()
	var opened := gGrate.interact()
	assert(opened.get("map", "") == "sewers", "met grate transitions to sewers")
	assert(gGrate.current_map == "sewers", "now on the sewers map")
	assert(gGrate.player_cell == Vector2i(2, 2), "descends to the sewers landing (2,2)")
	assert(_count("map_changed") == 1, "met grate emits map_changed")
	assert(gGrate.accomplishment_count("heard_the_sewers") == 1, "met grate does NOT re-bank heard_the_sewers")
	assert(gGrate.entities.has("shield_spiders") and gGrate.entities.has("sewer_exit"), "sewers entities bound")
	gGrate.player_cell = Vector2i(2, 2)
	gGrate.player_facing = Vector2i.UP
	gGrate.interact()
	assert(gGrate.current_map == "street" and gGrate.player_cell == Vector2i(15, 11), "ladder returns to the street grate")

	var gGold := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	assert(gGold.gold == 0, "fresh purse starts at 0")
	_events.clear()
	gGold.earn_gold(5, "test_chore")
	assert(gGold.gold == 5, "earn_gold adds to the purse")
	assert(String(_events[0]["type"]) == "gold_changed" and int(_events[0]["payload"]["delta"]) == 5 and int(_events[0]["payload"]["total"]) == 5 and String(_events[0]["payload"]["source"]) == "test_chore", "earn emits gold_changed {delta,total,source}")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "Earned 5 gold.", "earn emits the diegetic toast")
	_events.clear()
	assert(gGold.spend_gold(3, "krshia_shop"), "spend within budget succeeds")
	assert(gGold.gold == 2, "spend deducts from the purse")
	assert(String(_events[0]["type"]) == "gold_changed" and int(_events[0]["payload"]["delta"]) == -3 and int(_events[0]["payload"]["total"]) == 2 and String(_events[0]["payload"]["source"]) == "krshia_shop", "spend emits signed gold_changed with the sink as source")
	assert(String(_events[-1]["payload"]["text"]) == "Paid 3 gold.", "spend emits the diegetic toast")
	_events.clear()
	assert(not gGold.spend_gold(99, "krshia_shop"), "spend refuses when short (no debt)")
	assert(gGold.gold == 2, "refused spend leaves the purse untouched")
	assert(_count("gold_changed") == 0, "refused spend emits no gold_changed")
	assert(_count("toast") == 1 and String(_events[-1]["payload"]["text"]) == "Not enough gold.", "refused spend emits the refusal toast idiom")
	_events.clear()
	gGold.earn_gold(0, "x")
	assert(not gGold.spend_gold(0, "x"), "zero spend refuses")
	assert(gGold.gold == 2 and _events.is_empty(), "non-positive gold ops are silent no-ops")

	var loot_entity := {WIKeys.ID: "econ_test_encounter", "loot": [{"gold": 7, "chance": 0.5}, {"gold": 3, "chance": 0.5}]}
	var GldA := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 4242, combat_config)
	GldA._roll_loot(loot_entity)
	var GldB := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 4242, combat_config)
	GldB._roll_loot(loot_entity)
	assert(GldA.gold == GldB.gold, "same run_seed + encounter id -> identical loot-gold roll across independent instances")
	var sure_loot := {WIKeys.ID: "econ_sure_encounter", "loot": [{"gold": 7, "chance": 1.0}]}
	var GldC := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 4242, combat_config)
	_events.clear()
	GldC._roll_loot(sure_loot)
	assert(GldC.gold == 7, "guaranteed coin drop earns exactly the listed gold")
	assert(_count("loot_dropped") == 1, "coin drop emits one loot_dropped")
	assert(_count("gold_changed") == 1, "loot-gold routes through earn_gold (one gold_changed)")
	var econ_ld: Dictionary = {}
	for e: Dictionary in _events:
		if String(e["type"]) == "loot_dropped":
			econ_ld = e["payload"]
	assert(int(econ_ld.get("gold", 0)) == 7, "loot_dropped carries {gold}")
	assert(not econ_ld.has("items"), "pure-coin loot payload omits the items key (item-only stream stays byte-identical)")

	var gLoad := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gLoad.classes = {"warrior": 1, "tactician": 1, "helper": 1}
	assert(gLoad.hotbar_loadout.is_empty(), "fresh game starts in AUTO mode (empty loadout)")
	var manual_field: Array = []
	for raw: Variant in gLoad.known_skills():
		var id := String(raw)
		if bool((gLoad.skills.get(id, {}) as Dictionary).get("field", false)):
			manual_field.append(id)
	assert(gLoad.field_hotbar_loadout() == manual_field, "AUTO field_hotbar_loadout() matches the manual known_skills()-filtered-by-field derivation exactly (byte-parity proof)")
	assert(gLoad.field_hotbar_loadout() == ["basic_cleaning", "basic_cooking", "observe"], "AUTO field order: innate first, then catalog-order class grants (warrior contributes no field skills; helper's basic_cooking, then tactician's observe)")

	assert(WIGame.apply_loadout(["a", "b", "c"], []) == ["a", "b", "c"], "empty loadout is a pure passthrough (AUTO)")
	assert(WIGame.apply_loadout(["a", "b", "c"], ["c", "a"]) == ["c", "a"], "non-empty loadout reorders to LOADOUT order and drops unlisted candidates")
	assert(WIGame.apply_loadout(["a", "b"], ["nonexistent_skill", "b"]) == ["b"], "a loadout id absent from candidates (unknown/renamed) is silently dropped, never an error")

	# --- a7 #208: auto-slot on grant, custom-loadout mode only. The two call
	# sites (sleep() end, accept_consolidation() end) are one-line reconciles
	# over this helper; arms exercise the helper's whole decision table. ---
	var gAuto := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gAuto.classes = {"warrior": 1, "tactician": 1, "helper": 1}
	gAuto.hotbar_loadout.assign(["basic_cleaning"])
	_events.clear()
	var before_no_observe: Array = gAuto.known_skills().filter(func(id: Variant) -> bool: return String(id) != "observe")
	gAuto._auto_slot_new_field_skills(before_no_observe)
	assert(gAuto.hotbar_loadout == ["basic_cleaning", "observe"], "a newly granted field skill auto-joins a CUSTOM loadout")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "loadout_changed" and bool(e["payload"].get("auto", false)) and String(e["payload"]["skill"]) == "observe"),
		"auto-slot emits LOADOUT_CHANGED with auto:true")
	gAuto._auto_slot_new_field_skills(before_no_observe)
	assert(gAuto.hotbar_loadout == ["basic_cleaning", "observe"], "already-slotted: idempotent, no duplicate")
	gAuto.hotbar_loadout.assign(["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9"])
	gAuto._auto_slot_new_field_skills(before_no_observe)
	assert(gAuto.hotbar_loadout.size() == 9, "a full bar (AUTO_SLOT_CAP 9) never grows — selection stays manual when there is no room")
	gAuto.hotbar_loadout.clear()
	_events.clear()
	gAuto._auto_slot_new_field_skills(before_no_observe)
	assert(gAuto.hotbar_loadout.is_empty() and _events.is_empty(), "AUTO mode (empty loadout) needs nothing — it already shows every field skill")
	gAuto.hotbar_loadout.assign(["basic_cleaning"])
	var before_no_appraise: Array = gAuto.known_skills().filter(func(id: Variant) -> bool: return String(id) != "battlefield_awareness")
	gAuto._auto_slot_new_field_skills(before_no_appraise)
	assert(gAuto.hotbar_loadout == ["basic_cleaning"], "a NON-field grant never auto-slots")

	# Review fixes, pinned: (HIGH) an item-only loadout is an AUTO field bar
	# — auto-slot must NOT touch it (appending would collapse the bar to one
	# skill); (cap) item pins never count against the 9 skill keys; and the
	# CALL SITES themselves via a real sleep and a real consolidation decline.
	gAuto.hotbar_loadout.assign(["item:healing_draught"])
	_events.clear()
	gAuto._auto_slot_new_field_skills(before_no_observe)
	assert(gAuto.hotbar_loadout == ["item:healing_draught"] and _events.is_empty(),
		"item-only pins keep the field bar AUTO — auto-slot stays out (review HIGH: the collapse bug)")
	gAuto.hotbar_loadout.assign(["item:a", "item:b", "item:c", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8"])
	gAuto._auto_slot_new_field_skills(before_no_observe)
	assert(gAuto.hotbar_loadout.has("observe"),
		"cap counts SKILL entries only (8 skills + 3 item pins = room for a 9th skill)")
	var gAutoSleep := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	gAutoSleep.classes = {"warrior": 1}
	gAutoSleep.hotbar_loadout.assign(["basic_cleaning"])
	gAutoSleep.record_accomplishment("chess_with_olesm")
	_events.clear()
	gAutoSleep.sleep()
	assert(gAutoSleep.classes.has("tactician"), "sleep granted the tactician entry (integration precondition)")
	assert(gAutoSleep.hotbar_loadout.has("observe"),
		"the sleep() call site reconciles for real — tactician's observe auto-slots (review: deletable-call-site pin)")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "loadout_changed" and bool(e["payload"].get("auto", false))),
		"the sleep-path auto-slot emits auto:true")

	_events.clear()
	gLoad.loadout_toggle("observe")
	assert(gLoad.hotbar_loadout == ["observe"], "toggle on an unslotted skill assigns it (appends)")
	assert(_count("loadout_changed") == 1, "assign emits exactly one loadout_changed")
	assert(bool(_events[-1]["payload"]["assigned"]) == true and String(_events[-1]["payload"]["skill"]) == "observe" and (_events[-1]["payload"]["loadout"] as Array) == ["observe"], "loadout_changed payload carries {skill, assigned, loadout} exactly")
	assert(gLoad.field_hotbar_loadout() == ["observe"], "a non-empty loadout intersects+reorders the field bar (basic_cleaning/basic_cooking drop out, unslotted this walk)")
	gLoad.loadout_toggle("basic_cleaning")
	assert(gLoad.hotbar_loadout == ["observe", "basic_cleaning"], "a second assign appends after the first (v1-minimal reorder: assignment order IS the order)")
	assert(gLoad.field_hotbar_loadout() == ["observe", "basic_cleaning"], "field bar order follows LOADOUT order, not known_skills() order")
	_events.clear()
	gLoad.loadout_toggle("observe")
	assert(gLoad.hotbar_loadout == ["basic_cleaning"], "toggling an already-slotted skill unassigns it (erase, not re-append)")
	assert(bool(_events[-1]["payload"]["assigned"]) == false, "unassign emits loadout_changed with assigned:false")
	gLoad.loadout_toggle("basic_cleaning")
	assert(gLoad.hotbar_loadout.is_empty(), "unassigning the last entry returns to AUTO (empty loadout)")
	assert(gLoad.field_hotbar_loadout() == manual_field, "back to AUTO once the loadout empties out again -- exact parity with the original derivation")
	gLoad.loadout_toggle("item:mending_draught")
	assert(gLoad.hotbar_loadout == ["item:mending_draught"], "item token assigns onto the shared loadout")
	assert(gLoad.field_hotbar_loadout() == manual_field, "an item-only loadout leaves the field bar AUTO (item: tokens stripped, never a blank bar)")
	gLoad.loadout_toggle("observe")
	assert(gLoad.field_hotbar_loadout() == ["observe"], "item token + one skill: field bar carries the skill only, loadout order preserved")
	gLoad.loadout_toggle("observe")
	gLoad.loadout_toggle("item:mending_draught")
	assert(gLoad.hotbar_loadout.is_empty() and gLoad.field_hotbar_loadout() == manual_field, "untoggling both restores AUTO exactly")

	gLoad.loadout_toggle("not_a_real_skill_id")
	assert(gLoad.hotbar_loadout.has("not_a_real_skill_id"), "loadout_toggle doesn't gate on known-ness at write time")
	assert(not gLoad.field_hotbar_loadout().has("not_a_real_skill_id"), "an unknown id in the loadout is silently filtered out at READ time")
	gLoad.loadout_toggle("not_a_real_skill_id")
	assert(gLoad.hotbar_loadout.is_empty(), "cleanup: unassigned back to AUTO")

	var del_cc := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"items": _load_json("res://data/items.json"),
		"deliveries": _load_json("res://data/deliveries.json"),
	}
	var gDel := WIGame.new(scene_config, skill_config, _sink, 7, del_cc)
	var del_slate_ids: Array = gDel.delivery_board_deliveries().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(del_slate_ids == ["delivery_krshia_wool", "delivery_pisces_parcel", "delivery_gate_dispatch"], "times_slept 0 slate = pool window [0..2] (the DP2 rotation function, shared)")
	_events.clear()
	gDel.accept_delivery("delivery_krshia_wool")
	assert(gDel.accepted_delivery_id == "delivery_krshia_wool", "accept banks the slip")
	assert(gDel.inventory.has("parcel_plains_wool"), "accept grants the parcel via pickup")
	assert(gDel.accomplishment_count("accepted_delivery_delivery_krshia_wool") == 1, "accept banks accepted_delivery_<id>")
	assert(gDel.accepted_delivery_baseline == {"delivered_delivery_krshia_wool": 0}, "delta baseline snapshotted at accept")
	assert(_count("item_gained") == 1, "parcel grant emits item_gained")
	gDel.accept_delivery("delivery_pisces_parcel")
	assert(gDel.accepted_delivery_id == "delivery_krshia_wool", "one slip at a time -- second accept is a no-op")
	assert(not gDel.inventory.has("parcel_that_ticks"), "no second parcel granted")
	assert(not gDel.turn_in_delivery(), "turn-in refuses before the mark is reached")
	assert(gDel.accepted_delivery_id == "delivery_krshia_wool" and gDel.gold == 0, "refused turn-in leaves all state untouched")
	gDel.transition("street", Vector2i(14, 5))
	assert(gDel.inventory.has("parcel_plains_wool"), "a transition/teleport never triggers arrival (move_player-only, the trigger_radius convention)")
	assert(gDel.move_player(Vector2i.UP), "step to (14,4)")
	assert(gDel.inventory.has("parcel_plains_wool"), "distance 2 is not arrival")
	_events.clear()
	assert(gDel.move_player(Vector2i.UP), "step to (14,3), adjacent to the stall")
	assert(gDel.accomplishment_count("delivered_delivery_krshia_wool") == 1, "arrival banks delivered_<id>")
	assert(not gDel.inventory.has("parcel_plains_wool"), "arrival IS the handoff -- parcel leaves the pack")
	assert(_count("item_lost") == 1, "handoff emits item_lost")
	assert(_toast_texts().has("Delivered: Plains-Wool Bolt."), "handoff toast names the parcel")
	_events.clear()
	assert(gDel.turn_in_delivery(), "turn-in pays once the mark is made")
	assert(gDel.gold == 1, "band-1 leg pays 1 gold through earn_gold")
	assert(gDel.accomplishment_count("completed_delivery_delivery_krshia_wool") == 1, "turn-in banks completed_delivery_<id>")
	assert(gDel.accepted_delivery_id == "" and gDel.accepted_delivery_baseline.is_empty(), "turn-in clears the slip")
	gDel.accept_delivery("delivery_gate_dispatch")
	assert(gDel.inventory.has("parcel_watch_dispatch"), "second slip's parcel granted")
	_events.clear()
	gDel.sleep()
	assert(not gDel.inventory.has("parcel_watch_dispatch"), "sleep with an undelivered parcel returns it")
	assert(gDel.accepted_delivery_id == "" and gDel.delivery_failed, "run failed: slip cleared, delivery_failed armed for Vess's one-shot bark")
	assert(_count("item_lost") == 1, "the return emits item_lost")
	assert(_toast_texts().has("The undelivered parcel goes back on the night ledger."), "the return is toasted at the sleep beat")
	assert(gDel.accomplishment_count("completed_delivery_delivery_gate_dispatch") == 0 and gDel.gold == 1, "no pay, no completion on a failed run")
	var del_slate_after: Array = gDel.delivery_board_deliveries().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(del_slate_after == ["delivery_gate_dispatch", "delivery_grate_phials", "delivery_inn_hamper"], "the sleep rotates the slate over the RETIREMENT-FILTERED pool (times_slept 1 window, krshia_wool excluded)")
	assert(not del_slate_after.has("delivery_krshia_wool"), "a completed delivery never reappears in the slate, permanently")

	_events.clear()
	gDel.accept_delivery("delivery_krshia_wool")
	assert(gDel.accepted_delivery_id == "", "accept_delivery refuses a retired (completed) delivery id")
	assert(not gDel.inventory.has("parcel_plains_wool"), "no parcel re-granted for a retired id")
	assert(_events.is_empty(), "the refused re-accept emits nothing")

	gDel.accept_delivery("delivery_pisces_parcel")
	assert(gDel.accepted_delivery_id == "delivery_pisces_parcel", "a still-live (uncompleted) delivery accepts normally")
	gDel.transition("street", Vector2i(30, 6))
	assert(gDel.inventory.has("parcel_that_ticks"), "a transition/teleport never triggers arrival")
	_events.clear()
	assert(gDel.move_player(Vector2i.UP), "step to (30,5), adjacent to pisces (30,4)")
	assert(gDel.accomplishment_count("delivered_delivery_pisces_parcel") == 1, "arrival banks delivered_<id>")
	assert(not gDel.inventory.has("parcel_that_ticks"), "arrival IS the handoff -- parcel leaves the pack")
	gDel.sleep()
	assert(gDel.accepted_delivery_id == "delivery_pisces_parcel", "a delivered-but-unpaid slip survives sleep")
	assert(gDel.turn_in_delivery() and gDel.gold == 2, "pay collects fine on a later waking")
	assert(gDel.accomplishment_count("completed_delivery_delivery_pisces_parcel") == 1, "second delivery completes too")

	gDel.accept_delivery("delivery_standing_dispatch_run")
	assert(gDel.accepted_delivery_id == "delivery_standing_dispatch_run", "a standing slip accepts normally")
	assert(gDel.accepted_delivery_baseline == {"delivered_delivery_standing_dispatch_run": 0}, "first accept baselines at zero")
	assert(gDel.inventory.has("parcel_watch_dispatch"), "standing slip grants its (reused-id) parcel")
	gDel.transition("street", Vector2i(3, 5))
	assert(gDel.move_player(Vector2i.DOWN), "step to (3,6), adjacent to zevara (2,6)")
	assert(gDel.accomplishment_count("delivered_delivery_standing_dispatch_run") == 1, "arrival banks delivered_<id> (anchor override reads zevara's LIVE cell, not the [1,6] fallback)")
	assert(gDel.turn_in_delivery() and gDel.gold == 4, "standing leg pays its 2g band")
	assert(gDel.accomplishment_count("completed_delivery_delivery_standing_dispatch_run") == 1, "completion banks normally")
	gDel.accept_delivery("delivery_standing_dispatch_run")
	assert(gDel.accepted_delivery_id == "delivery_standing_dispatch_run", "a completed STANDING slip re-accepts (a one-off id is refused here)")
	assert(gDel.accepted_delivery_baseline == {"delivered_delivery_standing_dispatch_run": 1}, "re-accept baselines at the PRIOR delivered count -- delta demands a fresh arrival")
	assert(gDel.inventory.has("parcel_watch_dispatch"), "parcel granted again")
	assert(not gDel.turn_in_delivery(), "no pay off the FIRST carry's mark -- the delta honesty property")
	assert(gDel.move_player(Vector2i.DOWN), "step to (3,7), still adjacent")
	assert(gDel.accomplishment_count("delivered_delivery_standing_dispatch_run") == 2, "fresh arrival banks the second delivered_<id>")
	assert(gDel.turn_in_delivery() and gDel.gold == 6, "the standing route pays AGAIN -- the loop's whole point")
	assert(gDel.accomplishment_count("completed_delivery_delivery_standing_dispatch_run") == 2, "second completion tallies")
	while gDel.times_slept < 8:
		gDel.sleep()
	var standing_slate: Array = gDel.delivery_board_deliveries().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(standing_slate == ["delivery_standing_dispatch_run", "delivery_standing_inn_hamper", "delivery_standing_barracks_kit"], "a completed standing id keeps rotating -- never retired")

	var bounty_cc := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"items": _load_json("res://data/items.json"),
		"bounties": _load_json("res://data/bounties.json"),
	}
	var gB := WIGame.new(scene_config, skill_config, _sink, 7, bounty_cc)
	var pre_ids: Array = gB.board_bounties().map(func(b: Dictionary) -> String: return String(b["id"]))
	assert(pre_ids == ["bounty_road_cull", "bounty_settle_dispute", "bounty_gossip_tea"], "ts-0 window unchanged by the gated appends")
	gB.times_slept = 26
	var wrap_pre: Array = gB.board_bounties().map(func(b: Dictionary) -> String: return String(b["id"]))
	assert(wrap_pre == ["bounty_road_cull", "bounty_settle_dispute", "bounty_gossip_tea"], "pre-post_game the 26-entry pool wraps ts 26 to [0..2] -- gated rows invisible to rotation")
	gB.record_accomplishment("post_game")
	var wrap_post: Array = gB.board_bounties().map(func(b: Dictionary) -> String: return String(b["id"]))
	assert(wrap_post == ["bounty_standing_den_watch", "bounty_standing_lantern_line", "bounty_standing_road_order"], "post_game grows the pool to 29 and ts 26 reads the standing orders")
	gB.accept_bounty("bounty_standing_den_watch")
	assert(gB.accepted_bounty_id == "bounty_standing_den_watch", "a standing order accepts")
	assert(gB.accepted_bounty_baseline == {"kingslayer_spiders_culled": 0}, "delta baseline snapshotted")
	assert(not gB.turn_in_bounty(), "no pay before the culls")
	gB.record_accomplishment("kingslayer_spiders_culled")
	gB.record_accomplishment("kingslayer_spiders_culled")
	assert(gB.turn_in_bounty() and gB.gold == 10, "two culls pay the T4 band (10g)")
	gB.accept_bounty("bounty_standing_den_watch")
	assert(gB.accepted_bounty_id == "bounty_standing_den_watch", "the SAME posting re-accepts -- repeatable (delta mode, never one-shot-retired)")
	assert(gB.accepted_bounty_baseline == {"kingslayer_spiders_culled": 2}, "re-accept baselines at the prior count")
	assert(not gB.turn_in_bounty(), "prior culls never pay twice")
	gB.abandon_bounty()

	# --- b4 #219: turnin-graph voice param, all four arms (the grimalkin
	# MET arm has no canonical crossing -- QA's lean study loop only reaches
	# not-done -- so this is that copy's only executable proof; the selys
	# arms pin the default stays byte-identical for every existing caller) ---
	var tg_s_no: Dictionary = WIBounties.build_turnin_graph(false)
	var tg_s_yes: Dictionary = WIBounties.build_turnin_graph(true, "selys")
	var tg_g_no: Dictionary = WIBounties.build_turnin_graph(false, "grimalkin")
	var tg_g_yes: Dictionary = WIBounties.build_turnin_graph(true, "grimalkin")
	assert(String((tg_s_no["nodes"]["hub"] as Dictionary)["speaker"]) == "Selys"
		and String((tg_s_no["nodes"]["hub"] as Dictionary)["text"]) == "The notice says proof. Bring the proof, not the story. The story's free and so is my time apparently.",
		"voice default (omitted) stays Selys not-done verbatim")
	assert(String((tg_s_yes["nodes"]["hub"] as Dictionary)["text"]).begins_with("Done? "),
		"explicit selys met arm matches the shipped copy")
	assert(String((tg_g_no["nodes"]["hub"] as Dictionary)["speaker"]) == "Grimalkin"
		and String((tg_g_no["nodes"]["hub"] as Dictionary)["text"]) == "Incomplete measurements are noise. I did not assign you that errand, or you have not finished mine. Either way: come back with data.",
		"grimalkin not-done arm verbatim")
	assert(String((tg_g_yes["nodes"]["hub"] as Dictionary)["text"]) == "Adequate. The numbers hold, which puts you above most of my subjects. Payment as contracted — precision costs, and I pay for it.",
		"grimalkin met arm verbatim (no canonical reaches it)")

	# --- b4 #219 review fix: desk/paper matching. A desk only settles its
	# own paper; a MET foreign posting must never render a paid arm (the
	# review's live repro: road_cull consumed at Grimalkin's desk). ---
	var guild_row := {"id": "bounty_road_cull"}
	var private_row := {"id": "grimalkin_study_combat", "board": false}
	assert(not WIBounties.turnin_is_foreign(guild_row, "selys"), "guild paper at Selys's desk is hers")
	assert(WIBounties.turnin_is_foreign(guild_row, "grimalkin"), "guild paper at Grimalkin's desk is foreign")
	assert(WIBounties.turnin_is_foreign(private_row, "selys"), "private paper at Selys's desk is foreign")
	assert(not WIBounties.turnin_is_foreign(private_row, "grimalkin"), "private paper at his desk is his")
	var tg_g_foreign: Dictionary = WIBounties.build_turnin_graph(true, "grimalkin", true)
	assert(String((tg_g_foreign["nodes"]["hub"] as Dictionary)["text"]).begins_with("Incomplete measurements are noise."),
		"met+foreign at his desk renders his not-done copy, never the paid arm")
	var tg_s_foreign: Dictionary = WIBounties.build_turnin_graph(true, "selys", true)
	assert(String((tg_s_foreign["nodes"]["hub"] as Dictionary)["text"]) == "That's not Guild paper. Whoever wrote that contract pays for it — take it back to them. My ledger stays clean.",
		"met+foreign at her desk renders her foreign line verbatim, never the Guild-thanks payout copy")
	var ab_private: Dictionary = WIBounties.build_abandon_graph(true)
	assert(String((ab_private["nodes"]["hub"] as Dictionary)["text"]).begins_with("Hand it back? Fine. That one never touched my board"),
		"private abandon drops the fiction-false 'goes back on the board' line")
	assert(String((WIBounties.build_abandon_graph()["nodes"]["hub"] as Dictionary)["text"]).ends_with("for someone with follow-through."),
		"default abandon copy stays byte-identical")

	# --- b7 #207: delivery acknowledgments — the surfaces no canonical
	# renders live (no fixture banks a delivered_* counter). Stage precedence
	# on the SHIPPED entity rows, and the grate's observe override (its
	# interact toast is door-blocked once heard_about_cisterns banks). ---
	var ack_street: Dictionary = _load_json("res://data/maps/liscor/street.json")
	var zev_row: Dictionary = (ack_street["entities"] as Array).filter(func(e: Variant) -> bool: return String((e as Dictionary).get("id", "")) == "zevara")[0]
	var ack_counts := {"delivered_delivery_gate_dispatch": 1}
	var ack_lines: Array = []
	var ack_soc := WISocial.new(
		func(type: String, payload: Dictionary) -> void: if type == WIEvents.DIALOGUE_LINE: ack_lines.append(String(payload["text"])),
		func(id: String) -> int: return int(ack_counts.get(id, 0)),
		func(_id: String, _n: int) -> void: pass,
		Callable())
	ack_soc.talk_pool_line(zev_row, {})
	assert(ack_lines[-1] == "That dispatch you ran made it up the chain. Somebody upstairs read it, which is more than dispatches usually get. Don't let it go to your head.",
		"zevara one-shot delivery ack renders when only the dispatch is delivered")
	ack_counts["delivered_delivery_standing_dispatch_run"] = 1
	ack_soc.talk_pool_line(zev_row, {})
	assert(ack_lines[-1].begins_with("Dispatch pouch's on the run again."),
		"the standing-run familiarity stage outranks the one-shot ack (later in the array)")
	ack_counts["resolved_the_cisterns"] = 1
	ack_soc.talk_pool_line(zev_row, {})
	assert(ack_lines[-1].begins_with("Word is the cistern thing's settled."),
		"an active story thread outranks both delivery stages (acks sit first = lowest priority)")
	var erin_row: Dictionary = (_load_json("res://data/maps/inn/inn.json")["entities"] as Array).filter(func(e: Variant) -> bool: return String((e as Dictionary).get("id", "")) == "erin")[0]
	ack_counts.clear()
	ack_counts["delivered_delivery_inn_hamper"] = 1
	ack_soc.talk_pool_line(erin_row, {})
	assert(ack_lines[-1].begins_with("The hamper made it!"),
		"erin's hamper ack renders post-delivery (sits after the nudge block)")
	ack_counts["errand_decided"] = 1
	ack_counts["chatted_with_erin"] = 2
	ack_soc.talk_pool_line(erin_row, {})
	assert(ack_lines[-1].begins_with("Selys asked about you the other day."),
		"erin's warm terminal outranks the one-shot hamper ack once its gates are met (positive pin: erin_regular line 2 = chatted 2 % 3)")
	ack_counts["delivered_delivery_standing_inn_hamper"] = 1
	ack_soc.talk_pool_line(erin_row, {})
	assert(ack_lines[-1].begins_with("Hamper day again?"),
		"the promoted standing-hamper familiarity outranks the warm terminal (the review fix: the ordinary-path acknowledgment surface)")
	var gAck := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345)
	gAck.player_skills.append("observe")
	gAck.bind_map_silent("street", Vector2i(16, 10))
	gAck.player_facing = Vector2i.DOWN  # faces sewer_grate (16,11)
	gAck.record_accomplishment("delivered_delivery_grate_phials")
	_events.clear()
	gAck.use_skill_field("observe")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "Rust holds the bars, not a lock. The phial crate you eased down the rungs is gone from the ledge below. Collected, unbroken. Somewhere down there, someone's working glass got to keep being glass."),
		"the grate's delivered observe override renders (the only ack surface its door_when leaves reachable)")

	# --- b7 #212: the bond-path rumor keys on the Tamer chain's entry
	# counter (no canonical fixture banks soothed_a_beast outside the tamer
	# loops, which pin other surfaces). ---
	var selys_row: Dictionary = (_load_json("res://data/maps/liscor/guild.json")["entities"] as Array).filter(func(e: Variant) -> bool: return String((e as Dictionary).get("id", "")) == "selys")[0]
	ack_counts.clear()
	ack_counts["soothed_a_beast"] = 1
	ack_soc.talk_pool_line(selys_row, {})
	assert(ack_lines[-1].begins_with("Word came up you looked in on that lame corusdeer."),
		"selys's wolf-pup signpost renders once the player has soothed a beast")
	ack_counts["pallass_sponsored"] = 1
	ack_soc.talk_pool_line(selys_row, {})
	assert(ack_lines[-1].begins_with("Krshia's stone, market row"),
		"an active story relay outranks the standing bond-path signpost")

	# --- b7 #214: skill-flavor trio's sim arms. (b) door_flavor fires on a
	# door-shaped target and only there; (c) the pond_edge item gate,
	# bank, and once-per-waking serve — the prop sits ON the pond's
	# water-wall cell (9,17), so the faced-cell interact from the bank is
	# exactly what a player does. ---
	var gFlav := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345)
	gFlav.player_skills.append("open_doors")
	gFlav.bind_map_silent("inn", Vector2i(14, 7))
	gFlav.player_facing = Vector2i.UP  # faces pantry_door (14,6)
	_events.clear()
	var flav_res: Dictionary = gFlav.use_skill_field("open_doors")
	assert(String(flav_res.get("door_flavored", "")) == "pantry_door", "open_doors on the pantry door takes the door_flavor arm")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "[Open Doors] — The door was not locked. It opens anyway, with tremendous ceremony, and somewhere the Skill feels appreciated."),
		"the pantry joke renders verbatim")
	gFlav.player_facing = Vector2i.DOWN  # (14,8): no door faced
	_events.clear()
	var flav_res2: Dictionary = gFlav.use_skill_field("open_doors")
	assert(String(flav_res2.get("ambient", "")) == "open_doors", "no door faced falls through to the shipped field_ambient line")
	gFlav.bind_map_silent("deep_tunnels", Vector2i(4, 4))
	gFlav.player_facing = Vector2i.RIGHT  # faces cold_hearth (5,4): a prop, NOT a door
	var flav_res3: Dictionary = gFlav.use_skill_field("open_doors")
	assert(String(flav_res3.get("ambient", "")) == "open_doors",
		"a non-door entity falls through to ambient (review M2: the door-shape predicate has teeth)")
	gFlav.bind_map_silent("inn", Vector2i(3, 7))
	gFlav.player_facing = Vector2i.DOWN  # faces garden_door (3,8): door_when gate UNMET, hidden pre-unlock
	_events.clear()
	var flav_res4: Dictionary = gFlav.use_skill_field("open_doors")
	assert(String(flav_res4.get("ambient", "")) == "open_doors",
		"a sealed/hidden door_when door never jokes or leaks (review M1: 'was not locked' must be true)")
	assert(not _events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]).begins_with("[Open Doors] — The door was not locked.")),
		"no joke toast on the hidden garden door")
	gFlav.record_accomplishment("garden_door_unlocked")
	var flav_res5: Dictionary = gFlav.use_skill_field("open_doors")
	assert(String(flav_res5.get("door_flavored", "")) == "garden_door",
		"the same door jokes once its gate is MET (openable = door)")

	var gFish := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345)
	gFish.bind_map_silent("floodplains", Vector2i(9, 16))
	gFish.player_facing = Vector2i.DOWN  # faces pond_edge (9,17)
	_events.clear()
	gFish.interact()
	assert(gFish.accomplishment_count("went_fishing") == 0, "bare hands bank nothing at the shallows")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]) == "Whatever's under there won't come to bare hands. Lism's shelf had a fisher's handline."),
		"the item hint points at the handline's one vendor")
	gFish.inventory.append("fishers_handline")
	_events.clear()
	gFish.interact()
	assert(gFish.accomplishment_count("went_fishing") == 1, "the handline banks the cast")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == "toast" and String(e["payload"]["text"]).begins_with("You pay out the line into the dark water.")),
		"the cast toast renders")
	assert(gFish.inventory.has("fishers_handline"), "the handline is a tool, never consumed")
	_events.clear()
	gFish.interact()
	assert(gFish.accomplishment_count("went_fishing") == 1, "once per waking: the second cast serves the spent toast, no re-bank")

	# --- GH#163 review MEDIUM: the tier LOCK must survive a rank shift ---
	var tier_cc: Dictionary = combat_config.duplicate(true)
	tier_cc["classes"] = _load_json("res://data/classes.json")
	tier_cc["bounties"] = _load_json("res://data/bounties.json")
	var gTier := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 7, tier_cc)
	gTier.classes["warrior"] = 10
	assert(WIProgression.power_rank(gTier.classes, tier_cc["classes"]) == "silver", "one L10 line ranks silver")
	gTier.accept_bounty("bounty_road_cull")
	assert(gTier.accepted_bounty_tier == "silver", "accept locks the CURRENT rank's tier")
	gTier.classes["mage"] = 10
	assert(WIProgression.power_rank(gTier.classes, tier_cc["classes"]) == "gold", "two L10 lines rank gold")
	var locked: Dictionary = gTier.accepted_bounty()
	assert(int(locked.get("gold", 0)) == 12 and int((locked.get("condition", {}) as Dictionary).get("won_combat", 0)) == 3,
		"mid-bounty rank-up keeps the SILVER condition and payout (the lock, not the live rank)")

	var gate_scene := {
		"start_map": "plaza",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: []},
		"maps": {"plaza": {
			"grid": {"width": 8, "height": 8},
			"blocked": [],
			"entities": [
				{WIKeys.ID: "gate_interact_only", WIKeys.KIND: "encounter", WIKeys.CELL: [2, 1],
				 WIKeys.DISPLAY_NAME: "Night Thing", "sprite": "",
				 "arena": "goblin_ambush", "enemies": ["training_dummy_a"], "allies": [],
				 "on_victory": "test_won_gate_interact",
				 "encounter_when": {"phase": ["night"]},
				 "gate_closed_toast": "Nothing there in daylight."},
				{WIKeys.ID: "gate_trigger_only", WIKeys.KIND: "encounter", WIKeys.CELL: [2, 5],
				 WIKeys.DISPLAY_NAME: "Night Thing", "sprite": "",
				 "arena": "goblin_ambush", "enemies": ["training_dummy_a"], "allies": [],
				 "on_victory": "test_won_gate_trigger",
				 "encounter_when": {"phase": ["night"]},
				 "trigger_radius": 1},
			],
		}},
	}
	var real_combat_config := {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"items": _load_json("res://data/items.json"),
	}
	var gGate := WIGame.new(gate_scene, skill_config, _sink, 7, real_combat_config, {"dusk_at": 2, "night_at": 3})

	assert(gGate.phase() == "day", "fixture starts at day")
	_events.clear()
	var gi_day := gGate.interact()
	assert(gi_day.is_empty(), "gate_interact_only refuses at day (interact returns empty)")
	assert(gGate.combat == null, "no combat starts through the closed gate")
	assert(_count("combat_started") == 0, "encounter_when refuses BEFORE start_combat -- no combat_started at day")
	assert(_toast_texts().has("Nothing there in daylight."), "the gate's own gate_closed_toast fires")
	assert(gGate.phase() == "day", "one interact tick is not enough to cross dusk_at 2")

	_events.clear()
	assert(gGate.move_player(Vector2i.DOWN), "step to (1,2)")
	assert(gGate.phase() == "dusk", "second tick crosses dusk_at 2")
	assert(gGate.combat == null, "dusk is not in encounter_when's phase set -- gate stays closed")
	assert(_count("combat_started") == 0, "no proximity trigger at dusk")

	assert(gGate.move_player(Vector2i.DOWN), "step to (1,3)")
	assert(gGate.phase() == "night", "third tick crosses night_at 3")
	assert(gGate.combat == null, "gate open, but still out of trigger_radius at (1,3)")
	_events.clear()
	assert(gGate.move_player(Vector2i.DOWN), "step to (1,4), adjacent to gate_trigger_only")
	assert(gGate.combat != null, "encounter_when OPEN at night -- proximity starts real combat")
	assert(_count("combat_started") == 1, "combat_started fires exactly once through the open gate")
	gGate.combat.apply_damage("training_dummy_a", 999, "pc", true)
	assert(gGate.combat.finished and gGate.combat.outcome["victory"], "the gate-opened fight resolves for real")
	gGate.resolve_combat()
	assert(gGate.accomplishment_count("test_won_gate_trigger") == 1, "on_victory banks through the gated encounter same as any other")

	gGate.player_cell = Vector2i(1, 1)
	gGate.player_facing = Vector2i.RIGHT
	_events.clear()
	var gi_night := gGate.interact()
	assert(gi_night.get("combat", false), "gate_interact_only now opens through interact() at night")
	assert(gGate.combat != null, "real combat fielded")
	gGate.combat.apply_damage("training_dummy_a", 999, "pc", true)
	gGate.resolve_combat()
	assert(gGate.accomplishment_count("test_won_gate_interact") == 1, "interact-site gate's on_victory banks too")

	var echo_scene := {
		"start_map": "village",
		"player": {WIKeys.CELL: [1, 1], "classes": {}, WIKeys.SKILLS: []},
		"maps": {
			"village": {
				"grid": {"width": 6, "height": 6}, "blocked": [],
				"entities": [
					{WIKeys.ID: "echo_villager", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "A Villager",
					 "talk_pool": [{"echo_of": "echo_witch"}]},
				],
			},
			"hollow": {
				"grid": {"width": 6, "height": 6}, "blocked": [],
				"entities": [
					{WIKeys.ID: "echo_witch", WIKeys.KIND: "npc", WIKeys.CELL: [2, 1], WIKeys.DISPLAY_NAME: "The Witch",
					 "talk_pool": ["Tea first.", "I don't ask twice.", "Manners, always."]},
				],
			},
		},
	}
	var gEcho := WIGame.new(echo_scene, skill_config, _sink, 7)

	_events.clear()
	var ev0 := gEcho.interact()
	assert(ev0.get("talked", "") == "echo_villager", "villager's pool interact resolves")
	assert(_last_dialogue_text() == "Tea first.", "echo_of resolves to the witch's CURRENT (index 0) line sight-unseen")
	assert(gEcho.accomplishment_count("chatted_with_echo_villager") == 1, "the villager's OWN counter still banks (dedup bookkeeping)")
	assert(gEcho.accomplishment_count("chatted_with_echo_witch") == 0, "talking to the ECHO never advances the WITCH's own counter")

	gEcho.sleep()
	gEcho.transition("hollow", Vector2i(1, 1))
	gEcho.player_facing = Vector2i.RIGHT
	_events.clear()
	var w0 := gEcho.interact()
	assert(w0.get("talked", "") == "echo_witch", "the witch's own pool interact resolves")
	assert(_last_dialogue_text() == "Tea first.", "the witch's own first line matches what the villager echoed earlier")
	assert(gEcho.accomplishment_count("chatted_with_echo_witch") == 1, "the witch's real counter now advances")

	gEcho.sleep()
	gEcho.transition("village", Vector2i(1, 1))
	gEcho.player_facing = Vector2i.RIGHT
	_events.clear()
	var ev1 := gEcho.interact()
	assert(_last_dialogue_text() == "I don't ask twice.", "the echo advances to the witch's NEW current line (index 1), un-driftable by construction")
	assert(gEcho.accomplishment_count("chatted_with_echo_villager") == 2, "the villager's own dedup counter still advances independently")

	var g_wage_base := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_wage_base.player_cell = Vector2i(10, 1)
	g_wage_base.player_facing = Vector2i.DOWN
	var gold_before_base := g_wage_base.gold
	g_wage_base.interact()
	assert(g_wage_base.gold == gold_before_base + 1, "serving_tray pays its base +1 gold wage without [Perfect Hospitality]")

	var g_wage_hosp := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_wage_hosp.player_skills = ["perfect_hospitality"]
	g_wage_hosp.player_cell = Vector2i(10, 1)
	g_wage_hosp.player_facing = Vector2i.DOWN
	var gold_before_hosp := g_wage_hosp.gold
	g_wage_hosp.interact()
	assert(g_wage_hosp.gold == gold_before_hosp + 2, "[Perfect Hospitality] bumps the SAME wage to +2 gold (the interact()-level hook)")

	var g_wage_cache := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_wage_cache.player_skills = ["perfect_hospitality"]
	g_wage_cache.transition("floodplains", Vector2i(2, 3))
	var cache_entity := g_wage_cache.find_entity("frozen_cache")
	assert(not cache_entity.is_empty(), "frozen_cache exists on floodplains")
	var cache_cell: Vector2i = cache_entity[WIKeys.CELL]
	g_wage_cache.player_cell = cache_cell + Vector2i.DOWN
	g_wage_cache.player_facing = Vector2i.UP
	var gold_before_cache := g_wage_cache.gold
	g_wage_cache.interact()
	assert(g_wage_cache.gold == gold_before_cache + 5, "frozen_cache's one-shot 5g find is UNCHANGED by [Perfect Hospitality] -- the hook never reaches a non-once_per_waking prop")

	# --- Wave D-1 (#155): use_skill's String|Array requires_item / remove_item seam ([True Synthesis] component consume) ---
	# A synthetic bench prop keeps this test independent of map placement. [True
	# Synthesis] is granted by holding [Alchemist] at its floor level (10). The gate
	# is all-or-nothing: every listed item must be carried, or nothing is consumed.
	var synth_bench := {
		"id": "synth_test_bench",
		"kind": "prop",
		"requires_item": ["solvent_phial", "mineral_salts"],
		"item_hint_toast": "You need both the solvent phial and the mineral salts.",
		"on_skill_use": {
			"accomplishment": "synthesized_draught",
			"item": "tonic_of_the_clear_eye",
			"remove_item": ["solvent_phial", "mineral_salts"],
			"toast": "[True Synthesis] test bench.",
		},
	}

	var g_synth_both := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_synth_both.classes["alchemist"] = 10
	assert(g_synth_both.known_skills().has("true_synthesis"), "[Alchemist] L10 grants [True Synthesis] into the known set")
	g_synth_both.entities["synth_test_bench"] = synth_bench.duplicate(true)
	g_synth_both.inventory.assign(["solvent_phial", "mineral_salts"])
	_events.clear()
	var r_both: Dictionary = g_synth_both.use_skill("true_synthesis", "synth_test_bench")
	assert(String(r_both.get("accomplishment", "")) == "synthesized_draught", "both-present: [True Synthesis] resolves the recipe")
	assert(not g_synth_both.inventory.has("solvent_phial"), "both-present: solvent_phial consumed")
	assert(not g_synth_both.inventory.has("mineral_salts"), "both-present: mineral_salts consumed")
	assert(g_synth_both.inventory.has("tonic_of_the_clear_eye"), "both-present: the tonic is produced")
	assert(_count("item_lost") == 2, "both-present: exactly two components removed, each once")
	assert(_count("item_gained") == 1 and _count("skill_used") == 1, "both-present: one product picked up, one skill fired")

	var g_synth_one := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_synth_one.classes["alchemist"] = 10
	g_synth_one.entities["synth_test_bench"] = synth_bench.duplicate(true)
	g_synth_one.inventory.assign(["solvent_phial"])
	_events.clear()
	var r_one: Dictionary = g_synth_one.use_skill("true_synthesis", "synth_test_bench")
	assert(String(r_one.get("item_hint", "")) == "mineral_salts", "one-missing: the item-hint names the missing component")
	assert(g_synth_one.inventory.size() == 1 and g_synth_one.inventory.has("solvent_phial"), "one-missing: ALL-OR-NOTHING -- the held component is NOT consumed")
	assert(not g_synth_one.inventory.has("tonic_of_the_clear_eye"), "one-missing: no product")
	assert(_count("item_lost") == 0 and _count("skill_used") == 0, "one-missing: nothing removed, skill never fired")

	var g_synth_none := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_synth_none.classes["alchemist"] = 10
	g_synth_none.entities["synth_test_bench"] = synth_bench.duplicate(true)
	g_synth_none.inventory.clear()
	_events.clear()
	var r_none: Dictionary = g_synth_none.use_skill("true_synthesis", "synth_test_bench")
	assert(String(r_none.get("item_hint", "")) == "solvent_phial", "none-present: the item-hint names the first missing component")
	assert(g_synth_none.inventory.is_empty(), "none-present: nothing produced or consumed")
	assert(_count("item_lost") == 0 and _count("skill_used") == 0, "none-present: nothing removed, skill never fired")

	# GH#155 review M1: dup-output guard -- holding the recipe's output must
	# refuse BEFORE consuming components (inventory never stacks; the old path
	# ate both reagents behind a success toast).
	var g_synth_dup := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_synth_dup.classes["alchemist"] = 10
	g_synth_dup.entities["synth_test_bench"] = synth_bench.duplicate(true)
	g_synth_dup.inventory.clear()
	g_synth_dup.inventory.append_array(["tonic_of_the_clear_eye", "solvent_phial", "mineral_salts"])
	_events.clear()
	var r_dup: Dictionary = g_synth_dup.use_skill("true_synthesis", "synth_test_bench")
	assert(String(r_dup.get("blocked_duplicate", "")) == "tonic_of_the_clear_eye", "dup-output: refusal names the held output")
	assert(g_synth_dup.inventory.has("solvent_phial") and g_synth_dup.inventory.has("mineral_salts"), "dup-output: components NOT consumed")
	assert(_count("item_lost") == 0 and _count("skill_used") == 0 and _count("accomplishment_recorded") == 0, "dup-output: no state changes at all")

	# --- GH#165: [Perfect Reduction] recipe bench (lane deviation B, wired by controller) ---
	var g_reduce := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_reduce.classes["alchemist"] = 14
	assert(g_reduce.known_skills().has("perfect_reduction"), "[Alchemist] L14 grants [Perfect Reduction]")
	g_reduce.transition("pallass_market", Vector2i(4, 8))
	g_reduce.inventory.append("crude_draught")
	_events.clear()
	var r_reduce: Dictionary = g_reduce.use_skill("perfect_reduction", "alchemy_bench_reduction")
	assert(String(r_reduce.get("item", "")) == "tonic_of_the_clear_eye", "reduction yields the tonic")
	assert(not g_reduce.inventory.has("crude_draught"), "reduction consumes the crude draught")
	assert(g_reduce.inventory.has("tonic_of_the_clear_eye"), "the tonic lands in the pack")
	assert(g_reduce.accomplishment_count("synthesized_draught") == 1, "the cast banks synthesized_draught")

	# --- GH#165 review F2: execute the two new seams the sim never walks ---
	var g_pepper := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_pepper.player_skills.append("flarepepper_supplies")
	g_pepper.sleep()
	assert(g_pepper.inventory.has("flarepepper_powder"), "[Supplies] restocks one flarepepper at sleep")
	g_pepper.sleep()
	assert(g_pepper.inventory.count("flarepepper_powder") == 1, "restock never stacks a held powder")
	g_pepper.inventory.erase("flarepepper_powder")
	g_pepper.sleep()
	assert(g_pepper.inventory.has("flarepepper_powder"), "restock returns after the powder is spent")
	var g_no_pepper := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_no_pepper.sleep()
	assert(not g_no_pepper.inventory.has("flarepepper_powder"), "no skill, no restock")

	# --- GH#142: dialogue swap unequips first (the pay-and-keep-both exploit) ---
	var cc_ench: Dictionary = combat_config.duplicate(true)
	cc_ench["dialogue"] = {"hedault_enchanting": _load_json("res://data/dialogue/hedault_enchanting.json")}
	var g_ench := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, cc_ench)
	g_ench.transition("mercantile_alleys", Vector2i(3, 7))
	g_ench.gold = 40
	g_ench.inventory.append("hunters_fang_talisman")
	g_ench.equipped["accessory_1"] = "hunters_fang_talisman"
	g_ench.player_facing = Vector2i.UP
	assert(g_ench.start_dialogue("hedault_enchanting", "hedault"), "hedault conversation opens")
	g_ench.dialogue_choose(1)
	assert(g_ench.gold == 5, "enchant fee paid")
	assert(not g_ench.inventory.has("hunters_fang_talisman"), "EQUIPPED base still consumed (unequip-then-remove)")
	assert(g_ench.inventory.has("hedaults_hunters_fang"), "variant granted")
	assert(String(g_ench.equipped.get("accessory_1", "")) == "", "the dangling equip slot is cleared")

	# --- GH#185: widened entrance surfaces (facade + gate flanks) ---
	var g_ent := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_ent.transition("floodplains", Vector2i(6, 6))
	g_ent.player_facing = Vector2i.UP
	g_ent.interact()
	assert(g_ent.current_map == "inn", "interacting at the WEST facade cell enters the inn (GH#185)")
	var g_gate := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, combat_config)
	g_gate.transition("floodplains", Vector2i(32, 24))
	g_gate.player_facing = Vector2i.DOWN
	g_gate.interact()
	assert(g_gate.current_map == "street", "the gate's east flank enters Liscor")
	assert(g_gate.accomplishment_count("reached_liscor") == 1, "flank entry banks reached_liscor")

	# #148 Tier 3: map-level arrival_toasts re-orientation (armed / retired / unmet + first-satisfied-wins).
	# Placed last: each fresh WIGame emits sim_initialized, so this must run after the
	# _count("sim_initialized") == 1 assertion above.
	var arrival_game := WIGame.new(scene_config, skill_config, _sink, 4242)
	_events.clear()
	arrival_game.transition("ruin_surface", Vector2i(17, 5))
	assert(not _toast_texts().any(func(t: String) -> bool: return t.contains("this is the ruin")),
		"ruin_surface arrival toast stays silent until door_understood is banked")
	arrival_game.record_accomplishment("door_understood")
	_events.clear()
	arrival_game.transition("inn", Vector2i(2, 3))
	arrival_game.transition("ruin_surface", Vector2i(17, 5))
	assert(_toast_texts().any(func(t: String) -> bool: return t == "East past the gate road — this is the ruin. The pedestal Pisces described is deeper in."),
		"ruin_surface arrival toast fires when door_understood met and recovered_anchor_stone unmet")
	arrival_game.record_accomplishment("recovered_anchor_stone")
	_events.clear()
	arrival_game.transition("inn", Vector2i(2, 3))
	arrival_game.transition("ruin_surface", Vector2i(17, 5))
	assert(not _toast_texts().any(func(t: String) -> bool: return t.contains("this is the ruin")),
		"ruin_surface arrival toast retires once recovered_anchor_stone is banked (hide_when)")
	var dungeon_game := WIGame.new(scene_config, skill_config, _sink, 4243)
	dungeon_game.record_accomplishment("heard_the_deep_tremor")
	_events.clear()
	dungeon_game.transition("dungeon_approach", Vector2i(8, 10))
	assert(_toast_texts().any(func(t: String) -> bool: return t == "The fissure Zevara spoke of is down past the gallery. The dark has a direction today."),
		"dungeon_approach arrival toast fires on heard_the_deep_tremor")
	dungeon_game.record_accomplishment("cleared_the_warren")
	_events.clear()
	dungeon_game.transition("inn", Vector2i(2, 3))
	dungeon_game.transition("dungeon_approach", Vector2i(8, 10))
	assert(not _toast_texts().any(func(t: String) -> bool: return t.contains("fissure Zevara spoke of")),
		"dungeon_approach arrival toast retires once cleared_the_warren is banked (hide_when)")
	var fsw_config := WISceneCatalog.compose()
	(fsw_config["maps"]["ruin_surface"] as Dictionary)["arrival_toasts"] = [
		{"requires": {"door_understood": 1}, "text": "FIRST"},
		{"requires": {"door_understood": 1}, "text": "SECOND"},
	]
	var fsw_game := WIGame.new(fsw_config, skill_config, _sink, 4244)
	fsw_game.record_accomplishment("door_understood")
	_events.clear()
	fsw_game.transition("ruin_surface", Vector2i(17, 5))
	var fsw_toasts := _toast_texts()
	assert(fsw_toasts.has("FIRST") and not fsw_toasts.has("SECOND"),
		"arrival_toasts is first-satisfied-wins: only the earliest matching entry emits")

	print("PASS: sim core behaves correctly")
	quit(0)


func _check_chronicle_facts(scene_config: Dictionary, skill_config: Dictionary) -> void:
	var chronicle_config := {
		"classes": {"classes": [
			{WIKeys.ID: "mage", WIKeys.DISPLAY_NAME: "Mage"},
			{WIKeys.ID: "warrior", WIKeys.DISPLAY_NAME: "Warrior"},
			{WIKeys.ID: "helper", WIKeys.DISPLAY_NAME: "Helper"},
		]},
		"quests": {"quests": [
			{WIKeys.ID: "done_a", "beats": [{"description": "Done A", "complete_when": {"beat_a": 1}}]},
			{WIKeys.ID: "unfinished", "beats": [{"description": "Pending", "complete_when": {"beat_pending": 1}}]},
			{WIKeys.ID: "done_b", "beats": [{"description": "Done B", "complete_when": {"beat_b": 1}}]},
		]},
		"acts": _load_json("res://data/acts.json"),
	}
	var chronicle := WIGame.new(scene_config, skill_config, func(_type: String, _payload: Dictionary) -> void: pass, 91, chronicle_config, {}, {
		"pc_name": "  Sella  ", "pc_race": "drake",
	})
	chronicle.classes = {"helper": 2, "mage": 4}
	chronicle.started_quests.assign(["done_a", "unfinished", "done_b", "missing_quest"])
	chronicle.accomplishments = {"beat_a": 1, "beat_b": 1, "victories": 7}
	chronicle.times_slept = 5

	var facts: Dictionary = chronicle.chronicle_facts()
	var keys: Array = facts.keys()
	keys.sort()
	assert(keys == ["classes", "ending", "name", "quests_completed", "race", "schema", "sleeps", "victories"],
		"Chronicle schema must contain only the ratified result-fact fields")
	assert(int(facts["schema"]) == 1, "Chronicle schema version must be 1")
	assert(facts["name"] == "Sella" and facts["race"] == "Drake",
		"Chronicle identity must use sanitized name and title-cased race")
	assert(facts["classes"] == [{"name": "Mage", "level": 4}, {"name": "Helper", "level": 2}],
		"Chronicle classes must use display names and class-catalog order")
	assert(int(facts["quests_completed"]) == 2,
		"Chronicle counts completed authored quests only")
	assert(int(facts["victories"]) == 7 and int(facts["sleeps"]) == 5,
		"Chronicle reports achieved combat victories and sleeps")
	assert(facts["ending"] == "The seal holds. Liscor counts you among its own.",
		"Chronicle ending must remain exact")
