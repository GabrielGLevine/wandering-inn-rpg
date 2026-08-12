extends SceneTree
## #437 — the sim-only combat policies in `qa/combat_policies.gd`.
##
## Two contracts are worth more than the rest and are tested first:
##   (1) `dumb` IS today's autoplay. Every band in `sim_combat_batch.gd` was
##       authored against `WICombatAI.take_turn`, and those twelve call sites
##       now go through the policy object, so a divergence would silently
##       re-author the whole matrix.
##   (2) `expected_damage` is pinned against the ENGINE, by measurement. It is
##       the one piece of arithmetic the policy keeps locally, so it is the one
##       place that can drift away from `_resolve_hit` unnoticed. The test rolls
##       thousands of real hits and compares means; it never re-derives the
##       formula, because a copied formula proves only that the copy was made.

var _events: Array = []


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _quiet(_t: String, _p: Dictionary) -> void:
	pass


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _resolved(skill_id: String) -> bool:
	for e: Dictionary in _events:
		if String(e["type"]) == "skill_resolved" and String((e["payload"] as Dictionary).get("skill", "")) == skill_id:
			return true
	return false


func _cfgs(all: Dictionary, ids: Array) -> Array:
	var out: Array = []
	for want: String in ids:
		for c: Dictionary in all["combatants"]:
			if String(c[WIKeys.ID]) == want:
				out.append(c.duplicate(true))
	return out


## A whole fight's observable end state, for equivalence and determinism reads.
func _fingerprint(combat: WICombat) -> String:
	var parts: Array = ["v=%s r=%d" % [combat.outcome.get("victory", false), int(combat.outcome.get("rounds", 0))]]
	var ids: Array = combat.combatants.keys()
	ids.sort()
	for id: String in ids:
		var c: Dictionary = combat.combatants[id]
		parts.append("%s:%d/%d@%s,%s" % [id, int(c[WIKeys.HP]), int(c[WIKeys.MAX_HP]), c[WIKeys.CELL], c[WIKeys.ALIVE]])
	return "|".join(parts)


func _init() -> void:
	WITestWatchdog.arm(self)
	var arenas: Array = _load("res://data/arenas.json")["arenas"]
	var arena_by_id := {}
	for a: Dictionary in arenas:
		arena_by_id[String(a[WIKeys.ID])] = a
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var catalog := _load("res://data/combatants.json")
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it
	var goblin_ambush: Dictionary = arena_by_id["goblin_ambush"]
	var cave_mouth: Dictionary = arena_by_id["cave_mouth"]

	# --- 1. `dumb` is byte-compatible with today's autoplay -------------------
	# Two rosters, forty seeds each, whole-fight fingerprints. This is the gate
	# that lets `sim_combat_batch.gd` route through the policy object at all.
	var dumb := WICombatPolicies.new(WICombatPolicies.DUMB)
	var rosters := [
		["pc", "relc", "goblin_raider", "goblin_shaman"],
		["pc", "raskghar_scout", "raskghar_scout"],
	]
	var compared := 0
	for roster: Array in rosters:
		var arena: Dictionary = goblin_ambush if roster.has("goblin_raider") else cave_mouth
		for seed_v in range(1, 41):
			var a_combat := WICombat.new(arena, _cfgs(catalog, roster), skills, _quiet, seed_v)
			a_combat.begin()
			var guard_a := 0
			while not a_combat.finished and guard_a < 2000:
				guard_a += 1
				WICombatAI.take_turn(a_combat)
			var b_combat := WICombat.new(arena, _cfgs(catalog, roster), skills, _quiet, seed_v)
			b_combat.begin()
			var guard_b := 0
			while not b_combat.finished and guard_b < 2000:
				guard_b += 1
				dumb.take_turn(b_combat)
			assert(a_combat.finished and b_combat.finished, "both legs terminate at seed %d" % seed_v)
			assert(_fingerprint(a_combat) == _fingerprint(b_combat),
				"dumb policy diverged from WICombatAI at seed %d:\n  ai=%s\n  policy=%s" % [
					seed_v, _fingerprint(a_combat), _fingerprint(b_combat)])
			compared += 1
	assert(compared == 80, "both rosters ran all forty seeds")

	# The competent policy leaves NON-driven actors on the shipped profile: a
	# competent object whose `driven` set is empty must reproduce the same
	# fingerprint, because at that point every turn falls through to WICombatAI.
	var competent_nobody := WICombatPolicies.new(WICombatPolicies.COMPETENT)
	competent_nobody.driven = {}
	var ref_combat := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "relc", "goblin_raider", "goblin_shaman"]), skills, _quiet, 11)
	ref_combat.begin()
	while not ref_combat.finished:
		WICombatAI.take_turn(ref_combat)
	var nobody_combat := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "relc", "goblin_raider", "goblin_shaman"]), skills, _quiet, 11)
	nobody_combat.begin()
	while not nobody_combat.finished:
		competent_nobody.take_turn(nobody_combat)
	assert(_fingerprint(ref_combat) == _fingerprint(nobody_combat),
		"competent with an empty `driven` set drives nobody -- enemies and allies keep the shipped AI")

	# --- 2. `expected_damage` is pinned against the engine, by measurement ----
	# Roll real `_resolve_hit`s and compare the observed mean HP loss to the
	# helper's prediction. Both a bare target and a damage_reduction target,
	# because DR is subtracted per hit and is exactly what the helper exists to
	# price correctly when it ranks a x2 skill against two ordinary swings.
	for probe: Array in [["goblin_raider", 1.0, true], ["goblin_raider", 2.0, true], ["goblin_raider", 1.0, false], ["rock_crab", 1.0, true], ["rock_crab", 2.0, true]]:
		var target_id := String(probe[0])
		var mult := float(probe[1])
		var melee := bool(probe[2])
		var probe_combat := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", target_id]), skills, _quiet, 5)
		probe_combat.begin()
		var attacker: Dictionary = probe_combat.combatants["pc"]
		attacker[WIKeys.SKILLS] = []
		attacker["hit_bonus"] = 0
		var defender: Dictionary = probe_combat.combatants[target_id]
		defender[WIKeys.MAX_HP] = 4_000_000
		defender[WIKeys.HP] = 4_000_000
		var predicted := WICombatPolicies.expected_damage(probe_combat, attacker, defender, mult, melee)
		var rolls := 4000
		var before := int(defender[WIKeys.HP])
		for _i in rolls:
			probe_combat._resolve_hit("pc", target_id, mult, melee, false)
		var observed := float(before - int(defender[WIKeys.HP])) / float(rolls)
		assert(absf(observed - predicted) <= maxf(0.25, predicted * 0.03),
			"expected_damage(%s mult=%.1f melee=%s) predicted %.3f but the engine measured %.3f over %d rolls" % [
				target_id, mult, melee, predicted, observed, rolls])
		assert(predicted > 0.0, "the probe has to price a real hit")

	# --- 3. SURVIVE: [Second Wind] before anything else ----------------------
	var competent := WICombatPolicies.new(WICombatPolicies.COMPETENT)
	competent.items_by_id = items_by_id
	_events.clear()
	var sw := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "goblin_raider"]), skills, _sink, 3)
	sw.begin()
	var sw_pc: Dictionary = sw.combatants["pc"]
	sw_pc[WIKeys.SKILLS] = ["second_wind", "power_strike"]
	sw_pc[WIKeys.MAX_HP] = 100
	sw_pc[WIKeys.HP] = 20  # 0.20 of max, under the 0.35 threshold
	while sw.get_active() != "pc":
		WICombatAI.take_turn(sw)
	competent.take_turn(sw)
	assert(_resolved("second_wind"), "competent opens a sub-threshold turn with [Second Wind]")
	assert(int(sw.combatants["pc"][WIKeys.HP]) > 20, "the heal landed")
	# ...and exactly once. [Second Wind] has no cooldown and no once_per_fight,
	# so an unlatched policy would heal twice a turn off 4 AP -- optimal play,
	# and off this policy's brief.
	var sw_uses := 0
	for e: Dictionary in _events:
		if String(e["type"]) == "skill_resolved" and String((e["payload"] as Dictionary).get("skill", "")) == "second_wind":
			sw_uses += 1
	assert(sw_uses == 1, "at most one survive action per turn (got %d)" % sw_uses)

	# Above the threshold it does not heal at all -- it fights.
	_events.clear()
	var sw_hi := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "goblin_raider"]), skills, _sink, 3)
	sw_hi.begin()
	var sw_hi_pc: Dictionary = sw_hi.combatants["pc"]
	sw_hi_pc[WIKeys.SKILLS] = ["second_wind"]
	sw_hi_pc[WIKeys.MAX_HP] = 100
	sw_hi_pc[WIKeys.HP] = 60
	while sw_hi.get_active() != "pc":
		WICombatAI.take_turn(sw_hi)
	competent.take_turn(sw_hi)
	assert(not _resolved("second_wind"), "above 35% max HP the competent policy does not spend a heal")

	# --- 4. SURVIVE: carried draughts, through the shipped item path ---------
	_events.clear()
	var dr := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "goblin_raider"]), skills, _sink, 3)
	dr.begin()
	var dr_pc: Dictionary = dr.combatants["pc"]
	dr_pc[WIKeys.SKILLS] = []
	dr_pc[WIKeys.MAX_HP] = 100
	dr_pc[WIKeys.HP] = 20
	competent.carried = {"pc": ["mending_draught", "mending_draught"]}
	while dr.get_active() != "pc":
		WICombatAI.take_turn(dr)
	var hp_before_drink := int(dr_pc[WIKeys.HP])
	competent.take_turn(dr)
	assert(int(dr.combatants["pc"][WIKeys.HP]) == hp_before_drink + 8,
		"the mending draught healed its authored 8 through WIItems.resolve_use")
	assert((competent.carried["pc"] as Array).size() == 1, "drinking consumes exactly one draught from the pack")
	# A pack that runs dry stops mattering: with the last draught gone the
	# policy falls through to fighting rather than refusing the turn.
	competent.carried = {"pc": []}
	_events.clear()
	var dry := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "goblin_raider"]), skills, _sink, 3)
	dry.begin()
	var dry_pc: Dictionary = dry.combatants["pc"]
	dry_pc[WIKeys.SKILLS] = []
	dry_pc[WIKeys.MAX_HP] = 100
	dry_pc[WIKeys.HP] = 20
	while dry.get_active() != "pc":
		WICombatAI.take_turn(dry)
	competent.take_turn(dry)
	assert(dry.finished or dry.get_active() != "pc", "an empty pack still ends the turn cleanly")

	# --- 5. NUKE: the comparison decides, in both directions ------------------
	# Same skill, same geometry, one stat moved. A low-int PC swings; a high-int
	# PC casts. That is the whole of step 2 of the framework.
	competent.carried = {}
	for leg: Array in [[8, false], [40, true]]:
		var int_stat := int(leg[0])
		var wants_cast := bool(leg[1])
		_events.clear()
		var nk := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "goblin_raider"]), skills, _sink, 4)
		nk.begin()
		var nk_pc: Dictionary = nk.combatants["pc"]
		nk_pc[WIKeys.SKILLS] = ["frost_bolt"]
		nk_pc[WIKeys.MP] = 10
		nk_pc[WIKeys.MAX_MP] = 10
		(nk_pc[WIKeys.STATS] as Dictionary)["int"] = int_stat
		# Stand the PC IN CONTACT: the swing and the bolt are both legal from
		# here (frost_bolt's range is 4), so nothing but the two expected-damage
		# numbers can separate them. Out of contact the comparison is vacuous --
		# a basic attack that cannot reach is worth zero and any cast wins.
		nk_pc[WIKeys.CELL] = (nk.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i(1, 0)
		while nk.get_active() != "pc":
			WICombatAI.take_turn(nk)
		competent.take_turn(nk)
		assert(_resolved("frost_bolt") == wants_cast,
			"at int %d the competent policy should%s cast [Frost Bolt]" % [int_stat, "" if wants_cast else " not"])

	# --- 6. ATTACK: lowest-HP reachable, not nearest -------------------------
	_events.clear()
	var tg := WICombat.new(cave_mouth, _cfgs(catalog, ["pc", "raskghar_scout", "raskghar_scout"]), skills, _sink, 6)
	tg.begin()
	var tg_pc: Dictionary = tg.combatants["pc"]
	tg_pc[WIKeys.SKILLS] = []
	var wounded := "raskghar_scout_2"
	tg.combatants[wounded][WIKeys.HP] = 3
	tg_pc[WIKeys.CELL] = (tg.combatants[wounded][WIKeys.CELL] as Vector2i) + Vector2i(-1, 0)
	tg.combatants["raskghar_scout"][WIKeys.CELL] = (tg_pc[WIKeys.CELL] as Vector2i) + Vector2i(0, 1)
	while tg.get_active() != "pc":
		WICombatAI.take_turn(tg)
	competent.take_turn(tg)
	var struck := ""
	for e: Dictionary in _events:
		if String(e["type"]) == "attack_resolved" and String((e["payload"] as Dictionary).get("attacker", "")) == "pc":
			struck = String((e["payload"] as Dictionary).get("target", ""))
			break
	assert(struck == wounded, "with two adjacent foes the competent policy hits the wounded one (hit %s)" % struck)

	# --- 7. POSITION: a reaching weapon steps out of contact -----------------
	var kite := WICombat.new(goblin_ambush, _cfgs(catalog, ["pc", "goblin_raider"]), skills, _quiet, 8)
	kite.begin()
	var kite_pc: Dictionary = kite.combatants["pc"]
	kite_pc[WIKeys.SKILLS] = []
	kite_pc[WIKeys.WEAPON_RANGE] = 3
	kite_pc[WIKeys.CELL] = (kite.combatants["goblin_raider"][WIKeys.CELL] as Vector2i) + Vector2i(-1, 0)
	var kite_foe_cell: Vector2i = kite.combatants["goblin_raider"][WIKeys.CELL]
	while kite.get_active() != "pc":
		WICombatAI.take_turn(kite)
	competent.take_turn(kite)
	var kite_dist := maxi(absi((kite_pc[WIKeys.CELL] as Vector2i - kite_foe_cell).x), absi((kite_pc[WIKeys.CELL] as Vector2i - kite_foe_cell).y))
	assert(kite_dist > 1, "a range-3 weapon backs out of contact rather than trading in melee (ended at %d)" % kite_dist)

	# --- 8. determinism: same seed, same state, same fight -------------------
	var fingerprints: Array = []
	for _repeat in 2:
		var det_policy := WICombatPolicies.new(WICombatPolicies.COMPETENT)
		det_policy.items_by_id = items_by_id
		det_policy.carried = {"pc": ["mending_draught", "mending_draught"]}
		var det := WICombat.new(cave_mouth, _cfgs(catalog, ["pc", "raskghar_scout", "raskghar_scout"]), skills, _quiet, 17)
		det.begin()
		det.combatants["pc"][WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(
			WIProgression.granted_skills({"warrior": 5, "mage": 5}, classes), "sword", skills_by_id)
		det.combatants["pc"][WIKeys.MAX_MP] = 16
		det.combatants["pc"][WIKeys.MP] = 16
		var det_guard := 0
		while not det.finished and det_guard < 2000:
			det_guard += 1
			det_policy.take_turn(det)
		assert(det.finished, "the determinism fight terminates")
		fingerprints.append(_fingerprint(det))
	assert(fingerprints[0] == fingerprints[1],
		"competent is deterministic given (state, rng):\n  %s\n  %s" % [fingerprints[0], fingerprints[1]])

	# --- 9. the policy is strictly not-worse on the fight it was built for ----
	# `gallery_vermin_nest` at the shipped Act V kit is the calibration fight
	# behind this whole issue: hand-winnable, autoplay-losable. Here it is only
	# asserted that the competent leg terminates and does not LOSE ground; the
	# numbers themselves are the viability table's job, not a unit test's.
	var vermin_arena: Dictionary = arena_by_id["trapped_halls_snare"]
	var vermin_build := {"name": "unit_w12_m2", "classes": {"warrior": 12, "mage": 2}, WIKeys.WEAPON: "relcs_spare_spear", "armor": "", "accessories": []}
	var batch := preload("res://tests/sim_combat_batch.gd")
	var by_id := {}
	for c: Dictionary in catalog["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var wins := {WICombatPolicies.DUMB: 0, WICombatPolicies.COMPETENT: 0}
	for policy_name: String in wins:
		for seed_v in range(1, 21):
			var pol := WICombatPolicies.new(policy_name)
			pol.items_by_id = items_by_id
			pol.carried = {"pc": ["mending_draught", "mending_draught"]}
			var cfgs: Array = [batch._build_pc(vermin_build, by_id["pc"], classes, skills_by_id, items_by_id)]
			for enemy_id: String in ["rift_vermin_a", "rift_vermin_c"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var vc := WICombat.new(vermin_arena, cfgs, skills, _quiet, seed_v)
			vc.begin()
			var vguard := 0
			while not vc.finished and vguard < 2000:
				vguard += 1
				pol.take_turn(vc)
			assert(vc.finished, "%s vermin fight %d terminated" % [policy_name, seed_v])
			if bool(vc.outcome["victory"]):
				wins[policy_name] += 1
	assert(wins[WICombatPolicies.COMPETENT] >= wins[WICombatPolicies.DUMB],
		"competent must never be worse than the floor on the same roster (dumb %d, competent %d of 20)" % [
			wins[WICombatPolicies.DUMB], wins[WICombatPolicies.COMPETENT]])

	print("PASS: combat policies -- dumb is autoplay, competent spends the kit, both deterministic")
	quit(0)
