extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var original_biome := {
		"sheet": "res://assets/__missing_terrain_primary__.png", "tile_px": 540,
		"floor": [0, 0], "blocked": [0, 0], "skirt": [0, 0],
		"interior_flavor": "The familiar room.", "footstep_family": "earth",
		"fallback_render": {
			"sheet": "res://assets/tiles/harvest/meadow_paths.png", "tile_px": 16,
			"floor": [0, 3], "blocked": [0, 3], "skirt": [2, 1],
		},
	}
	var config := {
		"variants": [[16, 2], [17, 2]], "cells": {"rect": [1, 1, 2, 1]},
		"fallback_render": {"sheet": "res://assets/tiles/harvest/meadow_paths.png", "tile_px": 16, "coords": [2, 1]},
	}
	var parent := Node2D.new()
	WITileBoardBuilder.build_floor_layers(parent, [config], Vector2i(4, 3), original_biome, WISpriteRegistry)
	var floor := parent.get_child(0) as TileMapLayer
	assert(floor.tile_set.tile_size == Vector2i(16, 16), "missing inherited primary must switch tile unit with the whole descriptor")
	assert(floor.get_used_cells().size() == 2, "fallback must preserve the authored selector")
	assert(floor.get_cell_atlas_coords(Vector2i(1, 1)) == Vector2i(2, 1), "old private variant coordinates must never reach the owned atlas")
	assert(bool(floor.get_meta("owned_terrain_fallback", false)), "renderer must identify an actual owned fallback")
	var builder := WITileBoardBuilder.new()
	var biome: Dictionary = builder.call("resolve_biome_render", original_biome, WISpriteRegistry)
	assert(biome["sheet"] == "res://assets/tiles/harvest/meadow_paths.png" and biome["tile_px"] == 16)
	assert(biome["interior_flavor"] == "The familiar room." and biome["footstep_family"] == "earth", "render replacement must preserve gameplay identity")
	assert(original_biome["tile_px"] == 540 and config.has("variants"), "resolver must not mutate shared catalogs")
	var available := {"sheet": "res://assets/tiles/harvest/inn_floor.png", "tile_px": 16,
		"coords": [0, 3], "fallback_render": config["fallback_render"]}
	var resolved: Dictionary = builder.call("resolve_tile_render", available, original_biome, WISpriteRegistry)
	assert(resolved["sheet"] == available["sheet"] and resolved["coords"] == [0, 3], "available private or owned primary must win")
	var incomplete := config.duplicate(true)
	incomplete["fallback_render"]["sheet"] = "res://assets/__missing_terrain_fallback__.png"
	resolved = builder.call("resolve_tile_render", incomplete, original_biome, WISpriteRegistry)
	assert(resolved["sheet"] == original_biome["sheet"] and resolved.has("variants"), "unavailable target must not manufacture a render descriptor")
	var window := {"sheet": "res://assets/__missing_window__.png", "tile_px": 16,
		"coords": [13, 35], "cells": {"rect": [0, 1, 2, 1]},
		"fallback_render": {"sheet": "res://assets/tiles/harvest/window_facade.png", "tile_px": 64,
			"coords": [0, 0], "underlay": {"sheet": "res://assets/tiles/harvest/plaster_wall.png", "tile_px": 16, "coords": [4, 3]}}}
	var first := parent.get_child_count()
	WITileBoardBuilder.build_floor_layers(parent, [window], Vector2i(4, 3), original_biome, WISpriteRegistry)
	assert(parent.get_child_count() == first + 2, "transparent window fallback needs its own plaster backing")
	for index in range(first, first + 2):
		var layer := parent.get_child(index) as TileMapLayer
		assert(layer.get_used_cells().size() == 2 and bool(layer.get_meta("owned_terrain_fallback", false)))
	var walls := {"segments": [{"from": [1, 1], "to": [2, 1], "face": [14, 7], "cap": [14, 6],
		"fallback_render": {"sheet": "res://assets/tiles/harvest/plaster_wall.png", "tile_px": 16, "face": [4, 3], "cap": [4, 2]}}]}
	first = parent.get_child_count()
	var covered := WITileBoardBuilder.build_walls(parent, walls, Vector2i(4, 3), original_biome, WISpriteRegistry)
	assert(covered.size() == 2 and covered.has(Vector2i(1, 1)), "fallback must retain exact blocking footprint")
	var wall := parent.get_child(first) as TileMapLayer
	assert(wall.get_cell_atlas_coords(Vector2i(1, 1)) == Vector2i(4, 3))
	assert(wall.get_cell_atlas_coords(Vector2i(1, 0)) == Vector2i(4, 2), "face and cap must resolve together against original inheritance")
	parent.free()
	print("PASS: terrain fallbacks preserve selectors, replace whole render descriptors and keep original inheritance")
	quit(0)
