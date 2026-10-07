extends SceneTree

var game: WIGame
var snapshots: Array = []
var capture := false

func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 9, {
		"items": _load("res://data/items.json"), "classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"), "combatants": _load("res://data/combatants.json"),
		"progression": _load("res://data/progression.json"),
	})

func _sink(type: String, _payload: Dictionary) -> void:
	if capture and game != null and type in [WIEvents.ITEM_GAINED, WIEvents.ITEM_LOST, WIEvents.GOLD_CHANGED, WIEvents.DIALOGUE_ENDED]:
		snapshots.append(WISave.serialize(game))

func _shop() -> void:
	game.dialogue = WIDialogue.new({"start": "buy", "nodes": {"buy": {"speaker": "Xif", "text": "A draught.", "options": [
		{"text": "Buy", "requires": {"gold": 10}, "effects": [{"gold": -10}, {"item": "mending_draught"}], "end": true}
	]}}}, game._build_dialogue_ctx(), game._addressed_sink)
	game.dialogue.begin()

func _init() -> void:
	WITestWatchdog.arm(self)
	game = _new_game()
	assert(game.pickup("mending_draught", "test"))
	assert(game.pickup("mending_draught", "test"))
	assert(game.item_count("mending_draught") == 2 and game.inventory.count("mending_draught") == 1)
	assert(not game.pickup("rusty_sword", "test"))
	assert(not game.consumable_counts.has("rusty_sword"))
	var encoded := JSON.stringify(WISave.serialize(game))
	var restored := _new_game()
	assert(WISave.apply(restored, JSON.parse_string(encoded)), "JSON float counts restore")
	assert(restored.item_count("mending_draught") == 2)
	var legacy: Dictionary = JSON.parse_string(encoded)
	legacy.version = 11
	legacy.state.erase("consumable_counts")
	assert(WISave.apply(restored, legacy))
	assert(restored.item_count("mending_draught") == 1 and restored.resonance_limit() == 4)
	for bad: Variant in [null, {}, {"mending_draught": 0}, {"mending_draught": true}, {"mending_draught": 1.5}, {"mending_draught": -1}, {"mending_draught": 2147483648.0}, {"mending_draught": 2, "rusty_sword": 1}, {"mending_draught": 2, "fine_meal": 1}]:
		var corrupted: Dictionary = JSON.parse_string(encoded)
		corrupted.state.consumable_counts = bad
		var before := WISave.serialize(restored)
		assert(not WISave.apply(restored, corrupted), "bad modern counts refuse")
		assert(WISave.serialize(restored) == before, "bad counts never partly load")
	assert(game.remove_item("mending_draught", "handover"))
	assert(game.item_count("mending_draught") == 1)
	game.gold = 20
	capture = true
	for purchase in 2:
		_shop()
		assert(game.dialogue_choose(0))
		assert(game.purchase_confirm())
		assert(not game.purchase_confirm())
		assert(game.item_count("mending_draught") == 2 + purchase)
		assert(game.gold == 10 - 10 * purchase)
		for snap: Dictionary in snapshots:
			assert(snap.state.consumable_counts.mending_draught == 2 + purchase)
			assert(snap.state.gold == 10 - 10 * purchase, "purchase observers see complete tuple")
		snapshots.clear()
	assert(game.sell_item("mending_draught"))
	for snap: Dictionary in snapshots:
		assert(snap.state.consumable_counts.mending_draught == 2 and snap.state.gold == 5)
	capture = false
	assert(game.remove_item("mending_draught", "handover"))
	assert(game.remove_item("mending_draught", "handover"))
	assert(not game.inventory.has("mending_draught") and not game.consumable_counts.has("mending_draught"))
	assert(not game.remove_item("mending_draught", "handover"))
	game.pickup("mending_draught", "test")
	game.consumable_counts.mending_draught = WIItems.MAX_COUNT
	game.gold = 20
	_shop()
	assert(game.dialogue_choose(0))
	assert(not game.purchase_confirm() and game.gold == 20 and not game.dialogue.finished)
	var container := {"id": "test_chest", "kind": "prop", "contains": ["fine_meal", "mending_draught"]}
	assert(game._interactions.dispatch(container, game.social_talked, game.entity_first_use, game.container_state).get("inventory_refused", false))
	assert(not game.container_state.has("test_chest") and game.item_count("fine_meal") == 0)
	assert(not game.can_change_items([], ["mending_draught", "mending_draught", "missing"]))
	game.consumable_counts.mending_draught = 1
	assert(not game.can_change_items([], ["mending_draught", "mending_draught"]))
	print("PASS test_consumable_counts: quantities, JSON migration, atomic purchases/sales and overflow")
	quit(0)
