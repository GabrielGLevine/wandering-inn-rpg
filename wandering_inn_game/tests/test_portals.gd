extends SceneTree
## WIPortals pure tests + the
## wi_game.gd study-sleeps hook + portal-menu interact/travel wiring.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_portals.gd

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
		"quests": _load_json("res://data/quests.json"),
		"items": _load_json("res://data/items.json"),
		"portals": _load_json("res://data/portals.json"),
	}


func _new_game() -> WIGame:
	return WIGame.new(_load_json("res://data/skeleton_scene.json"), _load_json("res://data/skills.json"), _sink, 12345, _combat_config())


## Everything the door-study hook cares about, PLUS a pedestal-open path to
## door_understood -- bought_catalyst/recovered_anchor_stone are plain
## accomplishment counters, banked directly here (no need to walk the full
## D3 dialogue/fight chain just to prove D4's own hook math).
func _bank_beat3(game: WIGame) -> void:
	game.record_accomplishment("door_understood")
	game.record_accomplishment("recovered_anchor_stone")
	game.record_accomplishment("bought_catalyst")


func _init() -> void:
	WITestWatchdog.arm(self)

	# --- WIPortals.attuned_destinations: pure gating over an injected
	# accomplishment-count reader ---
	var rows: Array = [
		{"id": "a", "display_name": "Destination A", "map": "inn", "cell": [1, 1], "requires_accomplishment": "flag_a"},
		{"id": "b", "display_name": "Destination B", "map": "street", "cell": [2, 2], "requires_accomplishment": "flag_b"},
		{"id": "c", "display_name": "Destination C", "map": "guild", "cell": [3, 3]},
	]
	var counts := {"flag_a": 1, "flag_b": 0}
	var counter_cb := func(id: String) -> int: return int(counts.get(id, 0))
	var attuned: Array = WIPortals.attuned_destinations(rows, counter_cb)
	assert(attuned.size() == 2, "attuned_destinations: met gate (a) + gate-less row (c) pass, unmet gate (b) is excluded")
	var attuned_ids: Array = attuned.map(func(r: Dictionary) -> String: return String(r["id"]))
	assert(attuned_ids.has("a") and attuned_ids.has("c") and not attuned_ids.has("b"), "attuned_destinations: exact set")
	counts["flag_b"] = 1
	assert(WIPortals.attuned_destinations(rows, counter_cb).size() == 3, "attuned_destinations: raising the gate re-includes the row")

	# --- WIPortals.build_portal_graph: excludes current_map, always keeps
	# the fallback option, wires travel_to effects ---
	var graph: Dictionary = WIPortals.build_portal_graph(attuned, "inn")
	var hub: Dictionary = (graph["nodes"] as Dictionary)[String(graph["start"])]
	var opts: Array = hub["options"]
	assert(opts.size() == 2, "build_portal_graph: attuned {a (inn), c (guild)} minus the CURRENT map (a) leaves 1 real option (c) + 'Let it be.'")
	var never_mind_present := false
	for o: Dictionary in opts:
		if not o.has("effects"):
			never_mind_present = true
			assert(bool(o.get("end", false)), "the fallback option always ends the conversation")
	assert(never_mind_present, "build_portal_graph always ships an effect-less 'Let it be.' fallback")
	for o: Dictionary in opts:
		if o.has("effects"):
			assert(bool(o.get("end", false)), "every travel option is conversation-ending (the O2 rule: deferred, resolved via transition() only)")
			assert(String((o["effects"] as Array)[0].get("travel_to", "")) == "c", "the surviving option travels to the non-inn destination (c)")

	var empty_graph: Dictionary = WIPortals.build_portal_graph([], "inn")
	var empty_opts: Array = ((empty_graph["nodes"] as Dictionary)[String(empty_graph["start"])] as Dictionary)["options"]
	assert(empty_opts.size() == 1, "zero attuned destinations still yields a valid one-option (fallback-only) graph, never empty options")

	# --- WIPortals.destination_by_id ---
	assert(String(WIPortals.destination_by_id(rows, "b")["map"]) == "street", "destination_by_id finds a row by id")
	assert(WIPortals.destination_by_id(rows, "nonexistent").is_empty(), "destination_by_id returns {} for an unknown id")

	# --- The study-sleeps hook: counters-banked-mid-waking edge ---
	var game := _new_game()
	game.record_accomplishment("door_understood")
	game.record_accomplishment("bought_catalyst")
	# recovered_anchor_stone still missing -- only 2 of 3 beat-3 counters.
	game.sleep()
	assert(game.door_study_sleeps() == 0, "a sleep with only 2 of 3 beat-3 counters banked does not advance door_study_sleeps")
	assert(game.accomplishment_count("door_awakened") == 0, "door_awakened has not banked")

	game.record_accomplishment("recovered_anchor_stone")
	# NOW all three are banked -- this sleep is the FIRST that counts.
	game.sleep()
	assert(game.door_study_sleeps() == 1, "the first sleep after all 3 beat-3 counters land advances door_study_sleeps to 1")
	assert(game.accomplishment_count("door_awakened") == 0, "not yet awakened at N=1")

	game.sleep()
	assert(game.door_study_sleeps() == 2, "a second qualifying sleep advances to 2")
	assert(game.accomplishment_count("door_awakened") == 0, "not yet awakened at N=2")

	_events.clear()
	game.sleep()
	assert(game.door_study_sleeps() == 3, "the third qualifying sleep advances to 3")
	assert(game.accomplishment_count("door_awakened") == 1, "N=3 banks door_awakened")
	var awakened_events: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "accomplishment_recorded" and String(e["payload"].get("id", "")) == "door_awakened")
	assert(awakened_events.size() == 1, "door_awakened fires accomplishment_recorded exactly once (the sleep_veil.gd GDI-line hook's own trigger)")

	# Idempotent past N=3: a further qualifying sleep must not re-increment
	# or re-bank (record_accomplishment is a plain incrementing counter, but
	# the hook's own door_awakened<1 guard must stop it from firing again).
	game.sleep()
	assert(game.door_study_sleeps() == 3, "door_study_sleeps stops advancing once door_awakened is banked")
	assert(game.accomplishment_count("door_awakened") == 1, "door_awakened stays banked exactly once")

	# --- attuned_destinations() / interact() / travel_to end-to-end (the
	# O2 rule: transition() only, no move_player/trigger_radius) ---
	var attuned_ids2: Array = game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(attuned_ids2.has("liscor_street") and attuned_ids2.has("the_wandering_inn"), "both portals.json rows are attuned once door_awakened is banked")

	# Playtest hotfix #2 moved pantry_door (10,6)->(14,6), against the east
	# wall -- the free approach cell moved with it, (9,6)->(13,6).
	game.bind_map_silent("inn", Vector2i(13, 6))
	game.player_facing = Vector2i.RIGHT
	_events.clear()
	var result := game.interact()
	assert(result.get("dialogue", false), "interacting with the awakened pantry_door opens the portal menu, not the flavor toast")
	var started: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "dialogue_started")
	assert(started.size() == 1 and String(started[0]["payload"].get("conversation", "")) == "portal_menu", "the code-built graph is labeled 'portal_menu'")
	var menu_options: Array = game.dialogue.current_options()
	assert(menu_options.size() == 2, "from the inn, the menu offers ONLY the street destination + 'Let it be.' (the_wandering_inn is excluded: you're already there)")

	_events.clear()
	assert(game.dialogue_choose(0), "picking the (only) real destination succeeds")
	assert(game.current_map == "street", "transition() landed the PC on the street")
	assert(game.player_cell == Vector2i(29, 10), "transition() landed the PC on the portals.json-authored arrival cell")
	var map_changed: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "map_changed")
	assert(map_changed.size() == 1 and String(map_changed[0]["payload"].get("map", "")) == "street", "map_changed fired exactly once, to street")
	# The O2 rule, asserted structurally: portal travel calls transition()
	# directly, never move_player -- so NEITHER a player_moved/player_blocked
	# event NOR a combat/trigger event can appear in this burst.
	for e: Dictionary in _events:
		assert(String(e["type"]) not in ["player_moved", "player_blocked", "combat_started"], "no move/trigger/combat event fires on a portal arrival (O2 rule): saw %s" % String(e["type"]))

	# Return trip: from the street anchor, the menu must exclude
	# liscor_street (current map) and offer only the_wandering_inn.
	game.bind_map_silent("street", Vector2i(29, 10))
	game.player_facing = Vector2i.RIGHT
	game.interact()
	var return_options: Array = game.dialogue.current_options()
	assert(return_options.size() == 2, "from the street, the menu offers ONLY the inn destination + 'Let it be.'")
	assert(game.dialogue_choose(0), "picking the inn destination succeeds")
	assert(game.current_map == "inn", "the return trip lands back on the inn")
	assert(game.player_cell == Vector2i(13, 6), "the return trip lands on the inn's authored arrival cell")

	# --- Pre-awakening fallback: an UNMET portal_menu_when gate still shows
	# pantry_door's ordinary flavor toast (D1/D3 byte-identical fallback) ---
	var fresh := _new_game()
	fresh.bind_map_silent("inn", Vector2i(13, 6))
	fresh.player_facing = Vector2i.RIGHT
	var fresh_result := fresh.interact()
	assert(fresh_result.get("accomplishment", "") == "observed_the_pantry_door", "before door_awakened, pantry_door still falls through to its plain flavor toast, not the portal menu")

	# --- Save round-trip of door_study_sleeps (via the generic
	# accomplishments dict -- see door_study_sleeps()'s own doc comment for
	# why this is deliberately NOT a dedicated save.gd field) ---
	var partial := _new_game()
	_bank_beat3(partial)
	partial.sleep()
	partial.sleep()
	assert(partial.door_study_sleeps() == 2, "sanity: 2 qualifying sleeps banked before serializing")
	var data := WISave.serialize(partial)
	var restored := _new_game()
	assert(WISave.apply(restored, data), "save with a partial door_study_sleeps count applies")
	assert(restored.door_study_sleeps() == 2, "door_study_sleeps round-trips through the ordinary accomplishments save path")
	assert(restored.accomplishment_count("door_awakened") == 0, "door_awakened has NOT banked yet on the restored save (only 2 of 3 sleeps taken)")

	# --- Forward-referenced row guard (8e Phase C, ported from the stranded
	# lane-8ec review-fix commit): a catalog row whose map doesn't exist in
	# this build is INERT -- never listed by attuned_destinations (whatever
	# its attunement gate says) and refused cleanly by _travel_to_portal.
	# The bug class this kills: a region milestone's quest lane lands its
	# portals row + a LIVE attunement chain before the parallel maps lane
	# lands the map, and picking the row off the menu crashes _bind_map on
	# the missing map key.
	var fwd_rows: Array = [
		{"id": "real_dest", "display_name": "Real", "map": "inn", "cell": [1, 1]},
		{"id": "ghost_dest", "display_name": "Ghost", "map": "map_not_landed_yet", "cell": [10, 10]},
	]
	var fwd_counter := func(_id: String) -> int: return 1
	var fwd_has_map := func(map_id: String) -> bool: return map_id == "inn"
	var fwd_attuned: Array = WIPortals.attuned_destinations(fwd_rows, fwd_counter, fwd_has_map)
	assert(fwd_attuned.size() == 1 and String(fwd_attuned[0]["id"]) == "real_dest", "attuned_destinations excludes a row whose map doesn't exist, even with its gate met")
	assert(WIPortals.attuned_destinations(fwd_rows, fwd_counter).size() == 2, "an omitted has_map_cb (bare pure-unit caller) skips the map-existence filter -- both rows pass")
	var fwd_game := _new_game()
	assert(not fwd_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])).has("pallass"), "sanity: pallass stays gate-locked without pallass_attuned")
	# (No unattuned-travel refusal assert: _travel_to_portal deliberately
	# checks id + map existence ONLY -- attunement gating lives entirely in
	# the menu that produces the travel_to option, per the O2 rule.)
	# The catalog row this guard shipped FOR (pallass, forward-referenced
	# while pallass_market was a different lane's unlanded map) is LIVE now
	# the map exists -- prove the pattern's payoff end-to-end: banking the
	# attunement lists the row with zero further wiring, and travel works.
	fwd_game.record_accomplishment("pallass_attuned")
	assert(fwd_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])).has("pallass"), "the once-forward-referenced pallass row lists normally now its map exists (the guard's zero-further-wiring payoff)")
	fwd_game._travel_to_portal("pallass")
	assert(fwd_game.current_map == "pallass_market", "travel to the now-landed map succeeds through the same guard")

	print("PASS: WIPortals gating/graph construction + the study-sleeps hook + portal-menu travel (the O2 rule) + the forward-referenced-row map guard")
	quit(0)
