extends SceneTree
## #514: the #495 damage rule and the #494 trueing rule, through real code paths.
## Arms resolve in a real WICombat with a one-sided die and a sure hit, so each
## number is exact. Trueing runs Hedault's own dialogue swap; old saves go through
## WISave.apply.

const ARENA := {
	"id": "gear_rules", "grid": {"width": 8, "height": 3}, "blocked": [],
	"player_spawns": [[1, 1]], "enemy_spawns": [[2, 1], [3, 1]],
}
## str 20 / int 6, die 1, weapon damage 3, spell power 2:
## weapon hit = 20/2 + 1 + 3 = 14; spell hit = 6/2 + 1 + 2 = 6.
const WEAPON_HIT := 14
const SPELL_HIT := 6

var _events: Array = []
var _skills_cfg: Dictionary = {}
var _skills_by_id: Dictionary = {}


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload.duplicate(true)})


func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load("res://data/skills.json"), _sink, 21, {
		"items": _load("res://data/items.json"), "classes": _load("res://data/classes.json"),
		"arenas": _load("res://data/arenas.json"), "combatants": _load("res://data/combatants.json"),
		"progression": _load("res://data/progression.json"),
		"dialogue": {"hedault_enchanting": _load("res://data/dialogue/hedault_enchanting.json")}})


func _pc(skills: Array) -> Dictionary:
	return {"id": "pc", "display_name": "PC", "side": "player",
		"stats": {"str": 20, "dex": 40, "con": 10, "int": 6, "wis": 0, "cha": 0},
		"weapon_die": 1, "ai": "", "skills": skills, WIKeys.DAMAGE_MOD: 3, WIKeys.SPELL_POWER: 2}


func _dummy(id: String) -> Dictionary:
	return {"id": id, "display_name": "Dummy", "side": "enemy",
		"stats": {"str": 0, "dex": 0, "con": 1000, "int": 0, "wis": 0, "cha": 0},
		"weapon_die": 1, "ai": "melee", "skills": ["counter_strike"]}


func _fight(skill_id: String) -> WICombat:
	var kit: Array = [] if skill_id == "" else [skill_id]
	var combat := WICombat.new(ARENA, [_pc(kit), _dummy("dummy_a"), _dummy("dummy_b")], _skills_cfg, _sink, 3)
	combat.combatants["pc"]["hit_bonus"] = 100
	combat.combatants["pc"][WIKeys.MP] = 50
	combat.begin()
	assert(combat.get_active() == "pc", "the probe PC acts first")
	combat.combatants["pc"][WIKeys.AP] = 20
	_events.clear()
	return combat


func _first_hit() -> Dictionary:
	for e: Dictionary in _events:
		if e["type"] == WIEvents.ATTACK_RESOLVED and String(e["payload"]["attacker"]) == "pc":
			return e["payload"]
	return {}


func _reacted() -> bool:
	return _events.any(func(e: Dictionary) -> bool: return e["type"] == WIEvents.REACTION_TRIGGERED)


func _init() -> void:
	WITestWatchdog.arm(self)
	_skills_cfg = _load("res://data/skills.json")
	for s: Dictionary in _skills_cfg[WIKeys.SKILLS]:
		_skills_by_id[String(s[WIKeys.ID])] = s
	_check_classifier()
	_check_arms()
	_check_build_and_reach()
	_check_trueing()
	_check_old_saves()
	print("PASS test_gear_rules")
	quit(0)


func _check_classifier() -> void:
	var expect := {
		"crescent_cut": "weapon", "pierce_thrust": "weapon", "piercing_shot": "weapon", "piercing_volley": "weapon",
		"flame_jet": "spell", "phantom_barrage": "innate", "frost_bolt": "spell", "evil_eye": "spell",
		"raskghar_maul": "innate", "flame_bolt": "innate", "lich_grave_lance": "innate",
		"calming_touch": "spell", "flame_pillar": "spell", "slam": "weapon", "power_strike": "weapon",
		"spellbound_strike": "weapon", "counter_strike": "weapon", "second_wind": "", "icy_floor": "",
	}
	for id: String in expect:
		assert(WICombatBuild.damage_source(_skills_by_id[id]) == expect[id], "%s classifies as %s" % [id, expect[id]])
	# Every shipped spell/line/blast arm: weapon exactly when it carries a weapon
	# gate. Of the rest, a Skill no class or item can give the player is innate
	# (spell power is player gear, so its card must not promise "spell damage"),
	# and the one player-held innate arm is the Tactician's illusory barrage.
	var reachable := {}
	_collect_ids(_load("res://data/classes.json"), reachable)
	for it: Dictionary in _load("res://data/items.json")["items"]:
		for ability: Variant in (it.get(WIKeys.ABILITIES, []) as Array):
			reachable[String(ability)] = true
	for id: String in _skills_by_id:
		var skill: Dictionary = _skills_by_id[id]
		var effect_type := String((skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.TYPE, ""))
		var innate := String(skill.get(WIKeys.DAMAGE_SOURCE, "")) == WICombatBuild.SOURCE_INNATE
		if skill.has(WIKeys.DAMAGE_SOURCE):
			assert(innate, "%s: the only authored damage_source is innate" % id)
		if not (effect_type in ["spell_damage", "line_damage", "blast_damage"]) \
				or int((skill[WIKeys.EFFECT] as Dictionary).get(WIKeys.WINDUP_ROUNDS, 0)) > 0:
			assert(not innate, "%s: innate marks only spell/line/blast arms" % id)
			continue
		if skill.has(WIKeys.WEAPON):
			assert(not innate and WICombatBuild.damage_source(skill) == WICombatBuild.SOURCE_WEAPON, "%s: the weapon gate decides the source" % id)
		elif not reachable.has(id):
			assert(innate, "%s is enemy-only, so it must be innate, not spell damage" % id)
		elif innate:
			assert(id == "phantom_barrage", "%s: a player-held innate arm needs a ruling" % id)
		else:
			assert(WICombatBuild.damage_source(skill) == WICombatBuild.SOURCE_SPELL, "%s takes spell power" % id)


func _collect_ids(node: Variant, out: Dictionary) -> void:
	if node is Dictionary:
		for value: Variant in (node as Dictionary).values():
			_collect_ids(value, out)
	elif node is Array:
		for value: Variant in node:
			_collect_ids(value, out)
	elif node is String and _skills_by_id.has(node):
		out[node] = true


func _check_arms() -> void:
	# Ordinary attack and a strike: unchanged weapon hits, ripostes still answer.
	var combat := _fight("")
	assert(combat.attack("dummy_a"))
	assert(int(_first_hit()["damage"]) == WEAPON_HIT, "ordinary attack: str + die + weapon damage")
	assert(_reacted(), "an ordinary melee hit still provokes [Counter Strike]")
	combat = _fight("power_strike")
	assert(combat.use_skill("power_strike", "dummy_a"))
	assert(int(_first_hit()["damage"]) == 25, "x2 strike: int((10 + 1) * 2) + 3, no spell power")

	# Weapon-gated lines: str and weapon damage now; no riposte, no melee tally.
	for skill_id: String in ["crescent_cut", "pierce_thrust", "piercing_shot", "piercing_volley"]:
		combat = _fight(skill_id)
		assert(combat.use_skill(skill_id, "right"), "%s fires down the line" % skill_id)
		var hit := _first_hit()
		assert(int(hit["damage"]) == WEAPON_HIT, "%s takes str and weapon damage (was int and nothing)" % skill_id)
		assert(not bool(hit["melee"]), "%s keeps its non-melee payload" % skill_id)
		assert(not _reacted(), "%s still never provokes a riposte" % skill_id)
		assert(not (combat.action_tally.get("pc", {}) as Dictionary).has("melee_hit"), "%s banks no melee hit" % skill_id)
		var policy := WICombatPolicies.expected_damage(combat, combat.combatants["pc"], combat.combatants["dummy_b"], 1.0, false, WICombatBuild.damage_source(_skills_by_id[skill_id]))
		assert(is_equal_approx(policy, float(WEAPON_HIT)), "the competent policy prices %s like the engine" % skill_id)

	# Spells, spell lines and blasts: int and spell power, never weapon damage.
	var spell_targets := {"frost_bolt": "dummy_a", "evil_eye": "dummy_a", "flame_jet": "right", "flame_pillar": "dummy_b"}
	for skill_id: String in spell_targets:
		combat = _fight(skill_id)
		assert(combat.use_skill(skill_id, String(spell_targets[skill_id])), "%s resolves" % skill_id)
		assert(int(_first_hit()["damage"]) == SPELL_HIT, "%s takes int and spell power" % skill_id)
		var policy := WICombatPolicies.expected_damage(combat, combat.combatants["pc"], combat.combatants["dummy_a"], 1.0, false, WICombatBuild.damage_source(_skills_by_id[skill_id]))
		assert(is_equal_approx(policy, float(SPELL_HIT)), "the competent policy prices %s like the engine" % skill_id)

	# Innate arms keep int scaling and take no gear: the barrage and enemy casts.
	for skill_id: String in ["phantom_barrage", "raskghar_maul"]:
		combat = _fight(skill_id)
		assert(combat.use_skill(skill_id, "right" if skill_id == "phantom_barrage" else "dummy_a"), "%s resolves" % skill_id)
		assert(int(_first_hit()["damage"]) == 4, "%s: int/2 + die, no spell power, no weapon damage" % skill_id)
		var innate_price := WICombatPolicies.expected_damage(combat, combat.combatants["pc"], combat.combatants["dummy_a"], 1.0, false, WICombatBuild.damage_source(_skills_by_id[skill_id]))
		assert(is_equal_approx(innate_price, 4.0), "the competent policy prices %s like the engine" % skill_id)

	# A combatant row without the field (every enemy and ally) casts as before.
	combat = _fight("frost_bolt")
	combat.combatants["pc"].erase(WIKeys.SPELL_POWER)
	_events.clear()
	assert(combat.use_skill("frost_bolt", "dummy_a"))
	assert(int(_first_hit()["damage"]) == 4, "no spell power field: int/2 + die, the pre-#514 number")


func _pc_template(game: WIGame) -> Dictionary:
	for t: Dictionary in (game._combat_config["combatants"] as Dictionary)["combatants"]:
		if String(t[WIKeys.ID]) == "pc":
			return t
	return {}


func _check_build_and_reach() -> void:
	var mods := WICombatBuild.equipment_mods({}, {}, [{WIKeys.SPELL_POWER: 1, WIKeys.DAMAGE_MOD: 0}, {WIKeys.SPELL_POWER: 2}])
	assert(int(mods[WIKeys.SPELL_POWER]) == 3 and int(mods[WIKeys.DAMAGE_MOD]) == 0, "spell power sums over worn gear")
	var game := _new_game()
	for id: String in ["graveflame_wand", "gnollish_hunting_knife"]:
		assert(game.pickup(id, "test"))
		assert(game.equip(id))
	var cfg := game._player_combatant_config(_pc_template(game))
	assert(int(cfg[WIKeys.SPELL_POWER]) == 1, "the wand's spell power reaches the live combatant")
	assert(int(cfg[WIKeys.DAMAGE_MOD]) == 1, "only the knife adds weapon damage; the wand adds none")
	var live := WICombat.new(ARENA, [cfg], game.skills_config_raw(), Callable(), 1)
	assert(int(live.combatants["pc"][WIKeys.SPELL_POWER]) == 1, "the combatant carries it into the fight")

	# Reach names exactly the Skills the player would hold with the piece worn.
	game.classes = {"swordsman": 14}
	assert(game.pickup("hunting_bow", "test"))
	var sword_reach := game.gear_reach("gnollish_hunting_knife")
	assert((sword_reach["weapon"] as Array).has("crescent_cut") and (sword_reach["weapon"] as Array).has("power_strike"))
	assert((sword_reach["spell"] as Array).is_empty(), "a pure swordsman has no spells for a wand to reach")
	var bow_reach := game.gear_reach("hunting_bow")
	assert(not (bow_reach["weapon"] as Array).has("crescent_cut"), "a bow strips the sword lines, so it cannot claim them")
	var lines := WIEffectText.gear_reach_lines(game.item("graveflame_wand"), game.gear_reach("graveflame_wand"), game.skills.values())
	assert(lines == ["Improves none of your current Skills."], "a wand on a swordsman says so: %s" % [lines])
	game.classes = {"mage": 2}
	lines = WIEffectText.gear_reach_lines(game.item("graveflame_wand"), game.gear_reach("graveflame_wand"), game.skills.values())
	assert(lines == ["Improves your [Frost Bolt], [Flame Jet] and [Flame Dart]."], "a mage's wand names its spells: %s" % [lines])
	lines = WIEffectText.gear_reach_lines(game.item("gnollish_hunting_knife"), game.gear_reach("gnollish_hunting_knife"), game.skills.values())
	assert(lines == ["Improves your attacks."], "a mage's knife reaches only attacks: %s" % [lines])


func _choice(game: WIGame, text: String) -> int:
	var rows := game.dialogue.current_options()
	for i in rows.size():
		if String(rows[i].text) == text:
			return i
	return -1


func _check_trueing() -> void:
	# The craft discount, pinned: one under the power-budget price, floor 0, and
	# never above the consumed piece.
	var discount := {"hedaults_traveler_charm": 0, "hedaults_hunters_fang": 0, "hedaults_wardstone": 1,
		"hedaults_warded_setting": 0, "hedault_trued_spear": 0}
	var game := _new_game()
	for id: String in discount:
		assert(int(game.item(id)[WIKeys.RESONANCE]) == int(discount[id]), "%s resonance %d" % [id, discount[id]])
		var source := game.item(String(game.item(id)[WIKeys.TRUED_FROM]))
		assert(int(game.item(id)[WIKeys.RESONANCE]) <= int(source[WIKeys.RESONANCE]))
	# Every trued product is exactly what one of Hedault's arms makes from its
	# `trued_from` piece, and every such arm's product is marked.
	var swaps := {}
	for opt: Dictionary in (_load("res://data/dialogue/hedault_enchanting.json")["nodes"]["hub"]["options"] as Array):
		var removed := ""
		var made := ""
		for effect: Dictionary in opt.get("effects", []):
			removed = String(effect.get("remove_item", removed))
			made = String(effect.get("item", made))
		if removed != "" and made != "":
			swaps[made] = removed
	for id: String in discount:
		assert(swaps.get(id, "") == String(game.item(id)[WIKeys.TRUED_FROM]), "%s is trued from what Hedault consumes" % id)
	for made: String in swaps:
		assert(discount.has(made), "Hedault product %s carries a pinned trueing" % made)

	# Real route: a full loadout refuses one more charm until Hedault trues one.
	game.resonance_capacity = 4
	game.gold = 100
	for id: String in ["traveler_charm", "anchor_sliver", "hedge_ward_charm"]:
		assert(game.pickup(id, "test"))
	assert(game.equip("traveler_charm") and game.equip("anchor_sliver"))
	var plan := game.equip_plan("hedge_ward_charm")
	assert(not bool(plan["ok"]) and String(plan["reason"]) == "over_capacity" and int(plan["resonance"]) == 5)
	assert(WIEffectText.equip_plan_line(plan) == "If worn: Resonance 5/4, more than you can hold")
	_events.clear()
	assert(not game.equip("hedge_ward_charm"), "over capacity: refused")
	assert(_events.any(func(e: Dictionary) -> bool: return e["type"] == WIEvents.TOAST and String(e["payload"]["text"]).contains("more Resonance than you can hold")))

	assert(game.start_dialogue("hedault_enchanting", "hedault"))
	var index := _choice(game, "The traveler's charm. Improve it. (20 gold)")
	assert(index >= 0)
	var row: Dictionary = game.dialogue.current_options()[index]
	assert((row["effect_lines"] as Array).has("Resonance 1 → 0"), "the option previews the discount: %s" % [row["effect_lines"]])
	# Cancel first: nothing is spent or swapped.
	assert(game.dialogue_choose(index))
	assert(game.purchase_cancel())
	assert(game.gold == 100 and game.inventory.has("traveler_charm") and not game.inventory.has("hedaults_traveler_charm"))
	assert(game.dialogue_choose(index))
	assert(game.purchase_confirm())
	assert(game.gold == 80 and game.inventory.has("hedaults_traveler_charm") and not game.inventory.has("traveler_charm"))
	assert(game.resonance_used() == 3, "the swap took the charm off")
	assert(game.equip("hedaults_traveler_charm"))
	assert(game.resonance_used() == 3, "the trued charm costs nothing to wear")
	assert(bool(game.equip_plan("hedge_ward_charm")["ok"]))
	assert(game.equip("hedge_ward_charm"), "the discount made room for one more piece")
	assert(game.resonance_used() == 4 and game.resonance_used() <= game.resonance_limit())


func _check_old_saves() -> void:
	var original := _new_game()
	for id: String in ["hedaults_hunters_fang", "lichbone_wand", "hedge_ward_charm"]:
		assert(original.pickup(id, "test"))
	original.resonance_capacity = 4
	# Worn under the old prices (fang 1 + wand 3 = 4/4), as a pre-#514 save holds it.
	original.equipped["accessory_1"] = "hedaults_hunters_fang"
	original.equipped["accessory_2"] = "lichbone_wand"
	var data: Dictionary = JSON.parse_string(JSON.stringify(WISave.serialize(original)))
	assert(int(data["version"]) == WISave.VERSION, "no schema change: the save version is unchanged")
	for version: int in [WISave.VERSION, 10]:
		var legacy: Dictionary = data.duplicate(true)
		legacy["version"] = version
		if version == 10:
			legacy["state"]["resonance_capacity"] = 2  # migration adds the #570 baseline
		var restored := _new_game()
		assert(WISave.apply(restored, legacy), "v%d save with a trued piece and a wand loads" % version)
		assert(restored.resonance_limit() == 4, "v%d capacity" % version)
		assert(restored.resonance_used() == 3, "v%d loadout now costs 0 + 3" % version)
		var cfg := restored._player_combatant_config(_pc_template(restored))
		assert(int(cfg[WIKeys.SPELL_POWER]) == 2 and int(cfg[WIKeys.DAMAGE_MOD]) == 1, "v%d: wand spell power, fang weapon damage" % version)
		assert(restored.equip("hedge_ward_charm"), "v%d: the freed resonance takes one more piece" % version)
		assert(restored.resonance_used() == restored.resonance_limit())
