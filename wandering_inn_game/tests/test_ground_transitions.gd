extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/harvest/meadow_paths.meta.json"))
	var corners: Array = []
	corners.resize(16)
	for tile: Dictionary in metadata["tileset_data"]["tiles"]:
		var mask := 0
		for pair: Array in [["NW", 1], ["NE", 2], ["SW", 4], ["SE", 8]]:
			if tile["corners"][pair[0]] == "upper":
				mask |= int(pair[1])
		var box: Dictionary = tile["bounding_box"]
		corners[mask] = [int(box["x"]) / 16, int(box["y"]) / 16]
	var root := Node2D.new()
	var config := {
		"sheet": "res://assets/tiles/harvest/meadow_paths.png", "tile_px": 16,
		"wang_corners": corners, "terrain_lower_cells": {"list": [[0, 0]]},
	}
	WITileBoardBuilder.build_floor_layers(root, [config], Vector2i(2, 2), config, WISpriteRegistry)
	assert(root.get_child_count() == 1, "authored Wang ground must create a real floor")
	var floor := root.get_child(0) as TileMapLayer
	assert(floor.get_used_cells().size() == 9, "Wang ground paints every shared vertex")
	assert(floor.position == Vector2(-8, -8), "corner tiles must align to cell boundaries")
	assert(floor.get_cell_atlas_coords(Vector2i(1, 1)) == Vector2i(corners[14][0], corners[14][1]), "northwest dirt corner must use the metadata's matching tile")
	assert(floor.get_cell_atlas_coords(Vector2i(0, 0)) == Vector2i(corners[7][0], corners[7][1]), "southeast dirt corner must use its own tile")
	# #632: a null corner leaves that vertex unpainted (here: every all-upper vertex).
	var sparse := corners.duplicate()
	sparse[15] = null
	var sparse_root := Node2D.new()
	var sparse_config := config.duplicate()
	sparse_config["wang_corners"] = sparse
	WITileBoardBuilder.build_floor_layers(sparse_root, [sparse_config], Vector2i(3, 3), sparse_config, WISpriteRegistry)
	var sparse_floor := sparse_root.get_child(0) as TileMapLayer
	assert(sparse_floor.get_used_cells().size() == 4 and sparse_floor.get_cell_source_id(Vector2i(3, 3)) == -1,
		"null corners paint only the vertices touching the lower cell")
	sparse_root.free()
	# #632: a wall segment's `trim` overlays its tile on every face cell, in its own layer.
	var wall_root := Node2D.new()
	var trim_tile := {"sheet": "res://assets/tiles/invrisil/cornice_gold_line.png", "tile_px": 16, "coords": [0, 0]}
	var trim_walls := {"sheet": "res://assets/tiles/harvest/timberwall_over_plank_v1.png", "tile_px": 16, "segments": [
		{"from": [0, 0], "to": [2, 0], "cap": [0, 3], "face": [3, 0], "trim": trim_tile},
		{"from": [0, 1], "to": [0, 2], "cap": [0, 3], "face": null, "trim": trim_tile},
	]}
	WITileBoardBuilder.build_walls(wall_root, trim_walls, Vector2i(3, 3), trim_walls, WISpriteRegistry)
	assert(wall_root.get_child_count() == 3, "a faced segment gains one trim layer; a caps-only one never does")
	var trim_layer := wall_root.get_child(1) as TileMapLayer
	assert(trim_layer.get_used_cells().size() == 3 and trim_layer.get_cell_atlas_coords(Vector2i(2, 0)) == Vector2i.ZERO,
		"the trim tile covers exactly the face cells")
	wall_root.free()
	var builder := WITileBoardBuilder.new()
	for mask in 16:
		var lower := {}
		for pair: Array in [[Vector2i(-1, -1), 1], [Vector2i(0, -1), 2], [Vector2i(-1, 0), 4], [Vector2i.ZERO, 8]]:
			if mask & int(pair[1]) == 0:
				lower[pair[0]] = true
		assert(int(builder.call("terrain_vertex_bits", Vector2i.ZERO, lower)) == mask, "every corner combination must resolve independently")
	root.free()
	print("PASS: authored ground transitions match all sixteen metadata corner combinations")
	quit(0)
