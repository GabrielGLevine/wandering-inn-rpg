extends SceneTree
## Report-only accessory experiment. Bypasses acquisition/equip; never a balance gate.

const BATCH = preload("res://tests/sim_combat_batch.gd")
const RUNS := 100
const LOADOUTS := {
	"A": ["hedge_ward_charm", "hunters_fang_talisman"],
	"B": ["hedge_ward_charm", "hunters_fang_talisman", "stonescale_talisman"],
	"C": ["hedge_ward_charm", "hunters_fang_talisman", "phosphor_pendant"],
	"D": ["hedaults_wardstone", "hedaults_hunters_fang", "hedaults_traveler_charm"],
	"E": ["lichbone_wand"],
	"F": ["lichbone_wand", "hunters_fang_talisman"],
	"G": ["lichbone_wand", "hunters_fang_talisman", "hedge_ward_charm"],
}
const CASES := [
	{"group": "INVRISIL_CELLS", "cell": "counting_room_guard_t3_warrior10_solo", "variants": ["control", "A", "B", "E", "F", "G"]},
	{"group": "RUIN_CELLS", "cell": "briar_arch_wards_mage11_solo", "variants": ["control", "A", "B", "C", "D"]},
	{"group": "DUNGEON_CELLS", "cell": "side_vault_construct_t5_infiltrator14_solo", "variants": ["control", "C", "D"]},
	{"group": "ENCOUNTER_CELLS", "cell": "mage3_necromancer3_goblin_ambush_with_skeleton", "variants": ["control", "A", "B"]},
]
const GROUPS := [
	"LOADOUT_CELLS", "ENCOUNTER_CELLS", "BOSS_CELLS", "RUIN_CELLS",
	"RIVERFARM_CELLS", "INVRISIL_CELLS", "PARTY_CELLS", "DUNGEON_CELLS",
	"BESTIARY_CELLS", "SECOND_WIND_CELLS", "SCALED_CELLS",
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _index(rows: Array) -> Dictionary:
	var out := {}
	for row: Dictionary in rows:
		out[String(row["id"])] = row
	return out


func _named(rows: Array, name_value: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row["name"]) == name_value:
			return row.duplicate(true)
	assert(false, "Missing authoritative cell/build: %s" % name_value)
	return {}


func _source_index(constants: Dictionary, name_value: String) -> int:
	var matrix_builds := 0
	for build: Dictionary in BATCH.BUILDS:
		if bool(build.get("matrix", true)):
			matrix_builds += 1
	var offset := BATCH.COMPOSITIONS.size() * matrix_builds
	for group: String in GROUPS:
		for row: Dictionary in constants[group]:
			if String(row["name"]) == name_value:
				return offset
			offset += 1
	assert(false, "Missing authoritative global cell index")
	return -1


func _upper_median(values: Array) -> int:
	var ordered := values.duplicate()
	ordered.sort()
	return int(ordered[ordered.size() >> 1])


func _measure(cell: Dictionary, build: Dictionary, policy_name: String, catalogs: Dictionary) -> Dictionary:
	var wins := 0
	var rounds: Array = []
	var end_hp: Array = []
	var end_mp: Array = []
	var samples: Array = []
	var total_skills := {}
	var max_hp := 0
	var max_mp := 0
	var ally_downed := 0
	var ally_id := String(cell.get("ally", ""))
	assert(not bool(cell.get("companion_boons", false)), "This diagnostic has no companion-boon assembly")
	for seed_value in range(1, RUNS + 1):
		var pc: Dictionary = BATCH._build_pc(build, catalogs["combatants"]["pc"], catalogs["classes"], catalogs["skills_by_id"], catalogs["items"])
		var cfgs: Array = [pc]
		if ally_id != "":
			cfgs.append((catalogs["combatants"][ally_id] as Dictionary).duplicate(true))
		for enemy: String in cell["enemies"]:
			cfgs.append((catalogs["combatants"][enemy] as Dictionary).duplicate(true))
		var resolved := {}
		var sink := func(event_type: String, payload: Dictionary) -> void:
			if event_type == WIEvents.SKILL_RESOLVED and String(payload.get("actor", "")) == "pc":
				var skill_id := String(payload["skill"])
				resolved[skill_id] = int(resolved.get(skill_id, 0)) + 1
		var combat := WICombat.new(catalogs["arenas"][cell["arena"]], cfgs, catalogs["skills"], sink, seed_value)
		combat.difficulty_damage_taken_mult = 1.0
		combat.summon_catalog = catalogs["combatants"]
		var policy := WICombatPolicies.new(policy_name)
		combat.begin()
		max_hp = int(combat.combatants["pc"][WIKeys.MAX_HP])
		max_mp = int(combat.combatants["pc"][WIKeys.MAX_MP])
		var turns := 0
		while not combat.finished and turns < 2000:
			turns += 1
			policy.take_turn(combat)
		assert(combat.finished, "%s seed %d did not terminate" % [cell["name"], seed_value])
		var victory := bool(combat.outcome["victory"])
		wins += int(victory)
		var hp := int(combat.combatants["pc"][WIKeys.HP])
		var mp := int(combat.combatants["pc"][WIKeys.MP])
		var round_count := int(combat.outcome["rounds"])
		rounds.append(round_count)
		end_hp.append(hp)
		end_mp.append(mp)
		if ally_id != "" and not bool(combat.combatants[ally_id][WIKeys.ALIVE]):
			ally_downed += 1
		for skill_id: String in resolved:
			total_skills[skill_id] = int(total_skills.get(skill_id, 0)) + int(resolved[skill_id])
		samples.append({"seed": seed_value, "victory": victory, "rounds": round_count, "pc_end_hp": hp, "pc_end_mp": mp, "pc_skill_resolved": resolved})
	var histogram := {}
	for count: int in rounds:
		histogram[str(count)] = int(histogram.get(str(count), 0)) + 1
	return {
		"wins": wins, "win_rate": float(wins) / RUNS, "median_rounds": _upper_median(rounds),
		"rounds_histogram": histogram, "rounds_min": rounds.min(), "rounds_max": rounds.max(),
		"pc_max_hp": max_hp, "pc_max_mp": max_mp,
		"pc_median_end_hp": _upper_median(end_hp), "pc_median_end_mp": _upper_median(end_mp),
		"pc_skill_resolved_totals": total_skills, "ally_downed": ally_downed,
		"all_wins_risk": wins == RUNS, "samples": samples,
	}


func _init() -> void:
	WITestWatchdog.arm(self)
	var skills := _load("res://data/skills.json")
	var catalogs := {
		"skills": skills, "skills_by_id": _index(skills["skills"]),
		"items": _index(_load("res://data/items.json")["items"]),
		"arenas": _index(_load("res://data/arenas.json")["arenas"]),
		"combatants": _index(_load("res://data/combatants.json")["combatants"]),
		"classes": _load("res://data/classes.json"),
	}
	var hashes := {}
	for path: String in ["res://tests/sim_combat_batch.gd", "res://tests/sim_capacity_570.gd", "res://qa/combat_policies.gd", "res://src/core/combat_build.gd", "res://data/classes.json", "res://data/items.json", "res://data/skills.json", "res://data/arenas.json", "res://data/combatants.json"]:
		hashes[path] = FileAccess.get_sha256(path)
	var report := {
		"engine": Engine.get_version_info(), "runs_per_cell": RUNS, "seed_first": 1, "seed_last": RUNS,
		"difficulty_damage_taken_mult": 1.0, "carried_consumables": [], "preparation": {},
		"entry_resources": "full per current WICombat construction; no carried-resource model",
		"scope": "report-only counterfactual accessories; acquisition, equip and overall balance unproven",
		"source_sha256": hashes, "cells": [],
	}
	var batch_script: GDScript = BATCH
	var constants: Dictionary = batch_script.get_script_constant_map()
	for selection: Dictionary in CASES:
		var cell := _named(constants[selection["group"]], String(selection["cell"]))
		var source_build := _named(BATCH.BUILDS, String(cell["build"]))
		var source_index := _source_index(constants, String(cell["name"]))
		for variant: String in selection["variants"]:
			var build := source_build.duplicate(true)
			if variant != "control":
				# An explicit empty weapon enables the shared accessory fold for the unarmed caster.
				build[WIKeys.WEAPON] = String(source_build.get(WIKeys.WEAPON, ""))
				build["accessories"] = LOADOUTS[variant].duplicate()
			var resonance := 0
			for item_id: String in build.get("accessories", []):
				resonance += int(catalogs["items"][item_id]["resonance"])
			for policy_name: String in [WICombatPolicies.DUMB, WICombatPolicies.COMPETENT]:
				var measurement := _measure(cell, build, policy_name, catalogs)
				measurement.merge({"source_group": selection["group"], "source_index": source_index, "source_cell": cell, "source_build": source_build, "effective_build": build, "variant": variant, "resonance": resonance, "policy": policy_name})
				(report["cells"] as Array).append(measurement)
				var summary := measurement.duplicate()
				summary.erase("samples")
				print("CAPACITY570_CELL ", JSON.stringify(summary))
	var report_path := "user://capacity_570.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
	var output := FileAccess.open(report_path, FileAccess.WRITE)
	assert(output != null, "Cannot write capacity report: %s" % report_path)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("PASS: capacity diagnostic terminated cleanly over %d cells x %d seeds; report-only, not balance acceptance" % [(report["cells"] as Array).size(), RUNS])
	quit(0)
