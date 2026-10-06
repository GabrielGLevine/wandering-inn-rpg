extends SceneTree

var _events: Array[Dictionary] = []


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _new_game(resonance: Dictionary = {}) -> WIGame:
	var progression := _load("res://data/progression.json")
	if not resonance.is_empty():
		progression["resonance"] = resonance
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 37, {
		"combatants": _load("res://data/combatants.json"),
		"classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"),
		"items": _load("res://data/items.json"),
		"progression": progression,
	})


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload.duplicate(true)})


func _init() -> void:
	WITestWatchdog.arm(self)
	_check_equipment()
	_check_growth()
	_check_migration()
	_check_resources()
	print("PASS test_capacity_570")
	quit(0)


func _check_equipment() -> void:
	var game := _new_game()
	assert(game.resonance_limit() == 4)
	for id: String in ["stonescale_talisman", "moon_bone_amulet", "hedge_ward_charm", "hunters_fang_talisman", "phosphor_pendant"]:
		assert(game.pickup(id, "unit"))
	assert(game.equip("stonescale_talisman") and game.equip("moon_bone_amulet"))
	assert(game.resonance_used() == 4 and game.equipped["accessory_3"] == "")
	var before := WISave.serialize(game)
	_events.clear()
	assert(not game.equip("hedge_ward_charm"))
	assert(WISave.serialize(game) == before, "capacity refusal with a free position is lossless")
	assert(_events.size() == 1 and _events[0]["payload"]["text"] == WIGame._CAPACITY_REFUSAL_TOAST)
	assert(game.unequip("accessory_1") and game.unequip("accessory_2"))
	assert(game.equip("hedge_ward_charm") and game.equip("hunters_fang_talisman") and game.equip("phosphor_pendant"))
	assert(game.resonance_used() == 3)
	before = WISave.serialize(game)
	_events.clear()
	assert(not game.equip("stonescale_talisman"))
	assert(WISave.serialize(game) == before, "physical full refusal is lossless")
	assert(_events.size() == 1 and _events[0]["payload"]["text"] == WIGame._ACCESSORY_SLOTS_FULL_TOAST)


func _check_growth() -> void:
	for config: Dictionary in [{}, {"initial_capacity": 7, "growth_amount": 2}]:
		var game := _new_game(config)
		var initial := game.resonance_limit()
		var amount := int(config.get("growth_amount", 1))
		assert(initial == int(config.get("initial_capacity", 4)))
		game.record_accomplishment("door_awakened")
		game.sleep()
		assert(game.resonance_limit() == initial, "first attunement rest does not grow capacity")
		game.sleep()
		assert(game.resonance_limit() == initial + amount and game.accomplishment_count("resonance_grown") == 1)
		var restored := _new_game(config)
		assert(WISave.apply(restored, WISave.serialize(game)))
		restored.sleep()
		assert(restored.resonance_limit() == initial + amount, "reload and later sleep never duplicate growth")
		assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == WIEvents.TOAST and String(e["payload"].get("text", "")).contains("Yours grew by %s" % ("one" if amount == 1 else str(amount)))))


func _check_migration() -> void:
	var source := _new_game()
	source.classes = {"mage": 3}
	source.vitals.hp = 7
	source.vitals.mp = 0
	source.vitals.mp_potion_doses = 4
	assert(source.pickup("stonescale_talisman", "unit") and source.equip("stonescale_talisman"))
	source.lore_notes.append("An old note.")
	for version: int in [9, 10]:
		for old: int in [0, 2, 3, 12]:
			var data := WISave.serialize(source)
			data["version"] = version
			data["state"]["resonance_capacity"] = old
			var untouched := data.duplicate(true)
			var restored := _new_game()
			assert(WISave.apply(restored, data))
			assert(data == untouched, "migration cannot mutate caller's save")
			assert(restored.resonance_limit() == old + 2)
			assert(restored.equipped == source.equipped and restored.inventory == source.inventory and restored.lore_notes == source.lore_notes)
			assert(restored.vitals.serialized() == source.vitals.serialized(), "present depleted pools and exposure survive capacity migration")
			assert(WISave.apply(restored, WISave.serialize(restored)))
			assert(restored.resonance_limit() == old + 2, "modern reload does not repeat migration")
	for version: int in range(2, 9):
		var data := WISave.serialize(_new_game())
		data["version"] = version
		data["state"]["resonance_capacity"] = 3
		var restored := _new_game()
		assert(WISave.apply(restored, data) and restored.resonance_limit() == 5, "older schemas still reach the capacity migration")
	for grown: int in [0, 1]:
		var data := WISave.serialize(source)
		data["version"] = 10
		data["state"].erase("resonance_capacity")
		data["state"]["accomplishments"]["resonance_grown"] = grown
		var restored := _new_game()
		assert(WISave.apply(restored, data) and restored.resonance_limit() == 4 + grown)
	for version: int in [9, 10, WISave.VERSION]:
		for invalid: Variant in [-1, 2.5, INF, NAN, "4", true, null]:
			var data := WISave.serialize(source)
			data["version"] = version
			data["state"]["resonance_capacity"] = invalid
			var target := _new_game()
			var before := WISave.serialize(target)
			assert(not WISave.apply(target, data))
			assert(WISave.serialize(target) == before, "invalid capacity must fail before any game mutation")
	var overflow := WISave.serialize(source)
	overflow["version"] = 10
	overflow["state"]["resonance_capacity"] = WIResonance.MAX_CAPACITY
	assert(not WISave.apply(_new_game(), overflow), "migration cannot overflow capacity")
	var missing := WISave.serialize(source)
	missing["state"].erase("resonance_capacity")
	assert(not WISave.apply(_new_game(), missing), "modern saves require explicit capacity")


func _check_resources() -> void:
	for holds_tough_body: bool in [false, true]:
		var game := _new_game()
		game.classes = {"mage": 3}
		if holds_tough_body:
			game.classes["warrior"] = 1
		game.vitals.hp = 7
		game.vitals.mp = 0
		game.vitals.mp_potion_doses = 5
		var before := game.player_resources()
		assert(game.pickup("stonescale_talisman", "unit") and game.equip("stonescale_talisman"))
		var after := game.player_resources()
		assert(int(after[WIKeys.MAX_HP]) == int(before[WIKeys.MAX_HP]) + (0 if holds_tough_body else 10), "Tough Body grants HP only when not already held")
		assert(game.vitals.hp == 7 and game.vitals.mp == 0 and game.vitals.mp_potion_doses == 5, "equipment never heals or restores MP/exposure")
		assert(game.unequip("accessory_1") and game.equip("stonescale_talisman"))
		assert(game.vitals.hp == 7 and game.vitals.mp == 0)
		assert(game.start_combat("relc_spar"))
		var pc: Dictionary = game.combat.combatants["pc"]
		assert(int(pc[WIKeys.HP]) == 7 and int(pc[WIKeys.MP]) == 0)
		assert(pc[WIKeys.SKILLS].has("mana_shield") and int(pc[WIKeys.DAMAGE_REDUCTION]) == 1)
		game.combat.apply_damage("pc", 3, "training_dummy_a", true)
		assert(int(pc[WIKeys.HP]) == 5 and int(pc[WIKeys.MP]) == 0, "depleted Mana Shield cannot absorb damage after equipping")
