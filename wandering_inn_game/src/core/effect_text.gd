class_name WIEffectText
extends RefCounted
## M-LEGIBILITY L1: the effect-line formatter (pure, static).
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
## damage die from where the SIM actually rolls it (M-LEGIBILITY L5: skills.json's
## old `effect.die` field was vestigial, never read by wi_combat.gd — see that
## function's doc comment). Both catalog-injecting overloads keep the
## derivation unit-testable / tripwire-able.

const SKILLS_PATH := "res://data/skills.json"
const COMBATANTS_PATH := "res://data/combatants.json"
## The price line's prefix — WIDialogue drops the price line from shop-option
## effect_lines by matching THIS const (a buy option's text already names its
## price), so rephrasing the price line here can never silently un-filter it
## (opus final-review M4).
const PRICE_LINE_PREFIX := "Worth "

## Short present-tense verb appended to a Skill's effect line when it applies a
## status on hit (e.g. frost_bolt -> "... . Slows."). The FULL glossary sentence
## lives in `status_line`; this is only the card-side shorthand.
const _STATUS_VERB := {
	"slowed": "Slows.",
}


## Concrete effect lines for an inventory/shop item card, top to bottom:
## combat mods (damage, HP, reduction), resonance if present (M-GEAR), then the
## gold value. A plain item with no mods and no price yields an empty array —
## its card is name + description only.
static func item_effect_lines(item: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var damage_mod := int(item.get("damage_mod", 0))
	if damage_mod > 0:
		lines.append("+%d damage on melee hits" % damage_mod)
	var hp_mod := int(item.get("hp_mod", 0))
	if hp_mod > 0:
		lines.append("+%d HP" % hp_mod)
	var reduction := int(item.get("damage_reduction", 0))
	if reduction > 0:
		lines.append("Reduces every hit taken by %d" % reduction)
	# M-GEAR ships resonance; formatted here now so the card is ready for it.
	if item.has("resonance") and int(item["resonance"]) > 0:
		lines.append("Resonance %d" % int(item["resonance"]))
	if item.has("price") and int(item["price"]) > 0:
		lines.append(PRICE_LINE_PREFIX + "%d gold" % int(item["price"]))
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
	var effect: Dictionary = skill.get("effect", {})
	var phrase := _effect_phrase(effect, combatants_catalog, int(skill.get("ap_cost", 0)))
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
	return ""


# --- internals --------------------------------------------------------------

## The AP/MP cost segment ("1 AP, 2 MP"), or "" when the Skill spends neither
## (passives / reactions / field skills). Zero-cost keys are omitted, not shown
## as "0 AP".
static func _cost_prefix(skill: Dictionary) -> String:
	var parts: Array[String] = []
	if int(skill.get("ap_cost", 0)) > 0:
		parts.append("%d AP" % int(skill["ap_cost"]))
	if int(skill.get("mp_cost", 0)) > 0:
		parts.append("%d MP" % int(skill["mp_cost"]))
	return ", ".join(parts)


## Maps an effect dict to its visible-currency phrase. Returns "" for effects
## with no clean currency read (e.g. dangersense) and for absent effects, which
## suppresses the whole line.
static func _effect_phrase(effect: Dictionary, combatants_catalog: Array = [], ap_cost: int = 0) -> String:
	match String(effect.get("type", "")):
		"spell_damage":
			# M-LEGIBILITY L5: skills.json's `effect.die` was VESTIGIAL --
			# wi_combat.gd's _resolve_hit rolls the CASTER's own `weapon_die`
			# for every hit, melee or spell alike, and never reads this field
			# (L1 finding, resolved here). The die is real data, not a
			# free-floating literal: read it from the caster's own combatant
			# record. Every real render call site (combat_hud's hotbar,
			# journal, field_hotbar) only ever shows the PLAYER's own known/
			# fielded skills, so the default (no override) resolves the "pc"
			# entry from the shipped combatants.json.
			return "damage 1d%d at range %d" % [_caster_weapon_die(combatants_catalog), int(effect.get("range", 0))]
		"line_damage":
			return "damage everything in a line %d cells long" % int(effect.get("length", 0))
		"damage_mult":
			return "×%s damage" % _fmt_mult(float(effect.get("mult", 1.0)))
		"heal", "icy_floor":
			# M-LEGIBILITY L5 fix wave, Item 1: these two effect types have
			# ZERO sim consumer today -- `WISkillEffects.resolve_active`
			# (src/core/combat/skill_effects.gd) has no heal/icy_floor match
			# arm. Generating "2 AP — restore 8 HP" for second_wind/icy_floor
			# would promise a mechanic that never fires, so the line is
			# SUPPRESSED (return "") until the sim grows a real consumer.
			# Re-enable by adding a `resolve_active` match arm for the type
			# FIRST, then restoring the phrase here -- see CLAUDE.md's
			# M-LEGIBILITY disclosed-finding paragraph. Known/accepted cost:
			# this also blanks the whole `skill_effect_lines` line (cost
			# prefix included, per that function's early-return-on-""
			# contract) -- advertising a cost for a non-effect would be the
			# worse lie.
			return ""
		"move_pool_bonus":
			# Skills Wave Task K2: UN-SUPPRESSED, but ONLY for an actively-cast
			# skill (ap_cost > 0) -- skill_effects.gd's `resolve_active` now
			# wires a real self-buff resolver for exactly that shape (today,
			# only [Sneak]; see its doc comment for why the gate is ap_cost>0
			# specifically). The two PRE-EXISTING 0-cost move_pool_bonus
			# skills (quick_movement, battlefield_awareness) are UNCHANGED --
			# they hit this same case with ap_cost==0 and stay SUPPRESSED,
			# because they still have no resolver (disclosed above): showing
			# "+1 move cell" for a cast that would still silently do nothing
			# would be the exact lie this milestone exists to kill. Re-enable
			# THEIR line the same way heal/icy_floor's comment describes --
			# a resolve_active/`_apply_passives` consumer FIRST, then drop
			# this ap_cost guard.
			if ap_cost <= 0:
				return ""
			return "+%d move cells this turn" % int(effect.get("amount", 0))
		"hp_bonus":
			return "+%d max HP" % int(effect.get("amount", 0))
		"hit_bonus":
			return "+%d to hit" % int(effect.get("amount", 0))
		# DRIFT SEAM (opus final-review M1): the three arms below emit truthful
		# lines for any skill carrying these effect TYPES, but the sim wires
		# each mechanic by literal skill NAME (wi_combat.gd: counter_strike,
		# battle_momentum, mana_shield). 1:1 today. A future skill REUSING one
		# of these types would get a truthful-looking card the sim never
		# honors — generalize the sim lookup to the effect type (or add the
		# new name at the trigger site) BEFORE shipping such a skill.
		"ap_on_kill":
			return "+%d AP when you down a foe" % int(effect.get("amount", 0))
		"riposte":
			return "Strike back for ×%s damage when hit in melee." % _fmt_mult(float(effect.get("mult", 1.0)))
		"mana_shield":
			return "Spend MP to absorb incoming damage."
		"quick_cast":
			return "Your first spell each turn costs 1 less AP."
	return ""


## The trailing status shorthand ("Slows.") for a Skill that applies a status on
## hit, or "" for one that applies none.
static func _status_suffix(effect: Dictionary) -> String:
	var applies: Dictionary = effect.get("applies", {})
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
		var applies: Dictionary = (skill.get("effect", {}) as Dictionary).get("applies", {})
		if applies.has("slowed"):
			return int((applies["slowed"] as Dictionary).get("pool_penalty", 2))
	return 2


static func _load_skills() -> Array:
	if not FileAccess.file_exists(SKILLS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SKILLS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).has("skills"):
		return (parsed as Dictionary)["skills"]
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
		if String(c.get("id", "")) == "pc":
			return int(c.get("weapon_die", 6))
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
