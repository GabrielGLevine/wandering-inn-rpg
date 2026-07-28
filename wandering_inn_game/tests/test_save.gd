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
		"dialogue": {"save_test": {"start": "n1", "nodes": {"n1": {"speaker": "Erin", "text": "Take this.", "options": []}}}},
		"quests": {"quests": [{"id": "the_errand", "title": "The Errand", "beats": [
			{"id": "deliver", "description": "Deliver the package.", "complete_when": {"package_delivered": 1}},
		]}]},
		"items": _load_json("res://data/items.json"),
	}


func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, _combat_config())


## Task 2.6: every counter the dig backfill owes a migrated door-chain save,
## in the order test_fixture_coherence's monotone chain walks them.
func _assert_dig_backfilled(game: WIGame, label: String) -> void:
	for cid: String in ["horns_dig_started", "horns_dig_joined", "pedestal_breached",
			"door_retrieved", "door_mounted"]:
		assert(game.accomplishment_count(cid) >= 1, "%s: %s backfilled on load" % [label, cid])
	assert(game.started_quests.has("horns_dig"), "%s: The Dig is in started_quests after load" % label)


func _init() -> void:
	WITestWatchdog.arm(self)
	var original := _new_game()
	original.move_player(Vector2i.UP)
	original.transition("street", Vector2i(4, 3))
	original.player_facing = Vector2i.RIGHT
	original.classes["warrior"] = 2
	original.player_skills.append("flame_bolt")
	original.used_skills.append("basic_cleaning")
	original.seen_statuses.append("slowed")
	original.record_accomplishment("package_delivered")
	original.record_accomplishment("won_combat")
	original.remove_entity("goblin_encounter_2")
	original.start_quest("the_errand")
	original.rng.randi()
	original.pickup("leather_jerkin", "inn_chest")
	original.equip("leather_jerkin")
	original.container_state["inn_chest"] = true
	original.actions_since_sleep = 7
	original.light_active = true
	original.well_fed = true
	original.pending_meal = {"damage_mod": 1}
	original.sneaking = true
	original.pc_name = "Sella"
	original.pc_race = "drake"
	original.pc_gender = "f"
	original.hotbar_loadout.assign(["flame_bolt", "basic_cleaning"])
	original.warded_encounters = {
		"goblin_encounter_1": {"sleeps": 2, "map": "floodplains", "cell": [30, 21]},
	}
	original.companion = "skeleton_ally"
	original.companion_source = "tamed"

	var data := WISave.serialize(original)
	assert(data["version"] == WISave.VERSION, "save version matches the current constant")
	assert(data["state"]["rng_state"] is String, "rng state serializes as string")

	var stale: Dictionary = JSON.parse_string(JSON.stringify(data))
	stale["version"] = 1
	assert(not WISave.apply(_new_game(), stale), "older-version save is rejected")

	var restored := _new_game()
	_events.clear()
	assert(WISave.apply(restored, data), "save applies")
	assert(_events.is_empty(), "apply emits nothing")
	assert(restored.current_map == original.current_map, "current_map restored")
	assert(restored.player_cell == original.player_cell, "player_cell restored")
	assert(restored.player_facing == original.player_facing, "player_facing restored")
	assert(restored.classes == original.classes, "classes restored")
	assert(restored.accomplishments == original.accomplishments, "accomplishments restored")
	assert(restored.player_skills == original.player_skills, "player_skills restored")
	assert(restored.removed_entities == original.removed_entities, "removed_entities restored")
	assert(restored.started_quests == original.started_quests, "started_quests restored")
	assert(restored.dormant_encounters == original.dormant_encounters, "dormant_encounters restored")
	assert(restored.used_skills == original.used_skills, "used_skills restored")
	assert(restored.seen_statuses == original.seen_statuses, "seen_statuses restored")
	assert(restored.inventory == original.inventory, "inventory restored")
	assert(restored.equipped == original.equipped, "equipped restored")
	assert(restored.equipped == {"weapon": "rusty_sword", "armor": "leather_jerkin", "accessory_1": "", "accessory_2": "", "accessory_3": ""}, "equip() landed in the equipped dict as expected (M-GEAR Task G1: now the wider 5-key shape)")
	assert(restored.inventory.has("rusty_sword") and restored.inventory.has("leather_jerkin"), "inventory carries both the starter sword and the picked-up armor")
	assert(restored.container_state == original.container_state, "container_state restored")
	assert(int(restored.actions_since_sleep) == 7, "actions_since_sleep restored")
	assert(restored.light_active == original.light_active, "light_active restored")
	assert(restored.light_active == true, "light_active round-trips as true")
	assert(restored.well_fed == original.well_fed, "well_fed restored")
	assert(restored.well_fed == true, "well_fed round-trips as true")
	assert(restored.pending_meal == original.pending_meal, "pending_meal restored")
	assert(restored.pending_meal == {"damage_mod": 1}, "pending_meal round-trips verbatim")
	assert(restored.hotbar_loadout == original.hotbar_loadout, "hotbar_loadout restored")
	assert(restored.hotbar_loadout == ["flame_bolt", "basic_cleaning"], "hotbar_loadout round-trips in order")
	assert(restored.warded_encounters == original.warded_encounters, "warded encounter state round-trips")
	assert(restored.companion == "skeleton_ally", "companion state round-trips")
	assert(restored.companion_source == "tamed", "companion_source round-trips (GH#156)")
	var no_wave_b_state: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_wave_b_state.erase("warded_encounters")
	no_wave_b_state.erase("companion")
	no_wave_b_state.erase("companion_source")
	var no_wave_b_target := _new_game()
	no_wave_b_target.warded_encounters = {"stale": {"sleeps": 9}}
	no_wave_b_target.companion = "stale"
	no_wave_b_target.companion_source = "stale_source"
	assert(WISave.apply(no_wave_b_target, {"version": WISave.VERSION, "state": no_wave_b_state}), "pre-Wave-B save without ward/companion fields still applies")
	assert(no_wave_b_target.companion_source == "", "legacy save defaults companion_source empty -- a pre-#156 skeleton keeps fades-at-sleep behavior")
	assert(no_wave_b_target.warded_encounters.is_empty() and no_wave_b_target.companion == "", "absent Wave-B fields restore safe empty defaults")
	var bad_wards_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_wards_data["state"] as Dictionary)["warded_encounters"] = []
	assert(not WISave.apply(_new_game(), bad_wards_data), "wrong-typed warded_encounters rejected")
	var bad_companion_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_companion_data["state"] as Dictionary)["companion"] = 12
	assert(not WISave.apply(_new_game(), bad_companion_data), "wrong-typed companion rejected")
	var no_loadout: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_loadout.erase("hotbar_loadout")
	var loadout_target := _new_game()
	assert(WISave.apply(loadout_target, {"version": WISave.VERSION, "state": no_loadout}), "save without hotbar_loadout still applies")
	assert(loadout_target.hotbar_loadout.is_empty(), "absent hotbar_loadout defaults to AUTO (empty)")
	var bad_loadout: Dictionary = (data["state"] as Dictionary).duplicate(true)
	bad_loadout["hotbar_loadout"] = "not_an_array"
	assert(not WISave.apply(_new_game(), {"version": WISave.VERSION, "state": bad_loadout}), "non-Array hotbar_loadout rejected")
	assert(not data["state"].has("sneaking"), "sneaking is not even present in the serialized state")
	assert(restored.sneaking == false, "a save taken while sneaking round-trips to NOT sneaking")
	var no_glow: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_glow.erase("light_active")
	var glow_target := _new_game()
	assert(WISave.apply(glow_target, {"version": WISave.VERSION, "state": no_glow}), "save without light_active still applies")
	assert(glow_target.light_active == false, "absent light_active defaults false")
	var no_meal: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_meal.erase("well_fed")
	var meal_target := _new_game()
	assert(WISave.apply(meal_target, {"version": WISave.VERSION, "state": no_meal}), "save without well_fed still applies")
	assert(meal_target.well_fed == false, "absent well_fed defaults false")
	var bad_well_fed: Dictionary = (data["state"] as Dictionary).duplicate(true)
	bad_well_fed["well_fed"] = "not_a_bool"
	assert(not WISave.apply(_new_game(), {"version": WISave.VERSION, "state": bad_well_fed}), "non-bool well_fed rejected")
	var no_pending_meal: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_pending_meal.erase("pending_meal")
	var pending_meal_target := _new_game()
	assert(WISave.apply(pending_meal_target, {"version": WISave.VERSION, "state": no_pending_meal}), "save without pending_meal still applies")
	assert(pending_meal_target.pending_meal.is_empty(), "absent pending_meal defaults to {}")
	var bad_pending_meal: Dictionary = (data["state"] as Dictionary).duplicate(true)
	bad_pending_meal["pending_meal"] = "not_a_dict"
	assert(not WISave.apply(_new_game(), {"version": WISave.VERSION, "state": bad_pending_meal}), "non-Dictionary pending_meal rejected")
	assert(restored.pc_name == "Sella", "pc_name restored")
	assert(restored.pc_race == "drake", "pc_race restored")
	assert(restored.pc_gender == "f", "pc_gender restored")
	var no_identity: Dictionary = (data["state"] as Dictionary).duplicate(true)
	for k in ["pc_name", "pc_race", "pc_gender"]:
		no_identity.erase(k)
	var id_target := _new_game()
	assert(WISave.apply(id_target, {"version": WISave.VERSION, "state": no_identity}), "save without pc identity still applies")
	assert(id_target.pc_name == "Traveler" and id_target.pc_race == "human" and id_target.pc_gender == "m", "absent pc identity defaults to Human/male/Traveler")
	var garbage: Dictionary = (data["state"] as Dictionary).duplicate(true)
	garbage["pc_name"] = "   "
	garbage["pc_race"] = "elf"
	garbage["pc_gender"] = "x"
	var g_target := _new_game()
	assert(WISave.apply(g_target, {"version": WISave.VERSION, "state": garbage}), "garbage pc identity still applies")
	assert(g_target.pc_name == "Traveler" and g_target.pc_race == "human" and g_target.pc_gender == "m", "garbage pc identity sanitized to defaults")
	var bad_type: Dictionary = (data["state"] as Dictionary).duplicate(true)
	bad_type["pc_name"] = 5
	assert(not WISave.apply(_new_game(), {"version": WISave.VERSION, "state": bad_type}), "non-String pc_name rejected")
	assert(restored.find_entity("goblin_encounter_2").is_empty(), "removed entity stays removed")
	assert(restored.rng.state == original.rng.state, "rng state restored")
	assert(restored.rng.randi() == original.rng.randi(), "rng stream remains deterministic")

	var untouched := _new_game()
	var untouched_snapshot := untouched.snapshot()
	var untouched_rng_state := untouched.rng.state
	assert(not WISave.apply(untouched, {"version": 99, "state": data["state"]}), "version mismatch rejected")
	assert(untouched.snapshot() == untouched_snapshot, "version mismatch leaves state untouched")
	assert(untouched.rng.state == untouched_rng_state, "version mismatch leaves rng untouched")
	assert(not untouched.find_entity("goblin_encounter_2").is_empty(), "version mismatch leaves entities untouched")

	var m1_target := _new_game()
	var m1_snapshot := m1_target.snapshot()
	var m1_rng_state := m1_target.rng.state
	assert(not WISave.apply(m1_target, {"version": 1}), "missing state key rejected")
	assert(m1_target.snapshot() == m1_snapshot, "missing state leaves snapshot untouched")
	assert(m1_target.rng.state == m1_rng_state, "missing state leaves rng untouched")
	assert(not m1_target.find_entity("goblin_encounter_2").is_empty(), "missing state leaves entities untouched")

	var m2_base := WISave.serialize(original)
	var m2_corrupt := m2_base.duplicate(true)
	(m2_corrupt["state"] as Dictionary)["player_cell"] = [3]
	var m2_target := _new_game()
	var m2_snapshot := m2_target.snapshot()
	var m2_rng_state := m2_target.rng.state
	assert(not WISave.apply(m2_target, m2_corrupt), "truncated player_cell rejected")
	assert(m2_target.snapshot() == m2_snapshot, "truncated player_cell leaves snapshot untouched")
	assert(m2_target.rng.state == m2_rng_state, "truncated player_cell leaves rng untouched")
	assert(not m2_target.find_entity("goblin_encounter_2").is_empty(), "truncated player_cell leaves entities untouched")

	var m3_base := WISave.serialize(original)
	var m3_corrupt := m3_base.duplicate(true)
	(m3_corrupt["state"] as Dictionary)["classes"] = "warrior"
	var m3_target := _new_game()
	var m3_snapshot := m3_target.snapshot()
	var m3_rng_state := m3_target.rng.state
	assert(not WISave.apply(m3_target, m3_corrupt), "wrong type for classes rejected")
	assert(m3_target.snapshot() == m3_snapshot, "wrong type for classes leaves snapshot untouched")
	assert(m3_target.rng.state == m3_rng_state, "wrong type for classes leaves rng untouched")
	assert(not m3_target.find_entity("goblin_encounter_2").is_empty(), "wrong type for classes leaves entities untouched")

	var m4_base := WISave.serialize(original)
	var m4_corrupt := m4_base.duplicate(true)
	(m4_corrupt["state"] as Dictionary).erase("rng_state")
	var m4_target := _new_game()
	var m4_snapshot := m4_target.snapshot()
	var m4_rng_state := m4_target.rng.state
	assert(not WISave.apply(m4_target, m4_corrupt), "missing rng_state key rejected")
	assert(m4_target.snapshot() == m4_snapshot, "missing rng_state leaves snapshot untouched")
	assert(m4_target.rng.state == m4_rng_state, "missing rng_state leaves rng untouched")
	assert(not m4_target.find_entity("goblin_encounter_2").is_empty(), "missing rng_state leaves entities untouched")

	var m5_base := WISave.serialize(original)
	var m5_corrupt := m5_base.duplicate(true)
	(m5_corrupt["state"] as Dictionary)["current_map"] = "nonexistent_map"
	var m5_target := _new_game()
	var m5_snapshot := m5_target.snapshot()
	var m5_rng_state := m5_target.rng.state
	assert(not WISave.apply(m5_target, m5_corrupt), "unknown current_map rejected")
	assert(m5_target.snapshot() == m5_snapshot, "unknown current_map leaves snapshot untouched")
	assert(m5_target.rng.state == m5_rng_state, "unknown current_map leaves rng untouched")
	assert(not m5_target.find_entity("goblin_encounter_2").is_empty(), "unknown current_map leaves entities untouched")

	var resp_original := _new_game()
	resp_original.dormant_encounters.append("goblin_encounter_2")
	var resp_data := WISave.serialize(resp_original)
	assert(int(resp_data["version"]) == WISave.VERSION, "serialize tags the current VERSION constant (M6 T2 bumped 2->3; M-FP F fix bumped 3->4)")
	var resp_restored := _new_game()
	assert(WISave.apply(resp_restored, resp_data), "v3 save applies")
	assert(resp_restored.dormant_encounters == resp_original.dormant_encounters, "dormancy round-trips")

	var v2_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v2_data["version"] = 2
	(v2_data["state"] as Dictionary).erase("dormant_encounters")
	var v2_target := _new_game()
	v2_target.dormant_encounters.append("stale_entry")
	assert(WISave.apply(v2_target, v2_data), "v2 save migrates and applies")
	assert(v2_target.dormant_encounters.is_empty(), "migrated v2 save carries no dormancy")

	var m6_corrupt := WISave.serialize(resp_original).duplicate(true)
	(m6_corrupt["state"] as Dictionary).erase("dormant_encounters")
	assert(not WISave.apply(_new_game(), m6_corrupt), "v3 save without dormant_encounters rejected")

	var gen_original := _new_game()
	gen_original.generalist_classes.append("mage")
	var gen_data := WISave.serialize(gen_original)
	assert(int(gen_data["version"]) == WISave.VERSION, "M6 T3 does not bump the save version (still tags the current VERSION constant)")
	var gen_restored := _new_game()
	assert(WISave.apply(gen_restored, gen_data), "save with generalist_classes applies")
	assert(gen_restored.generalist_classes == gen_original.generalist_classes, "generalist_classes round-trips")

	var pre_t3_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_t3_data["state"] as Dictionary).erase("generalist_classes")
	var pre_t3_target := _new_game()
	pre_t3_target.generalist_classes.append("stale_entry")
	assert(WISave.apply(pre_t3_target, pre_t3_data), "save missing generalist_classes still applies")
	assert(pre_t3_target.generalist_classes.is_empty(), "absent generalist_classes restores empty, not stale data")

	var bad_gen_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_gen_data["state"] as Dictionary)["generalist_classes"] = "mage"
	assert(not WISave.apply(_new_game(), bad_gen_data), "wrong-typed generalist_classes rejected")

	var pending_original := _new_game()
	pending_original.pending_consolidation = {"parents": ["warrior", "mage"], "target": "spellsword", "level": 14}
	var pending_data := WISave.serialize(pending_original)
	assert(int(pending_data["version"]) == WISave.VERSION, "M6 T5 does not bump the save version (still tags the current VERSION constant)")
	var pending_restored := _new_game()
	assert(WISave.apply(pending_restored, pending_data), "save with pending_consolidation applies")
	assert(pending_restored.pending_consolidation == pending_original.pending_consolidation, "pending_consolidation round-trips")

	var pre_t5_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_t5_data["state"] as Dictionary).erase("pending_consolidation")
	var pre_t5_target := _new_game()
	pre_t5_target.pending_consolidation = {"parents": ["warrior", "mage"], "target": "spellsword", "level": 14}
	assert(WISave.apply(pre_t5_target, pre_t5_data), "save missing pending_consolidation still applies")
	assert(pre_t5_target.pending_consolidation.is_empty(), "absent pending_consolidation restores empty, not stale data")

	var bad_pending_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_pending_data["state"] as Dictionary)["pending_consolidation"] = "spellsword"
	assert(not WISave.apply(_new_game(), bad_pending_data), "wrong-typed pending_consolidation rejected")

	var used_original := _new_game()
	used_original.used_skills.append("power_strike")
	var used_data := WISave.serialize(used_original)
	assert(int(used_data["version"]) == WISave.VERSION, "used_skills does not bump the save version (still tags the current VERSION constant)")
	var used_restored := _new_game()
	assert(WISave.apply(used_restored, used_data), "save with used_skills applies")
	assert(used_restored.used_skills == used_original.used_skills, "used_skills round-trips")

	var pre_ui_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_ui_data["state"] as Dictionary).erase("used_skills")
	var pre_ui_target := _new_game()
	pre_ui_target.used_skills.append("stale_entry")
	assert(WISave.apply(pre_ui_target, pre_ui_data), "save missing used_skills still applies")
	assert(pre_ui_target.used_skills.is_empty(), "absent used_skills restores empty, not stale data")

	var bad_used_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_used_data["state"] as Dictionary)["used_skills"] = "power_strike"
	assert(not WISave.apply(_new_game(), bad_used_data), "wrong-typed used_skills rejected")

	var status_original := _new_game()
	status_original.seen_statuses.append("slowed")
	var status_data := WISave.serialize(status_original)
	assert(int(status_data["version"]) == WISave.VERSION, "seen_statuses does not bump the save version")
	var status_restored := _new_game()
	assert(WISave.apply(status_restored, status_data), "save with seen_statuses applies")
	assert(status_restored.seen_statuses == status_original.seen_statuses, "seen_statuses round-trips")

	var pre_l4_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_l4_data["state"] as Dictionary).erase("seen_statuses")
	var pre_l4_target := _new_game()
	pre_l4_target.seen_statuses.append("stale_entry")
	assert(WISave.apply(pre_l4_target, pre_l4_data), "save missing seen_statuses still applies")
	assert(pre_l4_target.seen_statuses.is_empty(), "absent seen_statuses restores empty, not stale data")

	var bad_status_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_status_data["state"] as Dictionary)["seen_statuses"] = "slowed"
	assert(not WISave.apply(_new_game(), bad_status_data), "wrong-typed seen_statuses rejected")

	assert(WISave.VERSION == 8, "VERSION bumped to 8 for the v0.15 A3 lore_notes record")

	# GH#130 v5->v6 arm: a pre-#130 save with sleeps behind it gains slept=1
	# exactly once; a never-slept v5 save gains nothing.
	var v5_slept_game := _new_game()
	v5_slept_game.record_accomplishment("cleaned_the_inn")
	var v5_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(v5_slept_game)))
	v5_data["version"] = 5
	(v5_data["state"] as Dictionary)["times_slept"] = 7
	((v5_data["state"] as Dictionary)["accomplishments"] as Dictionary).erase("slept")
	var v5_loaded := _new_game()
	assert(WISave.apply(v5_loaded, v5_data), "v5 save with sleeps applies")
	assert(v5_loaded.accomplishment_count("slept") == 1, "v5->v6 backfills slept to exactly 1 (capped, not times_slept)")
	var v5_fresh_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v5_fresh_data["version"] = 5
	(v5_fresh_data["state"] as Dictionary)["times_slept"] = 0
	((v5_fresh_data["state"] as Dictionary)["accomplishments"] as Dictionary).erase("slept")
	var v5_fresh_loaded := _new_game()
	assert(WISave.apply(v5_fresh_loaded, v5_fresh_data), "never-slept v5 save applies")
	assert(v5_fresh_loaded.accomplishment_count("slept") == 0, "never-slept v5 save gains no slept backfill")

	# GH#211 v6->v7 arm: pre-#211 saves gain an EMPTY fractional_bank (no
	# retroactive credit); a live fractional_bank round-trips exactly.
	var v6_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v6_data["version"] = 6
	(v6_data["state"] as Dictionary).erase("fractional_bank")
	var v6_loaded := _new_game()
	v6_loaded.fractional_bank["stale"] = 0.5
	assert(WISave.apply(v6_loaded, v6_data), "v6 save applies")
	assert(v6_loaded.fractional_bank.is_empty(), "v6->v7 migration restores an EMPTY fractional_bank, not stale data")
	var frac_original := _new_game()
	frac_original.fractional_bank = {"melee_hit": 0.75, "won_combat": 0.25}
	var frac_restored := _new_game()
	assert(WISave.apply(frac_restored, JSON.parse_string(JSON.stringify(WISave.serialize(frac_original)))), "fractional save applies")
	assert(is_equal_approx(float(frac_restored.fractional_bank.get("melee_hit", 0.0)), 0.75) and is_equal_approx(float(frac_restored.fractional_bank.get("won_combat", 0.0)), 0.25), "fractional_bank round-trips exactly")
	var bad_frac_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_frac_data["state"] as Dictionary)["fractional_bank"] = "corrupt"
	assert(not WISave.apply(_new_game(), bad_frac_data), "wrong-typed fractional_bank rejected before any mutation")

	# v0.15 A3 v7->v8 arm: `lore_notes` is new durable state. Old saves resume
	# with an EMPTY record -- nothing is retroactively remembered, and the
	# migration COMPOSES (a v5 save walks 5->6->7->8 and lands empty too).
	var v7_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v7_data["version"] = 7
	(v7_data["state"] as Dictionary).erase("lore_notes")
	var v7_loaded := _new_game()
	v7_loaded.lore_notes.append("stale note")
	assert(WISave.apply(v7_loaded, v7_data), "v7 save applies")
	assert(v7_loaded.lore_notes.is_empty(), "v7->v8 migration restores an EMPTY lore_notes, not stale data")
	var v5_chain_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v5_chain_data["version"] = 5
	for dropped: String in ["fractional_bank", "lore_notes"]:
		(v5_chain_data["state"] as Dictionary).erase(dropped)
	var v5_chain_loaded := _new_game()
	assert(WISave.apply(v5_chain_loaded, v5_chain_data), "a v5 save still walks the WHOLE composed chain to v8")
	assert(v5_chain_loaded.lore_notes.is_empty() and v5_chain_loaded.fractional_bank.is_empty(),
		"every arm on the composed path applies -- lore_notes and fractional_bank both land empty")
	var lore_original := _new_game()
	lore_original.lore_notes.assign([
		"The runes are the same. Not similar — the same hand.",
		"One lattice, and this door is where it drains to.",
	])
	var lore_restored := _new_game()
	assert(WISave.apply(lore_restored, JSON.parse_string(JSON.stringify(WISave.serialize(lore_original)))), "lore save applies")
	assert(lore_restored.lore_notes == lore_original.lore_notes, "lore_notes round-trips verbatim, in capture order")
	var bad_lore_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_lore_data["state"] as Dictionary)["lore_notes"] = "corrupt"
	assert(not WISave.apply(_new_game(), bad_lore_data), "wrong-typed lore_notes rejected before any mutation")

	var street_v3_original := _new_game()
	street_v3_original.transition("street", Vector2i(0, 0))
	street_v3_original.player_facing = Vector2i.DOWN
	street_v3_original.classes["warrior"] = 3
	street_v3_original.record_accomplishment("browsed_market")
	assert(street_v3_original.is_cell_blocked(Vector2i(0, 0)), "sanity: (0,0) is blocked in the current street layout")
	assert(not street_v3_original.is_cell_blocked(Vector2i(1, 3)), "sanity: (1,3) [liscor_gate arrival] is unblocked in the current street layout")
	var street_v3_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(street_v3_original)))
	street_v3_data["version"] = 3
	var street_v3_target := _new_game()
	assert(WISave.apply(street_v3_target, street_v3_data), "v3 street save at a now-blocked cell migrates and applies")
	assert(street_v3_target.player_cell == Vector2i(1, 3), "v3->v4 migration relocates the street player_cell to [1,3]")
	assert(street_v3_target.current_map == "street", "current_map is untouched by the relocation")
	assert(street_v3_target.player_facing == Vector2i.DOWN, "player_facing is untouched by the relocation")
	assert(street_v3_target.classes.size() == 1 and int(street_v3_target.classes.get("warrior", 0)) == 3, "classes is untouched by the relocation")
	assert(int(street_v3_target.accomplishments.get("browsed_market", 0)) == 1, "accomplishments are untouched by the relocation")

	var inn_v3_original := _new_game()
	inn_v3_original.move_player(Vector2i.RIGHT)
	var inn_v3_expected_cell := inn_v3_original.player_cell
	var inn_v3_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(inn_v3_original)))
	inn_v3_data["version"] = 3
	var inn_v3_target := _new_game()
	assert(WISave.apply(inn_v3_target, inn_v3_data), "v3 inn save migrates and applies")
	assert(inn_v3_target.current_map == "inn", "inn save keeps current_map")
	assert(inn_v3_target.player_cell == inn_v3_expected_cell, "v3 inn save's player_cell is untouched by the v3->v4 step")

	var street_v2_original := _new_game()
	street_v2_original.transition("street", Vector2i(0, 5))
	var street_v2_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(street_v2_original)))
	street_v2_data["version"] = 2
	(street_v2_data["state"] as Dictionary).erase("dormant_encounters")
	var street_v2_target := _new_game()
	street_v2_target.dormant_encounters.append("stale_entry")
	assert(WISave.apply(street_v2_target, street_v2_data), "v2 street save chains v2->v3->v4 and applies")
	assert(street_v2_target.current_map == "street", "current_map is untouched by the composed migration")
	assert(street_v2_target.player_cell == Vector2i(1, 3), "v2 street save composes through to the v4 relocation")
	assert(street_v2_target.dormant_encounters.is_empty(), "v2 street save still gets the v2->v3 dormant_encounters migration")

	var v4_original := _new_game()
	v4_original.classes["warrior"] = 4
	v4_original.record_accomplishment("browsed_market")
	var v4_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(v4_original)))
	v4_data["version"] = 4
	var v4_state: Dictionary = v4_data["state"]
	v4_state.erase("inventory")
	v4_state.erase("equipped")
	v4_state.erase("container_state")
	v4_state.erase("actions_since_sleep")
	var v4_target := _new_game()
	v4_target.inventory.append("stale_entry")
	v4_target.equipped = {"weapon": "stale", "armor": "stale"}
	v4_target.container_state["stale"] = true
	v4_target.actions_since_sleep = 999
	assert(WISave.apply(v4_target, v4_data), "v4 save (pre-M7, missing all four new fields) migrates and applies")
	assert(Array(v4_target.inventory) == ["rusty_sword"], "v4->v5 migration defaults inventory to the starter sword")
	assert(v4_target.equipped == {"weapon": "rusty_sword", "armor": ""}, "v4->v5 migration defaults equipped to the starter sword, no armor")
	assert(v4_target.container_state.is_empty(), "v4->v5 migration defaults container_state to empty")
	assert(int(v4_target.actions_since_sleep) == 0, "v4->v5 migration defaults actions_since_sleep to 0")
	assert(int(v4_target.classes.get("warrior", 0)) == 4, "other v4 fields (classes) pass through the v5 migration untouched")
	assert(int(v4_target.accomplishments.get("browsed_market", 0)) == 1, "other v4 fields (accomplishments) pass through the v5 migration untouched")

	for missing_key: String in ["inventory", "equipped", "container_state", "actions_since_sleep"]:
		var m7_missing_data: Dictionary = WISave.serialize(_new_game()).duplicate(true)
		(m7_missing_data["state"] as Dictionary).erase(missing_key)
		assert(not WISave.apply(_new_game(), m7_missing_data), "v5 save missing '%s' is rejected, not defaulted" % missing_key)

	var bad_inv_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_inv_data["state"] as Dictionary)["inventory"] = "rusty_sword"
	assert(not WISave.apply(_new_game(), bad_inv_data), "wrong-typed inventory rejected")

	var bad_eq_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_eq_data["state"] as Dictionary)["equipped"] = ["rusty_sword"]
	assert(not WISave.apply(_new_game(), bad_eq_data), "wrong-typed equipped rejected")

	var bad_cs_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_cs_data["state"] as Dictionary)["container_state"] = ["inn_chest"]
	assert(not WISave.apply(_new_game(), bad_cs_data), "wrong-typed container_state rejected")

	var bad_asl_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_asl_data["state"] as Dictionary)["actions_since_sleep"] = "seven"
	assert(not WISave.apply(_new_game(), bad_asl_data), "wrong-typed actions_since_sleep rejected")

	var v2_full_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v2_full_data["version"] = 2
	var v2_full_state: Dictionary = v2_full_data["state"]
	v2_full_state.erase("dormant_encounters")
	v2_full_state.erase("inventory")
	v2_full_state.erase("equipped")
	v2_full_state.erase("container_state")
	v2_full_state.erase("actions_since_sleep")
	var v2_full_target := _new_game()
	assert(WISave.apply(v2_full_target, v2_full_data), "v2 save chains v2->v3->v4->v5 and applies")
	assert(Array(v2_full_target.inventory) == ["rusty_sword"], "v2 save composes all the way through to the v5 inventory default")
	assert(v2_full_target.equipped == {"weapon": "rusty_sword", "armor": ""}, "v2 save composes all the way through to the v5 equipped default")
	assert(v2_full_target.container_state.is_empty(), "v2 save composes all the way through to the v5 container_state default")
	assert(int(v2_full_target.actions_since_sleep) == 0, "v2 save composes all the way through to the v5 actions_since_sleep default")
	assert(v2_full_target.dormant_encounters.is_empty(), "v2 save still gets the v2->v3 dormant_encounters migration too")

	var social_original := _new_game()
	social_original.social_talked["krshia"] = true
	social_original.entity_first_use["observe:krshia"] = true
	var social_data := WISave.serialize(social_original)
	assert(int(social_data["version"]) == WISave.VERSION, "S1 does not bump the save version (still tags the current VERSION constant)")
	var social_restored := _new_game()
	assert(WISave.apply(social_restored, social_data), "save with social_talked/entity_first_use applies")
	assert(social_restored.social_talked == social_original.social_talked, "social_talked round-trips")
	assert(social_restored.entity_first_use == social_original.entity_first_use, "entity_first_use round-trips")

	var pre_s1_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_s1_data["state"] as Dictionary).erase("social_talked")
	(pre_s1_data["state"] as Dictionary).erase("entity_first_use")
	var pre_s1_target := _new_game()
	pre_s1_target.social_talked["stale"] = true
	pre_s1_target.entity_first_use["stale:x"] = true
	assert(WISave.apply(pre_s1_target, pre_s1_data), "save missing the S1 keys still applies")
	assert(pre_s1_target.social_talked.is_empty(), "absent social_talked restores empty, not stale data")
	assert(pre_s1_target.entity_first_use.is_empty(), "absent entity_first_use restores empty, not stale data")

	var bad_social_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_social_data["state"] as Dictionary)["social_talked"] = "krshia"
	assert(not WISave.apply(_new_game(), bad_social_data), "wrong-typed social_talked rejected")
	var bad_efu_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_efu_data["state"] as Dictionary)["entity_first_use"] = ["observe:krshia"]
	assert(not WISave.apply(_new_game(), bad_efu_data), "wrong-typed entity_first_use rejected")

	var gold_original := _new_game()
	gold_original.gold = 42
	var gold_data := WISave.serialize(gold_original)
	assert(int(gold_data["version"]) == WISave.VERSION, "gold does not bump the save version")
	var gold_restored := _new_game()
	assert(WISave.apply(gold_restored, gold_data), "save with gold applies")
	assert(gold_restored.gold == 42, "gold round-trips")
	var pre_gold_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_gold_data["state"] as Dictionary).erase("gold")
	var pre_gold_target := _new_game()
	pre_gold_target.gold = 999
	assert(WISave.apply(pre_gold_target, pre_gold_data), "save missing the gold key still applies")
	assert(pre_gold_target.gold == 0, "absent gold restores 0, not stale data")
	var bad_gold_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_gold_data["state"] as Dictionary)["gold"] = "lots"
	assert(not WISave.apply(_new_game(), bad_gold_data), "wrong-typed gold rejected")

	var res_original := _new_game()
	res_original.resonance_capacity = 5
	var res_data := WISave.serialize(res_original)
	assert(int(res_data["version"]) == WISave.VERSION, "resonance_capacity does not bump the save version")
	var res_restored := _new_game()
	assert(WISave.apply(res_restored, res_data), "save with resonance_capacity applies")
	assert(res_restored.resonance_capacity == 5, "resonance_capacity round-trips")

	var pre_g1_cap_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_g1_cap_data["state"] as Dictionary).erase("resonance_capacity")
	var pre_g1_cap_target := _new_game()
	pre_g1_cap_target.resonance_capacity = 999
	assert(WISave.apply(pre_g1_cap_target, pre_g1_cap_data), "save missing resonance_capacity still applies")
	assert(pre_g1_cap_target.resonance_capacity == 2, "absent resonance_capacity restores the default 2, not stale data")

	var bad_cap_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_cap_data["state"] as Dictionary)["resonance_capacity"] = "two"
	assert(not WISave.apply(_new_game(), bad_cap_data), "wrong-typed resonance_capacity rejected")

	var old_shape_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(old_shape_data["state"] as Dictionary)["equipped"] = {"weapon": "rusty_sword", "armor": ""}
	var old_shape_target := _new_game()
	assert(WISave.apply(old_shape_target, old_shape_data), "a save with the pre-G1 2-key equipped shape still applies")
	assert(String(old_shape_target.equipped.get("weapon", "?")) == "rusty_sword", "old 2-key shape's weapon key reads through unchanged")
	assert(not old_shape_target.equipped.has("accessory_1"), "sanity: the loaded dict genuinely lacks the accessory keys (this is the pre-G1 shape, not a padded one)")
	assert(String(old_shape_target.equipped.get("accessory_1", "")) == "", "old 2-key shape's absent accessory_1 reads back empty via the SAME tolerant .get(slot, \"\") every consumer uses, not malformed")
	assert(String(old_shape_target.equipped.get("accessory_2", "")) == "", "old 2-key shape's absent accessory_2 reads back empty")
	assert(String(old_shape_target.equipped.get("accessory_3", "")) == "", "old 2-key shape's absent accessory_3 reads back empty")
	old_shape_target.pickup("leather_jerkin", "test")
	assert(old_shape_target.equip("leather_jerkin"), "equip still succeeds (armor slot) from the tolerant-loaded 2-key shape")
	var acc_cc := _combat_config()
	var acc_items: Array = ((acc_cc["items"] as Dictionary)["items"] as Array).duplicate(true)
	acc_items.append({"id": "test_g1_charm", "kind": "accessory", "resonance": 0})
	acc_cc["items"] = {"items": acc_items}
	var old_shape_acc_target := WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, acc_cc)
	assert(WISave.apply(old_shape_acc_target, old_shape_data), "2-key equipped shape applies onto an instance with an accessory-catalogued item too")
	old_shape_acc_target.pickup("test_g1_charm", "test")
	assert(old_shape_acc_target.equip("test_g1_charm"), "accessory equip succeeds from a tolerant-loaded 2-key equipped shape")
	assert(String(old_shape_acc_target.equipped.get("accessory_1", "?")) == "test_g1_charm", "the accessory lands in accessory_1 even though the loaded dict never declared that key")

	var board_original := _new_game()
	board_original.times_slept = 3
	board_original.accepted_bounty_id = "bounty_gossip_tea"
	board_original.accepted_bounty_baseline = {"heard_gossip": 1}
	board_original.accepted_bounty_tier = "silver"
	board_original.board_last_seen_times_slept = 2
	var board_data := WISave.serialize(board_original)
	assert(int(board_data["version"]) == WISave.VERSION, "DP2 board fields do not bump the save version")
	var board_restored := _new_game()
	assert(WISave.apply(board_restored, board_data), "save with DP2 board fields applies")
	assert(board_restored.times_slept == 3, "times_slept round-trips")
	assert(board_restored.accepted_bounty_id == "bounty_gossip_tea", "accepted_bounty_id round-trips")
	assert(board_restored.accepted_bounty_baseline == {"heard_gossip": 1}, "accepted_bounty_baseline round-trips")
	assert(board_restored.accepted_bounty_tier == "silver", "accepted_bounty_tier round-trips (#163 review MEDIUM)")
	assert(board_restored.board_last_seen_times_slept == 2, "board_last_seen_times_slept round-trips")

	var pre_dp2_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_dp2_data["state"] as Dictionary).erase("times_slept")
	(pre_dp2_data["state"] as Dictionary).erase("accepted_bounty_id")
	(pre_dp2_data["state"] as Dictionary).erase("accepted_bounty_baseline")
	(pre_dp2_data["state"] as Dictionary).erase("accepted_bounty_tier")
	(pre_dp2_data["state"] as Dictionary).erase("board_last_seen_times_slept")
	var pre_dp2_target := _new_game()
	pre_dp2_target.times_slept = 999
	pre_dp2_target.accepted_bounty_id = "stale"
	pre_dp2_target.accepted_bounty_baseline = {"stale": 999}
	pre_dp2_target.accepted_bounty_tier = "stale"
	pre_dp2_target.board_last_seen_times_slept = 999
	assert(WISave.apply(pre_dp2_target, pre_dp2_data), "save missing all 4 DP2 board keys still applies")
	assert(pre_dp2_target.times_slept == 0, "absent times_slept restores 0, not stale data")
	assert(pre_dp2_target.accepted_bounty_id == "", "absent accepted_bounty_id restores \"\", not stale data")
	assert(pre_dp2_target.accepted_bounty_baseline.is_empty(), "absent accepted_bounty_baseline restores {}, not stale data")
	assert(pre_dp2_target.accepted_bounty_tier == "", "absent accepted_bounty_tier restores \"\" -- a legacy save resolves bronze, never a stale lock")
	assert(pre_dp2_target.board_last_seen_times_slept == 0, "absent board_last_seen_times_slept restores 0, not stale data")

	var bad_ts_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_ts_data["state"] as Dictionary)["times_slept"] = "three"
	assert(not WISave.apply(_new_game(), bad_ts_data), "wrong-typed times_slept rejected")
	var bad_abid_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_abid_data["state"] as Dictionary)["accepted_bounty_id"] = 42
	assert(not WISave.apply(_new_game(), bad_abid_data), "wrong-typed accepted_bounty_id rejected")
	var bad_abbl_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_abbl_data["state"] as Dictionary)["accepted_bounty_baseline"] = "nope"
	assert(not WISave.apply(_new_game(), bad_abbl_data), "wrong-typed accepted_bounty_baseline rejected")
	var bad_tier_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_tier_data["state"] as Dictionary)["accepted_bounty_tier"] = 7
	assert(not WISave.apply(_new_game(), bad_tier_data), "wrong-typed accepted_bounty_tier rejected")
	var bad_blsts_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_blsts_data["state"] as Dictionary)["board_last_seen_times_slept"] = "two"
	assert(not WISave.apply(_new_game(), bad_blsts_data), "wrong-typed board_last_seen_times_slept rejected")

	var delivery_original := _new_game()
	delivery_original.accepted_delivery_id = "delivery_krshia_wool"
	delivery_original.accepted_delivery_baseline = {"delivered_delivery_krshia_wool": 0}
	delivery_original.delivery_failed = true
	var delivery_data := WISave.serialize(delivery_original)
	assert(int(delivery_data["version"]) == WISave.VERSION, "DP5 delivery fields do not bump the save version")
	var delivery_restored := _new_game()
	assert(WISave.apply(delivery_restored, delivery_data), "save with DP5 delivery fields applies")
	assert(delivery_restored.accepted_delivery_id == "delivery_krshia_wool", "accepted_delivery_id round-trips")
	assert(delivery_restored.accepted_delivery_baseline == {"delivered_delivery_krshia_wool": 0}, "accepted_delivery_baseline round-trips")
	assert(delivery_restored.delivery_failed == true, "delivery_failed round-trips")

	var pre_dp5_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_dp5_data["state"] as Dictionary).erase("accepted_delivery_id")
	(pre_dp5_data["state"] as Dictionary).erase("accepted_delivery_baseline")
	(pre_dp5_data["state"] as Dictionary).erase("delivery_failed")
	var pre_dp5_target := _new_game()
	pre_dp5_target.accepted_delivery_id = "stale"
	pre_dp5_target.accepted_delivery_baseline = {"stale": 999}
	pre_dp5_target.delivery_failed = true
	assert(WISave.apply(pre_dp5_target, pre_dp5_data), "save missing all 3 DP5 delivery keys still applies")
	assert(pre_dp5_target.accepted_delivery_id == "", "absent accepted_delivery_id restores \"\", not stale data")
	assert(pre_dp5_target.accepted_delivery_baseline.is_empty(), "absent accepted_delivery_baseline restores {}, not stale data")
	assert(pre_dp5_target.delivery_failed == false, "absent delivery_failed restores false, not stale data")

	var bad_adid_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_adid_data["state"] as Dictionary)["accepted_delivery_id"] = 42
	assert(not WISave.apply(_new_game(), bad_adid_data), "wrong-typed accepted_delivery_id rejected")
	var bad_adbl_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_adbl_data["state"] as Dictionary)["accepted_delivery_baseline"] = "nope"
	assert(not WISave.apply(_new_game(), bad_adbl_data), "wrong-typed accepted_delivery_baseline rejected")
	var bad_df_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_df_data["state"] as Dictionary)["delivery_failed"] = "yes"
	assert(not WISave.apply(_new_game(), bad_df_data), "wrong-typed delivery_failed rejected")

	var ghost_data := WISave.serialize(_new_game()).duplicate(true)
	(ghost_data["state"] as Dictionary)["classes"] = {
		"spellsword": 11, "warrior": 7, "mage": 10, "helper": 4}
	var ghost_game := _new_game()
	assert(WISave.apply(ghost_game, ghost_data), "ghost-parent save still applies")
	assert(not ghost_game.classes.has("warrior") and not ghost_game.classes.has("mage"),
		"consolidation-target ghosts stripped on load")
	assert(int(ghost_game.classes.get("spellsword", 0)) == 11 and int(ghost_game.classes.get("helper", 0)) == 4,
		"non-retired classes survive the sanitize untouched")

	# --- 2026-07-26 main-quest restructure (Task 2.6): The Dig backfill. Old
	# saves carry door-chain progress from before horns_dig existed, so a load
	# must leave the sim in a position the fixture-coherence invariant accepts:
	# door_chain_started -> door_mounted -> door_retrieved + pedestal_breached
	# -> horns_dig_joined -> horns_dig_started. (recovered_anchor_stone is
	# deliberately NOT part of the grant -- see save.gd's block.) ---
	var chain_done_state: Dictionary = (WISave.serialize(_new_game())["state"] as Dictionary).duplicate(true)
	chain_done_state["accomplishments"] = {
		"door_chain_started": 1, "door_understood": 1, "recovered_anchor_stone": 1,
		"bought_catalyst": 1, "door_awakened": 1,
	}
	chain_done_state["started_quests"] = ["door_that_goes_elsewhere"]
	var chain_done := _new_game()
	_events.clear()
	assert(WISave.apply(chain_done, {"version": WISave.VERSION, "state": chain_done_state}),
		"a pre-restructure save that finished the whole door chain still applies")
	_assert_dig_backfilled(chain_done, "finished chain")
	assert(_events.is_empty(),
		"the backfill is SILENT -- a restore that re-fired quest completion would toast (and re-grant) the chain the old save already finished")
	assert(chain_done.accomplishment_count("horns_dig_started") == 1,
		"the backfill banks exactly 1 per counter, not one per door-chain flag it matched")
	assert(chain_done.accomplishment_count("recovered_anchor_stone") == 1,
		"a chain save that already fetched the anchor stone keeps its single count")

	var reloaded := _new_game()
	assert(WISave.apply(reloaded, WISave.serialize(chain_done)), "re-saving a migrated save and loading it again applies")
	_assert_dig_backfilled(reloaded, "re-applied")
	assert(reloaded.accomplishment_count("door_mounted") == 1,
		"the backfill is idempotent -- saving a migrated save and reloading does not stack counts")
	assert(reloaded.started_quests.count("horns_dig") == 1, "horns_dig is appended once, never duplicated")

	# Mid-chain: the old flow banked door_chain_started + started the quest at
	# Erin's hub, so the door was 'in play' long before door_awakened.
	var mid_chain_state: Dictionary = (WISave.serialize(_new_game())["state"] as Dictionary).duplicate(true)
	mid_chain_state["accomplishments"] = {"door_chain_started": 1, "door_understood": 1}
	mid_chain_state["started_quests"] = ["door_that_goes_elsewhere"]
	var mid_chain := _new_game()
	assert(WISave.apply(mid_chain, {"version": WISave.VERSION, "state": mid_chain_state}),
		"a pre-restructure save stopped mid-chain (no door_awakened) applies")
	_assert_dig_backfilled(mid_chain, "mid chain")
	assert(mid_chain.accomplishment_count("recovered_anchor_stone") == 0,
		"the backfill does NOT hand out recovered_anchor_stone -- the migrated player still has an anchor stone to fetch (spec 8)")

	# The bare chain start is enough on its own: door_chain_started now MEANS
	# 'the Magical Door is hung at the inn', so it cannot stand without the dig.
	var bare_start_state: Dictionary = (WISave.serialize(_new_game())["state"] as Dictionary).duplicate(true)
	bare_start_state["accomplishments"] = {"door_chain_started": 1}
	var bare_start := _new_game()
	assert(WISave.apply(bare_start, {"version": WISave.VERSION, "state": bare_start_state}),
		"a pre-restructure save that only started the chain applies")
	_assert_dig_backfilled(bare_start, "bare chain start")

	var no_chain := _new_game()
	assert(WISave.apply(no_chain, WISave.serialize(_new_game())), "a save with no door-chain progress applies")
	assert(no_chain.accomplishment_count("horns_dig_started") == 0 and not no_chain.started_quests.has("horns_dig"),
		"a save that never touched the door chain is NOT handed The Dig")

	# A post-restructure save mid-dig must keep its own position: the guard
	# reads horns_dig_started, so nothing skips the player past the breach.
	var mid_dig_state: Dictionary = (WISave.serialize(_new_game())["state"] as Dictionary).duplicate(true)
	mid_dig_state["accomplishments"] = {"horns_dig_started": 1}
	mid_dig_state["started_quests"] = ["horns_dig"]
	var mid_dig := _new_game()
	assert(WISave.apply(mid_dig, {"version": WISave.VERSION, "state": mid_dig_state}),
		"a post-restructure save mid-dig applies")
	assert(mid_dig.accomplishment_count("horns_dig_joined") == 0 and mid_dig.accomplishment_count("door_mounted") == 0,
		"a player who is actually running The Dig is never fast-forwarded past it")

	var meta_game := _new_game()
	meta_game.classes["warrior"] = 2
	var meta_data := WISave.serialize(meta_game)
	var meta := WISave.metadata(meta_data)
	assert(not meta.is_empty(), "a current-version save yields metadata")
	assert(String(meta["pc_name"]) == "Traveler", "everyman default pc_name surfaces in metadata")
	assert(String(meta["top_class"]) == "warrior" and int(meta["top_level"]) == 2, "single-class metadata picks that class")
	assert(String(meta["map"]) == "inn", "current_map surfaces in metadata")

	var multi_game := _new_game()
	multi_game.classes = {"warrior": 3, "mage": 7, "helper": 1}
	var multi_meta := WISave.metadata(WISave.serialize(multi_game))
	assert(String(multi_meta["top_class"]) == "mage" and int(multi_meta["top_level"]) == 7,
		"metadata picks the HIGHEST-level class among several, not the first key")

	var classless_meta := WISave.metadata(WISave.serialize(_new_game()))
	assert(String(classless_meta["top_class"]) == "" and int(classless_meta["top_level"]) == 0,
		"a classless save's metadata carries no class")

	var meta_v2_data := {
		"version": 2,
		"state": {
			"current_map": "inn", "player_cell": [2, 3], "player_facing": [0, 1],
			"classes": {"fighter": 3}, "accomplishments": {}, "player_skills": [],
			"removed_entities": [], "started_quests": [], "rng_state": "12345",
			"inventory": [], "equipped": {}, "container_state": {}, "actions_since_sleep": 0,
			"pc_name": "Bob",
		},
	}
	var v2_meta := WISave.metadata(meta_v2_data)
	assert(not v2_meta.is_empty(), "a migratable v2 save still yields metadata")
	assert(String(v2_meta["top_class"]) == "warrior" and int(v2_meta["top_level"]) == 3,
		"v2's fighter->warrior remap applies to metadata, not just apply()")
	assert(String(v2_meta["pc_name"]) == "Bob", "pc_name surfaces from a migratable older save too")

	assert(WISave.metadata({"version": 1, "state": {}}).is_empty(), "a v1 save (still rejected) yields no metadata")
	assert(WISave.metadata({"version": WISave.VERSION}).is_empty(), "a save with no state Dictionary yields no metadata")
	assert(WISave.metadata({}).is_empty(), "an empty Dictionary yields no metadata")

	var mutate_check := WISave.serialize(_new_game())
	var before_json := JSON.stringify(mutate_check)
	WISave.metadata(mutate_check)
	assert(JSON.stringify(mutate_check) == before_json, "metadata() never mutates its input Dictionary")

	var carrier_data := {
		"version": 2,
		"state": {
			"classes": {"fighter": 3},
			"generalist_classes": ["fighter", "helper"],
			"pending_consolidation": {"parents": ["fighter", "mage"], "target": "fighter", "level": 9},
		},
	}
	var carrier_state: Dictionary = (WISave._migrated(carrier_data) as Dictionary)["state"]
	assert(int((carrier_state["classes"] as Dictionary).get("warrior", 0)) == 3 and not (carrier_state["classes"] as Dictionary).has("fighter"), "carrier remap: classes dict remaps fighter->warrior")
	assert(Array(carrier_state["generalist_classes"]) == ["warrior", "helper"], "carrier remap: generalist_classes rewritten in place, other ids untouched")
	assert(Array((carrier_state["pending_consolidation"] as Dictionary)["parents"]) == ["warrior", "mage"], "carrier remap: pending_consolidation.parents rewritten")
	assert(String((carrier_state["pending_consolidation"] as Dictionary)["target"]) == "warrior", "carrier remap: pending_consolidation.target rewritten")
	var carrier_in_state: Dictionary = carrier_data["state"]
	assert(Array(carrier_in_state["generalist_classes"]) == ["fighter", "helper"], "_migrated leaves the input's generalist_classes untouched")

	# --- a9 #246: the import/export TEXT seam. Export/import are thin
	# game.gd wrappers over exactly these pieces; the text round-trip and
	# every refusal class are pinned HERE (pure, no autoload). ---
	var exp_game := _new_game()
	exp_game.record_accomplishment("slept")
	exp_game.gold = 17
	var exported := JSON.stringify(WISave.serialize(exp_game))
	var reparsed: Variant = JSON.parse_string(exported)
	assert(reparsed is Dictionary, "exported text parses back")
	var imported := _new_game()
	assert(WISave.apply(imported, reparsed), "exported text imports through apply()")
	assert(imported.gold == 17 and imported.accomplishment_count("slept") == 1,
		"imported state is semantically identical (gold + counters survive the text hop)")
	# JSON has no int: the FIRST parse converts ints to floats, so the first
	# re-export differs textually (shipped slot loads already live at the
	# float fixed point — same behavior). The honest byte contract is the
	# FIXED POINT: one more text cycle is byte-stable.
	var exported2 := JSON.stringify(WISave.serialize(imported))
	var imported2 := _new_game()
	assert(WISave.apply(imported2, JSON.parse_string(exported2)), "second-cycle text imports")
	assert(JSON.stringify(WISave.serialize(imported2)) == exported2,
		"the text round-trip reaches its byte fixed point in one cycle (export -> import -> export is stable thereafter)")
	assert(JSON.parse_string(exported2) == JSON.parse_string(exported),
		"deep equality modulo int/float: no field is dropped or mutated across the text hop (review F5 — Dictionary == is recursive and parse float-normalizes both sides)")
	var trunc_parser := JSON.new()
	assert(trunc_parser.parse(exported.substr(0, exported.length() / 2)) != OK,
		"a truncated file fails at parse (import refuses before apply; JSON.new().parse is the SILENT contract — review F4)")
	var wrong_ver: Dictionary = (JSON.parse_string(exported) as Dictionary).duplicate(true)
	wrong_ver["version"] = 99
	assert(not WISave.apply(_new_game(), wrong_ver), "an unknown version refuses")
	var wrong_type: Dictionary = (JSON.parse_string(exported) as Dictionary).duplicate(true)
	(wrong_type["state"] as Dictionary)["player_facing"] = "up"
	assert(not WISave.apply(_new_game(), wrong_type), "a wrong-typed field refuses (the b4 facing trap, now a guarded import path)")
	var victim := _new_game()
	victim.gold = 5
	var victim_before := JSON.stringify(WISave.serialize(victim))
	assert(not WISave.apply(victim, wrong_type), "refused import returns false")
	assert(JSON.stringify(WISave.serialize(victim)) == victim_before,
		"a refused apply leaves the target sim byte-identical (the non-destructive contract's sim half; game.gd uses a TRIAL sim besides)")

	print("PASS: save round-trips the full sim including rng state")
	quit(0)
