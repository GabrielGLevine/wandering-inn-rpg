extends SceneTree
## Headless test for pure save serialization and restore.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_save.gd

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
	return WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, _combat_config())


func _init() -> void:
	WITestWatchdog.arm(self)
	var original := _new_game()
	original.move_player(Vector2i.UP)
	original.transition("street", Vector2i(4, 3))
	original.player_facing = Vector2i.RIGHT
	original.classes["warrior"] = 2
	original.player_skills.append("flame_bolt")
	original.used_skills.append("basic_cleaning")
	original.record_accomplishment("package_delivered")
	original.record_accomplishment("won_combat")
	original.remove_entity("goblin_encounter_2")
	original.start_quest("the_errand")
	original.rng.randi()
	# M7 Task E2: exercise inventory/equipped/container_state/actions_since_sleep
	# through the round-trip too (pickup/equip so the invariant holds, plus a
	# container mark and a nonzero action count).
	original.pickup("leather_jerkin", "inn_chest")
	original.equip("leather_jerkin")
	original.container_state["inn_chest"] = true
	original.actions_since_sleep = 7
	# Playtest feature 3: the [Light] PC-glow flag round-trips (additive-optional,
	# default false) so a load restores the conjured orb.
	original.light_active = true
	# M-ARC §5: cosmetic identity round-trips (additive-optional; default
	# Human/male/"Traveler"). A non-default trio here proves persistence.
	original.pc_name = "Sella"
	original.pc_race = "drake"
	original.pc_gender = "f"

	var data := WISave.serialize(original)
	assert(data["version"] == WISave.VERSION, "save version matches the current constant")
	assert(data["state"]["rng_state"] is String, "rng state serializes as string")

	# M5 final review: an older-version save is rejected, never applied with
	# stale layout coordinates (v1 player_cell can sit inside E3 furniture).
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
	# M7 Task E2: inventory/equipped/container_state/actions_since_sleep restore.
	assert(restored.inventory == original.inventory, "inventory restored")
	assert(restored.equipped == original.equipped, "equipped restored")
	assert(restored.equipped == {"weapon": "rusty_sword", "armor": "leather_jerkin"}, "equip() landed in the equipped dict as expected")
	assert(restored.inventory.has("rusty_sword") and restored.inventory.has("leather_jerkin"), "inventory carries both the starter sword and the picked-up armor")
	assert(restored.container_state == original.container_state, "container_state restored")
	assert(int(restored.actions_since_sleep) == 7, "actions_since_sleep restored")
	assert(restored.light_active == original.light_active, "light_active restored")
	assert(restored.light_active == true, "light_active round-trips as true")
	# Additive-optional default: a save with no light_active key restores false.
	var no_glow: Dictionary = (data["state"] as Dictionary).duplicate(true)
	no_glow.erase("light_active")
	var glow_target := _new_game()
	assert(WISave.apply(glow_target, {"version": WISave.VERSION, "state": no_glow}), "save without light_active still applies")
	assert(glow_target.light_active == false, "absent light_active defaults false")
	# M-ARC §5: cosmetic identity restores.
	assert(restored.pc_name == "Sella", "pc_name restored")
	assert(restored.pc_race == "drake", "pc_race restored")
	assert(restored.pc_gender == "f", "pc_gender restored")
	# Additive-optional default: a save with no identity keys restores the everyman.
	var no_identity: Dictionary = (data["state"] as Dictionary).duplicate(true)
	for k in ["pc_name", "pc_race", "pc_gender"]:
		no_identity.erase(k)
	var id_target := _new_game()
	assert(WISave.apply(id_target, {"version": WISave.VERSION, "state": no_identity}), "save without pc identity still applies")
	assert(id_target.pc_name == "Traveler" and id_target.pc_race == "human" and id_target.pc_gender == "m", "absent pc identity defaults to Human/male/Traveler")
	# Tolerant sanitize on load: blank name / unknown race+gender collapse to defaults.
	var garbage: Dictionary = (data["state"] as Dictionary).duplicate(true)
	garbage["pc_name"] = "   "
	garbage["pc_race"] = "elf"
	garbage["pc_gender"] = "x"
	var g_target := _new_game()
	assert(WISave.apply(g_target, {"version": WISave.VERSION, "state": garbage}), "garbage pc identity still applies")
	assert(g_target.pc_name == "Traveler" and g_target.pc_race == "human" and g_target.pc_gender == "m", "garbage pc identity sanitized to defaults")
	# A present-but-wrong-typed pc field is rejected (mirrors the light_active guard).
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

	## malformed-state rejection coverage
	# Case 1: missing "state" key
	var m1_target := _new_game()
	var m1_snapshot := m1_target.snapshot()
	var m1_rng_state := m1_target.rng.state
	assert(not WISave.apply(m1_target, {"version": 1}), "missing state key rejected")
	assert(m1_target.snapshot() == m1_snapshot, "missing state leaves snapshot untouched")
	assert(m1_target.rng.state == m1_rng_state, "missing state leaves rng untouched")
	assert(not m1_target.find_entity("goblin_encounter_2").is_empty(), "missing state leaves entities untouched")

	# Case 2: player_cell truncated to 1-element array
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

	# Case 3: classes replaced with wrong type (string)
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

	# Case 4: rng_state key deleted
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

	# Case 5: current_map not in this build's content (e.g. save from a
	# content version with a map since removed/renamed)
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

	# --- M6 T2: dormant respawning encounters persist (VERSION 3) ---
	var resp_original := _new_game()
	resp_original.dormant_encounters.append("goblin_encounter_2")
	var resp_data := WISave.serialize(resp_original)
	assert(int(resp_data["version"]) == WISave.VERSION, "serialize tags the current VERSION constant (M6 T2 bumped 2->3; M-FP F fix bumped 3->4)")
	var resp_restored := _new_game()
	assert(WISave.apply(resp_restored, resp_data), "v3 save applies")
	assert(resp_restored.dormant_encounters == resp_original.dormant_encounters, "dormancy round-trips")

	# A v2 save (pre-M6, no dormant_encounters key) migrates transparently:
	# nothing was dormant when v2 was written, so nothing is dormant after.
	var v2_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	v2_data["version"] = 2
	(v2_data["state"] as Dictionary).erase("dormant_encounters")
	var v2_target := _new_game()
	v2_target.dormant_encounters.append("stale_entry")
	assert(WISave.apply(v2_target, v2_data), "v2 save migrates and applies")
	assert(v2_target.dormant_encounters.is_empty(), "migrated v2 save carries no dormancy")

	# A v3 save MISSING the dormant_encounters key is malformed, not migratable.
	var m6_corrupt := WISave.serialize(resp_original).duplicate(true)
	(m6_corrupt["state"] as Dictionary).erase("dormant_encounters")
	assert(not WISave.apply(_new_game(), m6_corrupt), "v3 save without dormant_encounters rejected")

	# --- M6 T3: generalist_classes persists WITHOUT a version bump ---
	var gen_original := _new_game()
	gen_original.generalist_classes.append("mage")
	var gen_data := WISave.serialize(gen_original)
	assert(int(gen_data["version"]) == WISave.VERSION, "M6 T3 does not bump the save version (still tags the current VERSION constant)")
	var gen_restored := _new_game()
	assert(WISave.apply(gen_restored, gen_data), "save with generalist_classes applies")
	assert(gen_restored.generalist_classes == gen_original.generalist_classes, "generalist_classes round-trips")

	# A save WITHOUT the generalist_classes key (any save written before this
	# task) is not malformed -- it is absent-safe and restores empty (no
	# class had gone generalist yet, which is exactly correct).
	var pre_t3_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_t3_data["state"] as Dictionary).erase("generalist_classes")
	var pre_t3_target := _new_game()
	pre_t3_target.generalist_classes.append("stale_entry")
	assert(WISave.apply(pre_t3_target, pre_t3_data), "save missing generalist_classes still applies")
	assert(pre_t3_target.generalist_classes.is_empty(), "absent generalist_classes restores empty, not stale data")

	# A present-but-wrong-typed generalist_classes IS rejected as malformed.
	var bad_gen_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_gen_data["state"] as Dictionary)["generalist_classes"] = "mage"
	assert(not WISave.apply(_new_game(), bad_gen_data), "wrong-typed generalist_classes rejected")

	# --- M6 T5: pending_consolidation persists WITHOUT a version bump ---
	# (the T3 generalist_classes precedent: additive optional key, no bump).
	var pending_original := _new_game()
	pending_original.pending_consolidation = {"parents": ["warrior", "mage"], "target": "spellsword", "level": 14}
	var pending_data := WISave.serialize(pending_original)
	assert(int(pending_data["version"]) == WISave.VERSION, "M6 T5 does not bump the save version (still tags the current VERSION constant)")
	var pending_restored := _new_game()
	assert(WISave.apply(pending_restored, pending_data), "save with pending_consolidation applies")
	assert(pending_restored.pending_consolidation == pending_original.pending_consolidation, "pending_consolidation round-trips")

	# A save WITHOUT the pending_consolidation key (any save written before
	# this task, or a save with no offer pending) is not malformed -- it is
	# absent-safe and restores an empty Dictionary (no offer was pending,
	# which is exactly correct).
	var pre_t5_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_t5_data["state"] as Dictionary).erase("pending_consolidation")
	var pre_t5_target := _new_game()
	pre_t5_target.pending_consolidation = {"parents": ["warrior", "mage"], "target": "spellsword", "level": 14}
	assert(WISave.apply(pre_t5_target, pre_t5_data), "save missing pending_consolidation still applies")
	assert(pre_t5_target.pending_consolidation.is_empty(), "absent pending_consolidation restores empty, not stale data")

	# A present-but-wrong-typed pending_consolidation IS rejected as malformed.
	var bad_pending_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_pending_data["state"] as Dictionary)["pending_consolidation"] = "spellsword"
	assert(not WISave.apply(_new_game(), bad_pending_data), "wrong-typed pending_consolidation rejected")

	# --- UI wave item 19: used_skills persists WITHOUT a version bump ---
	# (the T3/T5 additive-optional precedent: no bump, absent-safe default []).
	var used_original := _new_game()
	used_original.used_skills.append("power_strike")
	var used_data := WISave.serialize(used_original)
	assert(int(used_data["version"]) == WISave.VERSION, "used_skills does not bump the save version (still tags the current VERSION constant)")
	var used_restored := _new_game()
	assert(WISave.apply(used_restored, used_data), "save with used_skills applies")
	assert(used_restored.used_skills == used_original.used_skills, "used_skills round-trips")

	# A save WITHOUT the used_skills key (any v4 save written before this
	# task) is not malformed -- it is absent-safe and restores empty (nothing
	# had been revealed yet, which is exactly correct).
	var pre_ui_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_ui_data["state"] as Dictionary).erase("used_skills")
	var pre_ui_target := _new_game()
	pre_ui_target.used_skills.append("stale_entry")
	assert(WISave.apply(pre_ui_target, pre_ui_data), "save missing used_skills still applies")
	assert(pre_ui_target.used_skills.is_empty(), "absent used_skills restores empty, not stale data")

	# A present-but-wrong-typed used_skills IS rejected as malformed.
	var bad_used_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_used_data["state"] as Dictionary)["used_skills"] = "power_strike"
	assert(not WISave.apply(_new_game(), bad_used_data), "wrong-typed used_skills rejected")

	# --- M-FP final review fix: VERSION 4 street relayout migration ---
	# W1 re-laid out street 10x6 -> 32x20 without a save version bump; a v3
	# street save's player_cell can now sit in a cell that's blocked in the
	# new layout ((0,0) and (0,5) are full softlocks -- all 4 neighbors
	# blocked). The fix migrates (not rejects) v3 street saves forward to
	# VERSION 4, relocating player_cell to the liscor_gate arrival cell [1,3].
	# M7 Task E2 bumped VERSION again, 4 -> 5 (weapons+equipment); the v3->v4
	# street-relocation step below still composes correctly underneath it.
	assert(WISave.VERSION == 5, "VERSION bumped to 5 for M7 weapons+equipment")

	# Case A: a synthetic v3 save on "street" at a now-blocked cell migrates
	# to v4 with player_cell relocated to [1,3] -- every other field (map,
	# facing, classes, accomplishments) passes through untouched.
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
	# (JSON round-trip turns 3 into 3.0; Dictionary == is type-strict on
	# values, so compare via int() rather than a literal Dictionary.)
	assert(street_v3_target.classes.size() == 1 and int(street_v3_target.classes.get("warrior", 0)) == 3, "classes is untouched by the relocation")
	assert(int(street_v3_target.accomplishments.get("browsed_market", 0)) == 1, "accomplishments are untouched by the relocation")

	# Case B: a v3 save on a map OTHER than street (inn) migrates with its
	# player_cell fully untouched -- the relocation is street-scoped only.
	var inn_v3_original := _new_game()
	inn_v3_original.move_player(Vector2i.RIGHT)
	var inn_v3_expected_cell := inn_v3_original.player_cell
	var inn_v3_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(inn_v3_original)))
	inn_v3_data["version"] = 3
	var inn_v3_target := _new_game()
	assert(WISave.apply(inn_v3_target, inn_v3_data), "v3 inn save migrates and applies")
	assert(inn_v3_target.current_map == "inn", "inn save keeps current_map")
	assert(inn_v3_target.player_cell == inn_v3_expected_cell, "v3 inn save's player_cell is untouched by the v3->v4 step")

	# Case C: a v2 save on street COMPOSES both migration steps (v2->v3 then
	# v3->v4) in one _migrated() call -- proves the chain composes rather
	# than switch-casing a single hop and skipping the second step.
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

	# --- M7 Task E2: VERSION 5 weapons+equipment migration ---
	# A v4 save (any save written before this task) has none of
	# inventory/equipped/container_state/actions_since_sleep -- _migrated
	# fills in the plan's tolerant defaults, preserving the "equipped items
	# are also in inventory" invariant equip() maintains going forward:
	# inventory ["rusty_sword"], equipped {"weapon":"rusty_sword","armor":""}.
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

	# A v5-tagged save MISSING any of the four new required keys is malformed
	# (they are REQUIRED, not the additive-optional T3/T5/UI-wave pattern) --
	# rejected, not silently defaulted (migration only fires for version < VERSION).
	for missing_key: String in ["inventory", "equipped", "container_state", "actions_since_sleep"]:
		var m7_missing_data: Dictionary = WISave.serialize(_new_game()).duplicate(true)
		(m7_missing_data["state"] as Dictionary).erase(missing_key)
		assert(not WISave.apply(_new_game(), m7_missing_data), "v5 save missing '%s' is rejected, not defaulted" % missing_key)

	# Present-but-wrong-typed values for each new field are rejected too.
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

	# A v2 save COMPOSES ALL FOUR migration steps (v2->v3->v4->v5) in one call.
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

	# --- Social Pillar S1: social_talked + entity_first_use persist WITHOUT a
	# version bump (the T3/T5/UI-wave additive-optional precedent). A mid-waking
	# save/reload must NOT re-arm an already-spent talk-pool line or first-use bank.
	var social_original := _new_game()
	social_original.social_talked["krshia"] = true
	social_original.entity_first_use["observe:krshia"] = true
	var social_data := WISave.serialize(social_original)
	assert(int(social_data["version"]) == WISave.VERSION, "S1 does not bump the save version (still tags the current VERSION constant)")
	var social_restored := _new_game()
	assert(WISave.apply(social_restored, social_data), "save with social_talked/entity_first_use applies")
	assert(social_restored.social_talked == social_original.social_talked, "social_talked round-trips")
	assert(social_restored.entity_first_use == social_original.entity_first_use, "entity_first_use round-trips")

	# A save WITHOUT either key (any save written before this task) is absent-safe
	# and restores empty Dictionaries (a fresh waking has done no small-talk / bank).
	var pre_s1_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_s1_data["state"] as Dictionary).erase("social_talked")
	(pre_s1_data["state"] as Dictionary).erase("entity_first_use")
	var pre_s1_target := _new_game()
	pre_s1_target.social_talked["stale"] = true
	pre_s1_target.entity_first_use["stale:x"] = true
	assert(WISave.apply(pre_s1_target, pre_s1_data), "save missing the S1 keys still applies")
	assert(pre_s1_target.social_talked.is_empty(), "absent social_talked restores empty, not stale data")
	assert(pre_s1_target.entity_first_use.is_empty(), "absent entity_first_use restores empty, not stale data")

	# Present-but-wrong-typed values for each new field are rejected as malformed.
	var bad_social_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_social_data["state"] as Dictionary)["social_talked"] = "krshia"
	assert(not WISave.apply(_new_game(), bad_social_data), "wrong-typed social_talked rejected")
	var bad_efu_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_efu_data["state"] as Dictionary)["entity_first_use"] = ["observe:krshia"]
	assert(not WISave.apply(_new_game(), bad_efu_data), "wrong-typed entity_first_use rejected")

	# --- Economy v1 Task D1: gold (additive-optional, tolerant default 0) ---
	var gold_original := _new_game()
	gold_original.gold = 42
	var gold_data := WISave.serialize(gold_original)
	assert(int(gold_data["version"]) == WISave.VERSION, "gold does not bump the save version")
	var gold_restored := _new_game()
	assert(WISave.apply(gold_restored, gold_data), "save with gold applies")
	assert(gold_restored.gold == 42, "gold round-trips")
	# A save WITHOUT the key (any save written before Economy v1) restores 0.
	var pre_gold_data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(_new_game())))
	(pre_gold_data["state"] as Dictionary).erase("gold")
	var pre_gold_target := _new_game()
	pre_gold_target.gold = 999
	assert(WISave.apply(pre_gold_target, pre_gold_data), "save missing the gold key still applies")
	assert(pre_gold_target.gold == 0, "absent gold restores 0, not stale data")
	# A present-but-wrong-typed gold value is rejected as malformed.
	var bad_gold_data := WISave.serialize(_new_game()).duplicate(true)
	(bad_gold_data["state"] as Dictionary)["gold"] = "lots"
	assert(not WISave.apply(_new_game(), bad_gold_data), "wrong-typed gold rejected")

	print("PASS: save round-trips the full sim including rng state")
	quit(0)
