extends SceneTree
## exact-string coverage for WIEffectText over the FULL shipped
## catalogs, plus the data-drift tripwires and a forbidden-vocabulary grep.
## Every shipped item + Skill + status is pinned; an id present in data but
## absent from the expected maps is a hard failure, so new content forces a
## deliberate line here (no silent drift).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_effect_text.gd

# Forbidden player-string vocabulary (global constraint): raw
# attributes as whole words. Percentages-toward are caught by the '%' scan.
const _FORBIDDEN_ATTR := "(?i)\\b(str|dex|con|int|wis|cha)\\b"

const EXPECTED_ITEMS := {
	# Issue #79: every weapon's own `weapon_family` now states the kit
	# consequence ("<Family> kit replaces other weapon Skills in combat") --
	# the same line for every weapon of that family, sword/spear/bow.
	"rusty_sword": ["Sword kit replaces other weapon Skills in combat"],
	"relcs_spare_spear": ["+1 damage on melee hits", "Spear kit replaces other weapon Skills in combat"],
	"crude_blade": ["Sword kit replaces other weapon Skills in combat"],
	"chipped_spear": ["Spear kit replaces other weapon Skills in combat"],
	"solid_oak_spear": ["Spear kit replaces other weapon Skills in combat"],
	"leather_jerkin": ["+4 HP", "Worth 24 gold"],
	# Now priced (previously fixture/harness-only, no live buy
	# path) -- sold at the new street `peddler_stall`.
	"watch_issue_gambeson": ["Reduces every hit taken by 1", "Worth 20 gold"],
	# traveler_charm is the plan's entry enchanted item,
	# resonance 1 -- the formatter's "Resonance N" line (effect_text.gd,
	# already wired) joins its card between the
	# hp line and the price line.
	"traveler_charm": ["+2 HP", "Resonance 1", "Worth 5 gold"],
	"gnollish_hunting_knife": ["+1 damage on melee hits", "Sword kit replaces other weapon Skills in combat", "Worth 15 gold"],
	"wool_lined_cloak": ["+3 HP", "Worth 18 gold"],
	# The 9 new items (7 accessories, 2 tools).
	"copper_luck_band": ["+1 HP", "Worth 4 gold"],
	"hedge_ward_charm": ["+2 HP", "Resonance 1", "Worth 9 gold"],
	"hunters_fang_talisman": ["+1 damage on melee hits", "Resonance 1", "Worth 14 gold"],
	"phosphor_pendant": ["+3 HP", "Resonance 1"],
	"stonescale_talisman": ["Reduces every hit taken by 1", "Resonance 2", "Worth 35 gold"],
	"moon_bone_amulet": ["+1 damage on melee hits", "+3 HP", "Resonance 2"],
	"watch_token": [],
	# brothers_marker: watch_token precedent shape verbatim (mundane
	# accessory, zero stat fields -- items.json's own _comment).
	"brothers_marker": [],
	"field_whetstone": ["Worth 5 gold"],
	"fishers_handline": ["Worth 4 gold"],
	# The 5 Runner's Guild delivery parcels -- inert carried
	# flavor by design (no combat fields, no price), so their cards carry
	# name + description only, zero generated effect lines.
	"parcel_plains_wool": [],
	"parcel_that_ticks": [],
	"parcel_watch_dispatch": [],
	"parcel_lamp_phials": [],
	"parcel_bluefruit_hamper": [],
	# 5 more Runner's Guild delivery parcels (issue #72's generated
	# delivery-pool growth) -- same inert-carried shape as the 5 above.
	"parcel_gambeson_bundle": [],
	"parcel_ledger_transfer": [],
	"parcel_tactics_brief": [],
	"parcel_sealed_letter": [],
	"parcel_seed_grain": [],
	# The kitchen's dish (issue #59) -- same inert-carried shape as the
	# parcels: no combat fields, deliberately NO price (structurally
	# unsellable), so name + description only.
	"hot_meal": [],
	# Cups' favor-carry chit (GH#68 TALK stage 2) -- the parcel shape:
	# no combat fields, no price (structurally unsellable), name +
	# description only.
	"cups_debt_chit": [],
	# Issue #81 (exploration & optional content): Renn's carry-back-to-owner
	# item + the lore-note collectible thread, all the SAME inert parcel
	# shape (no combat fields, no price).
	"renns_warhammer": [],
	"note_watch_veteran": [],
	"note_sewer_surveyor": [],
	"note_old_dread": [],
	# Krshia's attunement catalyst (priced tool, no combat fields).
	"resonant_catalyst": ["Worth 35 gold"],
	# The beat-3 recovery item -- inert
	# carried flavor by design (no combat fields, no price, kind "tool" per
	# the parcel/field_whetstone precedent), so its card carries name +
	# description only, zero generated effect lines.
	"anchor_stone": [],
	# 8b R3 (issue #11) witch-cottage vendor stock -- herb-craft consumables,
	# inside the shipped accessory envelope (copper_luck_band/hedge_ward_charm's
	# own hp_mod/resonance bounds).
	"dried_yarrow_bundle": ["Worth 4 gold"],
	"sleeproot_draught": ["Worth 5 gold"],
	"hollow_herb_sachet": ["+1 HP", "Worth 6 gold"],
	"witch_wardstone_bead": ["+2 HP", "Resonance 1", "Worth 16 gold"],
	# Issue #65: the post-Riverfarm Invrisil attunement purchase -- priced
	# tool, no combat fields, same shape as resonant_catalyst's card.
	"invrisil_attunement_stone": ["Worth 18 gold"],
	# 8e Phase C (issue #16): the Pallass attunement purchase --
	# invrisil_attunement_stone's exact twin, same priced-tool-no-combat-
	# fields shape.
	"pallass_attunement_stone": ["Worth 18 gold"],
	# GH#70 [Archer]: the two bows. `range` (4, > 1) earns the "Range 4" line;
	# damage_mod (hunting_bow only) reads "ranged hits" instead of "melee
	# hits" (effect_text.gd's own range-aware branch).
	"training_bow": ["Range 4", "Bow kit replaces other weapon Skills in combat", "Worth 8 gold"],
	"hunting_bow": ["+1 damage on ranged hits", "Range 4", "Bow kit replaces other weapon Skills in combat", "Worth 18 gold"],
	# 8d C1 (issue #14): the trapped_halls SKILL route's coin cost --
	# priced tool, no combat fields, same shape as field_whetstone's card.
	"trap_kit": ["Worth 3 gold"],
	# Class-foundation pass R5 (2026-07-12): the [Bargain] price_mod's own
	# real dynamic-priced buy option at Eloise's shop -- all-zero mods, same
	# priced-tool-no-combat-fields shape as field_whetstone/fishers_handline.
	"warding_salt_pinch": ["Worth 7 gold"],
}

const EXPECTED_SKILLS := {
	"basic_cleaning": [],
	"basic_swordwork": ["+5 to hit"],
	"tough_body": ["+10 max HP"],
	"power_strike": ["3 AP — ×2 damage"],
	"counter_strike": ["Strike back for ×0.8 damage when hit in melee."],
	"battle_momentum": ["+1 AP when you down a foe"],
	# GH#90 rider: `applies.burning` -- the "Burns." verb suffix (`_STATUS_VERB`).
	"flame_bolt": ["2 AP — damage 1d6 at range 4. Burns."],
	"flame_jet": ["2 AP, 4 MP — damage everything in a line 4 cells long"],
	"frost_bolt": ["1 AP, 2 MP — damage 1d6 at range 4. Slows."],
	"mana_shield": ["Spend MP to absorb incoming damage."],
	"quick_cast": ["Your first spell each turn costs 1 less AP."],
	"light": [],
	"frost_touch": [],
	"kindle": [],
	# [Stealth]'s combat read is a genuine ACTIVE cast
	# (ap_cost 1) -- effect_text.gd's `_effect_phrase` now un-suppresses
	# `move_pool_bonus` specifically for ap_cost > 0 (WISkillEffects.
	# resolve_active wires a real self-buff resolver for exactly that shape).
	# quick_movement/battlefield_awareness below are UNCHANGED (still ap_cost
	# 0, still no resolver, still SUPPRESSED) -- see effect_text.gd's own
	# comment on the ap_cost gate for why the two don't get un-suppressed too.
	"sneak": ["1 AP — +2 move cells this turn"],
	# WIRED -- [Invisibility]'s combat read
	# (a self-cast untargetable status; see skill_effects.gd's
	# `_resolve_invisibility` and skills.json's own _comment). The field-only
	# seam this skill also carries (`sneaks: true`) is completely unaffected.
	"invisibility": ["1 AP, 3 MP — become impossible to target for 3 rounds (breaks if you deal damage)"],
	# WIRED -- wi_combat.gd's `_start_turn` gained a real
	# `_move_pool_bonus_total` passive consumer for the two PRE-EXISTING
	# 0-cost move_pool_bonus skills (quick_movement, battlefield_awareness
	# below); the standing-bonus phrasing is distinct from [Stealth]'s
	# single-turn cast line above (see effect_text.gd's own comment).
	"quick_movement": ["+1 move cell every turn"],
	# WIRED -- skill_effects.gd's `resolve_active` gained
	# a real heal resolver (self-only; see its doc comment). dangersense
	# stays a confirmed, intentional no-op (no clean currency read --
	# see effect_text.gd's `_effect_phrase` doc comment) -- NOT part of this
	# task's four wiring items, unchanged.
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
	# WIRED -- WISkillEffects.resolve_active gained a real icy_floor
	# resolver, so effect_text.gd generates the real card line (radius=1 ->
	# 3x3 patch, range 3, duration_rounds 2, `applies.slowed` -> the "Slows."
	# suffix).
	"icy_floor": ["2 AP, 4 MP — glaze a 3×3 patch of ground at range 3 for 2 rounds. Slows."],
	"flame_scythe": ["2 AP, 4 MP — damage 1d6 at range 1"],
	"flare_burst": ["1 AP, 2 MP — damage 1d6 at range 3"],
	# GH#71 -- WISkillEffects.resolve_active gained a real blast_damage
	# resolver (skill_effects.gd's `_resolve_blast_damage`); radius=1 -> 3x3
	# area, die is the caster's own weapon_die (pc's is 6, same source as
	# every spell_damage line above), no `applies` rider so no trailing
	# "Slows."-style suffix -- the friendly-fire sentence is baked into the
	# phrase itself instead.
	"flame_pillar": ["3 AP, 5 MP — blast a 3×3 area around the target for 1d6. Hits friend and foe."],
	# Issue #82's WINDUP SIM SPEC: the first `windup_rounds`-carrying skill --
	# same blast_damage phrase shape as flame_pillar above, PLUS the literal
	# timing clause (`effect.windup_rounds > 0`) inserted before the period.
	# Die still reads the "pc" default (6) -- vault_construct is enemy-only
	# and this card never renders in any live UI, the SAME disclosed
	# raskghar_maul/calming_touch caster-attribution gap noted above (no
	# per-caster threading exists in this formatter).
	# GH#90 rider: `applies.rooted` -- the "Roots." verb suffix, appended
	# after the friendly-fire sentence (line already ends with ".").
	"slam": ["4 AP — blast a 3×3 area around the target for 1d6 after a round's gathering. Hits friend and foe. Roots."],
	"keener_edge": ["2 AP — ×1.6 damage"],
	# GH#61: [Spellsword] L16 capstone (INVENTED name, flagged -- see the
	# skill's own _comment in skills.json for the wiki-verification trace).
	# The only damage_mult skill in the catalog that also spends MP --
	# `_cost_prefix` joins both currencies exactly like a spell_damage line
	# would (see frost_bolt above), then `_effect_phrase`'s damage_mult arm
	# renders the mult unchanged.
	"spellbound_strike": ["4 AP, 3 MP — ×3 damage"],
	"lesser_stamina": [],
	"basic_cooking": [],
	"lesser_strength": [],
	"observe": [],
	# WIRED (same passive as quick_movement above).
	"battlefield_awareness": ["+1 move cell every turn"],
	"soothe_clientele": [],
	"unerring_aim": [],
	"sweep_the_tables": [],
	"servers_prescience": [],
	"charming_smile": [],
	# The die is now the CASTER's weapon_die (honest source,
	# see effect_text.gd's _caster_weapon_die), not the deleted vestigial
	# effect.die -- every one of these reads the "pc" default (weapon_die 6 in
	# the shipped combatants.json), including raskghar_maul: it's cast by
	# raskghar_awakened (weapon_die 9) in the sim, never the PC, but this
	# formatter has no per-caster attribution and the record is never rendered
	# in any UI (enemy-only skill) -- disclosed in the L5 report, not fixed
	# further (would need real caster-threading, out of this task's data-only
	# scope).
	"calming_touch": ["2 AP — damage 1d6 at range 1. Slows."],
	# GH#90 rider: `applies.weakened` added alongside slowed -- `_status_suffix`
	# joins BOTH verbs, dict insertion order (slowed first, weakened second).
	"raskghar_maul": ["3 AP — damage 1d6 at range 2. Slows. Weakens."],
	# GH#70 [Archer] kit -- all three existing effect TYPES (damage_mult twice,
	# line_damage once), zero new resolvers, so the phrasing matches their
	# sword/spear twins exactly (power_strike/quick_slash/triple_thrust's own
	# lines above).
	"power_shot": ["3 AP — ×2 damage"],
	"quick_nock": ["1 AP — ×0.7 damage"],
	"piercing_shot": ["3 AP — damage everything in a line 4 cells long"],
	# [Keen Eye]: field-only, no combat effect -- same empty card as
	# basic_cleaning/observe above.
	"keen_eye": [],
	# Class-foundation pass R1 (2026-07-12): the stagnant trio's ladders +
	# Sharpshooter's grants. See each skill's own _comment in skills.json for
	# the wiki-verification trace.
	"directed_strike": ["2 AP — ×1.6 damage"],
	# Passive, 0 ap_cost -- the STANDING per-turn phrasing (same branch as
	# quick_movement/battlefield_awareness above).
	"flanking_step": ["+1 move cell every turn"],
	"read_the_field": ["+10 to hit"],
	# Field-only, no combat effect -- same empty card as measured_words'
	# own field siblings (charming_smile/observe/keen_eye above).
	"measured_words": [],
	# WIRED -- WISkillEffects._resolve_heal widened for `effect.ally_target`
	# (see that function's own doc comment); the phrase reads "an ally, or
	# yourself" instead of second_wind's "yourself" alone.
	"soothing_presence": ["2 AP, 3 MP — restore 6 HP to an ally, or yourself"],
	# GH#90 support_skill carrier + guarded rider: heal's `applies` widening
	# (skill_effects.gd's `_resolve_heal`) appends "Guards." exactly like a
	# damage skill's own `_status_suffix` would -- the same shared function.
	"guarding_ward": ["2 AP — restore 4 HP to an ally, or yourself. Guards."],
	"open_doors": [],
	"find_trap": [],
	"disarm_trap": [],
	# ONCE per fight (WIKeys.ONCE_PER_FIGHT) -- the trailing sentence is the
	# skill-level suffix `skill_effect_lines` appends (distinct from
	# `_status_suffix`, which reads the EFFECT dict; see that function's own
	# comment).
	"sudden_strike": ["2 AP — ×1.8 damage. Once per fight."],
	"called_shot": ["3 AP — ×2.2 damage"],
	"piercing_volley": ["4 AP — damage everything in a line 5 cells long"],
	# R2 (issue #96's own content-gap fix): frost_bolt's fire twin, same
	# spell_damage phrase shape, no `applies` rider (frost_bolt slows, this
	# doesn't) -- die is the caster's own weapon_die per _caster_weapon_die's
	# default (pc, 6), same source every other spell_damage line above reads.
	"flame_dart": ["2 AP, 3 MP — damage 1d6 at range 4"],
	# R4 ([Innkeeper]/[Ranger] consolidations): perfect_hospitality is
	# field-only, no combat effect -- same empty card as measured_words/
	# open_doors/find_trap/disarm_trap above (its real mechanism is the
	# interact()-level wage bump, not a card-rendered effect).
	"perfect_hospitality": [],
	# steady_draw: hit_bonus, 0 ap_cost passive (the basic_swordwork/
	# read_the_field phrasing) -- weapon-gated to bow, invisible to the
	# card text (WIEffectText never renders `weapon`).
	"steady_draw": ["+8 to hit"],
	# R5 ([Trader]/[Merchant]): bargain/bulk_terms are pure passive identity
	# traits (no `effect` key at all -- same empty card as lesser_stamina/
	# lesser_strength above); appraise_goods is field-only, no combat
	# effect (same empty card as keen_eye/observe).
	"bargain": [],
	"appraise_goods": [],
	"bulk_terms": [],
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
	# Single-arg form reads the SHIPPED skills.json penalty (currently 2).
	_check(
		WIEffectText.status_line("slowed") == "Slowed — moves 2 fewer cells next turn (min 1).",
		"slowed glossary line: got %s" % WIEffectText.status_line("slowed")
	)
	_check(WIEffectText.status_line("nonexistent") == "", "unknown status yields empty string")
	# Single-arg form reads the SHIPPED skills.json duration_rounds (currently 3).
	_check(
		WIEffectText.status_line("invisible") == "Invisible — enemies can't choose you as a target; breaks if you deal damage, or fades after 3 rounds.",
		"invisible glossary line: got %s" % WIEffectText.status_line("invisible")
	)
	# GH#90: the four new statuses -- single-arg form reads the SHIPPED
	# skills.json riders (raskghar_maul's weakened duration_rounds=2,
	# guarding_ward's guarded duration_rounds=2, slam's rooted
	# duration_rounds=1, flame_bolt's burning tick_damage=2/duration_rounds=3).
	# The ×0.75 multiplier reads straight off WICombat's own const, not a
	# re-typed literal.
	# GH#90 TUNING: both riders' duration_rounds are floored at 1 (the
	# round-purge floor -- raskghar_maul's/guarding_ward's own TUNING notes
	# in skills.json), hence the singular "round".
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
	# Items: the number is READ from the dict, never a literal.
	_check(WIEffectText.item_effect_lines({"hp_mod": 4}) == ["+4 HP"], "item hp tripwire base")
	_check(WIEffectText.item_effect_lines({"hp_mod": 7}) == ["+7 HP"], "item hp tripwire moved")
	_check(WIEffectText.item_effect_lines({"damage_mod": 9}) == ["+9 damage on melee hits"], "item damage tripwire")
	# GH#70: `range > 1` earns its own line AND flips the damage phrasing to
	# "ranged hits" -- both numbers READ from the dict, never literals.
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

	# Skills: mutating effect.range moves the range in the line. effect.die is
	# VESTIGIAL (wi_combat.gd never reads it -- it rolls the
	# CASTER's own weapon_die for every hit, melee or spell alike) and is
	# IGNORED even if present; the die instead follows the caster catalog.
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

	# Opus final-review M3: dedicated moves-when-data-moves proofs for the four
	# sources previously covered only by EXPECTED_SKILLS' pin diversity.
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

	# Status: the penalty is derived from the injected catalog, not hardcoded.
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

	# GH#90: the four new statuses' duration/tick numbers are READ from the
	# injected catalog, not hardcoded (the slowed/invisible tripwire pattern
	# above, generalized).
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
	# GH#90: the four new statuses join the same grep.
	lines.append(WIEffectText.status_line("weakened"))
	lines.append(WIEffectText.status_line("guarded"))
	lines.append(WIEffectText.status_line("rooted"))
	lines.append(WIEffectText.status_line("burning"))
	for line: String in lines:
		_check(attr.search(line) == null, "forbidden attribute token in generated line: %s" % line)
		_check(not line.contains("%"), "forbidden percent-toward token in generated line: %s" % line)
