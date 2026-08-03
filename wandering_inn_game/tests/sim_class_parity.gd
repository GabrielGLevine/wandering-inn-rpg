extends SceneTree
## GH#360 (b) -- THE CROSS-CLASS PARITY LEG. Answers, with numbers, the question
## no other harness in this repo can: at the SAME total class level, how far
## apart are the classes?
##
## WHY THIS COULD NOT BE READ OFF sim_combat_batch.gd. That harness asserts a
## per-build win rate against a per-build ROSTER, and its own SECOND_WIND_CELLS
## comment says out loud that each L14 line needed a DIFFERENT roster to sit in
## 0.55-0.95 (swordsman fights three raskghar, sharpshooter fights two sewer
## vermin). Cell-selection tuning is the right tool for "is this fight shaped
## well", and it is exactly the wrong tool for "are these classes equal" -- it
## dissolves the spread it is meant to measure. This harness holds the roster
## fixed and lets the classes fall where they fall.
##
## MIRROR-MATCH CONTRACT (what "same except the class" means here):
##   * Same PC template, same seeds (1..RUNS_PER_CELL), same arena, same roster.
##   * Same armour (leather_jerkin) and NO accessories, on every build.
##   * Same weapon damage_mod -- 0 -- on every build. The weapon FAMILY still
##     varies, because a family is class identity, not gear: a bow line with a
##     sword has no kit at all (`WICombatBuild.weapon_gated_kit` strips it), so
##     forcing one weapon on everyone would measure the harness, not the class.
##   * SOLO. No ally, no companion, in the parity set -- an extra body is the
##     single largest confound in this sim, and the companion lines get their
##     own clearly-labelled context rows instead.
##
## WEAPON_RANGE IS THREADED HERE AND IS NOT IN sim_combat_batch.gd. `wi_game.gd`
## `_build_player_combatant` sets `pc[WEAPON_RANGE] = weapon.range` (bows: 4);
## `sim_combat_batch.gd`'s `_build_pc` does not, so every bow build in THAT file
## silently fights at melee reach. Correct there would move shipped bands, so it
## is logged as a seam rather than changed mid-wave -- but a parity read that
## measured archers with their range removed would be a lie, so this harness
## mirrors the game.
##
## THE BIGGEST CONFOUND, MEASURED RATHER THAN HIDDEN -- `ai_kit`. Autoplay is
## `WICombatAI`, and its profiles can express only a SLICE of any kit: the melee
## profile selects exactly one named skill (`power_strike`) plus a windup, and
## the caster profile selects `line_damage`/`spell_damage`/`heal`/area. Nothing
## in either profile ever fires `sudden_strike`, `power_shot`, `called_shot`,
## `flanking_step` or any other verb, so a rogue/archer/tactician line fights as
## its bare stats no matter how large its kit is. That is a HARNESS property,
## not a class property, and reading these numbers as "class X is weak" without
## it would be wrong -- so every row prints `ai_kit=N/M`: N kit skills the AI can
## actually select, M combat-context skills the class holds. A row with N=0 is
## measuring stat growth and a basic attack, full stop.
## `_ai_expressible` MIRRORS `combat_ai.gd`'s selection arms; update it in the
## same commit that teaches a profile a new verb.
##
## REPORT-ONLY (harness-first, the #211 precedent). The only assertion is
## determinism: every fight terminates. Spread envelopes are proposed from the
## first read and ratified after the numbers are seen.
##
## TOTAL LEVEL vs EFFECTIVE POWER: bands are TOTAL class level (the user's
## question is "Lv10 Mage vs Lv10 Warrior"), and the report prints
## `WIProgression.effective_power` beside it, because they are NOT the same
## number -- a 9/9 two-line build totals 18 and powers 14.1. The multiclass tax
## is a finding, not noise, so the generalist rows are in the parity set.

const RUNS_PER_CELL := 100

## damage_mod 0 in every family (items.json): the mirror-match's whole point.
const WEAPON_SWORD := "rusty_sword"
const WEAPON_SPEAR := "chipped_spear"
const WEAPON_BOW := "training_bow"
const PARITY_ARMOR := "leather_jerkin"

## Fixed per band, never per build. Chosen from SHIPPED rosters and CALIBRATED
## on the first read (2026-08-03): each band carries an easy / medium / hard
## roster so the band has RESOLUTION at both ends. Both saturations destroy the
## measurement -- a roster everyone wins flatters the weak lines to zero spread,
## and a roster everyone loses pins half the table at 0.00 and reports a spread
## that is really just a floor. The first authored band-14/18 sets did the
## latter (8 of 14 parity builds at exactly 0.000) and were re-calibrated down.
const BANDS := [
	{
		"band": 10,
		"rosters": [
			{"name": "sewer_vermin_pair", "arena": "goblin_ambush", "enemies": ["sewer_vermin", "sewer_vermin"]},
			{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
			{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
		],
		"builds": [
			{"name": "warrior10", "classes": {"warrior": 10}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "mage10", "classes": {"mage": 10}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "rogue10", "classes": {"rogue": 10}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "archer10", "classes": {"archer": 10}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "necromancer10", "classes": {"necromancer": 10}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "hedge_witch10", "classes": {"hedge_witch": 10}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "tactician10", "classes": {"tactician": 10}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "ai": "melee", "weapon": WEAPON_SWORD},
			# CONTEXT ROWS (not in the spread). Non-combat lines and the
			# companion reads -- see `parity: false`'s own note in the report.
			{"name": "beast_tamer10", "classes": {"beast_tamer": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "beast_tamer10_wolf", "classes": {"beast_tamer": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "helper10", "classes": {"helper": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "mixer10", "classes": {"mixer": 10}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "classless", "classes": {}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
		],
	},
	{
		"band": 14,
		"rosters": [
			{"name": "raider_vermin", "arena": "goblin_ambush", "enemies": ["goblin_raider", "sewer_vermin"]},
			{"name": "raskghar_pair", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"]},
			{"name": "raskghar_scouts", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"]},
		],
		"builds": [
			{"name": "swordsman14", "classes": {"swordsman": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "spearmaster14", "classes": {"spearmaster": 14}, "ai": "melee", "weapon": WEAPON_SPEAR},
			{"name": "ice_mage14", "classes": {"ice_mage": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "fire_mage14", "classes": {"fire_mage": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "sharpshooter14", "classes": {"sharpshooter": 14}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "infiltrator14", "classes": {"infiltrator": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "witch14", "classes": {"witch": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "strategist14", "classes": {"strategist": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "spellsword14", "classes": {"spellsword": 14}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "ranger14", "classes": {"ranger": 14}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "scout14", "classes": {"scout": 14}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "druid14", "classes": {"druid": 14}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "necromancer12_mage2", "classes": {"necromancer": 12, "mage": 2}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "warrior7_mage7", "classes": {"warrior": 7, "mage": 7}, "ai": "melee", "weapon": WEAPON_SWORD},
			# CONTEXT ROWS
			{"name": "beast_master14", "classes": {"beast_master": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "beast_master14_wolf", "classes": {"beast_master": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "druid14_wolf", "classes": {"druid": 14}, "ai": "caster", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "alchemist14", "classes": {"alchemist": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "innkeeper14", "classes": {"innkeeper": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
			{"name": "courier14", "classes": {"courier": 14}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
		],
	},
	{
		"band": 18,
		"rosters": [
			{"name": "raskghar_scouts", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"]},
			{"name": "briar_collectors", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"]},
			{"name": "forge_golem", "arena": "forge_hall", "enemies": ["forge_golem"]},
		],
		"builds": [
			{"name": "spellsword18", "classes": {"spellsword": 18}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "ranger18", "classes": {"ranger": 18}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "scout18", "classes": {"scout": 18}, "ai": "melee", "weapon": WEAPON_BOW},
			{"name": "druid18", "classes": {"druid": 18}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "ice_mage16_warrior2", "classes": {"ice_mage": 16, "warrior": 2}, "ai": "caster", "weapon": WEAPON_SWORD},
			{"name": "swordsman16_mage2", "classes": {"swordsman": 16, "mage": 2}, "ai": "melee", "weapon": WEAPON_SWORD},
			{"name": "warrior9_mage9", "classes": {"warrior": 9, "mage": 9}, "ai": "melee", "weapon": WEAPON_SWORD},
			# CONTEXT ROWS
			{"name": "druid18_wolf", "classes": {"druid": 18}, "ai": "caster", "weapon": WEAPON_SWORD, "parity": false, "companion": "wolf_companion"},
			{"name": "beast_master16_mage2", "classes": {"beast_master": 16, "mage": 2}, "ai": "melee", "weapon": WEAPON_SWORD, "parity": false},
		],
	},
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Mirrors `wi_game.gd::_build_player_combatant` (NOT sim_combat_batch.gd's
## `_build_pc`, which omits WEAPON_RANGE -- see the head comment).
func _build_pc(build: Dictionary, pc_template: Dictionary, classes_catalog: Dictionary,
		skills_by_id: Dictionary, items_by_id: Dictionary) -> Dictionary:
	var pc: Dictionary = pc_template.duplicate(true)
	pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes_catalog)
	var kit: Array = WIProgression.granted_skills(build["classes"], classes_catalog)
	var weapon: Dictionary = items_by_id.get(String(build[WIKeys.WEAPON]), {})
	var armor: Dictionary = items_by_id.get(PARITY_ARMOR, {})
	pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
	pc[WIKeys.WEAPON_RANGE] = int(weapon.get(WIKeys.RANGE, 1))
	# GH#165 mirror: a fielded companion + the passive folds the PC-side boon in.
	if String(build.get("companion", "")) != "" and (pc[WIKeys.SKILLS] as Array).has("sworn_fang_ride_together"):
		var pcs: Array = (pc[WIKeys.SKILLS] as Array).duplicate()
		pcs.append("sworn_fang_boon")
		pc[WIKeys.SKILLS] = pcs
	var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, [])
	pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
	pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
	pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
	return pc


func _companion_cfg(build: Dictionary, by_id: Dictionary, pc_skills: Array) -> Dictionary:
	var cfg: Dictionary = (by_id[String(build["companion"])] as Dictionary).duplicate(true)
	var boons: Array = []
	if pc_skills.has("animals_basic_command"):
		boons.append("basic_command_boon")
	if pc_skills.has("pack_bond"):
		boons.append("pack_bond_boon")
	if not boons.is_empty():
		var comp_skills: Array = (cfg.get(WIKeys.SKILLS, []) as Array).duplicate()
		comp_skills.append_array(boons)
		cfg[WIKeys.SKILLS] = comp_skills
	return cfg


## MIRROR CONTRACT with `combat_ai.gd`. Returns [expressible, combat_context]:
## how many of this build's skills autoplay can actually SELECT, and how many
## combat-context skills it holds at all. Keep in step with the profiles:
##   melee/skirmisher/guard/coward -> `power_strike` by literal id, plus a
##     `windup_cadence` holder (`_windup_skill_id`).
##   caster/ranged -> the first `line_damage` and the first `spell_damage`,
##     the area arm (`icy_floor`/`blast_damage`), and a `heal`.
## Nothing else in either profile fires a skill, which is why a kit full of
## `damage_mult`/`sneak`/positioning verbs reads as bare stats here.
func _ai_expressible(kit: Array, ai: String, skills_by_id: Dictionary) -> Array:
	var caster := ai == "caster" or ai == "ranged"
	var expressible := {}
	var combat_ctx := 0
	for raw: Variant in kit:
		var sk_id := String(raw)
		var s: Dictionary = skills_by_id.get(sk_id, {})
		if (s.get("contexts", []) as Array).has("combat"):
			combat_ctx += 1
		var effect_type := String((s.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, ""))
		if not caster:
			if sk_id == "power_strike" or s.has("windup_cadence"):
				expressible[sk_id] = true
		else:
			if effect_type in ["line_damage", "spell_damage", "heal", "icy_floor", "blast_damage"]:
				expressible[sk_id] = true
	return [expressible.size(), combat_ctx]


func _total_level(classes: Dictionary) -> int:
	var total := 0
	for held: Variant in classes.values():
		total += int(held)
	return total


func _init() -> void:
	WITestWatchdog.arm(self)
	var arenas_by_id := {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		arenas_by_id[String(a[WIKeys.ID])] = a
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var catalog := _load("res://data/combatants.json")
	var by_id := {}
	for c: Dictionary in catalog["combatants"]:
		by_id[String(c[WIKeys.ID])] = c
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it

	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var total_cells := 0
	var band_spreads: Array = []
	var band_ai_split: Array = []

	print("=".repeat(78))
	print("GH#360 (b) CROSS-CLASS PARITY -- fixed rosters, mirror-matched gear, %d seeded runs/cell" % RUNS_PER_CELL)
	print("gear held constant: armour %s, no accessories, weapon damage_mod 0 in every family" % PARITY_ARMOR)
	print("=".repeat(78))

	for band_cfg: Dictionary in BANDS:
		var band := int(band_cfg["band"])
		var rosters: Array = band_cfg["rosters"]
		var builds: Array = band_cfg["builds"]
		var roster_names: Array = []
		for r: Dictionary in rosters:
			roster_names.append(String(r["name"]))
		print("")
		print("-".repeat(78))
		print("BAND %d  (total class level %d)   rosters: %s" % [band, band, ", ".join(roster_names)])
		print("-".repeat(78))

		var parity_means := {}
		var all_means := {}
		var expressive_means: Array = []
		var mute_means: Array = []
		for build: Dictionary in builds:
			var per_roster: Array = []
			var per_roster_median: Array = []
			for roster: Dictionary in rosters:
				var arena: Dictionary = arenas_by_id[String(roster["arena"])]
				var wins := 0
				var rounds: Array[int] = []
				for seed_v in range(1, RUNS_PER_CELL + 1):
					var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
					var cfgs: Array = [pc]
					if String(build.get("companion", "")) != "":
						cfgs.append(_companion_cfg(build, by_id, pc[WIKeys.SKILLS] as Array))
					for enemy_id: String in roster["enemies"]:
						cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
					var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
					combat.begin()
					var guard := 0
					while not combat.finished and guard < 2000:
						guard += 1
						WICombatAI.take_turn(combat)
					assert(combat.finished, "parity %s/%s/%s fight %d did not terminate" % [
						band, build["name"], roster["name"], seed_v,
					])
					if combat.outcome["victory"]:
						wins += 1
					rounds.append(int(combat.outcome["rounds"]))
				rounds.sort()
				per_roster.append(float(wins) / float(RUNS_PER_CELL))
				per_roster_median.append(rounds[RUNS_PER_CELL / 2])
				total_cells += 1

			var mean := 0.0
			for v: float in per_roster:
				mean += v
			mean /= float(per_roster.size())
			var is_parity := bool(build.get("parity", true))
			var classes_dict: Dictionary = build["classes"]
			var power: float = WIProgression.effective_power(classes_dict, classes)
			all_means[String(build["name"])] = mean
			if is_parity:
				parity_means[String(build["name"])] = mean
			var cells: Array = []
			for i in range(per_roster.size()):
				cells.append("%s %.2f[%d]" % [String((rosters[i] as Dictionary)["name"]), per_roster[i], int(per_roster_median[i])])
			var probe_pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var ai_kit: Array = _ai_expressible(probe_pc[WIKeys.SKILLS] as Array, String(probe_pc[WIKeys.AI]), skills_by_id)
			if is_parity:
				if int(ai_kit[0]) > 0:
					expressive_means.append(mean)
				else:
					mute_means.append(mean)
			print("  %s %-22s lv%2d pow%5.1f ai_kit%2d/%-2d  mean %.3f   %s" % [
				" " if is_parity else "~", String(build["name"]), _total_level(classes_dict), power,
				int(ai_kit[0]), int(ai_kit[1]), mean, "  ".join(cells),
			])

		var lo := 2.0
		var hi := -1.0
		var lo_name := ""
		var hi_name := ""
		for name: String in parity_means:
			var v: float = parity_means[name]
			if v < lo:
				lo = v
				lo_name = name
			if v > hi:
				hi = v
				hi_name = name
		var exp_mean := 0.0
		for v: float in expressive_means:
			exp_mean += v
		exp_mean /= maxf(1.0, float(expressive_means.size()))
		var mute_mean := 0.0
		for v: float in mute_means:
			mute_mean += v
		mute_mean /= maxf(1.0, float(mute_means.size()))
		band_spreads.append([band, hi - lo, lo_name, lo, hi_name, hi, parity_means.size()])
		band_ai_split.append([band, expressive_means.size(), exp_mean, mute_means.size(), mute_mean])
		print("  ---")
		print("  PARITY SPREAD band %d: %.3f  (%s %.3f  ...  %s %.3f) over %d parity builds" % [
			band, hi - lo, lo_name, lo, hi_name, hi, parity_means.size(),
		])
		print("  AI-EXPRESSIBLE SPLIT band %d: ai_kit>0 n=%d mean %.3f   |   ai_kit=0 n=%d mean %.3f" % [
			band, expressive_means.size(), exp_mean, mute_means.size(), mute_mean,
		])
		print("  (rows marked ~ are CONTEXT: non-combat lines, or a fielded companion adding a body")
		print("   no other row has. They are printed, never counted in the spread.)")
		print("  (ai_kit N/M: N skills autoplay can select of M combat-context skills held. N=0")
		print("   means the row measures stat growth + a basic attack, not the class's design.)")

	print("")
	print("=".repeat(78))
	print("RECAP -- max spread per band (this is the number #360 asks to gate)")
	for row: Array in band_spreads:
		print("  band %2d  spread %.3f   floor %s %.3f   ceiling %s %.3f   (n=%d)" % [
			int(row[0]), float(row[1]), String(row[2]), float(row[3]), String(row[4]), float(row[5]), int(row[6]),
		])
	print("")
	print("RECAP -- the confound, quantified: does autoplay speak the class's kit?")
	for row: Array in band_ai_split:
		print("  band %2d  ai_kit>0: n=%d mean %.3f   |   ai_kit=0: n=%d mean %.3f   gap %+.3f" % [
			int(row[0]), int(row[1]), float(row[2]), int(row[3]), float(row[4]), float(row[2]) - float(row[4]),
		])
	print("")
	print("REPORT-ONLY (#360 harness-first). Spread envelopes ratify after this read.")
	print("PASS: class-parity harness terminated cleanly over %d cells x %d seeded runs" % [total_cells, RUNS_PER_CELL])
	quit(0)
