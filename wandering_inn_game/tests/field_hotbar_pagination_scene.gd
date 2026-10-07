extends Node

class PhoneBar extends WIFieldHotbar:
	var test_css := 390.0 / 720.0
	func _uses_touch_layout() -> bool:
		return true
	func _css_scale() -> float:
		return test_css

func _ready() -> void:
	var settings_path := "user://test_field_hotbar_pagination.cfg"
	WISettings.set("_settings_path", settings_path)
	WISettings.set("_settings", ConfigFile.new())
	WISettings.set_text_scale_step(0)
	var bar := PhoneBar.new()
	add_child(bar)
	bar._expanded = false
	var selection_events: Array[Dictionary] = []
	ObservableBus.domain_event.connect(func(type: String, payload: Dictionary) -> void:
		if type == WIEvents.UI_FIELD_HOTBAR_SELECTION_RENDERED:
			selection_events.append(payload))
	for i in 37:
		bar._field_skills.append("test%d" % i)
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
					assert(is_equal_approx(child.size.x, child.size.y) and child.size.y * bar.test_css < 45.0, "field slots must remain compact 44 CSS squares: %s scale %f" % [child.size, bar.test_css])
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
			assert(selection_events.back().visible and selection_events.back().index == 35)
			assert(bar._selection_label_backing.size.x >= bar._selection_label.size.x + 20.0, "selection paper must enclose wrapped label width")
			assert(bar.world_bottom() <= bar._selection_label_backing.position.y - bar.READOUT_GAP, "world content must clear transient help")
			var armed_page := bar._page
			bar._page_previous.pressed.emit()
			assert(not bar._selection_label.visible and not selection_events.back().visible)
			assert(bar._last_selected_index == 35 and selection_events.back().index == 35, "paging hides the label without disarming the selected skill")
			bar._page_next.pressed.emit()
			assert(bar._page == armed_page and bar._selection_label.visible and selection_events.back().visible, "returning to the armed page restores the label and its visibility event")
	bar._readout_lines = ["1  [Field Skill 0]"]
	bar._set_expanded(true, false, "test")
	assert(bar.world_bottom() <= bar._readout_panel.position.y - bar.READOUT_GAP, "phone world content must end above expanded Details")
	bar._set_expanded(false, false, "test")
	var desktop := WIFieldHotbar.new()
	add_child(desktop)
	var original_hint_band := WIFieldHotbar.MESSAGE_LAYER_SCRIPT.hint_band_width
	var desktop_clicked: Array[int] = []
	desktop.slot_activate_requested.connect(func(index: int) -> void: desktop_clicked.append(index))
	for count in [13, 37]:
		desktop._field_skills = bar._field_skills.slice(0, count)
		desktop._last_slots = bar._last_slots.slice(0, count)
		for text_scale in 3:
			WISettings.set_text_scale_step(text_scale)
			for hint_width: float in [340.0, 580.0]:
				WIFieldHotbar.MESSAGE_LAYER_SCRIPT.hint_band_width = hint_width
				desktop._page = 0
				desktop._last_selected_index = -1
				desktop._update_toggle_label()
				desktop._layout_controls()
				desktop_clicked.clear()
				var pages := WIHotbar.page_count(count, desktop._page_size)
				if count == 37 or hint_width == 580.0:
					assert(pages > 1, "desktop overflow must page rather than push Details offscreen")
				for page in pages:
					assert(desktop._page == page)
					_assert_desktop_controls(desktop, hint_width)
					for child: Control in desktop.hotbar_node().get_children():
						assert(child.size == WIHotbar.SLOT_SIZE, "desktop paging preserves readable slot dimensions")
						desktop.hotbar_node().slot_clicked.emit(int(child.get_meta("slot_index")))
					if page < pages - 1:
						desktop._page_next.pressed.emit()
				assert(desktop_clicked == range(1, count + 1), "desktop pages dispatch every original skill index once")
				desktop.set_selected(0)
				assert(desktop.hotbar_node().slot_rect(0).has_area(), "keyboard selection returns to the first page")
				desktop.set_selected(count - 1)
				assert(desktop.hotbar_node().slot_rect(count - 1).has_area(), "keyboard selection reveals the final desktop page")
				assert(selection_events.back().visible and selection_events.back().index == count - 1)
				desktop._page_previous.pressed.emit()
				if pages > 1:
					assert(not desktop._selection_label.visible, "manual paging hides off-page selection without changing its index")
					assert(desktop._last_selected_index == count - 1)
	WISettings.set_text_scale_step(0)
	WIFieldHotbar.MESSAGE_LAYER_SCRIPT.hint_band_width = 340.0
	desktop._field_skills = bar._field_skills.slice(0, 3)
	desktop._last_slots = bar._last_slots.slice(0, 3)
	desktop.set_selected(0)
	desktop._update_toggle_label()
	desktop._layout_controls()
	assert(desktop.hotbar_node().get_child_count() == 3, "small desktop bars stay continuous")
	assert(not desktop._page_previous.visible and not desktop._page_next.visible)
	_assert_desktop_controls(desktop, 340.0)
	desktop._readout_lines = ["1  [Field Skill 0]", "2  [Field Skill 1]", "3  [Field Skill 2]"]
	var desktop_world_bottom := desktop.world_bottom()
	assert(desktop._selection_label_backing.visible, "probe needs the transient selection paper on screen")
	desktop._set_expanded(true, false, "test")
	assert(desktop._readout_panel.visible)
	assert(is_equal_approx(desktop.world_bottom(), desktop_world_bottom), "desktop Details and selection paper overlay the world instead of resizing it")
	desktop._set_expanded(false, false, "test")
	assert(is_equal_approx(desktop.world_bottom(), desktop_world_bottom), "collapsing desktop Details leaves the world view unchanged")
	desktop._field_skills = bar._field_skills.duplicate()
	desktop._last_slots = bar._last_slots.duplicate(true)
	desktop._layout_controls()
	desktop.set_selected(30)
	var old_page_size := desktop._page_size
	WIFieldHotbar.MESSAGE_LAYER_SCRIPT.hint_band_width = 580.0
	ObservableBus.emit_domain_event(WIEvents.UI_HINT_RENDERED, {})
	assert(desktop._page_size < old_page_size, "a newly rendered wider hint must reduce desktop capacity")
	assert(desktop.hotbar_node().slot_rect(30).has_area(), "live hint resizing preserves the visible original selection")
	_assert_desktop_controls(desktop, 580.0)
	WIFieldHotbar.MESSAGE_LAYER_SCRIPT.hint_band_width = original_hint_band
	desktop.queue_free()
	bar.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	print("PASS: field pagination preserves original indices and safe controls on phone and overflowing desktop bars")
	get_tree().quit()


func _assert_desktop_controls(bar: WIFieldHotbar, hint_width: float) -> void:
	var controls: Array[Rect2] = [bar._toggle.get_global_rect()]
	if bar._page_previous.visible:
		controls.append(bar._page_previous.get_global_rect())
		controls.append(bar._page_next.get_global_rect())
	for child: Control in bar.hotbar_node().get_children():
		controls.append(child.get_global_rect())
	var safe := bar._current_safe_rect()
	for rect: Rect2 in controls:
		assert(safe.encloses(rect), "desktop control clipped: %s outside %s" % [rect, safe])
		assert(rect.position.x >= safe.position.x + hint_width + bar.HINT_BAND_GAP, "desktop controls overlap the live hint ribbon")
	for i in controls.size():
		for j in range(i + 1, controls.size()):
			assert(not controls[i].intersects(controls[j]), "desktop paging/skill/Details controls overlap")
