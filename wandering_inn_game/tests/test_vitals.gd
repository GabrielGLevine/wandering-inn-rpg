extends SceneTree

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload.duplicate(true)})


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 37, {
		"combatants": _load("res://data/combatants.json"),
		"classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"),
		"items": _load("res://data/items.json"),
	})


func _init() -> void:
	WITestWatchdog.arm(self)
	_check_maxima_and_equipment()
	_check_sleep()
	_check_saves()
	_check_live_projection_and_staging()
	print("PASS test_vitals")
	quit(0)


func _check_maxima_and_equipment() -> void:
	var game := _new_game()
	var base := game.player_resource_maxima()
	assert(game.vitals.hp == int(base[WIKeys.MAX_HP]) and game.vitals.mp == 0, "new noncaster starts full with no MP")
	game.vitals.hp = 7
	assert(game.pickup("leather_jerkin", "test"))
	assert(game.equip("leather_jerkin"))
	assert(int(game.player_resources()[WIKeys.MAX_HP]) == int(base[WIKeys.MAX_HP]) + 4, "armor contributes to the shared maximum")
	assert(game.vitals.hp == 7, "larger maximum cannot heal")
	game.vitals.hp = int(game.player_resources()[WIKeys.MAX_HP])
	assert(game.unequip("armor"))
	assert(game.vitals.hp == int(base[WIKeys.MAX_HP]), "smaller maximum clamps immediately")
	assert(game.equip("leather_jerkin"))
	assert(game.vitals.hp == int(base[WIKeys.MAX_HP]), "equip toggle cannot restore the lost four HP")
	game.well_fed = true
	game.record_accomplishment("room_tier_1")
	assert(int(game.player_resources()[WIKeys.MAX_HP]) == int(base[WIKeys.MAX_HP]) + 7, "armor, waking food and room stack in maxima")
	game.pending_meal = {WIKeys.HP_MOD: 2, WIKeys.DAMAGE_MOD: 1}
	var before := game.pending_meal.duplicate(true)
	var maxima := game.player_resource_maxima()
	assert(game.pending_meal == before, "preview cannot consume armed preparation")
	assert(int(maxima[WIKeys.MAX_HP]) == int(base[WIKeys.MAX_HP]) + 7, "next-fight preparation is not an active world maximum")
	var templates: Array = game._combat_config["combatants"]["combatants"]
	var pc: Dictionary = templates.filter(func(c: Dictionary) -> bool: return String(c[WIKeys.ID]) == "pc")[0]
	game.classes = {"warrior": 4, "mage": 3}
	var cfg := game._player_combatant_config(pc)
	var arena := {"id": "resources", "grid": {"width": 3, "height": 3}, "player_spawns": [[0, 0]], "enemy_spawns": [[2, 2]]}
	var fight := WICombat.new(arena, [cfg], game.skills_config_raw(), Callable(), 1)
	var live: Dictionary = fight.combatants["pc"]
	assert(game.player_resource_maxima()[WIKeys.MAX_HP] == live[WIKeys.MAX_HP], "world and runtime include identical passive HP")
	assert(game.player_resource_maxima()[WIKeys.MAX_MP] == live[WIKeys.MAX_MP], "world and runtime include identical MP kit rules")
	assert(int(live[WIKeys.MAX_MP]) > 0, "real Mage kit opens MP")
	var sparse := WIGame.new(WISceneCatalog.compose(), {"skills": []}, Callable())
	assert(sparse.vitals.hp == 1 and sparse.vitals.mp == 0, "a simulation with no combat config remains usable")
	var no_classes := WIGame.new(WISceneCatalog.compose(), game.skills_config_raw(), Callable(), 1, {"combatants": game._combat_config["combatants"]})
	assert(no_classes.vitals.hp > 1 and no_classes.vitals.mp == 0, "combatants without class configuration can initialize and preview")
	assert(no_classes.vitals != game.vitals, "each game owns independent resource state")


func _check_sleep() -> void:
	var game := _new_game()
	game.vitals.hp = 3
	game.vitals.mp_potion_doses = 4
	game.actions_since_sleep = 179
	game._tick_action()
	assert(game.phase() == "day", "precondition: actual phase wrap")
	assert(game.vitals.hp == 3 and game.vitals.mp_potion_doses == 4, "clock wrap neither refills nor clears exposure")
	game.record_accomplishment("learned_magic_from_pisces")
	game.well_fed = true
	game.sleep()
	assert(game.classes.has("mage"), "first caster kit is gained by actual sleep progression")
	var maxima := game.player_resource_maxima()
	assert(game.vitals.hp == int(maxima[WIKeys.MAX_HP]), "sleep fills after waking buffs expire")
	assert(game.vitals.mp == int(maxima[WIKeys.MAX_MP]) and game.vitals.mp > 0, "sleep fills after the first MP kit is granted")
	assert(game.vitals.mp_potion_doses == 0, "actual sleep clears dose exposure")
	game.classes = {"warrior": 10}
	game.accomplishments = {"sword_skill_used": 12}
	game.vitals.hp = 2
	game.sleep()
	assert(game.classes.has("swordsman"), "actual sleep resolves evolution")
	assert(game.vitals.hp == int(game.player_resource_maxima()[WIKeys.MAX_HP]), "refill uses post-evolution maxima")
	game.classes = {"warrior": 1}
	game.accomplishments = {"won_combat": 1}
	game.vitals.hp = 2
	game.sleep()
	assert(int(game.classes["warrior"]) == 2, "actual sleep levels the class")
	assert(game.vitals.hp == int(game.player_resource_maxima()[WIKeys.MAX_HP]), "refill uses the larger levelled maximum")


func _check_saves() -> void:
	var original := _new_game()
	original.classes = {"mage": 3}
	original.vitals.hp = 5
	original.vitals.mp = 0
	original.vitals.mp_potion_doses = 4
	var data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(original)))
	assert(not data["state"]["vitals"].has(WIKeys.MAX_HP), "derived maxima are never saved")
	var restored := _new_game()
	_events.clear()
	assert(WISave.apply(restored, data))
	assert(_events.is_empty(), "restore stays silent")
	assert(restored.vitals.serialized() == original.vitals.serialized(), "depletion, zero MP and exposure survive JSON")
	assert(WISave.apply(restored, WISave.serialize(restored)))
	assert(restored.vitals.hp == 5 and restored.vitals.mp == 0, "repeated modern load cannot refill")
	var legacy: Dictionary = data.duplicate(true)
	legacy["version"] = 9
	legacy["state"].erase("vitals")
	legacy["state"]["equipped"]["armor"] = "leather_jerkin"
	legacy["state"]["inventory"].append("leather_jerkin")
	var caller_copy := legacy.duplicate(true)
	assert(WISave.apply(restored, legacy), "real pre-resource schema migrates")
	assert(legacy == caller_copy, "migration never edits caller data")
	assert(restored.vitals.hp == int(restored.player_resource_maxima()[WIKeys.MAX_HP]), "legacy refill uses restored equipment and classes")
	assert(restored.vitals.mp == int(restored.player_resource_maxima()[WIKeys.MAX_MP]), "legacy caster initializes full once")
	assert(restored.vitals.mp_potion_doses == 0)
	restored.vitals.hp = 6
	restored.vitals.mp = 0
	assert(WISave.apply(restored, WISave.serialize(restored)))
	assert(restored.vitals.hp == 6 and restored.vitals.mp == 0, "migrated save no longer gets migration refill")
	var modern_missing: Dictionary = data.duplicate(true)
	modern_missing["state"].erase("vitals")
	assert(not WISave.apply(restored, modern_missing), "modern missing resources are corrupt, not legacy")
	for version: Variant in [9.5, 10.5, INF, NAN, "9", true, null]:
		var corrupt_version: Dictionary = legacy.duplicate(true)
		corrupt_version["version"] = version
		assert(not WISave.apply(restored, corrupt_version), "malformed version cannot impersonate legacy and refill")
		assert(WISave.metadata(corrupt_version).is_empty())
	var before := WISave.serialize(restored)
	var before_snapshot := restored.snapshot()
	for key: String in [WIKeys.HP, WIKeys.MP, "mp_potion_doses"]:
		for bad: Variant in ["4", true, null, [], {}, -1, 1.5, INF, NAN, 2147483648]:
			var corrupt: Dictionary = data.duplicate(true)
			corrupt["state"]["vitals"][key] = bad
			_events.clear()
			assert(not WISave.apply(restored, corrupt), "invalid resource scalar must refuse")
			assert(WISave.serialize(restored) == before and restored.snapshot() == before_snapshot, "corruption refusal is transactional")
			assert(_events.is_empty(), "corruption cannot emit")
		var missing: Dictionary = data.duplicate(true)
		missing["state"]["vitals"].erase(key)
		assert(not WISave.apply(restored, missing), "partial modern resources are refused")
	var zero_hp: Dictionary = data.duplicate(true)
	zero_hp["state"]["vitals"][WIKeys.HP] = 0
	assert(not WISave.apply(restored, zero_hp), "world saves cannot carry a dead player")
	var retuned: Dictionary = data.duplicate(true)
	retuned["state"]["vitals"][WIKeys.HP] = 100
	retuned["state"]["vitals"][WIKeys.MP] = 100
	assert(WISave.apply(restored, retuned))
	assert(restored.vitals.hp == int(restored.player_resource_maxima()[WIKeys.MAX_HP]), "saved values clamp to current-data maxima")
	assert(restored.vitals.mp == int(restored.player_resource_maxima()[WIKeys.MAX_MP]))
	var forged_max: Dictionary = data.duplicate(true)
	forged_max["state"]["vitals"][WIKeys.MAX_HP] = 100000
	forged_max["state"]["vitals"][WIKeys.MAX_MP] = 100000
	assert(WISave.apply(restored, forged_max))
	assert(int(restored.player_resources()[WIKeys.MAX_HP]) < 100000, "saved maximum fields are not authority")


func _check_live_projection_and_staging() -> void:
	var game := _new_game()
	game.vitals.hp = 3
	game.vitals.mp_potion_doses = 4
	game.transition("floodplains", Vector2i(12, 12))
	assert(game.vitals.hp == 3, "travel does not refill saved resources")
	assert(game.start_combat("relc_spar"), "actual practice entry remains available")
	var pc: Dictionary = game.combat.combatants["pc"]
	assert(int(pc[WIKeys.HP]) == int(pc[WIKeys.MAX_HP]), "player activation is deferred: legacy entry stays rested")
	pc[WIKeys.HP] = 8
	assert(int(game.player_resources()[WIKeys.HP]) == 8, "active projection follows live combat")
	assert(int(game.snapshot()["vitals"][WIKeys.HP]) == 8, "snapshot never projects stale world HP in combat")
	assert(int(WISave.serialize(game)["state"]["vitals"][WIKeys.HP]) == 3, "world checkpoint and live projection are distinct")
	assert(not WISave.serialize(game)["state"].has("combat"), "active battle stays unserialized")
