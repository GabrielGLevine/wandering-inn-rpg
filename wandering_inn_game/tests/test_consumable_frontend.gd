extends SceneTree

class GameBoundary extends RefCounted:
	var sim: WIGame

class BusBoundary extends RefCounted:
	signal domain_event(type: String, payload: Dictionary)
	var events: Array[Dictionary] = []
	func emit_domain_event(type: String, payload: Dictionary) -> void:
		events.append({"type": type, "payload": payload.duplicate(true)})
		domain_event.emit(type, payload)

class SettingsBoundary extends RefCounted:
	const TEXT_SCALE_STEPS := [1.0, 1.15, 1.3]
	func text_scale_step() -> int:
		return 0

var _game := GameBoundary.new()
var _bus := BusBoundary.new()
var _inventory: CanvasLayer
var _messages: CanvasLayer
var _failures: Array[String] = []

func _init() -> void:
	WITestWatchdog.arm(self)
	_run.call_deferred()

func _data(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + path + ".json"))

func _patched(path: String, globals: String, suppress_ready := false) -> GDScript:
	var source := FileAccess.get_file_as_string(path)
	source = source.replace("extends CanvasLayer", "extends CanvasLayer\n" + globals)
	if suppress_ready:
		source = source.replace("func _ready()", "func _build_full_ui()")
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK, "production frontend compiles with injected autoload boundaries")
	return script

func _frames(count := 5) -> void:
	for i in count:
		await process_frame

func _select(id: String) -> void:
	var ids: Array = _inventory.get("_item_ids")
	_inventory.set("_cursor", ids.find(id))
	_inventory.call("_render_detail")
	await _frames(2)

func _event_count(type: String) -> int:
	var count := 0
	for event: Dictionary in _bus.events:
		if event.type == type:
			count += 1
	return count

func _check(condition: bool, text: String) -> void:
	if not condition:
		_failures.append(text)
		print("FAIL: " + text)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_game.sim = WIGame.new(WISceneCatalog.compose(), _data("skills"), _bus.emit_domain_event, 9, {
		"items": _data("items"), "classes": _data("classes"), "progression": _data("progression"),
		"arenas": _data("arenas"), "combatants": _data("combatants"),
	})
	_game.sim.classes = {"mage": 1}
	_game.sim.vitals.refill(_game.sim.player_resource_maxima())
	_game.sim.pickup("mending_draught", "test")
	_game.sim.pickup("mending_draught", "test")
	_game.sim.pickup("remedy_draught", "test")
	_game.sim._items.test_mp = {"id": "test_mp", "name": "Test Mana", "stackable": true, "consumable_family": "mp_potion", "usable_in_combat": true, "use_effect": {"restore_mp": 6}}
	_game.sim.pickup("test_mp", "test")
	_game.sim.pickup("test_mp", "test")
	var message_script := _patched("res://src/ui/message_layer.gd", "var Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant\nvar TestDriver: Variant\nvar WIInputHints: Variant", true)
	_messages = message_script.new()
	_messages.set("Game", _game)
	_messages.set("ObservableBus", _bus)
	_messages.set("WISettings", SettingsBoundary.new())
	root.add_child(_messages)
	_messages.add_to_group("wi_item_use_presenter")
	# Use only the presenter's production event boundary, not unrelated world chrome.
	_bus.domain_event.connect(func(type: String, payload: Dictionary) -> void:
		if type == WIEvents.ITEM_USE_OFFERED:
			_messages.call("_show_use_warning", payload)
		elif type in [WIEvents.ITEM_USE_SETTLED, WIEvents.ITEM_USE_REFUSED, WIEvents.ITEM_USE_CANCELLED]:
			_messages.call("_accept_use_result", payload)
		elif type == WIEvents.UI_ITEM_USE_RENDERED:
			_messages.set("_use_rendered", true)
	)
	var inventory_script := _patched("res://src/ui/inventory.gd", "var Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant")
	_inventory = inventory_script.new()
	_inventory.set("Game", _game)
	_inventory.set("ObservableBus", _bus)
	_inventory.set("WISettings", SettingsBoundary.new())
	root.add_child(_inventory)
	_inventory.call("_open")
	_game.sim.vitals.hp = 1
	await _select("mending_draught")
	var button: Button = _inventory.get("_use_button")
	var bar: Button = _inventory.get("_bar_button")
	var stale: Callable = button.pressed.get_connections()[0]["callable"]
	bar.pressed.emit()
	_check(_game.sim.item_count("mending_draught") == 2 and _game.sim.vitals.hp == 1, "bar control does not consume or heal")
	_check(_game.sim.hotbar_loadout.has("item:mending_draught"), "bar control changes the combat loadout")
	stale.call()
	_check(_game.sim.item_count("mending_draught") == 2, "callback from prior render cannot use new token")
	var first: Callable = button.pressed.get_connections()[0]["callable"]
	first.call()
	first.call()
	_check(_game.sim.item_count("mending_draught") == 1, "duplicate activation consumes once")
	await _frames()
	_check(not _messages.item_use_busy() and bool(_inventory.get("open")), "visible receipt releases latch with inventory open")
	_check(_event_count(WIEvents.UI_ITEM_USE_RENDERED) == 1, "one result has one correlated render")
	_check((_messages.get("_toast_queue") as Array).is_empty(), "in-panel receipt does not duplicate into world queue")
	_check((_inventory.get("_use_receipt") as Label).text.contains("1 left"), "receipt retains captured remaining count")
	_game.sim.vitals.hp = 1
	await _select("mending_draught")
	var last: Callable = button.pressed.get_connections()[0]["callable"]
	last.call()
	await _frames()
	last.call()
	_check(_game.sim.item_count("mending_draught") == 0 and _game.sim.item_count("remedy_draught") == 1, "final stock callback never consumes adjacent row")
	_game.sim.vitals.mp = 0
	_game.sim.vitals.hp = 12
	_game.sim.vitals.mp_potion_doses = 3
	await _select("test_mp")
	var before := WISave.serialize(_game.sim)
	button.pressed.emit()
	_check(bool(_messages.get("_use_warning")), "fourth mana dose opens warning")
	_check((_messages.get("_use_confirm") as Button).disabled, "opening press cannot immediately confirm risk")
	_messages.call("_confirm_presented_use")
	_check(WISave.serialize(_game.sim) == before, "unarmed confirm does not mutate")
	_messages.call("_cancel_presented_use")
	await _frames()
	_check(WISave.serialize(_game.sim) == before and not _messages.item_use_busy(), "cancel preserves full saved tuple and releases latch")
	button.pressed.emit()
	await create_timer(0.35).timeout
	await _frames(2)
	_check(_event_count(WIEvents.UI_ITEM_USE_WARNING_ARMED) == 1, "warning arms after release and readable delay")
	_messages.call("_confirm_presented_use")
	await _frames()
	_check(_game.sim.vitals.hp == 8 and _game.sim.vitals.mp == 6 and _game.sim.vitals.mp_potion_doses == 4 and _game.sim.item_count("test_mp") == 1, "confirmed warning commits captured fourth dose once")
	var receipt := (_inventory.get("_use_receipt") as Label).text
	_game.sim.vitals.hp = 2
	_check((_inventory.get("_use_receipt") as Label).text == receipt and receipt.contains("Lost 4 HP"), "rendered poison receipt never rereads later resources")
	_inventory.free()
	_messages.free()
	await _frames()
	if not _failures.is_empty():
		quit(1)
		return
	print("PASS test_consumable_frontend: real controls, counts, tokens, warning cancellation and captured in-panel receipts")
	quit(0)
