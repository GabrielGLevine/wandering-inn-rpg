extends SceneTree

class SimStub extends RefCounted:
	var combat: Variant = null
	var times_slept := 0
	var resources := {"hp": 7, "max_hp": 24, "mp": 0, "max_mp": 12, "mp_potion_doses": 0}
	func player_resources() -> Dictionary:
		return resources.duplicate(true)

class GameStub extends RefCounted:
	var sim := SimStub.new()

class BusStub extends RefCounted:
	signal domain_event(type: String, payload: Dictionary)
	var events: Array[Dictionary] = []
	func emit_domain_event(type: String, payload: Dictionary) -> void:
		events.append({"type": type, "payload": payload.duplicate(true)})
		domain_event.emit(type, payload)

class SettingsStub extends RefCounted:
	const TEXT_SCALE_STEPS := [1.0, 1.15, 1.3]
	var step := 0
	func text_scale_step() -> int:
		return step
	func scaled_type_font_sizes(_step: int) -> Dictionary:
		return {"Small": int(ceil(14 * TEXT_SCALE_STEPS[step]))}

class PhoneLayout extends RefCounted:
	var scale := 844.0 / 1280.0
	func uses_touch_layout() -> bool:
		return true
	func safe_rect(viewport: Viewport) -> Rect2:
		return viewport.get_visible_rect().grow(-12.0)
	func readable_font_size(_viewport: Viewport, base: int, text_scale: float = 1.0) -> int:
		return maxi(base, int(ceil(14.0 * text_scale / scale)))
	func touch_size(_viewport: Viewport, size: Vector2) -> Vector2:
		return size.max(Vector2.ONE * ceil(44.0 / scale))

class DriverStub extends RefCounted:
	var real_message_timing := false
	func active() -> bool:
		return true
	func capture_in_flight() -> bool:
		return false

var _bus := BusStub.new()
var _game := GameStub.new()
var _settings := SettingsStub.new()
var _failures: Array[String] = []

func _init() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()

func _run() -> void:
	_check(WIEffectText.resource_line(_game.sim.resources) == "HP 7/24   MP 0/12", "depleted MP must remain numeric")
	var empty_pool := _game.sim.resources.duplicate()
	empty_pool["max_mp"] = 0
	_check(WIEffectText.resource_line(empty_pool).ends_with("MP 0/0"), "no MP pool remains distinct")
	var prep := WIEffectText.preparation_lines({"armed": {"hp_mod": 4}, "active": {"damage_mod": 1}, "well_fed": true, "room_hp": 2})
	_check(prep == ["Next fight: +4 max HP.", "This fight: +1 damage.", "Well fed — until sleep.", "Room: +2 max HP (permanent)."], "preparation amount and expiry")
	var before := _game.sim.resources.duplicate()
	var after := before.duplicate()
	after["max_hp"] = 28
	var change := {"reason": "equipment", "source": "armor", "before": before, "after": after, "preparation": {}}
	var receipt := WIEffectText.resource_receipt(change)
	_check(receipt.contains("HP 7/28") and receipt.contains("Max HP +4.") and not receipt.contains("Restored"), "capacity increase must not claim healing")
	var chip_source := FileAccess.get_file_as_string("res://src/ui/field_chips.gd")
	var chip_script := GDScript.new()
	chip_script.source_code = chip_source.replace("class_name WIFieldChips\n", "").replace("extends CanvasLayer", "extends CanvasLayer\nvar Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant")
	_check(chip_script.reload() == OK, "production chip script compiles with injected boundaries")
	var chips: CanvasLayer = chip_script.new()
	chips.set("Game", _game)
	chips.set("ObservableBus", _bus)
	chips.set("WISettings", _settings)
	root.size = Vector2i(1280, 720)
	root.add_child(chips)
	await process_frame
	await process_frame
	var panel: Control = chips.get("_resource_panel")
	var label: Label = chips.get("_resource_label")
	_check(label.text == "HP 7/24   MP 0/12", "actual field label draws authoritative depletion")
	_check(not panel.get_global_rect().intersects(chips.call("chip_rect", "inventory")), "resource strip clears launcher")
	_check(_count(WIEvents.UI_RESOURCES_RENDERED) > 0, "visible resource render has proof")
	for scale_step in 3:
		_settings.step = scale_step
		for width in [1280, 700, 440]:
			root.size = Vector2i(width, 720)
			chips.call("_refresh_resources", {"after": {"hp": 12345, "max_hp": 23456, "mp": 12345, "max_mp": 23456}})
			chips.call("_layout_chips")
			await process_frame
			_check(not panel.get_global_rect().intersects(chips.call("chip_rect", "inventory")), "long values clear launcher at %d / %d" % [width, scale_step])
			_check(label.size.x >= label.get_minimum_size().x, "numeric pairs must not clip")
			_check(panel.get_global_rect().end.x <= width, "resource strip stays inside viewport")
	var count := _count(WIEvents.UI_RESOURCES_RENDERED)
	_bus.emit_domain_event(WIEvents.PHASE_CHANGED, {"slept": true})
	_bus.emit_domain_event(WIEvents.RESOURCES_CHANGED, change)
	await process_frame
	await process_frame
	_check(not chips.visible and _count(WIEvents.UI_RESOURCES_RENDERED) == count, "sleep coverage cannot certify a field render")
	_bus.emit_domain_event(WIEvents.UI_SLEEP_VEIL_FINISHED, {})
	await process_frame
	await process_frame
	_check(chips.visible and _count(WIEvents.UI_RESOURCES_RENDERED) > count, "field resources return after sleep")
	chips.free()
	await _saved_phone_fit()
	await _receipt_queue(change)
	if not _failures.is_empty():
		print("FAIL: resource HUD: %d failures" % _failures.size())
		quit(1)
		return
	print("PASS: resource HUD numeric fit, preparation lifetime and captured receipt queue")
	quit(0)

func _saved_phone_fit() -> void:
	var phone := PhoneLayout.new()
	var message_script := GDScript.new()
	message_script.source_code = FileAccess.get_file_as_string("res://src/ui/message_layer.gd").replace("extends CanvasLayer", "extends CanvasLayer\nvar Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant\nvar TestDriver: Variant\nvar WIInputHints: Variant\nvar WIResponsiveLayout: Variant").replace("func _ready()", "func _build_full_ui()")
	_check(message_script.reload() == OK, "phone message renderer compiles")
	var messages: CanvasLayer = message_script.new()
	messages.set("WIResponsiveLayout", phone)
	messages.set("WISettings", _settings)
	var hint := Control.new()
	UIChrome.apply_theme(hint)
	var margin := MarginContainer.new()
	UIChrome.full_rect(margin)
	hint.add_child(margin)
	var label := UIChrome.make_label("Saved", "Small")
	margin.add_child(label)
	messages.add_child(hint)
	messages.set("_hint_panel", hint)
	messages.set("_hint_margin", margin)
	messages.set("_hint_label", label)
	root.add_child(messages)
	var chip_script := GDScript.new()
	chip_script.source_code = FileAccess.get_file_as_string("res://src/ui/field_chips.gd").replace("class_name WIFieldChips\n", "").replace("extends CanvasLayer", "extends CanvasLayer\nvar Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant\nvar WIResponsiveLayout: Variant")
	_check(chip_script.reload() == OK, "phone chips compile")
	var chips: CanvasLayer = chip_script.new()
	chips.set("Game", _game)
	chips.set("ObservableBus", _bus)
	chips.set("WISettings", _settings)
	chips.set("WIResponsiveLayout", phone)
	chips.set("message_layer_ref", messages)
	root.add_child(chips)
	for css_size: Vector2 in [Vector2(844, 390), Vector2(915, 412)]:
		phone.scale = css_size.x / 1280.0
		root.size = Vector2i(1280, int(css_size.y / phone.scale))
		for step in 3:
			_settings.step = step
			messages.call("_resize_hint_panel")
			chips.call("_refresh_resources", {"after": {"hp": 12345, "max_hp": 23456, "mp": 12345, "max_mp": 23456}})
			chips.call("_layout_chips")
			await process_frame
			var resources: Rect2 = chips.call("resource_rect")
			var saved: Rect2 = messages.call("field_hint_rect")
			var launcher: Rect2 = chips.call("chip_rect", "inventory")
			_check(saved.has_area() and not saved.intersects(resources) and not saved.intersects(launcher), "Saved clears resources and launchers at %s / %d" % [css_size, step])
			_check(phone.safe_rect(root).encloses(resources) and phone.safe_rect(root).encloses(saved), "phone bands respect safe area")
			_check(label.size.x >= label.get_minimum_size().x, "Saved label remains readable")
	chips.free()
	messages.free()

func _receipt_queue(change: Dictionary) -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/message_layer.gd")
	var script := GDScript.new()
	script.source_code = source.replace("extends CanvasLayer", "extends CanvasLayer\nvar Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant\nvar TestDriver: Variant\nvar WIInputHints: Variant").replace("func _ready()", "func _build_full_ui()")
	_check(script.reload() == OK, "production receipt queue compiles with injected boundaries")
	var layer: CanvasLayer = script.new()
	layer.set("Game", _game)
	layer.set("ObservableBus", _bus)
	layer.set("WISettings", _settings)
	layer.set("TestDriver", DriverStub.new())
	var panel := Control.new()
	var label := Label.new()
	panel.add_child(label)
	panel.hide()
	layer.add_child(panel)
	layer.set("_toast_panel", panel)
	layer.set("_toast_label", label)
	root.add_child(layer)
	layer.call("_on_domain_event", WIEvents.UI_INVENTORY_SHOWN, {})
	var original := change.duplicate(true)
	layer.call("_on_domain_event", WIEvents.RESOURCES_CHANGED, change)
	change["after"]["hp"] = 1
	await process_frame
	_check(_count(WIEvents.UI_RECOVERY_RENDERED) == 0, "covered receipt must wait for modal close")
	layer.call("_on_domain_event", WIEvents.UI_INVENTORY_HIDDEN, {})
	await process_frame
	await process_frame
	_check(panel.visible and label.text.contains("HP 7/28"), "queued text captures original values")
	var proof := _last(WIEvents.UI_RECOVERY_RENDERED)
	_check(proof.get("after", {}) == original["after"], "render confirmation captures original values")
	await create_timer(0.2).timeout
	layer.set("_sleep_active", true)
	layer.call("_on_domain_event", WIEvents.RESOURCES_CHANGED, original)
	var count := _count(WIEvents.UI_RECOVERY_RENDERED)
	await process_frame
	_check(_count(WIEvents.UI_RECOVERY_RENDERED) == count, "sleep blocks recovery receipt")
	layer.call("_on_domain_event", WIEvents.UI_SLEEP_VEIL_FINISHED, {})
	await process_frame
	await process_frame
	_check(_count(WIEvents.UI_RECOVERY_RENDERED) == count + 1, "sleep completion drains retained receipt")
	await create_timer(0.2).timeout
	layer.free()

func _count(type: String) -> int:
	var count := 0
	for event: Dictionary in _bus.events:
		if event["type"] == type:
			count += 1
	return count

func _last(type: String) -> Dictionary:
	for i in range(_bus.events.size() - 1, -1, -1):
		if _bus.events[i]["type"] == type:
			return _bus.events[i]["payload"]
	return {}

func _check(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
		print("FAIL: " + message)
