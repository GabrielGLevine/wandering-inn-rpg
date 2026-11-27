extends SceneTree
## #514 THE SPELL-POWER PROBE: the instrument behind the wand values in
## `docs/design/514-gear-rules.md` §8. No harness build wears an implement, so the
## matrix cannot see spell power at all; this reads the caster cells it would
## reach, at spell power 0-3 and with each shipped wand worn, under both
## policies.
##
## It measures through the matrix's own pieces: `sim_combat_batch._build_pc`,
## the cells' own arenas/rosters/allies, and the real `WICombat` driven by
## `WICombatPolicies`. Spell power 0 is the gated cell itself. A wand row adds
## the wand to the build's accessories through `_build_pc`, so its HP, damage
## reduction and spell power all land exactly as the runtime folds them.
##
##   Run:  godot --headless --path wandering_inn_game --script res://tests/_spell_power_probe.gd
##   Fast: WI_PROBE_RUNS=20 ...   (default 100 seeds, as the matrix)
##
## Underscore-prefixed: `scripts/preflight.sh --full` sweeps `tests/test_*.gd`,
## and an instrument is not a gate.

const BATCH := preload("res://tests/sim_combat_batch.gd")
const WANDS := ["graveflame_wand", "lichbone_wand"]
const SPELL_POWERS := [0, 1, 2, 3]

## {family, cell}: the matrix cells whose build casts spells.
const CELLS := [
	["second_wind", "fire_mage14_solo"], ["second_wind", "ice_mage14_solo"],
	["encounter", "mage3_necromancer3_goblin_ambush_solo"], ["encounter", "mage5_necromancer7_raskghar_scouts_solo"],
	["encounter", "mage3_necromancer3_goblin_ambush_with_skeleton"], ["encounter", "mage5_necromancer7_raskghar_scouts_with_skeleton"],
	["encounter", "druid14_raskghar_scouts_with_wolf"],
	["ruin", "briar_arch_wards_mage11_relc"], ["ruin", "briar_arch_wards_mage11_solo"],
	["composition", "goblin_ambush"], ["composition", "chieftains_raid"],
]

var _runs := 100
var _arenas := {}
var _skills := {}
var _skills_by_id := {}
var _classes := {}
var _by_id := {}
var _items_by_id := {}


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _find(list: Array, value: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e["name"]) == value:
			return e
	assert(false, "no cell %s" % value)
	return {}


## The cell as `sim_combat_batch` fields it: {arena, enemies, build, ally, boons}.
func _cell(family: String, name: String) -> Dictionary:
	match family:
		"second_wind":
			var c := _find(BATCH.SECOND_WIND_CELLS, name)
			return {"arena": c["arena"], "enemies": c["enemies"], "build": c["build"], "ally": String(c.get("ally", "")), "boons": bool(c.get("companion_boons", false))}
		"encounter":
			var c := _find(BATCH.ENCOUNTER_CELLS, name)
			var ally := "" if bool(c.get("solo", false)) else String(c.get("ally", "relc"))
			return {"arena": c["arena"], "enemies": c["enemies"], "build": c["build"], "ally": ally, "boons": bool(c.get("companion_boons", false))}
		"ruin":
			var c := _find(BATCH.RUIN_CELLS, name)
			return {"arena": c["arena"], "enemies": c["enemies"], "build": c["build"], "ally": "" if bool(c.get("solo", false)) else "relc", "boons": false}
	var comp := _find(BATCH.COMPOSITIONS, name)
	return {"arena": comp["arena"], "enemies": comp["enemies"], "build": "pure_mage10_caster", "ally": "relc", "boons": false}


func _build(cell: Dictionary, wand: String) -> Dictionary:
	var build: Dictionary = _find(BATCH.BUILDS, String(cell["build"])).duplicate(true)
	if wand != "":
		build[WIKeys.WEAPON] = String(build.get(WIKeys.WEAPON, ""))
		build["armor"] = String(build.get("armor", ""))
		var accessories: Array = (build.get("accessories", []) as Array).duplicate()
		accessories.append(wand)
		build["accessories"] = accessories
	return build


## `pre`: the wand as it shipped before #514 (its spell power read as one point
## of weapon damage instead), so the delta to the shipped column is the ruling's.
## WI_PROBE_<WAND>_SP overrides a wand's spell power to size the lever.
func _measure(cell: Dictionary, policy: WICombatPolicies, spell_power: int, wand: String, pre := false) -> float:
	var wins := 0
	var arena: Dictionary = _arenas[String(cell["arena"])]
	var build := _build(cell, wand)
	var wand_sp := int((_items_by_id.get(wand, {}) as Dictionary).get(WIKeys.SPELL_POWER, 0))
	var override := OS.get_environment("WI_PROBE_%s_SP" % wand.to_upper())
	for seed_v in range(1, _runs + 1):
		var pc: Dictionary = BATCH._build_pc(build, _by_id["pc"], _classes, _skills_by_id, _items_by_id)
		if wand == "":
			pc[WIKeys.SPELL_POWER] = spell_power
		elif pre:
			pc[WIKeys.SPELL_POWER] = int(pc[WIKeys.SPELL_POWER]) - wand_sp
			pc[WIKeys.DAMAGE_MOD] = int(pc[WIKeys.DAMAGE_MOD]) + 1
		elif override != "":
			pc[WIKeys.SPELL_POWER] = int(pc[WIKeys.SPELL_POWER]) - wand_sp + int(override)
		var cfgs: Array = [pc]
		if String(cell["ally"]) != "":
			var ally: Dictionary = (_by_id[String(cell["ally"])] as Dictionary).duplicate(true)
			if bool(cell["boons"]):
				var boons: Array = []
				if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
					boons.append("basic_command_boon")
				if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
					boons.append("pack_bond_boon")
				var ally_skills: Array = (ally.get(WIKeys.SKILLS, []) as Array).duplicate()
				ally_skills.append_array(boons)
				ally[WIKeys.SKILLS] = ally_skills
			cfgs.append(ally)
		for enemy_v: Variant in cell["enemies"]:
			cfgs.append((_by_id[String(enemy_v)] as Dictionary).duplicate(true))
		var combat := WICombat.new(arena, cfgs, _skills, func(_t: String, _p: Dictionary) -> void: pass, seed_v)
		combat.summon_catalog = _by_id
		combat.begin()
		var guard := 0
		while not combat.finished and guard < 2000:
			guard += 1
			policy.take_turn(combat)
		if bool(combat.outcome.get("victory", false)):
			wins += 1
	return float(wins) / float(_runs)


func _init() -> void:
	WITestWatchdog.arm(self)
	if OS.get_environment("WI_PROBE_RUNS") != "":
		_runs = int(OS.get_environment("WI_PROBE_RUNS"))
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		_arenas[String(a[WIKeys.ID])] = a
	_skills = _load("res://data/skills.json")
	for s: Dictionary in _skills[WIKeys.SKILLS]:
		_skills_by_id[String(s[WIKeys.ID])] = s
	_classes = _load("res://data/classes.json")
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		_by_id[String(c[WIKeys.ID])] = c
	for it: Dictionary in _load("res://data/items.json")["items"]:
		_items_by_id[String(it[WIKeys.ID])] = it
	var policies := {"dumb": WICombatPolicies.new(WICombatPolicies.DUMB), "competent": WICombatPolicies.new(WICombatPolicies.COMPETENT)}
	print("| Cell | Policy | sp0 | sp1 | sp2 | sp3 | Graveflame pre | Graveflame | Lichbone pre | Lichbone |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for pair: Array in CELLS:
		var cell := _cell(String(pair[0]), String(pair[1]))
		for policy_name: String in policies:
			var row: Array[String] = []
			for sp: int in SPELL_POWERS:
				row.append("%.2f" % _measure(cell, policies[policy_name], sp, ""))
			for wand: String in WANDS:
				row.append("%.2f" % _measure(cell, policies[policy_name], 0, wand, true))
				row.append("%.2f" % _measure(cell, policies[policy_name], 0, wand))
			print("| %s / %s | %s | %s |" % [pair[0], pair[1], policy_name, " | ".join(row)])
	print("PASS: spell-power probe reported %d cells x %d runs" % [CELLS.size(), _runs])
	quit(0)
