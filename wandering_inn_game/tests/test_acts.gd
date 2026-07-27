extends SceneTree


func _ctx(classes_count: int, quests_completed: int, accs: Dictionary) -> Dictionary:
	return {"classes_count": classes_count, "quests_completed": quests_completed, "accomplishments": accs}


func _act_gate(catalog: Dictionary, act_id: String) -> Dictionary:
	var acts: Array = catalog.get("acts", [])
	for act: Dictionary in acts:
		if String(act["id"]) == act_id:
			return act.get("advance_when", {})
	return {}


func _init() -> void:
	WITestWatchdog.arm(self)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/acts.json"))
	assert(parsed is Dictionary, "acts.json parses")
	var catalog: Dictionary = parsed

	assert(WIActs.conditions_met({}, {}), "empty condition met")
	assert(not WIActs.conditions_met({"min_classes": 1}, {}), "min_classes unmet with no counters")
	assert(WIActs.conditions_met({"min_classes": 1}, _ctx(1, 0, {})), "min_classes met")
	assert(not WIActs.conditions_met({"accomplishments": {"reached_liscor": 1}}, _ctx(2, 4, {})), "missing acc unmet")
	assert(WIActs.conditions_met({"quests_completed": 3}, _ctx(0, 3, {})), "quests_completed met")

	var fresh := WIActs.evaluate(catalog, {})
	assert(fresh["id"] == "act_i" and fresh["index"] == 0, "fresh boot = Act I")
	for beat: Dictionary in fresh["beats"]:
		assert(not bool(beat["achieved"]), "fresh Act I beats all pending")

	var got_class := WIActs.evaluate(catalog, _ctx(1, 0, {}))
	assert(got_class["index"] == 0, "class alone does not advance Act I")

	var into_ii := WIActs.evaluate(catalog, _ctx(1, 0, {"reached_liscor": 1}))
	assert(into_ii["id"] == "act_ii" and into_ii["index"] == 1, "class + reached_liscor => Act II")

	var mid_ii := WIActs.evaluate(catalog, _ctx(1, 2, {"reached_liscor": 1, "package_delivered": 1, "crate_returned": 1}))
	assert(mid_ii["index"] == 1, "1 class / 2 quests stays in Act II")
	var achieved_ids: Array = []
	for beat: Dictionary in mid_ii["beats"]:
		if bool(beat["achieved"]):
			achieved_ids.append(beat["id"])
	assert(achieved_ids.has("errands_around") and achieved_ids.has("krshia_trust"), "mid Act II beats reflect counters")
	assert(not achieved_ids.has("known_face"), "Act II capstone pending until the gate")

	var two_classes_no_flag := WIActs.evaluate(catalog, _ctx(2, 3, {"reached_liscor": 1}))
	assert(two_classes_no_flag["index"] == 1, "2 raw classes + 3 quests but no reached_two_classes flag stays Act II")
	var post_consolidation := WIActs.evaluate(catalog, _ctx(1, 2, {"reached_liscor": 1, "reached_two_classes": 1}))
	assert(post_consolidation["index"] == 1, "a post-consolidation save (classes_count 1, 2 quests) still reads Act II, not regressed to Act I")

	var into_iii := WIActs.evaluate(catalog, _ctx(1, 3, {"reached_liscor": 1, "reached_two_classes": 1}))
	assert(into_iii["id"] == "act_iii" and into_iii["index"] == 2, "reached_two_classes + 3 quests => Act III (even at classes_count 1)")

	var sealed_only := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1}))
	assert(sealed_only["id"] == "act_iv" and sealed_only["index"] == 3, "the seal alone advances into Act IV (2026-07-26 reframe: the door is its own thread, not the gate)")
	for beat: Dictionary in sealed_only["beats"]:
		assert(not bool(beat["achieved"]), "every Act IV beat pends on a seal-only entry -- the door has not woken yet")

	# act_iv must not require door_awakened (2026-07-26 main-quest reframe)
	var gates: Dictionary = _act_gate(catalog, "act_iii")
	assert((gates.get("accomplishments", {}) as Dictionary).has("raskghar_sealed"), "the seal is what Act III's gate names")
	assert(not (gates.get("accomplishments", {}) as Dictionary).has("door_awakened"), "Act III's gate no longer names door_awakened")

	var into_iv := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1, "door_awakened": 1}))
	assert(into_iv["id"] == "act_iv" and into_iv["index"] == 3, "seal + door_awakened is still Act IV, the last act")
	for beat: Dictionary in into_iv["beats"]:
		if String(beat["id"]) == "the_door_opens":
			assert(bool(beat["achieved"]), "the door beat reads achieved once door_awakened banks, mid-Act IV")
		else:
			assert(not bool(beat["achieved"]), "the four region beats all pending until their own counters land")

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

	var sparse := WIActs.evaluate(catalog, {"accomplishments": {"reached_liscor": 1}})
	assert(sparse["index"] == 0, "sparse ctx (no class/quest keys) = Act I, no crash")

	assert(WIActs.evaluate({}, _ctx(2, 3, {})).is_empty(), "empty catalog => {}")

	print("PASS: act line derives purely from counters (fresh=Act I; gates advance; maxed caps)")
	quit(0)
