extends SceneTree
## M-LEGIBILITY L1: exact-string coverage for WIEffectText over the FULL shipped
## catalogs, plus the data-drift tripwires and a forbidden-vocabulary grep.
## Every shipped item + Skill + status is pinned; an id present in data but
## absent from the expected maps is a hard failure, so new content forces a
## deliberate line here (no silent drift).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_effect_text.gd

# Forbidden player-string vocabulary (M-LEGIBILITY Global Constraints): raw
# attributes as whole words. Percentages-toward are caught by the '%' scan.
const _FORBIDDEN_ATTR := "(?i)\\b(str|dex|con|int|wis|cha)\\b"

const EXPECTED_ITEMS := {
	"rusty_sword": [],
	"relcs_spare_spear": ["+1 damage on melee hits"],
	"crude_blade": [],
	"chipped_spear": [],
	"solid_oak_spear": [],
	"leather_jerkin": ["+4 HP", "Worth 24 gold"],
	"watch_issue_gambeson": ["Reduces every hit taken by 1"],
	"traveler_charm": ["+2 HP", "Worth 5 gold"],
	"gnollish_hunting_knife": ["+1 damage on melee hits", "Worth 15 gold"],
	"wool_lined_cloak": ["+3 HP", "Worth 18 gold"],
}

const EXPECTED_SKILLS := {
	"basic_cleaning": [],
	"basic_swordwork": ["+5 to hit"],
	"tough_body": ["+10 max HP"],
	"power_strike": ["3 AP — ×2 damage"],
	"counter_strike": ["Strike back for ×0.8 damage when hit in melee."],
	"battle_momentum": ["+1 AP when you down a foe"],
	"flame_bolt": ["2 AP — damage 1d6 at range 4"],
	"flame_jet": ["2 AP, 4 MP — damage everything in a line 4 cells long"],
	"frost_bolt": ["1 AP, 2 MP — damage 1d6 at range 4. Slows."],
	"mana_shield": ["Spend MP to absorb incoming damage."],
	"quick_cast": ["Your first spell each turn costs 1 less AP."],
	"light": [],
	"quick_movement": ["+1 move cell"],
	"second_wind": ["2 AP — restore 8 HP"],
	"dangersense": [],
	"piercing_strikes": ["2 AP — ×1.4 damage"],
	"quick_slash": ["1 AP — ×0.7 damage"],
	"flash_cut": ["2 AP — ×1.4 damage"],
	"devastating_slash": ["4 AP — ×2.6 damage"],
	"triple_thrust": ["3 AP — ×2 damage"],
	"extended_sweep": ["2 AP — ×1.3 damage"],
	"spear_flurry": ["4 AP — ×2.6 damage"],
	"ice_shard": ["2 AP, 3 MP — damage 1d8 at range 4"],
	"icy_floor": ["2 AP, 4 MP — freeze the floor (range 3, radius 1) for 2 rounds. Slows."],
	"flame_scythe": ["2 AP, 4 MP — damage 1d10 at range 1"],
	"flare_burst": ["1 AP, 2 MP — damage 1d6 at range 3"],
	"keener_edge": ["2 AP — ×1.6 damage"],
	"lesser_stamina": [],
	"basic_cooking": [],
	"lesser_strength": [],
	"observe": [],
	"battlefield_awareness": ["+1 move cell"],
	"soothe_clientele": [],
	"unerring_aim": [],
	"sweep_the_tables": [],
	"servers_prescience": [],
	"charming_smile": [],
	"calming_touch": ["2 AP — damage 1d3 at range 1. Slows."],
	"raskghar_maul": ["3 AP — damage 1d11 at range 2. Slows."],
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


func _test_tripwires() -> void:
	# Items: the number is READ from the dict, never a literal.
	_check(WIEffectText.item_effect_lines({"hp_mod": 4}) == ["+4 HP"], "item hp tripwire base")
	_check(WIEffectText.item_effect_lines({"hp_mod": 7}) == ["+7 HP"], "item hp tripwire moved")
	_check(WIEffectText.item_effect_lines({"damage_mod": 9}) == ["+9 damage on melee hits"], "item damage tripwire")

	# Skills: mutating the effect dict moves the die/range in the line.
	var spell := {"ap_cost": 1, "mp_cost": 2, "effect": {"type": "spell_damage", "die": 6, "range": 4}}
	_check(WIEffectText.skill_effect_lines(spell) == ["1 AP, 2 MP — damage 1d6 at range 4"], "skill spell tripwire base")
	spell["effect"]["die"] = 9
	spell["effect"]["range"] = 2
	_check(WIEffectText.skill_effect_lines(spell) == ["1 AP, 2 MP — damage 1d9 at range 2"], "skill spell tripwire moved")

	# Status: the penalty is derived from the injected catalog, not hardcoded.
	var catalog := [{"id": "x", "effect": {"type": "spell_damage", "applies": {"slowed": {"pool_penalty": 5}}}}]
	_check(
		WIEffectText.status_line("slowed", catalog) == "Slowed — moves 5 fewer cells next turn (min 1).",
		"status tripwire: penalty follows the catalog"
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
	for line: String in lines:
		_check(attr.search(line) == null, "forbidden attribute token in generated line: %s" % line)
		_check(not line.contains("%"), "forbidden percent-toward token in generated line: %s" % line)
