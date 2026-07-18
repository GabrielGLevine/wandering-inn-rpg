class_name WISave
extends RefCounted

const VERSION := 6


const DEPRECATED_IDS := {
	"classes": {"fighter": "warrior"},
	"skills": {},
	"items": {},
	"maps": {},
	"accomplishments": {},
}

## ID deprecation requires DEPRECATED_IDS mapping, every carrier rewrite in
## _migrated(), and MIGRATABLE_ID_CLASSES/tests; missing one strands live saves.
const MIGRATABLE_ID_CLASSES := ["classes"]


static func serialize(game: WIGame) -> Dictionary:
	return {"version": VERSION, "state": {
		"current_map": game.current_map,
		"player_cell": [game.player_cell.x, game.player_cell.y],
		"player_facing": [game.player_facing.x, game.player_facing.y],
		"classes": game.classes.duplicate(true),
		"accomplishments": game.accomplishments.duplicate(true),
		"player_skills": game.player_skills.duplicate(),
		"removed_entities": game.removed_entities.duplicate(),
		"dormant_encounters": game.dormant_encounters.duplicate(),
		"generalist_classes": game.generalist_classes.duplicate(),
		"started_quests": game.started_quests.duplicate(),
		"pending_consolidation": game.pending_consolidation.duplicate(true),
		"used_skills": game.used_skills.duplicate(),
		"seen_statuses": game.seen_statuses.duplicate(),
		"inventory": game.inventory.duplicate(),
		"equipped": game.equipped.duplicate(true),
		"container_state": game.container_state.duplicate(true),
		"actions_since_sleep": game.actions_since_sleep,
		"social_talked": game.social_talked.duplicate(true),
		"entity_first_use": game.entity_first_use.duplicate(true),
		"gold": game.gold,
		"resonance_capacity": game.resonance_capacity,
		"light_active": game.light_active,
		"well_fed": game.well_fed,
		"pending_meal": game.pending_meal.duplicate(true),
		"frozen_cells": game.frozen_cells_json(),
		"hotbar_loadout": game.hotbar_loadout.duplicate(),
		"warded_encounters": game.warded_encounters.duplicate(true),
		"companion": game.companion,
		"companion_source": game.companion_source,
		"pc_name": game.pc_name,
		"pc_race": game.pc_race,
		"pc_gender": game.pc_gender,
		# String required: u64 RNG state exceeds JSON double precision.
		"rng_state": str(game.rng.state),
		"times_slept": game.times_slept,
		"accepted_bounty_id": game.accepted_bounty_id,
		"accepted_bounty_baseline": game.accepted_bounty_baseline.duplicate(true),
		"accepted_bounty_tier": game.accepted_bounty_tier,
		"board_last_seen_times_slept": game.board_last_seen_times_slept,
		"accepted_delivery_id": game.accepted_delivery_id,
		"accepted_delivery_baseline": game.accepted_delivery_baseline.duplicate(true),
		"delivery_failed": game.delivery_failed,
		"delivery_last_seen_times_slept": game.delivery_last_seen_times_slept,
	}}


static func _migrated(data: Dictionary) -> Dictionary:
	if not (data.get("state") is Dictionary):
		return data
	var version := int(data.get("version", -1))
	if version != 2 and version != 3 and version != 4 and version != 5 and version != VERSION:
		return data
	var out: Dictionary = data.duplicate(true)
	var state: Dictionary = out["state"]
	if version == 2:
		state["dormant_encounters"] = []
		version = 3
	if version == 3:
		if String(state.get("current_map", "")) == "street":
			state["player_cell"] = [1, 3]
		version = 4
	if version == 4:
		state["inventory"] = ["rusty_sword"]
		state["equipped"] = {WIKeys.WEAPON: "rusty_sword", "armor": ""}
		state["container_state"] = {}
		state["actions_since_sleep"] = 0
		version = 5
	if version == 5:
		# GH#130: `slept` counter is new; pre-v6 saves banked sleeps only in the
		# times_slept var. Backfill min(times_slept, 1) so the bed nudge never
		# fires at a player twenty sleeps deep (review M1). The cap at 1 is
		# deliberate -- nothing gates above 1 and inventing history is worse.
		var acc: Dictionary = state.get("accomplishments", {})
		if not acc.has("slept") and int(state.get("times_slept", 0)) > 0:
			acc["slept"] = 1
			state["accomplishments"] = acc
		version = VERSION
	out["version"] = version
	var class_map: Dictionary = DEPRECATED_IDS["classes"]
	var cls_raw: Variant = state.get("classes", {})
	if cls_raw is Dictionary:
		var cls: Dictionary = cls_raw
		for old_id: String in class_map:
			if cls.has(old_id):
				var new_id: String = String(class_map[old_id])
				cls[new_id] = maxi(int(cls.get(new_id, 0)), int(cls[old_id]))
				cls.erase(old_id)
	var gen_raw: Variant = state.get("generalist_classes", [])
	if gen_raw is Array:
		var gen: Array = gen_raw
		for i: int in gen.size():
			var gen_id := String(gen[i])
			if class_map.has(gen_id):
				gen[i] = String(class_map[gen_id])
	var pending_raw: Variant = state.get("pending_consolidation", {})
	if pending_raw is Dictionary:
		var pending: Dictionary = pending_raw
		var parents_raw: Variant = pending.get("parents", [])
		if parents_raw is Array:
			var parents: Array = parents_raw
			for i: int in parents.size():
				var parent_id := String(parents[i])
				if class_map.has(parent_id):
					parents[i] = String(class_map[parent_id])
		var target_id := String(pending.get("target", ""))
		if class_map.has(target_id):
			pending["target"] = String(class_map[target_id])
	return out


static func metadata(data: Dictionary) -> Dictionary:
	# Pure preview path: migrate a copy and never apply to WIGame or mutate caller data.
	var migrated := _migrated(data)
	if int(migrated.get("version", -1)) != VERSION:
		return {}
	var raw_state: Variant = migrated.get("state")
	if not (raw_state is Dictionary):
		return {}
	var s: Dictionary = raw_state
	var top_class := ""
	var top_level := 0
	var classes_raw: Variant = s.get("classes", {})
	if classes_raw is Dictionary:
		for id: String in (classes_raw as Dictionary).keys():
			var lvl := int((classes_raw as Dictionary)[id])
			if lvl > top_level:
				top_level = lvl
				top_class = id
	return {
		"pc_name": String(s.get("pc_name", "Traveler")),
		"top_class": top_class,
		"top_level": top_level,
		"map": String(s.get("current_map", "")),
	}


static func apply(game: WIGame, data: Dictionary) -> bool:
	data = _migrated(data)
	if int(data.get("version", -1)) != VERSION:
		return false
	var raw_state: Variant = data.get("state")
	if not (raw_state is Dictionary):
		return false
	var s: Dictionary = raw_state
	var required := ["current_map", "player_cell", "player_facing", "classes", "accomplishments", "player_skills", "removed_entities", "dormant_encounters", "started_quests", "rng_state", "inventory", "equipped", "container_state", "actions_since_sleep"]
	for key: String in required:
		if not s.has(key):
			return false
	if not (s["player_cell"] is Array) or (s["player_cell"] as Array).size() != 2:
		return false
	if not (s["player_facing"] is Array) or (s["player_facing"] as Array).size() != 2:
		return false
	if not (s["classes"] is Dictionary) or not (s["accomplishments"] is Dictionary):
		return false
	if not (s["player_skills"] is Array) or not (s["removed_entities"] is Array) or not (s["started_quests"] is Array):
		return false
	if not (s["dormant_encounters"] is Array):
		return false
	if s.has("generalist_classes") and not (s["generalist_classes"] is Array):
		return false
	if s.has("pending_consolidation") and not (s["pending_consolidation"] is Dictionary):
		return false
	if s.has("used_skills") and not (s["used_skills"] is Array):
		return false
	if s.has("seen_statuses") and not (s["seen_statuses"] is Array):
		return false
	if s.has("social_talked") and not (s["social_talked"] is Dictionary):
		return false
	if s.has("entity_first_use") and not (s["entity_first_use"] is Dictionary):
		return false
	if s.has("gold") and not (s["gold"] is int or s["gold"] is float):
		return false
	if s.has("resonance_capacity") and not (s["resonance_capacity"] is int or s["resonance_capacity"] is float):
		return false
	if s.has("light_active") and not (s["light_active"] is bool):
		return false
	if s.has("well_fed") and not (s["well_fed"] is bool):
		return false
	if s.has("pending_meal") and not (s["pending_meal"] is Dictionary):
		return false
	if s.has("frozen_cells") and not (s["frozen_cells"] is Dictionary):
		return false
	if s.has("hotbar_loadout") and not (s["hotbar_loadout"] is Array):
		return false
	if s.has("warded_encounters") and not (s["warded_encounters"] is Dictionary):
		return false
	if s.has("companion") and not (s["companion"] is String):
		return false
	if s.has("companion_source") and not (s["companion_source"] is String):
		return false
	for pc_key: String in ["pc_name", "pc_race", "pc_gender"]:
		if s.has(pc_key) and not (s[pc_key] is String):
			return false
	if s.has("times_slept") and not (s["times_slept"] is int or s["times_slept"] is float):
		return false
	if s.has("board_last_seen_times_slept") and not (s["board_last_seen_times_slept"] is int or s["board_last_seen_times_slept"] is float):
		return false
	if s.has("accepted_bounty_id") and not (s["accepted_bounty_id"] is String):
		return false
	if s.has("accepted_bounty_baseline") and not (s["accepted_bounty_baseline"] is Dictionary):
		return false
	if s.has("accepted_bounty_tier") and not (s["accepted_bounty_tier"] is String):
		return false
	if s.has("accepted_delivery_id") and not (s["accepted_delivery_id"] is String):
		return false
	if s.has("accepted_delivery_baseline") and not (s["accepted_delivery_baseline"] is Dictionary):
		return false
	if s.has("delivery_failed") and not (s["delivery_failed"] is bool):
		return false
	if s.has("delivery_last_seen_times_slept") and not (s["delivery_last_seen_times_slept"] is int or s["delivery_last_seen_times_slept"] is float):
		return false
	if not (s["inventory"] is Array):
		return false
	if not (s["equipped"] is Dictionary):
		return false
	if not (s["container_state"] is Dictionary):
		return false
	if not (s["actions_since_sleep"] is int or s["actions_since_sleep"] is float):
		return false
	if not game.has_map(String(s["current_map"])):
		return false

	var player_cell: Array = s["player_cell"]
	var player_facing: Array = s["player_facing"]
	var removed_entities: Array = s["removed_entities"]
	var player_skills: Array = s["player_skills"]
	var started_quests: Array = s["started_quests"]
	var dormant_encounters: Array = s["dormant_encounters"]
	var generalist_classes: Array = s.get("generalist_classes", [])
	var pending_consolidation: Dictionary = s.get("pending_consolidation", {})
	var used_skills: Array = s.get("used_skills", [])
	var seen_statuses: Array = s.get("seen_statuses", [])
	var inventory: Array = s["inventory"]
	var equipped: Dictionary = s["equipped"]
	var container_state: Dictionary = s["container_state"]
	var social_talked: Dictionary = s.get("social_talked", {})
	var entity_first_use: Dictionary = s.get("entity_first_use", {})

	game.bind_map_silent(String(s["current_map"]), Vector2i(int(player_cell[0]), int(player_cell[1])))
	game.player_facing = Vector2i(int(player_facing[0]), int(player_facing[1]))
	game.classes = (s["classes"] as Dictionary).duplicate(true)
	for retired_id: String in WIProgression._retired_class_ids(
			game.classes, game._combat_config.get("classes", {})):
		game.classes.erase(retired_id)
	game.accomplishments = (s["accomplishments"] as Dictionary).duplicate(true)
	if int(game.accomplishments.get("reached_two_classes", 0)) < 1 \
			and (game.classes.size() >= 2 or game._holds_consolidated_class()):
		game.accomplishments["reached_two_classes"] = 1
	game.player_skills.clear()
	game.player_skills.assign(player_skills)
	game.removed_entities.clear()
	for id: Variant in removed_entities:
		var entity_id := String(id)
		game.erase_entity_silent(entity_id)
		game.removed_entities.append(entity_id)
	game.started_quests.clear()
	game.started_quests.assign(started_quests)
	game.dormant_encounters.clear()
	game.dormant_encounters.assign(dormant_encounters)
	game.generalist_classes.clear()
	game.generalist_classes.assign(generalist_classes)
	game.pending_consolidation = pending_consolidation.duplicate(true)
	game.used_skills.clear()
	game.used_skills.assign(used_skills)
	game.seen_statuses.clear()
	game.seen_statuses.assign(seen_statuses)
	game.inventory.clear()
	game.inventory.assign(inventory)
	game.equipped = equipped.duplicate(true)
	game.container_state = container_state.duplicate(true)
	game.actions_since_sleep = int(s["actions_since_sleep"])
	game.social_talked = social_talked.duplicate(true)
	game.entity_first_use = entity_first_use.duplicate(true)
	game.gold = int(s.get("gold", 0))
	game.resonance_capacity = int(s.get("resonance_capacity", 2))
	game.light_active = bool(s.get("light_active", false))
	game.well_fed = bool(s.get("well_fed", false))
	game.pending_meal = (s.get("pending_meal", {}) as Dictionary).duplicate(true)
	game.set_frozen_cells_json(s.get("frozen_cells", {}))
	game.hotbar_loadout.clear()
	game.hotbar_loadout.assign(s.get("hotbar_loadout", []))
	game.warded_encounters = (s.get("warded_encounters", {}) as Dictionary).duplicate(true)
	game.companion = String(s.get("companion", ""))
	game.companion_source = String(s.get("companion_source", ""))
	# GH#167 backfill: something_beneath shipped after saves existed mid-arc;
	# the quest normally starts when the runner pointer fires (a one-shot),
	# so mid-arc loads start it here. start_quest is idempotent.
	if int((s.get("accomplishments", {}) as Dictionary).get("watch_runner_pointed", 0)) >= 1 \
			and not game.started_quests.has("something_beneath"):
		game.started_quests.append("something_beneath")
	game.pc_name = WIGame._sanitize_pc_name(String(s.get("pc_name", "Traveler")))
	game.pc_race = WIGame._sanitize_pc_race(String(s.get("pc_race", "human")))
	game.pc_gender = WIGame._sanitize_pc_gender(String(s.get("pc_gender", "m")))
	game.rng.state = int(String(s["rng_state"]))
	game.times_slept = int(s.get("times_slept", 0))
	game.accepted_bounty_id = String(s.get("accepted_bounty_id", ""))
	game.accepted_bounty_baseline = (s.get("accepted_bounty_baseline", {}) as Dictionary).duplicate(true)
	game.accepted_bounty_tier = String(s.get("accepted_bounty_tier", ""))
	game.board_last_seen_times_slept = int(s.get("board_last_seen_times_slept", 0))
	game.accepted_delivery_id = String(s.get("accepted_delivery_id", ""))
	game.accepted_delivery_baseline = (s.get("accepted_delivery_baseline", {}) as Dictionary).duplicate(true)
	game.delivery_failed = bool(s.get("delivery_failed", false))
	game.delivery_last_seen_times_slept = int(s.get("delivery_last_seen_times_slept", 0))
	game.reprime_quests()
	return true
