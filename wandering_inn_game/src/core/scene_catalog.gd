class_name WISceneCatalog
extends RefCounted
## Composes data/maps/<region>/<map>.json + data/scene_root.json into the
## EXACT dict shape data/skeleton_scene.json used to hand WIGame directly
## ({start_map, player, maps}) -- issue #100 / full-game architecture spec
## 2.2. The split's whole point is killing the single-file merge hotspot;
## region dirs are the new disjoint lane surface (see wi-adding-a-scene).
##
## The ONE seam: every consumer (Game autoload's sim-config assembly,
## WIDataRegistry's presentation cache, tools/scene_dynamism.gd, every
## `--script` test building its own WIGame) calls compose() instead of
## reading data/skeleton_scene.json directly. Cached after first call
## (data is static shipped content, never edited mid-run); always returns
## a fresh `duplicate(true)` so callers can't mutate the shared cache.

const MAPS_DIR := "res://data/maps"
const ROOT_PATH := "res://data/scene_root.json"

static var _cache: Dictionary = {}


static func compose() -> Dictionary:
	if _cache.is_empty():
		_cache = _compose()
	return (_cache as Dictionary).duplicate(true)


## Drops the cache so the next compose() call rereads from disk. Mirrors
## WIDataRegistry.reset()'s contract; no shipped caller needs this today
## (content is static) but tests can force a re-read after writing fixtures.
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


## Every data/maps/<region>/<map>.json path, SORTED (load-order determinism
## -- glob order must never matter, danger list item 1). Region dir names
## carry no meaning to the loader; they're purely a lane-ownership surface.
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
