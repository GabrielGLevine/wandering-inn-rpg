extends SceneTree

var game: WIGame
var events: Array = []
var check_settlement := false
var receipts := 0

func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 9, {
		"items": _load("res://data/items.json"), "classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"), "combatants": _load("res://data/combatants.json"),
		"progression": _load("res://data/progression.json"), "dialogue": {"erin_errand": _load("res://data/dialogue/erin_errand.json")}})

func _sink(type: String, payload: Dictionary) -> void:
	events.append({"type": type, "payload": payload.duplicate(true)})
	if check_settlement and type in [WIEvents.PURCHASE_CONFIRMED, WIEvents.RESOURCES_CHANGED, WIEvents.SERVICE_RECOVERY_SETTLED]:
		assert(not game.purchase_confirm() and not game.dialogue_choose(0), "synchronous callbacks cannot buy another meal")
		assert(game.gold == 6 and game.vitals.hp == 7 and game.vitals.mp == 4, "all observers see settled cost and pools")
	if type == WIEvents.SERVICE_RECOVERY_SETTLED:
		receipts += 1
		assert(game.player_resources() == payload.after and game.gold == int(payload.gold_after))
		assert(not game.save_settlement_pending(), "settled service is saveable")
		assert(WISave.serialize(game).state.vitals.hp == payload.after.hp)

func _choice(text: String) -> int:
	var rows := game.dialogue.current_options()
	for i in rows.size():
		if String(rows[i].text) == text:
			return i
	return -1

func _service() -> void:
	assert(game.start_dialogue("erin_errand", "erin"))
	assert(game.dialogue_choose(_choice("Could I get something to eat?")))
	assert(game.dialogue.current_id == "meal_service")

func _eat(id: String) -> Dictionary:
	var offer := game.prepare_item_use(id, "world")
	assert(offer.allowed)
	return game.commit_item_use(int(offer.operation_id))

func _init() -> void:
	WITestWatchdog.arm(self)
	game = _new_game()
	game.vitals.hp = 1
	_service()
	assert(not game.dialogue_choose(0) and game.gold == 0 and game.vitals.hp == 1)
	assert(game.dialogue_choose(1) and game.dialogue.current_id == "free_rest")
	assert(game.dialogue_choose(0) and game.dialogue == null)
	game.transition("inn_upstairs", Vector2i(9, 2))
	game.player_facing = Vector2i.UP
	game.interact()
	assert(game.vitals.hp == game.player_resource_maxima().max_hp, "zero-gold non-cook can use the actual free bed")
	game = _new_game()
	game.classes = {"mage": 1}
	game.vitals.refill(game.player_resource_maxima())
	game.vitals.hp = 1
	game.vitals.mp = 0
	game.gold = 9
	_service()
	var before := WISave.serialize(game)
	assert(game.dialogue_choose(0) and game.purchase_cancel())
	assert(WISave.serialize(game) == before, "cancel changes no resource/gold/gate")
	assert(game.dialogue_choose(0))
	check_settlement = true
	assert(game.purchase_confirm())
	check_settlement = false
	assert(not game.purchase_confirm() and receipts == 1)
	assert(game.dialogue_choose(0) and game.dialogue.current_id == "meal_service")
	assert(game.dialogue_choose(0))
	game.vitals.refill(game.player_resource_maxima())
	assert(not game.purchase_confirm() and game.gold == 6, "no-benefit revalidation cannot charge")
	assert(not game.dialogue_choose(0) and game.pending_purchase.is_empty())
	game.vitals.hp -= 1
	var mp_before := game.vitals.mp
	assert(game.dialogue_choose(0) and game.purchase_confirm())
	assert(game.gold == 3 and game.vitals.hp == game.player_resource_maxima().max_hp and game.vitals.mp == mp_before)
	assert(game.accomplishment_count("deliberate_commerce") == 0)
	assert(game.dialogue_choose(1))
	game.accomplishments["resolved_wrong_order"] = 1
	game.accomplishments["chatted_with_erin"] = 4
	assert(game.start_dialogue("erin_errand", "erin"))
	var old_max := int(game.player_resources().max_hp)
	assert(game.dialogue_choose(_choice("(Take the seat. The cook is already ladling.)")))
	assert(game.well_fed and game.entity_first_use.has("meal:erin"))
	assert(game.vitals.hp == old_max + 2 and game.player_resources().max_hp == old_max + 2)
	assert(game.dialogue_choose(1))
	assert(game.start_dialogue("erin_errand", "erin"))
	assert(_choice("(Take the seat. The cook is already ladling.)") == -1)
	game.dialogue = null
	game.entity_first_use.erase("meal:erin")
	assert(game.start_dialogue("erin_errand", "erin"))
	assert(not game.dialogue_choose(_choice("(Take the seat. The cook is already ladling.)")))
	assert(not game.entity_first_use.has("meal:erin"), "refused full meal does not spend waking gate")
	game.dialogue = null
	game.sleep()
	assert(not game.well_fed and not game.entity_first_use.has("meal:erin"))
	game = _new_game()
	game.classes = {"mage": 1}
	game.vitals.refill(game.player_resource_maxima())
	game.player_cell = Vector2i(4, 2)
	game.player_facing = Vector2i.UP
	game.use_skill_field("basic_cooking")
	assert(game.item_count("hot_meal") == 0, "missing held Skill produces nothing")
	game.player_skills.append("basic_cooking")
	for i in 3:
		game.use_skill_field("basic_cooking")
	assert(game.item_count("hot_meal") == 3 and game.accomplishment_count("cooked_meal") == 3)
	game.player_cell = Vector2i(6, 3)
	game.use_skill_field("basic_cooking")
	assert(game.item_count("hot_meal") == 4, "alternate cookware retains legal access")
	game.vitals.hp = 1
	assert(_eat("hot_meal").restore_hp == 6 and game.item_count("hot_meal") == 3)
	game.player_skills.append("advanced_cooking")
	game.player_cell = Vector2i(6, 1)
	game.player_facing = Vector2i.LEFT
	game.use_skill_field("advanced_cooking")
	game.use_skill_field("advanced_cooking")
	assert(game.item_count("fine_meal") == 2)
	game.vitals.mp = 0
	assert(_eat("fine_meal").restore_mp == 4)
	assert(_eat("fine_meal").restore_mp == 4 and game.pending_meal.hp_mod == 2, "repeated healing never stacks preparation")
	game.player_skills.append("signature_dish")
	game.player_cell = Vector2i(5, 3)
	game.player_facing = Vector2i.UP
	game.use_skill_field("signature_dish")
	assert(game.item_count("signature_meal") == 1)
	game.vitals.hp = int(game.player_resource_maxima().max_hp) - 1
	assert(_eat("signature_meal").restore_hp == 1 and game.pending_meal.hp_mod == 2 and game.pending_meal.damage_mod == 1)
	assert(not game.sellable_items().has("hot_meal") and not game.sellable_items().has("fine_meal"))
	assert(not game.sell_item("hot_meal") and game.gold == 0)
	var cooked_before := game.accomplishment_count("cooked_meal")
	game.player_cell = Vector2i(3, 3)
	game.use_skill_field("basic_cooking")
	assert(game.item_count("hot_meal") == 3 and game.accomplishment_count("cooked_meal") == cooked_before, "missing station cannot fabricate a meal")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(game)))
	assert(WISave.apply(game, saved) and game.item_count("hot_meal") == 3)
	game.vitals.hp -= 2
	assert(_eat("hot_meal").restore_hp == 2 and game.item_count("hot_meal") == 2)
	print("PASS test_meal_recovery: early service, atomic confirmation/gates, free bed, held cookware, capped food and reload")
	quit(0)
