extends SceneTree
## Balance authority: gated cells enforce bands; measured cells only report.
## Region tiers never scale to the player. Shards preserve global cell order
## and per-cell RNG, so their concatenated output must match an unsharded run.

const RUNS_PER_CELL := 100

var _cell_idx := -1
var _range_lo := -1
var _range_hi := -1

func _cell_in_range() -> bool:
	_cell_idx += 1
	if _range_lo < 0:
		return true
	return _cell_idx >= _range_lo and _cell_idx <= _range_hi

const COMPOSITIONS := [
	{"name": "goblin_ambush", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"]},
	{"name": "chieftains_raid", "arena": "cave_mouth", "enemies": ["goblin_chieftain", "goblin_raider", "cave_spider"]},
]

const LOADOUT_CELLS := [
	{"name": "warrior2_sword", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": ""},
	{"name": "warrior2_spear", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "relcs_spare_spear", "armor": ""},
	{"name": "warrior2_sword_armored", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior1_tutorial_solo_armored", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin"},
	{"name": "warrior2_mage2_gambeson", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson"},
	{"name": "warrior2_max_legal_kit", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior1_tutorial_solo_max_legal_kit", "comp": "goblin_ambush", "build": "warrior1_tutorial_solo", WIKeys.WEAPON: "rusty_sword", "armor": "leather_jerkin", "accessories": ["copper_luck_band", "hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "warrior2_mage2_stonescale_dr2", "comp": "chieftains_raid", "build": "warrior2_mage2", WIKeys.WEAPON: "rusty_sword", "armor": "watch_issue_gambeson", "accessories": ["stonescale_talisman"]},
	{"name": "chieftains_hp_stack", "comp": "chieftains_raid", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["phosphor_pendant", "hedge_ward_charm"]},
	{"name": "moon_bone_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["moon_bone_amulet"]},
	{"name": "construct_core_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["construct_core_shard"]},
	{"name": "kingslayer_fang_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["kingslayer_fang"]},
	{"name": "hollow_herb_solo", "comp": "goblin_ambush", "build": "warrior2", WIKeys.WEAPON: "rusty_sword", "armor": "", "accessories": ["hollow_herb_sachet"]},
]

const ENCOUNTER_CELLS := [
	{"name": "shield_spiders_w2_relc", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false},
	{"name": "shield_spiders_w2_klbkch", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": false, "ally": "klbkch"},
	{"name": "shield_spiders_w2_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior2", "solo": true},
	{"name": "shield_spiders_w1_solo", "arena": "sewers_nest", "enemies": ["shield_spider", "shield_spider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "sewer_vermin_w2_solo", "arena": "sewers_nest", "enemies": ["sewer_vermin", "sewer_vermin"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w2_relc", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false},
	{"name": "raskghar_scouts_w2_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
	{"name": "raskghar_scouts_w5_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "warrior5_mage5", "solo": true},
	{"name": "crate_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "crate_scavengers_w1_klbkch", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": false, "ally": "klbkch"},
	{"name": "supplier_scavengers_w1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "warrior1_tutorial", "solo": true},
	{"name": "rock_crab_nest_t1_relc", "arena": "boulder_flats", "enemies": ["rock_crab"], "build": "warrior2", "solo": false, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "rock_crab_nest_t1_solo", "arena": "boulder_flats", "enemies": ["rock_crab"], "build": "warrior2", "solo": true},
	{"name": "goblin_night_patrol_t1_relc", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "warrior2", "solo": false},
	{"name": "goblin_night_patrol_t1_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "warrior2", "solo": true},
	# Necromancer dual-class cells (#131): measured 0.57 / 0.72 at authoring (100 seeds).
	# Builds are matrix:false (dual-class is the in-model shape; solo pure necro is unreachable
	# -- class requires holding [Mage]); "solo" here on the CELL strips Relc, deliberate.
	{"name": "mage3_necromancer3_goblin_ambush_solo", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_shaman"], "build": "mage3_necromancer3_caster", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "mage5_necromancer7_raskghar_scouts_solo", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "mage5_necromancer7_caster", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# Wave-B companion cells (#132): these are the two shipped dual-necromancer
	# builds with an active Raised Skeleton. Both are GATED at 0.55-0.95 wins
	# and 3-12 median rounds. At authoring over 100 seeds they measured 0.62/4
	# and 0.92/3 (win rate/median rounds), after selecting only the encounter
	# composition; combatant stats remained fixed.
	{"name": "mage3_necromancer3_goblin_ambush_with_skeleton", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider", "goblin_shaman"], "build": "mage3_necromancer3_caster", "ally": "skeleton_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "mage5_necromancer7_raskghar_scouts_with_skeleton", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "mage5_necromancer7_caster", "ally": "skeleton_ally", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	# Wave-D-2 companion cells (#156): [Beast Tamer] with the tamed wolf
	# (companion_boons mirrors the roster-inject boon path), [Beast Master]
	# with wolf + [Pack Bond], and a consolidated [Druid] dual-kit build.
	# All GATED 0.55-0.95 / 3-12 rounds; cell-selection-only tuning. Measured
	# at authoring (100 seeds): 0.87/4, 0.90/4, 0.90/4 -- the tamer cell dropped
	# the shaman (0.36 with it: bolts eat the wolf), the druid cell took a third
	# scout (1.00 at two).
	{"name": "beast_tamer5_goblin_ambush_with_wolf", "arena": "goblin_ambush", "enemies": ["goblin_raider", "goblin_raider"], "build": "beast_tamer5_melee", "ally": "wolf_companion", "companion_boons": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "beast_master10_raskghar_scouts_with_wolf", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout"], "build": "beast_master10_melee", "ally": "wolf_companion", "companion_boons": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "druid14_raskghar_scouts_with_wolf", "arena": "cave_mouth", "enemies": ["raskghar_scout", "raskghar_scout", "raskghar_scout"], "build": "druid14_caster", "ally": "wolf_companion", "companion_boons": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
]

const BOSS_CELLS := [
	{"name": "awakened_boss_w2_relc", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": false, "win_lo": 0.6, "win_hi": 0.75},
	{"name": "awakened_boss_w2_solo", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "warrior2", "solo": true},
]

const RUIN_CELLS := [
	{"name": "rift_vermin_leak_w8_relc", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.95},
	{"name": "rift_vermin_leak_w8_solo", "arena": "inn_cellar", "enemies": ["rift_vermin_a", "rift_vermin_b", "rift_vermin_c"], "build": "warrior5_mage5", "solo": true},
	{"name": "ruin_guardian_w8_relc", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": false, "win_lo": 0.55, "win_hi": 0.8},
	{"name": "ruin_guardian_w8_solo", "arena": "ruin_court", "enemies": ["ruin_guardian", "ruin_ward_a", "ruin_ward_b"], "build": "warrior5_mage5", "solo": true},
]

const RIVERFARM_CELLS := [
	{"name": "briar_collectors_w10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "briar_collectors_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "warrior5_mage5", "solo": true},
	{"name": "briar_collectors_t3_spellsword9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "briar_collectors_t3_warrior9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_warrior9", "solo": false},
	{"name": "briar_collectors_t3_warrior10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_a", "briar_collector_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "briar_collectors_deep_w10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "briar_collectors_deep_w10_solo", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "warrior5_mage5", "solo": true},
	{"name": "briar_collectors_deep_t3_spellsword9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "briar_collectors_deep_t3_warrior9_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_warrior9", "solo": false},
	{"name": "briar_collectors_deep_t3_warrior10_hunter", "arena": "witch_hollow", "enemies": ["briar_collector_deep_a", "briar_collector_deep_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.55, "win_hi": 0.85, "check_rounds": true},
	{"name": "river_wolf_pack_t3_hunter", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "t3_warrior10", "solo": false},
	{"name": "river_wolf_pack_t3_solo", "arena": "village_edge_night", "enemies": ["river_wolf_a", "river_wolf_b", "river_wolf_c"], "build": "t3_warrior10", "solo": true},
	{"name": "riverfarm_thicket_patch_t3_solo", "arena": "witch_hollow", "enemies": ["thicket_remnant_a", "thicket_remnant_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95},
]

const INVRISIL_CELLS := [
	{"name": "alley_footpads_w2_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior2", "solo": true, "win_lo": 0.75, "win_hi": 0.98},
	{"name": "alley_footpads_w1_tutorial_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "warrior1_tutorial", "solo": true},
	{"name": "alley_footpads_t3_spellsword9_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_spellsword9", "solo": true},
	{"name": "alley_footpads_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_warrior10", "solo": true},
	{"name": "hired_blades_w10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": false},
	{"name": "hired_blades_w10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "warrior5_mage5", "solo": true},
	{"name": "hired_blades_t3_spellsword9_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_spellsword9", "solo": false},
	{"name": "hired_blades_t3_warrior9_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior9", "solo": false},
	{"name": "hired_blades_t3_warrior10_wilovan", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": false, "win_lo": 0.6, "win_hi": 0.8, "check_rounds": true},
	{"name": "hired_blades_t3_spellsword9_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_spellsword9", "solo": true},
	{"name": "hired_blades_t3_warrior10_solo", "arena": "merchant_warehouse", "enemies": ["hired_blade_leader", "hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": true},
	{"name": "boulevard_night_footpads_t3_spellsword9_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_spellsword9", "solo": true},
	{"name": "boulevard_night_footpads_t3_warrior10_solo", "arena": "mercantile_alley", "enemies": ["footpad_lookout", "footpad_bruiser"], "build": "t3_warrior10", "solo": true},
	{"name": "boulevard_duel_ring_t3_solo", "arena": "mercantile_alley", "enemies": ["hired_blade_knife_a", "hired_blade_knife_b"], "build": "t3_warrior10", "solo": true, "win_lo": 0.55, "win_hi": 0.95},
]

const BUILDS := [
	{"name": "warrior1_tutorial", "classes": {"warrior": 1}, "gated": false},
	{"name": "warrior1_tutorial_solo", "classes": {"warrior": 1}, "gated": false, "solo": true},
	{"name": "classless_solo", "classes": {}, "gated": false, "solo": true},
	{"name": "warrior2", "classes": {"warrior": 2}, "ungated_comps": ["goblin_ambush"]},
	{"name": "warrior2_helper2", "classes": {"warrior": 2, "helper": 2}, "gated": false},
	{"name": "warrior2_mage2", "classes": {"warrior": 2, "mage": 2}, "gated": false},
	{"name": "warrior2_mage2_caster", "classes": {"warrior": 2, "mage": 2}, WIKeys.AI: "caster", "gated": false},
	{"name": "pure_warrior10", "classes": {"warrior": 10}, "gated": false},
	{"name": "pure_mage10_caster", "classes": {"mage": 10}, WIKeys.AI: "caster", "gated": false},
	{"name": "mage3_necromancer3_caster", "classes": {"mage": 3, "necromancer": 3}, WIKeys.AI: "caster", "matrix": false},
	{"name": "beast_tamer5_melee", "classes": {"beast_tamer": 5}, WIKeys.AI: "melee", "matrix": false},
	{"name": "beast_master10_melee", "classes": {"beast_master": 10}, WIKeys.AI: "melee", "matrix": false},
	{"name": "druid14_caster", "classes": {"druid": 14}, WIKeys.AI: "caster", "matrix": false},
	{"name": "mage5_necromancer7_caster", "classes": {"mage": 5, "necromancer": 7}, WIKeys.AI: "caster", "matrix": false},
	{"name": "warrior5_mage5", "classes": {"warrior": 5, "mage": 5}, "gated": false},
	{"name": "warrior5_mage5_caster", "classes": {"warrior": 5, "mage": 5}, WIKeys.AI: "caster", "gated": false},
	{"name": "t3_spellsword9", "classes": {"spellsword": 9}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t3_warrior9", "classes": {"warrior": 9}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t3_warrior10", "classes": {"warrior": 10}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t4_spellsword11_party", "classes": {"spellsword": 11}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
	{"name": "t4_spellsword14_party", "classes": {"spellsword": 14}, "gated": false, WIKeys.WEAPON: "gnollish_hunting_knife", "armor": "leather_jerkin", "accessories": ["hedge_ward_charm", "hunters_fang_talisman"]},
]

const PARTY_CELLS := [
	{"name": "vault_construct_t4_party", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword11_party", "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "vault_construct_t4_party_guided", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword11_party", "ally_hp_mods": {"ksmvr": -18}},
	{"name": "raskghar_awakened_t4_party", "arena": "deep_warren", "enemies": ["raskghar_awakened", "raskghar_scout", "raskghar_scout"], "build": "t4_spellsword11_party"},
	{"name": "vault_construct_t4_spellsword14_party", "arena": "vault", "enemies": ["vault_construct"], "build": "t4_spellsword14_party"},
]

const DUNGEON_CELLS := [
	{"name": "trapped_halls_snare_t4_solo", "arena": "trapped_halls_snare", "enemies": ["snare_ward_a", "snare_ward_b", "rift_vermin_c"], "build": "t4_spellsword11_party", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
	{"name": "gallery_vermin_nest_t4_solo", "arena": "trapped_halls_snare", "enemies": ["rift_vermin_a", "rift_vermin_c"], "build": "t4_spellsword11_party", "solo": true, "win_lo": 0.55, "win_hi": 0.95, "check_rounds": true},
]

const BESTIARY_CELLS := [
	{"name": "corusdeer_range_t1_solo", "arena": "boulder_flats", "enemies": ["corusdeer"], "build": "warrior2", "solo": true},
	{"name": "razorbeak_nest_t1_solo", "arena": "boulder_flats", "enemies": ["razorbeak_a", "razorbeak_b"], "build": "warrior2", "solo": true},
	{"name": "boulevard_mothbears_t3_solo", "arena": "mercantile_alley", "enemies": ["mothbear_a", "mothbear_b"], "build": "t3_warrior10", "solo": true},
	{"name": "kingslayer_den_t4_solo", "arena": "spider_den", "enemies": ["kingslayer_spider"], "build": "t4_spellsword11_party", "solo": true},
	{"name": "forge_calibration_golem_t4_solo", "arena": "forge_hall", "enemies": ["forge_golem"], "build": "t4_spellsword11_party", "solo": true},
	{"name": "forge_calibration_golem_t5_sw14_solo", "arena": "forge_hall", "enemies": ["forge_golem"], "build": "t4_spellsword14_party", "solo": true},
	{"name": "market_watchgolems_t4_solo", "arena": "market_watch", "enemies": ["watchgolem_a", "watchgolem_b"], "build": "t4_spellsword11_party", "solo": true},
	{"name": "market_watchgolems_t5_sw14_solo", "arena": "market_watch", "enemies": ["watchgolem_a", "watchgolem_b"], "build": "t4_spellsword14_party", "solo": true},
]


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _find_by_name(list: Array, value: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e["name"]) == value:
			return e
	return {}


func _matrix_build_count() -> int:
	var count := 0
	for build: Dictionary in BUILDS:
		if bool(build.get("matrix", true)):
			count += 1
	return count


func _build_pc(build: Dictionary, pc_template: Dictionary, classes_catalog: Dictionary, skills_by_id: Dictionary, items_by_id: Dictionary) -> Dictionary:
	var pc: Dictionary = pc_template.duplicate(true)
	pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
	pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes_catalog)
	var kit: Array = WIProgression.granted_skills(build["classes"], classes_catalog)
	if build.has(WIKeys.WEAPON):
		var weapon: Dictionary = items_by_id.get(String(build[WIKeys.WEAPON]), {})
		var armor: Dictionary = items_by_id.get(String(build.get("armor", "")), {})
		var accessories: Array = []
		for acc_id_v: Variant in (build.get("accessories", []) as Array):
			accessories.append(items_by_id.get(String(acc_id_v), {}))
		pc[WIKeys.SKILLS] = WICombatBuild.weapon_gated_kit(kit, String(weapon.get("weapon_family", "")), skills_by_id)
		pc[WIKeys.SKILLS] = WICombatBuild.fold_abilities(pc[WIKeys.SKILLS] as Array, accessories)
		var mods: Dictionary = WICombatBuild.equipment_mods(weapon, armor, accessories)
		pc[WIKeys.DAMAGE_MOD] = mods[WIKeys.DAMAGE_MOD]
		pc[WIKeys.HP_MOD] = mods[WIKeys.HP_MOD]
		pc[WIKeys.DAMAGE_REDUCTION] = mods[WIKeys.DAMAGE_REDUCTION]
	else:
		pc[WIKeys.SKILLS] = kit
	return pc


func _init() -> void:
	var total_cells := COMPOSITIONS.size() * _matrix_build_count() + LOADOUT_CELLS.size() + ENCOUNTER_CELLS.size() + BOSS_CELLS.size() + RUIN_CELLS.size() + RIVERFARM_CELLS.size() + INVRISIL_CELLS.size() + PARTY_CELLS.size() + DUNGEON_CELLS.size() + BESTIARY_CELLS.size()
	if OS.get_environment("WI_CELL_COUNT_ONLY") != "":
		print("WI_CELL_COUNT: %d" % total_cells)
		quit(0)
		return
	var range_env := OS.get_environment("WI_CELL_RANGE")
	if range_env != "":
		var parts := range_env.split(":")
		assert(parts.size() == 2, "WI_CELL_RANGE must be LO:HI (0-based, inclusive)")
		_range_lo = int(parts[0])
		_range_hi = int(parts[1])

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
	var any_failed := false

	for comp: Dictionary in COMPOSITIONS:
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		for build: Dictionary in BUILDS:
			if not bool(build.get("matrix", true)): continue
			if not _cell_in_range(): continue
			var wins := 0
			var rounds: Array[int] = []
			var relc_downed := 0
			var has_relc := not bool(build.get("solo", false))
			for seed_v in range(1, RUNS_PER_CELL + 1):
				var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
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
			var gated := bool(build.get("gated", true)) \
					and not (build.get("ungated_comps", []) as Array).has(String(comp["name"]))
			print("[%s / %s]%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
				comp["name"], build["name"], "" if gated else " (measured)", win_rate, median, rounds[0], rounds[-1],
			])
			print("  rounds histogram: ", hist)
			if has_relc:
				print("  relc_downed_rate=%.2f (%d/%d)" % [float(relc_downed) / float(RUNS_PER_CELL), relc_downed, RUNS_PER_CELL])
			if not gated:
				continue
			if win_rate < 0.55 or win_rate > 0.95:
				any_failed = true
				printerr("FAIL [%s / %s]: win rate %.2f outside 0.55-0.95" % [comp["name"], build["name"], win_rate])
			if median < 3 or median > 12:
				any_failed = true
				printerr("FAIL [%s / %s]: median rounds %d outside 3-12" % [comp["name"], build["name"], median])

	for cell: Dictionary in LOADOUT_CELLS:
		if not _cell_in_range(): continue
		var comp: Dictionary = _find_by_name(COMPOSITIONS, String(cell["comp"]))
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(comp["arena"])]
		var weapon: Dictionary = items_by_id.get(String(cell[WIKeys.WEAPON]), {})
		var armor: Dictionary = items_by_id.get(String(cell["armor"]), {})
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
			pc[WIKeys.SKILLS] = WICombatBuild.fold_abilities(pc[WIKeys.SKILLS] as Array, accessories)
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

	for cell: Dictionary in ENCOUNTER_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var ally_downed := 0
		# Cell schema: solo defaults false; omitted ally means Relc. Win bands
		# are opt-in via win_lo/win_hi; otherwise the cell is measured only.
		var has_ally := not bool(cell.get("solo", false))
		var ally_id := String(cell.get("ally", "relc"))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = (by_id["pc"] as Dictionary).duplicate(true)
			pc[WIKeys.AI] = String(build.get(WIKeys.AI, "melee"))
			pc[WIKeys.STATS] = WIProgression.apply_stat_bonuses(pc[WIKeys.STATS], build["classes"], classes)
			pc[WIKeys.SKILLS] = WIProgression.granted_skills(build["classes"], classes)
			var cfgs: Array = [pc]
			if has_ally:
				var ally_cfg: Dictionary = (by_id[ally_id] as Dictionary).duplicate(true)
				# GH#156: mirror wi_game.start_combat's companion-boon injection
				# (basic_command_boon/pack_bond_boon keyed on the PC kit) -- the
				# harness must measure the shipped companion, boons included.
				if bool(cell.get("companion_boons", false)):
					var boons: Array = []
					if (pc[WIKeys.SKILLS] as Array).has("animals_basic_command"):
						boons.append("basic_command_boon")
					if (pc[WIKeys.SKILLS] as Array).has("pack_bond"):
						boons.append("pack_bond_boon")
					if not boons.is_empty():
						var comp_skills: Array = (ally_cfg.get(WIKeys.SKILLS, []) as Array).duplicate()
						comp_skills.append_array(boons)
						ally_cfg[WIKeys.SKILLS] = comp_skills
				cfgs.append(ally_cfg)
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
		var gated := cell.has("win_lo")
		print("[encounter / %s] arena=%s build=%s%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]),
			"" if has_ally else " solo", "" if gated else " (measured)", win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if has_ally:
			print("  %s_downed_rate=%.2f (%d/%d)" % [ally_id, float(ally_downed) / float(RUNS_PER_CELL), ally_downed, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [encounter / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [encounter / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in BOSS_CELLS:
		if not _cell_in_range(): continue
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

	for cell: Dictionary in RUIN_CELLS:
		if not _cell_in_range(): continue
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

	for cell: Dictionary in RIVERFARM_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var hunter_downed := 0
		var has_hunter := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
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
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [riverfarm / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in INVRISIL_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var wilovan_downed := 0
		var has_wilovan := not bool(cell.get("solo", false))
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
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
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [invrisil / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in PARTY_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		var pc_alive_end := 0
		var ally_downed := {"ceria": 0, "yvlon": 0, "ksmvr": 0}
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for ally_id: String in ["ceria", "yvlon", "ksmvr"]:
				var ally_cfg: Dictionary = (by_id[ally_id] as Dictionary).duplicate(true)
				var hp_mods: Dictionary = cell.get("ally_hp_mods", {})
				if hp_mods.has(ally_id):
					ally_cfg[WIKeys.HP_MOD] = int(ally_cfg.get(WIKeys.HP_MOD, 0)) + int(hp_mods[ally_id])
				cfgs.append(ally_cfg)
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "party %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
				assert(bool(combat.combatants["pc"][WIKeys.ALIVE]), "party %s fight %d: victory recorded with pc dead -- instant-defeat rule broken" % [cell["name"], seed_v])
			if bool(combat.combatants["pc"][WIKeys.ALIVE]):
				pc_alive_end += 1
			rounds.append(int(combat.outcome["rounds"]))
			for ally_id: String in ally_downed:
				if not bool(combat.combatants.get(ally_id, {}).get(WIKeys.ALIVE, true)):
					ally_downed[ally_id] = int(ally_downed[ally_id]) + 1

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[party / %s] arena=%s build=%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		print("  pc_alive_rate=%.2f (%d/%d)" % [float(pc_alive_end) / float(RUNS_PER_CELL), pc_alive_end, RUNS_PER_CELL])
		for ally_id: String in ["ceria", "yvlon", "ksmvr"]:
			print("  %s_downed_rate=%.2f (%d/%d)" % [ally_id, float(ally_downed[ally_id]) / float(RUNS_PER_CELL), ally_downed[ally_id], RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [party / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [party / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in DUNGEON_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var rounds: Array[int] = []
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "dungeon %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			rounds.append(int(combat.outcome["rounds"]))

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[dungeon / %s] arena=%s build=%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [dungeon / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [dungeon / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	for cell: Dictionary in BESTIARY_CELLS:
		if not _cell_in_range(): continue
		var build: Dictionary = _find_by_name(BUILDS, String(cell["build"]))
		var arena: Dictionary = arenas_by_id[String(cell["arena"])]
		var wins := 0
		var pc_alive_end := 0
		var rounds: Array[int] = []
		for seed_v in range(1, RUNS_PER_CELL + 1):
			var pc: Dictionary = _build_pc(build, by_id["pc"], classes, skills_by_id, items_by_id)
			var cfgs: Array = [pc]
			for enemy_id: String in cell["enemies"]:
				cfgs.append((by_id[enemy_id] as Dictionary).duplicate(true))
			var combat := WICombat.new(arena, cfgs, skills, sink, seed_v)
			combat.begin()
			var guard := 0
			while not combat.finished and guard < 2000:
				guard += 1
				WICombatAI.take_turn(combat)
			assert(combat.finished, "bestiary %s fight %d did not terminate" % [cell["name"], seed_v])
			if combat.outcome["victory"]:
				wins += 1
			if bool(combat.combatants["pc"]["alive"]):
				pc_alive_end += 1
			rounds.append(int(combat.outcome["rounds"]))

		rounds.sort()
		var win_rate := float(wins) / float(RUNS_PER_CELL)
		var median: int = rounds[RUNS_PER_CELL / 2]
		var hist := {}
		for r: int in rounds:
			hist[r] = int(hist.get(r, 0)) + 1
		var gated := cell.has("win_lo")
		print("[bestiary / %s] arena=%s build=%s%s win_rate=%.2f median_rounds=%d min=%d max=%d" % [
			cell["name"], String(cell["arena"]), String(cell["build"]), "" if gated else " (measured)",
			win_rate, median, rounds[0], rounds[-1],
		])
		print("  rounds histogram: ", hist)
		print("  pc_alive_rate=%.2f (%d/%d)" % [float(pc_alive_end) / float(RUNS_PER_CELL), pc_alive_end, RUNS_PER_CELL])
		if gated:
			var lo := float(cell["win_lo"])
			var hi := float(cell["win_hi"])
			if win_rate < lo or win_rate > hi:
				any_failed = true
				printerr("FAIL [bestiary / %s]: win rate %.2f outside band %.2f-%.2f" % [cell["name"], win_rate, lo, hi])
			if bool(cell.get("check_rounds", false)) and (median < 3 or median > 12):
				any_failed = true
				printerr("FAIL [bestiary / %s]: median rounds %d outside 3-12" % [cell["name"], median])

	assert(not any_failed, "one or more matrix cells failed bounds — see FAIL lines above")
	if any_failed:
		quit(1)
		return
	print("PASS: balance harness terminated cleanly over %d cells x %d seeded runs" % [total_cells, RUNS_PER_CELL])
	quit(0)
