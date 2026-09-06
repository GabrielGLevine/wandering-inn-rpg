extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var config := _combat_config()
	var game := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 9, config)
	var fixture := _load_json("res://qa/fixtures/near_riverfarm.json")
	assert(WISave.apply(game, fixture), "near_riverfarm must load")
	_assert_class_requirements_reachable(game, config["classes"])
	var facts := game.chronicle_facts()
	assert(int(facts["victories"]) == 4, "Chronicle must read the universal victory count")

	var custom_config: Dictionary = config.duplicate(true)
	for act: Dictionary in custom_config["acts"]["acts"]:
		for beat: Dictionary in act.get("beats", []):
			if String(beat.get("id", "")) == "counted_among":
				beat["text"] = "Catalog-owned ending."
	var custom_game := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 9, custom_config)
	assert(WISave.apply(custom_game, fixture), "near_riverfarm must load against a customized acts catalog")
	assert(String(custom_game.chronicle_facts()["ending"]) == "Catalog-owned ending.",
		"Chronicle ending must derive from acts.counted_among (act_iv since the 2026-07-26 reframe; was act_iii.seal_holds)")

	var victory_game := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 9, config)
	victory_game.classes = {"warrior": 5}
	victory_game.transition("floodplains", Vector2i(27, 18))
	assert(victory_game.start_combat("goblin_encounter_2"), "array-on_victory encounter must start")
	victory_game.combat.apply_damage("goblin_raider", 999, "pc", true)
	victory_game.combat.apply_damage("goblin_shaman", 999, "pc", true)
	assert(victory_game.combat.finished and victory_game.combat.outcome["victory"], "forced combat must end in victory")
	victory_game.resolve_combat()
	assert(victory_game.accomplishment_count("victories") == 1,
		"one victory must bank exactly one universal count despite multiple on_victory ids")
	print("PASS: Chronicle derives universal victories and its ending from the acts catalog")
	quit(0)


func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {},
		"quests": _load_json("res://data/quests.json"),
		"acts": _load_json("res://data/acts.json"),
		"items": _load_json("res://data/items.json"),
	}


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON: " + path)
	return parsed


func _assert_class_requirements_reachable(game: WIGame, catalog: Dictionary) -> void:
	for cls: Dictionary in catalog.get("classes", []):
		var class_id := String(cls.get("id", ""))
		if not game.classes.has(class_id):
			continue
		var gained_by: Dictionary = cls.get("gained_by", {}).get("accomplishment", {})
		for counter: String in gained_by:
			assert(game.accomplishment_count(counter) >= int(gained_by[counter]),
				"near_riverfarm held class %s must satisfy gained_by.%s" % [class_id, counter])
		# #477: the any arm is met by ANY one key clearing its threshold.
		var any_arm: Dictionary = cls.get("gained_by", {}).get("accomplishment_any", {})
		if not any_arm.is_empty():
			var any_met := false
			for counter: String in any_arm:
				if game.accomplishment_count(counter) >= int(any_arm[counter]):
					any_met = true
			assert(any_met, "near_riverfarm held class %s must satisfy one gained_by.accomplishment_any key" % class_id)
		for level_row: Dictionary in cls.get("levels", []):
			if int(level_row.get("level", 0)) > int(game.classes[class_id]):
				continue
			for counter: String in level_row.get("requires", {}):
				assert(game.accomplishment_count(counter) >= int(level_row["requires"][counter]),
					"near_riverfarm %s level %d must satisfy %s" % [class_id, int(level_row["level"]), counter])


func _sink(_type: String, _payload: Dictionary) -> void:
	pass
