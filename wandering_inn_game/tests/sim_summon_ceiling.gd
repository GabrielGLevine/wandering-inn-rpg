extends SceneTree
## #460 THE SUMMON-SPAM INVERSION CHECK (spec sec.3.3), preserved.
##
## Every number the archetype's data comments quote is derived HERE, so a reader
## who doubts one can re-run it instead of taking it on trust. That is the whole
## reason this file exists: the tuning that moved `raise_bones` off the spec's
## opening values was originally done with a throwaway probe, and a throwaway
## probe is not evidence.
##
##   Run: godot --headless --path wandering_inn_game --script res://tests/sim_summon_ceiling.gd
##   Fast: WI_CEILING_RUNS=20 ...   (default 100 seeds, as every other matrix)
##
## Named `sim_` and not `test_` deliberately, the `sim_spine_viability.gd`
## contract: `scripts/preflight.sh --full` sweeps `tests/test_*.gd`, and a
## measurement report is not a gate. The GATE for this archetype's window is
## `sim_spine_viability.gd`'s RULED_WINDOWS row `act4_crypt_lich`; this file
## explains the composition that row measures.
##
## WHAT "CEILING" MEANS HERE, and the distinction is the point.
##   SHIPPED      the authored encounter, played out. `raised` reports the mean
##                bodies actually summoned -- when it equals `fight_limit`, the
##                shipped row IS the ceiling row and no synthetic composition is
##                needed to state the guardrail.
##   SIMULTANEOUS the counterfactual: every thrall already standing at round 1
##                AND the summoner's allowance pre-spent, so the board is the
##                fully-raised one without the Lich also holding a fresh
##                allowance. STRICTLY HARSHER than anything reachable (nothing
##                has taken damage yet and the bodies arrived without costing
##                the Lich a turn), so it is an upper bound on how bad the
##                fully-summoned board can be, never a prediction of play.
##
## TRAP, and it cost a wrong number once: an event-sink lambda CANNOT tally into
## a captured local. GDScript lambdas capture by VALUE, so `added += 1` inside
## the sink increments a copy and the probe reports 0.00 raised while the engine
## is summoning correctly. Read `combat.summon_tally` after the fight instead --
## it is the sim's own ledger, so it cannot disagree with the sim.

const RUNS_DEFAULT := 100
const LICH := "crypt_lich"
const THRALL := "bone_thrall"
const RAISE := "raise_bones"

var _runs := RUNS_DEFAULT


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _median(values: Array) -> int:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


## One (composition x policy) cell. `spent` pre-fills the summoner's ledger, so
## a hand-composed board of thralls measures the fully-raised fight rather than
## a fight that fields them AND can still raise a full allowance on top.
func _measure(arena: Dictionary, cfgs: Array, skills: Dictionary, by_id: Dictionary,
		items_by_id: Dictionary, policy_name: String, draughts: Array, spent: int) -> Dictionary:
	var wins := 0
	var rounds: Array = []
	var raised := 0
	for seed_v in range(1, _runs + 1):
		var pol := WICombatPolicies.new(policy_name)
		pol.items_by_id = items_by_id
		pol.driven = {"pc": true}
		pol.carried = {"pc": draughts.duplicate()}
		var copies: Array = []
		for cfg: Dictionary in cfgs:
			copies.append(cfg.duplicate(true))
		var combat := WICombat.new(arena, copies, skills, func(_t: String, _p: Dictionary) -> void: pass, seed_v)
		combat.summon_catalog = by_id
		if spent > 0:
			combat.summon_tally = {LICH: {RAISE: spent}}
		combat.begin()
		var guard := 0
		while not combat.finished and guard < 2000:
			guard += 1
			pol.take_turn(combat)
		assert(combat.finished, "seed %d did not terminate" % seed_v)
		rounds.append(int(combat.outcome["rounds"]))
		# THE SIM'S OWN LEDGER, never a lambda-side counter -- see the file header.
		raised += int((combat.summon_tally.get(LICH, {}) as Dictionary).get(RAISE, 0)) - spent
		if bool(combat.outcome["victory"]):
			wins += 1
	return {
		"win": float(wins) / float(_runs),
		"rounds": _median(rounds),
		"raised": float(raised) / float(_runs),
	}


## In-memory only: the file on disk is never touched, so this can state what the
## SPEC'S OPENING NUMBERS measured without anyone having to revert data to read it.
func _with_summon_knobs(skills: Dictionary, cooldown: int, fight_limit: int) -> Dictionary:
	var out: Dictionary = skills.duplicate(true)
	for sk: Dictionary in out[WIKeys.SKILLS]:
		if String(sk[WIKeys.ID]) == RAISE:
			sk["cooldown_rounds"] = cooldown
			(sk[WIKeys.EFFECT] as Dictionary)["fight_limit"] = fight_limit
	return out


func _authored(skills: Dictionary, key: String) -> int:
	for sk: Dictionary in skills[WIKeys.SKILLS]:
		if String(sk[WIKeys.ID]) == RAISE:
			if key == "cooldown_rounds":
				return int(sk["cooldown_rounds"])
			return int((sk[WIKeys.EFFECT] as Dictionary)[key])
	return 0


func _init() -> void:
	WITestWatchdog.arm(self)
	var runs_env := OS.get_environment("WI_CEILING_RUNS")
	if runs_env != "":
		_runs = maxi(1, int(runs_env))

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

	# The PC is built through the matrix's own builder and the spine's own band
	# row, so this file and the gated `act4_crypt_lich` row measure ONE build.
	var batch: GDScript = preload("res://tests/sim_combat_batch.gd")
	var spine: GDScript = preload("res://tests/sim_spine_viability.gd")
	var build := {}
	for b: Dictionary in spine.BUILDS:
		if String(b["name"]) == "band_act4":
			build = b
	assert(not build.is_empty(), "band_act4 vanished from sim_spine_viability.BUILDS")
	var pc: Dictionary = batch._build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
	pc[WIKeys.HP_MOD] = int(pc.get(WIKeys.HP_MOD, 0)) + int(build.get("hp_mod_bonus", 0))
	var arena: Dictionary = arena_by_id["ruin_court"]
	var draughts: Array = ["mending_draught"]

	var limit := _authored(skills, "fight_limit")
	var cooldown := _authored(skills, "cooldown_rounds")
	print("[ceiling] band_act4 (%s) vs crypt_lich_mouth on ruin_court, %d seeds; authored cooldown %d / fight_limit %d" % [
		String(build["label"]), _runs, cooldown, limit])

	# (a) THE SHIPPED COMPOSITION. `raised` is what decides whether a synthetic
	# ceiling row is owed at all.
	var shipped_cfgs: Array = [pc, (by_id[LICH] as Dictionary).duplicate(true)]
	for policy_name: String in [WICombatPolicies.DUMB, WICombatPolicies.COMPETENT]:
		var m := _measure(arena, shipped_cfgs, skills, by_id, items_by_id, policy_name, draughts, 0)
		print("[ceiling] SHIPPED      %-9s win %.2f / %d rd / %.2f of %d raised" % [
			policy_name, m["win"], m["rounds"], m["raised"], limit])

	# (b) THE SIMULTANEOUS COUNTERFACTUAL, at the authored limit.
	print("[ceiling] SIMULTANEOUS (all thralls standing at round 1, allowance pre-spent):")
	for n in range(1, limit + 1):
		var sim_cfgs: Array = [pc, (by_id[LICH] as Dictionary).duplicate(true)]
		for _i in n:
			sim_cfgs.append((by_id[THRALL] as Dictionary).duplicate(true))
		var s := _measure(arena, sim_cfgs, skills, by_id, items_by_id, WICombatPolicies.COMPETENT, draughts, n)
		print("[ceiling]   %d thrall(s) up  competent win %.2f / %d rd" % [n, s["win"], s["rounds"]])

	# (c) THE PRE-TUNING ROW, in memory only, so the data comments' "we moved off
	# these and here is what they read" is a claim anyone can re-run rather than a
	# story. TWO variants, because the retune moved two different KINDS of thing
	# and a reader is owed the split:
	#   PRE-TUNE    the whole row as first authored -- cooldown 2, fight_limit 3
	#               AND crypt_lich con 26 (46 HP). This is the composition the
	#               skills.json/combatants.json comments quote.
	#   KNOBS ONLY  the same two summon knobs at the SHIPPED con 36, which
	#               isolates what the knobs alone are worth from what the
	#               statline is worth.
	var opening := _with_summon_knobs(skills, 2, 3)
	for variant: Array in [["PRE-TUNE  ", 26], ["KNOBS ONLY", 36]]:
		var lich_cfg: Dictionary = (by_id[LICH] as Dictionary).duplicate(true)
		(lich_cfg[WIKeys.STATS] as Dictionary)["con"] = int(variant[1])
		var v_ship: Array = [pc, lich_cfg]
		var v_ceiling: Array = [pc, lich_cfg.duplicate(true)]
		for _i in 3:
			v_ceiling.append((by_id[THRALL] as Dictionary).duplicate(true))
		var m_ship := _measure(arena, v_ship, opening, by_id, items_by_id, WICombatPolicies.COMPETENT, draughts, 0)
		var m_ceiling := _measure(arena, v_ceiling, opening, by_id, items_by_id, WICombatPolicies.COMPETENT, draughts, 3)
		print("[ceiling] %s (cooldown 2 / fight_limit 3, lich con %d): shipped competent %.2f / %d rd / %.2f of 3 raised; 3-up simultaneous %.2f" % [
			String(variant[0]), int(variant[1]), m_ship["win"], m_ship["rounds"], m_ship["raised"], m_ceiling["win"]])
	print("PASS: summon ceiling report generated")
	quit(0)
