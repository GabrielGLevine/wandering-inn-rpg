extends SceneTree
## Pure act-derivation tests.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_acts.gd
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

	# act_ii advances on the MONOTONIC `reached_two_classes`
	# accomplishment, NOT the live class count -- so a big raw classes_count with
	# the flag absent does NOT advance (proves the gate no longer reads size, the
	# property that stops a Spellsword consolidation from regressing the act line).
	var two_classes_no_flag := WIActs.evaluate(catalog, _ctx(2, 3, {"reached_liscor": 1}))
	assert(two_classes_no_flag["index"] == 1, "2 raw classes + 3 quests but no reached_two_classes flag stays Act II")
	# A post-consolidation save mid-Act-II (flag banked, only 2 quests done, so
	# act_ii's own gate not yet met) reads Act II at classes_count 1 -- the flag
	# holds act_i's advance without the live class count, so it never drops to Act I.
	var post_consolidation := WIActs.evaluate(catalog, _ctx(1, 2, {"reached_liscor": 1, "reached_two_classes": 1}))
	assert(post_consolidation["index"] == 1, "a post-consolidation save (classes_count 1, 2 quests) still reads Act II, not regressed to Act I")

	# Act II gate met (reached_two_classes + 3 quests) -> Act III. classes_count 1
	# here mirrors a consolidated [Spellsword] save: the flag alone advances it.
	var into_iii := WIActs.evaluate(catalog, _ctx(1, 3, {"reached_liscor": 1, "reached_two_classes": 1}))
	assert(into_iii["id"] == "act_iii" and into_iii["index"] == 2, "reached_two_classes + 3 quests => Act III (even at classes_count 1)")

	# A save with raskghar_sealed advances into Act IV (issue #89) -- no
	# further region beats banked yet, so every Act IV beat reads pending.
	var into_iv := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1}))
	assert(into_iv["id"] == "act_iv" and into_iv["index"] == 3, "raskghar_sealed advances into Act IV, the new last act")
	for beat: Dictionary in into_iv["beats"]:
		assert(not bool(beat["achieved"]), "fresh Act IV beats all pending")

	# A save with EVERYTHING (every Act IV region beat banked too) caps at
	# the last act -- there is no Act V to advance into.
	var maxed := WIActs.evaluate(catalog, _ctx(6, 4, {
		"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1,
		"door_awakened": 1, "price_of_a_favor_reported": 1, "brothers_job_done": 1,
		"elevator_pass_stamped": 1, "seal_kept_reported": 1,
	}))
	assert(maxed["id"] == "act_iv" and maxed["index"] == 3, "maxed save caps at the last act (Act IV)")
	var maxed_achieved: Array = []
	for beat: Dictionary in maxed["beats"]:
		if bool(beat["achieved"]):
			maxed_achieved.append(beat["id"])
	assert(maxed_achieved.size() == 5, "every Act IV beat reads achieved on a fully maxed save")

	# TOLERANT of a sparse/old save shape: ctx with only accomplishments (no
	# classes_count/quests_completed keys) reads them as 0 without erroring.
	var sparse := WIActs.evaluate(catalog, {"accomplishments": {"reached_liscor": 1}})
	assert(sparse["index"] == 0, "sparse ctx (no class/quest keys) = Act I, no crash")

	# Empty catalog degrades to {}.
	assert(WIActs.evaluate({}, _ctx(2, 3, {})).is_empty(), "empty catalog => {}")

	print("PASS: act line derives purely from counters (fresh=Act I; gates advance; maxed caps)")
	quit(0)
