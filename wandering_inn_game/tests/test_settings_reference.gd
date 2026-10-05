extends SceneTree

func _initialize() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()


func _run() -> void:
	var settings = root.get_node("WISettings")
	settings.set("_settings_path", "user://test_settings_reference.cfg")
	var panel = load("res://src/ui/settings_panel.gd").new()
	root.add_child(panel)
	panel.is_open = true
	for scale_step in 3:
		settings.set_text_scale_step(scale_step)
		for page in ["controls", "help"]:
			panel.call("_enter_" + page)
			await process_frame
			await process_frame
			var snapshot: Dictionary = panel.reference_layout_snapshot()
			assert(snapshot.page == page)
			assert(is_equal_approx(snapshot.text_scale, [1.0, 1.15, 1.3][scale_step]))
			var safe := _rect(snapshot.safe_rect)
			var bounds := _rect(snapshot.panel_rect)
			var back := panel.reference_back_rect() as Rect2
			var scroll := panel.reference_scroll_rect() as Rect2
			assert(safe.encloses(bounds), "Reference panel must fit the viewport")
			assert(bounds.encloses(back) and bounds.encloses(scroll))
			assert(back.size.y >= 34.0 and back.position.y >= scroll.end.y)
			if page == "controls":
				assert(snapshot.columns == 4 and snapshot.texts.size() == 44)
			else:
				assert(snapshot.texts.size() == 8 and snapshot.scroll_max >= 0)
				for text: Dictionary in snapshot.texts:
					assert(float(text.rect[2]) <= scroll.size.x)
	root.content_scale_size = Vector2i(640, 360)
	for page in ["controls", "help"]:
		panel.call("_enter_" + page)
		await process_frame
		await process_frame
		var small: Dictionary = panel.reference_layout_snapshot()
		assert(_rect(small.safe_rect).encloses(_rect(small.panel_rect)))
		assert(small.scroll_max > 0, "Small viewport must scroll content without losing Back")
		assert(_rect(small.panel_rect).encloses(panel.reference_back_rect()))
	panel.is_open = false
	assert(panel.reference_back_rect() == Rect2())
	assert(panel.reference_scroll_rect() == Rect2())
	assert(panel.reference_layout_snapshot().is_empty())
	panel.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings_reference.cfg"))
	print("PASS: settings reference bounds, fixed Back and scaled scrolling")
	quit(0)


func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
