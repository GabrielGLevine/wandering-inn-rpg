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
	# Slice 2's third synthetic carrier: a brand-new `cleans` skill, the dirty
	# pass's own "a new carrier is data alone" proof.
	rows.append({
		WIKeys.ID: "w1_scrub", WIKeys.DISPLAY_NAME: "[W1 Scrub]",
		WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "cleans": true,
		"field_ambient": "W1 scrub finds nothing worth wiping.",
	})
	rows.append({
		WIKeys.ID: "w1_cut", WIKeys.DISPLAY_NAME: "[W1 Cut]",
		WIKeys.CONTEXTS: ["exploration"], WIKeys.FIELD: true, "cuts": true,
		"field_ambient": "W1 cut finds nothing to clear.",
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
	# THE DIRTY-PASS PRECEDENCE PAIR (slice 2's regression-proof-by-construction
	# claim, made a test arm): the same `dirty` tag on two props, one of which
	# also keeps an authored arm for the same skill. The table generalizes over
	# the untagged-grime one; the authored one must still win on its own entity.
	ents.append({
		WIKeys.ID: "w1_grime", WIKeys.KIND: "prop", WIKeys.CELL: [6, 2],
		WIKeys.DISPLAY_NAME: "W1 Grime", "dirty": true,
		"state_counter": "w1_grime_cleaned",
		"clean_toast": "W1 grime toast.",
	})
	ents.append({
		WIKeys.ID: "w1_authored_grime", WIKeys.KIND: "prop", WIKeys.CELL: [8, 2],
		WIKeys.DISPLAY_NAME: "W1 Authored Grime", "dirty": true,
		"state_counter": "w1_grime_cleaned",
		"clean_toast": "W1 grime toast.",
		"requires_skill": "w1_scrub",
		"on_skill_use": {"accomplishment": "w1_authored_cleans", "toast": "W1 authored scrub toast."},
	})
	# `hearth` + `person` carriers for the state_set and refusal arms.
	ents.append({
		WIKeys.ID: "w1_brazier", WIKeys.KIND: "prop", WIKeys.CELL: [10, 2],
		WIKeys.DISPLAY_NAME: "W1 Brazier", "hearth": true,
		"state_counter": "w1_brazier_lit",
		"kindle_toast": "W1 brazier toast.",
	})
	ents.append({
		WIKeys.ID: "w1_bystander", WIKeys.KIND: "npc", WIKeys.CELL: [12, 2],
		WIKeys.DISPLAY_NAME: "W1 Bystander", "person": true,
	})
	ents.append({
		WIKeys.ID: "w1_briars", WIKeys.KIND: "prop", WIKeys.CELL: [14, 2],
		WIKeys.DISPLAY_NAME: "W1 Briars", "cuttable": true,
		"cut_toast": "W1 briars cut toast.",
	})
	# #398-p2: the counter-override pair. Same `burnable` row, same `cuttable`
	# row -- these two name their OWN counters where their siblings above take
	# the row default, which is the whole point of counter_from:"target".
	ents.append({
		WIKeys.ID: "w1_own_thicket", WIKeys.KIND: "prop", WIKeys.CELL: [16, 2],
		WIKeys.DISPLAY_NAME: "W1 Own-Counter Thicket", "burnable": true,
		"burn_counter": "w1_burned_its_own",
		"burn_toast": "W1 own-counter thicket toast.",
	})
	ents.append({
		WIKeys.ID: "w1_own_briars", WIKeys.KIND: "prop", WIKeys.CELL: [18, 2],
		WIKeys.DISPLAY_NAME: "W1 Own-Counter Briars", "cuttable": true,
		"cut_counter": "w1_cut_its_own",
		"cut_toast": "W1 own-counter briars cut toast.",
	})
	return scene


func _w1_game(scene: Dictionary) -> WIGame:
	var g := WIGame.new(scene, _w1_skill_config(), _sink, 4242, _combat_config())
	g.inventory.clear()
	g.equipped[WIKeys.WEAPON] = ""
	g.player_skills.append("w1_ice_floor")
	g.player_skills.append("w1_scorch")
	g.player_skills.append("w1_scrub")
	g.player_skills.append("w1_cut")
	return g


func _w1_face(g: WIGame, cell: Vector2i, facing: Vector2i) -> void:
	_w1_face_on(g, "sewers", cell, facing)


## The same seating on ANY map -- the cross-map isolation arms stand in
## deep_tunnels and then walk the save back to sewers.
func _w1_face_on(g: WIGame, map_id: String, cell: Vector2i, facing: Vector2i) -> void:
	g.transition(map_id, cell)
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
	var shipped_skills: Array = _load_json("res://data/skills.json")[WIKeys.SKILLS]
	var shipped_by_id: Dictionary = {}
	for skill: Dictionary in shipped_skills:
		shipped_by_id[String(skill[WIKeys.ID])] = skill
	for cut_skill: String in ["power_strike", "piercing_strikes"]:
		assert((shipped_by_id[cut_skill][WIKeys.CONTEXTS] as Array) == ["combat", "exploration"]
			and bool(shipped_by_id[cut_skill][WIKeys.FIELD])
			and bool(shipped_by_id[cut_skill]["cuts"]),
			"%s carries the exact dual-context field cuts shape" % cut_skill)
	assert(bool(shipped_by_id["flame_jet"]["burns"]), "flame_jet carries burns")
	var w1_rows: Array = table["interactions"]
	assert(w1_rows.size() >= 1, "the property table carries at least one row")
	assert(table["outcomes"] == WIFieldSkills.OUTCOMES,
		"MIRROR CONTRACT: data/interactions.json outcomes must equal WIFieldSkills.OUTCOMES")
	var w1_skill_props: Array = table["skill_properties"]
	var w1_target_props: Dictionary = table["target_properties"]
	var w1_order: Array = w1_rows.map(func(row: Dictionary) -> String:
		return "%s x %s" % [String(row["skill_property"]), String(row["target_property"])])
	assert(w1_order == [
		"burns x burnable", "freezes x freezable", "burns x frozen",
		"burns x freezable", "burns x hearth", "burns x unlit",
		"toggles_light x unlit", "cleans x dirty", "freezes x hearth",
		"freezes x person", "repairs x broken", "anchors x gap",
		"cuts x cuttable",
	], "property rows keep their exact shipped order; cuts x cuttable appends last")
	# COUNTER SHAPE PIN (#398-p2 review HIGH-1). The two row-defaulted banking
	# rows must BOTH carry the per-carrier override triple -- row `counter`
	# fallback + counter_from "target" + the carrier field `counter_key` names.
	# Dropping any leg of it puts every burnable (or every cuttable) in the game
	# back on one shared world-event id, which is the bug this pin exists for; a
	# mutation of any of the three values reds here.
	var w1_counter_shape: Dictionary = {}
	for row: Dictionary in w1_rows:
		if String(row["outcome"]) != WIFieldSkills.OUTCOME_REMOVE_SCORCH:
			assert(not row.has("counter_from"),
				"only a row-defaulted banking verb may declare counter_from (state_set is carrier-sourced by substrate)")
			continue
		w1_counter_shape["%s x %s" % [String(row["skill_property"]), String(row["target_property"])]] = [
			String(row.get("counter", "")), String(row.get("counter_from", "")), String(row.get("counter_key", "")),
		]
	assert(w1_counter_shape == {
		"burns x burnable": ["burned_the_debris", "target", "burn_counter"],
		"cuts x cuttable": ["cut_through_growth", "target", "cut_counter"],
	}, "every remove_scorch row keeps its row-default counter AND its per-carrier override key")
	for row: Dictionary in w1_rows:
		assert(w1_skill_props.has(String(row["skill_property"])), "every row's skill property is registered")
		assert(w1_target_props.has(String(row["target_property"])), "every row's target property is registered")
		assert(WIFieldSkills.OUTCOMES.has(String(row["outcome"])), "every row's outcome is a shipped verb")
	for placement: Variant in w1_target_props.values():
		assert(String(placement) in [WIFieldSkills.PLACEMENT_ENTITY, WIFieldSkills.PLACEMENT_CELL],
			"every target property declares a shipped placement")

	# --- VERB/PLACEMENT BINDING (v0.18 W1 review fix). Each verb's body has a
	# fixed target shape; nothing used to bind the two, so a lint-clean row could
	# hard-error a cast (remove_scorch reaching target[id] with no entity) or
	# silently flip an arbitrary cell's walkability (freeze_cell on an entity
	# class). Three proofs: the const covers the verb set, every SHIPPED row
	# obeys it, and a violating row is INERT in the engine rather than fatal.
	assert(WIFieldSkills.OUTCOME_PLACEMENT.keys().size() == WIFieldSkills.OUTCOMES.size(),
		"OUTCOME_PLACEMENT names exactly the shipped verb set")
	for w1_verb: String in WIFieldSkills.OUTCOMES:
		assert(WIFieldSkills.OUTCOME_PLACEMENT.has(w1_verb),
			"every shipped verb declares the placement its body dereferences")
		assert(String(WIFieldSkills.OUTCOME_PLACEMENT[w1_verb]) in [WIFieldSkills.PLACEMENT_ENTITY, WIFieldSkills.PLACEMENT_CELL, WIFieldSkills.PLACEMENT_ANY],
			"a verb's declared placement is one of the shipped shapes, or the ANY wildcard")
	for row: Dictionary in w1_rows:
		var w1_wants := String(WIFieldSkills.OUTCOME_PLACEMENT[String(row["outcome"])])
		assert(w1_wants == WIFieldSkills.PLACEMENT_ANY
				or w1_wants == String(w1_target_props[String(row["target_property"])]),
			"every shipped row binds its verb to the placement that verb acts on")
	# PLACEMENT_ANY is a VERB-side wildcard and must never leak into the target
	# vocabulary -- a target property declaring it would skip the binding guard.
	for placement: Variant in w1_target_props.values():
		assert(String(placement) != WIFieldSkills.PLACEMENT_ANY,
			"no target property may declare the 'any' wildcard as its placement")

	# --- ROW ORDER IS THE CONTRACT (slice 2). A frozen water cell carries BOTH
	# `frozen` and `freezable`, so the thaw row has to precede the water
	# refusal or fire could never take ice back off a channel.
	var w1_thaw_at := -1
	var w1_water_refusal_at := -1
	for i in range(w1_rows.size()):
		var r: Dictionary = w1_rows[i]
		if String(r["skill_property"]) == "burns" and String(r["target_property"]) == "frozen":
			w1_thaw_at = i
		if String(r["skill_property"]) == "burns" and String(r["target_property"]) == "freezable":
			w1_water_refusal_at = i
	assert(w1_thaw_at >= 0 and w1_water_refusal_at >= 0, "both burns-on-cell rows ship")
	assert(w1_thaw_at < w1_water_refusal_at,
		"burns x frozen (thaw) must precede burns x freezable (the water refusal)")

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

	var w1_cut := _w1_game(_w1_scene())
	_w1_face(w1_cut, Vector2i(14, 3), Vector2i.UP)
	var w1_cut_result := w1_cut.use_skill_field("w1_cut")
	assert(w1_cut_result.get("burned", "") == "w1_briars",
		"cuts x cuttable reuses remove_scorch without a sibling verb")
	assert(w1_cut.find_entity("w1_briars").is_empty(), "the cuttable carrier is removed permanently")
	assert(int(w1_cut.accomplishments.get("cut_through_growth", 0)) == 1,
		"the cuts row banks its own row-parameterized counter")
	assert(String(_w1_last("terrain_changed").get("to", "")) == "cleared",
		"the cuts row supplies its own terrain value")
	assert(String(_w1_last("toast").get("text", "")) == "W1 briars cut toast.",
		"toast_from=target reads the cuttable PROP's authored line")

	# --- PER-TARGET COUNTER OVERRIDE (#398-p2 review HIGH-1), the engine half.
	# The plain thicket above banked the ROW's `burned_the_debris`; this carrier
	# names its own id in the field `counter_key` points at and banks THAT, with
	# nothing spilling onto the shared counter. Same proof on the cuts row, so
	# the field is table-wide vocabulary and not a burn special case.
	var w1_own := _w1_game(_w1_scene())
	_w1_face(w1_own, Vector2i(16, 3), Vector2i.UP)
	assert(w1_own.use_skill_field("w1_scorch").get("burned", "") == "w1_own_thicket",
		"a burnable carrier with its own counter still resolves the shared burns row")
	assert(int(w1_own.accomplishments.get("w1_burned_its_own", 0)) == 1,
		"counter_from=target banks the CARRIER's own id")
	assert(int(w1_own.accomplishments.get("burned_the_debris", 0)) == 0,
		"an overriding carrier banks NOTHING onto the row's shared counter")
	assert(_w1_types() == ["skill_used", "accomplishment_recorded", "entity_removed", "terrain_changed", "toast"],
		"the override changes the banked id only -- the remove_scorch stream is byte-identical")
	assert(String(_w1_last("toast").get("text", "")) == "W1 own-counter thicket toast.",
		"the overriding carrier still speaks its own burn line")
	_w1_face(w1_own, Vector2i(18, 3), Vector2i.UP)
	assert(w1_own.use_skill_field("w1_cut").get("burned", "") == "w1_own_briars",
		"the cuts row honors the same override vocabulary")
	assert(int(w1_own.accomplishments.get("w1_cut_its_own", 0)) == 1,
		"the cuttable carrier's own counter banks")
	assert(int(w1_own.accomplishments.get("cut_through_growth", 0)) == 0,
		"the cuts row's shared counter stays untouched by an overriding carrier")
	# A carrier that authors an EMPTY override falls back to the row counter
	# rather than banking "" -- the fallback is what keeps sewers' own debris
	# working while a pocket two maps away overrides.
	var w1_empty_scene := _w1_scene()
	for raw_ent: Variant in (w1_empty_scene["maps"]["sewers"]["entities"] as Array):
		if raw_ent is Dictionary and String((raw_ent as Dictionary).get(WIKeys.ID, "")) == "w1_own_thicket":
			(raw_ent as Dictionary).erase("burn_counter")
	var w1_empty := _w1_game(w1_empty_scene)
	_w1_face(w1_empty, Vector2i(16, 3), Vector2i.UP)
	assert(w1_empty.use_skill_field("w1_scorch").get("burned", "") == "w1_own_thicket",
		"a carrier with no override still burns")
	assert(int(w1_empty.accomplishments.get("burned_the_debris", 0)) == 1,
		"with no override authored the ROW's counter is the fallback")

	# --- CROSS-MAP ISOLATION (#398-p2 review HIGH-1, the probe made permanent).
	# burns x burnable is ONE row over every burnable in the game. Before the
	# override, burning the collapsed gallery's shoring banked the same id the
	# SEWERS debris banks, so each pocket silently opened the other map's
	# strongbox. Both directions are pinned, against the REAL shipped maps, with
	# the nest counter pre-banked so the burn is the ONLY gate left in play.
	var w1_cross := _w1_game(_w1_scene())
	w1_cross.record_accomplishment("cleared_collapsed_gallery_nest", 1)
	_w1_face_on(w1_cross, "deep_tunnels", Vector2i(13, 3), Vector2i.RIGHT)
	assert(w1_cross.use_skill_field("w1_scorch").get("burned", "") == "collapsed_gallery_shoring",
		"a burns cast at the tarred shoring resolves the shipped burns row")
	assert(int(w1_cross.accomplishments.get("burned_the_gallery_shoring", 0)) == 1,
		"the shoring banks its OWN counter")
	assert(int(w1_cross.accomplishments.get("burned_the_debris", 0)) == 0,
		"burning the gallery shoring does NOT bank burned_the_debris")
	assert(String(w1_cross.entity_at(Vector2i(18, 2)).get(WIKeys.ID, "")) == "collapsed_gallery_strongbox_burn",
		"the gallery's own strongbox is present once the shoring burned and the nest is clear")
	w1_cross.transition("sewers", Vector2i(1, 3))
	assert(w1_cross.entity_at(Vector2i(0, 3)).is_empty(),
		"the SEWERS nook strongbox stays absent -- a deep-tunnels burn is not a sewers burn")
	# The mirror direction: the sewers debris still banks the row default, opens
	# its own nook, and leaves the gallery pocket shut.
	var w1_cross_back := _w1_game(_w1_scene())
	w1_cross_back.record_accomplishment("cleared_collapsed_gallery_nest", 1)
	_w1_face(w1_cross_back, Vector2i(1, 3), Vector2i.UP)
	assert(w1_cross_back.use_skill_field("w1_scorch").get("burned", "") == "sewer_debris",
		"the sewers debris keeps resolving the same row")
	assert(int(w1_cross_back.accomplishments.get("burned_the_debris", 0)) == 1,
		"the debris authors no override, so the ROW's counter is what banks")
	assert(int(w1_cross_back.accomplishments.get("burned_the_gallery_shoring", 0)) == 0,
		"the debris never banks the gallery's id")
	assert(String(w1_cross_back.entity_at(Vector2i(0, 3)).get(WIKeys.ID, "")) == "nook_strongbox",
		"the sewers nook opens on its own burn, exactly as it shipped")
	w1_cross_back.transition("deep_tunnels", Vector2i(13, 4))
	assert(w1_cross_back.entity_at(Vector2i(18, 2)).is_empty(),
		"the GALLERY strongbox stays absent -- a sewers burn is not a deep-tunnels burn")

	# Phase-0 review can-fail: the two shipped martial cutters are field
	# affordances only while their declared weapon family is EQUIPPED.
	var w1_bare_cut := _w1_game(_w1_scene())
	w1_bare_cut.player_skills.append("power_strike")
	_w1_face(w1_bare_cut, Vector2i(14, 3), Vector2i.UP)
	var w1_bare_result := w1_bare_cut.use_skill_field("power_strike")
	assert(w1_bare_result.is_empty(), "barehanded power_strike refuses a cuttable target")
	assert(not w1_bare_cut.find_entity("w1_briars").is_empty(),
		"barehanded refusal does not remove the cuttable target")
	assert(int(w1_bare_cut.accomplishments.get("cut_through_growth", 0)) == 0,
		"barehanded refusal does not bank the cuts counter")
	assert(_w1_types() == ["skill_no_effect", "toast"],
		"barehanded refusal emits only skill_no_effect -> toast")

	var w1_armed_cut := _w1_game(_w1_scene())
	w1_armed_cut.player_skills.append("power_strike")
	w1_armed_cut.inventory.assign(["rusty_sword"])
	w1_armed_cut.equipped[WIKeys.WEAPON] = "rusty_sword"
	_w1_face(w1_armed_cut, Vector2i(14, 3), Vector2i.UP)
	var w1_armed_result := w1_armed_cut.use_skill_field("power_strike")
	assert(w1_armed_result.get("burned", "") == "w1_briars",
		"sword-equipped power_strike resolves the cuts row")
	assert(w1_armed_cut.find_entity("w1_briars").is_empty(),
		"armed power_strike removes the cuttable target")
	assert(int(w1_armed_cut.accomplishments.get("cut_through_growth", 0)) == 1,
		"armed power_strike banks the cuts counter")

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

	# --- thaw_cell (slice 2): a burns carrier takes the ice back off the
	# channel. Same cell, opposite direction, over the SAME frozen_cells store.
	var w1_thaw := _w1_game(_w1_scene())
	_w1_face(w1_thaw, Vector2i(3, 4), Vector2i.DOWN)
	# The kindle x water refusal is reachable ONLY before the freeze, so it is
	# proven here rather than in its own game.
	var w1_water_refused := w1_thaw.use_skill_field("w1_scorch")
	assert(w1_water_refused.get("refused", "") == "w1_scorch", "burns at open water resolves the refusal row")
	assert(_w1_types() == ["skill_no_effect", "toast"],
		"refuse emits exactly skill_no_effect -> toast (the shipped ambient-refusal shape)")
	assert(w1_thaw.frozen_cells.is_empty(), "a refusal writes no cell state")
	assert(not w1_thaw.used_skills.has("w1_scorch"), "a refusal never marks the skill used")
	_events.clear()
	w1_thaw.use_skill_field("w1_ice_floor")
	assert(not w1_thaw.is_cell_blocked(Vector2i(3, 5)), "the channel is frozen and crossable")
	_events.clear()
	var w1_thaw_result := w1_thaw.use_skill_field("w1_scorch")
	assert(w1_thaw_result.get("thawed", []) == [3, 5], "the same burns carrier thaws the ice it just crossed")
	assert(w1_thaw.frozen_cells.is_empty(), "thaw_cell erases the frozen_cells entry, map key and all")
	assert(w1_thaw.is_cell_blocked(Vector2i(3, 5)), "the thawed channel is impassable water again")
	assert(_w1_types() == ["skill_used", "terrain_changed", "toast"],
		"thaw_cell emits exactly skill_used -> terrain_changed -> toast")
	assert(String(_w1_last("terrain_changed").get("to", "")) == "water", "the row's terrain value rides the event")
	assert(int(w1_thaw.accomplishments.get("burned_the_debris", 0)) == 0, "thaw_cell banks no counter")
	# Thawed means NOT frozen: the row stops matching and the water refusal,
	# which sits below it, is what answers the next cast.
	_events.clear()
	assert(w1_thaw.use_skill_field("w1_scorch").get("refused", "") == "w1_scorch",
		"a second burns cast on the thawed cell falls to the water refusal, never a second thaw")

	# --- state_set (slice 2): counter-backed, ONE-WAY, per-CARRIER counter.
	var w1_state := _w1_game(_w1_scene())
	_w1_face(w1_state, Vector2i(10, 3), Vector2i.UP)
	var w1_set_result := w1_state.use_skill_field("w1_scorch")
	assert(w1_set_result.get("state_set", "") == "w1_brazier", "burns x hearth resolves state_set on the faced prop")
	assert(int(w1_state.accomplishments.get("w1_brazier_lit", 0)) == 1,
		"the CARRIER's own state_counter banks, not a row-level id")
	assert(_w1_types() == ["skill_used", "accomplishment_recorded", "toast"],
		"state_set emits exactly skill_used -> accomplishment_recorded -> toast")
	assert(String(_w1_last("toast").get("text", "")) == "W1 brazier toast.", "the prop's own line spoke")
	assert(not w1_state.find_entity("w1_brazier").is_empty(), "state_set removes nothing")
	_events.clear()
	assert(w1_state.use_skill_field("w1_scorch").get("ambient", "") == "w1_scorch",
		"a second set on the same prop falls through to ambient (one-way, no double bank)")
	assert(int(w1_state.accomplishments.get("w1_brazier_lit", 0)) == 1, "the counter banked exactly once")
	# S0.1 REGRESSION GUARD (phase-0 review, BLOCK). The one-way guard used to
	# read entity_first_use, which sleep() CLEARS -- so an already-lit hearth
	# replayed its first-time toast and re-banked the save-persisted counter
	# once per sleep, unbounded, while data_lint declared the row "permanent".
	# The guard now reads the carrier's own counter. Sleeping is the only thing
	# that can red this arm, so it has to be here and not in the waking above.
	w1_state.sleep()
	_events.clear()
	_w1_face(w1_state, Vector2i(10, 3), Vector2i.UP)
	assert(w1_state.use_skill_field("w1_scorch").get("ambient", "") == "w1_scorch",
		"ACROSS A SLEEP a set prop still falls through to ambient -- one-way means permanent")
	assert(int(w1_state.accomplishments.get("w1_brazier_lit", 0)) == 1,
		"the counter did NOT re-bank after a sleep")
	assert(String(_w1_last("toast").get("text", "")) != "W1 brazier toast.",
		"the prop's FIRST-TIME line did not replay on an already-lit hearth (the ambient line is correct here)")
	# The douse cell has no substrate, so it is an authored refusal even on a
	# prop whose state is already set.
	_events.clear()
	assert(w1_state.use_skill_field("w1_ice_floor").get("refused", "") == "w1_ice_floor",
		"freezes x hearth is the authored douse refusal")
	assert(int(w1_state.accomplishments.get("w1_brazier_lit", 0)) == 1, "the refusal banks nothing")
	# A carrier missing the counter field leaves the row INERT rather than
	# emitting a hollow toast (the mismatched-row degradation contract).
	var w1_keyless_scene := _w1_scene()
	for raw_ent: Variant in (w1_keyless_scene["maps"]["sewers"]["entities"] as Array):
		if raw_ent is Dictionary and String((raw_ent as Dictionary).get(WIKeys.ID, "")) == "w1_brazier":
			(raw_ent as Dictionary).erase("state_counter")
	var w1_keyless := _w1_game(w1_keyless_scene)
	_w1_face(w1_keyless, Vector2i(10, 3), Vector2i.UP)
	assert(w1_keyless.use_skill_field("w1_scorch").get("ambient", "") == "w1_scorch",
		"a hearth carrier with no state_counter resolves NO row -- it falls through to ambient")
	assert(w1_keyless.accomplishments.is_empty(), "the inert row banks nothing")

	# --- THE DIRTY PASS + its precedence proof. The table generalizes over an
	# untagged-grime prop; an authored arm on an equally-tagged prop still wins.
	var w1_clean := _w1_game(_w1_scene())
	_w1_face(w1_clean, Vector2i(6, 3), Vector2i.UP)
	var w1_clean_result := w1_clean.use_skill_field("w1_scrub")
	assert(w1_clean_result.get("state_set", "") == "w1_grime", "cleans x dirty generalizes over a plain grime prop")
	assert(int(w1_clean.accomplishments.get("w1_grime_cleaned", 0)) == 1, "the table's carrier counter banked")
	assert(String(_w1_last("toast").get("text", "")) == "W1 grime toast.", "the prop's clean_toast spoke")
	_w1_face(w1_clean, Vector2i(8, 3), Vector2i.UP)
	var w1_clean_auth := w1_clean.use_skill_field("w1_scrub")
	assert(not w1_clean_auth.has("state_set"),
		"the table never resolves a dirty prop whose authored arm answers the same skill")
	assert(int(w1_clean.accomplishments.get("w1_authored_cleans", 0)) == 1, "the AUTHORED counter banked instead")
	assert(int(w1_clean.accomplishments.get("w1_grime_cleaned", 0)) == 1,
		"the table's counter did NOT bank a second time off the authored prop")
	assert(String(_w1_last("toast").get("text", "")) == "W1 authored scrub toast.", "the authored line spoke")

	# --- The refusal cells are refusals, not fallthroughs: a person answers
	# with the row's own copy and nothing else happens.
	var w1_person := _w1_game(_w1_scene())
	_w1_face(w1_person, Vector2i(12, 3), Vector2i.UP)
	var w1_person_result := w1_person.use_skill_field("w1_ice_floor")
	assert(w1_person_result.get("refused", "") == "w1_ice_floor", "freezes x person resolves the refusal row")
	assert(_w1_types() == ["skill_no_effect", "toast"], "the person refusal emits skill_no_effect -> toast")
	assert(String(_w1_last("toast").get("text", "")) != "W1 ice floor finds nothing to grip.",
		"an authored refusal speaks its OWN line, never the skill's ambient one")
	assert(w1_person.frozen_cells.is_empty(), "the person refusal freezes nothing")
	assert(not w1_person.find_entity("w1_bystander").is_empty(), "the bystander is still standing there")

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

	# --- A MISMATCHED ROW IS INERT, not fatal and not silent. data_lint fails
	# both shapes at the lint tier; these two prove the engine's own guard, so a
	# hand-edited or half-merged table degrades to the ambient fallthrough.
	# (A) entity verb bound to a CELL class: this is the row that used to reach
	# `target[WIKeys.ID]` with target == {} and raise a SCRIPT ERROR.
	var w1_bad_entity_scene := _w1_scene()
	w1_bad_entity_scene["interactions"] = {
		"skill_properties": ["burns"], "target_properties": {"freezable": "cell"},
		"outcomes": WIFieldSkills.OUTCOMES,
		"interactions": [{
			"skill_property": "burns", "target_property": "freezable",
			"outcome": "remove_scorch", "persistence": "permanent",
			"counter": "burned_the_debris", "terrain": "scorched",
			"toast_from": "target", "toast_key": "burn_toast", "toast_default": "x",
		}],
	}
	var w1_bad_entity := _w1_game(w1_bad_entity_scene)
	_w1_face(w1_bad_entity, Vector2i(3, 4), Vector2i.DOWN)
	assert(w1_bad_entity.use_skill_field("w1_scorch").get("ambient", "") == "w1_scorch",
		"remove_scorch bound to a cell class resolves NO row -- it falls through to ambient")
	assert(w1_bad_entity.removed_entities.is_empty(), "the inert row removes nothing")
	assert(int(w1_bad_entity.accomplishments.get("burned_the_debris", 0)) == 0,
		"the inert row banks no counter")
	# (B) cell verb bound to an ENTITY flag: the silent mirror. This row used to
	# freeze the faced CELL whenever the faced ENTITY carried the flag, and a
	# frozen cell is walkable unconditionally -- a wall-phase primitive.
	var w1_bad_cell_scene := _w1_scene()
	w1_bad_cell_scene["interactions"] = {
		"skill_properties": ["freezes"], "target_properties": {"burnable": "entity"},
		"outcomes": WIFieldSkills.OUTCOMES,
		"interactions": [{
			"skill_property": "freezes", "target_property": "burnable",
			"outcome": "freeze_cell", "persistence": "until_sleep", "terrain": "ice",
			"toast_from": "skill", "toast_key": "freeze_toast", "toast_default": "x",
		}],
	}
	var w1_bad_cell := _w1_game(w1_bad_cell_scene)
	_w1_face(w1_bad_cell, Vector2i(2, 4), Vector2i.DOWN)
	assert(w1_bad_cell.use_skill_field("w1_ice_floor").get("ambient", "") == "w1_ice_floor",
		"freeze_cell bound to an entity flag resolves NO row -- it falls through to ambient")
	assert(w1_bad_cell.frozen_cells.is_empty(), "the inert row freezes nothing")
	assert(w1_bad_cell.is_cell_blocked(Vector2i(3, 5)),
		"the water channel stays impassable -- the inert row flipped no walkability")
	# (C) THE WILDCARD HOLE (slice 2, hostile-row lens). `refuse` declares
	# PLACEMENT_ANY, so the `wants != placement` half of the binding guard
	# cannot reject a garbage placement for it -- only the membership `match`
	# can, and a match with no default arm silently tests NOTHING. Both shapes
	# below are one wrong character in `target_properties`, and both used to
	# make the row fire on EVERY cast of the skill property, at an empty floor
	# cell, with the refusal line as the only tell.
	for w1_bogus: String in ["entty", WIFieldSkills.PLACEMENT_ANY]:
		var w1_wild_scene := _w1_scene()
		w1_wild_scene["interactions"] = {
			"skill_properties": ["freezes"], "target_properties": {"person": w1_bogus},
			"outcomes": WIFieldSkills.OUTCOMES,
			"interactions": [{
				"skill_property": "freezes", "target_property": "person",
				"outcome": "refuse", "persistence": "none",
				"toast_from": "row", "toast_default": "W1 wildcard refusal.",
			}],
		}
		var w1_wild := _w1_game(w1_wild_scene)
		# An empty floor cell: no entity at all, so no `person` carrier either.
		_w1_face(w1_wild, Vector2i(10, 3), Vector2i.LEFT)
		assert(w1_wild.use_skill_field("w1_ice_floor").get("ambient", "") == "w1_ice_floor",
			"a refuse row whose target placement is '%s' resolves NO row -- ambient, not a blanket refusal" % w1_bogus)
		assert(String(_w1_last("toast").get("text", "")) != "W1 wildcard refusal.",
			"the hostile row's line never reaches the player")

	print("PASS: property-interaction table -- mirror contract, injection, new carriers, precedence (burn + dirty), verb/placement binding, thaw/state_set/refuse, inert fallthrough")
	quit(0)
