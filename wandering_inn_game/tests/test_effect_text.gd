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
	"old_delvers_clasp": ["+2 HP", "Reduces every hit taken by 1", "Resonance 1", "Worth 35 gold"],
	"gnollish_hunting_knife": ["+1 damage on melee hits", "Sword kit replaces other weapon Skills in combat", "Worth 15 gold"],
	"wool_lined_cloak": ["+3 HP", "Worth 18 gold"],
	"copper_luck_band": ["+1 HP", "Grants [Dangersense] in combat", "Worth 4 gold"],
	"hedge_ward_charm": ["+2 HP", "Resonance 1", "Worth 9 gold"],
	"hunters_fang_talisman": ["+1 damage on melee hits", "Resonance 1", "Worth 14 gold"],
	"phosphor_pendant": ["+3 HP", "Resonance 1", "Worth 20 gold"],
	"stonescale_talisman": ["Reduces every hit taken by 1", "Resonance 2", "Grants [Tough Body] in combat", "Worth 35 gold"],
	"moon_bone_amulet": ["+1 damage on melee hits", "+3 HP", "Resonance 2", "Grants [Invisibility]"],
	"watch_token": [],
	"brothers_marker": [],
	"field_whetstone": ["Worth 5 gold"],
	"fishers_handline": ["Worth 4 gold"],
	"wool_tuft": ["Worth 1 gold"],
	"shed_antler": ["Worth 6 gold"],
	"loose_arrow": ["Worth 1 gold"],
	# GH#380/#383 yields: both priceless (never merchandise), so only the
	# next_fight clause composes.
	"improvised_cudgel": ["Next fight: +1 damage (single use)"],
	"seared_venison": ["Next fight: +2 HP (single use)"],
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
	"mending_draught": ["Heals 8 HP in combat (single use)", "Worth 10 gold"],
	"remedy_draught": ["Heals 8 HP in combat (single use)", "Worth 10 gold"],
	# 2026-08-02 (GH#334 ruling 7): both lost their `price` key -- a meal is
	# served or eaten, never merchandise (hot_meal's precedent) -- so the
	# generated "Worth N gold" row is gone with it.
	"fine_meal": ["Next fight: +2 HP (single use)"],
	"signature_meal": ["Next fight: +1 damage, +2 HP (single use)"],
	"tempering_oil": ["Next fight: +1 damage (single use)", "Worth 12 gold"],
	"crude_draught": ["Next fight: +1 HP (single use)", "Worth 4 gold"],
	"solvent_phial": ["Worth 6 gold"],
	"mineral_salts": ["Worth 6 gold"],
	"tonic_of_the_clear_eye": ["Next fight: +1 damage, +2 HP (single use)", "Worth 16 gold"],
	"construct_core_shard": ["+3 HP", "Reduces every hit taken by 1", "Resonance 2", "Grants [Read the Field] in combat"],
	"warded_coil_charm": ["+2 HP", "Resonance 1"],
	"kingslayer_fang": ["+1 damage on melee hits", "+1 HP", "Resonance 1", "Grants [Battle Momentum] in combat"],
	"guardian_ward_fragment": ["+2 HP", "Reduces every hit taken by 1", "Resonance 1", "Grants [Guarding Ward] in combat"],
	# #398 P5 briar-arch coffer yield. warded_coil_charm's curve (hp_mod 2,
	# damage_reduction 0, resonance 1) plus guardian_ward_fragment's grant, and no
	# price -- so its lines are that fragment's MINUS the reduction clause. The
	# missing row here was review C2: the suite printed FAIL and still exited 0.
	"rootbound_ward_token": ["+2 HP", "Resonance 1", "Grants [Guarding Ward] in combat"],
	"wardwrights_counterweight": ["+2 HP", "Resonance 1", "Grants [Dangersense] in combat"],
	"sealed_factor_bale": ["Worth 28 gold"],
	"riverfarm_ferry_tally": ["Worth 28 gold"],
	# #423 the enchanter work-room reward, banded on the two rows above it.
	"enchanters_true_gauge": ["Worth 28 gold"],
	"hollow_thorn_tally": ["Worth 28 gold"],
	"pond_survey_seal": ["Reduces every hit taken by 1", "Resonance 1"],
	# 2026-07-26 Act V terminus reward (data/maps/dungeon/seal_vault.json's
	# vault_anchor_stone). construct_core_shard's curve, guardian_ward's grant,
	# no price (one-of-a-kind find, never vendored).
	"seal_anchor_rune": ["+3 HP", "Reduces every hit taken by 1", "Resonance 2", "Grants [Guarding Ward] in combat"],
	"hedaults_traveler_charm": ["+3 HP", "Resonance 1", "Grants [Dangersense] in combat", "Worth 18 gold"],
	"hedaults_hunters_fang": ["+1 damage on melee hits", "Resonance 1", "Grants [Eagle Eyes]", "Worth 45 gold"],
	"hedaults_wardstone": ["+2 HP", "Resonance 2", "Grants [Mana Shield] in combat", "Worth 50 gold"],
	# v0.16 I1 (#306), inserted at the `hedaults_wardstone` anchor this lane also
	# uses in items.json (ruling C). EXPECTED_ITEMS is exhaustive both ways, so a
	# new item id with no row here reds this suite. It used to red it QUIETLY --
	# see the `_failed` block at `_check` for the #398 P5 fix that made the exit
	# code, not just a zero-noise grep, the detector.
	"plum_silk_locket": ["+1 HP", "Resonance 1", "Worth 30 gold"],
	"moonhide_fetish": ["+1 damage on melee hits", "+1 HP", "Resonance 1", "Grants [Second Wind] in combat"],
	"anchor_sliver": ["+4 HP", "Reduces every hit taken by 1", "Resonance 3"],
}

const EXPECTED_SKILLS := {
	"basic_cleaning": [],
	"basic_swordwork": ["+5 to hit"],
	"tough_body": ["+10 max HP"],
	"power_strike": ["3 AP — ×2 damage. Once every 2 rounds."],
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
	"second_wind": ["2 AP — restore 8 HP to yourself. Once per fight."],
	"dangersense": [],
	"piercing_strikes": ["2 AP — ×1.4 damage"],
	"quick_slash": ["1 AP — ×0.7 damage"],
	"flash_cut": ["2 AP — ×1.4 damage"],
	"devastating_slash": ["3 AP — ×2.6 damage. Once every 2 rounds."],
	"triple_thrust": ["3 AP — ×2 damage. Once every 2 rounds."],
	"extended_sweep": ["2 AP — ×1.3 damage"],
	"spear_flurry": ["3 AP — ×2.6 damage. Once every 2 rounds."],
	"ice_shard": ["2 AP, 3 MP — damage 1d6 at range 4"],
	"icy_floor": ["2 AP, 4 MP — glaze a 3×3 patch of ground at range 3 for 2 rounds. Slows."],
	"flame_scythe": ["2 AP, 4 MP — damage 1d6 at range 1"],
	"flare_burst": ["1 AP, 2 MP — damage 1d6 at range 3"],
	"flame_pillar": ["3 AP, 5 MP — blast a 3×3 area around the target for 1d6. Hits friend and foe."],
	"slam": ["4 AP — blast a 3×3 area around the target for 1d6 after a round's gathering. Hits friend and foe. Roots."],
	"keener_edge": ["2 AP — ×1.6 damage"],
	"spellbound_strike": ["3 AP, 3 MP — ×3 damage. Once every 2 rounds."],
	# #449 [Spellspear]: the spear-flavored twins of the two rows directly
	# above. These pins reading IDENTICAL to their baselines is the point --
	# the user ruling makes [Spellsword] the mechanical baseline, so any drift
	# in cost or multiplier shows up here as a diff.
	"keener_point": ["2 AP — ×1.6 damage"],
	"spellbound_thrust": ["3 AP, 3 MP — ×3 damage. Once every 2 rounds."],
	# #438 [Deathknight]: the death-flavored twins of the SAME two baselines.
	# Identical readouts for the identical reason -- [Spellsword] is the
	# mechanical anchor for every martial x caster consolidation, so a tuning
	# drift in either lineage surfaces here as a diff rather than in a playtest.
	"grave_edge": ["2 AP — ×1.6 damage"],
	"deathbound_strike": ["3 AP, 3 MP — ×3 damage. Once every 2 rounds."],
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
	## #460 the crypt Lich's three enemy-kit verbs. None of them can reach a player
	## hotbar (no class grants them), but every catalog row is composed and pinned
	## here anyway -- the bestiary and the journal read the same composer, and a
	## Skill whose card says nothing is how a data key reaches a reader.
	"raise_bones": ["3 AP — raise Bone Thrall to fight beside you, up to 2 a fight. Once per round."],
	"lich_bone_splinter": ["1 AP, 2 MP — damage 1d6 at range 4"],
	"lich_grave_lance": ["2 AP, 4 MP — damage 1d6 at range 4. Weakens."],
	"power_shot": ["3 AP — ×2 damage. Once every 2 rounds."],
	"quick_nock": ["1 AP — ×0.7 damage"],
	"piercing_shot": ["3 AP — damage everything in a line 4 cells long. Once every 2 rounds."],
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
	"called_shot": ["3 AP — ×2.2 damage. Once every 2 rounds."],
	"piercing_volley": ["3 AP — damage everything in a line 5 cells long. Once every 2 rounds."],
	"flame_dart": ["2 AP, 3 MP — damage 1d6 at range 4"],
	"perfect_hospitality": [],
	"steady_draw": ["+8 to hit"],
	# #438 [Skirmisher]: the spear-gated twin of the row above. The readout is
	# identical because only the `weapon` gate re-flavors -- the effect block is
	# [Ranger]'s VERBATIM, and `weapon` never reaches the effect lines.
	"steady_point": ["+8 to hit"],
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
	# #438 [Wild Sage]: the twins of the two rows directly above. [Counsel of
	# the Wild] pins [] like its baseline -- BOTH carry their mechanics in
	# wi_game.gd::_wild_affinity_reduction rather than an `effect` block, so an
	# empty readout here is correct and NOT the signature of an inert twin.
	"counsel_of_the_wild": [],
	"bramble_hand": ["2 AP, 3 MP — damage 1d6 at range 1. Roots."],
	"hearthward_charm": [],
	"greater_hearthward": [],
	"crescent_cut": ["3 AP — damage everything in a line 3 cells long"],
	"pierce_thrust": ["3 AP — damage everything in a line 3 cells long"],
	"ice_wall": ["Spend MP to absorb incoming damage."],
	"flashfire_spellcraft": ["Your first spell each turn costs 1 less AP."],
	"blinding_arrow": ["2 AP — ×1.2 damage. Weakens."],
	"shadowstep": ["+2 move cells every turn"],
	"phantom_barrage": ["3 AP — damage everything in a line 4 cells long. Once every 2 rounds."],
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
	# GH#380/#381/#382 martial exploration slate: no `effect` block on any of
	# them, so every line is [] -- the frost_touch/kindle shape.
	"even_footing": [],
	"greater_strength": [],
	"broader_shoulders": [],
	"bar_fighting": [],
	"basic_repair": [],
	"rope_work": [],
	# #423: a field skill with no numeric currency to render, like every other
	# authored-arm exploration Skill (disarm_trap/rope_work/greater_strength).
	"pick_lock": [],
}

## The FIELD variant (`WIEffectText.field_effect_lines`), pinned separately from
## EXPECTED_SKILLS because the two composers answer to different surfaces: the
## combat HUD and the journal want "1 AP, 3 MP — become impossible to target for
## 3 rounds", the exploration hotbar must never say it (a field cast spends
## nothing and no round clock is running). Every row here is a `field: true`
## Skill that ALSO carries an `effect` block -- the only ones that could leak a
## combat phrase onto the hotbar readout. All resolve to [], so `_readout_line`
## falls back to "display_name — description". `_test_field_skills_exact` also
## sweeps the WHOLE catalog for field silence, so a new effect type that is not
## in `_COMBAT_ONLY_EFFECT_TYPES` reds this suite before it can reach a player.
const EXPECTED_FIELD_SKILLS := {
	"basic_swordwork": [],
	"sneak": [],
	"invisibility": [],
	"double_step": [],
	"flash_step": [],
	"eagle_eyes": [],
	"light": [],
	"observe": [],
	"hedge_remedy": [],
	# GH#380/#383 dual-context pair: combat spells that now reach the field bar.
	# Both must stay field-SILENT (their effect types are combat-only), so the
	# hotbar readout falls back to display_name -- description out on the map
	# while the combat HUD keeps the cost line pinned in EXPECTED_SKILLS.
	"icy_floor": [],
	"flame_jet": []
}


func _init() -> void:
	WITestWatchdog.arm(self)
	_test_items_exact()
	_test_skills_exact()
	_test_field_skills_exact()
	_test_status_exact()
	_test_tripwires()
	_test_pending_meal_line()
	_test_cooldown_clause()
	_test_forbidden_vocab()
	if _failed:
		printerr("FAIL: test_effect_text -- one or more pinned expectations failed (see the FAIL lines above)")
		quit(1)
		return
	print("PASS: WIEffectText generates every shipped line in visible currency only")
	quit(0)


## #398 P5 review C2 (the MASKED-RED class fix): `quit()` in Godot only REQUESTS
## an exit at the end of the frame -- it does NOT return from the caller. So the
## old `_check` failure path pushed `ERROR: FAIL ...`, kept running the whole
## suite, and then hit `_init()`'s trailing `quit(0)`, which overwrote the 1.
## The run printed PASS and exited 0 with the failure sitting in the log; only a
## zero-noise grep could see it, which is exactly how the missing
## `rootbound_ward_token` row above survived a green lane report.
## The flag makes the EXIT CODE the referee: every `_check` still reports (all
## failures in one run, not just the first), and `_init()` refuses to print PASS
## or exit 0 when any of them failed. `_check` now also RETURNS whether it
## passed, so the few sites that index a Dictionary right after proving the key
## exists can `continue` instead of erroring on a missing key.
var _failed := false


func _check(cond: bool, msg: String) -> bool:
	if cond:
		return true
	push_error("FAIL: " + msg)
	_failed = true
	return false


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(parsed is Dictionary, "invalid JSON: " + path):
		return {}
	return parsed


func _test_items_exact() -> void:
	var items: Array = _load("res://data/items.json")["items"]
	var seen := {}
	for item: Dictionary in items:
		var id := String(item["id"])
		seen[id] = true
		if not _check(EXPECTED_ITEMS.has(id), "item %s has no pinned expectation -- add it to EXPECTED_ITEMS" % id):
			continue
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
		if not _check(EXPECTED_SKILLS.has(id), "skill %s has no pinned expectation -- add it to EXPECTED_SKILLS" % id):
			continue
		_check(
			WIEffectText.skill_effect_lines(skill) == EXPECTED_SKILLS[id],
			"skill %s lines: got %s want %s" % [id, WIEffectText.skill_effect_lines(skill), EXPECTED_SKILLS[id]]
		)
	for id: String in EXPECTED_SKILLS:
		_check(seen.has(id), "EXPECTED_SKILLS lists %s but it is not in skills.json" % id)


func _test_field_skills_exact() -> void:
	var skills: Array = _load("res://data/skills.json")["skills"]
	var seen := {}
	for skill: Dictionary in skills:
		var id := String(skill["id"])
		seen[id] = true
		var field_lines := WIEffectText.field_effect_lines(skill)
		if EXPECTED_FIELD_SKILLS.has(id):
			_check(
				field_lines == EXPECTED_FIELD_SKILLS[id],
				"skill %s FIELD lines: got %s want %s" % [id, field_lines, EXPECTED_FIELD_SKILLS[id]]
			)
		# Catalog-wide silence: no shipped Skill speaks combat phrasing in the
		# field today. A new effect type that belongs out on the map gets its own
		# EXPECTED_FIELD_SKILLS row AND a deliberate omission from
		# WIEffectText._COMBAT_ONLY_EFFECT_TYPES; until then this is the tripwire.
		_check(
			field_lines.is_empty(),
			"skill %s leaks a combat phrase into the field readout: %s" % [id, field_lines]
		)
	for id: String in EXPECTED_FIELD_SKILLS:
		_check(seen.has(id), "EXPECTED_FIELD_SKILLS lists %s but it is not in skills.json" % id)

	# The dual-context four -- the shipped defect was these four rendering their
	# combat line on the exploration hotbar. Pin BOTH halves: the field composer
	# is silent, the combat composer is byte-identical to EXPECTED_SKILLS.
	for id: String in ["sneak", "invisibility", "double_step", "flash_step"]:
		for skill: Dictionary in skills:
			if String(skill["id"]) != id:
				continue
			_check(WIEffectText.field_effect_lines(skill).is_empty(), "%s must be field-silent" % id)
			_check(
				WIEffectText.skill_effect_lines(skill) == EXPECTED_SKILLS[id],
				"%s combat line must be untouched by the field split" % id
			)

	# Tripwires: cost prefixes never reach the field, and a non-combat effect
	# type (one deliberately absent from _COMBAT_ONLY_EFFECT_TYPES) still speaks.
	_check(
		WIEffectText.field_effect_lines({"ap_cost": 2, "mp_cost": 3, "effect": {"type": "move_pool_bonus", "amount": 3}}).is_empty(),
		"field tripwire: a costed move_pool_bonus is silent out of combat"
	)
	_check(
		WIEffectText.field_effect_lines({"ap_cost": 4, "effect": {}}).is_empty(),
		"field tripwire: a cost with no effect block never composes a bare cost line"
	)
	_check(
		WIEffectText.field_effect_lines({"effect": {"type": "not_a_combat_type"}}).is_empty(),
		"field tripwire: an unknown effect type yields no phrase, so no line"
	)


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


## GH#337 ruling 5. A cooldown is a COMBAT resource of the same class as AP and
## MP, so the card is allowed to say it -- the opaque-until-sleep lock governs
## PROGRESSION text. The clause is generated from the record (never hand-composed
## at a call site), and it has to be true to the ABSOLUTE-stamp semantics: `round
## + N` means unusable for N rounds counting the one it was used in.
func _test_cooldown_clause() -> void:
	_check(WIEffectText.cooldown_clause(0) == "Once per round.", "a non-positive count degrades to the tightest true statement")
	_check(WIEffectText.cooldown_clause(1) == "Once per round.", "N=1 only forbids a second cast inside the same turn")
	_check(WIEffectText.cooldown_clause(2) == "Once every 2 rounds.", "N=2 is the every-other-turn rhythm the milestone is for")
	_check(WIEffectText.cooldown_clause(3) == "Once every 3 rounds.", "cooldown clause tripwire: the count moves")
	var cd_skill := {"ap_cost": 3, "effect": {"type": "damage_mult", "mult": 2.0}}
	_check(WIEffectText.skill_effect_lines(cd_skill) == ["3 AP — ×2 damage"], "no cooldown_rounds row: byte-identical to before GH#337")
	cd_skill["cooldown_rounds"] = 0
	_check(WIEffectText.skill_effect_lines(cd_skill) == ["3 AP — ×2 damage"], "an explicit 0 is still no clause")
	cd_skill["cooldown_rounds"] = 2
	_check(
		WIEffectText.skill_effect_lines(cd_skill) == ["3 AP — ×2 damage. Once every 2 rounds."],
		"the clause rides the once_per_fight idiom, appended to the generated line"
	)
	cd_skill["effect"]["applies"] = {"weakened": {"duration_rounds": 2}}
	_check(
		WIEffectText.skill_effect_lines(cd_skill) == ["3 AP — ×2 damage. Weakens. Once every 2 rounds."],
		"status verb first, cooldown after -- effect then restriction"
	)
	cd_skill["effect"].erase("applies")
	cd_skill["once_per_fight"] = true
	_check(
		WIEffectText.skill_effect_lines(cd_skill) == ["3 AP — ×2 damage. Once every 2 rounds. Once per fight."],
		"the two restrictions stay distinct concepts (spec ruling 4) and both speak"
	)
	# The LIVE half, for a slot cooling right now.
	_check(WIEffectText.cooldown_recovering_line(0) == "", "a ready slot says nothing")
	_check(WIEffectText.cooldown_recovering_line(-1) == "", "a negative count says nothing")
	_check(WIEffectText.cooldown_recovering_line(1) == "Recovering — ready next round.", "one round left names the round, not a bare 1")
	_check(WIEffectText.cooldown_recovering_line(2) == "Recovering — ready in 2 rounds.", "recovering-line tripwire: the count moves")


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


## GH#334 note 28 item 3 + ruling 5. The meal-use toast restates the payload the
## next fight will actually apply, composed off the LIVE `pending_meal` dict --
## so it must share the item card's "Next fight:" phrasebook, not carry a second
## one that drifts the first time either is edited.
func _test_pending_meal_line() -> void:
	_check(WIEffectText.pending_meal_line({}) == "", "an empty armed dict phrases nothing")
	_check(
		WIEffectText.pending_meal_line({"hp_mod": 2}) == "+2 HP in your next fight.",
		"single-mod meal line tripwire"
	)
	_check(
		WIEffectText.pending_meal_line({"damage_mod": 1, "hp_mod": 2, "damage_reduction": 3})
			== "+1 damage, +2 HP, reduces hits by 3 in your next fight.",
		"merged meal line keeps card order (damage, HP, reduction) and the card's own wording"
	)
	# The card and the toast read the same bits, in the same order, from the same
	# function -- this is the drift tripwire for that sharing.
	_check(
		WIEffectText.next_fight_bits({"damage_mod": 1, "hp_mod": 2})
			== WIEffectText.next_fight_bits({"hp_mod": 2, "damage_mod": 1}),
		"bit ORDER is the formatter's, never the incoming dict's key order"
	)
	_check(
		WIEffectText.item_effect_lines({"use_effect": {"next_fight": {"damage_mod": 1, "hp_mod": 2}}})
			== ["Next fight: +1 damage, +2 HP (single use)"],
		"the item card still composes from the shared bits"
	)
	# Non-positive mods are not phrased at all (nothing in data authors them
	# today; a future negative would need its own deliberate wording).
	_check(WIEffectText.pending_meal_line({"hp_mod": 0}) == "", "a zero mod phrases nothing")
