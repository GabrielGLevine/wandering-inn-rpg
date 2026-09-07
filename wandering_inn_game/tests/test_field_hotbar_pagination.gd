extends Node

class PhoneBar extends WIFieldHotbar:
	var test_css := 390.0 / 720.0
	func _uses_touch_layout() -> bool:
		return true
	func _css_scale() -> float:
		return test_css

func _ready() -> void:
	var bar := PhoneBar.new()
	add_child(bar)
	bar._expanded = false
	for i in 37:
		bar._last_slots.append({"label": "[Field Skill %d]" % i, "type": "skill", "id": "test%d" % i})
	bar._update_toggle_label()
	var clicked: Array[int] = []
	bar.slot_activate_requested.connect(func(index: int) -> void: clicked.append(index))
	for css_height: float in [360.0, 390.0, 412.0]:
		bar.test_css = css_height / 720.0
		for text_scale in 3:
			bar.test_css = css_height / 720.0
			WISettings.set_text_scale_step(text_scale)
			bar._page = 0
			bar._layout_controls()
			clicked.clear()
			var pages := WIHotbar.page_count(37, bar._page_size)
			for page in pages:
				assert(bar._page == page)
				var controls: Array[Rect2] = [bar._toggle.get_global_rect(), bar._page_previous.get_global_rect(), bar._page_next.get_global_rect()]
				for child: Control in bar.hotbar_node().get_children():
					controls.append(child.get_global_rect())
					bar.hotbar_node().slot_clicked.emit(int(child.get_meta("slot_index")))
				for rect: Rect2 in controls:
					assert(bar._current_safe_rect().encloses(rect), "control clipped")
					assert(rect.size.x * bar.test_css >= 43.99 and rect.size.y * bar.test_css >= 43.99)
				for i in controls.size():
					for j in range(i + 1, controls.size()):
						assert(not controls[i].intersects(controls[j]), "controls overlap")
				if page < pages - 1:
					bar._page_next.pressed.emit()
			assert(clicked == range(1, 38), "every original slot dispatches exactly once")
			bar.set_selected(35)
			assert(bar.hotbar_node().slot_rect(35).has_area())
			bar.test_css = 360.0 / 720.0
			bar._refresh_layout()
			assert(bar._last_selected_index == 35, "resize must preserve original selection")
			assert(bar.hotbar_node().slot_rect(35).has_area(), "selected slot stays visible after resize")
	var desktop := WIFieldHotbar.new()
	add_child(desktop)
	desktop._last_slots = bar._last_slots.duplicate(true)
	desktop._update_toggle_label()
	desktop._layout_controls()
	assert(desktop.hotbar_node().get_child_count() == 37, "desktop retains the continuous row")
	assert(not desktop._page_previous.visible and not desktop._page_next.visible)
	desktop.queue_free()
	bar.queue_free()
	await get_tree().process_frame
	print("PASS: phone field pagination reaches 37 original slots with safe 44 CSS controls at all text scales; resize preserves selection")
	get_tree().quit()
