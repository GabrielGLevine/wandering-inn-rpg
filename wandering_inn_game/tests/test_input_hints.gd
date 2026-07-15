extends SceneTree


func _init() -> void:
	WITestWatchdog.arm(self)
	var instance := _build_instance()

	_check_labels(instance)
	_check_classification(instance)
	_check_field_readout_action()
	instance.free()

	print("PASS: WIInputHints label table + device classification hold")
	quit(0)


func _build_instance() -> Node:
	var raw_source := FileAccess.get_file_as_string("res://src/ui/input_hints.gd")
	var patched_source := raw_source.replace(
		"extends Node",
		"extends Node\n\nvar ObservableBus: Variant = null",
	)
	var patched_script := GDScript.new()
	patched_script.source_code = patched_source
	var compile_err := patched_script.reload()
	assert(compile_err == OK, "input_hints.gd (autoload-stubbed copy) failed to compile: %d" % compile_err)
	return patched_script.new()


func _check_labels(instance: Node) -> void:
	var kb_expected := {
		"move": "Arrows", "interact": "E", "confirm": "Enter", "cancel": "Esc",
		"cycle": "Tab", "journal": "J", "inventory": "I", "end_turn": "E",
		"hotbar": "number keys", "field_readout": "H",
	}
	var pad_expected := {
		"move": "stick", "interact": "A", "confirm": "A", "cancel": "B",
		"cycle": "LT", "journal": "Y", "inventory": "X", "end_turn": "Start",
		"hotbar": "LB/RB + A", "field_readout": "L3",
	}
	instance.set("_device", "kb")
	for action: String in kb_expected:
		var got: String = instance.label(action)
		assert(got == kb_expected[action], "kb label(%s) == %s, got %s" % [action, kb_expected[action], got])
	instance.set("_device", "pad")
	for action: String in pad_expected:
		var got: String = instance.label(action)
		assert(got == pad_expected[action], "pad label(%s) == %s, got %s" % [action, pad_expected[action], got])
	assert(instance.label("not_a_real_action") == "not_a_real_action", "label() must fall back to the action name for an unknown key")


func _check_classification(instance: Node) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	assert(instance._classify(key_event) == "kb", "a key press classifies as kb")

	var mouse_event := InputEventMouseButton.new()
	mouse_event.pressed = true
	assert(instance._classify(mouse_event) == "kb", "a mouse click classifies as kb")

	var mouse_motion := InputEventMouseMotion.new()
	assert(instance._classify(mouse_motion) == "kb", "mouse motion classifies as kb")

	var pad_button_down := InputEventJoypadButton.new()
	pad_button_down.pressed = true
	assert(instance._classify(pad_button_down) == "pad", "a joypad button press classifies as pad")

	var pad_button_up := InputEventJoypadButton.new()
	pad_button_up.pressed = false
	assert(instance._classify(pad_button_up) == "", "a joypad button RELEASE must not reclassify the device (empty string)")

	var motion_over := InputEventJoypadMotion.new()
	motion_over.axis_value = 0.51
	assert(instance._classify(motion_over) == "pad", "stick motion past the deadzone classifies as pad")

	var motion_over_negative := InputEventJoypadMotion.new()
	motion_over_negative.axis_value = -0.51
	assert(instance._classify(motion_over_negative) == "pad", "negative-axis stick motion past the deadzone classifies as pad (absf)")

	var motion_at_deadzone := InputEventJoypadMotion.new()
	motion_at_deadzone.axis_value = 0.5
	assert(instance._classify(motion_at_deadzone) == "", "stick motion AT the deadzone (not past it) must not reclassify -- matches every action's own InputMap deadzone (strictly-greater-than)")

	var motion_under := InputEventJoypadMotion.new()
	motion_under.axis_value = 0.2
	assert(instance._classify(motion_under) == "", "stick drift under the deadzone must not reclassify the device")


func _check_field_readout_action() -> void:
	assert(InputMap.has_action("field_readout"), "field readout toggle must use Input Map")
	var has_h := false
	var has_l3 := false
	for event: InputEvent in InputMap.action_get_events("field_readout"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_H:
			has_h = true
		elif event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK:
			has_l3 = true
	assert(has_h, "field readout toggle needs keyboard H parity")
	assert(has_l3, "field readout toggle needs gamepad L3 parity")
