extends SceneTree
## GH#160 class-path diversity harness (v0.10.0). Simulates archetypal
## players' counter accumulation through the REAL WIProgression sleep
## sequence and reports the distribution of terminal class paths.
##
## MIRROR CONTRACT: _sleep_resolve() below reproduces WIGame.sleep()'s
## progression order EXACTLY -- gains -> level-ups -> consolidation offer
## (which PREEMPTS evolutions that sleep; decline re-offers every
## qualifying sleep) -> evolutions (Replacement swaps id at held level;
## Generalist locks into generalist_classes). If sleep() changes, this
## harness measures a different game: keep them in lockstep (the
## sim_combat_batch/WICombatBuild precedent).
##
## The funnel question (user directive 2026-07-17): do combat-optimal
## choices inevitably end in [Spellsword]? GATES: pooled combat-lane
## [Spellsword] share <= FUNNEL_MAX at the last horizon, pooled terminal
## class-set entropy >= ENTROPY_MIN bits. Everything else is measured.

const RUNS_PER_ARCHETYPE := 200
const HORIZONS := [12, 25, 50]
const FUNNEL_MAX := 0.45
const ENTROPY_MIN := 2.0

## Archetypes: entry = one-time gained_by banks at a scripted waking
## (ids validated against classes.json gained_by -- the assert below fails
## the run if an archetype is still classless at waking 6). waking =
## {counter: [mean, jitter]} banked per waking, approximating real play
## (a fight ~= 5-7 curve hits + won_combat 1; a civil day banks errand
## counters instead). lane tags drive the funnel gate pool.
var ARCHETYPES := [
	{"name": "sword_fighter", "lane": "combat", "consolidate": true,
		"entry": {1: {"sparred_with_relc": 1}},
		"waking": {"melee_hit": [6, 2], "sword_skill_used": [2, 1], "won_combat": [1, 0]}},
	{"name": "spear_fighter", "lane": "combat", "consolidate": true,
		"entry": {1: {"sparred_with_relc": 1}},
		"waking": {"melee_hit": [6, 2], "spear_skill_used": [2, 1], "won_combat": [1, 0]}},
	{"name": "ice_caster", "lane": "combat", "consolidate": true,
		"entry": {1: {"learned_magic_from_pisces": 1}},
		"waking": {"spell_cast": [5, 2], "ice_cast": [3, 1], "won_combat": [1, 0]}},
	{"name": "fire_caster", "lane": "combat", "consolidate": true,
		"entry": {1: {"learned_magic_from_pisces": 1}},
		"waking": {"spell_cast": [5, 2], "fire_cast": [3, 1], "won_combat": [1, 0]}},
	{"name": "balanced_mage", "lane": "combat", "consolidate": true,
		"_comment": "casts both elements evenly -> the High-Mage generalist outcome",
		"entry": {1: {"learned_magic_from_pisces": 1}},
		"waking": {"spell_cast": [5, 2], "ice_cast": [2, 1], "fire_cast": [2, 1], "won_combat": [1, 0]}},
	{"name": "battle_mage_optimizer", "lane": "combat", "consolidate": true,
		"_comment": "THE funnel case: optimal-combat play splits sword+spell toward [Spellsword]",
		"entry": {1: {"sparred_with_relc": 1, "learned_magic_from_pisces": 1}},
		"waking": {"melee_hit": [4, 1], "sword_skill_used": [1, 1], "spell_cast": [3, 1], "won_combat": [1, 0]}},
	{"name": "archer", "lane": "combat", "consolidate": true,
		"entry": {},
		"waking": {"ranged_hit": [5, 2], "bow_skill_used": [2, 1], "won_combat": [1, 0]}},
	{"name": "warcher_ranger", "lane": "combat", "consolidate": true,
		"_comment": "sword+bow split -> [Ranger] lane",
		"entry": {1: {"sparred_with_relc": 1}},
		"waking": {"melee_hit": [4, 1], "sword_skill_used": [1, 1], "ranged_hit": [3, 1], "bow_skill_used": [1, 1], "won_combat": [1, 0]}},
	{"name": "sneak_thief", "lane": "mixed", "consolidate": true,
		"entry": {1: {"recovered_crate_watch": 1}},
		"waking": {"sneaked_past_danger": [3, 1], "ranged_hit": [2, 1], "bow_skill_used": [1, 1], "won_combat": [1, 1]}},
	{"name": "socialite_helper", "lane": "civil", "consolidate": true,
		"entry": {1: {"cleaned_the_inn": 1}, 3: {"persuaded_someone": 1, "heard_gossip": 3}},
		"waking": {"cleaned_the_inn": [2, 1], "served_customer": [3, 1], "heard_gossip": [2, 1], "befriended_moments": [1, 1]}},
	{"name": "merchant", "lane": "civil", "consolidate": true,
		"entry": {},
		"waking": {"deliberate_commerce": [3, 1]}},
	{"name": "alchemist_crafter", "lane": "civil", "consolidate": true,
		"entry": {2: {"synthesized_draught": 1}},
		"waking": {"synthesized_draught": [3, 1]}},
	{"name": "beast_handler", "lane": "mixed", "consolidate": true,
		"entry": {1: {"soothed_a_beast": 1}},
		"waking": {"tended_beasts": [3, 1], "melee_hit": [2, 1], "won_combat": [1, 1]}},
	{"name": "druid_curious", "lane": "mixed", "consolidate": true,
		"entry": {1: {"soothed_a_beast": 1, "learned_magic_from_pisces": 1}},
		"waking": {"tended_beasts": [2, 1], "spell_cast": [3, 1], "won_combat": [1, 1]}},
	{"name": "jack_decliner", "lane": "mixed", "consolidate": false,
		"_comment": "decline-policy control: offers must re-fire, never wedge",
		"entry": {1: {"sparred_with_relc": 1, "recovered_crate_watch": 1}},
		"waking": {"melee_hit": [3, 1], "sword_skill_used": [1, 1], "sneaked_past_danger": [2, 1], "won_combat": [1, 1]}},
]


func _init() -> void:
	var catalog: Dictionary = _load_json("res://data/classes.json")
	var rng := RandomNumberGenerator.new()
	var pooled_terminal: Dictionary = {}
	var lane_terminal: Dictionary = {}  # lane -> {class_set_key: count} at last horizon
	var rep_builds: Dictionary = {}  # archetype -> representative leveled build at last horizon
	print("class-path diversity: %d archetypes x %d runs, horizons %s" % [ARCHETYPES.size(), RUNS_PER_ARCHETYPE, str(HORIZONS)])
	for arch: Dictionary in ARCHETYPES:
		var horizon_sets: Dictionary = {}  # horizon -> {key: count}
		for h: int in HORIZONS:
			horizon_sets[h] = {}
		for run: int in RUNS_PER_ARCHETYPE:
			rng.seed = hash(String(arch["name"])) + run
			var classes: Dictionary = {}
			var acc: Dictionary = {}
			var generalists: Array = []
			var horizon_idx := 0
			for waking: int in range(1, HORIZONS[-1] + 1):
				var entry: Dictionary = arch.get("entry", {})
				if entry.has(waking):
					for k: String in entry[waking]:
						acc[k] = int(acc.get(k, 0)) + int(entry[waking][k])
				for k: String in arch["waking"]:
					var spec: Array = arch["waking"][k]
					var n := int(spec[0]) + rng.randi_range(-int(spec[1]), int(spec[1]))
					if n > 0:
						acc[k] = int(acc.get(k, 0)) + n
				_sleep_resolve(classes, acc, catalog, generalists, bool(arch["consolidate"]))
				if waking >= 6:
					assert(not classes.is_empty(), "%s still classless at waking %d -- entry ids drifted from classes.json gained_by" % [arch["name"], waking])
				if waking == HORIZONS[horizon_idx]:
					var key := _class_set_key(classes, generalists)
					var sets: Dictionary = horizon_sets[waking]
					sets[key] = int(sets.get(key, 0)) + 1
					if waking == HORIZONS[-1]:
						pooled_terminal[key] = int(pooled_terminal.get(key, 0)) + 1
						if not rep_builds.has(String(arch["name"])):
							rep_builds[String(arch["name"])] = {"key": key, "classes": classes.duplicate(true), "count": 0}
						if rep_builds[String(arch["name"])]["key"] == key:
							rep_builds[String(arch["name"])]["count"] = int(rep_builds[String(arch["name"])]["count"]) + 1
						var lane := String(arch["lane"])
						if not lane_terminal.has(lane):
							lane_terminal[lane] = {}
						lane_terminal[lane][key] = int(lane_terminal[lane].get(key, 0)) + 1
					horizon_idx = mini(horizon_idx + 1, HORIZONS.size() - 1)
		print("\n[%s] (%s lane)" % [arch["name"], arch["lane"]])
		for h: int in HORIZONS:
			print("  waking %d: %s" % [h, _dist_str(horizon_sets[h])])

	print("\n=== pooled terminal distribution (waking %d) ===" % HORIZONS[-1])
	print(_dist_str(pooled_terminal))
	var entropy := _entropy_bits(pooled_terminal)
	print("path entropy: %.2f bits (gate >= %.2f)" % [entropy, ENTROPY_MIN])
	var combat_total := 0
	var combat_spellsword := 0
	for key: String in lane_terminal.get("combat", {}):
		var n := int(lane_terminal["combat"][key])
		combat_total += n
		if key.contains("spellsword"):
			combat_spellsword += n
	var funnel := float(combat_spellsword) / float(combat_total) if combat_total > 0 else 0.0
	print("combat-lane [Spellsword] share: %.2f (gate <= %.2f)" % [funnel, FUNNEL_MAX])
	assert(entropy >= ENTROPY_MIN, "path entropy below gate -- the class graph funnels")
	assert(funnel <= FUNNEL_MAX, "[Spellsword] funnel exceeds gate among combat archetypes")

	## Phase 2 -- the OPTIMALITY question (the user's actual fear): at EQUAL
	## PLAYTIME (the last horizon), how much stronger is the optimizer's
	## [Spellsword] than every other archetype's terminal build? Fixed
	## battery, solo, 100 seeds, no equipment (the encounter-cell idiom).
	## MEASURED, not gated -- the verdict is a controller/user read: a wide
	## spellsword margin = real funnel pressure even with diverse tastes.
	print("\n=== equal-playtime power battery (waking %d terminal builds, solo, 100 seeds) ===" % HORIZONS[-1])
	var arenas_by_id := {}
	for a: Dictionary in _load_json("res://data/arenas.json")["arenas"]:
		arenas_by_id[String(a[WIKeys.ID])] = a
	var skills: Dictionary = _load_json("res://data/skills.json")
	var combatants_by_id := {}
	for c: Dictionary in _load_json("res://data/combatants.json")["combatants"]:
		combatants_by_id[String(c[WIKeys.ID])] = c
	var battery := [
		{"name": "raskghar_pair", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"]},
		{"name": "briar_pair", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"]},
	]
	var caster_counters := ["spell_cast", "ice_cast", "fire_cast", "tended_beasts"]
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	for arch: Dictionary in ARCHETYPES:
		var rep: Dictionary = rep_builds.get(String(arch["name"]), {})
		if rep.is_empty() or (rep["classes"] as Dictionary).is_empty():
			continue
		var build_classes: Dictionary = rep["classes"]
		var ai := "melee"
		for counter: String in arch["waking"]:
			if caster_counters.has(counter):
				ai = "caster"
				break
		var line := "  %-24s %-28s ai=%s" % [arch["name"], rep["key"], ai]
		for bat: Dictionary in battery:
			var wins := 0
			for seed_v: int in range(1, 101):
				var pc: Dictionary = (combatants_by_id["pc"] as Dictionary).duplicate(true)
				pc[WIKeys.AI] = ai
				pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build_classes, catalog)
				pc[WIKeys.SKILLS] = WIProgression.granted_skills(build_classes, catalog)
				var cfgs: Array = [pc]
				for enemy_id: String in bat["enemies"]:
					cfgs.append((combatants_by_id[enemy_id] as Dictionary).duplicate(true))
				var combat := WICombat.new(arenas_by_id[String(bat["arena"])], cfgs, skills, sink, seed_v)
				combat.begin()
				var guard := 0
				while not combat.finished and guard < 2000:
					guard += 1
					WICombatAI.take_turn(combat)
				if bool(combat.outcome.get("victory", false)):
					wins += 1
			line += "  %s=%.2f" % [bat["name"], float(wins) / 100.0]
		print(line)
	print("PASS: class-path harness -- %d archetypes measured, diversity gates hold" % ARCHETYPES.size())
	quit(0)


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
		return  # offer sleep resolves nothing else, accept or decline (mirrors sleep()'s early return)
	for outcome: Dictionary in WIProgression.check_evolutions(classes, acc, catalog, generalists):
		if outcome.has("to"):
			classes[String(outcome["to"])] = int(outcome["level"])
			classes.erase(String(outcome["class"]))
		elif bool(outcome.get("generalist", false)):
			if not generalists.has(String(outcome["class"])):
				generalists.append(String(outcome["class"]))


func _class_set_key(classes: Dictionary, generalists: Array) -> String:
	var ids := classes.keys()
	ids.sort()
	var parts: Array = []
	for id: Variant in ids:
		var tag := String(id)
		if generalists.has(tag):
			tag += "*"
		parts.append(tag)
	return "+".join(parts) if not parts.is_empty() else "(classless)"


func _dist_str(dist: Dictionary) -> String:
	var total := 0
	for k: String in dist:
		total += int(dist[k])
	var entries: Array = []
	for k: String in dist:
		entries.append([int(dist[k]), k])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var parts: Array = []
	for e: Array in entries.slice(0, 8):
		parts.append("%s %.0f%%" % [e[1], 100.0 * float(e[0]) / float(total)])
	return ", ".join(parts)


func _entropy_bits(dist: Dictionary) -> float:
	var total := 0
	for k: String in dist:
		total += int(dist[k])
	if total == 0:
		return 0.0
	var h := 0.0
	for k: String in dist:
		var p := float(dist[k]) / float(total)
		if p > 0.0:
			h -= p * (log(p) / log(2.0))
	return h


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())
