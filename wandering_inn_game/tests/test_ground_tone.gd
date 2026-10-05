extends SceneTree


func _init() -> void:
	var root := Node2D.new()
	var config := {
		"sheet": "res://assets/tiles/harvest/inn_floor.png", "tile_px": 16,
		"coords": [0, 3], "cells": "all",
		"tone": {"base": [0.37, 0.26, 0.17], "detail": 0.18},
	}
	WITileBoardBuilder.build_floor_layers(root, [config], Vector2i(3, 2), config, WISpriteRegistry)
	assert(root.get_child_count() == 1, "toned floor must be attached")
	var floor := root.get_child(0) as TileMapLayer
	assert(floor.get_used_cells().size() == 6, "tone must preserve painted geometry")
	var material := floor.material as ShaderMaterial
	assert(material != null, "authored tone must reach the live floor material")
	assert(material.shader == WITileBoardBuilder.GROUND_TONE_SHADER)
	assert(is_equal_approx(float(material.get_shader_parameter("ground_detail")), 0.18))
	assert(material.get_shader_parameter("ground_base") == Color(0.37, 0.26, 0.17))
	var untinted := TileMapLayer.new()
	WITileBoardBuilder.apply_ground_tone(untinted, {})
	assert(untinted.material == null, "unconfigured floors must retain their material")
	WITileBoardBuilder.apply_ground_tone(untinted, {"base": [0.1], "detail": 0.5})
	assert(untinted.material == null, "incomplete tone must not paint an arbitrary floor color")
	WITileBoardBuilder.apply_ground_tone(untinted, {"base": [0.2, 0.3, 0.4], "detail": 2.0})
	assert(is_equal_approx(float((untinted.material as ShaderMaterial).get_shader_parameter("ground_detail")), 1.0))
	untinted.free()
	root.free()
	print("PASS: authored ground tone preserves floor geometry and material scope")
	quit(0)
