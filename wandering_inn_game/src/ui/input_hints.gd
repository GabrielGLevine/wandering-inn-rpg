extends Node
## Device detection + the keycap-hint
## composer. Register as autoload `WIInputHints`.
##
## Tracks which device class the player last touched (keyboard/mouse vs.
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
##
## Emits `input_device_changed` {device:"kb"|"pad"} ONLY on an actual
## change (never spams the bus every keypress/stick wobble) -- panels that
## want to re-render their hint on a device swap listen for this, the same
## trigger-list idiom every other presentation layer in this codebase uses
## (see e.g. field_hotbar.gd's WORLD_READY/CLASS_* list).
##
## THE KEYBOARD GLYPHS ARE BYTE-IDENTICAL TO THE OLD HARDCODED STRINGS ON
## PURPOSE: `_device` defaults to "kb" and QA (`qa/test_driver.gd`) injects
## only real `InputEventKey`s (per CLAUDE.md's "QA safety proven" note), so
## every canonical script's exact-text pin on a hint string composed through
## `label()` keeps passing with ZERO re-pins -- only the DATA strings this
## plan's S3 task also rewrites (arenas.json tutor_lines, relc_intro.json)
## needed a re-pin, because those are genuinely NEW copy, not a glyph swap.

signal device_changed(device: String)

## action -> {device -> glyph text}. One row per keycap hint this plan's
## surface map swaps (char_creation/message_layer/journal/dialogue_panel/
## game.gd/targeting_controller/combat_hud) -- see each call site for the
## exact composed sentence. Pad glyphs match S1's LOCKED binding table
## (project.godot): confirm/interact=A, cancel=B, cycle=LT, inventory=X,
## journal=Y, end_turn=Start; `hotbar` has no single pad button (S1's
## slot_prev/slot_next+confirm idiom), hence the compound "LB/RB + A" hint.
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


## Pure classification, no side effects -- split out from `_input()` so unit
## tests (`tests/test_input_hints.gd`) can drive it directly with synthetic
## events instead of routing real input through a live Viewport. Returns
## "kb"/"pad", or "" for an event that shouldn't reclassify the device at all
## (a joypad button RELEASE, or stick motion still inside the deadzone).
func _classify(event: InputEvent) -> String:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		return "kb"
	if event is InputEventJoypadButton:
		return "pad" if (event as InputEventJoypadButton).pressed else ""
	if event is InputEventJoypadMotion:
		return "pad" if absf((event as InputEventJoypadMotion).axis_value) > MOTION_DEADZONE else ""
	return ""


## The last-seen device class ("kb"/"pad").
func device() -> String:
	return _device


## The device-correct glyph text for `action` (see `LABELS`' keys). Falls
## back to the action name itself for an unrecognized key -- never crashes a
## caller that passes a typo'd action, matching the graceful-degrade spirit
## of the `InputMap.has_action` guards elsewhere in this codebase.
func label(action: String) -> String:
	var table: Dictionary = LABELS.get(_device, LABELS["kb"])
	return String(table.get(action, action))
