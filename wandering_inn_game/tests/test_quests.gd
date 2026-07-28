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
	var fight: Dictionary = WIQuests.resolved_path(seal, {"seal_opened": 1})
	assert(String(fight["accomplishment"]) == "seal_opened", "a lone seal_opened still resolves as the fight")
	var hatch: Dictionary = WIQuests.resolved_path(seal, {"seal_opened": 1, "seal_kept_fed": 1})
	assert(String(hatch["accomplishment"]) == "seal_kept_fed", "seal_opened + seal_kept_fed records the FED ending, not the fight")
	assert(int((hatch["grant"] as Dictionary).get("persuaded_someone", 0)) == 6 and not (hatch["grant"] as Dictionary).has("melee_hit"), "...and pays the FED grant, never the fight's melee bank")
	assert(String(WIQuests.resolution_path_text(seal, {"seal_opened": 1, "seal_kept_fed": 1})) == String(hatch["text"]), "the journal history line follows the same entry the grant did")
	var rewarded: Dictionary = WIQuests.resolved_path(seal, {"seal_opened": 1, "seal_rewarded": 1})
	assert(String(rewarded["accomplishment"]) == "seal_rewarded", "seal_opened + seal_rewarded records the RE-WARD ending")
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
