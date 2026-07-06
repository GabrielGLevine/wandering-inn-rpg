class_name WIEffectText
extends RefCounted
## M-LEGIBILITY L1: the effect-line formatter (pure, static).
##
## Renders items, Skills, and statuses into the game's VISIBLE-CURRENCY tier
## ONLY: HP / MP / AP / damage dice+mods / move cells / gold / rounds. Every
## line is GENERATED from the mechanical data fields (items.json
## damage_mod/hp_mod/damage_reduction/price/resonance; skills.json
## ap_cost/mp_cost/effect.{die,range,length,mult,amount}/applies) — NEVER a
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
## read) to source the `slowed` penalty from where it is DEFINED; the
## catalog-injecting overload keeps the derivation unit-testable / tripwire-able.

const SKILLS_PATH := "res://data/skills.json"

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
		lines.append("Worth %d gold" % int(item["price"]))
	return lines


## The Skill's cost + effect summary as a card line (0 or 1 entries). Active
## skills read "N AP[, N MP] — <effect>[. <Status>.]"; cost-free passives and
## reactions read as a bare fragment/sentence; field/exploration Skills with no
## combat effect yield an empty array (their card carries name + description).
static func skill_effect_lines(skill: Dictionary) -> Array[String]:
	var effect: Dictionary = skill.get("effect", {})
	var phrase := _effect_phrase(effect)
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
static func _effect_phrase(effect: Dictionary) -> String:
	match String(effect.get("type", "")):
		"spell_damage":
			return "damage 1d%d at range %d" % [int(effect.get("die", 0)), int(effect.get("range", 0))]
		"line_damage":
			return "damage everything in a line %d cells long" % int(effect.get("length", 0))
		"damage_mult":
			return "×%s damage" % _fmt_mult(float(effect.get("mult", 1.0)))
		"heal":
			return "restore %d HP" % int(effect.get("amount", 0))
		"hp_bonus":
			return "+%d max HP" % int(effect.get("amount", 0))
		"hit_bonus":
			return "+%d to hit" % int(effect.get("amount", 0))
		"move_pool_bonus":
			return "+%d move cell" % int(effect.get("amount", 0))
		"ap_on_kill":
			return "+%d AP when you down a foe" % int(effect.get("amount", 0))
		"riposte":
			return "Strike back for ×%s damage when hit in melee." % _fmt_mult(float(effect.get("mult", 1.0)))
		"mana_shield":
			return "Spend MP to absorb incoming damage."
		"quick_cast":
			return "Your first spell each turn costs 1 less AP."
		"icy_floor":
			return "freeze the floor (range %d, radius %d) for %d rounds" % [
				int(effect.get("range", 0)), int(effect.get("radius", 0)), int(effect.get("duration_rounds", 0)),
			]
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


## Formats a damage multiplier without a trailing ".0" (2.0 -> "2", 1.4 -> "1.4").
static func _fmt_mult(m: float) -> String:
	if m == floor(m):
		return str(int(m))
	return str(m)
