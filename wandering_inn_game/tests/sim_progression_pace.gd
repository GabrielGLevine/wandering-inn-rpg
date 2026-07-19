extends SceneTree
## GH#211 progression-pace harness (design:
## docs/design/2026-07-19-211-challenge-weighted-leveling.md §6).
## Scripted Act I->III traces: REAL fights (WICombat + WICombatAI autoplay)
## resolved through the REAL banking seam (a locally-wired WICombatBanking —
## the exact deposit path #211's challenge weight / repetition decay will
## wrap), then the WIProgression sleep sequence. Reports per-act total-level
## bands per archetype. The flag ships ON (step 5); WI_PACE_WEIGHTED=0
## force-disables it to prove the legacy path still reproduces the
## pre-#211 baseline bands (warrior 6/14/16, caster 7/15/16, helper
## 10/21/26 p50 — recorded 2026-07-19); WI_PACE_WEIGHTED=1 force-enables
## regardless of data (symmetric probe). The determinism leg asserts
## same-seed runs reproduce counters exactly under whichever arm ran.
##
## MIRROR CONTRACT: _sleep_resolve() reproduces WIGame.sleep()'s progression
## order EXACTLY (gains -> level-ups -> consolidation offer preempts ->
## evolutions) — the sim_class_paths contract, same lockstep rule.
##
## Defeats bank NOTHING (WICombatBanking's victory branch — mirrors real
## play where a game-over reloads); the trace simply moves on, so a losing
## streak slows pace exactly as it does live.

const RUNS_PER_ARCHETYPE := 40
## Act boundaries in wakings — the trace positions where bands are read.
const ACT_ENDS := [10, 22, 36]

## Per-archetype act schedules. fights: rotation of composition indexes into
## COMPS, one fight per waking (rotation wraps). chores: flat per-waking
## civil banks. Rosters are REAL shipped cells (sim_combat_batch names);
## on_victory MIRRORS the in-game encounter's field (several Act-I fights
## bank won_combat explicitly — warrior/mage L2 gate on it); ally=relc on
## the cells the balance harness tunes WITH Relc.
const COMPS := [
	{"name": "crate_scavengers", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "on_victory": ["recovered_crate_force", "found_the_crate"]},
	{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "on_victory": ["won_combat", "sign_defended"], "ally": "relc"},
	{"name": "rock_crab_nest", "arena": "boulder_flats", "enemies": ["rock_crab"], "on_victory": ["rock_crabs_culled"], "ally": "relc"},
	{"name": "sewer_vermin", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "on_victory": ["cleared_sewer_vermin"]},
	{"name": "shield_spiders", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "on_victory": ["cleared_the_nest", "resolved_the_cisterns"], "ally": "relc"},
	{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"], "on_victory": ["won_combat"], "ally": "relc"},
	{"name": "raskghar_scouts", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "on_victory": ["cleared_raskghar_scouts"]},
	{"name": "goblin_night_patrol", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "on_victory": ["won_combat"]},
]

## quest_grants: waking -> authored grant deposits (mirrors the quests.json
## resolution_grant data for the path this archetype would take; applied via
## the REAL WICombatBanking.grant seam at that waking, pre-sleep — the §5
## "quest closes are the big movers" leg of the combined system).
var ARCHETYPES := [
	{"name": "warrior_line", "ai": "melee",
		"entry": {1: {"sparred_with_relc": 1}},
		"quest_grants": {10: {"melee_hit": 6, "won_combat": 1}, 22: {"melee_hit": 10, "won_combat": 2}, 36: {"melee_hit": 12, "won_combat": 2}},
		"acts": [
			{"fights": [0, 1, 2, 1], "chores": {}},
			{"fights": [3, 4, 7, 1], "chores": {}},
			{"fights": [5, 6, 7, 4], "chores": {}},
		]},
	{"name": "caster_line", "ai": "caster",
		"entry": {1: {"learned_magic_from_pisces": 1}},
		"quest_grants": {10: {"sneaked_past_danger": 2, "heard_gossip": 3}, 22: {"spell_cast": 8}, 36: {"persuaded_someone": 5, "heard_gossip": 8}},
		"acts": [
			{"fights": [0, 1, 2, 1], "chores": {}},
			{"fights": [3, 4, 7, 1], "chores": {}},
			{"fights": [5, 6, 7, 4], "chores": {}},
		]},
	{"name": "helper_social", "ai": "melee",
		"_comment": "fights every fourth waking; chores carry the pace — the non-combat pillar CONTROL (raw counting in v1, per directive)",
		"entry": {1: {"sparred_with_relc": 1, "cleaned_the_inn": 1}},
		"quest_grants": {10: {"cooked_meal": 4, "served_customer": 4}, 22: {"persuaded_someone": 3, "heard_gossip": 6}, 36: {"persuaded_someone": 5, "heard_gossip": 8}},
		"acts": [
			{"fights": [1, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "heard_gossip": 2}},
			{"fights": [3, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "persuaded_someone": 1}},
			{"fights": [7, -1, -1, -1], "chores": {"cleaned_the_inn": 2, "served_customer": 3, "befriended_moments": 1}},
		]},
]

var _acc: Dictionary = {}
var _used_skills: Array[String] = []
var _entity: Dictionary = {}
var _banking: WICombatBanking = null
var _frac: Dictionary = {}


func _init() -> void:
	var catalog: Dictionary = _load_json("res://data/classes.json")
	var skills: Dictionary = _load_json("res://data/skills.json")
	var arenas_by_id := {}
	for a: Dictionary in _load_json("res://data/arenas.json")["arenas"]:
		arenas_by_id[String(a[WIKeys.ID])] = a
	var combatants_by_id := {}
	for c: Dictionary in _load_json("res://data/combatants.json")["combatants"]:
		combatants_by_id[String(c[WIKeys.ID])] = c
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	# WI_PACE_WEIGHTED forces the flag either way (data ships enabled:true):
	# "0" = legacy-path regression arm (must reproduce the pre-#211 baseline
	# bands), "1" = force-on (symmetric; redundant while data is true).
	var challenge: Dictionary = (_load_json("res://data/progression.json").get("challenge", {}) as Dictionary).duplicate(true)
	if OS.get_environment("WI_PACE_WEIGHTED") == "1":
		challenge["enabled"] = true
		print("(WI_PACE_WEIGHTED probe: challenge weighting FORCED ON)")
	elif OS.get_environment("WI_PACE_WEIGHTED") == "0":
		challenge["enabled"] = false
		print("(WI_PACE_WEIGHTED=0: challenge weighting FORCED OFF — legacy regression arm)")
	var combatants_raw: Array = _load_json("res://data/combatants.json")["combatants"]
	_banking = WICombatBanking.new(sink, _mark_skill_used, _find_entity, _record, _count, _roll_loot_noop, _remove_noop, challenge, catalog, combatants_raw)

	print("progression pace: %d archetypes x %d runs, act ends %s" % [ARCHETYPES.size(), RUNS_PER_ARCHETYPE, str(ACT_ENDS)])
	var repeat_check := {}
	for arch: Dictionary in ARCHETYPES:
		# act -> Array of total-level samples
		var act_levels: Dictionary = {}
		var act_win_counts: Dictionary = {}
		for act_idx: int in ACT_ENDS.size():
			act_levels[act_idx] = []
			act_win_counts[act_idx] = []
		for run: int in RUNS_PER_ARCHETYPE:
			var classes: Dictionary = {}
			var generalists: Array = []
			var wins := 0
			_acc = {}
			_frac = {}
			_used_skills = []
			var act_idx := 0
			for waking: int in range(1, ACT_ENDS[-1] + 1):
				var entry: Dictionary = arch.get("entry", {})
				if entry.has(waking):
					for k: String in entry[waking]:
						_acc[k] = int(_acc.get(k, 0)) + int(entry[waking][k])
				var act: Dictionary = arch["acts"][act_idx]
				var rotation: Array = act["fights"]
				var comp_idx := int(rotation[(waking - 1) % rotation.size()])
				if comp_idx >= 0:
					var comp: Dictionary = COMPS[comp_idx]
					var fight_seed: int = hash(String(arch["name"])) + run * 1000 + waking
					if _run_fight(comp, classes, catalog, skills, arenas_by_id, combatants_by_id, String(arch["ai"]), fight_seed):
						wins += 1
				for k: String in act["chores"]:
					_acc[k] = int(_acc.get(k, 0)) + int(act["chores"][k])
				var qg: Dictionary = arch.get("quest_grants", {})
				if qg.has(waking):
					_banking.grant(qg[waking] as Dictionary, _frac)
				_sleep_resolve(classes, _acc, catalog, generalists, true)
				if waking >= 6:
					assert(not classes.is_empty(), "%s classless at waking %d — entry ids drifted from classes.json gained_by" % [arch["name"], waking])
				if waking == ACT_ENDS[act_idx]:
					(act_levels[act_idx] as Array).append(_total_levels(classes))
					(act_win_counts[act_idx] as Array).append(wins)
					act_idx = mini(act_idx + 1, ACT_ENDS.size() - 1)
			if run == 0:
				repeat_check[String(arch["name"])] = _acc.duplicate(true)
		print("\n[%s]" % arch["name"])
		for act_idx: int in ACT_ENDS.size():
			var samples: Array = act_levels[act_idx]
			samples.sort()
			print("  act %d (waking %d): total-level p10=%d p50=%d p90=%d  (fights won p50=%d)" % [
				act_idx + 1, ACT_ENDS[act_idx],
				samples[samples.size() / 10], samples[samples.size() / 2], samples[samples.size() * 9 / 10],
				_median(act_win_counts[act_idx]),
			])
		# Sanity gate: pace must be monotone and nonzero per act (band NUMBERS
		# are report-only until ratified via CHOICE-LOG; these structural
		# gates hold regardless of tuning).
		var p50s: Array = []
		for act_idx: int in ACT_ENDS.size():
			var s: Array = act_levels[act_idx]
			p50s.append(int(s[s.size() / 2]))
		assert(int(p50s[0]) >= 2, "%s: Act I median total level %d < 2 — trace banks too little" % [arch["name"], p50s[0]])
		assert(int(p50s[2]) > int(p50s[0]), "%s: no growth across acts (p50 %s)" % [arch["name"], str(p50s)])

	# Determinism / regression leg: the same seeded run must reproduce the
	# counter dictionary EXACTLY (the weight-off reproduction proof rides
	# this — after #211 lands, weight-off config re-runs must match too).
	for arch: Dictionary in ARCHETYPES:
		var classes: Dictionary = {}
		var generalists: Array = []
		_acc = {}
		_frac = {}
		_used_skills = []
		var act_idx := 0
		for waking: int in range(1, ACT_ENDS[-1] + 1):
			var entry: Dictionary = arch.get("entry", {})
			if entry.has(waking):
				for k: String in entry[waking]:
					_acc[k] = int(_acc.get(k, 0)) + int(entry[waking][k])
			var act: Dictionary = arch["acts"][act_idx]
			var rotation: Array = act["fights"]
			var comp_idx := int(rotation[(waking - 1) % rotation.size()])
			if comp_idx >= 0:
				var comp: Dictionary = COMPS[comp_idx]
				var fight_seed: int = hash(String(arch["name"])) + 0 * 1000 + waking
				var catalog2: Dictionary = catalog
				_run_fight(comp, classes, catalog2, skills, arenas_by_id, combatants_by_id, String(arch["ai"]), fight_seed)
			for k: String in act["chores"]:
				_acc[k] = int(_acc.get(k, 0)) + int(act["chores"][k])
			var qg: Dictionary = arch.get("quest_grants", {})
			if qg.has(waking):
				_banking.grant(qg[waking] as Dictionary, _frac)
			_sleep_resolve(classes, _acc, catalog, generalists, true)
			if waking == ACT_ENDS[act_idx]:
				act_idx = mini(act_idx + 1, ACT_ENDS.size() - 1)
		var first: Dictionary = repeat_check[String(arch["name"])]
		assert(JSON.stringify(_sorted(_acc)) == JSON.stringify(_sorted(first)),
			"%s: repeat run diverged from run 0 — banking path is not deterministic" % arch["name"])

	print("\nPASS: progression-pace harness — bands reported (ratify via CHOICE-LOG), determinism leg green")
	quit(0)


## One autoplay fight with the pc built from CURRENT classes; banks through
## the REAL WICombatBanking on victory. Returns victory.
func _run_fight(comp: Dictionary, classes: Dictionary, catalog: Dictionary, skills: Dictionary, arenas_by_id: Dictionary, combatants_by_id: Dictionary, ai: String, fight_seed: int) -> bool:
	var pc: Dictionary = (combatants_by_id["pc"] as Dictionary).duplicate(true)
	pc[WIKeys.AI] = ai
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], classes, catalog)
	pc[WIKeys.SKILLS] = WIProgression.granted_skills(classes, catalog)
	var cfgs: Array = [pc]
	if comp.has("ally"):
		cfgs.append((combatants_by_id[String(comp["ally"])] as Dictionary).duplicate(true))
	for enemy_id: String in comp["enemies"]:
		cfgs.append((combatants_by_id[enemy_id] as Dictionary).duplicate(true))
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var combat := WICombat.new(arenas_by_id[String(comp["arena"])], cfgs, skills, sink, fight_seed)
	combat.begin()
	var guard := 0
	while not combat.finished and guard < 2000:
		guard += 1
		WICombatAI.take_turn(combat)
	assert(combat.finished, "%s fight (seed %d) did not terminate" % [comp["name"], fight_seed])
	_entity = {"on_victory": comp["on_victory"]}
	var dormant: Array[String] = []
	_banking.resolve(combat, String(comp["name"]), dormant, classes, _frac)
	return bool(combat.outcome["victory"])


## --- WICombatBanking callable targets (local state) ---

func _mark_skill_used(skill_id: String) -> void:
	if skill_id == "" or _used_skills.has(skill_id):
		return
	_used_skills.append(skill_id)


func _find_entity(_id: String) -> Dictionary:
	return _entity


func _record(id: String, amount: int = 1) -> void:
	_acc[id] = int(_acc.get(id, 0)) + amount


func _count(id: String) -> int:
	return int(_acc.get(id, 0))


func _roll_loot_noop(_entity_arg: Dictionary) -> void:
	pass


func _remove_noop(_id: String) -> void:
	pass


## Mirror of WIGame.sleep()'s progression segment (see MIRROR CONTRACT).
func _sleep_resolve(classes: Dictionary, acc: Dictionary, catalog: Dictionary, generalists: Array, accept_policy: bool) -> void:
	for gained: Variant in WIProgression.check_class_gains(classes, acc, catalog):
		classes[String(gained)] = 1
	for up: Dictionary in WIProgression.check_level_ups(classes, acc, catalog):
		classes[String(up["class"])] = int(up["level"])
	var offer := WIProgression.check_consolidation(classes, catalog)
	if not offer.is_empty():
		if accept_policy:
			for parent: Variant in offer["parents"]:
				classes.erase(String(parent))
			classes[String(offer["target"])] = int(offer["level"])
		return
	for outcome: Dictionary in WIProgression.check_evolutions(classes, acc, catalog, generalists):
		if outcome.has("to"):
			classes[String(outcome["to"])] = int(outcome["level"])
			classes.erase(String(outcome["class"]))
		elif bool(outcome.get("generalist", false)):
			if not generalists.has(String(outcome["class"])):
				generalists.append(String(outcome["class"]))


func _total_levels(classes: Dictionary) -> int:
	var total := 0
	for held: Variant in classes.values():
		total += int(held)
	return total


func _median(samples: Array) -> int:
	var s := samples.duplicate()
	s.sort()
	return int(s[s.size() / 2])


func _sorted(d: Dictionary) -> Dictionary:
	var out := {}
	var keys := d.keys()
	keys.sort()
	for k: Variant in keys:
		out[k] = d[k]
	return out


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())
