extends SceneTree
## ONE-OFF proof for issue #100's skeleton_scene.json split: WISceneCatalog's
## composed dict deep-equals the original monolithic file. Run once at the
## split commit with data/skeleton_scene.json still present, then delete
## (both this file and the old JSON) -- not part of the regular suite,
## not in CLAUDE.md's unit-suite list or ci_sweep.sh.
## Usage: godot --headless --path wandering_inn_game --script res://tests/_scene_split_proof.gd
func _init() -> void:
	var old_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skeleton_scene.json"))
	if not (old_raw is Dictionary):
		push_error("FAIL: could not parse old data/skeleton_scene.json")
		quit(1)
		return
	var old: Dictionary = old_raw
	var composed: Dictionary = WISceneCatalog.compose()
	if composed == old:
		print("PASS: WISceneCatalog.compose() deep-equals data/skeleton_scene.json")
		print("  top-level keys: %s" % [composed.keys()])
		print("  map count: %d" % (composed["maps"] as Dictionary).size())
		quit(0)
	else:
		push_error("FAIL: composed dict differs from data/skeleton_scene.json")
		var old_maps: Dictionary = old.get("maps", {})
		var new_maps: Dictionary = composed.get("maps", {})
		if old.get("start_map") != composed.get("start_map"):
			push_error("  start_map mismatch: %s vs %s" % [old.get("start_map"), composed.get("start_map")])
		if old.get("player") != composed.get("player"):
			push_error("  player dict mismatch")
		if old_maps.keys() != new_maps.keys():
			push_error("  map key sets differ: old-only=%s new-only=%s" % [
				(old_maps.keys() as Array).filter(func(k): return not new_maps.has(k)),
				(new_maps.keys() as Array).filter(func(k): return not old_maps.has(k)),
			])
		for map_id: String in old_maps:
			if new_maps.has(map_id) and old_maps[map_id] != new_maps[map_id]:
				push_error("  map '%s' content differs" % map_id)
		quit(1)
