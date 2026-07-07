extends SceneTree
## Controller support (S3, issue #18): coverage for WIInputHints
## (src/ui/input_hints.gd) -- the device classifier + keycap-hint composer.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_input_hints.gd
##
## `input_hints.gd` extends Node and references the ObservableBus autoload
## directly (in `_input()`), so a bare `load()` fails to COMPILE under
## --script mode -- the same "autoloads don't resolve as bare identifiers"
## gotcha `tests/test_combat_visuals.gd` already works around. Same fix:
## compile an in-memory patched copy that stubs ObservableBus as an inert
## instance var. `WIEvents` is a plain `class_name` (not an autoload), so it
## resolves fine even under --script and needs no stub.
##
## Scope (matches the plan's verification bar): the label table in both
## device modes, and device CLASSIFICATION (`_classify`) including the
## deadzone edge. The live bus-emission path (`_input()` calling
## `ObservableBus.emit_domain_event`) is proven by the real QA/windowed pass
## instead -- exercising it here would mean actually firing the stubbed-null
## ObservableBus, which would crash the moment device state changes.


func _init() -> void:
	WITestWatchdog.arm(self)
	var instance := _build_instance()

	_check_labels(instance)
	_check_classification(instance)
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


## The label table (both kb and pad) for every action WIInputHints.LABELS
## carries -- pins BOTH modes and, for kb, byte-matches the pre-S3 hardcoded
## literals the swapped call sites used to carry verbatim (see each call
## site's own doc comment for why this makes those swaps zero-re-pin).
func _check_labels(instance: Node) -> void:
	var kb_expected := {
		"move": "Arrows", "interact": "E", "confirm": "Enter", "cancel": "Esc",
		"cycle": "Tab", "journal": "J", "inventory": "I", "end_turn": "E",
		"hotbar": "number keys",
	}
	var pad_expected := {
		"move": "stick", "interact": "A", "confirm": "A", "cancel": "B",
		"cycle": "LT", "journal": "Y", "inventory": "X", "end_turn": "Start",
		"hotbar": "LB/RB + A",
	}
	instance.set("_device", "kb")
	for action: String in kb_expected:
		var got: String = instance.label(action)
		assert(got == kb_expected[action], "kb label(%s) == %s, got %s" % [action, kb_expected[action], got])
	instance.set("_device", "pad")
	for action: String in pad_expected:
		var got: String = instance.label(action)
		assert(got == pad_expected[action], "pad label(%s) == %s, got %s" % [action, pad_expected[action], got])
	# Unrecognized action degrades to the action string itself (never crashes
	# a typo'd caller -- same graceful-degrade spirit as InputMap.has_action
	# guards elsewhere in this codebase).
	assert(instance.label("not_a_real_action") == "not_a_real_action", "label() must fall back to the action name for an unknown key")


## `_classify` is pure (no ObservableBus touch), so it's safe to call
## directly even on the stubbed instance. Covers every event class the file
## doc comment claims, plus the deadzone edge (S1's InputMap uses 0.5 on
## every action -- WIInputHints.MOTION_DEADZONE must agree with it, or "the
## player is on a pad" classification and actual action activation would
## disagree about what counts as a deliberate stick push).
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
