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
		"quests": {"quests": []},
		"items": _load_json("res://data/items.json"),
	}


func _new_game() -> WIGame:
	var g := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 4242, _combat_config())
	g.player_skills.append("frost_touch")
	g.player_skills.append("kindle")
	return g


func _has_event(type: String) -> bool:
	for e: Dictionary in _events:
		if String(e["type"]) == type:
			return true
	return false


func _last_event(type: String) -> Dictionary:
	for i in range(_events.size() - 1, -1, -1):
		if String(_events[i]["type"]) == type:
			return _events[i]["payload"]
	return {}


func _init() -> void:
	WITestWatchdog.arm(self)

	var g := _new_game()
	g.transition("sewers", Vector2i(3, 4))
	g.player_facing = Vector2i.DOWN  # faces (3,5)
	assert(g.is_cell_blocked(Vector2i(3, 5)), "the freezable channel cell is impassable water before freezing")
	_events.clear()
	var freeze_result := g.use_skill_field("frost_touch")
	assert(freeze_result.get("frozen", []) == [3, 5], "frost_touch reports the frozen cell")
	assert(not g.is_cell_blocked(Vector2i(3, 5)), "the frozen cell is walkable after freezing (walkability flip)")
	assert(_has_event("terrain_changed"), "freeze emits terrain_changed")
	var tc := _last_event("terrain_changed")
	assert(String(tc.get("to", "")) == "ice" and tc.get("cell", []) == [3, 5] and String(tc.get("map", "")) == "sewers", "terrain_changed carries {map:sewers, cell:[3,5], to:ice}")
	assert(_has_event("skill_used"), "freeze emits skill_used (journal reveal)")
	assert(g.used_skills.has("frost_touch"), "frost_touch is marked used")
	assert(g.move_player(Vector2i.DOWN), "the PC crosses onto the frozen cell")
	assert(g.player_cell == Vector2i(3, 5), "the PC stands on the ice")

	g.player_cell = Vector2i(3, 4)
	g.player_facing = Vector2i.DOWN
	_events.clear()
	var refreeze := g.use_skill_field("frost_touch")
	assert(not refreeze.has("frozen"), "re-freezing an already-frozen cell falls through (no second freeze)")
	assert(not _has_event("terrain_changed"), "re-freeze emits no terrain_changed")

	g.sleep()
	assert(g.frozen_cells.is_empty(), "sleep thaws every frozen cell")
	assert(g.is_cell_blocked(Vector2i(3, 5)), "the thawed cell is impassable water again")

	var g2 := _new_game()
	g2.transition("sewers", Vector2i(2, 3))
	g2.player_facing = Vector2i.UP  # faces (2,2), open floor, not freezable
	_events.clear()
	var inert := g2.use_skill_field("frost_touch")
	assert(inert.get("ambient", "") == "frost_touch", "frost on a non-freezable cell falls through to field_ambient")
	assert(g2.frozen_cells.is_empty(), "no cell was frozen by the ambient cast")
	assert(not _has_event("terrain_changed"), "an ambient frost cast emits no terrain_changed")

	var g3 := _new_game()
	g3.transition("sewers", Vector2i(2, 2))
	g3.player_facing = Vector2i.LEFT  # faces (1,2) = the debris
	assert(g3.is_cell_blocked(Vector2i(1, 2)), "the burnable debris blocks its cell before burning")
	assert(not g3.find_entity("sewer_debris").is_empty(), "the debris exists before burning")
	_events.clear()
	var burn_result := g3.use_skill_field("kindle")
	assert(burn_result.get("burned", "") == "sewer_debris", "kindle reports the burned prop")
	assert(g3.find_entity("sewer_debris").is_empty(), "the burned prop is gone from the map")
	assert(g3.removed_entities.has("sewer_debris"), "the burned prop is recorded removed (permanence)")
	assert(not g3.is_cell_blocked(Vector2i(1, 2)), "the vacated cell is walkable after burning")
	assert(int(g3.accomplishments.get("burned_the_debris", 0)) == 1, "burning banks the opaque debris counter")
	assert(_has_event("entity_removed"), "burn emits entity_removed")
	var bc := _last_event("terrain_changed")
	assert(String(bc.get("to", "")) == "scorched" and bc.get("cell", []) == [1, 2], "burn emits terrain_changed{to:scorched, cell:[1,2]}")
	assert(g3.used_skills.has("kindle"), "kindle is marked used")
	g3.sleep()
	assert(g3.find_entity("sewer_debris").is_empty(), "the burned prop stays gone after sleep")

	var g4 := _new_game()
	g4.transition("sewers", Vector2i(5, 2))
	g4.player_facing = Vector2i.DOWN  # faces (5,3) = the marker
	_events.clear()
	var no_burn := g4.use_skill_field("kindle")
	assert(no_burn.get("ambient", "") == "kindle", "kindle on a non-burnable prop falls through to field_ambient")
	assert(not g4.find_entity("drainage_marker").is_empty(), "a non-burnable prop is never destroyed (quest-prop safety)")
	assert(not g4.removed_entities.has("drainage_marker"), "the non-burnable prop is not recorded removed")

	var g5 := _new_game()
	g5.transition("sewers", Vector2i(3, 4))
	g5.player_facing = Vector2i.DOWN
	g5.use_skill_field("frost_touch")  # freeze (3,5)
	g5.player_cell = Vector2i(3, 8)
	g5.player_facing = Vector2i.DOWN
	g5.use_skill_field("frost_touch")  # freeze (3,9) too
	assert((g5.frozen_cells["sewers"] as Dictionary).size() == 2, "two sewers cells frozen before save")
	var data := WISave.serialize(g5)
	assert(data["state"].has("frozen_cells"), "frozen_cells is serialized")

	var restored := _new_game()
	_events.clear()
	assert(WISave.apply(restored, data), "a save carrying frozen ice applies")
	assert(_events.is_empty(), "apply emits nothing")
	assert(restored.current_map == "sewers", "current_map restored to sewers")
	assert((restored.frozen_cells.get("sewers", {}) as Dictionary).size() == 2, "both frozen cells restored")
	assert(not restored.is_cell_blocked(Vector2i(3, 5)), "restored ice is walkable at (3,5)")
	assert(not restored.is_cell_blocked(Vector2i(3, 9)), "restored ice is walkable at (3,9)")

	var no_ice: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_ice.erase("frozen_cells")
	var ice_target := _new_game()
	assert(WISave.apply(ice_target, {"version": WISave.VERSION, "state": no_ice}), "a save without frozen_cells still applies")
	assert(ice_target.frozen_cells.is_empty(), "absent frozen_cells defaults to an empty set")
	var bad_ice: Dictionary = (data["state"] as Dictionary).duplicate(true)
	bad_ice["frozen_cells"] = "solid"
	assert(not WISave.apply(_new_game(), {"version": WISave.VERSION, "state": bad_ice}), "non-Dictionary frozen_cells rejected")

	print("PASS: freezable-water + burnable-prop traversal seams round-trip")
	quit(0)
