extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var camera := Camera2D.new()
	var controller := WICameraController.new(camera, 16, Vector2(320, 144))
	controller.update(Vector2i(26, 11), Vector2i(4, 8))
	assert(camera.position == Vector2(160, 104), "unconfigured map keeps its original framing")
	if controller.has_method("set_field_framing"):
		controller.call("set_field_framing", Vector2.ZERO, Vector4(0, 2, 0, 4))
	controller.update(Vector2i(26, 11), Vector2i(4, 8))
	assert(camera.position == Vector2(160, 136), "authored margin must reveal scenery beyond the terrace")
	controller.pan_to(Vector2i(26, 11), Vector2i(4, 9), 0)
	assert(camera.position == Vector2(160, 152), "zero-duration movement uses the same authored bounds")
	controller.call("set_field_framing", Vector2(0, -3), Vector4.ZERO)
	controller.update(Vector2i(28, 18), Vector2i(4, 8))
	assert(camera.position.y < 136, "authored look-ahead keeps northern architecture in frame")
	assert(absf(camera.position.y - 136) <= 36, "offset keeps the player inside the view on small screens")
	controller.call("set_field_framing", Vector2.ZERO, Vector4.ZERO)
	controller.update(Vector2i(26, 11), Vector2i(4, 8))
	assert(camera.position == Vector2(160, 104), "leaving a framed map restores the ordinary camera")
	camera.free()
	print("PASS: authored field framing preserves defaults and reveals exterior scenery")
	quit(0)
