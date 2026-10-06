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
	_game.sim._items.burst_mp = _game.sim.item("mana_potion").duplicate(true)
	_game.sim._items.burst_mp.id = "burst_mp"
	for i in 3:
		_game.sim.pickup("burst_mp", "test")
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
			_messages.call("_mark_use_rendered", payload)
	)
	var inventory_script := _patched("res://src/ui/inventory.gd", "var Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant")
	_inventory = inventory_script.new()
	_inventory.set("Game", _game)
	_inventory.set("ObservableBus", _bus)
	_inventory.set("WISettings", SettingsBoundary.new())
	root.add_child(_inventory)
	_inventory.call("_open")
	_game.sim.vitals.mp = int(_game.sim.player_resource_maxima().max_mp)
	await _select("test_mp")
	var no_benefit := _game.sim.player_resources()
	var confirm := InputEventAction.new()
	confirm.action = "confirm"
	confirm.pressed = true
	_inventory.call("_unhandled_input", confirm)
	_check(not (_inventory.get("_bar_button") as Button).disabled and not _messages.item_use_busy(), "keyboard no-benefit Use leaves bar control enabled")
	(_inventory.get("_bar_button") as Button).pressed.emit()
	_check(_game.sim.hotbar_loadout.has("item:test_mp") and _game.sim.item_count("test_mp") == 2, "bar placement still works after keyboard no-benefit Use")
	_check(_game.sim.player_resources() == no_benefit, "no-benefit keyboard action preserves resources")
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
	Input.action_press("confirm")
	first.call()
	first.call()
	_check(_game.sim.item_count("mending_draught") == 1, "duplicate activation consumes once")
	await _frames()
	_check(_messages.item_use_busy(), "held confirm cannot rearm after visible receipt")
	Input.action_release("confirm")
	await _frames()
	button.pressed.emit()
	_check(_game.sim.item_count("mending_draught") == 1, "current button binding cannot consume again inside post-receipt burst")
	await _rearm()
	_check(not _messages.item_use_busy() and bool(_inventory.get("open")), "visible receipt releases latch with inventory open")
	_check(_event_count(WIEvents.UI_ITEM_USE_RENDERED) == 1, "one result has one correlated render")
	_check((_messages.get("_toast_queue") as Array).is_empty(), "in-panel receipt does not duplicate into world queue")
	_check((_inventory.get("_use_receipt") as Label).text.contains("1 left"), "receipt retains captured remaining count")
	_game.sim.vitals.hp = 1
	await _select("mending_draught")
	var last: Callable = button.pressed.get_connections()[0]["callable"]
	last.call()
	await _rearm()
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
	await _rearm()
	_check(WISave.serialize(_game.sim) == before and not _messages.item_use_busy(), "cancel preserves full saved tuple and releases latch")
	button.pressed.emit()
	await create_timer(0.35).timeout
	await _frames(2)
	_check(_event_count(WIEvents.UI_ITEM_USE_WARNING_ARMED) == 1, "warning arms after release and readable delay")
	_messages.call("_confirm_presented_use")
	await _rearm()
	_check(_game.sim.vitals.hp == 8 and _game.sim.vitals.mp == 6 and _game.sim.vitals.mp_potion_doses == 4 and _game.sim.item_count("test_mp") == 1, "confirmed warning commits captured fourth dose once")
	var receipt := (_inventory.get("_use_receipt") as Label).text
	_game.sim.vitals.hp = 2
	_check((_inventory.get("_use_receipt") as Label).text == receipt and receipt.contains("Lost 4 HP"), "rendered poison receipt never rereads later resources")
	await _live_button_burst()
	_inventory.free()
	_combat_previews()
	await _mobile_combat_receipt()
	_messages.free()
	await _frames()
	if not _failures.is_empty():
		quit(1)
		return
	print("PASS test_consumable_frontend: real controls, counts, tokens, warning cancellation and captured in-panel receipts")
	quit(0)


func _combat_previews() -> void:
	_game.sim.pickup("mana_potion", "test")
	_game.sim.pickup("mana_potion", "test")
	_game.sim.hotbar_loadout.append("item:mana_potion")
	_game.sim.transition("floodplains", Vector2i(3, 2))
	_check(_game.sim.start_combat("relc_spar"), "authored combat initializes")
	var combat := _game.sim.combat
	combat.active_index = combat.turn_order.find("pc")
	var pc: Dictionary = combat.combatants.pc
	pc.ap = 0
	pc.mp = 0
	pc.hp = 12
	var view := WICombatView.new(combat)
	var hud: RefCounted = load("res://src/combat/combat_hud.gd").new(null, null, null)
	var item := _game.sim.item("mana_potion").duplicate(true)
	item["count"] = _game.sim.item_count("mana_potion")
	item["preview"] = _game.sim.preview_item_use("mana_potion", "combat")
	var slots: Array = hud.rebuild_slots(view, "pc", _game.sim.hotbar_loadout, [item])
	var index := -1
	for i in slots.size():
		if String(slots[i].get("id", "")) == "mana_potion":
			index = i
	_check(index >= 0, "MP potion has a real combat item slot")
	var rendered: Array = hud.render_bar_slots(view, slots)
	_check(not rendered[index].affordable and String(hud._slot_info_line(rendered[index])).contains("Not enough AP"), "HUD refusal uses core preview with no AP")
	pc.ap = 2
	var selected := _game.sim.prepare_item_use("mana_potion", "combat")
	_game.sim.preview_item_use("remedy_draught", "combat")
	slots[index].preview = _game.sim.preview_item_use("mana_potion", "combat")
	rendered = hud.render_bar_slots(view, slots)
	_check(rendered[index].affordable and rendered[index].label.contains("×2") and String(hud._slot_info_line(rendered[index])).contains("Restore 6 MP"), "HUD shows count and projected MP restoration")
	var result := _game.sim.commit_item_use(int(selected.operation_id))
	_check(result.committed and pc.ap == 1 and _game.sim.item_count("mana_potion") == 1, "inspecting another slot preserves selected operation")


func _rearm() -> void:
	await create_timer(0.36).timeout
	await _frames(2)


func _live_button_burst() -> void:
	_game.sim.vitals.mp = 0
	_game.sim.vitals.mp_potion_doses = 0
	await _select("burst_mp")
	var button: Button = _inventory.get("_use_button")
	button.pressed.emit()
	await create_timer(0.03).timeout
	await _frames(3)
	button.pressed.emit()
	_check(_game.sim.item_count("burst_mp") == 2 and _game.sim.vitals.mp == 6 and _game.sim.vitals.mp_potion_doses == 1, "timed repeat uses current signal binding and consumes one of three mana doses")
	await _rearm()
	button.pressed.emit()
	_check(_game.sim.item_count("burst_mp") == 1 and _game.sim.vitals.mp_potion_doses == 2, "deliberate later button press consumes the second dose")
	await _rearm()


class HintsBoundary extends RefCounted:
	func label(action: String) -> String:
		return action

class TouchLayoutBoundary extends RefCounted:
	func uses_touch_layout() -> bool:
		return true
	func touch_size(viewport: Viewport, size: Vector2) -> Vector2:
		return WIResponsiveLayout.touch_size(viewport, size)
	func readable_font_size(viewport: Viewport, size: int, scale: float = 1.0) -> int:
		return WIResponsiveLayout.readable_font_size(viewport, size, scale)
	func place_panel(panel: Control, rect: Rect2) -> void:
		WIResponsiveLayout.place_panel(panel, rect)


func _mobile_combat_receipt() -> void:
	var combat := _game.sim.combat
	combat.combatants.pc.ap = 2
	combat.combatants.pc.mp = 0
	combat.combatants.pc.hp = 12
	_game.sim.vitals.mp_potion_doses = 4
	var screen_script := _patched("res://src/combat/combat_screen.gd", "var Game: Variant\nvar ObservableBus: Variant\nvar WISettings: Variant\nvar TestDriver: Variant\nvar WIInputHints: Variant", true)
	var screen: CanvasLayer = screen_script.new()
	screen.set("Game", _game)
	screen.set("ObservableBus", _bus)
	screen.set("WISettings", SettingsBoundary.new())
	screen.set("WIInputHints", HintsBoundary.new())
	root.add_child(screen)
	var host := Control.new()
	UIChrome.full_rect(host)
	screen.add_child(host)
	var hud_script := GDScript.new()
	hud_script.source_code = FileAccess.get_file_as_string("res://src/combat/combat_hud.gd").replace("class_name WICombatHud\n", "").replace("extends RefCounted", "extends RefCounted\nvar WIResponsiveLayout: Variant")
	assert(hud_script.reload() == OK)
	var hud: RefCounted = hud_script.new(host, null, screen)
	hud.set("WIResponsiveLayout", TouchLayoutBoundary.new())
	hud.build()
	var board: Node = load("res://src/combat/board_renderer.gd").new()
	screen.add_child(board)
	screen.set("_board_renderer", board)
	screen.set("_ai_playback", load("res://src/combat/combat_playback.gd").new(board, screen))
	screen.set("_view", WICombatView.new(combat))
	screen.set("_hud", hud)
	screen.set("_root", host)
	screen.set("_mode", screen.Mode.HOTBAR)
	var slots: Array = hud.rebuild_slots(screen.get("_view"), "pc", _game.sim.hotbar_loadout, screen.call("_usable_combat_items"))
	screen.set("_bar_slots", slots)
	var index := -1
	for i in slots.size():
		if String(slots[i].get("id", "")) == "mana_potion":
			index = i
	screen.call("_activate_bar_slot", index)
	screen.call("_refresh")
	var context: String = hud.mobile_hud().snapshot().context_text
	_check(context.contains("+6 MP") and context.contains("4 HP poison") and context.contains("1 AP") and not context.contains("refill your steps"), "actual mobile rail shows item recovery/AP/poison instead of Dash")
	var receipt_callback := func(type: String, payload: Dictionary) -> void:
		if type == WIEvents.ITEM_USE_SETTLED and String(payload.get("context", "")) == "combat":
			screen.call("_render_item_receipt", payload.duplicate(true))
	_bus.domain_event.connect(receipt_callback)
	var start := _bus.events.size()
	screen.call("_confirm_bar_action")
	await _frames(6)
	var surface := ""
	for event: Dictionary in _bus.events.slice(start):
		if event.type == WIEvents.UI_ITEM_USE_RENDERED:
			surface = String(event.payload.get("surface", ""))
	_check(surface == "item_receipt", "hidden mobile desktop feed cannot certify the receipt")
	_check(_messages.item_use_busy() and (_messages.get("_use_overlay") as Control).is_visible_in_tree(), "visible phone receipt retains latch until player closes it")
	_check((_messages.get("_use_warning_label") as Label).text.contains("Restored 6 MP"), "phone receipt draws captured restoration")
	(_messages.get("_use_cancel") as Button).pressed.emit()
	await _rearm()
	_check(not _messages.item_use_busy(), "actual receipt Close releases guarded use latch")
	_bus.domain_event.disconnect(receipt_callback)
	screen.free()
