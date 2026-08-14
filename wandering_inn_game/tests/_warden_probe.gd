extends SceneTree
## #438 THE WARDEN A/B PROBE — the instrument behind the capstone/Warden rebalance.
##
## `sim_spine_viability.gd` is the TABLE: every row, both policies, ~50s a run.
## This is the INSTRUMENT: the Act V alcove only, every Act V build that reaches
## it, at whatever warden the caller asks for. It exists so a warden lever is
## chosen from an A/B of the SAME cells rather than from a full-table re-run per
## candidate, and so the attribution claims in the lane's report ("the wolf is
## worth X", "int growth is worth Y") carry their own reproducer.
##
## It measures through the SAME code the table does — `sim_combat_batch._build_pc`
## for the PC, `sim_spine_viability`'s own BUILDS/SPINE_WEAPONS constants for the
## loadouts, the real `WICombat` driven by `WICombatPolicies` — so a probe number
## and a table number naming the same cell ARE the same measurement. Verified: the
## no-override run reproduces the table's act5 column exactly (see the lane report).
##
##   Run:  godot --headless --path wandering_inn_game --script res://tests/_warden_probe.gd
##   A/B:  WI_PROBE_WARDEN='{"stats":{"con":130}}' ...     # merged onto seal_warden
##         WI_PROBE_NO_COMPANION=1 ...                     # strip the bonded wolf
##         WI_PROBE_ABLATE=skill_a,skill_b ...             # strip PC skills
##         WI_PROBE_RUNS=100 ...                           # default 100 seeds
##         WI_PROBE_BUILD='{"label":"x","classes":{"warrior":5},"weapon":"relcs_spare_spear"}'
##                                                         # measure an ad-hoc build
##
## `WI_PROBE_BUILD` exists so a QA FIXTURE's build can be read against this fight
## without hand-porting it into `BUILDS`. That is not hypothetical: #438 used it
## to find that `seal_fed_start`/`seal_reward_start` carry roughly half the band
## this climax is authored for (see the lane report).
##
## Underscore-prefixed like `_derive_rng_state.gd`: `preflight.sh --full` sweeps
## `tests/test_*.gd`, and an instrument is not a gate.

const SPINE := preload("res://tests/sim_spine_viability.gd")
const BATCH := preload("res://tests/sim_combat_batch.gd")

const ROW_MAP := "dungeon/trapped_halls"
const ROW_ENTITY := "seal_warden_alcove"

var _runs := 100


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _median(values: Array) -> int:
	if values.is_empty():
		return 0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


func _find_build(name: String) -> Dictionary:
	for b: Dictionary in SPINE.BUILDS:
		if String(b["name"]) == name:
			return b
	assert(false, "unknown build %s" % name)
	return {}


## The Act V leg of `sim_spine_viability._spine_build`, restated for one act so the
## probe can enumerate the nine consolidation spines without running the table.
func _spine_build(target: String) -> Dictionary:
	return {
		"name": "spine_%s_v" % target,
		"classes": {target: 14},
		WIKeys.WEAPON: (SPINE.SPINE_WEAPONS[target] as Array)[4],
		"armor": "leather_jerkin",
		"accessories": ["hedge_ward_charm", "hunters_fang_talisman"],
		"label": "%s14" % target,
	}


func _measure(cfgs: Array, skills: Dictionary, arena: Dictionary, items_by_id: Dictionary, policy: String, ablate: Array) -> Dictionary:
	var wins := 0
	var rounds: Array = []
	var margins: Array = []
	for seed_v in range(1, _runs + 1):
		var pol := WICombatPolicies.new(policy)
		pol.items_by_id = items_by_id
		pol.driven = {"pc": true}
		pol.carried = {"pc": []}
		var run_cfgs: Array = []
		for cfg: Dictionary in cfgs:
			var copy: Dictionary = cfg.duplicate(true)
			if String(copy.get(WIKeys.ID, "")) == "pc" and not ablate.is_empty():
				var kit: Array = []
				for sk: Variant in (copy[WIKeys.SKILLS] as Array):
					if not ablate.has(String(sk)):
						kit.append(String(sk))
				copy[WIKeys.SKILLS] = kit
			run_cfgs.append(copy)
		var combat := WICombat.new(arena, run_cfgs, skills, func(_t: String, _p: Dictionary) -> void: pass, seed_v)
		combat.begin()
		var guard := 0
		while not combat.finished and guard < 2000:
			guard += 1
			pol.take_turn(combat)
		assert(combat.finished, "probe seed %d did not terminate" % seed_v)
		rounds.append(int(combat.outcome["rounds"]))
		if bool(combat.outcome["victory"]):
			wins += 1
			margins.append(int(combat.combatants["pc"][WIKeys.HP]))
		else:
			var standing := 0
			for id: String in combat.combatants:
				var c: Dictionary = combat.combatants[id]
				if String(c[WIKeys.SIDE]) != "player" and bool(c[WIKeys.ALIVE]):
					standing += int(c[WIKeys.HP])
			margins.append(-standing)
	return {
		"win_rate": float(wins) / float(_runs),
		"rounds": _median(rounds),
		"margin": _median(margins),
	}


func _init() -> void:
	WITestWatchdog.arm(self)
	var runs_env := OS.get_environment("WI_PROBE_RUNS")
	if runs_env != "":
		_runs = maxi(1, int(runs_env))
	var no_companion := OS.get_environment("WI_PROBE_NO_COMPANION") != ""
	var ablate: Array = []
	var ablate_env := OS.get_environment("WI_PROBE_ABLATE")
	if ablate_env != "":
		for part: String in ablate_env.split(",", false):
			ablate.append(part.strip_edges())

	var arena_by_id := {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		arena_by_id[String(a[WIKeys.ID])] = a
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var by_id := {}
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it

	# THE A/B ARM. A warden override is merged onto the SHIPPED combatant rather
	# than replacing it, so a probe of "con 130" is the shipped warden in every
	# other respect and the delta is attributable to the one field.
	var warden_env := OS.get_environment("WI_PROBE_WARDEN")
	var override: Dictionary = {}
	if warden_env != "":
		override = JSON.parse_string(warden_env)
		assert(override != null, "WI_PROBE_WARDEN is not valid JSON")
		var warden: Dictionary = by_id["seal_warden"]
		for key: String in override:
			if key == WIKeys.STATS:
				for stat_key: String in (override[key] as Dictionary):
					(warden[WIKeys.STATS] as Dictionary)[stat_key] = (override[key] as Dictionary)[stat_key]
			else:
				warden[key] = override[key]
	print("[probe] warden override: %s | no_companion=%s | ablate=%s | %d seeds" % [
		"none" if override.is_empty() else warden_env, no_companion, ablate, _runs])
	var w: Dictionary = by_id["seal_warden"]
	print("[probe] warden: con %d -> %d max HP (+tough_body), str %d, dex %d, weapon_die %d, skills %s" % [
		int((w[WIKeys.STATS] as Dictionary)["con"]), 20 + int((w[WIKeys.STATS] as Dictionary)["con"]),
		int((w[WIKeys.STATS] as Dictionary)["str"]), int((w[WIKeys.STATS] as Dictionary)["dex"]),
		int(w[WIKeys.WEAPON_DIE]), w[WIKeys.SKILLS]])

	var map_data := _load("res://data/maps/%s.json" % ROW_MAP)
	var entity := {}
	for e: Dictionary in map_data.get("entities", []):
		if String(e.get(WIKeys.ID, "")) == ROW_ENTITY:
			entity = e
	assert(not entity.is_empty(), "no %s entity" % ROW_ENTITY)
	var arena: Dictionary = arena_by_id[String(entity["arena"])]

	# THE CELL LIST. Ship-column rows first (the steel thread's own build and its
	# tactical-depth variants), then the reference band pair, then the nine
	# consolidation spines at level 14 — the same set the table's Act V column
	# carries, in the same order.
	var cells: Array = []
	var build_env := OS.get_environment("WI_PROBE_BUILD")
	if build_env != "":
		var adhoc: Dictionary = JSON.parse_string(build_env)
		assert(adhoc != null, "WI_PROBE_BUILD is not valid JSON")
		for key: String in ["name", "label", "armor"]:
			if not adhoc.has(key):
				adhoc[key] = String(adhoc.get("label", "adhoc"))
		if not adhoc.has("accessories"):
			adhoc["accessories"] = []
		cells.append({"build": adhoc, "kind": "adhoc"})
	for name: String in ["ship_act5", "ship_act5_amulet", "ship_act5_tactician6",
			"ship_act5_tactician12", "ship_act5_strategist16", "band_act5", "band_act5_top"]:
		cells.append({"build": _find_build(name), "kind": "ship"})
	for consolidation: Dictionary in classes.get("consolidations", []):
		if consolidation.has("_exempt"):
			continue
		cells.append({"build": _spine_build(String(consolidation["target"])), "kind": "spine"})

	print("[probe] %-26s %-8s %-8s %s" % ["build", "floor", "competent", "(win / rounds / margin)"])
	for cell: Dictionary in cells:
		var build: Dictionary = cell["build"]
		var pc := BATCH._build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
		pc[WIKeys.HP_MOD] = int(pc.get(WIKeys.HP_MOD, 0)) + int(build.get("hp_mod_bonus", 0))
		var cfgs: Array = [pc]
		# The bonded wolf, on exactly the rule the table uses (`_spine_cfgs`).
		var companion := "wolf_companion" if (pc[WIKeys.SKILLS] as Array).has("lesser_bond") else ""
		if companion != "" and not no_companion and 2 <= (arena["player_spawns"] as Array).size():
			if (pc[WIKeys.SKILLS] as Array).has("sworn_fang_ride_together"):
				(pc[WIKeys.SKILLS] as Array).append("sworn_fang_boon")
			var ally: Dictionary = (by_id[companion] as Dictionary).duplicate(true)
			var boons: Array = []
			if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
				boons.append("basic_command_boon")
			if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
				boons.append("pack_bond_boon")
			(ally[WIKeys.SKILLS] as Array).append_array(boons)
			cfgs.append(ally)
		for enemy_v: Variant in (entity.get("enemies", []) as Array):
			cfgs.append((by_id[String(enemy_v)] as Dictionary).duplicate(true))
		var floor_m := _measure(cfgs, skills, arena, items_by_id, WICombatPolicies.DUMB, ablate)
		var comp_m := _measure(cfgs, skills, arena, items_by_id, WICombatPolicies.COMPETENT, ablate)
		print("[probe] %-26s %.2f %2drd %+4d   %.2f %2drd %+4d   %s%s" % [
			build["label"], floor_m["win_rate"], floor_m["rounds"], floor_m["margin"],
			comp_m["win_rate"], comp_m["rounds"], comp_m["margin"],
			build["name"], "  +wolf" if cfgs.size() > 2 else ""])
	quit(0)
