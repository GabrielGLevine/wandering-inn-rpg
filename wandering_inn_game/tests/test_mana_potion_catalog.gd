extends SceneTree

func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _init() -> void:
	WITestWatchdog.arm(self)
	var game := WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), func(_t: String, _p: Dictionary) -> void: pass, 9, {
		"items": _load("res://data/items.json"), "classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"), "combatants": _load("res://data/combatants.json"),
		"progression": _load("res://data/progression.json"), "dialogue": {"xif": _load("res://data/dialogue/xif.json")},
	})
	# Unit setup supplies class/gold; production-input earned acquisition belongs to QA.
	game.classes = {"mage": 1}
	game.vitals.refill(game.player_resource_maxima())
	game.gold = 40
	game.transition("pallass_market", Vector2i(5, 6))
	game.player_facing = Vector2i.UP
	game.interact()
	assert(game.dialogue != null and game.dialogue.current_options().size() == 6)
	assert(game.item("mana_potion").use_effect.restore_mp == 6)
	assert(game.dialogue_choose(4) and game.item_count("mana_potion") == 0 and game.gold == 40)
	assert(game.purchase_cancel() and game.item_count("mana_potion") == 0 and game.gold == 40)
	for unit in 4:
		assert(game.dialogue_choose(4))
		assert(game.purchase_confirm())
		assert(game.item_count("mana_potion") == unit + 1 and game.gold == 30 - unit * 10)
		assert(game.dialogue_choose(0), "existing bought node returns to hub")
	assert(not game.dialogue_choose(4), "unaffordable fifth dose refuses")
	assert(game.dialogue_choose(5), "existing exit remains reachable")
	assert(game.dialogue == null)
	for dose in 3:
		game.vitals.mp = 0
		var offer := game.prepare_item_use("mana_potion", "world")
		assert(offer.allowed and offer.restore_mp == 6 and offer.poison_hp == 0)
		assert(game.commit_item_use(int(offer.operation_id)).committed)
		assert(game.item_count("mana_potion") == 3 - dose)
	game.vitals.mp = 0
	var fourth := game.prepare_item_use("mana_potion", "world")
	assert(fourth.dose_number == 4 and fourth.confirmation_required and fourth.poison_hp == 4)
	assert(game.commit_item_use(int(fourth.operation_id)).reason == "confirmation_required")
	assert(game.item_count("mana_potion") == 1)
	assert(game.commit_item_use(int(fourth.operation_id), true).committed)
	assert(game.item_count("mana_potion") == 0 and not game.inventory.has("mana_potion"))
	assert(game.vitals.mp_potion_doses == 4)
	print("PASS test_mana_potion_catalog: authored vendor, confirmed stock, actual data recovery and dose boundary")
	quit(0)
