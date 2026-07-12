class_name WIEffectText
extends RefCounted
## The effect-line formatter (pure, static).
##
## Renders items, Skills, and statuses into the game's VISIBLE-CURRENCY tier
## ONLY: HP / MP / AP / damage dice+mods / move cells / gold / rounds. Every
## line is GENERATED from the mechanical data fields (items.json
## damage_mod/hp_mod/damage_reduction/price/resonance; skills.json
## ap_cost/mp_cost/effect.{range,length,mult,amount}/applies; combatants.json
## "pc" weapon_die for a spell's damage die, see `_caster_weapon_die`) — NEVER a
## hand-written twin that can drift from the data it claims to describe. That
## drift is the exact defect class this milestone exists to kill, so callers
## (L2 item cards, L3 skill cards, L4 status glossary) MUST route through here
## rather than compose their own mechanical strings.
##
## FORBIDDEN in any string this class emits: raw attributes
## (STR/DEX/CON/INT/WIS/CHA), percentages-toward, level math, dominance/
## evolution internals. `tests/test_effect_text.gd` pins every shipped line and
## `tests/test_content.gd` greps the full-catalog output for that vocabulary.
##
## PURITY: no autoload, Node, or scene-tree reference. `status_line`'s single-
## arg form loads res://data/skills.json (deterministic, side-effect-free data
## read) to source the `slowed` penalty from where it is DEFINED; `_caster_
## weapon_die` likewise loads res://data/combatants.json to source a spell's
## damage die from where the SIM actually rolls it (skills.json's
## old `effect.die` field was vestigial, never read by wi_combat.gd — see that
## function's doc comment). Both catalog-injecting overloads keep the
## derivation unit-testable / tripwire-able.

const SKILLS_PATH := "res://data/skills.json"
const COMBATANTS_PATH := "res://data/combatants.json"
## The price line's prefix — WIDialogue drops the price line from shop-option
## effect_lines by matching THIS const (a buy option's text already names its
## price), so rephrasing the price line here can never silently un-filter it.
const PRICE_LINE_PREFIX := "Worth "

## Short present-tense verb appended to a Skill's effect line when it applies a
## status on hit (e.g. frost_bolt -> "... . Slows."). The FULL glossary sentence
## lives in `status_line`; this is only the card-side shorthand.
const _STATUS_VERB := {
	"slowed": "Slows.",
}


## Concrete effect lines for an inventory/shop item card, top to bottom:
## combat mods (damage, range, HP, reduction), resonance if present, then the
## gold value. A plain item with no mods and no price yields an empty array —
## its card is name + description only.
##
## GH#70: `range` (items.json, absent/1 = melee) is now part of the
## VISIBLE-CURRENCY set alongside dice/AP -- a weapon with `range > 1` (a bow)
## gets its own "Range N" line, and its damage_mod line (if any) reads "ranged
## hits" instead of "melee hits" so the card never claims a bow lands melee
## damage. Every pre-GH#70 item omits `range` (defaults 0, not > 1), so this
## is byte-identical for every shipped weapon but the two new bows.
static func item_effect_lines(item: Dictionary) -> Array[String]:
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
	var hp_mod := int(item.get(WIKeys.HP_MOD, 0))
	if hp_mod > 0:
		lines.append("+%d HP" % hp_mod)
	var reduction := int(item.get(WIKeys.DAMAGE_REDUCTION, 0))
	if reduction > 0:
		lines.append("Reduces every hit taken by %d" % reduction)
	# Resonance is a live gear stat; formatted here so the card carries it.
	if item.has(WIKeys.RESONANCE) and int(item[WIKeys.RESONANCE]) > 0:
		lines.append("Resonance %d" % int(item[WIKeys.RESONANCE]))
	if item.has(WIKeys.PRICE) and int(item[WIKeys.PRICE]) > 0:
		lines.append(PRICE_LINE_PREFIX + "%d gold" % int(item[WIKeys.PRICE]))
	return lines


## The Skill's cost + effect summary as a card line (0 or 1 entries). Active
## skills read "N AP[, N MP] — <effect>[. <Status>.]"; cost-free passives and
## reactions read as a bare fragment/sentence; field/exploration Skills with no
## combat effect yield an empty array (their card carries name + description).
## `combatants_catalog` overrides the caster-die derivation (see
## `_caster_weapon_die`) for drift-tripwire testing; every real render call
## site (combat_hud/journal/field_hotbar) uses the default, which resolves
## against the shipped combatants.json.
static func skill_effect_lines(skill: Dictionary, combatants_catalog: Array = []) -> Array[String]:
	var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
	var phrase := _effect_phrase(effect, combatants_catalog, int(skill.get(WIKeys.AP_COST, 0)))
	if phrase == "":
		return []
	var prefix := _cost_prefix(skill)
	var line := phrase if prefix == "" else "%s — %s" % [prefix, phrase]
	var suffix := _status_suffix(effect)
	if suffix != "":
		# The status shorthand is its own sentence: end the effect clause with a
		# period first (unless the phrase already punctuated itself).
		line += (" " if line.ends_with(".") else ". ") + suffix
	var lines: Array[String] = []
	lines.append(line)
	return lines


## The one-sentence glossary form for a status, param-substituted from where the
## status is DEFINED. `slowed`'s move penalty lives in skills.json's `applies`
## riders and the (min 1) floor mirrors WICombat._start_turn's maxi(1, ...) —
## both READ, never literal-duplicated. Pass `skills_catalog` (the array under
## skills.json's "skills" key) to derive from an in-memory catalog; the default
## empty loads the shipped file. Returns "" for an unknown status id.
static func status_line(status_id: String, skills_catalog: Array = []) -> String:
	match status_id:
		"slowed":
			var penalty := _slowed_penalty(skills_catalog)
			return "Slowed — moves %d fewer cells next turn (min 1)." % penalty
		"invisible":
			var duration := _invisibility_duration(skills_catalog)
			return "Invisible — enemies can't choose you as a target; breaks if you deal damage, or fades after %d rounds." % duration
	return ""


# --- internals --------------------------------------------------------------

## The AP/MP cost segment ("1 AP, 2 MP"), or "" when the Skill spends neither
## (passives / reactions / field skills). Zero-cost keys are omitted, not shown
## as "0 AP".
static func _cost_prefix(skill: Dictionary) -> String:
	var parts: Array[String] = []
	if int(skill.get(WIKeys.AP_COST, 0)) > 0:
		parts.append("%d AP" % int(skill[WIKeys.AP_COST]))
	if int(skill.get(WIKeys.MP_COST, 0)) > 0:
		parts.append("%d MP" % int(skill[WIKeys.MP_COST]))
	return ", ".join(parts)


## Maps an effect dict to its visible-currency phrase. Returns "" for effects
## with no clean currency read (e.g. dangersense) and for absent effects, which
## suppresses the whole line.
static func _effect_phrase(effect: Dictionary, combatants_catalog: Array = [], ap_cost: int = 0) -> String:
	match String(effect.get(WIKeys.TYPE, "")):
		"spell_damage":
			# skills.json's `effect.die` was VESTIGIAL --
			# wi_combat.gd's _resolve_hit rolls the CASTER's own `weapon_die`
			# for every hit, melee or spell alike, and never reads this field
			# (L1 finding, resolved here). The die is real data, not a
			# free-floating literal: read it from the caster's own combatant
			# record. Every real render call site (combat_hud's hotbar,
			# journal, field_hotbar) only ever shows the PLAYER's own known/
			# fielded skills, so the default (no override) resolves the "pc"
			# entry from the shipped combatants.json.
			return "damage 1d%d at range %d" % [_caster_weapon_die(combatants_catalog), int(effect.get(WIKeys.RANGE, 0))]
		"line_damage":
			return "damage everything in a line %d cells long" % int(effect.get(WIKeys.LENGTH, 0))
		"damage_mult":
			return "×%s damage" % _fmt_mult(float(effect.get(WIKeys.MULT, 1.0)))
		"heal":
			# WIRED -- `WISkillEffects.resolve_active`
			# (src/core/combat/skill_effects.gd) gained a real heal resolver,
			# so the line is no longer a promise-only lie. SELF-ONLY tonight
			# (the sim resolver refuses any target other than the actor's
			# own id -- see its doc comment for the ally-targeting follow-up),
			# so the card says exactly what the sim does: "yourself", not
			# "an ally". Widen this phrase the same task ally-targeting lands.
			return "restore %d HP to yourself" % int(effect.get(WIKeys.AMOUNT, 0))
		"icy_floor":
			# WIRED -- `WISkillEffects.resolve_active` (skill_effects.gd)
			# gained a real icy_floor resolver (an area-terrain cast: the target
			# id picks the blast CENTER via the existing combatant-targeting
			# mode -- no new cell-targeting UI needed after all -- and
			# WICombat.terrain carries the round-persistent state). Every
			# number here is READ from the effect dict (drift rule): `radius`
			# derives the patch's side length (a radius-R square spans
			# 2R+1 cells), `range`/`duration_rounds` are literal. The trailing
			# "Slows." comes from `_status_suffix` automatically, same as
			# frost_bolt/calming_touch (icy_floor's `applies.slowed` rider).
			var side := int(effect.get(WIKeys.RADIUS, 0)) * 2 + 1
			return "glaze a %d×%d patch of ground at range %d for %d rounds" % [
				side, side, int(effect.get(WIKeys.RANGE, 0)), int(effect.get(WIKeys.DURATION_ROUNDS, 0)),
			]
		"blast_damage":
			# WIRED -- WISkillEffects.resolve_active gained a real blast_damage
			# resolver (skill_effects.gd's `_resolve_blast_damage`, the icy_floor
			# area-derivation reused for instant damage instead of terrain/status).
			# `radius` derives the blast's side length exactly like icy_floor's
			# phrase above (a radius-R square spans 2R+1 cells); the die is the
			# CASTER's weapon_die, same honest source as spell_damage's phrase.
			# The trailing sentence is literal, not a `_status_suffix` verb (this
			# effect applies no status) -- spelled out here since friendly fire on
			# an AoE is the one property a player must not have to infer.
			var blast_side := int(effect.get(WIKeys.RADIUS, 0)) * 2 + 1
			# Issue #82's WINDUP SIM SPEC: a `windup_rounds`-carrying blast
			# (today only `slam`) inserts the literal timing clause BEFORE the
			# period, not as a trailing `_status_suffix`-style sentence --
			# "blast...for 1dN after a round's gathering. Hits friend and foe."
			# reads as one honest beat (gather, THEN it lands), not a bolt-on
			# afterthought. Absent (0) on flame_pillar, its only OTHER
			# blast_damage grant, so that card is untouched -- byte-identical.
			var windup_timing := " after a round's gathering" if int(effect.get(WIKeys.WINDUP_ROUNDS, 0)) > 0 else ""
			return "blast a %d×%d area around the target for 1d%d%s. Hits friend and foe." % [
				blast_side, blast_side, _caster_weapon_die(combatants_catalog), windup_timing,
			]
		"move_pool_bonus":
			# UN-SUPPRESSED for an actively-cast skill
			# (ap_cost > 0) -- skill_effects.gd's `resolve_active` wires a
			# real self-buff resolver for exactly that shape (today, only
			# [Stealth]; see its doc comment for why the gate is ap_cost>0
			# specifically).
			#
			# The two PRE-EXISTING 0-cost move_pool_bonus
			# skills (quick_movement, battlefield_awareness) are ALSO now
			# UN-SUPPRESSED -- wi_combat.gd's `_start_turn` gained a real
			# `_move_pool_bonus_total` passive consumer for exactly the
			# ap_cost==0 shape, so this is no longer a promise-only lie. The
			# phrasing is deliberately distinct from the ap_cost>0 branch
			# below: this is a STANDING per-turn bonus (fires every turn,
			# unconditionally, no cast), not a single cast's one-turn buff.
			if ap_cost <= 0:
				var amt := int(effect.get(WIKeys.AMOUNT, 0))
				return "+%d move cell%s every turn" % [amt, "" if amt == 1 else "s"]
			return "+%d move cells this turn" % int(effect.get(WIKeys.AMOUNT, 0))
		"hp_bonus":
			return "+%d max HP" % int(effect.get(WIKeys.AMOUNT, 0))
		"hit_bonus":
			return "+%d to hit" % int(effect.get(WIKeys.AMOUNT, 0))
		# DRIFT SEAM: the three arms below emit truthful
		# lines for any skill carrying these effect TYPES, but the sim wires
		# each mechanic by literal skill NAME (wi_combat.gd: counter_strike,
		# battle_momentum, mana_shield). 1:1 today. A future skill REUSING one
		# of these types would get a truthful-looking card the sim never
		# honors — generalize the sim lookup to the effect type (or add the
		# new name at the trigger site) BEFORE shipping such a skill.
		"ap_on_kill":
			return "+%d AP when you down a foe" % int(effect.get(WIKeys.AMOUNT, 0))
		"riposte":
			return "Strike back for ×%s damage when hit in melee." % _fmt_mult(float(effect.get(WIKeys.MULT, 1.0)))
		"mana_shield":
			return "Spend MP to absorb incoming damage."
		"quick_cast":
			return "Your first spell each turn costs 1 less AP."
		"invisibility":
			# WIRED -- WISkillEffects.resolve_active
			# gained a real invisibility resolver (a self-cast untargetable
			# status; see its doc comment). `duration_rounds` is the only
			# number this phrase reads (visible-currency: rounds); the
			# `applies.invisible.untargetable` rider carries no player-facing
			# number of its own, so no `_status_suffix` verb is needed here --
			# the phrase already says everything the card promises.
			return "become impossible to target for %d rounds (breaks if you deal damage)" % int(effect.get(WIKeys.DURATION_ROUNDS, 0))
	return ""


## The trailing status shorthand ("Slows.") for a Skill that applies a status on
## hit, or "" for one that applies none.
static func _status_suffix(effect: Dictionary) -> String:
	var applies: Dictionary = effect.get(WIKeys.APPLIES, {})
	var verbs: Array[String] = []
	for status_id: String in applies:
		if _STATUS_VERB.has(status_id):
			verbs.append(_STATUS_VERB[status_id])
	return " ".join(verbs)


## Reads the `slowed` move penalty from the skills catalog (the first skill that
## applies it — every shipped applier uses the same value). Falls back to the
## shipped file when no catalog is injected, and to 2 only if the catalog holds
## no slowed applier at all (keeps the glossary from emitting a nonsense 0).
static func _slowed_penalty(skills_catalog: Array) -> int:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		var applies: Dictionary = (skill.get(WIKeys.EFFECT, {}) as Dictionary).get(WIKeys.APPLIES, {})
		if applies.has("slowed"):
			return int((applies["slowed"] as Dictionary).get("pool_penalty", 2))
	return 2


## Reads invisibility's `duration_rounds` from the skills catalog (the first
## skill whose effect.type is "invisibility" -- mirrors `_slowed_penalty`'s
## derive-from-where-it's-defined idiom). Falls back to the shipped file when
## no catalog is injected, and to 3 only if the catalog holds no invisibility
## skill at all (keeps the glossary from emitting a nonsense 0).
static func _invisibility_duration(skills_catalog: Array) -> int:
	var catalog := skills_catalog
	if catalog.is_empty():
		catalog = _load_skills()
	for skill: Dictionary in catalog:
		var effect: Dictionary = skill.get(WIKeys.EFFECT, {})
		if String(effect.get(WIKeys.TYPE, "")) == "invisibility":
			return int(effect.get(WIKeys.DURATION_ROUNDS, 3))
	return 3


static func _load_skills() -> Array:
	if not FileAccess.file_exists(SKILLS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has(WIKeys.SKILLS):
		return (parsed as Dictionary)[WIKeys.SKILLS]
	return []


## The literal die a spell_damage cast actually rolls, per wi_combat.gd's
## _resolve_hit (base_damage reads `a["weapon_die"]` unconditionally, melee or
## spell alike — never a per-skill field). `weapon_die` is a FIXED per-
## combatant base stat: `wi_game.gd._build_player_combatant` threads a weapon's
## damage_mod/hp_mod/damage_reduction onto the runtime combatant dict but never
## touches weapon_die, so the PC's is constant regardless of what's equipped.
## Reads the "pc" entry from the combatants catalog (the only caster any
## shipped UI ever renders a Skill card for); falls back to 6 (the shipped
## value) if absent, matching `_slowed_penalty`'s "never a nonsense fallback"
## contract. Pass `combatants_catalog` (the array under combatants.json's
## "combatants" key) to derive from an in-memory catalog for drift-tripwire
## testing; the default empty loads the shipped file.
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


## Formats a damage multiplier without a trailing ".0" (2.0 -> "2", 1.4 -> "1.4").
static func _fmt_mult(m: float) -> String:
	if m == floor(m):
		return str(int(m))
	return str(m)
