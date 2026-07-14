extends SceneTree

const VALID_KINDS: Dictionary = {
	"weapon": true,
	"armor": true,
	"accessory": true,
	"tool": true,
	"parcel": true,
	"meal": true,
}

const VALID_TIERS: Dictionary = {
	"mundane": true,
	"enchanted": true,
}

const VALID_WEAPON_FAMILIES: Dictionary = {
	"sword": true,
	"spear": true,
	"bow": true,
	"none": true,
}

const NUMERIC_FIELDS: Array[String] = ["damage_mod", "hp_mod", "damage_reduction"]

const VALID_USE_EFFECT_KEYS: Dictionary = {
	"heal": true,
	"next_fight": true,
}


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("missing file: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("invalid JSON: " + path)
	return parsed


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	WITestWatchdog.arm(self)
	var items_config: Dictionary = _load("res://data/items.json")
	if not items_config.has("items"):
		_fail("items.json missing items")
	if not items_config["items"] is Array:
		_fail("items.json items must be an array")

	var skills_config_early: Dictionary = _load("res://data/skills.json")
	if not skills_config_early.has("skills"):
		_fail("skills.json missing skills")
	var known_skill_ids: Dictionary = {}
	for sk: Dictionary in skills_config_early["skills"]:
		known_skill_ids[String(sk["id"])] = true

	var ids: Dictionary = {}
	var weapon_families_present: Dictionary = {}

	for entry: Dictionary in items_config["items"]:
		for key: String in ["id", "name", "kind", "weapon_family", "tier", "abilities", "description", "lore", "resonance"]:
			if not entry.has(key):
				_fail("item entry missing %s: %s" % [key, JSON.stringify(entry)])

		var id: String = String(entry["id"])
		if ids.has(id):
			_fail("duplicate item id: " + id)
		ids[id] = true

		var kind: String = String(entry["kind"])
		if not VALID_KINDS.has(kind):
			_fail("unknown item kind: %s for %s" % [kind, id])

		var weapon_family: String = String(entry["weapon_family"])
		if not VALID_WEAPON_FAMILIES.has(weapon_family):
			_fail("unknown weapon_family: %s for %s" % [weapon_family, id])

		if kind == "weapon" and weapon_family == "none":
			_fail("weapon %s must have a real weapon_family, not none" % id)
		if kind != "weapon" and weapon_family != "none":
			_fail("%s %s must have weapon_family none, got %s" % [kind, id, weapon_family])

		if weapon_family != "none":
			weapon_families_present[weapon_family] = true

		if entry.has("use_effect"):
			if not entry["use_effect"] is Dictionary:
				_fail("item %s use_effect must be a Dictionary" % id)
			if kind == "weapon" or kind == "armor" or kind == "accessory":
				_fail("item %s carries use_effect but is equippable (kind %s) -- use_effect and an equip slot are mutually exclusive" % [id, kind])
			var use_effect: Dictionary = entry["use_effect"]
			if use_effect.is_empty():
				_fail("item %s use_effect must not be empty" % id)
			for ue_key: String in use_effect:
				if not VALID_USE_EFFECT_KEYS.has(ue_key):
					_fail("item %s use_effect has unknown key: %s" % [id, ue_key])

		for field: String in NUMERIC_FIELDS:
			if not entry.has(field):
				_fail("item %s missing numeric field %s" % [id, field])
			var value: Variant = entry[field]
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				_fail("item %s field %s must be numeric" % [id, field])
			if int(value) != value:
				_fail("item %s field %s must be an int, got %s" % [id, field, str(value)])
			if int(value) < 0:
				_fail("item %s field %s must be >= 0, got %d" % [id, field, int(value)])

		var tier: String = String(entry["tier"])
		if not VALID_TIERS.has(tier):
			_fail("item %s has unknown tier: %s" % [id, tier])

		if not entry["abilities"] is Array:
			_fail("item %s abilities must be an array" % id)
		if not (entry["abilities"] as Array).is_empty():
			if kind != "accessory":
				_fail("item %s abilities non-empty but kind is %s (abilities are accessory-only, issue #92 R3): got %s" % [id, kind, JSON.stringify(entry["abilities"])])
			for raw_ability: Variant in (entry["abilities"] as Array):
				var ability_id := String(raw_ability)
				if not known_skill_ids.has(ability_id):
					_fail("item %s abilities lists unknown skill id: %s" % [id, ability_id])

		if String(entry["name"]).is_empty():
			_fail("item %s has empty name" % id)
		if String(entry["description"]).is_empty():
			_fail("item %s has empty description" % id)
		if String(entry["lore"]).is_empty():
			_fail("item %s has empty lore" % id)

		var resonance_value: Variant = entry["resonance"]
		if typeof(resonance_value) != TYPE_INT and typeof(resonance_value) != TYPE_FLOAT:
			_fail("item %s resonance must be numeric" % id)
		if int(resonance_value) != resonance_value:
			_fail("item %s resonance must be an int, got %s" % [id, str(resonance_value)])
		var resonance := int(resonance_value)
		if resonance < 0 or resonance > 3:
			_fail("item %s resonance must be 0 <= r <= 3, got %d" % [id, resonance])
		var expect_enchanted := resonance >= 1
		if expect_enchanted and tier != "enchanted":
			_fail("item %s has resonance %d but tier %s (resonance >= 1 must be tier enchanted)" % [id, resonance, tier])
		if not expect_enchanted and tier != "mundane":
			_fail("item %s has resonance 0 but tier %s (resonance 0 must be tier mundane)" % [id, tier])

	var skills_config: Dictionary = skills_config_early

	var weapon_tags_used: Dictionary = {}
	var spells_with_weapon_tag: Array[String] = []
	for skill: Dictionary in skills_config["skills"]:
		if skill.has("weapon"):
			var tag: String = String(skill["weapon"])
			weapon_tags_used[tag] = true
			if skill.has("mp_cost"):
				spells_with_weapon_tag.append(String(skill.get("id", "?")))

	if not spells_with_weapon_tag.is_empty():
		_fail("ESCALATION: spell(s) with mp_cost carry a weapon tag -- would break mage kit-intersection in E2: %s" % [", ".join(spells_with_weapon_tag)])

	for tag: String in weapon_tags_used:
		if not weapon_families_present.has(tag):
			_fail("skills.json uses weapon tag %s but no items.json entry has that weapon_family" % tag)

	print("PASS: items data is well-formed and cross-referenced against skill weapon tags")
	quit(0)
