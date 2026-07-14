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

	print("PASS: quest progress derives purely from accomplishment counters")
	quit(0)
