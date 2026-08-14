class_name WIEffectText
extends RefCounted

const SKILLS_PATH := "res://data/skills.json"
const COMBATANTS_PATH := "res://data/combatants.json"
const PRICE_LINE_PREFIX := "Worth "

const _STATUS_VERB := {
	"slowed": "Slows.",
	"weakened": "Weakens.",
	"guarded": "Guards.",
	"rooted": "Roots.",
	"burning": "Burns.",
}


static func item_effect_lines(item: Dictionary, skills_catalog: Array = []) -> Array[String]:
	var lines: Array[String] = []
	var damage_mod := int(item.get(WIKeys.DAMAGE_MOD, 0))
	var weapon_range := int(item.get(WIKeys.RANGE, 0))
	if damage_mod > 0:
		if weapon_range > 1:
			lines.append("+%d damage on ranged hits" % damage_mod)
		else:
			lines.append("+%d damage on melee hits" % damage_mod)
	if weapon_range > 1:
		lines.append("Range %d" % weapon_range)
	var weapon_family := String(item.get("weapon_family", ""))
	if weapon_family != "" and weapon_family != "none":
		lines.append("%s kit replaces other weapon Skills in combat" % weapon_family.capitalize())
	var hp_mod := int(item.get(WIKeys.HP_MOD, 0))
	if hp_mod > 0:
		lines.append("+%d HP" % hp_mod)
	var reduction := int(item.get(WIKeys.DAMAGE_REDUCTION, 0))
	if reduction > 0:
		lines.append("Reduces every hit taken by %d" % reduction)
	if item.has(WIKeys.RESONANCE) and int(item[WIKeys.RESONANCE]) > 0:
		lines.append("Resonance %d" % int(item[WIKeys.RESONANCE]))
	for raw_ability: Variant in (item.get(WIKeys.ABILITIES, []) as Array):
		var ability_display := _skill_display_name(String(raw_ability), skills_catalog)
		if ability_display != "":
			# Steel-thread ruling (2026-08-11): worn-accessory abilities join
			# known_skills(), so a FIELD-capable ability is no longer combat-only
			# and the GH#334 note 28 honesty contract now cuts the other way —
			# "in combat" would promise a restriction that no longer exists.
			# The qualifier stays for combat-only abilities ([Second Wind]).
			if _skill_is_field(String(raw_ability), skills_catalog):
				lines.append("Grants %s" % ability_display)
			else:
				lines.append("Grants %s in combat" % ability_display)
	var use_effect: Dictionary = item.get(WIKeys.USE_EFFECT, {})
	if use_effect.has("heal"):
		# GH#334 note 28 item 2: "in combat" is not decoration. `WIItems.
		# _resolve_heal_use` refuses outright when `combat == null`, and the
		# inventory panel silently repurposes confirm into a hotbar toggle for
		# exactly these items -- so an unqualified "Heals 8 HP" was the card
		# promising something the only reachable out-of-combat press cannot do.
		# The `next_fight` branch three lines down already models the idiom.
		lines.append("Heals %d HP in combat (single use)" % int(use_effect["heal"]))
	if use_effect.has("next_fight"):
		var nf_bits := next_fight_bits(use_effect["next_fight"] as Dictionary)
		if not nf_bits.is_empty():
			lines.append("Next fight: %s (single use)" % ", ".join(nf_bits))
	if item.has(WIKeys.PRICE) and int(item[WIKeys.PRICE]) > 0:
		lines.append(PRICE_LINE_PREFIX + "%d gold" % int(item[WIKeys.PRICE]))
	return lines


## The mod-dict phrasebook shared by the item CARD (the "Next fight: ..." line
## above) and the meal USE toast (`WIGame.use_item`). ONE source, deliberately:
## the card promises a payload and the toast must restate the same payload in
## the same words, and after GH#334 ruling 5 the toast speaks the MERGED
## `pending_meal` (two armed items both apply) rather than the single item's own
## dict -- two composers would have drifted the moment that merge landed.
static func next_fight_bits(mods: Dictionary) -> Array[String]:
	var bits: Array[String] = []
	if int(mods.get(WIKeys.DAMAGE_MOD, 0)) > 0:
		bits.append("+%d damage" % int(mods[WIKeys.DAMAGE_MOD]))
	if int(mods.get(WIKeys.HP_MOD, 0)) > 0:
		bits.append("+%d HP" % int(mods[WIKeys.HP_MOD]))
	if int(mods.get(WIKeys.DAMAGE_REDUCTION, 0)) > 0:
		bits.append("reduces hits by %d" % int(mods[WIKeys.DAMAGE_REDUCTION]))
	return bits


## GH#334 note 28 item 3: what the meal-use toast says after "Used: <name>.".
## Composed off the LIVE `pending_meal` dict `_build_player_combatant` will
## actually read, so the promise and the payment can never disagree; "" when the
## armed dict carries nothing this formatter can phrase (which is also the
## honest answer -- say nothing rather than invent a payload).
static func pending_meal_line(pending: Dictionary) -> String:
	var bits := next_fight_bits(pending)
	if bits.is_empty():
		return ""
	return "%s in your next fight." % ", ".join(bits)


static func skill_effect_lines(skill: Dictionary, combatants_catalog: Array = []) -> Array[String]:
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var phrase := _effect_phrase(effect, combatants_catalog, int(skill.get(WIKeys.AP_COST, 0)))
	if phrase == "":
		return []
	var prefix := _cost_prefix(skill)
	var line := phrase if prefix == "" else "%s — %s" % [prefix, phrase]
	var suffix := _status_suffix(effect)
	if suffix != "":
		line += (" " if line.ends_with(".") else ". ") + suffix
	# GH#337 ruling 5: a cooldown is a COMBAT resource of the same class as AP
	# and MP, so saying it out loud is legal -- the opaque-until-sleep lock
	# governs progression text, not combat state. Rides the exact clause idiom
	# `once_per_fight` established one line below, and like it, is generated from
	# the record rather than hand-composed at the call site (combat_hud.gd's
	# `_slot_info_line` record has to carry the key or the clause silently
	# vanishes -- the GH#334 ruling-14 defect).
	var cooldown := int(skill.get(WICombat.COOLDOWN_ROUNDS, 0))
	if cooldown > 0:
		line += (" " if line.ends_with(".") else ". ") + cooldown_clause(cooldown)
	if bool(skill.get(WIKeys.ONCE_PER_FIGHT, false)):
		line += (" " if line.ends_with(".") else ". ") + "Once per fight."
	var lines: Array[String] = []
	lines.append(line)
	return lines


## Effect phrases that only mean anything inside a fight. `_effect_phrase` speaks
## rounds, AP, targets and the initiative order -- none of which exist out on the
## map, where a field cast spends nothing (`WIGame.use_skill_field` ticks an action
## and dispatches; there is no overworld AP or MP pool to draw on). A dual-context
## Skill like [Invisibility] therefore composes a TRUE combat line and a NONSENSE
## field line from the same data, which is what shipped ("1 AP, 3 MP — become
## impossible to target for 3 rounds" on the exploration hotbar).
## Everything `_effect_phrase` can currently produce is combat-only, so this set is
## exhaustive by construction: a NEW effect type is muted in the field until it is
## deliberately left out of this map, and `test_effect_text` pins that silence.
const _COMBAT_ONLY_EFFECT_TYPES := {
	"spell_damage": true,
	"line_damage": true,
	"damage_mult": true,
	"heal": true,
	"icy_floor": true,
	"blast_damage": true,
	"move_pool_bonus": true,
	"hp_bonus": true,
	"hit_bonus": true,
	"ap_on_kill": true,
	"riposte": true,
	"mana_shield": true,
	"quick_cast": true,
	"invisibility": true,
	## #460. Combat-only for the plainest possible reason: `WICombat.add_combatant`
	## is the only thing that can resolve it, and there is no overworld board to
	## put a body on.
	"summon": true,
}


## The exploration readout's composer. Deliberately NOT `skill_effect_lines`: no
## cost prefix (nothing is spent in the field) and no combat-only phrase. Returning
## [] is the normal, expected answer -- `field_hotbar._readout_line` falls back to
## "display_name — description", which is authored prose, and a Skill that wants
## bespoke field copy carries `field_ambient` instead.
static func field_effect_lines(skill: Dictionary) -> Array[String]:
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var effect_type := String(effect.get(WIKeys.TYPE, ""))
	if effect_type == "" or _COMBAT_ONLY_EFFECT_TYPES.has(effect_type):
		return []
	var phrase := _effect_phrase(effect, [], int(skill.get(WIKeys.AP_COST, 0)))
	if phrase == "":
		return []
	var lines: Array[String] = []
	lines.append(phrase)
	return lines


## GH#337. Phrased in ROUNDS, the unit the player already reads off status
## glossary lines and the terrain cards -- never in turns (the sim has no
## per-actor turn counter to be honest about) and never as a bare number. The
## semantics it has to be true to: an ABSOLUTE stamp of `round + N` means the
## Skill is unusable for N rounds counting the one it was used in, so N=1 forbids
## only a second cast inside the SAME turn, and N=2 is the real every-other-turn
## rhythm the milestone is for.
static func cooldown_clause(rounds: int) -> String:
	if rounds <= 1:
		return "Once per round."
	return "Once every %d rounds." % rounds


## GH#337. The LIVE half, for a slot that is cooling right now (the card clause
## above is the static rule). Separate function because it is only ever true of
## one combatant at one moment, and the tooltip has to say the number rather
## than leave a dimmed slot unexplained.
static func cooldown_recovering_line(rounds_left: int) -> String:
	if rounds_left <= 0:
		return ""
	if rounds_left == 1:
		return "Recovering — ready next round."
	return "Recovering — ready in %d rounds." % rounds_left


static func status_line(status_id: String, skills_catalog: Array = []) -> String:
	match status_id:
		"slowed":
			var penalty := _slowed_penalty(skills_catalog)
			return "Slowed — moves %d fewer cells next turn (min 1)." % penalty
		"invisible":
			var duration := _invisibility_duration(skills_catalog)
			return "Invisible — enemies can't choose you as a target; breaks if you deal damage, or fades after %d rounds." % duration
		"weakened":
			var rounds := _status_duration(status_id, skills_catalog)
			return "Weakened — deals ×%s damage for %d round%s." % [_fmt_mult(WICombat.WEAKENED_MULT), rounds, "" if rounds == 1 else "s"]
		"guarded":
			var rounds := _status_duration(status_id, skills_catalog)
			return "Guarded — takes ×%s damage for %d round%s." % [_fmt_mult(WICombat.GUARDED_MULT), rounds, "" if rounds == 1 else "s"]
		"rooted":
			var rounds := _status_duration(status_id, skills_catalog)
			return "Rooted — can't move or Dash for %d round%s." % [rounds, "" if rounds == 1 else "s"]
		"burning":
			var rounds := _status_duration(status_id, skills_catalog)
			var tick := _burning_tick_damage(skills_catalog)
			return "Burning — takes %d damage at the end of each round for %d round%s." % [tick, rounds, "" if rounds == 1 else "s"]
	return ""



static func _cost_prefix(skill: Dictionary) -> String:
	var parts: Array[String] = []
	if int(skill.get(WIKeys.AP_COST, 0)) > 0:
		parts.append("%d AP" % int(skill[WIKeys.AP_COST]))
	if int(skill.get(WIKeys.MP_COST, 0)) > 0:
		parts.append("%d MP" % int(skill[WIKeys.MP_COST]))
	return ", ".join(parts)


static func _effect_phrase(effect: Dictionary, combatants_catalog: Array = [], ap_cost: int = 0) -> String:
	match String(effect.get(WIKeys.TYPE, "")):
		"spell_damage":
			return "damage 1d%d at range %d" % [_caster_weapon_die(combatants_catalog), int(effect.get(WIKeys.RANGE, 0))]
		"line_damage":
			return "damage everything in a line %d cells long" % int(effect.get(WIKeys.LENGTH, 0))
		"damage_mult":
			return "×%s damage" % _fmt_mult(float(effect.get(WIKeys.MULT, 1.0)))
		"heal":
			if bool(effect.get("ally_target", false)):
				return "restore %d HP to an ally, or yourself" % int(effect.get(WIKeys.AMOUNT, 0))
			return "restore %d HP to yourself" % int(effect.get(WIKeys.AMOUNT, 0))
		"icy_floor":
			var side := int(effect.get(WIKeys.RADIUS, 0)) * 2 + 1
			return "glaze a %d×%d patch of ground at range %d for %d rounds" % [
				side, side, int(effect.get(WIKeys.RANGE, 0)), int(effect.get(WIKeys.DURATION_ROUNDS, 0)),
			]
		"blast_damage":
			var blast_side := int(effect.get(WIKeys.RADIUS, 0)) * 2 + 1
			var windup_timing := " after a round's gathering" if int(effect.get(WIKeys.WINDUP_ROUNDS, 0)) > 0 else ""
			return "blast a %d×%d area around the target for 1d%d%s. Hits friend and foe." % [
				blast_side, blast_side, _caster_weapon_die(combatants_catalog), windup_timing,
			]
		"move_pool_bonus":
			if ap_cost <= 0:
				var amt := int(effect.get(WIKeys.AMOUNT, 0))
				return "+%d move cell%s every turn" % [amt, "" if amt == 1 else "s"]
			return "+%d move cells this turn" % int(effect.get(WIKeys.AMOUNT, 0))
		"hp_bonus":
			return "+%d max HP" % int(effect.get(WIKeys.AMOUNT, 0))
		"hit_bonus":
			return "+%d to hit" % int(effect.get(WIKeys.AMOUNT, 0))
		"ap_on_kill":
			return "+%d AP when you down a foe" % int(effect.get(WIKeys.AMOUNT, 0))
		"riposte":
			return "Strike back for ×%s damage when hit in melee." % _fmt_mult(float(effect.get(WIKeys.MULT, 1.0)))
		"mana_shield":
			return "Spend MP to absorb incoming damage."
		"quick_cast":
			return "Your first spell each turn costs 1 less AP."
		"invisibility":
			return "become impossible to target for %d rounds (breaks if you deal damage)" % int(effect.get(WIKeys.DURATION_ROUNDS, 0))
		"summon":
			# #460. The clause names the BODY, not the row id, through the same
			# catalog `_caster_weapon_die` already reads -- a card that said
			# "bone_thrall" would be a data key spoken at a reader. `fight_limit`
			# is the half a player has to plan around, so it is stated; the
			# cooldown is already spoken by `cooldown_clause`.
			var summoned := _summon_display_name(combatants_catalog, String(effect.get("combatant", "")))
			var count := int(effect.get("count", 1))
			var many := "" if count == 1 else "%d " % count
			return "raise %s%s to fight beside you, up to %d a fight" % [
				many, summoned, int(effect.get("fight_limit", 0)),
			]
	return ""


## #460. Display name for a summon target, "the dead" when the catalog is absent
## (every composer here takes its catalog optionally and must stay speakable
## without one).
static func _summon_display_name(combatants_catalog: Array, combatant_id: String) -> String:
	var catalog := combatants_catalog
	if catalog.is_empty():
		catalog = _load_combatants()
	for row: Dictionary in catalog:
		if String(row.get(WIKeys.ID, "")) == combatant_id:
			return String(row.get(WIKeys.DISPLAY_NAME, "the dead"))
	return "the dead"


static func _status_suffix(effect: Dictionary) -> String:
	var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
	var verbs: Array[String] = []
	for status_id: String in applies:
		if _STATUS_VERB.has(status_id):
			verbs.append(_STATUS_VERB[status_id])
	return " ".join(verbs)


static func _slowed_penalty(skills_catalog: Array) -> int:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		var applies: Dictionary = (skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.APPLIES, {})
		if applies.has("slowed"):
			return int((applies["slowed"] as Dictionary).get("pool_penalty", 2))
	return 2


static func _invisibility_duration(skills_catalog: Array) -> int:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
		if String(effect.get(WIKeys.TYPE, "")) == "invisibility":
			return int(effect.get(WIKeys.DURATION_ROUNDS, 3))
	return 3


static func _status_duration(status_id: String, skills_catalog: Array) -> int:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		var applies: Dictionary = (skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.APPLIES, {})
		if applies.has(status_id):
			return int((applies[status_id] as Dictionary).get(WIKeys.DURATION_ROUNDS, 2))
	return 2


static func _burning_tick_damage(skills_catalog: Array) -> int:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		var applies: Dictionary = (skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.APPLIES, {})
		if applies.has("burning"):
			return int((applies["burning"] as Dictionary).get("tick_damage", 2))
	return 2


static func _load_skills() -> Array:
	if not FileAccess.file_exists(SKILLS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has(WIKeys.SKILLS):
		return (parsed as Dictionary)[WIKeys.SKILLS]
	return []


static func _skill_is_field(skill_id: String, skills_catalog: Array = []) -> bool:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		if String(skill.get(WIKeys.ID, "")) == skill_id:
			return bool(skill.get("field", false))
	return false


static func _skill_display_name(skill_id: String, skills_catalog: Array = []) -> String:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		if String(skill.get(WIKeys.ID, "")) == skill_id:
			return String(skill.get(WIKeys.DISPLAY_NAME, ""))
	return ""


static func _caster_weapon_die(combatants_catalog: Array = []) -> int:
	var catalog := combatants_catalog
	if catalog.is_empty():
		catalog = _load_combatants()
	for c: Dictionary in catalog:
		if String(c.get(WIKeys.ID, "")) == "pc":
			return int(c.get(WIKeys.WEAPON_DIE, 6))
	return 6


static func _load_combatants() -> Array:
	if not FileAccess.file_exists(COMBATANTS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBATANTS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has("combatants"):
		return (parsed as Dictionary)["combatants"]
	return []


static func _fmt_mult(m: float) -> String:
	if m == floor(m):
		return str(int(m))
	return str(m)
