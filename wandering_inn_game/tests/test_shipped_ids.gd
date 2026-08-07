extends SceneTree

const SHIPPED_IDS_PATH := "res://data/shipped_ids.json"
const DIALOGUE_DIR := "res://data/dialogue"
const GENERATOR_PATH := "res://scripts/generate_shipped_ids.py"

const STRUCTURAL_LITERALS := [
	"observed_things", "befriended_moments", "deliberate_commerce",
	"burned_the_debris", "cut_through_growth", "sneaked_past_danger", "read_the_board",
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

## RETIRED accomplishments (#396 ruling 9) -- THE registry for the one legal way
## a shipped counter loses every producer: the quest that banked it is retired
## for NEW saves (offer row deleted) while the counter, its quest def and its
## legacy CONSUMERS stay forever so mid-quest legacy saves still complete. Read
## here (freeze check), in test_reachability (zero-producer gate) and in
## test_content (unproduced-gate checks) -- all three already preload this file.
## Retiring is not deprecating: there is no successor id to migrate a save TO,
## so WISave.DEPRECATED_IDS is the wrong tool. A NEW PRODUCER of a retired id
## fails loudly in `_check_retired` -- retirement is one-way.
const RETIRED_ACCOMPLISHMENTS := {
	"heard_thicket_keeps": "_comment: retired 2026-08-05 (#396). what_the_thicket_keeps' offer row deleted from riverfarm_hunter.json's hub; the quest def and its 5 consumers (4 hub rows + witch_hollow.thicket_line_den.encounter_when) stay legal. Successor: heard_winter_teeth (a_winter_of_teeth).",
}

var _errors: Array[String] = []


func _init() -> void:
	WITestWatchdog.arm(self)
	var generator_source := FileAccess.get_file_as_string(GENERATOR_PATH)
	var generator_retired := _generator_retired_accomplishments(generator_source)
	var mirror_error := _retired_mirror_error(generator_retired)
	if mirror_error != "":
		_errors.append(mirror_error)
	var drift_source := generator_source.replace(
		'FROZEN_RETIRED_ACCOMPLISHMENTS = ["heard_thicket_keeps"]',
		'FROZEN_RETIRED_ACCOMPLISHMENTS = ["mirror_drift"]')
	assert(drift_source != generator_source,
		"retired-accomplishment mirror mutation must alter the generator fixture")
	assert(_retired_mirror_error(_generator_retired_accomplishments(drift_source)) != "",
		"retired-accomplishment mirror check must fail on generator/test drift")
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
	_check_retired(frozen.get("accomplishments", []), live["accomplishments"] as Dictionary)

	if _errors.is_empty():
		print("PASS: shipped-ids freeze -- %d frozen ids across 5 classes still covered (release %s)" % [total, String(frozen.get("release", "?"))])
	else:
		print("test_shipped_ids: %d failures across %d frozen ids:" % [_errors.size(), total])
		for e: String in _errors:
			print("  SHIPPED_ID_FAIL " + e)
	assert(_errors.is_empty(), "%d shipped-id freeze violations:\n%s" % [_errors.size(), "\n".join(_errors)])
	quit()


func _generator_retired_accomplishments(source: String) -> Array:
	var marker := "FROZEN_RETIRED_ACCOMPLISHMENTS = "
	if source.find(marker) == -1:
		return []
	var literal := source.get_slice(marker, 1).get_slice("\n", 0)
	var parsed: Variant = JSON.parse_string(literal)
	return parsed if parsed is Array else []


func _retired_mirror_error(generator_ids: Array) -> String:
	var generator_sorted: Array = generator_ids.duplicate()
	var test_sorted: Array = RETIRED_ACCOMPLISHMENTS.keys()
	generator_sorted.sort()
	test_sorted.sort()
	if generator_sorted == test_sorted:
		return ""
	return ("accomplishments: MIRROR CONTRACT drift between generate_shipped_ids.py " \
		+ "FROZEN_RETIRED_ACCOMPLISHMENTS %s and test_shipped_ids.gd " \
		+ "RETIRED_ACCOMPLISHMENTS %s") % [generator_sorted, test_sorted]


func _check_class(id_class: String, frozen_ids: Array, live_ids: Dictionary) -> void:
	var deprecated: Dictionary = (WISave.DEPRECATED_IDS as Dictionary).get(id_class, {})
	for raw_id: Variant in frozen_ids:
		var id := String(raw_id)
		if live_ids.has(id):
			continue
		if id_class == "accomplishments" and RETIRED_ACCOMPLISHMENTS.has(id):
			continue
		if deprecated.has(id):
			var new_id := String(deprecated[id])
			if live_ids.has(new_id):
				continue
			_errors.append("%s: frozen id '%s' is migration-mapped to '%s', but '%s' is ALSO absent from the live catalog -- the mapping target itself must exist" % [id_class, id, new_id, new_id])
			continue
		_errors.append("%s: frozen id '%s' has disappeared from its live catalog with no WISave.DEPRECATED_IDS[\"%s\"] entry -- a shipped id may only be deprecated-and-mapped, never silently dropped (spec §2.1)" % [id_class, id, id_class])


## Retirement is one-way and never a place to park a typo: every row must carry a
## justification, still be FROZEN (else it was never shipped and needs no
## exemption), and have NO live producer (a new one means the counter came back --
## delete the row instead of letting it mask a real freeze violation).
func _check_retired(frozen_ids: Array, live_ids: Dictionary) -> void:
	for id: String in RETIRED_ACCOMPLISHMENTS:
		if not String(RETIRED_ACCOMPLISHMENTS[id]).begins_with("_comment:"):
			_errors.append("accomplishments: RETIRED_ACCOMPLISHMENTS['%s'] needs an _comment-style justification" % id)
		if not frozen_ids.has(id):
			_errors.append("accomplishments: RETIRED_ACCOMPLISHMENTS['%s'] is not a frozen shipped id -- an unshipped counter needs no retirement exemption, it needs its producer" % id)
		if live_ids.has(id):
			_errors.append("accomplishments: RETIRED_ACCOMPLISHMENTS['%s'] has a LIVE PRODUCER again -- retirement is one-way; drop the registry row rather than let it mask a freeze violation" % id)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _load_dialogue_graphs() -> Dictionary:
	var graphs: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DIALOGUE_DIR)
	assert(dir != null, "missing dialogue directory")
	for file_name: String in dir.get_files():
		# Underscore files are line banks, never graphs -- indexing ["nodes"]
		# on one aborted the whole producer scan (every id after the crash
		# read as "disappeared").
		if file_name.ends_with(".json") and not file_name.begins_with("_"):
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


## #348 slice 2 + #398-p2: the table's CARRIER-sourced counters, authored on the
## prop under the field each row's `counter_key` names. Two row shapes feed it --
## `state_set` (carrier-sourced by substrate) and any row declaring counter_from
## "target" (a row-defaulted verb whose carrier overrides the shared id). Derived
## from the table (not hardcoded) so a new row registers its carriers with no
## edit here, and so deleting a carrier's field DROPS the id from the freeze list
## -- the exact mirror of generate_shipped_ids.py's _carrier_counter_keys.
func _carrier_counter_keys() -> Array:
	var keys: Array = []
	for row: Variant in (WISceneCatalog.compose().get("interactions", {}) as Dictionary).get("interactions", []):
		if not (row is Dictionary):
			continue
		var r := row as Dictionary
		if String(r.get("counter_key", "")) == "":
			continue
		if String(r.get("outcome", "")) == "state_set" or String(r.get("counter_from", "")) == "target":
			var key := String(r["counter_key"])
			if not keys.has(key):
				keys.append(key)
	return keys


## String|Array -> every id the arm banks (the on_victory/on_open contract).
func _note_banked(raw: Variant, out: Dictionary) -> void:
	for counter: Variant in (raw if raw is Array else [raw]):
		out[String(counter)] = true


func _produced_accomplishments(scene: Dictionary, graphs: Dictionary, skills: Dictionary, bounties: Dictionary, deliveries: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for lit: String in STRUCTURAL_LITERALS:
		out[lit] = true
	var carrier_counter_keys := _carrier_counter_keys()

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
				# v0.17 close: combat_banking banks fought_<encounter_id> on
				# every victory — third parity participant with the generator
				# and test_content:647 (the freeze regen that missed this arm
				# went red on exactly the 40 ids it froze).
				out["fought_%s" % String(entity["id"])] = true
			# #398-P3: String|Array here too (the on_open_accomplishment
			# contract below) -- the fourth mirror of the same walk.
			if entity.has("on_skill_use"):
				var skill_use: Dictionary = entity["on_skill_use"]
				if skill_use.has("accomplishment"):
					_note_banked(skill_use["accomplishment"], out)
				for variant: Dictionary in (skill_use.get("variants", []) as Array):
					if variant.has("accomplishment"):
						_note_banked(variant["accomplishment"], out)
			for sid: String in (entity.get("skill_uses", {}) as Dictionary):
				var arm: Dictionary = (entity["skill_uses"] as Dictionary)[sid]
				if arm.has("accomplishment"):
					_note_banked(arm["accomplishment"], out)
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
			for carrier_key: String in carrier_counter_keys:
				if String(entity.get(carrier_key, "")) != "":
					out[String(entity[carrier_key])] = true
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
