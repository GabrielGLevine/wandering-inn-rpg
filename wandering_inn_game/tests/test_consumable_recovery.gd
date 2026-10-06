extends SceneTree

var game: WIGame
var events: Array = []
var reenter := false
var observed := 0

func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _new_game() -> WIGame:
	var g := WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 9, {
		"items": _load("res://data/items.json"), "classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"), "combatants": _load("res://data/combatants.json"),
		"progression": _load("res://data/progression.json"),
	})
	g.classes = {"mage": 1}
	g.vitals.refill(g.player_resource_maxima())
	g._items.test_mp = {"id": "test_mp", "stackable": true, "consumable_family": "mp_potion", "usable_in_combat": true, "use_effect": {"restore_mp": 6}}
	for i in 8:
		g.pickup("test_mp", "test")
	g.pickup("mending_draught", "test")
	return g

func _sink(type: String, payload: Dictionary) -> void:
	events.append({"type": type, "payload": payload.duplicate(true)})
	if type == WIEvents.ITEM_USE_OFFERED:
		assert(not bool(game.commit_item_use(int(payload.operation_id), true).get("committed", false)), "warning callbacks cannot confirm themselves")
	if reenter and type in [WIEvents.INVENTORY_USE_RESOLVED, WIEvents.ITEM_USE_SETTLED]:
		observed += 1
		assert(game.player_resources() == payload.after, "observer sees fully settled resource tuple")
		assert(game.item_count(String(payload.item)) == int(payload.count_after))
		assert(not bool(game.commit_item_use(int(payload.operation_id)).get("committed", false)))
		assert(game.prepare_item_use(String(payload.item), String(payload.context)).reason == "busy", "callbacks cannot create another use")

func _use(id: String, context := "world", confirm := false) -> Dictionary:
	var offer := game.prepare_item_use(id, context)
	assert(offer.allowed, "expected useful owned item")
	return game.commit_item_use(int(offer.operation_id), confirm)

func _init() -> void:
	WITestWatchdog.arm(self)
	game = _new_game()
	var stock := game.item_count("test_mp")
	var full := game.prepare_item_use("test_mp", "world")
	assert(not full.allowed and full.reason == "no_benefit")
	assert(game.item_count("test_mp") == stock and game.vitals.mp_potion_doses == 0)
	game.vitals.mp = 0
	var frozen := game.prepare_item_use("test_mp", "world")
	frozen.after.mp = 999
	reenter = true
	var used := game.commit_item_use(int(frozen.operation_id))
	reenter = false
	assert(used.committed and used.restore_mp == 6 and game.vitals.mp == 6 and observed == 2)
	assert(not bool(game.commit_item_use(int(frozen.operation_id)).get("committed", false)))
	for dose in [2, 3]:
		game.vitals.mp = 0
		assert(_use("test_mp").dose_number == dose)
	game.vitals.mp = 0
	game.vitals.hp = 12
	var harmful := game.prepare_item_use("test_mp", "world")
	assert(harmful.confirmation_required and harmful.poison_hp == 4 and harmful.restore_mp == 6)
	var before := WISave.serialize(game)
	assert(game.commit_item_use(int(harmful.operation_id)).reason == "confirmation_required")
	assert(WISave.serialize(game) == before)
	assert(game.cancel_item_use(int(harmful.operation_id)))
	assert(not bool(game.commit_item_use(int(harmful.operation_id), true).get("committed", false)))
	assert(WISave.serialize(game) == before)
	var fourth := _use("test_mp", "world", true)
	assert(fourth.committed and game.vitals.hp == 8 and game.vitals.mp_potion_doses == 4)
	game.vitals.mp = 0
	assert(not game.prepare_item_use("test_mp", "world").confirmation_required)
	game.vitals.hp = 4
	var lethal := game.prepare_item_use("test_mp", "world")
	assert(not lethal.allowed and lethal.reason == "lethal_world_poison")
	assert(game.vitals.hp == 4 and game.vitals.mp_potion_doses == 4)
	game.vitals.hp = 8
	var stale := game.prepare_item_use("test_mp", "world")
	game.vitals.mp = 1
	assert(game.commit_item_use(int(stale.operation_id)).reason == "stale_operation")
	assert(game.vitals.mp_potion_doses == 4)
	var encoded := JSON.stringify(WISave.serialize(game))
	var count_before_load := game.item_count("test_mp")
	var pre_load := game.prepare_item_use("test_mp", "world")
	assert(WISave.apply(game, JSON.parse_string(encoded)))
	assert(not bool(game.commit_item_use(int(pre_load.operation_id)).get("committed", false)))
	assert(game.item_count("test_mp") == count_before_load and game.vitals.mp_potion_doses == 4)
	game.transition("floodplains", Vector2i(3, 2))
	assert(game.vitals.mp_potion_doses == 4)
	assert(game.start_combat("relc_spar"))
	var battle := game.combat
	battle.active_index = battle.turn_order.find("pc")
	var pc: Dictionary = battle.combatants.pc
	pc.ap = 0
	assert(game.prepare_item_use("test_mp", "combat").reason == "insufficient_ap")
	pc.ap = 2
	pc.mp = 0
	pc.hp = 8
	var enemy_index := (battle.active_index + 1) % battle.turn_order.size()
	battle.active_index = enemy_index
	assert(game.prepare_item_use("test_mp", "combat").reason == "wrong_actor")
	battle.active_index = battle.turn_order.find("pc")
	pc.damage_reduction = 100
	pc.skills.append("mana_shield")
	battle.difficulty_damage_taken_mult = 0.1
	reenter = true
	var combat_use := _use("test_mp", "combat")
	reenter = false
	assert(combat_use.committed and pc.hp == 4 and pc.mp == 6 and pc.ap == 1, "poison bypasses armor, shield and difficulty")
	assert(game.vitals.mp_potion_doses == 5 and not battle.finished)
	pc.mp = 0
	pc.hp = 3
	var doomed := _use("test_mp", "combat")
	assert(doomed.committed and pc.hp == 0 and not pc.alive and battle.finished and not battle.outcome.victory)
	assert(pc.mp == 6 and pc.ap == 0 and game.vitals.mp_potion_doses == 6)
	assert(game.prepare_item_use("test_mp", "combat").reason in ["not_alive", "finished_combat"])
	game = _new_game()
	game.vitals.hp = 1
	game.vitals.mp = 0
	game._items.combined = {"id": "combined", "stackable": true, "consumable_family": "hp_potion", "use_effect": {"restore_hp": 8, "restore_mp": 6}}
	game.pickup("combined", "test")
	assert(_use("combined").restore_hp == 8 and game.vitals.hp == 9 and game.vitals.mp == 6)
	assert(game.vitals.mp_potion_doses == 0)
	game.vitals.hp = int(game.player_resource_maxima().max_hp) - 2
	assert(_use("mending_draught").restore_hp == 2 and game.item_count("mending_draught") == 0)
	game.vitals.mp_potion_doses = 4
	game.sleep()
	assert(game.vitals.mp_potion_doses == 0 and game.vitals.mp == game.player_resource_maxima().max_mp)
	game = _new_game()
	game.pickup("fine_meal", "test")
	var before_sleep := game.player_resources().duplicate(true)
	var old_waking := game.prepare_item_use("fine_meal", "world")
	assert(old_waking.allowed)
	game.preview_item_use("mending_draught", "world")
	assert(int(game._pending_item_use.plan.operation_id) == int(old_waking.operation_id), "slot previews do not replace selected intent")
	game.sleep()
	assert(game.player_resources() == before_sleep, "same-state sleep regression really returns identical pools")
	assert(not bool(game.commit_item_use(int(old_waking.operation_id)).get("committed", false)))
	var pre_talk := game.prepare_item_use("fine_meal", "world")
	assert(game._begin_code_dialogue({"start": "done", "nodes": {"done": {"speaker": "Erin", "text": "Hello.", "options": [{"text": "Leave.", "end": true}]}}}, "test", "test"))
	assert(game.dialogue_choose(0))
	assert(game.dialogue == null and game.player_resources() == before_sleep)
	assert(not bool(game.commit_item_use(int(pre_talk.operation_id)).get("committed", false)), "leave-and-return dialogue invalidates the old token")
	print("PASS test_consumable_recovery: capped recovery, tokens, dose boundary, JSON, AP and lethal poison")
	quit(0)
