extends SceneTree
## #438 THE PER-SPINE KIT PROBE — the instrument behind the [Skirmisher] kit-gap
## diagnosis, and the generalisation of `_warden_probe.gd` off the Act V alcove.
##
## `sim_spine_viability.gd` is the TABLE: every row, every spine, ~2 min a run.
## `_warden_probe.gd` is the Act V INSTRUMENT: the alcove only, every Act V build.
## This is the CELL instrument: ONE (spine x climax) cell of the per-spine table,
## with the kit ablatable and addable and a round-by-round TAPE, so a claim about
## WHY a cell walls is a measurement rather than a reading of the win rate.
##
## It measures through the SAME code the table does — `sim_combat_batch._build_pc`
## for the PC, `sim_spine_viability`'s own SPINE_LEVELS/SPINE_WEAPONS constants and
## its `row_enemies`/`row_allies` statics for the roster, the real `WICombat` driven
## by `WICombatPolicies` — so a probe number and a table number naming the same cell
## ARE the same measurement. Verified: a no-override run reproduces the table's
## per-spine line exactly (see the lane report).
##
##   Run:  godot --headless --path wandering_inn_game --script res://tests/_kit_probe.gd
##   Cell: WI_KIT_SPINE=skirmisher WI_KIT_ROW=act5_seal_warden ...
##         (both default to every derived spine x every climax, which is the
##          whole per-spine table and takes as long as one)
##   A/B:  WI_KIT_ABLATE=a,b ...   # strip PC skills before the fight
##         WI_KIT_ADD=a,b ...      # add PC skills before the fight (weapon-gated
##                                 # exactly as `_build_pc` gates the earned kit,
##                                 # so a mis-gated candidate reads as inert here
##                                 # rather than as a silent buff)
##         WI_KIT_POLICY=dumb ...  # default `competent`, the table's per-spine policy
##         WI_KIT_RUNS=100 ...     # default 100 seeds, as the table
##         WI_KIT_TAPE=3 ...       # ALSO dump the round-by-round tape for that seed
##
## Underscore-prefixed like `_warden_probe.gd` and `_derive_rng_state.gd`:
## `scripts/preflight.sh --full` sweeps `tests/test_*.gd`, and an instrument is not
## a gate.

const SPINE := preload("res://tests/sim_spine_viability.gd")
const BATCH := preload("res://tests/sim_combat_batch.gd")

var _runs := 100
var _tape_seed := 0
var _ablate: Array = []
var _add: Array = []
var _policy := WICombatPolicies.COMPETENT

var _arena_by_id := {}
var _skills := {}
var _skills_by_id := {}
var _classes := {}
var _by_id := {}
var _items_by_id := {}


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _median(values: Array) -> int:
	if values.is_empty():
		return 0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


## `sim_spine_viability._spine_build`, restated (it is not static). Acts I-IV hold
## the target's two PARENT lines at the band allocation; Act V holds the
## consolidated class at 14. That asymmetry is the whole reason this probe exists:
## a class-table edit can only reach the Act V cell.
func _spine_build(spine: Dictionary, act: String) -> Dictionary:
	var act_i := ["I", "II", "III", "IV", "V"].find(act)
	assert(act_i >= 0, "unknown spine act %s" % act)
	var levels: Array = SPINE.SPINE_LEVELS[act]
	var held := {}
	if act == "V":
		held[String(spine["target"])] = int(levels[0])
	else:
		held[String((spine["parents"] as Array)[0])] = int(levels[0])
		if int(levels[1]) > 0:
			held[String((spine["parents"] as Array)[1])] = int(levels[1])
	var parts: Array[String] = []
	for class_id: String in held:
		parts.append("%s%d" % [class_id, held[class_id]])
	return {
		"name": "spine_%s_%s" % [spine["target"], act.to_lower()],
		"classes": held,
		WIKeys.WEAPON: (SPINE.SPINE_WEAPONS[spine["target"]] as Array)[act_i],
		"armor": "" if act == "I" else "leather_jerkin",
		"accessories": [] if act_i < 3 else ["hedge_ward_charm", "hunters_fang_talisman"],
		"label": "/".join(parts),
	}


func _entity(map_id: String, entity_id: String) -> Dictionary:
	for e: Dictionary in _load("res://data/maps/%s.json" % map_id).get("entities", []):
		if String(e.get(WIKeys.ID, "")) == entity_id:
			return e
	assert(false, "no entity %s in map %s" % [entity_id, map_id])
	return {}


func _row(row_id: String) -> Dictionary:
	for r: Dictionary in SPINE.ROSTER:
		if String(r["id"]) == row_id:
			return r
	assert(false, "unknown row %s" % row_id)
	return {}


## `_build_pc` + `sim_spine_viability._spine_cfgs`, with the ablate/add arms folded
## in at the one place the kit is decided. ADD goes through the SAME
## `weapon_gated_kit` the earned kit does, so a spear-gated candidate on a bow row
## reads inert here instead of quietly bypassing the gate the game enforces.
func _cfgs(spine: Dictionary, row: Dictionary, entity: Dictionary, arena: Dictionary) -> Array:
	var build := _spine_build(spine, String(row["act"]))
	var pc: Dictionary = BATCH._build_pc(build, _by_id["pc"], _classes, _skills_by_id, _items_by_id)
	var kit: Array = []
	for sk: Variant in (pc[WIKeys.SKILLS] as Array):
		if not _ablate.has(String(sk)):
			kit.append(String(sk))
	if not _add.is_empty():
		var weapon: Dictionary = _items_by_id.get(String(build[WIKeys.WEAPON]), {})
		for sk: Variant in WICombatBuild.weapon_gated_kit(_add, String(weapon.get("weapon_family", "")), _skills_by_id):
			if not kit.has(String(sk)):
				kit.append(String(sk))
	pc[WIKeys.SKILLS] = kit
	var cfgs: Array = [pc]
	var allies: Array = SPINE.row_allies(row, entity).duplicate()
	var companion := "wolf_companion" if kit.has("lesser_bond") else ""
	if companion != "" and not allies.has(companion) \
			and allies.size() + 2 <= (arena["player_spawns"] as Array).size():
		allies.append(companion)
	if companion != "" and kit.has("sworn_fang_ride_together"):
		kit.append("sworn_fang_boon")
	for ally_v: Variant in allies:
		var ally: Dictionary = (_by_id[String(ally_v)] as Dictionary).duplicate(true)
		var hp_mods: Dictionary = row.get("ally_hp_mods", {})
		if hp_mods.has(String(ally_v)):
			ally[WIKeys.HP_MOD] = int(ally.get(WIKeys.HP_MOD, 0)) + int(hp_mods[String(ally_v)])
		if String(ally_v) == companion:
			var boons: Array = []
			if kit.has("animals_basic_command"):
				boons.append("basic_command_boon")
			if kit.has("pack_bond"):
				boons.append("pack_bond_boon")
			(ally[WIKeys.SKILLS] as Array).append_array(boons)
		cfgs.append(ally)
	var rank := WIProgression.power_rank(build["classes"], _classes) if bool(entity.get("scales", false)) else "bronze"
	for enemy_v: Variant in SPINE.row_enemies(row, entity):
		cfgs.append(WIBountyScaling.scale_enemy((_by_id[String(enemy_v)] as Dictionary).duplicate(true), rank))
	return [build, cfgs]


func _measure(cfgs: Array, arena: Dictionary, draughts: Array) -> Dictionary:
	var wins := 0
	var rounds: Array = []
	var margins: Array = []
	var max_hp := 0
	var max_mp := 0
	for seed_v in range(1, _runs + 1):
		var pol := WICombatPolicies.new(_policy)
		pol.items_by_id = _items_by_id
		pol.driven = {"pc": true}
		var pack: Array = []
		for d: Variant in draughts:
			pack.append(String(d))
		pol.carried = {"pc": pack}
		var run_cfgs: Array = []
		for cfg: Dictionary in cfgs:
			run_cfgs.append(cfg.duplicate(true))
		var combat := WICombat.new(arena, run_cfgs, _skills, func(_t: String, _p: Dictionary) -> void: pass, seed_v)
		# #460: the roster a `summon` Skill reaches for, injected exactly as
		# `sim_spine_viability._measure` and `sim_combat_batch._new_combat` inject
		# it (and as `wi_game.start_combat` does in the live game). Latent for the
		# five climaxes today -- none of them fields a summoner -- but this file's
		# whole contract is that it drives the SAME code the table does, and an
		# unwired catalog would push_error and then silently measure a summoner
		# that never raises anything.
		combat.summon_catalog = _by_id
		combat.begin()
		max_hp = int(combat.combatants["pc"][WIKeys.MAX_HP])
		max_mp = int(combat.combatants["pc"][WIKeys.MAX_MP])
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
		"max_hp": max_hp,
		"max_mp": max_mp,
	}


## THE TAPE. One seed, every combat event that moves HP/AP/MP or spends a Skill,
## printed in resolution order with the round it happened in. This is the read the
## diagnosis quotes: "no defensive action was ever available" and "the AP went to
## two swings" are statements about this list, not about the win rate.
func _tape(cfgs: Array, arena: Dictionary, draughts: Array, seed_v: int) -> void:
	var lines: Array[String] = []
	var round_now := [0]
	var sink := func(type: String, p: Dictionary) -> void:
		match type:
			WIEvents.ROUND_STARTED:
				round_now[0] = int(p["round"])
				lines.append("--- round %d ---" % round_now[0])
			WIEvents.TURN_STARTED:
				lines.append("  r%d %s turn: ap %d move %d" % [round_now[0], p["id"], p["ap"], p["move_pool"]])
			WIEvents.ATTACK_RESOLVED:
				lines.append("  r%d   %s -> %s %s dmg %d (target hp %d)" % [
					round_now[0], p["attacker"], p["target"], "HIT" if p["hit"] else "miss",
					p["damage"], p["target_hp"]])
			WIEvents.SKILL_RESOLVED:
				var extra := ""
				if p.has("hit_ids"):
					extra = " -> %s" % str(p["hit_ids"])
				elif p.has("healed"):
					extra = " healed %d" % int(p["healed"])
				elif p.has("target"):
					extra = " -> %s" % str(p["target"])
				lines.append("  r%d   %s SKILL %s%s" % [round_now[0], p["actor"], p["skill"], extra])
			WIEvents.ACTION_REFUSED:
				lines.append("  r%d   %s REFUSED (%s)" % [round_now[0], p.get("actor", "?"), p.get("reason", "?")])
			WIEvents.STATUS_APPLIED:
				lines.append("  r%d   %s STATUS %s" % [round_now[0], p["id"], p["status"]])
			WIEvents.REACTION_TRIGGERED:
				lines.append("  r%d   %s REACTION %s%s" % [round_now[0], p["id"], p["skill"],
					(" absorbed %d" % int(p["absorbed"])) if p.has("absorbed") else ""])
			WIEvents.COMBATANT_DOWNED:
				lines.append("  r%d   %s DOWNED" % [round_now[0], p["id"]])
			WIEvents.COMBAT_FINISHED:
				lines.append("=== %s in %d rounds" % ["VICTORY" if p["victory"] else "DEFEAT", p["rounds"]])
	var pol := WICombatPolicies.new(_policy)
	pol.items_by_id = _items_by_id
	pol.driven = {"pc": true}
	var pack: Array = []
	for d: Variant in draughts:
		pack.append(String(d))
	pol.carried = {"pc": pack}
	var run_cfgs: Array = []
	for cfg: Dictionary in cfgs:
		run_cfgs.append(cfg.duplicate(true))
	var combat := WICombat.new(arena, run_cfgs, _skills, sink, seed_v)
	combat.summon_catalog = _by_id
	combat.begin()
	var guard := 0
	while not combat.finished and guard < 2000:
		guard += 1
		pol.take_turn(combat)
	print("[tape] seed %d" % seed_v)
	for line: String in lines:
		print("[tape] %s" % line)
	for id: String in combat.combatants:
		var c: Dictionary = combat.combatants[id]
		print("[tape] end %-18s hp %d/%d alive %s" % [id, int(c[WIKeys.HP]), int(c[WIKeys.MAX_HP]), c[WIKeys.ALIVE]])


func _init() -> void:
	WITestWatchdog.arm(self)
	var runs_env := OS.get_environment("WI_KIT_RUNS")
	if runs_env != "":
		_runs = maxi(1, int(runs_env))
	var tape_env := OS.get_environment("WI_KIT_TAPE")
	if tape_env != "":
		_tape_seed = maxi(1, int(tape_env))
	var policy_env := OS.get_environment("WI_KIT_POLICY")
	if policy_env != "":
		assert(policy_env == WICombatPolicies.DUMB or policy_env == WICombatPolicies.COMPETENT,
			"WI_KIT_POLICY must be 'dumb' or 'competent'")
		_policy = policy_env
	for key: String in ["WI_KIT_ABLATE", "WI_KIT_ADD"]:
		var raw := OS.get_environment(key)
		if raw == "":
			continue
		for part: String in raw.split(",", false):
			if key == "WI_KIT_ABLATE":
				_ablate.append(part.strip_edges())
			else:
				_add.append(part.strip_edges())

	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		_arena_by_id[String(a[WIKeys.ID])] = a
	_skills = _load("res://data/skills.json")
	_classes = _load("res://data/classes.json")
	for c: Dictionary in _load("res://data/combatants.json")["combatants"]:
		_by_id[String(c[WIKeys.ID])] = c
	for s: Dictionary in _skills[WIKeys.SKILLS]:
		_skills_by_id[String(s[WIKeys.ID])] = s
	for it: Dictionary in _load("res://data/items.json")["items"]:
		_items_by_id[String(it[WIKeys.ID])] = it

	var spines: Array = []
	var want_spine := OS.get_environment("WI_KIT_SPINE")
	for consolidation: Dictionary in _classes.get("consolidations", []):
		if consolidation.has("_exempt"):
			continue
		var target := String(consolidation["target"])
		if want_spine != "" and target != want_spine:
			continue
		var parent_lines: Array = consolidation["parent_lines"]
		spines.append({
			"target": target,
			"parents": [String((parent_lines[0] as Array)[0]), String((parent_lines[1] as Array)[0])],
		})
	assert(not spines.is_empty(), "no spine matched WI_KIT_SPINE=%s" % want_spine)

	var rows: Array = []
	var want_row := OS.get_environment("WI_KIT_ROW")
	for row_id: String in SPINE.SPINE_CLIMAX_IDS:
		if want_row == "" or row_id == want_row:
			rows.append(row_id)
	assert(not rows.is_empty(), "no climax matched WI_KIT_ROW=%s" % want_row)

	print("[kit] policy=%s runs=%d ablate=%s add=%s" % [_policy, _runs, _ablate, _add])
	for spine: Dictionary in spines:
		for row_id: String in rows:
			var row := _row(row_id)
			var entity := _entity(String(row["map"]), String(row["entity"]))
			var arena: Dictionary = _arena_by_id[String(entity["arena"])]
			var pair := _cfgs(spine, row, entity, arena)
			var build: Dictionary = pair[0]
			var cfgs: Array = pair[1]
			var pc: Dictionary = cfgs[0]
			var m := _measure(cfgs, arena, row["draughts"])
			print("[kit] %-11s %-24s %-22s %s %.2f / %d rd / %+d   (hp %d, mp %d, %s)" % [
				spine["target"], row_id, build["label"],
				"WIN " if m["win_rate"] >= 0.5 else "LOSS", m["win_rate"], m["rounds"], m["margin"],
				m["max_hp"], m["max_mp"], build[WIKeys.WEAPON]])
			var kit: Array = (pc[WIKeys.SKILLS] as Array).duplicate()
			kit.sort()
			print("[kit]   kit: %s" % ", ".join(PackedStringArray(kit)))
			print("[kit]   stats: %s  foes: %d" % [pc[WIKeys.STATS], cfgs.size() - 1])
			if _tape_seed > 0:
				_tape(cfgs, arena, row["draughts"], _tape_seed)
	quit(0)
