extends SceneTree

var game: WIGame
var mode := ""
var observations := 0
var nested_claims := 0

func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 9, {
		"items": _load("res://data/items.json"), "classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"), "combatants": _load("res://data/combatants.json"),
		"progression": _load("res://data/progression.json"), "deliveries": _load("res://data/deliveries.json"),
	})

func _sink(type: String, payload: Dictionary) -> void:
	if game == null:
		return
	if mode == "victory" and type in [WIEvents.LOOT_DROPPED, WIEvents.LOOT_PENDING, WIEvents.COMBAT_RESOLVED]:
		observations += 1
		assert(game.removed_entities.has("awakened_boss"), "retirement precedes reward callbacks")
		assert(game.item_count("mending_draught") == WIItems.MAX_COUNT)
		assert(game.pending_loot == [{"item": "mending_draught", "source": "awakened_boss", "count": 1}])
		if type == WIEvents.LOOT_DROPPED:
			assert(payload.items.has("mending_draught") and payload.pending.has("mending_draught"))
			assert(not payload.delivered.has("mending_draught"))
		game.resolve_combat()
	if mode == "accept" and type == WIEvents.ACCOMPLISHMENT_RECORDED:
		assert(game.accepted_delivery_id == "delivery_krshia_wool" and game.inventory.has("parcel_plains_wool"))
	if mode == "arrival" and type == WIEvents.ACCOMPLISHMENT_RECORDED:
		assert(not game.inventory.has("parcel_plains_wool"))
		assert(game.accomplishment_count("completed_delivery") == 1)
	if mode == "turnin" and type == WIEvents.GOLD_CHANGED:
		observations += 1
		assert(game.accepted_delivery_id == "" and game.accepted_delivery_baseline.is_empty())
		assert(game.accomplishment_count("completed_delivery_delivery_krshia_wool") == 1)
		if game.turn_in_delivery():
			nested_claims += 1

func _init() -> void:
	WITestWatchdog.arm(self)
	game = _new_game()
	game.pickup("mending_draught", "test")
	game.consumable_counts.mending_draught = WIItems.MAX_COUNT
	var encoded := JSON.stringify(WISave.serialize(game))
	assert(WISave.apply(game, JSON.parse_string(encoded)) and game.item_count("mending_draught") == WIItems.MAX_COUNT)
	var duplicate: Dictionary = JSON.parse_string(encoded)
	duplicate.state.inventory.append("mending_draught")
	assert(not WISave.apply(game, duplicate), "duplicate carrier rejects before load")
	game.transition("deep_tunnels", Vector2i(3, 3))
	assert(game.start_combat("awakened_boss"))
	game.combat._finish(true, false)
	mode = "victory"
	game.resolve_combat()
	mode = ""
	assert(observations == 3 and game.pending_loot.size() == 1)
	var earned: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(game)))
	var loaded := _new_game()
	assert(WISave.apply(loaded, earned))
	assert(loaded.pending_loot == game.pending_loot and loaded.item_count("mending_draught") == WIItems.MAX_COUNT)
	for bad: Variant in [null, {}, [{"item": "mending_draught", "source": "awakened_boss", "count": 0}], [{"item": "mending_draught", "source": "awakened_boss", "count": true}], [{"item": "rusty_sword", "source": "awakened_boss", "count": 1}], [{"item": "missing", "source": "awakened_boss", "count": 1}]]:
		var corrupt := earned.duplicate(true)
		corrupt.state.pending_loot = bad
		var before := WISave.serialize(loaded)
		assert(not WISave.apply(loaded, corrupt))
		assert(WISave.serialize(loaded) == before)
	game = loaded
	assert(game.claim_pending_loot() == 0 and game.pending_loot.size() == 1)
	game.vitals.hp = 1
	assert(game.use_item("mending_draught"))
	assert(game.item_count("mending_draught") == WIItems.MAX_COUNT - 1)
	assert(game.claim_pending_loot() == 1 and game.pending_loot.is_empty())
	assert(game.item_count("mending_draught") == WIItems.MAX_COUNT and game.claim_pending_loot() == 0)
	game = _new_game()
	mode = "accept"
	game.accept_delivery("delivery_krshia_wool")
	mode = ""
	game.transition("street", Vector2i(14, 5))
	game.move_player(Vector2i.UP)
	mode = "arrival"
	game.move_player(Vector2i.UP)
	mode = "turnin"
	assert(game.turn_in_delivery())
	mode = ""
	assert(game.gold == 1 and nested_claims == 0 and observations == 4)
	print("PASS test_consumable_rewards: lossless earned overflow, JSON, claim once and atomic delivery")
	quit(0)
