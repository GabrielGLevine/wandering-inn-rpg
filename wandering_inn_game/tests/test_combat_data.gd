extends SceneTree


const KNOWN_ICONLESS_SKILLS := {
	# Playtest fix wave (finding 3): the martial slate's five entries are GONE
	# -- icons landed and data_lint.check_skill_icons now hard-fails any field
	# skill without one, so this allowlist can only ever cover COMBAT-only
	# skills (enemy verbs the hotbar never renders).
	"guarding_ward": true,
	# #460: the crypt Lich's three enemy-kit verbs. Same category as the three
	# above -- no class grants them, so the hotbar never renders a slot for one
	# and an icon would be art nothing can look at.
	"lich_bone_splinter": true,
	"lich_grave_lance": true,
	"raise_bones": true,
	"raskghar_maul": true,
	"slam": true,
}

const VISUAL_LOG_ICON_SKILLS := [
	"appraise_goods", "called_shot", "directed_strike", "disarm_trap",
	"find_trap", "flame_dart", "flame_pillar", "measured_words",
	"open_doors", "perfect_hospitality", "piercing_volley", "soothing_presence",
]


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "invalid JSON: " + path)
	return parsed


func _reachable_from(start: Vector2i, w: int, h: int, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir: Vector2i in dirs:
			var next: Vector2i = cur + dir
			if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h:
				continue
			if blocked.has(next) or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _init() -> void:
	WITestWatchdog.arm(self)
	var skills := _load("res://data/skills.json")
	var sprites := _load("res://data/sprites.json")
	var combatants := _load("res://data/combatants.json")
	var classes := _load("res://data/classes.json")
	var arenas := _load("res://data/arenas.json")
	var scene := WISceneCatalog.compose()

	var skill_ids := {}
	var iconless_seen := {}
	for s: Dictionary in skills[WIKeys.SKILLS]:
		var sid := String(s[WIKeys.ID])
		skill_ids[sid] = true
		assert(s.has(WIKeys.CONTEXTS) and s.has(WIKeys.DISPLAY_NAME), "skill missing fields: " + sid)
		if (s[WIKeys.CONTEXTS] as Array).has("combat"):
			assert(s.has(WIKeys.AP_COST) and s.has(WIKeys.EFFECT), "combat skill missing ap_cost/effect: " + sid)
		var hotbar_visible := bool(s.get(WIKeys.FIELD, false)) or float(s.get(WIKeys.AP_COST, 0)) > 0.0
		if hotbar_visible and not s.has("icon"):
			iconless_seen[sid] = true
			assert(KNOWN_ICONLESS_SKILLS.has(sid), "skill %s is hotbar-visible (field/ap_cost) but ships with no icon -- add icon_%s or track it in KNOWN_ICONLESS_SKILLS" % [sid, sid])
		if VISUAL_LOG_ICON_SKILLS.has(sid):
			var expected_icon := "icon_" + sid
			assert(String(s.get("icon", "")) == expected_icon, "skill %s must use %s" % [sid, expected_icon])
			assert(sprites.has(expected_icon), "skill %s icon is absent from sprites.json" % sid)
	for known_sid: String in KNOWN_ICONLESS_SKILLS:
		assert(iconless_seen.has(known_sid), "KNOWN_ICONLESS_SKILLS lists %s but it now carries an icon -- shrink the allowlist" % known_sid)

	var combatant_ids := {}
	for c: Dictionary in combatants["combatants"]:
		combatant_ids[String(c[WIKeys.ID])] = true
		for key: String in ["id", "display_name", "side", "stats", "weapon_die", "ai", "skills"]:
			assert(c.has(key), "combatant %s missing %s" % [c.get(WIKeys.ID, "?"), key])
		for stat: String in ["str", "dex", "con", "int", "wis", "cha"]:
			assert(c[WIKeys.STATS].has(stat), "combatant %s missing stat %s" % [c[WIKeys.ID], stat])
		for sk: Variant in c[WIKeys.SKILLS]:
			assert(skill_ids.has(String(sk)), "combatant %s references unknown skill %s" % [c[WIKeys.ID], sk])

	for cls: Dictionary in classes["classes"]:
		var prev_level := -1
		for lv: Dictionary in cls["levels"]:
			assert(prev_level == -1 or int(lv["level"]) == prev_level + 1, "class %s levels must be contiguous (gap before %d)" % [String(cls.get("id", "?")), int(lv["level"])])
			prev_level = int(lv["level"])
			for sk: Variant in lv["grants"]:
				assert(skill_ids.has(String(sk)), "class grant references unknown skill %s" % sk)

	var arena_ids := {}
	for a: Dictionary in arenas["arenas"]:
		var id := String(a[WIKeys.ID])
		arena_ids[id] = true
		var w := int(a["grid"]["width"])
		var h := int(a["grid"]["height"])
		assert(w == 12 and h == 8, "M1 arenas are 12x8")
		for cell: Array in (a["blocked"] as Array) + (a["player_spawns"] as Array) + (a["enemy_spawns"] as Array):
			assert(int(cell[0]) >= 0 and int(cell[0]) < w and int(cell[1]) >= 0 and int(cell[1]) < h, "cell out of bounds")
		assert((a["player_spawns"] as Array).size() >= 4, "need 4 player spawns (design-for-4)")

		var blocked := {}
		for cell: Array in a["blocked"]:
			blocked[Vector2i(int(cell[0]), int(cell[1]))] = true
		var all_spawns: Array = (a["player_spawns"] as Array) + (a["enemy_spawns"] as Array)
		assert(not all_spawns.is_empty(), "arena %s has no spawns" % id)
		var first: Vector2i = Vector2i(int(all_spawns[0][0]), int(all_spawns[0][1]))
		assert(not blocked.has(first), "arena %s spawn %s is itself blocked" % [id, first])
		var reachable := _reachable_from(first, w, h, blocked)
		for spawn: Array in all_spawns:
			var cell := Vector2i(int(spawn[0]), int(spawn[1]))
			assert(not blocked.has(cell), "arena %s spawn %s is itself blocked" % [id, cell])
			assert(reachable.has(cell), "arena %s spawn %s is unreachable from spawn %s" % [id, cell, first])

	for map_id: String in (scene["maps"] as Dictionary):
		var map: Dictionary = scene["maps"][map_id]
		for entity: Dictionary in (map.get("entities", []) as Array):
			if String(entity.get(WIKeys.KIND, "")) != "encounter":
				continue
			var eid := String(entity[WIKeys.ID])
			for key: String in ["arena", "enemies", "allies", "on_victory"]:
				assert(entity.has(key), "encounter %s missing %s" % [eid, key])
			assert(arena_ids.has(String(entity["arena"])), "encounter %s references unknown arena %s" % [eid, entity["arena"]])
			for enemy_id: Variant in entity["enemies"]:
				assert(combatant_ids.has(String(enemy_id)), "encounter %s references unknown enemy %s" % [eid, enemy_id])
			for ally_id: Variant in entity["allies"]:
				assert(combatant_ids.has(String(ally_id)), "encounter %s references unknown ally %s" % [eid, ally_id])
			# GH#448 the veto branch's own roster. Cross-referenced like `enemies`,
			# and REFUSED on an encounter with no `ally_requires`: `start_combat`
			# only ever reaches for it when an ally gate went unmet, so authoring
			# one anywhere else is a roster that can never be fielded.
			if entity.has("solo_enemies"):
				assert(not (entity.get("ally_requires", {}) as Dictionary).is_empty(),
					"encounter %s authors solo_enemies but has no ally_requires, so the roster is unreachable" % eid)
				assert(not (entity["solo_enemies"] as Array).is_empty(), "encounter %s has an empty solo_enemies" % eid)
				for enemy_id: Variant in entity["solo_enemies"]:
					assert(combatant_ids.has(String(enemy_id)), "encounter %s references unknown solo enemy %s" % [eid, enemy_id])

	_check_boss_veto_roster(scene, skills, combatants, classes, arenas)

	# GH#211 power_level tripwires: every non-pc combatant carries a POSITIVE
	# power_level (a negative would NaN through pow(x, 1.55); a missing one
	# silently neutralizes the challenge weight for its whole roster); pc must
	# NOT carry one (live-derived from class levels). victory_toast carriers'
	# FIRST on_victory id must not be the fractional won_combat counter or the
	# first-win==1 toast check misfires under weighting.
	for c: Dictionary in combatants["combatants"]:
		var cid := String(c[WIKeys.ID])
		if cid == "pc":
			assert(not c.has("power_level"), "pc must not carry an authored power_level")
		else:
			assert(c.has("power_level"), "%s missing power_level (GH#211 authoring pass)" % cid)
			assert(float(c["power_level"]) > 0.0, "%s power_level must be positive, got %s" % [cid, str(c["power_level"])])
	print("PASS: combat data is well-formed and cross-referenced")


func _check_boss_veto_roster(scene: Dictionary, skills: Dictionary, combatants: Dictionary, classes: Dictionary, arenas: Dictionary) -> void:
	var sink := func(_t: String, _p: Dictionary) -> void: pass
	var cfg := {
		"combatants": combatants, "classes": classes, "arenas": arenas,
		"items": _load("res://data/items.json"), "quests": _load("res://data/quests.json"),
		"acts": _load("res://data/acts.json"), "dialogue": {},
	}
	var g_solo := WIGame.new(scene, skills, sink, 1, cfg)
	g_solo.record_accomplishment("went_alone")
	assert(g_solo.start_combat("awakened_boss"), "solo start_combat(awakened_boss) failed")
	var solo: Dictionary = g_solo.combat.snapshot()["combatants"]
	assert(solo.has("pc") and solo.has("raskghar_awakened"), "solo roster missing pc/boss")
	assert(not solo.has("relc"), "VETO path must field NO ally, but Relc is in the roster")
	var g_join := WIGame.new(scene, skills, sink, 1, cfg)
	g_join.record_accomplishment("relc_joined_descent")
	assert(g_join.start_combat("awakened_boss"), "join start_combat(awakened_boss) failed")
	var join: Dictionary = g_join.combat.snapshot()["combatants"]
	assert(join.has("relc"), "JOIN path must field Relc as an ally, but he is absent")
	# GH#448 THE VETO IS A DIFFERENT FIGHT. The defect this replaced was the veto
	# fielding the JOIN pack with the ally slot empty (0.04 competent-at-band --
	# a refusal to win the act). Assert the branch by its SHAPE rather than by a
	# roster literal: strictly fewer enemy bodies than the join pack, so the
	# wire cannot be quietly cut back to "the same fight minus Relc" and cannot
	# rot the next time the join roster is retuned.
	var solo_enemies := 0
	for id: String in solo:
		if String((solo[id] as Dictionary)[WIKeys.SIDE]) == "enemy":
			solo_enemies += 1
	var join_enemies := 0
	for id: String in join:
		if String((join[id] as Dictionary)[WIKeys.SIDE]) == "enemy":
			join_enemies += 1
	assert(solo_enemies < join_enemies,
		"VETO path must field its OWN pack (solo_enemies), not the join roster minus Relc: %d enemy bodies vs the join's %d" % [solo_enemies, join_enemies])
	print("PASS: veto branch fields %d enemy bodies against the join branch's %d, and neither leaks the other's ally slot" % [solo_enemies, join_enemies])
	quit(0)
