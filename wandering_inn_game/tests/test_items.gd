extends SceneTree
## Validates data/items.json (items data + events + validation).
## Run: /usr/local/bin/godot --headless --path wandering_inn_game --script res://tests/test_items.gd

const VALID_KINDS: Dictionary = {
	"weapon": true,
	"armor": true,
	"accessory": true,
	"tool": true,
	# A Runner's Guild delivery parcel -- inert carried flavor
	# (no price, no combat fields, resonance 0). Not equippable: WIGame.equip
	# only accepts weapon/armor/accessory, and inventory.gd's confirm shows
	# its neutral "isn't something you can equip" toast for this kind exactly
	# as for tools. Granted by accept_delivery, removed by remove_item on the
	# arrival handoff or a sleep-fail return.
	"parcel": true,
}

## Tier is now tied to resonance, not a mundane-only schema
## hook -- an item with resonance >= 1 is "enchanted" (the card's rarity
## vocabulary), everything else stays "mundane". Retiring the hard-pinned
## "mundane always" check from M7 in favor of this rule (G1/G2 call, per
## the staging doc's §D open question -- resonance stays the single source
## of truth for the arithmetic; tier is just its display bucket).
const VALID_TIERS: Dictionary = {
	"mundane": true,
	"enchanted": true,
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

		# weapons must carry a real family (never "none"); every other kind
		# (armor/accessory/tool) is always "none" -- same rule for all
		# non-weapon kinds.
		if kind == "weapon" and weapon_family == "none":
			_fail("weapon %s must have a real weapon_family, not none" % id)
		if kind != "weapon" and weapon_family != "none":
			_fail("%s %s must have weapon_family none, got %s" % [kind, id, weapon_family])

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
		if not VALID_TIERS.has(tier):
			_fail("item %s has unknown tier: %s" % [id, tier])

		if not entry["abilities"] is Array:
			_fail("item %s abilities must be an array" % id)
		if not (entry["abilities"] as Array).is_empty():
			_fail("item %s abilities must be empty (INERT schema hook in M7): got %s" % [id, JSON.stringify(entry["abilities"])])

		if String(entry["name"]).is_empty():
			_fail("item %s has empty name" % id)
		if String(entry["description"]).is_empty():
			_fail("item %s has empty description" % id)
		if String(entry["lore"]).is_empty():
			_fail("item %s has empty lore" % id)

		# Resonance is the single source of truth for the
		# capacity arithmetic (WIGame._equipped_resonance_total sums it across
		# all 5 equipped slots); tier above is only its display bucket.
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

	# Cross-reference: every weapon tag actually used by a skill (skills.json's
	# "weapon" field seam -- see wi_combat.gd's sword_skill_used/
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
