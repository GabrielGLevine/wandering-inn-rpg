extends SceneTree
## Shipped-ids freeze validator (issue #99, full-game-architecture spec
## §2.1): FAILS LOUD when a frozen id (data/shipped_ids.json) has vanished
## from its live catalog with no covering WISave.DEPRECATED_IDS entry (the
## deprecate-and-map hook, src/core/save.gd) -- the "never rename, only
## deprecate-and-map" policy enforced mechanically. Run:
## /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_shipped_ids.gd
##
## CENSUS DUPLICATION (deliberate, same tradeoff test_fixture_coherence.gd's
## own SKIP const documents against title_screen.gd): this file re-derives
## the SAME accomplishment-counter census scripts/generate_shipped_ids.py
## computes in Python, independently, in GDScript -- the generator can't
## call GDScript and this bare --script idiom can't cheaply import another
## SceneTree-extending script's instance methods without re-running its own
## _init(). KEEP IN SYNC: STRUCTURAL_LITERALS below mirrors the Python
## script's constant of the same name; the scene/dialogue/board/delivery
## scan mirrors its produced_accomplishments() function line for line. A new
## bare `record_accomplishment("literal")` call site, or a new accomplishment
## producer shape, needs an entry added to BOTH files or this validator can
## silently diverge from the freeze list's own generation logic.

const SHIPPED_IDS_PATH := "res://data/shipped_ids.json"
const DIALOGUE_DIR := "res://data/dialogue"

## KEEP IN SYNC with scripts/generate_shipped_ids.py's STRUCTURAL_LITERALS
## (see that file's module docstring, census source 1, for the full trace of
## every bare record_accomplishment()/WICombat._tally() literal call site).
const STRUCTURAL_LITERALS := [
	"observed_things", "befriended_moments", "deliberate_commerce",
	"burned_the_debris", "sneaked_past_danger", "read_the_board",
	"read_the_delivery_board", "door_study_sleeps", "door_awakened",
	"watch_runner_pointed", "reached_two_classes", "garden_door_unlocked",
	"post_game", "melee_hit", "ranged_hit", "spell_cast",
]

var _errors: Array[String] = []


func _init() -> void:
	WITestWatchdog.arm(self)
	var frozen: Dictionary = _load_json(SHIPPED_IDS_PATH)
	var classes: Dictionary = _load_json("res://data/classes.json")
	var skills: Dictionary = _load_json("res://data/skills.json")
	var items: Dictionary = _load_json("res://data/items.json")
	var scene: Dictionary = _load_json("res://data/skeleton_scene.json")
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

	# Structural coverage guard (issue #99 review): a populated
	# DEPRECATED_IDS entry outside WISave.MIGRATABLE_ID_CLASSES is
	# advertised-but-unhandled -- it would turn the freeze check below green
	# while real saves keep the dead id in their state carriers (skills:
	# player_skills/hotbar_loadout/used_skills; items: inventory/equipped;
	# maps: current_map; accomplishments: the accomplishments dict). Checked
	# FIRST so the failure names the missing remap arm, not the frozen id.
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
		# CONTRACT: every suite's success line must start with "PASS" -- CI's
		# unit gate greps ^PASS (see test_fixture_coherence.gd's own note).
		print("PASS: shipped-ids freeze -- %d frozen ids across 5 classes still covered (release %s)" % [total, String(frozen.get("release", "?"))])
	else:
		print("test_shipped_ids: %d failures across %d frozen ids:" % [_errors.size(), total])
		for e: String in _errors:
			print("  SHIPPED_ID_FAIL " + e)
	assert(_errors.is_empty(), "%d shipped-id freeze violations:\n%s" % [_errors.size(), "\n".join(_errors)])
	quit()


## A frozen id "disappeared" iff it is absent from the live catalog set AND
## uncovered by WISave.DEPRECATED_IDS[id_class] -- the deprecate-and-map
## hook. A covering entry must itself point at a LIVE id (a mapping to
## another vanished id is not a real migration).
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


## Mirrors scripts/generate_shipped_ids.py's produced_accomplishments()
## exactly (see this file's own header doc for the KEEP IN SYNC contract).
func _produced_accomplishments(scene: Dictionary, graphs: Dictionary, skills: Dictionary, bounties: Dictionary, deliveries: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for lit: String in STRUCTURAL_LITERALS:
		out[lit] = true

	# Combat action-tally dynamic counters (WICombat._tally_skill_use):
	# "<weapon>_skill_used" per distinct skills.json `weapon` tag,
	# "<element>_cast" per distinct `element` tag.
	for skill: Dictionary in skills.get("skills", []):
		if skill.has("weapon"):
			out["%s_skill_used" % String(skill["weapon"])] = true
		if skill.has("element"):
			out["%s_cast" % String(skill["element"])] = true

	# Scene-derived producers (mirrors test_content.gd's
	# _collect_scene_accomplishments, plus the won_combat structural default
	# WIGame.resolve_combat falls back to for a kind:encounter entity with
	# no authored on_victory -- explicit in every shipped entity today,
	# defensive for tomorrow).
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
			if entity.has("on_interact_accomplishment"):
				out[String(entity["on_interact_accomplishment"])] = true
				for variant: Dictionary in (entity.get("variants", []) as Array):
					if variant.has("accomplishment"):
						out[String(variant["accomplishment"])] = true
			if entity.has("on_open_accomplishment"):
				out[String(entity["on_open_accomplishment"])] = true
			if entity.has("on_enter_accomplishment"):
				out[String(entity["on_enter_accomplishment"])] = true
			if entity.has("talk_pool") and not (entity["talk_pool"] as Array).is_empty():
				out["heard_gossip"] = true
				out["chatted_with_%s" % String(entity["id"])] = true
			for rumor: Dictionary in (entity.get("board_rumors", []) as Array):
				out[String(rumor["banks_accomplishment"])] = true

	# Dialogue-effect producers.
	for graph_id: String in graphs:
		var nodes: Dictionary = graphs[graph_id]["nodes"]
		for node_id: String in nodes:
			for option: Dictionary in (nodes[node_id].get("options", []) as Array):
				for effect: Dictionary in (option.get("effects", []) as Array):
					if effect.has("accomplishment"):
						out[String(effect["accomplishment"])] = true

	# Board/delivery id-derived producers (WIGame.accept_bounty/
	# turn_in_bounty and their Runner's Guild twins bank on the ACCEPTED id,
	# not scannable from any per-entry data field).
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
