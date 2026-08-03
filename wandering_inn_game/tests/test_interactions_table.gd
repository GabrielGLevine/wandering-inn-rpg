extends SceneTree

## #348 slice 1 -- the property-interaction table (data/interactions.json +
## WIFieldSkills' table-lookup arm). tests/test_traversal_seams.gd stays the
## BYTE-IDENTITY referee for the two shipped rows; this file proves the
## substrate itself: the mirror contract, the injection path, the closed
## vocabularies, precedence under the authored layer, and -- the point of the
## slice -- that a NEW carrier on either side is DATA ALONE, zero engine work.

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"dialogue": {},
		"quests": {"quests": []},
		"items": _load_json("res://data/items.json"),
	}


## The two synthetic carriers the slice exists to make possible: a new
## `freezes` skill (the user's [Ice Floor] on water) and a new `burns` skill,
## neither of which touches data/skills.json or one line of engine code.
func _w1_skill_config() -> Dictionary:
	var rows: Array = (_load_json("res://data/skills.json")[WIKeys.SKILLS] as Array).duplicate(true)
	rows.append({
		WIKeys.ID: "w1_ice_floor", WIKeys.DISPLAY_NAME: "[W1 Ice Floor]",
		WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "freezes": true,
		"freeze_toast": "W1 ice floor toast.",
		"field_ambient": "W1 ice floor finds nothing to grip.",
	})
	rows.append({
		WIKeys.ID: "w1_scorch", WIKeys.DISPLAY_NAME: "[W1 Scorch]",
		WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "burns": true,
		"field_ambient": "W1 scorch finds nothing that will take the fire.",
	})
	return {WIKeys.SKILLS: rows}


## sewers + two synthetic props: a plain new burnable carrier, and one that is
## burnable AND carries an authored arm for the same skill (the precedence
## probe -- authored must always beat the table).
func _w1_scene() -> Dictionary:
	var scene: Dictionary = WISceneCatalog.compose()
	var ents: Array = scene["maps"]["sewers"]["entities"]
	ents.append({
		WIKeys.ID: "w1_thicket", WIKeys.KIND: "prop", WIKeys.CELL: [2, 5],
		WIKeys.DISPLAY_NAME: "W1 Thicket", "burnable": true,
		"burn_toast": "W1 thicket toast.",
	})
	ents.append({
		WIKeys.ID: "w1_authored_thicket", WIKeys.KIND: "prop", WIKeys.CELL: [4, 4],
		WIKeys.DISPLAY_NAME: "W1 Authored Thicket", "burnable": true,
		"requires_skill": "w1_scorch",
		"on_skill_use": {"accomplishment": "w1_authored_burns", "toast": "W1 authored arm toast."},
	})
	return scene


func _w1_game(scene: Dictionary) -> WIGame:
	var g := WIGame.new(scene, _w1_skill_config(), _sink, 4242, _combat_config())
	g.player_skills.append("w1_ice_floor")
	g.player_skills.append("w1_scorch")
	return g


func _w1_face(g: WIGame, cell: Vector2i, facing: Vector2i) -> void:
	g.transition("sewers", cell)
	g.player_facing = facing
	_events.clear()


func _w1_types() -> Array:
	var out: Array = []
	for e: Dictionary in _events:
		out.append(String(e["type"]))
	return out


func _w1_last(type: String) -> Dictionary:
	for i in range(_events.size() - 1, -1, -1):
		if String(_events[i]["type"]) == type:
			return _events[i]["payload"]
	return {}


func _init() -> void:
	WITestWatchdog.arm(self)

	# --- The table itself: shape, closed vocabularies, mirror contract.
	var table := _load_json("res://data/interactions.json")
	var w1_rows: Array = table["interactions"]
	assert(w1_rows.size() >= 1, "the property table carries at least one row")
	assert(table["outcomes"] == WIFieldSkills.OUTCOMES,
		"MIRROR CONTRACT: data/interactions.json outcomes must equal WIFieldSkills.OUTCOMES")
	var w1_skill_props: Array = table["skill_properties"]
	var w1_target_props: Dictionary = table["target_properties"]
	for row: Dictionary in w1_rows:
		assert(w1_skill_props.has(String(row["skill_property"])), "every row's skill property is registered")
		assert(w1_target_props.has(String(row["target_property"])), "every row's target property is registered")
		assert(WIFieldSkills.OUTCOMES.has(String(row["outcome"])), "every row's outcome is a shipped verb")
	for placement: Variant in w1_target_props.values():
		assert(String(placement) in [WIFieldSkills.PLACEMENT_ENTITY, WIFieldSkills.PLACEMENT_CELL],
			"every target property declares a shipped placement")

	# --- Injection: the table reaches the sim through scene_config, not disk.
	var w1_composed := WISceneCatalog.compose()
	assert(w1_composed.has("interactions"), "WISceneCatalog composes the table into scene_config")
	assert(w1_composed["interactions"] == table, "the composed table is data/interactions.json verbatim")

	# --- USER EXAMPLE 1 ([Ice Floor] on water): a NEW freezes-carrier skill
	# resolves through the shipped row with zero engine work, and the frozen
	# water is walkable.
	var w1_ice := _w1_game(_w1_scene())
	_w1_face(w1_ice, Vector2i(3, 4), Vector2i.DOWN)
	assert(w1_ice.is_cell_blocked(Vector2i(3, 5)), "the channel is impassable water before the cast")
	var w1_ice_result := w1_ice.use_skill_field("w1_ice_floor")
	assert(w1_ice_result.get("frozen", []) == [3, 5], "a brand-new freezes carrier freezes the faced water cell")
	assert(not w1_ice.is_cell_blocked(Vector2i(3, 5)), "the frozen cell is walkable (frozen_walkable)")
	assert(_w1_types() == ["skill_used", "terrain_changed", "toast"],
		"freeze_cell emits exactly skill_used -> terrain_changed -> toast")
	assert(String(_w1_last("terrain_changed").get("to", "")) == "ice", "the row's terrain value rides the event")
	assert(String(_w1_last("toast").get("text", "")) == "W1 ice floor toast.",
		"toast_from=skill reads the CASTER's authored line")
	assert(w1_ice.move_player(Vector2i.DOWN) and w1_ice.player_cell == Vector2i(3, 5), "the PC crosses on the new ice")
	w1_ice.sleep()
	assert(w1_ice.frozen_cells.is_empty(), "the row's until_sleep persistence still thaws at sleep")

	# --- A NEW burnable ENTITY carrier: also data alone.
	var w1_burn := _w1_game(_w1_scene())
	_w1_face(w1_burn, Vector2i(2, 4), Vector2i.DOWN)
	var w1_burn_result := w1_burn.use_skill_field("w1_scorch")
	assert(w1_burn_result.get("burned", "") == "w1_thicket", "a brand-new burns carrier burns a brand-new burnable prop")
	assert(w1_burn.find_entity("w1_thicket").is_empty(), "the burned prop is gone")
	assert(w1_burn.removed_entities.has("w1_thicket"), "remove_scorch persistence is permanent")
	assert(int(w1_burn.accomplishments.get("burned_the_debris", 0)) == 1, "the row's counter banks once")
	assert(_w1_types() == ["skill_used", "accomplishment_recorded", "entity_removed", "terrain_changed", "toast"],
		"remove_scorch emits skill_used -> accomplishment_recorded -> entity_removed -> terrain_changed -> toast")
	assert(String(_w1_last("terrain_changed").get("to", "")) == "scorched", "the row's terrain value rides the event")
	assert(String(_w1_last("toast").get("text", "")) == "W1 thicket toast.",
		"toast_from=target reads the PROP's authored line")

	# --- Precedence (spec §4.3): the authored arm beats the table on its own
	# entity, even when that entity also carries the target property.
	var w1_auth := _w1_game(_w1_scene())
	_w1_face(w1_auth, Vector2i(4, 3), Vector2i.DOWN)
	var w1_auth_result := w1_auth.use_skill_field("w1_scorch")
	assert(not w1_auth_result.has("burned"), "the table never resolves an entity whose authored arm answers the skill")
	assert(not w1_auth.find_entity("w1_authored_thicket").is_empty(), "the authored prop survives")
	assert(int(w1_auth.accomplishments.get("w1_authored_burns", 0)) == 1, "the AUTHORED counter banked instead")
	assert(int(w1_auth.accomplishments.get("burned_the_debris", 0)) == 0, "the table's counter never banked")
	assert(String(_w1_last("toast").get("text", "")) == "W1 authored arm toast.", "the authored line spoke")

	# --- Null cells stay null: a carrier-less target falls through to ambient,
	# and quest-prop safety holds for every burns skill, not just the shipped one.
	var w1_null := _w1_game(_w1_scene())
	_w1_face(w1_null, Vector2i(5, 2), Vector2i.DOWN)
	var w1_null_result := w1_null.use_skill_field("w1_scorch")
	assert(w1_null_result.get("ambient", "") == "w1_scorch", "an untagged prop falls through to field_ambient")
	assert(not w1_null.find_entity("drainage_marker").is_empty(), "an untagged prop is never destroyed")
	_w1_face(w1_null, Vector2i(2, 3), Vector2i.UP)
	assert(w1_null.use_skill_field("w1_ice_floor").get("ambient", "") == "w1_ice_floor",
		"a non-freezable cell falls through to field_ambient")
	assert(w1_null.frozen_cells.is_empty(), "an ambient cast freezes nothing")

	# --- Already-applied guard: a re-freeze is a fallthrough, not a second row hit.
	var w1_re := _w1_game(_w1_scene())
	_w1_face(w1_re, Vector2i(3, 4), Vector2i.DOWN)
	w1_re.use_skill_field("w1_ice_floor")
	_events.clear()
	assert(not w1_re.use_skill_field("w1_ice_floor").has("frozen"), "re-freezing an ice cell resolves no row")
	assert(not _w1_types().has("terrain_changed"), "a re-freeze emits no second terrain_changed")

	# --- The table is the ONLY resolver: strip it and both arms go inert
	# (proof that no hardcoded burnable/freezes branch survives in dispatch).
	var w1_bare_scene := _w1_scene()
	w1_bare_scene.erase("interactions")
	var w1_bare := _w1_game(w1_bare_scene)
	_w1_face(w1_bare, Vector2i(2, 4), Vector2i.DOWN)
	assert(w1_bare.use_skill_field("w1_scorch").get("ambient", "") == "w1_scorch",
		"with no table, a burns cast on a burnable prop falls through to ambient")
	assert(not w1_bare.find_entity("w1_thicket").is_empty(), "with no table nothing burns")
	_w1_face(w1_bare, Vector2i(3, 4), Vector2i.DOWN)
	assert(w1_bare.use_skill_field("w1_ice_floor").get("ambient", "") == "w1_ice_floor",
		"with no table, a freezes cast on water falls through to ambient")
	assert(w1_bare.frozen_cells.is_empty(), "with no table nothing freezes")

	print("PASS: property-interaction table -- mirror contract, injection, new carriers, precedence, inert fallthrough")
	quit(0)
