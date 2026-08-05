class_name WISceneCatalog
extends RefCounted

const MAPS_DIR := "res://data/maps"
const ROOT_PATH := "res://data/scene_root.json"
## #348 slice 1: the property-interaction table composes into scene_config
## beside the maps, so every WIGame built from compose() is handed it with no
## new constructor parameter (WIGame reads scene_config.interactions and
## injects it into WIFieldSkills -- core itself never touches disk).
const INTERACTIONS_PATH := "res://data/interactions.json"

static var _cache: Dictionary = {}


static func compose() -> Dictionary:
	if _cache.is_empty():
		_cache = _compose()
	return (_cache as Dictionary).duplicate(true)


static func reset() -> void:
	_cache = {}


static func _compose() -> Dictionary:
	var root: Dictionary = _read_json(ROOT_PATH)
	var maps: Dictionary = {}
	for path: String in _sorted_map_paths():
		var map_id: String = path.get_file().get_basename()
		assert(not maps.has(map_id), "duplicate map key '%s' (%s)" % [map_id, path])
		maps[map_id] = _expand_talk_banks(_read_json(path), map_id)
	root["maps"] = maps
	root["interactions"] = _read_json(INTERACTIONS_PATH)
	return root


static func _sorted_map_paths() -> Array[String]:
	var paths: Array[String] = []
	var top: DirAccess = DirAccess.open(MAPS_DIR)
	assert(top != null, "cannot open " + MAPS_DIR)
	for region: String in top.get_directories():
		var region_dir := MAPS_DIR.path_join(region)
		var sub: DirAccess = DirAccess.open(region_dir)
		assert(sub != null, "cannot open " + region_dir)
		for f: String in sub.get_files():
			if f.ends_with(".json"):
				paths.append(region_dir.path_join(f))
	paths.sort()
	return paths


static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


## Talk-line banks (user directive 2026-08-05): 92 of 395 map talk-line slots
## were verbatim copy-paste -- the same line hand-duplicated so it could
## appear under several stage conditions or on a *_returned entity twin. A
## map may now declare `"talk_banks": {"<name>": ["line", ...]}` once, and
## any talk_pool array or talk_pool_stages lines array may splice a bank
## with the entry "@<name>". Expansion happens HERE, at compose time, so
## the sim, the presentation layer, the QA driver and the save system all
## see exactly the shapes that shipped before banks existed. Banks may not
## reference banks (data_lint enforces); an unresolvable ref is a hard
## assert because a silently dropped line pool is a content bug.
const SHARED_TALK_PATH := "res://data/maps/_shared_talk.json"
static var _shared_talk_cache: Dictionary = {}


static func _shared_talk() -> Dictionary:
	if _shared_talk_cache.is_empty() and FileAccess.file_exists(SHARED_TALK_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHARED_TALK_PATH))
		_shared_talk_cache = (parsed as Dictionary).get("banks", {}) if parsed is Dictionary else {}
	return _shared_talk_cache


static func _expand_talk_banks(map: Dictionary, map_id: String) -> Dictionary:
	var banks: Dictionary = map.get("talk_banks", {}).duplicate()
	# Cross-map lines (quest nudges mirrored on two maps) live once in
	# _shared_talk.json; map-local banks resolve first, shadowing forbidden
	# by data_lint.
	for shared_name: String in _shared_talk():
		if not banks.has(shared_name):
			banks[shared_name] = _shared_talk()[shared_name]
	if banks.is_empty():
		return map
	for e: Variant in map.get("entities", []):
		if not (e is Dictionary):
			continue
		var ent := e as Dictionary
		if ent.get("talk_pool") is Array:
			ent["talk_pool"] = _splice_refs(ent["talk_pool"], banks, map_id)
		if ent.get("talk_pool_stages") is Array:
			for st: Variant in ent["talk_pool_stages"]:
				if st is Dictionary and (st as Dictionary).get("lines") is Array:
					(st as Dictionary)["lines"] = _splice_refs((st as Dictionary)["lines"], banks, map_id)
	return map


static func _splice_refs(pool: Array, banks: Dictionary, map_id: String) -> Array:
	var out: Array = []
	for entry: Variant in pool:
		if entry is String and (entry as String).begins_with("@"):
			var name := (entry as String).substr(1)
			assert(banks.has(name), "maps/%s: talk bank '@%s' does not resolve" % [map_id, name])
			for line: Variant in banks[name]:
				out.append(line)
		else:
			out.append(entry)
	return out
