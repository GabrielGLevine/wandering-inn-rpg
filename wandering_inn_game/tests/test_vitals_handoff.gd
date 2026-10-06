extends SceneTree

const SAVE_DIR := "res://qa_output/vitals_handoff_unit"
var _events: Array = []
var _game: WIGame
var _prebuild: Dictionary = {}
var _banked: Dictionary = {}
var _settled: Dictionary = {}
var _sleep_save: Dictionary = {}
var _resolve_callbacks := 0

class EventBus:
	extends RefCounted
	signal domain_event(type: String, payload: Dictionary)
	func emit_domain_event(type: String, payload: Dictionary) -> void:
		domain_event.emit(type, payload)


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _new_game(sink: Callable = Callable()) -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), (sink if sink.is_valid() else _sink), 37, {
		"combatants": _load("res://data/combatants.json"),
		"classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"),
		"items": _load("res://data/items.json"),
	})


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload.duplicate(true)})
	if _game == null:
		return
	if type == WIEvents.COMBAT_PREPARING:
		assert(_game.combat == null, "checkpoint precedes battle construction")
		_prebuild = WISave.serialize(_game)
	if type == WIEvents.COMBAT_RESOLVED:
		assert(_game.combat != null, "banking callbacks still see terminal combat")
		_banked = WISave.serialize(_game)
		_resolve_callbacks += 1
		_game.resolve_combat()
	if type == WIEvents.COMBAT_SETTLED:
		assert(_game.combat == null and not _game.save_settlement_pending())
		_settled = WISave.serialize(_game)
	if type == WIEvents.SLEEP_SETTLED:
		assert(not _game.save_settlement_pending())
		_sleep_save = WISave.serialize(_game)
	if type == WIEvents.CLASS_GAINED or (type == WIEvents.PHASE_CHANGED and bool(payload.get("slept", false))):
		assert(_game.save_settlement_pending(), "early sleep events cannot autosave")


func _win(game: WIGame) -> void:
	for id: String in game.combat.combatants.keys():
		if String(game.combat.combatants[id][WIKeys.SIDE]) == "enemy":
			game.combat.apply_damage(id, 10000, "pc", false)
	assert(game.combat.finished and bool(game.combat.outcome["victory"]))
	game.resolve_combat()


func _init() -> void:
	WITestWatchdog.arm(self)
	_check_handoff()
	_check_autosaves_and_rollback()
	_game = null
	print("PASS test_vitals_handoff")
	quit(0)


func _check_handoff() -> void:
	_game = _new_game()
	_game.classes = {"mage": 3}
	_game.vitals.hp = 12
	_game.vitals.mp = 6
	_game.vitals.mp_potion_doses = 4
	_game.pending_meal = {WIKeys.HP_MOD: 8}
	var encounter := _game.find_entity("relc_spar")
	var arena: String = encounter["arena"]
	encounter["arena"] = "missing"
	assert(not _game.start_combat("relc_spar"))
	assert(_game.pending_meal == {WIKeys.HP_MOD: 8}, "failed entry must preserve preparation")
	encounter["arena"] = arena
	assert(_game.start_combat("relc_spar"))
	assert(_prebuild["state"]["pending_meal"] == {WIKeys.HP_MOD: 8})
	assert(_prebuild["state"]["vitals"] == {"hp": 12, "mp": 6, "mp_potion_doses": 4})
	assert(_game.preparation_snapshot()["armed"].is_empty())
	assert(_game.preparation_snapshot()["active"] == {WIKeys.HP_MOD: 8})
	var pc: Dictionary = _game.combat.combatants["pc"]
	assert(int(pc[WIKeys.HP]) == 12 and int(pc[WIKeys.MP]) == 6)
	_game.combat.apply_damage("pc", 9, "training_dummy_a", true)
	assert(int(pc[WIKeys.HP]) == 9 and int(pc[WIKeys.MP]) == 0, "mana shield expenditure remains authoritative")
	_game.combat.active_index = _game.combat.turn_order.find("pc")
	pc[WIKeys.AP] = 3
	assert(_game.pickup("mending_draught", "test"))
	assert(_game.combat_use_item("mending_draught"), "existing healing action succeeds")
	assert(int(pc[WIKeys.HP]) == 17)
	_win(_game)
	assert(_game.vitals.hp == 17 and _game.vitals.mp == 0 and _game.vitals.mp_potion_doses == 4)
	assert(_banked["state"]["vitals"] == _settled["state"]["vitals"], "banking sees committed world resources")
	assert(_resolve_callbacks == 1, "reentrant callback cannot bank twice")
	var victories := _game.accomplishment_count("victories")
	_game.resolve_combat()
	assert(_game.accomplishment_count("victories") == victories)
	assert(_game.preparation_snapshot()["active"].is_empty())
	assert(_game.start_combat("relc_spar"))
	assert(int(_game.combat.combatants["pc"][WIKeys.HP]) == 17 and int(_game.combat.combatants["pc"][WIKeys.MP]) == 0, "second practice fight carries depleted pools")
	_win(_game)
	_game.pending_meal = {WIKeys.HP_MOD: 8}
	assert(_game.start_combat("relc_spar"))
	_game.combat.combatants["pc"][WIKeys.HP] = _game.combat.combatants["pc"][WIKeys.MAX_HP]
	_win(_game)
	assert(_game.vitals.hp == int(_game.player_resource_maxima()[WIKeys.MAX_HP]), "expiry clamps healed HP to world maximum")
	_game.vitals.hp = 3
	_game.classes = {}
	_game.record_accomplishment("learned_magic_from_pisces")
	_game.sleep()
	assert(_sleep_save["state"]["vitals"] == _game.vitals.serialized())
	assert(_game.vitals.mp > 0 and _game.vitals.mp_potion_doses == 0)
	var captured := (_events.filter(func(ev: Dictionary) -> bool: return ev["type"] == WIEvents.RESOURCES_CHANGED)[0] as Dictionary).duplicate(true)
	_game.pending_meal = {WIKeys.HP_MOD: 99}
	assert(captured == _events.filter(func(ev: Dictionary) -> bool: return ev["type"] == WIEvents.RESOURCES_CHANGED)[0], "event history remains frozen")
	_game = null


func _check_autosaves_and_rollback() -> void:
	var source := FileAccess.get_file_as_string("res://src/core/game.gd")
	var script := GDScript.new()
	script.source_code = source.replace("extends Node", "extends Node\nvar ObservableBus: Variant\nvar WIInputHints: Variant").replace("user://saves", SAVE_DIR)
	assert(script.reload() == OK)
	var controller: Node = script.new()
	var bus := EventBus.new()
	controller.set("ObservableBus", bus)
	controller.set("_autosave_announced", true)
	var game := _new_game(bus.emit_domain_event)
	controller.set("sim", game)
	bus.domain_event.connect(controller._on_domain_event)
	game.classes = {"mage": 3}
	game.vitals.hp = 9
	game.vitals.mp = 2
	game.vitals.mp_potion_doses = 5
	game.pending_meal = {WIKeys.HP_MOD: 4}
	assert(game.pickup("mending_draught", "test"))
	controller.save_auto()
	var checkpoint := FileAccess.get_file_as_string(SAVE_DIR + "/auto.json")
	assert(game.start_combat("relc_spar"))
	var pre := _load(SAVE_DIR + "/auto_pre_combat.json")
	assert(int(pre["state"]["pending_meal"][WIKeys.HP_MOD]) == 4)
	game.combat.active_index = game.combat.turn_order.find("pc")
	game.combat.combatants["pc"][WIKeys.AP] = 3
	assert(game.combat_use_item("mending_draught"))
	game.actions_since_sleep = 39
	game._tick_action()
	assert(FileAccess.get_file_as_string(SAVE_DIR + "/auto.json") == checkpoint, "combat phase change cannot overwrite rollback")
	game.combat.apply_damage("pc", 10000, "training_dummy_a", true)
	assert(not bool(game.combat.outcome["victory"]))
	game.resolve_combat()
	assert(game.vitals.hp == 9, "defeat does not commit zero or invent a one-HP survival")
	assert(controller.load_slot("auto_pre_combat", "defeat", "relc_spar"))
	game = controller.get("sim")
	assert(game.vitals.hp == 9 and game.vitals.mp == 2 and game.vitals.mp_potion_doses == 5)
	assert(game.inventory.has("mending_draught") and int(game.pending_meal[WIKeys.HP_MOD]) == 4)
	assert(game.warded_encounters.has("relc_spar"), "retry preserves encounter exit grace")
	assert(game.start_combat("relc_spar"))
	assert(controller.load_slot("auto"), "abandon retains its distinct auto checkpoint")
	game = controller.get("sim")
	assert(JSON.parse_string(JSON.stringify(WISave.serialize(game))) == JSON.parse_string(checkpoint))
	game.record_accomplishment("learned_magic_from_pisces")
	game.sleep()
	var slept := _load(SAVE_DIR + "/auto.json")
	assert(slept["state"]["vitals"] == JSON.parse_string(JSON.stringify(game.vitals.serialized())), "actual Game autosave captures settled refill")
	assert(int(slept["state"]["vitals"]["mp_potion_doses"]) == 0)
	controller.set("sim", null)
	controller.free()
	for name: String in ["auto", "auto_pre_combat"]:
		DirAccess.remove_absolute(SAVE_DIR + "/" + name + ".json")
	DirAccess.remove_absolute(SAVE_DIR)
