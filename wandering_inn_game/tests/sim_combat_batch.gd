extends SceneTree
## Balance harness: seeded AI-vs-AI runs across a composition x build matrix.
## Compositions: goblin_ambush (raider+shaman, arena goblin_ambush) and
## chieftains_raid (chieftain+raider+spider, arena cave_mouth). Builds: see
## BUILDS below — all granted via WIProgression.granted_skills.
## Allies: relc, in every non-solo cell. 100 seeds per cell (1800 fights).
## Asserts per GATED cell: win_rate 0.55-0.95, median rounds 3-12; measured
## cells are recorded-only (no bounds contract). relc_downed_rate is printed
## for every non-solo cell (WAVE A2 frontier metric, recorded-only).
## LOADOUT_CELLS below adds a measured-only equipment axis
## (weapon/armor from data/items.json, injected the same way wi_game.gd's
## `_build_player_combatant` does) layered onto existing composition+build
## pairings — 5 cells x 100 seeds (500 more fights), never touching the
## gated matrix's construction above.
## The LOADOUT_CELLS loop's weapon-gate filter and
## accessory-mod summation now call `WICombatBuild.weapon_gated_kit`/
## `equipment_mods` (`src/core/combat_build.gd`) -- the SAME functions
## `wi_game.gd`'s `_build_player_combatant` calls -- instead of hand-mirrored
## copies (a manual-sync drift class; keep the shared functions shared).
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
## contribution (the spec §2.4 dual-kit confound).
##
## Additive per-class stat_growth,
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
## The harness builds combatants DIRECTLY from
## combatants.json, bypassing WIGame/`_build_player_combatant` entirely --
## so equipment would be invisible to this harness without this section.
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
	{"name": "warrior2_sword", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": ""},
	{"name": "warrior2_spear", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "relcs_spare_spear", "armor": ""},
	{"name": "warrior2_sword_armored", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior1_tutorial_solo_armored", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior2_mage2_gambeson", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson"},
	## Accessory cells (measured-only, same convention as the
	## 5 weapon/armor cells above). Each cell's optional `accessories` key is
	## a list of `data/items.json` accessory ids whose damage_mod/hp_mod/
	## damage_reduction are SUMMED onto the same three fields alongside the
	## weapon/armor contribution -- a harness-local mirror of `wi_game.gd`'s
	## `_build_player_combatant` loop over `["accessory_1","accessory_2",
	## "accessory_3"]`. A cell omitting `accessories` behaves
	## exactly as before (empty list, zero contribution) -- the 5 cells above
	## are UNTOUCHED in both data and construction.
	## (1) `warrior2_max_legal_kit` / (2) its SOLO tutorial twin: the
	## realistic "chased every accessory legally obtainable at capacity 2"
	## kit -- copper_luck_band (res 0) + hedge_ward_charm (res 1) +
	## hunters_fang_talisman (res 1) = resonance 2, exactly at the shipped
	## capacity, so this is the actual best-case early loadout a real player
	## could equip today.
	## (3) `warrior2_mage2_stonescale_dr2`: stonescale_talisman (dr 1, res 2)
	## stacked with watch_issue_gambeson (dr 1) = dr 2 total, on the
	## chieftains_raid/warrior2_mage2 pairing the `warrior2_mage2_gambeson`
	## cell above already established -- the first dr-2 read in the M7
	## floor>=1 chain.
	## (4) `chieftains_hp_stack`: phosphor_pendant (hp+3) + hedge_ward_charm
	## (hp+2) = hp+5, resonance 1+1=2, on chieftains_raid/warrior2. Carries
	## rusty_sword (0 mods) so `WICombatBuild.weapon_gated_kit` still fields power_strike --
	## an empty weapon string would filter the kit down to untagged-only
	## skills (weapon_family "" only matches untagged), conflating "no
	## weapon equipped" with the accessory hp-stack read this cell wants
	## isolated. No armor, so hp+5 is entirely the accessories' contribution.
	## (5) `moon_bone_solo`: moon_bone_amulet's resonance was lowered so the
	## resonance 3 -> 2 (it was unequippable the moment it was awarded --
	## resonance_capacity never grows past its default 2 anywhere in this
	## codebase). Equal to capacity is legal (`equip()` refuses only
	## STRICTLY over capacity), so this is now a REAL fieldable solo kit, not
	## the capacity-unreachable measured-only curiosity it used to be --
	## renamed from `moon_bone_capacity_unreachable` and the `capacity_unreachable`
	## print-label flag dropped accordingly.
	{"name": "warrior2_max_legal_kit", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior1_tutorial_solo_max_legal_kit", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior2_mage2_stonescale_dr2", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson", "accessories": ["stonescale_talisman"]},
	{"name": "chieftains_hp_stack", "comp": "chieftains_raid", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["phosphor_pendant", "hedge_ward_charm"]},
	{"name": "moon_bone_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["moon_bone_amulet"]},
]

## MEASURED-only cells for the two sewers encounters
## (shield_spider nest + sewer_vermin trash). Self-contained -- each carries
## its own arena/enemies/build (never touching COMPOSITIONS/BUILDS or the
## gated matrix above), so a new content encounter can never redden a balance
## gate. `build` names a BUILDS entry (resolved for its `classes`); `solo`
## drops the ally entirely; an optional per-cell `ally` string (issue #69,
## Klbkch's own alternation) names WHICH combatants.json ally id to field
## when `solo` is false -- defaults to "relc" so every pre-#69 cell's
## construction and print output are byte-identical. warrior2 is the
## representative level a player enters the sewers at. Numbers are recorded
## to the report, not bounded (a nest fight's difficulty is content, not a
## win-rate contract).
const ENCOUNTER_CELLS := [
	## shield_spiders_w2_relc is a legacy MEASURED hypothetical -- the real
	## `shield_spiders` encounter (skeleton_scene.json) never actually fielded
	## Relc (its own `allies` was `[]`); issue #69 wires that entity's real
	## `ally_requires` to Klbkch instead (`shield_spiders_w2_klbkch` below is
	## the cell that now matches live content). Kept for the historical
	## with-Relc read, no longer content-representative.
	{"name": "shield_spiders_w2_relc", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false},
	{"name": "shield_spiders_w2_klbkch", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false, "ally": "klbkch"},
	{"name": "shield_spiders_w2_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": true},
	{"name": "shield_spiders_w1_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "sewer_vermin_w2_solo", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "warrior2", "solo": true},
	## The deep_tunnels Raskghar scout route-fight (bruiser pair,
	## fought in cave_mouth). MEASURED-only -- the scouts are content, not a
	## win-rate contract; deep_descent proves the fight clears via a pinned
	## fixture rng. Recorded with + without Relc so the report shows the
	## solo-difficulty frontier (the deep_descent fixture fields no ally).
	{"name": "raskghar_scouts_w2_relc", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false},
	{"name": "raskghar_scouts_w2_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w5_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior5_mage5", "solo": true},
	## The street "Missing Crate"/"Wrong Order" scavenger encounters
	## (crate_scavengers/supplier_scavengers, skeleton_scene.json -- both 2x
	## goblin_raider on arena goblin_ambush). Issue #69 wired crate_scavengers'
	## real `ally_requires` to Klbkch (`crate_scavengers_w1_klbkch` below
	## matches live content now); supplier_scavengers is untouched, still
	## `allies: []`, never any ally. MEASURED-only, same rationale as the
	## raskghar_scouts route-fight cells above: crate_fight/wrong_order_fight
	## already prove each one clears via its own pinned fixture rng_state (a
	## real content proof); a win-rate CONTRACT would risk CI churn on
	## balance-neutral changes elsewhere for solo/allied warrior1-vs-2-raider
	## street fights without changing anything a player experiences.
	## warrior1_tutorial is the honest representative build for both.
	{"name": "crate_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "crate_scavengers_w1_klbkch", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": false, "ally": "klbkch"},
	{"name": "supplier_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
]

## The Awakened Raskghar BOSS band (spec §2 / plan A2 item 4). Unlike
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

## The ruin encounter axis -- rift_vermin_leak
## (beat-2 inn-cellar leak fight) and ruin_guardian (beat-3 Albez-flavored
## construct guarding the anchor-stone pedestal; D1/D3 wire the real encounter
## entities into skeleton_scene.json separately -- this file only proves the
## combat DATA these locked ids/arena resolve to is in-band). Same per-cell
## win_lo/win_hi gating shape as BOSS_CELLS (a cell without them is
## measured-only, printed with the "(measured)" tag). Every cell uses
## `warrior5_mage5` (10 total levels, split-efficiency ~0.78) as the
## representative "~L8-12 kit" build the plan brief calls out.
## rift_vermin_leak is GATED to the GENERIC 0.55-0.95 band per the plan's
## explicit directive ("gated band 0.55-0.95 at the expected player level
## ~L8-12 kit") -- a trash-swarm leak fight, not a boss, so the generic bound
## applies directly; distinct enemy ids (rift_vermin_a/b/c) avoid the
## same-id WICombat collision documented on those combatants (see
## data/combatants.json). ruin_guardian is adjudicated like deep_descent's
## raskghar_awakened / this file's own BOSS_CELLS: the Relc-escorted cell
## gets an EXPLICIT win_lo/win_hi ("beatable-but-threatening", the recovery
## run is meant to matter, mirrors BOSS_CELLS' 0.6-0.75 shape at a slightly
## easier band since the guardian is "mid-weight", not a capstone boss); the
## solo cell (no ally assumed on the pedestal approach) is measured-only, the
## hard-mode frontier, same convention as awakened_boss_w2_solo.
const RUIN_CELLS := [
	{"name": "rift_vermin_leak_w8_relc", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "rift_vermin_leak_w8_solo", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": true},
	{"name": "ruin_guardian_w8_relc", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.8},
	{"name": "ruin_guardian_w8_solo", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": true},
]

## The Riverfarm encounter axis (briar collectors, both waves, arena
## `witch_hollow`; the night wolf ambush, arena `village_edge_night`). Same
## per-cell win_lo/win_hi gating shape as RUIN_CELLS -- a cell without them is
## measured-only. All four ally-fielded cells use `warrior5_mage5` (the
## representative "~L8-12 kit" build the plan brief calls out, same
## convention as RUIN_CELLS). `briar_collectors`/`briar_collectors_deep`
## are GATED to the generic 0.55-0.95 band (a two-enemy trash/escalation
## pair, not a boss) -- the deep wave carries a slightly tighter explicit
## band (0.55-0.85) reflecting its own `power_strike`-bearing striker on top
## of the shallow wave's plain pair. `river_wolf_pack` is deliberately
## MEASURED-ONLY: it's a NIGHT AMBUSH by design (spec sec.5) -- the point is
## that a 3-wolf pack caught at a bad moment is genuinely dangerous, not that
## it clears the generic win-rate band. No ambush/surprise mechanic exists in
## the sim today (no first-strike/stealth-detection seam for a night spawn to
## hook), so the numbers below are the fight's raw difficulty with no
## mechanical ambush bonus applied -- reported honestly rather than gated to
## a band that would misrepresent what "ambush" currently means here.
## The ally here is `riverfarm_hunter`, NOT `relc` (Riverfarm is a solo Door
## arrival with no fictional basis for Liscor's Watch to be present --
## combatants.json's riverfarm_hunter is an EXACT stat/weapon_die/ai/skills
## clone of relc, so these bands stay numerically valid under the new id).
const RIVERFARM_CELLS := [
	{"name": "briar_collectors_w10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "briar_collectors_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": true},
	{"name": "briar_collectors_deep_w10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.85},
	{"name": "briar_collectors_deep_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": true},
	{"name": "river_wolf_pack_w10_hunter", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "warrior5_mage5", "solo": false},
	{"name": "river_wolf_pack_w10_solo", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "warrior5_mage5", "solo": true},
]

## Invrisil 8c Task C2 (issues #12/#13) axis. The alley footpads
## (shared `mercantile_alley` arena, lane alpha's two encounter placements
## both resolve to this same pair) are SNEAK TARGETS, deliberately tuned
## LOW-lethality (design contract: a player who fails the K2 [Stealth]
## check and gets ambushed must not be walled by the fight) -- gated to an
## EXPLICIT band favoring the floor (0.75-0.98, well above the generic
## 0.55 floor) rather than the generic 0.55-0.95 band, at `warrior2` (the
## same early/low representative build goblin_ambush uses) SOLO -- no ally
## is structurally present when sneaking the alleys alone. A
## `warrior1_tutorial`-tier read is recorded (measured-only) to show even a
## fresh warrior1 isn't walled. `hired_blades` (the LOCKED `merchant_warehouse`
## arena, the first all-human combatant family) is gated 0.6-0.8 with the
## `wilovan` ally at `warrior5_mage5` (the deep_descent/ruin_guardian
## gated-ally-band precedent); the solo cell (the come-along beat declined)
## is measured-only, the hard-mode frontier, same convention as
## awakened_boss_w2_solo/ruin_guardian_w8_solo.
const INVRISIL_CELLS := [
	{"name": "alley_footpads_w2_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior2", "solo": true, "win_lo": 0.75, "win_hi": 0.98},
	{"name": "alley_footpads_w1_tutorial_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior1_tutorial", "solo": true},
	{"name": "hired_blades_w10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.6, "win_hi": 0.8},
	{"name": "hired_blades_w10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": true},
]

const BUILDS := [
	## The TUTORIAL profile: the player's actual first fight (street
	## goblin_encounter_2 -> arena goblin_ambush) is fought at warrior 1 --
	## no counter_strike/battle_momentum yet. M6-playtest directive: the
	## tutorial fight must be winnable on the first attempt, so this cell is
	## measured to keep the matchup visible whenever combat data moves.
	{"name": "warrior1_tutorial", "classes": {"warrior": 1}, "gated": false},
	## The ABOVE cell always fields relc as an
	## ally, but ally_requires{met_relc:1} means a naive player who dashes
	## straight at goblin_encounter_2 WITHOUT first talking to Relc fights this
	## exact matchup SOLO. That's the scenario the playtest flagged as "must
	## survive the opening exchanges" -- measuring it here (never gated; the
	## bar is "not trivially easy, wants Relc's advice", not a win-rate
	## contract) keeps the real risk visible whenever goblin_ambush data moves.
	{"name": "warrior1_tutorial_solo", "classes": {"warrior": 1}, "gated": false, "solo": true},
	## goblin_ambush/warrior2
	## is UN-GATED (per-cell, via `ungated_comps` -- the build stays gated for
	## chieftains_raid). Relc is a high-level [Spearmaster] (canon) escorting
	## the tutorial fight: a near-1.0 win rate on this ALLY-CARRIED cell is
	## CORRECT DESIGN, not a balance failure; the 0.55-0.95 gate is a generic
	## bound predating the mentor-carried-tutorial concept. The design-relevant
	## gates for this fight are now the warrior1_tutorial_solo measured cell
	## (target ~0.4-0.5 win) and relc_downed_rate (target <= ~0.15).
	{"name": "warrior2", "classes": {"warrior": 2}, "ungated_comps": ["goblin_ambush"]},
	## The martial+service hybrid. [Helper] contributes only
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
	{"name": "warrior2_mage2_caster", "classes": {"warrior": 2, "mage": 2}, WIKeys.AI: "caster", "gated": false},
	{"name": "pure_warrior10", "classes": {"warrior": 10}, "gated": false},
	{"name": "pure_mage10_caster", "classes": {"mage": 10}, WIKeys.AI: "caster", "gated": false},
	{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "gated": false},
	{"name": "warrior5_mage5_caster", "classes": {"warrior": 5, "mage": 5}, WIKeys.AI: "caster", "gated": false},
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
	# id-keyed mirrors for the loadout axis only -- the id-keyed
	# form matches wi_game.gd's `skills`/`_items` instance dicts (WICombat's
	# own constructor keys its internal `skills` the same way from the raw
	# array form the main loop below already passes it).
	var skills_by_id := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		skills_by_id[String(s[WIKeys.ID])] = s
	var items_by_id := {}
	for it: Dictionary in _load("res://data/items.json")["items"]:
		items_by_id[String(it[WIKeys.ID])] = it

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
				pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
				# Calls the SAME shared application path as
				# WIGame._build_player_combatant (WIProgression.
				# apply_stat_bonuses) so the harness measures the exact stats a
				# real PC combatant would carry for this class distribution.
				pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
				pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
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
				if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
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

	## Loadout axis. Every cell is measured-only (equipment is a
	## new design axis, not yet subject to the generic 0.55-0.95/3-12 gate --
	## same convention WAVE A2 established for the mentor-carried tutorial
	## cell) -- resolves each cell's named composition/build back to the
	## tables above so classes/ai/solo never drift from the cell they
	## reference, then injects equipment via the SAME shared pure functions
	## `wi_game.gd`'s `_build_player_combatant` calls (`WICombatBuild.
	## weapon_gated_kit`/`equipment_mods`, `src/core/combat_build.gd` --
	## promoted off two hand-mirrored copies) before
	## constructing the SAME WICombat class the main loop above uses.
	for cell: Dictionary in LOADOUT_CELLS:
		var comp: Dictionary = _find_by_name(COMPOSITIONS, String(cell["comp"]))
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		var weapon: Dictionary = items_by_id.get(String(cell[WIKeys.WEAPON]), {})
		var armor: Dictionary = items_by_id.get(String(cell["armor"]), {})
		# Resolve the cell's optional accessory ids ONCE (same
		# lifetime as weapon/armor above) -- a cell with no "accessories" key
		# gets an empty list, matching the pre-G4 5 cells exactly.
		var acc_ids: Array = cell.get("accessories", [])
		var accessories: Array = []
		for acc_id_v: Variant in acc_ids:
			accessories.append(items_by_id.get(String(acc_id_v), {}))
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(build.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			var kit: Array = WIProgression.granted_skills(build["classes"], classes)
			pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
			# Calls the SAME shared function wi_game.gd's
			# `_build_player_combatant` calls -- weapon/armor contribute first,
			# then each equipped accessory's own damage_mod/hp_mod/
			# damage_reduction is SUMMED onto the same three fields (default 0
			# each, same tolerant .get reads); no more hand-mirrored math here.
			var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
			pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
			pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
			pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
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
			if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var acc_str := "(none)" if acc_ids.is_empty() else ", ".join(acc_ids)
		var unreachable_tag := " CAPACITY-UNREACHABLE-TODAY (resonance > shipped capacity, harness bypasses equip())" if bool(cell.get("capacity_unreachable", false)) else ""
		print("[loadout / %s] comp=%s build=%s weapon=%s armor=%s accessories=%s (measured)%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], comp["name"], build["name"],
			String(cell[WIKeys.WEAPON]) if String(cell[WIKeys.WEAPON]) != "" else "(none)",
			String(cell["armor"]) if String(cell["armor"]) != "" else "(none)",
			acc_str, unreachable_tag,
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_relc:
			print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])

	## Sewers encounter axis. Measured-only -- mirrors the main
	## loop's construction (build pc from the named BUILDS entry's classes,
	## an optional ally, enemies) with the cell's own inline arena/enemies.
	## `ally_id` (issue #69) defaults to "relc" so every pre-#69 cell's
	## construction and print label are byte-identical to before.
	for cell: Dictionary in ENCOUNTER_CELLS:
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var ally_downed := 0
		var has_ally := not bool(cell.get("solo", false))
		var ally_id := String(cell.get("ally", "relc"))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_ally:
				cfgs.append((by_id[ally_id] as Dictionary).duplicate(true))
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
			if has_ally and not bool(combat.combatants.get(ally_id, {}).get(WIKeys.ALIVE, true)):
				ally_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		print("[encounter / %s] arena=%s build=%s%s (measured) win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_ally else " solo", win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_ally:
			print("  %s_downed_rate=%.2f (%d/%d)" % [ally_id, float(ally_downed) / float(RUNS_PER_CELL), ally_downed, RUNS_PER_CELL])

	## The Awakened Raskghar boss axis. Same construction as the
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
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
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
			if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
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

	## The ruin axis. Same construction/gating shape as
	## the BOSS_CELLS loop directly above (per-cell win_lo/win_hi, absent means
	## measured-only) -- see RUIN_CELLS' own doc comment for the per-cell band
	## rationale.
	for cell: Dictionary in RUIN_CELLS:
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var relc_downed := 0
		var has_relc := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
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
			assert(combat.finished, "ruin %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_relc and not bool(combat.combatants.get("relc", {}).get(WIKeys.ALIVE, true)):
				relc_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[ruin / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
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
				printerr("FAIL [ruin / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])

	## The Riverfarm axis. Same construction/gating shape as the
	## RUIN_CELLS loop directly above (per-cell win_lo/win_hi, absent means
	## measured-only) -- see RIVERFARM_CELLS' own doc comment for the
	## per-cell band rationale (the wolf pack is deliberately ungated) and
	## for why the ally combatant is `riverfarm_hunter`, not `relc`.
	for cell: Dictionary in RIVERFARM_CELLS:
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var hunter_downed := 0
		var has_hunter := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_hunter:
				cfgs.append((by_id["riverfarm_hunter"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "riverfarm %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_hunter and not bool(combat.combatants.get("riverfarm_hunter", {}).get(WIKeys.ALIVE, true)):
				hunter_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[riverfarm / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_hunter else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_hunter:
			print("  hunter_downed_rate=%.2f (%d/%d)" % [float(hunter_downed) / float(RUNS_PER_CELL), hunter_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [riverfarm / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])

	## The Invrisil axis. Same construction/gating shape as the
	## RIVERFARM_CELLS loop directly above (per-cell win_lo/win_hi, absent
	## means measured-only) -- see INVRISIL_CELLS' own doc comment for the
	## per-cell band rationale (footpads favor the floor; hired_blades mirrors
	## the gated-ally-band precedent) and for why the ally combatant is
	## `wilovan`, not `relc`/`riverfarm_hunter`.
	for cell: Dictionary in INVRISIL_CELLS:
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var wilovan_downed := 0
		var has_wilovan := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_wilovan:
				cfgs.append((by_id["wilovan"] as Dictionary).duplicate(true))
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "invrisil %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))
			if has_wilovan and not bool(combat.combatants.get("wilovan", {}).get(WIKeys.ALIVE, true)):
				wilovan_downed += 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[invrisil / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_wilovan else " solo", "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_wilovan:
			print("  wilovan_downed_rate=%.2f (%d/%d)" % [float(wilovan_downed) / float(RUNS_PER_CELL), wilovan_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [invrisil / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])

	assert(not any_failed, "one or more matrix cells failed bounds — see FAIL lines above")
	if any_failed:
		# Asserts are stripped in release templates; keep the exit code honest there too.
		quit(1)
		return
	print("PASS: balance harness terminated cleanly over %d cells x %d seeded runs" % [COMPOSITIONS.size() * BUILDS.size() + LOADOUT_CELLS.size() + ENCOUNTER_CELLS.size() + BOSS_CELLS.size() + RUIN_CELLS.size() + RIVERFARM_CELLS.size() + INVRISIL_CELLS.size(), RUNS_PER_CELL])
	quit(0)
