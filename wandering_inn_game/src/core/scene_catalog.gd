class_name WISceneCatalog
extends RefCounted

const MAPS_DIR := "res://data/maps"
const ROOT_PATH := "res://data/scene_root.json"

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
		maps[map_id] = _read_json(path)
	root["maps"] = maps
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
