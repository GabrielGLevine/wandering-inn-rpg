extends SceneTree

const MESSAGE_LAYER_PATH := "res://src/ui/message_layer.gd"

class EventSink extends RefCounted:
	var events: Array[Dictionary] = []
	func emit_domain_event(type: String, payload: Dictionary) -> void:
		events.append({"type": type, "payload": payload.duplicate(), "msec": Time.get_ticks_msec()})

class SettingsStub extends RefCounted:
	const TEXT_SCALE_STEPS := [1.0]
	func text_scale_step() -> int:
		return 0
	func scaled_type_font_sizes(_step: int) -> Dictionary:
		return {"Small": 14}

class DriverStub extends RefCounted:
	var real_message_timing := true
	func active() -> bool:
		return true
	func capture_in_flight() -> bool:
		return true

var _layer: CanvasLayer
var _sink := EventSink.new()
var _failures: Array[String] = []

func _init() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()

func _run() -> void:
	var raw := FileAccess.get_file_as_string(MESSAGE_LAYER_PATH)
	var stub := "\nvar Game: Variant = null\nvar ObservableBus: Variant = null\nvar TestDriver: Variant = null\nvar WIInputHints: Variant = null\nvar WISettings: Variant = null\n"
	var script := GDScript.new()
	# Build only the renderer's controls; the production queue, event handler,
	# timing loop, resizing and capture-release code remain unchanged.
	script.source_code = raw.replace("extends CanvasLayer", "extends CanvasLayer" + stub).replace("func _ready()", "func _build_full_ui()")
	_check(script.reload() == OK)
	_layer = script.new()
	_layer.set("ObservableBus", _sink)
	_layer.set("TestDriver", DriverStub.new())
	_layer.set("WISettings", SettingsStub.new())
	var panel := Control.new()
	var label := Label.new()
	panel.add_child(label)
	_layer.add_child(panel)
	panel.hide()
	_layer.set("_toast_panel", panel)
	_layer.set("_toast_label", label)
	var line := Control.new()
	_layer.add_child(line)
	line.hide()
	_layer.set("_dialogue_panel", line)
	root.add_child(_layer)
	await process_frame
	await _early_movement()
	await _late_movement()
	await _first_frame_movement()
	await _first_frame_transition()
	await _modal_delivery()
	await _unread_transition()
	await _save_contention_and_long_text()
	await _transient_history()
	_layer.free()
	if not _failures.is_empty():
		print("FAIL: message lifetime runtime: %d failures" % _failures.size())
		quit(1)
		return
	print("PASS: production message coroutine preserves readable lifetime and modal delivery")
	quit(0)

func _emit(type: String, payload: Dictionary = {}) -> void:
	_layer.call("_on_domain_event", type, payload)

func _state() -> Dictionary:
	return _layer.call("toast_display_state")

func _wait_elapsed(milliseconds: int) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while int(_state()["elapsed_msec"]) < milliseconds:
		if Time.get_ticks_msec() >= deadline:
			_check(false, "elapsed wait timed out")
			return
		await process_frame

func _wait_hidden() -> int:
	var deadline := Time.get_ticks_msec() + 3000
	while bool(_state()["visible"]):
		if Time.get_ticks_msec() >= deadline:
			_check(false, "message never retired")
			return int(_state()["elapsed_msec"])
		await process_frame
	return int(_state()["elapsed_msec"])

func _wait_text(text: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not bool(_state()["visible"]) or String(_state()["text"]) != text:
		if Time.get_ticks_msec() >= deadline:
			_check(false, "message never delivered: " + text)
			return
		await process_frame
	await process_frame

func _renders(text: String) -> int:
	var count := 0
	for event: Dictionary in _sink.events:
		if event["type"] == WIEvents.UI_TOAST_RENDERED and event["payload"]["text"] == text:
			count += 1
	return count

func _early_movement() -> void:
	_emit(WIEvents.TOAST, {"text": "An early movement receipt."})
	await process_frame
	await _wait_elapsed(150)
	_emit(WIEvents.PLAYER_MOVED)
	await _wait_elapsed(950)
	_check(bool(_state()["visible"]), "early movement erased copy before the readable floor")
	var elapsed := await _wait_hidden()
	_check(elapsed >= 1200 and elapsed < 1600, "early movement must retire at the production 1.2s floor, got %d" % elapsed)

func _late_movement() -> void:
	_emit(WIEvents.TOAST, {"text": "A late movement receipt."})
	await _wait_elapsed(1350)
	_check(bool(_state()["visible"]))
	var moved := Time.get_ticks_msec()
	_emit(WIEvents.PLAYER_MOVED)
	await _wait_hidden()
	_check(Time.get_ticks_msec() - moved < 200, "post-floor movement should dismiss promptly")

func _first_frame_movement() -> void:
	_emit(WIEvents.TOAST, {"text": "Movement during the first frame."})
	_emit(WIEvents.PLAYER_MOVED)
	var elapsed := await _wait_hidden()
	_check(elapsed >= 1200 and elapsed < 1600, "first-frame dismiss must survive the rendered-event boundary")

func _modal_delivery() -> void:
	_emit(WIEvents.UI_JOURNAL_SHOWN)
	_emit(WIEvents.TOAST, {"text": "Queued while the journal is open."})
	await create_timer(0.2).timeout
	_check(not bool(_state()["visible"]) and _renders("Queued while the journal is open.") == 0)
	_emit(WIEvents.UI_JOURNAL_HIDDEN)
	await _wait_text("Queued while the journal is open.")
	_check(_renders("Queued while the journal is open.") == 1)
	await _wait_elapsed(1300)
	_check(bool(_state()["visible"]), "modal delivery must receive an ordinary readable hold")
	_emit(WIEvents.PLAYER_MOVED)
	await _wait_hidden()
	_check(_renders("Queued while the journal is open.") == 1, "modal delivery must render exactly once")

func _first_frame_transition() -> void:
	var text := "A transition during the first display frame."
	_emit(WIEvents.TOAST, {"text": text})
	_emit(WIEvents.MAP_CHANGED)
	await _wait_text(text)
	_check(_renders(text) == 1, "the interrupted first frame must not report a hidden render")
	_emit(WIEvents.PLAYER_MOVED)
	_check(await _wait_hidden() >= 1200)
	_check((_layer.get_script().get("recent_messages") as Array).count(text) == 1)

func _unread_transition() -> void:
	var text := "Unread authored copy survives a map transition."
	_emit(WIEvents.TOAST, {"text": text})
	await process_frame
	await _wait_elapsed(100)
	_emit(WIEvents.MAP_CHANGED)
	await process_frame
	await _wait_text(text)
	await _wait_elapsed(950)
	_check(bool(_state()["visible"]))
	_emit(WIEvents.PLAYER_MOVED)
	_check(await _wait_hidden() >= 1200)
	_check((_layer.get_script().get("recent_messages") as Array).count(text) == 1, "transition replay duplicates history")

func _save_contention_and_long_text() -> void:
	var text := "Your coat goes over the chair back with the package folded into it, beside the one already hanging, and the other coat is over your arm two steps from the door."
	_emit(WIEvents.TOAST, {"text": "Autosaved.", "housekeeping": true})
	await process_frame
	var queued := Time.get_ticks_msec()
	_emit(WIEvents.TOAST, {"text": text})
	await _wait_text(text)
	_check(Time.get_ticks_msec() - queued < 250, "housekeeping blocked authored text")
	_emit(WIEvents.TOAST, {"text": "Game saved.", "housekeeping": true})
	await _wait_elapsed(1600)
	_check(String(_state()["text"]) == text and bool(_state()["visible"]), "queued save shortened authored text")
	_check((_layer.get("_toast_panel") as Control).size.y > 96, "long text did not receive extra layout height")
	_emit(WIEvents.PLAYER_MOVED)
	await _wait_text("Game saved.")
	_emit(WIEvents.PLAYER_MOVED)
	await _wait_hidden()

func _transient_history() -> void:
	var history: Array = _layer.get_script().get("recent_messages")
	var before := history.size()
	_layer.call("_queue_toast", "An empty-interaction flavor line.", false, true)
	await process_frame
	_emit(WIEvents.PLAYER_MOVED)
	await _wait_hidden()
	_check(history.size() == before, "transient ambient copy polluted Recent Messages")

func _check(condition: bool, message: String = "runtime assertion failed") -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
