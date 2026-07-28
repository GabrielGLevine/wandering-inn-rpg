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
	for beat: Dictionary in into_iii["beats"]:
		assert(not bool(beat["achieved"]), "both Act III beats pending on entry")

	# Act III's beats must be reachable IN Act III: both key off counters banked
	# before the seal, which is the act's own exit. (2026-07-26 reframe -- the old
	# pair keyed off raskghar_sealed/post_game and could never render in-act.)
	var mid_iii := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "heard_the_deep_tremor": 1}))
	assert(mid_iii["id"] == "act_iii" and mid_iii["index"] == 2, "the tremor summons does not advance Act III -- only the seal does")
	var mid_iii_achieved: Array = []
	for beat: Dictionary in mid_iii["beats"]:
		if bool(beat["achieved"]):
			mid_iii_achieved.append(beat["id"])
	assert(mid_iii_achieved == ["the_stirring"], "the tremor lights the_stirring while the player is still in Act III")

	var warren_iii := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "heard_the_deep_tremor": 1, "cleared_the_warren": 1}))
	assert(warren_iii["id"] == "act_iii" and warren_iii["index"] == 2, "victory below is still Act III -- the seal is a separate surface beat after the return")
	for beat: Dictionary in warren_iii["beats"]:
		assert(bool(beat["achieved"]), "both Act III beats read achieved on the pre-seal return, in-act")

	var sealed_only := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1}))
	assert(sealed_only["id"] == "act_iv" and sealed_only["index"] == 3, "the seal alone advances into Act IV (2026-07-26 reframe: the door is its own thread, not the gate)")
	for beat: Dictionary in sealed_only["beats"]:
		assert(not bool(beat["achieved"]), "every Act IV beat pends on a seal-only entry -- the door has not woken yet")

	# act_iv must not require door_awakened (2026-07-26 main-quest reframe)
	var gates: Dictionary = _act_gate(catalog, "act_iii")
	assert((gates.get("accomplishments", {}) as Dictionary).has("raskghar_sealed"), "the seal is what Act III's gate names")
	assert(not (gates.get("accomplishments", {}) as Dictionary).has("door_awakened"), "Act III's gate no longer names door_awakened")

	var into_iv := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1, "door_awakened": 1}))
	assert(into_iv["id"] == "act_iv" and into_iv["index"] == 3, "seal + door_awakened is Act IV -- the door is mid-act work now, not the act's exit")
	for beat: Dictionary in into_iv["beats"]:
		if String(beat["id"]) == "the_door_opens":
			assert(bool(beat["achieved"]), "the door beat reads achieved once door_awakened banks, mid-Act IV")
		else:
			assert(not bool(beat["achieved"]), "counted_among and the four region beats all pending until their own counters land")

	# counted_among carries the seal's closing line, and post_game banks only
	# after the seal has already moved the player on -- so it must render HERE.
	var counted := WIActs.evaluate(catalog, _ctx(6, 4, {"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1, "post_game": 1}))
	var counted_achieved: Array = []
	for beat: Dictionary in counted["beats"]:
		if bool(beat["achieved"]):
			counted_achieved.append(beat["id"])
	assert(counted["id"] == "act_iv" and counted_achieved == ["counted_among"], "post_game lights counted_among in Act IV, where the player actually stands when it banks")

	# 2026-07-26 Act V (Phase 7): the whole region arc WITHOUT the pilgrimage's
	# last piece still reads Act IV -- the gate is four keys (lattice_forge_rune,
	# seal_kept_reported, price_of_a_favor_reported, brothers_job_done; asserted
	# key-by-key below), and this context holds every one of them except the
	# forge rune, so six of the act's seven beats light.
	var region_arc := WIActs.evaluate(catalog, _ctx(6, 4, {
		"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1,
		"post_game": 1, "door_awakened": 1, "price_of_a_favor_reported": 1,
		"brothers_job_done": 1, "elevator_pass_stamped": 1, "seal_kept_reported": 1,
	}))
	assert(region_arc["id"] == "act_iv" and region_arc["index"] == 3, "the region arc without the third lattice piece stays in Act IV")
	var region_arc_achieved: Array = []
	for beat: Dictionary in region_arc["beats"]:
		if bool(beat["achieved"]):
			region_arc_achieved.append(beat["id"])
	assert(region_arc_achieved.size() == 6 and not region_arc_achieved.has("the_reach_mapped"), "six of Act IV's seven beats light; the pilgrimage beat waits on the forge rune")

	# Fix round 1 (controller ruling over plan 7.4): the two region terminals the
	# pilgrimage does not imply are back in the gate. Transitivity makes them
	# free -- lattice_witch_lore requires price_of_a_favor_reported and
	# lattice_hedault_reading requires brothers_job_done -- and naming them is
	# what keeps riverfarm_owed/invrisil_squared from stranding in an act the
	# player has already left.
	var iv_gate: Dictionary = (_act_gate(catalog, "act_iv").get("accomplishments", {}) as Dictionary)
	for key: String in ["lattice_forge_rune", "seal_kept_reported", "price_of_a_favor_reported", "brothers_job_done"]:
		assert(iv_gate.has(key), "Act IV's gate must name %s" % key)
	assert(iv_gate.size() == 4, "Act IV's gate is exactly those four keys")

	# The pilgrimage alone does NOT open Act V while a region beat is still
	# pending -- the stranding case this gate exists to prevent.
	var pilgrim_only := WIActs.evaluate(catalog, _ctx(6, 4, {
		"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1,
		"seal_kept_reported": 1, "lattice_forge_rune": 1,
	}))
	assert(pilgrim_only["id"] == "act_iv", "the forge rune + the seal report alone leave a region beat pending, so Act IV holds")

	var into_v := WIActs.evaluate(catalog, _ctx(6, 4, {
		"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1,
		"post_game": 1, "door_awakened": 1, "elevator_pass_stamped": 1,
		"seal_kept_reported": 1, "lattice_forge_rune": 1,
		"price_of_a_favor_reported": 1, "brothers_job_done": 1,
	}))
	assert(into_v["id"] == "act_v" and into_v["index"] == 4, "the pilgrimage's last piece plus the seal report opens Act V")
	for beat: Dictionary in into_v["beats"]:
		assert(not bool(beat["achieved"]), "every Act V beat pends on entry -- the descent has not been agreed yet")

	# Act V's own beats must render IN Act V (the act_iii lesson). Act V is
	# last, so even the resolution beat renders: the player never leaves it.
	var mid_v := WIActs.evaluate(catalog, _ctx(6, 4, {
		"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1,
		"seal_kept_reported": 1, "lattice_forge_rune": 1,
		"price_of_a_favor_reported": 1, "brothers_job_done": 1,
		"seal_descent_agreed": 1, "read_the_feeding_ward": 1,
	}))
	var mid_v_achieved: Array = []
	for beat: Dictionary in mid_v["beats"]:
		if bool(beat["achieved"]):
			mid_v_achieved.append(beat["id"])
	assert(mid_v["id"] == "act_v" and mid_v_achieved == ["the_descent", "the_reading"], "the descent and the reading light mid-Act V, before any path resolves")

	var maxed := WIActs.evaluate(catalog, _ctx(6, 4, {
		"reached_liscor": 1, "reached_two_classes": 1, "raskghar_sealed": 1,
		"post_game": 1, "door_awakened": 1, "price_of_a_favor_reported": 1,
		"brothers_job_done": 1, "elevator_pass_stamped": 1, "seal_kept_reported": 1,
		"lattice_forge_rune": 1, "seal_descent_agreed": 1, "read_the_feeding_ward": 1,
		"seal_resolved": 1, "seal_opened": 1,
	}))
	assert(maxed["id"] == "act_v" and maxed["index"] == 4, "maxed save caps at the last act (Act V)")
	var maxed_achieved: Array = []
	for beat: Dictionary in maxed["beats"]:
		if bool(beat["achieved"]):
			maxed_achieved.append(beat["id"])
	assert(maxed_achieved.size() == 3, "every Act V beat reads achieved on a fully maxed save, resolution included")

	var sparse := WIActs.evaluate(catalog, {"accomplishments": {"reached_liscor": 1}})
	assert(sparse["index"] == 0, "sparse ctx (no class/quest keys) = Act I, no crash")

	assert(WIActs.evaluate({}, _ctx(2, 3, {})).is_empty(), "empty catalog => {}")

	# Openings (v0.15 A1): evaluate() carries `opening` beside `text`;
	# render_beats() owns the POLICY -- banked => text, pending => opening,
	# pending with no opening => DROPPED (never falls back to outcome text).
	for beat: Dictionary in fresh["beats"]:
		assert(beat.has("opening"), "derived beats carry `opening` beside `text`")
		assert(String(beat["opening"]) != "", "shipped beats author an opening")
		assert(String(beat["opening"]) != String(beat["text"]), "opening is not the outcome line")

	var synth := {"acts": [{"id": "synth", "title": "T", "header": "T", "beats": [
		{"id": "banked", "text": "OUT-A", "opening": "OPEN-A", "when": {}},
		{"id": "pending_with", "text": "OUT-B", "opening": "OPEN-B", "when": {"min_classes": 1}},
		{"id": "pending_without", "text": "OUT-C", "when": {"min_classes": 1}},
		{"id": "pending_blank", "text": "OUT-D", "opening": "  \t ", "when": {"min_classes": 1}},
	]}]}
	var rows: Array = WIActs.render_beats(WIActs.evaluate(synth, {}))
	var row_ids: Array = []
	var row_lines: Array = []
	for raw_row: Variant in rows:
		var row := raw_row as Dictionary
		row_ids.append(String(row["id"]))
		row_lines.append(String(row["line"]))
	assert(row_ids == ["banked", "pending_with"], "an opening-less PENDING beat is dropped from the render list, never shown as outcome text -- a WHITESPACE-ONLY opening drops the same way, never a bare marker row")
	assert(row_lines == ["OUT-A", "OPEN-B"], "banked renders `text`, pending renders `opening`")
	assert(bool((rows[0] as Dictionary)["achieved"]) and not bool((rows[1] as Dictionary)["achieved"]), "render rows carry `achieved` for the journal marker")

	var synth_banked: Array = WIActs.render_beats(WIActs.evaluate(synth, _ctx(1, 0, {})))
	var banked_lines: Array = []
	for raw_row: Variant in synth_banked:
		banked_lines.append(String((raw_row as Dictionary)["line"]))
	assert(banked_lines == ["OUT-A", "OUT-B", "OUT-C", "OUT-D"], "once banked, every beat renders its outcome text -- including the opening-less and blank-opening ones")

	assert(WIActs.render_beats({}).is_empty(), "empty act => no render rows")

	# Every SHIPPED pending beat has a line to show: nothing vanishes in-game.
	for act: Dictionary in catalog["acts"]:
		var pending := WIActs.render_beats(WIActs.evaluate({"acts": [act]}, {}))
		assert(pending.size() == (act["beats"] as Array).size(), "%s renders every beat while pending (all openings authored)" % String(act["id"]))

	print("PASS: act line derives purely from counters (fresh=Act I; gates advance; maxed caps; pending beats render openings)")
	quit(0)
