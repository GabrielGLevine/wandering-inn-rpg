extends SceneTree
## Balance harness: seeded AI-vs-AI runs across a composition x build matrix.
## Compositions: goblin_ambush (raider+shaman, arena goblin_ambush) and
## chieftains_raid (chieftain+raider+spider, arena cave_mouth). Builds: see
## BUILDS below — all granted via WIProgression.granted_skills.
## Allies: relc, in every non-solo cell. 100 seeds per cell (1800 fights).
## Asserts per GATED cell: win_rate 0.55-0.95, median rounds 3-12; measured
## cells are recorded-only (no bounds contract). relc_downed_rate is printed
## for every non-solo cell (WAVE A2 frontier metric, recorded-only).
## M7 Task E6: LOADOUT_CELLS below adds a measured-only equipment axis
## (weapon/armor from data/items.json, injected the same way wi_game.gd's
## `_build_player_combatant` does) layered onto existing composition+build
## pairings — 5 cells x 100 seeds (500 more fights), never touching the
## gated matrix's construction above.
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/sim_combat_batch.gd

const RUNS_PER_CELL := 100

const COMPOSITIONS := [
	{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
	{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
]

## `ai` selects the PC's WICombatAI profile (default "melee"). `gated` builds
## assert the win-rate/median bounds; ungated builds are RECORDED-only — a
## measurement axis, not a contract. The caster build exists because the
## melee-profile PC NEVER casts (documented autoplay gotcha), so the mage
## build's whole win-rate edge reads as passive [Mana Shield]; the "caster"
## profile leads with spells then falls through to melee when mana-dry, which
## is the only way this harness measures a mage kit's ACTIVE spell
## contribution (M6 T0 spec §2.4 dual-kit confound).
##
## M6 T4b (spec §2.4 REVISION 2026-07-03): additive per-class stat_growth,
## scaled by the split-efficiency multiplier (kept from T4), ADDED to base
## template stats (see WIProgression.derived_stat_bonuses / apply_stat_bonuses
## / _build_player_combatant). Unlike T4's multiply-only reading, FOCUSED
## builds now also move (they gain the full class stat bonus at efficiency
## 1.0) -- so `warrior2`'s gated win-rate bounds reflect this task's baseline,
## not pre-T4b behavior. `warrior2_mage2` is a split -- under active
## split-efficiency friction its win rate is recorded, not gated, same as its
## caster sibling. The `pure_warrior10`/`pure_mage10_caster`/`warrior5_mage5`/
## `warrior5_mage5_caster` axes are the §2.4 power-axis matrix: a focused
## level-10 build vs. its 5/5 split counterpart, melee and caster profile.
## M7 Task E6 (loadout axis): the harness builds combatants DIRECTLY from
## combatants.json, bypassing WIGame/`_build_player_combatant` entirely (E2
## review finding) -- so equipment was invisible to this harness until now.
## Each cell below layers a weapon/armor pair (data/items.json ids, "" = none
## equipped) onto an EXISTING composition+build pairing (looked up by name
## below, never redefined) and runs its own 100-seed series. Deliberately
## NOT a full cross-product -- 5 design-relevant cells per plan §5:
## (a) the shipped-default control (sword, rusty_sword's mods are 0, should
## match the plain `warrior2`/`goblin_ambush` cell above within noise),
## (b) the spear identity fork (Relc's gift, +1 damage_mod, gates OUT
## power_strike/IN piercing_strikes -- but combat_ai.gd's `_act_melee` only
## ever calls power_strike BY NAME (see inventory_loop's documented finding),
## so this measures the flat damage_mod alone, not a piercing_strikes proc),
## (c) sword + leather_jerkin armored (the inn_chest starter piece),
## (d) the tutorial SOLO bar with the same early armor (does it trivialize
## the "not trivially easy" bar WAVE A/A2 established?),
## (e) the hardest composition's split build with the gambeson's flat
## damage_reduction. ALL measured (no bounds contract) -- the existing gated
## cells above stay gated AND UNCHANGED in construction (no equipment), which
## is what pins the pre-M7 canonical seeds.
const LOADOUT_CELLS := [
	{"name": "warrior2_sword", "comp": "goblin_ambush", "build": "warrior2", "weapon": "rusty_sword", "armor": ""},
	{"name": "warrior2_spear", "comp": "goblin_ambush", "build": "warrior2", "weapon": "relcs_spare_spear", "armor": ""},
	{"name": "warrior2_sword_armored", "comp": "goblin_ambush", "build": "warrior2", "weapon": "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior1_tutorial_solo_armored", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", "weapon": "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior2_mage2_gambeson", "comp": "chieftains_raid", "build": "warrior2_mage2", "weapon": "rusty_sword", "armor": "watch_issue_gambeson"},
]

## Content Wave C1: MEASURED-only cells for the two new sewers encounters
## (shield_spider nest + sewer_vermin trash). Self-contained -- each carries
## its own arena/enemies/build (never touching COMPOSITIONS/BUILDS or the
## gated matrix above), so a new content encounter can never redden a balance
## gate. `build` names a BUILDS entry (resolved for its `classes`); `solo`
## drops Relc. warrior2 is the representative level a player enters the sewers
## at. Numbers are recorded to the report, not bounded (a nest fight's
## difficulty is content, not a win-rate contract).
const ENCOUNTER_CELLS := [
	{"name": "shield_spiders_w2_relc", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false},
	{"name": "shield_spiders_w2_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": true},
	{"name": "shield_spiders_w1_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "sewer_vermin_w2_solo", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "warrior2", "solo": true},
	## M-ARC A2: the deep_tunnels Raskghar scout route-fight (bruiser pair,
	## fought in cave_mouth). MEASURED-only -- the scouts are content, not a
	## win-rate contract; deep_descent proves the fight clears via a pinned
	## fixture rng. Recorded with + without Relc so the report shows the
	## solo-difficulty frontier (the deep_descent fixture fields no ally).
	{"name": "raskghar_scouts_w2_relc", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false},
	{"name": "raskghar_scouts_w2_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w5_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior5_mage5", "solo": true},
]

## M-ARC A2: the Awakened Raskghar BOSS band (spec §2 / plan A2 item 4). Unlike
## every other new-content cell (all measured), the Relc-fielded boss cell is
## GATED to an EXPLICIT 0.6-0.75 win band (per-cell `win_lo`/`win_hi`, NOT the
## generic 0.55-0.95) -- the design contract "beatable-but-threatening with
## Relc". The solo (decline-veto) cell is measured-only (the hard-mode frontier,
## reported honestly, never gated). Boss + 2 scout adds in the deep_warren
## positioning arena. Tune DATA (combatants.json con/die, skills.json maul die/
## ap_cost) to hold the band; escalate if unreachable, never silently re-gate.
const BOSS_CELLS := [
	{"name": "awakened_boss_w2_relc", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false, "win_lo": 0.6, "win_hi": 0.75},
	{"name": "awakened_boss_w2_solo", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
]

const BUILDS := [
	## The TUTORIAL profile: the player's actual first fight (street
	## goblin_encounter_2 -> arena goblin_ambush) is fought at warrior 1 --
	## no counter_strike/battle_momentum yet. M6-playtest directive: the
	## tutorial fight must be winnable on the first attempt, so this cell is
	## measured to keep the matchup visible whenever combat data moves.
	{"name": "warrior1_tutorial", "classes": {"warrior": 1}, "gated": false},
	## Hotfix wave A (playtest 8+9): the ABOVE cell always fields relc as an
	## ally, but ally_requires{met_relc:1} means a naive player who dashes
	## straight at goblin_encounter_2 WITHOUT first talking to Relc fights this
	## exact matchup SOLO. That's the scenario the playtest flagged as "must
	## survive the opening exchanges" -- measuring it here (never gated; the
	## bar is "not trivially easy, wants Relc's advice", not a win-rate
	## contract) keeps the real risk visible whenever goblin_ambush data moves.
	{"name": "warrior1_tutorial_solo", "classes": {"warrior": 1}, "gated": false, "solo": true},
	## WAVE A2 (user directive 2026-07-04, playtest 8+9): goblin_ambush/warrior2
	## is UN-GATED (per-cell, via `ungated_comps` -- the build stays gated for
	## chieftains_raid). Relc is a high-level [Spearmaster] (canon) escorting
	## the tutorial fight: a near-1.0 win rate on this ALLY-CARRIED cell is
	## CORRECT DESIGN, not a balance failure; the 0.55-0.95 gate is a generic
	## bound predating the mentor-carried-tutorial concept. The design-relevant
	## gates for this fight are now the warrior1_tutorial_solo measured cell
	## (target ~0.4-0.5 win) and relc_downed_rate (target <= ~0.15).
	{"name": "warrior2", "classes": {"warrior": 2}, "ungated_comps": ["goblin_ambush"]},
	## Three Pillars P4: the martial+service hybrid. [Helper] contributes only
	## con stat_growth (+1/level) and non-combat/exploration grants ([Basic
	## Cooking] at L1; no combat skill until [Quick Movement] at L5) -- so at
	## helper 2 this build is `warrior2`'s exact combat kit plus +2 con (a
	## little more HP), no fielded combat benefit. MEASURED-only (same
	## convention as warrior2_mage2 and WAVE A2): a service multiclass is a
	## content/identity axis, not a balance contract. Target expectation: tracks
	## `warrior2` closely -- near-1.0 on the Relc-carried goblin_ambush cell,
	## and a hair above bare `warrior2` on chieftains_raid from the extra con.
	{"name": "warrior2_helper2", "classes": {"warrior": 2, "helper": 2}, "gated": false},
	{"name": "warrior2_mage2", "classes": {"warrior": 2, "mage": 2}, "gated": false},
	{"name": "warrior2_mage2_caster", "classes": {"warrior": 2, "mage": 2}, "ai": "caster", "gated": false},
	{"name": "pure_warrior10", "classes": {"warrior": 10}, "gated": false},
	{"name": "pure_mage10_caster", "classes": {"mage": 10}, "ai": "caster", "gated": false},
	{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "gated": false},
	{"name": "warrior5_mage5_caster", "classes": {"warrior": 5, "mage": 5}, "ai": "caster", "gated": false},
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Returns the first entry of `list` whose `key` field equals `value`, or {}.
## Used to resolve a LOADOUT_CELLS cell's "comp"/"build" name back to the
## COMPOSITIONS/BUILDS entry it references, so a loadout cell never redefines
## a composition or build -- only the equipment on top of it.
func _find_by_name(list: Array, value: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e["name"]) == value:
			return e
	return {}


## Harness-local MIRROR of `wi_game.gd`'s `_weapon_gated_kit` (M7 Task E6).
## The harness builds combatants directly from combatants.json and never
## touches WIGame, so it cannot call the real (private, instance-method,
## `self.skills`-reading) function -- this file's task scope also excludes
## wi_game.gd. Semantics kept byte-for-byte identical: a skill carrying
## skills.json's `weapon` key requires an exact family match against the
## equipped weapon; a skill with no `weapon` key (every spell, every
## passive) always passes. `weapon_family` "" (no weapon item, or an
## uncatalogued id) correctly fields untagged skills only. If the shipped
## function's semantics ever change, this copy must be updated by hand.
func _weapon_gated_kit(kit: Array, weapon_family: String, skills_by_id: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in kit:
		var sk_id := String(raw)
		var rec: Dictionary = skills_by_id.get(sk_id, {})
		if not rec.has("weapon") or String(rec["weapon"]) == weapon_family:
			out.append(sk_id)
	return out


func _init() -> void:
	WITestWatchdog.arm(self)
	var arenas_by_id := {}
	for a: Dictionary in _load("res://data/arenas.json")["arenas"]:
		arenas_by_id[String(a["id"])] = a
	var skills := _load("res://data/skills.json")
	var classes := _load("res://data/classes.json")
	var catalog := _load("res://data/combatants.json")
	var by_id := {}
	for c: Dictionary in catalog["combatants"]:
		by_id[String(c["id"])] = c
	# M7 Task E6: id-keyed mirrors for the loadout axis only -- the id-keyed
	# form matches wi_game.gd's `skills`/`_items` instance dicts (WICombat's
	# own constructor keys its internal `skills` the same way from the raw
	# array form the main loop below already passes it).
	var skills_by_id := {}
	for s: Dictionary in skills["skills"]:
		skills_by_id[String(s["id"])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it["id"])] = it

	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var any_failed := false

	for comp: Dictionary in COMPOSITIONS:
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		for build: Dictionary in BUILDS:
			var wins := 0
			var rounds: Array[int] = []
			var relc_downed := 0
			var has_relc := not bool(build.get("solo", false))
			for seed_v in range(1, RUNS_PER_CELL + 1):
				var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
				pc["ai"] = String(build.get("ai", "melee"))
				# Calls the SAME shared application path as
				# WIGame._build_player_combatant (M6 T4b: WIProgression.
				# apply_stat_bonuses) so the harness measures the exact stats a
				# real PC combatant would carry for this class distribution.
				pc["stats"] = WIProgression.apply_stat_bonuses(pc["stats"], build["classes"], classes)
				pc["skills"] = WIProgression.granted_skills(build["classes"], classes)
				var cfgs: Array = [pc]
				if not bool(build.get("solo", false)):
					cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
				for enemy_id: String in comp["enemies"]:
					cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
				var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
				combat.begin()
				var guard := 0
				while not combat.finished and guard < 2000:
					guard += 1
					WICombatAI.take_turn(combat)
				assert(combat.finished, "%s/%s fight %d did not terminate" % [comp["name"], build["name"], seed_v])
				if combat.outcome["victory"]:
					wins += 1
				rounds.append(int(combat.outcome["rounds"]))
				if has_relc and not bool(combat.combatants.get("relc", {}).get("alive", true)):
					relc_downed += 1

			rounds.sort()
			var win_rate := float(wins) / float(RUNS_PER_CELL)
			var median: int = rounds[RUNS_PER_CELL / 2]
			var hist := {}
			for r: int in rounds:
				hist[r] = int(hist.get(r, 0)) + 1
			## Per-cell gating: a build is gated by default; `gated: false` un-gates
			## it everywhere, `ungated_comps` un-gates it for the named
			## compositions only (WAVE A2 -- see the warrior2 build comment).
			var gated := bool(build.get("gated", true)) \
					and not (build.get("ungated_comps", []) as Array).has(String(comp["name"]))
			print("[%s / %s]%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
				comp["name"], build["name"], "" if gated else " (measured)", win_rate, median, rounds[0], rounds[-1],
			])
			print("  rounds histogram: ", hist)
			if has_relc:
				# Hotfix WAVE A2 (playtest 8+9 frontier metric): how often relc goes
				# down mid-fight, invisible to win-rate gates because the pc usually
				# finishes the fight alone. Recorded-only -- no bounds contract.
				print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
			if not gated:
				# Recorded-only measurement axis — no bounds contract yet (T0 §2.4).
				continue
			if win_rate < 0.55 or win_rate > 0.95:
				any_failed = true
				printerr("FAIL [%s / %s]: win rate %.2f outside 0.55-0.95" % [comp["name"], build["name"], win_rate])
			if median < 3 or median > 12:
				any_failed = true
				printerr("FAIL [%s / %s]: median rounds %d outside 3-12" % [comp["name"], build["name"], median])

	## M7 Task E6: loadout axis. Every cell is measured-only (equipment is a
	## new design axis, not yet subject to the generic 0.55-0.95/3-12 gate --
	## same convention WAVE A2 established for the mentor-carried tutorial
	## cell) -- resolves each cell's named composition/build back to the
	## tables above so classes/ai/solo never drift from the cell they
	## reference, then injects equipment exactly like wi_game.gd's
	## `_build_player_combatant` (weapon-gated kit + damage_mod, armor's
	## hp_mod/damage_reduction) before constructing the SAME WICombat class
	## the main loop above uses.
	for cell: Dictionary in LOADOUT_CELLS:
		var comp: Dictionary = _find_by_name(COMPOSITIONS, String(cell["comp"]))
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		var weapon: Dictionary = items_by_id.get(String(cell["weapon"]), {})
		var armor: Dictionary = items_by_id.get(String(cell["armor"]), {})
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(build.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc["ai"] = String(build.get("ai", "melee"))
			pc["stats"] = WIProgression.apply_stat_bonuses(pc["stats"], build["classes"], classes)
			var kit: Array = WIProgression.granted_skills(build["classes"], classes)
			pc["skills"] = _weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
			pc["damage_mod"] = int(weapon.get("damage_mod", 0))
			pc["hp_mod"] = int(armor.get("hp_mod", 0))
			pc["damage_reduction"] = int(armor.get("damage_reduction", 0))
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in comp["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "loadout %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get("alive", true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		print("[loadout / %s] comp=%s build=%s weapon=%s armor=%s (measured) win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], comp["name"], build["name"],
			String(cell["weapon"]) if String(cell["weapon"]) != "" else "(none)",
			String(cell["armor"]) if String(cell["armor"]) != "" else "(none)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])

	## Content Wave C1: sewers encounter axis. Measured-only -- mirrors the main
	## loop's construction (build pc from the named BUILDS entry's classes,
	## optional Relc, enemies) with the cell's own inline arena/enemies.
	for cell: Dictionary in ENCOUNTER_CELLS:
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc["ai"] = String(build.get("ai", "melee"))
			pc["stats"] = WIProgression.apply_stat_bonuses(pc["stats"], build["classes"], classes)
			pc["skills"] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "encounter %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get("alive", true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		print("[encounter / %s] arena=%s build=%s%s (measured) win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_relc else " solo", win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])

	## M-ARC A2: the Awakened Raskghar boss axis. Same construction as the
	## ENCOUNTER loop (build pc from the named BUILDS entry, optional Relc, the
	## boss + scout adds) but with a PER-CELL win band: a cell carrying
	## `win_lo`/`win_hi` is GATED to THAT band (the 0.6-0.75 Relc contract);
	## a cell without them is measured-only (the solo veto frontier). This is the
	## only gate in the file with a non-default band, by design.
	for cell: Dictionary in BOSS_CELLS:
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc["ai"] = String(build.get("ai", "melee"))
			pc["stats"] = WIProgression.apply_stat_bonuses(pc["stats"], build["classes"], classes)
			pc["skills"] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_relc:
				cfgs.append((by_id["relc"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "boss %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get("alive", true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[boss / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_relc else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [boss / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])

	assert(not any_failed, "one or more matrix cells failed bounds — see FAIL lines above")
	if any_failed:
		# Asserts are stripped in release templates; keep the exit code honest there too.
		quit(1)
		return
	print("PASS: balance harness terminated cleanly over %d cells x %d seeded runs" % [COMPOSITIONS.size() * BUILDS.size() + LOADOUT_CELLS.size() + ENCOUNTER_CELLS.size() + BOSS_CELLS.size(), RUNS_PER_CELL])
	quit(0)
