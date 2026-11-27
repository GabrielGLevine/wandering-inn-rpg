extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var factory := WIEntityVisualFactory.new(16.0, null)
	var roof := factory.make(Vector2i(2, 3), "city_roof_owned", [2.6, 0.5, 0.45], Color.BLACK)
	var sprite := roof.get_child(0) as AnimatedSprite2D
	if sprite == null or sprite.modulate != Color.WHITE:
		push_error("FAIL: owned roof must preserve its authored palette under the legacy roof tint")
		roof.free()
		quit(1)
		return
	var counter := factory.make(Vector2i.ZERO, "counter_segment_owned", [0.4, 0.5, 0.6], Color.BLACK)
	var counter_sprite := counter.get_child(counter.get_child_count() - 1) as AnimatedSprite2D
	if counter_sprite == null or counter_sprite.modulate != Color(0.4, 0.5, 0.6):
		push_error("FAIL: field tint remains effective when the sprite has no palette override")
		roof.free()
		counter.free()
		quit(1)
		return
	roof.free()
	counter.free()
	print("PASS: field sprites honor explicit palette overrides and preserve ordinary map tint")
	quit(0)
