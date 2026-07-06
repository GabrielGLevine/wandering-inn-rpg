extends SceneTree
## Pure act-derivation tests (M-ARC Task A1).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game_v4 --script res://tests/test_acts.gd
##
## Acts derive from counters (never stored) -- so old saves land mid-act by
## construction. These cases pin: fresh boot = Act I; each mid-counter shape =
## the correct act; a maxed save = the highest (last) act; missing counters are
## tolerated as 0. Runs against the SHIPPED data/acts.json (not a synthetic
## catalog) so a gate edit that breaks the spec's three acts fails here.


func _ctx(classes_count: int, quests_completed: int, accs: Dictionary) -> Dictionary:
	return {"classes_count": classes_count, "quests_completed": quests_completed, "accomplishments": accs}


func _init() -> void:
	WITestWatchdog.arm(self)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/acts.json"))
	assert(parsed is Dictionary, "acts.json parses")
	var catalog: Dictionary = parsed

	# conditions_met predicate: empty = trivially true; missing counters read 0.
	assert(WIActs.conditions_met({}, {}), "empty condition met")
	assert(not WIActs.conditions_met({"min_classes": 1}, {}), "min_classes unmet with no counters")
	assert(WIActs.conditions_met({"min_classes": 1}, _ctx(1, 0, {})), "min_classes met")
	assert(not WIActs.conditions_met({"accomplishments": {"reached_liscor": 1}}, _ctx(2, 4, {})), "missing acc unmet")
	assert(WIActs.conditions_met({"quests_completed": 3}, _ctx(0, 3, {})), "quests_completed met")

	# FRESH BOOT (all counters absent/zero) = Act I.
	var fresh := WIActs.evaluate(catalog, {})
	assert(fresh["id"] == "act_i" and fresh["index"] == 0, "fresh boot = Act I")
	# Act I beats both pending on a fresh boot.
	for beat: Dictionary in fresh["beats"]:
		assert(not bool(beat["achieved"]), "fresh Act I beats all pending")

	# Act I with a class but not yet in Liscor -> still Act I (gate needs BOTH).
	var got_class := WIActs.evaluate(catalog, _ctx(1, 0, {}))
	assert(got_class["index"] == 0, "class alone does not advance Act I")

	# Act I gate fully met (1 class + reached_liscor) -> Act II.
	var into_ii := WIActs.evaluate(catalog, _ctx(1, 0, {"reached_liscor": 1}))
	assert(into_ii["id"] == "act_ii" and into_ii["index"] == 1, "class + reached_liscor => Act II")

	# Mid Act II: some quests done but gate (2 classes + 3 quests) unmet -> still Act II.
	var mid_ii := WIActs.evaluate(catalog, _ctx(1, 2, {"reached_liscor": 1, "package_delivered": 1, "crate_returned": 1}))
	assert(mid_ii["index"] == 1, "1 class / 2 quests stays in Act II")
	# The two matching Act II beats read achieved; the capstone (2 classes/3 quests) does not.
	var achieved_ids: Array = []
	for beat: Dictionary in mid_ii["beats"]:
		if bool(beat["achieved"]):
			achieved_ids.append(beat["id"])
	assert(achieved_ids.has("errands_around") and achieved_ids.has("krshia_trust"), "mid Act II beats reflect counters")
	assert(not achieved_ids.has("known_face"), "Act II capstone pending until the gate")

	# Act II gate met (2 classes + 3 quests) -> Act III.
	var into_iii := WIActs.evaluate(catalog, _ctx(2, 3, {"reached_liscor": 1}))
	assert(into_iii["id"] == "act_iii" and into_iii["index"] == 2, "2 classes + 3 quests => Act III")

	# A save with EVERYTHING (incl. the not-yet-reachable raskghar_sealed) caps
	# at the last act -- there is no Act IV to advance into.
	var maxed := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "raskghar_sealed": 1}))
	assert(maxed["id"] == "act_iii" and maxed["index"] == 2, "maxed save caps at the last act")

	# TOLERANT of a sparse/old save shape: ctx with only accomplishments (no
	# classes_count/quests_completed keys) reads them as 0 without erroring.
	var sparse := WIActs.evaluate(catalog, {"accomplishments": {"reached_liscor": 1}})
	assert(sparse["index"] == 0, "sparse ctx (no class/quest keys) = Act I, no crash")

	# Empty catalog degrades to {}.
	assert(WIActs.evaluate({}, _ctx(2, 3, {})).is_empty(), "empty catalog => {}")

	print("PASS: act line derives purely from counters (fresh=Act I; gates advance; maxed caps)")
	quit(0)
