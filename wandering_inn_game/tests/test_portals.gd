extends SceneTree

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {},
		"quests": _load_json("res://data/quests.json"),
		"items": _load_json("res://data/items.json"),
		"portals": _load_json("res://data/portals.json"),
	}


func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, _combat_config())


func _bank_beat3(game: WIGame) -> void:
	game.record_accomplishment("door_understood")
	game.record_accomplishment("recovered_anchor_stone")
	game.record_accomplishment("bought_catalyst")


func _init() -> void:
	WITestWatchdog.arm(self)

	var rows: Array = [
		{"id": "a", "display_name": "Destination A", "map": "inn", "cell": [1, 1], "requires_accomplishment": "flag_a"},
		{"id": "b", "display_name": "Destination B", "map": "street", "cell": [2, 2], "requires_accomplishment": "flag_b"},
		{"id": "c", "display_name": "Destination C", "map": "guild", "cell": [3, 3]},
	]
	var counts := {"flag_a": 1, "flag_b": 0}
	var counter_cb := func(id: String) -> int: return int(counts.get(id, 0))
	var attuned: Array = WIPortals.attuned_destinations(rows, counter_cb)
	assert(attuned.size() == 2, "attuned_destinations: met gate (a) + gate-less row (c) pass, unmet gate (b) is excluded")
	var attuned_ids: Array = attuned.map(func(r: Dictionary) -> String: return String(r["id"]))
	assert(attuned_ids.has("a") and attuned_ids.has("c") and not attuned_ids.has("b"), "attuned_destinations: exact set")
	counts["flag_b"] = 1
	assert(WIPortals.attuned_destinations(rows, counter_cb).size() == 3, "attuned_destinations: raising the gate re-includes the row")

	var graph: Dictionary = WIPortals.build_portal_graph(attuned, "inn")
	var hub: Dictionary = (graph["nodes"] as Dictionary)[String(graph["start"])]
	var opts: Array = hub["options"]
	assert(opts.size() == 2, "build_portal_graph: attuned {a (inn), c (guild)} minus the CURRENT map (a) leaves 1 real option (c) + 'Let it be.'")
	var never_mind_present := false
	for o: Dictionary in opts:
		if not o.has("effects"):
			never_mind_present = true
			assert(bool(o.get("end", false)), "the fallback option always ends the conversation")
	assert(never_mind_present, "build_portal_graph always ships an effect-less 'Let it be.' fallback")
	for o: Dictionary in opts:
		if o.has("effects"):
			assert(bool(o.get("end", false)), "every travel option is conversation-ending (the O2 rule: deferred, resolved via transition() only)")
			assert(String((o["effects"] as Array)[0].get("travel_to", "")) == "c", "the surviving option travels to the non-inn destination (c)")

	var empty_graph: Dictionary = WIPortals.build_portal_graph([], "inn")
	var empty_opts: Array = ((empty_graph["nodes"] as Dictionary)[String(empty_graph["start"])] as Dictionary)["options"]
	assert(empty_opts.size() == 1, "zero attuned destinations still yields a valid one-option (fallback-only) graph, never empty options")

	assert(String(WIPortals.destination_by_id(rows, "b")["map"]) == "street", "destination_by_id finds a row by id")
	assert(WIPortals.destination_by_id(rows, "nonexistent").is_empty(), "destination_by_id returns {} for an unknown id")

	var game := _new_game()
	game.record_accomplishment("door_understood")
	game.record_accomplishment("bought_catalyst")
	game.sleep()
	assert(game.door_study_sleeps() == 0, "a sleep with only 2 of 3 beat-3 counters banked does not advance door_study_sleeps")
	assert(game.accomplishment_count("door_awakened") == 0, "door_awakened has not banked")

	game.record_accomplishment("recovered_anchor_stone")
	game.sleep()
	assert(game.door_study_sleeps() == 1, "the first sleep after all 3 beat-3 counters land advances door_study_sleeps to 1")
	assert(game.accomplishment_count("door_awakened") == 0, "not yet awakened at N=1")

	game.sleep()
	assert(game.door_study_sleeps() == 2, "a second qualifying sleep advances to 2")
	assert(game.accomplishment_count("door_awakened") == 0, "not yet awakened at N=2")

	_events.clear()
	game.sleep()
	assert(game.door_study_sleeps() == 3, "the third qualifying sleep advances to 3")
	assert(game.accomplishment_count("door_awakened") == 1, "N=3 banks door_awakened")
	var awakened_events: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "accomplishment_recorded" and String(e["payload"].get("id", "")) == "door_awakened")
	assert(awakened_events.size() == 1, "door_awakened fires accomplishment_recorded exactly once (the sleep_veil.gd GDI-line hook's own trigger)")

	game.sleep()
	assert(game.door_study_sleeps() == 3, "door_study_sleeps stops advancing once door_awakened is banked")
	assert(game.accomplishment_count("door_awakened") == 1, "door_awakened stays banked exactly once")

	var door2_game := _new_game()
	_bank_beat3(door2_game)
	door2_game.sleep()
	door2_game.sleep()
	door2_game.sleep()
	assert(door2_game.accomplishment_count("door_awakened") == 1, "sanity: door_awakened banked (3 qualifying sleeps)")

	door2_game.record_accomplishment("heard_pisces_second_door")
	door2_game.sleep()
	assert(door2_game.second_door_study_sleeps() == 1, "the first sleep after heard_pisces_second_door (door_awakened already banked) advances second_door_study_sleeps to 1")
	assert(door2_game.accomplishment_count("dungeon_attuned") == 0, "not yet attuned at N=1")

	door2_game.sleep()
	assert(door2_game.second_door_study_sleeps() == 2, "a second qualifying sleep advances to 2")
	assert(door2_game.accomplishment_count("dungeon_attuned") == 1, "N=2 banks dungeon_attuned")

	door2_game.sleep()
	assert(door2_game.second_door_study_sleeps() == 2, "second_door_study_sleeps stops advancing once dungeon_attuned is banked")

	var door2_gate_game := _new_game()
	door2_gate_game.record_accomplishment("heard_pisces_second_door")
	door2_gate_game.sleep()
	assert(door2_gate_game.second_door_study_sleeps() == 0, "second_door_study_sleeps never advances before door_awakened is banked")

	var dest_ids: Array = door2_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(dest_ids.has("dungeon_depths"), "dungeon_depths lists once dungeon_attuned is banked")
	var fresh_dest_ids: Array = _new_game().attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(not fresh_dest_ids.has("dungeon_depths"), "dungeon_depths stays gate-locked on a fresh game")
	door2_game._travel_to_portal("dungeon_depths")
	assert(door2_game.current_map == "dungeon_approach", "travel to the dungeon anchor lands on dungeon_approach")
	assert(door2_game.player_cell == Vector2i(2, 6), "travel lands on the portals.json-authored arrival cell")

	var attuned_ids2: Array = game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(attuned_ids2.has("liscor_street") and attuned_ids2.has("the_wandering_inn"), "both portals.json rows are attuned once door_awakened is banked")

	game.bind_map_silent("inn", Vector2i(13, 6))
	game.player_facing = Vector2i.RIGHT
	_events.clear()
	var result := game.interact()
	assert(result.get("dialogue", false), "interacting with the awakened pantry_door opens the portal menu, not the flavor toast")
	var started: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "dialogue_started")
	assert(started.size() == 1 and String(started[0]["payload"].get("conversation", "")) == "portal_menu", "the code-built graph is labeled 'portal_menu'")
	var menu_options: Array = game.dialogue.current_options()
	assert(menu_options.size() == 2, "from the inn, the menu offers ONLY the street destination + 'Let it be.' (the_wandering_inn is excluded: you're already there)")

	_events.clear()
	assert(game.dialogue_choose(0), "picking the (only) real destination succeeds")
	assert(game.current_map == "street", "transition() landed the PC on the street")
	assert(game.player_cell == Vector2i(29, 10), "transition() landed the PC on the portals.json-authored arrival cell")
	var map_changed: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "map_changed")
	assert(map_changed.size() == 1 and String(map_changed[0]["payload"].get("map", "")) == "street", "map_changed fired exactly once, to street")
	for e: Dictionary in _events:
		assert(String(e["type"]) not in ["player_moved", "player_blocked", "combat_started"], "no move/trigger/combat event fires on a portal arrival (O2 rule): saw %s" % String(e["type"]))

	game.bind_map_silent("street", Vector2i(29, 10))
	game.player_facing = Vector2i.RIGHT
	game.interact()
	var return_options: Array = game.dialogue.current_options()
	assert(return_options.size() == 2, "from the street, the menu offers ONLY the inn destination + 'Let it be.'")
	assert(game.dialogue_choose(0), "picking the inn destination succeeds")
	assert(game.current_map == "inn", "the return trip lands back on the inn")
	assert(game.player_cell == Vector2i(13, 6), "the return trip lands on the inn's authored arrival cell")

	var fresh := _new_game()
	fresh.bind_map_silent("inn", Vector2i(13, 6))
	fresh.player_facing = Vector2i.RIGHT
	var fresh_result := fresh.interact()
	assert(fresh_result.get("accomplishment", "") == "observed_the_pantry_door", "before door_awakened, pantry_door still falls through to its plain flavor toast, not the portal menu")

	var partial := _new_game()
	_bank_beat3(partial)
	partial.sleep()
	partial.sleep()
	assert(partial.door_study_sleeps() == 2, "sanity: 2 qualifying sleeps banked before serializing")
	var data := WISave.serialize(partial)
	var restored := _new_game()
	assert(WISave.apply(restored, data), "save with a partial door_study_sleeps count applies")
	assert(restored.door_study_sleeps() == 2, "door_study_sleeps round-trips through the ordinary accomplishments save path")
	assert(restored.accomplishment_count("door_awakened") == 0, "door_awakened has NOT banked yet on the restored save (only 2 of 3 sleeps taken)")

	var fwd_rows: Array = [
		{"id": "real_dest", "display_name": "Real", "map": "inn", "cell": [1, 1]},
		{"id": "ghost_dest", "display_name": "Ghost", "map": "map_not_landed_yet", "cell": [10, 10]},
	]
	var fwd_counter := func(_id: String) -> int: return 1
	var fwd_has_map := func(map_id: String) -> bool: return map_id == "inn"
	var fwd_attuned: Array = WIPortals.attuned_destinations(fwd_rows, fwd_counter, fwd_has_map)
	assert(fwd_attuned.size() == 1 and String(fwd_attuned[0]["id"]) == "real_dest", "attuned_destinations excludes a row whose map doesn't exist, even with its gate met")
	assert(WIPortals.attuned_destinations(fwd_rows, fwd_counter).size() == 2, "an omitted has_map_cb (bare pure-unit caller) skips the map-existence filter -- both rows pass")
	var fwd_game := _new_game()
	assert(not fwd_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])).has("pallass"), "sanity: pallass stays gate-locked without pallass_attuned")
	fwd_game.record_accomplishment("pallass_attuned")
	assert(fwd_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])).has("pallass"), "the once-forward-referenced pallass row lists normally now its map exists (the guard's zero-further-wiring payoff)")
	fwd_game._travel_to_portal("pallass")
	assert(fwd_game.current_map == "pallass_market", "travel to the now-landed map succeeds through the same guard")

	print("PASS: WIPortals gating/graph construction + the study-sleeps hook (both the door and its second-door mirror) + portal-menu travel (the O2 rule) + the forward-referenced-row map guard")
	quit(0)
