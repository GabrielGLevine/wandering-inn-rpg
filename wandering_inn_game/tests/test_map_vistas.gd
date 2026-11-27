extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var parent := Node2D.new()
	var builder := WITileBoardBuilder.new()
	var count := 0
	if builder.has_method("build_vistas"):
		count = int(builder.call("build_vistas", parent, [{"sprite": "pallass_lower_city", "cell": [13, 11]}], WISpriteRegistry))
	assert(count == 1 and parent.get_child_count() == 1, "authored vista must create a real world sprite")
	var vista := parent.get_child(0) as Sprite2D
	assert(vista != null and vista.texture != null, "vista must use an imported texture")
	assert(vista.position.distance_to(Vector2(0, 176)) < 0.01, "background starts beyond the playable terrace")
	assert(is_equal_approx(vista.get_rect().size.x * vista.scale.x, 416), "city must span the terrace width")
	assert(vista.z_index < 0, "background must stay behind floor, parapet and actors")
	assert(vista.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(int(builder.call("build_vistas", parent, [], WISpriteRegistry)) == 0)
	assert(parent.get_child_count() == 1, "unconfigured maps add no scenery")
	assert(int(builder.call("build_vistas", parent, [{"sprite": "pallass_parapet_full", "cell": [6.5, 10], "foreground": true}], WISpriteRegistry)) == 1)
	assert((parent.get_child(1) as Sprite2D).z_index == 0, "rail draws above floors before actors")
	parent.free()
	print("PASS: map vistas render beyond the playable grid behind field geometry")
	quit(0)
