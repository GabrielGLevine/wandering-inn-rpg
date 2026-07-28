extends SceneTree

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
	return WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 12345, _combat_config())


## THE CARRIER-VS-ROW AUDIT. A portal-only region's carrier IS its only exit, so
## a carrier gated tighter than its own map's arrival implication is a softlock
## by construction -- the Pallass trap, the Riverfarm strand and the Invrisil
## near-miss were all this one shape. Permitted gate counters, per carrier:
##   * `door_mounted` -- every arrival anywhere passed a door_mounted carrier to
##     get there, so it can never be unmet by someone standing on the map.
##   * the map's OWN portals.json `requires_accomplishment` -- true by
##     construction for anyone who took that row.
## Anything else (another region's counter, a quest flag, a later beat) can be
## unmet on arrival. Widen this list only with an implication proof.
func _audit_carrier_gates() -> void:
	var rows: Dictionary = {}
	for row: Dictionary in (_load_json("res://data/portals.json").get("portals", []) as Array):
		rows[String(row.get("map", ""))] = String(row.get("requires_accomplishment", ""))
	var maps: Dictionary = WISceneCatalog.compose()["maps"]
	var carriers := 0
	for map_id: String in maps:
		for entity: Dictionary in (maps[map_id] as Dictionary).get("entities", []):
			if not bool(entity.get("portal_menu", false)):
				continue
			carriers += 1
			var allowed: Array = ["door_mounted"]
			assert(rows.has(map_id), "portal carrier %s sits on %s, which has no portals.json row -- nothing can arrive there, so nothing should offer to leave" % [String(entity["id"]), map_id])
			if String(rows[map_id]) != "":
				allowed.append(String(rows[map_id]))
			var gate: Dictionary = (entity.get("portal_menu_when", {}) as Dictionary).get("requires", {})
			assert(not gate.is_empty(), "portal carrier %s (%s) has no requires-wrapped gate -- a bare or missing dict is vacuously true (data_lint's own arm)" % [String(entity["id"]), map_id])
			for counter: String in gate:
				assert(allowed.has(counter), "portal carrier %s (%s) gates on '%s', which its map's arrival (%s) does not imply -- a carrier may only gate on door_mounted or its own row's counter, else the region is a one-way trap" % [String(entity["id"]), map_id, counter, String(rows[map_id]) if String(rows[map_id]) != "" else "ungated"])
				# THRESHOLD-BLIND FALSE-ACCEPT: the counter-name check above passes
				# a `{door_mounted: 2}` that no arrival can ever satisfy (every
				# producer banks these once). Only 1 is honest.
				assert(int(gate[counter]) == 1, "portal carrier %s (%s) gates on '%s' at threshold %d -- an arrival implies the counter ONCE, so anything but 1 is unreachable by construction" % [String(entity["id"]), map_id, counter, int(gate[counter])])
	assert(carriers >= 5, "the audit found only %d portal carriers -- it must walk every shipped one" % carriers)


func _option_texts(game: WIGame) -> Array:
	return (game.dialogue.current_options() as Array).map(func(o: Dictionary) -> String: return String(o["text"]))


func _bank_beat3(game: WIGame) -> void:
	game.record_accomplishment("door_understood")
	game.record_accomplishment("recovered_anchor_stone")
	game.record_accomplishment("bought_catalyst")


func _init() -> void:
	WITestWatchdog.arm(self)
	_audit_carrier_gates()

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

	assert(String(WIPortals.destination_by_id(rows, "b")["map"]) == "street", "destination_by_id finds a row by id")
	assert(WIPortals.destination_by_id(rows, "nonexistent").is_empty(), "destination_by_id returns {} for an unknown id")

	var game := _new_game()
	game.record_accomplishment("door_understood")
	game.record_accomplishment("bought_catalyst")
	game.sleep()
	assert(game.door_study_sleeps() == 0, "a sleep with only 2 of 3 beat-3 counters banked does not advance door_study_sleeps")
	assert(game.accomplishment_count("door_awakened") == 0, "door_awakened has not banked")

	game.record_accomplishment("recovered_anchor_stone")
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

	game.sleep()
	assert(game.door_study_sleeps() == 3, "door_study_sleeps stops advancing once door_awakened is banked")
	assert(game.accomplishment_count("door_awakened") == 1, "door_awakened stays banked exactly once")

	var door2_game := _new_game()
	_bank_beat3(door2_game)
	door2_game.sleep()
	door2_game.sleep()
	door2_game.sleep()
	assert(door2_game.accomplishment_count("door_awakened") == 1, "sanity: door_awakened banked (3 qualifying sleeps)")

	door2_game.record_accomplishment("heard_pisces_second_door")
	door2_game.sleep()
	assert(door2_game.second_door_study_sleeps() == 1, "the first sleep after heard_pisces_second_door (door_awakened already banked) advances second_door_study_sleeps to 1")
	assert(door2_game.accomplishment_count("dungeon_attuned") == 0, "not yet attuned at N=1")

	door2_game.sleep()
	assert(door2_game.second_door_study_sleeps() == 2, "a second qualifying sleep advances to 2")
	assert(door2_game.accomplishment_count("dungeon_attuned") == 1, "N=2 banks dungeon_attuned")

	door2_game.sleep()
	assert(door2_game.second_door_study_sleeps() == 2, "second_door_study_sleeps stops advancing once dungeon_attuned is banked")

	var door2_gate_game := _new_game()
	door2_gate_game.record_accomplishment("heard_pisces_second_door")
	door2_gate_game.sleep()
	assert(door2_gate_game.second_door_study_sleeps() == 0, "second_door_study_sleeps never advances before door_awakened is banked")

	var dest_ids: Array = door2_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(dest_ids.has("dungeon_depths"), "dungeon_depths lists once dungeon_attuned is banked")
	var fresh_dest_ids: Array = _new_game().attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(not fresh_dest_ids.has("dungeon_depths"), "dungeon_depths stays gate-locked on a fresh game")
	door2_game._travel_to_portal("dungeon_depths")
	assert(door2_game.current_map == "dungeon_approach", "travel to the dungeon anchor lands on dungeon_approach")
	assert(door2_game.player_cell == Vector2i(2, 6), "travel lands on the portals.json-authored arrival cell")

	# 2026-07-26 main-quest restructure (Task 2.4) -- THE DAY-ONE LISCOR LINK.
	# liscor_street/the_wandering_inn re-gated door_awakened -> door_mounted:
	# the Magical Door carries the inn<->gate-district hop from the moment the
	# Horns hang it, three qualifying sleeps BEFORE door_awakened, which now
	# only means "reaches beyond Liscor" and only opens the region rows.
	var mounted_only := _new_game()
	var pre_mount_ids: Array = mounted_only.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(not pre_mount_ids.has("liscor_street") and not pre_mount_ids.has("the_wandering_inn"), "before door_mounted neither Liscor row lists")
	mounted_only.record_accomplishment("door_mounted")
	var mounted_ids: Array = mounted_only.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(mounted_ids.has("liscor_street") and mounted_ids.has("the_wandering_inn"), "door_mounted ALONE lists both Liscor rows -- the day-one link needs no awakening")
	assert(mounted_only.accomplishment_count("door_awakened") == 0, "sanity: the day-one link is proven with door_awakened still unbanked")
	for region_id: String in ["riverfarm", "invrisil", "pallass", "dungeon_depths"]:
		assert(not mounted_ids.has(region_id), "door_mounted opens Liscor only -- %s still waits on its own further gate" % region_id)
	# Riverfarm's row moved riverfarm_attuned -> door_awakened: the board rumor
	# alone used to offer a village whose only exit stone gated on the awakening.
	mounted_only.record_accomplishment("riverfarm_attuned")
	assert(not mounted_only.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])).has("riverfarm"), "the board rumor alone no longer opens Riverfarm -- door_awakened does")
	# The inn-side CARRIER moved with the rows: the picker must open at the
	# mounted door, not three sleeps later (a row nothing can reach is dead).
	mounted_only.bind_map_silent("inn", Vector2i(13, 6))
	mounted_only.player_facing = Vector2i.RIGHT
	assert(mounted_only.interact().get("dialogue", false), "pantry_door's portal picker opens at door_mounted, not door_awakened")
	assert(_option_texts(mounted_only) == ["Liscor — the Gate District", WIPortals.NEVER_MIND], "pre-awakening the inn picker offers Liscor and nothing further -- Riverfarm is absent: %s" % str(_option_texts(mounted_only)))
	# ...and so did Liscor's end of the pair.
	mounted_only.dialogue_choose(1)
	mounted_only.bind_map_silent("street", Vector2i(29, 10))
	mounted_only.player_facing = Vector2i.RIGHT
	assert(mounted_only.interact().get("dialogue", false), "street_anchor_stone's picker opens at door_mounted too -- the return leg is never stranded")
	mounted_only.dialogue_choose(1)

	game.record_accomplishment("door_mounted")
	var attuned_ids2: Array = game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"]))
	assert(attuned_ids2.has("liscor_street") and attuned_ids2.has("the_wandering_inn"), "both portals.json rows stay attuned on a fully awakened save")

	game.bind_map_silent("inn", Vector2i(13, 6))
	game.player_facing = Vector2i.RIGHT
	_events.clear()
	var result := game.interact()
	assert(result.get("dialogue", false), "interacting with the awakened pantry_door opens the portal menu, not the flavor toast")
	var started: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "dialogue_started")
	assert(started.size() == 1 and String(started[0]["payload"].get("conversation", "")) == "portal_menu", "the code-built graph is labeled 'portal_menu'")
	assert(_option_texts(game) == ["Liscor — the Gate District", "Riverfarm", WIPortals.NEVER_MIND], "awakened, the inn menu gains Riverfarm and still excludes the_wandering_inn (you're already there): %s" % str(_option_texts(game)))

	_events.clear()
	assert(game.dialogue_choose(0), "picking the (only) real destination succeeds")
	assert(game.current_map == "street", "transition() landed the PC on the street")
	assert(game.player_cell == Vector2i(29, 10), "transition() landed the PC on the portals.json-authored arrival cell")
	var map_changed: Array = _events.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "map_changed")
	assert(map_changed.size() == 1 and String(map_changed[0]["payload"].get("map", "")) == "street", "map_changed fired exactly once, to street")
	for e: Dictionary in _events:
		assert(String(e["type"]) not in ["player_moved", "player_blocked", "combat_started"], "no move/trigger/combat event fires on a portal arrival (O2 rule): saw %s" % String(e["type"]))

	game.bind_map_silent("street", Vector2i(29, 10))
	game.player_facing = Vector2i.RIGHT
	game.interact()
	assert(_option_texts(game) == ["The Wandering Inn", "Riverfarm", WIPortals.NEVER_MIND], "from the street the menu excludes liscor_street (current map): %s" % str(_option_texts(game)))
	assert(game.dialogue_choose(0), "picking the inn destination succeeds")
	assert(game.current_map == "inn", "the return trip lands back on the inn")
	assert(game.player_cell == Vector2i(13, 6), "the return trip lands on the inn's authored arrival cell")

	# THE STRAND FIX, both cohorts. riverfarm_anchor_stone is the village's only
	# exit (witch_hollow dead-ends off it), so it gates on door_mounted -- the one
	# counter BOTH arrival paths carry: the legacy rumor route (riverfarm_attuned,
	# no awakening) and the post-fix door_awakened row.
	var stranded := _new_game()
	stranded.record_accomplishment("door_mounted")
	stranded.record_accomplishment("riverfarm_attuned")
	stranded.bind_map_silent("riverfarm_village", Vector2i(13, 5))
	stranded.player_facing = Vector2i.LEFT
	assert(stranded.interact().get("dialogue", false), "a pre-awakening save parked in Riverfarm can still open the anchor stone and leave")
	assert(_option_texts(stranded) == ["Liscor — the Gate District", "The Wandering Inn", WIPortals.NEVER_MIND], "the stranded save's own menu offers both Liscor rows home: %s" % str(_option_texts(stranded)))
	assert(stranded.dialogue_choose(0), "and travelling out of Riverfarm succeeds")
	assert(stranded.current_map == "street", "the stranded save lands back in Liscor")

	var awakened_visitor := _new_game()
	awakened_visitor.record_accomplishment("door_mounted")
	_bank_beat3(awakened_visitor)
	awakened_visitor.sleep()
	awakened_visitor.sleep()
	awakened_visitor.sleep()
	assert(awakened_visitor.accomplishment_count("riverfarm_attuned") == 0, "sanity: this one never read the board rumor")
	awakened_visitor._travel_to_portal("riverfarm")
	assert(awakened_visitor.current_map == "riverfarm_village", "the awakening alone carries you to Riverfarm")
	awakened_visitor.player_facing = Vector2i.LEFT
	assert(awakened_visitor.interact().get("dialogue", false), "...and the anchor stone carries you back, rumor unread")

	var fresh := _new_game()
	fresh.bind_map_silent("inn", Vector2i(13, 6))
	fresh.player_facing = Vector2i.RIGHT
	var fresh_result := fresh.interact()
	assert(fresh_result.get("accomplishment", "") == "observed_the_pantry_door", "before door_mounted, pantry_door still falls through to its plain flavor toast, not the portal menu")

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
	fwd_game.record_accomplishment("pallass_attuned")
	assert(fwd_game.attuned_destinations().map(func(d: Dictionary) -> String: return String(d["id"])).has("pallass"), "the once-forward-referenced pallass row lists normally now its map exists (the guard's zero-further-wiring payoff)")
	fwd_game._travel_to_portal("pallass")
	assert(fwd_game.current_map == "pallass_market", "travel to the now-landed map succeeds through the same guard")

	print("PASS: WIPortals gating/graph construction + the study-sleeps hook (both the door and its second-door mirror) + portal-menu travel (the O2 rule) + the forward-referenced-row map guard")
	quit(0)
