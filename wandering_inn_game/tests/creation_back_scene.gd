extends Node

class TestMain extends WIMain:
	var title_returns := 0
	func _ready() -> void:
		pass
	func swap_to_title() -> void:
		title_returns += 1

func _ready() -> void:
	var main := TestMain.new()
	add_child(main)
	var renders: Array[Dictionary] = []
	ObservableBus.domain_event.connect(func(type: String, payload: Dictionary) -> void:
		if type == WIEvents.UI_CHAR_CREATION_RENDERED:
			renders.append(payload))
	var creation = load("res://src/ui/char_creation.gd").new()
	main.add_child(creation)
	assert(creation.has_method("back_button_rect"), "creation needs a visible Back control")
	var button: Button = creation.get("_back_button")
	assert(button != null and button.is_visible_in_tree() and button.text == "Back")
	assert(button.focus_mode == Control.FOCUS_NONE, "Back must not steal arrow/confirm navigation")
	assert(get_viewport().get_visible_rect().encloses(creation.back_button_rect()), "rendered desktop Back must fit even in a headless viewport")
	for height: float in [360.0, 390.0, 412.0]:
		var css := height / 720.0
		for text_scale: float in [1.0, 1.15, 1.3]:
			var font := ThemeDB.get_fallback_font()
			var font_px := ceili(14.0 * text_scale / css)
			var measured := font.get_string_size("Back", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px)
			for inset: float in [0.0, 48.0]:
				var safe := Rect2(inset, inset, 1280.0 - 2.0 * inset, 720.0 - 2.0 * inset)
				var rect: Rect2 = creation.back_control_layout(safe, css, measured)
				assert(safe.encloses(rect), "Back stays in safe area")
				assert(rect.size.x * css >= 44.0 and rect.size.y * css >= 44.0)
				assert(rect.size.x >= measured.x and rect.size.y >= measured.y)
	for step in range(3, 0, -1):
		creation.set("_step", step)
		creation.call("_render_step")
		assert(creation.back_button_rect().has_area())
		assert(renders.back().back_visible and renders.back().back_label == "Back")
		button.pressed.emit()
		assert(creation.get("_step") == step - 1, "Back shares the existing previous-step behavior")
	for step in range(3, 0, -1):
		creation.set("_step", step)
		creation.call("_render_step")
		var cancel := InputEventAction.new()
		cancel.action = "cancel"
		cancel.pressed = true
		creation.call("_unhandled_input", cancel)
		assert(creation.get("_step") == step - 1, "keyboard cancel retains the same transition")
	button.pressed.emit()
	await get_tree().process_frame
	assert(main.title_returns == 1, "Back from first step returns to title exactly once")
	main.queue_free()
	await get_tree().process_frame
	print("PASS: creation Back reaches every preceding step and title with safe 44 CSS controls")
	get_tree().quit()
