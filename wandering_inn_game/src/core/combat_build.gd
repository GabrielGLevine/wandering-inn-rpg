class_name WICombatBuild
extends RefCounted
## Shared combatant-build math for wi_game.gd's _build_player_combatant AND
## tests/sim_combat_batch.gd. TRAP: hand-copying between the two = harness
## silently measures a different game than shipped — keep shared here.
## Deliberately NOT wi_combat.gd (fight-resolution CONSUMER, not builder).


static func weapon_gated_kit(kit: Array, weapon_family: String, skills_by_id: Dictionary) -> Array:
	var out: Array = []
	for raw: Variant in kit:
		var sk_id := String(raw)
		var rec: Dictionary = skills_by_id.get(sk_id, {})
		if not rec.has(WIKeys.WEAPON) or String(rec[WIKeys.WEAPON]) == weapon_family:
			out.append(sk_id)
	return out


static func equipment_mods(weapon: Dictionary, armor: Dictionary, accessories: Array) -> Dictionary:
	var dmg_mod := int(weapon.get(WIKeys.DAMAGE_MOD, 0))
	var hp_mod := int(armor.get(WIKeys.HP_MOD, 0))
	var dmg_reduction := int(armor.get(WIKeys.DAMAGE_REDUCTION, 0))
	var spell_power := int(weapon.get(WIKeys.SPELL_POWER, 0)) + int(armor.get(WIKeys.SPELL_POWER, 0))
	for acc: Dictionary in accessories:
		dmg_mod += int(acc.get(WIKeys.DAMAGE_MOD, 0))
		hp_mod += int(acc.get(WIKeys.HP_MOD, 0))
		dmg_reduction += int(acc.get(WIKeys.DAMAGE_REDUCTION, 0))
		spell_power += int(acc.get(WIKeys.SPELL_POWER, 0))
	return {WIKeys.DAMAGE_MOD: dmg_mod, WIKeys.HP_MOD: hp_mod, WIKeys.DAMAGE_REDUCTION: dmg_reduction,
		WIKeys.SPELL_POWER: spell_power}


## #514 (#495 ruling): the one classifier of what a damaging Skill adds up from.
## The engine, the competent policy, Skill and item text and the inventory reach
## line all read it, so a preview can never name a different source than the hit.
## A `weapon` gate is what makes a spell/line/blast arm physical: it is the same
## key `weapon_gated_kit` strips by, so "physical for damage" and "gated for the
## kit" cannot diverge. Windup blasts resolve through the melee strike path.
## A Skill authored `"damage_source": "innate"` is neither: it keeps its int
## scaling and takes no gear add (the Tactician's illusory barrage; casts only
## enemies field, since spell power is player gear).
const SOURCE_WEAPON := "weapon"
const SOURCE_SPELL := "spell"
const SOURCE_INNATE := "innate"
const _SKILL_HIT_TYPES := ["spell_damage", "line_damage", "blast_damage"]

static func damage_source(skill: Dictionary) -> String:
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var effect_type := String(effect.get(WIKeys.TYPE, ""))
	if effect_type == "damage_mult" or effect_type == "riposte":
		return SOURCE_WEAPON
	if not _SKILL_HIT_TYPES.has(effect_type):
		return ""
	if String(skill.get(WIKeys.WEAPON, "")) != "" or int(effect.get(WIKeys.WINDUP_ROUNDS, 0)) > 0:
		return SOURCE_WEAPON
	if String(skill.get(WIKeys.DAMAGE_SOURCE, "")) == SOURCE_INNATE:
		return SOURCE_INNATE
	return SOURCE_SPELL


## The combat Skills in `kit` that weapon damage and spell power reach, in kit
## order. Ordinary attacks always take weapon damage; callers say so themselves.
static func damage_reach(kit: Array, skills_by_id: Dictionary) -> Dictionary:
	var reach := {SOURCE_WEAPON: [], SOURCE_SPELL: []}
	for raw: Variant in kit:
		var skill: Dictionary = skills_by_id.get(String(raw), {})
		if not (skill.get(WIKeys.CONTEXTS, []) as Array).has("combat"):
			continue
		var source := damage_source(skill)
		if source != "" and not (reach[source] as Array).has(String(raw)):
			(reach[source] as Array).append(String(raw))
	return reach


static func fold_abilities(kit: Array, accessories: Array) -> Array:
	var out: Array = kit.duplicate()
	for acc: Dictionary in accessories:
		for raw: Variant in (acc.get(WIKeys.ABILITIES, []) as Array):
			var ability_id := String(raw)
			if not out.has(ability_id):
				out.append(ability_id)
	return out


static func resource_maxima(cfg: Dictionary, skills_by_id: Dictionary) -> Dictionary:
	var stats: Dictionary = cfg[WIKeys.STATS]
	var max_hp := maxi(20 + int(stats["con"]) + int(cfg.get(WIKeys.HP_MOD, 0)), 1)
	var max_mp := 0
	for raw: Variant in cfg.get(WIKeys.SKILLS, []):
		var skill: Dictionary = skills_by_id.get(String(raw), {})
		var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
		if String(effect.get(WIKeys.TYPE, "")) == "hp_bonus":
			max_hp += int(effect[WIKeys.AMOUNT])
		if skill.has(WIKeys.MP_COST):
			max_mp = 8 + int(int(stats["int"]) / 2)
	return {WIKeys.MAX_HP: max_hp, WIKeys.MAX_MP: max_mp}
