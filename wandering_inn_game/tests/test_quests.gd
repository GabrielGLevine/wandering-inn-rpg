extends SceneTree

const CATALOG := {"quests": [{"id": "the_errand", "title": "The Errand", "beats": [
	{"id": "deliver", "description": "Deliver the package.", "complete_when": {"package_delivered": 1}},
	{"id": "decide", "description": "Decide about the reward.", "complete_when": {"errand_decided": 1}},
]}]}

const REGION_CATALOG := {"quests": [
	{"id": "far_quest", "title": "Far Quest", "region": "Riverfarm", "beats": [
		{"id": "only", "description": "Do the thing.", "complete_when": {"did_the_thing": 1}},
	]},
	{"id": "local_quest", "title": "Local Quest", "beats": [
		{"id": "only", "description": "Do the local thing.", "complete_when": {"did_the_local_thing": 1}},
	]},
]}


func _init() -> void:
	WITestWatchdog.arm(self)
	var q: Dictionary = CATALOG["quests"][0]
	assert(WIQuests.beat_index(q, {}) == 0, "nothing done = beat 0")
	assert(WIQuests.beat_index(q, {"package_delivered": 1}) == 1, "first beat done")
	assert(WIQuests.beat_index(q, {"package_delivered": 1, "errand_decided": 1}) == 2, "all done = beats.size()")
	assert(WIQuests.beat_index(q, {"errand_decided": 1}) == 0, "later accomplishment alone doesn't skip beats")

	var ev := WIQuests.evaluate(CATALOG, ["the_errand"], {"package_delivered": 1})
	assert(ev["the_errand"]["beat_index"] == 1 and not ev["the_errand"]["completed"], "evaluate mid-quest")
	assert(ev["the_errand"]["beat_description"] == "Decide about the reward.", "current beat description")
	assert(WIQuests.evaluate(CATALOG, [], {}).is_empty(), "unstarted quests absent")
	var done := WIQuests.evaluate(CATALOG, ["the_errand"], {"package_delivered": 1, "errand_decided": 1})
	assert(done["the_errand"]["completed"] and done["the_errand"]["beat_description"] == "", "completed shape")

	# v0.15 A5, the OR-producer idiom: `complete_when_any` sits BESIDE
	# `complete_when` and either side closes the beat. Shape cases first, then the
	# two shipped postings it was added for.
	var or_beat := {"complete_when": {"resolved": 1}, "complete_when_any": {"scouted": 1}}
	assert(WIQuests._beat_met(or_beat, {"resolved": 1}), "the AND side alone still closes the beat")
	assert(WIQuests._beat_met(or_beat, {"scouted": 1}), "the OR alternative alone closes the beat")
	assert(not WIQuests._beat_met(or_beat, {"something_else": 1}), "neither side satisfied leaves the beat open")
	assert(WIQuests._beat_met({"complete_when": {"a": 1}}, {"a": 1}), "a beat with no alternatives is unchanged")
	assert(not WIQuests._beat_met({"complete_when": {"a": 1, "b": 1}}, {"a": 1}), "complete_when stays an AND")
	assert(WIQuests._beat_met({"complete_when_any": {"a": 1, "b": 1}}, {"b": 1}), "complete_when_any is an OR across its own keys")

	var regions := WIQuests.evaluate(REGION_CATALOG, ["far_quest", "local_quest"], {})
	assert(regions["far_quest"]["region"] == "Riverfarm", "region field threads through when authored")
	assert(regions["local_quest"]["region"] == "", "region defaults to empty string, never missing/null, when unauthored")

	# resolved_path is LAST-MATCH-WINS among real counters (sleep_veil.gd's own
	# FINALE_CLOSE_LINES convention); an ""-req entry is the fallback, never a
	# match. THE BOUNCE HATCH: seal_opened stays banked when a later resolution
	# lands, and first-match used to record the FIGHT ending and pay the FIGHT
	# grant over the finale's own last-match close line.
	var shipped: Dictionary = _load_json("res://data/quests.json")
	var seal: Dictionary = WIQuests.quest_by_id(shipped, "what_the_seal_was_feeding")
	assert(not seal.is_empty(), "sanity: the Act V quest is in the shipped catalog")

	var cisterns: Dictionary = WIQuests.quest_by_id(shipped, "cisterns")
	assert(WIQuests.beat_index(cisterns, {"scouted_the_nest": 1}) == 1,
		"SCOUTING the nest closes the resolve beat -- the [Appraise Foe] route banks scouted_the_nest at the ledge and picks up resolved_the_cisterns only at Olesm's desk, so before this the journal kept asking a player who had already done it")
	assert(WIQuests.beat_index(cisterns, {"scouted_the_nest": 1, "cisterns_reported": 1}) == 2, "...and reporting still completes it")
	assert(WIQuests.beat_index(cisterns, {"cleared_the_nest": 1}) == 0, "the FIGHT route does not close resolve on its own counter -- it banks resolved_the_cisterns, which is the AND side")
	var wrong_order: Dictionary = WIQuests.quest_by_id(shipped, "wrong_order")
	assert(WIQuests.beat_index(wrong_order, {"stretched_the_order": 1}) == 1,
		"STRETCHING the order in the kitchen closes the resolve beat -- same lag as the cisterns scout, banked at the pot and only settled when Lyonette is told")

	var fight: Dictionary = WIQuests.resolved_path(seal, {"seal_opened": 1})
	assert(String(fight["accomplishment"]) == "seal_opened", "a lone seal_opened still resolves as the fight")
	var hatch: Dictionary = WIQuests.resolved_path(seal, {"seal_opened": 1, "seal_kept_fed": 1})
	assert(String(hatch["accomplishment"]) == "seal_kept_fed", "seal_opened + seal_kept_fed records the FED ending, not the fight")
	assert(int((hatch["grant"] as Dictionary).get("persuaded_someone", 0)) == 6 and not (hatch["grant"] as Dictionary).has("melee_hit"), "...and pays the FED grant, never the fight's melee bank")
	assert(String(WIQuests.resolution_path_text(seal, {"seal_opened": 1, "seal_kept_fed": 1})) == String(hatch["text"]), "the journal history line follows the same entry the grant did")
	var rewarded: Dictionary = WIQuests.resolved_path(seal, {"seal_opened": 1, "seal_rewarded": 1})
	assert(String(rewarded["accomplishment"]) == "seal_rewarded", "seal_opened + seal_rewarded records the RE-WARD ending")

	# THE OTHER TWO CO-BANKABLE QUESTS. Both arrays are ordered weakest-claim-
	# first so last-match lands on the strongest thing the player actually did.
	var cist: Dictionary = WIQuests.quest_by_id(shipped, "cisterns")
	assert(String(WIQuests.resolved_path(cist, {"scouted_the_nest": 1})["accomplishment"]) == "scouted_the_nest", "a scout-only cisterns run still records the scout")
	var cist_both: Dictionary = WIQuests.resolved_path(cist, {"scouted_the_nest": 1, "cleared_the_nest": 1})
	assert(String(cist_both["accomplishment"]) == "cleared_the_nest", "scouted THEN cleared records the CLEAR -- the stronger claim wins")
	assert(int((cist_both["grant"] as Dictionary).get("won_combat", 0)) == 2 and not (cist_both["grant"] as Dictionary).has("sneaked_past_danger"), "...and pays the clear grant, not the scout's")
	assert(String(WIQuests.resolved_path(cist, {"scouted_the_nest": 1, "watch_swept_cisterns": 1})["accomplishment"]) == "watch_swept_cisterns", "scouted THEN sent the Watch records the sweep")

	# v0.15 A5, THE PACIFIST RELABEL. The trapped halls have three routes and only
	# two of them used to have an id: the snare fight and the dart-slit disarm both
	# banked nothing but `halls_cleared`, so the disarmer fell through to a fallback
	# that told them they had cleared the halls themselves and paid 12 melee hits
	# they never landed. `cleared_halls_by_force` gives the fight its own id; the
	# fallback is now the disarm route, and says so.
	var halls: Dictionary = WIQuests.quest_by_id(shipped, "what_the_seal_kept")
	var disarmed: Dictionary = WIQuests.resolved_path(halls, {"halls_cleared": 1})
	assert(String(disarmed["accomplishment"]) == "", "halls_cleared alone is the DISARM route -- it falls through to the fallback")
	var disarm_grant: Dictionary = disarmed["grant"]
	assert(not disarm_grant.has("melee_hit") and not disarm_grant.has("won_combat"), "the pacifist route must stop paying combat counters (spec A5)")
	assert(int(disarm_grant.get("sneaked_past_danger", 0)) == 6 and int(disarm_grant.get("persuaded_someone", 0)) == 2, "...and pays the relabelled grant instead")
	var by_force: Dictionary = WIQuests.resolved_path(halls, {"halls_cleared": 1, "cleared_halls_by_force": 1})
	assert(String(by_force["text"]) == "You cleared the trapped halls yourself.", "the FIGHT keeps its own line, verbatim")
	assert(int((by_force["grant"] as Dictionary).get("melee_hit", 0)) == 12 and int((by_force["grant"] as Dictionary).get("won_combat", 0)) == 2, "...and its own grant, verbatim -- a fighter loses nothing to this fix")
	var guided_then_fought: Dictionary = WIQuests.resolved_path(halls, {"guided_ksmvr_through_plates": 1, "cleared_halls_by_force": 1})
	assert(String(guided_then_fought["accomplishment"]) == "cleared_halls_by_force", "guided THEN fought records the FIGHT -- weakest-claim-first, last match wins")
	assert(String(WIQuests.resolved_path(halls, {"guided_ksmvr_through_plates": 1})["accomplishment"]) == "guided_ksmvr_through_plates", "a talk-only run still records Ksmvr")

	var door: Dictionary = WIQuests.quest_by_id(shipped, "door_that_goes_elsewhere")
	assert(String(WIQuests.resolved_path(door, {"read_the_door_runes": 1})["accomplishment"]) == "read_the_door_runes", "a read-only door run still records the reading")
	var door_both: Dictionary = WIQuests.resolved_path(door, {"read_the_door_runes": 1, "cleared_the_leak": 1})
	assert(String(door_both["accomplishment"]) == "cleared_the_leak", "read THEN fought records the FIGHT -- the stronger claim wins")
	assert(int((door_both["grant"] as Dictionary).get("won_combat", 0)) == 2 and not (door_both["grant"] as Dictionary).has("spell_cast"), "...and pays the fight grant, not the reading's")
	assert(String(WIQuests.resolved_path(door, {})["text"]) == "You consulted Pisces about it.", "neither counter banked falls through to the consult fallback")

	# missing_crate: three INDEPENDENT surfaces (street fight / watch_crate /
	# Krshia's guile read, which hides only on crate_returned), so a player who
	# fights and then still reads the truth holds two. Ladder: force > watch > guile.
	var crate: Dictionary = WIQuests.quest_by_id(shipped, "missing_crate")
	assert(String(WIQuests.resolved_path(crate, {"recovered_crate_guile": 1})["accomplishment"]) == "recovered_crate_guile", "a guile-only crate run still records the guile")
	var crate_both: Dictionary = WIQuests.resolved_path(crate, {"recovered_crate_force": 1, "recovered_crate_guile": 1})
	assert(String(crate_both["accomplishment"]) == "recovered_crate_force", "fought THEN read the truth records the FORCE ending -- the stronger claim wins")
	assert(int((crate_both["grant"] as Dictionary).get("won_combat", 0)) == 1 and not (crate_both["grant"] as Dictionary).has("sneaked_past_danger"), "...and pays the force grant, not the guile's")
	assert(String(WIQuests.resolved_path(crate, {"recovered_crate_guile": 1, "recovered_crate_watch": 1})["accomplishment"]) == "recovered_crate_watch", "guile then the Watch records the Watch")

	# wrong_order: the short_order pot is ungated and supplier_scavengers carries
	# no encounter_when, so cooking and fighting stay available after either.
	var order: Dictionary = WIQuests.quest_by_id(shipped, "wrong_order")
	assert(String(WIQuests.resolved_path(order, {"stretched_the_order": 1})["accomplishment"]) == "stretched_the_order", "a kitchen-only run still records the stretch")
	var order_both: Dictionary = WIQuests.resolved_path(order, {"strongarmed_the_supplier": 1, "stretched_the_order": 1})
	assert(String(order_both["accomplishment"]) == "strongarmed_the_supplier", "strong-armed THEN cooked records the STRONG-ARM ending -- the stronger claim wins")
	assert(int((order_both["grant"] as Dictionary).get("won_combat", 0)) == 1 and not (order_both["grant"] as Dictionary).has("cooked_meal"), "...and pays the strong-arm grant, not the kitchen's")

	# v0.16 #305: both Riverfarm side quests co-bank freely (clear the granary,
	# then still walk the tally), so the ladder order is load-bearing the same
	# way price_of_a_favor's is. Ladder: read > worked > cleared.
	# Locals are r_-prefixed: this whole function is one scope and four lanes
	# append pins into it this wave.
	var r_ledger: Dictionary = WIQuests.quest_by_id(shipped, "flood_ledger")
	assert(String(WIQuests.resolved_path(r_ledger, {"granary_cleared": 1})["accomplishment"]) == "granary_cleared", "a fight-only flood_ledger run still records the granary")
	assert(String(WIQuests.resolved_path(r_ledger, {"granary_cleared": 1, "ledger_read_true": 1})["accomplishment"]) == "ledger_read_true", "cleared THEN read the tally records the READING -- the stronger claim wins")
	assert(String(WIQuests.resolved_path(r_ledger, {"flood_prep_done": 1, "granary_cleared": 1})["accomplishment"]) == "flood_prep_done", "cleared then worked records the WORK")

	# Ladder: read > rerouted > cleared.
	var r_thicket: Dictionary = WIQuests.quest_by_id(shipped, "what_the_thicket_keeps")
	assert(String(WIQuests.resolved_path(r_thicket, {"herd_rerouted": 1})["accomplishment"]) == "herd_rerouted", "a talk-only thicket run still records the reroute")
	assert(String(WIQuests.resolved_path(r_thicket, {"thicket_cleared": 1, "ward_scrap_read": 1})["accomplishment"]) == "ward_scrap_read", "killed the den THEN read the ward records the READING")
	assert(String(WIQuests.resolved_path(r_thicket, {"thicket_cleared": 1, "herd_rerouted": 1})["accomplishment"]) == "herd_rerouted", "killed then rerouted records the REROUTE")

	# price_of_a_favor co-banks too, and its authored order already reads right:
	# the renegotiated year is what lifts the blight, not clearing the field.
	var favor: Dictionary = WIQuests.quest_by_id(shipped, "price_of_a_favor")
	assert(String(WIQuests.resolved_path(favor, {"drove_off_collectors": 1, "mediated_the_debt": 1})["accomplishment"]) == "mediated_the_debt", "drove off THEN brokered records the MEDIATION")
	assert(String(WIQuests.resolved_path(favor, {})["text"]) == "You paid the debt yourself, at the standing stones.", "neither counter banked falls through to the stones fallback")

	# EVERY shipped array with 2+ real rungs must carry its ladder in writing --
	# the ordering is load-bearing now, and an unnoted array is an unreviewed one.
	for quest: Dictionary in shipped.get("quests", []):
		var real_rungs := 0
		for entry: Variant in quest.get("resolution_paths", []):
			if String((entry as Dictionary).get("accomplishment", "")) != "":
				real_rungs += 1
		if real_rungs >= 2:
			assert(quest.has("_resolution_order"), "quest %s has %d real resolution rungs but no _resolution_order note -- last-match makes the array order load-bearing" % [String(quest["id"]), real_rungs])
	# The ""-req fallback keeps losing to any real match, wherever it sits.
	var fallback_first := {"resolution_paths": [
		{"accomplishment": "", "text": "fallback"},
		{"accomplishment": "did_a", "text": "a"},
	]}
	assert(String(WIQuests.resolved_path(fallback_first, {"did_a": 1})["text"]) == "a", "a real match beats an EARLIER authored fallback")
	assert(String(WIQuests.resolved_path(fallback_first, {})["text"]) == "fallback", "...and the fallback still answers when nothing banked")
	assert(WIQuests.resolved_path({"resolution_paths": [{"accomplishment": "nope", "text": "x"}]}, {}).is_empty(), "no match and no fallback = no entry")

	print("PASS: quest progress derives purely from accomplishment counters")
	quit(0)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed
