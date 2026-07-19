extends SceneTree

const _FORBIDDEN_ATTR := "(?i)\\b(str|dex|con|int|wis|cha)\\b"

const EXPECTED_ITEMS := {
	"rusty_sword": ["Sword kit replaces other weapon Skills in combat"],
	"relcs_spare_spear": ["+1 damage on melee hits", "Spear kit replaces other weapon Skills in combat"],
	"crude_blade": ["Sword kit replaces other weapon Skills in combat"],
	"chipped_spear": ["Spear kit replaces other weapon Skills in combat"],
	"solid_oak_spear": ["Spear kit replaces other weapon Skills in combat"],
	"leather_jerkin": ["+4 HP", "Worth 24 gold"],
	"watch_issue_gambeson": ["Reduces every hit taken by 1", "Worth 20 gold"],
	"traveler_charm": ["+2 HP", "Resonance 1", "Worth 5 gold"],
	"carved_chess_pawn": ["Resonance 1", "Worth 12 gold"],
	"ratici_gray_feather": ["+1 HP", "Resonance 1", "Worth 11 gold"],
	"ratici_parlor_coin": ["Resonance 1", "Worth 13 gold"],
	"hedaults_warded_setting": ["+2 HP", "Reduces every hit taken by 1", "Resonance 1", "Worth 45 gold"],
	"gnollish_hunting_knife": ["+1 damage on melee hits", "Sword kit replaces other weapon Skills in combat", "Worth 15 gold"],
	"wool_lined_cloak": ["+3 HP", "Worth 18 gold"],
	"copper_luck_band": ["+1 HP", "Grants [Dangersense] in combat", "Worth 4 gold"],
	"hedge_ward_charm": ["+2 HP", "Resonance 1", "Worth 9 gold"],
	"hunters_fang_talisman": ["+1 damage on melee hits", "Resonance 1", "Worth 14 gold"],
	"phosphor_pendant": ["+3 HP", "Resonance 1", "Worth 20 gold"],
	"stonescale_talisman": ["Reduces every hit taken by 1", "Resonance 2", "Grants [Tough Body] in combat", "Worth 35 gold"],
	"moon_bone_amulet": ["+1 damage on melee hits", "+3 HP", "Resonance 2", "Grants [Invisibility] in combat"],
	"watch_token": [],
	"brothers_marker": [],
	"field_whetstone": ["Worth 5 gold"],
	"fishers_handline": ["Worth 4 gold"],
	"parcel_plains_wool": [],
	"parcel_that_ticks": [],
	"parcel_watch_dispatch": [],
	"parcel_lamp_phials": [],
	"parcel_bluefruit_hamper": [],
	"parcel_gambeson_bundle": [],
	"parcel_ledger_transfer": [],
	"parcel_tactics_brief": [],
	"parcel_sealed_letter": [],
	"parcel_seed_grain": [],
	"hot_meal": [],
	"flarepepper_powder": ["Next fight: +1 damage (single use)", "Worth 6 gold"],
	"cups_debt_chit": [],
	"renns_warhammer": [],
	"note_watch_veteran": [],
	"note_sewer_surveyor": [],
	"note_old_dread": [],
	"resonant_catalyst": ["Worth 35 gold"],
	"anchor_stone": [],
	"dried_yarrow_bundle": ["Worth 4 gold"],
	"sleeproot_draught": ["Worth 5 gold"],
	"hollow_herb_sachet": ["+1 HP", "Grants [Witch\'s Warding] in combat", "Worth 6 gold"],
	"witch_wardstone_bead": ["+2 HP", "Resonance 1", "Worth 16 gold"],
	"invrisil_attunement_stone": ["Worth 18 gold"],
	"pallass_attunement_stone": ["Worth 18 gold"],
	"training_bow": ["Range 4", "Bow kit replaces other weapon Skills in combat", "Worth 8 gold"],
	"hunting_bow": ["+1 damage on ranged hits", "Range 4", "Bow kit replaces other weapon Skills in combat", "Worth 18 gold"],
	"trap_kit": ["Worth 3 gold"],
	"warding_salt_pinch": ["Worth 7 gold"],
	"mending_draught": ["Heals 8 HP (single use)", "Worth 10 gold"],
	"remedy_draught": ["Heals 8 HP (single use)", "Worth 10 gold"],
	"fine_meal": ["Next fight: +2 HP (single use)", "Worth 8 gold"],
	"signature_meal": ["Next fight: +1 damage, +2 HP (single use)", "Worth 14 gold"],
	"tempering_oil": ["Next fight: +1 damage (single use)", "Worth 12 gold"],
	"crude_draught": ["Next fight: +1 HP (single use)", "Worth 4 gold"],
	"solvent_phial": ["Worth 6 gold"],
	"mineral_salts": ["Worth 6 gold"],
	"tonic_of_the_clear_eye": ["Next fight: +1 damage, +2 HP (single use)", "Worth 16 gold"],
	"construct_core_shard": ["+3 HP", "Reduces every hit taken by 1", "Resonance 2", "Grants [Read the Field] in combat"],
	"warded_coil_charm": ["+2 HP", "Resonance 1"],
	"kingslayer_fang": ["+1 damage on melee hits", "+1 HP", "Resonance 1", "Grants [Battle Momentum] in combat"],
	"guardian_ward_fragment": ["+2 HP", "Reduces every hit taken by 1", "Resonance 1", "Grants [Guarding Ward] in combat"],
	"hedaults_traveler_charm": ["+3 HP", "Resonance 1", "Grants [Dangersense] in combat", "Worth 18 gold"],
	"hedaults_hunters_fang": ["+1 damage on melee hits", "Resonance 1", "Grants [Eagle Eyes] in combat", "Worth 45 gold"],
	"hedaults_wardstone": ["+2 HP", "Resonance 2", "Grants [Mana Shield] in combat", "Worth 50 gold"],
	"moonhide_fetish": ["+1 damage on melee hits", "+1 HP", "Resonance 1", "Grants [Second Wind] in combat"],
	"anchor_sliver": ["+4 HP", "Reduces every hit taken by 1", "Resonance 3"],
}

const EXPECTED_SKILLS := {
	"basic_cleaning": [],
	"basic_swordwork": ["+5 to hit"],
	"tough_body": ["+10 max HP"],
	"power_strike": ["3 AP — ×2 damage"],
	"counter_strike": ["Strike back for ×0.8 damage when hit in melee."],
	"battle_momentum": ["+1 AP when you down a foe"],
	"flame_bolt": ["2 AP — damage 1d6 at range 4. Burns."],
	"flame_jet": ["2 AP, 4 MP — damage everything in a line 4 cells long"],
	"frost_bolt": ["1 AP, 2 MP — damage 1d6 at range 4. Slows."],
	"mana_shield": ["Spend MP to absorb incoming damage."],
	"quick_cast": ["Your first spell each turn costs 1 less AP."],
	"light": [],
	"frost_touch": [],
	"kindle": [],
	"sneak": ["1 AP — +2 move cells this turn"],
	"invisibility": ["1 AP, 3 MP — become impossible to target for 3 rounds (breaks if you deal damage)"],
	"quick_movement": ["+1 move cell every turn"],
	"second_wind": ["2 AP — restore 8 HP to yourself"],
	"dangersense": [],
	"piercing_strikes": ["2 AP — ×1.4 damage"],
	"quick_slash": ["1 AP — ×0.7 damage"],
	"flash_cut": ["2 AP — ×1.4 damage"],
	"devastating_slash": ["4 AP — ×2.6 damage"],
	"triple_thrust": ["3 AP — ×2 damage"],
	"extended_sweep": ["2 AP — ×1.3 damage"],
	"spear_flurry": ["4 AP — ×2.6 damage"],
	"ice_shard": ["2 AP, 3 MP — damage 1d6 at range 4"],
	"icy_floor": ["2 AP, 4 MP — glaze a 3×3 patch of ground at range 3 for 2 rounds. Slows."],
	"flame_scythe": ["2 AP, 4 MP — damage 1d6 at range 1"],
	"flare_burst": ["1 AP, 2 MP — damage 1d6 at range 3"],
	"flame_pillar": ["3 AP, 5 MP — blast a 3×3 area around the target for 1d6. Hits friend and foe."],
	"slam": ["4 AP — blast a 3×3 area around the target for 1d6 after a round's gathering. Hits friend and foe. Roots."],
	"keener_edge": ["2 AP — ×1.6 damage"],
	"spellbound_strike": ["4 AP, 3 MP — ×3 damage"],
	"lesser_stamina": [],
	"low_grade_synthesis": [],
	"cleansing_heat": [],
	"magic_water_solvent": [],
	"mineral_distillation": [],
	"true_synthesis": [],
	"basic_cooking": [],
	"lesser_strength": [],
	"observe": [],
	"battlefield_awareness": ["+1 move cell every turn"],
	"soothe_clientele": [],
	"unerring_aim": [],
	"sweep_the_tables": [],
	"servers_prescience": [],
	"charming_smile": [],
	"calming_touch": ["2 AP — damage 1d6 at range 1. Slows."],
	"raskghar_maul": ["3 AP — damage 1d6 at range 2. Slows. Weakens."],
	"power_shot": ["3 AP — ×2 damage"],
	"quick_nock": ["1 AP — ×0.7 damage"],
	"piercing_shot": ["3 AP — damage everything in a line 4 cells long"],
	"keen_eye": [],
	"directed_strike": ["2 AP — ×1.6 damage"],
	"flanking_step": ["+1 move cell every turn"],
	"read_the_field": ["+10 to hit"],
	"measured_words": [],
	"soothing_presence": ["2 AP, 3 MP — restore 6 HP to an ally, or yourself"],
	"guarding_ward": ["2 AP — restore 4 HP to an ally, or yourself. Guards."],
	"open_doors": [],
	"find_trap": [],
	"disarm_trap": [],
	"sudden_strike": ["2 AP — ×1.8 damage. Once per fight."],
	"called_shot": ["3 AP — ×2.2 damage"],
	"piercing_volley": ["4 AP — damage everything in a line 5 cells long"],
	"flame_dart": ["2 AP, 3 MP — damage 1d6 at range 4"],
	"perfect_hospitality": [],
	"steady_draw": ["+8 to hit"],
	"bargain": [],
	"appraise_goods": [],
	"bulk_terms": [],
	"runners_legs": [],
	"efficient_run": [],
	"enhanced_movement": ["+1 move cell every turn"],
	"hedge_remedy": [],
	"witchs_warding": ["+8 max HP"],
	"evil_eye": ["2 AP — damage 1d6 at range 3. Weakens."],
	"bone_dart": ["1 AP, 2 MP — damage 1d6 at range 4"],
	"deathbolt": ["2 AP, 4 MP — damage 1d6 at range 4. Weakens."],
	"detect_magic": [],
	"advanced_cooking": [],
	"perfect_recall": [],
	"signature_dish": [],
	"eagle_eyes": ["+8 to hit"],
	"marked_quarry": ["2 AP — ×1.8 damage. Once per fight."],
	"double_step": ["1 AP — +2 move cells this turn"],
	"flash_step": ["2 AP, 3 MP — +3 move cells this turn"],
	"animate_dead": [],
	"healthy_rearing": [],
	"animals_basic_command": [],
	"basic_command_boon": ["+8 to hit"],
	"lesser_bond": [],
	"beasts_mending": [],
	"wild_affinity": [],
	"pack_bond": [],
	"pack_bond_boon": ["+4 max HP"],
	"peace_of_the_wild": [],
	"thorn_hand": ["2 AP, 3 MP — damage 1d6 at range 1. Roots."],
	"hearthward_charm": [],
	"greater_hearthward": [],
	"crescent_cut": ["3 AP — damage everything in a line 3 cells long"],
	"pierce_thrust": ["3 AP — damage everything in a line 3 cells long"],
	"ice_wall": ["Spend MP to absorb incoming damage."],
	"flashfire_spellcraft": ["Your first spell each turn costs 1 less AP."],
	"blinding_arrow": ["2 AP — ×1.2 damage. Weakens."],
	"shadowstep": ["+2 move cells every turn"],
	"phantom_barrage": ["3 AP — damage everything in a line 4 cells long"],
	"trusted_voice": [],
	"barmaids_prescience": [],
	"swift_service": ["+1 move cell every turn"],
	"evaluation_of_wealth": [],
	"couriers_double_step": ["+2 move cells every turn"],
	"tea_omens": [],
	"flarepepper_supplies": [],
	"perfect_reduction": [],
	"sworn_fang_ride_together": [],
	"sworn_fang_boon": ["+8 to hit"],
}


func _init() -> void:
	WITestWatchdog.arm(self)
	_test_items_exact()
	_test_skills_exact()
	_test_status_exact()
	_test_tripwires()
	_test_forbidden_vocab()
	print("PASS: WIEffectText generates every shipped line in visible currency only")
	quit(0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		quit(1)


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "invalid JSON: " + path)
	return parsed


func _test_items_exact() -> void:
	var items: Array = _load("res://data/items.json")["items"]
	var seen := {}
	for item: Dictionary in items:
		var id := String(item["id"])
		seen[id] = true
		_check(EXPECTED_ITEMS.has(id), "item %s has no pinned expectation -- add it to EXPECTED_ITEMS" % id)
		_check(
			WIEffectText.item_effect_lines(item) == EXPECTED_ITEMS[id],
			"item %s lines: got %s want %s" % [id, WIEffectText.item_effect_lines(item), EXPECTED_ITEMS[id]]
		)
	for id: String in EXPECTED_ITEMS:
		_check(seen.has(id), "EXPECTED_ITEMS lists %s but it is not in items.json" % id)


func _test_skills_exact() -> void:
	var skills: Array = _load("res://data/skills.json")["skills"]
	var seen := {}
	for skill: Dictionary in skills:
		var id := String(skill["id"])
		seen[id] = true
		_check(EXPECTED_SKILLS.has(id), "skill %s has no pinned expectation -- add it to EXPECTED_SKILLS" % id)
		_check(
			WIEffectText.skill_effect_lines(skill) == EXPECTED_SKILLS[id],
			"skill %s lines: got %s want %s" % [id, WIEffectText.skill_effect_lines(skill), EXPECTED_SKILLS[id]]
		)
	for id: String in EXPECTED_SKILLS:
		_check(seen.has(id), "EXPECTED_SKILLS lists %s but it is not in skills.json" % id)


func _test_status_exact() -> void:
	_check(
		WIEffectText.status_line("slowed") == "Slowed — moves 2 fewer cells next turn (min 1).",
		"slowed glossary line: got %s" % WIEffectText.status_line("slowed")
	)
	_check(WIEffectText.status_line("nonexistent") == "", "unknown status yields empty string")
	_check(
		WIEffectText.status_line("invisible") == "Invisible — enemies can't choose you as a target; breaks if you deal damage, or fades after 3 rounds.",
		"invisible glossary line: got %s" % WIEffectText.status_line("invisible")
	)
	_check(
		WIEffectText.status_line("weakened") == "Weakened — deals ×0.75 damage for 1 round.",
		"weakened glossary line: got %s" % WIEffectText.status_line("weakened")
	)
	_check(
		WIEffectText.status_line("guarded") == "Guarded — takes ×0.75 damage for 1 round.",
		"guarded glossary line: got %s" % WIEffectText.status_line("guarded")
	)
	_check(
		WIEffectText.status_line("rooted") == "Rooted — can't move or Dash for 1 round.",
		"rooted glossary line: got %s" % WIEffectText.status_line("rooted")
	)
	_check(
		WIEffectText.status_line("burning") == "Burning — takes 2 damage at the end of each round for 3 rounds.",
		"burning glossary line: got %s" % WIEffectText.status_line("burning")
	)


func _test_tripwires() -> void:
	_check(WIEffectText.item_effect_lines({"hp_mod": 4}) == ["+4 HP"], "item hp tripwire base")
	_check(WIEffectText.item_effect_lines({"hp_mod": 7}) == ["+7 HP"], "item hp tripwire moved")
	_check(WIEffectText.item_effect_lines({"damage_mod": 9}) == ["+9 damage on melee hits"], "item damage tripwire")
	_check(
		WIEffectText.item_effect_lines({"damage_mod": 3, "range": 4}) == ["+3 damage on ranged hits", "Range 4"],
		"item ranged-damage tripwire base"
	)
	_check(
		WIEffectText.item_effect_lines({"damage_mod": 3, "range": 6}) == ["+3 damage on ranged hits", "Range 6"],
		"item ranged-damage tripwire: range moves"
	)
	_check(
		WIEffectText.item_effect_lines({"range": 1}) == [],
		"item range tripwire: range<=1 is melee, no Range line (byte-identical default)"
	)

	var spell := {"ap_cost": 1, "mp_cost": 2, "effect": {"type": "spell_damage", "range": 4}}
	_check(WIEffectText.skill_effect_lines(spell) == ["1 AP, 2 MP — damage 1d6 at range 4"], "skill spell tripwire base (default pc weapon_die 6)")
	spell["effect"]["die"] = 99
	_check(WIEffectText.skill_effect_lines(spell) == ["1 AP, 2 MP — damage 1d6 at range 4"], "skill spell tripwire: effect.die is vestigial, ignored")
	spell["effect"].erase("die")
	spell["effect"]["range"] = 2
	_check(WIEffectText.skill_effect_lines(spell) == ["1 AP, 2 MP — damage 1d6 at range 2"], "skill spell tripwire: range still moves")
	var combatants_catalog := [{"id": "pc", "weapon_die": 9}]
	_check(
		WIEffectText.skill_effect_lines(spell, combatants_catalog) == ["1 AP, 2 MP — damage 1d9 at range 2"],
		"skill spell tripwire: die follows the injected pc catalog, not effect.die"
	)

	var mult_skill := {"ap_cost": 3, "effect": {"type": "damage_mult", "mult": 2.0}}
	_check(WIEffectText.skill_effect_lines(mult_skill) == ["3 AP — ×2 damage"], "damage_mult tripwire base")
	mult_skill["effect"]["mult"] = 3.5
	_check(WIEffectText.skill_effect_lines(mult_skill) == ["3 AP — ×3.5 damage"], "damage_mult tripwire: mult moves")
	mult_skill["ap_cost"] = 5
	_check(WIEffectText.skill_effect_lines(mult_skill) == ["5 AP — ×3.5 damage"], "cost tripwire: ap_cost moves")
	_check(WIEffectText.skill_effect_lines({"effect": {"type": "hp_bonus", "amount": 10}}) == ["+10 max HP"], "hp_bonus tripwire base")
	_check(WIEffectText.skill_effect_lines({"effect": {"type": "hp_bonus", "amount": 25}}) == ["+25 max HP"], "hp_bonus tripwire: amount moves")
	var line_skill := {"ap_cost": 2, "mp_cost": 4, "effect": {"type": "line_damage", "length": 4}}
	_check(WIEffectText.skill_effect_lines(line_skill) == ["2 AP, 4 MP — damage everything in a line 4 cells long"], "line_damage tripwire base")
	line_skill["effect"]["length"] = 7
	_check(WIEffectText.skill_effect_lines(line_skill) == ["2 AP, 4 MP — damage everything in a line 7 cells long"], "line_damage tripwire: length moves")

	var catalog := [{"id": "x", "effect": {"type": "spell_damage", "applies": {"slowed": {"pool_penalty": 5}}}}]
	_check(
		WIEffectText.status_line("slowed", catalog) == "Slowed — moves 5 fewer cells next turn (min 1).",
		"status tripwire: penalty follows the catalog"
	)
	var inv_skill := {"ap_cost": 1, "mp_cost": 3, "effect": {"type": "invisibility", "duration_rounds": 3}}
	_check(
		WIEffectText.skill_effect_lines(inv_skill) == ["1 AP, 3 MP — become impossible to target for 3 rounds (breaks if you deal damage)"],
		"invisibility tripwire base"
	)
	inv_skill["effect"]["duration_rounds"] = 5
	_check(
		WIEffectText.skill_effect_lines(inv_skill) == ["1 AP, 3 MP — become impossible to target for 5 rounds (breaks if you deal damage)"],
		"invisibility tripwire: duration_rounds moves"
	)
	var inv_catalog := [{"id": "x", "effect": {"type": "invisibility", "duration_rounds": 7}}]
	_check(
		WIEffectText.status_line("invisible", inv_catalog) == "Invisible — enemies can't choose you as a target; breaks if you deal damage, or fades after 7 rounds.",
		"invisible status tripwire: duration follows the catalog"
	)

	var weak_catalog := [{"id": "x", "effect": {"type": "spell_damage", "applies": {"weakened": {"duration_rounds": 4}}}}]
	_check(
		WIEffectText.status_line("weakened", weak_catalog) == "Weakened — deals ×0.75 damage for 4 rounds.",
		"weakened status tripwire: duration follows the catalog"
	)
	var guard_catalog := [{"id": "x", "effect": {"type": "heal", "applies": {"guarded": {"duration_rounds": 5}}}}]
	_check(
		WIEffectText.status_line("guarded", guard_catalog) == "Guarded — takes ×0.75 damage for 5 rounds.",
		"guarded status tripwire: duration follows the catalog"
	)
	var root_catalog := [{"id": "x", "effect": {"type": "blast_damage", "applies": {"rooted": {"duration_rounds": 3}}}}]
	_check(
		WIEffectText.status_line("rooted", root_catalog) == "Rooted — can't move or Dash for 3 rounds.",
		"rooted status tripwire: duration follows the catalog, plural rounds"
	)
	var burn_catalog := [{"id": "x", "effect": {"type": "spell_damage", "applies": {"burning": {"tick_damage": 5, "duration_rounds": 2}}}}]
	_check(
		WIEffectText.status_line("burning", burn_catalog) == "Burning — takes 5 damage at the end of each round for 2 rounds.",
		"burning status tripwire: tick_damage and duration follow the catalog"
	)


func _test_forbidden_vocab() -> void:
	var attr := RegEx.new()
	attr.compile(_FORBIDDEN_ATTR)
	var lines: Array[String] = []
	for item: Dictionary in _load("res://data/items.json")["items"]:
		lines.append_array(WIEffectText.item_effect_lines(item))
	for skill: Dictionary in _load("res://data/skills.json")["skills"]:
		lines.append_array(WIEffectText.skill_effect_lines(skill))
	lines.append(WIEffectText.status_line("slowed"))
	lines.append(WIEffectText.status_line("invisible"))
	lines.append(WIEffectText.status_line("weakened"))
	lines.append(WIEffectText.status_line("guarded"))
	lines.append(WIEffectText.status_line("rooted"))
	lines.append(WIEffectText.status_line("burning"))
	for line: String in lines:
		_check(attr.search(line) == null, "forbidden attribute token in generated line: %s" % line)
		_check(not line.contains("%"), "forbidden percent-toward token in generated line: %s" % line)
