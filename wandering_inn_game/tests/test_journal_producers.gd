extends SceneTree
## GH#336 — the Skills-tab redesign's unit floor: the SIM-side derivation the
## redesigned journal renders (`WIGame.skill_category`/`skill_bar`/
## `skills_journal_categories`) plus the AUTO field-bar contract (ruling 9, as
## reversed in the fix wave: the bar never deletes a Skill).
##
## WHY A DEDICATED SUITE: the whole point of the redesign is that the
## category/slottable rule is derived ONCE, in the sim, and that the derivation
## AGREES with the two hotbar eligibility shapes it is supposed to restate.
## Field visibility can additionally depend on equipped weapon state, which
## this suite source-pins while the sim suite exercises behaviorally.


var _events: Array = []


class CursorHotbarProbe:
	extends Node

	var skills: Array = []
	var selected := -1

	func _init(field_skills: Array) -> void:
		skills = field_skills.duplicate()

	func slot_count() -> int:
		return skills.size()

	func set_selected(index: int) -> void:
		selected = index

	func skill_for_slot(slot: int) -> String:
		var index := slot - 1
		return "" if index < 0 or index >= skills.size() else String(skills[index])


func _sink(type: String, payload: Dictionary) -> void:
	_events.append({"type": type, "payload": payload})


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON at " + path)
	return parsed


func _combat_config() -> Dictionary:
	return {
		"combatants": _load_json("res://data/combatants.json"),
		"classes": _load_json("res://data/classes.json"),
		"arenas": _load_json("res://data/arenas.json"),
		"items": _load_json("res://data/items.json"),
	}


func _new_game() -> WIGame:
	return WIGame.new(WISceneCatalog.compose(), _load_json("res://data/skills.json"), _sink, 4242, _combat_config())


func _read(path: String) -> String:
	assert(FileAccess.file_exists(path), "missing source file " + path)
	return FileAccess.get_file_as_string(path)


func _world_cursor_probe() -> Node:
	var raw := _read("res://src/world/world.gd")
	var marker := "func _move_field_slot_cursor(delta: int) -> void:\n"
	var method_start := raw.find(marker)
	var method_end := raw.find("\n\n", method_start)
	assert(method_start >= 0 and method_end > method_start,
		"world.gd cursor method moved; re-anchor the behavioral extraction")
	var script := GDScript.new()
	script.source_code = "extends Node\nvar _field_hotbar: Node\nvar _field_slot_index := -1\n\n" \
		+ raw.substr(method_start, method_end - method_start) + "\n"
	var err := script.reload()
	assert(err == OK, "world.gd cursor-method extraction failed to compile: %d" % err)
	return script.new() as Node


func _init() -> void:
	# `data/skills.json` is `{"skills": [...]}`; WIGame keys it by id at
	# construction, and THAT dict is what every consumer reads.
	var skills: Dictionary = _new_game().skills
	assert(not skills.is_empty(), "fixture: the skill catalog loaded")

	_check_category_partition(skills)
	_check_filter_agreement(skills)
	_check_bar_semantics(skills)
	_check_dedupe_and_provenance()
	_check_entry_enrichment()
	_check_checkbox_honesty()
	_check_auto_bar_cap()

	print("PASS: GH#336 skill categorisation (partition + live-filter agreement), dedupe/provenance, checkbox honesty, AUTO field bar loses no Skill")
	quit(0)


## Every shipped Skill lands in EXACTLY ONE bucket, and every bucket name is one
## the renderer knows how to head. A Skill that fell through would render
## nowhere -- silently missing from the only screen that lists it.
func _check_category_partition(skills: Dictionary) -> void:
	var counts: Dictionary = {}
	for category: String in WIGame.SKILL_CATEGORY_ORDER:
		counts[category] = 0
	for id: String in skills:
		var category := WIGame.skill_category(skills[id] as Dictionary)
		assert(counts.has(category), "skill %s derived category %s, which is not in SKILL_CATEGORY_ORDER" % [id, category])
		assert(WIGame.SKILL_CATEGORY_HEADINGS.has(category), "category %s has no heading copy" % category)
		counts[category] += 1
	var total := 0
	for category: String in counts:
		total += int(counts[category])
	assert(total == skills.size(), "the four buckets partition the catalog exactly: %d bucketed vs %d shipped" % [total, skills.size()])
	for category: String in counts:
		assert(int(counts[category]) > 0, "bucket %s is empty -- the redesign would draw a heading with nothing under it" % category)


## SPEC RULING 3, the agreement check. `skill_category` is a RESTATEMENT of the
## two eligibility shapes that decide whether a Skill can reach a bar; if either
## moves and this one doesn't, the journal starts lying again. Two teeth:
##   (a) BEHAVIOURAL -- re-derive both live filters over the whole catalog here
##       and demand the same answer, entry by entry.
##   (b) SOURCE-TEXT -- pin the filter expressions themselves. `combat_hud.gd`
##       is not this lane's file to change, so the tripwire fires on ITS edit
##       and surfaces the seam instead of silently disagreeing.
func _check_filter_agreement(skills: Dictionary) -> void:
	for id: String in skills:
		var sk: Dictionary = skills[id]
		# combat_hud.gd's rebuild_slots kit filter, verbatim.
		var combat_bar_takes_it: bool = (sk.get("contexts", []) as Array).has("combat") and int(sk.get("ap_cost", 0)) > 0
		# Catalog eligibility; live field visibility may additionally require the
		# declared weapon family to be equipped.
		var field_bar_takes_it: bool = bool(sk.get("field", false))
		var category := WIGame.skill_category(sk)
		var slottable := WIGame.SLOTTABLE_SKILL_CATEGORIES.has(category)
		assert(slottable == (combat_bar_takes_it or field_bar_takes_it),
			"%s: derived slottable=%s disagrees with the live bar filters (combat=%s field=%s)" % [id, slottable, combat_bar_takes_it, field_bar_takes_it])
		if combat_bar_takes_it:
			assert(category == WIGame.SKILL_CATEGORY_COMBAT_ACTIVE,
				"%s reaches the combat bar, so its primary bucket must be Combat — Active, got %s" % [id, category])
		elif field_bar_takes_it:
			assert(category == WIGame.SKILL_CATEGORY_FIELD_ACTIVE,
				"%s reaches only the field bar, so its bucket must be Exploration — Active, got %s" % [id, category])

	var hud_source := _read("res://src/combat/combat_hud.gd")
	assert(hud_source.contains("if WIGame.skill_bar(sk) in [\"combat\", \"both\"]:"),
		"combat_hud.gd's combat-bar kit filter no longer consumes WIGame.skill_bar -- the v0.17 train swap (GH#336 seam) collapsed the third filter copy onto the derived source; if the filter moved again, re-point this pin at the new consumer line")
	var sim_source := _read("res://src/core/wi_game.gd")
	assert(sim_source.contains("if _field_skill_available(id):"),
		"field_hotbar_loadout must consume the shared live field-eligibility helper")
	assert(sim_source.contains("and _field_skill_weapon_ready(skill_id)")
		and sim_source.contains("skill.get(\"field_weapon\", skill.get(WIKeys.WEAPON, \"\"))")
		and sim_source.contains("String(equipped_weapon.get(\"weapon_family\", \"\")) == required_family"),
		"live field eligibility must preserve field-only weapon-family gating with combat-key fallback")


## `bar` says which bar a tick on the row actually moves. `hotbar_loadout` is
## ONE shared array, so a Skill that clears both candidate filters is genuinely
## toggled onto both bars at once -- the "both" badge is the only place the tab
## can say so, since the row renders once.
func _check_bar_semantics(skills: Dictionary) -> void:
	var both_count := 0
	for id: String in skills:
		var sk: Dictionary = skills[id]
		var combat_slot: bool = (sk.get("contexts", []) as Array).has("combat") and int(sk.get("ap_cost", 0)) > 0
		var field_slot: bool = bool(sk.get("field", false))
		var bar := WIGame.skill_bar(sk)
		var expected := ""
		if combat_slot and field_slot:
			expected = "both"
			both_count += 1
		elif combat_slot:
			expected = "combat"
		elif field_slot:
			expected = "field"
		assert(bar == expected, "%s: bar %s, expected %s" % [id, bar, expected])
		assert((bar != "") == WIGame.SLOTTABLE_SKILL_CATEGORIES.has(WIGame.skill_category(sk)),
			"%s: a Skill has a bar exactly when it is slottable" % id)
	assert(both_count > 0, "at least one dual-context Skill ships -- otherwise the 'both' badge is dead code")


## THE 46-ROWS-FOR-28-SKILLS DEFECT. The class-primary producer walks the
## inherits closure once PER GROUP, so a consolidation class re-renders every
## inherited Skill; the categorized producer renders each id exactly once and
## names its sources in the row instead.
func _check_dedupe_and_provenance() -> void:
	var g := _new_game()
	g.classes = {"warrior": 4, "mage": 4, "spellsword": 4}

	var class_rows: Array[String] = []
	for raw_group: Variant in g.skills_journal():
		for raw_skill: Variant in (raw_group as Dictionary)["skills"]:
			class_rows.append(String((raw_skill as Dictionary)["id"]))
	var distinct: Dictionary = {}
	for id: String in class_rows:
		distinct[id] = true
	assert(class_rows.size() > distinct.size(),
		"fixture: the spellsword closure must actually duplicate rows in the class-primary producer, or this test proves nothing")

	var category_rows: Array[String] = []
	var seen: Dictionary = {}
	var headings: Array[String] = []
	for raw_group: Variant in g.skills_journal_categories():
		var group := raw_group as Dictionary
		headings.append(String(group["heading"]))
		assert(WIGame.SKILL_CATEGORY_HEADINGS.values().has(String(group["heading"])), "unknown category heading " + String(group["heading"]))
		for raw_skill: Variant in (group[WIKeys.SKILLS] as Array):
			var entry := raw_skill as Dictionary
			var id := String(entry[WIKeys.ID])
			assert(not seen.has(id), "%s rendered twice -- the dedupe is the whole point of the redesign" % id)
			seen[id] = true
			category_rows.append(id)
			assert(String(entry["category"]) == String(group["category"]),
				"%s sits under %s but derives %s" % [id, String(group["category"]), String(entry["category"])])
	assert(category_rows.size() == distinct.size(),
		"the categorized tab renders every DISTINCT Skill exactly once: %d rows vs %d distinct" % [category_rows.size(), distinct.size()])
	# Bucket order is the render order the cursor walks; it must follow the const.
	var expected_headings: Array[String] = []
	for category: String in WIGame.SKILL_CATEGORY_ORDER:
		if WIGame.SKILL_CATEGORY_HEADINGS[category] in headings:
			expected_headings.append(String(WIGame.SKILL_CATEGORY_HEADINGS[category]))
	assert(headings == expected_headings, "categories render in SKILL_CATEGORY_ORDER, got %s" % [headings])

	var provenance: Dictionary = {}
	for raw_group: Variant in g.skills_journal_categories():
		for raw_skill: Variant in ((raw_group as Dictionary)[WIKeys.SKILLS] as Array):
			var entry := raw_skill as Dictionary
			provenance[String(entry[WIKeys.ID])] = String(entry["provenance"])
	for id: String in provenance:
		assert(String(provenance[id]) != "", "%s rendered with no provenance at all" % id)
	assert(String(provenance.get("basic_cleaning", "")) == "Innate",
		"an innate Skill's provenance is the word Innate, not a class rung, got: %s" % [provenance.get("basic_cleaning", "")])
	var multi_source := 0
	for id: String in provenance:
		if String(provenance[id]).contains(", "):
			multi_source += 1
		else:
			var single := String(provenance[id])
			assert(single == "Innate" or single.contains(" L"),
				"a single-source class row names its rung (\"Warrior L1\"), got: %s" % single)
	assert(multi_source > 0,
		"fixture: a warrior/mage/spellsword save must produce at least one multi-source row, or the \", \" provenance shape is untested")

	# Single-class sanity: the 1-class saves every shipped QA pin uses have no
	# duplicates at all, which is WHY their skill_count pins survive the change.
	var solo := _new_game()
	solo.classes = {"warrior": 1}
	var solo_rows := 0
	for raw_group: Variant in solo.skills_journal_categories():
		solo_rows += ((raw_group as Dictionary)[WIKeys.SKILLS] as Array).size()
	var solo_class_rows := 0
	for raw_group: Variant in solo.skills_journal():
		solo_class_rows += ((raw_group as Dictionary)["skills"] as Array).size()
	assert(solo_rows == solo_class_rows,
		"a single-class save has nothing to dedupe: %d categorized rows vs %d class rows" % [solo_rows, solo_class_rows])


## Seam 1a: the enrichment is ADDITIVE. Every pre-existing key keeps its exact
## meaning (test_sim_core's reveal-gate suite reads `revealed`/`text` off these
## same entries), and the new keys carry what the renderer needs so it never
## re-derives the rule a third time.
func _check_entry_enrichment() -> void:
	var g := _new_game()
	g.classes = {"warrior": 1}
	var by_id: Dictionary = {}
	for raw_group: Variant in g.skills_journal():
		for raw_skill: Variant in (raw_group as Dictionary)["skills"]:
			by_id[String((raw_skill as Dictionary)[WIKeys.ID])] = raw_skill
	for key: String in ["id", "display_name", "revealed", "text", "category", "slottable", "bar", "ap_cost", "mp_cost", "icon"]:
		assert((by_id["power_strike"] as Dictionary).has(key), "enriched entry is missing key " + key)
	var power := by_id["power_strike"] as Dictionary
	var power_source: Dictionary = g.skills["power_strike"]
	assert(int(power[WIKeys.AP_COST]) == int(power_source.get("ap_cost", 0)), "ap_cost is carried straight from the catalog record")
	assert(int(power[WIKeys.MP_COST]) == int(power_source.get("mp_cost", 0)), "mp_cost is carried straight from the catalog record")
	assert(String(power["icon"]) == String(power_source.get("icon", "")), "icon is carried straight from the catalog record")
	assert(String(power["category"]) == WIGame.SKILL_CATEGORY_COMBAT_ACTIVE and bool(power["slottable"]),
		"a 2 AP combat strike is Combat — Active and slottable")
	# The reveal gate is unchanged by the refactor: an activatable Skill stays
	# opaque, a passive reads revealed from the moment it is granted.
	assert(not bool(power["revealed"]), "an unused activatable Skill is still opaque")
	assert(bool((by_id["tough_body"] as Dictionary)["revealed"]), "a passive still reads revealed with no use behind it")
	assert(not bool((by_id["tough_body"] as Dictionary)["slottable"]), "a passive is not slottable")


## SPEC RULING 4, the honest checkbox. The old tab let the player tick 41 of 119
## catalog entries that ride `hotbar_loadout` and appear on no bar, ever. The
## invariant now: a row carries a checkbox EXACTLY when ticking it changes a bar.
func _check_checkbox_honesty() -> void:
	var g := _new_game()
	g.classes = {"warrior": 4, "mage": 4, "spellsword": 4}
	var combat_candidates: Dictionary = {}
	var field_candidates: Dictionary = {}
	for raw: Variant in g.known_skills():
		var id := String(raw)
		var sk: Dictionary = g.skills.get(id, {})
		if (sk.get("contexts", []) as Array).has("combat") and int(sk.get("ap_cost", 0)) > 0:
			combat_candidates[id] = true
		if bool(sk.get("field", false)):
			field_candidates[id] = true
	var checked := 0
	var glyphed := 0
	for raw_group: Variant in g.skills_journal_categories():
		for raw_skill: Variant in ((raw_group as Dictionary)[WIKeys.SKILLS] as Array):
			var entry := raw_skill as Dictionary
			var id := String(entry[WIKeys.ID])
			var reaches_a_bar: bool = combat_candidates.has(id) or field_candidates.has(id)
			assert(bool(entry["slottable"]) == reaches_a_bar,
				"%s: checkbox rendered=%s but reaches-a-bar=%s -- this IS the lie the redesign kills" % [id, entry["slottable"], reaches_a_bar])
			if bool(entry["slottable"]):
				checked += 1
			else:
				glyphed += 1
	assert(checked > 0 and glyphed > 0,
		"fixture must hold both slottable and passive Skills, got %d/%d" % [checked, glyphed])


## SPEC RULING 9, as REVERSED in the fix wave: the AUTO bar must never DELETE a
## field Skill. A first pass clipped AUTO to `AUTO_SLOT_CAP`, on the ruling's
## premise that slot ten was unreachable; it is only *number-key*-unreachable
## (`world.gd::_move_field_slot_cursor` wraps the cursor onto it, and
## `field_hotbar.gd`'s `slot_clicked` fires for any rendered slot), so clipping
## made earned Skills uncastable instead of tidying a dead affordance. These
## asserts are the regression tripwire on that: they fail the moment a slice
## comes back. AUTO_SLOT_CAP keeps its real job (bounding AUTO-SLOTTING into a
## CUSTOM loadout, a7 #208), which is asserted here too so the const cannot be
## deleted as unused.
func _check_auto_bar_cap() -> void:
	var g := _new_game()
	g.inventory.clear()
	g.equipped[WIKeys.WEAPON] = ""
	var field_ids: Array[String] = []
	for id: String in g.skills:
		var skill := g.skills[id] as Dictionary
		if bool(skill.get("field", false)) \
				and not (bool(skill.get("cuts", false)) \
				and String(skill.get("field_weapon", skill.get(WIKeys.WEAPON, ""))) != ""):
			field_ids.append(id)
	assert(field_ids.size() > WIGame.AUTO_SLOT_CAP,
		"fixture: the shipped catalog must carry more than %d field Skills for the over-cap case to be reachable at all" % WIGame.AUTO_SLOT_CAP)

	# Under the cap: AUTO is byte-identical to the currently eligible field
	# derivation (weapon-tagged cuts are intentionally absent while unarmed).
	g.player_skills = field_ids.slice(0, WIGame.AUTO_SLOT_CAP - 1)
	assert(g.field_hotbar_loadout() == g.player_skills,
		"under the cap, AUTO is the unfiltered eligible field list exactly")

	# OVER the cap: still the unfiltered eligible field list. Every currently
	# usable field Skill the player earned is on the bar; none is dropped.
	g.player_skills = field_ids.duplicate()
	var bar: Array = g.field_hotbar_loadout()
	assert(bar == field_ids,
		"AUTO renders EVERY field Skill (%d), got %d -- a clip here deletes earned Skills from the field, it does not tidy the bar" % [field_ids.size(), bar.size()])

	# KEYLESS-SLOT REACHABILITY PROOF. Slots ten and above have no number key,
	# but they are not unreachable: the real world cursor wraps onto them. Keep
	# the >=10 premise explicit so a shrinking field pool reds here instead of
	# silently turning this into another ordinary numbered-slot wrap test.
	assert(bar.size() >= 10,
		"cursor-wrap premise: synthetic AUTO field bar must reach a keyless slot, got %d" % bar.size())
	var cursor_hotbar := CursorHotbarProbe.new(bar)
	var world := _world_cursor_probe()
	world.set("_field_hotbar", cursor_hotbar)
	world.set("_field_slot_index", 0)
	world.call("_move_field_slot_cursor", -1)
	var wrapped_index := int(world.get("_field_slot_index"))
	assert(wrapped_index == bar.size() - 1 and cursor_hotbar.selected == wrapped_index,
		"one backwards move from primed index 0 must wrap onto the final keyless slot")
	assert(cursor_hotbar.skill_for_slot(wrapped_index + 1) == String(bar[wrapped_index]),
		"wrapped cursor must select the final Skill derived from the built field bar")
	world.call("_move_field_slot_cursor", 1)
	assert(int(world.get("_field_slot_index")) == 0 and cursor_hotbar.selected == 0,
		"one forwards move from the final keyless slot must wrap back to index 0")
	world.free()
	cursor_hotbar.free()

	# A CUSTOM loadout is honoured in full for the same reason, and because
	# `loadout_toggle` is the player's explicit curation: the redesigned tab IS
	# the tool for deliberately exceeding nine (spec ruling 9).
	g.hotbar_loadout = field_ids.duplicate()
	assert(g.field_hotbar_loadout().size() == field_ids.size(),
		"a CUSTOM loadout is honoured in full")

	# Fix wave: a curated kit that names no FIELD Skill is a statement about the
	# combat bar, not a request for an empty exploration bar. One shared
	# `hotbar_loadout` feeds both, so before this the first tick on the new
	# tab's top row (a combat-only Skill) blanked the field bar to zero slots.
	var combat_only: Array = []
	for id: String in g.skills:
		var sk := g.skills[id] as Dictionary
		if not bool(sk.get("field", false)) and (sk.get("contexts", []) as Array).has("combat"):
			combat_only.append(id)
	assert(not combat_only.is_empty(), "fixture: the catalog must carry a combat-only Skill")
	g.hotbar_loadout = [combat_only[0]]
	assert(g.field_hotbar_loadout() == field_ids,
		"a combat-only loadout leaves the field bar on AUTO, it does not blank it")

	# The cap's ONE surviving job: automatic growth. A CUSTOM loadout already at
	# the cap does not grow when a new field Skill is learned.
	var g2 := _new_game()
	var known_before: Array = field_ids.slice(0, WIGame.AUTO_SLOT_CAP)
	g2.player_skills = known_before.duplicate()
	g2.hotbar_loadout = known_before.duplicate()
	g2.player_skills = field_ids.duplicate()
	g2._auto_slot_new_field_skills(known_before)
	assert(g2.hotbar_loadout.size() == WIGame.AUTO_SLOT_CAP,
		"auto-slotting stops at the cap (%d), got %d" % [WIGame.AUTO_SLOT_CAP, g2.hotbar_loadout.size()])
