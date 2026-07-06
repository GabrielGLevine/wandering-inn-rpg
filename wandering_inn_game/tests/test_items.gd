extends SceneTree
## Validates data/items.json (M7 E1: items data + events + validation).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_items.gd

const VALID_KINDS: Dictionary = {
	"weapon": true,
	"armor": true,
}

const VALID_WEAPON_FAMILIES: Dictionary = {
	"sword": true,
	"spear": true,
	"none": true,
}

const NUMERIC_FIELDS: Array[String] = ["damage_mod", "hp_mod", "damage_reduction"]


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

	var ids: Dictionary = {}
	var weapon_families_present: Dictionary = {}

	for entry: Dictionary in items_config["items"]:
		for key: String in ["id", "name", "kind", "weapon_family", "tier", "abilities", "description"]:
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

		# weapons must carry a real family (never "none"); armor is always "none".
		if kind == "weapon" and weapon_family == "none":
			_fail("weapon %s must have a real weapon_family, not none" % id)
		if kind == "armor" and weapon_family != "none":
			_fail("armor %s must have weapon_family none, got %s" % [id, weapon_family])

		if weapon_family != "none":
			weapon_families_present[weapon_family] = true

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
		if tier != "mundane":
			_fail("item %s tier must be mundane (schema hook only, M7 ships mundane-only): got %s" % [id, tier])

		if not entry["abilities"] is Array:
			_fail("item %s abilities must be an array" % id)
		if not (entry["abilities"] as Array).is_empty():
			_fail("item %s abilities must be empty (INERT schema hook in M7): got %s" % [id, JSON.stringify(entry["abilities"])])

		if String(entry["name"]).is_empty():
			_fail("item %s has empty name" % id)
		if String(entry["description"]).is_empty():
			_fail("item %s has empty description" % id)

	# Cross-reference: every weapon tag actually used by a skill (skills.json's
	# "weapon" field, the M6 T1 seam -- see wi_combat.gd's sword_skill_used/
	# spear_skill_used doc comment) must have at least one items.json entry of
	# that weapon_family, or an equipped weapon could never field that skill.
	var skills_config: Dictionary = _load("res://data/skills.json")
	if not skills_config.has("skills"):
		_fail("skills.json missing skills")

	var weapon_tags_used: Dictionary = {}
	var spells_with_weapon_tag: Array[String] = []
	for skill: Dictionary in skills_config["skills"]:
		if skill.has("weapon"):
			var tag: String = String(skill["weapon"])
			weapon_tags_used[tag] = true
			# Escalation check (plan self-review risk (a)): a spell (mp_cost
			# skill) carrying a weapon tag would break mage kit-intersection
			# in E2 -- spells must be untagged/always-fieldable.
			if skill.has("mp_cost"):
				spells_with_weapon_tag.append(String(skill.get("id", "?")))

	if not spells_with_weapon_tag.is_empty():
		_fail("ESCALATION: spell(s) with mp_cost carry a weapon tag -- would break mage kit-intersection in E2: %s" % [", ".join(spells_with_weapon_tag)])

	for tag: String in weapon_tags_used:
		if not weapon_families_present.has(tag):
			_fail("skills.json uses weapon tag %s but no items.json entry has that weapon_family" % tag)

	print("PASS: items data is well-formed and cross-referenced against skill weapon tags")
	quit(0)
