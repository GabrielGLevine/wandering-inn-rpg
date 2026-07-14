extends Node
## gamepad) via `_input()` on a high-priority node -- observing only, never
## calling `set_input_as_handled()`, so it can sit anywhere in the tree
## without disturbing the real input-consumption chain (world.gd's /
## combat_screen.gd's `_unhandled_input`, panel GUI input, etc.). Godot's
## fixed dispatch order already runs every node's `_input()` before any
## `_unhandled_input()` this same frame, so a panel that composes a hint via
## `label()` in response to the SAME event that changed the device always
## sees the fresh classification; `process_priority` is pinned low anyway so
## this settles before any OTHER `_input()` listener, not just the
## unhandled-input consumers.

signal device_changed(device: String)

const LABELS := {
	"kb": {
		"move": "Arrows", "interact": "E", "confirm": "Enter", "cancel": "Esc",
		"cycle": "Tab", "journal": "J", "inventory": "I", "end_turn": "E",
		"hotbar": "number keys",
	},
	"pad": {
		"move": "stick", "interact": "A", "confirm": "A", "cancel": "B",
		"cycle": "LT", "journal": "Y", "inventory": "X", "end_turn": "Start",
		"hotbar": "LB/RB + A",
	},
}
## Motion axis-value deadzone for pad classification -- matches every pad
## action's own InputMap deadzone (project.godot's `"deadzone": 0.5` on
## every action), so "the player is on a pad" classification and actual
## action activation agree on what counts as a deliberate stick push (a
## resting stick with a little drift must not flip the device to "pad").
const MOTION_DEADZONE := 0.5

var _device := "kb"


func _ready() -> void:
	set_process_input(true)
	process_priority = -1000


func _input(event: InputEvent) -> void:
	var next := _classify(event)
	if next == "" or next == _device:
		return
	_device = next
	ObservableBus.emit_domain_event(WIEvents.INPUT_DEVICE_CHANGED, {"device": _device})
	device_changed.emit(_device)


func _classify(event: InputEvent) -> String:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		return "kb"
	if event is InputEventJoypadButton:
		return "pad" if (event as InputEventJoypadButton).pressed else ""
	if event is InputEventJoypadMotion:
		return "pad" if absf((event as InputEventJoypadMotion).axis_value) > MOTION_DEADZONE else ""
	return ""


func device() -> String:
	return _device


func label(action: String) -> String:
	var table: Dictionary = LABELS.get(_device, LABELS["kb"])
	return String(table.get(action, action))
