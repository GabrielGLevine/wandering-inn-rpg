extends SceneTree

const SHIPPED_IDS_PATH := "res://data/shipped_ids.json"
const DIALOGUE_DIR := "res://data/dialogue"

const STRUCTURAL_LITERALS := [
	"observed_things", "befriended_moments", "deliberate_commerce",
	"burned_the_debris", "sneaked_past_danger", "read_the_board",
	"read_the_delivery_board", "door_study_sleeps", "door_awakened",
	"watch_runner_pointed", "reached_two_classes", "garden_door_unlocked",
	"post_game", "victories", "melee_hit", "ranged_hit", "spell_cast",
	"slept", "completed_delivery", "blinked_past_danger",
	"warded_danger", "witch_craft_used", "second_door_study_sleeps",
	"dungeon_attuned", "catalyst_attunement_sleeps", "resonance_grown",
	"tended_beasts", "finale_played",
	# v017-L5 (GH#332): banked by wi_game._clear_companion, and only on a
	# TAMED downed-clear. Kept on its OWN row under this lane's anchor rather
	# than appended to the line above, so a sibling lane adding its own
	# code-banked counter appends a row instead of colliding on a shared
	# line. Same shape in scripts/generate_shipped_ids.py.
	"companion_lost",
]

var _errors: Array[String] = []


func _init() -> void:
	WITestWatchdog.arm(self)
	var frozen: Dictionary = _load_json(SHIPPED_IDS_PATH)
	var classes: Dictionary = _load_json("res://data/classes.json")
	var skills: Dictionary = _load_json("res://data/skills.json")
	var items: Dictionary = _load_json("res://data/items.json")
	var scene: Dictionary = WISceneCatalog.compose()
	var bounties: Dictionary = _load_json("res://data/bounties.json")
	var deliveries: Dictionary = _load_json("res://data/deliveries.json")
	var graphs: Dictionary = _load_dialogue_graphs()

	var live: Dictionary = {
		"classes": _catalog_ids(classes, "classes"),
		"skills": _catalog_ids(skills, "skills"),
		"items": _catalog_ids(items, "items"),
		"maps": _map_ids(scene),
		"accomplishments": _produced_accomplishments(scene, graphs, skills, bounties, deliveries),
	}

	for id_class: String in (WISave.DEPRECATED_IDS as Dictionary):
		if not ((WISave.DEPRECATED_IDS as Dictionary)[id_class] as Dictionary).is_empty() \
				and not (WISave.MIGRATABLE_ID_CLASSES as Array).has(id_class):
			_errors.append("%s: WISave.DEPRECATED_IDS[\"%s\"] has entries but WISave._migrated() has no remap arm for this id class (absent from MIGRATABLE_ID_CLASSES) -- a mapping only counts once migration code rewrites the save-state carriers; add the remap arm AND extend MIGRATABLE_ID_CLASSES together (see that const's doc comment in save.gd)" % [id_class, id_class])

	var total := 0
	for id_class: String in ["classes", "skills", "items", "maps", "accomplishments"]:
		var frozen_ids: Array = frozen.get(id_class, [])
		total += frozen_ids.size()
		_check_class(id_class, frozen_ids, live[id_class] as Dictionary)

	if _errors.is_empty():
		print("PASS: shipped-ids freeze -- %d frozen ids across 5 classes still covered (release %s)" % [total, String(frozen.get("release", "?"))])
	else:
		print("test_shipped_ids: %d failures across %d frozen ids:" % [_errors.size(), total])
		for e: String in _errors:
			print("  SHIPPED_ID_FAIL " + e)
	assert(_errors.is_empty(), "%d shipped-id freeze violations:\n%s" % [_errors.size(), "\n".join(_errors)])
	quit()


func _check_class(id_class: String, frozen_ids: Array, live_ids: Dictionary) -> void:
	var deprecated: Dictionary = (WISave.DEPRECATED_IDS as Dictionary).get(id_class, {})
	for raw_id: Variant in frozen_ids:
		var id := String(raw_id)
		if live_ids.has(id):
			continue
		if deprecated.has(id):
			var new_id := String(deprecated[id])
			if live_ids.has(new_id):
				continue
			_errors.append("%s: frozen id '%s' is migration-mapped to '%s', but '%s' is ALSO absent from the live catalog -- the mapping target itself must exist" % [id_class, id, new_id, new_id])
			continue
		_errors.append("%s: frozen id '%s' has disappeared from its live catalog with no WISave.DEPRECATED_IDS[\"%s\"] entry -- a shipped id may only be deprecated-and-mapped, never silently dropped (spec §2.1)" % [id_class, id, id_class])


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _load_dialogue_graphs() -> Dictionary:
	var graphs: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	assert(dir != null, "missing dialogue directory")
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			graphs[file_name.get_basename()] = _load_json(DIALOGUE_DIR.path_join(file_name))
	return graphs


func _catalog_ids(catalog: Dictionary, key: String) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in catalog.get(key, []):
		out[String(entry["id"])] = true
	return out


func _map_ids(scene: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id: String in scene["maps"]:
		out[map_id] = true
	return out


func _produced_accomplishments(scene: Dictionary, graphs: Dictionary, skills: Dictionary, bounties: Dictionary, deliveries: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for lit: String in STRUCTURAL_LITERALS:
		out[lit] = true

	for skill: Dictionary in skills.get("skills", []):
		if skill.has("weapon"):
			out["%s_skill_used" % String(skill["weapon"])] = true
		if skill.has("element"):
			out["%s_cast" % String(skill["element"])] = true

	for map_id: String in scene["maps"]:
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in map.get("entities", []):
			if String(entity.get("kind", "")) == "encounter":
				var victory: Variant = entity.get("on_victory", "won_combat")
				var victory_ids: Array = victory if victory is Array else [victory]
				for id: Variant in victory_ids:
					out[String(id)] = true
			if entity.has("on_skill_use"):
				var skill_use: Dictionary = entity["on_skill_use"]
				if skill_use.has("accomplishment"):
					out[String(skill_use["accomplishment"])] = true
				for variant: Dictionary in (skill_use.get("variants", []) as Array):
					if variant.has("accomplishment"):
						out[String(variant["accomplishment"])] = true
			for sid: String in (entity.get("skill_uses", {}) as Dictionary):
				var arm: Dictionary = (entity["skill_uses"] as Dictionary)[sid]
				if arm.has("accomplishment"):
					out[String(arm["accomplishment"])] = true
			if entity.has("on_interact_accomplishment"):
				out[String(entity["on_interact_accomplishment"])] = true
				for variant: Dictionary in (entity.get("variants", []) as Array):
					if variant.has("accomplishment"):
						out[String(variant["accomplishment"])] = true
			# Task 2.3: String|Array, the on_victory contract.
			var open_banks: Variant = entity.get("on_open_accomplishment", [])
			for counter: Variant in (open_banks if open_banks is Array else [open_banks]):
				out[String(counter)] = true
			if entity.has("on_enter_accomplishment"):
				out[String(entity["on_enter_accomplishment"])] = true
			if entity.has("talk_pool") and not (entity["talk_pool"] as Array).is_empty():
				out["heard_gossip"] = true
				out["chatted_with_%s" % String(entity["id"])] = true
			for rumor: Dictionary in (entity.get("board_rumors", []) as Array):
				out[String(rumor["banks_accomplishment"])] = true

	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				for effect: Dictionary in (option.get("effects", []) as Array):
					if effect.has("accomplishment"):
						out[String(effect["accomplishment"])] = true

	for bounty: Dictionary in bounties.get("bounties", []):
		var bid: String = String(bounty["id"])
		out["accepted_bounty_%s" % bid] = true
		out["completed_bounty_%s" % bid] = true
	for delivery: Dictionary in deliveries.get("deliveries", []):
		var did: String = String(delivery["id"])
		out["accepted_delivery_%s" % did] = true
		out["delivered_%s" % did] = true
		out["completed_delivery_%s" % did] = true

	return out
